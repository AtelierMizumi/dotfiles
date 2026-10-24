#!/usr/bin/env bash
# Tests for scripts/check-plasma-intact.sh. Each test runs in its own subshell and exits non-zero on a
# failed assertion. Fake pacman/gsettings/pgrep binaries in tests/stubs keep the tests off the real system.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/scripts/check-plasma-intact.sh"
STUBS="$ROOT/tests/stubs"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/check-plasma.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "expected [$2], got [$1] ($3)"
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "[$1] does not contain [$2]"
}

# Build an isolated HOME/XDG tree with a few Plasma-shared files and the stubs wired in.
new_env() {
  T=$(mktemp -d "$WORK/t.XXXXXX")
  export HOME="$T/home"
  export XDG_CONFIG_HOME="$T/cfg"
  export XDG_STATE_HOME="$T/state"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/kdedefaults" "$XDG_STATE_HOME" "$T/gs"
  printf 'a\n' >"$XDG_CONFIG_HOME/kdeglobals"
  printf 'b\n' >"$XDG_CONFIG_HOME/mimeapps.list"
  printf 'c\n' >"$XDG_CONFIG_HOME/kdedefaults/kdeglobals"
  export PACMAN_BIN="$STUBS/pacman"
  export GSETTINGS_BIN="$STUBS/gsettings"
  export PGREP_BIN="$STUBS/pgrep"
  export STUB_GSETTINGS_DIR="$T/gs"
  unset STUB_PACMAN_MISSING STUB_PACMAN_BROKEN STUB_PGREP_MATCH STUB_GSETTINGS_FAIL
}

# Run the script; sets CODE, OUT (stdout) and ERR (stderr).
run() {
  CODE=0
  OUT=$("$SCRIPT" "$@" 2>"$T/err") || CODE=$?
  ERR=$(<"$T/err")
}

t_unchanged_state_exits_0() {
  new_env
  run snapshot
  assert_eq "$CODE" 0 "snapshot"
  run compare
  assert_eq "$CODE" 0 "compare, output: $OUT $ERR"
}

t_modified_kdeglobals_exits_1_and_names_file() {
  new_env
  run snapshot
  printf 'changed\n' >"$XDG_CONFIG_HOME/kdeglobals"
  run compare
  assert_eq "$CODE" 1 "compare"
  assert_contains "$OUT" "CHANGED: kdeglobals"
}

t_watched_file_appearing_or_disappearing_exits_1() {
  new_env
  run snapshot
  printf 'new\n' >"$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
  run compare
  assert_eq "$CODE" 1 "appearing file"
  assert_contains "$OUT" "CHANGED: gtk-3.0/settings.ini"

  new_env
  run snapshot
  rm "$XDG_CONFIG_HOME/mimeapps.list"
  run compare
  assert_eq "$CODE" 1 "disappearing file"
  assert_contains "$OUT" "CHANGED: mimeapps.list"
}

t_snapshot_missing_exits_2() {
  new_env
  run compare
  assert_eq "$CODE" 2 "compare without snapshot"
}

t_home_with_spaces_works() {
  new_env
  export HOME="$T/my home"
  unset XDG_CONFIG_HOME XDG_STATE_HOME
  mkdir -p "$HOME/.config" "$HOME/.local/state"
  printf 'a\n' >"$HOME/.config/kdeglobals"
  run snapshot
  assert_eq "$CODE" 0 "snapshot, output: $OUT $ERR"
  run compare
  assert_eq "$CODE" 0 "compare, output: $OUT $ERR"
  printf 'x\n' >"$HOME/.config/kdeglobals"
  run compare
  assert_eq "$CODE" 1 "compare after change"
  assert_contains "$OUT" "CHANGED: kdeglobals"
}

t_gsettings_unavailable_is_recorded_and_not_a_violation() {
  new_env
  export STUB_GSETTINGS_FAIL=1
  run snapshot
  assert_eq "$CODE" 0 "snapshot"
  run compare
  assert_eq "$CODE" 0 "compare, output: $OUT $ERR"
}

t_gsettings_value_change_exits_1() {
  new_env
  run snapshot
  printf "'prefer-dark'\n" >"$T/gs/color-scheme"
  run compare
  assert_eq "$CODE" 1 "compare"
  assert_contains "$OUT" "GSETTINGS CHANGED: color-scheme"
}

t_plasmashell_running_refuses_snapshot_and_compare() {
  new_env
  export STUB_PGREP_MATCH=1
  run snapshot
  assert_eq "$CODE" 2 "snapshot"
  assert_contains "$ERR" "REFUSED: plasmashell is running"
  run compare
  assert_eq "$CODE" 2 "compare"
  assert_contains "$ERR" "REFUSED: plasmashell is running"
  run packages
  assert_eq "$CODE" 0 "packages still works, output: $OUT $ERR"
}

