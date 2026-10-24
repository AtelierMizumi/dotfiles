# niri + Noctalia rice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a stow-managed niri + Noctalia v5 configuration with the "Mizu" palette, plus a test-first script that proves Plasma is untouched.

**Architecture:** Two stow packages (`niri/`, `noctalia/`) hold the config. `scripts/check-plasma-intact.sh` (bash) snapshots and compares Plasma-shared files, gsettings and package state. It delegates Noctalia config rules to `scripts/check_noctalia.py` (Python, `tomllib`). Config files are tested with `niri validate` and `unittest`.

**Tech Stack:** bash + `shellcheck`, Python 3 stdlib (`unittest`, `tomllib`, `json`), `niri validate`, GNU stow (installed by the user).

**Spec:** `docs/superpowers/specs/2026-10-24-niri-noctalia-rice-design.md`

> **Erratum (after the whole-branch review):** Task 7 phases 3-4 and the `noctalia config validate` gate below were
> corrected. Stow `niri` and `noctalia` together before the next niri login, stay in the niri session until the final
> compare, and run `noctalia config validate` with no argument (pass = exit 0 and no `WARN`/`ERROR` line). `README.md`
> and spec sections 7-8 are authoritative.

## Global Constraints

- niri 26.04 and `noctalia 5.3.0-1` (both from `extra`). No `/etc` edits. The agent never runs `sudo`; the user runs `! sudo pacman -S ...` interactively and aborts if the prompt removes or replaces `plasma-*`, `kde-*` or `xdg-desktop-portal-kde`.
- `[theme] sync_color_scheme = false` and `[theme.templates] enable_builtin_templates = false`, `enable_community_templates = false`. All templates off.
- `LC_TIME=ja_JP.UTF-8` only on the `noctalia` process via `spawn-at-startup "env" "LC_TIME=ja_JP.UTF-8" "noctalia"`. No `environment.d`, shell profile, global fontconfig or `logind.conf` change.
- Palette "Mizu" role values exactly as in spec section 3.1. No per-monitor bar overrides. Dock and desktop widgets stay off.
- niri: gaps `12`, `geometry-corner-radius 20`, `clip-to-geometry true`, focus ring 2 px hardcoded `#E2A63B`.
- Do **not** install `gnome-keyring` (it provides `org.freedesktop.secrets`, the name KWallet serves).
- Commit messages in English, ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Never commit `.env`, credentials, or `*.docx *.pdf *.xlsx *.pptx *.zip`.
- Bash scripts use `#!/usr/bin/env bash`, `set -euo pipefail`, pass `shellcheck`. Tests are plain bash and `python3 -I -m unittest`; `bats` is not installed.

## Review Focus

Inputs the spec implies but its tables do not pin, most likely first. Each has a test in the owning task.

- `HOME` containing a space (Task 1 test `home_with_spaces_works`).
- `~/.local/state/noctalia/settings.toml` malformed or absent: malformed is a violation, absent is fine (Task 2).
- `gsettings` missing or failing (no D-Bus): recorded as `UNAVAILABLE`, unchanged is not a violation (Task 1).
- Snapshot or compare run while `plasmashell` is running: refused with exit 2 (Task 1).
- A watched file that did not exist at snapshot time appears later, or one that existed disappears (Task 1).

## File Structure

| Path | Responsibility |
|---|---|
| `scripts/check-plasma-intact.sh` | CLI: `snapshot`, `compare`, `packages`, `noctalia`. Owns watched-file list, gsettings and package checks. |
| `scripts/check_noctalia.py` | Merge `*.toml` + GUI `settings.toml`, report template and `sync_color_scheme` violations. |
| `tests/run-all.sh` | Runs shellcheck, every `tests/test_*.sh` and `tests/test_*.py`; prints pass/fail counts. |
| `tests/stubs/{pacman,gsettings,pgrep}` | Fake binaries driven by env vars, used via `PACMAN_BIN`, `GSETTINGS_BIN`, `PGREP_BIN`. |
| `tests/test_check_plasma_intact.sh`, `tests/test_check_noctalia.py` | Tests for the two scripts. |
| `noctalia/.config/noctalia/palettes/Mizu.json`, `tests/test_palette.py` | Palette and its tests. |
| `noctalia/.config/noctalia/config.toml`, `tests/test_noctalia_config.py` | Noctalia overlay and tests. |
| `niri/.config/niri/config.kdl`, `docs/baseline/niri-config.default.kdl`, `tests/test_niri_config.sh` | niri config, untouched baseline copy, tests. |
| `README.md` | Install runbook, gates, rollback, measurement procedure. |

