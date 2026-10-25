#!/usr/bin/env bash
# The focus-ring colors reach niri through `include optional=true "colors.kdl"`. Deployed, ~/.config/niri/config.kdl is a
# stow symlink into this repo and colors.kdl is a real file beside the link. With `optional=true` a miss is only a
# warning, so a layout where niri looks next to the symlink target instead would stay green and leave the ring amber.
# `niri validate` does not print colors, so "the file is read" is proven by a colors.kdl with a syntax error: niri must
# then refuse the config.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG="${NIRI_CONFIG_UNDER_TEST:-$ROOT/niri/.config/niri/config.kdl}"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Builds <tmp>/real/config.kdl (copy of the repo config), <tmp>/link/config.kdl -> ../real/config.kdl (what stow makes).
deploy() {
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  mkdir -p "$TMP/real" "$TMP/link"
  cp "$CONFIG" "$TMP/real/config.kdl"
  ln -s ../real/config.kdl "$TMP/link/config.kdl"
}

validate() {
  niri validate -c "$TMP/link/config.kdl" 2>&1
}

t_colors_file_beside_the_symlink_is_read() {
  local out
  deploy
  printf 'layout {\n    focus-ring {\n        active-color "#123456"\n    }\n}\n' >"$TMP/link/colors.kdl"
  out=$(validate) || fail "valid colors.kdl rejected: $out"
  [[ "$out" == *"config is valid"* ]] || fail "no 'config is valid' in: $out"
  [[ "$out" != *"optional include not found"* ]] || fail "niri did not find colors.kdl beside the symlink: $out"
}

t_a_broken_colors_file_beside_the_symlink_breaks_the_config() {
  local out
  deploy
  printf 'layout {\n    focus-ring {\n        active-color\n' >"$TMP/link/colors.kdl"
  if out=$(validate); then
    fail "niri accepted a syntax error in colors.kdl, so it never read the file beside the symlink: $out"
  fi
}

t_missing_colors_file_still_validates() {
  local out
  deploy
  out=$(validate) || fail "config without colors.kdl rejected: $out"
  [[ "$out" == *"config is valid"* ]] || fail "no 'config is valid' in: $out"
}

t_colors_file_next_to_the_target_is_not_what_niri_reads() {
  local out
  deploy
  # Documents the layout the install must NOT rely on: a broken file next to the repo copy has no effect.
  printf 'layout {\n    focus-ring {\n        active-color\n' >"$TMP/real/colors.kdl"
  out=$(validate) || fail "niri read colors.kdl next to the symlink target: $out"
}

passed=0
failed=0
skipped=0
if ! command -v niri >/dev/null 2>&1; then
  echo "SKIP all (niri is not installed)"
  echo "RESULT passed=0 failed=0 skipped=1"
  exit 0
fi
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
