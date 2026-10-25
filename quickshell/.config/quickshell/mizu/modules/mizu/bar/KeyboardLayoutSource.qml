import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// niri's keyboard layouts, for the bar's layout pill (KeyboardLayoutIndicator.qml). Reads `niri msg -j event-stream`
// while `wanted`: niri sends the layout list once on connect and a line for every switch, so nothing polls.
//
//   code    "EN", "VI"... the first two letters of the active layout's name, "" when there is only one layout
//   next()  switch to the next layout (`niri msg action switch-layout next`)
Scope {
    id: root

    property bool wanted: false

    property var names: []
    property int index: 0

    readonly property string code: root.names.length > 1 && root.names[root.index]
        ? String(root.names[root.index]).slice(0, 2).toUpperCase() : ""

    function next() {
        Compositor.action("switch-layout", "next")
    }

    function handle(line) {
        let msg
        try {
            msg = JSON.parse(line)
        } catch (e) {
            return
        }
        const changed = msg.KeyboardLayoutsChanged
        if (changed && changed.keyboard_layouts) {
            root.names = changed.keyboard_layouts.names || []
            root.index = changed.keyboard_layouts.current_idx || 0
            return
        }
        const switched = msg.KeyboardLayoutSwitched
        if (switched && typeof switched.idx === "number")
            root.index = switched.idx
    }

    Process {
        running: root.wanted && Compositor.running
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
    }
}
