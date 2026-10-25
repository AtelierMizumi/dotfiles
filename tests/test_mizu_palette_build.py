"""Tests for palette_core.build.build(): the pure grid -> tokens function, with a fake generator (no display, no noctalia)."""

import random
import sys
import unittest
from pathlib import Path

PALETTE_DIR = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu/palette"
sys.path.insert(0, str(PALETTE_DIR))

from palette_core import analysis, build, color  # noqa: E402

SURFACES = ("bar", "phone", "widget")
SCHEMA_COLOR_KEYS = {
    "accent", "accent2", "outline", "line", "shadow", "surface", "surfaceHover", "surfaceDivider", "surfaceRing",
    "ring", "ink", "inkMuted", "onAccent", "chip", "onChip", "scrim", "hoverTint", "paper", "danger", "warning",
    "series",
}
SCHEMA_PHONE_KEYS = {"rimHighlight", "bezel", "wallLight", "wallMid", "wallDark", "hardware", "lens", "lensGlint",
                     "shadowAlpha"}
SURFACE_KEYS = {"housing", "alpha", "backdrop", "ink", "inkMuted", "accent", "onAccent"}


def roles(mode, weak_ink=False, weak_on_primary=False, primary=None, ink=None):
    """A realistic role dict like `noctalia theme` returns, with optional deliberately weak foregrounds."""
    if mode == "dark":
        r = {
            "surface": "#14161a", "surface_container": "#1c1f24", "surface_container_low": "#181b1f",
            "surface_container_lowest": "#0f1114", "surface_container_high": "#262a30", "surface_bright": "#33373e",
            "surface_dim": "#0f1114", "on_surface": "#222529" if weak_ink else "#e3e6ea",
            "on_surface_variant": "#23262b" if weak_ink else "#b4bac2", "outline": "#6b7280",
            "outline_variant": "#3a3f47", "primary": "#7aa7ff", "on_primary": "#0b1b3a",
            "secondary": "#9aa5b8", "secondary_container": "#2c3a52", "on_secondary_container": "#d3e0f7",
            "tertiary": "#b79cff", "error": "#ff6b7a", "scrim": "#000000", "shadow": "#000000",
        }
    else:
        r = {
            "surface": "#f6f7f9", "surface_container": "#eceef2", "surface_container_low": "#f1f2f5",
            "surface_container_lowest": "#ffffff", "surface_container_high": "#e3e6eb", "surface_bright": "#ffffff",
            "surface_dim": "#d5d9df", "on_surface": "#e0e3e8" if weak_ink else "#1b1d21",
            "on_surface_variant": "#e4e7ec" if weak_ink else "#4a5058", "outline": "#7c838c",
            "outline_variant": "#c4c9d0", "primary": "#2a5ad7", "on_primary": "#ffffff",
            "secondary": "#57657f", "secondary_container": "#d6e0f5", "on_secondary_container": "#1d2a44",
            "tertiary": "#7f4fd1", "error": "#c4283c", "scrim": "#000000", "shadow": "#000000",
        }
    if weak_on_primary:
        r["on_primary"] = r["primary"]
    if primary:
        r["primary"] = primary
    if ink:
        r["on_surface"] = ink
    return r


class FakeGenerator:
    def __init__(self, **options):
        self.options = options
        self.calls = []

    def __call__(self, scheme, mode):
        self.calls.append((scheme, mode))
        return roles(mode, **self.options)


def solid(rgb, width=32, height=18):
    return analysis.Grid(width, height, [rgb] * (width * height))


def random_grid(seed, width=32, height=18):
    rng = random.Random(seed)
    base = (rng.random(), rng.random(), rng.random())
    other = (rng.random(), rng.random(), rng.random())
    noise = rng.choice([0.0, 0.05, 0.3])
    pixels = []
    for y in range(height):
        for x in range(width):
            t = (x / (width - 1)) * rng.choice([0.0, 1.0]) if y == 0 else (x / (width - 1)) * (seed % 2)
            pixels.append(tuple(max(0.0, min(1.0, base[i] + (other[i] - base[i]) * t + rng.uniform(-noise, noise)))
                                for i in range(3)))
    return analysis.Grid(width, height, pixels)


