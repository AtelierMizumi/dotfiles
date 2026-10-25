# Porting brief: one surface of the mizu shell

Read this whole file first, then your own assignment (given in your prompt). It is the shared rulebook for everybody
porting a part of the forked SekaiPop tree. The repo is the worktree
`/home/thuanc177/Projects/Tools/dotfiles/.claude/worktrees/smart-shell` (branch `smart-shell`); use absolute paths.

## What this is

`quickshell/.config/quickshell/mizu/` is a fork of the Quickshell config of SekaiPop (GPL-3.0, built for the Hyprland
compositor), being turned into a theme-neutral shell for the **niri** compositor on Arch Linux. Background:
`docs/adr/0001-own-quickshell-shell.md`, `docs/superpowers/specs/2026-10-25-mizu-shell-design.md`,
`docs/research/sekaipop-harvest-map.md` (per-file notes, Hyprland coupling, replacements) and
`docs/research/quickshell-niri-shell.md` (Quickshell 0.3.2 and niri IPC facts). The progress ledger is
`docs/superpowers/plans/2026-10-25-mizu-shell-progress.md`.

The goal of the port: the same look and motion as upstream, but

1. **every color comes from the wallpaper palette**: components read `mt.<role>` (`readonly property var mt:
   Theme.of(QsWindow.window)` or `Theme.of(screen)`) and `modules/common/ThemeSet.qml` maps the roles onto
   `Tokens.qml`. No hex color literal is allowed in your files (named colors `"white"`, `"black"`, `"transparent"` and
   `Qt.rgba(r, g, b, a)` with literal numbers for neutral shadows and scrims are fine). ThemeSet roles you can use:
   `colBorder accentCyan accentMint textWhite surface surfaceHover surfaceDivider surfaceRing ringWhite surfaceTint ink
   inkSub paper line lineShadow chipFill chipInk scrim danger warning attributeColors` (five colors), the `p*` aliases
   (`pInk pSurface ...`), `phone*` plastics, and `barHousing barAlpha phoneHousing phoneAlpha widgetHousing widgetAlpha`
   (a housing color and opacity the palette tool fitted to the wallpaper behind that kind of surface: use them for a
   translucent background). Hard-coded reds and oranges become `mt.danger` / `mt.warning`; fixed pastel sets become
   `mt.attributeColors[i]`; white ink on a picture becomes `mt.textWhite`. Add a role to ThemeSet only if truly needed
   (and say so in your report; ThemeSet is not yours).
2. **no Hyprland**: no `Quickshell.Hyprland`, `Hyprland.*`, `HyprlandFocusGrab`, `GlobalShortcut`, `hyprctl`, hyprsunset,
   hyprpicker. Replacements: the focused monitor is `Compositor.focusedScreen()` / `Compositor.focusedOutput`;
   workspaces are `Compositor.activeOn(output)`, `Compositor.occupiedOn(output)`, `Compositor.focusWorkspace(output,
   idx)`; the active window is `ToplevelManager.activeToplevel` (`Quickshell.Wayland`); "click outside closes the popup"
   is `modules/common/Catcher.qml` (read its header); niri actions are `Compositor.action("...")`,
   `Compositor.powerOffMonitors()`, `Compositor.quit()`; a global shortcut becomes an IPC function that a niri bind
   calls. Keyboard layout: niri's events or the fcitx5 engine name (`fcitx5-remote -n`), not hyprctl.
3. **nothing outside the allowed places is written**: the shell may write only under `~/.cache/mizu/` (state in
   `~/.cache/mizu/state`, data in `~/.cache/mizu/data`) and `~/.config/quickshell/mizu-user/` (settings). Never touch
   KDE/GTK/Qt settings, gsettings, dconf, `/etc`, shell rc files, icon or cursor themes. No `sudo`, no `pkexec`. Run only
   programs on the allowlist in `tests/test_mizu_safety.py` (`ALLOWED_PROGRAMS`); if you truly need another one, say so
   in your report instead of editing the list.
4. **no Sekai identity**: no "SekaiPop", "Project SEKAI", unit/character names or mascots in strings the user sees or in
   code (comments may keep history). The product name is "mizu".
5. **less code**: delete what is out of scope for milestone 1 (spec section 5 and 11) instead of porting it. Dead
   branches for removed features go away too.

Removed on purpose (references to these must disappear from your files): ThemeService, AppThemeService, IconCursorService,
UpdateService, PackageUpdatesService, HookService, PluginService, PluginState, Hyprland* services, DisplayService,
ScrollOverviewService, DiscordVoiceService, WallhavenService, KeybindService, RegionService, EqualizerService,
PcCavaService, VisualizerService, WelcomeService, PaletteService, DesktopPresetService, ShelfService, PinnedAppsService,
FilesStackService, DockService, and the modules dock, overview, cheatSheet, keybinds, regionSelector, keyboard, palette,
editMode, welcome, equalizer, visualizer, framing, desktopMenu, wallpaperSelector. Kept as inert or simple stand-ins:
`EditMode` (never active; `desktopDragAllowed`, `homeScreen`), `EditStage/EditChrome/EditPreview/SizeKey` (stubs in
`modules/common/widgets`), `GameModeService` (a plain flag), `WallpaperService` (one wallpaper, folder listing,
`setWallpaper`, `next`, `random`, `runPalette`), `PresetMotion` (flags false), `Compositor`, `SettingsService`
(defaults rewritten: a key you read that no longer exists returns undefined, so check `SettingsService.defaults`).

