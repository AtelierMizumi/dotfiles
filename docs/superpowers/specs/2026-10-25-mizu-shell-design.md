# mizu shell: SekaiPop-based Quickshell shell for niri with a smart wallpaper palette

Status: approved under the user's autonomous brief (2026-10-25). Approval gates are waived and design decisions are
recorded as **Ruling** lines. The independent review that replaces the user review was an advisor pass on 2026-10-25
(its findings are folded in; the planned deep-thinker pass died on a rate limit).
ADR: docs/adr/0001-own-quickshell-shell.md. Research: docs/research/quickshell-niri-shell.md,
docs/research/sekaipop-harvest-map.md.

## 1. Understanding

What the user said (brief in /home/thuanc177/.claude/plans/zany-plotting-shamir.md):

- **Base:** take SekaiPop's best code, widgets and animation as the base, without the Project SEKAI identity.
- **Colors:** every color comes from a smart palette derived from the wallpaper. It must suit any wallpaper:
  landscape, anime or cinematic; bright, dark or grey.
- **Milestone 1:**
  - phone quick panel (portrait, rises from the bottom);
  - settings phone (rotates to landscape);
  - launcher phone;
  - bar with niri workspaces on both monitors;
  - desktop widgets: clock (Japanese date), weather, calendar, to-do, media/lyrics.
- **Parity:**
  - lock screen;
  - idle at 30 min screen off and 45 min lock, no suspend, inhibitors respected;
  - polkit agent, OSD, clipboard history (Mod+Shift+V), screenshot;
  - Japanese clock;
  - screen share/Discord;
  - every keybind in docs/USAGE.md, keeping the 2-3 key rule.
- **Rules:** Plasma untouched, no sudo by Claude, test-first, GPL-3.0 kept.
- **Delivery:** the user receives exactly one command that switches the desktop over (`--dry-run`, `--rollback`).

Assumptions (Rulings):

- **Ruling: shell name `mizu`, Quickshell config `~/.config/quickshell/mizu`.** The palette is called Mizu, and the
  name has no Sekai identity. Cost if wrong: a rename.
- **Ruling: one wallpaper for all outputs in milestone 1.** Its palette themes both monitors. Cost if wrong:
  per-output palettes later.
- **Ruling: dark mode by default, `auto` picks light for bright wallpapers.** A user setting `theme.mode` (`auto`,
  `dark`, `light`) overrides it. Cost if wrong: one setting.

## 2. Architecture

```
wallpaper (~/Pictures/Wallpapers/...)
   │ chosen in the settings phone / `mizu wallpaper ...` IPC, stored in ~/.cache/mizu/state/wallpaper.json
   ▼
WallpaperLayer (shell, WlrLayer.Background, fade transition) ──► the picture on screen
   │ path changed
   ▼
palette tool: python3 -I -B palette/mizu_palette.py <wallpaper>      (repo: quickshell/.config/quickshell/mizu/palette/)
   │ analysis → scheme pick → `noctalia theme` generator → per-surface fit → contrast correction
   ├──► ~/.cache/mizu/tokens.json   (atomic)  ──► Theme/ThemeSet adapter (FileView, watchChanges) ──► every mt.* read
   └──► ~/.config/niri/colors.kdl   (atomic)  ──► niri include (focus ring, insert hint)
```

Session wiring (stow package `niri`):

- `spawn-at-startup "~/.config/niri/scripts/shell-start"` reads `~/.config/niri/shell` (`mizu` or `noctalia`;
  missing means `noctalia`) and starts that shell.
- Every shell bind in config.kdl runs `~/.config/niri/scripts/shell-ipc <action>`, which maps one action name onto
  `qs -c mizu ipc call mizu <action>` or `noctalia msg ...`. The binds therefore stay identical for both shells, and
  switching needs no config.kdl edit.
- **Ruling:** the dispatcher replaces the brief's "flip config.kdl". Editing a stowed repo file at switch time would
  dirty the repo. Cost if wrong: none, the behaviour is the same.

Stow packages after this work:

- `niri`: config.kdl, niri-portals.conf, scripts/{fcitx5-cycle, shell-start, shell-ipc}.
- `noctalia`: unchanged, plus its niri-colors template.
- `quickshell`: `.config/quickshell/mizu/**` (the GPL-3.0 fork, with LICENSE and UPSTREAM.md).

## 3. Palette tool (the core)

Interface (the only thing callers learn):

