FROM ghcr.io/astral-sh/uv:python3.15-trixie-slim
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y curl jq
WORKDIR /app
COPY . /app
RUN uv init --bare
RUN uv add -r requirements-local.txt