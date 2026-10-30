"""Unit tests for the Live2D palette extractor (palette/l2d_palette.py).

Builds a fake model directory (model3.json + texture PNGs) and a fake
l2d_mapping.json with a background, then checks texture discovery, background
resolution, accent scoring and the swatch fallback — all pure PIL, no ImageMagick
or noctalia involved.
"""

import sys
import tempfile
import unittest
from pathlib import Path

MIZU_DIR = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu"
sys.path.insert(0, str(MIZU_DIR / "palette"))

import l2d_palette as lp  # noqa: E402

from PIL import Image  # noqa: E402


def make_texture(path, color, size=64, alpha=255):
    img = Image.new("RGBA", (size, size), color + (alpha,))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")


class L2dPaletteTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.mizu_root = root / "l2d"
        self.mapping = root / "l2d_mapping.json"
        self.swatch_dir = root / "swatches"

        model_dir = self.mizu_root / "gaoxiong_7"
        make_texture(model_dir / "textures/texture_00.png", (200, 40, 60))  # vivid red uniform
        make_texture(model_dir / "textures/texture_01.png", (40, 40, 44))   # dark hair
        model3 = {
            "FileReferences": {
                "Textures": ["textures/texture_00.png", "textures/texture_01.png",
                             "textures/missing.png"]
            }
        }
        (model_dir / "gaoxiong_7.model3.json").write_text(
            __import__("json").dumps(model3), encoding="utf-8")

        bg = Image.new("RGB", (32, 32), (30, 90, 160))
        (self.mizu_root / "bg").mkdir(parents=True, exist_ok=True)
        bg.save(self.mizu_root / "bg" / "319.png", "PNG")

        self.mapping.write_text(
            __import__("json").dumps({
                "30311": {"skins": [{"prefab": "gaoxiong_7", "bg": "319"}]},
                "1": {"skins": [{"prefab": "unknown_1", "bg": "319"}]},
            }),
            encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def test_texture_paths_reads_model3_and_skips_missing(self):
        paths = lp.texture_paths(self.mizu_root / "gaoxiong_7", "gaoxiong_7")
        self.assertEqual(len(paths), 2)
        self.assertTrue(all(p.is_file() for p in paths))

    def test_texture_paths_missing_model(self):
        self.assertEqual(lp.texture_paths(self.mizu_root / "nope_1", "nope_1"), [])

    def test_find_bg_resolves_skin_background(self):
        bg = lp.find_bg(self.mapping, "gaoxiong_7", self.mizu_root)
        self.assertEqual(bg, self.mizu_root / "bg" / "319.png")
        self.assertTrue(bg.is_file())

    def test_find_bg_unknown_prefab_is_none(self):
        self.assertIsNone(lp.find_bg(self.mapping, "nobody_1", self.mizu_root))

    def test_accent_picks_the_vivid_cluster(self):
        pixels = [(200, 40, 60)] * 600 + [(40, 40, 44)] * 200
        accent = lp.accent_from_pixels(pixels)
        rgb = tuple(int(accent[i:i + 2], 16) for i in (1, 3, 5))
        self.assertGreater(rgb[0], rgb[1], f"accent {accent} is not red-dominant")
        self.assertGreater(rgb[0], rgb[2], f"accent {accent} is not red-dominant")

    def test_accent_falls_back_without_vivid_pixels(self):
        accent = lp.accent_from_pixels([(20, 20, 20)] * 100)
        self.assertRegex(accent, r"^#[0-9a-f]{6}$")

    def test_make_swatch_writes_a_png(self):
        pixels = [(200, 40, 60)] * 300 + [(40, 40, 44)] * 100
        out = lp.make_swatch(pixels, self.swatch_dir / "gaoxiong_7.png")
        self.assertTrue(out.is_file())
        with Image.open(out) as img:
            self.assertEqual(img.size, (96, 64))

    def test_texture_pixels_only_counts_opaque(self):
        # a texture whose pixels sit below MIN_ALPHA must contribute nothing
        ghost = self.mizu_root / "gaoxiong_7" / "textures" / "ghost.png"
        make_texture(ghost, (200, 40, 60), size=32, alpha=100)
        paths = lp.texture_paths(self.mizu_root / "gaoxiong_7", "gaoxiong_7")
        self.assertEqual(len(lp._texture_pixels(paths)), len(lp._texture_pixels(paths + [ghost])))


if __name__ == "__main__":
    unittest.main()
