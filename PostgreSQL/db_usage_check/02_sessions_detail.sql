/*
 02_sessions_detail.sql
 ЧТО: детально каждая сессия в целевых БД: кто, откуда, с какого времени,
      что делает, текущий запрос.
 ГДЕ: в любой БД кластера.
 КАК: разово, когда 01 показал, что кто-то есть.
 ПРАВА: pg_monitor / pg_read_all_stats, иначе query чужих сессий скрыт.
*/
WITH targets(datname) AS (VALUES
    ('flora-business-process-prod'),
    ('flora-clients-request-prod'),
    ('flora-comments-and-annotations-prod'),
    ('flora-communications-prod'),
    ('flora-legal-execution-prod')
)
SELECT a.pid,
       a.datname,
       a.usename,
       a.application_name,
       a.client_addr,
       a.client_hostname,
       a.backend_type,
       a.backend_start,
       a.xact_start,
       a.state,
       a.state_change,
       a.wait_event_type || ':' || a.wait_event          AS wait,
       left(regexp_replace(a.query, '\s+', ' ', 'g'), 150) AS query
FROM pg_stat_activity a
JOIN targets t ON t.datname = a.datname
WHERE a.pid <> pg_backend_pid()
ORDER BY a.datname, a.backend_start;
