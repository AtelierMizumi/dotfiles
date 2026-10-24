"""docs/USAGE.md must list every key combo that this repo's niri config adds or changes versus the baseline."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "niri/.config/niri/config.kdl"
BASELINE = ROOT / "docs/baseline/niri-config.default.kdl"
GUIDE = ROOT / "docs/USAGE.md"

# niri key names mapped to what the guide shows on a keycap.
KEY_NAMES = {"Mod": "Super", "Minus": "-", "Equal": "=", "Comma": ",", "Period": ".", "Slash": "/", "Escape": "Esc"}


def bind_lines(path: Path) -> dict[str, str]:
    """Return {combo: normalized line} for every active bind in the `binds { ... }` block."""
    binds: dict[str, str] = {}
    inside = False
    skip = 0
    for raw in path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if not inside:
            inside = stripped.startswith("binds") and stripped.endswith("{")
            continue
        if raw.startswith("}"):
            break
        if skip:
            skip += raw.count("{") - raw.count("}")
            continue
        if not stripped or stripped.startswith("//"):
            continue
        if stripped.startswith("/-"):
            skip = max(raw.count("{") - raw.count("}"), 0)
            continue
        combo = stripped.split()[0]
        binds[combo] = " ".join(stripped.split())
    return binds


def show(combo: str) -> str:
    return "+".join(KEY_NAMES.get(part, part) for part in combo.split("+"))


def expand(text: str) -> set[str]:
    """All combos a guide mentions, expanding `Super+Shift+H/J/K/L` and `Super+1..9` shorthands."""
    found = set(re.findall(r"[A-Za-z]+(?:\+[A-Za-z0-9=/-]+)+", text))
    for prefix, keys in re.findall(r"((?:[A-Za-z]+\+)+)([A-Za-z0-9](?:/[A-Za-z0-9])+)", text):
        found.update(prefix + key for key in keys.split("/"))
    for prefix, low, high in re.findall(r"((?:[A-Za-z]+\+)+)([0-9])\.\.([0-9])", text):
        found.update(f"{prefix}{n}" for n in range(int(low), int(high) + 1))
    return found


class UsageGuideTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.guide = GUIDE.read_text(encoding="utf-8")
        config, baseline = bind_lines(CONFIG), bind_lines(BASELINE)
        cls.custom = sorted(combo for combo, line in config.items() if baseline.get(combo) != line)

    def test_there_are_custom_binds_to_document(self):
        self.assertGreater(len(self.custom), 30, "the keymap should add or change many binds")

    def test_guide_lists_every_custom_bind(self):
        mentioned = expand(self.guide)
        # Hardware keys such as XF86AudioMute are single names, so they only need to appear in the text.
        missing = [
            combo
            for combo in self.custom
            if (show(combo) not in mentioned if "+" in combo else combo not in self.guide)
        ]
        self.assertEqual(missing, [], f"USAGE.md does not mention: {missing}")

    def test_guide_covers_the_essentials(self):
        for needle in ("Sofle", "laptop", "Super+Shift+/", "docs/baseline", "stow -D", "niri validate"):
            self.assertIn(needle, self.guide, f"USAGE.md should mention {needle!r}")


if __name__ == "__main__":
    unittest.main()
