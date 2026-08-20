#!/usr/bin/env bash
set -u

SCRIPT="${1:?path to verify-docs.sh}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
REPO="$TEST_ROOT/repo"
BIN="$TEST_ROOT/bin"
LOG="$TEST_ROOT/node.log"
mkdir -p "$REPO/tools" "$REPO/nested/work" "$BIN"
git -C "$REPO" init --quiet
cp "$SCRIPT" "$REPO/tools/verify-docs.sh"
for name in gen-index.mjs corp-lint.mjs check-contract-split-brain.mjs; do : > "$REPO/tools/$name"; done
printf '#!/usr/bin/env bash\nprintf "%%s|%%s\\n" "$PWD" "$1" >> "$VERIFY_PATH_LOG"\n' > "$BIN/node"
chmod +x "$BIN/node"

out=$(cd "$REPO/nested/work" && PATH="$BIN:$PATH" VERIFY_PATH_LOG="$LOG" \
  bash "$REPO/tools/verify-docs.sh" 2>&1); rc=$?
REPO_REAL="$(cd "$REPO" && pwd -P)"
expected="$REPO_REAL/tools"
if [ "$rc" -eq 0 ] \
  && [ "$(wc -l < "$LOG" | tr -d ' ')" = 3 ] \
  && awk -F'|' -v root="$REPO_REAL" -v tools="$expected" '$1 != root || index($2, tools "/") != 1 { exit 1 }' "$LOG"; then
  echo "PASS=1 FAIL=0"
else
  echo "PASS=0 FAIL=1"
  printf '%s\n' "$out"
  [ -f "$LOG" ] && cat "$LOG"
  exit 1
fi
