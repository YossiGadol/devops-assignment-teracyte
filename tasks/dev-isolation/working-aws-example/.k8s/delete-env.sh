#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <search_string>"
  exit 1
fi

SEARCH="$1"
RESOURCE_TYPES=(
  service deployment configmap secret ingresse job cronjob
)
DB_NAME=${SEARCH//-/_}

helm uninstall spin-test-env-"$SEARCH" -n "$SEARCH" --ignore-not-found --kube-context=arn:aws:eks:us-east-2:999999999999:cluster/working_example-test

for TYPE in "${RESOURCE_TYPES[@]}"; do
  kubectl get "$TYPE" --context=arn:aws:eks:us-east-2:999999999999:cluster/working_example-test -A -o jsonpath='{range .items[*]}{.metadata.namespace}:{.metadata.name}{"\n"}{end}' 2>/dev/null | \
  grep "$SEARCH" | while read -r line; do
    kubectl delete "$TYPE" --context=arn:aws:eks:us-east-2:999999999999:cluster/working_example-test -n "${line%%:*}" "${line##*:}" --ignore-not-found --now
  done
done

mysql -e "drop database if exists $DB_NAME;"
psql postgresql://"$PG_USERNAME":"$PG_PASSWORD"@"$PG_HOST":"$PG_PORT" -c "drop database if exists vector_$DB_NAME with (force);"