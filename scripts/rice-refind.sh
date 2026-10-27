#!/usr/bin/env bash
# Rice rEFInd bootloader with Catppuccin theme and optional wallpaper
# Usage:
#   sudo bash scripts/rice-refind.sh [--wallpaper [PATH]]
#   sudo bash scripts/rice-refind.sh --rollback
set -euo pipefail

REFIND_DIR="/boot/EFI/refind"
CONF_FILE="$REFIND_DIR/refind.conf"
THEMES_DIR="$REFIND_DIR/themes"
CATPPUCCIN_DIR="$THEMES_DIR/catppuccin"

if [[ $EUID -ne 0 ]]; then
  echo "This script writes to /boot/EFI/refind/."
  echo "Please run with sudo:"
  echo "  sudo bash scripts/rice-refind.sh [--wallpaper]"
  exit 1
fi

if [[ ! -d "$REFIND_DIR" ]]; then
  echo "Error: rEFInd directory not found at $REFIND_DIR" >&2
  exit 1
fi

if [[ ! -f "$CONF_FILE" ]]; then
  echo "Error: rEFInd config file not found at $CONF_FILE" >&2
  exit 1
fi

# Rollback mode
if [[ "${1:-}" == "--rollback" ]]; then
  LATEST_BACKUP=$(find "$REFIND_DIR" -maxdepth 1 -name "refind.conf.bak.*" | sort -r | head -n 1)
  if [[ -n "$LATEST_BACKUP" && -f "$LATEST_BACKUP" ]]; then
    echo "==> Rolling back refind.conf from $LATEST_BACKUP..."
    cp "$LATEST_BACKUP" "$CONF_FILE"
    echo "==> Successfully restored refind.conf."
    exit 0
  else
    echo "No backup found in $REFIND_DIR to restore." >&2
    exit 1
  fi
fi

# Backup refind.conf
BACKUP_FILE="$REFIND_DIR/refind.conf.bak.$(date +%Y%m%d%H%M%S)"
echo "==> Creating backup: $BACKUP_FILE..."
cp "$CONF_FILE" "$BACKUP_FILE"

# Prepare Catppuccin theme
mkdir -p "$CATPPUCCIN_DIR"
if [[ -d "/tmp/refind-catppuccin" ]]; then
  cp -r /tmp/refind-catppuccin/assets "$CATPPUCCIN_DIR/"
  cp /tmp/refind-catppuccin/*.conf "$CATPPUCCIN_DIR/"
else
  echo "==> Cloning catppuccin/refind..."
  git clone --depth=1 https://github.com/catppuccin/refind.git /tmp/refind-catppuccin-install
  cp -r /tmp/refind-catppuccin-install/assets "$CATPPUCCIN_DIR/"
  cp /tmp/refind-catppuccin-install/*.conf "$CATPPUCCIN_DIR/"
  rm -rf /tmp/refind-catppuccin-install
fi

# Handle custom wallpaper banner if requested
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
WALLPAPER_SRC=""

if [[ "${1:-}" == "--wallpaper" ]]; then
  if [[ -n "${2:-}" && -f "${2:-}" ]]; then
    WALLPAPER_SRC="$2"
  else
    CACHE_WALL="$REAL_HOME/.cache/mizu/state/wallpaper"
    if [[ -f "$CACHE_WALL" ]]; then
      WALLPAPER_SRC=$(tr -d '[:space:]' < "$CACHE_WALL")
    fi
  fi
fi

if [[ -n "$WALLPAPER_SRC" && -f "$WALLPAPER_SRC" ]]; then
  echo "==> Rendering active wallpaper ($WALLPAPER_SRC) for rEFInd..."
  BANNER_PNG="$CATPPUCCIN_DIR/assets/mocha/background.png"
  if command -v magick >/dev/null 2>&1; then
    magick "$WALLPAPER_SRC" -resize 1920x1080^ -gravity center -extent 1920x1080 "$BANNER_PNG"
  elif command -v convert >/dev/null 2>&1; then
    convert "$WALLPAPER_SRC" -resize 1920x1080^ -gravity center -extent 1920x1080 "$BANNER_PNG"
  fi
  echo "==> Wallpaper banner installed to $BANNER_PNG"
fi

# Add include to refind.conf if not already present
INCLUDE_LINE="include themes/catppuccin/mocha.conf"
# Remove any existing catppuccin includes first to prevent duplicates
sed -i '/include themes\/catppuccin/d' "$CONF_FILE"

{
  echo ""
  echo "# Catppuccin Mocha Rice Theme"
  echo "$INCLUDE_LINE"
} >> "$CONF_FILE"

echo "==> rEFInd riced successfully with Catppuccin Mocha!"
echo "==> To rollback anytime: sudo bash scripts/rice-refind.sh --rollback"
