---
title: SDD decks — source & rebuild
type: reference
status: active
created: 2026-07-22
updated: 2026-07-22
tags: [sdd, presentation, content, enterprise-sdd-agents]
links: []
---

# SDD decks — source

Reproducible source for the two Russian HTML slide decks (`../deck-ru-leadership.html`,
`../deck-ru-team.html`). Data-driven: **one engine, content in JSON.**

## Files
- `deck-template.html` — the engine: CSS design system (two accents, light+dark themes),
  a data-driven renderer (12 slide layouts), keyboard nav, progress, height auto-fit,
  print-to-PDF. Placeholders: `/*__TOKENS_CSS__*/`, `/*__META_JSON__*/`, `/*__SLIDES_JSON__*/`.
- `build-decks.mjs` — injects per-deck color tokens + slide JSON into the template; emits a
  standalone `.html` (with `<head>`) **and** a `.artifact.html` (body-only, for the Artifact
  publisher) into `dist/`.
- `content/leadership.json`, `content/team.json` — the slide content (one array per deck).
  **This is the edit surface** — change wording here, not in the built HTML.

## Rebuild
```
node build-decks.mjs leadership team      # -> dist/deck-ru-<key>.html (+ .artifact.html)
cp dist/deck-ru-leadership.html ../deck-ru-leadership.html
cp dist/deck-ru-team.html       ../deck-ru-team.html
```
To re-publish an Artifact in-place, republish the matching `dist/*.artifact.html` with the
existing Artifact URL (see `../index.md`).

## Layouts (per slide `layout` field)
`title · bullets · statement · two-col · cards · stack · fanout · pipeline · timeline · table · map · closing`
See the schema comment block near the top of `deck-template.html`'s renderer.

## Provenance
Content written + adversarially verified by Opus subagents (content → verify → revise)
strictly from `2026-07-17-corp-sdd-transition-design.md` and
`2026-07-18-corp-sdd-team-playbook.md`. Generated 2026-07-22.
