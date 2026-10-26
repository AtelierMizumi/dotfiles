pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The desktop user card widget's state — where the card sits and whether it's
// shown — kept as its own singleton (like ClockService.qml) so anything else
// can flip it without touching UserCardWidget.qml:
//
//   import qs.services
//   ...
//   UserCardService.setShown(false)
//
// UserCardWidget.qml is the only thing that draws it. The picture on the card
// is the same avatar the Quick Panel shows (PanelImages.qml), so it is not
// stored here.
//
// Persistence is the same convention as ClockService: a tiny shell script
// (usercard-state.sh) run as a Process. Position is saved straight away, the
// rest is debounced.
Singleton {
    id: root

    // False until the saved state has been read. Nothing is written before
    // then, or a fresh start would overwrite what's on disk with defaults.
    property bool loaded: false

    property bool shown: false       // off until you add it: ipc usercard toggle
    property real posX: -1           // -1 = never placed; widget picks a default
    property real posY: -1
    // The shell scale (ShellScale) posX / posY were saved at.
    property real posScale: 0
    // The monitor (output name, e.g. "DP-1") the card was last dropped on.
    property string screenName: ""

    // Saved straight away (no wait): a refresh or reload right after you drop
    // the card must not be able to beat the save.
    function setPosition(x, y, screen, scale) {
        if (!root.loaded)
            return
        root.posX = x
        root.posY = y
        if (typeof scale === "number" && scale > 0)
            root.posScale = scale
        if (typeof screen === "string" && screen !== "")
            root.screenName = screen
        saveTimer.stop()
        saver.save(root.snapshot())
    }

    function setShown(value) {
        root.shown = value
        root.persist()
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/usercard-state.sh")

    function snapshot() {
        return JSON.stringify({
            x: root.posX,
            y: root.posY,
            scale: root.posScale,
            screen: root.screenName,
            shown: root.shown
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.x === "number")
                root.posX = s.x
            if (typeof s.y === "number")
                root.posY = s.y
            if (typeof s.scale === "number" && s.scale > 0)
                root.posScale = s.scale
            if (typeof s.screen === "string")
                root.screenName = s.screen
            root.shown = s.shown !== false
        } catch (e) {
            // No file yet (first run) or an unreadable one: keep the defaults.
        }
        root.loaded = true
    }

    // Runs once, at startup.
    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: root.restore(text)
        }
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    // Fire-and-forget save.
    Process {
        id: saver

        property var pending: null

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
