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

    def test_no_per_monitor_bar_tables(self):
        for name, bar in self.config.get("bar", {}).items():
            self.assertNotIn("monitor", bar, f"[bar.{name}] has per-monitor overrides")

    def test_dock_and_desktop_widgets_not_enabled(self):
        self.assertIs(self.config.get("dock", {}).get("enabled", False), False)
        self.assertIs(self.config.get("desktop_widgets", {}).get("enabled", False), False)

    def test_plasma_checker_accepts_the_repo_config(self):
        with tempfile.TemporaryDirectory() as state_home:
            env = {key: value for key, value in os.environ.items() if key != "NOCTALIA_REPO_CONFIG_DIR"}
            env["XDG_STATE_HOME"] = state_home
            result = subprocess.run(
                [str(CHECKER), "noctalia"], env=env, capture_output=True, text=True, check=False
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
