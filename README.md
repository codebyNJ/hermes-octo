# Hermes + Honcho on Render + Neon

Self-hosted personal second brain. **₹0/month, no credit card.** [Hermes Agent](https://github.com/NousResearch/hermes-agent) + self-hosted [Honcho](https://github.com/plastic-labs/honcho) run in one Render free Docker container, backed by [Neon's](https://neon.com) free serverless Postgres with pgvector. Custom domain (`hermes.nijeeshnj.tech`) is fully supported.

See [ARCHITECTURE.MD](ARCHITECTURE.MD) and [PRD.MD](PRD.MD) for the why.

## What's running

One Render container, three supervisord-managed processes, one Neon database:

| Process | Where | Port | Public? |
| --- | --- | --- | --- |
| `hermes gateway` | Render container | `$PORT` | yes (`/v1/*` + `/health`) |
| `honcho api` | Render container | `8000` | no (localhost) |
| `honcho deriver` | Render container | — | no |
| Postgres + pgvector | Neon (separate) | — | no (only the Render container connects) |

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
├── render.yaml              Render Blueprint — wires the service up declaratively.
├── honcho-config.json       Tells Hermes to talk to the local Honcho on 127.0.0.1:8000.
├── hermes-data/
│   └── config.yaml          Baked-in Hermes config (Groq provider, Honcho enabled).
├── .env.example             Variables you set in Render's dashboard.
└── ARCHITECTURE.MD, PRD.MD
```

## Deploy

### 1. Get the three secrets

| Secret | Where | Card? |
|---|---|---|
| `API_SERVER_KEY` | `openssl rand -hex 32` | — |
| `GROQ_API_KEY` | https://console.groq.com | No |
| `DATABASE_URL` | https://console.neon.tech (next step) | No |

### 2. Create a Neon project (Postgres + pgvector)

1. Sign up at https://console.neon.tech (GitHub/Google OAuth, no card)
2. Create a project — pick the region closest to your Render region (Oregon if you use Render's default)
3. From the project Dashboard, copy the **Connection string** (format: `postgresql://<user>:<pass>@<host>/<db>?sslmode=require`)
4. The pgvector extension is created automatically by the container on first boot (`CREATE EXTENSION IF NOT EXISTS vector;` in [entrypoint.sh](entrypoint.sh)).

Free Neon includes 0.5 GB storage and 100 compute-hours/month per project — plenty for personal use, but see "Known constraints" for how Honcho cadence is tuned to fit this.

### 3. Push to GitHub

```bash
git init
git add .
git commit -m "initial deploy"
git remote add origin git@github.com:<you>/hermes.git
git push -u origin main
```

### 4. Deploy on Render

**Easiest path — Blueprint (uses [render.yaml](render.yaml)):**

1. https://dashboard.render.com/blueprints → **New Blueprint Instance**
2. Connect GitHub, pick the repo
3. Render reads `render.yaml` and creates the service automatically
4. When prompted, fill in the three `sync: false` env vars: `API_SERVER_KEY`, `GROQ_API_KEY`, `DATABASE_URL`
5. **Apply**

**Manual path:**

1. https://dashboard.render.com → **New** → **Web Service** → connect repo
2. Runtime: **Docker** (auto-detected)
3. Region: pick the same as your Neon project (e.g. Oregon)
4. Plan: **Free**
5. Add env vars: `API_SERVER_KEY`, `GROQ_API_KEY`, `DATABASE_URL`, `API_SERVER_CORS_ORIGINS`, `CACHE_ENABLED=false`
6. Health check path: `/health`
7. **Create Web Service**

First build takes ~5–10 minutes (cloning Hermes + Honcho, installing both venvs).

### 5. Custom domain

1. Render dashboard → service → **Settings → Custom Domains → Add Custom Domain** → `hermes.nijeeshnj.tech`
2. Render shows you a CNAME target. In Cloudflare DNS for `nijeeshnj.tech`:
   ```
   Type:   CNAME
   Name:   hermes
   Target: <render-target>.onrender.com
   Proxy:  OFF  (grey cloud — for Render's Let's Encrypt to validate)
   ```
3. Render auto-issues a Let's Encrypt cert in ~1–2 minutes.
4. (Optional) Once the cert is live, flip Cloudflare proxy back to ON if you want their DDoS/edge cache.

### 6. Keep it awake (important)

Render free services **sleep after 15 minutes of inactivity** with a ~60-second cold start. For a personal brain you actually use, that's annoying.

Set up UptimeRobot:
1. https://uptimerobot.com — free signup, no card
2. **Add New Monitor**
   - Type: HTTPS
   - URL: `https://hermes.nijeeshnj.tech/health`
   - Interval: 5 minutes
3. This consumes ~720 of your 750 free Render hours/month — barely fits. Watch the Render dashboard for hour usage in the first week.

## Verify

```bash
curl https://hermes.nijeeshnj.tech/health
# {"status":"ok"}

curl -H "Authorization: Bearer $API_SERVER_KEY" \
     https://hermes.nijeeshnj.tech/v1/models
```

## Use it

Any OpenAI-compatible client:

```bash
curl https://hermes.nijeeshnj.tech/v1/chat/completions \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama-3.3-70b-versatile",
    "messages": [{"role": "user", "content": "hello"}]
  }'
```

OpenCode, Open WebUI, TypingMind, Cursor's custom endpoint — all point at `https://hermes.nijeeshnj.tech/v1` with the bearer token.

## Known constraints

- **Render free: 512 MB RAM, sleeps after 15 min idle, 750 instance-hours/month.** UptimeRobot pings keep it awake but eat ~720 hr/mo — you have ~30 hr/mo of headroom. If you hit it, the service forced-sleeps for the rest of the month.
- **Neon free: 0.5 GB storage, 100 compute-hours/month per project.** Honcho's deriver is chatty — `honcho-config.json` is tuned to `contextCadence: low`, `dialecticCadence: low`, `dialecticReasoningLevel: low` to minimize Postgres traffic. If you hit the CU-hour cap, memory queries pause until next month.
- **RAM is tight.** Hermes (~200 MB) + Honcho api (~100 MB) + Honcho deriver (~100 MB) ≈ 400 MB in a 512 MB container. If you see OOM kills in Render logs, the cleanest workaround is splitting Honcho out to a second Render service.
- **No Redis.** `CACHE_ENABLED=false`. Honcho's deriver is slower without it but works. If throughput becomes a bottleneck, add a free Redis (e.g. Upstash free tier, no card) and flip the flag.
- **Cold start ~60 s.** The first request after a forced sleep will hang for a minute. UptimeRobot mitigates this for the warmth-budget you have.
- **No browser/audio tools** (no Playwright/Chromium/ffmpeg) — kept lean to fit RAM.

## Updating Hermes / Honcho versions

[Dockerfile](Dockerfile) pins both projects to `main`. To pin to a specific commit/tag, change `ARG HERMES_REF=main` / `ARG HONCHO_REF=main` and push — Render auto-rebuilds.

## If you outgrow this

When Render's sleep or Neon's CU-hour cap gets in the way:
- **Oracle Cloud Always-Free** — 24 GB ARM VM, always-on, never expires. Card required for ID verification only (no charges). Move the whole stack onto one VM via docker-compose and stop juggling free tiers.
