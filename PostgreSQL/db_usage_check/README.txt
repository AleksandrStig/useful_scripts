FLORA DB USAGE CHECK (simple)
=============================
Набор независимых SQL-запросов: используются ли БД flora-*-prod.
Каждый файл самостоятельный: один запрос, описание в шапке.
Запросы только читают, ничего не меняют, XID не тратят.
Список БД задаётся в начале файла в блоке  WITH targets(datname) AS (VALUES ...).
Запускать можно в psql, DBeaver и любом другом клиенте.

ФАЙЛЫ
01_connections_now.sql     кто подключён сейчас, сводка        | разово или \watch 60
02_sessions_detail.sql     каждая сессия детально              | разово
03_db_stats.sql            счётчики pg_stat_database           | раз в сутки, сравнивать разницу
04_xid_age.sql             XID кластера, age(datfrozenxid)     | раз в сутки
05_xmin_holders.sql        кто держит xmin                     | разово или \watch 300
06_replication_slots.sql   логические слоты (Debezium/CDC)     | раз в сутки, на мастере
07_connect_privileges.sql  кто может CONNECT                   | разово
08_pg_stat_statements.sql  запросы по ролям                    | разово, в БД с расширением
09_table_stats.sql         запись и сканы по таблицам          | ВНУТРИ каждой БД, сравнивать
10_table_last_read.sql     последнее чтение таблиц (PG16+)     | ВНУТРИ каждой БД

ЗАПУСК (пример)
  psql -X -h <host> -U <user> -d postgres -f 03_db_stats.sql
  psql -X -h <host> -U <user> -d flora-communications-prod -f 09_table_stats.sql

ЧТО УЧЕСТЬ
- Истории коннектов в PG нет. Для неё: log_connections = on и логи сервера.
- Счётчики (03, 08, 09) копятся с момента stats_reset или рестарта. Смотри разницу между запусками.
- XID общий на кластер: age(datfrozenxid) не доказывает, что БД используют.
- Активность могут давать мониторинг, бэкапы и pgbouncer. Отфильтровывай по usename.
- Проверь и реплики: приложение может читать только с них.
- Твой коннект к целевой БД (09, 10) увеличивает sessions в 03.

ИСТОЧНИКИ
https://www.postgresql.org/docs/current/monitoring-stats.html
https://www.postgresql.org/docs/current/routine-vacuuming.html#VACUUM-FOR-WRAPAROUND
https://www.postgresql.org/docs/current/runtime-config-logging.html
https://www.postgresql.org/docs/current/view-pg-replication-slots.html
https://www.postgresql.org/docs/current/pgstatstatements.html
https://www.postgresql.org/docs/current/app-psql.html  (\watch)
