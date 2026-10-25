"""Image analysis for the palette tool: regions of a downscaled wallpaper, scheme pick and mode pick."""

from __future__ import annotations

import math
from dataclasses import dataclass
from functools import cached_property

from . import color

Rgb = color.Rgb

# Where each surface sits on a screen, as fractions (x0, y0, x1, y1) of the wallpaper.
REGIONS = {
    "bar": (0.0, 0.0, 1.0, 0.045),
    "phone": (0.36, 0.45, 0.64, 1.0),
    "widget": (0.03, 0.10, 0.28, 0.40),
}

_MONOCHROME_BELOW = 7.0
_SOFT_BELOW = 16.0
_LIGHT_IMAGE_L = 66.0
_LIGHT_BAR_L = 70.0


@dataclass(frozen=True)
class Region:
    mean: Rgb
    L: float
    chroma: float
    busy: float
    lum_lo: float  # WCAG luminance, 5th percentile
    lum_hi: float  # WCAG luminance, 95th percentile


class Grid:
    """A downscaled wallpaper: width x height sRGB cells in row-major order."""

    def __init__(self, width: int, height: int, pixels: list[Rgb]):
        if len(pixels) != width * height:
            raise ValueError(f"{len(pixels)} pixels for a {width}x{height} grid")
        self.width = width
        self.height = height
        self.pixels = pixels

    @cached_property
    def labs(self) -> list[tuple[float, float, float]]:
        return [color.to_lab(p) for p in self.pixels]

    @cached_property
    def luminances(self) -> list[float]:
        return [color.luminance(p) for p in self.pixels]


def region_stats(grid: Grid, rect: tuple[float, float, float, float]) -> Region:
    x0, y0, x1, y1 = rect
    xs = range(int(x0 * grid.width), max(int(x0 * grid.width) + 1, int(x1 * grid.width)))
    ys = range(int(y0 * grid.height), max(int(y0 * grid.height) + 1, int(y1 * grid.height)))
    cells = [y * grid.width + x for y in ys for x in xs]
    count = len(cells)
    mean = tuple(sum(grid.pixels[i][k] for i in cells) / count for k in range(3))
    chroma = sum(math.hypot(grid.labs[i][1], grid.labs[i][2]) for i in cells) / count
    diffs = []
    for y in ys:
        for x in xs:
            here = grid.labs[y * grid.width + x][0]
            if x + 1 < grid.width:
                diffs.append(abs(here - grid.labs[y * grid.width + x + 1][0]))
            if y + 1 < grid.height:
                diffs.append(abs(here - grid.labs[(y + 1) * grid.width + x][0]))
    lums = sorted(grid.luminances[i] for i in cells)
    return Region(
        mean=mean,  # type: ignore[arg-type]
        L=color.to_lab(mean)[0],  # type: ignore[arg-type]
        chroma=chroma,
        busy=sum(diffs) / len(diffs) if diffs else 0.0,
        lum_lo=lums[int(0.05 * (count - 1))],
        lum_hi=lums[int(0.95 * (count - 1))],
    )


def pick_scheme(whole: Region, override: str | None) -> str:
    """Grey images get a quiet scheme instead of a fabricated hue."""
    if override:
        return override
    if whole.chroma < _MONOCHROME_BELOW:
        return "m3-monochrome"
    if whole.chroma < _SOFT_BELOW:
        return "soft"
    return "faithful"


def pick_mode(whole: Region, bar: Region, mode: str) -> str:
    if mode in ("dark", "light"):
        return mode
    if mode != "auto":
        raise ValueError(f"mode must be auto, dark or light, not {mode!r}")
    return "light" if whole.L > _LIGHT_IMAGE_L and bar.L > _LIGHT_BAR_L else "dark"
