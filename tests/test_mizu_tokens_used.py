"""Every `Tokens.<name>` the shell reads must be a property of the Tokens singleton (modules/common/Tokens.qml).

QML does not fail on a misspelt singleton property: the binding silently becomes undefined and Quickshell logs
"Unable to assign [undefined] to QColor" at run time, with the colour left transparent. The old SekaiPop names
(accentCyan, colBorder, ...) live on ThemeSet, not on Tokens, which is how three files went wrong.
"""

import re
import unittest
from pathlib import Path

SHELL = Path(__file__).resolve().parent.parent / "quickshell/.config/quickshell/mizu"
TOKENS = SHELL / "modules/common/Tokens.qml"
USE = re.compile(r"\bTokens\.([A-Za-z_][A-Za-z0-9_]*)")
DEFINED = re.compile(r"(?:property\s+[\w<>.]+\s+|function\s+|signal\s+)([A-Za-z_][A-Za-z0-9_]*)")
# `Tokens.qml` in an import line or a path is not a property read.
NOT_PROPERTIES = {"qml"}


class TokensUsedTest(unittest.TestCase):
    def test_every_tokens_property_that_is_read_exists(self):
        defined = set(DEFINED.findall(TOKENS.read_text()))
        self.assertIn("accent", defined, "the parser found no properties in Tokens.qml")
        missing = {}
        for path in sorted(SHELL.rglob("*")):
            if path.suffix not in (".qml", ".js") or path == TOKENS:
                continue
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if line.lstrip().startswith("//"):
                    continue
                for name in USE.findall(line):
                    if name not in defined and name not in NOT_PROPERTIES:
                        missing.setdefault(name, []).append(f"{path.relative_to(SHELL)}:{number}")
        report = "\n".join(f"  Tokens.{name}: {', '.join(places[:3])}" for name, places in sorted(missing.items()))
        self.assertEqual(missing, {}, "Tokens has no such property:\n" + report)

class TextOverPicturesTest(unittest.TestCase):
    """Text drawn straight over the wallpaper picture must use the fixed light `onPicture` ink.

    `textWhite` is the ink for accent fills (Tokens.onAccent), which is dark in many palettes: on the launcher's
    wallpaper screen it turned the app names black on a dark picture.
    """

    OVER_PICTURE = re.compile(r"lcdOn|wallOn|bannerDark|lcdLayer\.dark")

    def test_ink_over_a_picture_is_not_the_accent_ink(self):
        offenders = []
        for rel in ("modules/mizu/launcher/LauncherFace.qml", "modules/mizu/quickPanel/QuickPanelFace.qml"):
            for number, line in enumerate((SHELL / rel).read_text().splitlines(), 1):
                if "textWhite" in line and self.OVER_PICTURE.search(line):
                    offenders.append(f"{rel}:{number}: {line.strip()}")
        self.assertEqual(offenders, [], "over-picture text must use mt.onPicture")

    def test_on_picture_is_a_light_ink_in_the_theme(self):
        theme = (SHELL / "modules/common/ThemeSet.qml").read_text()
        self.assertRegex(theme, r"readonly property color onPicture: Qt\.rgba\(1, 1, 1, 1\)")

class TokensPropertyNamesTest(unittest.TestCase):
    """A property of the Tokens singleton named `on` + capital (onAccent, onChip) reads back as #000000 at run time,
    whatever the palette says: QML reserves that spelling for signal handlers. Found by measuring the pills on screen:
    every chip showed black text on a dark fill, although tokens.json had a light `onChip`. The JSON keys keep their
    names; only the QML properties must not start with `on`.
    """

    def test_no_color_property_is_named_like_a_signal_handler(self):
        names = re.findall(r"property\s+color\s+(on[A-Z]\w*)", TOKENS.read_text())
        self.assertEqual(names, [], "rename these Tokens properties (e.g. onChip -> chipInk)")

    def test_the_renamed_properties_exist(self):
        defined = set(DEFINED.findall(TOKENS.read_text()))
        for name in ("accentInk", "chipInk"):
            self.assertIn(name, defined)


if __name__ == "__main__":
    unittest.main()