- `python3 -I -B mizu_palette.py <wallpaper> [--tokens PATH] [--niri PATH] [--mode auto|dark|light]
  [--overrides PATH]`.
  - Defaults: `--tokens ~/.cache/mizu/tokens.json`, `--niri ~/.config/niri/colors.kdl`,
    `--overrides ~/.cache/mizu/state/palette-overrides.json`, `--mode auto`.
  - It writes both files atomically (temp file in the same directory, then rename) and prints the tokens path.
  - Exit codes: 0 ok; 2 for an unreadable image or a failed generator, in which case **both previous files are left
    untouched**; 64 for a usage error.
- Python: `build(grid, generate, overrides, mode) -> dict` is pure.
  - `grid` is 96×54 sRGB triples.
  - `generate(scheme, mode) -> dict` returns the generator's role dict.
  - Two adapters at each seam: `magick` and synthetic grids; `noctalia theme --scheme S --dark|--light` and a fake
    generator.

Algorithm. The prototype (`docs/research/smart-palette-prototype/`) validated it in **dark mode only**, on 31
images. Light mode, `auto`, accent correction against a light backdrop and the hue rotation are new in the production
tool and must be covered by tests in both modes (see §10):

1. **Analysis on the whole grid:**
   - mean L* and chroma C* (CIELAB, D65);
   - busyness: the mean |ΔL*| between neighbours;
   - the 5th and 95th luminance percentiles.
2. **Scheme pick:** C* < 7 → `m3-monochrome`; C* < 16 → `soft`; otherwise `faithful`. The per-wallpaper override
   `scheme` wins.
   - **Ruling:** the thresholds come from the 30-wallpaper set. Grey images (ColdRipple, 3qwx1v, gw2gyq, vpywv3) got
     monochrome, and `faithful` had invented a red for them. Cost if wrong: one constant.
3. **Mode for `auto`:** light when the whole-image mean L* > 66 **and** the bar region's mean L* > 70; otherwise dark.
4. **Generator:** `noctalia theme <img> --scheme S --dark|--light` (Noctalia stays installed as the fallback shell).
   - **Ruling:** no new dependency, and the faithful and soft schemes were compared on screen. matugen's Material set
     lacks faithful and soft. Cost if wrong: swap the adapter.
5. **Per-surface fit.** Fit each of the surfaces `bar`, `phone` and `widget` to its region (fractions of a 16:9
   screen: bar y 0-0.045; phone x 0.36-0.64, y 0.45-1; widget x 0.03-0.28, y 0.10-0.40):
   - **Housing color:** `surface_container` mixed 25% toward the region's mean hue at the same L*.
   - **Opacity:** `clamp(0.62 + busy/40, 0.55, 0.92)`.
   - **Effective backdrop:** the region's 95th-percentile luminance (dark mode) or 5th percentile (light mode),
     seen through the housing at that opacity.
   - **Text contrast:** raise opacity in 0.03 steps until text contrast ≥ 4.5:1 or opacity reaches 0.97. If that
     still fails, set text to white/black.
   - **Accent contrast:** shift the accent's L* in 2-unit steps until accent contrast ≥ 3:1 against the effective
     backdrop. The direction follows the mode: lighter against a dark backdrop, darker against a light one. If the
     limit is reached (L* 96 or 8) without ≥ 3:1, fall back to the generator's `on_surface` for that surface.
6. **Role mapping to tokens:** see §4. `accent2` is the accent rotated +28° in LCh at the same L*. Chroma is
   reduced in steps of 2 until the color is inside the sRGB gamut, so clipping never shifts the hue. The `on_*` roles
   are checked against their fills: ≥ 4.5:1, corrected the same way.
7. **Cache:** results are cached by sha256 of the image plus the mode, the overrides and the tool version, in
   `~/.cache/mizu/palette-cache/`. Re-selecting a wallpaper is instant.

Tokens JSON (schema `mizu.tokens/1`):

```json
{ "schema": "mizu.tokens/1", "wallpaper": "...", "scheme": "faithful", "mode": "dark",
  "analysis": {"L": 0, "chroma": 0, "busy": 0},
  "color": {"accent","accent2","outline","line","shadow","surface","surfaceHover","surfaceDivider","surfaceRing",
            "ring","ink","inkMuted","onAccent","chip","onChip","scrim","hoverTint","paper","danger","warning",
            "series":[5]},
  "surface": {"bar": {"housing","alpha","ink","accent","onAccent"}, "phone": {...}, "widget": {...}},
  "phone": {"rimHighlight","bezel","wallLight","wallMid","wallDark","hardware","lens","lensGlint","shadowAlpha"},
  "contrast": {"bar.ink": 0, "bar.accent": 0, "phone.ink": 0, "widget.ink": 0} }
```

