#!/usr/bin/env bash
set -euo pipefail

: "${PORT:=8642}"
export API_SERVER_ENABLED="${API_SERVER_ENABLED:-true}"
export API_SERVER_HOST="${API_SERVER_HOST:-0.0.0.0}"
export API_SERVER_PORT="${PORT}"

if [[ -z "${API_SERVER_KEY:-}" ]]; then
  echo "[entrypoint] FATAL: API_SERVER_KEY is not set" >&2
  exit 1
fi

if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "[entrypoint] FATAL: GROQ_API_KEY is not set" >&2
  exit 1
fi

if [[ -z "${HONCHO_API_KEY:-}" ]]; then
  echo "[entrypoint] WARN: HONCHO_API_KEY is not set — memory will be disabled" >&2
fi

exec /usr/local/bin/hermes gateway
