#!/usr/bin/env bash
# corp-sdd-version: 1.0.0
# corp-versions.sh — report which Corp SDD asset versions are installed on this machine.
# Reads the version marker each asset carries in its own header, so it works on any copy:
#   Markdown frontmatter `version: X.Y.Z` (commands, skills)
#   `# corp-sdd-version: X.Y.Z` / `// corp-sdd-version: X.Y.Z` (scripts)
# Usage:
#   bash corp-versions.sh <path> [<path>...]              list installed versions
#   bash corp-versions.sh --kit <kit-root> <path>...      also compare against the kit and flag drift
# Paths may be files or directories (commands dir, skills dir, tools dir).
# Exit 0 when nothing is stale, 1 when a drift or a missing marker is found.
set -uo pipefail

KIT=""
if [ "${1:-}" = "--kit" ]; then KIT="${2:?--kit needs a path}"; shift 2; fi
if [ "$#" -eq 0 ]; then
  echo "usage: corp-versions.sh [--kit <kit-root>] <path> [<path>...]" >&2
  exit 2
fi

read_version() {
  # $1 = file. Prints the version or nothing.
  case "$1" in
    *.md)  sed -n '1,40p' "$1" | sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)[[:space:]]*$/\1/p' | head -1 ;;
    *)     sed -n '1,40p' "$1" | sed -n 's|^\(#\|//\) corp-sdd-version:[[:space:]]*\([0-9][0-9.]*\)[[:space:]]*$|\2|p' | head -1 ;;
  esac
}

kit_version() {
  # $1 = asset basename hint (relative name). Finds the same asset inside the kit.
  [ -n "$KIT" ] || return 0
  local match
  match="$(find "$KIT" -type f -path "*$1" 2>/dev/null | head -1)"
  [ -n "$match" ] && read_version "$match"
}

rc=0
printf '%-46s %-10s %-10s %s\n' 'ASSET' 'INSTALLED' 'KIT' 'STATE'
for target in "$@"; do
  if [ -f "$target" ]; then files="$target"
  elif [ -d "$target" ]; then files="$(find "$target" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.mjs' \) | LC_ALL=C sort)"
  else
    printf '%-46s %-10s %-10s %s\n' "$target" '-' '-' 'MISSING'; rc=1; continue
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    v="$(read_version "$f")"
    rel="${f#$target/}"
    case "$f" in */SKILL.md) key="$(basename "$(dirname "$f")")/SKILL.md" ;; *) key="$(basename "$f")" ;; esac
    kv="$(kit_version "$key")"
    if [ -z "$v" ]; then state=UNVERSIONED; rc=1
    elif [ -z "$KIT" ] || [ -z "$kv" ]; then state=ok
    elif [ "$v" = "$kv" ]; then state=current
    else state=STALE; rc=1
    fi
    printf '%-46s %-10s %-10s %s\n' "$key" "${v:--}" "${kv:--}" "$state"
  done <<EOL
$files
EOL
done
exit $rc
