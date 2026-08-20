---
description: Draft the delta spec(s) for a story via interview; fan out across repos when needed (analyst flow)
---
You are drafting the spec for story {{args}}.
Follow skills corp-drill-down (all system facts) and corp-verification (all done-claims).

1. READ + INTERVIEW, once. Fetch the story, wiki pages, and attachments through the configured
   tracker/wiki integration. If it is unavailable, use the user-provided export and mark missing
   evidence; never invent it. In every selected repository, set
   `REPO_ROOT="$(git rev-parse --show-toplevel)"` and run
   `bash "$REPO_ROOT/tools/repository-state.sh" inspect` before trusting local code. Read
   openspec/index.md and ONLY the living specs the story touches; follow
   corp-drill-down (central catalog → repo index → live files; repo wins; ≤3 hops). Verify every
   contract fact against live code. Interview the analyst — ONE question at a time,
   multiple-choice preferred — until requirements and Given/When/Then scenarios are unambiguous.
   Interview ONCE at story level even if several repos are involved: the requirements are shared,
   so interviewing per repo asks the same questions N times and invites N different answers.

2. DECIDE THE SHAPE, then CONFIRM before creating anything.
   Count the repos the story touches.
   - ONE repo → single-repo path. Go to step 3.
   - MORE THAN ONE repo → is there a genuine shared contract (a shape or protocol crossing the
     boundary)? If NOT, say "not a cross-repo change; this is N independent stories" and stop —
     do not fan out. If YES, go to step 4.
   Before creating any ticket, branch, commit or PR, state the plan and WAIT for the analyst:
   which repos, which is the producer, which tickets already exist, which you would create, and
   how many PRs this will open. Never fan out silently.

3. SINGLE REPO. Run `bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`; stop on failure.
   Create `feature/<TICKET>` from the prepared configured base, publish its upstream, then run
   `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <TICKET>`. Run
   `<opsx-new-command> <change-id>`, then `<opsx-continue-command> <change-id>` until both
   `proposal.md` and the delta `spec.md` exist. Stop before design and tasks. Append verified
   facts to research.md as pointers (path#Lx-Ly + one-line finding).
   Do NOT create design.md or tasks.md — planning happens at pull time.
   Run `bash "$REPO_ROOT/tools/verify-docs.sh"`; fix until green.
   HANDOVER (do this yourself — the analyst never touches git): commit the change folder, push, and
   open (or update) the spec PR. Post the spec summary + PR link back to the story. Done.

4. CROSS-REPO — TICKETS FIRST, driven by what already exists.
   Look at the child tickets attached to the parent story.
   - Children already exist → use them. Map each child to its repo. If a repo has no child, or a
     child names no repo, STOP and ask the analyst — never guess an owner.
   - No children exist → ask the analyst: "N repos are involved; shall I create one child story
     per repo, or will you?" Follow the answer. If they create them, wait and re-read.
   The PARENT story is the store-contract ticket — it does not get a child of its own.

5. CONTRACT FIRST. In the SYSTEM STORE, set
   `STORE_ROOT="$(git rev-parse --show-toplevel)"`, then run
   `bash "$STORE_ROOT/tools/repository-state.sh" prepare-base`. Create and publish
   `feature/<parent-ticket>`, then run
   `bash "$STORE_ROOT/tools/repository-state.sh" assert-change <parent-ticket>`. Run
   `<opsx-new-command> <contract-change-id>` then `<opsx-continue-command> <contract-change-id>`
   until its proposal and contract delta exist. Use `store-contract.md`; shape facts live there
   and nowhere else. Run `bash "$STORE_ROOT/tools/verify-docs.sh"`, commit, push, open the store PR, and
   post its link on the parent story.

6. PER REPO, one at a time:
   a. Set `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Run
      `bash "$REPO_ROOT/tools/repository-state.sh" prepare-base`, create and publish
      `feature/<child-ticket>`, then run
      `bash "$REPO_ROOT/tools/repository-state.sh" assert-change <child-ticket>`.
   b. Run `<opsx-new-command> <change-id>` then `<opsx-continue-command> <change-id>` until the
      proposal and that repo's OWN delta spec exist. The delta LINKS the store
      contract by spec id and store id — never restates the shape. Include the fetch line:
      `openspec show <contract-spec-id> --type spec --store <store-id>`
      Append verified facts to research.md as pointers. No design.md, no tasks.md.
   c. Run `bash "$REPO_ROOT/tools/verify-docs.sh"`; fix until green. The split-brain lint must pass; if it
      fires you restated a contract fact — delete it and link instead.
   d. Commit as feat(<child-ticket>): <text>, push, open the PR, post the PR link to the ticket.

7. GATES. On every implementation child record: approval order (contract first), implementation
   order (producer first), merge order (producer → consumers → store contract last), and that a
   contract change stops work in all repos. Mark each child blocked by the parent.

8. On the parent story, post the ticket → repo → role map and the intended merge window.

9. VERIFY before reporting: every child is linked and mapped to a repo; every repo has a branch,
   a pushed commit and an open PR; verify-docs green in each. Paste the evidence.
   Never claim done without it.
