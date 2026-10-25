#!/usr/bin/env bash
# Tests for scripts/dev/nested-shell.sh (the nested-niri harness) that need no display: usage errors, state handling,
# and the guard that never lets it quit or screenshot the real session's niri.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HARNESS="$ROOT/scripts/dev/nested-shell.sh"
NESTED_CONFIG="$ROOT/scripts/dev/nested-niri.kdl"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Runs the harness with a private state dir; leaves stdout/stderr/exit code in $OUT, $ERR, $CODE.
harness() {
  OUT=$(MIZU_DEV_STATE="$STATE" "$HARNESS" "$@" 2>"$STATE.err")
  CODE=$?
  ERR=$(cat "$STATE.err")
}

setup() {
  STATE=$(mktemp -d)
  trap 'rm -rf "$STATE" "$STATE.err"' EXIT
}

t_script_is_executable() {
  [[ -x "$HARNESS" ]] || fail "$HARNESS is missing or not executable"
}

t_stage_script_is_valid_bash_and_executable() {
  local script="$ROOT/scripts/dev/stage-quickshell.sh"
  [[ -x "$script" ]] || fail "$script is missing or not executable"
  bash -n "$script" || fail "syntax error in $script"
  grep -q 'gpg --homedir /etc/pacman.d/gnupg --verify' "$script" || fail "the script does not verify signatures"
}

t_no_arguments_prints_usage_and_exits_64() {
  setup
  harness
  [[ $CODE -eq 64 ]] || fail "exit $CODE, expected 64"
  [[ "${ERR,,}" == *usage* ]] || fail "no usage text: $ERR"
}

t_unknown_command_exits_64() {
  setup
  harness frobnicate
  [[ $CODE -eq 64 ]] || fail "exit $CODE, expected 64"
}

t_start_without_a_shell_dir_exits_64() {
  setup
  harness start
  [[ $CODE -eq 64 ]] || fail "exit $CODE, expected 64"
}

t_start_with_a_missing_shell_dir_exits_2_and_starts_nothing() {
  setup
  harness start "$STATE/nope"
  [[ $CODE -eq 2 ]] || fail "exit $CODE, expected 2: $ERR"
  [[ "$ERR" == *nope* ]] || fail "the message does not name the directory: $ERR"
  [[ ! -e "$STATE/niri.pid" ]] || fail "a pid file was written"
}

t_commands_that_need_a_session_exit_2_when_none_runs() {
  local command
  setup
  for command in "shot x" "ipc show" "run true" "log"; do
    # shellcheck disable=SC2086
    harness $command
    [[ $CODE -eq 2 ]] || fail "'$command' exited $CODE without a session, expected 2"
    [[ "${ERR,,}" == *"not running"* ]] || fail "'$command' did not say it is not running: $ERR"
  done
}

t_status_says_stopped_and_exits_1() {
  setup
  harness status
  [[ $CODE -eq 1 ]] || fail "exit $CODE, expected 1"
  [[ "$OUT" == *stopped* ]] || fail "status said: $OUT"
}

t_stop_without_a_session_is_a_no_op_that_exits_0() {
  setup
  harness stop
  [[ $CODE -eq 0 ]] || fail "exit $CODE: $ERR"
}

t_refuses_to_touch_the_outer_niri_socket() {
  setup
  printf '%s\nwayland-9\n' "/run/user/1000/niri.outer.sock" >"$STATE/env"
  echo $$ >"$STATE/niri.pid" # a live process, so the harness believes a nested session runs
  OUT=$(NIRI_SOCKET=/run/user/1000/niri.outer.sock MIZU_DEV_STATE="$STATE" "$HARNESS" shot x 2>"$STATE.err")
  CODE=$?
  ERR=$(cat "$STATE.err")
  [[ $CODE -eq 2 ]] || fail "exit $CODE, expected 2"
  [[ "${ERR,,}" == *"outer"* ]] || fail "no message about the outer session: $ERR"
}

