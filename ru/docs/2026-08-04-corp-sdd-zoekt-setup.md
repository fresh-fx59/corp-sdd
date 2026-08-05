# Zoekt setup for corp SDD — pulled from Phase 2 into Phase 0

**Companion to:** [implementation guide](2026-07-18-corp-sdd-implementation-guide.md) · [design](../specs/2026-07-17-corp-sdd-transition-design.md) §13 item 1 · **Date:** 2026-08-04

**Why this exists.** The design scheduled Zoekt for Phase 2 ("when cross-repo work starts"). The
operator decided 2026-08-04 to pull it into **Phase 0**: the generated `openspec/index.md` indexes
*specs and modules only* — it never opens a source file — so on day 1 in a brownfield repo it holds
0 capabilities. Until living specs accumulate, cross-repo code search **is** the agent's map of the
estate.

**Verification status.** Everything in §1–§4 was executed on 2026-08-04 against **zoekt 3.7.2**
(`3.7.2-2-unstable-2025-11-20`, Apache-2.0) and **universal-ctags 6.2.1**, on a synthetic two-repo
estate (one multi-package JVM repo, one TypeScript frontend). Evidence in §7. Items marked
**TEMPLATE** were *not* executed — they need the real Bitbucket DC / the self-hosted CI.

---

## 1. Install (two binaries, no service dependencies)

Zoekt is a set of static Go binaries — no runtime, no database, no JVM. The whole estate needs:

| Binary | Role |
|---|---|
| `zoekt-git-index` | build/refresh index shards from a git clone |
| `zoekt-webserver` | serve search (HTML UI + JSON API) |
| `zoekt` | CLI search straight against an index dir (no server) |
| `zoekt-mirror-bitbucket-server` | clone every repo from a Bitbucket DC project — **ships in the box** |
| `universal-ctags` | **required** for `sym:` search — see §2 |

Restricted-network note: the release is source-only (Go 1.22+). Either build once on a
build host and distribute the binaries via the internal package channel, or vendor the module
cache into the internal Go proxy. `universal-ctags` is packaged by every distro.

## 2. The trap: `sym:` fails SILENTLY without ctags

This is the finding that costs a day if you meet it in production.

Index a JVM repo with no `ctags` on `PATH` and **everything reports success** — the indexer
prints `attempting to index 2 total files` / `finished shard …`, exit code 0, shards on disk,
substring search works perfectly. But every `sym:` query returns **zero results, with no error**.
An agent reads that as "this symbol does not exist in the estate".

Proven both ways (§7 T3/T4). Same repo, same query `sym:InvoiceService`:

```
# without ctags →   (no output, exit 0)
# with ctags    →   src/main/jvm/com/corp/billing/InvoiceService.jvm:3:public class InvoiceService {
```

Two defences, both mandatory:

1. **Always pass `-require_ctags`** to `zoekt-git-index`. It turns the silent degradation into a
   loud non-zero exit.
2. The indexer log line **`symbol analysis finished for shard statistics: … symbols=9`** appears
   only when ctags actually ran. Absence of that line = symbol search is dead. Grep for it in the
   the self-hosted CI job.

Why it matters here: `sym:` is the whole reason to run Zoekt next to grep. On the test repo,
substring `InvoiceService` returns **3 hits** (definition + import + field); `sym:InvoiceService`
returns **1** — the definition. That is jump-to-definition across the estate, which grep cannot do.

## 3. Indexing — reuse the store's clones, add no second mirror

The system store already materializes a clone of every repo in `repos.json` via
`tools/sync-repos.sh`. Zoekt indexes those clones directly. **`repos.json` stays the single list of
repos** — no separate Zoekt config, nothing to drift.

`tools/index-all.sh` (system store) — tested, both the failure and success path:

