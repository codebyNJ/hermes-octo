# Hermes on Koyeb + cloud Honcho

Self-hosted personal second brain — deployed for **₹0/month with no credit card**. [Hermes Agent](https://github.com/NousResearch/hermes-agent) runs as a single-process container on Koyeb's free tier; memory is delegated to [Honcho's hosted cloud](https://honcho.dev) free tier.

See [ARCHITECTURE.MD](ARCHITECTURE.MD) and [PRD.MD](PRD.MD) for the why.

## What's in the container

One Docker image, one process:

| Process | Port | Public? | Purpose |
| --- | --- | --- | --- |
| `hermes gateway` | `$PORT` | yes | OpenAI-compatible `/v1/*` + `/health` |

Honcho lives outside the container as a cloud service. Hermes talks to it over HTTPS using `HONCHO_API_KEY`. There's no Postgres, no Redis, no supervisord — the brain is one container plus two API keys.

## Repo layout

```
.
├── Dockerfile               Single-stage. Clones Hermes at build, installs core only.
├── entrypoint.sh            Binds Hermes to $PORT, validates env, execs `hermes gateway`.
├── hermes-data/
│   └── config.yaml          Baked-in Hermes config (Groq provider, Honcho enabled).
├── .env.example             Variables you need to set in Koyeb.
└── ARCHITECTURE.MD, PRD.MD
```

## Deploy

### 1. Get the three secrets

| Secret | Where |
|---|---|
| `API_SERVER_KEY` | `openssl rand -hex 32` (any random string) |
| `GROQ_API_KEY` | https://console.groq.com — free, no card |
| `HONCHO_API_KEY` | https://honcho.dev — free tier, no card |

### 2. Push to GitHub

```bash
git init
git add .
git commit -m "initial deploy"
git remote add origin git@github.com:<you>/hermes.git
git push -u origin main
```

### 3. Create the Koyeb service

Two options — dashboard is quicker the first time, CLI is reproducible.

**Dashboard:**
1. https://app.koyeb.com/services/new
2. Source → **GitHub** → pick your repo
3. Builder → **Dockerfile** (auto-detected)
4. Instance type → **Free** (Eco/Free Web)
5. Environment variables → add all four from `.env.example`
6. Health checks → HTTP `GET /health` on port `8000` (Koyeb's default `$PORT`)
7. Deploy

**CLI:**
```bash
curl -fsSL https://raw.githubusercontent.com/koyeb/koyeb-cli/master/install.sh | bash
koyeb login
koyeb service create hermes \
  --git github.com/<you>/hermes \
  --git-branch main \
  --git-builder docker \
  --instance-type free \
  --regions fra \
  --ports 8000:http \
  --routes /:8000 \
  --checks 8000:http:/health \
  --env API_SERVER_KEY=@API_SERVER_KEY \
  --env GROQ_API_KEY=@GROQ_API_KEY \
  --env HONCHO_API_KEY=@HONCHO_API_KEY \
  --env API_SERVER_CORS_ORIGINS=https://hermes.nijeeshnj.tech
```

(The `@NAME` syntax pulls a secret you've previously created with `koyeb secret create NAME --value ...`.)

### 4. Expose via your portfolio subdomain

1. Koyeb dashboard → service → Settings → **Domains** → add `hermes.nijeeshnj.tech`.
2. Cloudflare DNS for `nijeeshnj.tech`:
   ```
   Type:   CNAME
   Name:   hermes
   Target: <app>-<org>.koyeb.app
   Proxy:  ON  (orange cloud)
   ```
3. Koyeb auto-issues a Let's Encrypt cert. Cloudflare handles edge SSL.

## Verify

```bash
koyeb service logs hermes --follow      # stream live container logs

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

## Updates

Push to `main` → Koyeb rebuilds and rolls out automatically. To pin Hermes to a specific commit, change `ARG HERMES_REF=main` in [Dockerfile](Dockerfile) and push.

## Known constraints (Koyeb free + Honcho cloud)

- **Koyeb free tier: 512MB / 0.1 vCPU, single instance, no autoscale.** Plenty for personal single-user use. If Hermes gets sluggish under load, the bottleneck is the CPU quota, not RAM.
- **Honcho cloud free tier limits apply.** Check honcho.dev for current quotas. If you hit them, the agent still works — it just stops getting smarter that month.
- **No persistent disk in the container.** All long-term state lives in Honcho cloud. Anything written to the local filesystem is lost on redeploy.
- **No browser/audio tools installed** (no Playwright/Chromium/ffmpeg). Web fetch via plain HTTP still works.
- **Single region.** Pick one near you (`fra`, `was`, `sin`) when creating the service.

## Switching providers later

The container is Hermes-only — provider-agnostic. To swap LLM:
- Edit `hermes-data/config.yaml` (model, base_url, key_env)
- Add a new `LLM_*_API_KEY` env var to Koyeb if needed
- Push

To self-host Honcho later (Postgres + Redis), `git log` the older Railway-era commits in this repo — that scaffolding lived here briefly.
