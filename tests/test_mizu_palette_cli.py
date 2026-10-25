"""Tests for the palette CLI (mizu_palette.py) and its adapters: atomic writes, exit codes, cache, overrides, niri file."""

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

PALETTE_DIR = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu/palette"
sys.path.insert(0, str(PALETTE_DIR))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import mizu_palette  # noqa: E402
from palette_core import adapters, analysis  # noqa: E402

from test_mizu_palette_build import FakeGenerator, solid  # noqa: E402

CLI = PALETTE_DIR / "mizu_palette.py"
CONFIG = Path(__file__).resolve().parent.parent / "niri/.config/niri/config.kdl"


class Env:
    """A temporary XDG-like layout and fakes for the two adapters."""

    def __init__(self, test):
        self.dir = Path(tempfile.mkdtemp())
        test.addCleanup(shutil.rmtree, self.dir, True)
        self.tokens = self.dir / "cache/tokens.json"
        self.niri = self.dir / "niri/colors.kdl"
        self.overrides = self.dir / "state/palette-overrides.json"
        self.cache = self.dir / "cache/palette-cache"
        self.wallpaper = self.dir / "wall.png"
        self.wallpaper.write_bytes(b"not really a png, only hashed in these tests")
        self.out = io.StringIO()
        self.generator = FakeGenerator()
        self.generator_calls = self.generator.calls
        self.grid = solid((0.2, 0.4, 0.8))

    def argv(self, *extra, wallpaper=None):
        return [str(wallpaper or self.wallpaper), "--tokens", str(self.tokens), "--niri", str(self.niri),
                "--overrides", str(self.overrides), "--cache-dir", str(self.cache), *extra]

    def run(self, *extra, wallpaper=None, grid_reader=None, generator_factory=None):
        return mizu_palette.main(
            self.argv(*extra, wallpaper=wallpaper),
            grid_reader=grid_reader or (lambda path: self.grid),
            generator_factory=generator_factory or (lambda path: self.generator),
            out=self.out,
        )

    def leftovers(self):
        return [p for p in self.dir.rglob("*") if p.is_file() and ".tmp" in p.name]


class WritesTest(unittest.TestCase):
    def setUp(self):
        self.env = Env(self)

    def test_writes_tokens_and_niri_file(self):
        self.assertEqual(self.env.run("--mode", "dark"), 0)
        tokens = json.loads(self.env.tokens.read_text())
        self.assertEqual(tokens["schema"], "mizu.tokens/1")
        self.assertEqual(tokens["wallpaper"], str(self.env.wallpaper))
        niri = self.env.niri.read_text()
        self.assertIn(f'active-color "{tokens["color"]["accent"]}"', niri)
        self.assertIn(f'urgent-color "{tokens["color"]["danger"]}"', niri)
        self.assertIn(f'color "{tokens["color"]["accent"]}80"', niri)

    def test_creates_missing_parent_directories(self):
        self.assertFalse(self.env.tokens.parent.exists())
        self.assertEqual(self.env.run(), 0)
        self.assertTrue(self.env.tokens.is_file() and self.env.niri.is_file())

    def test_no_temp_files_are_left_behind(self):
        self.env.run()
        self.assertEqual(self.env.leftovers(), [])

    def test_prints_the_tokens_path(self):
        self.env.run()
        self.assertEqual(self.env.out.getvalue().strip(), str(self.env.tokens))

    def test_a_second_run_replaces_the_files(self):
        self.env.run("--mode", "dark")
        first = json.loads(self.env.tokens.read_text())["mode"]
        self.env.run("--mode", "light")
        self.assertEqual((first, json.loads(self.env.tokens.read_text())["mode"]), ("dark", "light"))


