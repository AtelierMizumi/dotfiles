# Mizu L2D: technical design — a native Live2D wallpaper engine for niri

> **Superseded in part (2026-10-29).** The renderer decision D1 (native only, no webview)
> is no longer the plan. The current scope and architecture are in
> `mizu-l2d/docs/SPEC.md` and `mizu-l2d/docs/PLAN.md` (web engine in WebKitGTK 6.0 as the
> planned reference host; native renderer parked; web vs native host pending a measurement
> spike). Sections below are kept as the record of the earlier analysis.

Product: a resident daemon that renders an Azur Lane Live2D character on the niri background
layer, interactive like the in-game secretary screen, with a camera, a semi-transparent Azur
Lane-flavored control UI, and Wallpaper-Engine-class resource discipline.

Supersedes the renderer decision in `azurlane-live2d-render.md`: that note recommended
"webview first, native later" under a speed-to-demo goal. With the goal restated as maximum
hardware efficiency and smoothness, **the product is native (Cubism SDK for Native + C++,
layer-shell, EGL)** and the webview path is demoted to an optional disposable UX prototype.
Design/UI concepts in that note carry over; everything below is written for the native build.

Researched / designed 2026-10-28. Items marked **(unverified)** or **(spike)** need empirical
confirmation before they are load-bearing.

## 0. Decisions

- **D1 — Native renderer.** Cubism SDK for Native (the same SDK the game uses) rendering
  directly into the layer surface via EGL. No webview, no CEF, no second runtime.
- **D2 — One daemon, one render thread, one layer-shell surface per output.** All outputs
  share one process and one EGL context (shared objects across surfaces); each output has its
  own model instance so each screen animates independently.
- **D3 — All UI is drawn inside the same GL scene.** No GTK overlay process, no second
  compositor path, no cross-process input synchronization. Chrome is hover-revealed and
  translucent; the default state of the wallpaper is chrome-free, like the game's secretary
  screen.
- **D4 — Interaction mirrors the game** (focus tracking, tap zones → motion groups, touch
  pacing with special-touch gating). §5 documents the mapping.
- **D5 — IP discipline.** Cubism Core and game assets are downloaded to
  `~/.local/share/mizu/l2d/`, never committed. The dotfiles repo carries code, config, docs
  only. Personal use; nothing published.
