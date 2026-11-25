#!/bin/bash
# Usage: ./export-results.sh [experiment-id]
# Exports the results for the given experiment (default: demo-local).
set -euo pipefail

EXPERIMENT_ID="${1:-demo-local}"

docker exec -t teracyte-api sh -c "curl -X POST localhost:8000/experiments/$EXPERIMENT_ID/exports" | jq .