class FailureTest(unittest.TestCase):
    def setUp(self):
        self.env = Env(self)
        self.env.run()
        self.before = (self.env.tokens.read_bytes(), self.env.niri.read_bytes())

    def assert_untouched(self):
        self.assertEqual((self.env.tokens.read_bytes(), self.env.niri.read_bytes()), self.before)
        self.assertEqual(self.env.leftovers(), [])

    def test_failed_generator_exits_2_and_keeps_both_old_files(self):
        def broken(path):
            def generate(scheme, mode):
                raise adapters.GeneratorError("noctalia theme exited 1")
            return generate

        other = self.env.dir / "other.png"
        other.write_bytes(b"different bytes so the cache cannot answer")
        self.assertEqual(self.env.run(wallpaper=other, generator_factory=broken), 2)
        self.assert_untouched()

    def test_unreadable_image_exits_2_and_keeps_both_old_files(self):
        def unreadable(path):
            raise adapters.ImageError("magick exited 1")

        other = self.env.dir / "other.png"
        other.write_bytes(b"different bytes so the cache cannot answer")
        self.assertEqual(self.env.run(wallpaper=other, grid_reader=unreadable), 2)
        self.assert_untouched()

    def test_missing_wallpaper_file_exits_2(self):
        self.assertEqual(self.env.run(wallpaper=self.env.dir / "nope.png"), 2)
        self.assert_untouched()

    def test_interrupted_write_leaves_whole_files_and_no_temp_files(self):
        other = self.env.dir / "other.png"
        other.write_bytes(b"another wallpaper")
        real_replace = os.replace
        calls = []

        def flaky(src, dst):
            calls.append(dst)
            if len(calls) == 2:
                raise OSError("disk fell off")
            return real_replace(src, dst)

        with mock.patch("os.replace", flaky):
            code = self.env.run("--mode", "light", wallpaper=other)
        self.assertEqual(code, 2)
        json.loads(self.env.tokens.read_text())  # whole, whichever generation it belongs to
        self.assertEqual(self.env.niri.read_bytes(), self.before[1])
        self.assertEqual(self.env.leftovers(), [])


class UsageTest(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, "-I", "-B", str(CLI), *args], capture_output=True, text=True,
                              check=False)

    def test_usage_errors_exit_64(self):
        for args in ([], ["a.png", "--mode", "sepia"], ["a.png", "--nonsense"], ["a.png", "b.png"]):
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertEqual(result.returncode, 64, result.stderr)
                self.assertIn("usage", result.stderr.lower())


class CacheTest(unittest.TestCase):
    def setUp(self):
        self.env = Env(self)

    def test_cache_hit_does_not_call_the_generator(self):
        self.env.run("--mode", "dark")
        self.assertEqual(len(self.env.generator_calls), 1)
        first = self.env.tokens.read_text()
        self.env.tokens.unlink()
        self.env.niri.unlink()
        self.assertEqual(self.env.run("--mode", "dark"), 0)
        self.assertEqual(len(self.env.generator_calls), 1, "the generator ran again on a cache hit")
        self.assertEqual(self.env.tokens.read_text(), first)
        self.assertTrue(self.env.niri.is_file())

    def test_cache_hit_does_not_even_read_the_image(self):
        self.env.run("--mode", "dark")

        def exploding(path):
            raise AssertionError("the image was decoded on a cache hit")

        self.assertEqual(self.env.run("--mode", "dark", grid_reader=exploding), 0)

    def test_a_different_mode_is_a_miss(self):
        self.env.run("--mode", "dark")
        self.env.run("--mode", "light")
        self.assertEqual(len(self.env.generator_calls), 2)

    def test_different_image_bytes_are_a_miss(self):
        self.env.run()
        self.env.wallpaper.write_bytes(b"the same path, a new picture")
        self.env.run()
        self.assertEqual(len(self.env.generator_calls), 2)

    def test_changed_overrides_are_a_miss(self):
        self.env.run()
        self.env.overrides.parent.mkdir(parents=True)
        self.env.overrides.write_text(json.dumps({str(self.env.wallpaper): {"scheme": "vibrant"}}))
        self.env.run()
        self.assertEqual(len(self.env.generator_calls), 2)

    def test_the_cached_tokens_carry_the_current_wallpaper_path(self):
        self.env.run()
        copy = self.env.dir / "copy.png"
        shutil.copy(self.env.wallpaper, copy)  # same bytes, other path
        self.env.run(wallpaper=copy)
        self.assertEqual(len(self.env.generator_calls), 1)
        self.assertEqual(json.loads(self.env.tokens.read_text())["wallpaper"], str(copy))


class OverridesTest(unittest.TestCase):
    def setUp(self):
        self.env = Env(self)
        self.env.overrides.parent.mkdir(parents=True)

    def test_per_wallpaper_override_wins_over_the_default_entry(self):
        self.env.overrides.write_text(json.dumps({
            "*": {"scheme": "soft"},
            str(self.env.wallpaper): {"scheme": "vibrant"},
        }))
        self.env.run()
        self.assertEqual(json.loads(self.env.tokens.read_text())["scheme"], "vibrant")

    def test_default_entry_applies_to_other_wallpapers(self):
        self.env.overrides.write_text(json.dumps({"*": {"scheme": "soft"}}))
        self.env.run()
        self.assertEqual(json.loads(self.env.tokens.read_text())["scheme"], "soft")

    def test_malformed_overrides_warn_and_the_run_continues(self):
        self.env.overrides.write_text("{ not json")
        with mock.patch("sys.stderr") as err:
            code = self.env.run()
        self.assertEqual(code, 0)
        self.assertIn("overrides", "".join(call.args[0] for call in err.write.call_args_list).lower())
        self.assertTrue(self.env.tokens.is_file())