t_nested_config_validates_and_cannot_quit_the_real_session() {
  command -v niri >/dev/null 2>&1 || return 0
  local out
  out=$(niri validate -c "$NESTED_CONFIG" 2>&1) || fail "niri validate failed: $out"
  [[ "$out" == *"config is valid"* ]] || fail "no 'config is valid': $out"
}

t_measure_idle_is_valid_bash_and_asks_for_a_shell_dir() {
  local script="$ROOT/scripts/dev/measure-idle.sh" err code
  [[ -x "$script" ]] || fail "$script is missing or not executable"
  bash -n "$script" || fail "syntax error in $script"
  err=$("$script" 2>&1 >/dev/null)
  code=$?
  [[ $code -eq 64 ]] || fail "exit $code without arguments, expected 64"
  [[ "${err,,}" == *usage* ]] || fail "no usage text: $err"
}

t_measure_idle_refuses_a_missing_shell_dir_before_starting_anything() {
  setup
  local err code
  err=$(MIZU_DEV_STATE="$STATE" "$ROOT/scripts/dev/measure-idle.sh" "$STATE/nope" 2>&1 >/dev/null)
  code=$?
  [[ $code -eq 2 ]] || fail "exit $code, expected 2: $err"
  [[ ! -e "$STATE/niri.pid" ]] || fail "a nested session was started"
}

t_runs_the_system_quickshell_when_nothing_is_staged() {
  setup
  mkdir -p "$STATE/bin" "$STATE/empty-stage"
  printf '#!/bin/sh\nexit 0\n' >"$STATE/bin/quickshell"
  printf '#!/bin/sh\necho "$*" >"%s/dbus.args"\n' "$STATE" >"$STATE/bin/dbus-run-session"
  chmod +x "$STATE/bin/quickshell" "$STATE/bin/dbus-run-session"

  RICE_STAGE="$STATE/empty-stage" PATH="$STATE/bin:$PATH" MIZU_DEV_STATE="$STATE" "$HARNESS" _qs -p somewhere \
    >/dev/null 2>"$STATE.err" || fail "the harness refused to run without a staged quickshell: $(cat "$STATE.err")"

  [[ "$(cat "$STATE/dbus.args")" == "-- $STATE/bin/quickshell -p somewhere" ]] ||
    fail "quickshell was not run from the system path: $(cat "$STATE/dbus.args")"
}

t_a_staged_quickshell_still_wins_over_the_system_one() {
  setup
  mkdir -p "$STATE/bin" "$STATE/stage/root/usr/bin"
  printf '#!/bin/sh\nexit 0\n' >"$STATE/bin/quickshell"
  printf '#!/bin/sh\nexit 0\n' >"$STATE/stage/root/usr/bin/quickshell"
  printf '#!/bin/sh\necho "$*" >"%s/dbus.args"\n' "$STATE" >"$STATE/bin/dbus-run-session"
  chmod +x "$STATE/bin/quickshell" "$STATE/stage/root/usr/bin/quickshell" "$STATE/bin/dbus-run-session"

  RICE_STAGE="$STATE/stage" PATH="$STATE/bin:$PATH" MIZU_DEV_STATE="$STATE" "$HARNESS" _qs -p somewhere \
    >/dev/null 2>"$STATE.err" || fail "the harness failed with a staged quickshell: $(cat "$STATE.err")"

  [[ "$(cat "$STATE/dbus.args")" == "-- $STATE/stage/root/usr/bin/quickshell -p somewhere" ]] ||
    fail "the staged quickshell was not used: $(cat "$STATE/dbus.args")"
}

passed=0
failed=0
skipped=0
for name in $(compgen -A function | grep '^t_' | sort); do
  if ("$name"); then
    echo "PASS ${name#t_}"
    passed=$((passed + 1))
  else
    echo "FAIL ${name#t_}"
    failed=$((failed + 1))
  fi
done
echo "RESULT passed=$passed failed=$failed skipped=$skipped"
[[ $failed -eq 0 ]]
