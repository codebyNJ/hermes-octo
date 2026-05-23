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

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "[entrypoint] FATAL: DATABASE_URL is not set (attach a Railway Postgres add-on)" >&2
  exit 1
fi

if [[ -z "${GROQ_API_KEY:-}" ]]; then
  echo "[entrypoint] FATAL: GROQ_API_KEY is not set" >&2
  exit 1
fi
export LLM_GROQ_API_KEY="${LLM_GROQ_API_KEY:-$GROQ_API_KEY}"

normalize_pg_url() {
  local url="$1"
  if [[ "$url" == postgres://* ]]; then
    echo "postgresql+psycopg://${url#postgres://}"
  elif [[ "$url" == postgresql://* && "$url" != postgresql+*://* ]]; then
    echo "postgresql+psycopg://${url#postgresql://}"
  else
    echo "$url"
  fi
}

export DB_CONNECTION_URI="$(normalize_pg_url "${DATABASE_URL}")"
export CACHE_ENABLED="${CACHE_ENABLED:-false}"

/opt/honcho/.venv/bin/python - <<'PY'
import os, sys, time
import psycopg

dsn = os.environ["DATABASE_URL"]
for attempt in range(30):
    try:
        with psycopg.connect(dsn, connect_timeout=5, autocommit=True) as conn:
            conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        print("[entrypoint] pgvector extension verified", flush=True)
        sys.exit(0)
    except Exception as exc:
        print(f"[entrypoint] postgres not ready ({attempt+1}/30): {exc}", flush=True)
        time.sleep(2)
print("[entrypoint] FATAL: could not connect to postgres", file=sys.stderr)
sys.exit(1)
PY

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/hermes.conf