t_packages_ok_exits_0() {
  new_env
  run packages
  assert_eq "$CODE" 0 "packages, output: $OUT $ERR"
}

t_packages_missing_portal_kde_exits_1() {
  new_env
  export STUB_PACMAN_MISSING="xdg-desktop-portal-kde"
  run packages
  assert_eq "$CODE" 1 "packages"
  assert_contains "$OUT" "MISSING PACKAGE: xdg-desktop-portal-kde"
}

t_packages_qk_missing_files_exits_1() {
  new_env
  export STUB_PACMAN_BROKEN="plasma-desktop"
  run packages
  assert_eq "$CODE" 1 "packages"
  assert_contains "$OUT" "BROKEN PACKAGE: plasma-desktop"
}

t_noctalia_subcommand_propagates_exit_code() {
  new_env
  local good="$T/noctalia-good" bad="$T/noctalia-bad"
  mkdir -p "$good" "$bad"
  printf '[theme]\nsync_color_scheme = false\n\n[theme.templates]\nenable_builtin_templates = false\nenable_community_templates = false\n' >"$good/config.toml"
  printf '[theme]\nsync_color_scheme = true\n' >"$bad/config.toml"
  export NOCTALIA_REPO_CONFIG_DIR="$good"
  run noctalia
  assert_eq "$CODE" 0 "good config, output: $OUT $ERR"
  export NOCTALIA_REPO_CONFIG_DIR="$bad"
  run noctalia
  assert_eq "$CODE" 1 "bad config"
  assert_contains "$OUT" "SYNC_COLOR_SCHEME NOT FALSE"
  mkdir -p "$XDG_STATE_HOME/noctalia"
  printf '[theme]\nsync_color_scheme = true\n' >"$XDG_STATE_HOME/noctalia/settings.toml"
  export NOCTALIA_REPO_CONFIG_DIR="$good"
  run noctalia
  assert_eq "$CODE" 1 "GUI override under XDG_STATE_HOME must be read"
  assert_contains "$OUT" "settings.toml"
}

t_portal_overrides_are_watched() {
  new_env
  mkdir -p "$XDG_CONFIG_HOME/xdg-desktop-portal"
  printf '[preferred]\ndefault=kde\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/portals.conf"
  printf '[preferred]\ndefault=kde\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/kde-portals.conf"
  run snapshot
  assert_eq "$CODE" 0 "snapshot"
  printf '[preferred]\ndefault=gnome\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/kde-portals.conf"
  run compare
  assert_eq "$CODE" 1 "kde-portals.conf changed"
  assert_contains "$OUT" "CHANGED: xdg-desktop-portal/kde-portals.conf"

  new_env
  mkdir -p "$XDG_CONFIG_HOME/xdg-desktop-portal"
  printf '[preferred]\ndefault=kde\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/portals.conf"
  run snapshot
  rm "$XDG_CONFIG_HOME/xdg-desktop-portal/portals.conf"
  run compare
  assert_eq "$CODE" 1 "portals.conf removed"
  assert_contains "$OUT" "CHANGED: xdg-desktop-portal/portals.conf"
}

t_noctalia_subcommand_checks_the_live_config_dir() {
  new_env
  local good="$T/noctalia-good"
  mkdir -p "$good" "$XDG_CONFIG_HOME/noctalia"
  printf '[theme]\nsync_color_scheme = false\n\n[theme.templates]\nenable_builtin_templates = false\nenable_community_templates = false\n' >"$good/config.toml"
  printf '[theme]\nsync_color_scheme = true\n' >"$XDG_CONFIG_HOME/noctalia/extra.toml"
  export NOCTALIA_REPO_CONFIG_DIR="$good"
  run noctalia
  assert_eq "$CODE" 1 "an extra file in the live config dir must be caught"
  assert_contains "$OUT" "extra.toml"
}

t_noctalia_subcommand_honors_noctalia_home_overrides() {
  new_env
  local good="$T/noctalia-good"
  mkdir -p "$good" "$T/nc/noctalia" "$T/ns/noctalia"
  printf '[theme]\nsync_color_scheme = false\n\n[theme.templates]\nenable_builtin_templates = false\nenable_community_templates = false\n' >"$good/config.toml"
  cp "$good/config.toml" "$T/nc/noctalia/config.toml"
  export NOCTALIA_REPO_CONFIG_DIR="$good"
  export NOCTALIA_CONFIG_HOME="$T/nc"
  export NOCTALIA_STATE_HOME="$T/ns"
  run noctalia
  assert_eq "$CODE" 0 "clean overrides, output: $OUT $ERR"
  printf '[theme]\nsync_color_scheme = true\n' >"$T/ns/noctalia/settings.toml"
  run noctalia
  assert_eq "$CODE" 1 "settings.toml under NOCTALIA_STATE_HOME must be read"
  assert_contains "$OUT" "$T/ns/noctalia/settings.toml"
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
