#!/usr/bin/env bash
# Tests for niri/.config/niri/scripts/apps-start: the apps launch in the order browser -> coding -> entertainment, a
# missing app is skipped without blocking the rest, Waydroid's UI starts only when its container and session run,
# Antigravity moves to the coding workspace only on a single monitor, and the script ends on the browser workspace.
# PATH holds only fake binaries and symlinks to the few tools the script needs, so a real app installed on this
# machine cannot leak into a test. Launches are checked in apps-start's own log, which is written before each launch;
# niri and waydroid calls are checked in $CALLS, which the fakes write synchronously.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/niri/.config/niri/scripts/apps-start"
BASH_BIN=$(command -v bash)

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Builds fake binaries in a temporary PATH and runs apps-start once. Inputs, all optional environment variables:
#   FAKE_OUTPUTS (default 2)       number of outputs niri reports
#   FAKE_WINDOW                    id of an Antigravity window niri reports; empty means no window
#   FAKE_CONTAINER / FAKE_SESSION  Waydroid status (default STOPPED)
#   MISSING_APPS                   space-separated app names to leave out of PATH
# Outputs: CALLS (niri and waydroid calls, one per line), LOG (apps-start's log), CODE (exit code).
run_apps_start() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  local bin="$TMP/bin" state="$TMP/state" app tool
  mkdir -p "$bin" "$state"
  CALLS="$TMP/calls.log"
  : >"$CALLS"
  LOG="$state/niri/apps-start.log"

  for tool in bash jq grep sleep seq mkdir cat; do
    ln -s "$(command -v "$tool")" "$bin/$tool"
  done
  for app in zen-browser antigravity zcode discord zalo steam; do
    [[ " ${MISSING_APPS:-} " == *" $app "* ]] && continue
    printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/$app"
    chmod +x "$bin/$app"
  done

  cat >"$bin/niri" <<'EOF'
#!/usr/bin/env bash
echo "niri $*" >>"$FAKE_CALLS"
if [[ "$1 $2" == "msg outputs" ]]; then
  for ((i = 1; i <= FAKE_OUTPUTS; i++)); do echo "Output \"OUT$i\" (fake)"; done
elif [[ "$1 $2 $3" == "msg --json windows" ]]; then
  if [[ -n "$FAKE_WINDOW" ]]; then
    echo "[{\"id\": $FAKE_WINDOW, \"app_id\": \"antigravity\"}]"
  else
    echo "[]"
  fi
fi
exit 0
EOF
  cat >"$bin/waydroid" <<'EOF'
#!/usr/bin/env bash
echo "waydroid $*" >>"$FAKE_CALLS"
if [[ "$1" == "status" ]]; then
  echo "Container: $FAKE_CONTAINER"
  echo "Session: $FAKE_SESSION"
fi
exit 0
EOF
  chmod +x "$bin/niri" "$bin/waydroid"

  export FAKE_CALLS="$CALLS"
  export FAKE_OUTPUTS="${FAKE_OUTPUTS:-2}" FAKE_WINDOW="${FAKE_WINDOW:-}"
  export FAKE_CONTAINER="${FAKE_CONTAINER:-STOPPED}" FAKE_SESSION="${FAKE_SESSION:-STOPPED}"
  PATH="$bin" XDG_STATE_HOME="$state" "$BASH_BIN" "$SCRIPT" >/dev/null 2>&1
  CODE=$?
  # Without this, a script that dies before its first log line would make the negative checks pass vacuously.
  [[ -f "$LOG" ]] || fail "apps-start wrote no log (exit $CODE)"
}

# Prints the app names in the order apps-start launched them.
started_apps() {
  sed -n 's/^apps-start: \([^:]*\): starting .*/\1/p' "$LOG" | tr '\n' ' '
}

t_script_exists_and_is_executable() {
  [[ -x "$SCRIPT" ]] || fail "$SCRIPT is missing or not executable"
}

t_apps_launch_in_browser_coding_entertainment_order() {
  run_apps_start
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(started_apps)" == "zen-browser antigravity zcode discord zalo steam " ]] ||
    fail "launch order was '$(started_apps)'"
}

t_missing_app_is_skipped_and_the_rest_still_start() {
  export MISSING_APPS=discord
  run_apps_start
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  grep -qxF 'apps-start: discord: discord not found, skipped' "$LOG" || fail "missing discord was not logged as skipped"
  [[ "$(started_apps)" == "zen-browser antigravity zcode zalo steam " ]] || fail "apps after the missing one did not start: '$(started_apps)'"
}

t_waydroid_is_skipped_when_its_container_is_stopped() {
  export FAKE_CONTAINER=STOPPED
  run_apps_start
  grep -qxF 'apps-start: waydroid: container not running, skipped' "$LOG" || fail "stopped Waydroid container was not logged as skipped"
  ! grep -q 'starting waydroid show-full-ui' "$LOG" || fail "Waydroid UI started while its container is stopped"
}

t_waydroid_ui_starts_when_container_and_session_run() {
  export FAKE_CONTAINER=RUNNING FAKE_SESSION=RUNNING
  run_apps_start
  grep -qxF 'apps-start: waydroid: starting waydroid show-full-ui' "$LOG" || fail "Waydroid UI did not start with the container and session running"
}

t_single_monitor_moves_antigravity_to_coding() {
  export FAKE_OUTPUTS=1 FAKE_WINDOW=42
  run_apps_start
  grep -qxF 'niri msg action move-window-to-workspace coding --window-id 42' "$CALLS" ||
    fail "Antigravity window 42 was not moved to the coding workspace on a single monitor"
}

t_two_monitors_leave_antigravity_on_its_output() {
  export FAKE_OUTPUTS=2 FAKE_WINDOW=42
  run_apps_start
  ! grep -q 'move-window-to-workspace' "$CALLS" || fail "Antigravity was moved although two monitors are connected"
}

t_script_ends_by_focusing_the_browser_workspace() {
  run_apps_start
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(tail -n 1 "$CALLS")" == "niri msg action focus-workspace browser" ]] ||
    fail "last niri call was '$(tail -n 1 "$CALLS")', expected focus-workspace browser"
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
