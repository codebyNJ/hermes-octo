# PRD — Personal Second Brain (Hermes + Honcho)
**Owner:** Nijeesh NJ  
**Version:** 1.0  
**Status:** In Progress  
**Last Updated:** May 2026

---

## 1. Overview

A personal always-on AI second brain hosted on Railway, accessible from any device via `hermes.nijeeshnj.tech`. It combines Hermes Agent as the reasoning and execution layer with Honcho as the long-term memory layer — knowing who Nijeesh is, what he's working on, and getting smarter over every session.

No predefined skills. No fixed workflows. Just raw intelligence with persistent memory that can handle anything thrown at it — dump a GitHub repo, paste an article, ask it to write code, research a topic, review a PR, plan a project, or just think out loud.

Local OpenCode on WSL2 connects to this cloud brain for all coding tasks, keeping the laptop lightweight.

---

## 2. Problem Statement

Nijeesh works across multiple domains simultaneously — web dev projects, a freelance business, stock trading, learning, content creation, and job hunting. Context is scattered across browser tabs, notes, and conversations that disappear.

The core problem is **context loss**. Every AI conversation starts from zero. There's no system that:
- Remembers what was discussed last week
- Knows the current state of active projects
- Understands Nijeesh's preferences, style, and working patterns
- Can take any kind of input — code, links, documents, thoughts — and do something useful with it

A persistent second brain that accumulates knowledge and context over time, accessible from anywhere, at zero cost, solves this.

---

## 3. Goals

### Primary Goals
- Always-on AI agent at `hermes.nijeeshnj.tech` — accessible from laptop, phone, any browser
- Persistent memory via Honcho — remembers context across sessions, builds a model of Nijeesh over time
- Zero predefined constraints — accepts any input, handles any task
- Local OpenCode wired to cloud brain — file-level coding without local inference load
- ₹0/month total cost

### Secondary Goals
- Railway CLI workflow — deploy, monitor, debug from terminal
- Single Docker container — minimal infra, one service
- Custom subdomain with HTTPS via Cloudflare

### Non-Goals (v1)
- Predefined skill library
- WhatsApp / Telegram gateway
- Voice interface
- Multi-user support
- Paid API usage

---

## 4. User

**Name:** Nijeesh NJ  
**Role:** Indie developer, web dev business owner, builder  
**Devices:** Windows 11 laptop (WSL2 + Docker), Android phone  
**Access:** Browser from any device + OpenCode locally in WSL2  
**Technical level:** High — comfortable with Docker, CLI, Git, APIs  
**Budget:** ₹0/month hard constraint

---

## 5. What "Second Brain" Means Here

Unlike a skill-based agent, this system has no fixed workflows. It works like a brilliant colleague who:

- **Remembers everything** — past conversations, project context, preferences, style
- **Takes any input** — paste a GitHub URL, drop a codebase, share an article, describe a problem
- **Does anything** — write, research, code, review, plan, explain, debug, draft
- **Gets smarter over time** — Honcho builds a richer model of Nijeesh with every session
- **Works across contexts** — jumps from trading research to UI code to job applications without losing thread

The only interface is a chat window. The only limit is what Hermes + Groq can do.

---

## 6. Inputs the System Must Handle

- Raw text — thoughts, ideas, problems, questions
- GitHub URLs — repos, PRs, issues, gists
- Web URLs — articles, documentation, job postings
- Code snippets — any language, any size
- File contents — pasted markdown, JSON, CSV, config files
- Screenshots — UI designs, error messages, diagrams (via vision model)
- Long documents — pasted research papers, specs, reports

---

## 7. Access Patterns

| Surface | How | Notes |
|---|---|---|
| Browser laptop | `hermes.nijeeshnj.tech` | Primary interface |
| Browser phone | Same URL | Mobile access anywhere |
| OpenCode (WSL2) | API → `hermes.nijeeshnj.tech/v1` | Coding tasks on local files |
| Railway CLI | `railway logs`, `railway ssh` | Ops and monitoring |

---

## 8. Constraints

- **₹0/month** — free tiers only, no credit card, no paid APIs
- **Single Railway service** — one Docker container, Hermes + Honcho together
- **512MB RAM limit** — must stay within Railway free tier container limit
- **Groq rate limits** — 30 req/min on free tier, calls serialized not parallelized
- **No persistent disk on Railway** — Honcho memory in-memory in v1, resets on redeploy
- **Linux only** — Hermes runs on Linux; development via WSL2, deployment on Railway Linux container

---

## 9. Success Criteria

| Criteria | Target |
|---|---|
| Monthly cost | ₹0 |
| Accessible from phone browser | Yes |
| Hermes + Honcho both running | Yes |
| Memory persists within a session | Yes |
| OpenCode connects to cloud brain | Yes |
| Railway CLI monitoring works | Yes |
| Deploy from WSL2 terminal | Yes |

---

## 10. Future Considerations (v2+)

- Persistent cross-session memory via Cloudflare R2 or Supabase
- WhatsApp trigger — message it from anywhere, get reply
- Dump GitHub repos as context automatically via webhook
- Upgrade to paid Railway tier ($5/mo) if free limits hit
- Add Google Gemini OAuth as fallback provider
- MCP server integrations — Google Drive, Gmail, Calendar