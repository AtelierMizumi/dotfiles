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
        # The key must start its own line: a \n inside the line's comment once
        # left it commented out while this substring check still matched.
        self.assertRegex(content, r'(?m)^\s*"wallpaper\.placementLocked": true\b')

    def test_settings_service_defines_theme_and_layout(self):
        settings_file = MIZU_DIR / "services/SettingsService.qml"
        content = settings_file.read_text(encoding="utf-8")
        self.assertRegex(content, r'(?m)^\s*"wallpaper\.liveTheme": true\b')
        self.assertRegex(content, r'(?m)^\s*"wallpaper\.liveLayout": "independent"')

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
        self.assertIn("function l2dLock(locked: bool)", content)
        self.assertIn("function l2dToggleLock()", content)

    def test_settings_page_desktop_has_live2d_card(self):
        page_file = MIZU_DIR / "modules/mizu/settings/SettingsPageDesktop.qml"
        self.assertTrue(page_file.is_file())
        content = page_file.read_text(encoding="utf-8")
        self.assertIn('title: "Live2D"', content)
        self.assertIn("L2dService.toggle()", content)
        self.assertIn("L2dService.setOutputs(", content)
        self.assertIn("L2dService.setModel(", content)
        self.assertIn("L2dService.previewFor(", content)
        self.assertIn("L2dService.resetCamera()", content)
        self.assertIn("L2dService.zoomCamera(", content)
        self.assertIn("L2dService.toggleTips()", content)
        self.assertIn("L2dService.togglePlacementLocked()", content)

    def test_l2d_service_defines_tips_and_camera(self):
        service_file = MIZU_DIR / "services/L2dService.qml"
        content = service_file.read_text(encoding="utf-8")
        self.assertIn("function previewFor(prefab)", content)
        self.assertIn("function setTips(enabled)", content)
        self.assertIn("function resetCamera()", content)
        self.assertIn("function zoomCamera(factor)", content)
        self.assertIn("function setPlacementLocked(", content)
        self.assertIn("function togglePlacementLocked()", content)

    def test_systemd_unit_valid(self):
        unit_file = ROOT / "systemd/.config/systemd/user/mizu-l2d-wall.service"
        self.assertTrue(unit_file.is_file())

    def test_l2d_service_defines_gaze_and_lang(self):
        service_file = MIZU_DIR / "services/L2dService.qml"
        content = service_file.read_text(encoding="utf-8")
        self.assertIn("function setGaze(enabled)", content)
        self.assertIn("function toggleGaze()", content)
        self.assertIn("function setLanguage(lang)", content)

    def test_settings_service_defines_language_and_gaze(self):
        settings_file = MIZU_DIR / "services/SettingsService.qml"
        content = settings_file.read_text(encoding="utf-8")
        self.assertIn('"system.language": "vi"', content)
        self.assertIn('"wallpaper.gazeFollow": true', content)

    def test_ctl_script_accepts_gaze_and_lang(self):
        ctl_file = Path("/home/thuanc177/Projects/Tools/mizu-l2d/wall/mizu-l2d-ctl.py")
        content = ctl_file.read_text(encoding="utf-8")
        self.assertIn('"gaze"', content)
        self.assertIn('"lang"', content)
        wall_file = Path("/home/thuanc177/Projects/Tools/mizu-l2d/wall/mizu-l2d-wall.py")
        wall_content = wall_file.read_text(encoding="utf-8")
        self.assertIn("set_media_playback_requires_user_gesture(False)", wall_content)

    def test_l2d_service_defines_layout_and_palette(self):
        service_file = MIZU_DIR / "services/L2dService.qml"
        content = service_file.read_text(encoding="utf-8")
        self.assertIn('property string currentLayout', content)
        self.assertIn("function setLayout(mode)", content)
        self.assertIn("function applyPalette(force)", content)
        self.assertIn("function setLiveTheme(enabled)", content)
        self.assertIn("function toggleLiveTheme()", content)
        self.assertIn("property bool liveTheme", content)
        self.assertIn("l2d_palette.py", content)
        self.assertIn("WallpaperService.runPalette()", content)
        self.assertIn("mirror ? \"true\" : \"false\"", content)

    def test_mizu_ipc_defines_layout_and_palette(self):
        ipc_file = MIZU_DIR / "services/MizuIpc.qml"
        content = ipc_file.read_text(encoding="utf-8")
        self.assertIn("function l2dLayout(mode: string)", content)
        self.assertIn("function l2dPalette()", content)

    def test_quick_panel_has_l2d_tile(self):
        tiles_file = MIZU_DIR / "modules/common/functions/QuickTiles.js"
        content = tiles_file.read_text(encoding="utf-8")
        self.assertIn('"l2d"', content)
        face_file = MIZU_DIR / "modules/mizu/quickPanel/QuickPanelFace.qml"
        content = face_file.read_text(encoding="utf-8")
        self.assertIn('case "l2d"', content)
        self.assertIn("property bool l2dOn", content)
        self.assertIn("signal l2dToggled()", content)
        panel_file = MIZU_DIR / "modules/mizu/quickPanel/QuickPanel.qml"
        content = panel_file.read_text(encoding="utf-8")
        self.assertIn("onL2dToggled: root.source.toggleL2d()", content)
        source_file = MIZU_DIR / "services/QuickSource.qml"
        content = source_file.read_text(encoding="utf-8")
        self.assertIn("function toggleL2d()", content)
        self.assertIn("L2dService.toggle()", content)

    def test_settings_page_desktop_defines_layout_and_theme(self):
        page_file = MIZU_DIR / "modules/mizu/settings/SettingsPageDesktop.qml"
        content = page_file.read_text(encoding="utf-8")
        self.assertIn("L2dService.setLayout(", content)
        self.assertIn("L2dService.toggleLiveTheme()", content)
        self.assertIn("L2dService.applyPalette(true)", content)

    def test_fetch_model_is_manifest_driven(self):
        scripts = Path("/home/thuanc177/Projects/Tools/mizu-l2d/scripts")
        sh = (scripts / "fetch-model.sh").read_text(encoding="utf-8")
        self.assertIn("exec python3 -I -B", sh)
        self.assertIn("fetch-model.py", sh)
        py = (scripts / "fetch-model.py").read_text(encoding="utf-8")
        self.assertIn("MANIFEST_NAME = \".mizu-manifest.json\"", py)
        self.assertIn("def install_atomic(", py)
        self.assertIn("def safe_rel(", py)
        self.assertIn("sha256", py)
        self.assertIn("l2d_ledger.set_bytes(", py)

    def test_cache_tool_guards_eviction(self):
        cache = Path("/home/thuanc177/Projects/Tools/mizu-l2d/scripts/mizu-l2d-cache.py")
        content = cache.read_text(encoding="utf-8")
        self.assertIn("def guard_evictable(", content)
        self.assertIn("is the active model", content)
        self.assertIn("is pinned", content)
        self.assertIn("def do_enforce(", content)
        self.assertIn("--dry-run", content)

    def test_wall_host_touches_ledger(self):
        wall = Path("/home/thuanc177/Projects/Tools/mizu-l2d/wall/mizu-l2d-wall.py")
        content = wall.read_text(encoding="utf-8")
        self.assertIn("def touch_last_used(", content)
        self.assertIn("touch_last_used(prefab)", content)
        self.assertIn(".ledger.json", content)

    def test_l2d_service_cache_wiring(self):
        content = (MIZU_DIR / "services/L2dService.qml").read_text(encoding="utf-8")
        self.assertIn("mizu-l2d-cache.py", content)
        self.assertIn("root.ledgerPath", content)
        self.assertIn("function cacheEvict(prefab)", content)
        self.assertIn("function cacheClean()", content)
        self.assertIn("function cacheStatusText()", content)

    def test_ipc_and_settings_expose_cache(self):
        ipc = (MIZU_DIR / "services/MizuIpc.qml").read_text(encoding="utf-8")
        self.assertIn("function l2dCacheStatus(): string", ipc)
        self.assertIn("function l2dCacheEvict(prefab: string): void", ipc)
        self.assertIn("function l2dCacheClean(): void", ipc)
        page = MIZU_DIR / "modules/mizu/settings/SettingsPageDesktop.qml"
        content = page.read_text(encoding="utf-8")
        self.assertIn("Model storage", content)
        self.assertIn("L2dService.cacheClean()", content)
        self.assertIn("L2dService.cacheStatusText()", content)

    def test_palette_tooling_exists(self):
        palette_dir = MIZU_DIR / "palette"
        l2d_file = palette_dir / "l2d_palette.py"
        self.assertTrue(l2d_file.is_file())
        content = l2d_file.read_text(encoding="utf-8")
        self.assertIn("def accent_from_pixels(", content)
        self.assertIn("def find_bg(", content)
        self.assertIn("def texture_paths(", content)
        self.assertIn("def make_swatch(", content)
        mizu_file = palette_dir / "mizu_palette.py"
        content = mizu_file.read_text(encoding="utf-8")
        self.assertIn('--accent', content)

    def test_wall_host_handles_mirror(self):
        wall_file = Path("/home/thuanc177/Projects/Tools/mizu-l2d/wall/mizu-l2d-wall.py")
        content = wall_file.read_text(encoding="utf-8")
        self.assertIn("mirror", content)
        self.assertIn("def make_surface(self, monitor, source=None)", content)
        self.assertIn("Gtk.WidgetPaintable", content)
        self.assertIn("isinstance(view, WebKit.WebView)", content)
        example = Path("/home/thuanc177/Projects/Tools/mizu-l2d/docs/config.example.toml")
        self.assertIn("mirror", example.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
