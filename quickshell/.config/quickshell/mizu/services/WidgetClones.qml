pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// A desktop widget on MORE THAN ONE monitor.
//
// Every widget has one main copy: the one its own service knows about (ClockService.screenName,
// posX, posY ...), on the monitor it was last dropped on. This singleton holds the other copies:
// the same widget, on another monitor, with a spot of its own. Everything else about the widget
// (its style, its size, whether it is on at all) is still the one in its service, so the copies
// always look alike; only where each one sits differs.
//
//   spots   what is saved:  { widgetId: { "DP-2": { x, y, scale } } }   (design pixels, like posX / posY)
//   screens what the shell builds windows from: { widgetId: ["DP-2"] }  only the monitors that are
//           plugged in and are not the main copy's. It is a new object only when a copy is added,
//           removed or a monitor comes or goes, never when a copy is merely moved, so a drag does
//           not rebuild the window (shell.qml: one Variants per widget over `screens[id]`).
//
// Used by EditMode.qml (add / remove / move a copy) and by the widgets themselves
// (`clone: true`, they read and save their spot here instead of in their service).
//
// Which widgets can have copies: EditMode.cloneable(id).
Singleton {
    id: root

    property bool loaded: false
    property var spots: ({})
    property var screens: ({})

    readonly property string script: Directories.script("state/clones-state.sh")

    function has(id, screen) {
        return !!root.spots[id] && root.spots[id][screen] !== undefined
    }

    function spot(id, screen) {
        return root.has(id, screen) ? root.spots[id][screen] : null
    }

    function namesOf(id) {
        return root.spots[id] ? Object.keys(root.spots[id]) : []
    }

    // The monitors that are plugged in, as names.
    function plugged() {
        const out = []
        for (const s of Quickshell.screens)
            out.push(s.name)
        return out
    }

    // The copies that get a window: saved, plugged in, and not on the monitor where the main
    // copy is (it would sit on top of it).
    function rebuild() {
        const here = root.plugged()
        const next = {}
        for (const id in root.spots) {
            const home = EditMode.homeOf(id)
            const list = root.namesOf(id).filter(n => here.indexOf(n) >= 0 && n !== home)
            if (list.length > 0)
                next[id] = list
        }
        if (JSON.stringify(next) !== JSON.stringify(root.screens))
            root.screens = next
    }

    function add(id, screen) {
        if (screen === "" || root.has(id, screen))
            return
        const s = Object.assign({}, root.spots)
        s[id] = Object.assign({}, s[id] || {})
        // -1: no spot yet, the widget puts the copy where a new one goes
        s[id][screen] = { x: -1, y: -1, scale: 0 }
        root.spots = s
        root.rebuild()
        root.persist()
    }

    function remove(id, screen) {
        if (!root.has(id, screen))
            return
        const s = Object.assign({}, root.spots)
        s[id] = Object.assign({}, s[id])
        delete s[id][screen]
        if (Object.keys(s[id]).length === 0)
            delete s[id]
        root.spots = s
        root.rebuild()
        root.persist()
    }

    function setSpot(id, screen, x, y, scale) {
        if (!root.loaded || !root.has(id, screen))
            return
        const old = root.spots[id][screen]
        const sc = (typeof scale === "number" && scale > 0) ? scale : old.scale
        const s = Object.assign({}, root.spots)
        s[id] = Object.assign({}, s[id])
        s[id][screen] = { x: x, y: y, scale: sc }
        root.spots = s
        root.persist()
    }

    // Back to "no spot yet": the widget puts the copy where a new one goes.
    function clearSpot(id, screen) {
        if (!root.has(id, screen))
            return
        const s = Object.assign({}, root.spots)
        s[id] = Object.assign({}, s[id])
        s[id][screen] = { x: -1, y: -1, scale: 0 }
        root.spots = s
        root.persist()
    }

    // `ipc <widget> resetPosition` also brings the copies back to a first spot.
    function clearAll(id) {
        for (const n of root.namesOf(id))
            root.clearSpot(id, n)
    }

    // Where a main copy is (its service has read its saved state, or it was moved) decides which
    // monitor is NOT given a copy's window.
    Connections {
        target: ClockService

        function onScreenNameChanged() {
            root.rebuild()
        }
    }

    Connections {
        target: WeatherCardService

        function onScreenNameChanged() {
            root.rebuild()
        }
    }

    Connections {
        target: CalendarCardService

        function onScreenNameChanged() {
            root.rebuild()
        }
    }

    Connections {
        target: LyricsService

        function onScreenNameChanged() {
            root.rebuild()
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.rebuild()
        }
    }

    // ===== persistence =====
    function snapshot() {
        return JSON.stringify({ spots: root.spots })
    }

    function restore(text) {
        try {
            const d = JSON.parse(text)
            const out = {}
            if (d && d.spots && typeof d.spots === "object") {
                for (const id in d.spots) {
                    const per = {}
                    for (const scr in d.spots[id]) {
                        const p = d.spots[id][scr]
                        if (p && typeof p.x === "number" && typeof p.y === "number")
                            per[scr] = { x: p.x, y: p.y, scale: (typeof p.scale === "number" && p.scale > 0) ? p.scale : 0 }
                    }
                    if (Object.keys(per).length > 0)
                        out[id] = per
                }
            }
            root.spots = out
        } catch (e) {
            // No file yet (nobody has used a second monitor) or an unreadable one: no copies.
        }
        root.loaded = true
        root.rebuild()
    }

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
