/*
 09_table_stats.sql
 ЧТО: статистика по таблицам ТЕКУЩЕЙ БД: вставки, обновления, удаления, сканы,
      последние vacuum/analyze. Отсортировано по объёму записи.
      Если n_tup_ins/upd/del растут между запусками, в БД пишут.
 ГДЕ: ВНУТРИ проверяемой БД (pg_stat_user_tables видит только свою БД).
      Список БД тут не нужен: запускай по очереди в каждой, например
        psql -X -d flora-communications-prod -f 09_table_stats.sql
 КАК: разово, затем повторить через период и сравнить.
 ВАЖНО: сам коннект к БД увеличивает pg_stat_database.sessions (см. 03).
*/
SELECT current_database()                  AS datname,
       now()                               AS checked_at,
       schemaname || '.' || relname        AS table_name,
       n_live_tup,
       n_tup_ins,
       n_tup_upd,
       n_tup_del,
       n_mod_since_analyze,
       seq_scan,
       idx_scan,
       last_autovacuum,
       last_vacuum,
       last_autoanalyze,
       last_analyze
FROM pg_stat_user_tables
ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC, seq_scan + coalesce(idx_scan, 0) DESC
LIMIT 50;
