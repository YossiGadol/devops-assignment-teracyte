#!/bin/bash
set -e
TARGET_HOST=we-postgres.cluster.us-east-2.rds.amazonaws.com
TARGET_USER=user
TARGET_PASSWORD=password
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}
branches=$(git branch -r | grep 'origin/test/' | sed 's|origin/||')
for branch in $branches; do
    printf "\n\e[1;32mRedeploying branch: %s\e[0m\n" "$branch"
    env_name=$(slugify "${branch}")
    db_name=${env_name//-/_}
    result=$(mysql -e "use $db_name;" || echo 1)
    if [[ $result -eq 0 ]]; then
        echo "Database $db_name already exists."
    else
        echo "Creating database $db_name..."
        echo "create database $db_name default character set utf8mb4 collate utf8mb4_unicode_ci default encryption = 'N';"
        mysql -e "create database $db_name default character set utf8mb4 collate utf8mb4_unicode_ci default encryption = 'N';"
        mysql "$db_name" </working_example-mysql/working_example-mysql.sql
        mysql -e "grant all privileges on $db_name.* to 'working_example'@'%';"
    fi
    PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "create database vector_${db_name};"
    PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "create database conninfo_${db_name};"
    PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "alter database $db_name owner to working_example_vector;"
    PGPASSWORD=$TARGET_PASSWORD psql -X -q -h $TARGET_HOST -U $TARGET_USER -c "alter database conninfo_${db_name} owner to working_example_vector;"
done
echo "All databases have been recreated for test branches."
