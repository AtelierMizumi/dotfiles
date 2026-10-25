import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// Pure UI (no Quickshell imports): Status_Bar.qml feeds this what
// BatterySource.qml knows. Hidden entirely on a desktop (no battery to
// report). The glyph is the Material Symbols Rounded "battery_android_frame"
// family (frame_1..frame_6, frame_full, frame_bolt) rather than a drawn
// shape or an exported image — same font MaterialIcon.qml already draws
// every other bar icon from, so it needs nothing extra installed. It
// still recolors live (low battery goes red-ish, unless it's charging).
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool available: false
    property int percentage: 0
    property bool isCharging: false
    property bool isLow: false

    // True on a standing bar (left / right edge): the glyph sits over
    // the percentage instead of beside it.
    property bool vertical: false

    // Which edge the bar is on, so the hover tag opens towards the screen.
    property string barPosition: "top"

    // What the hover tag says.
    readonly property string tipText: "Battery: " + root.percentage + "%" + (root.isCharging ? " · charging" : (root.isLow ? " · low" : ""))

    signal clicked()

    visible: available
    implicitWidth: available ? pill.implicitWidth : 0
    implicitHeight: pill.implicitHeight

    readonly property color glyphTone: root.isLow ? mt.danger : mt.chipInk

    // Picks the frame that matches the level: bolt while charging (the
    // set has no per-level charging glyph, just the one bolt), full at
    // 100, otherwise the percentage split evenly into frame_1..frame_6.
    readonly property string glyphName: {
        if (root.isCharging) return "battery_android_frame_bolt"
        if (root.percentage >= 100) return "battery_android_frame_full"
        var bucket = Math.ceil(root.percentage / (100 / 6))
        return "battery_android_frame_" + Math.max(1, Math.min(6, bucket))
    }

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        fillColor: mt.chipFill
        pressed: area.pressed
        ringWidth: 6   // the bar's pills all share the Utility pill's ring
        implicitWidth: root.vertical ? pill.barVWidth : batteryRow.implicitWidth + (pill.capsule ? 20 : 26)
        implicitHeight: root.vertical
            ? batteryColumn.implicitHeight + (pill.capsule ? 4 : 2 * ringWidth) + 12 + mt.shadowOffset
            : mt.pillHeight + mt.shadowOffset

        Column {
            id: batteryColumn
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 1

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: root.glyphName
                size: 20
                color: root.glyphTone
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.percentage + "%"
                color: mt.chipInk
                font.family: mt.fontFamily
                font.pixelSize: mt.fontSizeInfo
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }

        Row {
            id: batteryRow
            visible: !root.vertical
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.glyphName
                size: 20
                color: root.glyphTone
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.percentage + "%"
                color: mt.chipInk
                font.family: mt.fontFamily
                font.pixelSize: mt.fontSizeInfo
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
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
