/*
 10_table_last_read.sql
 ЧТО: когда таблицы ТЕКУЩЕЙ БД последний раз читали (seq scan / index scan).
      Это лучший способ понять, читают ли БД вообще.
 ГДЕ: ВНУТРИ проверяемой БД, по очереди в каждой:
        psql -X -d flora-communications-prod -f 10_table_last_read.sql
 КАК: разово.
 ВЕРСИЯ: только PG16+ (колонки last_seq_scan / last_idx_scan).
 ВАЖНО: pg_dump тоже делает seq scan и «освежает» last_seq_scan.
      Если время совпадает с окном бэкапа, скорее всего это бэкап, а не приложение.
*/
SELECT current_database()                         AS datname,
       schemaname || '.' || relname               AS table_name,
       greatest(last_seq_scan, last_idx_scan)     AS last_read,
       last_seq_scan,
       last_idx_scan,
       seq_scan,
       idx_scan
FROM pg_stat_user_tables
ORDER BY last_read DESC NULLS LAST
LIMIT 50;
