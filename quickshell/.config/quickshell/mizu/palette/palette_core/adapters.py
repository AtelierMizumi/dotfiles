"""The two seams of the palette tool: reading a wallpaper into a Grid, and generating roles from a wallpaper.

Plus the file side: the niri colors file and atomic writes.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from . import analysis

GRID_WIDTH = 96
GRID_HEIGHT = 54
_TIMEOUT_SECONDS = 60


class ImageError(Exception):
    """The wallpaper could not be decoded."""


class GeneratorError(Exception):
    """The color generator failed or answered with something unusable."""


def read_grid(path: str | os.PathLike) -> analysis.Grid:
    """Decode the wallpaper with ImageMagick, fill-and-crop it to 96x54 the way a fill-mode wallpaper is shown."""
    command = [
        "magick", f"{path}[0]", "-alpha", "remove", "-alpha", "off",
        "-resize", f"{GRID_WIDTH}x{GRID_HEIGHT}^", "-gravity", "center", "-extent", f"{GRID_WIDTH}x{GRID_HEIGHT}",
        "-depth", "8", "rgb:-",
    ]
    try:
        result = subprocess.run(command, capture_output=True, check=False, timeout=_TIMEOUT_SECONDS)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise ImageError(f"magick could not run: {exc}") from exc
    data = result.stdout
    if result.returncode != 0 or len(data) != GRID_WIDTH * GRID_HEIGHT * 3:
        detail = result.stderr.decode(errors="replace").strip().splitlines()
        raise ImageError(f"magick could not read {path}: {detail[0] if detail else f'exit {result.returncode}'}")
    pixels = [(data[i] / 255, data[i + 1] / 255, data[i + 2] / 255) for i in range(0, len(data), 3)]
    return analysis.Grid(GRID_WIDTH, GRID_HEIGHT, pixels)


def noctalia_generator(path: str | os.PathLike):
    """generate(scheme, mode) -> role dict, from `noctalia theme` on this wallpaper."""

    def generate(scheme: str, mode: str) -> dict:
        flag = "--dark" if mode == "dark" else "--light"
        command = ["noctalia", "theme", str(path), "--scheme", scheme, flag]
        try:
            result = subprocess.run(command, capture_output=True, text=True, check=False, timeout=_TIMEOUT_SECONDS)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise GeneratorError(f"noctalia theme could not run: {exc}") from exc
        if result.returncode != 0:
            raise GeneratorError(f"noctalia theme exited {result.returncode}: {result.stderr.strip()[:200]}")
        try:
            roles = json.loads(result.stdout)
        except ValueError as exc:
            raise GeneratorError(f"noctalia theme printed no JSON: {exc}") from exc
        if not isinstance(roles, dict):
            raise GeneratorError("noctalia theme printed JSON that is not an object")
        return roles

    return generate


def render_niri_kdl(tokens: dict) -> str:
    """The focus ring and insert hint, for `include optional=true "colors.kdl"` in niri's config."""
    colors = tokens["color"]
    source = str(tokens.get("wallpaper", "")).replace("\n", " ")
    return (
        f"// Rendered by mizu_palette.py from {source}. The next wallpaper change rewrites this file.\n"
        "layout {\n"
        "    focus-ring {\n"
        f'        active-color "{colors["accent"]}"\n'
        f'        inactive-color "{colors["surfaceDivider"]}"\n'
        f'        urgent-color "{colors["danger"]}"\n'
        "    }\n"
        "    insert-hint {\n"
        f'        color "{colors["accent"]}80"\n'
        "    }\n"
        "}\n"
    )


def _temp_for(path: Path) -> Path:
    return path.with_name(f"{path.name}.tmp{os.getpid()}")


def _write_temp(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = _temp_for(path)
    with open(temp, "w", encoding="utf-8") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    return temp


def atomic_write(path: str | os.PathLike, text: str) -> None:
    """Write via a temp file in the same directory and a rename, so a reader never sees half a file."""
    target = Path(path)
    temp = _write_temp(target, text)
    try:
        os.replace(temp, target)
    except BaseException:
        temp.unlink(missing_ok=True)
        raise


def write_pair(first: str | os.PathLike, first_text: str, second: str | os.PathLike, second_text: str) -> None:
    """Both files are prepared before either is replaced; an error removes whatever temp file is left."""
    targets = [Path(first), Path(second)]
    temps: list[Path] = []
    try:
        temps.append(_write_temp(targets[0], first_text))
        temps.append(_write_temp(targets[1], second_text))
        for temp, target in zip(list(temps), targets):
            os.replace(temp, target)
            temps.remove(temp)
    finally:
        for temp in temps:
            temp.unlink(missing_ok=True)
