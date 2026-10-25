import QtQuick
import Quickshell
import qs.modules.common

// The Power menu's dimming glass. The actual eight pills now float
// outside the phone, beside it (see PowerMenu.qml, instantiated by
// QuickPanel.qml, not this file) — but the "screen going dark" feel only
// reads right if it happens ON the phone's own tilted screen, so that
// half of the old PowerMenu.qml lives here instead, inside
// QuickPanelFace, drawn and warped exactly like the rest of the screen's
// content.
//
// Tapping the dimmed glass dismisses the menu, same as tapping anywhere
// outside the rail.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool open: false
    signal dismissRequested()

    anchors.fill: parent
    visible: opacity > 0
    opacity: root.open ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: root.open ? 120 : 260 }
    }

    // Inset by Theme.phoneScreenInset (rimWidth + bezelWidth, same constant PhoneBody.qml
    // uses) and rounded by (cornerRadius - that inset) so it exactly
    // covers the visible glass, not the bezel around it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: mt.phoneScreenInset
        radius: mt.phoneCornerRadius - mt.phoneScreenInset
        color: mt.scrim
        opacity: root.open ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissRequested()
        }
        antialiasing: true
    }
}
