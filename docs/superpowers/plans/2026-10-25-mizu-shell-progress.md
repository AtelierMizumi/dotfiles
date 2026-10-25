# mizu shell: progress ledger

Plan: docs/superpowers/plans/2026-10-25-mizu-shell.md. Spec: docs/superpowers/specs/2026-10-25-mizu-shell-design.md.
Worktree `.claude/worktrees/smart-shell`, branch `smart-shell` (from local main de7ee4b). Never push to main.

## Done (committed)

- Phase 0: `Mod+BackSpace` cycles typing languages (`niri/.config/niri/scripts/fcitx5-cycle`); Noctalia takes its colors
  from the wallpaper (`faithful`); `~/.config/niri/colors.kdl` feeds the focus ring (Noctalia template).
- Palette tool (`quickshell/.config/quickshell/mizu/palette/`): `palette_core/{color,analysis,build,adapters}.py` and
  the CLI `mizu_palette.py`. Tests: `tests/test_mizu_palette_*.py`, `tests/test_niri_colors_include.sh`.
  A mutation check found and fixed one test gap. Security review fixed a KDL comment injection through the wallpaper path.
- Dev harness (`scripts/dev/`): `stage-quickshell.sh` (quickshell and the icon font from the mirror into
  `~/.cache/rice-staging`, signatures checked), `nested-shell.sh` (nested niri with private HOME/XDG/D-Bus),
  `palette_sheet.py`.

## Done (not yet committed: the safety scan is red until the tree is pruned)

- Fork import of SekaiPop `sekaipop/` into `quickshell/.config/quickshell/mizu/` (LICENSE, UPSTREAM.md); removed the
  modules, services and scripts listed in `tests/test_mizu_safety.py` REMOVED; retargeted paths (`sekaipop` ->
  `~/.cache/mizu/{state,data}`, `~/.config/quickshell/mizu-user`); renamed `modules/sekai` -> `modules/mizu` and the
  `Sekai*` types (PopupFrame, LeanKey, LeanNavKey, LeanTile, HubTile, NumberPlate, PhoneBackdrop, SlimScrollBar).
- Core, mine: `modules/common/{Tokens,ThemeSet,Theme}.qml` (colors only from tokens.json), `services/{Compositor,
  WallpaperService,GameModeService,EditMode,SettingsService}.qml`, `modules/mizu/background/WallpaperLayer.qml`,
  `modules/common/widgets/{EditChrome,EditStage,EditPreview,SizeKey}.qml` (inert stubs), `NiriMath.focusedOutput`
  (+ `tests/js/niri-test`, runner `tests/test_mizu_js.sh`).
- Verified in the nested niri (stage-1 shell: wallpaper layer + a strip of token swatches): the wallpaper crossfades,
  the palette tool runs, `tokens.json` appears, `Tokens` fades the colors, `Compositor.focusedOutput` reads niri.

## Findings and rulings so far

- Upstream SekaiPop's phone surfaces open on niri unpatched (the first failed walk was timing, not Hyprland).
- A `Behavior on <property>` inside a Singleton crashes Qt 6.12's QML engine here (segfault in
  `QQmlData::deferData`): Tokens fades through one animated `blend` number instead.
- After a hot reload Quickshell 0.3.2 no longer registers the instance under its shell path, so `qs -p <dir> ipc`
  finds nothing; the harness addresses the process with `--pid`.
- Ruling: keep upstream's small `scripts/state/*.sh` helpers (retargeted) instead of rewriting 25 services to FileView.
- Ruling: `WallpaperService` is new and small (one wallpaper for all monitors, `find -L` over the folder, palette run on
  each change); upstream's 1273-line one, its shaders, parallax and video wallpaper are not carried.
- Ruling: weather location defaults to "Ho Chi Minh City" (no IP lookup); launcher web suggestions default off.
- Ruling: `switch-shell.sh` never writes `~/.local/state/noctalia/settings.toml` (it held the user's GUI choice,
  Catppuccin, on 2026-10-25).

## Tools

- `scripts/dev/nested-shell.sh start <dir>|shot <name>|ipc <args>|log|stop` (needs `scripts/dev/stage-quickshell.sh` once).
  Per-agent state: `MIZU_DEV_STATE=~/.cache/mizu-dev-<name>`. The sandbox sees the wallpaper folder through a symlink at
  `$MIZU_DEV_STATE/sandbox-home/Pictures/Wallpapers` (create it once).
- `python3 -I -B scripts/dev/qml_unresolved.py <mizu dir> [--files NAME]` names that resolve to no file and no Qt type.
- `python3 -I -B scripts/dev/qml_theme_missing.py <mizu dir>` theme roles read but not defined by ThemeSet.
- `python3 -I -B scripts/dev/safety_list.py <repo root> [writes|hypr|sekai|programs]` the safety scan's findings.
- A dev shell for one surface: a directory with symlinks to `modules services scripts palette assets` of the mizu tree
  and its own `shell.qml` (see the stage-1 example in this ledger's history).

## Left

1. Bar (`modules/mizu/bar`), quick panel + OSD + notifications + polkit (`modules/mizu/quickPanel`, `onScreenDisplay`,
   `notificationPopup`, `polkit`, services `QuickSource`, `NotificationSource`, `OSDSource`, `PanelImages`), launcher,
   settings pages, desktop widgets, lock + idle: remove removed-service references, Hyprland calls, forbidden writes and
   hex literals; screenshot each on dark, bright and grey wallpapers.
2. New `shell.qml` (compositing all of it), `services/MizuIpc.qml` (target `mizu`), `Idle.qml`, `Catcher.qml`.
3. Hex-literal test, import-resolution check, imported JS tests of the kept libraries.
4. `niri/.config/niri/scripts/{shell-start,shell-ipc}` + binds, `scripts/switch-shell.sh`, docs, quality gates.
