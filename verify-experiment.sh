#!/bin/bash
# Usage: ./verify-experiment.sh [--timeout SECONDS] [--expected-model-sha256 HEX] [--experiment-id ID]
# Runs the analysis for a fresh experiment inside the api container and verifies the
# results in PostgreSQL and MongoDB (tests/e2e_verify.py). Exits nonzero on failure:
#   1 wrong results, 2 analysis failed, 3 timeout, 4 setup error.
# MODEL_SELECTION_FILE (container path) selects a promoted model; it overrides the Compose value.
# Requires the stack to be up (./start.sh) with an image that contains the current code.
set -euo pipefail
# Git Bash on Windows rewrites /app/... arguments into C:/Program Files/Git/app/...; no-op elsewhere.
export MSYS_NO_PATHCONV=1

# No -t: works without a TTY (CI) and the exit status of the verifier is propagated.
docker exec ${MODEL_SELECTION_FILE+-e MODEL_SELECTION_FILE="$MODEL_SELECTION_FILE"} \
  teracyte-api uv run python -m tests.e2e_verify "$@"
