---
title: Hermes
emoji: 🧠
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# Hermes + Honcho on HF Spaces + Neon

Self-hosted personal second brain. **₹0/month, no credit card.** [Hermes Agent](https://github.com/NousResearch/hermes-agent) + self-hosted [Honcho](https://github.com/plastic-labs/honcho) run in one HF Spaces Docker container (2 vCPU, 16 GB RAM), backed by [Neon's](https://neon.com) free serverless Postgres with pgvector. Memory persists across restarts because all state lives in Neon, not container disk.

See [ARCHITECTURE.MD](ARCHITECTURE.MD) and [PRD.MD](PRD.MD) for the why.

## What's running

One HF Spaces container, three supervisord-managed processes, one Neon database:

| Process | Where | Port | Public? |
| --- | --- | --- | --- |
| `hermes gateway` | HF Spaces container | `7860` | yes (`/v1/*` + `/health`) |
| `honcho api` | HF Spaces container | `8000` | no (localhost) |
| `honcho deriver` | HF Spaces container | — | no |
| Postgres + pgvector | Neon (separate) | — | no (only the container connects) |

Three secrets power everything:
- `API_SERVER_KEY` — bearer token clients must send
- `GROQ_API_KEY` — Hermes inference + Honcho deriver reasoning (one key, two consumers)
- `DATABASE_URL` — Neon Postgres connection string

## Repo layout

```
.
├── Dockerfile               Single image. Clones Hermes + Honcho at build, installs both.
├── supervisord.conf         3 processes: honcho-api, honcho-deriver, hermes-gateway.
├── entrypoint.sh            Validates env, normalizes DATABASE_URL, enables pgvector, exec supervisord.
├── honcho-config.json       Tells Hermes to talk to the local Honcho on 127.0.0.1:8000.
├── hermes-data/
│   └── config.yaml          Baked-in Hermes config (Groq provider, Honcho enabled).
├── .env.example             Variables you set in HF Space settings.
└── ARCHITECTURE.MD, PRD.MD
```

## Deploy

### 1. Get the three secrets

| Secret | Where | Card? |
|---|---|---|
| `API_SERVER_KEY` | `openssl rand -hex 32` or any random 64-char hex | — |
| `GROQ_API_KEY` | https://console.groq.com | No |
| `DATABASE_URL` | https://console.neon.tech (next step) | No |

### 2. Create a Neon project (Postgres + pgvector)

1. Sign up at https://console.neon.tech (GitHub/Google OAuth, no card)
2. Create a project — pick **US East** region (closest to HF Spaces default)
3. From the project Dashboard, copy the **Connection string**
   - Format: `postgresql://<user>:<pass>@<host>/<db>?sslmode=require`
   - Drop `channel_binding=require` if present — keep only `sslmode=require`
4. pgvector is enabled automatically by the container on first boot.

### 3. Create the HF Space

1. https://huggingface.co/new-space
2. **SDK: Docker** → **Blank** template
3. Name it `hermes` (your Space URL will be `https://<username>-hermes.hf.space`)
4. Visibility: **Public** (or Private if you want, but Public is fine since the API requires a bearer token)
5. **Create Space**

### 4. Push to the HF Space repo

```bash
# Clone the HF Space repo (replace <username> with your HF username)
git remote add hf https://huggingface.co/spaces/<username>/hermes

# Push
git push hf main
```

Or link directly: in HF Space Settings → **Linked GitHub Repo** → connect your GitHub repo for auto-deploy on push.

First build takes ~5–10 minutes (cloning Hermes + Honcho, installing both venvs).

### 5. Add secrets in HF Space settings

Space Settings → **Variables and secrets** → add these as **Secrets** (not variables — secrets are hidden from logs):

| Secret name | Value |
|---|---|
| `API_SERVER_KEY` | your generated key |
| `GROQ_API_KEY` | `gsk_...` |
| `DATABASE_URL` | `postgresql://...neon.tech/...?sslmode=require` |
| `API_SERVER_CORS_ORIGINS` | `https://<username>-hermes.hf.space` |
| `CACHE_ENABLED` | `false` |

### 6. Keep it awake (optional but recommended)

HF Spaces sleep after ~48 h of inactivity. Set up UptimeRobot:
1. https://uptimerobot.com — free signup, no card
2. **Add New Monitor**
   - Type: HTTPS
   - URL: `https://<username>-hermes.hf.space/health`
   - Interval: 5 minutes

## Custom domain

HF Spaces free tier uses `https://<username>-hermes.hf.space`. Custom domain support requires HF Pro ($9/mo).

**Cloudflare redirect workaround** (browser traffic only):
```
Cloudflare DNS → nijeeshnj.tech
  Rules → Redirect → hermes.nijeeshnj.tech/* → https://<username>-hermes.hf.space/$1
```

For API access from OpenCode/Aider, use `https://<username>-hermes.hf.space/v1` directly.

## Verify

```bash
curl https://<username>-hermes.hf.space/health
# {"status":"ok"}

curl -H "Authorization: Bearer $API_SERVER_KEY" \
     https://<username>-hermes.hf.space/v1/models
```

## Use it

Any OpenAI-compatible client:

```bash
curl https://<username>-hermes.hf.space/v1/chat/completions \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.3-70b-versatile",
    "messages": [{"role": "user", "content": "hello"}]
  }'
```

OpenCode, Open WebUI, TypingMind — point at `https://<username>-hermes.hf.space/v1` with the bearer token.

## Known constraints

- **HF Spaces sleep after ~48 h idle.** UptimeRobot pings every 5 min keep it awake.
- **No custom domain on free tier.** Use `<username>-hermes.hf.space` or a Cloudflare redirect rule.
- **Neon free: 0.5 GB storage, 100 compute-hours/month.** `honcho-config.json` is tuned `contextCadence: low` to stay within budget.
- **Cold start ~30–60 s** after a forced sleep. UptimeRobot mitigates this.
- **No browser/audio tools** (no Playwright/Chromium/ffmpeg) — lean image.

## Updating Hermes / Honcho versions

[Dockerfile](Dockerfile) pins both to `main`. To pin a specific commit, change `ARG HERMES_REF=main` / `ARG HONCHO_REF=main` and push — HF rebuilds automatically.

## If you outgrow this

When HF Spaces sleep or Neon's CU-hour cap gets in the way:
- **Oracle Cloud Always-Free** — 24 GB ARM VM, always-on. Card required for ID verification only (no charges). Move the whole stack onto one VM.
