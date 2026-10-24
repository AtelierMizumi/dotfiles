#!/usr/bin/env bash
# Repo hygiene (review finding 7): no committed Python bytecode, and nothing in the repo writes it.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 2

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

t_no_tracked_bytecode() {
  local tracked
  tracked=$(git ls-files | grep -E '(^|/)__pycache__/|\.pyc$' || true)
  [[ -z "$tracked" ]] || fail "tracked bytecode files: $tracked"
}

t_gitignore_covers_bytecode() {
  git check-ignore -q scripts/__pycache__/example.cpython-314.pyc || fail "__pycache__ is not git-ignored"
}

t_python_is_run_without_writing_bytecode() {
  grep -q 'python3 -I -B' scripts/check-plasma-intact.sh || fail "check-plasma-intact.sh runs python3 without -B"
  grep -q 'python3 -I -B' tests/run-all.sh || fail "run-all.sh runs python3 without -B"
}

passed=0
failed=0
for name in $(compgen -A function | grep '^t_' | sort); do
  if ("$name"); then
    echo "PASS ${name#t_}"
    passed=$((passed + 1))
  else
    echo "FAIL ${name#t_}"
    failed=$((failed + 1))
  fi
done
echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
