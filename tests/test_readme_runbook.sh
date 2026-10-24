#!/usr/bin/env bash
# Guards the README runbook and the CLAUDE.md handoff: the Noctalia overlay is stowed before Noctalia can start,
# plasmashell stays stopped from snapshot to the last compare, the validate gate can pass, and the install is
# drivable from a TTY (the user leaves Plasma first, runs sudo themselves, and never ends in a partial upgrade).
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
README="$ROOT/README.md"
HANDOFF="$ROOT/CLAUDE.md"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

line_of() {
  grep -n -m 1 -F -- "$1" "$README" | cut -d: -f1
}

t_niri_and_noctalia_are_stowed_together() {
  grep -qE '^[[:space:]]*stow -n -v --no-folding -t ~ niri noctalia[[:space:]]*(#.*)?$' "$README" || fail "no dry run stowing niri and noctalia together"
  grep -qE '^[[:space:]]*stow --no-folding -t ~ niri noctalia[[:space:]]*$' "$README" || fail "no real stow of niri and noctalia together"
}

t_no_niri_only_stow_command() {
  ! grep -qE 'stow (-n -v )?--no-folding -t ~ niri[[:space:]]*(#.*)?$' "$README" || fail "a stow command installs niri without noctalia"
}

t_noctalia_check_runs_before_next_niri_login() {
  grep -qF 'check-plasma-intact.sh noctalia' "$README" || fail "runbook never runs the noctalia check"
  grep -q 'before logging into niri' "$README" || fail "runbook does not say to run the noctalia check before logging into niri"
}

t_plasma_stays_closed_until_final_compare() {
  local last_compare plasma_login
  grep -q 'plasmashell' "$README" || fail "runbook never explains that plasmashell must be stopped"
  last_compare=$(grep -n 'check-plasma-intact.sh compare' "$README" | tail -n 1 | cut -d: -f1)
  plasma_login=$(line_of 'Only then log into Plasma')
  [[ -n "$last_compare" ]] || fail "no compare step"
  [[ -n "$plasma_login" ]] || fail "no 'Only then log into Plasma' step"
  [[ "$last_compare" -lt "$plasma_login" ]] || fail "the Plasma login ($plasma_login) comes before the last compare ($last_compare)"
}

t_validate_gate_is_passable() {
  grep -q 'noctalia config validate' "$README" || fail "no validate step"
  ! grep -q 'noctalia config validate ~' "$README" || fail "validate is given a directory, which skips settings.toml"
  grep -q 'WARN' "$README" || fail "gate does not mention WARN lines"
  ! grep -q 'no output at all' "$README" || fail "gate still demands no output, which validate never produces"
}

t_tty_flow_is_documented() {
  grep -qF 'loginctl terminate-session' "$README" || fail "no way to end the Plasma session from a TTY"
  grep -qF 'Ctrl+Alt+F3' "$README" || fail "no instruction to switch to a TTY"
  grep -qF 'git merge --ff-only worktree-niri-noctalia-spec' "$README" || fail "no merge instruction for the main checkout"
}

t_package_step_never_ends_in_a_partial_upgrade() {
  grep -qF 'sudo pacman -Syu' "$README" || fail "no full-upgrade instruction for a stale sync database"
  grep -qF "never \`pacman -Sy\`" "$README" || fail "no warning against a bare pacman -Sy"
}

t_smoke_test_precedes_package_install() {
  local smoke install
  smoke=$(line_of 'smoke test')
  install=$(line_of 'sudo pacman -S stow')
  [[ -n "$smoke" ]] || fail "no smoke test step"
  [[ -n "$install" ]] || fail "no package install step"
  [[ "$smoke" -lt "$install" ]] || fail "the smoke test ($smoke) comes after the package install ($install)"
}

t_gpu_choice_is_read_from_the_niri_log() {
  grep -qF 'journalctl --user -u niri -b' "$README" || fail "no niri log check for the chosen GPU"
  ! grep -q 'runtime_status' "$README" || fail "runtime_status is not a reliable GPU signal here"
}

t_final_plasma_check_covers_file_dialogs() {
  grep -q 'file dialogs' "$README" || fail "the final Plasma check does not cover file dialogs"
}

t_sudo_runs_in_a_second_vt() {
  grep -q 'second VT' "$README" || fail "sudo lines are not routed to a second VT"
}

t_console_font_test_is_documented() {
  grep -qF 'Tiếng Việt' "$README" || fail "no Vietnamese glyph test for the TTY font"
}

t_portal_override_is_explained() {
  grep -qF 'niri-portals.conf' "$README" || fail "README does not explain the niri portal override"
  grep -qF 'ScreenCast' "$README" || fail "README does not say why the override exists (ScreenCast)"
}

t_handoff_points_to_the_runbook_and_keeps_the_rules() {
  [[ -f "$HANDOFF" ]] || fail "CLAUDE.md is missing"
  grep -q 'README.md' "$HANDOFF" || fail "CLAUDE.md does not point to the README runbook"
  grep -q 'sudo' "$HANDOFF" || fail "CLAUDE.md does not say the user runs sudo"
  grep -q 'plasmashell' "$HANDOFF" || fail "CLAUDE.md does not mention the plasmashell rule"
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
