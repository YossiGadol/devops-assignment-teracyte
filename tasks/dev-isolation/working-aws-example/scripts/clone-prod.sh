#!/bin/bash

START_TIME=$(date +%s)
PROD_DB_NAME="working_example_prod"
PROD_DB_HOST="we-mysql.cluster.us-east-2.rds.amazonaws.com"
PROD_DB_PASS="DB_PASS"
PROD_DB_PASS="DB_USER"

cd /working_example-mysql || exit 1
rm -f working_example-mysql.sql
mysqldump -h "$PROD_DB_HOST" -u "$PROD_DB_USER" -p"$PROD_DB_PASS" "$PROD_DB_NAME" > working_example-mysql.sql


END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n\nCompleted %02d:%02d minutes.\n\n" $MINUTES $SECONDS