def hue_delta(a, b):
    return (b - a + 180.0) % 360.0 - 180.0


class BuildSchemaTest(unittest.TestCase):
    def setUp(self):
        self.tokens = build.build(solid((0.2, 0.4, 0.8)), FakeGenerator(), {}, "dark")

    def test_tokens_have_every_key_of_the_schema(self):
        self.assertEqual(self.tokens["schema"], "mizu.tokens/1")
        for key in ("wallpaper", "scheme", "mode", "analysis", "color", "surface", "phone", "contrast"):
            self.assertIn(key, self.tokens)
        self.assertEqual(set(self.tokens["color"]), SCHEMA_COLOR_KEYS)
        self.assertEqual(len(self.tokens["color"]["series"]), 5)
        self.assertEqual(set(self.tokens["phone"]), SCHEMA_PHONE_KEYS)
        self.assertEqual(set(self.tokens["surface"]), set(SURFACES))
        for name in SURFACES:
            self.assertEqual(set(self.tokens["surface"][name]), SURFACE_KEYS)
        self.assertEqual(set(self.tokens["analysis"]), {"L", "chroma", "busy"})

    def test_every_color_is_a_six_digit_hex(self):
        def walk(value):
            if isinstance(value, dict):
                for child in value.values():
                    yield from walk(child)
            elif isinstance(value, list):
                for child in value:
                    yield from walk(child)
            elif isinstance(value, str):
                yield value

        colors = list(walk(self.tokens["color"])) + list(walk(self.tokens["phone"]))
        colors += [s[k] for s in self.tokens["surface"].values() for k in ("housing", "backdrop", "ink", "inkMuted",
                                                                            "accent", "onAccent")]
        for value in colors:
            self.assertRegex(value, r"^#[0-9a-f]{6}$")

    def test_generator_receives_the_picked_scheme_and_mode_once(self):
        gen = FakeGenerator()
        tokens = build.build(solid((0.2, 0.4, 0.8)), gen, {}, "dark")
        self.assertEqual(gen.calls, [(tokens["scheme"], "dark")])
        self.assertEqual(tokens["scheme"], "faithful")

    def test_missing_generator_role_is_named_in_the_error(self):
        def broken(scheme, mode):
            r = roles(mode)
            del r["secondary_container"]
            return r

        with self.assertRaises(ValueError) as caught:
            build.build(solid((0.5, 0.5, 0.5)), broken, {}, "dark")
        self.assertIn("secondary_container", str(caught.exception))

    def test_phone_shadow_alpha_is_the_upstream_value(self):
        self.assertEqual(self.tokens["phone"]["shadowAlpha"], 0.17)


