# Hermes + Honcho on Railway

Self-hosted personal second brain deployed to Railway from this GitHub repo. [Hermes Agent](https://github.com/NousResearch/hermes-agent) exposes an OpenAI-compatible API; [Honcho](https://github.com/plastic-labs/honcho) gives it long-term memory. Both run in one container, fronted by Cloudflare at a subdomain of your portfolio.

See [ARCHITECTURE.MD](ARCHITECTURE.MD) and [PRD.MD](PRD.MD) for the why.

## What's in the container

One Docker image with three processes managed by supervisord:

| Process | Port | Public? | Purpose |
| --- | --- | --- | --- |
| `hermes gateway` | `$PORT` | yes | OpenAI-compatible `/v1/*` + `/health` |
| `honcho api` | `8000` | no (localhost) | Memory backend Hermes talks to |
| `honcho deriver` | — | no | Background worker that builds the user model |

Postgres (with pgvector) lives outside the container as a Railway add-on. No Redis — Honcho runs with `CACHE_ENABLED=false`.

Only one external API is used: **Groq**. The same `GROQ_API_KEY` powers both Hermes' inference and Honcho's deriver.

## Repo layout

```
.
├── Dockerfile               Single image. Clones Hermes + Honcho at build, installs both.
├── supervisord.conf         3 processes: honcho-api, honcho-deriver, hermes-gateway.
├── entrypoint.sh            Binds Hermes to $PORT, waits for Postgres, enables pgvector.
├── railway.toml             Railway build + healthcheck config.
├── honcho-config.json       Tells Hermes to talk to the local Honcho on 127.0.0.1:8000.
├── hermes-data/
│   └── config.yaml          Baked-in Hermes config (Groq provider, Honcho enabled).
├── .env.example             Variables you need to set in Railway.
└── ARCHITECTURE.MD, PRD.MD
```

There is no local dev / WSL2 setup required — everything builds inside the Railway container.

## Deploy

### 1. Push this repo to GitHub

```bash
git init
git add .
git commit -m "initial deploy"
git remote add origin git@github.com:<you>/hermes.git
git push -u origin main
```

### 2. Create the Railway project from the GitHub repo

```bash
railway login
railway init             # pick "Deploy from GitHub repo", select your repo
railway link             # link this local folder so subsequent CLI calls target it
```

### 3. Attach Postgres (with pgvector)

```bash
railway add --database postgres
```

This provisions a Postgres service and injects `DATABASE_URL` into your app service. The `entrypoint.sh` script runs `CREATE EXTENSION IF NOT EXISTS vector;` on every boot, so pgvector is enabled automatically — no manual SQL needed.

### 4. Set environment variables

```bash
railway variables \
  --set API_SERVER_KEY=$(openssl rand -hex 32) \
  --set API_SERVER_CORS_ORIGINS=https://hermes.nijeeshnj.tech \
  --set GROQ_API_KEY=gsk_...
```

`DATABASE_URL` is auto-injected by the Postgres add-on — do not set it manually.

### 5. Deploy

```bash
railway up
```

Railway reads [railway.toml](railway.toml), builds from the [Dockerfile](Dockerfile), and hits `/health` for liveness.

### 6. Expose via your portfolio subdomain

1. In Railway dashboard → your service → Settings → Networking → **Generate domain**. You'll get `<something>.up.railway.app`.
2. In Cloudflare (the DNS for `nijeeshnj.tech`), add:

   ```
   Type:   CNAME
   Name:   hermes
   Target: <something>.up.railway.app
   Proxy:  ON  (orange cloud)
   ```

3. (Optional but recommended) Railway → Settings → Networking → Custom domain → add `hermes.nijeeshnj.tech` so Railway issues a matching cert and avoids edge SSL loops.

## Verify

```bash
railway logs                              # stream live container logs

curl https://hermes.nijeeshnj.tech/health
# {"status":"ok"}

curl -H "Authorization: Bearer $API_SERVER_KEY" \
     https://hermes.nijeeshnj.tech/v1/models
```

## Use it

Any OpenAI-compatible client works:

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

- **Cost is not ₹0.** Railway killed the free hobby tier in 2024. Expect ~$5/month on the Hobby plan once the trial credit runs out.
- **RAM is tight.** Hermes + Honcho api + Honcho deriver in one 512MB container is borderline. If you see OOM kills in `railway logs`, split Honcho into its own Railway service.
- **No Redis.** `CACHE_ENABLED=false` skips it. If Honcho's deriver crash-loops or throughput becomes a bottleneck, add a Railway Redis service and flip `CACHE_ENABLED=true` + `CACHE_URL=...`.
- **No pgvector size cap.** Honcho doesn't expose a TTL knob today. If the Postgres add-on approaches its storage quota, prune `messages` / `embeddings` tables manually.
- **Hermes' browser/audio tools are not installed** (no Playwright/Chromium/ffmpeg) — keeps the image lean. Web fetch via plain HTTP still works.
- **`config.yaml` is committed in [hermes-data/](hermes-data/)**. If you ever want to change the model, system prompt, or persona (`SOUL.md`), edit it in-repo and `railway up` again.

## Updating Hermes / Honcho versions

The Dockerfile pins both projects to `main` via `--depth 1`. To pin to a specific commit or tag, change the `ARG HERMES_REF=main` / `ARG HONCHO_REF=main` lines in [Dockerfile](Dockerfile) and redeploy.
