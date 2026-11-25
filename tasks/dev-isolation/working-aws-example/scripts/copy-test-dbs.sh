#!/bin/bash

START_TIME=$(date +%s)
SOURCE_HOST="working_example-mysql.cluster.us-east-2.rds.amazonaws.com"

dbs=$(mysql -h "$SOURCE_HOST" -e "show databases;" | grep -E 'test_|evaluat')
for db in $dbs; do
    printf "\n\e[1;32mDeleteing DB: %s\e[0m\n" "$db"
    mysql -e "drop database if exists $db;"
    mysql -e "create database $db;"
    mysqldump -h "$SOURCE_HOST" --disable-keys "$db" | mysql "$db"
done


END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n\nCompleted %02d:%02d minutes.\n\n" $MINUTES $SECONDS
