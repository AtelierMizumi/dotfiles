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

t_shell_started_via_shell_start() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qxF 'spawn-at-startup "~/.config/niri/scripts/shell-start"' <<<"$active" || fail "shell-start startup line missing"
}

# Noctalia renders ~/.config/niri/colors.kdl from the wallpaper palette. Includes are positional, so it must come after
# the layout block to override the amber fallback, and optional so niri still starts before the first render.
t_wallpaper_colors_are_included_after_the_layout() {
  local active include_at layout_at
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  include_at=$(grep -nxF 'include optional=true "colors.kdl"' <<<"$active" | cut -d: -f1)
  layout_at=$(grep -nE '^layout[[:space:]]*\{' <<<"$active" | cut -d: -f1)
  [[ -n "$include_at" ]] || fail 'no active top-level include optional=true "colors.kdl"'
  [[ -n "$layout_at" && "$include_at" -gt "$layout_at" ]] || fail "colors.kdl is included before the layout block"
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
  ! grep -qE '^[[:space:]]*Mod\+Space[[:space:]].*panel-toggle launcher' <<<"$active" || fail "Mod+Space is the launcher again; it is the input method switch"
  grep -qE '^[[:space:]]*Mod\+D[[:space:]].*spawn-sh "~/\.config/niri/scripts/shell-ipc launcher"' <<<"$active" || fail "Mod+D launcher bind missing"
  grep -qE '^[[:space:]]*Mod\+S[[:space:]].*spawn-sh "~/\.config/niri/scripts/shell-ipc quick"' <<<"$active" || fail "Mod+S control center bind missing"
  grep -qE '^[[:space:]]*Mod\+Alt\+S[[:space:]].*spawn-sh "~/\.config/niri/scripts/shell-ipc settings"' <<<"$active" || fail "Mod+Alt+S settings bind missing"
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

t_lc_time_comment_is_accurate() {
  # Apps started from the launcher inherit its environment, so the comment must not claim isolation.
  grep -q 'apps it launches' "$CONFIG" || fail "the LC_TIME comment does not say apps launched by Noctalia inherit it"
  ! grep -q 'any other app' "$CONFIG" || fail "the LC_TIME comment still claims no other app is affected"
}

t_lock_bind_uses_shell_ipc() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qE '^[[:space:]]*Super\+Alt\+L[[:space:]].*spawn-sh "~/\.config/niri/scripts/shell-ipc lock"' <<<"$active" || fail "Super+Alt+L does not lock through shell-ipc"
  ! grep -qi 'swaylock' "$CONFIG" || fail "swaylock (not installed) is still referenced"
}

t_hardware_keys_use_shell_ipc() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  local pair key action
  for pair in \
    'XF86AudioRaiseVolume|volume-up' 'XF86AudioLowerVolume|volume-down' 'XF86AudioMute|volume-mute' \
    'XF86AudioMicMute|mic-mute' \
    'XF86MonBrightnessUp|brightness-up' 'XF86MonBrightnessDown|brightness-down' \
    'XF86AudioPlay|media-play' 'XF86AudioNext|media-next' 'XF86AudioPrev|media-prev' 'XF86AudioStop|media-play'; do
    key=${pair%%|*}
    action=${pair#*|}
    grep -qE "^[[:space:]]*${key}[[:space:]].*shell-ipc ${action}" <<<"$active" || fail "$key does not run 'shell-ipc $action'"
  done
  ! grep -qE 'brightnessctl|playerctl' "$CONFIG" || fail "brightnessctl/playerctl (not installed) are still referenced"
}

# Succeeds when an active bind with this exact key combo contains the given text.
has_bind() {
  active_lines "$CONFIG" | awk -v combo="$1" -v text="$2" '$1 == combo && index($0, text) > 0 { found = 1 } END { exit !found }'
}

