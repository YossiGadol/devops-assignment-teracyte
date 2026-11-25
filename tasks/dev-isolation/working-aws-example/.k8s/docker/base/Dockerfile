FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get -y install git openssh-client build-essential net-tools procps iputils* traceroute nano curl telnet supervisor sqlite3 python3-psycopg2 unzip curl wget
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN chmod +x /uv-installer.sh && /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"
ENV PIP_ROOT_USER_ACTION=ignore
RUN uv python install 3.13
RUN apt-get update
RUN apt-get -y install git openssh-client build-essential net-tools procps iputils* traceroute nano curl telnet supervisor sqlite3 python3-psycopg2 unzip
RUN curl -fsSL https://deno.land/install.sh | sh
ENV PATH="/root/.deno/bin:$PATH"
RUN ln -s /root/.deno/bin/deno /usr/local/bin/deno
RUN apt-get -y autoremove && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
COPY ./pyproject.toml pyproject.toml
RUN uv sync --no-dev
WORKDIR /app
