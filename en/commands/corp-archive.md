---
description: Post-merge close-out — fold the delta into living specs, ADR, index (dev flow, on main)
---
Archive change {{args}}. Follow skill corp-verification (evidence for every step below).
Precondition: the change's PR is MERGED and you are on updated main —
verify both; if not, STOP.
1. Run the OpenSpec archive step (opsx archive) — delta folds into openspec/specs/.
2. Draft an ADR from the change's decisions (proposal "why" + research.md discoveries + any
   spec amendments) using the template in the harness pack; write to openspec/adr/NNNN-<slug>.md
   (next free number). ADRs are append-only: never edit an accepted ADR — supersede it.
3. Regenerate the index: node tools/gen-index.mjs
4. Run: bash tools/verify-docs.sh — must be green.
5. Commit ("archive <change-id>: living spec + ADR + index") and push. The store catalog picks
   this up on its next aggregation — no manual store edits, ever.
6. Post a one-line completion note to the tracker story via MCP.
