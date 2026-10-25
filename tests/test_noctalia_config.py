"""Tests for the Noctalia overlay config (spec section 3, rows 1-8): values the repo config must pin."""

import os
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "noctalia/.config/noctalia/config.toml"
CHECKER = ROOT / "scripts/check-plasma-intact.sh"
# Any image works for rendering the template; this one ships with plasma-workspace-wallpapers.
WALLPAPER_SAMPLE = Path("/usr/share/wallpapers/ColdRipple/contents/images/2560x1440.jpg")


class NoctaliaConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with CONFIG.open("rb") as handle:
            cls.config = tomllib.load(handle)

    def test_theme_follows_the_wallpaper_with_the_faithful_scheme(self):
        # faithful keeps the bar tinted with the wallpaper's own hue; m3-tonal-spot (the default) came out grey.
        theme = self.config["theme"]
        self.assertEqual(theme["mode"], "dark")
        self.assertEqual(theme["source"], "wallpaper")
        self.assertEqual(theme["wallpaper_scheme"], "faithful")

    def test_sync_color_scheme_is_false(self):
        self.assertIs(self.config["theme"]["sync_color_scheme"], False)

    def test_builtin_and_community_templates_are_off(self):
        templates = self.config["theme"]["templates"]
        self.assertIs(templates["enable_builtin_templates"], False)
        self.assertIs(templates["enable_community_templates"], False)

    def test_only_user_template_renders_the_niri_colors(self):
        users = self.config["theme"]["templates"]["user"]
        self.assertEqual(list(users), ["niri-colors"])
        template = users["niri-colors"]
        self.assertEqual(template, {"input_path": "templates/niri-colors.kdl", "output_path": "~/.config/niri/colors.kdl"})
        self.assertTrue((CONFIG.parent / template["input_path"]).is_file(), "the template file is not in the repo")

    def test_niri_colors_template_renders_a_valid_niri_include(self):
        # Render the template with Noctalia's own generator, then let niri validate a config that includes it.
        if not (shutil.which("noctalia") and shutil.which("niri")):
            self.skipTest("noctalia or niri is not installed")
        template = CONFIG.parent / "templates/niri-colors.kdl"
        with tempfile.TemporaryDirectory() as tmp:
            rendered = Path(tmp) / "colors.kdl"
            subprocess.run(
                ["noctalia", "theme", str(WALLPAPER_SAMPLE), "--scheme", "faithful", "--dark",
                 "-r", f"{template}:{rendered}"],
                capture_output=True, text=True, check=True,
            )
            text = rendered.read_text(encoding="utf-8")
            self.assertNotIn("{{", text, "unrendered template tokens left")
            self.assertRegex(text, r'active-color "#[0-9a-fA-F]{6}"')
            main = Path(tmp) / "config.kdl"
            main.write_text('include optional=true "colors.kdl"\n', encoding="utf-8")
            result = subprocess.run(["niri", "validate", "-c", str(main)], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_wallpaper_picker_uses_the_wallpapers_folder(self):
        self.assertEqual(self.config["wallpaper"]["directory"], "~/Pictures/Wallpapers")

    def test_polkit_agent_enabled(self):
        self.assertIs(self.config["shell"]["polkit_agent"], True)

    def test_clock_format_is_japanese_date_and_time(self):
        self.assertEqual(self.config["widget"]["clock"]["format"], "{:%-m}月{:%-d}日 {:%a} {:%H:%M}")

    def test_idle_turns_the_screens_off_after_30_minutes_then_locks_after_45(self):
        # Desk setup with two fixed monitors: long timeouts, and no automatic suspend that would cut builds short.
        idle = self.config["idle"]
        self.assertEqual(idle["behavior_order"], ["screen-off", "lock"])
        screen_off = idle["behavior"]["screen-off"]
        self.assertEqual((screen_off["action"], screen_off["timeout"]), ("screen_off", 1800))
        lock = idle["behavior"]["lock"]
        self.assertEqual((lock["action"], lock["timeout"]), ("lock", 2700))
        self.assertNotIn("suspend", idle["behavior"])

    def test_default_wallpaper_is_coldripple(self):
        path = self.config["wallpaper"]["default"]["path"]
        self.assertEqual(path, "/usr/share/wallpapers/ColdRipple/contents/images/2560x1440.jpg")
        self.assertTrue(Path(path).is_file(), f"{path} does not exist on this machine")

    def test_no_per_monitor_bar_tables(self):
        for name, bar in self.config.get("bar", {}).items():
            self.assertNotIn("monitor", bar, f"[bar.{name}] has per-monitor overrides")

    def test_dock_and_desktop_widgets_not_enabled(self):
        self.assertIs(self.config.get("dock", {}).get("enabled", False), False)
        self.assertIs(self.config.get("desktop_widgets", {}).get("enabled", False), False)

    def test_plasma_checker_accepts_the_repo_config(self):
        # Isolate both XDG dirs: the checker also reads the live ~/.config/noctalia, which depends on the machine.
        with tempfile.TemporaryDirectory() as home:
            hidden = {"NOCTALIA_REPO_CONFIG_DIR", "NOCTALIA_CONFIG_HOME", "NOCTALIA_STATE_HOME"}
            env = {key: value for key, value in os.environ.items() if key not in hidden}
            env["XDG_STATE_HOME"] = f"{home}/state"
            env["XDG_CONFIG_HOME"] = f"{home}/config"
            result = subprocess.run(
                [str(CHECKER), "noctalia"], env=env, capture_output=True, text=True, check=False
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
