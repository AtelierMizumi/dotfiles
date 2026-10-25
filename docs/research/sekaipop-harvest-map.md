# SekaiPop harvest map (for a theme-neutral Quickshell shell on niri)

Static read-only analysis of a downloaded copy of SekaiPop (GPL-3.0). Nothing from the download was executed:
files were read and grepped, and seven of them were hashed to check they match the upstream tree. Paths below
are relative to `sekaipop/` unless they start with `docs/`, `hypr/` or `examples/`. Line counts come from `wc -l`.
"Hyprland coupling" lists only non-comment uses, with line numbers.

Verdicts:
- **TAKE**: usable as is (at most a rename or an import change).
- **ADAPT**: worth porting. The cell says what to change: Hyprland to niri, colours to tokens, removing the
  Sekai identity, paths.
- **LEAVE**: not for milestone 1. The cell says why.
- **LATER**: worth having, but not in milestone 1.

---

## 0. Upstream, version, licence

| Item | Value |
|---|---|
| Repo | `https://github.com/Blapples/SekaiPop` (branch `main`, from `get.sh:25`) |
| Commit SHA | **Not in the download.** It has no `.git`, and neither `VERSION`, `CHANGELOG.md` nor `docs/DEVLOG.md` records the tip commit. |
| Tree SHA (best available) | `4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf`: the root *tree* (not commit) object from the GitHub trees API listing saved next to the download (`tmp/sekai-tree.json`, 7050 entries, not truncated). The git blob hashes of `VERSION`, `shell.qml`, `PhoneBody.qml`, `QuickPanel.qml`, `ThemeService.qml`, `docs/DEVLOG.md` and `shaders/fade.frag.qsb` all match that tree. |
| Version | `VERSION` = `1.0.0`. `CHANGELOG.md` starts with an "Unreleased" section. |
| DEVLOG top entry | "Unreleased — Auto-hide for the bar, and a key to show or hide it (issue #61)" |
| Archive mtime | 2026-10-24 03:41 +07:00 on every file. GitHub archives stamp files with the commit time, so the tip is probably about 2026-10-23 20:41 UTC. This is an inference, not verified. |
| Tested runtime (DEVLOG) | Quickshell 0.3.1, Qt 6.11, Hyprland 0.56.2. README: Qt 6.7+, "shaders ship built for Qt 6.12". |
| Licence | GPL-3.0 (README:339). It includes end4/dots-hyprland code (Anti-Flashbang shaders, Overview/HyprlandData pattern), visualizer shaders ported from pCtrade's end4-pC fork, and the Discord bridge from P3DROVFX's fork. **Anything we harvest makes our shell GPL-3.0.** Keep the copyright notices and credit upstream. |
| Local host check | `qt6-base 6.12.0`, `qt6-shadertools 6.12.0` (`/usr/lib/qt6/bin/qsb`). **`quickshell` is not installed** (`pacman -Q quickshell` fails). Noctalia 5.3.0 is installed. |

Download size: 739 files locally. The icons (`assets/icons/**`, Solar Icon Set) were excluded. What is left:
`sekaipop/` has about 166k lines of QML/JS/sh/py, plus `docs/` (12 md), `hypr/` (Lua config) and `examples/plugins/hello-clock`.

---

## 1. Key findings (read this first)

1. **The good parts are pure UI.** `PhoneBody.qml`, `QuickPanelFace.qml`, `SettingsFace.qml`, `LauncherFace.qml`
   and almost every widget and dialog have no system access. They take data in through properties and send intents
   out as signals. The system side is split into a few "source" objects: `QuickSource`, `NotificationSource`,
   `MediaSource`, `WeatherSource`, `AppSource`, `TraySource`, `BatterySource`, `ResourceSource`, `OSDSource`.
   Hyprland coupling sits almost entirely in the *host* files (`QuickPanel.qml`, `Bar.qml`) and in services.
2. **Some niri support already exists upstream.** `services/NiriWorkspaces.qml` + `functions/NiriMath.js` read
   niri's event stream from `$NIRI_SOCKET` over a Quickshell `Socket` (no child process). `Bar.qml` already
   switches to them when `NiriWorkspaces.running` is true (lines 805, 809, 1140). `tests/niri-test/niri_unit.js`
   covers the maths.
3. **Hyprland features used by the milestone-1 parts, and their niri replacements:**
   - `HyprlandFocusGrab` (click-away in QuickPanel, SekaiPopup, TrayPopups, ScalePopup, LauncherPhone).
     Replace it with the transparent full-screen "catcher" PanelWindow that QuickPanel already uses on the Apps
     screen (`QuickPanel.qml:1694-1721`).
   - `Hyprland.focusedMonitor` (about 10 files). Replace it with the focused output from niri's
     `is_focused` workspace flag, which NiriMath already tracks.
   - `hyprsunset` (night light and gamma). Replace it with a wlr-gamma-control client such as `wlsunset` or
     `gammastep`; niri implements that protocol (verify on the target niri version).
   - `hyprctl -j devices` / `switchxkblayout` (keyboard layout). Replace them with niri's `KeyboardLayouts*`
     events and the `SwitchLayout` action, or fcitx5 if the typing language goes through it (see the dotfiles
     commits d46eeed and de7ee4b).
   - `GlobalShortcut` (bare Super tap). Replace it with a niri bind that runs `qs ipc call`.
   - `Hyprland.toplevels` / `activeToplevel`. Replace them with `ToplevelManager` from `Quickshell.Wayland`
     (wlr-foreign-toplevel works on niri) or niri's `Windows*` events.
4. **Theming must be cut out, not just switched off.** Out of the box the shell writes `~/.config/kdeglobals`,
   GTK and qt5ct/qt6ct files, `~/.local/share/color-schemes` and GNOME `color-scheme`:
   - `SettingsService` defaults turn `systemTheme.sync`, `.gtk`, `.qt` and `.kde` **on**
     (`SettingsService.qml:251-256`), which runs `scripts/theming/system-theme.sh`.
   - `appTheme.hyprland` is also on by default.
   - Any light/dark crossing calls `ThemeService.syncSystemScheme()` (`ThemeService.qml:311-339`). That runs
     end4's `switchwall.sh` if it is present, otherwise `gsettings set org.gnome.desktop.interface color-scheme`.

   This would break the "Plasma files byte-identical" rule in `CLAUDE.md`. **Do not port `ThemeService`,
   `AppThemeService`, `IconCursorService` or `scripts/theming/*`. Write a tiny token-loader instead.**
5. **One more privileged action: the WARP tile.** It can run
   `pkexec sh -c "systemctl enable --now systemd-resolved && ln -sf … /etc/resolv.conf"`
   (`QuickSource.qml:994-997`). That conflicts with the user's DNS-Switcher/NextDNS setup. Remove it.
6. **Persistence lives outside the allowed directories.** `~/.config/sekaipop/` holds settings, scale, presets
   and plugins. `~/.local/state/sekaipop/` holds about 23 state files plus notification history, tray state and
   the equaliser. `~/.local/share/sekaipop/` holds the avatar, banner, phone wallpaper and custom images.
   `~/Pictures/Wallpapers` and `~/Pictures/Screenshots` are also written. Move all of them to
   `~/.config/quickshell/<shell>/` (user settings) and `~/.cache/<shell>/` (state and caches).
7. **The phone needs no custom shader.** The phone, Quick Panel, Settings and launcher use only
   `QtQuick.Effects.MultiEffect` (masking). Custom `.qsb` shaders are needed only for wallpaper transitions, the
   lock, the visualizer and the welcome screen. All of them ship prebuilt. The opaque binaries can be rebuilt
   with the local qsb 6.12, except 4 visualizer shaders that ship without source.
8. **Coexistence with Noctalia.** SekaiPop registers singletons that a session can only have one of: the
   notification server (`NotificationServer`), the polkit agent (`PolkitAgent`), the StatusNotifier tray, and the
   WlrLayer.Background wallpaper owner. Our shell and Noctalia must not both own them. Pick one owner per
   service, or turn each off on one side.

---

## 2. Harvest map

Abbreviations in the Deps column: `S:` singletons read, `C:` child components, `js:` JS libraries.

### 2.1 Root

| File | Lines | What it does | Deps | Hyprland coupling | Verdict | Ext. programs / network |
|---|---|---|---|---|---|---|
| `shell.qml` | 1367 | `ShellRoot`. Builds per-screen `Variants`: WallpaperLayer, FramerWindow, Bar, Dock, widgets (`FocusGate` + `LazyLoader`). Also builds QuickPanel, LauncherPhone, Overview, CheatSheet, KeybindsPanel, PaletteTool, Lockscreen, Polkit, OSD, NotificationPopup, Welcome, Region. About 20 `IpcHandler` targets. | imports every `qs.modules.sekai.*` module and `qs.services`. `FolderListModel`. | Only comments (319, 391). It pulls in Hyprland-coupled modules (Overview, CheatSheet, KeybindsPanel, Dock). | **ADAPT**: write a new small `shell.qml`. Copy the `Variants` + `LazyLoader` + `FocusGate` pattern and only the IPC targets we keep (`phone`, `quickpanel`, `settings`, `bar`, `clock`, `todo`, `weathercard`, `calendarcard`, `lyrics`). | `sh scripts/wallpapers/default-wallpaper.sh seed` copies the bundled wallpaper into `~/Pictures/Wallpapers`. |
| `ReloadPopup.qml` | 417 | Card shown when a hot-reload fails, with a Restart button. | `S: SettingsService, Theme`. `scripts/system/restart-shell.sh`. | 2 (import), 46 (`Hyprland.focusedMonitor`) | **LATER / ADAPT**: niri focused output, colours to tokens. | `restart-shell.sh` (pkill/qs) |
| `VERSION`, `CHANGELOG.md` | 1, 53 | Version number and release notes. | – | – | reference only | – |

### 2.2 `modules/common/` (singletons and helpers)

| File | Lines | What it does | Deps | Hyprland | Verdict | Ext./net |
|---|---|---|---|---|---|---|
| `Directories.qml` | 25 | Shell paths: `shell`, `scripts`, `shaders`, `assets` and helpers. | `Quickshell.shellDir` | – | **TAKE** | – |
| `Theme.qml` | 50 | Singleton `ThemeSet`. `Theme.of(window\|screen)` returns a per-monitor ThemeSet when `theme.perMonitor` is set. | `S: SettingsService, ThemeService` | – | **ADAPT**: keep the `Theme.of()` API (269 call sites in milestone dirs), but make it return the single token theme. Drop per-monitor themes. | – |
| `ThemeSet.qml` | 420 | Every colour role and metric, derived from `pal` (a ThemeService palette) and the light/dark/darker mode. Also the "classic" p* roles, capsule-bar metrics, attribute pastels and wallpaper-transition colours. | `S: ThemeService, SettingsService, GameModeService` | – | **ADAPT** (core): becomes a token adapter. Read tokens JSON (section 4.4). Keep the property *names* so harvested files work unchanged, and drop the derivation maths. Remove `attributeColors` (Sekai attribute pastels), `iris*`, `transitionColors()` and `classic*`. Keep `capsule*` only if the capsule bar is ported. 34 hex literals. | – |
| `PanelImages.qml` | 271 | Avatar, banner and phone wallpaper pictures (pick, keep, framing) for the Quick Panel and the user card. | `S: Directories, SettingsService, WallpaperService`. `js: Framing.js`. `scripts/images/pick-image.sh`. | 3, 121, 183 (`Hyprland.focusedMonitor`) | **ADAPT**: niri focused output. Move storage from `~/.local/share/sekaipop` to `~/.cache/<shell>/images`. Optional in milestone 1: a plain banner and avatar are enough. | `pick-image.sh`: kdialog / zenity / yad file chooser, then `shrink-image.sh` (ImageMagick or ffmpeg) |
| `PresetMotion.qml` | 80 | Flags for the "slide away, apply preset, slide back" motion (`outMs 190`, `inMs 380`). | – | – | **LEAVE** (presets). Stub `barOut` / `clockOut` / … = false, because Bar, Clock, Todo, UserCard and WeatherCard read them. | – |
| `ScrapbookTheme.qml` | 60 | Fixed paper, cork and film palette (cream page `#f5eeda`, tapes, cork, film). 29 hex literals. | `S: ThemeService` | – | **ADAPT** to a few tokens (`paper`, `accent3`), or drop it. Milestone files read only `accentPink`, `inkSoft`, `frameShade`, `tape*`, `film*` and `cork*` (about 30 reads, in SekaiNavKey, SekaiHubTile, AppResultRow, the launcher cards, SearchPill, SekaiBackdrop and SettingsPageAbout). | – |
| `LockPalette.qml` | 96 | Lockscreen palette | `S: ThemeService` | – | **LEAVE** (lock) | – |
| `PadPalette.qml` | 206 | "Sekai Pad" equaliser palette | `S: ThemeService` | – | **LEAVE** | – |

### 2.3 `modules/common/widgets/`

