# Choosing niri's render GPU (hybrid Intel + NVIDIA laptop)

niri composites on one GPU. A monitor wired to the other GPU gets a cross-GPU copy (extra latency).
On this laptop (Intel Iris Xe drives eDP-1, RTX 3050 drives HDMI-A-1):

| niri renders on | HDMI-A-1 | eDP-1 |
|---|---|---|
| NVIDIA (`renderD128`) | direct | copied |
| Intel (`renderD129`) | copied | direct |

## How it is wired

`config.kdl` ends with `include optional=true "gpu.kdl"`. `gpu.kdl` is generated, not stowed,
and holds `debug { render-drm-device "/dev/dri/renderD128" }`. A missing file means niri picks its default.

## Usage

```
scripts/niri-render-gpu status          # what niri uses now, and which monitor is direct
scripts/niri-render-gpu nvidia          # write gpu.kdl for the NVIDIA node
scripts/niri-render-gpu intel
scripts/niri-render-gpu default         # remove gpu.kdl
```

Changing direction needs a niri re-login. Run the game on the same GPU niri renders on
(`OSU_GPU=auto` in the osu wrappers does this), otherwise the game's frames are copied across GPUs.

## Rollback

`niri-render-gpu default`, re-login. The original config is untouched apart from the single include line.
