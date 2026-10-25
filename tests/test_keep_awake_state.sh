#!/usr/bin/env bash
# Tests for the Keep Awake bookkeeping: quickshell/.config/quickshell/mizu/scripts/state/keep-awake-state.sh and how
# QuickSource.qml starts the inhibitor. The state and the leftover cleanup belong to one runtime dir (a nested test
# session must not read or kill the real session's Keep Awake).
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/quickshell/.config/quickshell/mizu/scripts/state/keep-awake-state.sh"
QUICKSOURCE="$ROOT/quickshell/.config/quickshell/mizu/services/QuickSource.qml"

passed=0
failed=0

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

run_test() {
  local output code
  output=$("$1" 2>&1)
  code=$?
  if [[ $code -eq 0 ]]; then
    echo "PASS $1"
    passed=$((passed + 1))
  else
    echo "FAIL $1"
    echo "$output"
    failed=$((failed + 1))
  fi
}

t_state_lives_in_the_mizu_runtime_dir_when_one_is_given() {
  local tmp out
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  MIZU_RUNTIME_DIR="$tmp/run" XDG_RUNTIME_DIR="$tmp/xdg" sh "$SCRIPT" save on || fail "save failed"
  [[ -f "$tmp/run/keep-awake" ]] || fail "the state file is not in MIZU_RUNTIME_DIR"
  [[ ! -e "$tmp/xdg" ]] || fail "XDG_RUNTIME_DIR was touched although MIZU_RUNTIME_DIR was given"
  out=$(MIZU_RUNTIME_DIR="$tmp/run" sh "$SCRIPT" restore)
  [[ "$out" == "on" ]] || fail "restore printed '$out', expected 'on'"
}

t_state_defaults_to_the_xdg_runtime_dir() {
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  env -u MIZU_RUNTIME_DIR XDG_RUNTIME_DIR="$tmp" sh "$SCRIPT" save off || fail "save failed"
  [[ -f "$tmp/mizu/keep-awake" ]] || fail "the default state file is not under \$XDG_RUNTIME_DIR/mizu"
}

t_restore_only_ends_the_inhibitor_of_its_own_runtime_dir() {
  local tmp mine other
  tmp=$(mktemp -d)
  trap 'kill "$other" 2>/dev/null; rm -rf "$tmp"' EXIT

  # stdio redirected: a background process holding the test's pipe would keep run_test waiting for it
  sh -c "while sleep 60; do :; done # mizu-keep-awake $tmp/mine" >/dev/null 2>&1 &
  mine=$!
  sh -c "while sleep 60; do :; done # mizu-keep-awake $tmp/other" >/dev/null 2>&1 &
  other=$!
  sleep 0.3

  MIZU_RUNTIME_DIR="$tmp/mine" sh "$SCRIPT" restore >/dev/null
  sleep 0.3

  kill -0 "$mine" 2>/dev/null && fail "the inhibitor of this runtime dir is still running"
  kill -0 "$other" 2>/dev/null || fail "the inhibitor of another runtime dir was killed"
}

t_quicksource_marks_the_inhibitor_with_its_runtime_dir_and_ties_it_to_the_shell() {
  grep -q '"setpriv", "--pdeathsig", "TERM", "systemd-inhibit"' "$QUICKSOURCE" ||
    fail "the inhibitor must die with the shell (setpriv --pdeathsig TERM), or it outlives a quit and blocks idle"
  grep -q '# mizu-keep-awake ' "$QUICKSOURCE" || fail "the inhibitor marker does not carry the runtime dir"
}

t_the_nested_harness_gives_the_shell_its_own_runtime_dir() {
  grep -q 'MIZU_RUNTIME_DIR' "$ROOT/scripts/dev/nested-shell.sh" ||
    fail "nested-shell.sh does not set MIZU_RUNTIME_DIR for the shell it runs"
}

run_test t_state_lives_in_the_mizu_runtime_dir_when_one_is_given
run_test t_state_defaults_to_the_xdg_runtime_dir
run_test t_restore_only_ends_the_inhibitor_of_its_own_runtime_dir
run_test t_quicksource_marks_the_inhibitor_with_its_runtime_dir_and_ties_it_to_the_shell
run_test t_the_nested_harness_gives_the_shell_its_own_runtime_dir

echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
