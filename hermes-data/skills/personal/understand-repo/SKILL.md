---
name: understand-repo
description: Trigger when Nijeesh pastes a GitHub repo/file/PR link and wants to understand it ("what does this repo do", "explain this codebase", "how does this work", "read this repo"). Works with the always-on GitHub + web tools; no special MCP needed.
version: 1.0.0
platforms: [api, cli]
category: personal
tags: [github, code, learning]
metadata:
  hermes:
    requires_toolsets: [mcp-github]
---

# Understand a Repo

## When to invoke

- A GitHub link is pasted with intent to understand: a repo, a file, a PR, a directory.
- "Explain this codebase / what does X do / how is this built".

## What you do (lean — uses only always-on tools)

1. **Orient first, don't read everything.** Pull the README and repo metadata via the `mcp-github` tools (get file contents, list files). Identify: what it does, the entry point, the main directories.
2. **Trace the mechanism, not every file.** Follow the entry point inward. Read the 3–5 files that actually carry the logic. Use GitHub code search to locate a function rather than scanning blind.
3. **For docs-heavy or unfamiliar libraries**, fall back to `web_extract` on the repo's README/raw files or docs site. (For a deep multi-file Q&A session, ask Nijeesh to flip the `gitmcp` MCP to `enabled: true` — it's built for exactly this but is off by default to save the free-model tool budget.)
4. **Explain it his way** — mechanism-first, plain English, and a **Mermaid diagram** of the architecture or data flow (see learn-simple). Cite real file paths + line numbers.

## Output format

```
What it does: <1–2 lines>

How it works:
```mermaid
<flowchart or sequence of the core flow>
```
<3–5 bullets walking the mechanism, each citing path:line>

Where to start reading: <the one file/function to open first>
```

## What to avoid

- Summarizing the README back verbatim — explain the mechanism it doesn't.
- Reading every file. Find the load-bearing ones.
- Skipping the diagram.
