# dotfiles

Personal Arch Linux rice: a scrollable-tiling Wayland session (niri) with a Quickshell-/native-based shell,
living **next to** KDE Plasma without touching it.

> Status: planning. Nothing here is installed or symlinked yet.

## Goals

- Keep the existing KDE Plasma session fully working (separate session picked at the display manager).
- Reproducible: every config lives in this repo, installs are explicit and reversible.
- Gaming-friendly on the hybrid Intel iGPU + NVIDIA dGPU laptop (compositor on iGPU, games on dGPU).

## Rules

- No secrets (`.env`, tokens, keys) and no binary documents in this repo.
- Environment variables for the rice go in the compositor config, never in `environment.d` or shell profiles
  (they would leak into Plasma).
- Back up the shared theming files before the first run of any dynamic-theming tool.

## Layout

To be decided in the design spec.
