import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// Pure UI, same shape as the Weather/Clock pills. Only worth showing
// when there's more than one layout configured — on a one-layout
// system this would just permanently say "EN" and take up space for
// no reason, so Bar.qml only reports a nonempty layoutCode when there's
// something to switch between. Click cycles to the next layout.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string layoutCode: ""

    // Which edge the bar is on, so the hover tag opens towards the screen.
    property string barPosition: "top"

    // What the hover tag says.
    readonly property string tipText: "Keyboard layout: " + root.layoutCode.toUpperCase() + " (click to switch)"

    signal clicked()

    visible: layoutCode !== ""
    implicitWidth: layoutCode !== "" ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        fillColor: mt.chipFill
        pressed: area.pressed
        implicitWidth: label.implicitWidth + (pill.capsule ? 20 : 28)

        Text {
            id: label
            anchors.centerIn: parent
            text: root.layoutCode
            color: mt.chipInk
            font.family: mt.fontFamily
            font.pixelSize: mt.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
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
