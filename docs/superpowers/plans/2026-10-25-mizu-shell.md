# mizu shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) or subagent-driven-development.
> Steps use checkbox syntax. Every code step is test-first (red, green, whole suite).

**Goal:** a SekaiPop-based Quickshell shell for niri whose colors all come from a smart wallpaper palette, switched in
with one command, with Noctalia kept as the fallback.

**Architecture:** palette tool (pure python `build()` + CLI) writes `tokens.json` and `colors.kdl`; the forked, pruned
SekaiPop tree reads the tokens through an adapter that keeps its old property names; niri binds go through a
`shell-ipc` dispatcher that serves either shell; `switch-shell.sh` installs, merges, stows, switches, and reverts on
failure.

**Tech stack:** Python 3.14 stdlib (`tomllib`, `unittest`), ImageMagick `magick`, `noctalia theme`, Quickshell 0.3.2
QML, niri 26.04, bash with fakes for tests.

**Spec:** docs/superpowers/specs/2026-10-25-mizu-shell-design.md (ADR: docs/adr/0001-own-quickshell-shell.md).

## Global Constraints

- Plasma stays byte-identical: no writes to kdeglobals, gtk-*, qt*ct, gsettings, environment.d, /etc,
  `~/.config/fcitx5`, and never to `~/.local/state/noctalia/settings.toml`.
- The shell and the palette tool write only under `~/.config/quickshell/`, `~/.config/niri/` and `~/.cache/`.
- No sudo by Claude. The user runs `scripts/switch-shell.sh`.
- Tests never need a display. Stow only from the main checkout. Commit when green. Never push to main.
- Palette: text >= 4.5:1, icons and borders >= 3:1 (WCAG), in dark and light mode.
- GPL-3.0 stays on the fork: LICENSE, credits, fork-point tree `4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf`.

## Review Focus

- A symlinked `config.kdl` with `colors.kdl` beside the symlink (the deployed layout): the include must resolve and
  the focus ring must change. A missing `colors.kdl` must still validate.
- Light mode and `auto`: bright wallpaper with a dark bar region, very bright and very dark backdrops, saturated
  blues and greens at the gamut edge for `accent2`.
- A broken `tokens.json` (missing keys, wrong types, empty file): the shell must keep its last colors, not go blank.
- `switch-shell.sh` with a broken mizu: the 60 s confirm times out and Noctalia returns; `--rollback` works without
  `qs`.
- Palette CLI interrupted mid-write: neither `tokens.json` nor `colors.kdl` may be half-written.

---

### Task 1: Palette core (`build()` and its helpers)

**Files:**
- Create: `quickshell/.config/quickshell/mizu/palette/mizu_palette/color.py`, `analysis.py`, `build.py`,
  `__init__.py`
- Test: `tests/test_mizu_palette_color.py`, `tests/test_mizu_palette_build.py`

**Interfaces:**
- Produces:
  - `color.py`: `hex_to_rgb(str) -> tuple[float,float,float]`, `rgb_to_hex(rgb) -> str`, `contrast(a, b) -> float`
    (WCAG), `to_lab(rgb)`, `from_lab(lab)`, `to_lch`, `from_lch`, `in_gamut(rgb) -> bool`,
    `rotate_hue(rgb, degrees) -> rgb` (same L*, chroma reduced in steps of 2 until in gamut),
    `fit_lightness(color, backdrop, minimum, direction) -> rgb | None`.
  - `analysis.py`: `Region` dataclass (`mean`, `L`, `chroma`, `busy`, `lum_lo`, `lum_hi`),
    `region_stats(grid, rect) -> Region`, `pick_scheme(whole: Region, override: str | None) -> str`,
    `pick_mode(whole: Region, bar: Region, mode: str) -> str`.
  - `build.py`: `build(grid, generate, overrides, mode) -> dict` returning the `mizu.tokens/1` document of spec §3.
    `generate(scheme: str, mode: str) -> dict[str, str]` returns the generator's role dict (the `noctalia theme`
    keys: `primary`, `on_primary`, `surface_container`, ...).
- Consumes: nothing.

