"""Tests for palette_core.color: WCAG contrast, CIELAB/LCh, hue rotation inside the sRGB gamut, lightness fitting."""

import random
import sys
import unittest
from pathlib import Path

PALETTE_DIR = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu/palette"
sys.path.insert(0, str(PALETTE_DIR))

from palette_core import color  # noqa: E402


def random_colors(count, seed):
    rng = random.Random(seed)
    fixed = [(0.0, 0.0, 1.0), (0.0, 1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 1.0), (1.0, 1.0, 0.0)]
    return fixed + [(rng.random(), rng.random(), rng.random()) for _ in range(count)]


def hue_delta(a, b):
    """Signed hue difference b - a in degrees, in (-180, 180]."""
    return (b - a + 180.0) % 360.0 - 180.0


class ContrastTest(unittest.TestCase):
    def test_black_on_white_is_21(self):
        self.assertAlmostEqual(color.contrast((0, 0, 0), (1, 1, 1)), 21.0, places=6)

    def test_same_color_is_1(self):
        self.assertAlmostEqual(color.contrast((0.3, 0.5, 0.7), (0.3, 0.5, 0.7)), 1.0, places=9)

    def test_is_symmetric(self):
        for a, b in zip(random_colors(30, 1), random_colors(30, 2)):
            self.assertAlmostEqual(color.contrast(a, b), color.contrast(b, a), places=9)

    def test_known_pair_777_on_white_is_4_48(self):
        # #777777 on white is the textbook just-below-AA pair (4.48:1).
        self.assertAlmostEqual(color.contrast(color.hex_to_rgb("#777777"), (1, 1, 1)), 4.48, places=2)


class HexTest(unittest.TestCase):
    def test_round_trip(self):
        for value in ("#000000", "#ffffff", "#e2a63b", "#182338"):
            self.assertEqual(color.rgb_to_hex(color.hex_to_rgb(value)), value)

    def test_rgb_to_hex_clamps(self):
        self.assertEqual(color.rgb_to_hex((1.4, -0.2, 0.5)), "#ff0080")


class LabTest(unittest.TestCase):
    def test_round_trip_within_half_a_channel_step(self):
        for rgb in random_colors(200, 3):
            back = color.from_lab(color.to_lab(rgb))
            for before, after in zip(rgb, back):
                self.assertLess(abs(before - after), 0.5 / 255, f"{rgb} -> {back}")

    def test_white_is_L100_and_black_is_L0(self):
        self.assertAlmostEqual(color.to_lab((1, 1, 1))[0], 100.0, places=1)
        self.assertAlmostEqual(color.to_lab((0, 0, 0))[0], 0.0, places=1)

    def test_in_gamut_rejects_an_impossible_lch(self):
        self.assertFalse(color.in_gamut(color.from_lch_unclipped(50.0, 130.0, 140.0)))
        self.assertTrue(color.in_gamut(color.from_lch_unclipped(50.0, 20.0, 140.0)))


class RotateHueTest(unittest.TestCase):
    def test_result_is_inside_the_gamut_and_keeps_lightness(self):
        for rgb in random_colors(200, 4):
            rotated = color.rotate_hue(rgb, 28.0)
            self.assertTrue(color.in_gamut(rotated), f"{rgb} -> {rotated}")
            self.assertLess(abs(color.to_lab(rotated)[0] - color.to_lab(rgb)[0]), 0.6, f"{rgb}")

    def test_hue_moves_by_28_degrees_when_no_chroma_reduction_is_needed(self):
        checked = 0
        for rgb in random_colors(300, 5):
            L, C, h = color.to_lch(rgb)
            if C < 8 or not color.in_gamut(color.from_lch_unclipped(L, C, h + 28.0)):
                continue  # the rotated color needs chroma reduction (or has no hue to speak of): other tests
            rotated = color.rotate_hue(rgb, 28.0)
            _, c2, h2 = color.to_lch(rotated)
            self.assertAlmostEqual(hue_delta(h, h2), 28.0, delta=2.0, msg=f"{rgb}")
            self.assertAlmostEqual(c2, C, delta=1.5, msg=f"{rgb}")
            checked += 1
        self.assertGreater(checked, 25, "too few colors exercised the no-reduction path")

    def test_saturated_colors_keep_their_hue_shift_after_chroma_reduction(self):
        for rgb in [(0.0, 0.0, 1.0), (0.0, 1.0, 0.0), (0.0, 1.0, 1.0)]:
            _, _, h = color.to_lch(rgb)
            _, c2, h2 = color.to_lch(color.rotate_hue(rgb, 28.0))
            self.assertAlmostEqual(hue_delta(h, h2), 28.0, delta=3.0, msg=f"{rgb}")
            self.assertGreater(c2, 5.0, "chroma reduction must not wipe the color out")

    def test_zero_degrees_returns_the_same_color(self):
        for rgb in random_colors(30, 6):
            for before, after in zip(rgb, color.rotate_hue(rgb, 0.0)):
                self.assertAlmostEqual(before, after, places=3)


