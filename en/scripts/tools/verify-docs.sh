#!/usr/bin/env bash
# corp-version: 2026-08-26.8
# verify-docs.sh — the disposer entry point. One code path, four triggers:
# agent post-write self-check / lefthook pre-commit / on demand / CI backstop.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"; fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
cd "$REPO_ROOT"
fail=0
node "$REPO_ROOT/tools/gen-index.mjs" --check || fail=1
node "$REPO_ROOT/tools/corp-lint.mjs" || fail=1
node "$REPO_ROOT/tools/check-contract-split-brain.mjs" || fail=1   # no-op in repos with no references:
if [ "$fail" -ne 0 ]; then
  echo "✗ verify-docs failed — fix the errors above (each carries a remediation hint), then retry"
  exit 1
fi
echo "✓ verify-docs passed"
