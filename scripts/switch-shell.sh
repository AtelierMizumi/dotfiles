#!/usr/bin/env bash
# Switch session between Quickshell mizu and Noctalia.
# Usage: switch-shell.sh [--dry-run] [--rollback] [--yes]
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
NIRI_SHELL_FILE="$CONFIG_HOME/niri/shell"
STAGING_DIR="${RICE_STAGE:-$HOME/.cache/rice-staging}"

dry_run=0
rollback=0
yes_flag=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --rollback)
      rollback=1
      ;;
    --yes)
      yes_flag=1
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--dry-run] [--rollback] [--yes]"
      echo "  --dry-run   Simulate all steps without modifying the system"
      echo "  --rollback  Revert active shell to Noctalia"
      echo "  --yes       Skip confirmation prompt"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

reload_session() {
  local target_shell="$1"
  if command -v niri >/dev/null 2>&1; then
    niri msg action load-config-file >/dev/null 2>&1 || true
  fi
  if [[ "$target_shell" == "noctalia" ]]; then
    pkill -x quickshell >/dev/null 2>&1 || true
    pkill -x qs >/dev/null 2>&1 || true
    if command -v noctalia >/dev/null 2>&1; then
      noctalia >/dev/null 2>&1 &
    fi
  else
    pkill -x noctalia >/dev/null 2>&1 || true
    pkill -x quickshell >/dev/null 2>&1 || true
    pkill -x qs >/dev/null 2>&1 || true
    local start_script="$CONFIG_HOME/niri/scripts/shell-start"
    if [[ -x "$start_script" ]]; then
      nohup "$start_script" >/dev/null 2>&1 &
    elif [[ -x "$ROOT/niri/.config/niri/scripts/shell-start" ]]; then
      nohup "$ROOT/niri/.config/niri/scripts/shell-start" >/dev/null 2>&1 &
    fi
  fi
}

# --- Rollback Mode ---
if [[ $rollback -eq 1 ]]; then
  echo "==> Rolling back shell to Noctalia..."
  if [[ $dry_run -eq 1 ]]; then
    echo "[dry-run] Would write 'noctalia' to $NIRI_SHELL_FILE"
    echo "[dry-run] Would reload niri and launch noctalia"
    exit 0
  fi

  mkdir -p "$(dirname "$NIRI_SHELL_FILE")"
  echo "noctalia" >"$NIRI_SHELL_FILE"
  reload_session "noctalia"
  echo "==> Successfully rolled back to Noctalia."
  exit 0
fi

# --- Preflight: the main checkout only ---
# Stow links ~/.config into the checkout it runs from: from a worktree under .claude/worktrees/ the live config would
# point at a directory that goes away with the worktree. (MIZU_ALLOW_WORKTREE=1 is for the tests, which run the script
# from wherever the repo is checked out.)
if [[ "$ROOT" == */.claude/worktrees/* && "${MIZU_ALLOW_WORKTREE:-0}" != "1" ]]; then
  echo "ERROR: run this from the main checkout, not from a worktree ($ROOT)." >&2
  exit 1
fi

# --- Preflight Package Conflicts Check ---
packages_needed=(brightnessctl cliphist wlsunset)
if [[ -n "${MIZU_EXTRA_PACKAGES:-}" ]]; then
  # shellcheck disable=SC2206
  packages_needed+=($MIZU_EXTRA_PACKAGES)
fi

echo "==> Checking for package conflicts..."
if command -v pacman >/dev/null 2>&1; then
  if ! pacman -Sp "${packages_needed[@]}" >/dev/null 2>&1; then
    echo "ERROR: Package conflict detected while resolving dependencies for: ${packages_needed[*]}" >&2
    exit 1
  fi
fi

# --- Dry Run Mode ---
if [[ $dry_run -eq 1 ]]; then
  echo "==> [dry-run] Preflight checks passed."
  echo "==> [dry-run] Would install packages: ${packages_needed[*]}"
  if [[ -d "$STAGING_DIR/pkgs" ]]; then
    echo "==> [dry-run] Would install local staged packages from $STAGING_DIR/pkgs"
  fi
  echo "==> [dry-run] Would merge branch smart-shell into main"
  echo "==> [dry-run] Would run: stow --no-folding -t \"$HOME\" quickshell niri"
  echo "==> [dry-run] Would write 'mizu' to $NIRI_SHELL_FILE"
  echo "==> [dry-run] Would reload niri session to launch mizu"
  echo "==> [dry-run] Complete (no changes made)."
  exit 0
fi

# --- Install Packages ---
echo "==> Installing required packages..."
if command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm "${packages_needed[@]}"
  if compgen -G "$STAGING_DIR/pkgs/*.pkg.tar.zst" >/dev/null; then
    echo "==> Installing staged quickshell packages..."
    # shellcheck disable=SC2046
    sudo pacman -U --needed --noconfirm $(compgen -G "$STAGING_DIR/pkgs/*.pkg.tar.zst")
  fi
fi

# --- Merge smart-shell into main ---
# Fast-forward only: a smart-shell that has diverged from main stops the switch before anything is stowed.
if command -v git >/dev/null 2>&1; then
  current_branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if [[ "$current_branch" == "main" ]] && git -C "$ROOT" rev-parse --verify --quiet smart-shell >/dev/null 2>&1; then
    echo "==> Merging branch smart-shell into main (fast-forward only)..."
    if ! git -C "$ROOT" merge --ff-only smart-shell; then
      echo "ERROR: smart-shell cannot be fast-forwarded into main; nothing was stowed or switched." >&2
      exit 1
    fi
  fi
fi

# --- Stow Configurations ---
echo "==> Stowing configuration directories..."
if command -v stow >/dev/null 2>&1; then
  (cd "$ROOT" && stow --no-folding -t "$HOME" quickshell niri)
fi

# --- Switch Session to Mizu ---
echo "==> Activating mizu shell..."
mkdir -p "$(dirname "$NIRI_SHELL_FILE")"
echo "mizu" >"$NIRI_SHELL_FILE"
reload_session "mizu"

# --- Confirmation Loop ---
if [[ $yes_flag -eq 0 ]]; then
  confirm_timeout="${MIZU_CONFIRM_SECONDS:-60}"
  echo ""
  echo "Mizu shell has been started!"
  echo "Please verify that the shell displays properly."
  response=""
  if read -r -t "$confirm_timeout" -p "Keep Mizu shell? [Y/n] (auto-revert in ${confirm_timeout}s): " answer; then
    response="$answer"
  else
    echo ""
    echo "Confirmation timed out after ${confirm_timeout}s."
    response="n"
  fi

  if [[ "$response" =~ ^[Nn] ]]; then
    echo "==> Reverting session back to Noctalia..."
    echo "noctalia" >"$NIRI_SHELL_FILE"
    reload_session "noctalia"
    echo "==> Successfully reverted to Noctalia."
    exit 1
  fi
fi

echo "==> Mizu shell activated and confirmed!"
exit 0
