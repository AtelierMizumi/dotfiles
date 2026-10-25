#!/usr/bin/env python3
"""A contact sheet of real palette runs: bar, phone and widget drawn over each wallpaper with the measured contrast.

    python3 -I -B scripts/dev/palette_sheet.py OUT.jpg [--modes dark,light,auto] WALLPAPER...

Runs the production tool (mizu_palette.py) for every wallpaper and mode into a temporary directory, so nothing in the
real cache or in ~/.config/niri is touched. Prints the worst contrast seen.
"""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOOL = ROOT / "quickshell/.config/quickshell/mizu/palette/mizu_palette.py"
CELL_W, CELL_H = 480, 270
REGIONS = {  # the same screen fractions the palette analysis uses
    "bar": (0.0, 0.0, 1.0, 0.045),
    "phone": (0.36, 0.45, 0.64, 1.0),
    "widget": (0.03, 0.10, 0.28, 0.40),
}


def usage(message=None):
    if message:
        print(message, file=sys.stderr)
    print("usage: palette_sheet.py OUT.jpg [--modes dark,light,auto] WALLPAPER...", file=sys.stderr)
    return 64


def palette(wallpaper, mode, work):
    result = subprocess.run(
        [sys.executable, "-I", "-B", str(TOOL), str(wallpaper), "--mode", mode, "--tokens", str(work / "tokens.json"),
         "--niri", str(work / "colors.kdl"), "--overrides", str(work / "none.json"),
         "--cache-dir", str(work / "cache")],
        capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"{wallpaper}: {result.stderr.strip()}")
    return json.loads((work / "tokens.json").read_text())


def draw_cell(wallpaper, tokens, out):
    command = ["magick", f"{wallpaper}[0]", "-resize", f"{CELL_W}x{CELL_H}^", "-gravity", "center",
               "-extent", f"{CELL_W}x{CELL_H}", "+gravity"]
    for name, (x0, y0, x1, y1) in REGIONS.items():
        surface = tokens["surface"][name]
        left, top = int(x0 * CELL_W), int(y0 * CELL_H)
        right, bottom = int(x1 * CELL_W), int(y1 * CELL_H)
        if name == "bar":
            left, top, right, bottom = 4, 3, CELL_W - 4, 3 + 16
        radius = 5 if name == "bar" else 14
        alpha = f"{int(surface['alpha'] * 255):02x}"
        command += ["-fill", f"{surface['housing']}{alpha}", "-draw",
                    f"roundrectangle {left},{top} {right},{bottom} {radius},{radius}"]
        command += ["-fill", surface["accent"], "-draw",
                    f"roundrectangle {left + 6},{top + 4} {left + 30},{top + 11} 3,3"]
        text_y = top + (12 if name == "bar" else 20)
        command += ["-fill", surface["ink"], "-pointsize", "9" if name == "bar" else "11", "-annotate",
                    f"+{left + 36}+{text_y}",
                    f"{name} {tokens['contrast'][name + '.ink']}:1  accent {tokens['contrast'][name + '.accent']}:1"]
        if name != "bar":
            command += ["-fill", surface["inkMuted"], "-pointsize", "10", "-annotate",
                        f"+{left + 8}+{text_y + 18}", "muted text"]
    analysis = tokens["analysis"]
    caption = (f"{Path(wallpaper).stem}  {tokens['mode']}  {tokens['scheme']}  C*{analysis['chroma']} "
               f"busy {analysis['busy']}")
    command += ["-fill", "#000000b0", "-draw", f"rectangle 0,{CELL_H - 16} {CELL_W},{CELL_H}", "-fill", "white",
                "-pointsize", "10", "-annotate", f"+4+{CELL_H - 5}", caption, str(out)]
    subprocess.run(command, check=True, capture_output=True)


def main(argv):
    if not argv or argv[0].startswith("-"):
        return usage()
    out = Path(argv[0])
    modes = ["dark"]
    images = []
    rest = argv[1:]
    while rest:
        item = rest.pop(0)
        if item == "--modes":
            if not rest:
                return usage("--modes needs a value")
            modes = rest.pop(0).split(",")
        else:
            images.append(Path(item))
    if not images:
        return usage("no wallpapers given")
    for image in images:
        if not image.is_file():
            print(f"palette_sheet.py: no such wallpaper: {image}", file=sys.stderr)
            return 2

    work = Path(tempfile.mkdtemp(prefix="palette-sheet-"))
    try:
        cells = []
        worst_ink, worst_accent = 99.0, 99.0
        for image in images:
            for mode in modes:
                tokens = palette(image, mode, work)
                for name in REGIONS:
                    worst_ink = min(worst_ink, tokens["contrast"][f"{name}.ink"])
                    worst_accent = min(worst_accent, tokens["contrast"][f"{name}.accent"])
                cell = work / f"cell-{len(cells):03d}.png"
                draw_cell(image, tokens, cell)
                cells.append(str(cell))
        subprocess.run(["magick", "montage", *cells, "-tile", "4x", "-geometry", f"{CELL_W}x{CELL_H}+3+3",
                        "-background", "#202020", "-quality", "82", str(out)], check=True, capture_output=True)
    except (RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"palette_sheet.py: {exc}", file=sys.stderr)
        return 2
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print(f"{len(cells)} renders -> {out}; worst contrast: ink {worst_ink}:1, accent {worst_accent}:1")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
