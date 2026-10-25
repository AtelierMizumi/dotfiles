#!/usr/bin/env bash
# Tests for scripts/switch-shell.sh
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/scripts/switch-shell.sh"

passed=0
failed=0

# The tests may run from a worktree; the script refuses those unless told otherwise (see t_refuses_to_stow_from_a_worktree).
export MIZU_ALLOW_WORKTREE=1

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
if [[ "\$*" == *"--abbrev-ref"* ]]; then
  echo "\${FAKE_BRANCH:-smart-shell}"
  exit 0
fi
if [[ "\$*" == *"merge"* ]]; then
  exit \${FAKE_MERGE_RC:-0}
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

  # Fake pkill: the tests must never signal the real shell of whoever runs them
  cat >"$TMP/bin/pkill" <<EOF
#!/usr/bin/env bash
echo "pkill: \$*" >>"$LOG"
exit 0
EOF
  chmod +x "$TMP/bin/pkill"

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

t_the_shell_supervisor_is_stopped_before_the_shell_on_every_switch() {
  local args first_pkill
  for args in "--yes" "--rollback"; do
    setup_sandbox
    trap 'rm -rf "$TMP"' EXIT

    PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" bash "$SCRIPT" $args >/dev/null 2>&1 ||
      fail "$args failed"

    first_pkill=$(grep '^pkill:' "$LOG" | head -1)
    [[ "$first_pkill" == *"scripts/shell-start"* ]] ||
      fail "$args: the first pkill must stop the shell-start supervisor, got: $first_pkill"
    grep -q '^pkill: .*-x quickshell' "$LOG" || [[ "$args" == "--rollback" ]] || fail "$args: quickshell was not stopped"
    rm -rf "$TMP"
  done
}

t_installs_the_packages_the_shell_runs_tools_from() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$SCRIPT" --yes >/dev/null 2>&1 || fail "switch failed"

  # wlsunset is the Night Light tile's backend; cliphist and brightnessctl are the clipboard and brightness ones.
  for package in quickshell ttf-material-symbols-variable wlsunset cliphist brightnessctl; do
    grep -q "^pacman: -S --needed --noconfirm .*\\b$package\\b" "$LOG" || fail "$package is not installed by the switch"
  done
}

t_never_installs_leftover_staged_packages_over_the_repo_ones() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  mkdir -p "$TMP/stage/pkgs"
  : >"$TMP/stage/pkgs/quickshell-0.0.1-1-x86_64.pkg.tar.zst"

  RICE_STAGE="$TMP/stage" PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$SCRIPT" --yes >/dev/null 2>&1 || fail "switch failed"

  ! grep -q '^pacman: -U' "$LOG" || fail "a leftover staged package was installed with pacman -U"
}

t_main_checkout_merges_smart_shell_before_stowing() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  FAKE_BRANCH=main PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
    bash "$SCRIPT" --yes >/dev/null 2>&1 || fail "switch failed"

  grep -q 'git: .*merge --ff-only smart-shell' "$LOG" || fail "smart-shell was not merged into main"
  local merge_line stow_line
  merge_line=$(grep -n 'merge --ff-only smart-shell' "$LOG" | head -1 | cut -d: -f1)
  stow_line=$(grep -n '^stow:' "$LOG" | head -1 | cut -d: -f1)
  [[ -n "$stow_line" && "$merge_line" -lt "$stow_line" ]] || fail "the merge must come before stow"
}

t_failed_merge_stops_before_stow_and_switch() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  if FAKE_BRANCH=main FAKE_MERGE_RC=1 PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
     bash "$SCRIPT" --yes >/dev/null 2>&1; then
    fail "a merge that cannot fast-forward must stop the switch"
  fi

  ! grep -q '^stow:' "$LOG" || fail "stow ran after a failed merge"
  [[ ! -f "$TMP/config/niri/shell" ]] || fail "the shell was switched after a failed merge"
}

t_refuses_to_stow_from_a_worktree() {
  setup_sandbox
  trap 'rm -rf "$TMP"' EXIT

  local fake_root="$TMP/dotfiles/.claude/worktrees/w"
  mkdir -p "$fake_root/scripts"
  cp "$SCRIPT" "$fake_root/scripts/switch-shell.sh"

  if env -u MIZU_ALLOW_WORKTREE PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_CONFIG_HOME="$TMP/config" \
     bash "$fake_root/scripts/switch-shell.sh" --yes >/dev/null 2>&1; then
    fail "running from a worktree must be refused"
  fi

  ! grep -q '^stow:' "$LOG" || fail "stow ran from a worktree"
  ! grep -q 'sudo:' "$LOG" || fail "sudo ran from a worktree"
}

run_test t_dry_run_runs_no_mutating_commands
run_test t_conflicting_package_aborts_before_sudo
run_test t_rollback_works_without_quickshell_and_keeps_settings
run_test t_confirm_timeout_reverts_to_noctalia
run_test t_confirm_yes_keeps_mizu
run_test t_the_shell_supervisor_is_stopped_before_the_shell_on_every_switch
run_test t_installs_the_packages_the_shell_runs_tools_from
run_test t_never_installs_leftover_staged_packages_over_the_repo_ones
run_test t_main_checkout_merges_smart_shell_before_stowing
run_test t_failed_merge_stops_before_stow_and_switch
run_test t_refuses_to_stow_from_a_worktree

echo "RESULT passed=$passed failed=$failed skipped=0"
[[ $failed -eq 0 ]]
