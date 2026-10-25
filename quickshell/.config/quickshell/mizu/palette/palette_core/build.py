"""The pure core of the palette tool: a downscaled wallpaper and a color generator in, a tokens document out.

`generate(scheme, mode)` returns the role dict of `noctalia theme` (hex strings). Everything else is arithmetic, so the
whole function is testable without a display. See docs/superpowers/specs/2026-10-25-mizu-shell-design.md section 3.
"""

from __future__ import annotations

from typing import Callable

from . import analysis, color

Rgb = color.Rgb
Generator = Callable[[str, str], dict]

SCHEMA = "mizu.tokens/1"
REQUIRED_ROLES = (
    "primary", "on_primary", "secondary", "secondary_container", "on_secondary_container", "tertiary", "error",
    "surface", "surface_container", "surface_container_low", "surface_container_lowest", "surface_container_high",
    "surface_bright", "surface_dim", "on_surface", "on_surface_variant", "outline", "outline_variant", "scrim",
)

_BASE_ALPHA = 0.62
_MIN_ALPHA = 0.55
_SOFT_MAX_ALPHA = 0.92
_HARD_MAX_ALPHA = 0.97
_ALPHA_STEP = 0.03
_TEXT = 4.5
_NON_TEXT = 3.0
_MARGIN = 0.05  # asked of the fitting loops on top of the target, so hex rounding cannot drop below it
_TINT = 0.25
_ACCENT2_DEGREES = 28.0
_WARNING_HUE = 70.0
_PHONE_SHADOW_ALPHA = 0.17

BLACK: Rgb = (0.0, 0.0, 0.0)
WHITE: Rgb = (1.0, 1.0, 1.0)


def _q(rgb: Rgb) -> Rgb:
    """Round to what a hex string can hold, so decisions are made on the colors that are written."""
    return color.hex_to_rgb(color.rgb_to_hex(rgb))


def _mix(a: Rgb, b: Rgb, t: float) -> Rgb:
    return tuple(x + (y - x) * t for x, y in zip(a, b))  # type: ignore[return-value]


def _grey_of_luminance(lum: float) -> Rgb:
    level = 12.92 * lum if lum <= 0.0031308 else 1.055 * lum ** (1 / 2.4) - 0.055
    return (level, level, level)


def _with_lightness(rgb: Rgb, L: float) -> Rgb:
    _, a, b = color.to_lab(rgb)
    return color.from_lab((L, a, b))


def _best_bw(backdrops: list[Rgb]) -> Rgb:
    """White or black, whichever has the larger worst-case contrast with the backdrops."""
    return max((WHITE, BLACK), key=lambda c: min(color.contrast(c, b) for b in backdrops))


def _min_contrast(foreground: Rgb, backdrops: list[Rgb]) -> float:
    return min(color.contrast(_q(foreground), b) for b in backdrops)


def _fit_against(start: Rgb, backdrops: list[Rgb], minimum: float, direction: str, fallback: Rgb) -> Rgb:
    """Start color nudged in lightness until it reads on every backdrop; the fallback if it cannot."""
    fitted: Rgb | None = start
    for backdrop in backdrops:
        if fitted is None:
            break
        fitted = color.fit_lightness(fitted, backdrop, minimum + _MARGIN, direction)
    if fitted is not None and _min_contrast(fitted, backdrops) >= minimum:
        return _q(fitted)
    return _q(fallback)


def _surface(region: analysis.Region, base: Rgb, dark: bool) -> dict:
    tint = _with_lightness(region.mean, color.to_lab(base)[0])
    housing = _q(_mix(base, tint, _TINT))
    alpha = round(max(_MIN_ALPHA, min(_SOFT_MAX_ALPHA, _BASE_ALPHA + region.busy / 40)), 3)
    # Worst case behind the housing: the brightest cells under a dark housing, the darkest under a light one.
    worst = _grey_of_luminance(region.lum_hi if dark else region.lum_lo)
    return {"region": region, "housing": housing, "alpha": alpha, "worst": worst,
            "backdrop": _q(_mix(worst, housing, alpha))}


def _raise_alpha_until_readable(surface: dict, ink: Rgb) -> None:
    while color.contrast(_q(ink), surface["backdrop"]) < _TEXT and surface["alpha"] < _HARD_MAX_ALPHA:
        surface["alpha"] = round(min(_HARD_MAX_ALPHA, surface["alpha"] + _ALPHA_STEP), 3)
        surface["backdrop"] = _q(_mix(surface["worst"], surface["housing"], surface["alpha"]))


