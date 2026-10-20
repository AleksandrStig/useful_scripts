-- указать наименование целевого пользователя
\set target_role 'bi-change-readwrite'
-- Получить наименование владельца БД 
WITH db_owner AS (
    SELECT r.rolname 
    FROM pg_database d 
    JOIN pg_roles r ON d.datdba = r.oid 
    WHERE d.datname = current_database()
)
-- Выдать права на существующие объекты
SELECT 'GRANT USAGE ON SCHEMA "' || n.nspname || '" TO "' || :'target_role' || '";'
FROM pg_namespace n
WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname NOT LIKE 'information%'

UNION ALL

SELECT 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA "' || n.nspname || '" TO "' || :'target_role' || '";'
FROM pg_namespace n
WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname NOT LIKE 'information%'

UNION ALL

SELECT 'GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA "' || n.nspname || '" TO "' || :'target_role' || '";'
FROM pg_namespace n
WHERE n.nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
  AND n.nspname NOT LIKE 'pg_%'
  AND n.nspname NOT LIKE 'information%'

UNION ALL
-- Выдать права по умолчанию (на вновь создаваемые объекты)
SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE "' || (SELECT rolname FROM db_owner) || '" GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "' || :'target_role' || '";'

UNION ALL

SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE "' || (SELECT rolname FROM db_owner) || '" GRANT USAGE, SELECT ON SEQUENCES TO "' || :'target_role' || '";'

UNION ALL

SELECT 'ALTER DEFAULT PRIVILEGES FOR ROLE "' || (SELECT rolname FROM db_owner) || '" GRANT USAGE ON SCHEMAS TO "' || :'target_role' || '";'

UNION ALL
-- CREATE 
SELECT 'GRANT CREATE ON DATABASE "' || (SELECT current_database()) || '" TO "' || :'target_role' || '";'

ORDER BY 1 \gexec

