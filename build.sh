#!/bin/bash

docker buildx build \
  --provenance=true \
  --sbom=true \
  --no-cache \
  -t api-image .