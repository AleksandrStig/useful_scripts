/*
 04_xid_age.sql
 ЧТО: текущий XID кластера и возраст datfrozenxid/datminmxid по ВСЕМ БД
      (целевые помечены target = true).
 ГДЕ: в любой БД кластера.
 КАК: разово или раз в сутки, вместе с 03. Разница next_xid между запусками
      показывает расход XID всего кластера.
 ВАЖНО: XID общий на кластер. age(datfrozenxid) растёт от транзакций в ЛЮБОЙ БД,
      поэтому это метрика про wraparound и freeze, а не доказательство, что
      конкретную БД используют. Запрос сам XID не тратит.
 ВЕРСИЯ: PG13+ (pg_current_snapshot). На PG12 и ниже замени на
      txid_snapshot_xmax(txid_current_snapshot()).
*/
WITH targets(datname) AS (VALUES
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name')
)
SELECT now()                                         AS checked_at,
       pg_snapshot_xmax(pg_current_snapshot())       AS cluster_next_xid,
       d.datname,
       (t.datname IS NOT NULL)                       AS target,
       age(d.datfrozenxid)                           AS xid_age,
       round(100.0 * age(d.datfrozenxid)
             / current_setting('autovacuum_freeze_max_age')::bigint, 1) AS pct_of_freeze_max_age,
       round(100.0 * age(d.datfrozenxid) / 2147483647, 2)               AS pct_of_wraparound,
       mxid_age(d.datminmxid)                        AS mxid_age,
       d.datallowconn
FROM pg_database d
LEFT JOIN targets t ON t.datname = d.datname
ORDER BY target DESC, xid_age DESC;
