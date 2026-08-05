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

Reproducible source for the Russian HTML slide deck `../deck-ru-talk5.html` (the
5-minute solution talk). Data-driven: **one engine, content in JSON.**

> The 18-slide `deck-ru-leadership.html` and 21-slide `deck-ru-team.html` were **deleted
> on 2026-08-05**: built 2026-07-23, they predated every 2026-08-04/05 change (Zoekt in
> Phase 0, the OpenSpec root-resolution blocker, the `feature/ABCD-1234` conventions, the
> cross-repo fan-out, the four new guard scripts) and a stale deck that still exists is a
> deck that gets shown. Recoverable from git history if ever wanted; rebuild content from
> `docs/2026-08-05-corp-sdd-solution-handoff.md`, not from the old JSON.

## Files
- `deck-template.html` — the engine: CSS design system (two accents, light+dark themes),
  a data-driven renderer (12 slide layouts), keyboard nav, progress, height auto-fit,
  print-to-PDF. Placeholders: `/*__TOKENS_CSS__*/`, `/*__META_JSON__*/`, `/*__SLIDES_JSON__*/`.
- `build-decks.mjs` — injects per-deck color tokens + slide JSON into the template; emits a
  standalone `.html` (with `<head>`) **and** a `.artifact.html` (body-only, for the Artifact
  publisher) into `dist/`.
- `content/talk5.json` — the slide content (one array per deck).
  **This is the edit surface** — change wording here, not in the built HTML.

## Rebuild
```
node build-decks.mjs talk5                # -> dist/deck-ru-talk5.html (+ .artifact.html)
cp dist/deck-ru-talk5.html ../deck-ru-talk5.html
```
To re-publish an Artifact in-place, republish the matching `dist/*.artifact.html` with the
existing Artifact URL (see `../index.md`).

## Layouts (per slide `layout` field)
`title · bullets · statement · two-col · cards · stack · fanout · pipeline · timeline · table · map · closing`
See the schema comment block near the top of `deck-template.html`'s renderer.

## Provenance
Content written + adversarially verified by Opus subagents (content → verify → revise)
strictly from `docs/superpowers/specs/2026-07-17-corp-sdd-transition-design.md` and
`docs/superpowers/plans/2026-07-18-corp-sdd-team-playbook.md`. Generated 2026-07-22.
