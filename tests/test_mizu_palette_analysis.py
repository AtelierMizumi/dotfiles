"""Tests for palette_core.analysis: grid regions, scheme pick and mode pick."""

import sys
import unittest
from pathlib import Path

PALETTE_DIR = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu/palette"
sys.path.insert(0, str(PALETTE_DIR))

from palette_core import analysis, color  # noqa: E402


def solid(rgb, width=32, height=18):
    return analysis.Grid(width, height, [rgb] * (width * height))


def halves(left, right, width=32, height=18):
    return analysis.Grid(width, height, [left if x < width // 2 else right for y in range(height) for x in range(width)])


def checker(a, b, width=32, height=18):
    return analysis.Grid(width, height, [a if (x + y) % 2 == 0 else b for y in range(height) for x in range(width)])


def region(L=50.0, chroma=10.0):
    return analysis.Region(mean=(0.5, 0.5, 0.5), L=L, chroma=chroma, busy=0.0, lum_lo=0.1, lum_hi=0.2)


class RegionStatsTest(unittest.TestCase):
    def test_solid_grid_has_no_busyness_and_no_chroma_for_grey(self):
        stats = analysis.region_stats(solid((0.5, 0.5, 0.5)), (0, 0, 1, 1))
        self.assertAlmostEqual(stats.busy, 0.0, places=6)
        self.assertLess(stats.chroma, 0.5)
        self.assertAlmostEqual(stats.L, color.to_lab((0.5, 0.5, 0.5))[0], places=3)
        self.assertAlmostEqual(stats.lum_lo, stats.lum_hi, places=6)

    def test_saturated_color_has_high_chroma(self):
        self.assertGreater(analysis.region_stats(solid((0.1, 0.3, 0.9)), (0, 0, 1, 1)).chroma, 50)

    def test_checkerboard_is_busier_than_a_gradient_that_is_busier_than_solid(self):
        gradient = analysis.Grid(32, 18, [(x / 31,) * 3 for y in range(18) for x in range(32)])
        busy_checker = analysis.region_stats(checker((0, 0, 0), (1, 1, 1)), (0, 0, 1, 1)).busy
        busy_gradient = analysis.region_stats(gradient, (0, 0, 1, 1)).busy
        self.assertGreater(busy_checker, busy_gradient)
        self.assertGreater(busy_gradient, 0.0)

    def test_rectangle_selects_only_its_cells(self):
        grid = halves((0, 0, 0), (1, 1, 1))
        left = analysis.region_stats(grid, (0, 0, 0.4, 1))
        right = analysis.region_stats(grid, (0.6, 0, 1, 1))
        self.assertLess(left.L, 1.0)
        self.assertGreater(right.L, 99.0)

    def test_percentiles_follow_the_cells_of_the_region(self):
        grid = halves((0, 0, 0), (1, 1, 1))
        whole = analysis.region_stats(grid, (0, 0, 1, 1))
        self.assertAlmostEqual(whole.lum_lo, 0.0, places=6)
        self.assertAlmostEqual(whole.lum_hi, 1.0, places=6)

    def test_tiny_rectangle_still_covers_one_cell(self):
        stats = analysis.region_stats(solid((0.2, 0.2, 0.2)), (0.5, 0.5, 0.5, 0.5))
        self.assertAlmostEqual(stats.mean[0], 0.2, places=6)

    def test_regions_cover_bar_phone_and_widget(self):
        self.assertEqual(sorted(analysis.REGIONS), ["bar", "phone", "widget"])
        for rect in analysis.REGIONS.values():
            x0, y0, x1, y1 = rect
            self.assertTrue(0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1)


class PickSchemeTest(unittest.TestCase):
    def test_thresholds(self):
        self.assertEqual(analysis.pick_scheme(region(chroma=6.9), None), "m3-monochrome")
        self.assertEqual(analysis.pick_scheme(region(chroma=7.0), None), "soft")
        self.assertEqual(analysis.pick_scheme(region(chroma=15.9), None), "soft")
        self.assertEqual(analysis.pick_scheme(region(chroma=16.0), None), "faithful")

    def test_override_wins(self):
        self.assertEqual(analysis.pick_scheme(region(chroma=2.0), "vibrant"), "vibrant")


class PickModeTest(unittest.TestCase):
    def test_explicit_modes_pass_through(self):
        self.assertEqual(analysis.pick_mode(region(L=95), region(L=95), "dark"), "dark")
        self.assertEqual(analysis.pick_mode(region(L=5), region(L=5), "light"), "light")

    def test_auto_is_light_only_when_the_image_and_the_bar_region_are_bright(self):
        self.assertEqual(analysis.pick_mode(region(L=70), region(L=75), "auto"), "light")
        self.assertEqual(analysis.pick_mode(region(L=70), region(L=60), "auto"), "dark")
        self.assertEqual(analysis.pick_mode(region(L=60), region(L=75), "auto"), "dark")
        self.assertEqual(analysis.pick_mode(region(L=66.0), region(L=70.0), "auto"), "dark")
        self.assertEqual(analysis.pick_mode(region(L=66.1), region(L=70.1), "auto"), "light")

    def test_unknown_mode_is_rejected(self):
        with self.assertRaises(ValueError):
            analysis.pick_mode(region(), region(), "sepia")


if __name__ == "__main__":
    unittest.main()