| File | Lines | What it does | Deps | Hyprland | Verdict |
|---|---|---|---|---|---|
| `Pill.qml` | 218 | The core block: outline, then white ring, then fill, on a hard offset shadow. Has capsule, bare and flat modes. | `S: Theme` | – | **ADAPT**: tokens. Drop the capsule and classic branches if those bar styles are not ported. |
| `ScaleHost.qml` | 38 | Scales a window's design-pixel UI by a factor. | – | – | **TAKE** |
| `ScalePopup.qml` | 299 | Generic scaled popup card that dismisses on click-away. | `S: ShellScale, Theme`. `C: Pill, MaterialIcon, ScaleHost` | 2, 87 (`HyprlandFocusGrab`) | **ADAPT**: replace the grab with a catcher. |
| `MaterialIcon.qml` | 90 | Draws an icon: a Solar SVG through `IconMap.js`, falling back to the Material Symbols Rounded font. | `S: Theme`. `js: IconMap.js`. `assets/icons/**` | – | **ADAPT**: the icons are **not** in the download. Either fetch the Solar Icon Set (CC BY 4.0, check its licence) or use only the Material Symbols font (`ttf-material-symbols-variable`). |
| `WheelScroll.qml` | 110 | Mouse and touchpad scroll normaliser for lists (`Theme.wheelPx`). | `S: Theme` | – | **TAKE** |
| `SekaiScrollBar.qml` | 48 | Thin scrollbar | `S: Theme` | – | **TAKE** (rename) |
| `InnerRing.qml` | 26 | Inner ring of flat cards in dark mode | `S: Theme` | – | **TAKE** |
| `RoundClip.qml` | 24 | Per-corner rounded clip (`ClippingRectangle`) | `Quickshell.Widgets` | – | **TAKE** |
| `FramedImage.qml` | 88 | Image drawn with a saved framing (zoom and offset) | `js: ImageMath.js` | – | **TAKE** |
| `Slant.qml` | 47 | Shear transform helper (the "leaning" look) | – | – | **TAKE** |
| `DiamondDot.qml`, `Burst.qml`, `DotField.qml` | 55, 56, 56 | Decorative diamond, burst and halftone dots | `S: Theme` | – | **ADAPT**: the decoration colours become tokens. These are the Sekai "game menu" flourishes, so keep or drop them by taste. |
| `StickerText.qml` | 129 | Outlined sticker text | `S: Theme` | – | **ADAPT** (`ink: "#000000"`) |
| `SekaiPlate.qml` | 105 | Numbered plate (popups and cards) | `S: Theme`. `C: Pill, Slant, DotField` | – | **ADAPT**: rename, `numberRing "#ffffff"` becomes a token. |
| `SekaiBackdrop.qml` | 114 | Settings phone backdrop: halftones, bands, stars | `S: Theme, ScrapbookTheme` | – | **ADAPT**: tokens, keep it neutral. |
| `SearchPill.qml` | 173 | Search field pill (Settings, launcher) | `S: Theme, ScrapbookTheme` | – | **ADAPT** |
| `SegmentSwitch.qml` | 88 | Segmented switch | `S: Theme` | – | **TAKE** |
| `SettingRoundButton.qml` | 160 | Round outlined button | `S: Theme` | – | **TAKE** |
| `ShellBadge.qml` | 107 | Notification app badge | `S: Theme`. `js: NotifyKinds.js` | – | **ADAPT**: hard-coded `"#555473"` (the Virtual Singer navy) at line 32. NotifyKinds maps notifications to the 5 Project SEKAI attribute colours; map them to `series[]` instead. |
| `TrayMenuRow.qml` | 168 | Tray menu row | `S: Theme` | – | **LATER** (with the tray) |
| `WeatherGlyph.qml` | 123 | Weather icon | `S: Theme` | – | **TAKE** (with the weather widget) |
| `CorkBoard.qml`, `FilmStrip.qml`, `WashiTape.qml` | 148, 115, 127 | Scrapbook pieces (cheat sheet, overview, wallpaper board, ExtraFrame) | `S: ScrapbookTheme` | – | **LEAVE** (WashiTape only through ExtraFrame and ColorCard) |

### 2.4 `modules/common/functions/` (pure JS, all `.pragma library`)

| File | Lines | What it does | Verdict |
|---|---|---|---|
| `PhoneMath.js` | 251 | 4x4 matrix maths, perspective, pose bounds, silhouette hull, point-in-convex test, colour ramp. | **TAKE** (core). Node-tested. |
| `FlipMath.js` | 81 | Quick-to-landscape turn: rolls, scale dip, cross-fade alphas. | **TAKE** |
| `NiriMath.js` | 163 | Parses niri `EventStream` lines and applies workspace events. `activeOn`, `occupiedOn`, `idOf`. | **TAKE + extend**: a `focusedOutput()` built from `is_focused`, and window events for the active-window title. |
| `QuickTiles.js` | 210 | Quick Panel tile catalogue, sizes and grid flow. | **ADAPT**: drop the tiles we don't ship (gameMode, antiFlashbang, warp, easyeffects, musicRecognition). |
| `ImageMath.js` | 284 | Image fit and frame maths (banner, avatar, LCD wallpaper, custom image) | **TAKE** |
| `Framing.js` | 141 | Saved framing per picture | **TAKE** if PanelImages is ported |
| `IconMap.js` | 406 | Material name to Solar file | **ADAPT** with the icon decision |
| `OpenMeteo.js` | 314 | Open-Meteo URLs, geocoding, IP geolocation, parsing | **TAKE** |
| `WeatherMath.js` | 89 | Weather popup and card helpers | **TAKE** |
| `EventMath.js` | 339 | Calendar card events (recurrence, soon, alerts) | **TAKE** |
| `LyricsMath.js` | 1680 | LRC and word-sync parsing, provider responses, timing | **TAKE** (with the lyrics widget) |
| `NotifyKinds.js` | 46 | Notification kind to one of the 5 SEKAI attribute colours | **ADAPT** (to `series[]`) |
| `FocusMath.js` | 202 | Desktop Focus Mode rules (hide widgets while windows are on screen) | **ADAPT**: the rules are compositor-neutral. Feed them niri workspace and window data. |
| `KeyBinds.js` | 573 | Hyprland bind parsing and editing | **LEAVE** (Hyprland-only) |
| `DisplayMath.js` | 355 | `hyprctl monitors` modes and layout | **LEAVE** (niri owns output config) |
| `MatugenMath.js`, `PaletteMath.js`, `ScreenThemes.js` | 121, 412, 80 | Matugen knobs, palette tool, per-monitor themes | **LEAVE** (our tokens come from outside) |
| `Extras.js` | 322 | Launcher extras: calc, clipboard, colour, web, `>cmd`, system actions | **ADAPT**: line 232 "Log out" runs `session-logout.sh` (hyprctl). Use `niri msg action quit` instead. |
| `BatteryAlertMath.js` | 71 | Low-battery alert rules | **LATER** (TAKE) |
| `NotesMath.js` | 178 | Sticky notes | **LATER** |
| `EditGridMath.js`, `ShelfDragMath.js`, `ShelfMath.js`, `PresetParts.js`, `WelcomeMath.js`, `WelcomeSlides.js`, `WallhavenMath.js`, `LockCrop.js`, `PluginForm.js`, `PluginManifest.js` | – | Edit Desktop, dock shelf, presets, welcome, Wallhaven, lock, plugins | **LEAVE** |

### 2.5 `modules/sekai/phone/` (the 2.5D phone)

| File | Lines | What it does | Deps | Hyprland | Verdict |
|---|---|---|---|---|---|
| `PhoneBody.qml` | 1247 | The phone "hardware" (section 5). Front face, wall slices, side buttons, notch and lens, a 9-slice soft shadow, and the content layer. Portrait or `landscape`, 2.5D or flat (`flat`, `plain`, `faceDirect`). | `S: Theme, SettingsService` (`quick.phoneShadow`). `js: PhoneMath.js`. `assets/images/phone-shadow.png` (in the download). | – | **ADAPT** (core): colours already come from `mt.colBorder`, `phone*` and `pSurface`. Point them at tokens. `shadowColor: Qt.rgba(0,0,0,0.17)` becomes a token alpha. The settings flag becomes our setting. No Hyprland. |
| `PhonePlate.qml` | 79 | Rounded plate with outline and hard offset shadow (phone cards) | `S: Theme` | – | **TAKE** (tokens via `mt.p*`) |
| `PhoneKey.qml` | 89 | Pressable key on a plate | `S: Theme`. `C: PhonePlate, MaterialIcon` | – | **TAKE** |
| `PhoneCard.qml` | 37 | Page base for the phone cards. Fade and rise in: 200 ms OutCubic, 12 px. | – | – | **TAKE** |
| `SekaiKey.qml` | 182 | Leaning keycap with shadow, outline, ring and a wipe-in "lit" fill. Press: 80 ms OutQuad; release: 260 ms OutBack, overshoot 2.2. | `S: Theme`. `C: Slant` | – | **ADAPT**: rename (e.g. `LeanKey`), tokens. |
| `SekaiNavKey.qml` | 102 | Small leaning header key (Settings back and close) | `S: Theme, ScrapbookTheme`. `C: SekaiKey, MaterialIcon` | – | **ADAPT** (rename, `ScrapbookTheme.accentPink` becomes a token) |
| `PanelActivity.qml` | 49 | Singleton: "a gesture is running" with a 320 ms hold (drags, scrolls) | – | – | **TAKE** |

### 2.6 `modules/sekai/quickPanel/`

| File | Lines | What it does | Deps | Hyprland | Verdict | Ext. |
|---|---|---|---|---|---|---|
| `QuickPanel.qml` | 3025 | **The host.** One window holds the portrait phone (Quick / Apps faces) and the landscape phone (Settings / Wallpapers). Also: pull-out, alert peek, buzz, route stack, IPC (`phone`, `quickpanel`, `settings`, `wallpaperpicker`, …), hot edge, click-away. | `S: BarPositionService, EditMode, HyprlandSettings, IconCursorService, KeybindService, PanelActivity, PanelImages, SettingsService, ShellScale, Theme, WallhavenService, WallpaperService`. `C: PhoneBody, QuickPanelFace, LauncherFace, SettingsStage, PowerMenu`. `js: PhoneMath, FlipMath, PhoneRoute` | 3 (import); 347 `focusedScreen()` reads `Hyprland.focusedMonitor`; 489, 503 `HyprlandSettings.refresh()`; 1034-1037 `hyprctl reload` before `Quickshell.reload(true)`; 1145 `GlobalShortcut{appid:"quickshell", name:"searchToggleRelease"}`; 1675 `HyprlandFocusGrab` (grabList = phone + bar windows); 2646 Refresh button runs the hyprctl reload. | **ADAPT** (core). Replace `focusedScreen()` with a niri focused output. Replace the grab with the existing `catcher` window for every screen, not only Apps. Delete the GlobalShortcut (a niri bind calls `qs ipc call phone go apps`). Refresh does `Quickshell.reload(true)` only. Remove the Wallhaven, KeybindService, IconCursorService and EditMode hooks. | `hyprctl reload` (remove) |
| `QuickPanelFace.qml` | 2755 | The Quick screen (pure UI): banner, avatar, clock, tile grid, sliders, notification list with heads-up "peek", the dialogs, an optional LCD wallpaper. | `S: PanelActivity, Theme`. `C: QuickToggle, VolumeSlider, GammaBrightnessSlider, NetworkDialog, BluetoothDialog, VolumeMixerDialog, NightLightDialog, NotificationCard, PowerMenuScrim, ShellBadge, FramedImage, LauncherLcd, MaterialIcon, WheelScroll`. `js: QuickTiles, ImageMath` | – | **ADAPT**: hex at 445/447/1057 (`"#ffffff"` banner and wallpaper ink), 2046 `peekTone "#e9e9e9"`. Drop the Sekai-only tiles. Keep the `classicPanel` scope only if "classic" stays (recommended: drop it). | – |
| `QuickToggle.qml` | 315 | One tile on `Pill`: on/off look, shadow direction change, 170 ms OutCubic. | `S: Theme`. `C: Pill, MaterialIcon` | – | **TAKE** | – |
| `VolumeSlider.qml` | 380 | Draggable volume/mic slider on a wide tile | `S: PanelActivity, Theme`. `C: Pill, MaterialIcon` | – | **TAKE** | – |
| `GammaBrightnessSlider.qml` | 229 | One slider for brightness, then gamma below 0 | `S: PanelActivity, Theme` | – | **ADAPT**: keep brightness. Gamma needs a gamma tool on niri (wlsunset/gammastep), or drop it. | – |
| `NetworkDialog.qml` | 424 | Wi-Fi list and password entry over the screen | `S: PanelActivity, Theme`. `C: SekaiScrollBar, WheelScroll` | – | **ADAPT**: error red `#c0392b` (205) becomes `danger`. | – |
| `BluetoothDialog.qml` | 324 | Paired-device list | same | – | **ADAPT**: `#c0392b` (177), battery low `#e0575b` (238). | – |
| `VolumeMixerDialog.qml` | 480 | Sinks, sources and per-app streams | same | – | **ADAPT**: `#c0392b` (180). | – |
| `NightLightDialog.qml` | 447 | Kelvin slider and schedule | `S: Theme` | 34: comment only ("hyprsunset's 'no tint'", `maxKelvin 6000`) | **ADAPT**: kelvin gradient `#dcecff → #ffe3b8 → #ff9a3c` (198-200). Keep it as a fixed physical ramp or tokens. The backend changes in QuickSource. | – |
| `NotificationCard.qml` | 350 | One notification card (list and heads-up) | `S: PanelActivity, Theme`. `C: ShellBadge` | – | **ADAPT** (`edgeTone "#e9e9e9"` 132) | – |
| `PowerMenu.qml` | 349 | Power rail beside the phone: lock, logout, suspend, … | `S: PowerBusyService, Theme`. `C: QuickToggle` | – | **ADAPT** (`#ff9f1c` 302, 326 become `warning`) | – |
| `PowerMenuScrim.qml` | 48 | Dimming glass under the power menu | `S: Theme` | – | **TAKE** | – |
| `PhoneRoute.js` | 81 | Screen stack: open, go, back, home, byNumber, startsSearch | – | – | **TAKE** (node-tested) | – |
| `ScreenGlyph.qml` | 69 | Tiny screen-with-bar drawing (bar position chips) | `S: Theme` | – | **TAKE** (with Settings) | – |
| `SekaiTile.qml` | 152 | Settings leaning tile (Toggle, Action, Stepper base) | `S: Theme`. `C: SekaiKey` | – | **ADAPT** (rename) | – |
| `SekaiHubTile.qml` | 166 | Big Settings menu tile with a number plate | `S: Theme, ScrapbookTheme` | – | **ADAPT** (rename, tokens) | – |

### 2.7 `modules/sekai/launcher/` (the Apps screen)

