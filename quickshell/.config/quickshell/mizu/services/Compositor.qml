pragma Singleton
import QtQuick
import Quickshell
import "../modules/common/functions/NiriMath.js" as NM

// niri, as the shell sees it. Where upstream asked the compositor,
// the harvested files ask this singleton.
//
// - Workspaces and the focused output come from niri's event stream (services/NiriWorkspaces.qml, NiriMath.js).
// - Actions go through `niri msg action ...`, one short process each: they are rare (a click, a key) and this keeps
//   the shell off a third socket.
// - There is no focus-grab protocol on niri. A popup that must close when you click elsewhere uses
//   modules/common/Catcher.qml, a transparent window behind it.
Singleton {
    id: root

    readonly property bool running: NiriWorkspaces.running
    readonly property var workspaces: NiriWorkspaces.workspaces

    // The monitor the user is looking at: the output of niri's focused workspace ("" until niri has said).
    readonly property string focusedOutput: NM.focusedOutput(root.workspaces) ?? ""

    function screenNamed(name) {
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return null
    }

    // The screen a phone or popup opens on: the focused output, else the first screen.
    function focusedScreen() {
        return root.screenNamed(root.focusedOutput) ?? Quickshell.screens[0]
    }

    function activeOn(output) {
        return NiriWorkspaces.activeOn(output)
    }

    function occupiedOn(output) {
        return NiriWorkspaces.occupiedOn(output)
    }

    function focusWorkspace(output, idx) {
        NiriWorkspaces.focus(output, idx)
    }

    function action(...args) {
        Quickshell.execDetached(["niri", "msg", "action", ...args])
    }

    // Both monitors off; any input wakes them again.
    function powerOffMonitors() {
        root.action("power-off-monitors")
    }

    // The niri session ends. The caller confirms with the user.
    function quit() {
        root.action("quit", "--skip-confirmation")
    }
}
