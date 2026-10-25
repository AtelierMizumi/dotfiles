"""Every file of the mizu shell is referred to by something (scripts/dev/orphans.py): an upstream file nothing uses any
more is dead weight in the stow package and noise for the next reader."""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIZU = ROOT / "quickshell/.config/quickshell/mizu"


class OrphanFilesTest(unittest.TestCase):
    def test_no_file_of_the_shell_is_unreferenced(self):
        result = subprocess.run([sys.executable, "-I", "-B", str(ROOT / "scripts/dev/orphans.py"), str(MIZU)],
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.split(), [], "unreferenced files (delete them, or use them)")


if __name__ == "__main__":
    unittest.main()
