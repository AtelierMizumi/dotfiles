#!/usr/bin/env bash
# Rice SDDM with a modern theme matching the Niri session
# Usage:
#   scripts/rice-sddm.sh [astronaut|catppuccin] [--sync-wallpaper]
#   scripts/rice-sddm.sh --test [astronaut|catppuccin]
set -euo pipefail

THEME_CHOICE="${1:-astronaut}"
SYNC_WALLPAPER=0

for arg in "$@"; do
  case "$arg" in
    --sync-wallpaper)
      SYNC_WALLPAPER=1
      ;;
    --test)
      THEME_NAME="sddm-astronaut-theme"
      if [[ "${2:-}" == "catppuccin" ]]; then
        THEME_NAME="catppuccin-mocha"
      fi
      THEME_PATH="/usr/share/sddm/themes/$THEME_NAME"
      if [[ ! -d "$THEME_PATH" ]]; then
        echo "Theme not installed yet at $THEME_PATH" >&2
        echo "Run 'sudo bash scripts/rice-sddm.sh $THEME_CHOICE' first." >&2
        exit 1
      fi
      echo "Launching SDDM greeter in test mode (press Ctrl+C or close window to exit)..."
      exec sddm-greeter-qt6 --test-mode --theme "$THEME_PATH"
      ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "This script configures system-level SDDM (/etc/sddm.conf.d, /usr/share/sddm)."
  echo "Please run with sudo:"
  echo "  sudo bash scripts/rice-sddm.sh [astronaut|catppuccin] [--sync-wallpaper]"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

mkdir -p /etc/sddm.conf.d
mkdir -p /usr/share/sddm/themes

case "$THEME_CHOICE" in
  astronaut|sddm-astronaut-theme)
    SELECTED_THEME="sddm-astronaut-theme"
    TARGET_DIR="/usr/share/sddm/themes/sddm-astronaut-theme"
    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "==> Installing sddm-astronaut-theme from AUR / git..."
      if [[ -d "/tmp/sddm-astronaut-theme" ]]; then
        cp -r /tmp/sddm-astronaut-theme "$TARGET_DIR"
      else
        git clone --depth=1 https://github.com/Keyitdev/sddm-astronaut-theme.git "$TARGET_DIR"
      fi
    fi

    # Set up user-writable background target for dynamic wallpaper sync
    BG_FILE="$TARGET_DIR/Backgrounds/current_wallpaper.jpg"
    if [[ ! -f "$BG_FILE" ]]; then
      if [[ -f "$TARGET_DIR/Backgrounds/astronaut.png" ]]; then
        cp "$TARGET_DIR/Backgrounds/astronaut.png" "$BG_FILE"
      fi
    fi
    chown "$REAL_USER":"$REAL_USER" "$BG_FILE" 2>/dev/null || true
    chmod 664 "$BG_FILE" 2>/dev/null || true

    # Configure metadata / theme to point to current_wallpaper.jpg
    if [[ -f "$TARGET_DIR/metadata.desktop" ]]; then
      sed -i 's|ConfigFile=.*|ConfigFile=Themes/astronaut.conf|' "$TARGET_DIR/metadata.desktop"
    fi
    if [[ -f "$TARGET_DIR/Themes/astronaut.conf" ]]; then
      sed -i 's|Background=.*|Background="Backgrounds/current_wallpaper.jpg"|' "$TARGET_DIR/Themes/astronaut.conf"
    fi
    ;;

  catppuccin|catppuccin-mocha)
    SELECTED_THEME="catppuccin-mocha"
    TARGET_DIR="/usr/share/sddm/themes/catppuccin-mocha"
    if [[ ! -d "$TARGET_DIR" ]]; then
      echo "==> Installing Catppuccin Mocha SDDM theme..."
      ZIP_URL="https://github.com/catppuccin/sddm/releases/download/v1.0.0/catppuccin-mocha.zip"
      TMP_ZIP="/tmp/catppuccin-mocha.zip"
      curl -fsSL "$ZIP_URL" -o "$TMP_ZIP" || true
      if [[ -f "$TMP_ZIP" ]] && command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$TMP_ZIP" -d /usr/share/sddm/themes/
        rm -f "$TMP_ZIP"
      elif [[ -d "/tmp/sddm-catppuccin" ]]; then
        cp -r /tmp/sddm-catppuccin/src "$TARGET_DIR"
      fi
    fi

    BG_FILE="$TARGET_DIR/backgrounds/wall.png"
    if [[ -f "$BG_FILE" ]]; then
      chown "$REAL_USER":"$REAL_USER" "$BG_FILE" 2>/dev/null || true
      chmod 664 "$BG_FILE" 2>/dev/null || true
    fi
    ;;

  *)
    echo "Unknown theme: $THEME_CHOICE (choose 'astronaut' or 'catppuccin')" >&2
    exit 1
    ;;
esac

# Write SDDM theme drop-in config
cat <<EOF > /etc/sddm.conf.d/10-theme.conf
[Theme]
Current=$SELECTED_THEME
CursorTheme=breeze_cursors
CursorSize=24
EOF

echo "==> SDDM theme set to $SELECTED_THEME in /etc/sddm.conf.d/10-theme.conf"

# Sync current wallpaper if requested or if available
ACTIVE_WALL="$REAL_HOME/.cache/mizu/state/wallpaper"
if [[ $SYNC_WALLPAPER -eq 1 || -f "$ACTIVE_WALL" ]]; then
  WALL_PATH=$(tr -d '[:space:]' < "$ACTIVE_WALL")
  if [[ -f "$WALL_PATH" ]]; then
    echo "==> Syncing active Niri wallpaper ($WALL_PATH) to SDDM..."
    if [[ "$SELECTED_THEME" == "sddm-astronaut-theme" ]]; then
      cp "$WALL_PATH" "/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg" || true
    elif [[ "$SELECTED_THEME" == "catppuccin-mocha" ]]; then
      cp "$WALL_PATH" "/usr/share/sddm/themes/catppuccin-mocha/backgrounds/wall.png" || true
    fi
  fi
fi

echo "==> Done! You can test the login screen by running:"
echo "    scripts/rice-sddm.sh --test $THEME_CHOICE"
