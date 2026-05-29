# AGENTS.md — Hermes Second Brain Deployment

This repo deploys a personal "second brain" agent on Hugging Face Spaces free tier, backed by Neon Postgres.

## What this is

A single Docker container running four supervisord-managed processes:
- `hermes-gateway` — public OpenAI-compatible API on port 7860
- `honcho-api` — local memory backend on 127.0.0.1:8000
- `honcho-deriver` — async memory worker
- `llama-server` — local LLM (xLAM-1b-fc-r) as last-resort fallback on 127.0.0.1:8080

State (memory, embeddings, conversation history) lives in **Neon Postgres**, NOT the container disk. Container is ephemeral.

## Key files

- [Dockerfile](Dockerfile) — builds the image (Python 3.11, Hermes + Honcho + llama-cpp-python + xLAM-1b GGUF)
- [supervisord.conf](supervisord.conf) — process definitions
- [entrypoint.sh](entrypoint.sh) — env validation, DB URL normalization, pgvector init, alembic migrations, exec supervisord
- [honcho-config.json](honcho-config.json) — Hermes → local Honcho wiring (pinned peerName=nijeesh, global session)
- [hermes-data/config.yaml](hermes-data/config.yaml) — Hermes config (provider chain, toolsets, agent settings)
- [hermes-data/SOUL.md](hermes-data/SOUL.md), [USER.md](hermes-data/memories/USER.md), [MEMORY.md](hermes-data/memories/MEMORY.md) — agent personality + user profile
- [.env.example](.env.example) — documents secrets (NEVER put real values here)

## Provider fallback chain

Defined in `hermes-data/config.yaml` under `fallback_providers`:
1. Z.AI GLM-4.7-Flash (primary, 50 RPD free)
2. Groq Llama 3.3 70B (14,400 RPD)
3. Gemini 2.0 Flash (1,500 RPD)
4. Gemini 1.5 Flash (1,500 RPD)
5. OpenRouter Llama 3.3 70B free
6. Local xLAM-1b-fc-r (unlimited, slow)

## Deploy commands

- Build & deploy: just `git push` — HF Space auto-rebuilds from linked repo
- Logs: HF Space → Logs tab (all 4 processes stream to stdout via `/dev/fd/1`)
- Restart: HF Space → Settings → Factory rebuild

## Secrets (HF Space → Settings → Variables and secrets)

Required: `API_SERVER_KEY`, `DATABASE_URL`, `GROQ_API_KEY`.
Optional but recommended: `ZAI_API_KEY`, `GEMINI_API_KEY`, `OPENROUTER_API_KEY`.
NEVER commit real values to `.env.example`.

## Known pitfalls (learned the hard way)

- **Neon pooler URLs reject SQLAlchemy startup params.** Use the **direct** connection string (no `-pooler` in hostname). Drop `channel_binding=require` too — keep only `sslmode=require`.
- **HF Spaces has no IPv6.** `entrypoint.sh` forces IPv4 by appending `gssencmode=disable`.
- **Honcho API isn't a script — it's a server.** Must start with `uvicorn src.main:app`, NOT `python -m src.main`.
- **xLAM is NOT a Functionary model.** Use `--chat_format chatml-function-calling`, not `functionary-v2`.
- **n_ctx 4096 is too small** for Hermes' system-prompt + tool-defs. Use ≥ 8192.
- **HF Space web editor lets you accidentally paste into the wrong file.** If Dockerfile build error mentions `[supervisord]`, the files were swapped — re-push from local.

## Testing

```bash
# Health
curl https://<username>-hermes-octo.hf.space/health

# Auth + chat (replace API_SERVER_KEY)
curl https://<username>-hermes-octo.hf.space/v1/chat/completions \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"glm-4.7-flash","messages":[{"role":"user","content":"hi"}]}'
```

## When editing this repo

- Edit `hermes-data/*.md` to refine agent personality — these are baked into the image at build time
- Changes to `Dockerfile` trigger a full rebuild (~10 min)
- Changes to `supervisord.conf` / `entrypoint.sh` also rebuild
- Changes to `hermes-data/config.yaml` rebuild but model weights are cached
