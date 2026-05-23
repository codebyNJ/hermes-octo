# Architecture — Personal Second Brain (Hermes + Honcho)
**Owner:** Nijeesh NJ  
**Version:** 1.0  
**Last Updated:** May 2026

---

## 1. System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                        ACCESS LAYER                          │
│                                                              │
│   Browser (laptop / phone)        OpenCode (WSL2 local)      │
│   hermes.nijeeshnj.tech    ──┐ ┌── → API calls to Hermes    │
│                              │ │                             │
└──────────────────────────────┼─┼─────────────────────────────┘
                               │ │  HTTPS
┌──────────────────────────────┼─┼─────────────────────────────┐
│                   CLOUDFLARE (free)                          │
│                              │ │                             │
│    CNAME hermes.nijeeshnj.tech → railway-app.up.railway.app  │
│    SSL termination · DDoS protection · zero config           │
└──────────────────────────────┼─┼─────────────────────────────┘
                               │ │
┌──────────────────────────────┼─┼─────────────────────────────┐
│              RAILWAY FREE TIER (single container)            │
│                              │ │                             │
│   ┌──────────────────────────▼─▼──────────────────────────┐ │
│   │                Docker Container                        │ │
│   │                512MB RAM · 1 vCPU                      │ │
│   │                                                        │ │
│   │   ┌────────────┐                                       │ │
│   │   │ Supervisord│                                       │ │
│   │   │            ├──► Hermes Agent :8642                 │ │
│   │   │            │      OpenAI-compatible API server     │ │
│   │   │            │      intent routing · tool calling    │ │
│   │   │            │             │                         │ │
│   │   │            │             │ localhost               │ │
│   │   │            │             ▼                         │ │
│   │   │            ├──► Honcho :8000                       │ │
│   │   └────────────┘      memory backend                   │ │
│   │                       user modeling                    │ │
│   └────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────┘
                               │ outbound
┌──────────────────────────────┼───────────────────────────────┐
│                EXTERNAL FREE APIs                            │
│                                                              │
│   Groq API       → LLM inference (primary, free tier)       │
│   Gemini OAuth   → LLM fallback (free, Google account)      │
│   Any public API → Hermes tool calls on demand              │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Components

### 2.1 Hermes Agent
**What it is:** Open-source agent runtime by Nous Research  
**Port:** 8642  
**Role:** The brain — receives any input, reasons about it, calls tools, returns responses  

Hermes exposes an OpenAI-compatible API (`/v1/chat/completions`). Any client that speaks OpenAI format — Open WebUI, OpenCode, curl — connects directly. No predefined skills or workflows in v1. Raw Hermes with memory context injected by Honcho on every request.