- **D6 — The character is a palette source.** Accent colors are extracted from the rendered
  model once per load/placement and published through IPC + a state file, so the shell theme
  follows the active character (extending Mizu's wallpaper-derived palette concept). §8.

## 1. Process model

```
mizu-l2d (daemon)
├─ wayland/          wl_display loop, registry, layer surfaces, seat/pointer
├─ render/           EGL contexts, GL state, Cubism renderer wrapper, damage calc
├─ model/            loader, per-output model instances, motion queue, physics, hit zones
├─ camera/           pose state + easing, placement persistence
├─ ui/               hand-drawn toolbar + ImGui settings drawer (same GL scene)
├─ ipc/              JSON-lines unix socket + mizu-l2d-ctl
└─ config/           TOML load/validate/hot-reload (SIGHUP)
```

- Runs as a **systemd user unit** (`Restart=on-failure`), started from the niri session.
- **Output lifecycle**: one surface per output, created on `wl_output` + `zxdg_output` arrival,
  destroyed on removal; model instance per output torn down with it. Handles `niri msg action
  reload`, monitor hotplug, resolution change (`configure` events resize the `wl_egl_window`).
- **Crash safety**: never `abort()` on GL/model errors per-output — degrade that output
  (character hidden, wallpaper navy) and keep the daemon alive. Corrupt model files are skipped
  with a journald warning; the daemon always holds a "last known good" model path.
- **Signals**: `SIGUSR1` toggle pause, `SIGUSR2` reload config (same as IPC `config reload`).
- **No network** at runtime; socket at `$XDG_RUNTIME_DIR/mizu-l2d.sock` mode 0600.

## 2. Wayland layer

Protocols: `zwlr_layer_shell_v1` (background layer, per output), `xdg_output`, `wl_seat` +
`wl_pointer` (keyboard interactivity `none`), `wp_viewporter` + `wp_fractional_scale_v1` for
HiDPI correctness, `EGL_EXT_swap_buffers_with_damage` + `EGL_EXT_buffer_age` for damage.

Surface setup per output:

- `set_anchor` all four sides, `set_size(0,0)` → compositor gives full output size.
- Input region: **full surface** (we need pointer for interaction). This is the deliberate
  opposite of swaybg. The niri question below decides everything.

| # | Spike (timeboxed) | Question | Fallback if it fails |
|---|---|---|---|
| S1 | 30 min | Does niri deliver pointer enter/motion/button to a background-layer surface with a full input region, when the desktop is exposed? | Use the **bottom** layer instead (same interaction, still behind windows); verify it doesn't interfere with niri's Overview **(spike)** |
| S2 | 1 h | EGL GLES2/GLES3 context + Cubism `CubismRenderer_OpenGLES2` on Mesa + NVIDIA Wayland (client-side vertex arrays are legal in ES2; ES3/desktop-compat behaviour must be checked per driver) | Request desktop-GL **compatibility** profile via `EGL_OPENGL_API` (what the official native samples effectively do with GLFW) |
| S3 | 30 min | Does `niri msg event-stream` expose fullscreen-window state per output (to pause rendering when covered)? | Skip the optimization; keep rendering (cost is bounded, see §9) |
| S4 | 30 min | Are AL moc3 drawable ids semantic (eye/hair), enabling drawable-group palette extraction without per-model rects? | Ship the rect-based eye-band config (§8) |

**Spike results (2026-10-29, niri 26.04, Mesa 26.2.5, Iris Xe):**

- **S1 PASS.** `spikes/s1-pointer/` in the mizu-l2d repo: background-layer surfaces on both
  outputs received `pointer enter` and `motion` (enter=5, motion=794 across scripted
  wlr-virtual-pointer sweeps over exposed desktops). Cross-checked against niri source
  (`contents_under` → `layer_surface_under`): background/bottom get pointer input per their
  input region; excluded only while the Overview is open. No fallback needed. Two
  implementation pitfalls recorded in the spike source: (1) attach the `wl_seat` listener at
  bind time or the capabilities event is dispatched to nobody; (2) the generated
  layer-shell header names a parameter `namespace` — needs a macro shim to include from C++.
- **S2 PASS.** GLES3 context via `EGL_PLATFORM_WAYLAND_EXT`; `EGL_EXT_buffer_age` and
  swap-with-damage both present; frame callbacks drive rendering at panel rate (137 Hz
  measured on the 144 Hz panels). The Cubism-GLES2-renderer part of S2 is checked when the
  SDK lands; nothing so far suggests the desktop-compat fallback will be needed.
- **S3 open** — not yet attempted (optional optimization only).
- **S4 PASS.** `strings` on `abeikelongbi_3.moc3` shows semantic drawable names
  (`Eyes`, `EyesWhite`, `EyeLashL/R`, `HairFront`, `Face`, `Body`, `UpperBody`…) — palette
  extraction can render named groups; the `eye_rect` config becomes an override, not a
  requirement.

**Frame lifecycle** (per output): block on `wl_display_dispatch` → on frame callback:
`dt` → update motion/physics/camera/UI state → compute model bbox damage (old ∪ new) →
`eglSwapBuffersWithDamage(damage)` → set `wl_surface.damage_buffer` same region → commit.
With the model occupying ~⅓ of the screen, the compositor only recomposites that region per
frame — this is the single most important "smoothness for the rest of the desktop" property,
so **full-surface damage is a bug**, asserted in debug builds.

**Pacing**: render on every frame callback while `interactive` (pointer over surface, motion
playing, camera easing). After `quiet-time` (default 5 s), drop to `idle-fps` (default 30) by
skipping callbacks; on interaction, resume full vsync with the eased camera hiding the step.
Output off ⇒ frame callbacks stop ⇒ we block, ~0% CPU for free.

## 3. Renderer

GL setup: one EGL context per process, marked shareable, made current to each output's
surface in turn (single render thread). Request GLES3 → GLES2 → desktop-compat (S2 decides the
winner; the code keeps all three behind one flag).

Cubism renderer configuration (all documented knobs, chosen for a wallpaper):

- **Masking: low precision (stencil-based)** rather than per-drawable FBO masks
  (`UseHighPrecisionMask=false`) — avoids FBO ping-pong; visual difference is not perceptible
  for desktop viewing. Only re-enable per-model if a specific model shows mask artifacts.
- **Premultiplied alpha: on**, with textures converted at load (one CPU pass per texture, then
  freed) — cleaner blending, one less shader branch.
- **Mipmaps + anisotropy 4×–8×**: generated at load; makes zoomed-out and oblique view stable.
- **Textures: RGBA8.** BC7 compression is a non-goal (one model ≈ 16–64 MB VRAM is cheap);
  revisit only if a model-carousel mode ships.
- **Texture pool keyed by path hash**: multiple outputs render the same model → one set of GL
  textures, shared via the context; CPU-side decoded copies are freed after upload.

Draw call reality check: ~100–300 drawables/model, tiny triangle strips, ≤ 3× overdraw over
the model's bbox. At 4K worst case this is a few MP of fill per frame — trivial for any GPU
from the last decade. **Do not** pre-optimize the Cubism renderer (VBO rewrites etc.) before
measuring; the known hot path is small and the framework code is licensed — keep our diff to
it near zero.

Perf instrumentation is built in from day one (§10) so optimization is always measured.

## 4. Model runtime

**Loading** (worker thread, per model): parse `model3.json` → moc3 → **all 14 motions parsed
eagerly** (~3 MB RAM total; removes first-tap hitch) → physics → textures async. UI shows
nothing meanwhile (wallpaper just stays navy for <1 s).

**Instances**: one `ModelInstance` per output = own motion queue, physics, blink, focus
controller, camera pose; shares moc, motions, textures. Placement/zoom is per
`(model, output)` and persisted to `$XDG_STATE_HOME/mizu-l2d/state.toml`.

**Model switch**: load new fully (off-thread) → crossfade ~250 ms (render both during fade) →
dispose old in order: motion queue → drawables → physics → moc → textures (pool refcount) →
config cache. A leak here is the classic wallpaper-engine bug class; the perf command asserts
VRAM/RSS return to baseline ± ε after a switch loop of 10 iterations.

**Camera**: state = `{offset, scale, rot}` with a target pose; easing is exponential decay
toward target, `k ≈ 10` (`current += (target − current) · (1 − e^(−k·dt))`). Wheel = zoom
toward cursor (keep the world point under the cursor fixed). Drag = pan. Double-click = reset
to the model's default framing (character anchored lower-center, like the game office view).
Camera transform lives **outside** the Cubism model matrix (screen-space presentation), so it
composes cleanly with hit-testing (§5).

**Screen ↔ model coordinate chain**: screen px → world (camera inverse) → model local
(model matrix inverse) → moc canvas units (from moc3 canvas info). All three transforms are
composed once per frame into a single matrix pair; hit-testing and the UI reuse it. Unit-tested
(round-trip + known points), because every interaction bug will live here.

## 5. Interaction: mapping the game

The extracted models carry the game's motion groups but **no HitAreas** (the game did its own
hit-testing), so zones are ours — geometric, defined in **moc-canvas-normalized coordinates**
(resolution- and placement-independent), configurable per model, editable visually (§6).

