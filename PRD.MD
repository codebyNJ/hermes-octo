# PRD — Personal Second Brain (Hermes + self-hosted Honcho on Render + Neon)
**Owner:** Nijeesh NJ
**Version:** 4.0
**Status:** In Progress
**Last Updated:** May 2026

---

## 1. Overview

A personal always-warm AI second brain deployed for **₹0/month with no credit card**, accessible from any device via `hermes.nijeeshnj.tech`. Hermes Agent is the reasoning and execution layer; Honcho (self-hosted in the same container) is the long-term memory layer, backed by Neon's serverless Postgres + pgvector.

The data lives in a database **you own** (your Neon project). Custom domain works on the free tier. Memory persists forever — across redeploys, sleeps, restarts.

No predefined skills. No fixed workflows. Just raw intelligence with persistent memory that can handle anything thrown at it.

---

## 2. Problem Statement

Nijeesh works across multiple domains simultaneously — web dev projects, a freelance business, stock trading, learning, content creation, and job hunting. Context is scattered across browser tabs, notes, and conversations that disappear.

The core problem is **context loss**. Every AI conversation starts from zero. There's no system that:
- Remembers what was discussed last week
- Knows the current state of active projects
- Understands Nijeesh's preferences, style, and working patterns
- Can take any kind of input — code, links, documents, thoughts — and do something useful with it

A persistent second brain — owned, no card, accessible at a real subdomain — solves this.

---

## 3. Goals

### Primary Goals
- Always-warm AI agent at `hermes.nijeeshnj.tech` — accessible from laptop, phone, any browser
- **Self-owned** long-term memory via self-hosted Honcho + Neon Postgres
- Zero predefined constraints — accepts any input, handles any task
- Deploy from a single `git push` to GitHub (Render auto-builds)
- **Total cost: ₹0/month, no credit card required**
- Custom subdomain (`hermes.nijeeshnj.tech`) live on day one

### Secondary Goals
- Render CLI / dashboard workflow for monitoring
- Single Docker image with 3 supervisord-managed processes
- Lean container — no Chromium / Playwright / ffmpeg
- UptimeRobot keep-warm to mask Render's 15-min sleep

### Non-Goals (v4)
- Predefined skill library
- WhatsApp / Telegram gateway
- Voice interface (STT/TTS)
- Multi-user support
- Multiple LLM providers (Groq only)
- Cloud Honcho (we self-host now)
- Redis (deliberately omitted to dodge a third free-tier dependency)
- Local-dev parity (no docker-compose, no WSL2 Hermes install)

---

## 4. User

**Name:** Nijeesh NJ
**Role:** Indie developer, web dev business owner, builder
**Devices:** Windows 11 laptop, Android phone
**Access:** Browser from any device, plus optionally OpenCode / Aider / any OpenAI-compatible client pointed at the subdomain with a bearer token.
**Technical level:** High — comfortable with Docker, CLI, Git, APIs
**Budget:** ₹0/month, no credit card

---

## 5. What "Second Brain" Means Here

Unlike a skill-based agent, this system has no fixed workflows. It works like a brilliant colleague who:

- **Remembers everything** — past conversations, project context, preferences, style (persisted in your Neon Postgres)
- **Takes any input** — paste a GitHub URL, drop a codebase, share an article, describe a problem
- **Does anything** — write, research, code, review, plan, explain, debug, draft
- **Gets smarter over time** — Honcho's deriver builds a richer model of Nijeesh with every session
- **Works across contexts** — jumps from trading research to UI code to job applications without losing thread

The only interface contract is the OpenAI `/v1/chat/completions` endpoint. Pick whatever frontend feels right.

---

## 6. Inputs the System Must Handle

- Raw text — thoughts, ideas, problems, questions
- GitHub URLs — repos, PRs, issues, gists
- Web URLs — articles, documentation, job postings
- Code snippets — any language, any size
- File contents — pasted markdown, JSON, CSV, config files
- Long documents — pasted research papers, specs, reports

Vision and audio inputs are out of scope for v4.

---

## 7. Access Patterns

| Surface | How | Notes |
|---|---|---|
| Browser laptop | `hermes.nijeeshnj.tech` via Open WebUI / TypingMind / similar | Primary interface |
| Browser phone | Same URL | Mobile access anywhere |
| OpenCode / Aider | API → `hermes.nijeeshnj.tech/v1` with bearer token | Coding tasks on local files |
| Render dashboard | Logs + Metrics tab | Ops and monitoring |
| Neon dashboard | Monitoring tab | DB usage, CU-hours, storage |

---

## 8. Constraints

- **Budget: ₹0/month, no card.** Render free + Neon free + Groq free + Cloudflare + UptimeRobot. None require a card.
- **Render free instance:** 512 MB RAM, 0.1 vCPU, single region. Sleeps after 15 min idle, ~60 s cold start. 750 instance-hours/month cap.
- **Neon free project:** 0.5 GB storage, 100 compute-hours/project/month, sub-second cold start from auto-suspend.
- **Honcho cadence tuned `low`** — `contextCadence`, `dialecticCadence`, `dialecticReasoningLevel` all set to `low` in `honcho-config.json` to keep Neon CU-hours within budget.
- **3 processes in 512 MB.** Hermes (~200 MB) + Honcho api (~100 MB) + Honcho deriver (~100 MB) ≈ 400 MB. Tight.
- **No Redis** — `CACHE_ENABLED=false`. Honcho deriver runs without caching.
- **Groq only** — single `GROQ_API_KEY` powers Hermes inference and Honcho deriver. No fallback provider.
- **Groq rate limits** — 30 req/min, 6000 tokens/min, 14400 req/day on free tier.
- **Linux container only** — no local dev path. Dockerfile is the only build.

---

## 9. Success Criteria

| Criteria | Target |
|---|---|
| Monthly cost | ₹0 |
| Credit card required | No |
| Accessible at `hermes.nijeeshnj.tech` | Yes (custom domain on free Render) |
| Hermes + Honcho api + deriver all running | Yes |
| Memory persists across redeploys | Yes (Neon Postgres) |
| Data ownership | Yes (your Neon project) |
| OpenCode / any OpenAI client connects | Yes |
| Render auto-deploy from GitHub | Yes |
| UptimeRobot keeps Render awake | Yes (within 750 hr/mo cap) |
| Cold start when forced sleep happens | ≤ 60 s |

---

## 10. Future Considerations (v5+)

- WhatsApp trigger — message the brain from anywhere, get a reply
- GitHub webhook to auto-dump repos as context
- Add a Gemini or OpenRouter fallback for when Groq is rate-limited
- Add Upstash Redis (free, no card) if Honcho deriver throughput becomes a bottleneck
- MCP server integrations — Google Drive, Gmail, Calendar
- Honcho retention policy (TTL on `messages` / `embeddings`) once upstream exposes it
- Vision input via Groq's multimodal models
- Move to **Oracle Cloud Always-Free** (24 GB ARM VM, always-on) if Render's sleep or Neon's CU-hours become blockers — card required for ID verification only, no charges