- [ ] **Step 1: Write the failing tests for `color.py`.** Names and assertions:
  - `test_contrast_black_on_white_is_21`; `test_contrast_is_symmetric`;
  - `test_lab_round_trip_within_0_5_per_channel`;
  - `test_rotate_hue_keeps_lightness_and_stays_in_gamut` over 200 seeded random colors including `#0000ff`, `#00ff00`;
  - `test_rotate_hue_moves_the_hue_by_28_degrees_within_2` for colors that stay in gamut without chroma reduction;
  - `test_fit_lightness_lightens_on_dark_backdrop_and_darkens_on_light`; `test_fit_lightness_returns_none_at_the_limit`.
- [ ] **Step 2: Run:** `python3 -I -B -m unittest tests.test_mizu_palette_color` (add `tests` to the path as the other
  python tests do). Expected: FAIL, module missing.
- [ ] **Step 3: Implement `color.py`** (CIELAB D65 as in the prototype's helpers; LCh hue rotation with the
  chroma-reduction loop).
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Write the failing tests for `analysis.py` and `build.py`:**
  - `test_pick_scheme_thresholds` at chroma 6.9 -> `m3-monochrome`, 7 -> `soft`, 15.9 -> `soft`, 16 -> `faithful`;
    `test_scheme_override_wins`;
  - `test_auto_mode_light_only_when_image_and_bar_are_bright` (4 cases);
  - `test_opacity_is_clamped_between_0_55_and_0_97`;
  - `test_text_contrast_is_at_least_4_5_for_random_grids_in_dark_and_light_mode` (200 seeded grids per mode, fake
    generator with deliberately weak `on_surface`); `test_accent_contrast_is_at_least_3`;
  - `test_accent_falls_back_to_on_surface_at_the_limit` (all-white and all-black grids, both modes);
  - `test_accent2_is_in_gamut_and_28_degrees_from_accent`;
  - `test_overrides_win_over_analysis`; `test_tokens_have_every_key_of_the_schema` (the key list of spec §3);
  - `test_generator_receives_scheme_and_mode`.
- [ ] **Step 6: Run.** Expected: FAIL, functions missing.
- [ ] **Step 7: Implement `analysis.py` and `build.py`** per spec §3 (region rectangles for bar, phone, widget;
  opacity `clamp(0.62 + busy/40, 0.55, 0.97 after correction)`; token mapping table of spec §4).
- [ ] **Step 8: Run the whole suite** (`tests/run-all.sh`). Expected: all green. Commit:
  `git commit -m "Palette core: analysis, scheme pick and contrast-corrected token build"`.

### Task 2: Palette CLI and the niri colors file

**Files:**
- Create: `quickshell/.config/quickshell/mizu/palette/mizu_palette.py` (CLI), `adapters.py` (`magick` grid reader,
  `noctalia theme` generator, `render_niri_kdl(tokens) -> str`, `atomic_write(path, text)`)
- Test: `tests/test_mizu_palette_cli.py`, `tests/test_niri_colors_include.sh`

**Interfaces:**
- Produces: `python3 -I -B mizu_palette.py <wallpaper> [--tokens P] [--niri P] [--mode auto|dark|light]
  [--overrides P] [--cache-dir P]`; exit 0, 2 (image or generator failure, old files kept), 64 (usage).
- Consumes: `build.build`, `analysis`, `color` from Task 1.

- [ ] **Step 1: Failing tests:**
  - `test_writes_tokens_and_niri_file_atomically` (no `*.tmp` left; the temp file is in the same directory);
  - `test_failed_generator_exits_2_and_keeps_both_old_files`; `test_unreadable_image_exits_2`;
  - `test_usage_error_exits_64`; `test_cache_hit_does_not_call_the_generator` (counting fake generator);
  - `test_niri_file_validates` (real `niri validate` on a config that includes it) and carries the tokens'
    `accent` as `active-color`;
  - `test_interrupted_write_leaves_no_half_file` (fault injected between the two renames);
  - `test_tokens_primary_matches_noctalia_theme_output` (real `noctalia theme` and `magick`; skipped only when either
    binary is absent, and then reported by name).
