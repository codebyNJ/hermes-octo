---
name: gtm-research
description: Trigger for go-to-market or market-analysis questions ("market size for X", "who are the competitors", "is there demand for X", "GTM for my product", "TAM/SAM", "research this company/space"). Runs on the always-on Exa web search; flag the specialist MCPs for a deep dive.
version: 1.0.0
platforms: [api, cli]
category: personal
tags: [gtm, market, research, finance, competitors]
---

# GTM / Market Research

## When to invoke

- Market sizing, demand validation, competitor landscape, pricing, positioning.
- "Research this company / this space / this market", "should I build X", "who else does this".

## What you do (lean — native Exa search)

1. **Frame the question in one line**: market, segment, geography, time horizon. Then act.
2. **Search from distinct angles** (`web_search`, Exa-backed) — market size, competitors, pricing, recent funding/news. Distinct angles, not paraphrases.
3. **Extract the 3–5 best sources** (`web_extract`) — prefer primary: analyst reports, company sites, filings, recent news. Skip listicles.
4. **Cross-check numbers.** Market-size figures vary wildly by source — give a range and name who said what. Flag disagreement, don't average blindly.
5. **For a deep dive**, tell Nijeesh to flip on the specialist MCPs (off by default for the free-model budget):
   - `exa` MCP → `company_research_exa`, `competitor_finder`, `linkedin_search_exa`, `deep_search_exa`
   - `yahoo-finance` MCP → real fundamentals / comparables for sizing
   Then re-run with those tools.

## Output format

```
## Read
<2–3 sentence direct take: is there a market, how big, how contested>

## Market
<size range with sources> · <growth/trend>

## Competitors
- <name> — <what they do / gap they leave>

## Angle for Nijeesh
<where the opening is, given his stack and constraints — 2–3 lines>

## Sources
- [Title](url) — why it matters
```

## What to avoid

- A single unsourced TAM number stated as fact.
- Generic "the market is growing" filler.
- More than ~5 competitors — pick the ones that define the space.
- Recommending he validate with "a survey" — give a sharper, faster signal.
