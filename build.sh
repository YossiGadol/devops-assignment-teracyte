#!/bin/bash
# Usage: ./build.sh
# Builds the shared image 'api-image' (API, worker, analysis steps and the training environment).
#   BUILD_ATTESTATIONS=false  skip SBOM/provenance (the default 'docker' buildx driver used by
#                             CI runners cannot always attach attestations in the build process)
#   BUILD_NO_CACHE=false      allow layer cache (CI)
set -euo pipefail

args=(-t api-image --load)
if [[ "${BUILD_ATTESTATIONS:-true}" == true ]]; then
  args+=(--provenance=true --sbom=true)
fi
if [[ "${BUILD_NO_CACHE:-true}" == true ]]; then
  args+=(--no-cache)
fi

docker buildx build "${args[@]}" .