class WithHueTest(unittest.TestCase):
    def test_sets_the_hue_and_keeps_lightness_inside_the_gamut(self):
        for rgb in random_colors(100, 7):
            result = color.with_hue(rgb, 70.0)
            self.assertTrue(color.in_gamut(result), f"{rgb} -> {result}")
            self.assertLess(abs(color.to_lab(result)[0] - color.to_lab(rgb)[0]), 0.6)
            _, chroma, hue = color.to_lch(result)
            if chroma > 8:
                self.assertAlmostEqual(hue_delta(70.0, hue), 0.0, delta=3.0, msg=f"{rgb}")


class FitLightnessTest(unittest.TestCase):
    def test_lightens_against_a_dark_backdrop(self):
        start = color.hex_to_rgb("#202020")
        backdrop = color.hex_to_rgb("#101010")
        fitted = color.fit_lightness(start, backdrop, 3.0, "lighter")
        self.assertIsNotNone(fitted)
        self.assertGreaterEqual(color.contrast(fitted, backdrop), 3.0)
        self.assertGreater(color.to_lab(fitted)[0], color.to_lab(start)[0])

    def test_darkens_against_a_light_backdrop(self):
        start = color.hex_to_rgb("#e0e0e0")
        backdrop = color.hex_to_rgb("#f0f0f0")
        fitted = color.fit_lightness(start, backdrop, 3.0, "darker")
        self.assertIsNotNone(fitted)
        self.assertGreaterEqual(color.contrast(fitted, backdrop), 3.0)
        self.assertLess(color.to_lab(fitted)[0], color.to_lab(start)[0])

    def test_unchanged_when_already_enough(self):
        start = color.hex_to_rgb("#ffffff")
        backdrop = color.hex_to_rgb("#000000")
        self.assertEqual(color.fit_lightness(start, backdrop, 3.0, "lighter"), start)

    def test_none_when_the_limit_is_reached(self):
        grey = color.hex_to_rgb("#808080")
        # Lightening grey against a white backdrop only lowers the contrast: the limit is hit with no solution.
        self.assertIsNone(color.fit_lightness(grey, (1, 1, 1), 7.0, "lighter"))
        # Darkening against a black backdrop likewise.
        self.assertIsNone(color.fit_lightness(grey, (0, 0, 0), 7.0, "darker"))

    def test_keeps_the_hue_of_the_input(self):
        start = color.hex_to_rgb("#334488")
        backdrop = color.hex_to_rgb("#101820")
        fitted = color.fit_lightness(start, backdrop, 4.5, "lighter")
        self.assertIsNotNone(fitted)
        self.assertAlmostEqual(hue_delta(color.to_lch(start)[2], color.to_lch(fitted)[2]), 0.0, delta=6.0)

    def test_rejects_an_unknown_direction(self):
        with self.assertRaises(ValueError):
            color.fit_lightness((0.5, 0.5, 0.5), (0, 0, 0), 3.0, "sideways")


if __name__ == "__main__":
    unittest.main()
