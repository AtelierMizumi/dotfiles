pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The wallpaper: which picture is on the desktop, the folder the picker lists, and the palette that follows it.
//
// Every time the picture changes (a pick, the next one, a random one, the first start) the palette tool runs on it
// (palette/mizu_palette.py) and rewrites ~/.cache/mizu/tokens.json, which Tokens.qml watches, so the shell recolors
// itself, and ~/.config/niri/colors.kdl, which niri includes for the focus ring.
//
// One wallpaper for every monitor. The pick is remembered in ~/.cache/mizu/state/wallpaper (scripts/state/wallpaper-state.sh).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string customFolder: SettingsService.get("wallpaper.folder")
    readonly property string directory: root.customFolder !== "" ? root.customFolder : root.home + "/Pictures/Wallpapers"
    readonly property url directoryUrl: "file://" + root.directory
    readonly property string directoryShort: root.directory.startsWith(root.home) ? "~" + root.directory.slice(root.home.length)
                                                                                  : root.directory

    // The picture on the desktop now: an absolute path, "" when there is none.
    property string current: ""
    // The pictures of the folder, searched recursively, sorted by path.
    property var files: []

    property bool restoring: true
    property bool listed: false
    readonly property bool ready: !root.restoring && root.listed && SettingsService.loaded
    // Kept for the files that ask "is there a wallpaper yet" (upstream's name).
    readonly property string defaultPath: root.current
    // Upstream raised the widgets above the wallpaper while it re-stacked; nothing here needs that.
    readonly property bool restacking: false
    property bool folderPicking: false

    readonly property string stateScript: Directories.script("state/wallpaper-state.sh")
    readonly property string paletteTool: Directories.shell + "/palette/mizu_palette.py"

    function imageFor(screenName) {
        return root.current === "" ? "" : "file://" + root.current
    }

    function pathFor(screenName) {
        return root.current
    }

    // The lock screen shows the desktop's picture.
    function lockPathFor(screenName) {
        return root.current
    }

    function lockImagePathFor(screenName) {
        return root.imageFor(screenName)
    }

    function restackWidgets() {}

    function setWallpaper(path, screenName) {
        if (typeof path !== "string" || path === "" || path === root.current)
            return
        root.current = path
        saver.exec(["sh", root.stateScript, "save", path])
        root.runPalette()
    }

    // Only if nothing has been picked yet.
    function ensureDefault(path) {
        if (root.current === "")
            root.setWallpaper(path, "")
    }

    function next(step) {
        if (root.files.length === 0)
            return
        const at = root.files.indexOf(root.current)
        const n = root.files.length
        root.setWallpaper(root.files[((at < 0 ? 0 : at + (step ?? 1)) % n + n) % n], "")
    }

    function random() {
        if (root.files.length === 0)
            return
        let pick = root.files[Math.floor(Math.random() * root.files.length)]
        if (pick === root.current && root.files.length > 1)
            pick = root.files[(root.files.indexOf(pick) + 1) % root.files.length]
        root.setWallpaper(pick, "")
    }

    function resetFolder() {
        SettingsService.set("wallpaper.folder", "")
    }

    // The folder chooser of upstream is not carried; the folder is a setting (wallpaper.folder).
    function pickFolder() {}

    function rescan() {
        lister.running = true
    }

    // Runs the palette tool for the current wallpaper. A run in progress finishes first, then the latest picture is done.
    function runPalette() {
        if (root.current === "")
            return
        if (palette.running) {
            palette.again = true
            return
        }
        palette.again = false
        palette.exec(["python3", "-I", "-B", root.paletteTool, root.current, "--mode", SettingsService.get("theme.mode")])
    }

    readonly property string themeMode: SettingsService.get("theme.mode")
    onThemeModeChanged: root.runPalette()

    // Start: the remembered pick, then the folder, then the palette if there is no token file yet.
    Component.onCompleted: {
        restorer.running = true
        lister.running = true
    }

    // Once both the remembered pick and the folder are known: nothing remembered means the first picture of the folder;
    // otherwise the palette is made if there is no token file yet.
    function settle() {
        if (!root.listed || root.restoring)
            return
        if (root.current === "")
            root.pickFirst()
        else if (!Tokens.loaded)
            root.runPalette()
    }

    function pickFirst() {
        if (root.files.length > 0)
            root.setWallpaper(root.files[0], "")
    }

    Process {
        id: restorer
        command: ["sh", root.stateScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path !== "")
                    root.current = path
                root.restoring = false
                root.settle()
            }
        }
        onExited: {
            root.restoring = false
        }
    }

    Process {
        id: lister
        command: ["sh", "-c",
                  "find -L \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort",
                  "sh", root.directory]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(line => line !== "")
                root.listed = true
                root.settle()
            }
        }
        onExited: root.listed = true
    }

    Process {
        id: saver
    }

    Process {
        id: palette
        property bool again: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("WallpaperService: palette tool: " + text.trim())
            }
        }
        onExited: {
            if (palette.again)
                root.runPalette()
        }
    }

    Timer {
        interval: Math.max(1, SettingsService.get("wallpaper.randomMinutes")) * 60000
        running: SettingsService.get("wallpaper.randomMinutes") > 0
        repeat: true
        onTriggered: root.random()
    }

    // Lock screen transition stubs
    readonly property string transitionStyle: "sekaiRing"
    readonly property int ringVariant: 0
    readonly property real ringDistortion: 0.0
    readonly property real ringSpeed: 1.0
    readonly property real ringWidth: 0.2
    readonly property real ringColorIntensity: 1.0
    readonly property vector2d ringCenter: Qt.vector2d(0.5, 0.5)
    readonly property real starColorIntensity: 1.0
    readonly property vector2d starCenter: Qt.vector2d(0.5, 0.5)
    readonly property real starThickness: 1.0
    readonly property real starPointLength: 1.0
    readonly property real starCurvature: 1.0
    readonly property real starElastic: 1.0
    readonly property real starSpin: 0.0
    readonly property vector2d blocksDirection: Qt.vector2d(1.0, 1.0)
    readonly property real blocksBandThickness: 1.0
    readonly property real blocksBlockSize: 32.0
    readonly property real blocksStagger: 0.0
    readonly property int transitionEasing: Easing.InOutQuad

    function transitionMsFor(style) { return 600 }
    function transitionLinearFor(style) { return true }
    function lockShaderStemFor(style) { return "ring_lock" }
    function rollLockStyle() {}
}
