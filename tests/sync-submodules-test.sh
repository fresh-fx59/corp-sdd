#!/usr/bin/env bash
# Throwaway Git test for sync-submodules.sh. Uses local bare remotes only.
set -uo pipefail

SCRIPT="${1:?path to sync-submodules.sh}"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
no() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; printf '%s\n' "$2" | sed 's/^/      /'; }
G() { git -c init.defaultBranch=master -c user.email=test@example.invalid -c user.name=test -c commit.gpgsign=false "$@"; }

make_remote() {
  local name=$1
  G init --quiet --bare "$TEST_ROOT/forge/$name.git"
  G clone --quiet "$TEST_ROOT/forge/$name.git" "$TEST_ROOT/seed-$name" 2>/dev/null
  printf '%s\n' "$name" > "$TEST_ROOT/seed-$name/README.md"
  G -C "$TEST_ROOT/seed-$name" add README.md
  G -C "$TEST_ROOT/seed-$name" commit --quiet -m init
  G -C "$TEST_ROOT/seed-$name" push --quiet origin master
  G -C "$TEST_ROOT/seed-$name" checkout --quiet -b develop
  printf 'develop\n' >> "$TEST_ROOT/seed-$name/README.md"
  G -C "$TEST_ROOT/seed-$name" commit --quiet -am develop
  G -C "$TEST_ROOT/seed-$name" push --quiet origin develop
}

mkdir -p "$TEST_ROOT/forge"
make_remote alpha
make_remote beta
make_remote gamma

mkdir -p "$TEST_ROOT/system-store"
G -C "$TEST_ROOT/system-store" init --quiet
printf '# store\n' > "$TEST_ROOT/system-store/README.md"
G -C "$TEST_ROOT/system-store" add README.md
G -C "$TEST_ROOT/system-store" commit --quiet -m init

write_inventory() {
  local body=$1
  printf '{"schema_version":1,"project":"DEMO","repositories":%s}\n' "$body" > "$TEST_ROOT/inventory.json"
}

run_sync() {
  GIT_ALLOW_PROTOCOL=file bash "$SCRIPT" \
    --inventory "$TEST_ROOT/inventory.json" \
    --store-root "$TEST_ROOT/system-store" 2>&1
}