| File | Lines | What it does | Deps | Hyprland | Verdict | Ext./net |
|---|---|---|---|---|---|---|
| `LauncherFace.qml` | 735 | Apps screen (pure UI): clock strip, search, A-Z grid or ranked results, extras | `S: PanelImages, Theme`. `C: AppPlaceholder, LauncherExtras, LauncherLcd, SekaiScrollBar, WheelScroll` | – | **ADAPT** (hex 291/292/580/714 white ink on the LCD) | – |
| `AppResultRow.qml` | 150 | One result row | `S: IconCursorService, ScrapbookTheme, Theme` | – | **ADAPT** (drop IconCursorService; `#fde3da` 47) | – |
| `AppPlaceholder.qml` | 87 | Letter icon for apps without one | `S: Theme` | – | **ADAPT** (hard-coded `"#555473"` 37) | – |
| `LauncherLcd.qml` | 262 | Wallpaper as an "LCD" behind the phone's screen | `S: Theme`. `C: FramedImage`. `assets/images/lcd-mesh.png` | – | **TAKE** (optional) | – |
| `LauncherExtras.qml` | 594 | Extras router: Calc, Clip, Colour, Emoji, Web, `>cmd`, actions | `C: CalculatorCard, ClipboardCard, ColorCard, EmojiCard, WebCard, ExtrasSource`. `js: Calc, Extras` | – | **LATER** (ADAPT) | via ExtrasSource: `curl -s https://duckduckgo.com/ac/` (search suggestions), `xdg-open`, clipboard (`wl-paste`/`cliphist` via ClipboardWatcher) |
| `CalculatorCard.qml` + `Calc.js` | 262 + 235 | Calculator | `C: PhoneCard, PhoneKey, PhonePlate` | – | **LATER** (TAKE) | – |
| `ClipboardCard.qml` | 452 | Clipboard history | idem | – | **LATER** | ClipboardWatcher process |
| `EmojiCard.qml` + `Emoji.js` | 399 + 1974 | Emoji picker | idem | – | **LATER** (TAKE) | – |
| `WebCard.qml` | 365 | Web search with brand-coloured engine chips | idem | – | **LATER** (brand hex at 41 are brand colours, acceptable) | DDG, Google, YouTube, GitHub, Arch wiki, Wikipedia URLs |
| `ColorCard.qml`, `ExtraFrame.qml`, `ExtraKey.qml`, `GallerySortCard.qml` | 257, 94, 90, 120 | Old paper-card extras and wallpaper sort | `S: ScrapbookTheme` | – | **LEAVE** | – |
| `LauncherPhone.qml` | 881 | Old corner launcher phone. Only its Wallpapers screen and the `wallpaperphone` IPC are left (header: its Home is "no longer reachable"). | `S: EditMode, SettingsService, ShellScale, WallpaperService`. `C: PhoneBody, LauncherFace, WallpaperStage` | 3, 148 (`focusedMonitor`), 575 (`HyprlandFocusGrab`) | **LEAVE**: the Apps launcher already lives in `QuickPanel` + `LauncherFace`. Use this file only as a second-phone reference. | – |

The system side of the launcher is `services/AppSource.qml` (221 lines). It uses Quickshell `DesktopEntries` and
has no shell-outs. **ADAPT** it: remove `IconCursorService` (used for icon theme lookups). There are no Hyprland
dependencies.

### 2.8 `modules/sekai/settings/` (the landscape Settings phone)

| File | Lines | What it does | Deps | Hyprland | Verdict |
|---|---|---|---|---|---|
| `SettingsStage.qml` | 428 | The landscape phone: `PhoneBody{landscape}` with SettingsFace or WallpaperFace. Draws itself at any `flip` (0..1) and pops in on its own (`sPop`, `sAlpha`, `sTilt`). Pure UI. | `S: Theme, WallhavenService`. `C: PhoneBody, SettingsFace, WallpaperFace`. `js: FlipMath` | – | **ADAPT**: drop WallpaperFace and Wallhaven for milestone 1. |
| `SettingsFace.qml` | 858 | Settings screen: game-menu tiles, page host, header, search | `S: SettingsService, Theme, UpdateService`. `C: SekaiBackdrop, SekaiHubTile, SekaiKey, SekaiNavKey, SearchPill, SettingRoundButton, the 6 pages` | – | **ADAPT**: replace the Hyprland page with a niri page. Drop UpdateService (self-updater). |
| `SettingsPage.qml` | 305 | Scrolling page frame | `S: PanelActivity, Theme` | – | **TAKE** |
| `SectionCard.qml` | 181 | Card with a coloured name plate | `S: Theme` | – | **TAKE** |
| `SettingToggle`, `SettingAction`, `SettingStepper`, `SettingChoice`, `SettingChip`, `SettingSlider`, `SettingText` | 38, 31, 68, 83, 166, 252, 136 | Controls | `S: Theme`. `C: SekaiTile, SekaiKey, SettingRoundButton, Pill` | – | **TAKE** (after renaming the Sekai* bases) |
| `SettingsPageQuick.qml` | 236 | Quick toggles page (widgets on/off, bar position, …) | many widget services | – | **ADAPT** (keep only the services we port) |
| `SettingsPageGeneral.qml` | 441 | Time, units, Quick Panel, launcher and lock, notifications | `S: ClockService, HookService, LockState, PanelImages, RegionService, SettingsService, Theme` | – | **ADAPT** |
| `SettingsPageBar.qml` | 313 | Bar position, style and modules | `S: BarLayoutService, BarPositionService, BarStyleService, PackageUpdatesService, SettingsService, ShellScale` | – | **ADAPT** |
| `SettingsPageDesktop.qml` | 1237 | Wallpaper, widgets, theme, **App colours / GTK-Qt-KDE sync**, icons and cursor, plugins | 19 singletons incl. `AppThemeService, IconCursorService, ThemeService` | 1043 (`HyprlandSettings.isLua` for the app-colour row) | **ADAPT heavily**: keep the widget sections. **Delete** the system-theme, app-theme and icon-cursor sections. |
| `SettingsPageAbout.qml` | 411 | About, update, welcome replay, branding ("SekaiPop" at 116) | `S: GameModeService, UpdateService, WelcomeService, …` | – | **ADAPT** (our branding, no updater) |
| `SettingsPageHyprland.qml` | 971 | Hyprland gaps, borders, animations, displays, scroll-overview plugin | `S: DisplayService, HyprlandSettings, ScrollOverviewService` | about 66 lines (16 … 968): every row reads or writes `HyprlandSettings`; `hyprctl reload`; `nwg-displays`; a git URL for the scroll-overview plugin | **LEAVE** (rewrite as a niri page that edits only our own include file under `~/.config/niri`) |
| `DisplayLayout.qml` | 185 | Monitor layout editor | `S: DisplayService`. `js: DisplayMath` | via DisplayService (`hyprctl -j monitors all`) | **LEAVE** |
| `KeyCaps.qml`, `KeyRoundButton.qml` | 176, 108 | Keybind keycaps | `js: KeyBinds` | – | **LEAVE** (KeyRoundButton is TAKE if needed) |
| `SettingsPluginsCard`, `PluginRow`, `PluginEditor`, `PluginSettingRow`, `PluginSecretRow`, `PluginSectionHead`, `PluginBadge`, `PluginDiamond` | 273, 245, 286, 240, 152, 64, 115, 41 | Plugins UI | `S: PluginService, WidgetClones` | – | **LEAVE** (section 8) |

### 2.9 `modules/sekai/desktopWidgets/`

Shared pattern: each widget is its own full-screen transparent `PanelWindow`. It sits on `WlrLayer.Background`
(raised to `Bottom` while edited), with `keyboardFocus None` (or OnDemand via `KeysOnPoint`) and
`exclusionMode Ignore`, and a `mask` around its card. It has a `reveal` 0..1 driven by popIn and swallow
(section 6). It is gated by `FocusGate` (Desktop Focus Mode), dragged with `EditChrome`, and cloned per monitor
by `WidgetClones` and `DesktopMonitors`.

**Dependency chain to cut for milestone 1:** `EditMode`, `EditChrome`, `EditStage`, `EditPreview`, `SizeKey`,
`WidgetClones`, `PresetMotion` and `WallpaperService.restacking`. Stub them, or replace them with a fixed position
from our settings plus a simple drag.

| File | Lines | What it does | Deps (beyond the shared chain) | Hyprland | Verdict | Ext./net |
|---|---|---|---|---|---|---|
| `ClockWidget.qml` | 1881 | Desktop clock, 4 designs (KEYS, TOWER, STACK, …) | `S: ClockService, PresetMotion, Theme`. `C: Pill, MaterialIcon` | 75: comment only | **ADAPT**: tokens (`#000000` 578, `#ffffff` 645, 1763-1845). Strip edit chrome. Pick 1-2 designs. | – |
| `TodoWidget.qml` | 1410 | To-do card | `S: TodoService, PresetMotion, Theme`. `C: KeysOnPoint, WheelScroll, SizeKey` | 58: comment only | **ADAPT** (no hex; strip edit chrome) | – |
| `CalendarCardWidget.qml` | 1748 | Month calendar and upcoming events | `S: CalendarCardService, ClockService, Theme`. `C: CalendarChip, CalendarEventCard, CalendarField, CalendarNavKey, Burst, SekaiPlate, StickerText, Slant, KeysOnPoint`. `js: CalendarMath (bar/), EventMath` | 72: comment only | **ADAPT** (`weekendInk #ff8fa3/#e0575b`, `soonInk #ffc266/#f0a030` 308-311 become danger/warning) | – |
| `CalendarEventCard.qml`, `CalendarChip.qml`, `CalendarField.qml`, `CalendarNavKey.qml` | 300, 89, 84, 49 | Calendar parts | `S: Theme` | – | **ADAPT** (`#e0575b`, `#f0a030` 39-41; `#e0575b` 23) | – |
| `WeatherCardWidget.qml` | 2018 | Weather card (the bar popup on the desktop) | `S: WeatherCardService, SettingsService, PresetMotion, Theme`. `C: WeatherSource, WeatherGlyph, SekaiPlate, StickerText, Burst`. `js: WeatherMath` | 85: comment only | **ADAPT** (`#FFE066` and similar UV pastels at 1263 become series) | via WeatherSource: `curl https://api.open-meteo.com/v1/forecast`, `https://geocoding-api.open-meteo.com/v1/search`, `https://ipwho.is/` (IP geolocation when no city is set) |
| `LyricsWidget.qml` | 849 | Sung-along lyrics on the desktop | `S: LyricsService`. `C: LyricsLine, LyricsWord, LyricsKey, MediaSource` | 83: comment only | **ADAPT** (popIn 520 ms, overshoot 1.6, swallow 360 ms) | via LyricsService (section 10) |
| `LyricsLine.qml`, `LyricsWord.qml`, `LyricsKey.qml` | 367, 103, 46 | Lyric line, word sticker, sync keys | `S: Theme`. `js: LyricsMath` | – | **ADAPT** (`#FFFFFF` fills 291/300/360, 24, 34 become `onAccent`/`ring`) | – |
| `LyricsSources.qml` | 369 | Lyrics provider picker window | `S: LyricsService, DesktopMonitors, ShellScale, Theme` | – | **LATER** | – |
| `FocusGate.qml` | 114 | One widget's view of Desktop Focus Mode | `S: FocusService`. `js: FocusMath` | via FocusService (Hyprland toplevels, monitors, workspaces) | **ADAPT**: feed it from NiriWorkspaces (`occupiedOn`, the active workspace), or stub `show: true`. | – |
| `KeysOnPoint.qml` | 30 | Keyboard OnDemand only while hovered or typing | – | – | **TAKE** | – |
| `UserCardWidget.qml` | 1301 | "Player card" with avatar, banner and uptime | `S: UserCardService, PanelImages, PresetMotion`. `C: FramedImage` | – | **LATER** | `cat /proc/uptime`, `uname -n` |
| `PaletteWidget.qml` | 854 | Palette tool card | `S: PaletteService`. `C: Palette*` | – | **LEAVE** (theme tool) | – |
| `ImageWidget.qml`, `ImageInspector.qml` | 1210, 544 | Custom images on the desktop | `S: ImageService, PanelImages` | – | **LATER** | `pick-custom-image.sh` |
| `StickyNotesWidget.qml`, `StickyNote.qml` | 271, 588 | Sticky notes | `S: NotesService`. `js: NotesMath` | – | **LATER** | – |
| `PluginWidgetHost.qml` | 507 | Window for a plugin widget | `S: PluginService` | – | **LEAVE** (section 8) | – |

### 2.10 `modules/sekai/bar/`

