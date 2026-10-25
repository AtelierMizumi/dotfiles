#!/usr/bin/env bash
# Runs the node tests of the shell's pure JavaScript libraries (tests/js/*/*.js, from SekaiPop's own test suite plus
# ours) and reports one PASS or FAIL per file. Only tests for files this fork keeps live there; see
# quickshell/.config/quickshell/mizu/UPSTREAM.md for the ones left out.
# MIZU_JS_TESTS_DIR points the runner at another directory (used by the runner's own test).
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TESTS=${MIZU_JS_TESTS_DIR:-$ROOT/tests/js}

passed=0
failed=0
skipped=0

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP all (node is not installed)"
  echo "RESULT passed=0 failed=0 skipped=1"
  exit 0
fi

shopt -s nullglob
files=("$TESTS"/*/*.js)
if ((${#files[@]} == 0)); then
  echo "FAIL no node tests found in $TESTS"
  echo "RESULT passed=0 failed=1 skipped=0"
  exit 1
fi

for file in "${files[@]}"; do
  name=${file#"$TESTS"/}
  [[ "$name" == lib/* ]] && continue # helpers, not tests
  if output=$(node "$file" 2>&1); then
    echo "PASS $name"
    passed=$((passed + 1))
  else
    echo "FAIL $name"
    printf '%s\n' "$output" | head -20 | while IFS= read -r line; do printf '    %s\n' "$line"; done
    failed=$((failed + 1))
  fi
done
echo "RESULT passed=$passed failed=$failed skipped=$skipped"
[[ $failed -eq 0 ]]
