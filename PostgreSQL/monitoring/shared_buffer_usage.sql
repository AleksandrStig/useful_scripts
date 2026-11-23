SHOW shared_buffers;

-- used total
SELECT buffers_used,
       buffers_unused,
       buffers_dirty,
       pg_size_pretty(buffers_used * current_setting('block_size')::int) AS used
FROM pg_buffercache_summary();

-- used by DBs
SELECT coalesce(d.datname, 'shared') AS db,
       count(*) FILTER (WHERE b.relfilenode IS NOT NULL) AS buffers,
       pg_size_pretty(count(*) FILTER (WHERE b.relfilenode IS NOT NULL)
                      * current_setting('block_size')::int) AS size
FROM pg_buffercache b
LEFT JOIN pg_database d ON d.oid = b.reldatabase
GROUP BY 1
ORDER BY buffers DESC;

-- used by objects in current DB
SELECT n.nspname, c.relname,
       count(*) AS buffers,
       pg_size_pretty(count(*) * current_setting('block_size')::int) AS size
FROM pg_buffercache b
JOIN pg_class c ON c.relfilenode = b.relfilenode
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE b.reldatabase = (SELECT oid FROM pg_database WHERE datname = current_database())
GROUP BY 1, 2
ORDER BY buffers DESC
LIMIT 30;
