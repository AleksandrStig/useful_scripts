#!/bin/bash

# Connection settings (each row must be corrrect) 
HOST="hostname"
PORT="5432"
USER="user_name"
SQL_FILE="/path/to/file/file.sql"
LOG_FILE="/path/to/log/curdb_log_$(date +%Y%m%d).log"
PGPASSWORD="*****"
STARTDB="name_of_the_first_db_in_cluster"

# Exclude database (optional) 
EXCLUDE_DBS="template0,template1,postgres"

echo "Start: $(date)" | tee -a "$LOG_FILE"
echo "host: $HOST, port: $PORT, user: $USER" | tee -a "$LOG_FILE"
echo "SQL file: $SQL_FILE" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Get databases list
DATABASES=$(psql -h $HOST -p $PORT -U $USER -d $STARTDB -t -c "
SELECT datname
FROM pg_database
WHERE datistemplate = false
AND datname NOT IN ('$EXCLUDE_DBS')
ORDER BY datname;")

# Check file exists 
if [ ! -f "$SQL_FILE" ]; then
    echo "ERROR: file $SQL_FILE not exists!" | tee -a "$LOG_FILE"
    exit 1
fi

# Run query in each database and log output 
for DB in $DATABASES; do
    echo "Database: $DB" | tee -a "$LOG_FILE"
    echo "Start: $(date '+%H:%M:%S')" | tee -a "$LOG_FILE"

    if PGPASSWORD=$PGPASSWORD psql -h $HOST -p $PORT -U $USER -d "$DB" -f "$SQL_FILE" >> "$LOG_FILE" 2>&1; then
        echo "✅ Ok: $DB completed" | tee -a "$LOG_FILE"
    else
        echo "❌ ERROR: $DB" | tee -a "$LOG_FILE"
    fi

    echo "Finish: $(date '+%H:%M:%S')" | tee -a "$LOG_FILE"
    echo "------------------------------------------" | tee -a "$LOG_FILE"

    # pause between databases (optional)
    # sleep 1
done

echo "File was executed in databases: $(date)" | tee -a "$LOG_FILE"
echo "See log file: $LOG_FILE" | tee -a "$LOG_FILE"
