# PRD — Personal Second Brain (Hermes + cloud Honcho)
**Owner:** Nijeesh NJ
**Version:** 2.0
**Status:** In Progress
**Last Updated:** May 2026

---

## 1. Overview

A personal always-on AI second brain hosted on Koyeb's free tier (no credit card), accessible from any device via `hermes.nijeeshnj.tech`. Hermes Agent is the reasoning and execution layer; Honcho cloud is the long-term memory layer — knowing who Nijeesh is, what he's working on, and getting smarter every session.

No predefined skills. No fixed workflows. Just raw intelligence with persistent memory that can handle anything thrown at it — dump a GitHub repo, paste an article, ask it to write code, research a topic, review a PR, plan a project, or just think out loud.

Any OpenAI-compatible client connects: browsers, OpenCode for coding, mobile chat apps. None of those clients run inside the deploy — they're consumers of the single `/v1` endpoint.

---

## 2. Problem Statement

Nijeesh works across multiple domains simultaneously — web dev projects, a freelance business, stock trading, learning, content creation, and job hunting. Context is scattered across browser tabs, notes, and conversations that disappear.

The core problem is **context loss**. Every AI conversation starts from zero. There's no system that:
- Remembers what was discussed last week
- Knows the current state of active projects
- Understands Nijeesh's preferences, style, and working patterns
- Can take any kind of input — code, links, documents, thoughts — and do something useful with it

A persistent second brain that accumulates knowledge and context over time, accessible from anywhere, at literal zero cost, solves this.

---

## 3. Goals

### Primary Goals
- Always-on AI agent at `hermes.nijeeshnj.tech` — accessible from laptop, phone, any browser
- Persistent cross-session memory via Honcho cloud
- Zero predefined constraints — accepts any input, handles any task
- Deploy from GitHub repo via Koyeb auto-build, no local Hermes install required
- **Total cost: ₹0/month, no credit card required**

### Secondary Goals
- Koyeb CLI workflow — deploy, monitor, debug from terminal
- Single-process Docker image — minimal infra, no Postgres, no Redis, no supervisord
- Custom subdomain with HTTPS via Cloudflare + Koyeb's Let's Encrypt
- Lean container — no Chromium / Playwright / ffmpeg until actually needed

### Non-Goals (v2)
- Predefined skill library
- WhatsApp / Telegram gateway
- Voice interface (STT/TTS)
- Multi-user support
- Multiple LLM providers (Groq only in v2)
- Self-hosting Honcho (delegated to honcho.dev cloud)
- Local-dev parity (no docker-compose, no WSL2 Hermes install)

---

## 4. User

**Name:** Nijeesh NJ
**Role:** Indie developer, web dev business owner, builder
**Devices:** Windows 11 laptop, Android phone
**Access:** Browser from any device. Optionally OpenCode (or any OpenAI-compatible client) pointed at `https://hermes.nijeeshnj.tech/v1`.
**Technical level:** High — comfortable with Docker, CLI, Git, APIs
**Budget:** ₹0/month, no credit card

---

## 5. What "Second Brain" Means Here

Unlike a skill-based agent, this system has no fixed workflows. It works like a brilliant colleague who:

- **Remembers everything** — past conversations, project context, preferences, style (persisted in Honcho cloud)
- **Takes any input** — paste a GitHub URL, drop a codebase, share an article, describe a problem
- **Does anything** — write, research, code, review, plan, explain, debug, draft
- **Gets smarter over time** — Honcho builds a richer model of Nijeesh with every session
- **Works across contexts** — jumps from trading research to UI code to job applications without losing thread

The only interface contract is the OpenAI `/v1/chat/completions` endpoint. Pick whatever frontend (browser UI, terminal, mobile app) feels right.

---

## 6. Inputs the System Must Handle

- Raw text — thoughts, ideas, problems, questions
- GitHub URLs — repos, PRs, issues, gists
- Web URLs — articles, documentation, job postings
- Code snippets — any language, any size
- File contents — pasted markdown, JSON, CSV, config files
- Long documents — pasted research papers, specs, reports

Vision (screenshots) and audio inputs are out of scope for v2 — Groq's vision-capable models can be added later via a config edit.

---

## 7. Access Patterns

| Surface | How | Notes |
|---|---|---|
| Browser laptop | `hermes.nijeeshnj.tech` via Open WebUI / TypingMind / similar | Primary interface |
| Browser phone | Same URL | Mobile access anywhere |
| OpenCode / Aider | API → `hermes.nijeeshnj.tech/v1` with bearer token | Coding tasks on local files |
| Koyeb CLI | `koyeb service logs`, `koyeb service get` | Ops and monitoring |

---

## 8. Constraints

- **Budget: ₹0/month, no card.** Koyeb free tier covers the app service; Honcho cloud free tier covers memory; Groq free tier covers inference; Cloudflare/UptimeRobot/domain stay free. No card required by any provider.
- **Single Koyeb free instance** — 512MB RAM, 0.1 vCPU, one region, no autoscale.
- **Honcho cloud free-tier quotas apply** — memory still works once limits hit, but the model stops getting smarter that month.
- **Groq rate limits** — 30 req/min on free tier; calls serialized, not parallelized.
- **Container is single-process** — `hermes gateway` is the only program. No Postgres, no Redis, no supervisord, no sidecars.
- **No persistent local disk** — anything written inside the container is lost on redeploy; long-term state lives in Honcho cloud.
- **Linux container only** — no local development setup; the Dockerfile is the only build path.
- **Groq only** — a single `GROQ_API_KEY` powers Hermes inference. No fallback provider in v2.

---

## 9. Success Criteria

| Criteria | Target |
|---|---|
| Monthly cost | ₹0 |
| Credit card required | No |
| Accessible from phone browser | Yes |
| Hermes responding on `/v1/chat/completions` | Yes |
| Memory persists across redeploys | Yes (Honcho cloud) |
| OpenCode / any OpenAI client connects | Yes |
| Koyeb CLI monitoring works | Yes |
| Deploy from GitHub via auto-build | Yes |
| No local Hermes install needed | Yes |

---

## 10. Future Considerations (v3+)

- WhatsApp trigger — message the brain from anywhere, get a reply
- GitHub webhook to auto-dump repos as context
- Add a Gemini or OpenRouter fallback for when Groq is rate-limited
- MCP server integrations — Google Drive, Gmail, Calendar
- Vision input via Groq's multimodal models
- Self-host Honcho on Oracle Cloud Free Tier (ARM Ampere, 24GB RAM) if cloud quotas become a blocker
- Voice input via Groq's Whisper-on-Groq when ready
