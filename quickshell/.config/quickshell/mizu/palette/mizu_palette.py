#!/usr/bin/env python3
"""Turn a wallpaper into the mizu tokens and the niri focus-ring colors.

    python3 -I -B mizu_palette.py <wallpaper> [--tokens PATH] [--niri PATH] [--mode auto|dark|light]
                                  [--accent #RRGGBB] [--overrides PATH] [--cache-dir PATH]

Writes ~/.cache/mizu/tokens.json and ~/.config/niri/colors.kdl (atomically) and prints the tokens path.
--accent forces the accent colour for this run, on top of the overrides file.
Exit codes: 0 done; 2 the image or the color generator failed, both previous files are left untouched; 64 usage error.
Nothing outside the given paths is written.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from palette_core import adapters, build  # noqa: E402

TOOL_VERSION = "1"
OVERRIDE_KEYS = ("scheme", "mode", "accent")
EXIT_OK, EXIT_FAILED, EXIT_USAGE = 0, 2, 64


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        print(f"mizu_palette.py: error: {message}", file=sys.stderr)
        raise SystemExit(EXIT_USAGE)


def _default_paths():
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return {
        "tokens": cache_home / "mizu/tokens.json",
        "niri": config_home / "niri/colors.kdl",
        "overrides": cache_home / "mizu/state/palette-overrides.json",
        "cache_dir": cache_home / "mizu/palette-cache",
    }


def _parser() -> argparse.ArgumentParser:
    defaults = _default_paths()
    parser = _Parser(prog="mizu_palette.py", description="Wallpaper to mizu tokens and niri colors.")
    parser.add_argument("wallpaper")
    parser.add_argument("--tokens", type=Path, default=defaults["tokens"])
    parser.add_argument("--niri", type=Path, default=defaults["niri"])
    parser.add_argument("--mode", choices=("auto", "dark", "light"), default="auto")
    parser.add_argument("--accent", default=None, metavar="#RRGGBB",
                        help="force the accent colour for this run, on top of the overrides file")
    parser.add_argument("--overrides", type=Path, default=defaults["overrides"])
    parser.add_argument("--cache-dir", type=Path, default=defaults["cache_dir"])
    return parser


def _load_overrides(path: Path, wallpaper: str) -> dict:
    """The `*` entry, then the wallpaper's own entry on top. A broken file is reported and ignored."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("not a JSON object")
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as exc:
        print(f"mizu_palette.py: ignoring unreadable overrides {path}: {exc}", file=sys.stderr)
        return {}
    merged: dict = {}
    for entry in (data.get("*"), data.get(wallpaper)):
        if isinstance(entry, dict):
            merged.update({key: entry[key] for key in OVERRIDE_KEYS if isinstance(entry.get(key), str)})
    return merged


def _cache_key(image_bytes: bytes, mode: str, overrides: dict) -> str:
    digest = hashlib.sha256()
    digest.update(image_bytes)
    digest.update(b"\0" + mode.encode() + b"\0" + json.dumps(overrides, sort_keys=True).encode())
    digest.update(b"\0" + TOOL_VERSION.encode())
    return digest.hexdigest()


def main(argv, grid_reader=None, generator_factory=None, out=None) -> int:
    try:
        args = _parser().parse_args(argv)
    except SystemExit as exit_request:
        return int(exit_request.code or 0)
    grid_reader = grid_reader or adapters.read_grid
    generator_factory = generator_factory or adapters.noctalia_generator

    wallpaper = Path(os.path.abspath(os.path.expanduser(args.wallpaper)))
    try:
        image_bytes = wallpaper.read_bytes()
    except OSError as exc:
        print(f"mizu_palette.py: cannot read {wallpaper}: {exc}", file=sys.stderr)
        return EXIT_FAILED

    overrides = _load_overrides(args.overrides, str(wallpaper))
    if args.accent is not None:
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", args.accent):
            print(f"mizu_palette.py: --accent wants #RRGGBB, got {args.accent!r}", file=sys.stderr)
            return EXIT_USAGE
        overrides["accent"] = args.accent
    cache_file = args.cache_dir / f"{_cache_key(image_bytes, args.mode, overrides)}.json"

    tokens = None
    try:
        tokens = json.loads(cache_file.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        tokens = None
    if tokens is not None and not (isinstance(tokens, dict) and tokens.get("schema") == build.SCHEMA
                                   and adapters.niri_colors_ok(tokens)):
        tokens = None  # an entry that was edited or written by another version is a miss, never trusted

    if tokens is None:
        try:
            grid = grid_reader(wallpaper)
            tokens = build.build(grid, generator_factory(wallpaper), overrides, args.mode)
        except (adapters.ImageError, adapters.GeneratorError, ValueError) as exc:
            print(f"mizu_palette.py: {exc}", file=sys.stderr)
            return EXIT_FAILED
        tokens["wallpaper"] = str(wallpaper)
        try:
            adapters.atomic_write(cache_file, json.dumps(tokens, indent=2))
        except OSError as exc:
            print(f"mizu_palette.py: could not cache the palette: {exc}", file=sys.stderr)
    tokens["wallpaper"] = str(wallpaper)

    try:
        adapters.write_pair(args.tokens, json.dumps(tokens, indent=2) + "\n",
                            args.niri, adapters.render_niri_kdl(tokens))
    except OSError as exc:
        print(f"mizu_palette.py: could not write the palette files: {exc}", file=sys.stderr)
        return EXIT_FAILED
    print(args.tokens, file=out or sys.stdout)
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
