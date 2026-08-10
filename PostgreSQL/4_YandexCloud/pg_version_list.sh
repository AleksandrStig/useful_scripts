#!/usr/bin/env bash
#
# Собирает версии PostgreSQL со всех managed-кластеров во всех фолдерах.
# Выводит: версию, фолдер, имя кластера. Отсортировано по возрастанию версии.
#
# Профили тут используются только как источник аутентификации: если несколько твоих
# yc-профилей смотрят на один и тот же cloud-id (частый случай — один юзер/федерация,
# просто разные дефолтные фолдеры), скрипт сканирует такое облако только ОДИН раз,
# а не по разу на каждый профиль.
#
# Требуется: yc CLI (авторизованный), jq.
#
# Использование:
#   ./pg_versions_by_profile.sh                # обойти ВСЕ фолдеры во всех уникальных облаках
#   ./pg_versions_by_profile.sh <folder-id>     # ограничиться одним конкретным фолдером

set -uo pipefail

TARGET_FOLDER="${1:-}"

if ! command -v jq >/dev/null 2>&1; then
  echo "Нужен jq (sudo apt install jq / brew install jq)." >&2
  exit 1
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

PROFILES=$(yc config profile list 2>/dev/null | tail -n +2 | awk '{print $1}')

if [[ -z "$PROFILES" ]]; then
  echo "Не нашёл ни одного yc-профиля (yc config profile list пуст)." >&2
  exit 1
fi

collect_clusters_for_folder() {
  local profile="$1" folder_id="$2"

  local folder_name
  folder_name=$(yc resource-manager folder get "$folder_id" --profile "$profile" --format json 2>/dev/null \
    | jq -r '.name // empty')
  [[ -z "$folder_name" ]] && folder_name="$folder_id"

  echo "    фолдер: $folder_name ($folder_id)..." >&2

  local clusters_json
  clusters_json=$(yc managed-postgresql cluster list --folder-id "$folder_id" --profile "$profile" --format json 2>/dev/null)
  [[ -z "$clusters_json" || "$clusters_json" == "null" ]] && return

  echo "$clusters_json" | jq -r '.[] | [.config.version, .name] | @tsv' 2>/dev/null \
    | while IFS=$'\t' read -r version cname; do
        [[ -z "$cname" ]] && continue
        printf '%s\t%s\t%s\n' "$version" "$folder_name" "$cname" >> "$TMPFILE"
      done
}

if [[ -n "$TARGET_FOLDER" ]]; then
  # Конкретный фолдер задан аргументом — хватит одного любого профиля для аутентификации.
  first_profile=$(echo "$PROFILES" | head -n1)
  collect_clusters_for_folder "$first_profile" "$TARGET_FOLDER"
else
  # Дедуп профилей по cloud-id: для каждого уникального облака берём первый попавшийся
  # профиль, который на него смотрит, и используем его как источник аутентификации.
  CLOUD_PROFILE_PAIRS=$(
    for profile in $PROFILES; do
      cid=$(yc config get cloud-id --profile "$profile" 2>/dev/null)
      [[ -n "$cid" && "$cid" != "null" ]] && echo "$cid $profile"
    done | awk '!seen[$1]++'
  )

  if [[ -z "$CLOUD_PROFILE_PAIRS" ]]; then
    echo "Ни у одного профиля не нашёл cloud-id." >&2
    exit 1
  fi

  CLOUD_TOTAL=$(echo "$CLOUD_PROFILE_PAIRS" | wc -l)
  CLOUD_NUM=0

  while read -r cloud_id profile; do
    CLOUD_NUM=$((CLOUD_NUM + 1))
    echo "=== [$CLOUD_NUM/$CLOUD_TOTAL] облако: $cloud_id (через профиль $profile) ===" >&2

    folder_ids=$(yc resource-manager folder list --cloud-id "$cloud_id" --profile "$profile" --format json 2>/dev/null \
      | jq -r '.[].id')

    if [[ -z "$folder_ids" ]]; then
      echo "  не нашёл ни одного фолдера в облаке $cloud_id — пропускаю" >&2
      continue
    fi

    echo "  найдено фолдеров: $(echo "$folder_ids" | wc -l)" >&2

    for folder_id in $folder_ids; do
      collect_clusters_for_folder "$profile" "$folder_id"
    done
  done <<< "$CLOUD_PROFILE_PAIRS"
fi

if [[ ! -s "$TMPFILE" ]]; then
  echo "Кластеров PostgreSQL не найдено." >&2
  exit 0
fi

{
  printf 'VERSION\tFOLDER\tCLUSTER\n'
  # сначала dedup по всей строке, потом сортировка по версии
  # (sort -k1,1 -u проверяет уникальность только по полю версии — этим не пользуемся)
  sort -u "$TMPFILE" | sort -t $'\t' -k1,1V
} | column -t -s $'\t'
