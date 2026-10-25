# dotfiles: niri + Noctalia rice next to KDE Plasma

Install this rice from a TTY with Plasma logged out. Follow the "Install runbook" in README.md phase by phase; every
phase ends on a gate command that must exit 0 before the next phase starts.

## Rules
- Hand every `sudo` line to the user, who runs it in a second VT. Read pacman's output afterwards.
- Run `scripts/check-plasma-intact.sh snapshot` and `compare` only while plasmashell is stopped; the script refuses otherwise.
- Keep Plasma's files (`kdeglobals`, `mimeapps.list`, `gtk-*`, `xdg-desktop-portal/*`) byte-identical. A `CHANGED:` line from `compare` stops the install.
- Stow from the main checkout, never from a worktree under `.claude/worktrees/`.
- Treat Noctalia's `sync_color_scheme`, its built-in and community templates and `gnome-keyring` as off limits
  (README.md "Rules"). The only allowed template renders into `~/.config/niri/` with no hook.

## Where am I?
Read-only commands that tell the current phase:

| Question | Command |
|---|---|
| Is Plasma running? | `pgrep -x plasmashell` |
| Is stow installed? | `pacman -Q stow` |
| Is a baseline snapshot taken? | `ls ~/.local/state/dotfiles-check/files.sha256` |
| Are the packages installed? | `pacman -Q noctalia xwayland-satellite xdg-desktop-portal-gnome` |
| Is the config stowed? | `readlink ~/.config/niri/config.kdl ~/.config/noctalia/config.toml ~/.config/xdg-desktop-portal/niri-portals.conf` |
| Do the tests pass? | `bash tests/run-all.sh` |

## Failure notes
- pacman 404 on a stale sync database: stop, run `sudo pacman -Syu` as its own step, then take a new snapshot (README.md).
- `compare` reports `CHANGED:` for a file after a Plasma login: that is Plasma rewriting it. Take a new snapshot and redo the phase without logging into Plasma.