## Rules of engagement

- **Own only your files** (listed in your assignment). Do not edit anything else, in particular `tests/`,
  `modules/common/ThemeSet.qml`, `Tokens.qml`, `Theme.qml`, `services/SettingsService.qml`, `services/Compositor.qml`,
  `services/WallpaperService.qml`, `shell.qml`. If you need a change there, finish your work with a workaround and put the
  request in your report.
- **Do not run git commands that change anything** (no add, commit, stash, checkout, reset, clean). The lead commits.
- **Never run `qs`/`quickshell` yourself.** Use the harness (below): it runs the staged quickshell in a nested niri with
  a private HOME, private XDG directories and a private D-Bus, so a mistake in this tree cannot touch the real session or
  KDE Plasma. Do not start anything that writes under the real `~/.config`.
- No `sudo`. Never delete anything outside your own files. Before deleting a file, make sure nothing keeps
  referencing it (`grep -rn Name quickshell/.config/quickshell/mizu`).
- Do not weaken, skip or edit tests. If a test seems wrong, say so in your report.
- Match upstream's code style in the files you touch; comments in English, short.

## Tools

All from the repo root. Paths below are relative to it.

- Staged quickshell is already in `~/.cache/rice-staging` (made by `scripts/dev/stage-quickshell.sh`).
- **Harness**: `MIZU_DEV_STATE=$HOME/.cache/mizu-dev-<yourname> scripts/dev/nested-shell.sh start <shell dir>`, then
  `... shot <name>` (screenshot, prints the png path; open it with the Read tool and LOOK at it), `... ipc call <target>
  <function> [args]` (target names are the `IpcHandler { target: "..." }` of the code), `... log [lines]` (the shell's
  log), `... stop`. Always use your own `MIZU_DEV_STATE`, and `stop` when you finish. The shell hot-reloads when a file in
  the tree changes (the log says "Reloading configuration..." then "Configuration Loaded", or the error); a reload
  that fails keeps the old one running, so read the log after every edit.
- A **dev shell** for your surface: make a directory (for example `$HOME/.cache/mizu-dev-<yourname>/devshell`) containing
  symlinks `modules services scripts palette assets` to the tree's directories and your own `shell.qml` that builds
  only your surface (imports `qs.services`, `qs.modules.common`, ... like the real one will). Start the harness on that
  directory. Make the wallpaper folder visible to the sandbox once:
  `mkdir -p $MIZU_DEV_STATE/sandbox-home/Pictures && ln -sfn $HOME/Pictures/Wallpapers
  $MIZU_DEV_STATE/sandbox-home/Pictures/Wallpapers` (30 wallpapers: `landscape/`, `anime/`, `cinematic/`).
  Include `WallpaperLayer {}` per screen (`qs.modules.mizu.background`) so the palette follows the picture; switch
  wallpapers from your dev shell with an `IpcHandler` that calls `WallpaperService.setWallpaper(path, "")` or `next(1)`.
- Static checks (all must end clean for your files):
  - `python3 -I -B scripts/dev/safety_list.py <repo root> [writes|hypr|sekai|programs]` the safety scan; the hex-literal
    rule is `python3 -I -B -m unittest discover -s tests -p test_mizu_safety.py` (its failure lists the first 40).
  - `python3 -I -B scripts/dev/qml_unresolved.py <mizu dir> [--files NAME]` names used by QML that resolve to no file of
    the tree and no Qt/Quickshell type (ignore `QtQuick`, `QtMultimedia`, single letters).
  - `python3 -I -B scripts/dev/qml_theme_missing.py <mizu dir>` theme roles read but not defined by ThemeSet.
- Known Qt 6.12 trap: a `Behavior on <property>` declared inside a **Singleton** crashes the QML engine. Fine inside Items.

## Done means

1. The static checks above report nothing for your files (the safety scan's other findings belong to other people).
2. Your dev shell loads with **no** `TypeError`, `ReferenceError`, `is not a type`, `module ... is not installed`,
   `Unable to assign`, `Cannot read property` or "undefined color" messages in the log attributable to your files
   (warnings about missing optional files are fine; say which you saw).
3. You took screenshots of the surface on at least three wallpapers (a dark one, a bright one, a grey or very colorful
   one), looked at them and fixed what looked wrong (unreadable text, wrong color, clipped, missing icon). Icons come from
   the Material Symbols font in the sandbox; a box instead of a glyph is a bug.
4. Your report (final message) lists: files changed and deleted, what each removed feature's replacement is, decisions
   you took and why, anything you could not do, requests for files you do not own, and the screenshot paths you
   judged. Keep it under 40 lines.
