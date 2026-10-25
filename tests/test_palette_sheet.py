"""Smoke test for scripts/dev/palette_sheet.py: the contact sheet of real palette runs over a set of wallpapers."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "scripts/dev/palette_sheet.py"


class PaletteSheetTest(unittest.TestCase):
    def setUp(self):
        missing = [tool for tool in ("magick", "noctalia") if not shutil.which(tool)]
        if missing:
            self.skipTest(f"{', '.join(missing)} not installed")
        self.dir = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.dir, True)

    def make_image(self, name, spec):
        path = self.dir / name
        subprocess.run(["magick", "-size", "320x180", spec, str(path)], check=True)
        return path

    def test_builds_one_sheet_with_a_row_per_wallpaper_and_mode(self):
        images = [self.make_image("a.png", "gradient:#2060ff-#ff40a0"), self.make_image("b.png", "xc:#202020"),
                  self.make_image("c.png", "xc:#f0e8d8")]
        out = self.dir / "sheet.jpg"
        result = subprocess.run([sys.executable, "-I", "-B", str(SHEET), str(out), "--modes", "dark,light",
                                 *map(str, images)], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("6 renders", result.stdout)
        self.assertIn("worst contrast", result.stdout)
        size = subprocess.run(["magick", "identify", "-format", "%w %h", str(out)], capture_output=True, text=True,
                              check=True).stdout.split()
        width, height = int(size[0]), int(size[1])
        # Four 480x270 cells per row (6 px apart): 3 wallpapers x 2 modes = 6 cells = 2 rows.
        self.assertAlmostEqual(width, 4 * 486, delta=20)
        self.assertAlmostEqual(height, 2 * 276, delta=20)

    def test_a_missing_wallpaper_fails_with_a_message(self):
        result = subprocess.run([sys.executable, "-I", "-B", str(SHEET), str(self.dir / "o.jpg"),
                                 str(self.dir / "nope.png")], capture_output=True, text=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("nope.png", result.stderr)

    def test_without_arguments_it_prints_usage_and_exits_64(self):
        result = subprocess.run([sys.executable, "-I", "-B", str(SHEET)], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 64)
        self.assertIn("usage", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
