#!/bin/bash
# Usage: ./show-results.sh [experiment-id]
# Shows the results for the given experiment (default: demo-local).
set -euo pipefail

EXPERIMENT_ID="${1:-demo-local}"

docker exec -t teracyte-api sh -c "curl localhost:8000/experiments/$EXPERIMENT_ID/results" | jq .