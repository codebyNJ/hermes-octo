# Architecture — Personal Second Brain (Hermes + self-hosted Honcho on Render + Neon)
**Owner:** Nijeesh NJ
**Version:** 4.0
**Last Updated:** May 2026

---

## 1. System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        ACCESS LAYER                          │
│                                                              │
│   Browser (laptop / phone)        OpenAI-compatible clients  │
│   hermes.nijeeshnj.tech  ──┐  ┌── (OpenCode, Open WebUI,     │
│                            │  │   TypingMind, curl, etc.)    │
└────────────────────────────┼──┼──────────────────────────────┘
                             │  │  HTTPS
┌────────────────────────────┼──┼──────────────────────────────┐
│                   CLOUDFLARE (free)                          │
│                            │  │                              │
│   CNAME hermes.nijeeshnj.tech → <hash>.onrender.com          │
│   SSL termination · DDoS protection                          │
└────────────────────────────┼──┼──────────────────────────────┘
                             │  │
┌────────────────────────────┼──┼──────────────────────────────┐
│               RENDER FREE TIER  (Docker web service)         │
│                            │  │                              │
│   ┌────────────────────────▼──▼─────────────────────────┐    │
│   │           container  (this Dockerfile)              │    │
│   │           512 MB RAM · 0.1 vCPU                     │    │
│   │           sleeps after 15 min idle                  │    │
│   │           tini → supervisord                        │    │
│   │                                                     │    │
│   │      hermes gateway   :$PORT     ◄── public         │    │
│   │           │                                         │    │
│   │           │ HTTP loopback                           │    │
│   │           ▼                                         │    │
│   │      honcho api       :8000     ◄── localhost only  │    │
│   │      honcho deriver   (worker)                      │    │
│   │           │                                         │    │
│   └───────────┼─────────────────────────────────────────┘    │
└───────────────┼──────────────────────────────────────────────┘
                │ DATABASE_URL (sslmode=require)
                ▼
┌────────────────────────────────────────────────┐
│  NEON  (serverless Postgres, free tier)        │
│                                                │
│  Postgres + pgvector                           │
│  0.5 GB storage · 100 CU-hr/mo                 │
│  auto-suspends idle, sub-second cold start     │
└────────────────────────────────────────────────┘

UptimeRobot (free)  →  pings /health every 5 min  →  keeps Render warm
```

---

## 2. Components

### 2.1 Hermes Agent
**What it is:** Open-source agent runtime by Nous Research ([NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent))
**Public port:** `$PORT` (Render-assigned)
**Role:** Receives any input, reasons, calls tools, returns OpenAI-compatible responses

Exposes `/v1/chat/completions`, `/v1/models`, `/health`, `/health/detailed`. Hermes config baked into the image at [hermes-data/config.yaml](hermes-data/config.yaml); the local-Honcho wiring sits in [honcho-config.json](honcho-config.json) (copied to `/root/.honcho/config.json` at build time).

Runtime env (set as Render env vars):
```
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=$PORT
API_SERVER_KEY=<secret>
API_SERVER_CORS_ORIGINS=https://hermes.nijeeshnj.tech
GROQ_API_KEY=<secret>
DATABASE_URL=<neon-secret>
CACHE_ENABLED=false
```

**Not installed**: Node.js, Playwright/Chromium, ffmpeg, audio tools.

---

### 2.2 Honcho (self-hosted, in-container)
**What it is:** Open-source AI memory backend by Plastic Labs ([plastic-labs/honcho](https://github.com/plastic-labs/honcho))
**Internal port:** 8000 (localhost only)
**Processes:** two (`api` + `deriver`)
**Role:** Long-term memory — builds and maintains a model of Nijeesh across sessions

Hermes is told to use the local Honcho via [honcho-config.json](honcho-config.json). Cadence knobs are tuned **low** to minimize Postgres traffic and stay within Neon's 100 CU-hr/mo quota:

```json
{
  "enabled": true,
  "baseUrl": "http://127.0.0.1:8000",
  "contextCadence": "low",
  "dialecticCadence": "low",
  "dialecticReasoningLevel": "low",
  ...
}
```

Both Hermes and Honcho's deriver use the same `GROQ_API_KEY` (aliased to `LLM_GROQ_API_KEY` by [entrypoint.sh](entrypoint.sh)).

**Memory persists across redeploys** because state lives in Neon, not the container.

---

### 2.3 Neon Postgres + pgvector (external)
**Provisioned at:** https://console.neon.tech
**Connection:** `DATABASE_URL` env var; [entrypoint.sh](entrypoint.sh) normalizes it to `postgresql+psycopg://...` as Honcho expects and exports it as `DB_CONNECTION_URI`.
**Extension:** `CREATE EXTENSION IF NOT EXISTS vector;` runs on every boot — no manual SQL.