class OverridesTest(unittest.TestCase):
    def test_scheme_override_reaches_the_generator(self):
        gen = FakeGenerator()
        tokens = build.build(solid((0.5, 0.5, 0.5)), gen, {"scheme": "vibrant"}, "dark")
        self.assertEqual(gen.calls, [("vibrant", "dark")])
        self.assertEqual(tokens["scheme"], "vibrant")

    def test_mode_override_beats_the_mode_argument(self):
        gen = FakeGenerator()
        tokens = build.build(solid((0.9, 0.9, 0.9)), gen, {"mode": "light"}, "dark")
        self.assertEqual(tokens["mode"], "light")
        self.assertEqual(gen.calls[0][1], "light")

    def test_accent_override_replaces_the_generators_primary_but_is_still_corrected(self):
        tokens = build.build(solid((0.5, 0.5, 0.5)), FakeGenerator(), {"accent": "#ff00aa"}, "dark")
        accent = color.hex_to_rgb(tokens["color"]["accent"])
        _, chroma, hue = color.to_lch(accent)
        _, _, want_hue = color.to_lch(color.hex_to_rgb("#ff00aa"))
        self.assertAlmostEqual(hue_delta(want_hue, hue), 0.0, delta=8.0)
        for name in SURFACES:
            surface = tokens["surface"][name]
            self.assertGreaterEqual(color.contrast(accent, color.hex_to_rgb(surface["backdrop"])), 3.0)

    def test_auto_mode_picks_light_for_a_bright_wallpaper_and_dark_for_a_dark_one(self):
        self.assertEqual(build.build(solid((0.95, 0.95, 0.9)), FakeGenerator(), {}, "auto")["mode"], "light")
        self.assertEqual(build.build(solid((0.05, 0.06, 0.1)), FakeGenerator(), {}, "auto")["mode"], "dark")

    def test_auto_mode_stays_dark_when_the_bar_region_is_dark_on_a_bright_image(self):
        w, h = 32, 18
        pixels = [(0.05, 0.05, 0.08) if y == 0 else (0.95, 0.95, 0.95) for y in range(h) for x in range(w)]
        tokens = build.build(analysis.Grid(w, h, pixels), FakeGenerator(), {}, "auto")
        self.assertEqual(tokens["mode"], "dark")


class OpacityTest(unittest.TestCase):
    def test_a_calm_wallpaper_gets_the_base_opacity(self):
        tokens = build.build(solid((0.3, 0.3, 0.35)), FakeGenerator(), {}, "dark")
        for name in SURFACES:
            self.assertAlmostEqual(tokens["surface"][name]["alpha"], 0.62, delta=0.005)

    def test_a_busy_wallpaper_gets_more_opacity_but_never_more_than_0_97(self):
        w, h = 32, 18
        pixels = [(0, 0, 0) if (x + y) % 2 == 0 else (1, 1, 1) for y in range(h) for x in range(w)]
        tokens = build.build(analysis.Grid(w, h, pixels), FakeGenerator(), {}, "dark")
        for name in SURFACES:
            alpha = tokens["surface"][name]["alpha"]
            self.assertGreaterEqual(alpha, 0.9)
            self.assertLessEqual(alpha, 0.97)


class OpacityRescuesTheGeneratorsInkTest(unittest.TestCase):
    """A hostile wallpaper behind the housing is answered with more opacity, not by replacing the theme's ink."""

    def test_bright_wallpaper_in_dark_mode(self):
        tokens = build.build(solid((1, 1, 1)), FakeGenerator(), {"mode": "dark"}, "dark")
        for name in SURFACES:
            surface = tokens["surface"][name]
            self.assertGreater(surface["alpha"], 0.65, f"{name}: opacity was not raised")
            self.assertEqual(surface["ink"], roles("dark")["on_surface"], f"{name}: the generator's ink was replaced")

    def test_dark_wallpaper_in_light_mode(self):
        # A mid-dark ink: the black cells behind the light housing pull the backdrop down until it no longer reads.
        tokens = build.build(solid((0, 0, 0)), FakeGenerator(ink="#555a62"), {"mode": "light"}, "light")
        for name in SURFACES:
            surface = tokens["surface"][name]
            self.assertGreater(surface["alpha"], 0.65, f"{name}: opacity was not raised")
            self.assertEqual(surface["ink"], "#555a62", f"{name}: the generator's ink was replaced")


