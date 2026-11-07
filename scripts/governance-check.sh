#!/usr/bin/env bash
# Dotfiles governance CI checkpoint — enforces AGENTS.md rules that are
# machine-checkable. Plasma byte-identity at install time (snapshot/compare)
# needs the user's machine and stays a manual gate, see docs/governance-ci.md.
# Usage: scripts/governance-check.sh
# Exit 0 = all checkpoints pass, 1 = violation.
set -u
cd "$(dirname "$0")/.." || exit 1
FAIL=0
pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1 — $2"; FAIL=1; }
CFG="noctalia/.config/noctalia/config.toml"

# Noctalia off-limits: sync_color_scheme must be false (else it writes kdeglobals)
if grep -qE '^[[:space:]]*sync_color_scheme[[:space:]]*=[[:space:]]*true' "$CFG" 2>/dev/null; then
  fail "Noctalia sync_color_scheme must be false" "$CFG"
else
  pass "Noctalia sync_color_scheme is not enabled"
fi

# Noctalia off-limits: builtin/community templates must stay disabled
BAD=$(grep -nE 'enable_(builtin|community)_templates[[:space:]]*=[[:space:]]*true' "$CFG" 2>/dev/null || true)
if [[ -n "$BAD" ]]; then fail "Noctalia templates must stay disabled" "$BAD"; else pass "Noctalia builtin/community templates disabled"; fi

# Noctalia off-limits: gnome-keyring must not appear in any tracked config
BAD=$(git grep -n 'gnome-keyring' -- '*.toml' '*.kdl' '*.conf' niri noctalia quickshell 2>/dev/null || true)
if [[ -n "$BAD" ]]; then fail "gnome-keyring referenced in tracked config" "$BAD"; else pass "no gnome-keyring in tracked config"; fi

# Plasma-owned files must never be tracked (byte-identity rule, repo side)
BAD=$(git ls-files | grep -E '(^|/)(kdeglobals|kdedefaults/kdeglobals|mimeapps\.list|gtk-3\.0/settings\.ini|gtk-4\.0/settings\.ini|xdg-desktop-portal-kderc|xdg-desktop-portal/(portals|kde-portals)\.conf)$' | grep -v 'niri-mimeapps' || true)
if [[ -n "$BAD" ]]; then fail "Plasma-owned file tracked in git" "$BAD"; else pass "no Plasma-owned files tracked"; fi

# No secrets in tracked files
BAD=$(git grep -n -iE 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' -- . 2>/dev/null || true)
if [[ -n "$BAD" ]]; then fail "secret material in tracked files" "$BAD"; else pass "no secret patterns in tracked files"; fi

echo
if [[ "$FAIL" -eq 0 ]]; then echo "Governance: ALL CHECKPOINTS PASS"; else echo "Governance: VIOLATIONS FOUND"; fi
exit "$FAIL"