```bash
#!/usr/bin/env bash
# index-all.sh — rebuild the Zoekt index over every clone the system store already materializes.
# Companion to tools/sync-repos.sh: that script produces the clones, this one indexes them.
# Zero new mirroring: the store's repos.json stays the single list of repos.
set -euo pipefail

CLONES_DIR="${CLONES_DIR:-../clones}"        # same default as repos.json "clones_dir"
INDEX_DIR="${INDEX_DIR:-/var/lib/zoekt/index}"
ZOEKT_GIT_INDEX="${ZOEKT_GIT_INDEX:-zoekt-git-index}"

# HARD REQUIREMENT: universal-ctags must be on PATH or sym: queries silently return nothing.
# -require_ctags turns that silent degradation into a loud non-zero exit.
if ! command -v ctags >/dev/null 2>&1; then
  echo "✗ universal-ctags not on PATH — sym: search would be silently dead" >&2
  echo "  ↳ install universal-ctags on this host, then re-run" >&2
  exit 1
fi

mkdir -p "$INDEX_DIR"
rc=0
shopt -s nullglob
for repo in "$CLONES_DIR"/*/; do
  name="$(basename "$repo")"
  if [ ! -d "$repo/.git" ]; then
    echo "⚠ skip $name — not a git clone"
    continue
  fi
  echo "→ indexing $name"
  if ! ( cd "$repo" && "$ZOEKT_GIT_INDEX" -require_ctags -incremental -index "$INDEX_DIR" . ); then
    echo "✗ index FAILED for $name" >&2
    rc=1
  fi
done

shards=$(find "$INDEX_DIR" -name '*.zoekt' | wc -l)
echo "✓ index dir $INDEX_DIR holds $shards shard(s)"
exit "$rc"
```

Notes proven in test:

- **`-incremental`** (on by default) skips a repo whose shard is already current — a nightly
  re-run over an unchanged estate is nearly free.
- **Repo identity comes from the clone's directory name** (`pilot-repo-a_v16.00000.zoekt`), the
  same trap `openspec/repo.txt` exists to solve. Because `sync-repos.sh` names each clone from
  `repos.json` `"name"`, the two stay consistent — do not let anyone hand-clone into `clones/`.
- One shard per repo; `zoekt` and `zoekt-webserver` search **all shards in the index dir** at once.
  Cross-repo search needs no extra configuration.

**TEMPLATE — the self-hosted CI job.** Chain it after the existing catalog job so one nightly run refreshes
clones, catalog, and index together:

```
bash tools/sync-repos.sh && node tools/aggregate-index.mjs && bash tools/index-all.sh
```

**TEMPLATE — Bitbucket DC mirror**, only if you ever want Zoekt to cover repos the store does not
clone. Not tested (needs a live DC):

```
zoekt-mirror-bitbucket-server -url https://<bitbucket-dc> -project <KEY> \
  -dest /var/lib/zoekt/clones -credentials /etc/zoekt/.bitbucket-credentials -delete
```

## 4. Serving + the agent-facing contract

```bash
zoekt-webserver -index /var/lib/zoekt/index -listen 127.0.0.1:6070
```

Serves an HTML UI for humans and JSON for agents on the same port.

**The JSON endpoint is `GET /search?q=<query>&format=json&num=<n>`.** Verified. Note two things
that will otherwise cost an hour:

- `POST /api/search` in this build **returns the HTML page**, not JSON. Do not wire an agent to it.
- In the JSON, `.Line` is **always `null`**. The matched text lives in
  `Fragments[] = {Pre, Match, Post}`. Read the fragments, not `Line`.

Verified response shape:

```json
{
  "result": {
    "Stats": { "MatchCount": 3, "Duration": 212547, "FileCount": 1 },
    "FileMatches": [
      { "Repo": "pilot-repo-a",
        "FileName": "src/main/jvm/com/corp/billing/InvoiceService.jvm",
        "Matches": [
          { "LineNum": 3,
            "Fragments": [ { "Pre": "public class ", "Match": "InvoiceService", "Post": " {\n" } ] }
        ] }
    ]
  }
}
```

