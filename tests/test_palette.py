"""Tests for the Mizu palette (spec section 3.1): role values, terminal block and WCAG text contrast."""

import json
import re
import unittest
from pathlib import Path

PALETTE = Path(__file__).resolve().parent.parent / "noctalia/.config/noctalia/palettes/Mizu.json"

EXPECTED_ROLES = {
    "mPrimary": "#E2A63B",
    "mOnPrimary": "#182338",
    "mSecondary": "#7FB4CA",
    "mOnSecondary": "#182338",
    "mTertiary": "#9ECE6A",
    "mOnTertiary": "#182338",
    "mError": "#F7768E",
    "mOnError": "#182338",
    "mSurface": "#182338",
    "mOnSurface": "#EDF0F3",
    "mSurfaceVariant": "#2A3F5F",
    "mOnSurfaceVariant": "#B4BECE",
    "mOutline": "#4A6088",
    "mShadow": "#101826",
    "mHover": "#3A5078",
    "mOnHover": "#EDF0F3",
}

ANSI_NAMES = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
TERMINAL_KEYS = {"background", "foreground", "cursor", "cursorText", "selectionBg", "selectionFg", "normal", "bright"}

# (foreground role, background role): every text-on-surface pair the shell draws.
TEXT_PAIRS = [
    ("mOnSurface", "mSurface"),
    ("mOnSurface", "mSurfaceVariant"),
    ("mOnSurfaceVariant", "mSurface"),
    ("mOnSurfaceVariant", "mSurfaceVariant"),
    ("mPrimary", "mSurface"),
    ("mOnPrimary", "mPrimary"),
    ("mSecondary", "mSurface"),
    ("mOnSecondary", "mSecondary"),
    ("mTertiary", "mSurface"),
    ("mOnTertiary", "mTertiary"),
    ("mError", "mSurface"),
    ("mOnError", "mError"),
    ("mOnHover", "mHover"),
]

HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _linear(channel: int) -> float:
    value = channel / 255
    return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4


def _luminance(color: str) -> float:
    red, green, blue = (int(color[i : i + 2], 16) for i in (1, 3, 5))
    return 0.2126 * _linear(red) + 0.7152 * _linear(green) + 0.0722 * _linear(blue)


def contrast(foreground: str, background: str) -> float:
    lighter, darker = sorted((_luminance(foreground), _luminance(background)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def _all_colors(node):
    if isinstance(node, dict):
        for child in node.values():
            yield from _all_colors(child)
    else:
        yield node


class MizuPaletteTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(PALETTE.read_text(encoding="utf-8"))
        cls.dark = cls.data["dark"]

    def test_dark_has_exactly_the_16_roles_with_spec_values(self):
        roles = {key: value.upper() for key, value in self.dark.items() if key != "terminal"}
        self.assertEqual(roles, EXPECTED_ROLES)

    def test_light_is_omitted(self):
        self.assertEqual(set(self.data), {"dark"})

    def test_all_colors_are_6_digit_hex(self):
        for color in _all_colors(self.dark):
            self.assertRegex(color, HEX_RE, f"not a #RRGGBB color: {color!r}")

    def test_terminal_has_background_foreground_cursor_selection_and_16_ansi(self):
        terminal = self.dark["terminal"]
        self.assertEqual(set(terminal), TERMINAL_KEYS)
        self.assertEqual(set(terminal["normal"]), ANSI_NAMES)
        self.assertEqual(set(terminal["bright"]), ANSI_NAMES)

    def test_terminal_background_and_foreground_match_surface(self):
        terminal = self.dark["terminal"]
        self.assertEqual(terminal["background"].upper(), "#182338")
        self.assertEqual(terminal["foreground"].upper(), "#EDF0F3")

    def test_text_pairs_meet_4_5_contrast(self):
        for foreground, background in TEXT_PAIRS:
            ratio = contrast(self.dark[foreground], self.dark[background])
            self.assertGreaterEqual(ratio, 4.5, f"{foreground} on {background}: {ratio:.2f}:1")


if __name__ == "__main__":
    unittest.main()
