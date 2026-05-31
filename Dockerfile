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
 && ln -s ${HERMES_INSTALL_DIR}/.venv/bin/hermes /usr/local/bin/hermes

RUN git clone --branch ${HONCHO_REF} --depth 1 \
        https://github.com/plastic-labs/honcho.git ${HONCHO_INSTALL_DIR}
WORKDIR ${HONCHO_INSTALL_DIR}
RUN uv sync --no-dev

# Local LLM fallback: NousResearch Hermes-3-Llama-3.2-3B (Q4_0, ChatML + tool use, ~2GB)
# Use prebuilt CPU wheel to skip C++ compilation (no g++ needed in image)
ENV LLAMA_SERVER_DIR=/opt/llama-server \
    LLAMA_MODEL_PATH=/opt/models/Hermes-3-Llama-3.2-3B.Q4_0.gguf
RUN mkdir -p ${LLAMA_SERVER_DIR} /opt/models \
 && uv venv ${LLAMA_SERVER_DIR}/.venv --python 3.11 \
 && uv pip install --python ${LLAMA_SERVER_DIR}/.venv/bin/python \
        --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu \
        "llama-cpp-python[server]" \
 && curl -fL --connect-timeout 10 -o ${LLAMA_MODEL_PATH} \
        https://huggingface.co/NousResearch/Hermes-3-Llama-3.2-3B-GGUF/resolve/main/Hermes-3-Llama-3.2-3B.Q4_0.gguf \
        || echo "⚠️  Model download failed (fallback disabled, cloud providers will be used)" \
 && if test -s ${LLAMA_MODEL_PATH}; then ls -lh ${LLAMA_MODEL_PATH}; fi

RUN mkdir -p ${HERMES_HOME} \
             /root/.honcho \
             /var/log/hermes \
             /var/log/honcho \
             /etc/supervisor/conf.d

COPY honcho-config.json /root/.honcho/config.json
COPY supervisord.conf   /etc/supervisor/conf.d/hermes.conf
COPY entrypoint.sh      /usr/local/bin/entrypoint.sh
COPY hermes-data/       ${HERMES_HOME}/

RUN chmod +x /usr/local/bin/entrypoint.sh

RUN apt-get purge -y --auto-remove gcc \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
