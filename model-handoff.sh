#!/bin/bash
# Usage: ./model-handoff.sh <train|publish|accept|promote|rollback|resolve|status> [options]
# Runs the model handoff CLI (python -m model_handoff) inside the api container, which is
# also the portable training image. The registry is the data-model-registry volume.
#   ./model-handoff.sh train   --run-dir data/model-lifecycle/runs/<run>
#   ./model-handoff.sh publish --run-dir data/model-lifecycle/runs/<run> --version 1.0.0
#   ./model-handoff.sh accept  --version 1.0.0 [--expected-sha256 HEX]   # exit 1 = REJECTED
#   ./model-handoff.sh promote --version 1.0.0 --reason "..."
#   ./model-handoff.sh rollback [--to-version 1.0.0]
#   ./model-handoff.sh status | resolve
set -euo pipefail
# Git Bash on Windows rewrites /app/... arguments into C:/Program Files/Git/app/...; no-op elsewhere.
export MSYS_NO_PATHCONV=1

GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
docker exec -e GIT_COMMIT="$GIT_COMMIT" -e PROMOTED_BY="${PROMOTED_BY:-${USER:-${USERNAME:-unknown}}}" \
  teracyte-api uv run python -m model_handoff "$@"