Free Neon quotas:
- 0.5 GB storage
- 100 CU-hours/project/month (≈ 400 hr at the smallest 0.25-CU shape)
- Auto-suspends idle, sub-second cold start

---

### 2.4 Supervisord
**Role:** Process manager inside the container.

```
tini (PID 1)
  └── supervisord
        ├── honcho-api        (restarts if crashes)
        ├── honcho-deriver    (restarts if crashes)
        └── hermes-gateway    (restarts if crashes)
```

Logs in `/var/log/honcho/*` and `/var/log/hermes/*`, surfaced via Render's log stream.

---

### 2.5 No Redis (deliberate)
`CACHE_ENABLED=false`. Honcho's deriver is slower but works. Trade-off accepted to avoid a third free-tier dependency.

---

### 2.6 UptimeRobot
**Role:** Keep the Render container warm.
**Endpoint pinged:** `https://hermes.nijeeshnj.tech/health` every 5 minutes.

Render's 750 free instance-hr/month is ~30 hr above 24/7 — pinging burns most of that. If you ever hit the cap, the service forced-sleeps for the rest of the month.

---

## 3. Docker Container Design

### Single-container rationale
- Hermes ↔ Honcho talk over `localhost` — no network hop, no DNS
- One Dockerfile, one log stream, one healthcheck
- Postgres is the only external dependency, and Neon manages it

### RAM budget (best estimate)
```
tini + supervisord     ~5 MB
honcho api             ~100 MB
honcho deriver         ~100 MB
hermes gateway         ~200 MB
─────────────────────────────
Total                  ~405 MB    (in a 512 MB Render free container)
```

Tight. If OOM kills appear in Render logs, split Honcho out to a second Render service.

### Container file layout
```
/opt/hermes-agent/        ← Hermes repo + .venv (built at image time)
/opt/honcho/              ← Honcho repo + .venv (built at image time)

/root/.hermes/            ← HERMES_HOME (baked from hermes-data/ in repo)
  └── config.yaml         ← Groq provider + Honcho enabled

/root/.honcho/
  └── config.json         ← tells Hermes to use the local Honcho

/etc/supervisor/conf.d/
  └── hermes.conf         ← 3 program definitions

/var/log/{hermes,honcho}/ ← rotating stdout/stderr logs
```

---

## 4. Repo Layout

```
hermes/                          ← git repo root
│
├── Dockerfile                   builds the image
├── supervisord.conf             3 programs
├── entrypoint.sh                env validation + pgvector init + supervisord exec
├── render.yaml                  Render Blueprint
├── honcho-config.json           Hermes → local-Honcho wiring (tuned cadence)
├── .env.example                 documented env vars
├── .dockerignore
├── .gitignore
│
├── hermes-data/                 baked into HERMES_HOME at build time
│   └── config.yaml              Groq provider, Honcho enabled
│
├── ARCHITECTURE.MD
├── PRD.MD
└── README.md
```

---

## 5. Deployment

### One-time setup
```bash
# 1. Push to GitHub
git init && git add . && git commit -m "initial deploy"
git remote add origin git@github.com:<you>/hermes.git
git push -u origin main

# 2. Create a Neon Postgres project (https://console.neon.tech, no card)
#    Copy the Connection string → use as DATABASE_URL

# 3. Render dashboard → Blueprints → New Blueprint Instance
#    Pick the GitHub repo. Render reads render.yaml automatically.
#    Fill in the 3 sync:false env vars in the dashboard:
#      API_SERVER_KEY=$(openssl rand -hex 32)
#      GROQ_API_KEY=gsk_...
#      DATABASE_URL=postgresql://...neon.tech/...?sslmode=require

# 4. Custom domain
#    Render → Settings → Custom Domains → add hermes.nijeeshnj.tech
#    Cloudflare DNS → CNAME hermes → <render-target>.onrender.com (proxy OFF for cert issuance)

# 5. Keep warm
#    UptimeRobot → monitor https://hermes.nijeeshnj.tech/health every 5 min
```

### Every subsequent deploy
```bash
git push                     # Render auto-rebuilds via GitHub integration
```

### Monitor
- Render dashboard → service → Logs tab (live stream + filters)
- Neon dashboard → Monitoring tab (query log, storage usage, CU-hours)
- UptimeRobot dashboard → uptime + response time history

