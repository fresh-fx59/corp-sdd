---
description: Draft a delta spec from a tracker story via interview (analyst flow)
---
You are drafting a delta spec for story {{args}}.
1. Fetch the story and linked wiki pages via the tracker/wiki MCP tools.
2. Read openspec/index.md, then ONLY the living specs the story touches; follow skill
   corp-drill-down (central catalog → repo index → live files; repo wins; ≤3 hops).
3. Verify every contract fact against live code (embed with <!-- embed --> directives).
4. Interview the analyst — ONE question at a time, multiple-choice preferred — until
   requirements and Given/When/Then scenarios are unambiguous.
5. Create the OpenSpec change (proposal + delta spec) via the opsx workflow.
   Append every verified fact as a pointer line to research.md (path#Lx-Ly + finding).
6. Run: bash tools/verify-docs.sh — fix until green.
7. HANDOVER (do this yourself — the analyst never touches git): create/switch to the
   change branch, commit the change folder, push, and open (or update) the spec PR.
   Post the spec summary + PR link back to the tracker story. Do NOT create design.md
   or tasks.md (plan happens at pull time).
