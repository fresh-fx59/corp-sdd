#!/usr/bin/env bash
# corp-sdd-version: 1.0.0
# repository-state.sh — inspect and enforce the Git state expected by Corp SDD.
# Never resets, cleans, rebases, force-checks out, mutates stashes, or deletes work.
set -uo pipefail

usage() {
  cat >&2 <<'EOF'
usage:
  bash repository-state.sh inspect [--repo <path>] [--base <branch>]
  bash repository-state.sh prepare-base [--repo <path>] [--base <branch>]
  bash repository-state.sh assert-change <TICKET> [--repo <path>] [--allow-dirty]
EOF
}

MODE=${1:-}
[ -n "$MODE" ] || { usage; exit 2; }
shift
TICKET=""
if [ "$MODE" = assert-change ]; then
  TICKET=${1:-}
  [ -n "$TICKET" ] || { usage; exit 2; }
  shift
fi

REPO="."
BASE_OVERRIDE="${CORP_BASE_BRANCH:-}"
ALLOW_DIRTY=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO=${2:-}; shift 2 ;;
    --base) BASE_OVERRIDE=${2:-}; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "✗ unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done
case "$MODE" in inspect|prepare-base|assert-change) ;; *) echo "✗ unknown mode: $MODE" >&2; usage; exit 2 ;; esac
if [ "$MODE" != assert-change ] && [ "$ALLOW_DIRTY" -eq 1 ]; then
  echo "✗ --allow-dirty is valid only with assert-change" >&2
  exit 2
fi

