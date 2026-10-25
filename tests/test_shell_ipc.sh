#!/usr/bin/env bash
# Tests for niri/.config/niri/scripts/shell-start and niri/.config/niri/scripts/shell-ipc.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHELL_START="$ROOT/niri/.config/niri/scripts/shell-start"
SHELL_IPC="$ROOT/niri/.config/niri/scripts/shell-ipc"

passed=0
failed=0

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

run_test() {
  local name="$1"
  local output code
  output=$( "$name" 2>&1 )
  code=$?
  if [[ $code -eq 0 ]]; then
    echo "PASS $name"
    passed=$((passed + 1))
  else
    echo "FAIL $name"
    echo "$output"
    failed=$((failed + 1))
  fi
}

setup_env() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/bin" "$TMP/config/niri"
  LOG="$TMP/calls.log"
  : >"$LOG"

  cat >"$TMP/bin/noctalia" <<EOF
#!/usr/bin/env bash
echo "noctalia: LC_TIME=\${LC_TIME-} args: \$*" >>"$LOG"
EOF
  chmod +x "$TMP/bin/noctalia"

  cat >"$TMP/bin/qs" <<EOF
#!/usr/bin/env bash
echo "qs: LC_TIME=\${LC_TIME-} args: \$*" >>"$LOG"
EOF
  chmod +x "$TMP/bin/qs"

  cat >"$TMP/bin/quickshell" <<EOF
#!/usr/bin/env bash
echo "quickshell: LC_TIME=\${LC_TIME-} args: \$*" >>"$LOG"
EOF
  chmod +x "$TMP/bin/quickshell"

  cat >"$TMP/bin/wpctl" <<EOF
#!/usr/bin/env bash
echo "wpctl: args: \$*" >>"$LOG"
EOF
  chmod +x "$TMP/bin/wpctl"
}

t_scripts_exist_and_are_executable() {
  [[ -x "$SHELL_START" ]] || fail "shell-start not executable"
  [[ -x "$SHELL_IPC" ]] || fail "shell-ipc not executable"
}

t_shell_start_defaults_to_noctalia() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  # No shell file
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_START"
  grep -q 'noctalia: LC_TIME=ja_JP.UTF-8' "$LOG" || fail "noctalia not started with LC_TIME"

  # Empty shell file
  : >"$LOG"
  : >"$TMP/config/niri/shell"
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_START"
  grep -q 'noctalia: LC_TIME=ja_JP.UTF-8' "$LOG" || fail "empty shell file did not default to noctalia"

  # Garbage shell file
  : >"$LOG"
  echo "bogus" >"$TMP/config/niri/shell"
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_START"
  grep -q 'noctalia: LC_TIME=ja_JP.UTF-8' "$LOG" || fail "garbage shell file did not default to noctalia"
}

t_shell_start_runs_mizu_when_configured() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo "mizu" >"$TMP/config/niri/shell"
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_START"
  grep -q 'qs: LC_TIME=ja_JP.UTF-8 args: -c mizu' "$LOG" || fail "mizu not started via qs with LC_TIME"
}

t_shell_ipc_dispatches_noctalia() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo "noctalia" >"$TMP/config/niri/shell"

  local actions=(
    "launcher|noctalia:.*args: msg panel-toggle launcher"
    "quick|noctalia:.*args: msg panel-toggle control-center"
    "settings|noctalia:.*args: msg settings-toggle"
    "clipboard|noctalia:.*args: msg panel-toggle clipboard"
    "dnd|noctalia:.*args: msg notification-dnd-toggle"
    "lock|noctalia:.*args: msg session lock"
    "volume-up|noctalia:.*args: msg volume-up"
    "volume-down|noctalia:.*args: msg volume-down"
    "volume-mute|noctalia:.*args: msg volume-mute"
    "mic-mute|wpctl: args: set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    "brightness-up|noctalia:.*args: msg brightness-up"
    "brightness-down|noctalia:.*args: msg brightness-down"
    "media-play|noctalia:.*args: msg media toggle"
    "media-next|noctalia:.*args: msg media next"
    "media-prev|noctalia:.*args: msg media previous"
    "wallpaper-next|noctalia:.*args: msg wallpaper-random"
  )

  for item in "${actions[@]}"; do
    local action="${item%%|*}"
    local pattern="${item#*|}"
    : >"$LOG"
    PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_IPC" "$action"
    grep -qE "$pattern" "$LOG" || fail "$action did not match: $pattern (got: $(cat "$LOG"))"
  done
}