# One hand on a Sofle or a laptop: every bind is at most three keys (Super, one more modifier, one key).
t_no_bind_needs_more_than_three_keys() {
  local too_long
  [[ -f "$CONFIG" ]] || fail "config missing"
  too_long=$(active_lines "$CONFIG" | awk '/^binds[[:space:]]*\{/ { inb = 1; next } inb && /^\}/ { inb = 0 } inb && NF > 0 { n = split($1, p, "+"); if (n > 3) print $1 }')
  [[ -z "$too_long" ]] || fail "binds with more than three keys: $(tr '\n' ' ' <<<"$too_long")"
}

t_app_binds() {
  local pair combo text
  for pair in 'Mod+T|spawn "ghostty"' 'Mod+Return|spawn "ghostty"' 'Mod+B|spawn "zen-browser"' 'Mod+E|spawn "nautilus"' 'Mod+C|spawn "code"'; do
    combo=${pair%%|*}
    text=${pair#*|}
    has_bind "$combo" "$text" || fail "$combo does not run $text"
  done
}

t_shell_binds() {
  local pair combo text
  for pair in 'Mod+Shift+V|shell-ipc clipboard' 'Mod+N|shell-ipc dnd' 'Mod+Alt+W|shell-ipc wallpaper-next' \
    'Mod+Escape|shell-ipc lock' 'Super+Alt+L|shell-ipc lock'; do
    combo=${pair%%|*}
    text=${pair#*|}
    has_bind "$combo" "$text" || fail "$combo does not run $text"
  done
}

t_screenshot_and_brightness_binds() {
  has_bind 'Mod+Shift+S' 'screenshot;' || fail "Mod+Shift+S does not take a screenshot"
  has_bind 'Mod+Alt+Minus' 'shell-ipc brightness-down' || fail "Mod+Alt+Minus does not lower the brightness"
  has_bind 'Mod+Alt+Equal' 'shell-ipc brightness-up' || fail "Mod+Alt+Equal does not raise the brightness"
}

t_movement_binds_use_letters_and_one_modifier() {
  local pair combo text
  for pair in 'Mod+H|focus-column-left' 'Mod+L|focus-column-right' 'Mod+J|focus-window-down' 'Mod+K|focus-window-up' \
    'Mod+Shift+H|move-column-left' 'Mod+Shift+L|move-column-right' 'Mod+Shift+J|move-window-down' 'Mod+Shift+K|move-window-up' \
    'Mod+U|focus-workspace-down' 'Mod+I|focus-workspace-up' \
    'Mod+Tab|focus-monitor-next' 'Mod+Shift+Tab|move-column-to-monitor-next' \
    'Mod+Alt+Left|move-column-to-monitor-left' 'Mod+Alt+Right|move-column-to-monitor-right' \
    'Mod+Alt+Up|move-column-to-monitor-up' 'Mod+Alt+Down|move-column-to-monitor-down'; do
    combo=${pair%%|*}
    text=${pair#*|}
    has_bind "$combo" "$text" || fail "$combo does not run $text"
  done
}

t_workspace_number_binds() {
  local n
  for n in 1 2 3 4 5 6 7 8 9; do
    has_bind "Mod+$n" "focus-workspace $n;" || fail "Mod+$n does not focus workspace $n"
    has_bind "Mod+Shift+$n" "move-column-to-workspace $n;" || fail "Mod+Shift+$n does not move the column to workspace $n"
  done
}

t_layout_binds_moved_to_free_keys() {
  has_bind 'Mod+Z' 'center-column;' || fail "Mod+Z does not center the column"
  has_bind 'Mod+Alt+R' 'switch-preset-window-height;' || fail "Mod+Alt+R does not switch the window height preset"
  has_bind 'Mod+Alt+V' 'switch-focus-between-floating-and-tiling;' || fail "Mod+Alt+V does not switch floating/tiling focus"
  has_bind 'Mod+Alt+Escape' 'toggle-keyboard-shortcuts-inhibit;' || fail "Mod+Alt+Escape does not toggle the shortcut inhibitor"
  has_bind 'Mod+V' 'toggle-window-floating;' || fail "Mod+V no longer toggles floating"
  has_bind 'Mod+F' 'maximize-column;' || fail "Mod+F no longer maximizes the column"
}

# The typing language cycles on Super+BackSpace through every engine of the fcitx5 group (keyboard-us -> lotus ->
# anthy); `fcitx5-remote -t` only toggled to the last used engine and never reached the third one. Super+Space is
# left unbound in niri, so fcitx5's own Super+space (EnumerateForwardKeys, shared with Plasma) still works in text
# fields. fcitx5-remote -s <name> picks one engine directly.
t_super_backspace_cycles_the_input_method() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  has_bind 'Mod+BackSpace' 'spawn-sh "~/.config/niri/scripts/fcitx5-cycle"' || fail "Mod+BackSpace does not run the fcitx5-cycle script"
  ! grep -qE '^[[:space:]]*Mod\+Space[[:space:]]' <<<"$active" || fail "Mod+Space is still bound in niri"
  ! grep -qF 'fcitx5-remote" "-t"' <<<"$active" || fail "the -t toggle that skips the third engine is still bound"
  has_bind 'Mod+Shift+Space' 'spawn "fcitx5-remote" "-s" "anthy"' || fail "Mod+Shift+Space does not select the Japanese engine"
  has_bind 'Mod+Alt+Space' 'spawn "fcitx5-remote" "-s" "lotus"' || fail "Mod+Alt+Space does not select the Vietnamese engine"
}

t_orca_bind_removed() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  ! grep -q 'orca' <<<"$active" || fail "the Orca screen reader bind is still active"
}

t_outputs_mirror_the_plasma_layout() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  awk '/^output "eDP-1"[[:space:]]*\{/ { inb = 1 } inb && /scale 1[[:space:]]*$/ { s = 1 } inb && /position x=0 y=0/ { p = 1 } inb && /^\}/ { exit } END { exit !(s && p) }' <<<"$active" ||
    fail "output eDP-1 is not scale 1 at x=0 y=0"
  awk '/^output "HDMI-A-1"[[:space:]]*\{/ { inb = 1 } inb && /scale 1[[:space:]]*$/ { s = 1 } inb && /position x=1920 y=0/ { p = 1 } inb && /^\}/ { exit } END { exit !(s && p) }' <<<"$active" ||
    fail "output HDMI-A-1 is not scale 1 at x=1920 y=0"
  ! grep -qE '^[[:space:]]*mode ' <<<"$active" || fail "a fixed output mode is set; the external monitors change with the place"
}

