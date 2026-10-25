import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// Pure UI. Same 36px square-cle as the tray button, since it's the
// same kind of thing — a toggle-ish button that lives in the bar. Reuses
// the bell icons the Quick Panel's Notifications tile uses
// (notifications_active / notifications_off, Material Symbols Rounded)
// rather than drawing a third bell from scratch. Click opens the Quick
// Panel — the notification list lives
// there, this is just "is anything waiting, and is do-not-disturb on".
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property int count: 0
    property bool doNotDisturb: false

    // Which edge the bar is on, so the hover tag opens towards the screen.
    property string barPosition: "top"

    // What the hover tag says.
    readonly property string tipText: (root.count === 0 ? "No notifications" : root.count + (root.count === 1 ? " notification" : " notifications")) + (root.doNotDisturb ? " · do not disturb" : "")

    signal clicked()

    implicitWidth: mt.pillHeight
    implicitHeight: mt.pillHeight + mt.shadowOffset

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        ringWidth: 8
        fillColor: root.doNotDisturb ? mt.surface : mt.accentCyan
        pressed: area.pressed

        MaterialIcon {
            // (Capsule: the chip is dark, so the ink is the chip's own.)
            color: pill.capsule ? mt.capInk : (root.doNotDisturb ? mt.ink : mt.colBorder)
            anchors.centerIn: parent
            size: 18
            name: root.doNotDisturb ? "notifications_off" : "notifications_active"
        }

        Rectangle {
            visible: !root.doNotDisturb && root.count > 0
            anchors {
                top: parent.top
                right: parent.right
                topMargin: -2
                rightMargin: -2
            }
            radius: 8
            color: mt.danger
            border.width: 2
            border.color: mt.ringWhite
            implicitWidth: Math.max(16, countLabel.implicitWidth + 8)
            implicitHeight: 16

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: root.count > 9 ? "9+" : root.count
                color: "white"
                font.family: mt.fontFamily
                font.pixelSize: 9
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
            antialiasing: true
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // The hover tag (BarTip.qml): what the popup behind the click would tell you, at a glance.
    BarTip {
        shown: area.containsMouse
        pressed: area.pressed
        text: root.tipText
        barPosition: root.barPosition
    }
}
