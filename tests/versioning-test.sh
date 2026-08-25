#!/usr/bin/env bash
# versioning-test.sh — prove the version markers exist, the manifest is fresh,
# and the pre-commit hook bumps an edited asset automatically inside a real clone.
set -u
KIT_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd -P)}"
PASS=0; FAIL=0
pass() { printf '  ✓ %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL + 1)); }

printf 'T1 every asset carries a version marker and VERSIONS.md is current\n'
if (cd "$KIT_ROOT" && node tools/versions.mjs --check >/dev/null 2>&1); then pass "versions.mjs --check clean"; else fail "versions.mjs --check reported problems"; fi
if [ -f "$KIT_ROOT/VERSIONS.md" ]; then pass "VERSIONS.md present"; else fail "VERSIONS.md missing"; fi

printf 'T2 the hook bumps an edited asset on commit, with no prompting\n'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
CLONE="$TMP/clone"
git clone -q "$KIT_ROOT" "$CLONE" 2>/dev/null
cd "$CLONE" || { fail "clone failed"; exit 1; }
git config user.email t@t; git config user.name t; git config core.hooksPath .githooks
before="$(sed -n 's/^version:[[:space:]]*//p' en/skills/corp-tdd/SKILL.md | head -1)"
printf '\nedit for the versioning test.\n' >> en/skills/corp-tdd/SKILL.md
git add en/skills/corp-tdd/SKILL.md
git commit -qm 'test: edit a skill' >/dev/null 2>&1
after="$(sed -n 's/^version:[[:space:]]*//p' en/skills/corp-tdd/SKILL.md | head -1)"
if [ "$before" != "$after" ]; then pass "SKILL.md version bumped $before -> $after"; else fail "version not bumped (still $after)"; fi
if git show --stat --name-only HEAD | grep -q '^VERSIONS.md$'; then pass "VERSIONS.md committed with the change"; else fail "VERSIONS.md not in the commit"; fi
if grep -q "$after" VERSIONS.md; then pass "manifest lists the new version"; else fail "manifest not refreshed"; fi

printf 'T3 non-asset edits do not bump anything\n'
v_before="$(sed -n 's/^version:[[:space:]]*//p' en/commands/corp-spec.md | head -1)"
printf '\n' >> README.md; git add README.md; git commit -qm 'docs: touch readme' >/dev/null 2>&1
v_after="$(sed -n 's/^version:[[:space:]]*//p' en/commands/corp-spec.md | head -1)"
if [ "$v_before" = "$v_after" ]; then pass "untouched command kept $v_after"; else fail "unrelated bump $v_before -> $v_after"; fi

printf 'T4 the installed-versions reporter flags drift\n'
out="$(bash "$CLONE/en/scripts/tools/corp-versions.sh" --kit "$KIT_ROOT" "$CLONE/en/skills" 2>&1)"
if printf '%s' "$out" | grep -q 'corp-tdd/SKILL.md.*STALE'; then pass "drifted skill reported STALE"; else fail "drift not detected: $(printf '%s' "$out" | head -3)"; fi

printf 'T5 re-committing an unchanged asset does not bump it\n'
v1="$(sed -n 's/^version:[[:space:]]*//p' en/skills/corp-tdd/SKILL.md | head -1)"
touch en/skills/corp-tdd/SKILL.md
git add -f en/skills/corp-tdd/SKILL.md
git commit -qm 'chore: restage unchanged skill' >/dev/null 2>&1
v2="$(sed -n 's/^version:[[:space:]]*//p' en/skills/corp-tdd/SKILL.md | head -1)"
if [ "$v1" = "$v2" ]; then pass "unchanged asset kept $v2"; else fail "spurious bump $v1 -> $v2"; fi

printf 'T6 amending a commit does not bump a second time\n'
printf '\nsecond edit.\n' >> en/commands/corp-plan.md
git add en/commands/corp-plan.md
git commit -qm 'test: edit a command' >/dev/null 2>&1
a1="$(sed -n 's/^version:[[:space:]]*//p' en/commands/corp-plan.md | head -1)"
git commit -q --amend -m 'test: edit a command (amended)' >/dev/null 2>&1
a2="$(sed -n 's/^version:[[:space:]]*//p' en/commands/corp-plan.md | head -1)"
if [ "$a1" = "$a2" ]; then pass "amend kept $a2"; else fail "amend re-bumped $a1 -> $a2"; fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
