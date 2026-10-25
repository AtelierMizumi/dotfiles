#!/usr/bin/env bash
# Tests for scripts/switch-shell.sh
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/scripts/switch-shell.sh"

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

setup_sandbox() {
  TMP=$(mktemp -d)
  mkdir -p "$TMP/bin" "$TMP/config/niri" "$TMP/local/state/noctalia" "$TMP/repo"
  LOG="$TMP/commands.log"
  : >"$LOG"

  # Fake sudo
  cat >"$TMP/bin/sudo" <<EOF
#!/usr/bin/env bash
echo "sudo: \$*" >>"$LOG"
"\$@"
EOF
  chmod +x "$TMP/bin/sudo"

  # Fake pacman
  cat >"$TMP/bin/pacman" <<EOF
#!/usr/bin/env bash
echo "pacman: \$*" >>"$LOG"
if [[ "\$*" == *"-Sp"* && "\$*" == *"conflict-pkg"* ]]; then
  echo "error: unresolvable package conflicts detected" >&2
  exit 1
fi
exit 0
EOF
  chmod +x "$TMP/bin/pacman"

  # Fake git
  cat >"$TMP/bin/git" <<EOF
#!/usr/bin/env bash
echo "git: \$*" >>"$LOG"
if [[ "\$1" == "rev-parse" ]]; then
  echo "smart-shell"
  exit 0
fi
exit 0
EOF
  chmod +x "$TMP/bin/git"

  # Fake stow
  cat >"$TMP/bin/stow" <<EOF
#!/usr/bin/env bash
echo "stow: \$*" >>"$LOG"
exit 0
EOF
  chmod +x "$TMP/bin/stow"

  # Fake niri
  cat >"$TMP/bin/niri" <<EOF
#!/usr/bin/env bash
echo "niri: \$*" >>"$LOG"
exit 0
EOF
  chmod +x "$TMP/bin/niri"

  # Fake noctalia
  cat >"$TMP/bin/noctalia" <<EOF
#!/usr/bin/env bash
echo "noctalia: \$*" >>"$LOG"
exit 0
EOF
  chmod +x "$TMP/bin/noctalia"
}

t_dry_run_runs_no_mutating_commands() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$SCRIPT" --dry-run >/dev/null 2>&1 || fail "dry-run failed"

  # Sudo, stow, git checkout/merge should not run in dry-run
  ! grep -q 'sudo:' "$LOG" || fail "sudo was called in dry-run"
  ! grep -q 'stow:' "$LOG" || fail "stow was called in dry-run"
  [[ ! -f "$TMP/config/niri/shell" ]] || fail "niri/shell was modified in dry-run"
}

t_conflicting_package_aborts_before_sudo() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  if MIZU_EXTRA_PACKAGES="conflict-pkg" \
     PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
     bash "$SCRIPT" --yes >/dev/null 2>&1; then
    fail "conflict should abort"
  fi

  ! grep -q 'sudo:' "$LOG" || fail "sudo was called despite conflict"
}

t_rollback_works_without_quickshell_and_keeps_settings() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  echo "mizu" >"$TMP/config/niri/shell"
  echo "keep-untouched" >"$TMP/local/state/noctalia/settings.toml"

  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" XDG_STATE_HOME="$TMP/local/state" \
    bash "$SCRIPT" --rollback >/dev/null 2>&1 || fail "rollback failed"

  [[ "$(cat "$TMP/config/niri/shell")" == "noctalia" ]] || fail "shell was not reverted to noctalia"
  [[ "$(cat "$TMP/local/state/noctalia/settings.toml")" == "keep-untouched" ]] || fail "settings.toml was modified"
}

t_confirm_timeout_reverts_to_noctalia() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  # Run with MIZU_CONFIRM_SECONDS=1 and pipe no input so it times out
  if MIZU_CONFIRM_SECONDS=1 \
     PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
     bash "$SCRIPT" </dev/null >/dev/null 2>&1; then
    fail "timeout should exit non-zero"
  fi

  [[ "$(cat "$TMP/config/niri/shell")" == "noctalia" ]] || fail "shell was not reverted after timeout"
}

t_confirm_yes_keeps_mizu() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$SCRIPT" --yes >/dev/null 2>&1 || fail "switch with --yes failed"

  [[ "$(cat "$TMP/config/niri/shell")" == "mizu" ]] || fail "shell was not switched to mizu"
}

run_test t_dry_run_runs_no_mutating_commands
run_test t_conflicting_package_aborts_before_sudo
run_test t_rollback_works_without_quickshell_and_keeps_settings
run_test t_confirm_timeout_reverts_to_noctalia
run_test t_confirm_yes_keeps_mizu

echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