t_shell_ipc_dispatches_mizu() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo "mizu" >"$TMP/config/niri/shell"

  local actions=(
    "launcher|qs:.*args: -c mizu ipc call mizu launcher"
    "quick|qs:.*args: -c mizu ipc call mizu quick"
    "settings|qs:.*args: -c mizu ipc call mizu settings"
    "clipboard|qs:.*args: -c mizu ipc call mizu clipboard"
    "dnd|qs:.*args: -c mizu ipc call mizu dnd"
    "lock|qs:.*args: -c mizu ipc call mizu lock"
    "volume-up|qs:.*args: -c mizu ipc call mizu volumeUp"
    "volume-down|qs:.*args: -c mizu ipc call mizu volumeDown"
    "volume-mute|qs:.*args: -c mizu ipc call mizu volumeMute"
    "mic-mute|qs:.*args: -c mizu ipc call mizu micMute"
    "brightness-up|qs:.*args: -c mizu ipc call mizu brightnessUp"
    "brightness-down|qs:.*args: -c mizu ipc call mizu brightnessDown"
    "media-play|qs:.*args: -c mizu ipc call mizu mediaPlay"
    "media-next|qs:.*args: -c mizu ipc call mizu mediaNext"
    "media-prev|qs:.*args: -c mizu ipc call mizu mediaPrev"
    "wallpaper-next|qs:.*args: -c mizu ipc call mizu wallpaperNext"
    "palette|qs:.*args: -c mizu ipc call mizu palette"
  )

  for item in "${actions[@]}"; do
    local action="${item%%|*}"
    local pattern="${item#*|}"
    : >"$LOG"
    PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_IPC" "$action"
    grep -qE "$pattern" "$LOG" || fail "$action did not match: $pattern (got: $(cat "$LOG"))"
  done

  # Test with wallpaper argument
  : >"$LOG"
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_IPC" wallpaper "/path/to/wall.png"
  grep -qE 'qs:.*args: -c mizu ipc call mizu wallpaper /path/to/wall.png' "$LOG" || fail "wallpaper path not passed"
}

t_unknown_action_fails() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo "mizu" >"$TMP/config/niri/shell"
  ! PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SHELL_IPC" "nonexistent-action" >/dev/null 2>&1 \
    || fail "unknown action should exit non-zero"
}

# A fake `qs` that exits with the next code of $TMP/codes (one per line; 0 when the list is used up) and logs each run.
fake_qs_with_exit_codes() {
  printf '%s\n' "$@" >"$TMP/codes"
  cat >"$TMP/bin/qs" <<EOF
#!/usr/bin/env bash
echo "qs run" >>"$LOG"
code=\$(head -n 1 "$TMP/codes" 2>/dev/null)
sed -i 1d "$TMP/codes"
exit \${code:-0}
EOF
  chmod +x "$TMP/bin/qs"
}

run_shell_start() {
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" MIZU_RESTART_DELAY=0 bash "$SHELL_START"
}

t_shell_start_restarts_mizu_after_a_crash() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo mizu >"$TMP/config/niri/shell"
  fake_qs_with_exit_codes 139 1 0

  run_shell_start || fail "shell-start failed although the third run exited cleanly"

  [[ $(grep -c 'qs run' "$LOG") -eq 3 ]] || fail "expected 3 runs (2 crashes, then a clean exit), got $(grep -c 'qs run' "$LOG")"
}

t_shell_start_does_not_restart_after_a_clean_exit() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo mizu >"$TMP/config/niri/shell"
  fake_qs_with_exit_codes 0

  run_shell_start || fail "shell-start failed after a clean exit"

  [[ $(grep -c 'qs run' "$LOG") -eq 1 ]] || fail "a clean exit must not restart the shell"
}

t_shell_start_gives_up_on_a_crash_loop() {
  setup_env
  trap 'rm -rf "$TMP"' EXIT
  echo mizu >"$TMP/config/niri/shell"
  fake_qs_with_exit_codes 1 1 1 1 1 1 1 1 1 1

  if run_shell_start; then
    fail "a shell that crashes at once every time must make shell-start fail"
  fi

  [[ $(grep -c 'qs run' "$LOG") -eq 5 ]] || fail "expected 5 tries before giving up, got $(grep -c 'qs run' "$LOG")"
}

run_test t_scripts_exist_and_are_executable
run_test t_shell_start_restarts_mizu_after_a_crash
run_test t_shell_start_does_not_restart_after_a_clean_exit
run_test t_shell_start_gives_up_on_a_crash_loop
run_test t_shell_start_defaults_to_noctalia
run_test t_shell_start_runs_mizu_when_configured
run_test t_shell_ipc_dispatches_noctalia
run_test t_shell_ipc_dispatches_mizu
run_test t_unknown_action_fails

echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
