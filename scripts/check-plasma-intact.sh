#!/usr/bin/env bash
# Prove that a rice install left KDE Plasma alone.
#
#   check-plasma-intact.sh snapshot [--state-dir DIR]   record hashes of Plasma-shared files and gsettings values
#   check-plasma-intact.sh compare  [--state-dir DIR]   report anything that differs from the snapshot
#   check-plasma-intact.sh packages                     check Plasma, portal and SDDM packages are installed and intact
#   check-plasma-intact.sh noctalia                     check Noctalia config invariants
#
# snapshot and compare refuse to run while plasmashell is running: Plasma rewrites some of these files itself,
# so a comparison across a Plasma session reports false positives. Run them inside the niri session.
# Exit codes: 0 ok, 1 violation found, 2 usage error, missing snapshot or refused.
set -euo pipefail

WATCHED_FILES=(
  kdeglobals
  kdedefaults/kdeglobals
  mimeapps.list
  gtk-3.0/settings.ini
  gtk-4.0/settings.ini
  xdg-desktop-portal-kderc
  xdg-desktop-portal/portals.conf
  xdg-desktop-portal/kde-portals.conf
)
GSETTINGS_SCHEMA=org.gnome.desktop.interface
GSETTINGS_KEYS=(color-scheme gtk-theme)
PACKAGES=(xdg-desktop-portal-kde plasma-desktop sddm)

CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
PACMAN_BIN=${PACMAN_BIN:-pacman}
GSETTINGS_BIN=${GSETTINGS_BIN:-gsettings}
PGREP_BIN=${PGREP_BIN:-pgrep}

usage() {
  echo "usage: $(basename "$0") <snapshot|compare|packages|noctalia> [--state-dir DIR]" >&2
  exit 2
}

refuse_if_plasma_running() {
  if "$PGREP_BIN" -x plasmashell >/dev/null 2>&1; then
    echo "REFUSED: plasmashell is running (log out of Plasma and run this from the niri session)" >&2
    exit 2
  fi
}

# Print the sha256 of a watched file, or MISSING if it does not exist.
hash_of() {
  local path="$CONFIG_HOME/$1"
  if [[ -f "$path" ]]; then
    sha256sum <"$path" | cut -d' ' -f1
  else
    echo MISSING
  fi
}

# Print the gsettings value for a key, or UNAVAILABLE when gsettings fails (no binary, no D-Bus session).
gsettings_value() {
  local value
  if value=$("$GSETTINGS_BIN" get "$GSETTINGS_SCHEMA" "$1" 2>/dev/null); then
    printf '%s' "$value"
  else
    printf 'UNAVAILABLE'
  fi
}

cmd_snapshot() {
  refuse_if_plasma_running
  mkdir -p "$state_dir"
  local rel key
  for rel in "${WATCHED_FILES[@]}"; do
    printf '%s\t%s\n' "$(hash_of "$rel")" "$rel"
  done >"$state_dir/files.sha256"
  for key in "${GSETTINGS_KEYS[@]}"; do
    printf '%s\t%s\n' "$key" "$(gsettings_value "$key")"
  done >"$state_dir/gsettings.txt"
  echo "Snapshot written to $state_dir"
}

cmd_compare() {
  refuse_if_plasma_running
  if [[ ! -f "$state_dir/files.sha256" || ! -f "$state_dir/gsettings.txt" ]]; then
    echo "NO SNAPSHOT in $state_dir: run 'snapshot' first" >&2
    exit 2
  fi
  local violations=0 old new rel key
  while IFS=$'\t' read -r old rel; do
    new=$(hash_of "$rel")
    if [[ "$old" != "$new" ]]; then
      echo "CHANGED: $rel"
      violations=1
    fi
  done <"$state_dir/files.sha256"
  while IFS=$'\t' read -r key old; do
    new=$(gsettings_value "$key")
    if [[ "$old" != "$new" ]]; then
      echo "GSETTINGS CHANGED: $key"
      violations=1
    fi
  done <"$state_dir/gsettings.txt"
  if [[ $violations -ne 0 ]]; then
    exit 1
  fi
  echo "OK: Plasma-shared files and gsettings match the snapshot"
}

cmd_packages() {
  local violations=0 pkg output
  for pkg in "${PACKAGES[@]}"; do
    if ! "$PACMAN_BIN" -Q "$pkg" >/dev/null 2>&1; then
      echo "MISSING PACKAGE: $pkg"
      violations=1
      continue
    fi
    output=$("$PACMAN_BIN" -Qk "$pkg" 2>&1 || true)
    if [[ "$output" != *", 0 missing files"* ]]; then
      echo "BROKEN PACKAGE: $pkg"
      violations=1
    fi
  done
  if [[ $violations -ne 0 ]]; then
    exit 1
  fi
  echo "OK: ${PACKAGES[*]} are installed and intact"
}

cmd_noctalia() {
  local script_dir repo_config live_config settings
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  repo_config=${NOCTALIA_REPO_CONFIG_DIR:-$script_dir/../noctalia/.config/noctalia}
  # Noctalia prefers its own NOCTALIA_*_HOME variables over XDG, and loads the live config dir, not the repo.
  live_config="${NOCTALIA_CONFIG_HOME:-$CONFIG_HOME}/noctalia"
  settings="${NOCTALIA_STATE_HOME:-$STATE_HOME}/noctalia/settings.toml"
  python3 -I -B "$script_dir/check_noctalia.py" "$repo_config" "$settings" "$live_config"
}

command_name=${1:-}
[[ -n "$command_name" ]] || usage
shift
state_dir="$STATE_HOME/dotfiles-check"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-dir)
      [[ $# -ge 2 ]] || usage
      state_dir=$2
      shift 2
      ;;
    *) usage ;;
  esac
done

case "$command_name" in
  snapshot) cmd_snapshot ;;
  compare) cmd_compare ;;
  packages) cmd_packages ;;
  noctalia) cmd_noctalia ;;
  *) usage ;;
esac
