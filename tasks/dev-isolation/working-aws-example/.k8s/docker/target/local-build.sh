#!/bin/bash
aws --profile working_example ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 999999999999.dkr.ecr.us-east-2.amazonaws.com
branch="$(git branch --show-current)" || "${GITHUB_REF_NAME}"
revision="$(git rev-parse --short HEAD)" || "${GITHUB_SHA}"
{ [ "$branch" = "master" ] || [ "$branch" = "main" ]; } && target_env="staging-uv" || target_env="${branch}-uv"
docker buildx build \
  --platform=linux/amd64 \
  --provenance=true \
  --sbom=true \
  --pull \
  --no-cache \
  --builder=desktop-linux \
  --build-arg GIT_REV="${revision}" \
  -t 999999999999.dkr.ecr.us-east-2.amazonaws.com/working_example/python-backend:"${target_env}" \
  -f Dockerfile "$(git rev-parse --show-toplevel)"
