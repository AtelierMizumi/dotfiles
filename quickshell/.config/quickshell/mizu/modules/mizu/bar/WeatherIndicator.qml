import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// The weather pill in the bar: an icon that matches the current
// conditions plus the temperature. Pure UI (no Quickshell imports):
// Status_Bar.qml feeds it the text and the icon name from
// WeatherSource.qml (via Bar.qml). Same pill shape as Date / Clock, and it
// presses like a physical button — a click opens WeatherPopup.qml.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string text: "--"
    property string iconName: "cloud"

    // True on a standing bar (left / right edge): icon over temperature.
    property bool vertical: false

    // Which edge the bar is on, so the hover tag opens towards the screen.
    property string barPosition: "top"

    // What the hover tag says.
    readonly property string tipText: "Weather: " + root.text

    signal clicked()

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        fillColor: mt.chipFill
        pressed: area.pressed
        ringWidth: 6   // the bar's pills all share the Utility pill's ring
        implicitWidth: root.vertical ? pill.barVWidth : weatherIcon.width + label.implicitWidth + (pill.capsule ? 26 : 34)
        implicitHeight: root.vertical
            ? vcol.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 8 + mt.shadowOffset
            : mt.pillHeight + mt.shadowOffset

        Column {
            id: vcol
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 1

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.iconName
                size: 24
                color: mt.chipInk
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.text
                color: mt.chipInk
                font.family: mt.fontFamily
                font.pixelSize: mt.fontSizeInfo
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }

        MaterialIcon {
            id: weatherIcon
            visible: !root.vertical
            name: root.iconName
            size: 24
            color: mt.chipInk
            x: 10
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: label
            visible: !root.vertical
            anchors.left: weatherIcon.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: mt.chipInk
            font.family: mt.fontFamily
            font.pixelSize: mt.fontSizeInfo
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // A sibling of the Pill (not inside it) so the hit area doesn't
    // move with the pressed cap — same as the date and clock buttons.
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
