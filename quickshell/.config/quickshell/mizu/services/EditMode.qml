pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// What is left of upstream's Edit Desktop (a full-screen layout editor with a widget shelf, presets and a theme
// board): there is none here, so `active` is false for good and its functions do nothing. The desktop widgets and the
// bar were written against this singleton, so it stays with the members they read.
//
// Two real things remain:
//   widgetsLocked  Desktop widgets can be dragged to a new place only while the desktop is unlocked. Locked is the
//                  default, kept in ~/.cache/mizu/state/edit (scripts/state/edit-state.sh).
//   homeScreen()   Which monitor a widget lives on: the one it was last dropped on, else the default monitor
//                  (DesktopMonitors.qml).
//
//   qs -c mizu ipc call widgets lock | unlock | toggle | status
Singleton {
    id: root

    // ===== Edit Desktop (not carried) =====
    readonly property bool active: false
    readonly property string screenName: ""
    readonly property string editTarget: ""
    readonly property real trayHeight: 0
    readonly property bool compactWindows: false
    readonly property var widgetList: []

    function editing(name) { return false }
    function select(id) {}
    function open(screen, tab) {}
    function close() {}
    function openMenu(screen, x, y) {}
    function closeMenu() {}
    function park(name) {}
    function dropWidget(id, cx, cy, ui, roomW, roomH) {}
    function removeFrom(id, here) {}
    function cardRect(w, h, ui) { return Qt.rect(0, 0, w, h) }
    function scaleFor(name, w, h, ui) { return 1 }
    function xFor(name, w, h, ui) { return 0 }
    function yFor(name, w, h, ui) { return 0 }

    // ===== which monitor a widget lives on =====
    function homeScreen(saved) {
        for (const s of Quickshell.screens) {
            if (s.name === saved)
                return saved
        }
        return DesktopMonitors.fallbackName
    }

    // The widgets that can have a copy on another monitor (services/WidgetClones.qml).
    readonly property var cloneIds: ["clock", "weathercard", "calendarcard", "lyrics"]

    function cloneable(id) {
        return root.cloneIds.indexOf(id) >= 0
    }

    function svcOf(id) {
        if (id === "clock")
            return ClockService
        if (id === "weathercard")
            return WeatherCardService
        if (id === "calendarcard")
            return CalendarCardService
        if (id === "lyrics")
            return LyricsService
        return null
    }

    // The monitor the main copy is on.
    function homeOf(id) {
        const s = root.svcOf(id)
        return s ? root.homeScreen(s.screenName) : ""
    }

    // ===== Lock all =====
    property bool widgetsLocked: true
    property bool lockLoaded: false
    readonly property bool desktopDragAllowed: !root.widgetsLocked

    function setWidgetsLocked(value) {
        root.widgetsLocked = value
        if (root.lockLoaded)
            lockSaver.exec(["sh", root.lockScript, "save", JSON.stringify({ widgetsLocked: root.widgetsLocked })])
    }

    function toggleWidgetsLocked() {
        root.setWidgetsLocked(!root.widgetsLocked)
    }

    readonly property string lockScript: Directories.script("state/edit-state.sh")

    function restoreLock(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.widgetsLocked === "boolean")
                root.widgetsLocked = s.widgetsLocked
        } catch (e) {
            // No file yet (first run) or an unreadable one: stay locked.
        }
        root.lockLoaded = true
    }

    Process {
        running: true
        command: ["sh", root.lockScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restoreLock(text)
        }
        onExited: root.lockLoaded = true
    }

    Process {
        id: lockSaver
    }

    IpcHandler {
        target: "widgets"

        function lock(): void { root.setWidgetsLocked(true) }
        function unlock(): void { root.setWidgetsLocked(false) }
        function toggle(): void { root.toggleWidgetsLocked() }
        function status(): string { return root.widgetsLocked ? "locked" : "unlocked" }
    }
}
