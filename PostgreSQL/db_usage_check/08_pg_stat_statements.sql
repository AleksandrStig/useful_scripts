/*
 08_pg_stat_statements.sql
 ЧТО: какие роли и сколько запросов выполняли в целевых БД
      (с момента последнего сброса pg_stat_statements).
 ГДЕ: в БД, где установлено расширение pg_stat_statements (обычно postgres).
      Без расширения запрос упадёт с ошибкой relation does not exist.
 КАК: разово, затем повторить через период и сравнить calls.
      Дату сброса смотри так (PG14+): SELECT stats_reset, dealloc FROM pg_stat_statements_info;
 ВЕРСИЯ: PG13+ (total_exec_time). На PG12 и ниже замени на total_time.
*/
WITH targets(datname) AS (VALUES
    ('flora-business-process-prod'),
    ('flora-clients-request-prod'),
    ('flora-comments-and-annotations-prod'),
    ('flora-communications-prod'),
    ('flora-legal-execution-prod')
)
SELECT d.datname,
       pg_get_userbyid(s.userid)                       AS role,
       count(*)                                        AS distinct_queries,
       sum(s.calls)                                    AS calls,
       sum(s.rows)                                     AS rows,
       round(sum(s.total_exec_time)::numeric / 1000, 1) AS exec_sec,
       left(regexp_replace((array_agg(s.query ORDER BY s.calls DESC))[1], '\s+', ' ', 'g'), 150) AS top_query
FROM pg_stat_statements s
JOIN pg_database d ON d.oid = s.dbid
JOIN targets t ON t.datname = d.datname
GROUP BY d.datname, s.userid
ORDER BY d.datname, calls DESC;
