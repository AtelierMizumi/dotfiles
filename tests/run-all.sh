#!/usr/bin/env bash
# Run shellcheck, every tests/test_*.sh and every tests/test_*.py, then print passed/failed/skipped totals.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 2

passed=0
failed=0
skipped=0

add_result_line() {
  local line="$1" p f s
  p=$(sed -n 's/.*passed=\([0-9]*\).*/\1/p' <<<"$line")
  f=$(sed -n 's/.*failed=\([0-9]*\).*/\1/p' <<<"$line")
  s=$(sed -n 's/.*skipped=\([0-9]*\).*/\1/p' <<<"$line")
  passed=$((passed + ${p:-0}))
  failed=$((failed + ${f:-0}))
  skipped=$((skipped + ${s:-0}))
}

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck scripts/*.sh scripts/dev/*.sh tests/*.sh tests/stubs/* niri/.config/niri/scripts/*; then
    echo "PASS shellcheck"
    passed=$((passed + 1))
  else
    echo "FAIL shellcheck"
    failed=$((failed + 1))
  fi
else
  echo "SKIP shellcheck (not installed)"
  skipped=$((skipped + 1))
fi

for test_file in tests/test_*.sh; do
  [[ -e "$test_file" ]] || continue
  echo "== $test_file"
  output=$(bash "$test_file" 2>&1)
  code=$?
  echo "$output"
  result=$(grep '^RESULT ' <<<"$output" | tail -n 1)
  if [[ -n "$result" ]]; then
    add_result_line "$result"
  fi
  if [[ $code -ne 0 && "$result" != *"failed="[1-9]* ]]; then
    failed=$((failed + 1))
  fi
done

# Python discovery exits 5 when no test file exists yet, so only run it once some exist.
if compgen -G "tests/test_*.py" >/dev/null; then
  echo "== python unittest"
  output=$(python3 -I -B -m unittest discover -s tests -p 'test_*.py' -v 2>&1)
  code=$?
  echo "$output"
  py_passed=$(grep -c ' \.\.\. ok$' <<<"$output")
  py_failed=$(grep -cE ' \.\.\. (FAIL|ERROR)$' <<<"$output")
  py_skipped=$(grep -c ' \.\.\. skipped' <<<"$output")
  passed=$((passed + py_passed))
  failed=$((failed + py_failed))
  skipped=$((skipped + py_skipped))
  if [[ $code -ne 0 && $py_failed -eq 0 ]]; then
    failed=$((failed + 1))
  fi
fi

echo "passed=$passed failed=$failed skipped=$skipped"
[[ $failed -eq 0 ]]