Metrics and fonts are not in the tokens. They are design constants in ThemeSet (they do not depend on the
wallpaper).

## 4. Token roles (design system)

The keycap language stays: an **outline**, then an inner **ring**, then the **fill**, on a **hard offset shadow**.
Every one of those colors comes from the palette. Mapping from generator roles (dark / light):

| Token | Dark | Light | Used for |
|---|---|---|---|
| accent / accent2 | primary / primary+28° | same | lit gradients, active keys, workspace badge |
| outline | surface_container_lowest darkened to L* ≤ 12 | on_surface | strong outline, phone rim |
| line | outline (generator) | outline_variant | pill and card borders |
| shadow | outline mixed 50% with scrim | outline darkened 30% | hard offset shadow |
| surface / surfaceHover / surfaceDivider | surface_container / _high / outline_variant | same roles in light | panel fills |
| surfaceRing | surface_bright | surface_dim | housing ring of bar and dock |
| ring | on_surface at L* 92 (the old cream ring) | surface_container_lowest | gap ring inside pills |
| ink / inkMuted | on_surface / on_surface_variant | same | text |
| onAccent | on_primary, corrected to ≥ 4.5:1 | same | text on accent fills and pictures |
| chip / onChip | secondary_container / on_secondary_container | same | chips |
| scrim / hoverTint | scrim / primary at 12% | same | dims, hover |
| paper | surface_container_low | surface_container_low | launcher and paper cards |
| danger / warning | error / tertiary shifted to hue 70° | same | all the hand-typed reds and oranges |
| series[5] | primary, secondary, tertiary, error, accent2 | same | workspace dots, OSD states, battery tiers |
| phone.* | wall ramp from surface_container (light → dark), bezel = scrim, lens = surface_dim | same | phone hardware |

Motion (kept from upstream, centralised in `PopReveal.qml`):

- pop in: 460 ms OutBack, overshoot 1.9;
- swallow: 300 ms InCubic;
- bar popups: 340 ms, overshoot 1.3 / 170 ms;
- phone rise: lift 340 ms, then OutElastic tilt 820 ms;
- portrait to landscape: 200 ms bezier roll ±90°.

Color changes animate with `Behavior on color { ColorAnimation { duration: 450 } }` in the adapter.

## 5. The fork and its pruning

- **Fork point:** the upstream tree `4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf`, fetched 2026-10-25. The tree goes
  into `quickshell/.config/quickshell/mizu/`, together with LICENSE (GPL-3.0), UPSTREAM.md (source, fork point,
  credits) and a list of local changes.
- **Removed outright.** These are the LEAVE rows of the harvest map:
  - theming: ThemeService, AppThemeService, IconCursorService and all of `scripts/theming/`;
  - the WARP tile with its pkexec;
  - UpdateService, PackageUpdatesService, HookService, PluginService and PluginState, with the plugins UI;
  - welcome;
  - equalizer and visualizer with cava, plus the 4 visualizer shaders that have no source;
  - dock, overview, cheatSheet and keybinds;
  - regionSelector, the keyboard module and the palette tool;
  - Hyprland* services, DisplayService and ScrollOverviewService;
  - Discord;
  - the gacha lock surface;
  - Wallhaven;
  - the editMode UI.
- **Stubbed singletons** (same name, inert):
  - `EditMode { active: false }`, `PresetMotion` (all flags false) and `GameModeService { enabled: false }`;
  - `WidgetClones` (one copy per widget), `WallpaperService.restacking: false` and `FocusService` (always show).
- **New:**
  - `services/Compositor.qml`, wrapping NiriWorkspaces. It provides `focusedOutput`, `workspaces`,
    `activeOn`/`occupiedOn`, `focusWorkspace()` and `quit()`, with a second socket for actions;
  - `modules/common/Catcher.qml`, the click-away window that replaces HyprlandFocusGrab;
  - `services/MizuIpc.qml`, IPC target `mizu` (§7);
  - `services/Idle.qml`;
  - `modules/common/PopReveal.qml`;
  - `palette/`.
