/*
 05_xmin_holders.sql
 ЧТО: кто держит xmin-горизонт в целевых БД: сессии с открытыми транзакциями,
      слоты репликации, prepared (2PC) транзакции. Именно они тормозят
      vacuum и «смещение» xmin.
 ГДЕ: в любой БД кластера.
 КАК: разово. Если что-то висит, мониторь через  \watch 300
*/
WITH targets(datname) AS (VALUES
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name')
)
SELECT 'session'                         AS holder_type,
       a.datname,
       a.pid::text || ' ' || coalesce(a.usename, '') || ' ' || coalesce(a.application_name, '') AS holder,
       a.backend_xmin                    AS xmin,
       age(a.backend_xmin)               AS xmin_age,
       a.xact_start                      AS since
FROM pg_stat_activity a
JOIN targets t ON t.datname = a.datname
WHERE a.backend_xmin IS NOT NULL
  AND a.pid <> pg_backend_pid()
UNION ALL
SELECT 'slot',
       s.database,
       s.slot_name || ' (' || s.slot_type || ', active=' || s.active || ')',
       coalesce(s.xmin, s.catalog_xmin),
       age(coalesce(s.xmin, s.catalog_xmin)),
       NULL
FROM pg_replication_slots s
JOIN targets t ON t.datname = s.database
WHERE coalesce(s.xmin, s.catalog_xmin) IS NOT NULL
UNION ALL
SELECT 'prepared_xact',
       p.database,
       p.gid || ' owner=' || p.owner,
       p.transaction,
       age(p.transaction),
       p.prepared
FROM pg_prepared_xacts p
JOIN targets t ON t.datname = p.database
ORDER BY xmin_age DESC NULLS LAST;
