# Memory

Auto-curated by Hermes as it learns. Below are seeded facts; the agent will append/update over time.

## Deployment

- This Hermes lives at `codeNJ-hermes-octo.hf.space` on HF Spaces free tier (2 vCPU, 16 GB RAM).
- Stack: Hermes Agent + self-hosted Honcho + Neon Postgres (pgvector). One Docker container, four supervisord processes.
- All long-term memory persists in Neon. Container disk is ephemeral.
- LLM fallback chain: Z.AI GLM-4.7-Flash → Groq Llama 3.3 70B → Gemini 2.0 Flash → Gemini 1.5 Flash → OpenRouter Llama 3.3 70B free → local xLAM-1b-fc-r.
- Goal stated since 1st year of B.Tech: by end of 4th year, complete digital second-brain version of himself. This stack is v0 of that.

## Personal history (use as context, not chatter)

- Schooling timeline: Christ School (LKG–2nd) → Cathedral ICSE (3rd–4th) → St. Francis ICSE (5th–10th) → SJPUC (11th–12th, his best memories and friend circle) → Saveetha Engineering College.
- Switched from Christ/Cathedral/Francis to SJPUC for brand and rank. Hated AI initially, chose cyber-security, fell in love with AI later. View on Saveetha: doesn't matter for placements, the paper is the only point — output is what matters.
- JEE: 91 percentile mains attempt 1, 90 attempt 2. JEE Advanced — lost 3 marks from cutoff.
- Closest friend: Prajwal — gave him his first music-director shot for a short film. He treasures that experience.
- Childhood ambitions: businessman OR India-level karting racer OR music director. New ambition: "monster of my domain", calm-beast style.
- Tried hashing his first blockchain in 8th std in Java. Skipped it as too much then; the curiosity stayed.

## How he builds (observed patterns)

- **Systems brain + aesthete brain in one head.** Smart caching to stretch free APIs AND obsesses over font pairings (Mukta 800 + Instrument Sans). Both halves are him.
- **Anti-generic bias.** Picks psychedelic retro / pixel art / handwritten doodle over flat clean UI. Picks neon palettes (neon lime, hot pink, deep purple, cosmic black) over corporate.
- **Constraints as craft.** ₹0/month + no card is treated as creative design input, not a limitation.
- **Multi-project worker.** Several projects active at different stages — Nite, Flux, Just Us, StampForge Studio, this Hermes brain. Doesn't finish-one-then-start-another.
- **Polishes the final 10%** — status bar colors, splash screen, SVG edges, status of the small things others leave rough.
- **Builds for Indian users specifically** — metro context, NGO space, Zomato/Swiggy deep links.
- **Methodical debugger** — rules things out before asking why something's broken.

## Conventions for this repo

- Honcho peer identity: `nijeesh` (user) / `hermes` (AI). Pinned via `honcho-config.json`.
- `.env.example` must never contain real secrets — they go in HF Space settings only.
- HF Spaces has no IPv6 — entrypoint forces IPv4. Neon pooler URLs reject SQLAlchemy startup params — use direct connection only.
