#!/usr/bin/env bash
# Tests for niri/.config/niri/scripts/shell-start (the supervisor that keeps the shell running).
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/niri/.config/niri/scripts/shell-start"

passed=0
failed=0

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

run_test() {
  local name="$1" output code
  output=$("$name" 2>&1)
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

# A sandbox where `qs` is a fake: its first run prints the line Qt logs when the GPU context is lost and then keeps
# running (as the real shell did: alive, but its windows no longer redraw). Later runs just stay alive.
setup_sandbox() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/bin" "$TMP/config/niri"
  echo mizu >"$TMP/config/niri/shell"
  RUNS="$TMP/runs"
  : >"$RUNS"
  cat >"$TMP/bin/qs" <<EOF
#!/usr/bin/env bash
echo run >>"$RUNS"
echo \$\$ >>"$TMP/pids"
if [[ \$(wc -l <"$RUNS") -eq 1 ]]; then
  echo "WARN: QRhiGles2: Context is lost." >&2
  echo "WARN: Graphics device lost, cleaning up scenegraph and releasing RHI" >&2
fi
exec sleep 60
EOF
  cat >"$TMP/bin/dbus-update-activation-environment" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TMP/bin/qs" "$TMP/bin/dbus-update-activation-environment"
}

run_supervisor() {
  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" MIZU_RESTART_DELAY=0 \
    timeout 4 bash "$SCRIPT" >"$TMP/out" 2>&1
  # shellcheck disable=SC2046
  [[ -f "$TMP/pids" ]] && kill $(cat "$TMP/pids") 2>/dev/null || true
}

t_restarts_the_shell_when_the_graphics_device_is_lost() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT
  run_supervisor
  [[ $(wc -l <"$RUNS") -ge 2 ]] || fail "shell was not restarted after 'Graphics device lost' (runs: $(wc -l <"$RUNS"))"
}

t_a_healthy_shell_is_not_restarted() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT
  # Same fake, but it never reports a lost device.
  sed -i 's/-eq 1/-eq 999/' "$TMP/bin/qs"
  run_supervisor
  [[ $(wc -l <"$RUNS") -eq 1 ]] || fail "healthy shell restarted (runs: $(wc -l <"$RUNS"))"
}

# The shell logs media titles ("DEBUG qml: [media] <title>"); a title must not be able to restart the shell.
t_a_media_title_cannot_trigger_a_restart() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT
  sed -i 's/echo "WARN: Graphics device lost,/echo "DEBUG qml: [media] Graphics device lost,/' "$TMP/bin/qs"
  run_supervisor
  [[ $(wc -l <"$RUNS") -eq 1 ]] || fail "a log line from QML restarted the shell (runs: $(wc -l <"$RUNS"))"
}

run_test t_restarts_the_shell_when_the_graphics_device_is_lost
run_test t_a_media_title_cannot_trigger_a_restart
run_test t_a_healthy_shell_is_not_restarted

echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