- [ ] **Step 2: Failing shell test `tests/test_niri_colors_include.sh`:** build a temp dir with `real/config.kdl`
  (includes `colors.kdl`), a symlink `link/config.kdl -> ../real/config.kdl` and `link/colors.kdl`;
  assert `niri validate -c link/config.kdl` prints no `optional include not found`; then remove `colors.kdl` and
  assert it still validates (warning allowed).
  Note the deployed layout: stow links `~/.config/niri/config.kdl` into the repo, and `colors.kdl` is a real file
  beside the link. If niri resolves the include next to the target instead of the link, this test fails, and the
  fix is to stow `colors.kdl` as a real file via the CLI default path (decided by the test result).
- [ ] **Step 3: Run both.** Expected: FAIL.
- [ ] **Step 4: Implement the CLI and adapters.**
- [ ] **Step 5: Run the whole suite. Expected: green.** Commit.
- [ ] **Step 6: Real-wallpaper smoke:** run the CLI on 6 wallpapers of `~/Pictures/Wallpapers` into a temp dir and
  read the contact sheet (`scripts/dev/palette-sheet.sh`, new) for the final report.

### Task 3: Make the focus ring follow the wallpaper with the new tool

**Files:** modify `noctalia/.config/noctalia/config.toml` (nothing, if the include test passes as is),
`niri/.config/niri/scripts/` (no change), `README.md`, `docs/USAGE.md`.

- [ ] **Step 1:** only if Task 2 Step 2 showed a layout problem: failing test for the fix, then apply it.
- [ ] **Step 2:** document `mizu_palette.py` as the way to render colors for any wallpaper without a shell, in
  README.md (rules table) and docs/USAGE.md (Vietnamese). Commit.

### Task 4: Fork import and the safety scan (red), then pruning to green

**Files:**
- Create: `quickshell/.config/quickshell/mizu/**` (import of upstream `sekaipop/` at the fork point, minus `assets/icons`),
  `LICENSE`, `UPSTREAM.md`
- Test: `tests/test_mizu_safety.py`

- [ ] **Step 1: Failing test:** the scan of spec §9 over `quickshell/`, **plus** `test_every_removed_module_is_gone`
  (the REMOVE list of spec §5 as a literal list of paths) and `test_upstream_md_names_the_fork_point_and_licence`.
  Run it against an imported copy: expected FAIL with hundreds of findings (kdeglobals, hyprctl, pkexec...).
- [ ] **Step 2: Import** the upstream tree and run the scan again to record the red count in the ledger.
- [ ] **Step 3: Prune in groups, each ending with the nested niri smoke and the scan count going down:**
  (a) theming services, scripts and the settings sections that call them; (b) Hyprland services and modules;
  (c) updater, plugins, hooks, WARP, Discord, welcome, equalizer, visualizer, dock, overview, cheatSheet, keybinds,
  regionSelector, keyboard, palette tool, editMode UI, gacha lock; (d) stub singletons (EditMode, PresetMotion,
  GameModeService, WidgetClones, FocusService, WallpaperService.restacking).
- [ ] **Step 4: Scan green, whole suite green.** Commit per group.

### Task 5: Tokens adapter and neutral colors

**Files:** modify `modules/common/Theme.qml`, `ThemeSet.qml`, `ScrapbookTheme.qml` and every file the scan lists for
hex literals; create `modules/common/Tokens.qml`; test `tests/test_mizu_safety.py` (hex rule),
`tests/test_mizu_tokens.py`.

- [ ] **Step 1: Failing tests:** `test_tokens_qml_reads_the_cache_path_and_watches_it`; `test_every_theme_role_has_a_token`
  (the map of spec §4 against `ThemeSet.qml`); `test_tokens_json_missing_keys_fall_back_to_neutral_defaults` (a QML
  smoke in the nested niri is the proof, the unit test checks the default table).
- [ ] **Step 2: Implement** `Tokens.qml` (FileView, `watchChanges: true`, parse guard, last-good kept) and make
  `ThemeSet.qml` read it with the old property names; colors animate over 450 ms.
- [ ] **Step 3:** replace hard-coded colors per the harvest map section 4.3. Scan green, suite green. Commit.

### Task 6: Compositor, Catcher, IPC target, idle

**Files:** create `services/Compositor.qml`, `modules/common/Catcher.qml`, `services/MizuIpc.qml`,
`services/Idle.qml`, `modules/common/PopReveal.qml`; extend `functions/NiriMath.js` (+ node test).

