#!/bin/bash
# Usage: ./run-experiment.sh [--show] [--export] [--experiment-id experiment_id]
# Runs the local pipeline for the given experiment (default: demo-local).
#   --show    show the experiment results after the run (./show-results.sh)
#   MODEL_SELECTION_FILE=<container path> selects a promoted model (default: Compose value)
#   --export  export the experiment results after the run (./export-results.sh)
set -euo pipefail
# Git Bash on Windows rewrites /app/... arguments into C:/Program Files/Git/app/...; no-op elsewhere.
export MSYS_NO_PATHCONV=1

EXPERIMENT_ID=demo-local
EXPORT=false

COUNTER=0
for arg in "$@"; do
    COUNTER=$((COUNTER+1))
    case "$arg" in
        --export) EXPORT=true ;;
        --experiment-id)
            shift $((COUNTER))
            EXPERIMENT_ID="$1"
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Running experiment $EXPERIMENT_ID..."
docker exec -t ${MODEL_SELECTION_FILE+-e MODEL_SELECTION_FILE="$MODEL_SELECTION_FILE"} \
  teracyte-api sh -c "uv run python -m scripts.run_local --experiment-id $EXPERIMENT_ID" | jq .

if [[ "$EXPORT" == true ]]; then
  "$SCRIPT_DIR/export-results.sh" "$EXPERIMENT_ID"
fi
