# niri + Noctalia rice: design spec

Date: 2026-10-24 · Status: approved by the user on 2026-10-24 (decisions: screen share and Discord are required,
so the GNOME portal is used; custom palette "Mizu") · Repo: `AtelierMizumi/dotfiles` (private)

## 1. Intent

What the user asked for:

- A modern, robust Wayland rice on Arch, **without affecting the KDE Plasma session** that stays the daily driver.
- Do **not** hand-design the look. Take an existing, harmonious design that works on one or several monitors, then
  apply a short list of custom modifications.
- Direction (a): quiet, minimal.
- Gaming on the hybrid Intel Iris Xe + RTX 3050 Mobile laptop should not regress versus Plasma by more than the
  NVIDIA driver already costs.

Assumptions (correct me in review):

- Base design = **Noctalia v5 upstream defaults** (`noctalia 5.3.0-1`, `extra`), running on **niri 26.04**.
- The machine has two outputs: `eDP-1` (Intel) and `HDMI-A-1` (NVIDIA). Multi-monitor is a real requirement.
- Only the current user's `$HOME` and explicitly listed packages are touched. No `/etc` edits.

## 2. Non-goals

- No dock, no desktop widgets, no custom shell code, no QML. Both are off by default upstream and stay off.
- No global fontconfig, locale, `environment.d`, `logind.conf`, SDDM or portal-KDE changes.
- No wallpaper-driven theming and no third-party installer (`./setup install`-style scripts).

## 3. Design = upstream defaults + a small overlay

Upstream default layout (from `example.toml`): top bar, `start = launcher, wallpaper, workspaces`,
`center = clock`, `end = media, tray, notifications, clipboard, network, bluetooth, volume, brightness, battery,
control-center, session`. This is kept as is. Bars are spawned on **every** connected output automatically.

Overlay (everything not listed here is an upstream default):

| # | Setting | Value | Source | Status |
|---|---|---|---|---|
| 1 | `[theme] source` / `custom_palette` | `"custom"` / `"Mizu"` (see 3.1) | palette docs; key `custom_palette` exists in `config_schema.cpp` | key verified in source; `source = "custom"` value **unverified** (docs say `custom`, `example.toml` lists `builtin \| wallpaper \| community`) |
| 2 | `[theme] mode` | `"dark"` | `example.toml` | verified |
| 3 | `[theme] sync_color_scheme` | `false` | `config_schema.cpp`, `config_types.h`, `application_services.cpp` | verified: default is `true` and runs `gsettings set org.gnome.desktop.interface color-scheme prefer-dark/light`, a user-wide dconf write that would also hit GTK apps under Plasma |
| 4 | `[theme.templates] enable_builtin_templates`, `enable_community_templates` | `false`, `false` | `example.toml`, templates docs | verified keys. Invariant: **all templates off** (the GTK/Qt, KColorScheme and niri templates write `gtk-*`, `kdeglobals`, `niri/config.kdl`) |
| 5 | `[shell] polkit_agent` | `true` | `example.toml` (default `false`) | key verified. Nothing else starts a polkit agent in a niri session |
| 6 | `[widget.clock] format` | `"{:%-m}月{:%-d}日 {:%a} {:%H:%M}"` | clock + date-format-tokens docs | strftime tokens verified; non-ASCII literals "copied through" per docs but **unverified** |
| 7 | Process locale | `LC_TIME=ja_JP.UTF-8` on the `noctalia` process only | date-format docs (names follow `LC_TIME`); `locale -a` shows `ja_JP.utf8` | verified on this machine. Scoped via niri `spawn-at-startup "env" "LC_TIME=ja_JP.UTF-8" "noctalia"` so Plasma is untouched |
| 8 | Per-monitor bar overrides | none at first | bar docs | If needed later, match by **connector name** (`eDP-1`, `HDMI-A-1`), never by description substring |
| 9 | niri focus ring | 2 px, hex hardcoded `#E2A63B` in `config.kdl` | niri docs | hardcoded on purpose, instead of enabling the niri template |
| 10 | niri gaps / corner radius | gaps 12, `geometry-corner-radius 20`, `clip-to-geometry true` | Noctalia niri page recommends radius 20 | gaps value is our choice |
| 11 | niri startup | remove `spawn-at-startup "waybar"`; replace `Mod+D` (fuzzel is not installed) with `noctalia msg panel-toggle launcher` | niri Getting Started, Noctalia niri page | verified |
| 12 | Settings window rule | floating, 1080x920 for `app-id="dev.noctalia.Noctalia"` | Noctalia niri page | verified |

### 3.1 The "Mizu" palette (modification 1)

