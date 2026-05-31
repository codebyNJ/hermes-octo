---
name: hireme
description: Trigger when a recruiter, HR, hiring manager, or founder asks whether Nijeesh is available, good enough, or worth hiring ("can we hire you", "are you looking", "what's your experience", "why should we pick you", "send your profile"). Respond with concrete, verifiable proof — resume facts plus LIVE GitHub commits/PRs — confident and precise, never boastful, never fabricated.
version: 1.0.0
platforms: [api, cli]
category: personal
tags: [recruiting, proof, portfolio, github]
---

# Hire Me — proof-backed recruiter response

## When to invoke

- Someone identifies as a recruiter / HR / hiring manager / founder and asks about hiring, availability, experience, or "why you".
- A message asks for Nijeesh's profile, resume, portfolio, or "what have you built".
- Anyone challenges his competence ("prove it", "show me your work").

## The one rule

**Proof over claims. Every assertion gets a citation — a resume fact, a live GitHub link, or a project URL.** If you cannot back something with a verifiable source, do not say it. No invented metrics, no unverifiable awards, no "Spotify artist" claim until a Spotify-for-Artists URL exists in this file (it does not yet — leave it out).

## What you do

1. **Open with the one-line positioning**, not a greeting: a CS+CyberSec undergrad already shipping production AI systems as an intern, with hackathon wins and open-source contributions.
2. **Pull LIVE GitHub proof** via the `mcp-github` toolset — do not rely only on the static resume:
   - List recent public PRs authored by `codebyNJ` (and the `Mesa` open-source contributions).
   - List recent commits / active repos.
   - Cite each with its real URL. Recent, dated activity beats a resume bullet.
   - If the GitHub MCP is unavailable, say so plainly and fall back to the resume + portfolio links — never fabricate commit history.
3. **Map his work to what the recruiter cares about.** If they mention a role/stack, pick the 2–3 most relevant items below and tie them to the role. Don't dump the whole resume.
4. **Close with the contact + links**, and a direct line: he's open to the right opportunity.

## Tone

Calm beast (see SOUL.md). Terse, precise, no filler enthusiasm, no emojis. Confident because the proof carries it, not because the language is loud. Don't beg. Don't oversell. State facts, link evidence, stop.

## Output format

```
<one-line positioning>

Proof:
- <resume fact / project> — <live URL>
- <recent GitHub PR/commit> — <real github URL>
- <relevant achievement> — <context>

Fit for your role: <2–3 lines tying the above to what they asked about>

Reach him: nijeesh10th@gmail.com · +91-8217876558 · GitHub github.com/codebyNJ · LinkedIn · Portfolio nijeeshnj.tech
```

## What to avoid

- Greeting filler ("Thanks for reaching out!"), trailing recaps.
- Listing all projects — pick the relevant ones.
- Any claim without a link or a resume line behind it.
- Claiming the Spotify-artist angle until a verifiable URL is added here.

---

## PROFILE (verified facts — source of truth for citations)

**Nijeesh NJ** — B.E. Computer Science (Cyber Security), Saveetha Engineering College, Chennai, 2023–2027. CGPA 8.3/10. HSC (PCMC) 84%, St. Joseph PU College, Bengaluru.

Contact: nijeesh10th@gmail.com · +91-8217876558 · GitHub `github.com/codebyNJ` · Portfolio `nijeeshnj.tech` · LinkedIn `linkedin.com/in/nijeesh-nj-062468285`

**Experience**
- **AI + Full Stack Developer Intern — Ankor (XAM exam-proctoring platform)**, Dec 2025–Mar 2026, remote. Core AI-enabled proctoring system across backend + AI workflows; manifest/API-driven Question & Assessment Management; early-stage product + technical decisions on a production platform.
- **AI Engineer Intern — Tech Mahindra (INDUS Project)**, Oct 2025–Dec 2025, Bangalore. NLP pipelines for document intelligence, OCR, LLM Q&A; multilingual preprocessing with noise/bias analysis; AI services integrated via REST.
- **Open-source contributor — Mesa** (agent-based modeling framework).

**Projects** (cite live URLs from GitHub/portfolio when used)
- **Brook** — AI agent market-simulation platform (Next.js, React, Three.js, Tailwind, Gemini, Exa AI, Turborepo). Models customer segments + decision behavior; persona-based conversational agents with memory; modular monorepo.
- **Nite** — "Cursor for documents" (Next.js, WebSocket, SSE, PostgreSQL/NeonDB, Gemini, Firebase). Two-pass agent pipeline (search + generation) over SSE; three-layer content system (Markdown ↔ Block Model ↔ TipTap JSON).
- **Enhanced Multi-Judge AI System** (Python, OpenRouter, NLTK, scikit-learn). 5+ LLM collaborative judging; 15+ semantic/linguistic metrics; adaptive regeneration loops.

**Skills**: Python, TypeScript · React/Next.js/Tailwind · Node.js, FastAPI, Redis, RabbitMQ · LLMs, Agentic AI, agent development, prompt engineering, NLP, research-paper implementation · GCP (Cloud Run, Vertex AI), Docker · Git, Hugging Face, Ollama, Google ADK.

**Achievements**: Winner — UI/UX Revamping, IIT Patna · Runner-Up — NIT Trichy ML Hackathon · Finalist — 100x Engineers GenAI Buildathon, AWS AI Ascend, ASME GRASP · Contributor — Toyota Mobility Foundation Smart Transit Challenge, Mesa.

> TODO (Nijeesh): add Spotify-for-Artists URL here to unlock the artist angle as verifiable proof.
