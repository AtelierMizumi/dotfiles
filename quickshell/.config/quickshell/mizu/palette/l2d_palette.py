#!/usr/bin/env python3
"""Extract the Live2D theme palette of a model and feed it to mizu_palette.py.

    python3 -I -B l2d_palette.py <prefab> [--mode auto|dark|light]
                                 [--mizu-root PATH] [--mapping PATH] [--swatch-dir PATH]

The skin's background picture (`bg` id in l2d_mapping.json) is the palette
source, like any other wallpaper. The model's textures decide the accent:
their opaque pixels are quantized and the best-scoring cluster (saturated,
mid-bright, reasonably frequent) wins. Without a background on disk a swatch
of the texture palette is generated instead, so every model can theme.

Writes the same files as mizu_palette.py (~/.cache/mizu/tokens.json and
~/.config/niri/colors.kdl) and prints the tokens path.
Exit codes: 0 done; 2 extraction or generation failed; 64 usage error.
"""

from __future__ import annotations

import argparse
import colorsys
import json
import math
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

EXIT_OK, EXIT_FAILED, EXIT_USAGE = 0, 2, 64

PREFAB_RE = re.compile(r"^[a-z0-9_]+$")
TEXTURE_SIZE = 160        # textures are sampled down to this before counting
SAMPLE_CAP = 40000        # total opaque pixels across all textures
CLUSTERS = 12             # quantized colours to score
MIN_ALPHA = 200


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        print(f"l2d_palette.py: error: {message}", file=sys.stderr)
        raise SystemExit(EXIT_USAGE)


def _defaults():
    share = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return {
        "mizu_root": share / "mizu/l2d",
        "mapping": share / "mizu/data/l2d_mapping.json",
        "swatch_dir": cache / "mizu/l2d-palette-src",
    }


def _parser() -> argparse.ArgumentParser:
    defaults = _defaults()
    parser = _Parser(prog="l2d_palette.py", description="Live2D model palette to mizu tokens and niri colors.")
    parser.add_argument("prefab", help="model prefab, e.g. gaoxiong_7")
    parser.add_argument("--mode", choices=("auto", "dark", "light"), default="auto")
    parser.add_argument("--mizu-root", type=Path, default=defaults["mizu_root"])
    parser.add_argument("--mapping", type=Path, default=defaults["mapping"])
    parser.add_argument("--swatch-dir", type=Path, default=defaults["swatch_dir"])
    return parser


def texture_paths(model_dir: Path, prefab: str) -> list[Path]:
    """The texture files of the model, in model3.json order, existing ones only."""
    model_json = model_dir / f"{prefab}.model3.json"
    try:
        ref = json.loads(model_json.read_text(encoding="utf-8")).get("FileReferences", {})
    except (OSError, ValueError):
        return []
    out = []
    for rel in ref.get("Textures", []):
        if isinstance(rel, str):
            path = model_dir / rel
            if path.is_file():
                out.append(path)
    return out


