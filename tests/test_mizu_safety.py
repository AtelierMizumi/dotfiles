"""Static safety scan of the forked shell (quickshell/.config/quickshell/mizu): nothing that writes Plasma's files, nothing
Hyprland-only, no Sekai paths, only allowlisted programs, and the removed modules stay removed.

Spec: docs/superpowers/specs/2026-10-25-mizu-shell-design.md section 9.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIZU = ROOT / "quickshell/.config/quickshell/mizu"

TEXT_SUFFIXES = {".qml", ".js", ".sh", ".py", ".conf", ".json", ".kdl", ".frag", ".vert", ".toml", ".txt", ".pam"}
SCAN_SKIP_DIRS = {"palette"}  # our own python tool: it has its own tests, and no QML to scan

# Anything that could write Plasma's files, the user's shell setup or system paths.
FORBIDDEN_WRITES = [
    r"kdeglobals", r"gtk-3\.0", r"gtk-4\.0", r"qt5ct", r"qt6ct", r"gsettings", r"dconf", r"kwriteconfig",
    r"color-schemes", r"kcminputrc", r"\.icons\b", r"pkexec", r"\bsudo\b", r"/etc/", r"\.bashrc", r"\.zshrc",
    r"fish/conf\.d",
]
HYPRLAND_ONLY = [r"hyprctl", r"Quickshell\.Hyprland", r"HyprlandFocusGrab", r"GlobalShortcut", r"\bHyprland\.",
                 r"HYPRLAND_INSTANCE", r"hyprsunset", r"hyprpicker"]

# Programs a `Process { command: [...] }` or `execDetached([...])` may start. `sh` and `bash` run snippets that the
# forbidden-word scan above reads too. Extend this list only with a reason.
ALLOWED_PROGRAMS = {
    "sh", "bash", "env", "notify-send", "qs", "niri", "xdg-open", "wpctl", "pactl", "curl", "bluetoothctl", "nmcli",
    "mkdir", "uname", "cat", "ddcutil", "brightnessctl", "wlsunset", "cliphist", "wl-copy", "wl-paste",
    "systemd-inhibit", "systemctl", "loginctl", "python3", "pkill", "setsid", "nice", "magick", "busctl",
    # setpriv only sets PR_SET_PDEATHSIG, so a helper (the Keep Awake inhibitor) dies with the shell; no new rights.
    "setpriv",
}

# Modules, services and scripts of the upstream tree that milestone 1 does not carry (spec section 5).
REMOVED = [
    "modules/mizu/dock", "modules/mizu/overview", "modules/mizu/cheatSheet", "modules/mizu/keybinds",
    "modules/mizu/regionSelector", "modules/mizu/keyboard", "modules/mizu/palette", "modules/mizu/editMode",
    "modules/mizu/welcome", "modules/mizu/equalizer", "modules/mizu/visualizer", "modules/mizu/framing",
    "modules/mizu/desktopMenu", "modules/mizu/wallpaperSelector",
    "services/ThemeService.qml", "services/AppThemeService.qml", "services/IconCursorService.qml",
    "services/UpdateService.qml", "services/PackageUpdatesService.qml", "services/HookService.qml",
    "services/PluginService.qml", "services/PluginState.qml", "services/HyprlandData.qml",
    "services/HyprlandSettings.qml", "services/DisplayService.qml", "services/ScrollOverviewService.qml",
    "services/DiscordVoiceService.qml", "services/WallhavenService.qml", "services/KeybindService.qml",
    "services/RegionService.qml", "services/EqualizerService.qml", "services/PcCavaService.qml",
    "services/VisualizerService.qml", "services/WelcomeService.qml", "services/PaletteService.qml",
    "services/DesktopPresetService.qml", "services/ShelfService.qml", "services/PinnedAppsService.qml",
    "services/FilesStackService.qml", "services/DockService.qml",
    "scripts/theming", "scripts/hyprland", "scripts/discordVoice", "scripts/eq", "scripts/cava",
    "scripts/musicRecognition", "scripts/system/update-check.sh", "scripts/system/pkg-updates.sh",
    "scripts/system/region-action.sh", "scripts/system/migrate-from-pjsekai.sh", "scripts/wallpapers/wallhaven.sh",
    "assets/icons", "shaders",
]


def scanned_files():
    for path in sorted(MIZU.rglob("*")):
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        relative = path.relative_to(MIZU)
        if relative.parts[0] in SCAN_SKIP_DIRS:
            continue
        yield path, relative


def findings(patterns, skip_comments=False):
    compiled = [(p, re.compile(p)) for p in patterns]
    found = []
    for path, relative in scanned_files():
        for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            stripped = line.strip()
            if skip_comments and (stripped.startswith(("//", "#", "*", "/*"))):
                continue
            for pattern, regex in compiled:
                if regex.search(line):
                    found.append(f"{relative}:{number}: {pattern}")
    return found


def report(found):
    shown = "\n  ".join(found[:40])
    return f"{len(found)} findings, first {min(40, len(found))}:\n  {shown}"


class ForkProvenanceTest(unittest.TestCase):
    def test_upstream_md_names_the_fork_point_and_the_licence(self):
        text = (MIZU / "UPSTREAM.md").read_text(encoding="utf-8")
        self.assertIn("4a3363c2d5e5ffa8e0ee88784bea04a5e6c90cbf", text)
        self.assertIn("GPL-3.0", text)
        self.assertIn("https://github.com/Blapples/SekaiPop", text)

    def test_gpl_licence_text_is_kept(self):
        self.assertIn("GNU GENERAL PUBLIC LICENSE", (MIZU / "LICENSE").read_text(encoding="utf-8"))


class ForbiddenContentTest(unittest.TestCase):
    def test_nothing_writes_plasmas_files_or_system_paths(self):
        found = findings(FORBIDDEN_WRITES)
        self.assertEqual(found, [], report(found))

    def test_no_hyprland_only_api_remains(self):
        found = findings(HYPRLAND_ONLY)
        self.assertEqual(found, [], report(found))

    def test_no_sekaipop_path_or_name_in_code(self):
        found = findings([r"(?i)sekaipop"], skip_comments=True)
        self.assertEqual(found, [], report(found))

    def test_only_allowlisted_programs_are_started(self):
        regex = re.compile(r'(?:command:\s*\[|execDetached\(\s*\[|execDetached\(\s*\{\s*command:\s*\[)\s*"([^"]+)"')
        found = []
        for path, relative in scanned_files():
            if path.suffix != ".qml":
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                for program in regex.findall(line):
                    if program not in ALLOWED_PROGRAMS:
                        found.append(f"{relative}:{number}: starts {program!r}")
        self.assertEqual(found, [], report(found))


# Where a hex color may be written: the token adapter and the defaults (neutral fallbacks), and the night-light ramp,
# which is a physical scale of color temperatures and not a theme color.
HEX_ALLOWED = {
    "modules/common/ThemeSet.qml",
    "modules/common/Tokens.qml",
    "modules/mizu/quickPanel/NightLightDialog.qml",
}


class ColorTokensOnlyTest(unittest.TestCase):
    def test_no_hex_color_literal_outside_the_token_files(self):
        regex = re.compile(r"""["']#[0-9a-fA-F]{3,8}["']""")
        found = []
        for path, relative in scanned_files():
            if path.suffix not in (".qml", ".js") or str(relative) in HEX_ALLOWED:
                continue
            for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                stripped = line.strip()
                if stripped.startswith(("//", "*", "/*")):
                    continue
                if regex.search(line):
                    found.append(f"{relative}:{number}: {stripped[:90]}")
        self.assertEqual(found, [], report(found))


class RemovedModulesTest(unittest.TestCase):
    def test_every_removed_module_is_gone(self):
        present = [name for name in REMOVED if (MIZU / name).exists()]
        self.assertEqual(present, [], f"still present: {present}")

    def test_every_compiled_shader_has_its_source(self):
        orphans = [str(p.relative_to(MIZU)) for p in MIZU.rglob("*.qsb") if not p.with_suffix("").exists()]
        self.assertEqual(orphans, [], f"qsb files without source: {orphans}")


if __name__ == "__main__":
    unittest.main()