| File | Lines | What it does | Deps | Hyprland | Verdict | Ext. |
|---|---|---|---|---|---|---|
| `Bar.qml` | 1168 | **Bar host** (talks to the system): window, edge, styles, auto-hide, popups, sources. | 19 singletons (Bar*Service, DiscordVoiceService, EqualizerService, GameModeService, HyprlandSettings, IconCursorService, NiriWorkspaces, PackageUpdatesService, PcCavaService, PresetMotion, PrivacyService, SettingsService, ShellScale, StatusIconsService, Theme, VisualizerService). `C: Status_Bar`, every popup, `MediaSource, WeatherSource, BatterySource, ResourceSource` | 2; 146, 149 `HyprlandSettings.num("general.gaps_out")`; 434 `focusedMonitor`; 743-755 `hyprctl -j devices` (keyboard layout); 778 Connections on HyprlandSettings; 800 `hyprctl switchxkblayout all next`; 804 `Hyprland.monitorFor`; 805, 809 workspaces (**niri branch exists**); 822 `usingLua`; 827-828 `activeToplevel`; 1149, 1151 `Hyprland.dispatch` (**niri branch at 1140**) | **ADAPT** (core): the niri path is half done. Gaps become a token or setting. Keyboard layout uses niri events. Active window uses `ToplevelManager.activeToplevel`. Drop Discord, EQ, cava, updates and game mode. | `hyprctl` (remove) |
| `Status_Bar.qml` | 1155 | Bar layout (pure UI), module order, capsule/float/classic styles | `S: Theme`. `C:` every indicator | – | **ADAPT** (keep one or two styles) | – |
| `WorkspaceBadges.qml` | 453 | Workspace badges (pills and capsule dots) | `S: Theme`. `C: Pill` | – | **TAKE** (fed by Bar) | – |
| `SekaiPopup.qml` | 326 | Shared popup frame: pops out of its button, swallows back. **The canonical pop/swallow** (section 6). | `S: PopupHandoff, Theme`. `C: Pill, ScaleHost` | 2, 176 (`HyprlandFocusGrab` on popup + bar) | **ADAPT**: catcher instead of the grab. Rename. | – |
| `BarTip.qml` | 215 | Hover tag with a stuck-pointer check | `S: Theme`. `C: ScaleHost` | 140 `hyprctl -j cursorpos` | **ADAPT**: drop the cursorpos check (niri has no cursor IPC) and rely on HoverHandler. | – |
| `DateIndicator.qml`, `CalendarPopup.qml`, `CalendarMath.js` | 110, 830, 177 | Date pill and month popup | `S: SettingsService` | – | **ADAPT** (`weekendInk` 76) | – |
| `WeatherIndicator.qml`, `WeatherPopup.qml` | 112, 1112 | Weather pill and popup | `S: SettingsService, Theme`. `js: WeatherMath` | – | **ADAPT** (`#FFE066`, `#ff6f78` 640/1106) | WeatherSource |
| `MediaPill.qml`, `PillBars.qml`, `PillWave.qml` | 405, 48, 90 | Media pill and mini visualizers (ported from end4-pC) | – | – | **ADAPT** (visualizer data comes from cava; drop it or keep the static waves) | cava via VisualizerService |
| `NotificationBadge.qml` | 93 | Bell with count | `S: Theme` | – | **ADAPT** (`#e0575b` 58 becomes danger) | – |
| `StatusPill.qml` | 159 | Wi-Fi / BT / speaker icons pill | `S: Theme` | – | **TAKE** | via StatusIconsService (`status-icons.sh`: nmcli, bluetoothctl) |
| `BatteryIndicator.qml`, `BatteryPopup.qml`, `BatteryMath.js` | 128, 731, 99 | Battery pill and popup | `S: Theme` | – | **ADAPT** (tier fills use SEKAI pastels, 56) | UPower |
| `KeyboardLayoutIndicator.qml` | 66 | Layout pill | `S: Theme` | – | **ADAPT** (niri or fcitx source) | – |
| `PrivacyIndicator.qml` | 177 | Mic, screen and desktop-audio in use | `S: Theme` | – | **LATER** (Pipewire) | – |
| `ResourceIndicator.qml`, `ResourcePopup.qml`, `LoadGauge.qml`, `LoadPlate.qml` | 180, 263, 216, 86 | CPU/RAM | `S: Theme` | – | **LATER** | `/proc` via ResourceSource |
| `TrayButton`, `TrayCollection`, `TrayMenu`, `TrayPopups` | 166, 454, 250, 656 | System tray | `S: PopupHandoff, SettingsService` | TrayPopups 2, 451 (`HyprlandFocusGrab`) | **LATER / ADAPT** (catcher). Conflicts with Noctalia's tray watcher. | – |
| `UtilButtons`, `UtilKey`, `UtilKeys`, `UtilPopup` | 248, 89, 138, 71 | Utility keys: snip, record, colour picker, dark mode, … | `S: RegionService, ThemeService, KeyboardService` | – | **LEAVE** (ThemeService dark toggle triggers the system sync; `hyprpicker`) | grim, slurp, hyprpicker, wl-copy |
| `ActiveWindowKey.qml` | 91 | Active window on a vertical bar | `S: Theme` | – | **TAKE** (fed by Bar) | – |
| `ScrollHint.qml`, `SectionTab.qml` | 72, 56 | Small markers | `S: Theme` | – | **TAKE** | – |
| `UpdatesBadge.qml` | 169 | Pending pacman updates | `S: Theme` | – | **LEAVE** | `pkg-updates.sh` (checkupdates) |
| `DiscordKey`, `DiscordMemberRow`, `DiscordPill`, `DiscordPopup` | 66, 248, 385, 453 | Discord voice | `S: DiscordVoiceService` | via the service (`Hyprland.toplevels`, `dispatch`) | **LEAVE** | python bridge, Vencord companion, `cdn.discordapp.com` |

### 2.11 `modules/sekai/mediaControls/`

| File | Lines | What it does | Deps | Hyprland | Verdict |
|---|---|---|---|---|---|
| `MediaPopup.qml` | 795 | Media card: cover, title, keys, one tab per player | `C: SekaiPopup, MediaKey, MediaTab, SekaiPlate, DiamondDot, VisualizerCover, Pill`. `js: MediaOwner, MediaMath`. `Quickshell.Services.Mpris` | 2; 70, 111, 122 `Hyprland.toplevels.values` (which window owns a player); 113 `usingLua`; 188, 191 `Hyprland.dispatch(focuswindow …)` | **ADAPT**: owner lookup via `ToplevelManager.toplevels` (appId, title) and focus with `toplevel.activate()`. `"#55000000"` scrim at 446. |
| `MediaKey.qml`, `MediaTab.qml` | 91, 82 | Keycap, slanted tab | `S: Theme` | – | **TAKE** |
| `MediaMath.js` | 228 | Time, cover URL helpers (`i.ytimg.com` thumbnails) | – | – | **TAKE** |
| `MediaOwner.js` | 73 | Match a player to a Hyprland window | – | data shape is Hyprland clients | **ADAPT** (to the toplevel shape) |

`services/MediaSource.qml` (140) picks the player through Quickshell MPRIS. It does not use `playerctl`.
**TAKE** it. For cover art from YouTube tabs it may build `https://i.ytimg.com/vi/<id>/…` URLs.
`VisualizerCover.qml` caches cover art in `~/.cache/sekaipop/cover-art`; rename the cache directory.

### 2.12 `modules/sekai/background/`

| File | Lines | What it does | Hyprland | Verdict |
|---|---|---|---|---|
| `WallpaperLayer.qml` | 781 | Per-screen `WlrLayer.Background` wallpaper with shader transitions, parallax, video pause and edit backdrop | 3; 102 `Hyprland.monitorFor(screen)` (parallax workspace id); 164 `Hyprland.refreshWorkspaces()` (fullscreen check for the video pause) | **LATER**: we don't need the shell to own the wallpaper in milestone 1. Two shells on the background layer collide (Noctalia/swaybg). If taken: niri active workspace idx for parallax, `fade` transition only. |
| `WallpaperTextureSlot.qml` | 43 | One GPU texture slot (destroyed, not reused, to avoid FBO leaks) | – | **TAKE** with the layer |
| `VideoWallpaper.qml`, `MpvpaperWallpaper.qml` | 46, 238 | QtMultimedia or mpvpaper video wallpaper | – | **LEAVE** |

### 2.13 OSD and notification popups

| File | Lines | What it does | Deps | Hyprland | Verdict |
|---|---|---|---|---|---|
| `onScreenDisplay/OSDPopup.qml` | 137 | OSD window on the focused monitor | `S: OSDSource, BarPositionService, ShellScale`. `C: OSDIndicator` | via OSDSource | **ADAPT** |
| `onScreenDisplay/OSDIndicator.qml` | 349 | Volume, mic, brightness and gamma plate | `C: Pill, SekaiPlate, Slant, StickerText` | – | **ADAPT** (`mutedColor #B39DDB`, `overColor #FF9ECB` = SEKAI pastels at 73-74; `#ff8a92`/`#c93a40` at 256) |
| `notificationPopup/NotificationPopup.qml` | 208 | Optional corner popup stack (`notify.style "popups"`) | `S: BarPositionService, ShellScale` | – | **LATER**: the phone "peek" is the milestone-1 path. |
| `notificationPopup/NotificationPopupCard.qml` | 534 | One popup card | `S: Theme`. `js: NotifyKinds` | – | **LATER** (`#FFB3D1`, `#FF6F9C` critical) |

### 2.14 Lock and polkit

| File | Lines | What it does | Verdict |
|---|---|---|---|
| `lock/Lockscreen.qml` | 164 | `WlSessionLock` + PAM (`Quickshell.Services.Pam`), with optional fingerprint (`lock/pam/lock-fingerprint`) | **LEAVE** for milestone 1. The default look is the Project Sekai gacha screen (`LockSurface.qml`, 1047). The calendar look (`LockCalendar.qml`, 1143) and `LockContext.qml` (PAM logic) are **LATER** candidates. |
| `lock/LockRing.qml` | 259 | Lock transition through the `*_lock` shaders | **LEAVE** |
| `lock/LockHost.qml`, `LockPanel`, `LockPlate`, `LockPowerKey`, `LockLyrics` | 76, 153, 100, 57, 228 | Lock parts | **LEAVE** |
| `polkit/PolkitPrompt.qml` | 104 | Polkit agent window (`Quickshell.Services.Polkit` via PolkitService). Hyprland: 3, 24 (`focusedMonitor`). | **LATER / ADAPT**. Only one polkit agent per session: decide between ours, Noctalia's and KDE's. |
| `polkit/PolkitDialog.qml` | 305 | Password card | **LATER** (TAKE, tokens) |

### 2.15 Other module directories (outside milestone 1)

| Dir | Verdict | Why |
|---|---|---|
| `dock/` (Dock.qml 3308 + 20 files) | LEAVE | Heavy Hyprland coupling (DockService: `hyprctl clients/monitors`, `Hyprland.dispatch`). Not in milestone 1. |
| `editMode/` (24 files) | LEAVE | Edit Desktop (drag, presets, theme board, matugen controls). The widgets depend on it; stub it out. |
| `overview/`, `cheatSheet/`, `keybinds/` | LEAVE | Hyprland-specific (HyprlandData, `hyprctl -j binds`, keybind editing). |
| `equalizer/` (Sekai Pad), `visualizer/` | LEAVE | EasyEffects, cava, Sekai Pad identity. Visualizer is LATER at most. |
| `welcome/` | LEAVE | Sekai branding, unit logos, shaders. |
| `wallpaperSelector/` | LATER | Wallpapers face of the landscape phone, Wallhaven (network). |
| `palette/`, `framing/` | LEAVE / LATER | Palette tool (theme). The framer is only needed with PanelImages framing. |
| `regionSelector/` | LEAVE | Screenshots and recording with grim, slurp and Hyprland rules (RegionService). |
| `keyboard/` (on-screen keyboard) | LEAVE | `wtype` |
| `desktopMenu/` | LATER | Right-click desktop menu that opens Edit Desktop. |

### 2.16 `services/`

Non-singletons (instantiated in `shell.qml`): ActivationEntry, AppSource, BatteryAlertService, BatterySource,
ExtrasSource, MediaSource, NotificationSource, QuickSource, ResourceSource, TraySource, WeatherSource. Everything
else is a `pragma Singleton`.