def build(grid: analysis.Grid, generate: Generator, overrides: dict | None, mode: str) -> dict:
    overrides = overrides or {}
    whole = analysis.region_stats(grid, (0.0, 0.0, 1.0, 1.0))
    regions = {name: analysis.region_stats(grid, rect) for name, rect in analysis.REGIONS.items()}
    scheme = analysis.pick_scheme(whole, overrides.get("scheme"))
    mode = analysis.pick_mode(whole, regions["bar"], overrides.get("mode", mode))
    dark = mode == "dark"
    direction = "lighter" if dark else "darker"

    roles = generate(scheme, mode)
    missing = [name for name in REQUIRED_ROLES if name not in roles]
    if missing:
        raise ValueError(f"the generator returned no role named {', '.join(missing)}")
    rgb = {name: color.hex_to_rgb(roles[name]) for name in REQUIRED_ROLES}

    surfaces = {name: _surface(region, rgb["surface_container"], dark) for name, region in regions.items()}

    # Opacity first: more opaque housing hides the picture behind it until the generator's own ink reads.
    for surface in surfaces.values():
        _raise_alpha_until_readable(surface, rgb["on_surface"])
    backdrops = [s["backdrop"] for s in surfaces.values()]

    # One ink for every surface: the generator's, else white or black.
    ink = rgb["on_surface"]
    if _min_contrast(ink, backdrops) < _TEXT:
        ink = _best_bw(backdrops)
        if _min_contrast(ink, backdrops) < _TEXT:  # the backdrops disagree: make every housing as opaque as allowed
            for surface in surfaces.values():
                surface["alpha"] = _HARD_MAX_ALPHA
                surface["backdrop"] = _q(_mix(surface["worst"], surface["housing"], _HARD_MAX_ALPHA))
            backdrops = [s["backdrop"] for s in surfaces.values()]
            ink = _best_bw(backdrops)
    ink = _q(ink)

    ink_muted = _fit_against(rgb["on_surface_variant"], backdrops, _TEXT, direction, ink)
    accent_start = color.hex_to_rgb(overrides["accent"]) if overrides.get("accent") else rgb["primary"]
    accent = _fit_against(accent_start, backdrops, _NON_TEXT, direction, ink)
    accent2 = _q(color.rotate_hue(accent, _ACCENT2_DEGREES))
    on_accent = _q(rgb["on_primary"])
    if color.contrast(on_accent, accent) < _TEXT:
        on_accent = _best_bw([accent])

    outline = _q(_with_lightness(rgb["surface_container_lowest"], 12.0)) if dark else _q(rgb["on_surface"])
    line_role = _mix(rgb["outline"], rgb["primary"], 0.25) if dark else rgb["outline_variant"]
    line = _fit_against(line_role, backdrops, _NON_TEXT, direction, ink)
    shadow = _q(_mix(outline, rgb["scrim"], 0.5)) if dark else _q(_mix(outline, BLACK, 0.3))
    danger = _fit_against(rgb["error"], backdrops, _NON_TEXT, direction, ink)
    warning = _fit_against(color.with_hue(rgb["tertiary"], _WARNING_HUE), backdrops, _NON_TEXT, direction, ink)
    series = [accent] + [_fit_against(rgb[role], backdrops, _NON_TEXT, direction, ink)
                         for role in ("secondary", "tertiary")] + [danger, accent2]
    chip = _q(rgb["secondary_container"])
    if dark:
        L_ch, C_ch, h_ch = color.to_lch(chip)
        if C_ch > 28.0:
            chip = _q(color.clip(color.from_lch_unclipped(min(34.0, max(22.0, L_ch)), 24.0, h_ch)))
    on_chip = _q(rgb["on_secondary_container"])
    chip_dark = color.luminance(chip) < 0.35
    on_chip_dark = color.luminance(on_chip) < 0.35
    if color.contrast(on_chip, chip) < _TEXT or (chip_dark and on_chip_dark) or (not chip_dark and not on_chip_dark):
        on_chip = _best_bw([chip])
    ring = _q(_mix(rgb["surface_bright"], accent, 0.30)) if dark else _q(rgb["surface_container_lowest"])

    def hexed(value: Rgb) -> str:
        return color.rgb_to_hex(value)

    surface_tokens = {}
    contrast_report = {}
    for name, surface in surfaces.items():
        surface_tokens[name] = {
            "housing": hexed(surface["housing"]), "alpha": surface["alpha"], "backdrop": hexed(surface["backdrop"]),
            "ink": hexed(ink), "inkMuted": hexed(ink_muted), "accent": hexed(accent), "onAccent": hexed(on_accent),
        }
        contrast_report[f"{name}.ink"] = round(color.contrast(ink, surface["backdrop"]), 2)
        contrast_report[f"{name}.inkMuted"] = round(color.contrast(ink_muted, surface["backdrop"]), 2)
        contrast_report[f"{name}.accent"] = round(color.contrast(accent, surface["backdrop"]), 2)

    return {
        "schema": SCHEMA,
        "wallpaper": "",
        "scheme": scheme,
        "mode": mode,
        "analysis": {"L": round(whole.L, 1), "chroma": round(whole.chroma, 1), "busy": round(whole.busy, 2)},
        "color": {
            "accent": hexed(accent), "accent2": hexed(accent2), "outline": hexed(outline), "line": hexed(line),
            "shadow": hexed(shadow), "surface": hexed(rgb["surface_container"]),
            "surfaceHover": hexed(rgb["surface_container_high"]), "surfaceDivider": hexed(rgb["outline_variant"]),
            "surfaceRing": hexed(rgb["surface_bright"] if dark else rgb["surface_dim"]), "ring": hexed(ring),
            "ink": hexed(ink), "inkMuted": hexed(ink_muted), "onAccent": hexed(on_accent), "chip": hexed(chip),
            "onChip": hexed(on_chip), "scrim": hexed(rgb["scrim"]),
            "hoverTint": hexed(_mix(rgb["surface_container"], rgb["primary"], 0.12)),
            "paper": hexed(rgb["surface_container_low"]), "danger": hexed(danger), "warning": hexed(warning),
            "series": [hexed(c) for c in series],
        },
        "surface": surface_tokens,
        "phone": {
            "rimHighlight": hexed(rgb["surface_bright"]), "bezel": hexed(rgb["scrim"]),
            "wallLight": hexed(rgb["surface_container_high"]), "wallMid": hexed(rgb["surface_container"]),
            "wallDark": hexed(rgb["surface_container_low"]), "hardware": hexed(rgb["outline_variant"]),
            "lens": hexed(rgb["surface_dim"]), "lensGlint": hexed(rgb["on_surface"]),
            "shadowAlpha": _PHONE_SHADOW_ALPHA,
        },
        "contrast": contrast_report,
    }
