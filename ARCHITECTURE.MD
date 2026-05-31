# Architecture — Hermes Second Brain

**Owner:** Nijeesh NJ
**Version:** 5.0
**Last Updated:** May 2026

This doc explains how Hermes Second Brain is built and why each piece is there, in plain English. No prior infra background needed.

---

## 1. The Big Picture

```
   Your apps (OpenCode, TypingMind, curl, etc.)
                    │
                    │  HTTPS + your bearer token
                    ▼
   ┌────────────────────────────────────────────────┐
   │            HUGGING FACE SPACE                  │
   │            (2 CPU · 16 GB RAM)                 │
   │                                                │
   │   ┌─────────────────────────────────────┐      │
   │   │  hermes-gateway   (port 7860)       │◄─────┼─── Public API
   │   │  the public front door              │      │
   │   └─────────────────────────────────────┘      │
   │      │            │             │              │
   │      │  asks      │  calls      │  last        │
   │      │  for       │  cloud      │  resort      │
   │      │  memory    │  LLMs       │  fallback    │
   │      ▼            ▼             ▼              │
   │   honcho-api   OpenRouter   llama-server       │
   │   (8000)       Z.AI         (8080, local CPU)  │
   │   honcho-deriver                               │
   │   (background worker)                          │
   │      │                                         │
   │      │  reads & writes memory                  │
   └──────┼─────────────────────────────────────────┘
          │
          │  encrypted Postgres connection
          ▼
   ┌──────────────────────────┐
   │  NEON (serverless        │
   │  Postgres + pgvector)    │
   │                          │
   │  This is where YOUR      │
   │  memories actually live. │
   └──────────────────────────┘

   UptimeRobot → pings /health every 5 min → keeps the Space awake
```

The container is **disposable**. Hugging Face can restart it any time. Nothing important lives inside it — all your memory data is in Neon. Restarts cost you nothing.

---

## 2. What happens when you send a message

Walk through a single chat request end to end:

1. **Your client** sends a POST to `https://<you>-hermes.hf.space/v1/chat/completions` with a bearer token and a message.
2. **hermes-gateway** receives it. Checks the token. Wrong token = 401.
3. The gateway asks **honcho-api** (its local memory service) "what do I know about this user?" The answer — a compact summary of past observations — gets stitched into the system prompt.
4. The gateway picks a model from the **fallback chain** (see §4) and calls it.
5. If that model errors or times out, the gateway automatically retries with the next provider in the chain. The user never sees a failure unless **every** provider fails.
6. The model's reply streams back to your client.
7. **In the background**, honcho-deriver reads the new conversation and extracts facts worth remembering ("Nijeesh is doing his 4th year"). These get written to Neon as observations.

Next time you chat, step 3 finds those new facts and uses them. That's how memory persists.

---

## 3. The Four Programs Inside the Container

A small process manager called **supervisord** runs four programs. If any crash, supervisord restarts it.

| Program | What it does | Where you reach it |
|---|---|---|
| `hermes-gateway` | The public API. Receives chat requests, runs the fallback chain, talks to memory, streams responses. | Port **7860**, public |
| `honcho-api` | Memory service. Stores/retrieves observations, embeddings, conversation history. | Port **8000**, local only |
| `honcho-deriver` | Background worker. Reads new messages, extracts facts, writes to Neon. | No port, runs continuously |
| `llama-server` | A small 3B-parameter model (Hermes-3-Llama-3.2-3B) running on the container's own CPU. | Port **8080**, local only |

Why a local model? Insurance. If every cloud provider in your fallback chain is rate-limited or down, the gateway can still respond — slowly, but it responds.

---

## 4. The LLM Fallback Chain

Hermes doesn't pick one LLM and hope for the best. It walks down a list. Defined in [hermes-data/config.yaml](hermes-data/config.yaml):

```
1.  OpenRouter — nvidia/nemotron-3-super-120b-a12b:free  ← first choice
2.  OpenRouter — poolside/laguna-m.1:free
3.  OpenRouter — openai/gpt-oss-120b:free
4.  OpenRouter — google/gemma-4-31b-it:free
5.  Z.AI — glm-4.7-flash
6.  Local — hermes-3-llama-3.2-3b                        ← last resort
```

