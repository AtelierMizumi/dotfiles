"""Tests for the Noctalia overlay config (spec section 3, rows 1-8): values the repo config must pin."""

import os
import subprocess
import tempfile
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "noctalia/.config/noctalia/config.toml"
CHECKER = ROOT / "scripts/check-plasma-intact.sh"


class NoctaliaConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with CONFIG.open("rb") as handle:
            cls.config = tomllib.load(handle)

    def test_theme_uses_custom_mizu_dark(self):
        theme = self.config["theme"]
        self.assertEqual(theme["mode"], "dark")
        self.assertEqual(theme["source"], "custom")
        self.assertEqual(theme["custom_palette"], "Mizu")

    def test_sync_color_scheme_is_false(self):
        self.assertIs(self.config["theme"]["sync_color_scheme"], False)

    def test_all_templates_are_off(self):
        templates = self.config["theme"]["templates"]
        self.assertIs(templates["enable_builtin_templates"], False)
        self.assertIs(templates["enable_community_templates"], False)
        self.assertNotIn("user", templates)

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
