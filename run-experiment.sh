#!/bin/bash
# Usage: ./run-experiment.sh [experiment-id]
# Runs the local pipeline for the given experiment (default: demo-local).
set -euo pipefail

EXPERIMENT_ID="${1:-demo-local}"

docker exec -t teracyte-api sh -c "uv run python -m scripts.run_local --experiment-id $EXPERIMENT_ID" | jq .