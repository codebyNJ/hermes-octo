---
name: learn-simple
description: Trigger when Nijeesh wants to understand or learn a concept ("explain X", "how does X work", "ELI5", "I don't get X", "break down X", "teach me X"). Explain from the underlying mechanism up, in plain English, ALWAYS with a Mermaid diagram, and add a finance/markets lens where it fits.
version: 1.0.0
platforms: [api, cli]
category: personal
tags: [learning, explanation, mermaid, diagrams, finance]
---

# Learn Simple — mechanism-first, always drawn

## When to invoke

- "Explain / teach / break down / ELI5 / how does ___ work / I don't understand ___".
- He pastes a concept, term, snippet, or paper and wants to actually get it.

## How Nijeesh learns (respect this — it's in SOUL.md)

**Hardest-path learning: the gnarly mechanism first, the umbrella concept second.** Explain how the thing actually works underneath BEFORE naming the abstraction. Don't simplify away the mechanism to save him time — that defeats the point.

## What you do

1. **Plain-English first.** No jargon in the opening. If a technical term is needed, explain the idea, then drop the label at the end.
2. **Build from the mechanism up.** Start with the moving part / the loop / the data flow — what's literally happening — then zoom out to the named concept.
3. **ALWAYS include a Mermaid diagram.** Pick the type that fits:
   - `flowchart` — processes, data flow, decision logic
   - `sequenceDiagram` — request/response, who-calls-whom over time
   - `mindmap` — a concept and its branches
   - `stateDiagram-v2` — state machines, lifecycles
   - `erDiagram` — data models / schemas
   Keep node labels short. Verify the syntax is valid Mermaid before sending.
4. **Add a finance / markets lens when it genuinely clarifies** — an analogy to pricing, risk, compounding, supply/demand, or a real market example. Skip it if forced; never bolt it on for the sake of it.
5. **One worked example** grounded in something concrete (ideally his stack: Next.js, FastAPI, agents, LLMs).

## Output format

```
<2–4 sentence plain-English explanation, mechanism first>

```mermaid
<diagram>
```

Worked example: <one concrete example>

Finance lens: <one line — only if it actually clarifies>

The name for this: <the jargon term, dropped in last>
```

## What to avoid

- Leading with the abstraction or the jargon term.
- Walls of text — the diagram carries half the load.
- A diagram with 20 nodes; if it's that complex, split into two.
- Forcing a finance analogy that doesn't fit.
- Filler intros and recaps.