class ContrastGuaranteeTest(unittest.TestCase):
    """Text >= 4.5:1 and accent, line >= 3:1 against the backdrop each surface really sits on, in both modes."""

    def check(self, grid, mode, **gen_options):
        tokens = build.build(grid, FakeGenerator(**gen_options), {}, mode)
        for name in SURFACES:
            surface = tokens["surface"][name]
            backdrop = color.hex_to_rgb(surface["backdrop"])
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["ink"]), backdrop), 4.5, f"{name} ink")
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["inkMuted"]), backdrop), 4.5,
                                    f"{name} inkMuted")
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["accent"]), backdrop), 3.0, f"{name} accent")
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(tokens["color"]["line"]), backdrop), 3.0,
                                    f"{name} line")
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["onAccent"]),
                                                   color.hex_to_rgb(surface["accent"])), 4.5, f"{name} onAccent")
            self.assertGreaterEqual(surface["alpha"], 0.55)
            self.assertLessEqual(surface["alpha"], 0.97)
            self.assertGreaterEqual(tokens["contrast"][f"{name}.ink"], 4.5)
        chip, on_chip = (color.hex_to_rgb(tokens["color"][k]) for k in ("chip", "onChip"))
        self.assertGreaterEqual(color.contrast(on_chip, chip), 4.5, "onChip")
        return tokens

    def test_random_grids_in_dark_and_light_mode_with_weak_foregrounds(self):
        for seed in range(120):
            for mode in ("dark", "light"):
                with self.subTest(seed=seed, mode=mode):
                    self.check(random_grid(seed), mode, weak_ink=True, weak_on_primary=True)

    def test_random_grids_with_a_healthy_generator(self):
        for seed in range(60):
            for mode in ("dark", "light"):
                with self.subTest(seed=seed, mode=mode):
                    self.check(random_grid(1000 + seed), mode)

    def test_extreme_backdrops(self):
        for rgb in ((1, 1, 1), (0, 0, 0), (0.5, 0.5, 0.5), (0.18, 0.18, 0.18)):
            for mode in ("dark", "light"):
                with self.subTest(rgb=rgb, mode=mode):
                    self.check(solid(rgb), mode, weak_ink=True)

    def test_backdrop_is_the_worst_case_cell_seen_through_the_housing(self):
        grid = random_grid(7)
        for mode in ("dark", "light"):
            tokens = build.build(grid, FakeGenerator(), {}, mode)
            for name in SURFACES:
                stats = analysis.region_stats(grid, analysis.REGIONS[name])
                lum = stats.lum_hi if mode == "dark" else stats.lum_lo
                surface = tokens["surface"][name]
                housing = color.hex_to_rgb(surface["housing"])
                alpha = surface["alpha"]
                # The worst cell counts as the grey of that luminance (sRGB-encoded), seen through the housing at
                # its opacity; the surface is drawn by plain sRGB alpha blending.
                level = _gamma(lum)
                expected = tuple(level * (1 - alpha) + housing[i] * alpha for i in range(3))
                got = color.hex_to_rgb(surface["backdrop"])
                for a, b in zip(expected, got):
                    self.assertAlmostEqual(a, b, delta=0.01, msg=f"{mode} {name}")


class AccentFallbackTest(unittest.TestCase):
    """A generator whose housing fights its accent forces the lightness limit; the accent then falls back to the ink."""

    def test_dark_mode_accent_falls_back_when_lightening_cannot_reach_3_to_1(self):
        def pathological(scheme, mode):
            r = roles("dark")
            r["surface_container"] = "#f0f0f0"
            r["primary"] = "#f4f4f4"
            r["on_surface"] = "#101010"
            return r

        tokens = build.build(solid((1, 1, 1)), pathological, {}, "dark")
        for name in SURFACES:
            surface = tokens["surface"][name]
            backdrop = color.hex_to_rgb(surface["backdrop"])
            self.assertEqual(surface["accent"], surface["ink"], name)
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["accent"]), backdrop), 3.0)

    def test_light_mode_accent_falls_back_when_darkening_cannot_reach_3_to_1(self):
        def pathological(scheme, mode):
            r = roles("light")
            r["surface_container"] = "#101010"
            r["primary"] = "#0c0c0c"
            r["on_surface"] = "#f0f0f0"
            return r

        tokens = build.build(solid((0, 0, 0)), pathological, {}, "light")
        for name in SURFACES:
            surface = tokens["surface"][name]
            backdrop = color.hex_to_rgb(surface["backdrop"])
            self.assertEqual(surface["accent"], surface["ink"], name)
            self.assertGreaterEqual(color.contrast(color.hex_to_rgb(surface["accent"]), backdrop), 3.0)