- **Adapted:**
  - ThemeSet/Theme become a tokens adapter that keeps the old property names. `p*` aliases the plain roles, and
    `attributeColors` aliases `series`.
  - Every hard-coded color becomes a token. The only exception is the night-light kelvin ramp, which is physical.
  - `Hyprland.*` becomes Compositor or ToplevelManager.
  - Storage moves to `~/.config/quickshell/mizu-user/` (settings) and `~/.cache/mizu/` (state and caches).
  - Weather location defaults to the system timezone's city (`Asia/Ho_Chi_Minh` → "Ho Chi Minh City"), with IP
    geolocation off.
  - Lyrics providers default to lrclib only.
  - Icons come from the Material Symbols Rounded font (`ttf-material-symbols-variable`).
- **Ruling: no Solar SVGs.** Their licence is not stated in SekaiPop, and they are 5-26 MB. Cost if wrong: icons
  look less like upstream.
- **Lock screen:** upstream Lockscreen + LockContext (PAM) with the neutral calendar look (`LockCalendar`), using
  tokens. PAM uses our own config file `lock/pam/mizu-lock` (`auth required pam_unix.so`). The `login` stack would
  count failures in faillock.
- **Night light:** wlsunset (`-t <K> -T <K+1>` while on, killed when off). Gamma below 0 is dropped.
- **Brightness:** brightnessctl for the laptop panel, ddcutil (already installed) for HDMI when DDC works.
- **Clipboard:** the shell starts `wl-paste --watch cliphist store`. The launcher's clipboard extra lists `cliphist`.
- **Screenshot:** niri's own `screenshot` action (unchanged).

## 6. Milestone 1 surfaces

| Surface | From upstream | niri/ token work |
|---|---|---|
| Bar (both outputs) | Bar.qml, Status_Bar.qml, WorkspaceBadges, DateIndicator+CalendarPopup, WeatherIndicator+Popup, MediaPill (static waves), NotificationBadge, StatusPill, BatteryIndicator+Popup, KeyboardLayoutIndicator (fcitx5 name) | Compositor, Catcher, Japanese date format |
| Quick panel phone | QuickPanel host, QuickPanelFace, QuickToggle, VolumeSlider, GammaBrightnessSlider (brightness only), Network/Bluetooth/VolumeMixer/NightLight dialogs, NotificationCard (peek), PowerMenu | focusedOutput, catcher, niri logout, wlsunset |
| Settings phone (landscape) | SettingsStage, SettingsFace, pages Quick, General, Bar, Desktop (widgets + wallpaper only), About; new Niri page (read-only info: outputs, workspaces, keybind list) | remove the theme, app-theme, icon and update sections |
| Wallpaper face | WallpaperFace (local folder only) | palette re-run on pick |
| Launcher phone | LauncherFace, AppResultRow, AppPlaceholder, LauncherLcd, LauncherExtras with the Calculator, Clipboard and Emoji cards | — |
| Desktop widgets | ClockWidget (1-2 designs), WeatherCardWidget, CalendarCardWidget, TodoWidget, LyricsWidget, all on the eDP-1 output by default | strip edit chrome |
| OSD | OSDPopup + OSDIndicator | tokens |
| Notifications | NotificationSource (server, DND, history), peek in the phone | quiet while a niri window is fullscreen |
| Polkit | PolkitPrompt + PolkitDialog | focusedOutput |
| Lock | Lockscreen + LockContext + LockCalendar | own PAM file |
| Idle | new `Idle.qml`: IdleMonitor 1800 s → `niri msg action power-off-monitors`; IdleMonitor 2700 s → lock; `respectInhibitors: true`; no suspend | — |

niri layer-rules (config.kdl, harmless for Noctalia): `match namespace="^mizu-"` with `background-effect { blur
true }` and geometry-corner-radius where the surface is rounded.

## 7. IPC and keybinds

Target `mizu` (one stable interface for niri binds). The functions:

- `launcher`, `quick`, `settings`, `clipboard`, `dnd`, `lock`;
- `volumeUp`, `volumeDown`, `volumeMute`, `micMute`;
- `brightnessUp`, `brightnessDown`;
- `mediaPlay`, `mediaNext`, `mediaPrev`;
- `wallpaperNext`, `wallpaper <path>`, `palette` (re-run).

`shell-ipc <action>` maps each action to the active shell:

