# mizu-l2d — Skin dialogue + placement/camera (research, 2026-10-30)

Follow-up to `mizu-l2d-tech-design.md`. Two features requested by the owner to
differentiate from existing web Live2D previews: **skin dialogue bubbles** and
**placement/camera controls** (game's secretary-placement editor UX).

## 1. Skin dialogue

### Data source (verified 2026-10-30)

The nagami data layer does NOT carry dialogue text (skins.json has only
placement/hotspot data). Two community sources verified:

- **`Fernando2603/AzurLane`** → `voiceline.json` (12.7 MB, EN server):
  keyed by numeric skin ID (`"805032"`), each value maps dialogue keys to
  `{link: <ogg url>, line: "<text>"}`. Keys seen: `login`, `home`, `detail`,
  `expedition`, `feeling5`, `unlock`, `mission`, `mission_complete`,
  `main1`..`main4`, `touch`, `touch2`, `headtouch`, `win_mvp`. Text + CV
  audio (`.ogg`, hosted on the same repo). 202/239 of our prefabs confirmed
  covered via a quick mapping; the remaining 37 need a proper parser, not a
  new source.
- **Voice lines: VERIFIED 2026-10-30.** The `link` in voiceline.json points
  to `audio/voiceline/<skinId>/<key>.ogg` on the same repo (content-type
  audio/ogg). Downloaded and checked: real Ogg Vorbis, mono 44.1 kHz
  ~80 kbps, 40–55 KB per line. Coverage across our 202 mapped skins:
  2372 dialogue entries, 99% voiced (198 skins fully voiced, 2 partial,
  2 none); the L2D-relevant triggers are 100% voiced (touch 190/190,
  touch2 179/179, headtouch 73/73, main1–3 ~200/200, login 197, home 182).
  Per-skin audio ≈ 0.5–1 MB → fits on-demand download per chosen model.
  `voicelink.json` in the same repo is the URL-only variant (no need).
  The Azur Lane wiki (biligame) also hosts voice audio but is CN-server +
  HTML scraping; unnecessary given the mirror above.
  - License note: game-derived IP — same "personal, local use only" gate as
    our other Azur Lane assets (D-L2 overlay before any public release).
- **`AzurLaneTools/AzurLaneLuaScripts`** (game Lua dumps):
  - `EN/sharecfg/ship_skin_template_sublist/ship_skin_template_*.lua`
    (20 files): each skin entry has `id`, `painting = "<prefab>"`, `bg`,
    `l2d_animations` — this is the **prefab → skin-ID map** (aersasi_3 →
    805032, lisailiu_3 → 805012, wuqi_3 → 399042; also confirms our bg ids).
  - `EN/sharecfg/ship_skin_words.lua`: `[skinId] = {offset, count}` — index
    into the game's binary word asset (text NOT in the repo).
  - `EN/sharecfg/ship_skin_words_extra.lua`: full text for some (newer)
    skins: `{login: [[100, "text"]], home, main, touch, ...}` where 100 is a
    weight and `|` separates alternate lines. aersasi_3 is NOT here (binary
    asset path) — use voiceline.json instead as the primary source.

### Dialogue-key → motion-group mapping (initial)

| dialogue key | our motion group | game trigger |
|---|---|---|
| `touch` | `touch_body` | body tap |
| `headtouch` | `touch_head` | head pat |
| `touch2` | `touch_special` (verify per skin) | special touch |
| `main1`..`main4` | `main_1`..`main_3` | periodic idle chatter |
| `login` | `login` | login |
| `home` | `home` | return to home |
| `mission` / `mission_complete` | same names | mission notif |
| `mail` | `mail` | mail notif |

Per-skin key sets differ (wuqi_3 has no `headtouch`); missing keys → no
bubble for that trigger.

### UI (matches game, screenshot ref)

Bottom-center translucent dark bar, white bold text, fades after ~3–4 s,
one line per trigger (random pick, avoid repeating the last line). Optional
CV audio playback (ogg) with a mute toggle — nice differentiator for the
wallpaper. On the web viewer: DOM overlay; on the niri daemon: same overlay
drawn by the shell layer.

## 2. Placement / camera

### The nagami site's own placement formula (extracted from its bundle,
chunk `CFlKh342.js`, mode "main" — home screen):

```
uiScale        s = screenHeight / designHeight      // designHeight = 1080
model.scale    = scale / pixelsPerUnit * s          // scale e.g. 53; defaultScale = 52
position.x     = screenWidth/2  + offsetX * s       // offset in design px
position.y     = screenHeight/2 - offsetY * s       // Y inverted (+offset = up)
effectiveOffset = newMainOffset + newMainScale * offset   // if newMainOffset present
```

- `index.json` (data.nagami.moe/live2d/EN/index.json): `designHeight: 1080`,
  `defaultScale: 52`, `dragRateMultipliers {x:5, y:3, damping:0.3}`,
  `skins[prefab] = {hx?, hotspots?, guide?}` — covers all 239 of our prefabs.
- `offset`/`scale`/`newMainOffset`/`newMainScale` from skins.json;
  `profileOffset`/`profileScale` for profile mode; `offset` Y axis is
  inverted (+ = up). Anchor (bottom-center vs center) to be pinned down in
  the calibration pass (R1c.1).
- Site uses pixi-live2d-display **0.5.x** APIs (`fromSync`,
  `idleMotionGroup` option, `pixelsPerUnit` on the model) — a future vendor
  upgrade would replace our 0.4.0 watchdog hack.
- Censored variants are separate models named `<prefab>_hx` (site's
  "Censored" toggle swaps models) — optional future fetch.

### UX (from the game, owner's screenshots)

- Edit mode: drag = move model, wheel = zoom (game uses pinch on mobile),
  reset restores skins.json defaults. Persist per prefab (web: localStorage;
  daemon later: per-monitor config file). Chrome (buttons) on hover only —
  already the PLAN's plan for the wallpaper.
- Layering: bg stays fixed; placement moves the MODEL relative to bg.
  Optional whole-scene camera (pan/zoom) on top for wallpaper framing.

## 3. Proposed plan split

- **R1a.3** (already planned): consume skins.json — now with the exact
  formula above; replace the 90%-height fit.
- **R1a.5 (new)**: placement editor — drag/wheel/reset + per-prefab
  persistence; calibration against the site (R1c.1) folded in.
- **R1d (new)**: dialogue — words pipeline (`fetch-model.sh --words` or
  separate script building `data/words/<prefab>.json` from voiceline.json +
  template map), bubble UI, trigger wiring into the hotspot system, optional
  CV audio.