Key capabilities used:
- Tool calling / function calling (fetch URLs, run code, call APIs on demand)
- Long context window (128K via Groq's Llama 3.1 70B)
- MCP server support (connect GitHub, Drive, Gmail etc. later)
- `execute_code` tool — runs Python/JS snippets inline

Config at container start:
```
HERMES_HOME=/root/.hermes
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=<secret set in Railway env>
HONCHO_URL=http://localhost:8000
HONCHO_ENABLED=true
```

---

### 2.2 Honcho
**What it is:** Open-source AI memory backend by Plastic Labs  
**Port:** 8000  
**Role:** Long-term memory — builds and maintains a model of Nijeesh across sessions  

Every conversation turn, Honcho synthesises two memory layers:

```
Base context
  └── who Nijeesh is, his preferences, working style,
      active projects, past decisions, recurring topics

Dialectic supplement
  └── what matters right now in this session,
      what the agent should keep in mind
```

This context is injected into every Hermes request automatically. The agent doesn't start from zero — it starts from knowing you.

In v1, Honcho runs in-memory. Data resets on Railway redeploy. Persistent storage planned for v2 via Cloudflare R2 or Supabase.

---

### 2.3 OpenCode (Local — WSL2)
**What it is:** Open-source terminal AI coding agent  
**Location:** Nijeesh's laptop, WSL2, `D:\HermesSetup\`  
**Role:** File-level coding — reads local files, writes code, runs tests  

OpenCode is configured to use `hermes.nijeeshnj.tech/v1` as its LLM backend instead of OpenAI. This means:

- All inference happens on Railway (Hermes + Groq) — not locally
- Laptop only does file I/O — lightweight, no local model running
- OpenCode gets the same Honcho memory context as the browser interface
- Can work on local project files while brain lives in cloud

```
OpenCode in WSL2
    reads/writes → D:\Projects\my-app\
    sends prompts → hermes.nijeeshnj.tech/v1
                         ↓
                    Hermes on Railway
                         ↓
                    Groq inference
```

Config:
```bash
opencode config set api-url https://hermes.nijeeshnj.tech/v1
opencode config set api-key <same key as API_SERVER_KEY>
```

---

### 2.4 Supervisord
**Role:** Process manager inside the Docker container  
**Why:** Docker expects one process per container. Supervisord runs Hermes and Honcho as two managed processes, auto-restarting either on crash.

```
Container entrypoint → supervisord
                            ├── honcho (restarts if crashes)
                            └── hermes (restarts if crashes)
```

Both processes log to `/var/log/` inside the container, visible via `railway logs`.

---

## 3. Docker Container Design

### Single Container Rationale
Railway free tier = 1 service. Hermes + Honcho run together:
- Internal communication via `localhost` — no network latency
- Single deploy, single log stream, single health check
- 235MB actual RAM — well within 512MB limit

### RAM Budget
```
Supervisord      ~5MB
Honcho           ~80MB
Hermes gateway   ~150MB
─────────────────────────────
Total            ~235MB
Free headroom    ~277MB   (buffer for Groq response processing)
```

### Container File Layout
```
/root/
└── .hermes/
      ├── .env            ← API keys (injected from Railway env vars)
      └── config.yaml     ← model + provider config

/app/
└── honcho/               ← Honcho install

/etc/supervisor/conf.d/
└── supervisord.conf      ← process definitions

/var/log/
├── hermes.log
├── hermes-error.log
├── honcho.log
└── honcho-error.log
```

---

## 4. Local Project Structure

```
D:\HermesSetup\                 ← git repo root
│
├── Dockerfile                  ← builds the container
├── supervisord.conf            ← Hermes + Honcho process config
├── docker-compose.yml          ← local testing only
├── railway.toml                ← Railway deploy config
├── .env                        ← local secrets (gitignored)
├── .gitignore
├── README.md
├── PRD.md
├── ARCHITECTURE.md
│
├── hermes-data\                ← local Hermes config (gitignored)
│     ├── .env
│     └── config.yaml
│
├── honcho-data\                ← local Honcho data (gitignored)
│     └── .gitkeep
│
└── logs\                       ← local logs (gitignored)
      └── .gitkeep
```

---

## 5. Deployment Flow

### One-time Setup
```bash
# In WSL2
railway login                    # GitHub OAuth
railway init                     # create Railway project
railway link                     # link local folder to project

# Set secrets
railway variable set GROQ_API_KEY=xxx
railway variable set API_SERVER_KEY=xxx
railway variable set HONCHO_ENABLED=true
```

### Every Deploy
```bash
railway up                       # build + deploy + stream logs
```

### Monitor
```bash
railway logs                     # live log stream
railway logs --lines 50          # last 50 lines
railway status                   # deployment state
railway ssh                      # shell inside container
```

---

## 6. Network Flow

```
Request from browser or OpenCode
        │
        │ HTTPS :443
        ▼
Cloudflare (hermes.nijeeshnj.tech)
        │ proxies to Railway origin
        ▼
Railway ingress → container :8642
        │
        ▼
Hermes API server
        │ fetches memory context
        ▼
Honcho :8000 (localhost, same container)
        │ returns user context
        ▼
Hermes builds enriched prompt
        │
        ▼
Groq API (outbound HTTPS)
        │ returns completion
        ▼
Hermes streams response back to client
```

---

## 7. LLM Provider Strategy

### Primary — Groq (free, no card)
```
Model:      llama-3.1-70b-versatile (Hermes 3 fine-tune)
Rate limit: 30 req/min · 6000 tokens/min
Latency:    200–400ms
Cost:       $0
```

### Fallback — Google Gemini OAuth (free, Google account)
```
Model:      gemini-1.5-flash
Activates:  when Groq rate limit hit
Auth:       Google OAuth login, no card
Cost:       $0
```

### Rate Limit Handling
Hermes serializes requests — one Groq call at a time. For a personal single-user system, 30 req/min is more than sufficient. If concurrent sessions ever hit the limit, Gemini fallback kicks in automatically.

---

## 8. DNS + SSL Setup

```
Cloudflare Dashboard → nijeeshnj.tech
  Add record:
    Type:    CNAME
    Name:    hermes
    Target:  <your-app>.up.railway.app
    Proxy:   ON (orange cloud)
```

Cloudflare handles SSL automatically. No cert management needed.

---

## 9. Security

| Concern | Mitigation |
|---|---|
| Unauthorized API access | Bearer token on all requests (`API_SERVER_KEY`) |
| Origin IP exposure | Cloudflare proxy hides Railway URL |
| Secrets in Git | `.env` and `hermes-data/` in `.gitignore` |
| Railway env vars | Set via CLI, never in code |

---

## 10. Monitoring

```bash
railway logs                  # stream live
railway logs --lines 100      # historical
railway ssh                   # debug inside container
railway status --json         # machine-readable state
```

UptimeRobot free tier — pings `hermes.nijeeshnj.tech/health` every 5 minutes. Alerts via email if down. Prevents Railway container from cold-starting.

---

## 11. Known Limitations (v1)

| Limitation | Impact | Planned Fix |
|---|---|---|
| Honcho memory resets on redeploy | Lose session memory | v2: Cloudflare R2 / Supabase |
| Single container | No independent scaling | Acceptable for personal use |
| Groq rate limits | Slow under concurrent load | Gemini fallback |
| No persistent disk on Railway free | Can't store files | v2: external storage |
| Hermes beta on Windows | Dev must use WSL2 | Already using WSL2 |

---

## 12. Tech Stack

| Layer | Technology | Cost |
|---|---|---|
| Agent runtime | Hermes Agent (Nous Research) | Free / OSS |
| Memory | Honcho (Plastic Labs) | Free / OSS |
| Local coding | OpenCode | Free / OSS |
| LLM primary | Groq (Llama 3.1 70B) | Free tier |
| LLM fallback | Google Gemini OAuth | Free |
| Process manager | Supervisord | Free / OSS |
| Container | Docker | Free / OSS |
| Hosting | Railway free tier | Free |
| DNS + SSL | Cloudflare | Free |
| Uptime monitor | UptimeRobot | Free |
| Domain | nijeeshnj.tech | Already owned |
| **Total** | | **₹0 / month** |