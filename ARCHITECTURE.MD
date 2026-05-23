# Architecture — Personal Second Brain (Hermes + cloud Honcho)
**Owner:** Nijeesh NJ
**Version:** 2.0
**Last Updated:** May 2026

---

## 1. System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        ACCESS LAYER                          │
│                                                              │
│   Browser (laptop / phone)        OpenAI-compatible clients  │
│   hermes.nijeeshnj.tech ──┐  ┌──  (OpenCode, Open WebUI,     │
│                           │  │    TypingMind, curl, etc.)    │
└───────────────────────────┼──┼───────────────────────────────┘
                            │  │  HTTPS
┌───────────────────────────┼──┼───────────────────────────────┐
│                  CLOUDFLARE (free)                           │
│                           │  │                               │
│   CNAME hermes.nijeeshnj.tech → <app>-<org>.koyeb.app        │
│   SSL termination · DDoS protection · zero config            │
└───────────────────────────┼──┼───────────────────────────────┘
                            │  │
┌───────────────────────────┼──┼───────────────────────────────┐
│              KOYEB FREE TIER  (single container)             │
│                           │  │                               │
│   ┌───────────────────────▼──▼──────────────────────────┐    │
│   │              app service  (this Dockerfile)         │    │
│   │              512MB · 0.1 vCPU                       │    │
│   │                                                     │    │
│   │              tini → hermes gateway :$PORT           │    │
│   │                                                     │    │
│   └────────────────────────┬───────────────────────┬────┘    │
└────────────────────────────┼───────────────────────┼─────────┘
                             │ HTTPS                 │ HTTPS
                             ▼                       ▼
                  ┌─────────────────────┐   ┌────────────────────┐
                  │   Groq API          │   │   Honcho cloud     │
                  │   Llama 3.3 70B     │   │   honcho.dev       │
                  │   GROQ_API_KEY      │   │   HONCHO_API_KEY   │
                  └─────────────────────┘   └────────────────────┘
                  (Hermes inference)        (Long-term memory)
```

---

## 2. Components

### 2.1 Hermes Agent (in the container)
**What it is:** Open-source agent runtime by Nous Research ([NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent))
**Public port:** `$PORT` (Koyeb-assigned, default 8000)
**Role:** Receives any input, reasons, calls tools, returns OpenAI-compatible responses

Exposes `/v1/chat/completions`, `/v1/models`, `/health`, `/health/detailed`. Any OpenAI-format client connects directly with a bearer token. Config baked into the image at [hermes-data/config.yaml](hermes-data/config.yaml).

Runtime env (set as Koyeb secrets):
```
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=$PORT
API_SERVER_KEY=<random>
API_SERVER_CORS_ORIGINS=https://hermes.nijeeshnj.tech
GROQ_API_KEY=<groq>
HONCHO_API_KEY=<honcho>
```

Capabilities used:
- Tool / function calling
- 128K context window via Groq's Llama 3.3 70B
- MCP server support (add integrations post-deploy via config)
- `execute_code` for inline Python/JS

**Not installed** (kept lean for the 512MB budget): Node.js, Playwright/Chromium, ffmpeg, audio tools, WhatsApp bridge.

---

### 2.2 Honcho (cloud, external)
**What it is:** Open-source AI memory backend by Plastic Labs, hosted at [honcho.dev](https://honcho.dev)
**Role:** Long-term memory — builds and maintains a model of Nijeesh across sessions

Hermes' built-in Honcho plugin defaults to the cloud endpoint. With `HONCHO_API_KEY` set and `honcho.enabled: true` in [hermes-data/config.yaml](hermes-data/config.yaml), no further wiring is needed.

Honcho synthesises two memory layers on every turn, injected into Hermes' prompts:

```
Base context
  └── who Nijeesh is, his preferences, working style,
      active projects, past decisions, recurring topics

Dialectic supplement
  └── what matters right now in this session,
      what the agent should keep in mind
