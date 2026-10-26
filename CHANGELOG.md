# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-26

### Added
- **Dual-Shell Wayland Environment**:
  - Implemented **Mizu** (Quickshell) as the primary rich desktop shell featuring dynamic Material You/KDE color palette extraction from the active wallpaper, 3D perspective phone projection launcher, synced lyrics player, and comprehensive desktop widgets (Weather for VKU Da Nang, Calendar, Player ID Card, Sticky Notes, Pomodoro/Stopwatch Timer).
  - Implemented **Noctalia** as an ultra-lightweight, resilient fallback shell.
  - Added `scripts/switch-shell.sh` and `niri/.config/niri/scripts/shell-ipc` for seamless, safe shell switching and unified hotkey control.
- **KDE Plasma Coexistence & Safety Verification**:
  - Added `scripts/check-plasma-intact.sh` snapshot and hash verification ensuring KDE Plasma's files (`kdeglobals`, `mimeapps.list`, `gtk-*`, `xdg-desktop-portal/*`) remain 100% byte-identical.
  - Scoped all environment variables, theme overrides, and portal routing strictly to the `niri` session.
- **Desktop-Specific File Manager Association**:
  - Configured `niri/.config/niri-mimeapps.list` to set GNOME Nautilus as the default directory handler specifically inside niri without overriding KDE Plasma's Dolphin handler.
  - Bound `Mod+E` in `niri/config.kdl` to Nautilus.
- **Theme & Dark/Light Synchronization**:
  - Added `niri/.config/niri/scripts/sync-theme` to synchronize GTK `color-scheme`, KDE color schemes (`plasma-apply-colorscheme BreezeDark` / `BreezeLight`), and D-Bus portal activation.
  - Exported `QT_QPA_PLATFORMTHEME=kde` in `shell-start` for Breeze icon and widget theme resolution.
- **Display Configuration & Integer Scaling**:
  - Configured native 1.0 integer scaling on internal laptop display `eDP-1` (1920x1080@144Hz) and seamless multi-monitor canvas on `HDMI-A-1` (1920x1080@120Hz at `x=1920 y=0`), eliminating fractional scaling blur.
- **Multilingual Input Method Switching**:
  - Added `niri/.config/niri/scripts/fcitx5-cycle` bound to `Super+BackSpace` to cycle smoothly through English (US) -> Vietnamese (Lotus) -> Japanese (Anthy).
- **Test Automation & Documentation**:
  - Created 292 automated tests in `tests/run-all.sh` covering ShellCheck, bash unit tests, Python unittests, and WCAG 2.1 AA contrast compliance.
  - Overhauled `README.md` with complete architecture specifications, cheat sheet, and TTY installation runbook.
  - Added `docs/USAGE.md` detailing keyboard shortcuts and ergonomic mapping for both laptop keyboards and Sofle split keyboards.
