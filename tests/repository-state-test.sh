#!/usr/bin/env bash
# Throwaway Git test for repository-state.sh. Uses local bare remotes only.
set -uo pipefail

SCRIPT="${1:?path to repository-state.sh}"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
no() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; printf '%s\n' "$2" | sed 's/^/      /'; }
G() { git -c init.defaultBranch=master -c user.email=test@example.invalid -c user.name=test -c commit.gpgsign=false "$@"; }

G init --quiet --bare "$TEST_ROOT/alpha.git"
G clone --quiet "$TEST_ROOT/alpha.git" "$TEST_ROOT/seed" 2>/dev/null
printf 'master\n' > "$TEST_ROOT/seed/state.txt"
G -C "$TEST_ROOT/seed" add state.txt
G -C "$TEST_ROOT/seed" commit --quiet -m master
G -C "$TEST_ROOT/seed" push --quiet origin master
G -C "$TEST_ROOT/seed" checkout --quiet -b develop
printf 'develop\n' >> "$TEST_ROOT/seed/state.txt"
G -C "$TEST_ROOT/seed" commit --quiet -am develop
G -C "$TEST_ROOT/seed" push --quiet origin develop

mkdir -p "$TEST_ROOT/store"
G -C "$TEST_ROOT/store" init --quiet
printf 'store\n' > "$TEST_ROOT/store/README.md"
G -C "$TEST_ROOT/store" add README.md
G -C "$TEST_ROOT/store" commit --quiet -m init
GIT_ALLOW_PROTOCOL=file G -C "$TEST_ROOT/store" submodule add --quiet --name alpha -b develop "$TEST_ROOT/alpha.git" submodules/alpha
G -C "$TEST_ROOT/store" config -f .gitmodules submodule.alpha.branch develop
G -C "$TEST_ROOT/store" add .gitmodules submodules/alpha
G -C "$TEST_ROOT/store" commit --quiet -m alpha
REPO="$TEST_ROOT/store/submodules/alpha"

run_state() {
  bash "$SCRIPT" "$@" --repo "$REPO" 2>&1
}

restore_repo() {
  G -C "$REPO" rebase --abort >/dev/null 2>&1 || true
  G -C "$REPO" merge --abort >/dev/null 2>&1 || true
  G -C "$REPO" reset --hard origin/develop >/dev/null
  G -C "$REPO" clean -fd >/dev/null
  G -C "$REPO" stash clear
  G -C "$REPO" checkout --quiet develop
  G -C "$REPO" branch --set-upstream-to=origin/develop develop >/dev/null
}

echo "T1 inspect discovers the configured submodule base branch"
out=$(run_state inspect); rc=$?
if [ "$rc" -eq 0 ] \
  && grep -q '^expected_base=develop$' <<<"$out" \
  && grep -q '^branch=develop$' <<<"$out" \
  && grep -q '^ahead=0$' <<<"$out" \
  && grep -q '^behind=0$' <<<"$out" \
  && grep -q '^untracked=0$' <<<"$out"; then
  ok "reported the real submodule state"
else
  no "inspect output was incomplete (rc=$rc)" "$out"
fi

echo "T2 prepare-base returns a clean temporary branch to develop"
G -C "$REPO" checkout --quiet -b feature/OLD-1
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 0 ] && [ "$(G -C "$REPO" branch --show-current)" = develop ]; then
  ok "prepared the configured base branch"
else
  no "prepare-base did not select develop (rc=$rc)" "$out"
fi

echo "T3 prepare-base refuses tracked dirty work and leaves the branch unchanged"
G -C "$REPO" checkout --quiet feature/OLD-1
printf 'dirty\n' >> "$REPO/state.txt"
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 1 ] && grep -q "uncommitted changes to TRACKED files" <<<"$out" \
  && [ "$(G -C "$REPO" branch --show-current)" = feature/OLD-1 ]; then
  ok "preserved dirty work"
else
  no "dirty work was not protected (rc=$rc)" "$out"
fi
restore_repo

echo "T4 prepare-base refuses detached HEAD"
G -C "$REPO" checkout --quiet --detach HEAD
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 1 ] && grep -q "detached HEAD" <<<"$out"; then
  ok "refused detached HEAD"
else
  no "detached HEAD was not rejected (rc=$rc)" "$out"
fi
restore_repo

echo "T5 prepare-base reports commits that exist on no remote and preserves them"
# Checking out the base neither moves nor deletes a commit on ANOTHER branch, so it is a
# warning, not a stop. The one case that could lose work — an unpushed commit on the base
# itself — is still refused; T7 covers it.
G -C "$REPO" checkout --quiet -b feature/LOCAL-1
printf 'local\n' > "$REPO/local.txt"
G -C "$REPO" add local.txt
G -C "$REPO" commit --quiet -m local
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 0 ] && grep -q "commit(s) exist on no remote" <<<"$out" \
  && [ "$(G -C "$REPO" branch --show-current)" = develop ] \
  && G -C "$REPO" show feature/LOCAL-1:local.txt >/dev/null 2>&1; then
  ok "warned about the local-only commit and left it intact"
