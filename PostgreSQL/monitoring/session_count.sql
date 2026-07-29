-- How much sessions is in different state
SELECT 
    state,
    count(*) as session_count,
    round(
        100.0 * count(*) / 
        (SELECT count(*) 
         FROM pg_stat_activity 
         WHERE datname = current_database()), 
        2
    ) as percentage
FROM 
    pg_stat_activity
WHERE 
    datname = current_database()
GROUP BY 
    state
ORDER BY 
    session_count DESC;