- [ ] **Step 1: Failing node tests:** `focusedOutput` from `is_focused`, window events, keyboard layouts.
- [ ] **Step 2: Implement; replace each Hyprland API per the harvest map section 3 table. Nested niri smoke: every
  phone opens on the focused output; click outside closes it (scripted with `niri msg action` pointer-free: the IPC
  `hide` path) and a screenshot proves the catcher exists.
- [ ] **Step 3:** idle: IdleMonitor 1800 s -> power-off-monitors, 2700 s -> lock, `respectInhibitors: true`.
  Test with shortened timeouts (30 s / 45 s) through a settings override, in the nested niri.

### Task 7: Dispatcher scripts and niri binds

**Files:** create `niri/.config/niri/scripts/shell-start`, `shell-ipc`; modify `config.kdl`; tests
`tests/test_shell_ipc.sh`, adapt `tests/test_niri_config.sh`, `tests/test_usage_guide.py`.

- [ ] **Step 1: Failing tests:** every action maps to both shells (fake `qs` and `noctalia` on PATH log their
  argv); a missing, empty or garbage `~/.config/niri/shell` means `noctalia`; the bind lines use
  `spawn-sh "~/.config/niri/scripts/shell-ipc <action>"` and run (the test executes the exact bind string in a shell
  with HOME pointing at a temp dir holding the scripts); startup uses `shell-start`; the 3-key rule still holds;
  `Mod+Alt+W` -> `wallpaper-next`.
- [ ] **Step 2: Implement; update `docs/USAGE.md`.** Commit.

### Task 8: Surfaces, in the order of the harvest map's port list

One group per sub-task, each: nested niri screenshot on 3 wallpapers (dark, bright, grey), no QML errors in the log,
suite green, commit.

- [ ] 8a Bar on both outputs with niri workspaces, status pills, clock with the Japanese date, tray.
- [ ] 8b Quick panel phone (network, Bluetooth, volume, brightness via brightnessctl/ddcutil, night light via
  wlsunset, DND, notifications with peek, power menu with niri logout).
- [ ] 8c Settings phone (Quick, General, Bar, Desktop, About, niri page) and the wallpaper face (local folder,
  palette re-run on pick, `wallpaper` and `wallpaper-next` IPC).
- [ ] 8d Launcher phone with the calculator, clipboard (cliphist) and emoji cards.
- [ ] 8e Desktop widgets: clock, weather (timezone city default, no IP lookup), calendar, to-do, lyrics (lrclib only).
- [ ] 8f OSD, notification server, polkit prompt, lock screen (own PAM file, three lock scenarios of spec §10).

### Task 9: `scripts/switch-shell.sh`

**Files:** create `scripts/switch-shell.sh`, `tests/test_switch_shell.sh`, `tests/stubs/*` fakes; modify README.md.
Built with the wizard skill.

- [ ] **Step 1: Failing tests** (fakes for sudo, pacman, git, stow, niri, qs, noctalia on PATH, each logging argv):
  dry-run runs no mutating command; a package list conflicting with an installed plasma-/kde package aborts before
  sudo; a failing gate after the merge reverts `shell` to `noctalia` and restarts Noctalia; the 60 s confirm times
  out (test shortens it by `MIZU_CONFIRM_SECONDS`) and reverts; `--rollback` works with `qs` absent and never writes
  `settings.toml`; the live theme mismatch is printed, not changed.
- [ ] **Step 2: Implement.** Step 3: suite green. Commit.

### Task 10: Quality gates and report

- [ ] `design:accessibility-review` on the palette sheet; `design:design-critique` on the screenshots;
  `/code-review`, `/security-review`, `/simplify`; `superpowers:requesting-code-review` on the whole branch
  (fix Critical and Important with test-first, ledger the rest).
- [ ] `engineering:documentation` for `docs/USAGE.md` (Vietnamese): keymap, palette, switch and rollback;
  `mattpocock-skills:writing-for-agents` for CLAUDE.md.
- [ ] `superpowers:verification-before-completion`: full suite, `niri validate`, `check-plasma-intact.sh noctalia`,
  fingerprint of Plasma files unchanged across the whole run. Final report in Vietnamese with the parity split, the
  rulings, the deferred minors and, on the last line, the one command.
