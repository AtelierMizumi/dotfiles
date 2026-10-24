#!/usr/bin/env bash
# The user's generic ~/.config/xdg-desktop-portal/portals.conf routes every backend (ScreenCast, Screenshot, ...) to
# kde and outranks the system niri-portals.conf, which would break screen share in niri. A desktop-specific
# niri-portals.conf in the same directory wins over that generic file, so the repo ships one.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONF="$ROOT/niri/.config/xdg-desktop-portal/niri-portals.conf"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

t_override_exists() {
  [[ -f "$CONF" ]] || fail "$CONF is missing"
}

t_default_backend_is_gnome_then_gtk() {
  [[ -f "$CONF" ]] || fail "$CONF is missing"
  grep -qxF 'default=gnome;gtk;' "$CONF" || fail "default is not gnome;gtk;"
}

t_no_kde_backend_in_the_niri_session() {
  [[ -f "$CONF" ]] || fail "$CONF is missing"
  ! grep -qi 'kde' "$CONF" || fail "a kde backend is referenced; screen share needs the gnome portal in niri"
}

t_access_and_notification_use_gtk() {
  [[ -f "$CONF" ]] || fail "$CONF is missing"
  grep -qxF 'org.freedesktop.impl.portal.Access=gtk;' "$CONF" || fail "Access is not gtk"
  grep -qxF 'org.freedesktop.impl.portal.Notification=gtk;' "$CONF" || fail "Notification is not gtk"
}

t_no_backend_that_is_not_installed() {
  [[ -f "$CONF" ]] || fail "$CONF is missing"
  ! grep -q 'gnome-keyring' "$CONF" || fail "gnome-keyring is deliberately not installed (it provides org.freedesktop.secrets)"
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
