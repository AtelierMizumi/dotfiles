# Azur Lane Live2D as an interactive shell background: research notes

Goal: render an Azur Lane Live2D character on the niri background layer, fully interactive
(mouse tracking, tap reactions, motions), with adjustable camera and smooth (vsync) rendering.

Researched 2026-10-28. Every structural claim about the assets was verified against the actual
repo contents via the GitHub API (see [1] [2]); repo facts come from the READMEs. Items marked
**(unverified)** rest on a single weak source or on the author's own reading and need a spike
before use.

## 0. Source quality

- Asset structure verified directly: folder listing + `model3.json` fetched from the MilkyLan
  repo. Strongest source here. [2]
- Tooling: AssetStudioMod and UnityLive2DExtractor READMEs. [3] [4]
- Prior art: Waifuland README (C++ layer-shell Live2D desktop pet) — describes its own stack and
  limitations, no code review done. [5]
- Compositor behaviour: niri wiki does not document pointer input for background-layer surfaces.
  The layer-shell protocol itself is the only grounding source; treat niri-specific input
  behaviour as **(unverified, needs a spike)**. [6]
- Licensing: Live2D official license pages. [7] [8]

## 1. Assets: what the MilkyLan repo actually contains

The repo is a dump of Azur Lane game files (CN client, package `com.bilibili.azurlane`), ~53 GB.
Four top-level groups: `com.bilibili.azurlane/` (raw game source bundles: `cue`, `live2d`,
`painting`, `spinepainting`), `live2d/` (already-extracted Live2D models), `painting/` (static
art), `spinepainting/` (Spine animated art). Extraction was done with AssetStudio (aelurum
lineage). [1]

Verified structure of one model (`live2d/abeikelongbi_3`):

```
abeikelongbi_3.moc3            2.6 MB   Cubism 3/4 binary model
abeikelongbi_3.model3.json     2.1 KB   standard Cubism model settings
abeikelongbi_3.physics3.json  132 KB    physics (hair/cloth sway)
motions/*.motion3.json         14 files
textures/texture_00.png        3.9 MB   (+ webp variant)
```

The `model3.json` is standard Cubism 3/4 format with:

- Motion groups identical to the in-game secretary interactions: `idle`, `login`, `home`,
  `main_1`, `main_2`, `main_3`, `mission`, `mission_complete`, `mail`, `complete`,
  `touch_head`, `touch_body`, `touch_special`, `wedding`.
- `Groups`: `EyeBlink` (7 parameter ids) and `LipSync` (`ParamMouthOpenY`) — eye blink and
  mouth/lip-sync parameter sets are declared.
- **No `HitAreas`** and **no expressions** (`Expressions: []`). Hit areas must be built by us
  (see §5). Azur Lane models do not ship expressions; everything is motions.

Naming is pinyin of the Chinese ship name (`abeikelongbi` = Abercrombie). Finding a model by
English name needs a mapping table; community ship databases can generate it. **(unverified)**

Repo is ~53 GB, plain git (no LFS — blobs are real). Do not full-clone; use a partial clone:

```sh
git clone --filter=blob:none --no-checkout https://github.com/MilkyLan/AzurLane-Live2d
git -C AzurLane-Live2d sparse-checkout set live2d/abeikelongbi_3   # etc.
```

## 2. Extracting models the repo doesn't have yet