| Service | Lines | What it does | Hyprland coupling | Ext. programs / net | Writes | Verdict |
|---|---|---|---|---|---|---|
| `NiriWorkspaces.qml` | 188 | niri workspaces over `$NIRI_SOCKET` (EventStream + FocusWorkspace requests) | – | – (Quickshell `Socket`) | – | **TAKE + extend** (focused output, windows, keyboard layouts) |
| `SettingsService.qml` | 450 | Key/value options with defaults. `get`, `flag`, `set`, `toggle`. IPC `options`. Saves only the diff. | – | `sh state/settings-state.sh` | `~/.config/sekaipop/settings.json` | **ADAPT**: path, and replace the script with `FileView` + `JsonAdapter`. Prune the defaults. **Delete the systemTheme.\* and appTheme.\* defaults.** |
| `ShellScale.qml` | 215 | Per-monitor UI scale | 5; 142 (`focusedMonitor`) | `state/scale-state.sh` | `~/.config/sekaipop/scale.json` | **ADAPT** |
| `QuickSource.qml` | 2018 | Quick Panel system side: network, BT, audio, brightness, night light, keep-awake, power, extra tiles | 247-252 (`hyprctl hyprsunset temperature/gamma`, `hyprctl getoption animations` and `decoration.screen_shader`); 477, 733-734 (`hyprsunset`); session logout via `system/session-logout.sh` (hyprctl clients and exit) | `nmcli`, `bluetoothctl`, `wpctl`, `pactl`, `brightnessctl`, `ddcutil`, `systemd-inhibit`, `powerprofilesctl`, `easyeffects`, `warp-cli`, **`pkexec … /etc/resolv.conf`** (994-997), `grim`, `slurp`, `wl-copy`, `songrec` + `ffmpeg`, `notify-send`, `systemctl`/`loginctl` poweroff/reboot/suspend/hibernate/firmware-setup; scripts `antiflashbang-state.sh`, `keep-awake-state.sh`, `nightlight-state.sh`, `qp-tiles-state.sh`, `open-settings-app.sh`, `session-logout.sh`, `music-recognize.sh` | `~/.local/state/sekaipop/{qp-tiles, nightlight, keep-awake}`, `~/Pictures/Screenshots` | **ADAPT** (core): keep network, BT, audio, brightness, keep-awake and power. Night light and gamma move to wlsunset or gammastep. Logout is `niri msg action quit -s`. **Remove** WARP and pkexec, Game Mode, Anti-Flashbang, EasyEffects and music recognition. Move state under `~/.cache`. |
| `NotificationSource.qml` | 701 | Notification server, list, heads-up toast, DND, history | 3; 82 (`focusedMonitor.activeWorkspace.lastIpcObject.hasfullscreen`, quiet while fullscreen); 574 (popup monitor); 678, 684 (`refreshWorkspaces`) | `mkdir -p` | `~/.local/state/sekaipop/notifications*.json` | **ADAPT**: fullscreen detection via niri (window `is_fullscreen`, if exposed) or drop it. Focused output. Path to `~/.cache`. **Owns `org.freedesktop.Notifications`, so it conflicts with Noctalia.** |
| `OSDSource.qml` | 365 | Volume, mic, brightness and gamma for the OSD | 5; 125 (`focusedMonitor`); 291, 335 (`hyprctl hyprsunset gamma`) | Pipewire (`Quickshell.Services.Pipewire`), `brightnessctl`, `ddcutil` | – | **ADAPT** |
| `AppSource.qml` | 221 | Desktop entries index for the Apps screen | – | – (DesktopEntries) | – | **ADAPT** (drop IconCursorService) |
| `MediaSource.qml` | 140 | MPRIS player pick | – | – | – | **TAKE** |
| `WeatherSource.qml` | 367 | Open-Meteo fetch and geocode | – | `curl -s -m 10` to open-meteo and ipwho.is | – | **TAKE** |
| `WeatherCardService.qml` | 165 | Weather card position and state | – | `state/weathercard-state.sh` | `~/.local/state/sekaipop/weathercard.json` | **ADAPT** (path) |
| `ClockService.qml` | 174 | Clock widget state (design, 12/24 h, position) | comment only | `state/clock-state.sh` | `~/.local/state/sekaipop/clock*` | **ADAPT** (path) |
| `TodoService.qml` | 250 | To-do items and position | – | `state/todo-state.sh` | `…/todo.json` | **ADAPT** (path) |
| `CalendarCardService.qml` | 234 | Calendar events and position | – | `state/calendarcard-state.sh` | `…/calendarcard.json` | **ADAPT** (path) |
| `LyricsService.qml` | 1271 | Lyrics lookup, cache and position | – | `curl` to 8 providers (section 10). `state/lyrics-cache.sh`, `state/lyrics-state.sh` | `~/.cache/sekaipop/lyrics`, `…/state/sekaipop/lyrics*` | **ADAPT** (paths). Limit the providers by default for privacy. |
| `BarPositionService.qml` | 136 | Bar edge, reserved size | – | `state/barposition-state.sh` | state dir | **ADAPT** |
| `BarStyleService.qml` | 110 | Bar style (float, capsule, …) | – | `state/barstyle-state.sh` | state dir | **ADAPT** |
| `BarLayoutService.qml` | 469 | Bar module order per monitor | – | `state/barlayout-state.sh` | state dir | **ADAPT** (or a fixed layout first) |
| `StatusIconsService.qml` | 170 | Wi-Fi, BT and ethernet for StatusPill | – | `system/status-icons.sh` (nmcli, bluetoothctl) | – | **TAKE** |
| `BatterySource.qml`, `BatteryAlertService.qml` | 39, 127 | UPower battery and low-battery notifications | – | `notify-send` | – | **TAKE** / LATER |
| `PopupHandoff.qml` | 19 | "Another popup is opening" serial | – | – | – | **TAKE** |
| `PowerBusyService.qml` | 83 | Power action in flight | – | – | – | **TAKE** |
| `DesktopMonitors.qml` | 153 | Which monitors show the widgets | – | `state/monitors-state.sh` | state dir | **ADAPT** (or fixed to one monitor) |
| `WidgetClones.qml` | 251 | Per-monitor widget copies | – | `state/clones-state.sh` | state dir | LEAVE (stub) |
| `FocusService.qml` | 396 | Desktop Focus Mode | 5; 118, 141, 234-251, 303-350 (Hyprland toplevels, monitors and workspaces, refresh*) | – | – | **ADAPT** (to niri) or LATER |
| `GameModeService.qml` | 118 | Game mode | via `hyprland/gamemode-state.sh` | `hyprctl` | – | **LEAVE**. ThemeSet reads `GameModeService.enabled` in `quickFlat`; stub it to false. |
| `ComponentActivation.qml`, `ActivationEntry.qml` | 58, 125 | Lazy creation of big windows | ActivationEntry 3, 49 (`focusedMonitor`) | – | – | **ADAPT** (small) |
| `HookService.qml` | 48 | Runs user hook executables on events | – | the user-configured path | – | LEAVE (arbitrary exec) |
| `PolkitService.qml` | 86 | Polkit agent | – | – | – | LATER |
| `PrivacyService.qml` | 214 | Pipewire node watch for mic and screen | – | – | – | LATER |
| `TraySource.qml` | 74 | SystemTray model | – | `mkdir -p` | `~/.local/state/sekaipop/tray.json` | LATER |
| `ResourceSource.qml` | 79 | CPU/RAM from `/proc` | – | – | – | LATER |
| `ThemeService.qml` | 1362 | Sekai group palettes, light/dark/darker, matugen, per-monitor themes, **system theme sync**, Discord theme | 5 (import only) | `matugen` (via `matugen-state.sh`), `system-theme.sh` (gsettings, dconf, kwriteconfig, qt5ct/qt6ct, GTK files), `discord-theme.sh`, `bash -c` (switchwall.sh or gsettings) | `~/.local/state/sekaipop/{theme,dark,darker,custom-palette}`, `~/.cache/sekaipop/matugen/*.json`, and via system-theme: `~/.config/kdeglobals`, `gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`, `~/.local/share/color-schemes`, `~/.local/share/themes` | **LEAVE.** Replace it with a ~60-line `Tokens.qml` (FileView on our tokens JSON, `watchChanges: true`). |
| `AppThemeService.qml` | 337 | Recolours kitty, foot, VS Code, fish prompt, fuzzel/rofi and Hyprland borders | – | `theming/app-theme.sh` | `~/.config/{kitty,foot,fuzzel,rofi,fish,…}`, `~/.config/sekaipop/vscode-colors.json` | **LEAVE** (forbidden writes) |
| `IconCursorService.qml` | 536 | Icon theme and cursor packs, Windows cursor converter | 5; 488 comment | `icon-cursor.sh`, `pick-cursor-pack.sh`, `win-cursor.py`, `qs -c` | `~/.local/share/icons`, `~/.icons/default/index.theme`, `~/.config/kcminputrc`, gsettings | **LEAVE** (forbidden writes; touches KDE `kcminputrc`) |
| `PaletteService.qml` | 311 | Palette tool state | – | `state/palette-state.sh` | state dir | LEAVE |
| `WallpaperService.qml` | 1273 | Wallpaper paths, transitions, thumbnails, folder picking | – | `wallpaper-state.sh`, `wallpaper-thumbs.sh` (ImageMagick/ffmpeg), `pick-folder.sh`, `qs -c` | `~/.local/state/sekaipop/wallpaper*`, a thumbnail cache, `~/Pictures/Wallpapers` | LATER. Many widgets read `WallpaperService.restacking` or `ready`; stub them. |
| `WallhavenService.qml` | 345 | Wallhaven search and download | – | `wallpapers/wallhaven.sh` (curl `wallhaven.cc/api/v1`) | downloads into the wallpaper folder | LEAVE |
| `EditMode.qml`, `EditGrid.qml`, `DesktopPresetService.qml`, `PresetWidgets.qml`, `ShelfService.qml`, `PinnedAppsService.qml`, `FilesStackService.qml`, `DockService.qml`, `ImageService.qml`, `NotesService.qml`, `UserCardService.qml`, `TimerService.qml`, `ClipboardWatcher.qml`, `ExtrasSource.qml` | – | Edit Desktop, presets, dock, misc widgets | EditMode: 5, 717-958 (`dispatch`, `hyprctl -j clients/monitors`); DockService: 5, 29-95, 187-212 | various `sh` state scripts, `xdg-open`, `wl-copy`, `curl` (DDG suggestions in ExtrasSource) | state dir, `~/.config/sekaipop/presets/` | LEAVE / LATER. **EditMode must be stubbed** (`active: false`), because the phone, bar and widgets read it. |
| `HyprlandData.qml`, `HyprlandSettings.qml`, `KeybindService.qml`, `KeyboardService.qml`, `DisplayService.qml`, `ScrollOverviewService.qml`, `RegionService.qml`, `DiscordVoiceService.qml` | 121, 188, 189, 115, 364, 298, 419, 263 | Hyprland data, settings, binds, displays, plugin, regions, Discord | whole files | `hyprctl`, `hyprland-settings.sh`, `keybinds.sh`, `displays.sh`, python Discord bridge | `~/.config/hypr/sekaipop_overrides.lua`, `monitors.lua` | **LEAVE**. `HyprlandSettings` is read in Bar.qml (146, 149) and QuickPanel (489, 503); replace those reads with a token or setting. |
| `EqualizerService.qml`, `PcCavaService.qml`, `VisualizerService.qml` | 694, 114, 312 | EasyEffects EQ, cava | – | `eq/equalizer.sh`, `cava` (`setpriv --pdeathsig`) | `~/.local/state/sekaipop/eq`, `~/.config/easyeffects/output` | LEAVE |
| `UpdateService.qml`, `PackageUpdatesService.qml`, `WelcomeService.qml`, `LockState.qml`, `LockCropService.qml`, `GameModeService.qml` | – | Self-updater (git pull from GitHub), pacman updates, welcome, lock | – | `update-check.sh` (git, curl GitHub), `pkg-updates.sh`, `restart-shell.sh` | `~/.cache/sekaipop/update-seen`, `~/.config/sekaipop/update-*` | **LEAVE** (a self-updater from a third-party repo is not wanted) |
| `PluginService.qml`, `PluginState.qml` | 290, 227 | Plugin discovery and state | – | `state/plugin-state.sh` | `~/.config/sekaipop/plugins/`, state dir | LEAVE (section 8) |

### 2.17 `scripts/`

