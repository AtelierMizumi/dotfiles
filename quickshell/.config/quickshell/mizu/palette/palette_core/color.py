"""Color math for the palette tool: sRGB, WCAG contrast, CIELAB / LCh (D65), hue rotation and lightness fitting.

Colors are (r, g, b) tuples of floats in [0, 1], gamma-encoded sRGB, unless a name says "unclipped".
"""

from __future__ import annotations

import math

Rgb = tuple[float, float, float]

# sRGB (D65) <-> XYZ, standard matrices; the white point is the sum of the first matrix's rows.
_TO_XYZ = (
    (0.4124564, 0.3575761, 0.1804375),
    (0.2126729, 0.7151522, 0.0721750),
    (0.0193339, 0.1191920, 0.9503041),
)
_FROM_XYZ = (
    (3.2404542, -1.5371385, -0.4985314),
    (-0.9692660, 1.8760108, 0.0415560),
    (0.0556434, -0.2040259, 1.0572252),
)
_WHITE = (0.95047, 1.0, 1.08883)
_EPS = 216 / 24389
_KAPPA = 24389 / 27
_GAMUT_TOLERANCE = 1e-4
_CHROMA_STEP = 2.0
_LIGHTNESS_STEP = 2.0
_LIGHT_LIMIT = 96.0
_DARK_LIMIT = 8.0


def hex_to_rgb(value: str) -> Rgb:
    digits = value.lstrip("#")
    return tuple(int(digits[i:i + 2], 16) / 255 for i in (0, 2, 4))  # type: ignore[return-value]


def rgb_to_hex(rgb: Rgb) -> str:
    return "#" + "".join(f"{max(0, min(255, int(v * 255 + 0.5))):02x}" for v in rgb)


def _linear(v: float) -> float:
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def _gamma(v: float) -> float:
    # The linear branch also covers negative values, which only occur for unclipped out-of-gamut colors.
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def luminance(rgb: Rgb) -> float:
    r, g, b = (_linear(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: Rgb, b: Rgb) -> float:
    """WCAG 2 contrast ratio, 1 to 21."""
    la, lb = luminance(a), luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def to_lab(rgb: Rgb) -> tuple[float, float, float]:
    lin = [_linear(v) for v in rgb]
    xyz = [sum(m * c for m, c in zip(row, lin)) / w for row, w in zip(_TO_XYZ, _WHITE)]
    f = [t ** (1 / 3) if t > _EPS else (_KAPPA * t + 16) / 116 for t in xyz]
    return 116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])


def from_lab_unclipped(lab: tuple[float, float, float]) -> Rgb:
    L, a, b = lab
    fy = (L + 16) / 116
    f = (fy + a / 500, fy, fy - b / 200)
    xyz = [(t ** 3 if t ** 3 > _EPS else (116 * t - 16) / _KAPPA) * w for t, w in zip(f, _WHITE)]
    lin = [sum(m * c for m, c in zip(row, xyz)) for row in _FROM_XYZ]
    return tuple(_gamma(v) for v in lin)  # type: ignore[return-value]


def clip(rgb: Rgb) -> Rgb:
    return tuple(max(0.0, min(1.0, v)) for v in rgb)  # type: ignore[return-value]


def from_lab(lab: tuple[float, float, float]) -> Rgb:
    return clip(from_lab_unclipped(lab))


def in_gamut(rgb: Rgb) -> bool:
    return all(-_GAMUT_TOLERANCE <= v <= 1 + _GAMUT_TOLERANCE for v in rgb)


def to_lch(rgb: Rgb) -> tuple[float, float, float]:
    L, a, b = to_lab(rgb)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360.0


def from_lch_unclipped(L: float, C: float, h: float) -> Rgb:
    radians = math.radians(h)
    return from_lab_unclipped((L, C * math.cos(radians), C * math.sin(radians)))


def _fit_chroma(L: float, C: float, h: float) -> Rgb:
    """The color with this lightness and hue and the largest chroma <= C (in steps) that fits in sRGB."""
    chroma = C
    while chroma > 0:
        candidate = from_lch_unclipped(L, chroma, h)
        if in_gamut(candidate):
            return clip(candidate)
        chroma -= _CHROMA_STEP
    return clip(from_lch_unclipped(L, 0.0, h))


def rotate_hue(rgb: Rgb, degrees: float) -> Rgb:
    """Rotate the hue in LCh at the same L*, reducing chroma until the result is inside the sRGB gamut.

    Clipping a channel would shift the hue, so chroma gives way instead.
    """
    L, C, h = to_lch(rgb)
    return _fit_chroma(L, C, (h + degrees) % 360.0)


def with_hue(rgb: Rgb, hue: float) -> Rgb:
    """The color with the lightness of rgb and the given LCh hue, chroma reduced until it fits in sRGB."""
    L, C, _ = to_lch(rgb)
    return _fit_chroma(L, C, hue % 360.0)


def fit_lightness(rgb: Rgb, backdrop: Rgb, minimum: float, direction: str) -> Rgb | None:
    """Move L* in steps of 2 ('lighter' or 'darker') until the contrast with the backdrop reaches the minimum.

    Returns the color unchanged when it already meets the minimum, and None when L* 96 (lighter) or 8 (darker) is
    passed without reaching it. Hue is kept; chroma gives way at the gamut edge.
    """
    if direction not in ("lighter", "darker"):
        raise ValueError(f"direction must be 'lighter' or 'darker', not {direction!r}")
    if contrast(rgb, backdrop) >= minimum:
        return rgb
    L, C, h = to_lch(rgb)
    step = _LIGHTNESS_STEP if direction == "lighter" else -_LIGHTNESS_STEP
    while True:
        L += step
        if (direction == "lighter" and L > _LIGHT_LIMIT) or (direction == "darker" and L < _DARK_LIMIT):
            return None
        candidate = _fit_chroma(L, C, h)
        if contrast(candidate, backdrop) >= minimum:
            return candidate
