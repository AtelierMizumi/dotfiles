#!/usr/bin/env bash
# Synchronize active Niri wallpaper with SDDM theme background
set -euo pipefail

NEW_WALL="${1:-}"

if [[ -z "$NEW_WALL" ]]; then
  CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/state/wallpaper"
  if [[ -f "$CACHE_FILE" ]]; then
    NEW_WALL=$(tr -d '[:space:]' < "$CACHE_FILE")
  fi
fi

if [[ -z "$NEW_WALL" || ! -f "$NEW_WALL" ]]; then
  exit 0
fi

# Candidates for SDDM theme background destinations
SDDM_BG_TARGETS=(
  "/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/current_wallpaper.jpg"
  "/usr/share/sddm/themes/catppuccin-mocha/backgrounds/wall.png"
)

for target in "${SDDM_BG_TARGETS[@]}"; do
  dir=$(dirname "$target")
  if [[ -d "$dir" && -w "$dir" ]] || [[ -f "$target" && -w "$target" ]]; then
    cp "$NEW_WALL" "$target" 2>/dev/null || true
  fi
done
