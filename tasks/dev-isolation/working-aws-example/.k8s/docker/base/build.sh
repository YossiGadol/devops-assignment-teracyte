#!/bin/bash
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 999999999999.dkr.ecr.us-east-2.amazonaws.com
docker buildx build \
--platform=linux/amd64 \
--provenance=true \
--sbom=true \
--no-cache \
--pull \
--push \
-t 999999999999.dkr.ecr.us-east-2.amazonaws.com/working_example/python-backend:base-uv .