class Accent2Test(unittest.TestCase):
    def test_accent2_is_28_degrees_from_the_accent_with_the_same_lightness(self):
        checked = 0
        for seed in range(80):
            for mode in ("dark", "light"):
                tokens = build.build(random_grid(2000 + seed), FakeGenerator(), {}, mode)
                accent = color.hex_to_rgb(tokens["color"]["accent"])
                accent2 = color.hex_to_rgb(tokens["color"]["accent2"])
                self.assertTrue(color.in_gamut(accent2))
                L1, C1, h1 = color.to_lch(accent)
                L2, C2, h2 = color.to_lch(accent2)
                if C1 < 12 or C2 < 12:
                    continue  # hex rounding blurs the hue of near-greys (and the accent may have fallen back to ink)
                self.assertAlmostEqual(hue_delta(h1, h2), 28.0, delta=4.0, msg=f"seed {seed} {mode}")
                self.assertAlmostEqual(L1, L2, delta=1.5)
                checked += 1
        self.assertGreater(checked, 40)

    def test_saturated_blue_accent_keeps_its_hue_shift_inside_the_gamut(self):
        for primary in ("#0000ff", "#00ff00", "#00ffff", "#ff00ff"):
            tokens = build.build(solid((0.3, 0.3, 0.3)), lambda s, m, p=primary: roles(m, primary=p), {}, "dark")
            accent2 = color.hex_to_rgb(tokens["color"]["accent2"])
            self.assertTrue(color.in_gamut(accent2))
            accent = color.hex_to_rgb(tokens["color"]["accent"])
            _, _, h1 = color.to_lch(accent)
            _, c2, h2 = color.to_lch(accent2)
            self.assertAlmostEqual(hue_delta(h1, h2), 28.0, delta=4.0, msg=primary)
            self.assertGreater(c2, 5.0)


def _gamma(lum):
    """The sRGB channel value of the grey (r = g = b) whose WCAG luminance is lum."""
    return 12.92 * lum if lum <= 0.0031308 else 1.055 * lum ** (1 / 2.4) - 0.055




class ChipTest(unittest.TestCase):
    """The chip (a pill behind small labels) must not glare, and its label must stand out from it."""

    def build_with(self, mode, **role_changes):
        def generator(scheme, mode_):
            changed = roles(mode_)
            changed.update(role_changes)
            return changed

        return build.build(solid((0.2, 0.4, 0.8)), generator, {}, mode)

    def chip_and_label(self, tokens):
        return (color.hex_to_rgb(tokens["color"]["chip"]), color.hex_to_rgb(tokens["color"]["onChip"]))

    def test_a_neon_container_is_calmed_down_in_dark_mode(self):
        tokens = self.build_with("dark", secondary_container="#1849e3", on_secondary_container="#e8edff")
        L, C, _ = color.to_lch(self.chip_and_label(tokens)[0])
        self.assertLessEqual(C, 26.0, "chip chroma")
        self.assertGreaterEqual(L, 22.0)
        self.assertLessEqual(L, 34.0)

    def test_a_calm_container_is_left_alone_in_dark_mode(self):
        tokens = self.build_with("dark")
        self.assertEqual(tokens["color"]["chip"], "#2c3a52")

    def test_a_dark_chip_never_gets_a_dark_label(self):
        tokens = self.build_with("dark", on_secondary_container="#10131a")
        chip, label = self.chip_and_label(tokens)
        self.assertGreater(color.luminance(label), color.luminance(chip))
        self.assertGreaterEqual(color.contrast(label, chip), 4.5)

    def test_a_light_chip_never_gets_a_light_label(self):
        tokens = self.build_with("light", on_secondary_container="#f2f4f8")
        chip, label = self.chip_and_label(tokens)
        self.assertLess(color.luminance(label), color.luminance(chip))
        self.assertGreaterEqual(color.contrast(label, chip), 4.5)


if __name__ == "__main__":
    unittest.main()
