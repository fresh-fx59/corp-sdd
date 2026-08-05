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
