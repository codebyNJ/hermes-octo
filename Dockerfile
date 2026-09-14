# syntax=docker/dockerfile:1.7
FROM python:3.11-slim-bookworm

ARG HERMES_REF=main
ARG HONCHO_REF=main

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_NO_CONFIG=1 \
    HERMES_HOME=/root/.hermes \
    HERMES_INSTALL_DIR=/opt/hermes-agent \
    HONCHO_INSTALL_DIR=/opt/honcho \
    PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gcc \
        libpq-dev \
        ripgrep \
        supervisor \
        tini \
        xz-utils \
        ffmpeg \
        gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

RUN git clone --branch ${HERMES_REF} --depth 1 \
        https://github.com/NousResearch/hermes-agent.git ${HERMES_INSTALL_DIR}
WORKDIR ${HERMES_INSTALL_DIR}
RUN uv venv .venv --python 3.11 \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python -e . \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python websockets \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python aiohttp \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python mcp \
 && uv pip install --python ${HERMES_INSTALL_DIR}/.venv/bin/python "honcho-ai==2.2.0" \
 && ln -s ${HERMES_INSTALL_DIR}/.venv/bin/hermes /usr/local/bin/hermes

RUN git clone --branch ${HONCHO_REF} --depth 1 \
        https://github.com/plastic-labs/honcho.git ${HONCHO_INSTALL_DIR}
WORKDIR ${HONCHO_INSTALL_DIR}
RUN uv sync --no-dev

# Local LLM fallback: NousResearch Hermes-3-Llama-3.2-3B (Q4_0, ChatML + tool use, ~2GB)
# Use prebuilt CPU wheel to skip C++ compilation (no g++ needed in image)
# Local EMBEDDING server (OpenAI-compatible /v1/embeddings via llama-cpp-python).
# OpenRouter has no embeddings endpoint, so Honcho's semantic search runs on this
# local nomic-embed model (768-dim). Replaces the old unused Hermes-3 chat GGUF.
ENV LLAMA_SERVER_DIR=/opt/llama-server \
    EMBED_MODEL_PATH=/opt/models/nomic-embed-text-v1.5.Q4_K_M.gguf
RUN mkdir -p ${LLAMA_SERVER_DIR} /opt/models \
 && uv venv ${LLAMA_SERVER_DIR}/.venv --python 3.11 \
 && uv pip install --python ${LLAMA_SERVER_DIR}/.venv/bin/python \
        --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu \
        "llama-cpp-python[server]" \
 && curl -fL --connect-timeout 10 -o ${EMBED_MODEL_PATH} \
        https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.Q4_K_M.gguf \
 && test -s ${EMBED_MODEL_PATH} && ls -lh ${EMBED_MODEL_PATH}

RUN mkdir -p ${HERMES_HOME} \
             /root/.honcho \
             /var/log/hermes \
             /var/log/honcho \
             /etc/supervisor/conf.d

COPY honcho-config.json /root/.honcho/config.json
COPY supervisord.conf   /etc/supervisor/conf.d/hermes.conf
COPY entrypoint.sh      /usr/local/bin/entrypoint.sh
COPY hermes-data/       ${HERMES_HOME}/

# Config validation gate: hermes-data drives provider routing but has no
# runtime schema check, so cross-file drift (provider chain, memory toggles,
# enabled MCPs vs skill requirements) shipped undetected. Fail the build on
# tests/test_hermes_data_config.py — mirror the repo layout so the suite's
# ROOT-relative paths resolve. Dedicated venv so no runtime venv is touched.
COPY tests/ /opt/hermes-data-check/tests/
COPY hermes-data/ /opt/hermes-data-check/hermes-data/
RUN uv venv /opt/hermes-data-check/.venv --python 3.11 \
 && uv pip install --python /opt/hermes-data-check/.venv/bin/python -q pyyaml \
 && /opt/hermes-data-check/.venv/bin/python /opt/hermes-data-check/tests/test_hermes_data_config.py \
 && rm -rf /opt/hermes-data-check

RUN chmod +x /usr/local/bin/entrypoint.sh

# Playwright MCP browser: install the EXACT chromium build @playwright/mcp expects,
# into the DEFAULT cache (/root/.cache/ms-playwright) where the MCP subprocess looks
# (it does not inherit a custom PLAYWRIGHT_BROWSERS_PATH). Version-pinned so the
# baked browser revision matches the MCP the agent runs. --with-deps adds the OS
# libs chromium needs. Adds ~1GB.
RUN npm install -g @playwright/mcp@0.0.79 \
 && CORE=$(find "$(npm root -g)" -path "*playwright-core/cli.js" | head -1) \
 && node "$CORE" install --with-deps chromium

RUN apt-get purge -y --auto-remove gcc \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
