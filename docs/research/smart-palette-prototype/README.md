# Smart palette prototype (throwaway, evidence only)

Question: can image analysis, scheme pick, region sampling and WCAG contrast correction give readable, harmonious
bar / phone / widget colors for every wallpaper, with stdlib Python, ImageMagick and `noctalia theme`?

- `smart_palette_PROTOTYPE.py` is throwaway code. The production tool is rewritten test-first in
  `quickshell/.config/quickshell/mizu/palette/`.
- `state.jsonl` holds the full per-wallpaper state of the run: 30 wallpapers from `~/Pictures/Wallpapers` plus
  Plasma's ColdRipple, **dark mode only**.
- `sheet-dark-mode.jpg` is the contact sheet (surfaces drawn over the wallpaper, with the measured contrast ratios).

Verdict, 2026-10-25 (dark mode):

- All 31 images ended with text contrast >= 4.5:1 and accent contrast >= 3:1 on bar, phone and widget.
- 9 images needed an accent lift. 1 needed more opacity (3q3j6y).
- Grey images (ColdRipple, 3qwx1v, gw2gyq, vpywv3) were correctly sent to `m3-monochrome`. `faithful` had invented a
  red for ColdRipple.

NOT validated by this prototype (the production tool must cover them with tests in both modes):

- light mode and the `auto` choice;
- accent correction against a light backdrop (the prototype only ever lifts L*);
- the +28 degree hue rotation for `accent2` with out-of-gamut colors (the prototype never rotates hue).
