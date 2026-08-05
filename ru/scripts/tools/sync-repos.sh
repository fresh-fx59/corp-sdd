#!/usr/bin/env bash
# sync-repos.sh — materialize, ADOPT and refresh local clones of every repo in repos.json.
#
#   bash tools/sync-repos.sh              # clone what is missing, adopt what is there, pull
#   bash tools/sync-repos.sh --prune      # also delete stray clones that hold no local work
#   bash tools/sync-repos.sh --prune --dry-run   # say what --prune would delete, delete nothing
#
# Safe by construction: ff-only pulls, never touches local work, and a clone that already
# exists is ADOPTED (checked, then pulled) — never re-cloned and never overwritten. A repo
# whose origin points somewhere else, or a directory that is not a clone at all, is reported
# with the exact one-line fix instead of being silently pulled from the wrong place.
# --prune refuses to delete anything holding uncommitted, unpushed or stashed work.
set -uo pipefail
cd "$(dirname "$0")/.."

PRUNE=0; DRYRUN=0
for a in "$@"; do
  case "$a" in
    --prune)   PRUNE=1 ;;
    --dry-run) DRYRUN=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "✗ unknown flag: $a (use --prune, --dry-run)"; exit 2 ;;
  esac
done

CLONES_DIR=$(node -e "console.log(require('./repos.json').clones_dir)")
mkdir -p "$CLONES_DIR"
fail=0
warn=0

# Compare remotes by MEANING, not by string: ssh://…/x.git, …/x.git/ and …/x are one repo.
norm() { printf '%s' "${1%/}" | sed -e 's#/*$##' -e 's#\.git$##'; }

repolist=$(node -e "const c=require('./repos.json');const seen=new Set();for(const r of c.repos){if(!/^[a-z0-9][a-z0-9._-]*\$/.test(r.name)||seen.has(r.name)){console.error('invalid/duplicate repo name: '+r.name);process.exit(2)}seen.add(r.name);console.log(r.name+' '+r.url)}") || { echo "✗ repos.json failed validation"; exit 2; }

configured=""
while read -r name url; do
  [ -z "$name" ] && continue
  configured="$configured $name"
  dir="$CLONES_DIR/$name"

  # --- a directory that is not a clone: never clone INTO it, never delete it -------------
  if [ -e "$dir" ] && [ ! -d "$dir/.git" ]; then
    echo "🔴 $name: $dir exists but is not a git clone"
    echo "     fix: mv \"$dir\" \"$dir.not-a-clone\"   # then re-run; nothing here is deleted for you"
    fail=1; continue
  fi

  # --- missing: clone --------------------------------------------------------------------
  if [ ! -d "$dir/.git" ]; then
    echo "cloning $name..."
    git clone --quiet "$url" "$dir" || { echo "🔴 $name: clone failed"; fail=1; continue; }
    echo "✓ $name (cloned)"
    continue
  fi

  # --- present: ADOPT it — prove it is the right repo before pulling anything -------------
  have=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
  if [ -z "$have" ]; then
    echo "🔴 $name: existing clone has no 'origin' remote"
    echo "     fix: git -C \"$dir\" remote add origin \"$url\""
    fail=1; continue
  fi
  if [ "$(norm "$have")" != "$(norm "$url")" ]; then
    echo "🔴 $name: existing clone points at a DIFFERENT repo — not pulling"
    echo "     on disk:   $have"
    echo "     repos.json: $url"
    echo "     fix: git -C \"$dir\" remote set-url origin \"$url\"   (or correct repos.json)"
    fail=1; continue
  fi

  git -C "$dir" fetch --quiet origin || { echo "🔴 $name: fetch failed"; fail=1; continue; }

  branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD || true)
  if [ -z "$branch" ]; then
    echo "⚠ $name: detached HEAD — adopted, but not pulled (drill-down may read stale files)"
    echo "     fix: git -C \"$dir\" checkout <branch>"
    warn=1; continue
  fi
  if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
    echo "⚠ $name: local changes on $branch — adopted, not pulled (drill-down may read stale files)"
    warn=1; continue
  fi
  if ! git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "⚠ $name: $branch has no upstream — adopted, not pulled"
    echo "     fix: git -C \"$dir\" branch --set-upstream-to=origin/$branch $branch"
    warn=1; continue
  fi
  before=$(git -C "$dir" rev-parse HEAD)
  if ! git -C "$dir" pull --quiet --ff-only; then
    echo "⚠ $name: cannot fast-forward $branch (diverged) — resolve manually"
    warn=1; continue
  fi
  after=$(git -C "$dir" rev-parse HEAD)
  if [ "$before" = "$after" ]; then echo "✓ $name (adopted, up to date)"
  else echo "↑ $name (adopted, fast-forwarded $(git -C "$dir" rev-list --count "$before..$after") commit(s))"; fi
done <<< "$repolist"

# --- strays: clones nobody listed. They are what a half-finished setup leaves behind, and
# they are read by nothing — but they are also where someone's only copy of a branch can be
# hiding, so they are never removed without proof that they hold no work. ------------------
strays=""
for d in "$CLONES_DIR"/*; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  case " $configured " in *" $n "*) continue ;; esac
  strays="$strays $n"
done

if [ -n "$strays" ]; then
  for n in $strays; do
    d="$CLONES_DIR/$n"
    reason=""
    if [ ! -d "$d/.git" ]; then reason="not a git clone"
    elif [ -n "$(git -C "$d" status --porcelain 2>/dev/null)" ]; then reason="uncommitted changes"
    elif [ -n "$(git -C "$d" log --branches --not --remotes --oneline 2>/dev/null | head -1)" ]; then reason="commits that exist nowhere else"
    elif [ -n "$(git -C "$d" stash list 2>/dev/null)" ]; then reason="stashed work"
    fi
    if [ "$PRUNE" -eq 0 ]; then
      echo "⚠ stray clone: $n — not in repos.json${reason:+ (holds $reason)}"
      warn=1
    elif [ -n "$reason" ]; then
      echo "⚠ stray clone: $n — REFUSING to delete: $reason"
      echo "     look at it first: git -C \"$d\" status && git -C \"$d\" log --branches --not --remotes --oneline"
      warn=1
    elif [ "$DRYRUN" -eq 1 ]; then
      echo "would delete stray clone: $d (no local work)"
    else
      rm -rf "$d" && echo "deleted stray clone: $d (no local work)"
    fi
  done
  [ "$PRUNE" -eq 0 ] && echo "   (run: bash tools/sync-repos.sh --prune --dry-run  to see what --prune would remove)"
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ sync finished with failures (see 🔴 above)"
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "✓ sync done → $CLONES_DIR (with warnings — see ⚠ above)"
  exit 0
fi
echo "✓ sync done → $CLONES_DIR"
