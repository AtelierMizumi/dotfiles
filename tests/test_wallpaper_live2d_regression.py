#!/usr/bin/env python3
"""Regression test suite for wallpaper toggling, static wallpaper browsing,
Live2D card rendering and pagination in the Mizu shell settings."""

from pathlib import Path
import math
import unittest

ROOT = Path(__file__).resolve().parent.parent
MIZU_DIR = ROOT / "quickshell/.config/quickshell/mizu"


class WallpaperLayerRegressionTest(unittest.TestCase):
    """Verifies WallpaperLayer.qml does not introduce binding loops and properly reloads."""

    def setUp(self):
        self.layer_file = MIZU_DIR / "modules/mizu/background/WallpaperLayer.qml"
        self.assertTrue(self.layer_file.is_file(), f"missing {self.layer_file}")
        self.content = self.layer_file.read_text(encoding="utf-8")

    def test_no_win_screen_in_visible_binding(self):
        """Binding on visible must not read win.screen directly (causes Wayland unmap cyclic binding loop)."""
        lines = [line.strip() for line in self.content.splitlines() if line.strip().startswith("visible:")]
        self.assertTrue(len(lines) > 0, "No visible binding found in WallpaperLayer.qml")
        for line in lines:
            self.assertNotIn(
                "win.screen ?",
                line,
                "WallpaperLayer.qml uses win.screen in visible binding, which triggers binding loops on unmap",
            )

    def test_uses_stable_target_screen_or_screen_name(self):
        """Must read targetScreen or screenName anchored to win.modelData."""
        self.assertIn("readonly property var targetScreen: win.modelData", self.content)
        self.assertIn("readonly property string screenName:", self.content)

    def test_reloads_on_visible_changed(self):
        """When visibility toggles back to true, win.load() must be triggered."""
        self.assertIn("onVisibleChanged: if (visible) win.load()", self.content)

    def test_checks_wallpaper_service_covered(self):
        """Layer must yield when wallpaper is covered by live wallpaper."""
        self.assertIn("!WallpaperService.covered(", self.content)


class WallpaperServiceRegressionTest(unittest.TestCase):
    """Verifies WallpaperService.qml covered logic and thumbnail management."""

    def setUp(self):
        self.service_file = MIZU_DIR / "services/WallpaperService.qml"
        self.assertTrue(self.service_file.is_file(), f"missing {self.service_file}")
        self.content = self.service_file.read_text(encoding="utf-8")

    def test_covered_requires_l2d_service_running(self):
        """covered() must verify L2dService.running is true so stopped Live2D never blocks static wallpaper."""
        self.assertIn("L2dService.running &&", self.content)

    def test_defines_shared_thumbs(self):
        """WallpaperService must provide a shared thumbs map for picker components."""
        self.assertIn("property var thumbs:", self.content)
        self.assertIn("function loadThumbs()", self.content)
        self.assertIn("function sweepThumbs()", self.content)


class L2dServiceSafetyTest(unittest.TestCase):
    """Verifies L2dService.qml resets liveScreens on stop and error states."""

    def setUp(self):
        self.l2d_file = MIZU_DIR / "services/L2dService.qml"
        self.assertTrue(self.l2d_file.is_file(), f"missing {self.l2d_file}")
        self.content = self.l2d_file.read_text(encoding="utf-8")

    def test_stop_cleans_live_screens(self):
        """Stopping L2dService must immediately clear WallpaperService.liveScreens."""
        self.assertIn("WallpaperService.liveScreens = []", self.content)


class SettingsPageDesktopRegressionTest(unittest.TestCase):
    """Verifies SettingsPageDesktop has wallpaper browser, search, and refined Live2D pagination."""

    def setUp(self):
        self.desktop_file = MIZU_DIR / "modules/mizu/settings/SettingsPageDesktop.qml"
        self.assertTrue(self.desktop_file.is_file(), f"missing {self.desktop_file}")
        self.content = self.desktop_file.read_text(encoding="utf-8")

    def test_wallpaper_section_has_search(self):
        """Wallpaper section must include search input."""
        self.assertIn('label: "Search wallpaper"', self.content)
        self.assertIn('placeholder: "e.g. anime, mountain, cyberpunk..."', self.content)

    def test_wallpaper_section_has_folder_chips(self):
        """Wallpaper section must include folder chips for filtering."""
        self.assertIn("wallpaperCard.folderChoices", self.content)
        self.assertIn("WallpaperService.setFolder(", self.content)

    def test_wallpaper_section_has_grid_and_pagination(self):
        """Wallpaper section must include 3x4 grid view and pager."""
        self.assertIn("id: wpGrid", self.content)
        self.assertIn("readonly property int columns: 4", self.content)
        self.assertIn("readonly property int rows: 3", self.content)
        self.assertIn("id: wpPager", self.content)
        self.assertIn("WallpaperService.setWallpaper(", self.content)

    def test_live2d_section_has_12_per_page_pagination(self):
        """Live2D browser must use 12 per page pagination instead of sequential load more."""
        self.assertIn("readonly property int perPage: 12", self.content)
        self.assertIn("id: l2dPager", self.content)
        self.assertNotIn("label: \"Load more (\"", self.content)

    def test_live2d_card_has_clip_and_no_invalid_column_anchors(self):
        """Live2D itemCard must clip: true and inner infoCol must not use anchors.left/right."""
        self.assertIn("clip: true", self.content)
        self.assertIn("id: infoCol", self.content)
        # Verify infoCol has width: parent.width and not anchors.left inside Column
        info_col_idx = self.content.find("id: infoCol")
        self.assertTrue(info_col_idx > 0)
        col_snippet = self.content[info_col_idx:info_col_idx + 250]
        self.assertNotIn("anchors.left: parent.left", col_snippet)
        self.assertNotIn("anchors.right: parent.right", col_snippet)


class PaginationAndFilterLogicTest(unittest.TestCase):
    """Pure algorithmic unit tests verifying pagination math and search filtering."""

    def calculate_page_count(self, total_items, per_page):
        return max(1, math.ceil(total_items / per_page))

    def test_page_count_calculations(self):
        self.assertEqual(self.calculate_page_count(0, 12), 1)
        self.assertEqual(self.calculate_page_count(1, 12), 1)
        self.assertEqual(self.calculate_page_count(12, 12), 1)
        self.assertEqual(self.calculate_page_count(13, 12), 2)
        self.assertEqual(self.calculate_page_count(24, 12), 2)
        self.assertEqual(self.calculate_page_count(25, 12), 3)

    def test_filter_matching(self):
        wallpapers = [
            "/home/user/Pictures/Wallpapers/anime/miku.png",
            "/home/user/Pictures/Wallpapers/landscape/mountain_sunset.jpg",
            "/home/user/Pictures/Wallpapers/cyberpunk/neon_city.webp",
        ]
        query = "mOuNtAin"
        filtered = [f for f in wallpapers if query.lower() in f.split("/")[-1].lower()]
        self.assertEqual(filtered, ["/home/user/Pictures/Wallpapers/landscape/mountain_sunset.jpg"])

        query_empty = "   "
        q_norm = query_empty.strip().lower()
        filtered_all = wallpapers if not q_norm else [f for f in wallpapers if q_norm in f.split("/")[-1].lower()]
        self.assertEqual(filtered_all, wallpapers)


if __name__ == "__main__":
    unittest.main()