The HTML UI links to a `print?…#lNN` view — usable as the human-readable citation in `research.md`
when the agent reports where a fact came from. The `research.md` rule is unchanged: **pointers, not
payloads** (`path#Lstart-Lend` + a one-line finding).

### Query syntax the agent needs (all verified on the test estate)

| Query | Meaning |
|---|---|
| `createInvoice` | substring, case-insensitive by default |
| `sym:createInvoice` | **definition only** — needs ctags (§2) |
| `lang:jvm InvoiceService` | restrict by language |
| `f:billing amountCents` | restrict by file path |
| `r:pilot-repo-b invoice` | restrict to one repo |
| `case:yes InvoiceService` | force case-sensitive |
| `invoiceService\.[a-zA-Z]+\(` | bare regex — works, no flag needed |

Cross-repo is the default and is the point: one `case:no invoice` query returned hits from the JVM
service **and** the TypeScript frontend in a single result set.

## 5. Wiring it into the skills

Zoekt changes exactly one thing in `corp-drill-down`: the **cold-start** step. Today it reads
"search code (grep across local clones)". With Zoekt in Phase 0 it becomes a `sym:` lookup first,
then substring, then grep — and only then "STOP and ask a human which repo should own it".

The trust order does **not** change. Zoekt is a *router*, exactly like the central catalog: it tells
the agent which file to open. Only live code and living specs may be quoted as fact, and contract
shapes must still be embedded from source with `<!-- embed: path#Lx-Ly -->`.

Precedence against the deployed JVM LSP MCP: **LSP first for symbol questions inside one repo**
(types, real call graph), **Zoekt for breadth** (which repo, which module, does this string exist
anywhere). They answer different questions; keep both.

## 6. What is NOT proven

- The Bitbucket DC mirror and the self-hosted CI job (§3) — TEMPLATE, need the real systems.
- Scale. The test estate was 3 files. Sourcegraph runs Zoekt over very large corpora, but **index
  size, RAM, and full-reindex wall-clock on your JVM estate are unmeasured** — measure them on the
  first real pilot repo before sizing the host.
- Access control. `zoekt-webserver` has **no authentication**. Bind it to localhost or put it behind
  the corporate reverse proxy. An open instance exposes every indexed repo's source to anyone who
  can reach the port. Treat this as a Phase-0 blocker, not a nicety.
- Effect on agent answer quality — the design's claim ("largest agent-quality delta on a
  multi-module JVM estate") is a hypothesis. Baseline it during the Phase-0 smoke test.

## 7. Test evidence (2026-08-04, zoekt 3.7.2, universal-ctags 6.2.1)

| # | What | Result |
|---|---|---|
| T1 | `zoekt-git-index` a 2-file JVM repo | `2 files processed`, 5854 index bytes, 1 shard |
| T2 | substring search `createInvoice` | 2 hits (definition + call site) |
| T3 | `sym:InvoiceService` **without** ctags | **0 results, exit 0, no warning** — the silent trap |
| T4 | re-index with ctags on PATH, `-require_ctags` | log gains `symbol analysis finished … symbols=9`; `sym:InvoiceService` → 1 hit (definition only) |
| T5 | `lang:`, `f:`, `r:`, `case:`, bare regex atoms | all return the expected hits (§4 table) |
| T6 | `index-all.sh` with no ctags on PATH | `✗ universal-ctags not on PATH`, **exit 1** |
| T7 | `index-all.sh` over 2 clones, ctags present | both indexed, `✓ … holds 2 shard(s)`, exit 0 |
| T8 | cross-repo query `case:no invoice` over both shards | hits from the JVM repo **and** the TS repo in one result |
| T9 | `zoekt-webserver` HTML UI | HTTP 200 |
| T10 | `GET /search?q=…&format=json` | valid JSON, shape as §4 |
| T11 | `POST /api/search` | **returns HTML**, not JSON — do not use |
| T12 | `.Line` field in JSON | **always null**; text is in `Fragments[]` |
