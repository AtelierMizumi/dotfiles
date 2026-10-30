"""Tests for mizu-l2d integration into the dotfiles rice.

Verifies:
1. niri/.config/niri/scripts/mizu-l2d is executable and handles help and invalid commands cleanly.
2. Quickshell IPC contract (MizuIpc.qml defines liveWallpaper handler).
3. WallpaperService contract (liveScreens property and covered() helper).
4. WallpaperLayer contract (hides static wallpaper when live wallpaper covers the screen).
5. Desktop widgets layer elevation contract (moves all 7 desktop widgets from Background to Bottom).
"""

import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "niri/.config/niri/scripts/mizu-l2d"
MIZU_DIR = ROOT / "quickshell/.config/quickshell/mizu"

DESKTOP_WIDGETS = [
    "CalendarCardWidget.qml",
    "ClockWidget.qml",
    "LyricsWidget.qml",
    "StickyNotesWidget.qml",
    "TodoWidget.qml",
    "UserCardWidget.qml",
    "WeatherCardWidget.qml",
]


class MizuL2DIntegrationTest(unittest.TestCase):
    def test_script_exists_and_is_executable(self):
        self.assertTrue(SCRIPT.is_file(), f"missing script: {SCRIPT}")
        self.assertTrue(os.access(SCRIPT, os.X_OK), f"script not executable: {SCRIPT}")

    def test_script_help_exits_0(self):
        res = subprocess.run([str(SCRIPT), "--help"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Usage:", res.stdout)
        self.assertIn("start", res.stdout)
        self.assertIn("stop", res.stdout)
        self.assertIn("toggle", res.stdout)
        self.assertIn("status", res.stdout)
        self.assertIn("ctl", res.stdout)

    def test_script_unknown_command_exits_1(self):
        res = subprocess.run([str(SCRIPT), "invalid-command-xyz"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 1)
        self.assertIn("Unknown command", res.stderr)

    def test_mizu_ipc_defines_live_wallpaper_handler(self):
        ipc_file = MIZU_DIR / "services/MizuIpc.qml"
        self.assertTrue(ipc_file.is_file())
        content = ipc_file.read_text(encoding="utf-8")
        self.assertIn("function liveWallpaper(screens: string)", content)
        self.assertIn("WallpaperService.liveScreens", content)

    def test_wallpaper_service_defines_live_screens_and_covered(self):
        service_file = MIZU_DIR / "services/WallpaperService.qml"
        self.assertTrue(service_file.is_file())
        content = service_file.read_text(encoding="utf-8")
        self.assertIn("property var liveScreens", content)
        self.assertIn("function covered(screenName)", content)

    def test_wallpaper_layer_hides_when_covered(self):
        layer_file = MIZU_DIR / "modules/mizu/background/WallpaperLayer.qml"
        self.assertTrue(layer_file.is_file())
        content = layer_file.read_text(encoding="utf-8")
        self.assertIn("!WallpaperService.covered(", content)

    def test_all_desktop_widgets_elevate_layer_when_covered(self):
        widgets_dir = MIZU_DIR / "modules/mizu/desktopWidgets"
        for name in DESKTOP_WIDGETS:
            path = widgets_dir / name
            self.assertTrue(path.is_file(), f"missing widget file: {path}")
            content = path.read_text(encoding="utf-8")
            self.assertIn(
                "WallpaperService.covered(",
                content,
                f"{name} does not check WallpaperService.covered() for layer elevation",
            )
            self.assertIn(
                "WlrLayer.Bottom",
                content,
                f"{name} does not reference WlrLayer.Bottom for elevation above live wallpaper",
            )


    def test_settings_service_defines_live_defaults(self):
        settings_file = MIZU_DIR / "services/SettingsService.qml"
        self.assertTrue(settings_file.is_file())
        content = settings_file.read_text(encoding="utf-8")
        self.assertIn('"wallpaper.live": false', content)
        self.assertIn('"wallpaper.liveModel": "gaoxiong_7"', content)
        self.assertIn('"wallpaper.liveOutputs": ""', content)

    def test_l2d_service_exists_and_declares_lifecycle(self):
        service_file = MIZU_DIR / "services/L2dService.qml"
        self.assertTrue(service_file.is_file())
        content = service_file.read_text(encoding="utf-8")
        self.assertIn("pragma Singleton", content)
        self.assertIn('property string state: "off"', content)
        self.assertIn("function setEnabled(", content)
        self.assertIn("function toggle()", content)
        self.assertIn("function setModel(", content)
        self.assertIn("function setOutputs(", content)

    def test_mizu_ipc_defines_l2d_ctl_handlers(self):
        ipc_file = MIZU_DIR / "services/MizuIpc.qml"
        content = ipc_file.read_text(encoding="utf-8")
        self.assertIn("function l2dEnable(on: bool)", content)
        self.assertIn("function l2dToggle()", content)
        self.assertIn("function l2dModel(prefab: string)", content)

    def test_settings_page_desktop_has_live2d_card(self):
        page_file = MIZU_DIR / "modules/mizu/settings/SettingsPageDesktop.qml"
        self.assertTrue(page_file.is_file())
        content = page_file.read_text(encoding="utf-8")
        self.assertIn('title: "Live2D"', content)
        self.assertIn("L2dService.toggle()", content)
        self.assertIn("L2dService.setOutputs(", content)
        self.assertIn("L2dService.setModel(", content)

    def test_systemd_unit_valid(self):
        unit_file = ROOT / "systemd/.config/systemd/user/mizu-l2d-wall.service"
        self.assertTrue(unit_file.is_file())
        content = unit_file.read_text(encoding="utf-8")
        self.assertIn("mizu-l2d-wall.py", content)
        self.assertIn("libgtk4-layer-shell.so", content)


if __name__ == "__main__":
    unittest.main()
