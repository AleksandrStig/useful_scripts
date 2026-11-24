WITH s AS (
    SELECT
        sum(total_exec_time) AS t,
        sum(shared_blk_read_time + shared_blk_write_time
          + local_blk_read_time + local_blk_write_time
          + temp_blk_read_time + temp_blk_write_time) AS iot,
        sum(total_exec_time
          - shared_blk_read_time - shared_blk_write_time
          - local_blk_read_time - local_blk_write_time
          - temp_blk_read_time - temp_blk_write_time) AS cput,
        sum(calls) AS s,
        sum(rows) AS r
    FROM pg_stat_statements
    WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
),
_pg_stat_statements AS (
    SELECT
        query,
        sum(total_exec_time) AS total_exec_time,
        sum(shared_blk_read_time + shared_blk_write_time
          + local_blk_read_time + local_blk_write_time
          + temp_blk_read_time + temp_blk_write_time) AS io_time,
        sum(calls) AS calls,
        sum(rows) AS rows
    FROM pg_stat_statements
    WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
    GROUP BY query
)
SELECT
    (100 * total_exec_time / (SELECT t FROM s))::numeric(20,2) AS time_percent,
    (100 * io_time / (SELECT iot FROM s))::numeric(20,2) AS iotime_percent,
    (100 * (total_exec_time - io_time) / (SELECT cput FROM s))::numeric(20,2) AS cputime_percent,
    total_exec_time::numeric(20,2) AS total_exec_time,
    (total_exec_time * 1000 / calls)::numeric(20,2) AS avg_time,
    (io_time * 1000 / calls)::numeric(20,2) AS avg_io_time,
    calls,
    (100 * calls / (SELECT s FROM s))::numeric(20,2) AS calls_percent,
    rows,
    (100 * rows / (SELECT r FROM s))::numeric(20,2) AS row_percent,
    query
FROM _pg_stat_statements
WHERE (total_exec_time - io_time) / (SELECT cput FROM s) >= 0.02
UNION ALL
SELECT
    (100 * sum(total_exec_time) / (SELECT t FROM s))::numeric(20,2),
    (100 * sum(io_time) / (SELECT iot FROM s))::numeric(20,2),
    (100 * sum(total_exec_time - io_time) / (SELECT cput FROM s))::numeric(20,2),
    sum(total_exec_time)::numeric(20,2),
    (sum(total_exec_time) * 1000 / sum(calls))::numeric(10,3),
    (sum(io_time) * 1000 / sum(calls))::numeric(10,3),
    sum(calls),
    (100 * sum(calls) / (SELECT s FROM s))::numeric(20,2),
    sum(rows),
    (100 * sum(rows) / (SELECT r FROM s))::numeric(20,2),
    'other'
FROM _pg_stat_statements
WHERE (total_exec_time - io_time) / (SELECT cput FROM s) < 0.02
ORDER BY 3 DESC;