| Action | mizu | noctalia |
|---|---|---|
| launcher | `qs -c mizu ipc call mizu launcher` | `noctalia msg panel-toggle launcher` |
| quick | `... mizu quick` | `noctalia msg panel-toggle control-center` |
| settings | `... mizu settings` | `noctalia msg settings-toggle` |
| clipboard | `... mizu clipboard` | `noctalia msg panel-toggle clipboard` |
| dnd | `... mizu dnd` | `noctalia msg notification-dnd-toggle` |
| lock | `... mizu lock` | `noctalia msg session lock` |
| volume-up/down/mute, mic-mute, brightness-up/down, media-* | `... mizu <fn>` | the existing `noctalia msg` commands |

The keys in config.kdl do not change (Mod+D, Mod+S, Mod+Alt+S, Mod+Shift+V, Mod+N, Mod+Escape, Super+Alt+L,
hardware keys). Only the bind actions change, to `spawn-sh "~/.config/niri/scripts/shell-ipc <action>"` (`spawn-sh` runs the line through a shell, so `~` expands;
`niri validate` only checks syntax, the expansion is proven by the dispatcher test and the nested run). Mod+Alt+W
(new, 3 keys) maps to `wallpaper-next`.

## 8. The one command: scripts/switch-shell.sh

`~/Projects/Tools/dotfiles/scripts/switch-shell.sh [--dry-run] [--rollback] [--yes]`, generated with the wizard
skill. Steps:

1. **Preflight**, read-only:
   - it runs in a niri session, from the main checkout;
   - branch `smart-shell` exists;
   - `tests/run-all.sh` is green on the branch;
   - `check-plasma-intact.sh noctalia` passes.
2. **Summary** of what will happen (packages, merge, stow, switch). Then it asks to continue, unless `--yes`.
3. **Packages:** `sudo pacman -S --needed quickshell ttf-material-symbols-variable cliphist brightnessctl
   wlsunset`. Before that, it aborts if any target's `Conflicts`/`Replaces` names an installed `plasma-*`, `kde*` or
   `xdg-desktop-portal-kde` package. pacman's own prompt stays interactive.
4. **Merge and stow:**
   - `git merge --ff-only smart-shell` in the main checkout;
   - `stow -n` dry run, then `stow --no-folding -R -t ~ niri noctalia quickshell`.
5. **Gates:**
   - `tests/run-all.sh`;
   - `niri validate`;
   - `check-plasma-intact.sh noctalia`;
   - `noctalia config validate`.
6. **Noctalia settings:** `~/.local/state/noctalia/settings.toml` is the user's GUI choice and wins over the repo
   config (on 2026-10-25 it held `source = "builtin"`, Catppuccin). The script never writes it. It only prints when
   the live theme differs from the repo's `wallpaper`/`faithful`, with the one `noctalia msg color-scheme-set` line
   to align it if the user wants that.
7. **Switch:**
   - write `~/.config/niri/shell` = `mizu`;
   - stop Noctalia;
   - start mizu through `niri msg action spawn-sh -- ~/.config/niri/scripts/shell-start`;
   - wait for `qs -c mizu ipc call mizu ping`;
   - then ask "keep mizu? [y/N]" for **60 seconds**; no answer (or `n`) reverts to Noctalia the same way as a failure.
     This guards against a shell that starts but cannot be used (no bar, no lock, no input).
8. **Failure handling:**
   - on any failure after step 4: restore `shell` = `noctalia`, restart Noctalia and print the log path;
   - a failure before step 4 changes nothing;
   - `--rollback` needs only a terminal, the `shell` file and `shell-start`: it does not call `qs` or anything from
     mizu, so it works when mizu is broken. It leaves the packages installed.
   - the report lists the TTY recovery steps (`echo noctalia > ~/.config/niri/shell`, then `niri msg action quit`
     and log in again) in case the screen is locked or unusable.

## 9. Safety checks (extend the existing ones)

