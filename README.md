# Corporate SDD with AI agents — starter kit

A self-contained kit for rolling out **spec-driven development (SDD) with an AI coding
agent** across a whole engineering org — on a constrained, self-hosted setup: a model you
don't control, served through a shared OpenAI-compatible gateway, OSS-only tooling, dozens
of repositories, five roles who don't share a workflow (analysts, developers, manual
testers, SDETs, DevOps).

It combines a spec lifecycle ([OpenSpec](https://github.com/Fission-AI/OpenSpec), MIT) with
execution discipline (skills derived from the
[Superpowers](https://github.com/obra/superpowers) framework, MIT), anchored on one idea:

> **Model proposes, code disposes.** Prompts and skills are advisory; every rule you
> actually care about — a size budget, a schema, a contract that must match live code, a
> test that must pass — is enforced by a deterministic script (the "disposer"), not by a
> sentence in a prompt.

Background essay (public):
https://aiengineerhelper.com/posts/enterprise-spec-driven-development-ai-agents/

## Languages

| | |
|---|---|
| 🇬🇧 English | [`en/`](en/) |
| 🇷🇺 Русский | [`ru/`](ru/) |

The two trees are identical in substance; only the prose is translated. Code, file paths,
commands, scripts, and the slide structure are the same in both.

## What's in each tree

- **`docs/`** — the SDD docs, in read order: handoff → design → implementation guide →
  harness pack → team playbook → project log, followed by the 2026-08-04/05 amendments
  (OpenSpec root resolution, cross-repo fan-out, the executable setup task, code search).
  Start with `README.md` inside the tree.
- **`scripts/tools/`** — nine tested, zero-dependency scripts (Node + bash): the disposer
  (`verify-docs.sh`, `corp-lint.mjs`, `check-contract-split-brain.mjs`), the per-repo index
  generator (`gen-index.mjs`), the guards (`check-openspec-root.sh`, `check-git-naming.sh`),
  and the system-store aggregator + sync + search index (`aggregate-index.mjs`,
  `sync-repos.sh`, `index-all.sh`).
- **`commands/` · `skills/` · `templates/`** — seven `corp-*` command bodies, five vendored
  skills, and file templates. **These are templates** — adapt the command/skill invocation
  syntax to your own agent-CLI port before relying on them.
- **`config/`** — example `repos.json` (store clone manifest) and `lefthook.yml`
  (pre-commit hook).
- **`slides/`** — three self-contained decks (Russian): the 5-minute solution talk, one for
  leadership, one for the team. Open in any browser; editable source in `slides/src/`.

## The 5-minute talk, in your browser

**https://fresh-fx59.github.io/corp-sdd/** — the whole solution in ten slides: the story
flow, what appears on disk, the checks that reject bad writes, the single cross-repo
contract, the honest limits, and the hour it takes to set up per repo.
(← → to move, `T` for theme, `F` for full screen, Ctrl/Cmd+P for PDF.)

## Anonymization

This is a **generalized, anonymized** blueprint. It carries no employer name and no
employer-specific product stack: concrete products are described by category (a JVM estate,
stream-processing jobs, a columnar OLAP store, a self-hosted ALM suite, an OpenAI-compatible
gateway model, and so on). The agent CLI, config directory (`.agent/`), and context file
(`AGENT.md`) are neutral placeholders — rename them to whatever your org actually runs.

## Credits & license

Skills are derived from [Superpowers](https://github.com/obra/superpowers) (MIT); the spec
lifecycle is [OpenSpec](https://github.com/Fission-AI/OpenSpec) (MIT). Everything here is
offered under the MIT License — see [`LICENSE`](LICENSE).
