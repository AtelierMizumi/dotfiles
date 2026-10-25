"""Text on the widgets' and bar's coloured pills must stay legible.

 - days outside the month are dimmed on purpose: the ink at `opacity` over the widget backdrop must keep 4.5:1
 - the bar's accent pills (media, active window, workspace badges, notification bell) draw their text in `accentInk`
   (the palette's onAccent, which the palette tool guarantees at 4.5:1 against the accent). `colBorder` is the outline
   colour: dark in both modes, so on a light-mode accent pill it was 2.8:1.
 - sub-lines under a title are tiny (7 px): they may be dimmed by at most 15% and must keep 4.5:1 after it
"""

import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / "quickshell/.config/quickshell/mizu"
sys.path.insert(0, str(SHELL / "palette"))

from palette_core import build, color  # noqa: E402
from test_mizu_palette_build import FakeGenerator, solid  # noqa: E402

ACCENT_PILL_FILES = ("modules/mizu/bar/MediaPill.qml", "modules/mizu/bar/Status_Bar.qml",
                     "modules/mizu/bar/ActiveWindowKey.qml", "modules/mizu/bar/WorkspaceBadges.qml",
                     "modules/mizu/bar/NotificationBadge.qml")


def tokens_for(mode):
    return build.build(solid((0.2, 0.4, 0.8)), FakeGenerator(), {}, mode)


def over(foreground, alpha, background):
    """`foreground` at `alpha` drawn over `background` (sRGB 0..1 triples)."""
    return tuple(alpha * f + (1 - alpha) * b for f, b in zip(foreground, background))


def constants(path, pattern):
    found = re.findall(pattern, (SHELL / path).read_text())
    assert found, f"{path}: no match for {pattern}"
    return [float(x) for x in found]


class DimmedTextTest(unittest.TestCase):
    def test_days_outside_the_month_stay_readable(self):
        opacities = constants("modules/mizu/desktopWidgets/CalendarCardWidget.qml",
                              r"String\(m?cell\.c\.d\)\s*\n\s*opacity: m?cell\.c\.inMonth \? 1 : ([0-9.]+)")
        self.assertEqual(len(opacities), 2, "expected the day numbers of both calendar views")
        for mode in ("dark", "light"):
            tokens = tokens_for(mode)
            ink = color.hex_to_rgb(tokens["color"]["ink"])
            backdrop = color.hex_to_rgb(tokens["surface"]["widget"]["backdrop"])
            for opacity in opacities:
                ratio = color.contrast(over(ink, opacity, backdrop), backdrop)
                self.assertGreaterEqual(ratio, 4.5, f"{mode}: out-of-month days at opacity {opacity} are {ratio:.2f}:1")

    def test_sub_lines_are_dimmed_a_little_and_stay_readable(self):
        alphas = (constants("modules/mizu/bar/MediaPill.qml",
                            r"color: Qt\.rgba\(root\.ink\.r, root\.ink\.g, root\.ink\.b, ([0-9.]+)\)")
                  + constants("modules/mizu/bar/Status_Bar.qml",
                              r"color: Qt\.rgba\(mt\.accentInk\.r, mt\.accentInk\.g, mt\.accentInk\.b, ([0-9.]+)\)"))
        for alpha in alphas:
            self.assertGreaterEqual(alpha, 0.85, f"a 7 px sub-line at alpha {alpha} is too faint")
        for mode in ("dark", "light"):
            tokens = tokens_for(mode)
            ink = color.hex_to_rgb(tokens["color"]["onAccent"])
            for fill_key in ("accent", "accent2"):
                fill = color.hex_to_rgb(tokens["color"][fill_key])
                for alpha in alphas:
                    ratio = color.contrast(over(ink, alpha, fill), fill)
                    self.assertGreaterEqual(ratio, 4.5, f"{mode}: sub-line at alpha {alpha} on {fill_key} is {ratio:.2f}:1")


class AccentPillInkTest(unittest.TestCase):
    def test_text_on_accent_pills_is_not_the_outline_colour(self):
        offenders = [rel for rel in ACCENT_PILL_FILES if "colBorder" in (SHELL / rel).read_text()]
        self.assertEqual(offenders, [], "these files still draw text with mt.colBorder; use mt.accentInk")

    def test_the_calendar_today_cell_uses_the_accent_ink(self):
        source = (SHELL / "modules/mizu/desktopWidgets/CalendarCardWidget.qml").read_text()
        self.assertNotIn("isToday ? mt.colBorder", source, "today's number sits on the accent gradient")

    def test_the_theme_exposes_accent_ink_from_the_tokens(self):
        theme = (SHELL / "modules/common/ThemeSet.qml").read_text()
        self.assertIn("readonly property color accentInk: Tokens.accentInk", theme)

def text_blocks_with_outline_ink(source):
    """Lines like `color: ... mt.colBorder ...` that belong to a Text or MaterialIcon block, as (line number, text).

    A line that already chooses by mode (`mt.dark`) is left alone: its author handled both modes.
    """
    lines = source.splitlines()
    found = []
    for number, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith(("color:", "ink:")) or "mt.colBorder" not in stripped or "mt.dark" in stripped:
            continue
        indent = len(line) - len(line.lstrip())
        for back in range(number - 1, -1, -1):
            opener = lines[back]
            if opener.strip().endswith("{") and len(opener) - len(opener.lstrip()) < indent:
                kind = opener.strip().split()[0]
                if kind in ("Text", "MaterialIcon"):
                    found.append((number + 1, stripped))
                break
    return found


class WidgetTextInkTest(unittest.TestCase):
    """Text in the desktop widgets sits on the accent fills (digit cards, day badges, AM / PM, chips): it uses accentInk,
    the ink the palette keeps at 4.5:1 against the accent in both modes, not the outline colour (dark in both)."""

    def test_widget_text_on_accent_fills_uses_accent_ink(self):
        offenders = []
        for path in sorted((SHELL / "modules/mizu/desktopWidgets").glob("*.qml")):
            for number, line in text_blocks_with_outline_ink(path.read_text()):
                offenders.append(f"{path.name}:{number}: {line}")
        self.assertEqual(offenders, [], "text drawn with mt.colBorder; use mt.accentInk")


if __name__ == "__main__":
    unittest.main()
