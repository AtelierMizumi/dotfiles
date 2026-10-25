import QtQuick
import Quickshell
import Quickshell.Wayland

// Closes a popup when you click anywhere else. Upstream used Hyprland's focus-grab protocol; niri has none, so a
// popup that must go away on an outside click gets this instead: a transparent window over the whole screen, mapped
// just below the popup. A press on it only says "dismissed"; the popup decides what that means (usually: close).
//
//     Catcher { screen: win.screen; open: popup.shown; layer: WlrLayer.Top; onDismissed: popup.close() }
//
// The popup must be on the same layer or one above and be mapped AFTER the catcher (layer-shell stacks windows of the
// same layer in the order they were mapped), so set `open` before the popup becomes visible, or give the popup the
// next layer up (Overlay over a Top catcher).
PanelWindow {
    id: root

    // Mapped while true. Nothing exists on screen (and no input is taken) while it is false.
    property bool open: false
    property int layer: WlrLayer.Top

    signal dismissed()

    visible: root.open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: root.layer
    WlrLayershell.namespace: "mizu-catcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.dismissed()
    }
}
