"""Tests for scripts/check_noctalia.py: all theme templates off and sync_color_scheme false, repo config and GUI overrides."""

import contextlib
import io
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

    # A user template may only render a file inside the niri config directory, which Plasma never reads, and may not
    # run any hook. Every other key or target is reported (fail closed).
    def test_user_template_into_the_niri_dir_is_ok(self):
        for output in ("~/.config/niri/colors.kdl", "$XDG_CONFIG_HOME/niri/colors.kdl"):
            with self.subTest(output=output):
                self.write_config(
                    GOOD + f'\n[theme.templates.user.niri-colors]\ninput_path = "templates/niri-colors.kdl"\n'
                    f'output_path = "{output}"\n'
                )
                self.assertEqual(self.problems(), [])

    def test_user_template_outside_the_niri_dir_is_violation(self):
        # config.kdl is a stow symlink into this repo, so rendering over it would rewrite the repo file.
        for output in ("~/.config/gtk-3.0/gtk.css", "~/.config/niri/../kdeglobals", "~/.config/niri", "/tmp/x.kdl",
                       "~/.config/niri/config.kdl", "$XDG_CONFIG_HOME/niri/config.kdl"):
            with self.subTest(output=output):
                self.write_config(
                    GOOD + f'\n[theme.templates.user.t]\ninput_path = "t.kdl"\noutput_path = "{output}"\n'
                )
                self.assert_violation("TEMPLATE ENABLED")

    def test_user_template_with_a_hook_is_violation(self):
        for extra in ('post_hook = "touch ~/x"', 'undo_hook = "rm x"', 'output_path_dynamic = "echo ~/x"'):
            with self.subTest(extra=extra):
                self.write_config(
                    GOOD + '\n[theme.templates.user.t]\ninput_path = "t.kdl"\n'
                    f'output_path = "~/.config/niri/colors.kdl"\n{extra}\n'
                )
                self.assert_violation("TEMPLATE ENABLED")

    def test_user_template_without_output_path_is_violation(self):
        self.write_config(GOOD + '\n[theme.templates.user.t]\ninput_path = "t.kdl"\n')
        self.assert_violation("TEMPLATE ENABLED")

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

    def test_include_table_is_unsupported_violation(self):
        # Noctalia expands [include] files; the checker does not, so it must fail closed instead of saying OK.
        self.write_config(GOOD + '\n[include]\nfiles = ["extra.toml"]\n')
        self.assert_violation("UNSUPPORTED INCLUDE")

    def test_include_autoload_false_is_violation(self):
        self.write_config(GOOD + "\n[include]\nautoload = false\n")
        self.assert_violation("UNSUPPORTED INCLUDE")

    def test_directory_named_toml_is_ignored(self):
        # Noctalia skips non-regular files, so a directory called x.toml is not an unreadable config.
        self.write_config(GOOD)
        (self.config_dir / "fake.toml").mkdir()
        self.assertEqual(self.problems(), [])

    def test_main_checks_extra_config_dirs_and_skips_missing_ones(self):
        self.write_config(GOOD)
        live = Path(self._tmp.name) / "live"
        live.mkdir()
        (live / "extra.toml").write_text("[theme]\nsync_color_scheme = true\n", encoding="utf-8")
        argv = ["check_noctalia.py", str(self.config_dir), str(self.settings), str(live)]
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = check_noctalia.main(argv)
        self.assertEqual(code, 1)
        self.assertIn("extra.toml", out.getvalue())
        missing = Path(self._tmp.name) / "not-stowed-yet"
        with contextlib.redirect_stdout(io.StringIO()):
            code = check_noctalia.main(["check_noctalia.py", str(self.config_dir), str(self.settings), str(missing)])
        self.assertEqual(code, 0)

    def test_later_toml_file_wins_alphabetically(self):
        self.write_config(GOOD, name="a.toml")
        self.write_config("[theme]\nsync_color_scheme = true\n", name="b.toml")
        self.assert_violation("SYNC_COLOR_SCHEME NOT FALSE")
        self.write_config("[theme]\nsync_color_scheme = true\n", name="a.toml")
        self.write_config(GOOD, name="b.toml")
        self.assertEqual(self.problems(), [])


if __name__ == "__main__":
    unittest.main()
