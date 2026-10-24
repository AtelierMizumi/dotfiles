#!/usr/bin/env bash
# Guards the README runbook's order and gates (review findings 1-3): the Noctalia overlay must be stowed before
# Noctalia can start, the compares must stay in the niri session, and the validate gate must be passable.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
README="$ROOT/README.md"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
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

t_stay_in_niri_until_final_compare() {
  local last_compare plasma_login
  grep -q 'stay in the niri session' "$README" || fail "runbook does not say to stay in the niri session"
  last_compare=$(grep -n 'check-plasma-intact.sh compare' "$README" | tail -n 1 | cut -d: -f1)
  plasma_login=$(grep -n 'Only then log into Plasma' "$README" | head -n 1 | cut -d: -f1)
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
