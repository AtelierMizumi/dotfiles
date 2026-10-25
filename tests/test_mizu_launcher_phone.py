"""LauncherPhone.qml is the corner launcher phone. Its old turn into a landscape Wallpapers phone is gone (the Settings'
Appearance page replaced that screen), so nothing in the file may point at the removed stage, and the entry points the
rest of the shell calls must still be there.
"""

import re
import unittest
from pathlib import Path

SHELL = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu"
SOURCE = (SHELL / "modules/mizu/launcher/LauncherPhone.qml").read_text()

LEFTOVERS = ("wallStage", "FlipMath", "wallpapersOpen", "flipAnim", "flipPrep", "wallpaperphone", "WallpaperService",
             "turnTo(", "openWallpapers", "returnToApps")
ENTRY_POINTS = ("function openOn(", "function openWithText(", "function close()", "function toggleOn(",
                "property bool open", "required property var source", "property var quickPanel")


class LauncherPhoneTest(unittest.TestCase):
    def test_nothing_points_at_the_removed_wallpapers_phone(self):
        found = [word for word in LEFTOVERS if word in SOURCE]
        self.assertEqual(found, [], "dead wallpapers code is still in LauncherPhone.qml")

    def test_the_entry_points_the_shell_calls_remain(self):
        missing = [entry for entry in ENTRY_POINTS if entry not in SOURCE]
        self.assertEqual(missing, [])

    def test_every_identifier_with_a_dot_call_is_declared_in_the_file(self):
        declared = set(re.findall(r"\bid:\s*(\w+)", SOURCE))
        used = set(re.findall(r"\b(win|phone|face|catcher|clock|enterAnim|exitAnim|exitDelay|focusTimer)\.", SOURCE))
        self.assertEqual(used - declared - {"phone"}, set())

    def test_the_shell_still_builds_it_with_the_properties_it_gives(self):
        shell = (SHELL / "shell.qml").read_text()
        block = shell[shell.index("LauncherPhone {"):]
        block = block[:block.index("}")]
        for given in re.findall(r"^\s+(\w+):", block, flags=re.M):
            if given == "id":
                continue
            self.assertRegex(SOURCE, r"property (?:var|real|bool|string|int) " + given + r"\b|required property var " +
                             given + r"\b", f"shell.qml sets {given}, which LauncherPhone does not declare")


if __name__ == "__main__":
    unittest.main()