t_cursor_matches_plasma() {
  local block
  block=$(active_lines "$CONFIG" | awk '/^cursor[[:space:]]*\{/ { inb = 1 } inb { print } inb && /^\}/ { exit }')
  grep -qF 'xcursor-theme "breeze_cursors"' <<<"$block" || fail "cursor theme is not breeze_cursors"
  grep -qE 'xcursor-size 36' <<<"$block" || fail "cursor size is not 36"
}

t_windows_have_no_client_decorations() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qxF 'prefer-no-csd' <<<"$active" || fail "prefer-no-csd is not enabled"
}

t_editors_open_full_width() {
  window_rule_has 'app-id=r#"^([Cc]ode|[Aa]ntigravity|[Zz]code)$"#' 'default-column-width { proportion 1.0; }' || fail "no window-rule opening VS Code, Antigravity and ZCode full width"
}

# The laptop panel is 1920 logical pixels at scale 1; a comment that still gives 1536 or scale 1.25 is stale.
t_comments_describe_the_laptop_panel_at_scale_1() {
  ! grep -qE '1536|scale 1\.25' "$CONFIG" || fail "a comment still gives the laptop panel as 1536 pixels or scale 1.25"
}

# Succeeds when a top-level `workspace "<name>" { ... }` node (a niri named workspace) sets open-on-output to <output>.
workspace_opens_on() {
  active_lines "$CONFIG" | awk -v name="$1" -v out="$2" '
    $0 ~ "^workspace \"" name "\"" { inblk = 1 }
    inblk && index($0, "open-on-output \"" out "\"") > 0 { found = 1 }
    inblk && /^\}/ { inblk = 0 }
    END { exit !found }
  '
}