| Game behaviour | Implementation |
|---|---|
| Secretary's eyes/head follow cursor | pointer motion → `SetDragging` via Cubism `FocusController` (built-in smoothing = natural look) |
| Tap head / body | zone hit → `motion("touch_head" / "touch_body", random, FORCE)` |
| Special touch (gated in game) | counter: N soft touches within T seconds unlock `touch_special` once; then reset. Configurable, default ≈ game pacing |
| Hold to keep petting | press ≥ 600 ms on a zone re-triggers its motion (cooldown bypass), like holding in game |
| Idle | `idle` group loops; any tap overrides with fade; idle resumes after motion end |
| Login / return | `login` group on daemon start and after unlock (from niri lock state **(unverified)** — else on resume from DPMS off) |
| Wedding skin behaviour | `wedding` group exposed via config/IPC if the model has it |
| Reaction without voice | small translucent speech-bubble near the head with configurable lines (AL flavor, no audio dependency) |

Touch pacing state machine (per instance): `IDLE → SOFT(n) → (threshold) → SPECIAL_READY →
SPECIAL → IDLE`, with per-zone cooldowns (`head 4 s, body 6 s, special 30 s` defaults). All
numbers in config; the settings UI exposes them.

**Lipsync hook** (Phase 3): `ParamMouthOpenY` is declared in every model; motion→audio-file
mapping in config, driven through the LipSync group. The MilkyLan repo has no audio; voice
would come from extracting `com.bilibili.azurlane/cue` bundles — separate pipeline, not MVP.

