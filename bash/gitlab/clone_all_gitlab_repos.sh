#!/usr/bin/env bash
#
# Клонирует ВСЕ репозитории GitLab, к которым у тебя есть доступ (не важно, в какой
# группе/подгруппе они лежат), сохраняя структуру путей как в GitLab
# (namespace/подгруппа/repo -> такая же вложенность папок локально).
#
# Требуется: curl, jq, git, валидный Personal Access Token (scope: read_repository, read_api).
#
# Использование:
#   export GITLAB_URL="https://gitlab.link.ru"
#   export TOKEN="твой_токен"
#   export EXCLUDE="some-group,another-group/subgroup"   # необязательно, через запятую
#   ./clone_all_gitlab_repos.sh
#
# EXCLUDE — список path_with_namespace-префиксов (групп/подгрупп/конкретных репо),
# которые нужно пропустить. Совпадение по префиксу пути, например:
#   EXCLUDE="infrastructure/legacy"  исключит и сам репо infrastructure/legacy (если это репо),
#   и всё, что лежит внутри infrastructure/legacy/... (если это группа).
#
# Запускать из той папки, куда хочешь склонировать репозитории (например, .../project/gitlab).

set -uo pipefail

: "${GITLAB_URL:?Укажи GITLAB_URL, например https://gitlab.link.ru}"
: "${TOKEN:?Укажи TOKEN (Personal Access Token с scope read_repository/read_api)}"

EXCLUDE="${EXCLUDE:-}"
IFS=',' read -ra EXCLUDE_PREFIXES <<< "$EXCLUDE"

is_excluded() {
  local repo="$1" prefix
  for prefix in "${EXCLUDE_PREFIXES[@]:-}"; do
    [[ -z "$prefix" ]] && continue
    if [[ "$repo" == "$prefix" || "$repo" == "$prefix"/* ]]; then
      return 0
    fi
  done
  return 1
}

if ! command -v jq >/dev/null 2>&1; then
  echo "Нужен jq (sudo apt install jq)." >&2
  exit 1
fi

HOST="${GITLAB_URL#https://}"
HOST="${HOST#http://}"

PAGE=1
PER_PAGE=100
TOTAL=0
FAILED=0

echo "Собираю список проектов (может занять время, если репозиториев много)..." >&2

while :; do
  HTTP_CODE=$(curl -s -o /tmp/gl_resp_$$ -w '%{http_code}' --header "PRIVATE-TOKEN: $TOKEN" \
    "$GITLAB_URL/api/v4/projects?membership=true&per_page=${PER_PAGE}&page=${PAGE}&simple=true")
  RESPONSE=$(cat /tmp/gl_resp_$$)
  rm -f /tmp/gl_resp_$$

  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "!! GitLab API вернул HTTP $HTTP_CODE:" >&2
    echo "$RESPONSE" | jq . 2>/dev/null >&2 || echo "$RESPONSE" >&2
    echo "Проверь TOKEN (валиден? scope read_api/read_repository?) и GITLAB_URL." >&2
    exit 1
  fi

  IS_ARRAY=$(echo "$RESPONSE" | jq 'type == "array"' 2>/dev/null)
  if [[ "$IS_ARRAY" != "true" ]]; then
    echo "!! Ожидал JSON-массив проектов, получил другое:" >&2
    echo "$RESPONSE" | jq . 2>/dev/null >&2 || echo "$RESPONSE" >&2
    exit 1
  fi

  COUNT=$(echo "$RESPONSE" | jq 'length')
  [[ "$COUNT" -eq 0 ]] && break

  echo "$RESPONSE" | jq -r '.[].path_with_namespace' | while read -r repo; do
    [[ -z "$repo" ]] && continue
    if is_excluded "$repo"; then
      echo "  [исключено] $repo — пропускаю"
      continue
    fi
    if [[ -d "$repo/.git" ]]; then
      echo "  [уже есть] $repo — пропускаю (если нужно обновить, добавь git pull отдельно)"
      continue
    fi
    echo "  клонирую: $repo"
    mkdir -p "$(dirname "$repo")"
    if ! git clone --quiet "https://oauth2:${TOKEN}@${HOST}/${repo}.git" "$repo" 2>/tmp/clone_err_$$; then
      echo "  !! ОШИБКА клонирования $repo: $(cat /tmp/clone_err_$$)" >&2
    fi
    rm -f /tmp/clone_err_$$
  done

  TOTAL=$((TOTAL + COUNT))
  PAGE=$((PAGE + 1))
done

echo "Готово. Всего проектов найдено: $TOTAL" >&2
echo "Структура папок повторяет namespace/подгруппы GitLab." >&2