# Browser on the laptop; coding and games on the external monitor, which falls back to the laptop when it is unplugged.
t_named_workspaces_open_on_their_outputs() {
  workspace_opens_on browser eDP-1 || fail 'workspace "browser" does not open on eDP-1'
  workspace_opens_on coding HDMI-A-1 || fail 'workspace "coding" does not open on HDMI-A-1'
  workspace_opens_on games HDMI-A-1 || fail 'workspace "games" does not open on HDMI-A-1'
}

# niri 26.04 reads named workspaces as top-level nodes; a `workspaces { }` wrapper is rejected as an unexpected node.
t_workspaces_are_top_level_nodes() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  ! grep -qE '^workspaces[[:space:]]*\{' <<<"$active" || fail "workspaces { } wrapper found; use top-level workspace nodes"
}

t_apps_start_runs_after_shell_start() {
  local active shell_at apps_at
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  shell_at=$(grep -nxF 'spawn-at-startup "~/.config/niri/scripts/shell-start"' <<<"$active" | cut -d: -f1)
  apps_at=$(grep -nxF 'spawn-at-startup "~/.config/niri/scripts/apps-start"' <<<"$active" | cut -d: -f1)
  [[ -n "$apps_at" ]] || fail "apps-start startup line missing"
  [[ -n "$shell_at" && "$apps_at" -gt "$shell_at" ]] || fail "apps-start is not spawned after shell-start"
}

# Each autostarted app goes to its workspace by app-id; the workspace's open-on-output decides the monitor.
t_app_windows_open_on_their_workspace() {
  window_rule_has 'app-id=r#"^zen$"#' 'open-on-workspace "browser"' || fail "zen does not open on the browser workspace"
  window_rule_has 'app-id=r#"^antigravity$"#' 'open-on-workspace "coding"' || fail "Antigravity does not open on the coding workspace"
  window_rule_has 'app-id=r#"^zcode$"#' 'open-on-workspace "coding"' || fail "ZCode does not open on the coding workspace"
  window_rule_has 'app-id=r#"^discord$"#' 'open-on-workspace "games"' || fail "Discord does not open on the games workspace"
  window_rule_has 'app-id=r#"^zalo$"#' 'open-on-workspace "games"' || fail "Zalo does not open on the games workspace"
  window_rule_has 'app-id=r#"^Waydroid$"#' 'open-on-workspace "games"' || fail "Waydroid does not open on the games workspace"
  window_rule_has 'app-id=r#"^steam$"#' 'title=r#"^Steam$"#' 'open-on-workspace "games"' || fail "the Steam main window does not open on the games workspace"
}

t_steam_windows_float_and_notifications_corner() {
  local active
  active=$(active_lines "$CONFIG") || fail "config unreadable"
  grep -qF 'match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#' <<<"$active" || fail "no steam notification window rule"
  grep -qF 'default-floating-position x=16 y=16 relative-to="bottom-right"' <<<"$active" || fail "steam notifications not positioned in bottom-right"
  grep -qF 'open-focused false' <<<"$active" || fail "steam notifications steal focus"
  grep -qF 'exclude title=r#"^Steam$"#' <<<"$active" || fail "steam popups not floating"
}

t_no_env_leak() {
  local active count
  [[ -f "$CONFIG" ]] || fail "config missing"
  ! grep -q 'QT_QPA_PLATFORMTHEME' "$CONFIG" || fail "QT_QPA_PLATFORMTHEME is set"
  active=$(active_lines "$CONFIG")
  count=$(grep -c 'LC_TIME' <<<"$active")
  [[ "$count" -eq 0 ]] || fail "LC_TIME appears on $count active lines; environment variables should not leak into niri config"
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
