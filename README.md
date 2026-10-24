# dotfiles

Personal Arch Linux rice: a scrollable-tiling Wayland session (niri) with the Noctalia v5 shell, living **next to**
KDE Plasma without touching it.

> Status: configs and checks are in place. Nothing is installed or symlinked until you follow the runbook below.

Design: [`docs/superpowers/specs/2026-10-24-niri-noctalia-rice-design.md`](docs/superpowers/specs/2026-10-24-niri-noctalia-rice-design.md) ·
Plan: [`docs/superpowers/plans/2026-10-24-niri-noctalia-rice.md`](docs/superpowers/plans/2026-10-24-niri-noctalia-rice.md)

## Goals

- Keep the existing KDE Plasma session fully working (separate session picked at the display manager).
- Reproducible: every config lives in this repo, installs are explicit and reversible.
- Gaming-friendly on the hybrid Intel iGPU + NVIDIA dGPU laptop (compositor on iGPU, games on dGPU).

## Rules

- No secrets (`.env`, tokens, keys) and no binary documents in this repo.
- Environment variables for the rice go in the compositor config, never in `environment.d` or shell profiles
  (they would leak into Plasma).
- All Noctalia templates stay off and `sync_color_scheme` stays `false`: they would write `gtk-*`, `kdeglobals`
  and the user-wide gsettings `color-scheme`.
- Do not install `gnome-keyring`: it provides `org.freedesktop.secrets`, the name KWallet serves for Plasma.

## Layout

| Path | What it is |
|---|---|
| `niri/.config/niri/config.kdl` | niri config (stow package `niri`) |
| `niri/.config/xdg-desktop-portal/niri-portals.conf` | portal routing for the niri session (stow package `niri`) |
| `noctalia/.config/noctalia/config.toml`, `palettes/Mizu.json` | Noctalia overlay and the Mizu palette (stow package `noctalia`) |
| `docs/USAGE.md` | user guide in Vietnamese: keymap for laptop and Sofle, daily coding workflow, idle, rollback |
| `docs/baseline/niri-config.default.kdl` | the untouched default niri config this one started from |
| `scripts/check-plasma-intact.sh`, `scripts/check_noctalia.py` | proof that Plasma is untouched (see Checks) |
| `tests/` | `bash tests/run-all.sh` runs shellcheck, the bash tests and the Python tests |
| `CLAUDE.md` | handoff for a new Claude Code session: rules and read-only phase detection |

`niri-portals.conf` exists because your generic `~/.config/xdg-desktop-portal/portals.conf` routes every backend,
including ScreenCast and Screenshot, to the Plasma portals, and a user-level `portals.conf` outranks the system
`niri-portals.conf`. A desktop-specific file in the same directory wins over the generic one, so niri gets the GNOME
portal that screen share (and Discord) needs. Plasma keeps using its own `kde-portals.conf`.

## Checks

`scripts/check-plasma-intact.sh <command>`, exit 0 means fine, 1 a violation, 2 usage error or refused:

- `snapshot` and `compare` record and compare hashes of `kdeglobals`, `kdedefaults/kdeglobals`, `mimeapps.list`,
  `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `xdg-desktop-portal-kderc`, `xdg-desktop-portal/portals.conf` and
  `xdg-desktop-portal/kde-portals.conf`, plus the gsettings `color-scheme` and `gtk-theme`. They **refuse to run
  while `plasmashell` is running** (Plasma rewrites some of these files itself), so run them with Plasma logged out.
  State lives in `~/.local/state/dotfiles-check`.
- `packages` checks that `xdg-desktop-portal-kde`, `plasma-desktop` and `sddm` are installed with no missing files.
- `noctalia` checks the repo config **and** the live `~/.config/noctalia` (honoring `NOCTALIA_CONFIG_HOME`), plus
  `~/.local/state/noctalia/settings.toml` (the GUI overrides, which win; honoring `NOCTALIA_STATE_HOME`). Every
  template must be off and `sync_color_scheme` false. An `[include]` table is reported as `UNSUPPORTED INCLUDE`
  because the checker cannot expand it.

## Install runbook (driven from a TTY)

Every phase ends on a gate that must pass before the next one. Lines starting with `sudo` are yours to run, in a
**second VT** (for example Ctrl+Alt+F4), not through the Claude Code prompt: the password prompt and the sandbox make
`sudo` unreliable there. Read pacman's prompt and **abort** if it removes or replaces any `plasma-*`, `kde-*` or
`xdg-desktop-portal-kde` package.

### Before you leave Plasma

1. **Merge.** A Claude Code session started in the main checkout only sees this README after the branch is merged.
   In `~/Projects/Tools/dotfiles`: `git merge --ff-only worktree-niri-noctalia-spec`. Always stow from that checkout,
   never from `.claude/worktrees/`, whose path disappears when the worktree is removed.
2. **Check free space.** `df -h /` (it was 91% full; the 37 packages need about 56 MiB of downloads).
3. **Test the console font.** On a TTY run `printf 'Tiếng Việt: ơ ư ạ ế\n'`. `FONT=default8x16` probably lacks those
   glyphs (unverified), and a font swap may cost the box-drawing characters the Claude Code UI uses. If it is
   unreadable, run Claude Code in alacritty (Mod+T) inside the niri session instead, which gives up the TTY safety net.
4. **Start the session in the main checkout** (`cd ~/Projects/Tools/dotfiles && claude`). Its saved `/sandbox`
   setting is what lets `stow` write outside the project; run `/sandbox` to confirm.

### Phases

**You must keep plasmashell stopped from the snapshot to the final compare.** Plasma rewrites some checked files itself,
so a Plasma login in between makes `compare` report false positives you cannot tell from real changes. If you do log
into Plasma, take a new snapshot first.

1. **Leave Plasma and snapshot.**
   Switching to a TTY is not enough: plasmashell keeps running and the checker refuses. Log out from the Plasma menu, or
   from a TTY run `loginctl list-sessions`, re-read the id of your graphical session, then
   `loginctl terminate-session <id>` (this closes every app). Then press Ctrl+Alt+F3, log in, `cd` into the main
   checkout, and run `scripts/check-plasma-intact.sh snapshot`. It must exit 0.
2. **Smoke test the compositor with the untouched config.**
   This smoke test separates compositor and hybrid-GPU problems from shell problems before any package changes. From the SDDM
   greeter pick the **Niri** session, look around (Mod+T opens alacritty), and read which render node niri chose:
   `journalctl --user -u niri -b | rg -i 'render|device|drm'`. On 2026-10-24 `renderD129` was the Intel iGPU
   (`/dev/dri/by-path/pci-0000:00:02.0-render`) and `renderD128` the NVIDIA GPU; node numbers are not guaranteed across
   boots. Do not pin `render-drm-device` (a debug option niri calls unstable) unless the log shows the NVIDIA node.
   Log out of niri, return to the TTY (Ctrl+Alt+F3) and run `scripts/check-plasma-intact.sh compare`. Expect exit 0.
3. **Packages.**
   If the sync database is stale, `pacman -S` can answer 404. Then stop, run a full `sudo pacman -Syu` as its own
   step (never `pacman -Sy` alone, which is a partial upgrade), reboot if the kernel or the NVIDIA module changed, and
   start again from phase 1 with a fresh snapshot. Before installing, run `ls /usr/share/xdg-desktop-portal/` and note
   that `kde-portals.conf` is present. Then:
   `sudo pacman -S stow noctalia xwayland-satellite xdg-desktop-portal-gnome`, followed by
   `scripts/check-plasma-intact.sh packages` (exit 0). A read-only `pacman -Sp` dry run on 2026-10-24 listed only
   additions.
4. **Stow both packages, then gate.**
   The niri config starts Noctalia at login, so the Noctalia overlay has to be in place first. Otherwise Noctalia starts
   with `sync_color_scheme = true` and writes the gsettings `color-scheme` user-wide.
   ```sh
   mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.bak.(date +%F)   # fish; in bash use $(date +%F)
   stow -n -v --no-folding -t ~ niri noctalia    # dry run, expect no conflicts
   stow --no-folding -t ~ niri noctalia
   ```
   Run `scripts/check-plasma-intact.sh noctalia` (must exit 0) before logging into niri again. Then run
   `noctalia config validate` with **no argument**, which also reads `~/.local/state/noctalia/settings.toml`; a
   directory argument skips it. On success it always prints `✓ Config is valid`. Pass = exit 0 and no line starting
   with `WARN` or `ERROR`. This also confirms `source = "custom"`; if it is rejected, set `source = "builtin"` and
   `builtin = "Tokyo-Night"` in `config.toml`, and update `test_theme_uses_custom_mizu_dark` in
   `tests/test_noctalia_config.py` to match.
5. **Log into niri with the full config.**
   Do not change the theme in Noctalia's first-run wizard: it writes `~/.local/state/noctalia/settings.toml`, which
   beats the repo config, and Mizu would silently never appear. Check that the clock shows the Japanese date, both
   `eDP-1` and `HDMI-A-1` have a bar, Settings → Appearance → Theme → Palette Inspector shows Mizu, screen share works
   (Discord), and your Discord login survives a restart (`niri-portals.conf` in the system directory names
   `gnome-keyring` for the `Secret` portal and it is deliberately not installed). Log out, return to the TTY, and run
   `scripts/check-plasma-intact.sh compare` and `scripts/check-plasma-intact.sh noctalia`; both must exit 0.
6. **Plasma last.**
   Only then log into Plasma and confirm it behaves normally, and that file dialogs are still the KDE ones.

`--no-folding` keeps `~/.config/niri`, `~/.config/noctalia` and `~/.config/xdg-desktop-portal` real directories so
nothing can write into the repo through a directory symlink. The `stow` flags come from its manual; `stow` is not
installed on the machine that wrote this runbook.

## Rollback

```sh
stow -D --no-folding -t ~ noctalia niri
rm -r ~/.local/state/noctalia ~/.cache/noctalia
mv ~/.config/niri/config.kdl.bak.<date> ~/.config/niri/config.kdl
```

`sudo pacman -Rns noctalia` removes the shell if you also want the package gone. No template files exist to clean up
because all templates are off.

## Measure gaming performance

Compare the same scene on the Plasma session and on niri; there is no benchmark of niri against KDE to rely on.

1. Use the discrete GPU through `prime-run` (it sets `__NV_PRIME_RENDER_OFFLOAD`, `__VK_LAYER_NV_optimus` and
   `__GLX_VENDOR_LIBRARY_NAME`). Steam launch option: `prime-run mangohud %command%`.
2. Log with MangoHud. Keys from `/usr/share/doc/mangohud/MangoHud.conf.example`: `toggle_logging` (default
   `Shift_L+F2`), `output_folder` (required for logging), `log_duration` and `autostart_log` (seconds). The same keys
   can go in `MANGOHUD_CONFIG` as comma-separated `key=value` pairs (MangoHud's README; the installed example does not
   spell out the format).
3. Compare average FPS and 1% lows between the two sessions. Whether MangoHud writes a summary with 1% lows is
   **unverified**; check after the first log.