class NiriFileTest(unittest.TestCase):
    def test_render_is_valid_for_niri_as_an_included_file(self):
        if not shutil.which("niri"):
            self.skipTest("niri is not installed")
        env = Env(self)
        env.run()
        link_dir = env.dir / "deployed"
        link_dir.mkdir()
        (link_dir / "config.kdl").symlink_to(CONFIG)
        shutil.copy(env.niri, link_dir / "colors.kdl")
        result = subprocess.run(["niri", "validate", "-c", str(link_dir / "config.kdl")], capture_output=True,
                                text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("optional include not found", result.stdout + result.stderr)


class RealToolsTest(unittest.TestCase):
    """The real magick and `noctalia theme`, on a synthetic colorful image."""

    def test_tokens_agree_with_noctalia_theme_and_colors_kdl_agrees_with_the_tokens(self):
        missing = [tool for tool in ("magick", "noctalia") if not shutil.which(tool)]
        if missing:
            self.skipTest(f"{', '.join(missing)} not installed")
        env = Env(self)
        image = env.dir / "colorful.png"
        subprocess.run(["magick", "-size", "640x360", "gradient:#2060ff-#ff40a0", str(image)], check=True)
        result = subprocess.run([sys.executable, "-I", "-B", str(CLI), *env.argv("--mode", "dark", wallpaper=image)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        tokens = json.loads(env.tokens.read_text())
        theme = subprocess.run(["noctalia", "theme", str(image), "--scheme", tokens["scheme"], "--dark"],
                               capture_output=True, text=True, check=True)
        primary = json.loads(theme.stdout)["primary"]
        from palette_core import color
        _, c1, h1 = color.to_lch(color.hex_to_rgb(primary))
        _, c2, h2 = color.to_lch(color.hex_to_rgb(tokens["color"]["accent"]))
        self.assertGreater(c1, 8, "the synthetic image should give a colorful primary")
        self.assertLess(abs((h2 - h1 + 180) % 360 - 180), 10, f"accent {tokens['color']['accent']} vs primary {primary}")
        self.assertIn(f'active-color "{tokens["color"]["accent"]}"', env.niri.read_text())


class AdaptersTest(unittest.TestCase):
    def test_render_niri_kdl_has_the_three_ring_colors_and_the_hint(self):
        tokens = {"wallpaper": "/x.png", "color": {"accent": "#112233", "surfaceDivider": "#445566",
                                                    "danger": "#778899"}}
        text = adapters.render_niri_kdl(tokens)
        for needle in ('active-color "#112233"', 'inactive-color "#445566"', 'urgent-color "#778899"',
                       'color "#11223380"'):
            self.assertIn(needle, text)

    def test_atomic_write_replaces_in_place_and_leaves_no_temp(self):
        env = Env(self)
        target = env.dir / "sub/file.txt"
        adapters.atomic_write(target, "one")
        adapters.atomic_write(target, "two")
        self.assertEqual(target.read_text(), "two")
        self.assertEqual(env.leftovers(), [])

    def test_read_grid_downscales_to_96_by_54(self):
        if not shutil.which("magick"):
            self.skipTest("magick is not installed")
        env = Env(self)
        image = env.dir / "red.png"
        subprocess.run(["magick", "-size", "320x200", "xc:#ff0000", str(image)], check=True)
        grid = adapters.read_grid(image)
        self.assertEqual((grid.width, grid.height, len(grid.pixels)), (96, 54, 96 * 54))
        self.assertAlmostEqual(grid.pixels[0][0], 1.0, places=2)
        self.assertIsInstance(grid, analysis.Grid)

    def test_read_grid_raises_image_error_for_a_non_image(self):
        if not shutil.which("magick"):
            self.skipTest("magick is not installed")
        env = Env(self)
        with self.assertRaises(adapters.ImageError):
            adapters.read_grid(env.wallpaper)


if __name__ == "__main__":
    unittest.main()