write_inventory "[
  {\"name\":\"alpha\",\"url\":\"$TEST_ROOT/forge/alpha.git\",\"base_branch\":\"develop\"},
  {\"name\":\"beta\",\"url\":\"$TEST_ROOT/forge/beta.git\",\"base_branch\":\"master\"}
]"

echo "T1 materializes project-bound repositories as named submodules"
out=$(run_sync); rc=$?
if [ "$rc" -eq 0 ] \
  && [ "$(G -C "$TEST_ROOT/system-store" config -f .gitmodules --get submodule.alpha.path)" = "submodules/alpha" ] \
  && [ "$(G -C "$TEST_ROOT/system-store" config -f .gitmodules --get submodule.beta.path)" = "submodules/beta" ] \
  && [ -f "$TEST_ROOT/system-store/submodules/alpha/.git" ]; then
  ok "created submodules/alpha and submodules/beta"
else
  no "submodules were not created (rc=$rc)" "$out"
fi

echo "T2 records the required base branch in .gitmodules and checks it out"
if [ "$(G -C "$TEST_ROOT/system-store" config -f .gitmodules --get submodule.alpha.branch)" = "develop" ] \
  && [ "$(G -C "$TEST_ROOT/system-store/submodules/alpha" branch --show-current)" = "develop" ] \
  && [ "$(G -C "$TEST_ROOT/system-store/submodules/beta" branch --show-current)" = "master" ]; then
  ok "stored and checked out configured branches"
else
  no "base branch was not applied" "$out"
fi

echo "T3 repeat runs are idempotent"
G -C "$TEST_ROOT/system-store" add .gitmodules submodules/alpha submodules/beta
G -C "$TEST_ROOT/system-store" commit --quiet -m submodules
out=$(run_sync); rc=$?
status=$(G -C "$TEST_ROOT/system-store" status --porcelain)
if [ "$rc" -eq 0 ] && [ -z "$status" ]; then
  ok "repeat run changed nothing"
else
  no "repeat run changed the store (rc=$rc)" "$out\n$status"
fi

echo "T4 a mismatched registered URL fails before changing the submodule"
G -C "$TEST_ROOT/system-store" config -f .gitmodules submodule.alpha.url "$TEST_ROOT/forge/gamma.git"
out=$(run_sync); rc=$?
if [ "$rc" -eq 1 ] \
  && grep -q "alpha: registered URL does not match project inventory" <<<"$out" \
  && [ "$(G -C "$TEST_ROOT/system-store/submodules/alpha" remote get-url origin)" = "$TEST_ROOT/forge/alpha.git" ]; then
  ok "refused the mismatched registration"
else
  no "mismatched URL was not rejected safely (rc=$rc)" "$out"
fi
G -C "$TEST_ROOT/system-store" config -f .gitmodules submodule.alpha.url "$TEST_ROOT/forge/alpha.git"
G -C "$TEST_ROOT/system-store" checkout -- .gitmodules

echo "T5 invalid inventory fails before adding anything"
write_inventory "[{\"name\":\"../escape\",\"url\":\"$TEST_ROOT/forge/gamma.git\",\"base_branch\":\"master\"}]"
before=$(find "$TEST_ROOT/system-store/submodules" -mindepth 1 -maxdepth 1 -type d | sort)
out=$(run_sync); rc=$?
after=$(find "$TEST_ROOT/system-store/submodules" -mindepth 1 -maxdepth 1 -type d | sort)
if [ "$rc" -eq 2 ] && grep -q "invalid repository name" <<<"$out" && [ "$before" = "$after" ]; then
  ok "input gate rejected path traversal"
else
  no "invalid inventory was not rejected atomically (rc=$rc)" "$out"
fi

echo "T6 bindings removed from inventory are reported but never deleted"
write_inventory "[{\"name\":\"alpha\",\"url\":\"$TEST_ROOT/forge/alpha.git\",\"base_branch\":\"develop\"}]"
out=$(run_sync); rc=$?
if [ "$rc" -eq 0 ] && grep -q "orphaned submodule binding: beta" <<<"$out" \
  && [ -d "$TEST_ROOT/system-store/submodules/beta" ]; then
  ok "reported and preserved the orphan"
else
  no "orphan handling is unsafe or silent (rc=$rc)" "$out"
fi

echo "T7 a plain directory at a target path is never overwritten"
write_inventory "[
  {\"name\":\"alpha\",\"url\":\"$TEST_ROOT/forge/alpha.git\",\"base_branch\":\"develop\"},
  {\"name\":\"delta\",\"url\":\"$TEST_ROOT/forge/gamma.git\",\"base_branch\":\"master\"}
]"
mkdir -p "$TEST_ROOT/system-store/submodules/delta"
printf 'keep\n' > "$TEST_ROOT/system-store/submodules/delta/important.txt"
out=$(run_sync); rc=$?
if [ "$rc" -eq 1 ] && grep -q "delta: target exists but is not a registered submodule" <<<"$out" \
  && [ "$(cat "$TEST_ROOT/system-store/submodules/delta/important.txt")" = "keep" ]; then
  ok "preserved the foreign directory"
else
  no "foreign directory was not handled safely (rc=$rc)" "$out"
fi

echo "T8 an installed tool defaults to its own system-store root"
mkdir -p "$TEST_ROOT/system-store/tools"
cp "$SCRIPT" "$TEST_ROOT/system-store/tools/sync-submodules.sh"
write_inventory "[{\"name\":\"alpha\",\"url\":\"$TEST_ROOT/forge/alpha.git\",\"base_branch\":\"develop\"}]"
out=$(cd "$TEST_ROOT" && GIT_ALLOW_PROTOCOL=file bash "$TEST_ROOT/system-store/tools/sync-submodules.sh" \
  --inventory "$TEST_ROOT/inventory.json" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && grep -q "$TEST_ROOT/system-store/submodules" <<<"$out"; then
  ok "derived the installed store root"
else
  no "installed default root was wrong (rc=$rc)" "$out"
fi

echo "T9 first setup works before the system-store has its first commit"
mkdir -p "$TEST_ROOT/unborn-store"
G -C "$TEST_ROOT/unborn-store" init --quiet
write_inventory "[{\"name\":\"alpha\",\"url\":\"$TEST_ROOT/forge/alpha.git\",\"base_branch\":\"develop\"}]"
out=$(GIT_ALLOW_PROTOCOL=file bash "$SCRIPT" \
  --inventory "$TEST_ROOT/inventory.json" \
  --store-root "$TEST_ROOT/unborn-store" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && [ "$(G -C "$TEST_ROOT/unborn-store" config -f .gitmodules --get submodule.alpha.path)" = "submodules/alpha" ] \
  && [ "$(G -C "$TEST_ROOT/unborn-store/submodules/alpha" branch --show-current)" = "develop" ]; then
  ok "initialized submodules in an unborn system-store"
else
  no "first setup requires an undocumented initial commit (rc=$rc)" "$out"
fi

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