AssetStudioMod (aelurum fork of Perfare's AssetStudio) is the right tool and the same one the
repo itself used. Relevant facts from its README: [3]

- Dedicated **`live2d` export mode**, ported from the UnityLive2DExtractor fork (integrated
  since v0.17.1): exports moc3, model3.json, motion3.json, physics3.json, exp3.json, cdi3.json,
  pose3.json. Options include Unity-version override, assembly folder, motion export mode, and
  a "linear motion segments → Bezier" fix for jerky motions.
- CLI runs on **Linux** via .NET 8/9 runtime; modes: `info`, `dump`, `live2d`, `splitObjects`,
  `animator`; in live2d mode only `--filter-by-name` applies.
- Unity support 1.7 – 6000.2. UnityCN-encrypted bundles are **detection only** — the CN client's
  bundles open fine (the MilkyLan repo exists because of this). [1]

Pipeline for a missing model:

```sh
dotnet AssetStudioModCLI.dll com.bilibili.azurlane/live2d -m live2d \
  -o ~/assets/live2d --filter-by-name <pinyin-name>
```

Cubism version: all Azur Lane models seen are Cubism 3/4 (`.moc3`). No Cubism 2 (`.moc`)
handling needed.

## 3. Rendering paths on niri (wlr-layer-shell)

All paths share the same Wayland foundation: a **background-layer layer-shell surface** per
output, an OpenGL/EGL or WebGL context on it, rendering driven by frame callbacks (compositor
vsync; callbacks stop when the output is off, which pauses rendering for free).

### Path A — native daemon, Cubism Native SDK (C++)

Cubism SDK for Native + wlr-layer-shell + EGL, no windowing toolkit. Prior art exists and works:
**Waifuland** [5] — C++14/CMake, Cubism SDK for Native (Core downloaded separately), raw
`wl_compositor` + `zwlr_layer_shell_v1` + EGL/GLEW, works on any layer-shell compositor. It is
an *overlay desktop pet*, not a wallpaper, but its architecture maps 1:1 onto ours:

- input-region management so only part of the surface takes input (we need the inverse:
  full-surface input on a background layer);
- click zones → motions; drag; scroll-to-zoom; JSON-over-unix-socket IPC with a `*-ctl` CLI
  (switch model/motion/expression, zoom, position, look-at);
- global cursor tracking implemented via **Hyprland-only** IPC — there is no generic Wayland way
  to read the cursor when it is over another surface. niri's IPC does not expose cursor
  position. **(unverified)**

Adaptation work: background layer instead of overlay, camera (pan/zoom/rotate) as first-class
state, fullscreen model placement, per-output surfaces. Highest fidelity (same SDK the game
uses), lowest runtime overhead (~50–100 MB RAM), most work.

### Path B — layer-shell webview + pixi-live2d-display (JS/WebGL)

A small webkit2gtk shell (`gtk4-layer-shell` or raw protocol) hosting an HTML page that loads
[pixi-live2d-display](https://guansss.github.io/pixi-live2d-display/) (PixiJS, WebGL). The
library covers everything the goal needs:

- Cubism 2.1 + 3/4 (needs `live2dcubismcore.min.js` runtime, not bundled);
- `autoFocus` — eyes/head track the pointer via pointer events; `model.focus(x, y)` manual;
- `model.tap(x, y)` / `model.hitTest(x, y)` — hit testing with `hit` events by area name;
- `model.motion(group, index?, priority?)` with IDLE/NORMAL/FORCE priorities;
- `model.expression(id?)`;
- camera = PixiJS container transforms on the model (`x/y`, `scale`, `rotation`, `anchor`) —
  pan/zoom/rotate with easing is trivial; `MotionPreloadStrategy` for preload control.

Caveats: original guansss library targets PixiJS v6/v7 and the Cubism **5.3** Web SDK broke it
(new render pipeline) — **pin Cubism Core ≤ 5.2**; actively maintained forks exist
(`pixi-live2d-display-advanced` for Pixi v7, `untitled-pixi-live2d-engine` for Pixi v8). [9]
Load assets over a tiny local HTTP server (fetch + file:// CORS). webkit2gtk costs ~200–300 MB
RAM for the renderer process. Fastest path to "everything works", easiest camera UI and config
UI; hardest ceiling on raw performance is still far above one model's load.

### Path C — linux-wallpaperengine (CEF)

Renders Wallpaper Engine wallpapers via wlr-layer-shell + EGL; `web` wallpapers run in CEF
windowless off-screen at up to 60 fps, and it **forwards pointer position and clicks** into the
wallpaper. Wallpapers load from a local directory, but the project expects Wallpaper Engine
installed for its assets. [10] Making a WE-format web wallpaper that embeds pixi-live2d-display
is possible but we inherit CEF, WE quirks, and someone else's input pipeline, and camera control
has to live inside the wallpaper. Least custom code, least control. Fine as a fallback / quick
demo.

### Comparison

| | A: native C++ | B: webview + pixi | C: linux-wallpaperengine |
|---|---|---|---|
| Fidelity to in-game look | identical SDK | near-identical | depends on wallpaper |
| Interaction (focus/tap/motions) | build from samples | built-in | via forwarded events |
| Camera control | projection/model matrices | PixiJS transforms | inside wallpaper |
| Perf overhead | lowest | medium (webkit) | medium (CEF) |
| Effort to MVP | weeks | days | days |
| Dependency risk | Core download step, sample license | Core pin ≤5.2 | WE ownership, CEF |

Recommendation: **start with B as the working product, keep A as the long-term target** if
webkit overhead or rendering details bother us. C only for a zero-effort demo.

## 4. niri integration specifics

- Background-layer surface per output; namespace e.g. `mizu-l2d` so niri `layer-rule {}` can
  target it (opacity, `block-out`, etc.). [6]
- `place-within-backdrop` layer-rule exists if a surface should persist across workspaces in
  the Overview; a plain background-layer wallpaper is already per-output and always behind, so
  it is likely unnecessary. **(unverified)**
- **Pointer input to a background-layer surface is governed by its input region per the
  layer-shell protocol, not by the layer** — swaybg et al. set an *empty* input region to pass
  clicks through. A full input region should therefore receive pointer motion/clicks on empty
  desktop areas. niri's exact behaviour is undocumented — needs a 30-minute spike with a
  minimal test client before committing to the design. **(unverified)**
- Cursor tracking scope: the surface only sees the pointer while it is over exposed background
  (windows take over when under them). Global cursor tracking is not available on niri (no IPC
  for it), unlike Hyprland. Consequence: the character tracks the mouse when the desktop is
  visible — which is the case that matters for a wallpaper. **(unverified)**
- Keyboard interactivity stays `none`; fullscreen windows cover everything above the top layer
  except overlay.
- Autostart: `spawn-at-startup` in the niri config; the daemon should re-attach on output
  add/remove (niri reload, monitor changes).

## 5. Interaction design: mapping game behaviour to the model

The game does its own hit-testing and pacing; the extracted model has no hit areas, so:

- **Mouse tracking**: `model.focus(x, y)` on pointer motion (head/eyes follow).
- **Tap zones** (geometric, screen-space, proportional to the model's transformed bounding
  box): upper ~1/4 → `touch_head`; torso → `touch_body`; a configurable region →
  `touch_special`. Persisted per-model in config, with per-zone cooldown.
- **Special-touch gating** (game-gated behaviour): only allow `touch_special` after N
  `touch_body`/`touch_head` within a time window, mirroring the in-game pacing. Configurable.
- **Idle loop**: `model.motion('idle', undefined, FORCE)` on idle timeout; `login`/`main_N`
  groups can be wired to lock/unlock and workspace events via IPC.
- **Lip sync**: `ParamMouthOpenY` is declared; optional voice clips from the game's audio
  (MilkyLan repo does not include audio — the `com.bilibili.azurlane/cue` source bundles would
  need extraction) driven by the LipSync group. Extension, not MVP.

## 6. Camera

"Camera" here is a presentation transform, since Live2D is 2D: pan (x/y offset), zoom (uniform
scale), slight rotation, anchored on the character's face. In path B it is PixiJS container
transforms with easing; in path A it is the model matrix / projection matrix from the Cubism
samples. Camera state should live in the daemon, manipulated by pointer drag/scroll (when in a
"camera mode" gesture) and by IPC (`mizu-l2d-ctl camera zoom 1.2`), so Mizu/noctalia widgets or
keybinds can drive it.

## 7. Performance

- One Cubism model is cheap: a handful of textures (≤ 2048²), hundreds of draw elements,
  motion + physics evaluation per frame in the low single-digit ms. Any GPU handles 60 fps.
- Frame callbacks give vsync and automatic pause (output off / DPMS); optional idle FPS cap.
- VRAM per model ≈ texture size (few MB); RAM: webkit ~200–300 MB (path B) vs ~50–100 MB
  native (path A, per Waifuland's class of app). [5] **(estimate)**
- Only one model at a time; model switching = load new + dispose old.

## 8. Licensing and IP

- **Cubism Core is proprietary** (Live2D Proprietary Software License): embeddable in an
  application, **not redistributable standalone** — do not commit it to the dotfiles; download
  separately at build/setup time. The Cubism Framework (samples-derived code) carries the
  Live2D Open Software License / Cubism SDK Release License terms. [7] [8]
- Individuals and small-scale enterprises are exempt from the paid Release License, so a
  personal dotfiles project is unambiguous. [7]
- **Azur Lane assets are Manjuu/Yongshi / Yostar / Bilibili IP.** Personal, local use only —
  do not publish the extracted models or screenshots of them in the public dotfiles README.
  Keep the assets outside the repo (e.g. `~/.local/share/mizu/l2d/`) and keep the repo to
  code + config. This mirrors the "take principles, not assets" rule from the Persona research.

## 9. Plan

Phase 0 — spike (half a day):
1. Partial-clone one model; open it in Cubism Viewer (web) to confirm it renders standalone.
2. Minimal layer-shell client on niri: background layer, full input region, log pointer
   events — verifies §4 assumptions.
3. Decide path B vs A with that knowledge.

Phase 1 — MVP (path B assumed):
- `mizu-l2d` daemon: webkit2gtk layer-shell surface, local asset server, pixi-live2d-display
  page; idle + focus + tap motions + camera drag/scroll; unix-socket IPC
  (`model switch|list`, `camera`, `motion`, `pause`); per-output surfaces; autostart from niri
  config; config file for hit zones, model choice, camera defaults.

Phase 2 — polish:
- special-touch gating, lock/unlock + workspace event motions, optional voice lipsync,
  camera presets, pause-on-fullscreen detection, and only if justified: port rendering to
  native Cubism SDK (path A).

## Link labels

- [1] [MilkyLan/AzurLane-Live2d](https://github.com/MilkyLan/AzurLane-Live2d) — asset dump repo
- [2] GitHub API contents/tree of `live2d/abeikelongbi_3` incl. raw `model3.json` (fetched 2026-10-28)
- [3] [aelurum/AssetStudioMod](https://github.com/aelurum/AssetStudioMod) — Unity asset extractor, live2d mode
- [4] [aelurum/UnityLive2DExtractor](https://github.com/aelurum/UnityLive2DExtractor) — Live2D extractor (merged into AssetStudioMod)
- [5] [shinkuan/Waifuland](https://github.com/shinkuan/Waifuland) — C++ layer-shell Live2D desktop pet
- [6] [niri wiki: Layer-Shell Components](https://github.com/niri-wm/niri/wiki/Layer%E2%80%90Shell-Components), [Layer Rules](https://niri-wm.github.io/niri/Configuration%3A-Layer-Rules.html)
- [7] [Live2D SDK Release License](https://www.live2d.com/en/sdk/license/)
- [8] [CubismNativeSamples Core LICENSE](https://github.com/Live2D/CubismNativeSamples/blob/develop/Core/LICENSE.md)
- [9] [guansss/pixi-live2d-display](https://github.com/guansss/pixi-live2d-display), [pixi-live2d-display-advanced](https://github.com/GuangChen2333/pixi-live2d-display-advanced)
- [10] [Almamu/linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine)