else
  no "local-only commit was not reported or not preserved (rc=$rc)" "$out"
fi
G -C "$REPO" branch -D feature/LOCAL-1 >/dev/null 2>&1 || true
restore_repo

echo "T6 prepare-base fast-forwards a clean base"
printf 'remote\n' >> "$TEST_ROOT/seed/state.txt"
G -C "$TEST_ROOT/seed" commit --quiet -am remote
G -C "$TEST_ROOT/seed" push --quiet origin develop
expected=$(G -C "$TEST_ROOT/seed" rev-parse HEAD)
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 0 ] && [ "$(G -C "$REPO" rev-parse HEAD)" = "$expected" ] \
  && grep -q "fast-forwarded develop" <<<"$out"; then
  ok "fast-forwarded safely"
else
  no "clean base was not updated (rc=$rc)" "$out"
fi

echo "T7 prepare-base refuses a diverged base"
printf 'local-diverge\n' > "$REPO/local-diverge.txt"
G -C "$REPO" add local-diverge.txt
G -C "$REPO" commit --quiet -m local-diverge
printf 'remote-diverge\n' > "$TEST_ROOT/seed/remote-diverge.txt"
G -C "$TEST_ROOT/seed" add remote-diverge.txt
G -C "$TEST_ROOT/seed" commit --quiet -m remote-diverge
G -C "$TEST_ROOT/seed" push --quiet origin develop
out=$(run_state prepare-base); rc=$?
if [ "$rc" -eq 1 ] && grep -q "unpushed commit" <<<"$out"; then
  ok "stopped before changing a diverged base"
else
  no "divergence was not rejected (rc=$rc)" "$out"
fi
G -C "$REPO" reset --hard HEAD^ >/dev/null
restore_repo

echo "T8 assert-change accepts the exact tracked feature branch"
G -C "$REPO" checkout --quiet -b feature/DEMO-123
G -C "$REPO" push --quiet -u origin feature/DEMO-123
out=$(run_state assert-change DEMO-123); rc=$?
if [ "$rc" -eq 0 ] && grep -q "feature/DEMO-123 is valid" <<<"$out"; then
  ok "accepted the expected change branch"
else
  no "valid change branch was rejected (rc=$rc)" "$out"
fi

echo "T9 assert-change rejects the wrong ticket branch"
out=$(run_state assert-change DEMO-999); rc=$?
if [ "$rc" -eq 1 ] && grep -q "expected branch feature/DEMO-999" <<<"$out"; then
  ok "rejected the wrong ticket"
else
  no "wrong ticket was not rejected (rc=$rc)" "$out"
fi

echo "T10 assert-change permits dirty implementation state only when explicit"
printf 'work\n' >> "$REPO/state.txt"
blocked=$(run_state assert-change DEMO-123); blocked_rc=$?
allowed=$(run_state assert-change DEMO-123 --allow-dirty); allowed_rc=$?
if [ "$blocked_rc" -eq 1 ] && grep -q "uncommitted changes to TRACKED files" <<<"$blocked" \
  && [ "$allowed_rc" -eq 0 ]; then
  ok "required explicit dirty-state permission"
else
  no "dirty-state mode was incorrect" "$blocked\n$allowed"
fi

echo "T11 a standalone repository uses its durable corp.baseBranch setting"
G -C "$TEST_ROOT/seed" config corp.baseBranch master
out=$(bash "$SCRIPT" inspect --repo "$TEST_ROOT/seed" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && grep -q '^expected_base=master$' <<<"$out"; then
  ok "used the repository-local base branch"
else
  no "ignored corp.baseBranch (rc=$rc)" "$out"
fi

echo "T12 untracked files never block a gate, and inspect counts them"
restore_repo
G -C "$REPO" checkout --quiet feature/DEMO-123
printf 'scratch\n' > "$REPO/scratch.local"
seen=$(run_state inspect); seen_rc=$?
gated=$(run_state assert-change DEMO-123); gated_rc=$?
if [ "$seen_rc" -eq 0 ] && grep -q '^untracked=1$' <<<"$seen" \
  && [ "$gated_rc" -eq 0 ] && grep -q "untracked file(s) present" <<<"$gated" \
  && [ -f "$REPO/scratch.local" ]; then
  ok "counted the untracked file, warned, and let the gate pass"
else
  no "untracked handling was incorrect (inspect rc=$seen_rc, gate rc=$gated_rc)" "$seen\n$gated"
fi
rm -f "$REPO/scratch.local"
restore_repo

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
