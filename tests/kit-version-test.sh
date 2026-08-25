#!/usr/bin/env bash
# Acceptance test for the shipped kit-edition versioning scheme.
# Identity is per kit edition, not per asset: `VERSION` holds the edition, every shipped
# command, skill and tool carries a matching `corp-version:` stamp, `MANIFEST.sha256` pins
# their exact bytes, and `scripts/tools/kit-version.sh` is the only reader.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf '  ✓ %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$1"; [ "${2:-}" = "" ] || printf '%s\n' "$2" | sed 's/^/      /'; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

for KIT in en ru; do
  ROOT="$REPO_ROOT/$KIT"
  KV="$ROOT/scripts/tools/kit-version.sh"

  printf 'T1 (%s) the kit declares one edition\n' "$KIT"
  if [ -f "$ROOT/VERSION" ] && [ -f "$ROOT/MANIFEST.sha256" ] && [ -f "$KV" ]; then
    pass "VERSION, MANIFEST.sha256 and kit-version.sh ship"
  else
    fail "the edition scheme is incomplete in $KIT"
  fi
  EDITION=$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null)
  out=$(bash "$KV" show 2>&1)
  if [ "$out" = "$EDITION" ]; then pass "kit-version.sh show reports $EDITION"; else fail "show printed '$out', VERSION holds '$EDITION'"; fi

  printf 'T2 (%s) every stamped file carries the edition\n' "$KIT"
  out=$(bash "$KV" check 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then pass "every command, skill and tool is stamped $EDITION"; else fail "stamp drift inside the kit" "$out"; fi

  printf 'T3 (%s) the manifest matches the shipped bytes\n' "$KIT"
  out=$(bash "$KV" verify 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then pass "MANIFEST.sha256 verifies"; else fail "a shipped file differs from the manifest" "$out"; fi

  printf 'T4 (%s) the manifest covers exactly the stamped files\n' "$KIT"
  listed=$(awk '{print $2}' "$ROOT/MANIFEST.sha256" | LC_ALL=C sort)
  stamped=$( { find "$ROOT/commands" -name '*.md' -type f
               find "$ROOT/skills" -name 'SKILL.md' -type f
               find "$ROOT/scripts/tools" -type f \( -name '*.sh' -o -name '*.mjs' \)
             } 2>/dev/null | sed "s|^$ROOT/||" | LC_ALL=C sort)
  if [ "$listed" = "$stamped" ]; then
    pass "no stamped file is missing from the manifest and none is stale"
  else
    fail "manifest and stamped-file sets differ" "$(diff <(echo "$listed") <(echo "$stamped"))"
  fi

  printf 'T5 (%s) identify separates pristine, modified and unstamped copies\n' "$KIT"
  cp "$ROOT/commands/corp-spec.md" "$WORK/pristine.md"
  cp "$ROOT/commands/corp-spec.md" "$WORK/modified.md"
  printf '\nlocal edit\n' >> "$WORK/modified.md"
  printf 'no stamp here\n' > "$WORK/unstamped.md"
  out=$(bash "$KV" identify "$WORK/pristine.md" 2>&1)
  if grep -q "pristine $EDITION" <<<"$out"; then pass "an untouched installed copy reads as pristine"; else fail "pristine copy misreported" "$out"; fi
  out=$(bash "$KV" identify "$WORK/modified.md" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'MODIFIED' <<<"$out"; then pass "a locally edited copy reads as MODIFIED"; else fail "modified copy misreported (rc=$rc)" "$out"; fi
  out=$(bash "$KV" identify "$WORK/unstamped.md" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'UNSTAMPED' <<<"$out"; then pass "a foreign copy reads as UNSTAMPED"; else fail "unstamped copy misreported (rc=$rc)" "$out"; fi
  rm -f "$WORK/pristine.md" "$WORK/modified.md" "$WORK/unstamped.md"
done

printf 'T6 both language kits ship the same edition\n'
if [ "$(tr -d '[:space:]' < "$REPO_ROOT/en/VERSION")" = "$(tr -d '[:space:]' < "$REPO_ROOT/ru/VERSION")" ]; then
  pass "en and ru are the same edition"
else
  fail "en and ru editions differ"
fi

printf 'T7 the retired per-asset semver markers are gone\n'
if command grep -rq -e 'corp-sdd-version:' -e '^version: [0-9]' "$REPO_ROOT/en" "$REPO_ROOT/ru" 2>/dev/null; then
  fail "a pre-edition version marker survives" "$(command grep -rn -e 'corp-sdd-version:' -e '^version: [0-9]' "$REPO_ROOT/en" "$REPO_ROOT/ru")"
else
  pass "only corp-version: stamps remain"
fi

printf '\nPASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
