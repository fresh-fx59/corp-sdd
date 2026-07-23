#!/usr/bin/env bash
# verify-docs.sh — the disposer entry point. One code path, four triggers:
# agent post-write self-check / lefthook pre-commit / on demand / CI backstop.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
node tools/gen-index.mjs --check || fail=1
node tools/corp-lint.mjs || fail=1
if [ "$fail" -ne 0 ]; then
  echo "✗ verify-docs failed — fix the errors above (each carries a remediation hint), then retry"
  exit 1
fi
echo "✓ verify-docs passed"