- `tests/test_mizu_safety.py` (static scan of `quickshell/`) fails on:
  - any of `kdeglobals`, `gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `gsettings`, `dconf`, `kwriteconfig`,
    `color-schemes`, `kcminputrc`, `.icons`, `pkexec`, `sudo`, `/etc/`, `.bashrc`, `.zshrc`, `fish/conf.d`;
  - any of `hyprctl`, `Quickshell.Hyprland`, `HyprlandFocusGrab`, `GlobalShortcut`;
  - `sekaipop` in a path;
  - a `Process` command whose program is outside the allowlist;
  - a hex color literal outside `ThemeSet.qml` (neutral fallbacks) and the allowlisted kelvin ramp;
  - a binary `.qsb` without a matching source.
- `check-plasma-intact.sh compare` after logging out of niri, as before.

## 10. Testing

| Area | Type | Cases |
|---|---|---|
| Palette tool | unit (python, synthetic grids, fake generator) | scheme pick at the thresholds (C* 6.9 / 7 / 15.9 / 16); auto mode (both outcomes, incl. a bright wallpaper with a dark bar region); opacity clamps; text/accent contrast always ≥ 4.5 / 3 after correction, as a property test over random grids **in both dark and light mode**, including a very bright and a very dark backdrop where the accent needs the `on_surface` fallback; `accent2` is +28° in hue and always inside the sRGB gamut (property test over random accents, including saturated blues and greens near the gamut edge); overrides win; schema keys present |
| Palette CLI | integration (tmp dirs, real magick, fake or real noctalia) | atomic writes; exit 2 keeps old files; cache hit; niri output validates with `niri validate` |
| niri colors include, as deployed | integration (tmp dir) | a `config.kdl` that is a **symlink** into another directory, with `colors.kdl` next to the symlink: `niri validate` must print no "optional include not found" warning, and the focus ring in the loaded config takes the primary. A missing `colors.kdl` must still validate |
| Palette agrees with its source | integration (real noctalia + magick) | for the live wallpaper, the primary in `~/.cache/mizu/tokens.json` comes from `noctalia theme <wallpaper> --scheme <scheme> --dark|--light`, and `colors.kdl` carries the same primary as the tokens |
| Pure JS (NiriMath, PhoneRoute, PhoneMath, FlipMath) | node | only the upstream tests that cover **harvested** files are imported (`niri-test/niri_unit.js`, the PhoneRoute, PhoneMath and FlipMath unit tests), run by run-all.sh, plus `focusedOutput()`. Upstream's own tip is "81 pass, 9 fail": the failing ones belong to pruned modules (Hyprland settings, keybinds, display, theme) and are **not** imported or skipped. The list of tests left out, and which pruned module each belongs to, is kept in `quickshell/.config/quickshell/mizu/UPSTREAM.md` |
| Safety scan | static | §9 |
| shell-ipc, shell-start | bash with fakes | each action maps to each shell; missing or garbage `shell` file → noctalia; `~` in the bind line expands to the real script |
| switch-shell.sh | bash with fake sudo/pacman/git/stow/niri/qs/noctalia | dry-run changes nothing; plasma conflict aborts; gate failure rolls back; the 60 s confirm times out and reverts; `--rollback` works with `qs` missing and never writes `settings.toml` |
| Lock, nested niri | scripted, in the nested session | correct password unlocks; wrong password stays locked and does not touch faillock; `qs` killed while locked leaves the session locked (niri's lock surface remains, as the protocol requires) and the TTY recovery steps in §8 work |
| Shell smoke | nested niri (manual verification script `scripts/dev/nested-shell.sh`, not in run-all) | loads with no QML `TypeError`/`ReferenceError`/"is not a type"; screenshots of bar, quick panel, settings, launcher, widgets, OSD, lock on several wallpapers (dark, bright, grey, saturated) |

**Parity report.** The final report splits every parity item into **verified in the nested niri** (on a private
D-Bus, so against fakes or nothing) and **first real run at switch time**. The second list is the one the user
watches: notification server ownership, polkit agent registration (in the nested run the registration failed
because Noctalia's agent already owned the subject), tray watcher, MPRIS players, the real lock, idle.

## 10a. Order of work

1. **Palette tool first, tests first** (python, no display). It is the user's first ask, and any slippage then lands
   on the QML work, not on the palette. Includes the include-as-deployed test and the colors.kdl hookup through
   Noctalia's template, so the focus ring already follows the wallpaper before the new shell exists.
2. Fork import and the safety scan, red, then pruning until green (the shell keeps running in the nested niri at each
   step; the baseline already works).
3. Tokens adapter, Compositor, Catcher, IPC target, dispatcher scripts.
4. Surfaces in the order of the harvest map's port list.
5. `switch-shell.sh`, quality gates, docs.

## 11. Out of scope for milestone 1

Dock/shelf, Edit Desktop, the equalizer pad, a lock redesign beyond the neutral calendar, recording/OCR, Discord voice,
plugins, per-output wallpapers.

**Ruling: the tray is in milestone 1** (TraySource + TrayButton/TrayCollection/TrayMenu/TrayPopups on the bar, catcher
instead of the grab). Noctalia had one, and Discord and similar apps hide in it. Without a tray they would be
unreachable while mizu runs. Cost: about 1500 more lines to adapt.
