#!/usr/bin/env bash
# sync-repos.sh — materialize/refresh local clones of every repo in repos.json.
# Safe: ff-only pulls, never touches local work; reports repos that are behind/dirty.
set -uo pipefail
cd "$(dirname "$0")/.."
CLONES_DIR=$(node -e "console.log(require('./repos.json').clones_dir)")
mkdir -p "$CLONES_DIR"
fail=0
repolist=$(node -e "const c=require('./repos.json');const seen=new Set();for(const r of c.repos){if(!/^[a-z0-9][a-z0-9._-]*\$/.test(r.name)||seen.has(r.name)){console.error('invalid/duplicate repo name: '+r.name);process.exit(2)}seen.add(r.name);console.log(r.name+' '+r.url)}") || { echo "✗ repos.json failed validation"; exit 2; }
while read -r name url; do
  [ -z "$name" ] && continue
  dir="$CLONES_DIR/$name"
  if [ ! -d "$dir/.git" ]; then
    echo "cloning $name..."
    git clone --quiet "$url" "$dir" || { echo "🔴 $name: clone failed"; fail=1; continue; }
  else
    ( cd "$dir"
      git fetch --quiet origin || { echo "🔴 $name: fetch failed"; exit 1; }
      if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠ $name: local changes — skipped pull (drill-down may read stale files here)"
      elif ! git pull --quiet --ff-only; then
        echo "⚠ $name: cannot fast-forward (diverged) — resolve manually"
      fi
    ) || fail=1
  fi
done <<< "$repolist"
if [ "$fail" -ne 0 ]; then
  echo "✗ sync finished with failures (see 🔴 above)"
  exit 1
fi
echo "✓ sync done → $CLONES_DIR"