Rules:
- A **rate limit (429)** → skip to the next entry.
- An **auth error (401)** → skip to the next entry.
- A **bad request (400)** → skip to the next entry.
- A successful response → stop, return it.

OpenRouter sits at the top because four free models there give you a soft cushion before you start paying daily-cap costs on anything else. Z.AI's GLM-4.7-Flash is a strong general-purpose model but capped at 50 requests/day on the free tier. The local Hermes-3-3B is unlimited but slow (CPU inference, ~3 GB RAM, several seconds per response).

---

## 5. How Memory Actually Works

Memory is the whole reason this exists. The setup:

**Honcho** (open-source, by Plastic Labs) is a memory service designed for AI agents. It has two parts:
- **honcho-api** — the synchronous read path. When the gateway needs context, it asks honcho-api and gets a quick answer.
- **honcho-deriver** — the asynchronous write path. After each chat turn, it reads the new messages, runs a small LLM call to extract facts, and writes those observations to the database.

**Neon** is where Honcho stores everything. It's a "serverless" Postgres — that means the database goes to sleep when nobody's using it (sub-second wake-up) and you only pay (in compute-hours) for actual usage. The `pgvector` extension lets it store and search embeddings, which is how Honcho finds relevant past observations for the current conversation.

The connection between Honcho and Neon is normal Postgres over the public internet, protected by TLS. The connection string lives in the `DATABASE_URL` environment variable, set as a Hugging Face Secret. It is never written to disk inside the repo.

**Why this matters**: the Hugging Face container is ephemeral. Hugging Face can restart it for any reason — a build, a sleep, a hardware migration. Because all state is in Neon, every restart is invisible to you.

---

## 6. The Extras (Web, GitHub, Skills)

These are optional capabilities the agent uses **when relevant**, not on every turn.