## 6. UI — semi-transparent, Azur Lane flavor

Principles: the wallpaper's default state has **zero chrome** (like the game's office screen);
controls appear on pointer hover over the desktop, fade out after 3 s of inactivity; everything
is drawn in the same GL pass — translucency is a color, not a compositor feature. Styling
targets the game's visual language: deep navy glass panels, thin gold hairlines and accents,
slanted parallelogram buttons, circular gold-rimmed icon buttons, horizontal card carousel for
skins. Exact palette is **sampled from in-game screenshots during implementation** (token
table below is placeholder); text in the user's locale, minimal labels.

**Chrome inventory:**

1. **Hover toolbar** — bottom-right vertical stack of 3–4 circular, gold-rimmed,
   α≈0.55 translucent buttons (mirrors the game's stacked menu column): position/move, camera
   reset, model switcher, settings. Hand-drawn GL (a few drawlist primitives + icon font
   subset — Material Symbols); no UI framework in this path. Hover → α 0.8, 150 ms ease.
2. **Position mode** — click move → character follows the pointer as a semi-transparent ghost;
   scroll = scale; snap guides (center-x, baseline-y, thirds) appear as 1 px gold lines;
   confirm = gold check, cancel = X (the game's confirm/cancel pair). Persisted per
   `(model, output)`.
3. **Model carousel** — bottom sheet, α≈0.8: horizontal cards (slanted frames) with character
   art thumbnails sourced from MilkyLan `painting/` webp art mapped by the same pinyin key;
   click to switch with crossfade. "Like the game's secretary selection".
4. **Settings drawer** — right-side panel α≈0.85, themed **ImGui** (this is the only ImGui
   surface; custom widgets render the slanted/parallaxed AL look via drawlists):
   motion test buttons (each group), hit-zone editor (drag rectangles over a dimmed model),
   interaction toggles + pacing sliders, performance (idle fps, quiet time), appearance
   (toolbar opacity, preset), and a per-model **parameter sliders** panel (config-declared
   param ids — manual posing, the "customization" equivalent Wallpaper Engine wallpapers have).
5. **Toasts** — small translucent bubble near the character for gated-special feedback or
   model errors; 2 s lifetime.

**Style tokens** (fill at implementation): `--al-navy`, `--al-navy-2`, `--al-gold`,
`--al-ink`, `--al-glass` (α), skew angle (−12°), corner radius, hairline width. Two presets:
`office` (game-like stacked circles, default) and `glass` (modern pill, for users who want it
subtler).

**Keybinds** (niri config, via ctl): hide/show chrome, camera reset, next model, pause.
Screenshots: chrome auto-hides with the pointer away, and `mizu-l2d-ctl ui hide --sticky`
forces it off.

## 7. IPC & control

JSON-lines over the unix socket; one request → one response; optional event subscription
(motion started, model switched) for a future noctalia/quickshell bar widget.

```
mizu-l2d-ctl model list|show <name>|next
mizu-l2d-ctl camera reset|zoom <k>|pos <x,y>
mizu-l2d-ctl motion <group> [index]
mizu-l2d-ctl ui show|hide|mode <office|glass>
mizu-l2d-ctl palette [--reextract]
mizu-l2d-ctl perf [--window 30s]
mizu-l2d-ctl config reload
```

Config (TOML, hot-reloadable):

```toml
[model]
path = "~/.local/share/mizu/l2d/abeikelongbi_3"
on_login = "login"

[interaction]
tracking = true
special_after = 4
special_window_s = 20
cooldown = { head = 4.0, body = 6.0, special = 30.0 }
[interaction.zones.head]
rect = [0.30, 0.05, 0.70, 0.35]   # normalized moc-canvas rect
motion = "touch_head"

[camera]
zoom = 1.15
offset = [0.0, -0.12]

[render]
idle_fps = 30
quiet_time_s = 5
```

## 8. Palette extraction — accent colors from the character

Goal: the active character drives the shell accent palette, the way wallpaper themes do —
switching the secretary recolors the desktop. The daemon computes a small palette struct and
publishes it; Mizu consumes it like any other palette source (outranking the static
wallpaper-derived palette while a character is active).

**Data sources, in decreasing order of fidelity:**

1. **Rendered model (primary).** After load, render the model into a 256² offscreen FBO using
   the current camera/placement transforms, read back once, cluster. Weighting is by *visible
   pixels*, so occluded parts and unused texture areas never vote — the failure mode of naive
   texture analysis. One-time ≈ 50 ms on the loader thread; zero steady-state cost.
2. **Drawable-subset render (semantic).** Same pass, but rendering only drawables whose
   centroid falls inside a configured rect (e.g. an eye band) → the exact eye color. This
   reuses the hit-zone rect machinery and the screen↔model transform chain from §4.
3. **Texture-only (fallback / preview).** Alpha-weighted clustering of the texture PNGs with
   no GL involvement — good enough for swatches in the model carousel before a model loads,
   advisory only (includes occluded parts).

**Algorithm.** sRGB → linear → OKLab (Ottosson) for perceptual distance; k-means with
k ≈ 6–8 over the ~65k downsampled pixels (10 iterations — negligible CPU); discard clusters
that are near-neutral (low chroma), extreme luminance, or inside the anime skin-hue band
**(unverified threshold — tune over 3+ models)**; rank survivors by chroma × coverage.
Top cluster = `accent`, runner-up = `accent2`; derive `on_accent` (black/white by contrast)
and a text-safe variant of each (lightness adjusted in OKLCh to ≥ 4.5:1 against the navy
glass panels). Cache per `(model content hash, placement)` in the state dir.

**Triggers**: model load, placement change (not camera pan — palette is placement-independent
enough that only the placement rescale matters), explicit IPC request.

**Publishing:**

- `mizu-l2d-ctl palette` returns the JSON; a `palette` IPC event fires on change (200 ms
  debounce);
- the daemon writes `$XDG_STATE_HOME/mizu-l2d/palette.json`; a systemd **path unit** runs the
  dotfiles palette-apply script (same pattern as the existing wallpaper pipeline), feeding
  noctalia/quickshell theme, terminals, etc. Shell theme transitions crossfade 200 ms.

**UI tie-in:** swatch strip in the settings drawer (with "re-extract" button); optional
*accent-follows-character* mode recolors the toolbar hover glow and placement snap guides.
AL gold remains the base identity of the chrome — the extracted accent decorates; it does not
replace.

```toml
[palette]
enable = true
source = "auto"                       # auto | eye | frame
eye_rect = [0.40, 0.18, 0.60, 0.30]   # moc-canvas normalized, per-model override
```

Spike **S4** (30 min): dump drawable ids/centroids for 2–3 models — if drawable names are
semantic (eye/hair…), the eye rect becomes optional and hair/outfit accents come free; if
opaque ids, the rect-based approach ships as designed.

## 9. Project layout & third-party

- Code lives in its own repo (`~/Projects/Tools/mizu-l2d`); dotfiles carry only the config,
  autostart, keybinds, and these docs.
- Third-party fetch script (`scripts/fetch-thirdparty.sh`) pins and downloads: **Cubism Core +
  Framework** (proprietary/license-encumbered — never committed; the script verifies the
  version hash), stb_image, toml++, yyjson, Dear ImGui. Framework sample-derived files keep
  their Live2D headers verbatim.
- Deps from Arch repos: wayland, wayland-protocols, libxkbcommon, mesa/EGL, glm, systemd.
- `systemd --user` unit + install target; `niri` config gains `spawn-at-startup` + keybinds
  via the dotfiles.

## 10. Performance engineering

Budgets (per frame, per output, 60 Hz → 16.6 ms):

| Metric | Budget | Enforced by |
|---|---|---|
| CPU: update (motion+physics+camera+UI) | ≤ 2 ms | `perf` p95 |
| CPU: draw submission | ≤ 2 ms | `perf` p95 |
| Damage area | ≤ model bbox ∪ old bbox | debug assert |
| RSS resident | ≤ 120 MB | perf + systemd status |
| VRAM: textures + swapchain | ≤ 150 MB | pool accounting |
| Model switch leak | ± 2 % of baseline after 10-switch loop | switch-loop test |
| Idle CPU (30 fps, no interaction) | ≤ 1.5 % of one core | perf |

Levers, in the order we'd reach for them: damage bbox correctness (compositor cost), idle fps
ramp, mask precision mode, premultiplied alpha, mipmap/aniso at load. **Deliberately not
pursued**: BC7 textures, VBO rewrite of the Cubism GLES2 renderer, multi-threaded rendering
(one model per output is not enough work to justify the complexity; revisit only if two large
models ever show a problem).

**Verification**: `mizu-l2d-ctl perf` (p50/p95/p99 frame times, fps, damage area, RSS/VRAM,
over a rolling window); `--screenshot file.png` (glReadPixels pre-swap) for visual regression
of the UI chrome and zones; headless smoke run (wlroots headless backend) in CI-style checks;
ASan/UBSan build target. The "mượt" claim is only ever made with these numbers attached.

## 11. Risks & open questions

1. ~~**S1 niri background input**~~ — **resolved PASS** (2026-10-29, see §2 results).
2. ~~**S2 GL profile**~~ — **resolved PASS** for context creation; the Cubism-GLES2-renderer
   check completes when the SDK is wired in.
3. **S3 fullscreen-cover detection** — optional optimization only, still open.
4. **Motion quality** — AssetStudio-exported motions occasionally benefit from the
   "linear→Bezier" re-export; keep the re-export path documented.
5. **Framework license scope** — sample-derived code keeps Live2D headers; our additions are
   separable; Core is downloaded, not distributed. Re-read the Release License before ever
   sharing a build with anyone.
6. **Painting-art mapping for the carousel** — pinyin↔ship mapping table needs a data source
   (community ship DB); if none is clean, ship the carousel with moc `Name` only.
7. **Palette thresholds** — the skin-hue band and chroma cutoffs are the only "hand-tuned"
   numbers in the palette pipeline; tune across 3+ models using `--screenshot` + swatch
   comparisons, and let per-model config override. S4 resolved: drawable names are semantic,
   so group-based extraction is available as the primary source.

## 12. Roadmap

- **P1 — playable core**: ~~S1–S3 spikes~~ (done 2026-10-29: S1/S2/S4 PASS, S3 open);
  ~~daemon skeleton (surfaces, EGL, frame loop, damage)~~ (done: running at panel rate with
  damage discipline, IPC `model|camera|perf`, config, ctl); remaining: model load + idle +
  focus tracking + tap zones + camera-on-model; systemd unit install; perf numbers published.
  *Acceptance*: all perf gates green on the target machine; a tap on head/body plays the right
  motion with correct pacing.
- **P2 — product**: settings drawer + zone editor + model carousel; special gating + toasts;
  state persistence; model-switch leak test; quiet-time fps ramp; lock/login motion hook;
  palette extraction + publishing (state file + path unit + ctl).
  *Acceptance*: a new model can be added by dropping a folder + minimal config, no code; the
  shell accent visibly follows the active character.
- **P3 — delight**: voice lipsync (audio extraction pipeline), parameter sliders panel,
  accent-follows-character chrome mode, noctalia widget (palette + status + quick camera),
  battery-aware idle fps, day/night dimming.

## 13. Pivot (2026-10-29): port the web viewer instead of a native renderer

The goal is restated: **port the azurlane.nagami.moe Live2D viewer to an
interactive wallpaper**, not author a native Cubism renderer. Two findings
drove this.

First, browser inspection of the site (SvelteKit + `live2dcubismcore.min.js`,
i.e. Cubism Web SDK) revealed that everything hard about the viewer is a
**public, data-driven layer** — no frontend source needed:

- `azlassets.nagami.moe/EN/live2d/<prefab>/` — model3.json / moc3 / textures /
  motions / physics / `animator.json`. Same extraction lineage and naming as
  MilkyLan/AzurLane-Live2d (aersasi_3 = Alsace), so both sources are
  interchangeable.
- `data.nagami.moe/live2d/EN/`:
  - `l2d_mapping.json` — shipId → EN/CN/JP names + skins (prefab, bg id).
    Solves the pinyin→name mapping problem for free.
  - `skins/<prefab>.json` — per-skin rendering + interaction config: screen
    `offset`/`scale`, `actions` (motion groups), `paraRange` (mouse-follow
    clamps), and **`drags` (66 entries for Alsace = the "66 hotspots")**: each
    entry names a part (`TouchIdle1`…), a trigger (`touch_idle1` motion),
    idle indexing, smoothing and ignore lists. This is the in-game touch
    system, data-encoded.
  - `index.json`, `name_code.json`, `assistant.json`, `changelog`.
- `azlassets.nagami.moe/EN/bg/<bg_id>.png` — full background images.
- `animator.json` — a Mecanim-like state machine (layers, states, loop flags)
  driving which motions play and how they hand over.

Second, the native renderer built on Cubism SDK for Native reached "draws
something" but its rest pose renders exploded (correct textures, scrambled
part layout — see mizu-l2d repo debug notes), an unresolved bug. With the web
path, every asset is already proven in WebGL by the site itself.

**Decision (supersedes D1):** the wallpaper becomes a **webview layer-shell
surface** hosting a minimal viewer page built on the public data layer:

- R1 — viewer web MVP (regular browser first): local mirror of assets +
  data (scripts/fetch-model.sh now mirrors from the nagami CDNs), a static
  page with pixi-live2d-display or the Cubism Web Framework, rendering
  model + BG, consuming `skins.json` for offset/scale/paraRange and
  `drags` for hit→motion, idle poses via `animator.json`.
- R2 — embed: webkit2gtk + layer-shell (background layer) in the existing
  mizu-l2d daemon skeleton (its Wayland/input/IPC/perf work carries over);
  camera + model switching over the existing JSON-lines IPC; page talks to
  the daemon over a small JS bridge.
- R3 — Mizu chrome (hover toolbar, model carousel from `l2d_mapping.json`,
  palette extraction now reading rendered WebGL pixels via the page).

The native Cubism path is parked, not deleted: the daemon skeleton (spikes
S1/S2/S4, IPC, damage discipline) remains the R2 shell, and the renderer work
is documented for a future return. Known-asset note: newer skins (Alsace et
al.) carry 40–70 motions including large `touch_idle*` sets on the nagami CDN;
older models may have no `skins.json`/`animator.json` (abeikelongbi_3) and
fall back to basic touch_head/body/special.

Open reference viewers: alg-wiki/AzurLaneL2DViewer (AGPL; forks by yukariin /
lesslsmore; Cubism-2 era, no BG) — useful for motion-group conventions only.
The nagami frontend itself is not publicly hosted (checked GitHub user and
repo search), so R1 does not depend on it.

> Execution continues from the project repo's own plan, which supersedes this
> document for day-to-day work: `~/Projects/Tools/mizu-l2d/docs/PLAN.md`
> (v2, post-pivot) + `STATUS.md` ledger + `CLAUDE.md` agent rules.
