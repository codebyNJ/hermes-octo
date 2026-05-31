# Hermes Second Brain

This repo packages [Hermes Agent](https://github.com/NousResearch/hermes-agent) (the open-source agent runtime from Nous Research) into a single Docker container that runs on Hugging Face Spaces' free tier, with a Postgres database on Neon for state. It exposes an OpenAI-compatible HTTP API.

Hermes Agent on its own is a runtime — you still have to give it a memory backend, a model provider, a deployment target, and a way to keep tools and skills available. This repo is the wiring that does all of that.

---

## What this repo adds on top of Hermes Agent

The upstream `hermes-agent` repo gives you the runtime and CLI. 

| Layer | What we did |
|---|---|
| **Persistent memory** | Built a self-hosted [Honcho](https://github.com/plastic-labs/honcho) (api + deriver) into the same container. Hermes points at `127.0.0.1:8000` via [honcho-config.json](honcho-config.json). Both processes share the container's Python toolchain. |
| **Database** | Used [Neon](https://neon.com) for Postgres + pgvector. [entrypoint.sh](entrypoint.sh) normalizes the connection URL to `postgresql+psycopg://`, forces IPv4 (`gssencmode=disable` — HF Spaces has no IPv6), runs `CREATE EXTENSION IF NOT EXISTS vector;`, then runs Honcho's Alembic migrations. |
| **Process management** | Wrote [supervisord.conf](supervisord.conf) to run four programs in one container with restart-on-crash and stdout streamed to HF's log viewer. |
| **Provider fallback chain** | Replaced the default single-provider config with a chain in [hermes-data/config.yaml](hermes-data/config.yaml): OpenRouter (4 free models) → Z.AI GLM-4.7-Flash → local model. Hermes' built-in retry/fallback machinery walks the chain on rate limits or auth errors. |
| **Local last-resort model** | Added a fourth process: a CPU-only `llama-cpp-python` server running [Hermes-3-Llama-3.2-3B (Q4_0)](https://huggingface.co/NousResearch/Hermes-3-Llama-3.2-3B-GGUF) bound to `127.0.0.1:8080`. Used as the bottom of the fallback chain so the API still responds even if every cloud provider fails. Chat format set to `chatml-function-calling` for tool-call compatibility. |
| **Skills as files** | Added a `hermes-data/skills/` directory baked into the container at build time. Each skill is a markdown file the agent can load on demand (`hireme`, `gtm-research`, `understand-repo`, etc.). Skills are toggled via `skills.enabled: true` in config. |
| **MCP servers** | Configured the GitHub MCP server to always run; left specialist servers (Exa, GitMCP, Context7, Yahoo Finance) defined-but-disabled to keep the free-model tool budget small. |
| **Web search & extract** | Set `web.search_backend: exa` and `extract_backend: exa` so the agent can hit Exa's API directly (no separate MCP needed). |
| **Tool budget trimming** | Disabled toolsets the free models don't need (cronjob, delegation, spotify, discord, computer_use, image_gen, video_gen, browser, code_execution, debugging, messaging) — every enabled tool's definition is injected into the system prompt each turn, which burns context. |
| **Deployment surface** | Single Dockerfile, builds in ~10 minutes on HF Spaces. No CI/CD config required — `git push` to the Space rebuilds. |
| **Persona / identity** | Baked `hermes-data/SOUL.md` and `hermes-data/memories/USER.md` into the image as the agent's starting context — replaces a generic system prompt with a personal one. |

The original Hermes Agent code itself is **not modified**. We clone it at image build time and pin to `main` (or any commit you set via `ARG HERMES_REF`).

---

## What's in the running container

`tini` is PID 1, runs `supervisord`, which runs four programs:

| Program | Port | Reachable | Purpose |
|---|---|---|---|
| `hermes-gateway` | 7860 | public | The Hermes CLI's `gateway` subcommand. OpenAI-compatible `/v1/*`. |
| `honcho-api` | 8000 | localhost only | Honcho's FastAPI server, run via `uvicorn src.main:app`. |
| `honcho-deriver` | — | — | Honcho's background worker, `python -m src.deriver`. |
| `llama-server` | 8080 | localhost only | `llama-cpp-python[server]` hosting `Hermes-3-Llama-3.2-3B.Q4_0.gguf`. |

State (memory, embeddings, conversation history) lives in Neon. The container disk is treated as ephemeral.

---

## Files in this repo

```
.
├── Dockerfile                  Builds Python 3.11 image. Clones hermes-agent + honcho.
│                               Installs llama-cpp-python (CPU wheel). Downloads the
│                               Hermes-3-3B GGUF. ~10 min cold build.
├── supervisord.conf            Four-program config. Logs to /dev/fd/1.
├── entrypoint.sh               Env validation → DB URL normalization → pgvector check
│                               → Alembic migrations → exec supervisord.
├── honcho-config.json          Hermes → local Honcho wiring. Cadence tuned `low` to
│                               minimize Postgres compute-hour usage on Neon free tier.
├── hermes-data/                Baked into /root/.hermes inside the container.
│   ├── config.yaml             Provider chain, MCP servers, skills toggle, disabled toolsets.
│   ├── SOUL.md                 Agent persona.
│   ├── memories/USER.md        Build-time user context (Nijeesh).
│   └── skills/                 Markdown skill playbooks (eng, gtm, personal).
└── .env.example                Documents required + optional environment variables.
```

---

## Provider chain (current)

Defined in [hermes-data/config.yaml:23-35](hermes-data/config.yaml#L23-L35):

```
1. OpenRouter — nvidia/nemotron-3-super-120b-a12b:free    (primary)
2. OpenRouter — poolside/laguna-m.1:free
3. OpenRouter — openai/gpt-oss-120b:free
4. OpenRouter — google/gemma-4-31b-it:free
5. Z.AI       — glm-4.7-flash
6. Local      — hermes-3-llama-3.2-3b
```

Behavior:
- HTTP 429 (rate-limited) or 401 (auth) on any entry → skip to the next.
- HTTP 400 → skip (Hermes treats this as non-retryable for that provider).
- First successful response wins.
- Each provider's API key comes from a named env var (`OPENROUTER_API_KEY`, `ZAI_API_KEY`, etc.) via the `custom_providers` block.

---

## Deploy

### 1. Required environment values

| Variable | Source |
|---|---|
| `API_SERVER_KEY` | `openssl rand -hex 32` — bearer token your clients send. |
| `DATABASE_URL` | Neon dashboard → Connection string. Use the **direct** (not pooled) URL, with `sslmode=require` and no `channel_binding` param. |
| `OPENROUTER_API_KEY` | openrouter.ai/keys |

Optional but recommended: `GROQ_API_KEY`, `ZAI_API_KEY`, `EXA_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`, `API_SERVER_CORS_ORIGINS`.

### 2. Neon setup

Create a project at [console.neon.tech](https://console.neon.tech). Region: US East (closest to HF Spaces' default). The pgvector extension is enabled by `entrypoint.sh` on first boot — no manual SQL.

### 3. Hugging Face Space

[huggingface.co/new-space](https://huggingface.co/new-space) → SDK: Docker → Blank template. Push this repo to the Space's git remote, or link a GitHub repo for auto-rebuild on push.

```bash
git remote add hf https://huggingface.co/spaces/<username>/hermes
git push hf main
```

First build ≈ 5–10 minutes.

### 4. Add secrets

Space → Settings → Variables and secrets → add each as a **Secret** (hidden from logs, unlike Variables).

### 5. Keep it warm

HF Spaces sleeps after ~48 h idle. UptimeRobot HTTPS monitor on `/health` every 5 minutes keeps it awake.

---

## Verify

```bash
curl https://<username>-hermes.hf.space/health

curl -H "Authorization: Bearer $API_SERVER_KEY" \
     https://<username>-hermes.hf.space/v1/models

curl https://<username>-hermes.hf.space/v1/chat/completions \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nvidia/nemotron-3-super-120b-a12b:free",
    "messages": [{"role": "user", "content": "hi"}]
  }'
```

---

## Constraints we accepted

- **HF Spaces sleep after ~48 h idle.** Mitigated by UptimeRobot pings.
- **Neon free tier: 0.5 GB storage, 100 CU-hr/month.** Honcho cadence tuned `low` in honcho-config.json to stay within budget.
- **Local model on 2 CPU is slow.** Several seconds per token. Acceptable because it's only the last-resort fallback.
- **No custom domain on HF free tier.** Use `<username>-hermes.hf.space` directly, or front it with a Cloudflare redirect rule for browser traffic.
- **No browser/Playwright, no ffmpeg, no Node-side audio tools.** Image is intentionally lean.
- **Image size grew from ~1 GB to ~3 GB** when the local Hermes-3-3B model was added (Q4_0 weights are ~2 GB).

---

## Pinning versions

[Dockerfile](Dockerfile) clones with `ARG HERMES_REF=main` and `ARG HONCHO_REF=main`. To pin a specific commit, set them at build time. HF Spaces rebuilds automatically on every push.

---

## Detailed walkthrough

[ARCHITECTURE.MD](ARCHITECTURE.MD) — request lifecycle, memory flow, file layout, network diagram.
[AGENTS.md](AGENTS.md) — internal notes for working on this repo with an AI agent.
