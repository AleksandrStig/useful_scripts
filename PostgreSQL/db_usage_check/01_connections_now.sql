/*
 01_connections_now.sql
 ЧТО: кто сейчас подключён к целевым БД. Результат выводится одной строкой
      NOTICE на каждую группу (БД / роль / приложение / адрес):
        NOTICE:  <ts>  --  ACTIVITY db=... user=... app=... addr=... sessions=N ...
      Если сессий нет ни в одной БД, выводится одна строка:
        NOTICE:  <ts>  --  pg_stat_activity is empty for target databases
 ГДЕ: в любой БД кластера (например postgres).
 КАК: разово, либо мониторить:
        psql -X -q -P pager=off -h <host> -U <user> -d postgres \
          -c '\i 01_connections_now.sql' -c '\watch 60' 2>&1 | tee -a 01_connections.log
      NOTICE пишется в stderr, поэтому нужен 2>&1.
      Ловит только тех, кто подключён в момент запроса. Для истории нужен log_connections = on.
 ПРАВА: pg_monitor / pg_read_all_stats, иначе addr чужих сессий будет «-».
 ГРЕП ЛОГА:
      grep ACTIVITY 01_connections.log
      grep -o 'db=.* addr=[^ ]*' 01_connections.log | sort | uniq -c
*/

-- вариант запуска
-- { cat 01_connections_now.sql; echo '\watch 5'; } | psql -X -q -P pager=off -h $PROD1 -p 6432 -U aaevstegneev -d flora-clients-request-prod 2>&1 | tee -a ~/tmp/01_connections.log
DO $$
DECLARE
    -- ===== список проверяемых БД =====
    target_dbs text[] := ARRAY[
        'your_db_name',
        'your_db_name',
        'your_db_name',
        'your_db_name',
        'your_db_name'
    ];
    -- =================================
    ts        text    := now()::text;
    found_any boolean := false;
    r         record;
BEGIN
    FOR r IN
        SELECT a.datname,
               a.usename,
               a.application_name,
               a.client_addr,
               count(*)                                   AS sessions,
               count(*) FILTER (WHERE a.state = 'active') AS active,
               min(a.backend_start)                       AS oldest_backend_start,
               max(a.state_change)                        AS last_state_change
        FROM pg_stat_activity a
        WHERE a.datname::text = ANY (target_dbs)
          AND a.pid <> pg_backend_pid()
        GROUP BY a.datname, a.usename, a.application_name, a.client_addr
        ORDER BY a.datname, sessions DESC
    LOOP
        found_any := true;
        RAISE NOTICE '%  --  ACTIVITY db=% user=% app=% addr=% sessions=% active=% oldest_backend_start=% last_state_change=%',
            ts,
            r.datname,
            coalesce(r.usename::text, '-'),
            coalesce(nullif(r.application_name, ''), '-'),
            coalesce(r.client_addr::text, '-'),
            r.sessions,
            r.active,
            coalesce(r.oldest_backend_start::text, '-'),
            coalesce(r.last_state_change::text, '-');
    END LOOP;

    IF NOT found_any THEN
        RAISE NOTICE '%  --  pg_stat_activity is empty for target databases', ts;
    END IF;
END
$$;
