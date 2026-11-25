#!/bin/bash
# Usage: ./verify-experiment.sh [--timeout SECONDS] [--expected-model-sha256 HEX] [--experiment-id ID]
# Runs the analysis for a fresh experiment inside the api container and verifies the
# results in PostgreSQL and MongoDB (tests/e2e_verify.py). Exits nonzero on failure:
#   1 wrong results, 2 analysis failed, 3 timeout, 4 setup error.
# Requires the stack to be up (./start.sh) with an image that contains the current code.
set -euo pipefail

# No -t: works without a TTY (CI) and the exit status of the verifier is propagated.
docker exec teracyte-api uv run python -m tests.e2e_verify "$@"
