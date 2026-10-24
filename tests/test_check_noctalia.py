"""Tests for scripts/check_noctalia.py: all theme templates off and sync_color_scheme false, repo config and GUI overrides."""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_noctalia  # noqa: E402

GOOD = """\
[theme]
sync_color_scheme = false

[theme.templates]
enable_builtin_templates = false
enable_community_templates = false
"""


class CheckNoctaliaTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.config_dir = Path(self._tmp.name) / "config"
        self.config_dir.mkdir()
        self.settings = Path(self._tmp.name) / "state" / "settings.toml"

    def write_config(self, text, name="config.toml"):
        (self.config_dir / name).write_text(text, encoding="utf-8")

    def write_settings(self, text):
        self.settings.parent.mkdir(parents=True, exist_ok=True)
        self.settings.write_text(text, encoding="utf-8")

    def problems(self):
        return check_noctalia.check(self.config_dir, self.settings)

    def assert_violation(self, prefix):
        problems = self.problems()
        self.assertTrue(
            any(line.startswith(prefix) for line in problems),
            f"expected a line starting with {prefix!r}, got {problems!r}",
        )

    def test_missing_sync_color_scheme_is_violation(self):
        # Upstream default is true, so leaving the key out must be reported.
        self.write_config(GOOD.replace("sync_color_scheme = false\n", ""))
        self.assert_violation("SYNC_COLOR_SCHEME NOT FALSE")

    def test_sync_false_is_ok(self):
        self.write_config(GOOD)
        self.assertEqual(self.problems(), [])

    def test_builtin_templates_enabled_is_violation(self):
        self.write_config(GOOD.replace("enable_builtin_templates = false", "enable_builtin_templates = true"))
        self.assert_violation("TEMPLATE ENABLED")

    def test_community_templates_enabled_is_violation(self):
        self.write_config(GOOD.replace("enable_community_templates = false", "enable_community_templates = true"))
        self.assert_violation("TEMPLATE ENABLED")

    def test_settings_toml_template_ids_is_violation(self):
        self.write_config(GOOD)
        self.write_settings('[theme.templates]\nbuiltin_ids = ["x"]\n')
        self.assert_violation("TEMPLATE ENABLED")

    def test_settings_toml_user_template_without_enabled_false_is_violation(self):
        self.write_config(GOOD)
        self.write_settings('[theme.templates.user.my_app]\noutput_path = "~/.config/my-app/theme.css"\n')
        self.assert_violation("TEMPLATE ENABLED")
        self.write_settings('[theme.templates.user.my_app]\nenabled = false\n')
        self.assertEqual(self.problems(), [])

    def test_settings_toml_sync_true_overrides_repo_false(self):
        self.write_config(GOOD)
        self.write_settings("[theme]\nsync_color_scheme = true\n")
        problems = self.problems()
        self.assertTrue(
            any(line.startswith("SYNC_COLOR_SCHEME NOT FALSE") and "settings.toml" in line for line in problems),
            f"expected a violation naming settings.toml, got {problems!r}",
        )

    def test_settings_toml_absent_is_ok(self):
        self.write_config(GOOD)
        self.assertFalse(self.settings.exists())
        self.assertEqual(self.problems(), [])

    def test_settings_toml_malformed_is_violation(self):
        self.write_config(GOOD)
        self.write_settings("[theme\nsync_color_scheme = ")
        self.assert_violation("UNREADABLE TOML")

    def test_later_toml_file_wins_alphabetically(self):
        self.write_config(GOOD, name="a.toml")
        self.write_config("[theme]\nsync_color_scheme = true\n", name="b.toml")
        self.assert_violation("SYNC_COLOR_SCHEME NOT FALSE")
        self.write_config("[theme]\nsync_color_scheme = true\n", name="a.toml")
        self.write_config(GOOD, name="b.toml")
        self.assertEqual(self.problems(), [])


if __name__ == "__main__":
    unittest.main()
