/*
 07_connect_privileges.sql
 ЧТО: какие LOGIN-роли в принципе могут подключиться (CONNECT) к целевым БД.
      Это список «подозреваемых». Пригодится и для scream test: сохрани вывод,
      чтобы потом откатить REVOKE CONNECT через GRANT.
 ГДЕ: в любой БД кластера.
 КАК: разово.
*/
WITH targets(datname) AS (VALUES
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name'),
    ('your_db_name')
)
SELECT d.datname,
       pg_get_userbyid(d.datdba)          AS db_owner,
       d.datacl                           AS db_acl,
       r.rolname,
       r.rolsuper,
       r.rolconnlimit,
       r.rolvaliduntil
FROM pg_database d
JOIN targets t ON t.datname = d.datname
CROSS JOIN pg_roles r
WHERE r.rolcanlogin
  AND has_database_privilege(r.oid, d.oid, 'CONNECT')
ORDER BY d.datname, r.rolname;
