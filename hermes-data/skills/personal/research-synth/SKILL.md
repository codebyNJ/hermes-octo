---
name: research-synth
description: Research a topic deeply by searching the web, fetching sources, cross-checking, and producing a concise synthesis with citations. Use when Nijeesh says "research X", "what's the current state of X", "compare X and Y", or any open-ended learning question that needs current info beyond your training data.
version: 1.0.0
platforms: [api, cli]
category: personal
tags: [research, learning, synthesis, web]
---

# Research Synthesis

## When to invoke

- User asks an open-ended question about a topic that needs **current** (post-training-cutoff) information
- User says "research", "look into", "what's the current state of", "compare", "review"
- User shares a URL and asks for analysis or context around it
- User is learning something new and wants a primer

## What you do

1. **Clarify scope in one line, then act.** Don't ask 3 questions. Ask at most one if truly ambiguous, otherwise pick a sensible scope and proceed.
2. **Search the web** (`search` toolset) with 2–4 distinct queries that approach the topic from different angles. Note: distinct angles, not paraphrases.
3. **Fetch the 3–5 most authoritative-looking sources** (`web` toolset). Prefer primary docs, recent papers, official repos. Skip SEO content farms and listicles.
4. **Cross-check facts across sources.** If two sources disagree, flag it.
5. **Synthesize.** Don't paste source content; combine into Nijeesh's voice.

## Output format

```
## Quick answer
<1–3 sentence direct answer>

## What I found
<3–6 bullets of the substantive findings — facts, not opinions about facts>

## Disagreements / uncertainty
<anything sources disagree on, or things still unclear — only if applicable>

## Sources
- [Title](url) — one-line why it's useful
- [Title](url) — ...
```

## What to avoid

- Filler intros ("Great question! Let me research…")
- Restating the question back at him
- Bullet lists when a sentence works
- Vague hedging ("It depends" without saying on what)
- More than 6 bullets in "What I found" — if you need more, you're not synthesizing

## When NOT to invoke

- Pure code questions with a clear answer (just answer it)
- Recall about Nijeesh himself (use Honcho memory, not web search)
- Questions where you already have high-confidence training-data knowledge
