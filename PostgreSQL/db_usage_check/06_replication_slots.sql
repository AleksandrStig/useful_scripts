/*
 06_replication_slots.sql
 ЧТО: логические слоты репликации на целевых БД (Debezium, CDC, подписки).
      Живой слот значит, что изменения БД кто-то читает, даже если в
      pg_stat_activity приложений не видно.
      active = false и большой wal_retained: брошенный слот, который копит WAL
      и может забить диск.
 ГДЕ: на мастере (pg_current_wal_lsn на реплике выдаст ошибку).
 КАК: разово, затем раз в сутки, чтобы видеть, двигается ли confirmed_flush_lsn.
*/
WITH targets(datname) AS (VALUES
    ('flora-business-process-prod'),
    ('flora-clients-request-prod'),
    ('flora-comments-and-annotations-prod'),
    ('flora-communications-prod'),
    ('flora-legal-execution-prod')
)
SELECT now()                         AS checked_at,
       s.database,
       s.slot_name,
       s.slot_type,
       s.plugin,
       s.active,
       s.active_pid,
       a.usename,
       a.application_name,
       a.client_addr,
       a.backend_start,
       s.confirmed_flush_lsn,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), s.confirmed_flush_lsn)) AS lag_confirmed,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), s.restart_lsn))         AS wal_retained
FROM pg_replication_slots s
JOIN targets t ON t.datname = s.database
LEFT JOIN pg_stat_activity a ON a.pid = s.active_pid
ORDER BY s.database, s.slot_name;
