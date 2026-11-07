#!/usr/bin/env bash
# Test-first harness for scripts/governance-check.sh (dotfiles)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/scripts/governance-check.sh"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL - $1"; }

if [[ ! -x "$CHECK" ]]; then
  echo "FAIL - governance-check.sh does not exist yet (RED)"
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
git init -q
git config user.email "test@example.com"
git config user.name "Test"
git config commit.gpgsign false
mkdir -p scripts noctalia/.config/noctalia niri/.config
cp "$CHECK" scripts/governance-check.sh
chmod +x scripts/governance-check.sh
CHECK=scripts/governance-check.sh
cat > noctalia/.config/noctalia/config.toml <<'EOF'
[theme]
sync_color_scheme = false
[theme.templates]
enable_builtin_templates = false
enable_community_templates = false
EOF
echo "x" > niri/.config/config.kdl
git add -A
git commit -qm "feat(niri): add config (#1)"
if "$CHECK" >/dev/null 2>&1; then ok "clean repo passes"; else bad "clean repo should pass"; fi

# Violation 1: sync_color_scheme enabled
sed -i 's/sync_color_scheme = false/sync_color_scheme = true/' noctalia/.config/noctalia/config.toml
git add noctalia/.config/noctalia/config.toml
if "$CHECK" >/dev/null 2>&1; then bad "sync_color_scheme=true should fail"; else ok "sync_color_scheme=true fails check"; fi
git checkout -q -- noctalia/.config/noctalia/config.toml

# Violation 2: builtin templates enabled
sed -i 's/enable_builtin_templates = false/enable_builtin_templates = true/' noctalia/.config/noctalia/config.toml
git add noctalia/.config/noctalia/config.toml
if "$CHECK" >/dev/null 2>&1; then bad "builtin templates=true should fail"; else ok "builtin templates=true fails check"; fi
git checkout -q -- noctalia/.config/noctalia/config.toml

# Violation 3: gnome-keyring referenced in config
echo 'gnome-keyring' >> niri/.config/config.kdl
git add niri/.config/config.kdl
if "$CHECK" >/dev/null 2>&1; then bad "gnome-keyring in config should fail"; else ok "gnome-keyring in config fails check"; fi
git checkout -q -- niri/.config/config.kdl

# Violation 4: tracked Plasma-owned file
echo "x" > kdeglobals
git add kdeglobals
if "$CHECK" >/dev/null 2>&1; then bad "tracked kdeglobals should fail"; else ok "tracked kdeglobals fails check"; fi
git reset -q HEAD kdeglobals; rm -f kdeglobals

echo
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