| Capability | What it adds | Backed by |
|---|---|---|
| **Web search & extract** | The agent can search the web and read pages. | [Exa](https://exa.ai) free tier — uses `EXA_API_KEY`. |
| **GitHub access** | The agent can read your public repos, search code, list commits. | A GitHub MCP server, started by the container on demand. Needs `GITHUB_PERSONAL_ACCESS_TOKEN`. |
| **Skills** | Small markdown playbooks the agent can load when a task matches. Examples in this repo: `hireme`, `understand-repo`, `learn-simple`, `gtm-research`. | Plain `.md` files in `hermes-data/skills/`. |

Skills are just markdown. You can write new ones by dropping a `SKILL.md` file into the right folder and rebuilding.

---

## 7. What Lives Where (File Layout)

```
hermes/                              ← this git repo
│
├── Dockerfile                       Builds the container. Clones Hermes + Honcho,
│                                    installs Python deps, downloads the local model.
│
├── supervisord.conf                 Tells supervisord which 4 programs to run.
├── entrypoint.sh                    First-boot setup: validates secrets, makes sure
│                                    Postgres is reachable, runs DB migrations.
│
├── honcho-config.json               Wires Hermes to the local Honcho on 127.0.0.1:8000.
├── .env.example                     Documents which secrets you need (no real values).
│
├── hermes-data/                     Baked into /root/.hermes inside the container.
│   ├── config.yaml                  Provider chain, model defaults, MCP servers, skills toggle.
│   ├── SOUL.md                      The agent's persona/values.
│   ├── memories/USER.md             What the agent "knows" about Nijeesh at build time.
│   ├── memories/MEMORY.md           Index of additional memory files.
│   └── skills/                      Markdown playbooks: eng/, gtm/, personal/.
│
├── README.md                        How to deploy.
├── ARCHITECTURE.MD                  This file.
└── AGENTS.md                        Internal notes for Claude Code.
```

Inside the running container:

```
/opt/hermes-agent/         The Hermes runtime (Python venv)
/opt/honcho/               The Honcho service (Python venv)
/opt/llama-server/         The local LLM server (Python venv)
/opt/models/               The downloaded GGUF model file
/root/.hermes/             Hermes' config home (copied from hermes-data/)
/root/.honcho/             Honcho's config home
/etc/supervisor/conf.d/    supervisord program definitions
```

---

## 8. Memory Budget (Why It Fits in 16 GB)

```
supervisord + tini          ~10 MB
honcho-api                  ~150 MB
honcho-deriver              ~150 MB
hermes-gateway              ~300 MB
llama-server + 3B Q4 model  ~2.5 GB   (the big one)
───────────────────────────────────
Total                       ~3.1 GB   (out of 16 GB)
```

Plenty of headroom. The local model dominates because it's actually holding 3 billion weights in memory.

---

## 9. The Network Picture

```
Your client
   │ HTTPS + Bearer token
   ▼
Hugging Face edge (TLS termination, free cert)
   │
   ▼
hermes-gateway :7860
   │                                 ┌─► honcho-api :8000  ─► Neon (Postgres)
   ├── asks for memory context ──────┤
   │                                 └─► honcho-deriver  ──► Neon (writes facts)
   │
   └── calls LLM provider in chain:
         ├─► OpenRouter  (HTTPS, openrouter.ai)
         ├─► Z.AI         (HTTPS, api.z.ai)
         └─► llama-server :8080 (loopback, never leaves container)
```

The gateway is the only thing the public internet sees. Everything else (Honcho, the local model) listens on `127.0.0.1` and is unreachable from outside.

---

## 10. Security

| Concern | Mitigation |
|---|---|
| Random people calling your API | Bearer token check on every `/v1/*` request. |
| API key leaks in Git | Only `.env.example` is committed. Real keys are Hugging Face Secrets. |
| Honcho memory exposed | Honcho binds to `127.0.0.1:8000`, not reachable from outside the container. |
| Postgres in transit | TLS enforced via `sslmode=require` on the Neon connection string. |
| Postgres at rest | Neon encrypts disks. |
| Local model misuse | Loopback only. Not part of the public API surface. |

There is no admin UI, no dashboard, no user system. The bearer token is the single line of defense. Treat it like a password.

---

## 11. Known Limits

| Limit | What it means | Workaround |
|---|---|---|
| Hugging Face sleep after ~48 h idle | First call after a forced sleep takes 30–60 seconds | UptimeRobot pings every 5 min |
| Neon: 0.5 GB storage | Memory can fill up if you talk a lot every day | Periodically delete old `messages` rows |
| Neon: 100 compute-hours/month | Background deriver eats this | Honcho's cadence is tuned `low` in config |
| OpenRouter free models: per-day caps | Top of the chain may exhaust during heavy days | Chain automatically falls to Z.AI then local |
| Z.AI free: 50 requests/day | Cheap fallback runs out quickly | Local model takes over |
| Local model: slow on 2 CPU | Several seconds per token of output | Acceptable as last resort |
| Hugging Face: no custom domain on free tier | Only `<user>-hermes.hf.space` works | Cloudflare redirect rule (browser only) or HF Pro ($9/mo) |

---

## 12. Tech Stack at a Glance

| Layer | Software | Cost | Card required? |
|---|---|---|---|
| Agent runtime | Hermes Agent (Nous Research) | OSS | — |
| Memory backend | Honcho (Plastic Labs) | OSS | — |
| Database | Neon Postgres + pgvector | Free tier | No |
| Primary LLMs | OpenRouter (free models) | Free tier | No |
| Secondary LLM | Z.AI GLM-4.7-Flash | Free tier (50/day) | No |
| Local LLM | Hermes-3-Llama-3.2-3B (NousResearch) | Free / OSS | — |
| Web search | Exa | Free tier (1000/mo) | No |
| Code access | GitHub MCP server | Free / OSS | — |
| Hosting | Hugging Face Spaces | Free tier | No |
| Container | Docker + supervisord + tini | OSS | — |
| Uptime monitoring | UptimeRobot | Free tier | No |
| **Total** | | **₹0/month** | **No card** |

That's the whole system.
