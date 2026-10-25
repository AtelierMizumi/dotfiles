"""PROTOTYPE (throwaway): smart wallpaper palette.

Question: can image analysis -> scheme pick -> region sampling -> WCAG contrast correction give readable, harmonious
bar/phone/widget colors for every wallpaper, with stdlib Python + ImageMagick + `noctalia theme` only?

Run: python3 -I smart_palette_PROTOTYPE.py <out_dir> <wallpaper>...
Writes one mock per wallpaper (<out_dir>/<name>.png) and prints the full state per wallpaper.
"""

import json
import math
import subprocess
import sys
from pathlib import Path

W, H = 96, 54  # analysis grid


# ---------- color math ----------
def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb_to_hex(c):
    return "#" + "".join(f"{max(0, min(255, round(v * 255))):02x}" for v in c)


def lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rel_lum(c):
    r, g, b = (lin(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def rgb_to_lab(c):
    r, g, b = (lin(v) for v in c)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def lab_to_rgb(lab):
    L, a, b = lab
    fy = (L + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200
    finv = lambda t: t ** 3 if t ** 3 > 216 / 24389 else (116 * t - 16) / (24389 / 27)
    x, y, z = finv(fx) * 0.95047, finv(fy), finv(fz) * 1.08883
    r = 3.2406 * x - 1.5372 * y - 0.4986 * z
    g = -0.9689 * x + 1.8758 * y + 0.0415 * z
    bl = 0.0557 * x - 0.2040 * y + 1.0570 * z
    gam = lambda v: 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
    return tuple(max(0.0, min(1.0, gam(v))) for v in (r, g, bl))


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def set_lightness(c, L):
    _, a, b = rgb_to_lab(c)
    return lab_to_rgb((L, a, b))


# ---------- image analysis ----------
def load_grid(path):
    out = subprocess.run(["magick", str(path), "-resize", f"{W}x{H}!", "-depth", "8", "rgb:-"],
                         capture_output=True, check=True).stdout
    return [tuple(out[i + k] / 255 for k in range(3)) for i in range(0, len(out), 3)]


def region_stats(grid, x0, y0, x1, y1):
    """Stats of the grid cells inside a fractional rectangle."""
    xs = range(int(x0 * W), max(int(x0 * W) + 1, int(x1 * W)))
    ys = range(int(y0 * H), max(int(y0 * H) + 1, int(y1 * H)))
    px = [grid[y * W + x] for y in ys for x in xs]
    labs = [rgb_to_lab(p) for p in px]
    lums = sorted(rel_lum(p) for p in px)
    mean = tuple(sum(p[k] for p in px) / len(px) for k in range(3))
    chroma = sum(math.hypot(l[1], l[2]) for l in labs) / len(labs)
    # busyness: mean absolute L* difference to the right/below neighbour
    diffs = []
    for y in ys:
        for x in xs:
            l0 = rgb_to_lab(grid[y * W + x])[0]
            if x + 1 < W:
                diffs.append(abs(l0 - rgb_to_lab(grid[y * W + x + 1])[0]))
            if y + 1 < H:
                diffs.append(abs(l0 - rgb_to_lab(grid[(y + 1) * W + x])[0]))
    return {
        "mean": mean,
        "L": rgb_to_lab(mean)[0],
        "chroma": chroma,
        "busy": sum(diffs) / max(1, len(diffs)),
        "lum_lo": lums[int(0.05 * (len(lums) - 1))],
        "lum_hi": lums[int(0.95 * (len(lums) - 1))],
        "dark": lums[int(0.05 * (len(lums) - 1))],
    }


def pick_scheme(whole):
    # Grey/low-chroma images get a quiet scheme instead of a fabricated hue.
    if whole["chroma"] < 7:
        return "m3-monochrome"
    if whole["chroma"] < 16:
        return "soft"
    return "faithful"


def palette(path, scheme):
    out = subprocess.run(["noctalia", "theme", str(path), "--scheme", scheme, "--dark"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


# ---------- the smart part ----------
def fit_surface(pal, region):
    """Surface color + opacity for one component over its region, and readable on-colors."""
    surface = hex_to_rgb(pal["surface_container"])
    # tint the surface slightly towards what is behind it
    surface = mix(surface, set_lightness(region["mean"], rgb_to_lab(surface)[0]), 0.25)
    alpha = max(0.55, min(0.92, 0.62 + region["busy"] / 40))
    # worst-case backdrop: the brightest 5% of the region (dark surfaces) seen through the surface
    worst_bg = (region["lum_hi"],) * 3
    eff = mix(worst_bg, surface, alpha)
    text = hex_to_rgb(pal["on_surface"])
    fixes = []
    while contrast(text, eff) < 4.5 and alpha < 0.97:
        alpha += 0.03
        eff = mix(worst_bg, surface, alpha)
        fixes.append("alpha+")
    if contrast(text, eff) < 4.5:
        text = (1, 1, 1) if rel_lum(eff) < 0.18 else (0, 0, 0)
        fixes.append("text->bw")
    accent = hex_to_rgb(pal["primary"])
    L = rgb_to_lab(accent)[0]
    while contrast(accent, eff) < 3.0 and L < 96:
        L += 2
        accent = set_lightness(accent, L)
        fixes.append("accent+L")
    return {
        "surface": rgb_to_hex(surface), "alpha": round(alpha, 2), "text": rgb_to_hex(text),
        "accent": rgb_to_hex(accent), "on_accent": pal["on_primary"],
        "text_cr": round(contrast(text, eff), 2), "accent_cr": round(contrast(accent, eff), 2),
        "fixes": sorted(set(fixes)),
    }


REGIONS = {  # fractional rectangles where each surface sits on a 16:9 screen
    "bar": (0.0, 0.0, 1.0, 0.045),
    "phone": (0.36, 0.45, 0.64, 1.0),
    "widget": (0.03, 0.10, 0.28, 0.40),
}


def render(path, out, result):
    w, h = 960, 540
    cmds = ["magick", str(path), "-resize", f"{w}x{h}^", "-gravity", "center", "-extent", f"{w}x{h}", "+gravity"]
    for name, (x0, y0, x1, y1) in REGIONS.items():
        r = result[name]
        X0, Y0, X1, Y1 = int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)
        if name == "bar":
            X0, Y0, X1, Y1 = 8, 6, w - 8, 6 + 30
        rad = 8 if name == "bar" else 22
        cmds += ["-fill", f"{r['surface']}{int(r['alpha'] * 255):02x}", "-draw",
                 f"roundrectangle {X0},{Y0} {X1},{Y1} {rad},{rad}"]
        cmds += ["-fill", r["accent"], "-draw", f"roundrectangle {X0 + 10},{Y0 + 8} {X0 + 60},{Y0 + 22} 7,7"]
        cmds += ["-fill", r["text"], "-pointsize", "15", "-annotate", f"+{X0 + 70}+{Y0 + 21}",
                 f"{name} {r['text_cr']}:1 / {r['accent_cr']}:1"]
    cmds += ["-fill", "#000000a0", "-draw", f"rectangle 0,{h - 26} {w},{h}", "-fill", "white", "-pointsize", "14",
             "-annotate", f"+8+{h - 8}",
             f"{Path(path).stem}  scheme={result['scheme']}  C*={result['whole']['chroma']:.1f}  "
             f"busy={result['whole']['busy']:.1f}  fixes={sorted(set(sum((result[n]['fixes'] for n in REGIONS), [])))}",
             str(out)]
    subprocess.run(cmds, check=True)


def main():
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in sys.argv[2:]:
        grid = load_grid(p)
        whole = region_stats(grid, 0, 0, 1, 1)
        scheme = pick_scheme(whole)
        pal = palette(p, scheme)
        result = {"scheme": scheme, "whole": whole}
        for name, rect in REGIONS.items():
            result[name] = fit_surface(pal, region_stats(grid, *rect))
        render(p, out_dir / f"{Path(p).stem}.png", result)
        print(json.dumps({"file": Path(p).name, "scheme": scheme,
                          "chroma": round(whole["chroma"], 1), "busy": round(whole["busy"], 1),
                          **{n: result[n] for n in REGIONS}}))


if __name__ == "__main__":
    main()
