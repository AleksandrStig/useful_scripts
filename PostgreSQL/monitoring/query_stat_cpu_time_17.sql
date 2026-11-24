SELECT
    d.datname AS db,
    q.queryid,
    round((100 * cpu / sum(cpu) OVER ())::numeric)::int AS cpu_pct,
    round(cpu::numeric)::bigint AS cpu_ms,
    round((cpu / calls)::numeric, 1) AS avg_ms,
    round(io::numeric)::bigint AS io_ms,
    calls,
    left(regexp_replace(query, '\s+', ' ', 'g'), 70) AS query
FROM (
    SELECT
        dbid,
        queryid,
        query,
        sum(calls) AS calls,
        sum(total_exec_time
            - shared_blk_read_time - shared_blk_write_time
            - local_blk_read_time - local_blk_write_time
            - temp_blk_read_time - temp_blk_write_time) AS cpu,
        sum(shared_blk_read_time + shared_blk_write_time
            + local_blk_read_time + local_blk_write_time
            + temp_blk_read_time + temp_blk_write_time) AS io
    FROM pg_stat_statements
    GROUP BY dbid, queryid, query
) q
JOIN pg_database d ON d.oid = q.dbid
WHERE cpu > 0
ORDER BY cpu DESC
LIMIT 30;

-- then

SELECT query
FROM pg_stat_statements
WHERE queryid = <id>
  AND dbid = (SELECT oid FROM pg_database WHERE datname = '<db>');