No built-in palette matches the intended look. Checked in `src/theme/builtin_palettes.cpp`: Ayu, Catppuccin, Dracula,
Eldritch, Gruvbox, Kanagawa, Noctalia, Nord, Rosé Pine, Tokyo-Night. Kanagawa is near-black purple `#1f1f28` with warm
cream text `#c8c093` and a green primary, so it is **not** an indigo-with-amber scheme. Tokyo-Night is the closest
built-in (blue-black `#1a1b26`, blue primary `#7aa2f7`) and is the fallback if the custom palette is rejected.

To keep hand-building small, "Mizu" copies Tokyo-Night's structure and terminal block and changes only the roles below.
File: `~/.config/noctalia/palettes/Mizu.json`, top-level `dark` object, `light` omitted (dark is used for both).

| Role | Hex | Name | Contrast (WCAG) |
|---|---|---|---|
| `mSurface` | `#182338` | kon 紺 | n/a (base) |
| `mSurfaceVariant` | `#2A3F5F` | ai 藍 | n/a (cards) |
| `mOnSurface` | `#EDF0F3` | gofun 胡粉 | 13.74 on surface, 9.30 on variant |
| `mOnSurfaceVariant` | `#B4BECE` | | 8.38 on surface, 5.67 on variant |
| `mPrimary` | `#E2A63B` | yamabuki 山吹 | 7.30 on surface |
| `mOnPrimary` | `#182338` | | 7.30 on primary |
| `mSecondary` | `#7FB4CA` | mizu 水 | 6.95 on surface |
| `mOnSecondary` | `#182338` | | 6.95 on secondary |
| `mTertiary` / `mOnTertiary` | `#9ECE6A` / `#182338` | from Tokyo-Night | 8.60 |
| `mError` / `mOnError` | `#F7768E` / `#182338` | from Tokyo-Night | 5.94 |
| `mOutline` | `#4A6088` | | 2.48, decorative borders only |
| `mHover` / `mOnHover` | `#3A5078` / `#EDF0F3` | | 7.07 |
| `mShadow` | `#101826` | | n/a |

An earlier draft used `#8591A3` for secondary text. It measured 3.33:1 on `ai` and was replaced.
Terminal `background`/`foreground` are set to `#182338`/`#EDF0F3`; the remaining terminal colors are copied from
Tokyo-Night. Amber appears only as the primary role and the niri focus ring.

## 4. Plasma-safety design

Invariants, each enforced by `scripts/check-plasma-intact.sh`:

1. **No template is enabled**, in the repo config **and** in the GUI override file
   `~/.local/state/noctalia/settings.toml`, which loads last and wins over repo config. A settings-UI toggle could
   otherwise enable the GTK or KColorScheme templates.
