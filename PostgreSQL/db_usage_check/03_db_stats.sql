/*
 03_db_stats.sql
 ЧТО: накопительные счётчики pg_stat_database: сессии, транзакции, запись, чтение.
      Счёт идёт с момента stats_reset (или рестарта), поэтому смотреть надо на
      РАЗНИЦУ между двумя запусками, а не на абсолютные цифры.
 ГДЕ: в любой БД кластера.
 КАК: запусти, сохрани вывод. Через N часов или дней запусти ещё раз и сравни.
      Удобно раз в сутки по cron:  psql -X -f 03_db_stats.sql >> db_stats.txt
      Если stats_reset между запусками поменялся, сравнение недостоверно.
 ВЕРСИЯ: PG14+ (колонки sessions*). На PG13 и ниже убери строки с sessions/session_time/active_time.
 ВАЖНО: любой коннект к целевой БД (в том числе твой) увеличивает sessions на 1.
*/
WITH targets(datname) AS (VALUES
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name')
)
SELECT now()                                         AS checked_at,
       d.datname,
       pg_size_pretty(pg_database_size(d.datname))  AS size,
       d.numbackends                                 AS backends_now,
       d.sessions,
       d.sessions_abandoned,
       d.sessions_fatal,
       d.sessions_killed,
       round(d.session_time::numeric / 3600000, 2)  AS session_hours,
       round(d.active_time::numeric  / 3600000, 2)  AS active_hours,
       d.xact_commit,
       d.xact_rollback,
       d.tup_inserted,
       d.tup_updated,
       d.tup_deleted,
       d.tup_fetched,
       d.tup_returned,
       d.blks_read,
       d.blks_hit,
       d.stats_reset,
       pg_postmaster_start_time()                    AS postmaster_start
FROM pg_stat_database d
JOIN targets t ON t.datname = d.datname
ORDER BY d.datname;
