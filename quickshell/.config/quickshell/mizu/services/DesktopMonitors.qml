pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Which monitor the desktop widgets use.
//
// Monitors are remembered BY NAME ("DP-1", "HDMI-A-1"), never by their place in the list: the
// compositor can list them in another order after a reboot, and "the first monitor" then is
// another one. A name stays the same.
//
//   defaultScreen  where a widget goes when it has no monitor of its own yet, or when its monitor
//                  is not plugged in. "" = automatic (the first one the compositor lists).
//   homes          the monitor of the widgets that have no monitor of their own in their service:
//                  { todo: "DP-1", notes: "DP-2" }. Chosen in Settings → Desktop → Widgets, or by
//                  adding the widget while editing the monitor you want it on.
//
// A monitor that is not plugged in (switched off at boot, say) is skipped: the widget shows on
// the default monitor, and goes back to its own as soon as that one comes back.
Singleton {
    id: root

    property bool loaded: false
    property string defaultScreen: ""
    property var homes: ({})

    readonly property string script: Directories.script("state/monitors-state.sh")

    function plugged(name) {
        if (typeof name !== "string" || name === "")
            return false
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return true
        }
        return false
    }

    // The monitor a widget with no (usable) monitor of its own gets.
    readonly property string fallbackName: {
        if (root.plugged(root.defaultScreen))
            return root.defaultScreen
        const ext = Quickshell.screens.find(s => !s.name.startsWith("eDP"))
        if (ext)
            return ext.name
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""
    }

    readonly property var fallbackScreen: Quickshell.screens.find(s => s.name === root.fallbackName) ?? Quickshell.screens[0]

    // The monitor of the To-Do (id "todo") or the Sticky Notes (id "notes").
    function homeFor(id) {
        const n = root.homes[id] ?? ""
        return root.plugged(n) ? n : root.fallbackName
    }

    // For the settings: "Automatic" and every monitor that is plugged in, with its model so that
    // "the Philips" and "the AOC" can be told apart.
    readonly property var choices: {
        const out = [{ id: "", label: "Automatic", icon: "auto_mode" }]
        for (const s of Quickshell.screens) {
            const model = s.model ? String(s.model) : ""
            out.push({ id: s.name, label: model !== "" ? (s.name + " · " + model) : s.name, icon: "desktop_windows" })
        }
        return out
    }

    function setDefault(name) {
        const n = typeof name === "string" ? name : ""
        if (n === root.defaultScreen)
            return
        root.defaultScreen = n
        root.persist()
    }

    // name "" = automatic (the default monitor).
    function setHome(id, name) {
        const n = typeof name === "string" ? name : ""
        if ((root.homes[id] ?? "") === n)
            return
        const h = Object.assign({}, root.homes)
        if (n === "")
            delete h[id]
        else
            h[id] = n
        root.homes = h
        root.persist()
    }

    // ===== persistence =====
    function snapshot() {
        return JSON.stringify({ defaultScreen: root.defaultScreen, homes: root.homes })
    }

    function restore(text) {
        try {
            const d = JSON.parse(text)
            if (typeof d.defaultScreen === "string")
                root.defaultScreen = d.defaultScreen
            const h = {}
            if (d.homes && typeof d.homes === "object") {
                for (const k in d.homes) {
                    if (typeof d.homes[k] === "string" && d.homes[k] !== "")
                        h[k] = d.homes[k]
                }
            }
            root.homes = h
        } catch (e) {
            // No file yet (nothing was chosen) or an unreadable one: automatic.
        }
        root.loaded = true
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
