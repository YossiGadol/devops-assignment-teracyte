#!/bin/bash

START_TIME=$(date +%s)
PROD_DB_NAME="working_example_prod"
PROD_DB_HOST="we-mysql.cluster.us-east-2.rds.amazonaws.com"
PROD_DB_PASS="DB_PASS"
PROD_DB_PASS="DB_USER"

cd /working_example-mysql || exit 1
rm -f production-cleaned.sql
mysqldump \
-h 255.255.255.255 -u user -ppass dbname \
--ignore-views=true \
> production-cleaned.sql


mysql -h "$PROD_DB_HOST" -u "$PROD_DB_USER" -p"$PROD_DB_PASS" "$PROD_DB_NAME" -e "show tables;" | grep -v Tables_in_working_example | xargs -I {} mysql -h "$PROD_DB_HOST" -u "$PROD_DB_USER" -p"$PROD_DB_PASS" "$PROD_DB_NAME" -e "drop table if exists {};"
mysql -h "$PROD_DB_HOST" -u "$PROD_DB_USER" -p"$PROD_DB_PASS" "$PROD_DB_NAME" < production-cleaned.sql
echo

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n\nCompleted %02d:%02d minutes.\n\n" $MINUTES $SECONDS
