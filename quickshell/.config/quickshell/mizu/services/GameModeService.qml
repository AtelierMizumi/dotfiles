pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Game Mode: the one place that says whether it is on. Everything else just reads `enabled`.
//
// While it is on the shell gets out of the way of a game: the bar shrinks to a fixed strip, the desktop widgets are
// unloaded (not just hidden), the phones are drawn flat (no 2.5D, no shadows). Switching it off puts all of it back.
// It does not touch niri, the GPU or any other program.
//
//   qs -c mizu ipc call gamemode toggle | enable | disable | status
Singleton {
    id: root

    property bool enabled: false

    // Upstream waited for a Hyprland state marker; there is nothing to wait for here.
    readonly property bool loaded: true
    readonly property bool busy: false

    function toggle() {
        root.enabled = !root.enabled
    }

    function set(want) {
        root.enabled = !!want
    }

    IpcHandler {
        target: "gamemode"

        function toggle(): void { root.toggle() }
        function enable(): void { root.set(true) }
        function disable(): void { root.set(false) }
        function status(): string { return root.enabled ? "on" : "off" }
    }
}