## Task 1: Plasma-safety checker, files, gsettings, packages

**Files:**
- Create: `scripts/check-plasma-intact.sh`, `tests/run-all.sh`, `tests/test_check_plasma_intact.sh`, `tests/stubs/pacman`, `tests/stubs/gsettings`, `tests/stubs/pgrep`

**Interfaces:**
- Produces: `check-plasma-intact.sh <snapshot|compare|packages|noctalia> [--state-dir DIR]`. Env overrides: `XDG_CONFIG_HOME` (default `$HOME/.config`), `XDG_STATE_HOME` (default `$HOME/.local/state`), `PACMAN_BIN`, `GSETTINGS_BIN`, `PGREP_BIN`. Default state dir `$XDG_STATE_HOME/dotfiles-check`. Exit 0 ok, 1 violation, 2 usage/no snapshot/refused. Violation lines: `CHANGED: <path relative to config home>`, `GSETTINGS CHANGED: <key>`, `MISSING PACKAGE: <name>`, `BROKEN PACKAGE: <name>`. Refusal line on stderr: `REFUSED: plasmashell is running`.
- Watched files (relative to config home): `kdeglobals`, `kdedefaults/kdeglobals`, `mimeapps.list`, `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `xdg-desktop-portal-kderc`. gsettings keys: `org.gnome.desktop.interface color-scheme` and `gtk-theme`. Packages: `xdg-desktop-portal-kde`, `plasma-desktop`, `sddm` (`pacman -Q <pkg>` must succeed; `pacman -Qk <pkg>` output must contain `0 missing files`).
- `noctalia` subcommand is wired in Task 2.

- [ ] **Step 1: Write the failing tests** in `tests/test_check_plasma_intact.sh`. Each test builds a temp `HOME` and runs the script with stubs. Test names and assertions:
  - `unchanged_state_exits_0`: snapshot then compare, exit 0.
  - `modified_kdeglobals_exits_1_and_names_file`: exit 1, stdout contains `CHANGED: kdeglobals`.
  - `watched_file_appearing_or_disappearing_exits_1`: a file absent at snapshot then created, and a present file then deleted; each exit 1 with `CHANGED: <path>`.
  - `snapshot_missing_exits_2`: compare with no snapshot, exit 2.
  - `home_with_spaces_works`: `HOME="$tmp/my home"`, snapshot+compare exit 0.
  - `gsettings_unavailable_is_recorded_and_not_a_violation`: `GSETTINGS_BIN` points to a stub that exits 1; snapshot and compare exit 0.
  - `gsettings_value_change_exits_1`: stub value changes between runs; stdout contains `GSETTINGS CHANGED: color-scheme`.
  - `plasmashell_running_refuses_snapshot_and_compare`: `pgrep` stub reports a match; both exit 2 and stderr contains `REFUSED: plasmashell is running`; `packages` still works.
  - `packages_ok_exits_0`, `packages_missing_portal_kde_exits_1` (stdout `MISSING PACKAGE: xdg-desktop-portal-kde`), `packages_qk_missing_files_exits_1` (stdout `BROKEN PACKAGE: plasma-desktop`).
  - `tests/run-all.sh` runs `shellcheck scripts/*.sh tests/*.sh tests/stubs/*`, then every `tests/test_*.sh` (each exits non-zero on any failed assertion) and `python3 -I -m unittest discover -s tests -p 'test_*.py'`, and prints `passed=N failed=M skipped=K`.
- [ ] **Step 2: Create a skeleton** `scripts/check-plasma-intact.sh` that prints `not implemented` and exits 3, so the run fails on assertions rather than on a missing file. Run `bash tests/run-all.sh`. Expected: FAIL, exit-code mismatches (3 versus 0/1/2).
- [ ] **Step 3: Implement the script** to the interface above. Snapshot stores `files.sha256` (`MISSING` for absent files) and `gsettings.txt` (`UNAVAILABLE` when the binary fails). Quote every path expansion.
- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `failed=0`, shellcheck clean.
- [ ] **Step 5: Commit** `scripts tests`, message `Add Plasma-safety checker for shared files, gsettings and packages`.

## Task 2: Noctalia config rules for the checker

**Files:**
- Create: `scripts/check_noctalia.py`, `tests/test_check_noctalia.py`
- Modify: `scripts/check-plasma-intact.sh` (wire `noctalia` subcommand), `tests/test_check_plasma_intact.sh` (one test)

**Interfaces:**
- Consumes: Task 1 CLI conventions (exit codes, `XDG_STATE_HOME`).
- Produces: `check_noctalia.py <config_dir> <settings_toml>`; `def check(config_dir: Path, settings_toml: Path) -> list[str]` returns violation lines; `def main(argv: list[str]) -> int` prints them, returns 0/1. Merge rule: every `*.toml` in `config_dir` sorted by name, deep-merged, then `settings_toml` on top (it wins). Violation lines: `TEMPLATE ENABLED: <where>`, `SYNC_COLOR_SCHEME NOT FALSE: <where>`, `UNREADABLE TOML: <path>`. `noctalia` subcommand uses `<repo>/noctalia/.config/noctalia` and `$XDG_STATE_HOME/noctalia/settings.toml`.

- [ ] **Step 1: Write the failing tests** in `tests/test_check_noctalia.py` (`unittest`, temp dirs). Names and assertions:
  - `test_missing_sync_color_scheme_is_violation` (upstream default is true), `test_sync_false_is_ok`.
  - `test_builtin_templates_enabled_is_violation`, `test_community_templates_enabled_is_violation`.
  - `test_settings_toml_template_ids_is_violation` (`builtin_ids = ["x"]`), `test_settings_toml_user_template_without_enabled_false_is_violation`, `test_settings_toml_sync_true_overrides_repo_false`.
  - `test_settings_toml_absent_is_ok`, `test_settings_toml_malformed_is_violation` (`UNREADABLE TOML`).
  - `test_later_toml_file_wins_alphabetically`.
  - Bash test `noctalia_subcommand_propagates_exit_code` in `tests/test_check_plasma_intact.sh`.
- [ ] **Step 2: Skeleton** `check_noctalia.py` with `check()` returning `[]` and `main()` returning 0. Run `bash tests/run-all.sh`. Expected: FAIL on the violation tests.
- [ ] **Step 3: Implement `check`** with `tomllib`; a user template table is enabled unless it has `enabled = false`.
- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `failed=0`.
- [ ] **Step 5: Commit**, message `Add Noctalia template and sync_color_scheme checks`.

## Task 3: Mizu palette

**Files:**
- Create: `noctalia/.config/noctalia/palettes/Mizu.json`, `tests/test_palette.py`

**Interfaces:**
- Produces: palette file name `Mizu` (referenced by Task 4 as `custom_palette = "Mizu"`). Top-level `dark` only; 16 role keys `mPrimary mOnPrimary mSecondary mOnSecondary mTertiary mOnTertiary mError mOnError mSurface mOnSurface mSurfaceVariant mOnSurfaceVariant mOutline mShadow mHover mOnHover` plus `terminal`.

- [ ] **Step 1: Write the failing tests** in `tests/test_palette.py`, with the spec 3.1 table as the expected dict. Names: `test_dark_has_exactly_the_16_roles_with_spec_values`; `test_light_is_omitted`; `test_all_colors_are_6_digit_hex`; `test_terminal_has_background_foreground_cursor_selection_and_16_ansi`; `test_terminal_background_and_foreground_match_surface` (`#182338`, `#EDF0F3`); `test_text_pairs_meet_4_5_contrast` over onSurface/surface, onSurface/surfaceVariant, onSurfaceVariant/surface, onSurfaceVariant/surfaceVariant, primary/surface, onPrimary/primary, secondary/surface, onSecondary/secondary, tertiary/surface, onTertiary/tertiary, error/surface, onError/error, onHover/hover (WCAG relative luminance, implemented inside the test).
- [ ] **Step 2: Run** `python3 -I -m unittest tests/test_palette.py`. Expected: FAIL, file not found.
- [ ] **Step 3: Create `Mizu.json`:** role values from spec 3.1. Copy the `terminal` `normal` and `bright` blocks and `cursor`/`cursorText`/`selectionBg`/`selectionFg` from Tokyo-Night in `src/theme/builtin_palettes.cpp` (read with `gh api repos/noctalia-dev/noctalia/contents/src/theme/builtin_palettes.cpp -H 'Accept: application/vnd.github.raw'`, from line 1019). Set terminal `background`/`foreground` to `#182338`/`#EDF0F3`.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit**, message `Add Mizu palette`.

## Task 4: Noctalia overlay config

**Files:**
- Create: `noctalia/.config/noctalia/config.toml`, `tests/test_noctalia_config.py`

**Interfaces:**
- Consumes: palette name `Mizu` (Task 3); `check-plasma-intact.sh noctalia` (Task 2).

- [ ] **Step 1: Write the failing tests** in `tests/test_noctalia_config.py` (parse with `tomllib`). Names: `test_theme_uses_custom_mizu_dark`, `test_sync_color_scheme_is_false`, `test_all_templates_are_off`, `test_polkit_agent_enabled`, `test_clock_format_is_japanese_date_and_time` (exact string `{:%-m}月{:%-d}日 {:%a} {:%H:%M}`), `test_no_per_monitor_bar_tables` (no `monitor` key under any `bar.*`), `test_dock_and_desktop_widgets_not_enabled`, plus a subprocess test that `scripts/check-plasma-intact.sh noctalia` exits 0 with an empty `XDG_STATE_HOME`.
- [ ] **Step 2: Run** `python3 -I -m unittest tests/test_noctalia_config.py`. Expected: FAIL, file not found.
- [ ] **Step 3: Create `config.toml`** with `[theme]` (`mode = "dark"`, `source = "custom"`, `custom_palette = "Mizu"`, `sync_color_scheme = false`), `[theme.templates]` (both enables `false`), `[shell] polkit_agent = true`, `[widget.clock] format = ...`. Add a comment on `source = "custom"` that it is unverified until `noctalia config validate` runs (see Task 7).
- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `failed=0`.
- [ ] **Step 5: Commit**, message `Add Noctalia overlay config`.

## Task 5: niri config

**Files:**
- Create: `docs/baseline/niri-config.default.kdl` (verbatim copy of the current `~/.config/niri/config.kdl`), `niri/.config/niri/config.kdl`, `tests/test_niri_config.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: the stow target for `~/.config/niri/config.kdl`.

- [ ] **Step 1: Write the failing tests** in `tests/test_niri_config.sh`. Names: `validates` (`niri validate -c niri/.config/niri/config.kdl` output contains `config is valid`); `baseline_validates` (`docs/baseline/niri-config.default.kdl` also prints `config is valid`); `waybar_not_started`; `fuzzel_not_referenced`; `noctalia_started_with_scoped_lc_time` (line `spawn-at-startup "env" "LC_TIME=ja_JP.UTF-8" "noctalia"`); `focus_ring_is_amber_2px` (`#E2A63B`, width 2); `gaps_12`; `corner_radius_20_with_clip`; `settings_window_floats_1080x920` (`app-id="dev.noctalia.Noctalia"`); `launcher_control_center_settings_binds` (`Mod+Space`, `Mod+S`, `Mod+Comma` using `noctalia msg panel-toggle launcher`, `panel-toggle control-center`, `settings-toggle`); `no_env_leak` (no `QT_QPA_PLATFORMTHEME`, and `LC_TIME` appears only on the spawn line).
- [ ] **Step 2: Run** the test. Expected: FAIL, config file missing.
- [ ] **Step 3: Copy the baseline** into `docs/baseline/` and `niri/.config/niri/config.kdl`, then edit the latter per spec items 9-12 (Noctalia niri page: window rules, `debug { honor-xdg-activation-with-invalid-serial }`). Verify with `niri validate`; adjust syntax until valid. If `spawn-sh` is rejected, use `spawn "noctalia" "msg" ...`.
- [ ] **Step 4: Run** `bash tests/run-all.sh`. Expected: `failed=0`.
- [ ] **Step 5: Commit**, message `Add niri config and baseline copy`.

## Task 6: README runbook

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the runbook** replacing the "Layout" placeholder: layout table, install phases 1-4 from Task 7 with exact commands, rollback (`stow -D`, remove `~/.local/state/noctalia` and `~/.cache/noctalia`, restore the niri backup), and a measurement section. Use `stow --no-folding` so Noctalia never writes into the repo. MangoHud keys verified in `/usr/share/doc/mangohud/MangoHud.conf.example`: `toggle_logging=Shift_L+F2`, `output_folder`, `log_duration`, `autostart_log`. Steam option: `prime-run mangohud %command%`. Whether MangoHud writes a summary with 1% lows is **unverified**; check after the first run.
- [ ] **Step 2: Verify** every command in the README exists: run `shellcheck` on any script snippets and `bash tests/run-all.sh`. Expected: `failed=0`.
- [ ] **Step 3: Commit**, message `Document install runbook and measurement procedure`.

## Task 7: Install and gates (the user runs these; the agent reads the output)

The agent cannot run `sudo` and cannot log into a niri session, so these steps are interactive.

- [ ] **Phase 1, baseline.** User: `! sudo pacman -S stow` (interactive). Log out of Plasma, log into the **niri** session (default config), run `scripts/check-plasma-intact.sh snapshot`. Expected: exit 0.
- [ ] **Phase 2, packages.** User: `! sudo pacman -S noctalia xwayland-satellite xdg-desktop-portal-gnome`, abort if the prompt removes or replaces any Plasma/KDE package. Then `scripts/check-plasma-intact.sh packages`. Expected: exit 0.
- [ ] **Phase 3, niri config.** `mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.bak.$(date +%F)`, then `stow -n -v --no-folding -t ~ niri` (dry run, no conflicts), then `stow --no-folding -t ~ niri`. Log into niri; `scripts/check-plasma-intact.sh compare` exits 0; log into Plasma and confirm it behaves normally. Check that the Discord login persists across a restart (spec open question 7).
- [ ] **Phase 4, Noctalia.** `stow --no-folding -t ~ noctalia`, then `noctalia config validate ~/.config/noctalia`. **Pass = no output at all** (it exits 0 on warnings). This also settles `source = "custom"`; if rejected, switch to `source = "builtin"`, `builtin = "Tokyo-Night"` and re-run the tests. In niri: clock shows `10月24日 土 14:30`, both `eDP-1` and `HDMI-A-1` show a bar, Palette Inspector shows Mizu. Then `scripts/check-plasma-intact.sh compare` and `scripts/check-plasma-intact.sh noctalia` both exit 0.
- [ ] **Phase 5, gaming measurement** per the README, same scene on Plasma and niri.
- [ ] **Phase 6, polish** (per-monitor tweaks by connector name, optional `Source Han Sans` glyph forms).

## Self-review

- **Spec coverage:** items 1-12 and 3.1 → Tasks 3-5; invariants 1-4 and the snapshot rules → Tasks 1-2; install mechanism, packages, `gnome-keyring` rule and rollback → Tasks 6-7; test plan → Tasks 1-5 and Task 7 gate; phases 1-6 → Task 7; open questions 1, 3, 7 → Task 7. Open questions 4, 5, 6 (render-device pinning, `font_family` fallback, mixed-scale `panel_overlap`) are deliberately not planned and stay open in the spec.
- **Interface consistency:** `check-plasma-intact.sh noctalia` is defined in Task 1's interface, wired in Task 2, used in Tasks 4 and 7. Palette name `Mizu` matches Tasks 3-4. State dir and env override names are identical across Tasks 1-2.
- **Proportion:** no step carries a function body; the only literal copy is the clock format string, which the spec fixes.