---

## 6. Network Flow

```
Request from any OpenAI-compatible client
        │
        │ HTTPS :443 + Bearer token
        ▼
Cloudflare  (hermes.nijeeshnj.tech)
        │ proxies to Render origin
        ▼
Render ingress  →  container :$PORT
        │
        ▼
hermes gateway
        │ fetches Honcho memory context
        ▼
honcho api  (127.0.0.1:8000)
        │ reads / writes
        ▼
Neon Postgres + pgvector  (over public internet, sslmode=require)
        ▲
        │ asynchronous writes
        │
honcho deriver  ←── extracts observations, runs dialectic
        │ uses Groq for reasoning
        ▼
Groq API  (outbound HTTPS)

(Meanwhile, hermes gateway uses Groq for the chat response and streams it back to the client.)
```

---

## 7. LLM Provider

Only Groq is configured. Same `GROQ_API_KEY` consumed by:
- Hermes' chat inference (`provider: custom:groq` in [hermes-data/config.yaml](hermes-data/config.yaml))
- Honcho's deriver (`LLM_GROQ_API_KEY`, aliased from `GROQ_API_KEY` in [entrypoint.sh](entrypoint.sh))

```
Model:      llama-3.3-70b-versatile
Rate limit: 30 req/min · 6000 tokens/min · 14400 req/day  (free tier)
Latency:    200–400 ms
Cost:       $0
```

---

## 8. DNS + SSL

```
Cloudflare → nijeeshnj.tech
  Type:    CNAME
  Name:    hermes
  Target:  <hash>.onrender.com
  Proxy:   OFF first  (for Render's Let's Encrypt validation)
           ON later   (for Cloudflare DDoS / edge cache, once cert is live)
```

Render issues a free Let's Encrypt cert for the custom domain. Cloudflare handles edge SSL once you flip the proxy on.

---

## 9. Security

| Concern | Mitigation |
|---|---|
| Unauthorized API access | Bearer token (`API_SERVER_KEY`) required on `/v1/*` |
| Origin IP exposure | Cloudflare proxy hides Render URL (after cert issuance) |
| Secrets in Git | Only `.env.example` committed; real values are Render env vars |
| Honcho exposed externally | Honcho api binds `127.0.0.1:8000` — only reachable from inside the container |
| Postgres credentials | Injected via `DATABASE_URL`, sent over TLS to Neon |
| Postgres data at rest | Neon encrypts at rest |

---

## 10. Monitoring

- **Render**: dashboard → service → Logs tab. Streams live, plus historical filter.
- **Neon**: dashboard → Monitoring → CU-hours used, storage used, query log.
- **UptimeRobot**: dashboard → uptime % + response-time chart + alert history.

---

## 11. Known Limitations (v4)

| Limitation | Impact | Planned Fix |
|---|---|---|
| Render free: 15 min sleep, ~60 s cold start | First request after a forced sleep hangs | UptimeRobot pings every 5 min |
| Render free: 750 instance-hr/month | Hard cap. UptimeRobot pings eat ~720 hr. ~30 hr headroom. | If hit, forced sleep until next month |
| 512 MB container is tight for 3 processes | OOM risk under load | Split Honcho into its own Render service |
| Neon free: 100 CU-hours/project/month | Heavy Honcho deriver traffic could exhaust this | Honcho cadence tuned `low` in honcho-config.json |
| Neon free: 0.5 GB storage | Cap on memory growth | Prune old `messages` / `embeddings` rows |
| No Redis | Slower deriver throughput | Add Upstash Redis (free, no card) if needed |
| Groq rate limit (30 req/min) | Brief 429s under bursts | Add Gemini fallback later |
| Single-region deploy | Latency from outside Oregon (or whatever you pick) | Acceptable for personal use |

---

## 12. Tech Stack

| Layer | Technology | Cost | Card? |
|---|---|---|---|
| Agent runtime | Hermes Agent (Nous Research) | Free / OSS | — |
| Memory | Honcho (Plastic Labs) | Free / OSS | — |
| Database | Neon Postgres + pgvector | Free tier | No |
| LLM provider | Groq (Llama 3.3 70B) | Free tier | No |
| Process manager | Supervisord + tini | Free / OSS | — |
| Container | Docker | Free / OSS | — |
| Hosting | Render free tier | Free | No |
| DNS + SSL | Cloudflare | Free | No |
| Uptime monitor | UptimeRobot | Free | No |
| Domain | nijeeshnj.tech | Already owned | — |
| **Total** | | **₹0 / month** | **No** |
