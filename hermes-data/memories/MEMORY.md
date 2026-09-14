Skill installs → ~/.hermes/skills/<category>/<name>/SKILL.md via skill_manage create or write_file. Session skill loader cached — new skills visible next session. No git in container; fetch repos via mcp__github__get_file_contents.
§
Hermes deployment: codeNJ-hermes-octo.hf.space, HF Spaces free tier (2 vCPU/16GB), one Docker container, 4 supervisord processes — Hermes Agent + self-hosted Honcho + Neon Postgres (pgvector). Memory persists in Neon; container disk ephemeral.
§
LLM fallback: Z.AI GLM-4.7-Flash → Groq Llama3.3-70B → Gemini 2.0 Flash → Gemini 1.5 Flash → OpenRouter Llama3.3-70B free → local Hermes-3-Llama-3.2-3B.
§
Goal since 1st yr B.Tech: full digital second-brain of himself by end of 4th yr; this stack is v0.
§
Schools: Christ (LKG–2) → Cathedral ICSE (3–4) → St. Francis ICSE (5–10) → SJPUC (11–12, best memories/friend circle) → Saveetha Engg. Switched for brand+rank. Hated AI first (chose cyber-security), fell for AI later. Saveetha: paper is the point, output matters.
§
JEE: mains 91%ile then 90; Advanced missed cutoff by 3.
§
Closest friend Prajwal — gave him first music-director shot (short film); treasures it.
§
Old ambitions: businessman / karting racer / music director. New: 'monster of my domain', calm-beast style.
§
8th std: first blockchain hashing attempt in Java; shelved, curiosity stayed.
§
Builds: systems+aesthete brain — caching for free APIs AND font obsession (Mukta 800 + Instrument Sans). Anti-generic: retro/pixel/doodle over corporate; neon palettes. ₹0/month = design input. Parallel projects: Nite, Flux, Just Us, StampForge, this brain. Polishes final 10%. Builds for Indian users. Methodical debugger.
§
Repo conventions: Honcho peers `nijeesh`/`hermes` via honcho-config.json. .env.example never holds secrets. HF Spaces: no IPv6. Neon pooler URLs reject SQLAlchemy startup params — direct connection only.