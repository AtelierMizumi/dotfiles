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
| `noctalia/.config/noctalia/config.toml`, `palettes/Mizu.json` | Noctalia overlay and the Mizu palette (stow package `noctalia`) |
| `docs/baseline/niri-config.default.kdl` | the untouched default niri config this one started from |
| `scripts/check-plasma-intact.sh`, `scripts/check_noctalia.py` | proof that Plasma is untouched (see Checks) |
| `tests/` | `bash tests/run-all.sh` runs shellcheck, the bash tests and the Python tests |

## Checks

`scripts/check-plasma-intact.sh <command>`, exit 0 means fine, 1 a violation, 2 usage error or refused:

- `snapshot` and `compare` record and compare hashes of `kdeglobals`, `kdedefaults/kdeglobals`, `mimeapps.list`,
  `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini`, `xdg-desktop-portal-kderc`, plus the gsettings `color-scheme` and
  `gtk-theme`. They **refuse to run while `plasmashell` is running** (Plasma rewrites some of these files itself), so
  run them inside the niri session. State lives in `~/.local/state/dotfiles-check`.
- `packages` checks that `xdg-desktop-portal-kde`, `plasma-desktop` and `sddm` are installed with no missing files.
- `noctalia` checks that the repo config and `~/.local/state/noctalia/settings.toml` (the GUI overrides, which win)
  keep every template off and `sync_color_scheme` false.

## Install runbook

Run from the repo root. Commands starting with `sudo` are yours to run; read every pacman prompt and **abort** if it
removes or replaces any `plasma-*`, `kde-*` or `xdg-desktop-portal-kde` package.

1. **Baseline.**
   `sudo pacman -S stow`, then log out of Plasma, log into the **niri** session (default config for now) and run
   `scripts/check-plasma-intact.sh snapshot`. It must exit 0.
2. **Packages.**
   `sudo pacman -S noctalia xwayland-satellite xdg-desktop-portal-gnome`, then `scripts/check-plasma-intact.sh packages`.
   A read-only `pacman -Sp` dry run on 2026-10-24 listed only additions.
3. **niri config.**
   ```sh
   mv ~/.config/niri/config.kdl ~/.config/niri/config.kdl.bak.(date +%F)   # fish; in bash use $(date +%F)
   stow -n -v --no-folding -t ~ niri    # dry run, expect no conflicts
   stow --no-folding -t ~ niri
   ```
   Log into niri again and run `scripts/check-plasma-intact.sh compare`. Then log into Plasma and confirm it behaves
   normally. Check that your Discord login survives a restart in the niri session: `niri-portals.conf` names
   `gnome-keyring` for the `Secret` portal and it is deliberately not installed.
4. **Noctalia.**
   `stow --no-folding -t ~ noctalia`, then `noctalia config validate ~/.config/noctalia`. Pass means **no output at
   all**: it exits 0 even on warnings such as unknown keys. This also settles `source = "custom"`; if it is rejected,
   set `source = "builtin"` and `builtin = "Tokyo-Night"` in `config.toml` and re-run the tests. In niri check that the
   clock shows the Japanese date, both `eDP-1` and `HDMI-A-1` have a bar, and Settings → Appearance → Theme → Palette
   Inspector shows Mizu. Finish with `scripts/check-plasma-intact.sh compare` and `scripts/check-plasma-intact.sh noctalia`.

`--no-folding` keeps `~/.config/niri` and `~/.config/noctalia` real directories so nothing can write into the repo
through a directory symlink. The `stow` flags come from its manual; `stow` is not installed on the machine that wrote
this runbook.

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