def find_bg(mapping_path: Path, prefab: str, mizu_root: Path) -> Path | None:
    """The skin's background picture, or None when the mapping or the file is missing."""
    try:
        data = json.loads(mapping_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    for ship in data.values():
        skins = ship.get("skins") if isinstance(ship, dict) else None
        if not isinstance(skins, list):
            continue
        for skin in skins:
            if isinstance(skin, dict) and skin.get("prefab") == prefab:
                bg = str(skin.get("bg") or "")
                if not bg:
                    return None
                candidate = mizu_root / "bg" / f"{bg}.png"
                return candidate if candidate.is_file() else None
    return None


def _texture_pixels(paths: list[Path]) -> list[tuple[int, int, int]]:
    """Opaque RGB samples from the textures, capped at SAMPLE_CAP in total."""
    from PIL import Image

    pixels: list[tuple[int, int, int]] = []
    for path in paths:
        img = Image.open(path).convert("RGBA")
        img.thumbnail((TEXTURE_SIZE, TEXTURE_SIZE))
        budget = SAMPLE_CAP // max(1, len(paths))
        step = max(1, (img.width * img.height) // max(1, budget))
        raw = img.tobytes()  # RGBA, 4 bytes a pixel
        for i in range(0, len(raw), 4 * step):
            if raw[i + 3] >= MIN_ALPHA:
                pixels.append((raw[i], raw[i + 1], raw[i + 2]))
    return pixels


def _dominant(pixels: list[tuple[int, int, int]], count: int) -> list[tuple[float, tuple[int, int, int]]]:
    """Quantized colours as (frequency 0..1, rgb), most frequent first."""
    from PIL import Image

    img = Image.new("RGB", (len(pixels), 1))
    img.putdata(pixels)
    q = img.quantize(colors=count)
    palette = q.getpalette() or []
    total = max(1, len(pixels))
    out = []
    for freq, idx in (q.getcolors() or []):
        rgb = palette[idx * 3: idx * 3 + 3]
        if len(rgb) == 3:
            out.append((freq / total, (rgb[0], rgb[1], rgb[2])))
    out.sort(key=lambda item: -item[0])
    return out


def accent_from_pixels(pixels: list[tuple[int, int, int]]) -> str:
    """The model's accent: the most frequent reasonably vivid mid-bright cluster."""
    clusters = _dominant(pixels, CLUSTERS)
    if not clusters:
        return "#5a8dd6"
    best: tuple[int, int, int] | None = None
    best_score = 0.0
    for freq, rgb in clusters:
        _, sat, val = colorsys.rgb_to_hsv(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255)
        if not (0.25 <= val <= 0.95) or sat < 0.2:
            continue
        score = sat * math.sqrt(freq)
        if score > best_score:
            best, best_score = rgb, score
    if best is None:  # every cluster is near-black, near-white or gray
        best = clusters[0][1]
    return "#%02x%02x%02x" % best


def make_swatch(pixels: list[tuple[int, int, int]], out_path: Path) -> Path:
    """A stand-in source image: the dominant colours as vertical bands."""
    from PIL import Image, ImageDraw

    clusters = _dominant(pixels, 6)
    swatch = Image.new("RGB", (96, 64))
    draw = ImageDraw.Draw(swatch)
    band = math.ceil(96 / max(1, len(clusters)))
    for i, (_, rgb) in enumerate(clusters):
        x1 = 96 if i == len(clusters) - 1 else (i + 1) * band
        draw.rectangle([i * band, 0, x1 - 1, 63], fill=rgb)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    swatch.save(out_path, "PNG")
    return out_path


def main(argv=None) -> int:
    try:
        args = _parser().parse_args(argv)
    except SystemExit as exit_request:
        return int(exit_request.code or 0)
    if not PREFAB_RE.fullmatch(args.prefab):
        print(f"l2d_palette.py: prefab wants [a-z0-9_]+, got {args.prefab!r}", file=sys.stderr)
        return EXIT_USAGE

    textures = texture_paths(args.mizu_root / args.prefab, args.prefab)
    if not textures:
        print(f"l2d_palette.py: no textures for {args.prefab} under {args.mizu_root}", file=sys.stderr)
        return EXIT_FAILED
    try:
        pixels = _texture_pixels(textures)
    except (OSError, ValueError) as exc:
        print(f"l2d_palette.py: could not read the textures: {exc}", file=sys.stderr)
        return EXIT_FAILED
    if not pixels:
        print(f"l2d_palette.py: the textures of {args.prefab} have no opaque pixels", file=sys.stderr)
        return EXIT_FAILED
    accent = accent_from_pixels(pixels)

    source = find_bg(args.mapping, args.prefab, args.mizu_root)
    if source is None:
        try:
            source = make_swatch(pixels, args.swatch_dir / f"{args.prefab}.png")
        except (OSError, ValueError) as exc:
            print(f"l2d_palette.py: could not write the swatch: {exc}", file=sys.stderr)
            return EXIT_FAILED

    import mizu_palette
    return mizu_palette.main([str(source), "--mode", args.mode, "--accent", accent])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