```

**Memory persists across redeploys** because state lives in Honcho's cloud, not in the container.

---

### 2.3 Optional clients (run anywhere)
Any OpenAI-compatible client connects with the bearer token:
- Browser-based UIs (Open WebUI, TypingMind, LibreChat) pointed at `https://hermes.nijeeshnj.tech/v1`
- Terminal coding agents (OpenCode, Aider, Cursor's custom-endpoint mode)
- Mobile chat apps that accept a custom base URL + API key

None of these run inside the Koyeb service. They're purely consumers.

---

## 3. Docker Container Design

### Single-process rationale
The container runs exactly one program: `hermes gateway`. No supervisord, no sidecars, no init system beyond tini (signal forwarding + zombie reaping for PID 1).

### RAM budget (best estimate)
```
tini                   ~1MB
hermes gateway         ~200MB
─────────────────────────────
Total                  ~201MB    (in Koyeb's 512MB free instance)
Free headroom          ~311MB    (buffer for Groq response processing)
```

Comfortably fits the free tier — was the main reason for collapsing Honcho out of the container.

### Container file layout
```
/opt/hermes-agent/        ← Hermes repo + .venv (built at image time)

/root/.hermes/            ← HERMES_HOME (baked from hermes-data/ in repo)
  └── config.yaml         ← Groq provider + Honcho enabled
```

---

## 4. Repo Layout

```
hermes/                       ← git repo root
│
├── Dockerfile                builds the image
├── entrypoint.sh             env validation + exec hermes gateway
├── .env.example              documented env vars
├── .dockerignore
├── .gitignore
│
├── hermes-data/              baked into HERMES_HOME at build time
│   └── config.yaml           Groq provider, Honcho enabled
│
├── ARCHITECTURE.MD
├── PRD.MD
└── README.md
```

No local-dev or WSL2 path. The repo deploys straight from GitHub to Koyeb.

---

## 5. Deployment

### One-time setup
```bash
# 1. Grab the three API keys
#    - GROQ_API_KEY    : https://console.groq.com (free, no card)
#    - HONCHO_API_KEY  : https://honcho.dev (free, no card)
#    - API_SERVER_KEY  : openssl rand -hex 32

# 2. Push the repo to GitHub
git init && git add . && git commit -m "initial deploy"
git remote add origin git@github.com:<you>/hermes.git
git push -u origin main

# 3. Create the Koyeb service (CLI flow)
curl -fsSL https://raw.githubusercontent.com/koyeb/koyeb-cli/master/install.sh | bash
koyeb login

koyeb secret create API_SERVER_KEY  --value "$(openssl rand -hex 32)"
koyeb secret create GROQ_API_KEY    --value "gsk_..."
koyeb secret create HONCHO_API_KEY  --value "hnc_..."

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

### Custom domain
1. Koyeb dashboard → service → Settings → **Domains** → add `hermes.nijeeshnj.tech`.
2. Cloudflare DNS for `nijeeshnj.tech`:
   ```
   Type:   CNAME
   Name:   hermes
   Target: <app>-<org>.koyeb.app
   Proxy:  ON
   ```
3. Koyeb auto-issues a Let's Encrypt cert; Cloudflare proxies edge traffic.

### Every subsequent deploy
```bash
git push                       # Koyeb auto-builds on GitHub push
# or, manually:
koyeb service redeploy hermes
```

### Monitor
```bash
koyeb service logs hermes --follow    # stream live
koyeb service get hermes              # deployment state
koyeb service describe hermes         # full config
```

---

## 6. Network Flow

```
Request from any OpenAI-compatible client
        │
        │ HTTPS :443 + Bearer token
        ▼
Cloudflare  (hermes.nijeeshnj.tech)
        │ proxies to Koyeb origin
        ▼
Koyeb ingress  →  container :$PORT
        │
        ▼
hermes gateway
        │
        ├──► Honcho cloud  (honcho.dev)    ── fetches memory context
        │                                     pushes new observations async
        │
        └──► Groq API                       ── chat completion
                                              streams response back
```

---

## 7. LLM Provider

Only Groq is configured. `GROQ_API_KEY` powers Hermes' inference via `provider: custom:groq` in [hermes-data/config.yaml](hermes-data/config.yaml).

```
Model:      llama-3.3-70b-versatile
Rate limit: 30 req/min · 6000 tokens/min  (free tier)
Latency:    200–400ms
Cost:       $0
```

No fallback in v1 — adding one (Gemini, OpenRouter) is a config edit and an extra env var.

---

## 8. DNS + SSL

```
Cloudflare → nijeeshnj.tech
  Type:    CNAME
  Name:    hermes
  Target:  <app>-<org>.koyeb.app
  Proxy:   ON  (orange cloud)
```

Cloudflare handles edge SSL; Koyeb issues a Let's Encrypt cert for the same hostname when added as a custom domain.

---

## 9. Security

| Concern | Mitigation |
|---|---|
| Unauthorized API access | Bearer token (`API_SERVER_KEY`) required on `/v1/*` |
| Origin IP exposure | Cloudflare proxy hides Koyeb URL |
| Secrets in Git | Only `.env.example` committed; real values are Koyeb secrets |
| Honcho credentials in transit | HTTPS to honcho.dev; key stored as Koyeb secret |

---

## 10. Monitoring

```bash
koyeb service logs hermes --follow      # stream live
koyeb service logs hermes --since 1h    # historical
koyeb service get hermes                # deployment state
```

UptimeRobot free tier pings `https://hermes.nijeeshnj.tech/health` every 5 minutes — alerts via email if down, and keeps the Koyeb instance warm.

---

## 11. Known Limitations (v2)

| Limitation | Impact | Planned Fix |
|---|---|---|
| Koyeb free tier: 0.1 vCPU | Slow under bursty load | Acceptable for single-user; upgrade to paid if needed |
| Single region | Latency outside chosen region | Acceptable for personal use |
| Honcho cloud free-tier quotas | Hits a ceiling per month | Re-enable Honcho self-host if/when needed |
| Groq rate limit (30 req/min) | Brief 429s under bursts | Add Gemini fallback later |
| No persistent local disk | Container fs is ephemeral | Honcho cloud already covers memory; nothing else needs persistence |

---

## 12. Tech Stack

| Layer | Technology | Cost |
|---|---|---|
| Agent runtime | Hermes Agent (Nous Research) | Free / OSS |
| Memory | Honcho cloud (Plastic Labs) | Free tier |
| LLM provider | Groq (Llama 3.3 70B) | Free tier |
| Container | Docker | Free / OSS |
| Hosting | Koyeb free tier | Free — **no card** |
| DNS + SSL | Cloudflare | Free |
| Uptime monitor | UptimeRobot | Free |
| Domain | nijeeshnj.tech | Already owned |
| **Total** | | **₹0 / month** |
