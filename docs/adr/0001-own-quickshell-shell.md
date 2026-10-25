# ADR-0001: Own Quickshell shell "mizu", forked from SekaiPop and pruned, replacing Noctalia on niri

**Status:** Accepted under the user's autonomous brief. Review: an advisor review on 2026-10-25 (folded in below). The
planned deep-thinker review did not run: that agent died on a rate limit.
**Date:** 2026-10-25
**Deciders:** the user (brief), Claude (implementation)

## Context

- The niri session runs Noctalia v5. The user finds its widgets plain and wants SekaiPop's look and motion: the 2.5D
  phone quick panel (portrait), the settings phone (turned landscape), the launcher phone, and lively desktop widgets.
  The user does **not** want Project SEKAI's identity, only the code, widgets and animation as a base.
- Every color must come from a smart palette derived from the wallpaper, so the desktop matches any wallpaper.
- Hard rules: KDE Plasma's files stay byte-identical (no writes to kdeglobals, gtk-*, qt*ct, gsettings,
  environment.d, /etc); no sudo by Claude; one command for the user to switch.
- Facts (docs/research/quickshell-niri-shell.md, docs/research/sekaipop-harvest-map.md):
  - Noctalia v5 is C++ with Luau plugins, so QML parts cannot be grafted onto it.
  - SekaiPop is Quickshell QML (GPL-3.0, 369 files) built for Hyprland. **Baseline, measured 2026-10-25:** upstream
    with no patch, started in a sandbox (private HOME, XDG dirs and D-Bus) inside a nested niri 26.04, drew the bar,
    desktop clock and dock, and its quick panel (portrait phone with Wi-Fi, Bluetooth, mic, speaker and
    notifications), launcher phone and settings phone (landscape, 2.5D) all opened through `qs ipc call`.
    `Hyprland.focusedMonitor` is null there and the `focusedScreen()` helpers already fall back to the first screen.
    The first attempt showed no phone, but a repeat with longer waits did, so that failure was timing: the waits had
    been too short after the welcome tour was closed, and the shell restart that followed was the nested niri shutting
    down. Evidence is reproducible with the sandbox scripts described in the spec (section 10).
  - Its harvestable parts are pure UI, while the Hyprland coupling sits in a few host files and services. Its theming
    writes kdeglobals, GTK, qt*ct and gsettings by default, and ran `gsettings set` at startup in the sandbox.

## Decision

Fork SekaiPop's `sekaipop/` tree into this repo as the Quickshell config `mizu` (stow package `quickshell`), then
prune it. Remove every forbidden write and every out-of-scope module, replace the theme system with a tokens adapter
fed by our own palette tool, and replace Hyprland APIs with niri IPC. Noctalia stays installed: a one-word file
(`~/.config/niri/shell`) read by `shell-start` and `shell-ipc` picks the shell, and `switch-shell.sh --rollback`
goes back. Because the baseline already works on niri, the work is mostly removal and recolouring, not a port.

## Options considered

### A: Fork and prune (chosen)
| Dimension | Assessment |
|---|---|
| Complexity | Medium: delete first, then adapt in place; the internal singletons keep working |
| Cost | Large one-time pruning; the tree shrinks with each step |
| Risk | Leftover code paths; caught by static tests that grep for forbidden writes and Hyprland APIs |
| Familiarity | Quickshell QML; upstream already half-supports niri |

**Pros:**
- It runs at every step. Each removal is checked in the nested niri.
- The harvested files' 1000+ `mt.*` theme reads keep working through an adapter.

**Cons:**
- It inherits upstream's size and style.
- Upstream changes need manual merges; the fork commit is recorded.

### B: Cherry-pick files into a new tree
**Pros:** a clean tree from day one.
**Cons:**
- The pure-UI files depend on about 20 singletons (SettingsService, ShellScale, EditMode, PresetMotion, Theme...),
  so each pick drags its dependencies in.
- Nothing runs until most of the graph is rebuilt.
- In the end it is the same code, reached with more risk.

### C: Keep Noctalia, add a separate Quickshell "phone layer"
**Pros:** smallest change.
**Cons:**
- Two shells fight over the notification server, the polkit agent, the tray and the background layer.
- The look stays mixed, and the bar keeps Noctalia's style.

### D: Run SekaiPop on a Hyprland session
**Pros:** upstream as-is.
**Cons:**
- A third desktop to maintain, against the niri choice.
- Its theming writes Plasma's files by default.

## Trade-off analysis

A and B end in the same code. A keeps a running shell at every step, so the nested-niri screenshots can judge each
change. C fails the "one harmonious look" goal and doubles the singleton owners. D fails the Plasma rule and the
niri decision.

## Consequences

- **Easier:** iterating on the look with screenshots; the palette pipeline is ours and testable without a display.
- **Harder:** maintaining a GPL-3.0 fork (license and credits kept in `quickshell/.config/quickshell/mizu/`).
- **Revisit:**
  - pulling upstream fixes (fork point: upstream tree `4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf`);
  - the lock screen look;
  - the dock, tray and other modules left for later milestones.

## Action items

1. [ ] Spec: docs/superpowers/specs/2026-10-25-mizu-shell-design.md
2. [ ] Plan: docs/superpowers/plans/2026-10-25-mizu-shell.md
3. [ ] Implement milestone 1, then `scripts/switch-shell.sh`
