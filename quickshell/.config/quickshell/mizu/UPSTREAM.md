# Upstream and licence

This directory is a fork of the Quickshell config `sekaipop/` from **SekaiPop**
(https://github.com/Blapples/SekaiPop), licensed **GPL-3.0** (see `LICENSE`). SekaiPop itself includes GPL-3.0 code from
end4's dots-hyprland, and credits pCtrade, p3dro and ilyamiro. This fork is therefore GPL-3.0 too. It is an
unofficial derivative, not affiliated with SEGA, Colorful Palette or Crypton Future Media, and it drops Project SEKAI's
identity: palettes, branding, mascots and shaders.

## Fork point

- Source: https://github.com/Blapples/SekaiPop, branch `main`, fetched 2026-10-25 as a tarball (no git history).
- Upstream tree: `4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf` (the root tree of that snapshot, from the GitHub trees API).
- Upstream version file: 1.0.0, changelog head "Unreleased".

To pull an upstream change later, diff the file in a fresh SekaiPop checkout against the same file at this fork point and
apply the difference by hand: most files here are edited (colors are tokens, paths are `mizu`, Hyprland calls are niri).

## What this fork changes

See docs/superpowers/specs/2026-10-25-mizu-shell-design.md section 5 and docs/research/sekaipop-harvest-map.md.
In short: removed the theming scripts, the Hyprland modules, the updater, plugins, hooks, Discord, the dock, welcome,
equalizer, visualizer, Edit Desktop, the gacha lock and the Solar icon set; replaced the theme system by a token adapter
fed by `palette/` (the wallpaper palette tool, our own code); replaced Hyprland APIs by niri's IPC; moved every file the
shell writes under `~/.cache/mizu` and `~/.config/quickshell/mizu-user`.

## Tests left out

Upstream's own tip is "81 pass, 9 fail". Only the tests that cover files this fork keeps are imported. The ones left out
belong to pruned modules: the Hyprland settings, keybinds, display, theme, preset, dock and plugin tests. (The exact list
is filled in when the tests are imported, in the pruning step of the plan.)
