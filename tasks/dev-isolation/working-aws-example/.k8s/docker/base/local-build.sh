docker buildx build \
  --platform=linux/amd64 \
  --provenance=true \
  --sbom=true \
  --no-cache \
  --pull \
  --builder=desktop-linux \
  -t 999999999999.dkr.ecr.us-east-2.amazonaws.com/working_example/python-backend:base .
