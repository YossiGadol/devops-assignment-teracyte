#!/bin/bash
# Usage: ./start.sh [--build]
# Starts the containers.
#   --build  Rebuild the image even if it already exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x ./*.sh

BUILD=false
for arg in "$@"; do
  case "$arg" in
    --build) BUILD=true ;;
  esac
done

if [ "$BUILD" = true ]; then
  echo "Building Docker image 'api-image' (--build specified)..."
  "$SCRIPT_DIR/build.sh"
  docker compose down
elif ! docker image inspect api-image >/dev/null 2>&1; then
  echo "Docker image 'api-image' not found. Building..."
  "$SCRIPT_DIR/build.sh"
fi

docker compose up -d