| Script group | Files | What they do | Writes | Verdict |
|---|---|---|---|---|
| `state/*-state.sh` | 25 files, 32-368 lines (`preset-state.sh` 368, `wallpaper-state.sh` 96, `pinned-apps-state.sh` 78, `theme-state.sh` 74, `lyrics-cache.sh` 72, `welcome-state.sh` 69, `plugin-state.sh` 65, `qp-tiles-state.sh` 54, the rest about 33) | One `save`/`load` helper per service: atomic tmp-then-mv JSON or plain text | `${XDG_STATE_HOME:-~/.local/state}/sekaipop/*`. `settings-state.sh` writes `${XDG_CONFIG_HOME}/sekaipop/settings.json` and moves the old one. `lyrics-cache.sh` writes `~/.cache/sekaipop/lyrics`. | **ADAPT the idea, not the scripts.** Replace them with QML `FileView` + `JsonAdapter` (atomic write) under `~/.config/quickshell/<shell>/` and `~/.cache/<shell>/`. One fewer `sh` per save. |
| `theming/` | `app-theme.sh` 606, `system-theme.sh` 586, `icon-cursor.sh` 520, `discord-theme.sh` 502 (+4 css), `win-cursor.py` 849, `matugen-state.sh` 126 (+`matugen-template.json` 28), `pick-cursor-pack.sh` 77, `prompt-sekaipop.sh` / `prompt-pjsekai.sh` 176, `system-templates/*` (gtk, kde, qt5ct, qt6ct) | System and app theming | `kdeglobals`, `gtk-3.0/4.0` css + `settings.ini`, `qt5ct`/`qt6ct`, `~/.local/share/{color-schemes,themes,icons}`, `~/.icons`, `kcminputrc`, gsettings/dconf, kitty, foot, fuzzel, rofi, fish `conf.d`, VS Code, Vencord, Vesktop, Equicord, `~/.bashrc`/`~/.zshrc` prompt lines | **LEAVE (forbidden).** One exception: `matugen-state.sh` + `matugen-template.json` write only `~/.cache/sekaipop/matugen/` and use a private matugen config. They are a usable *pattern* if we ever want wallpaper tokens, but our tokens come from outside. |
| `hyprland/` | `displays.sh` 141, `hyprland-settings.sh` 188, `keybinds.sh` 119, `gamemode-state.sh` 50, `antiflashbang-state.sh` 52, `anti-flashbang*.glsl` | Hyprland config and live tweaks | `~/.config/hypr/*` | **LEAVE** |
| `system/` | `session-logout.sh` 34 (hyprctl, loginctl), `open-settings-app.sh` 61, `status-icons.sh` 65, `pkg-updates.sh` 57, `update-check.sh` 205, `restart-shell.sh` 33, `region-action.sh` 204, `migrate-from-pjsekai.sh` 187 | Session, status and updates | – / `~/.local/state/sekaipop` | `status-icons.sh`: **TAKE**. `open-settings-app.sh`: ADAPT (it prefers KDE's page, which is fine). `session-logout.sh`: replace with niri. The rest: LEAVE. |
| `images/` | `pick-image.sh` 148, `shrink-image.sh` 119, `pick-custom-image.sh` 108 | File chooser (kdialog/zenity/yad), downscale (ImageMagick/ffmpeg) | `~/.local/share/sekaipop/…` | ADAPT the paths if PanelImages is ported |
| `wallpapers/`, `thumbnails/` | `default-wallpaper.sh` 42, `pick-folder.sh` 70, `lock-crop.sh` 36, `wallhaven.sh` 112, `wallpaper-thumbs.sh` 112 | Wallpaper helpers | `~/Pictures/Wallpapers`, a thumbnail cache | LATER / LEAVE |
| `cava/` | `sekai_analyzer.py` 474, `cava-*.conf` | Audio analyzer | – | LEAVE |
| `eq/equalizer.sh` | 683 | EasyEffects presets | `~/.config/easyeffects/output`, state | LEAVE |
| `discordVoice/` | python bridge 501, Vencord companion (ts + `install.sh` 257) | Discord voice | `~/.config/Vencord/…` | LEAVE |
| `musicRecognition/music-recognize.sh` | 40 | songrec | – | LEAVE |

### 2.18 `shaders/`

| Shader | Source | Prebuilt `.qsb` | Used by | Milestone 1? |
|---|---|---|---|---|
| `fade.{vert,frag}` | yes | yes | WallpaperLayer (plain crossfade, also the fallback) | Only if we own the wallpaper. Neutral. |
| `sekai_{ring,star,iris,flash,blocks}.{vert,frag}` | yes | yes | WallpaperLayer transitions (Sekai emblem motifs) | No (identity) |
| `*_lock.{vert,frag}` (6 styles) | yes | yes | LockRing | No |
| `welcome_{dots,halo,warp}` | yes | yes | Welcome | No |
| `visualizer/{tide,ribbons,scope,pulse}.frag` | yes | yes | ShaderVisualizerLayer, TideShaderLayer | No |
| `visualizer/{aurora,dots,mirror,ring}.frag.qsb` | **no source** | yes | Visualizer (ported from pCtrade) | No (opaque binaries: do not ship) |

Totals: 28 top-level `.qsb` (one per source) plus 8 visualizer `.qsb`. Rebuild with `shaders/compile-shaders.sh`
(`qsb --qt6`, falling back to `--glsl "100 es,120,150" --hlsl 50 --msl 12`) or `visualizer/build.sh`. The local
`/usr/lib/qt6/bin/qsb` is 6.12. If we ever take `fade`, rebuild it from source rather than ship the downloaded
binary.

---

## 3. Hyprland to niri: replacement table (milestone-1 files only)

| Hyprland use | Where | niri replacement |
|---|---|---|
| `Hyprland.focusedMonitor` | QuickPanel:347, PanelImages:121/183, ShellScale:142, OSDSource:125, NotificationSource:574, ActivationEntry:49, PolkitPrompt:24, ReloadPopup:46, Bar:434, KeyboardService:91, LauncherPhone:148 | `NiriWorkspaces.focusedOutput()`: the output of the workspace with `is_focused`. Fallback: `Quickshell.screens[0]`. |
| `Hyprland.monitorFor(screen).activeWorkspace.id`, `Hyprland.workspaces` | Bar:804-809, WallpaperLayer:102 | `NiriWorkspaces.activeOn(screen.name)` and `occupiedOn()` (already in Bar). |
| `Hyprland.dispatch("workspace N")` | Bar:1149-1151 | `NiriWorkspaces.focus(output, idx)` (already in Bar:1140). |
| `HyprlandFocusGrab` (click-away) | QuickPanel:1675, SekaiPopup:176, TrayPopups:451, ScalePopup:87, LauncherPhone:575 | A transparent full-screen `PanelWindow` "catcher" one layer below the popup (pattern at QuickPanel:1694-1721), plus the in-window `awayArea` MouseArea for the exclusive-keyboard case. |
| `GlobalShortcut` | QuickPanel:1145 | niri `binds { Mod+… { spawn "qs" "-c" "<shell>" "ipc" "call" "phone" "go" "apps"; } }`. A bare-Super release has no niri equivalent; use a chord. |
| `Hyprland.activeToplevel` (window title) | Bar:827-828 | `ToplevelManager.activeToplevel` (`Quickshell.Wayland`, wlr-foreign-toplevel; niri supports it) or niri `WindowFocusChanged` and `WindowsChanged` events. |
| `Hyprland.toplevels` + `dispatch focuswindow` | MediaPopup:70-191 | `ToplevelManager.toplevels` (appId, title) and `toplevel.activate()`. |
| `hyprctl -j devices` / `switchxkblayout` | Bar:743-800 | niri `KeyboardLayoutsChanged` and `KeyboardLayoutSwitched` events, and the `SwitchLayout` action over `$NIRI_SOCKET` (or fcitx5 if that is the typing-language owner). |
| `HyprlandSettings.num("general.gaps_out")` | Bar:146-149 | A token or setting (`bar.edgeGap`), or parse our own niri include. |
| `hyprctl hyprsunset temperature/gamma` | QuickSource:247-248, 477, 733-734; OSDSource:291, 335 | `wlsunset -t <K> -T <K>` or `gammastep -O <K>` (wlr-gamma-control), with state kept by the shell. Gamma below 100 %: `wlsunset -g`, or drop it. |
| `hyprctl getoption …` (game mode, anti-flashbang) | QuickSource:249, 252 | Drop the tiles. |
| `hyprctl reload` | QuickPanel:1036 | Just `Quickshell.reload(true)`. |
| `hasfullscreen` (quiet while fullscreen) | NotificationSource:82-84 | niri window state if the IPC exposes fullscreen; otherwise drop the option. |
| `hyprctl -j cursorpos` | BarTip:140 | Drop the stuck-pointer check. |
| Session logout (`session-logout.sh`) | QuickSource, Extras.js:232 | `niri msg action quit --skip-confirmation` (or `loginctl terminate-session`). |

---

## 4. Theme and colour system

### 4.1 How it works today

1. **Palette source: `services/ThemeService.qml`.**
   - `baseGroups` (lines 56-63) holds the six Project Sekai unit palettes: vs (the default), leoneed, mmj, vbs,
     wxs and nightcord.
   - `extraGroups` holds `mono`. `matugen` comes from `buildMatugenPalette()` (lines 599-628, Material dark/light
     tones mapped onto the roles). `custom` comes from the Palette tool.
   - Every palette has the same role keys: `border, A, B, deep, divider, hoverTint, rimHi, bezel, wallLight,
     wallMid, wallDark, hardware, lens, glint, boardBg, boardDot`, plus the optional `lockMint`, `lockPink` and
     `mono`.
   - `ThemeService.palette` is the active one. The mode is `dark` / `darker` (saved in
     `~/.local/state/sekaipop/{dark,darker}`). Writing `theme.perMonitor` gives `paletteFor(screenName)`.
2. **Role derivation: `modules/common/ThemeSet.qml`.**
   - `pal` comes from the active palette. Every role is computed from `pal` and the mode, for example
     `surface = dark ? Qt.lighter(pal.deep, 1.18) : "#ffffff"` and
     `line = dark ? colBorder : Qt.tint(white, colBorder @ 0.42)`.
   - It also has a parallel "classic panel" set (`pSurface`, `pInk`, `pLine`, …). The phone uses those, and they
     switch to white panels in the first dark mode.
3. **Access: `Theme.qml`** is a singleton `ThemeSet`. Every component does
   `readonly property var mt: Theme.of(QsWindow.window)` (or `Theme.of(screen)` in a PanelWindow), then
   `color: mt.pInk` and similar.
4. **Other fixed palettes:** `ScrapbookTheme` (paper, cork, film), `LockPalette`, `PadPalette`.
5. **Side effects:** see section 1, finding 4. ThemeService and AppThemeService push the theme into
   system/toolkit files and apps.

### 4.2 Most-read roles in milestone dirs

Counted over phone, quickPanel, launcher, settings, desktopWidgets, bar, mediaControls, onScreenDisplay,
notificationPopup and common/widgets:

`fontFamily` 410 · `colBorder` 280 · `of()` 269 · `fontStyleBold` 220 · `pInk` 177 · `accentMint` 161 ·
`accentCyan` 137 · `pInkSub` 125 · `pLine` 117 · `shadowOffset` 74 · `ink` 74 · `pSurface` 71 · `chipInk` 67 ·
`pSurfaceHover` 61 · `borderWidth` 60 · `chipFill` 52 · `line` 49 · `quickFlat` 33 · `inkSub` 29 ·
`pLineShadow` 27 · `surfaceHover` 26 · `dark` 26 · `attributeColors` 26 · `pSurfaceDivider` 24 · `textWhite` 23 ·
`pillHeight` 20 · `phoneScreenInset` 20 · `surface` 18 · `radiusOuter` 18 · `radiusBadge` 18 ·
`outerRingWidth` 18 · `whiteLine` 16 · `pSurfaceRing` 16 · `fontSizeInfo` 16 · `classicFor` 14 ·
`ringWhite` 10 · `cardRing` 8 · `pRingWhite` 7 · `scrim` 5 · `phone*` 1-2 each.

### 4.3 Hard-coded colours

Counts are of `"#rrggbb"`-style literals, `Qt.rgba(` calls and the named `"white"`, `"black"` and
`"transparent"`. Many `Qt.rgba` calls are derived from tokens (`Qt.rgba(colBorder.r, …, a)`), so only a few
of them are truly hard-coded.

| Directory | `"#hex"` | `Qt.rgba(` | named |
|---|---|---|---|
| `services/` | 135 (ThemeService 116, AppThemeService 13, PaletteService 5) | 2 | 2 |
| `modules/common/` (top level) | 64 (ThemeSet 34, ScrapbookTheme 29, PadPalette 1) | 15 | – |
| `modules/common/functions/` | 95 (PaletteMath, Extras, NotesMath, WallhavenMath: palette, demo and brand data) | 0 | 3 |
| `modules/common/widgets/` | 17 | 6 | 13 |
| `modules/sekai/bar/` | 44 | 25 | 14 |
| `modules/sekai/desktopWidgets/` | 33 | 25 | 31 |
| `modules/sekai/launcher/` | 25 | 14 | 6 |
| `modules/sekai/quickPanel/` | 14 | 15 | 30 |
| `modules/sekai/settings/` | 5 | 7 | 10 |
| `modules/sekai/phone/` | 0 | 3 | 2 |
| `modules/sekai/mediaControls/` | 2 | 2 | 0 |
| `modules/sekai/onScreenDisplay/` | 4 | 1 | 1 |
| `modules/sekai/notificationPopup/` | 4 | 7 | 3 |
| `modules/sekai/lock/` | 1 | 4 | 19 |
| (out of scope) welcome 23/33, equalizer 27/9, visualizer 18/9, dock 16/22, editMode 17/0, cheatSheet 16/0, wallpaperSelector 11/6, overview 6/0 | | | |

**Main offenders:**

- **The white or cream ring and paper tones.** These live in ThemeSet:
  - `colBg` / `textWhite` / light `surface` = `#ffffff`.
  - `ringWhite` (pure white, or white tinted 8 % with border).
  - `pRingWhite` forced to `#ffffff` in classic mode.
  - `colOuterRing` / `surfaceRing` = `#d9d9d9` (the pale ring on the bar and dock housing).
  - `paper` / `paperHover` / `paperEdge` = `#f5f1e6` / `#ece6d4` / `#e4dcc6` (the warm cream of the launcher
    and overview).
  - `ScrapbookTheme.page` = `#f5eeda` ("cream paper").
- **Hard shadows.**
  - `lineShadow` is derived (`Qt.darker(border, 1.3 / 1.8)` or a 30 % tint). It is drawn as an offset copy:
    `Pill.shadowDy = shadowOffset (4)`, `PhonePlate.shadow 4`, `SekaiKey`. The *offset* is a metric, the
    *colour* is a token.
  - The soft phone shadow is `Qt.rgba(0,0,0,0.17)` on a black 9-slice PNG (`PhoneBody.qml:115`).
- **Hard-coded Virtual Singer navy `#555473`.** `ShellBadge.qml:32`, `AppPlaceholder.qml:37`, and `WebCard`'s
  SekaiPop chip.
- **SEKAI attribute pastels** `#8EE3EF #FF9ECB #FFE066 #B39DDB #A5E6A5`. They appear in
  `ThemeSet.attributeColors`, OSDIndicator 73-74, BatteryPopup 56, ResourcePopup 52, WeatherPopup and
  WeatherCard 640/1263, and `NotifyKinds.js`.
- **Status colours, repeated by hand.**
  - Red: `#e0575b` (about 15 places), `#c0392b` (3 dialogs), `#c93a40` / `#ff8a92`, `#ff5c7a`, `#ff6f78`,
    `#ff6f91`, `#ed4245` (Discord), `#ff7a8c`.
  - Orange: `#f0a030`, `#ffc266`, `#ff9f1c`, `#ffb74d`.
- **White ink on images** (banner and LCD): QuickPanelFace 445/447/1057, LauncherFace 291/292/580/714.
- **Night light kelvin ramp:** `#dcecff #ffe3b8 #ff9a3c` (NightLightDialog 198-200). It is physical, so it may stay
  fixed.

### 4.4 Proposed minimal token set (our tokens JSON)

Recommendation:
- Feed **resolved role tokens** (no derivation maths in the shell).
- Keep a thin `Theme`/`ThemeSet` adapter that exposes SekaiPop's old property names, so the 1000+ `mt.*` reads in
  harvested files need no edit.
- Drop "classic" and alias each `p*` role to its plain role.
- Rename later.

```json
{
  "mode": "dark",                       // ThemeSet.dark (26 reads); "darker" is gone
  "color": {
    "accent":        "#…",  // accentCyan  (first stop of every lit gradient)
    "accent2":       "#…",  // accentMint  (second stop)
    "outline":       "#…",  // colBorder   (strong outline, ink in light mode, phone rim)
    "line":          "#…",  // line / pLine (outer border of pills and cards)
    "shadow":        "#…",  // lineShadow / pLineShadow (hard offset shadow colour)
    "surface":       "#…",  // surface / pSurface / phone screen
    "surfaceHover":  "#…",  // surfaceHover / pSurfaceHover / colHover
    "surfaceDivider":"#…",  // surfaceDivider / pSurfaceDivider / colDivider
    "surfaceRing":   "#…",  // surfaceRing / pSurfaceRing / colOuterRing (housing ring)
    "ring":          "#…",  // ringWhite / pRingWhite (gap ring inside a Pill: the old white/cream ring)
    "ink":           "#…",  // ink / pInk
    "inkMuted":      "#…",  // inkSub / pInkSub / colSubText
    "onAccent":      "#…",  // textWhite (text on accent fills and over pictures)
    "chip":          "#…",  // chipFill
    "onChip":        "#…",  // chipInk
    "scrim":         "#…",  // scrim / colDeep
    "hoverTint":     "#…",  // surfaceTint / colHoverTint
    "paper":         "#…",  // paper (+ derive paperHover/paperEdge, or add them)
    "danger":        "#…",  // every red listed above
    "warning":       "#…",  // every orange listed above
    "series":        ["#…","#…","#…","#…","#…"]   // attributeColors, OSD muted/over, tier fills, workspace dots
  },
  "phone": {
    "rimHighlight": "#…", "bezel": "#…", "wallLight": "#…", "wallMid": "#…", "wallDark": "#…",
    "hardware": "#…", "lens": "#…", "lensGlint": "#…", "shadowAlpha": 0.17
  },
  "metric": {
    "borderWidth": 3, "ringWidth": 8, "whiteLine": 2, "cardRing": 3, "shadowOffset": 4,
    "radiusOuter": 13, "radiusBadge": 15, "pillHeight": 36, "outerRingWidth": 4,
    "phoneRimWidth": 10, "phoneBezelWidth": 9, "phoneCornerRadius": 100
  },
  "font": { "family": "…", "styleBold": "ExtraBold", "size": 16, "icon": "Material Symbols Rounded" }
}
```

That is 21 colour roles, 9 phone roles and about 12 metrics. Load it with a `FileView` and `watchChanges: true` from
`~/.config/quickshell/<shell>/tokens.json` (or a generated `~/.cache/<shell>/tokens.json`). Our own pipeline can
fill it from Noctalia's or matugen's palette **without the shell writing anywhere else**. Missing keys fall back
to built-in neutral defaults.

---

## 5. How the phone works

### 5.1 Geometry and maths (`PhoneMath.js`, `PhoneBody.qml`)

- **Design frame.**
  - Portrait face: 654 × 1214 design units, `cornerRadius 100`, `thickness 92`.
  - The landscape Settings design is about 1440 × 760. `FlipMath.SIZE_RATIO = 1.16`, the smaller of 1440/1214
    and 760/654.
- **Coordinates.** x right, y down, z toward the viewer. The front face is at z = 0 and the body runs back to
  z = −T.
- **Matrix pipeline.** Matrices are row-major arrays of 16, applied to column vectors (the same layout as
  `Qt.matrix4x4`).
  - `core = persp(d) · rotY(−yaw) · rotX(pitch) · rotZ(roll) · trans(−W/2, −H/2, T/2)`.
  - `persp(d)` is `w = 1 − z/d`, with camera distance `perspective = 3400`.
  - `build()` projects the front (z = 0) and back (z = −T) rounded outlines (9 points per corner) to get the
    on-screen bounds. Then `base = flatZ · trans(−minX + pad, −minY + pad) · core`.
  - `flatZ` zeroes z after projection, because Qt Quick clips against a very shallow depth range. Draw order
    is painting order.
  - `baseFor()` reuses the resting offsets, so an animated pose turns about the same spot without
    resizing.
  - `boundsFor()` and `swing` work out how far a tilted pose sticks out, so the window can be made big enough
    up front.
- **Default pose.** `yaw 33°, pitch 18°, roll 0`. On top of that come `yawOffset` / `pitchOffset` /
  `rollOffset` (animation only, never resizes) and `turnRoll` (the Settings turn, enlarges only the render
  texture).
- **Body = stacked slices.** No 3D model. Each layer is a `Matrix4x4 { matrix: … }` transform with
  `PM.mul(drawBase, local)`:
  - the front face;
  - `sliceCount` copies of the rounded rect pushed back in z (fine slices about every 0.5 px on screen, up to
    200; coarse = T/3, at least 8), coloured by `wallColor(s)` with
    `PM.ramp([0 mid, 0.05 light (specular), 0.20 mid, 1 dark])`;
  - side buttons (7 slices each), the notch and lens, and bottom holes.

  `PM.zOffset()` is the hot-path shortcut for `mul(m, trans(0,0,z))`. Input maps correctly because every layer
  shares one matrix and Qt maps pointer events through transforms.
- **Quality and memory.**
  - The scene renders into a layer with `superSample 2` and MSAA (`restSamples 4`, `moveSamples 2`,
    `turnSamples 2`). Megapixel caps: 10 at rest, 8 moving, 2.5 turning (`turnLite`).
  - The face content has its own layer (`contentSS`, `contentSamples`).
  - `faceDirect` (2D) draws the face straight to device pixels with pixel snapping, which keeps text sharp.
  - `warm` / `coolDelay 20 s` keeps the layers allocated between quick reopenings. `PanelActivity.busy` is
    bookkeeping only.
- **Soft shadow.** One 9-slice `BorderImage` (`assets/images/phone-shadow.png`, 282 × 282) on the back-face plane,
  `shadowDx 3`, `shadowDy 12`, alpha 0.17. No blur or shader.
- **Click-away outline.** `PM.silhouette()` builds the convex hull of the front and back outlines plus the button
  boxes. `PhoneBody.outlinePoly` holds it, and `PM.insideConvex(poly, x, y, slack=3)` tests a point.
  QuickPanel's `besidePhone` MouseArea uses it, so clicks in the empty corners of a tilted phone's box close
  the panel (docs/PHONE-CLICK-AWAY.md).
- **Variants.**
  - `landscape: true`: the same body turned a quarter turn. The camera cut-out is on the left edge and the ports
    are on the right wall. No side buttons.
  - `flat` / `plain`: 2D, no wall.
  - `powerButton`: the live side button, drawn flat in 2D.
  - `Theme.quickFlat` (setting `quick.flat`, or game mode) forces 2D.

### 5.2 Portrait to landscape (Quick Panel to Settings or Wallpapers)

- `QuickPanel.qml` holds **both** bodies in one window: `PhoneBody` (portrait) and `SettingsStage`
  (`PhoneBody{landscape}`). The window size is computed once to fit the whole turn (`flipRoom`), because
  resizing a layer-shell window mid-animation stutters.
- `stage.flip` p goes 0 → 1, animated by `flipAnim`: `flipMs 200`, `Easing.BezierSpline [0.30, 0.0, 0.20, 1.0]`.
  - `FlipMath.quickRoll(p) = −90p` and `settingsRoll(p) = 90(1 − p)`. Both bodies show the same picture at
    every moment.
  - `quickScale` goes from the quick fit to `SIZE_RATIO × settings fit` and dips by `flipDip 0.12 × sin(πp)`.
  - Positions lerp from the Quick rest centre to the monitor middle (`setMidX`/`setMidY`).
  - The screens cross-fade in wide p-windows (`quickAlpha`, settings alpha), so the phone is never see-through.
- After landing, the roll "ring" wobbles 2.5° over `flipRingMs 380` (InOutSine steps). `ringKeepsLite` holds the
  light render settings until the ring is over.
- The Settings can also open without the turn: `ipc call settings show`.
  - In (`settingsEnter`): `sPop` 0 → 1 over 560 ms (OutBack, overshoot 1.5), `sTilt` → 0 over 900 ms
    (OutElastic, amplitude 1, period 0.45), `sAlpha` over 140 ms (OutQuad).
  - Out (`settingsExit`): `sPop` → 0 over 340 ms (InOutCubic), `sAlpha` over 290 ms (InOutQuad), `sTilt` → 0.8
    over 340 ms (InOutQuad).
- Quick ↔ Apps is not a turn. It is a short vertical slide, `routeK` 0 → 1 over `routeMs 200` with Bezier
  `[0.40, 0, 0.20, 1]`.

### 5.3 Rise from the bottom (pull out of the pocket)

`stage.lift` is in px below the rest position (`hiddenLift` means off-screen). `stage.tilt` goes from 1 (in the
pocket) to 0 (upright). The pocket pose adds `tiltYaw −6°`, `tiltPitch 10°` and `tiltRoll 12°` multiplied by
`tilt`; it is 0 in 2D.

| Phase | Animation |
|---|---|
| Enter (`enterAnim`) | `lift` → `−bounce` (34 px) over 340 ms OutCubic; → 0 over 170 ms InOutSine; → `−bounce×0.14` over 110 ms OutQuad; → 0 over 110 ms InQuad. In parallel, `tilt` → 0 over 820 ms OutElastic (amplitude 1, period 0.4). |
| Enter, keyboard-launched Apps (`launching`) | `lift` → 0 over 340 ms and `tilt` over 460 ms, both Bezier `[0.32, 0.72, 0, 1]` |
| Exit (`exitAnim`) | `lift` → `exitPeak` (−0.7 × bounce, 130 ms OutQuad), then → `hiddenLift` over 340 ms InCubic (launching: 300 ms Bezier `[0.5, 0, 0.7, 0.35]`). `tilt` → 1 over 440 ms InQuad. |
| Peek | Only `panel.peek` % of the phone height shows (`peekEff` is ×1.10 in 2D). The rest stays below the edge. |
| Alert peek | A new notification raises the phone only to `alertLift` (the heads-up card shows), with no grab and no keyboard. `stage.rise` has a 320 ms OutCubic Behavior. A buzz shakes it sideways (`buzzAmount`, `buzzHz`, `buzzPulses` …). Clicking it, or resting the pointer on it for 1 s, opens the full panel. Swipe-down or middle-click lowers it. Right-click also removes the notification. |
| Bleed | The window extends `bleed` (max(24, 4 % of the shown height)) past the bottom edge, with a negative `margins.bottom`. That hides the compositor's own layer-open overshoot. |

### 5.4 What drives it (state)

- `PhoneRoute.js`: an immutable stack `{stack: [...]}` over `quick | apps | wallpapers | settings`.
  - Functions: `open(entry)`, `go(name)` (going to a lower screen pops back to it), `back()` → `{state, closed}`,
    `home()`, `byNumber(1..4)` (Ctrl+1..4), `startsSearch()` (typing a printable character on Quick opens Apps).
  - Tested by `tests/route-test/route_unit.js`.
- QuickPanel state:
  - `open` / `alertUp` / `alertMode` / `up`;
  - `phoneRoute`, `faceScreen` (quick or apps), `routeK`;
  - `settingsOpen` + `landscape` ("settings" or "wallpapers");
  - `launching`, `turningBack`, `coverCheat`, `targetScreen`.
- One IPC target `phone` with `toggle | show | hide | go <screen> | back | home`. Legacy targets: `quickpanel`,
  `launcherphone`, `settings`, `wallpaperpicker`.

### 5.5 Window it lives in

`QuickPanel.qml:1778-1860`:

- `PanelWindow win` on `targetScreen`, `anchors.bottom` only (centred), `color "transparent"`,
  `exclusionMode Ignore`, `WlrLayershell.namespace "sekaipop-quickpanel"`.
- `margins.bottom: −bleed`.
- Layer: `WlrLayer.Overlay` while the bar is on the bottom, Settings are shown, the Apps catcher is up, the
  cheat sheet is covered or Edit Desktop is on. `WlrLayer.Top` otherwise.
- Keyboard:
  - `Exclusive` when opened on Apps by keyboard (the search must type at once);
  - `OnDemand` while the Wi-Fi password field, Settings, turning back or `phoneKeysWanted` (type-to-search) is
    active;
  - `None` otherwise.
- `mask: Region { item: hitRect; Region { item: railHost } Region { item: setHit } }`: only the visible phone, the
  power rail and the Settings rectangle take input.
- Click-away:
  - **Quick and Settings:** `HyprlandFocusGrab` on `[win] + barWindows`.
  - **Apps:** `catcher`, a full-screen transparent PanelWindow on `Top` under the Overlay phone, plus the
    in-window `awayArea`.
  - `besidePhone` (z −100) covers the tilted-box corners.
- Hot edge: one PanelWindow per screen, 360 × 4 px at the bottom centre, opening after `panel.hotDwell`.

For niri: use `catcher` in all modes, on the target output only.

---

## 6. Pop and swallow animations

There is **no shared helper**. The pattern is copy-pasted. It is a `reveal` real (0 = away, 1 = shown) driven by
two *fixed* `NumberAnimation`s started from an `onWantChanged` / `onOpenChanged` handler. The comment explains
why: a Behavior whose easing depends on the same flag can start with the previous direction's easing.

`reveal` drives:

```
transform: Scale { origin: <button or card anchor>; xScale: max(0, reveal); yScale: max(0, reveal) }
```

It also drives opacity: `min(1, reveal × 8)` on the way in and 1 on the way out (whole until it is gone). The
window stays mapped while `reveal > 0.001` (`live`). An `armed` timer (800 ms after load) stops a reload from
replaying the pop.

| Where | Pop in | Swallow out |
|---|---|---|
| Desktop widgets: Clock, Todo, Calendar, Weather, UserCard, Palette, Image, StickyNotes, PluginWidgetHost, Visualizer | 460 ms `OutBack`, overshoot 1.9 | 300 ms `InCubic` |
| LyricsWidget | 520 ms `OutBack`, overshoot 1.6 | 360 ms `InCubic` |
| `bar/SekaiPopup.qml` (Calendar, Battery, Weather, Media, Discord popups) | 340 ms `OutBack`, overshoot 1.3, grows out of its button | 170 ms `InCubic`, then `settle()` holds the empty window a few frames. `PopupHandoff.serial` snaps an outgoing popup away when another opens. |
| `common/widgets/ScalePopup.qml` | opacity 120 ms | – |
| Quick Panel phone | section 5.3 | |
| Settings standalone | `sPop` 560 ms OutBack 1.5 + `sTilt` 900 ms OutElastic | 340 ms InOutCubic |
| Key press (`SekaiKey`, `PhoneBody` power button) | down 70-80 ms OutQuad | up 190-260 ms `OutBack`, overshoot 2-2.2 |
| `QuickToggle` on/off | 170 ms OutCubic | |
| `PhoneCard` (launcher cards) | 200 ms OutCubic fade plus a 12 px rise | |
| `Burst.qml` (sparkle) | 600 ms OutCubic | |
| `PresetMotion` (bar and dock off-edge) | `outMs 190`, `inMs 380` | |

**Port recommendation.** Extract one `PopReveal.qml` (QtObject with `want`, `reveal`, `live`, `armed`,
`popMs = 460`, `overshoot = 1.9`, `swallowMs = 300`) and one `PopScale` transform. Use them in every widget and
popup.

---

## 7. Settings persistence, and every write outside the allowed directories

- **SettingsService**: one JSON object with only the values that differ from `defaults` (about 167 keys). Saved by `sh scripts/state/settings-state.sh save <json>` (tmp file, then mv) to
  `${XDG_CONFIG_HOME:-~/.config}/sekaipop/settings.json`. Loaded once at start. IPC `options get|set|reset`.
  `set()` ignores unknown keys; a test (`tests/settings-test/keys_have_defaults_test.js`) guards this.
- **Per-service state**: about 23 `scripts/state/*.sh` helpers write `${XDG_STATE_HOME:-~/.local/state}/sekaipop/`
  (theme, dark, darker, wallpaper, todo.json, clock, calendarcard, weathercard, usercard, visualizer, lyrics,
  notes, palette, qp-tiles, nightlight, keep-awake, monitors, clones, edit, extras, recent-emoji, welcome, presets
  …). In QML: `NotificationSource` and `TraySource` (`stateDir`), `EqualizerService` (`…/eq`).
- **`~/.config/sekaipop/`**: settings.json, scale.json, presets/, plugins/, update-repo, update-url,
  vscode-colors.json.
- **`~/.local/share/sekaipop/`**: avatar, banner and phone pictures (`pick-image.sh`), custom images.
- **`~/.cache/sekaipop/`**: matugen/*.json, lyrics/, cover-art/, nonotify/ (a notify-send stub), update-seen,
  thumbnails.
- **`$HOME` outside the allowed dirs (forbidden for us):**
  - `~/Pictures/Wallpapers` (default wallpaper seed, Wallhaven downloads);
  - `~/Pictures/Screenshots` (snip tile, region);
  - `~/.config/{kdeglobals, gtk-3.0, gtk-4.0, qt5ct, qt6ct, kitty, foot, fuzzel, rofi, fish/conf.d, Vencord, vesktop, Equicord, easyeffects, hypr, kcminputrc, matugen?}`;
  - `~/.local/share/{color-schemes, themes, icons}`, `~/.icons/default/index.theme`;
  - `~/.bashrc`, `~/.zshrc` (prompt);
  - gsettings/dconf (`org.gnome.desktop.interface color-scheme`, gtk-theme, cursor);
  - `/etc/resolv.conf` via pkexec (WARP).

**Target for our port.** User settings and tokens go in `~/.config/quickshell/<shell>/settings.json` and
`tokens.json`. Everything stateful (widget positions, todo, notification history, qp tiles, night light) goes in
`~/.cache/<shell>/`. If losing it on a cache wipe is a problem, use `~/.config/quickshell/<shell>/state/`.
Screenshots and wallpapers stay out of milestone 1.

---

## 8. The plugin system and its security implications

- Plugins are folders in `${XDG_CONFIG_HOME}/sekaipop/plugins/<id>/` holding `plugin.json` + `Widget.qml` (any
  other QML and images are allowed). `PluginService` scans them through `plugin-state.sh scan`, validates the
  manifest (`PluginManifest.js`, the plugin API version) and builds a `PluginWidgetHost` window for each. The
  plugin gets a `host` object: theme, settings, secrets, `path()`, `reloadSecrets()`.
- **Trust model (docs/PLUGINS.md:11-13):** "A plugin's QML runs with the shell's full rights: it can run programs
  and read your files … The shell does not sandbox plugins."
  - A plugin can `import Quickshell` and `Quickshell.Io`, so it can `Process` anything and read or write any file
    the user can.
  - The only restriction is that `qs.*` modules do not resolve outside the shell folder. That keeps the API
    stable; it is not a security boundary.
- **Secrets.** A manifest names `secrets: { name: { env, file } }`. The shell reads **any environment variable**
  and **any file path** (`~/` expanded) the manifest asks for, through `plugin-state.sh secret <path>`, which just
  runs `cat "$2"`. A malicious manifest can therefore get the shell to read and hand it `~/.ssh/id_ed25519` or
  `$SSH_AUTH_SOCK`. It could do the same with its own `Process`, so this adds no new power, but it is a second
  path to watch.
- Plugins are never downloaded automatically, and the README says not to install untrusted ones.
- **Verdict: LEAVE for milestone 1.** If ever wanted:
  - load plugins only from a repo-controlled directory;
  - pin them by hash;
  - put no secret-file reading in the shell;
  - document that a plugin is equivalent to running a shell script.

---

## 9. Test setup (`sekaipop/tests/`)

- **Runtime: plain Node.js (`node <file>`)**, run from the `sekaipop/` folder. There is no framework, no
  package.json and no single runner.
  - 90 JS test files and 7 `.sh` tests (`update_check_test.sh`, `migrate_test.sh`, `plugin_state_test.sh`,
    `shrink_test.sh`, …).
  - 7 Python files: `analyzer-test/` (needs numpy plus a fake `aubio`), `cursor-test/win_cursor_test.py`,
    `perf-test/*`, `lock-transition-test/shader-sim/`.
  - `analyzer-test/run-tests.sh` is the only runner script.
- **Two styles.**
  1. **Unit tests of the `.pragma library` JS.** The file is read, `.pragma library` is stripped, and it is
     evaluated with `new Function(src + "; return {…}")`. Assertions use `assert` or a tiny `eq()`. Examples:
     `route-test`, `niri-test`, `phone-test/click_away_test.js` (runs the PhoneMath silhouette for the 2.5D and
     2D poses), `matugen-test`, `weather-api-test`, `lyrics-test`, `calendar-test`.
  2. **"Source" tests that grep the QML text** to check wiring. Examples: `keys_have_defaults_test.js` (every
     `SettingsService.get/flag/set` key has a default), `qml-names-test`, `size_wiring_test.js`.

  `tests/lib/locate.js` finds a file by path or by unique basename. `tests/lib/registry.js` evaluates the real
  widget list from `PresetWidgets.qml` against fakes.
- **State at the tip** (DEVLOG top entry): "81 pass, the same 9 fail" for the JS tests. The tip ships with **9
  known failing tests**; not listed by name in the DEVLOG.
- No QML runtime tests (no `qmltestrunner`). DEVLOG entries rely on `qmllint` and live checks.
- **Directly reusable for our milestone 1:**
  - `tests/route-test/route_unit.js` (PhoneRoute);
  - `tests/niri-test/niri_unit.js` (NiriMath);
  - `tests/phone-test/click_away_test.js` (PhoneMath silhouette);
  - `tests/weather-api-test/open_meteo_unit.js`, `tests/weather-card-test/style_unit.js`;
  - `tests/calendar-test/events_unit.js`, `tests/lyrics-test/{lyrics_unit,cache_unit}.js`,
    `tests/media-test/media_unit.js`.

  Copy them together with the JS they test and run them with `node` from our tests (our repo has
  `tests/run-all.sh`).

---

## 10. External programs and network (milestone-1 scope)

| Feature | Programs | Network |
|---|---|---|
| Wi-Fi | `nmcli` (status, radio, connection up/down, device list) | – |
| Bluetooth | `bluetoothctl` (power, connect, disconnect, devices) | – |
| Volume and mic | Pipewire via `Quickshell.Services.Pipewire` (OSD, privacy); `wpctl` + `pactl` (QuickSource: set volume, mute, default sink and source, `pactl subscribe` for key changes) | – |
| Brightness | `brightnessctl g/m/s` (laptop), `ddcutil detect/getvcp/setvcp 10` (external monitors) | – |
| Night light and gamma | `hyprsunset` + `hyprctl hyprsunset …` (**replace** with wlsunset or gammastep) | – |
| Keep awake | `systemd-inhibit` | – |
| Power | `systemctl`/`loginctl` poweroff, reboot, suspend, hibernate, firmware-setup; logout via `session-logout.sh` (**replace**) | – |
| Notifications | Quickshell `NotificationServer` (D-Bus); `notify-send` for the shell's own messages | – |
| Media | MPRIS via Quickshell (no playerctl) | `https://i.ytimg.com/vi/<id>/…` cover art for YouTube tabs |
| Weather | `curl -s -m 10` | `api.open-meteo.com/v1/forecast`, `geocoding-api.open-meteo.com/v1/search`, `ipwho.is` (**IP geolocation when no city is set**: set a city to avoid it) |
| Lyrics | `curl` | All asked **at once**: `lyrics-api.boidu.dev` / `api.betterlyrics.org`, `lyricsplus.prjktla.workers.dev`, `lrclib.net/api`, `music.youtube.com/youtubei/v1`, `api-lyrics.simpmusic.org`, `music.163.com/api` (NetEase), `c.y.qq.com` (QQ Music), `lyrics.kugou.com` / `mobileservice.kugou.com`. Sends artist, title, album, length and maybe the YouTube video id. **Default to LRCLIB only.** |
| Launcher web card | `curl` | `duckduckgo.com/ac/` suggestions as you type (LATER; make it opt-in) |
| Bar status pill | `status-icons.sh` → `nmcli`, `bluetoothctl` | – |
| Not ported | `matugen`, `cava`, `easyeffects`, `warp-cli` + `pkexec`, `grim`/`slurp`/`hyprpicker`/`wtype`, `songrec`+`ffmpeg`, `mpvpaper`, ImageMagick, kdialog/zenity/yad, python Discord bridge, `git` (self-update), `checkupdates` | `wallhaven.cc/api/v1`, GitHub (updates), Discord CDN |

---

## 11. Prioritized port list for milestone 1 (in order)

This assumes the new shell lives at `~/.config/quickshell/<shell>/` with our own `shell.qml`. Each step
compiles and runs before the next. Paths are SekaiPop paths; rename `Sekai*` as you go.

**Stage A: foundations (pure JS and singletons, test-first with the upstream node tests)**
1. `modules/common/functions/PhoneMath.js` (TAKE) with `tests/phone-test/click_away_test.js`
2. `modules/common/functions/FlipMath.js` (TAKE)
3. `modules/sekai/quickPanel/PhoneRoute.js` (TAKE) with `tests/route-test/route_unit.js`
4. `modules/common/functions/NiriMath.js` (TAKE + extend: focused output, windows, keyboard layouts) with
   `tests/niri-test/niri_unit.js`
5. `services/NiriWorkspaces.qml` (TAKE + extend: `focusedOutput()`, `SwitchLayout`)
6. `modules/common/Directories.qml` (TAKE)
7. **New** `services/Tokens.qml` + `modules/common/ThemeSet.qml` → token adapter (ADAPT; old property names kept,
   section 4.4)
8. `modules/common/Theme.qml` (ADAPT: `of()` returns the single theme)
9. `services/SettingsService.qml` (ADAPT: FileView/JsonAdapter at `~/.config/quickshell/<shell>/settings.json`;
   pruned defaults with no systemTheme or appTheme)
10. `services/ShellScale.qml` (ADAPT: niri focused output; `~/.config/quickshell/<shell>/scale.json`)
11. Stubs: `EditMode` (`active: false`), `GameModeService` (`enabled: false`), `PresetMotion` (all false),
    `WallpaperService` (`ready: true`, `restacking: false`)

**Stage B: shared widgets**

12. `modules/common/widgets/ScaleHost.qml`, `Slant.qml`, `RoundClip.qml`, `WheelScroll.qml`, `InnerRing.qml`
    (TAKE)
13. `modules/common/widgets/Pill.qml` (ADAPT: tokens; drop capsule and classic unless needed)
14. `modules/common/widgets/MaterialIcon.qml` + `functions/IconMap.js` (ADAPT: decide on the icons; the Solar
    SVGs are not in the download)
15. `modules/sekai/phone/PanelActivity.qml`, `PhonePlate.qml`, `PhoneKey.qml`, `PhoneCard.qml` (TAKE)
16. `modules/sekai/phone/SekaiKey.qml` → `LeanKey.qml`, and `SekaiNavKey.qml` (ADAPT)

**Stage C: the phone and the Quick Panel**

17. `modules/sekai/phone/PhoneBody.qml` + `assets/images/phone-shadow.png` (ADAPT: tokens). Prove it with a demo
    window before going on.
18. `modules/sekai/quickPanel/QuickToggle.qml`, `VolumeSlider.qml`, `GammaBrightnessSlider.qml` (TAKE / ADAPT)
19. `modules/common/functions/QuickTiles.js` (ADAPT: trimmed tile catalogue)
20. `services/QuickSource.qml` (ADAPT: nmcli, bluetoothctl, wpctl/pactl, brightnessctl/ddcutil, wlsunset or
    gammastep, systemd-inhibit, power through niri. Remove WARP/pkexec, game mode, anti-flashbang, EasyEffects
    and songrec. State goes to `~/.cache`.)
21. `modules/sekai/quickPanel/NetworkDialog.qml`, `BluetoothDialog.qml`, `VolumeMixerDialog.qml`,
    `NightLightDialog.qml` (ADAPT: `danger`/`warning` tokens)
22. `services/NotificationSource.qml` (ADAPT: niri focused output, history in `~/.cache`, D-Bus ownership
    decided against Noctalia) + `modules/sekai/quickPanel/NotificationCard.qml` +
    `modules/common/widgets/ShellBadge.qml` + `functions/NotifyKinds.js` (to `series[]`)
23. `modules/sekai/quickPanel/PowerMenu.qml`, `PowerMenuScrim.qml` (ADAPT)
24. `modules/sekai/quickPanel/QuickPanelFace.qml` (ADAPT: trimmed tiles, tokens; banner and avatar optional)
25. `modules/sekai/quickPanel/QuickPanel.qml` (ADAPT: catcher instead of HyprlandFocusGrab, niri
    `focusedScreen()`, no GlobalShortcut or hyprctl, IPC `phone`)

**Stage D: the Settings phone (landscape) and the launcher phone**

26. `modules/sekai/settings/SettingsStage.qml` (ADAPT: no Wallpapers in milestone 1)
27. `modules/common/widgets/SekaiBackdrop.qml`, `SearchPill.qml`, `SettingRoundButton.qml`, `DotField.qml`,
    `SegmentSwitch.qml` (ADAPT / TAKE)
28. `modules/sekai/quickPanel/SekaiTile.qml`, `SekaiHubTile.qml`, `ScreenGlyph.qml` (ADAPT)
29. `modules/sekai/settings/SettingsPage.qml`, `SectionCard.qml`, `SettingToggle.qml`, `SettingAction.qml`,
    `SettingStepper.qml`, `SettingChoice.qml`, `SettingChip.qml`, `SettingSlider.qml`, `SettingText.qml` (TAKE)
30. `modules/sekai/settings/SettingsFace.qml` + `SettingsPageQuick.qml`, `SettingsPageGeneral.qml`,
    `SettingsPageBar.qml` (ADAPT) + a **new** niri page replacing `SettingsPageHyprland.qml`
31. `services/AppSource.qml` (ADAPT) + `modules/sekai/launcher/LauncherFace.qml`, `AppResultRow.qml`,
    `AppPlaceholder.qml`, `LauncherLcd.qml` (ADAPT)

**Stage E: the bar**

32. `services/PopupHandoff.qml` (TAKE) + `modules/sekai/bar/SekaiPopup.qml` (ADAPT: catcher; extract
    `PopReveal`)
33. `modules/sekai/bar/Bar.qml` (ADAPT: niri-only paths, token gap, ToplevelManager title, niri keyboard layout)
    + `Status_Bar.qml` (one style) + `WorkspaceBadges.qml` (TAKE)
34. `services/BarPositionService.qml`, `BarStyleService.qml` (ADAPT: paths) +
    `modules/sekai/bar/DateIndicator.qml`, `CalendarPopup.qml`, `CalendarMath.js`, `NotificationBadge.qml`,
    `StatusPill.qml` + `services/StatusIconsService.qml` + `scripts/system/status-icons.sh` (TAKE / ADAPT)
35. `services/MediaSource.qml` (TAKE) + `modules/sekai/bar/MediaPill.qml` +
    `modules/sekai/mediaControls/MediaPopup.qml`, `MediaKey.qml`, `MediaTab.qml`, `MediaMath.js`,
    `MediaOwner.js` (ADAPT: ToplevelManager)

**Stage F: desktop widgets** (strip EditChrome and WidgetClones; fixed positions from settings first)

36. `modules/sekai/desktopWidgets/FocusGate.qml` (stub or niri-fed), `KeysOnPoint.qml` (TAKE)
37. `services/ClockService.qml` (ADAPT: path) + `modules/sekai/desktopWidgets/ClockWidget.qml` (ADAPT: one or two
    designs)
38. `services/WeatherSource.qml` + `functions/OpenMeteo.js` + `functions/WeatherMath.js` (TAKE) +
    `services/WeatherCardService.qml` (ADAPT) + `modules/sekai/desktopWidgets/WeatherCardWidget.qml` +
    `modules/common/widgets/WeatherGlyph.qml`, `SekaiPlate.qml`, `StickerText.qml`, `Burst.qml`, `DiamondDot.qml`
    (ADAPT)
39. `services/CalendarCardService.qml` + `functions/EventMath.js` +
    `modules/sekai/desktopWidgets/CalendarCardWidget.qml` (+ `CalendarEventCard`, `CalendarChip`,
    `CalendarField`, `CalendarNavKey`), then `services/TodoService.qml` +
    `modules/sekai/desktopWidgets/TodoWidget.qml` (ADAPT)
40. `services/LyricsService.qml` (ADAPT: LRCLIB-only default, paths in `~/.cache`) + `functions/LyricsMath.js` +
    `modules/sekai/desktopWidgets/LyricsWidget.qml`, `LyricsLine.qml`, `LyricsWord.qml`, `LyricsKey.qml` (ADAPT)

**Do not port:**
- `services/ThemeService.qml`, `services/AppThemeService.qml`, `services/IconCursorService.qml`,
  `scripts/theming/*`;
- every `Hyprland*` service, `SettingsPageHyprland.qml`, `KeyBinds.js`;
- dock, editMode, overview, cheatSheet, welcome, equalizer, visualizer, lock (gacha), plugins, the self-updater,
  and the WARP/pkexec path.
