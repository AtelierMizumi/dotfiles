#!/usr/bin/env bash
# Tests for niri/.config/niri/config.kdl (spec section 3, rows 9-12) and the untouched baseline copy.
# Checks ignore comment lines and slashdashed (`/-`) blocks, which niri does not apply.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG="$ROOT/niri/.config/niri/config.kdl"
BASELINE="$ROOT/docs/baseline/niri-config.default.kdl"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Print the lines niri actually applies: no `//` comment lines, no `/-` slashdashed nodes with their blocks.
active_lines() {
  awk '
    /^[[:space:]]*\/\// { next }
    skip > 0 { skip += gsub(/\{/, "{") - gsub(/\}/, "}"); next }
    /^[[:space:]]*\/-/ { skip = gsub(/\{/, "{") - gsub(/\}/, "}"); if (skip < 0) skip = 0; next }
    { print }
  ' "$1"
}

# Succeeds when some top-level `window-rule { ... }` block contains every given pattern.
window_rule_has() {
  local patterns
  patterns=$(printf '%s\n' "$@")
  active_lines "$CONFIG" | awk -v wanted="$patterns" '
    BEGIN { n = split(wanted, pats, "\n") }
    /^[[:space:]]*window-rule[[:space:]]*\{/ { inblk = 1; for (i = 1; i <= n; i++) hit[i] = 0 }
    inblk { for (i = 1; i <= n; i++) if (index($0, pats[i]) > 0) hit[i] = 1 }
    inblk && /^[[:space:]]*\}/ {
      ok = 1
      for (i = 1; i <= n; i++) if (!hit[i]) ok = 0
      if (ok) found = 1
      inblk = 0
    }
    END { exit !found }
  '
}

t_validates() {
  local out
  out=$(niri validate -c "$CONFIG" 2>&1) || fail "niri validate failed: $out"
  [[ "$out" == *"config is valid"* ]] || fail "no 'config is valid' in: $out"
}

t_baseline_validates() {
  local out
  out=$(niri validate -c "$BASELINE" 2>&1) || fail "niri validate failed: $out"
  [[ "$out" == *"config is valid"* ]] || fail "no 'config is valid' in: $out"
}

t_waybar_not_started() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  [[ -n "$active" ]] || fail "no active lines"
  ! grep -q 'spawn-at-startup "waybar"' <<<"$active" || fail "waybar is still started"
}

t_fuzzel_not_referenced() {
  [[ -f "$CONFIG" ]] || fail "config missing"
  ! grep -qi 'fuzzel' "$CONFIG" || fail "fuzzel is still referenced"
}

t_noctalia_started_with_scoped_lc_time() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qxF 'spawn-at-startup "env" "LC_TIME=ja_JP.UTF-8" "noctalia"' <<<"$active" || fail "scoped noctalia startup line missing"
}

t_focus_ring_is_amber_2px() {
  local block
  block=$(active_lines "$CONFIG" | awk '/^[[:space:]]*focus-ring[[:space:]]*\{/{in_ring=1} in_ring{print} in_ring && /^[[:space:]]*\}/{exit}')
  [[ -n "$block" ]] || fail "no active focus-ring block"
  grep -qE '^[[:space:]]*width 2[[:space:]]*$' <<<"$block" || fail "focus-ring width is not 2"
  grep -qF 'active-color "#E2A63B"' <<<"$block" || fail "focus-ring active-color is not #E2A63B"
}

t_gaps_12() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qE '^[[:space:]]*gaps 12[[:space:]]*$' <<<"$active" || fail "gaps 12 missing"
}

t_corner_radius_20_with_clip() {
  window_rule_has 'geometry-corner-radius 20' 'clip-to-geometry true' || fail "no active window-rule with radius 20 and clip"
}

t_settings_window_floats_1080x920() {
  window_rule_has 'match app-id="dev.noctalia.Noctalia"' 'open-floating true' 'fixed 1080' 'fixed 920' ||
    fail "no active window-rule floating the Noctalia settings window at 1080x920"
}

t_launcher_control_center_settings_binds() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qE '^[[:space:]]*Mod\+Space[[:space:]].*spawn-sh "noctalia msg panel-toggle launcher"' <<<"$active" || fail "Mod+Space launcher bind missing"
  grep -qE '^[[:space:]]*Mod\+D[[:space:]].*spawn-sh "noctalia msg panel-toggle launcher"' <<<"$active" || fail "Mod+D launcher bind missing"
  grep -qE '^[[:space:]]*Mod\+S[[:space:]].*spawn-sh "noctalia msg panel-toggle control-center"' <<<"$active" || fail "Mod+S control center bind missing"
  grep -qE '^[[:space:]]*Mod\+Shift\+Comma[[:space:]].*spawn-sh "noctalia msg settings-toggle"' <<<"$active" || fail "Mod+Shift+Comma settings bind missing"
}

t_default_column_binds_kept() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qE '^[[:space:]]*Mod\+Comma[[:space:]]+\{ consume-window-into-column; \}' <<<"$active" || fail "Mod+Comma consume-window-into-column was removed"
  grep -qE '^[[:space:]]*Mod\+Period[[:space:]]+\{ expel-window-from-column; \}' <<<"$active" || fail "Mod+Period expel-window-from-column was removed"
}

t_xdg_activation_honored() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qE '^[[:space:]]*honor-xdg-activation-with-invalid-serial' <<<"$active" || fail "honor-xdg-activation-with-invalid-serial missing"
}

t_no_env_leak() {
  local active count
  [[ -f "$CONFIG" ]] || fail "config missing"
  ! grep -q 'QT_QPA_PLATFORMTHEME' "$CONFIG" || fail "QT_QPA_PLATFORMTHEME is set"
  active=$(active_lines "$CONFIG")
  count=$(grep -c 'LC_TIME' <<<"$active")
  [[ "$count" -eq 1 ]] || fail "LC_TIME appears on $count active lines, expected only the spawn line"
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