repo_top=$(git -C "$REPO" rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$repo_top" ]; then
  echo "✗ not a Git repository: $REPO" >&2
  exit 2
fi
REPO=$(cd "$repo_top" && pwd -P)

expected_base() {
  if [ -n "$BASE_OVERRIDE" ]; then
    printf '%s\n' "$BASE_OVERRIDE"
    return
  fi

  local super rel key branch
  branch=$(git -C "$REPO" config --local --get corp.baseBranch 2>/dev/null || true)
  if [ -n "$branch" ]; then
    printf '%s\n' "$branch"
    return
  fi

  super=$(git -C "$REPO" rev-parse --show-superproject-working-tree 2>/dev/null || true)
  if [ -n "$super" ] && [ -f "$super/.gitmodules" ]; then
    super=$(cd "$super" && pwd -P)
    rel=${REPO#"$super"/}
    key=$(git -C "$super" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
      | awk -v target="$rel" '$2 == target { print $1; exit }')
    if [ -n "$key" ]; then
      key=${key%.path}.branch
      branch=$(git -C "$super" config -f .gitmodules --get "$key" 2>/dev/null || true)
      if [ -n "$branch" ]; then printf '%s\n' "$branch"; return; fi
    fi
  fi

  if git -C "$REPO" show-ref --verify --quiet refs/remotes/origin/develop; then
    printf 'develop\n'
    return
  fi
  branch=$(git -C "$REPO" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
  branch=${branch#origin/}
  if [ -n "$branch" ]; then printf '%s\n' "$branch"; return; fi

  echo "✗ cannot determine the required base branch" >&2
  echo "  ↳ set branch in the parent .gitmodules, or pass --base <branch>" >&2
  return 1
}

BASE=$(expected_base) || exit 1
if ! git check-ref-format --branch "$BASE" >/dev/null 2>&1; then
  echo "✗ invalid expected base branch: $BASE" >&2
  exit 2
fi

branch=$(git -C "$REPO" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
upstream=$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
dirty=0
[ -n "$(git -C "$REPO" status --porcelain)" ] && dirty=1
stash_count=$(git -C "$REPO" stash list | wc -l | tr -d ' ')
ahead=0
behind=0
if [ -n "$upstream" ]; then
  counts=$(git -C "$REPO" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null || printf '0\t0')
  ahead=${counts%%[[:space:]]*}
  behind=${counts##*[[:space:]]}
fi

print_state() {
  printf 'repo=%s\n' "$REPO"
  printf 'expected_base=%s\n' "$BASE"
  printf 'branch=%s\n' "${branch:-DETACHED}"
  printf 'upstream=%s\n' "${upstream:-NONE}"
  printf 'dirty=%s\n' "$dirty"
  printf 'stash_count=%s\n' "$stash_count"
  printf 'ahead=%s\n' "$ahead"
  printf 'behind=%s\n' "$behind"
}

if [ "$MODE" = inspect ]; then
  print_state
  exit 0
fi

die_state() {
  echo "✗ $1" >&2
  shift
  for line in "$@"; do echo "$line" >&2; done
  echo "--- repository state ---" >&2
  print_state >&2
  exit 1
}

[ -n "$branch" ] || die_state "detached HEAD" "  ↳ inspect it: git -C \"$REPO\" log -1 --oneline"
if [ "$dirty" -eq 1 ] && { [ "$MODE" != assert-change ] || [ "$ALLOW_DIRTY" -eq 0 ]; }; then
  die_state "working tree is dirty" "  ↳ inspect it: git -C \"$REPO\" status --short"
fi
[ "$stash_count" -eq 0 ] || die_state "repository has $stash_count stash entry(s)" "  ↳ inspect them: git -C \"$REPO\" stash list"

if [ "$MODE" = prepare-base ]; then
  unpublished=$(git -C "$REPO" log --branches --not --remotes --oneline 2>/dev/null || true)
  if [ -n "$unpublished" ]; then
    die_state "repository has unpushed commit(s)" "  ↳ inspect them: git -C \"$REPO\" log --branches --not --remotes --oneline"
  fi

  git -C "$REPO" fetch --quiet origin || die_state "fetch from origin failed" "  ↳ check access: git -C \"$REPO\" fetch origin"
  if ! git -C "$REPO" show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
    die_state "origin/$BASE does not exist" "  ↳ inspect branches: git -C \"$REPO\" branch -r"
  fi

  if git -C "$REPO" show-ref --verify --quiet "refs/heads/$BASE"; then
    git -C "$REPO" checkout --quiet "$BASE" || die_state "cannot check out $BASE" "  ↳ inspect it: git -C \"$REPO\" status"
  else
    git -C "$REPO" checkout --quiet -b "$BASE" --track "origin/$BASE" \
      || die_state "cannot create local $BASE" "  ↳ inspect branches: git -C \"$REPO\" branch -avv"
  fi

  current_upstream=$(git -C "$REPO" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -z "$current_upstream" ]; then
    git -C "$REPO" branch --set-upstream-to="origin/$BASE" "$BASE" >/dev/null \
      || die_state "cannot set upstream for $BASE" "  ↳ run: git -C \"$REPO\" branch --set-upstream-to=origin/$BASE $BASE"
  elif [ "$current_upstream" != "origin/$BASE" ]; then
    die_state "$BASE tracks $current_upstream, expected origin/$BASE" \
      "  ↳ inspect it: git -C \"$REPO\" branch -vv"
  fi

  counts=$(git -C "$REPO" rev-list --left-right --count "HEAD...origin/$BASE")
  base_ahead=${counts%%[[:space:]]*}
  base_behind=${counts##*[[:space:]]}
  if [ "$base_ahead" -gt 0 ]; then
    die_state "$BASE has $base_ahead unpushed commit(s)" "  ↳ inspect them: git -C \"$REPO\" log origin/$BASE..$BASE --oneline"
  fi
  if [ "$base_behind" -gt 0 ]; then
    before=$(git -C "$REPO" rev-parse HEAD)
    git -C "$REPO" merge --quiet --ff-only "origin/$BASE" \
      || die_state "$BASE diverged from origin/$BASE" "  ↳ inspect it: git -C \"$REPO\" log --oneline --left-right $BASE...origin/$BASE"
    after=$(git -C "$REPO" rev-parse HEAD)
    echo "✓ fast-forwarded $BASE from ${before:0:12} to ${after:0:12}"
  else
    echo "✓ $BASE is clean and up to date"
  fi
  exit 0
fi

if [[ ! "$TICKET" =~ ^[A-Z][A-Z0-9]+-[0-9]+$ ]]; then
  echo "✗ invalid ticket '$TICKET'; expected ABCD-1234" >&2
  exit 2
fi
expected_change="feature/$TICKET"
[ "$branch" = "$expected_change" ] \
  || die_state "expected branch $expected_change, found ${branch:-DETACHED}" "  ↳ rename it only after review: git -C \"$REPO\" branch -m $expected_change"
[ -n "$upstream" ] \
  || die_state "$expected_change has no upstream" "  ↳ publish it: git -C \"$REPO\" push -u origin $expected_change"
[ "$upstream" = "origin/$expected_change" ] \
  || die_state "$expected_change tracks $upstream, expected origin/$expected_change" "  ↳ inspect it: git -C \"$REPO\" branch -vv"

git -C "$REPO" fetch --quiet origin || die_state "fetch from origin failed" "  ↳ check access: git -C \"$REPO\" fetch origin"
counts=$(git -C "$REPO" rev-list --left-right --count "HEAD...origin/$expected_change")
change_ahead=${counts%%[[:space:]]*}
change_behind=${counts##*[[:space:]]}
[ "$change_behind" -eq 0 ] \
  || die_state "$expected_change is behind origin by $change_behind commit(s)" \
    "  ↳ inspect it: git -C \"$REPO\" log --oneline --left-right HEAD...origin/$expected_change"
echo "✓ $expected_change is valid (ahead $change_ahead, behind 0, dirty $dirty)"
