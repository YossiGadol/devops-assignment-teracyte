#!/bin/bash
cd /working_example-pg || exit 1
rm -f ./*.dump
START_TIME=$(date +%s)
sources=(
    "working_example-postgres-vector-dev.99999999999.us-east-2.rds.amazonaws.com|postgres|rVkXzTD8XxntVWrbZT6y|sb_dev"
)
stmt_source="select datname \
from pg_catalog.pg_database d \
where datistemplate = false \
  and datallowconn = true \
  and datname not in ('template0', 'template1', 'rdsadmin') \
order by datname;"

stmt_dest="select datname \
from pg_catalog.pg_database d \
where datistemplate = false \
  and datallowconn = true \
  and datname not in ('postgres', 'sb_prod', 'template0', 'template1', 'rdsadmin') \
order by datname;"

TARGET_HOST=we-postgres.cluster.us-east-2.rds.amazonaws.com
TARGET_USER=postgres
TARGET_PASSWORD=pMpB5zSqxNvqdpYAnE3b

PGPASSWORD=$TARGET_PASSWORD psql -h $TARGET_HOST -U $TARGET_USER -c "$stmt_dest" -t | while read -r line; do
    TARGET_DB_TO_DROP=$(echo "$line" | xargs)
    if [ -n "$TARGET_DB_TO_DROP" ]; then
      printf "\n\e[31mDropping target database: %s\e[0m\n" "$TARGET_DB_TO_DROP"
      PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "alter database $TARGET_DB_TO_DROP owner to postgres;"
      PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "drop database if exists $TARGET_DB_TO_DROP with (force);"
    fi
done

for source in "${sources[@]}"; do
    IFS='|' read -r SOURCE_PG_HOST SOURCE_PG_USER SOURCE_PG_PASSWORD SOURCE_PG_ALIAS <<< "$source"
    printf "\n\e[1;32mProcessing %s\e[0m\n" "$SOURCE_PG_HOST"

    PGPASSWORD=$SOURCE_PG_PASSWORD psql -h "$SOURCE_PG_HOST" -U "$SOURCE_PG_USER" -c "$stmt_source" -t | while read -r line; do
        SOURCE_PG_DB_TO_DUMP=$(echo "$line" | xargs)
        if [ -n "$SOURCE_PG_DB_TO_DUMP" ]; then
          if [[ "$SOURCE_PG_DB_TO_DUMP" == "working_example_vector" || "$SOURCE_PG_DB_TO_DUMP" == "postgres" ]]; then
            TARGET_DB="$SOURCE_PG_ALIAS"
          else
            TARGET_DB="$SOURCE_PG_DB_TO_DUMP"
          fi
          printf "\n\e[33mCreating target database if needed: %s\e[0m\n" "$TARGET_DB"
          PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB'" | grep -q 1 || PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "create database $TARGET_DB with template template0;"
          printf "\n\e[33mDumping source database: %s\e[0m\n" "$SOURCE_PG_DB_TO_DUMP"
          if [ "$SOURCE_PG_DB_TO_DUMP" == "postgres" ]; then
            PGPASSWORD=$SOURCE_PG_PASSWORD pg_dump -t '*checkpoint*' -h "$SOURCE_PG_HOST" -U "$SOURCE_PG_USER" "$SOURCE_PG_DB_TO_DUMP" > "${SOURCE_PG_ALIAS}_${SOURCE_PG_DB_TO_DUMP}_backup.dump"
          else
            PGPASSWORD=$SOURCE_PG_PASSWORD pg_dump -h "$SOURCE_PG_HOST" -U "$SOURCE_PG_USER" "$SOURCE_PG_DB_TO_DUMP" > "${SOURCE_PG_ALIAS}_${SOURCE_PG_DB_TO_DUMP}_backup.dump"
          fi
          printf "\n\e[33mImporting source database: %s\e[0m\n" "$SOURCE_PG_DB_TO_DUMP"
          PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -d "$TARGET_DB"  -f "${SOURCE_PG_ALIAS}_${SOURCE_PG_DB_TO_DUMP}_backup.dump"
          PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "alter database $TARGET_DB owner to working_example_vector;"
        fi
    done
done

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n\nCompleted %02d:%02d minutes.\n\n" $MINUTES $SECONDS


