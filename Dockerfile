# syntax=docker/dockerfile:1.7
FROM python:3.11-slim-bookworm

ARG HERMES_REF=main

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_NO_CONFIG=1 \
    HERMES_HOME=/root/.hermes \
    HERMES_INSTALL_DIR=/opt/hermes-agent \
    PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        ripgrep \
        tini \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

RUN git clone --branch ${HERMES_REF} --depth 1 \
        https://github.com/NousResearch/hermes-agent.git ${HERMES_INSTALL_DIR}
WORKDIR ${HERMES_INSTALL_DIR}
RUN uv venv .venv --python 3.11 \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python -e . \
 && ln -s ${HERMES_INSTALL_DIR}/.venv/bin/hermes /usr/local/bin/hermes

RUN mkdir -p ${HERMES_HOME}

COPY hermes-data/   ${HERMES_HOME}/
COPY entrypoint.sh  /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
