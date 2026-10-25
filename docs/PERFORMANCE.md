# mizu shell: what it costs, and where to look

Measured on 2026-10-25 with `scripts/dev/measure-idle.sh quickshell/.config/quickshell/mizu` (the shell in the nested
niri, one 942x1010 output, Qt 6.12, quickshell 0.3.2, tokens from a bright wallpaper). Run it again after a change that
adds a window, a timer or a big image; numbers below are the baseline.

## Idle cost

| What runs | RSS | CPU (idle) |
|---|---|---|
| empty `ShellRoot {}` (the Qt + Mesa floor) | 314 MB | 0.00 % |
| + wallpaper layer | 403 MB | 0.00 % |
| everything except the desktop widgets | 633 MB | 0.47 % |
| ... without the bars | 595 MB | 0.07 % |
| ... without the two phones (Quick Panel, launcher) | 503 MB | 0.40 % |
| everything | ~700 MB | 0.6 - 0.8 % |

- About 340 MB of the RSS is shared library mappings (`SHR` in `top`); the private part is about 370 MB
  (`Pss_Anon` in `/proc/<pid>/smaps_rollup`).
- The CPU is the QML main thread (clock ticks, bindings); the render threads stay near 0.1 %, so nothing animates
  while idle. Every recurring timer in the tree has a `running:` condition (the Quick Panel's pollers only run while
  the panel is open; the resource and status pollers only while the bar shows them).
- Child processes at idle: `niri msg -j event-stream`, `dbus-monitor` (logind), two `wl-paste --watch cliphist store`.
  The Keep Awake inhibitor exists only while Keep Awake is on.

## Where the memory is

1. The two phones, built while hidden: about 130 MB. `QuickPanel` and `LauncherPhone` keep their `PhoneBody` and
   screens alive so that opening is instant. A `LazyLoader` around each window that unloads it a minute after it
   closes would give the memory back at the price of a cold first open (about a second of building). Not done: the
   saving is real but the cost is felt on every open after a pause, and glibc may not return the freed pages to the
   system, so measure with `measure-idle.sh` before committing to it.
2. The bars: about 40 MB per shell, and nearly all of the idle CPU. Their popups (weather, calendar, battery,
   resources, media, tray) are built with the bar.
3. Desktop widgets: about 65 MB with all five shown. They already use `LazyLoader` staggered over a second, unload in
   Game Mode and sleep while the lockscreen is up.

Wallpaper images are decoded at the output's pixel size (`sourceSize`), never at the file's, and are not cached.

## Setup choices that matter

- `niri/.config/niri/scripts/shell-start` supervises the shell: an error exit (a crash, the OOM killer) restarts it
  after a second, a clean exit does not, and five quick failures in a row stop it so a broken config cannot spin the
  CPU. `scripts/switch-shell.sh` stops that supervisor before it stops the shell, otherwise a rollback to Noctalia
  would be undone by a restart.
- Packages come from the repos (`quickshell`, `ttf-material-symbols-variable`, `wlsunset`, `cliphist`,
  `brightnessctl`); nothing is installed from a local directory.
- Keep Awake is a `systemd-inhibit` started under `setpriv --pdeathsig TERM`, so quitting the shell releases it. Its
  saved state lives in `$XDG_RUNTIME_DIR/mizu` (tmpfs): a reload keeps it, a new login clears it.
- Idle policy (screen off at 1800 s, lock at 2700 s, never suspend) is the shell's `Idle.qml`; Keep Awake and
  fullscreen video block it through logind's idle inhibitor.
- niri itself is left at its defaults for rendering (no window shadows, no blur); the cheap wins there are already
  taken.

## How to measure something specific

- Whole shell: `scripts/dev/measure-idle.sh <shell dir>`. A smaller shell for an experiment is a directory whose
  `shell.qml` is yours and whose other entries are symlinks into the real tree (`modules`, `services`, `scripts`,
  `palette`, `assets`, `ReloadPopup.qml`).
- Unreferenced files: `python3 -I -B scripts/dev/orphans.py quickshell/.config/quickshell/mizu` (a test runs it).
- Names that resolve to nothing: `python3 -I -B scripts/dev/qml_unresolved.py quickshell/.config/quickshell/mizu`.