2. **`sync_color_scheme` is false** in the merged result, same two files.
3. Shared files are unchanged between a snapshot and a comparison: `kdeglobals`, `kdedefaults/kdeglobals`,
   `mimeapps.list`, `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `xdg-desktop-portal-kderc`, plus the values of
   `gsettings get org.gnome.desktop.interface color-scheme` and `gtk-theme`.
4. Package state: `xdg-desktop-portal-kde`, `plasma-desktop`, `sddm` still installed and `pacman -Qk` reports 0 missing
   files.

Rules:

- Snapshot and compare **inside the niri session, with Plasma not running**. Plasma itself rewrote the gtk files and
  `appletsrc` on 2026-10-24, so comparing across a Plasma session gives false positives. `plasma-org.kde.plasma.desktop-appletsrc`
  is excluded.
- For the package phase the checks are the `pacman` dry-run prompt and invariant 4, not home files.
- Environment variables for the rice go in the niri `environment {}` block only. `QT_QPA_PLATFORMTHEME` is not set
  unless a Qt template is wanted, which it is not.
- niri is installed next to Plasma upstream-supported (niri Getting Started). `niri.desktop` and `plasma.desktop` already
  coexist in `/usr/share/wayland-sessions/`. Session is chosen at SDDM after logging Plasma out.

## 5. Install mechanism

- `stow` (not installed; user installs it with `! sudo pacman -S stow`). One package directory per tool:
  `niri/.config/niri/`, `noctalia/.config/noctalia/`. `stow -n` is the dry run. `stow` refuses to overwrite existing
  targets, which is the desired safety net.
- Existing `~/.config/niri/config.kdl` (199 active lines, looks like the upstream default) is copied into the repo as
  the baseline commit and backed up as `config.kdl.bak.<date>` before stowing.
- Packages to add (user runs `! sudo pacman -S ...`, interactively, abort if the prompt removes or replaces any
  `plasma-*`, `kde-*` or `xdg-desktop-portal-kde`): `stow`, `noctalia`, `xwayland-satellite`,
  `xdg-desktop-portal-gnome` (decided: screen share and Discord are required, and niri screencasting goes through the
  GNOME portal). A read-only `pacman -Sp` dry run on 2026-10-24 for `niri noctalia xdg-desktop-portal-gnome
  xwayland-satellite` listed only additions.
- The niri package already ships `/usr/share/xdg-desktop-portal/niri-portals.conf`
  (`default=gnome;gtk;`, `Access` and `Notification` = gtk, `Secret=gnome-keyring`). No portal config is added by this repo.
- **Do not install `gnome-keyring`.** It `Provides: org.freedesktop.secrets`, the same D-Bus name KWallet serves for
  Plasma. It is not pulled in by `xdg-desktop-portal-gnome` (checked with `pacman -Sp`). Consequence: the niri `Secret`
  portal has no backend, so secret storage in niri-session apps may not persist (open question 7).
- Uninstall: `stow -D`, remove the two Noctalia dirs below, restore the niri backup.
  `~/.local/state/noctalia`, `~/.cache/noctalia` (from the Noctalia uninstall page). No template files exist because
  all templates are off.

## 6. Multi-monitor and hybrid GPU

- Bars, notifications, OSD and lock screen already cover all outputs by default. No per-monitor tables initially.
- niri keeps the compositor on the Intel iGPU (the laptop panel is wired to Intel, HDMI to NVIDIA). Games run via
  `prime-run %command%` (installed; sets `__NV_PRIME_RENDER_OFFLOAD`, `__VK_LAYER_NV_optimus`,
  `__GLX_VENDOR_LIBRARY_NAME`). How to pin niri's render device is **unverified** (open question 4).
- Gaming comparison between Plasma and niri is a measurement task (MangoHud logs of the same scene), not a spec
  claim. No benchmark comparing niri with KDE was found.

## 7. Test plan (honest scope)

- **Test-first now:** `scripts/check-plasma-intact.sh` with a stubbed `pacman`/`gsettings` and a temporary `HOME`.
  Red then green. Cases: unchanged state exits 0; modified `kdeglobals` exits 1 and names the file; missing
  `xdg-desktop-portal-kde` exits 1; template id in `settings.toml` exits 1; `sync_color_scheme = true` exits 1;
  missing snapshot exits 2. Plain bash runner; `shellcheck` is installed, `bats` is not.
- **Test-first now, because niri is already installed:** `niri validate -c <file>` (verified: prints `config is valid`)
  for the repo `config.kdl`, and a Python check of `Mizu.json` (16 roles, hex format, the contrast ratios in 3.1).
- **After the package is installed, not before:** `noctalia config validate <dir>`. It exits 0 on warnings such as
  unknown keys, so the test must fail on **any output**, not on exit code alone. This is also where
  `source = "custom"` gets settled. No config test exists or is implied before installation.
- **Manual, in the real session:** clock renders `10月24日 土 14:30`; both outputs show a bar; the Palette Inspector
  (Settings → Appearance → Theme) shows Mizu active.

## 8. Phases (each ends with a gate)

1. **Baseline:** stow installed; baseline snapshot; niri config copied into repo and backed up. Gate: check script green.
2. **Packages:** `noctalia`, `xwayland-satellite`, portal choice; user runs `sudo`. Gate: dry-run clean, invariant 4.
3. **Minimal niri session:** edited `config.kdl` (items 9-12), Noctalia not yet started. Gate: login works, Plasma
   session still works.
4. **Noctalia on:** items 1-8, run `noctalia config validate`. Gate: no output, check script green.
5. **Gaming measurement:** `prime-run`, MangoHud, same scene on Plasma and niri.
6. **Polish:** per-monitor tweaks, optional Japanese glyph forms.

## 9. Unverified items and open questions

1. Docs say `source = "custom"`; `example.toml` lists only `builtin | wallpaper | community`. Settled by
   `noctalia config validate` after install. Fallback: built-in Tokyo-Night.
2. ~~Portal choice~~ Resolved: `xdg-desktop-portal-gnome` is installed (it pulls `nautilus`, `gvfs`, `graphviz`,
   `ghostscript` and more) because screen share and Discord are required.
3. Non-ASCII literals (`月`, `日`) in the clock format are only implied by the docs ("literal text is copied through").
4. How to pin niri's render device to the iGPU; the Debug Options page was not read.
5. `font_family` fallback syntax is **parked**. The default `sans-serif` for Japanese resolves to WenQuanYi Zen Hei,
   but common kanji such as 月 and 日 look near-identical in Japanese and Chinese forms. Check by eye first. If wanted,
   `Source Han Sans` (the Japanese family, installed via `adobe-source-han-sans-otc-fonts`) is the candidate.
   No global fontconfig change.
6. Multi-monitor behavior with mixed scales (`panel_overlap`) is untested on this hardware.
7. Secret storage in the niri session. `niri-portals.conf` names `gnome-keyring` for `Secret`, which stays uninstalled
   to protect KWallet. Check at phase 3 whether the Discord login persists across a restart. Fixing it, if it does not,
   is a separate decision.
