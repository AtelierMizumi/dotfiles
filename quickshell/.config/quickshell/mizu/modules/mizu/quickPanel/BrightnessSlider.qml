import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mizu.phone

// Brightness as one slider in the Quick Panel: an icon and the value on top, a thin gradient track under it.
// (Upstream's slider carried a gamma stretch too; gamma needed a Hyprland-only tool.)
// Press anywhere on the track and drag: the value under the pointer follows it. Pure UI: QuickPanelFace feeds it
// `brightness` (0-100) and reads changes back out through `brightnessMoved`.
//
// With several monitors the face lays one of these per monitor in compact mode: same slider, smaller, with the
// monitor's connector name after the icon and the value pushed to the right end.
Item {
    id: root

    readonly property var mt: Theme.of(QsWindow.window)

    property real brightness: 100   // 0-100

    // Monitor name ("eDP-1", "HDMI-A-1") for the multi-monitor rows; "" keeps the original single-slider look.
    property string label: ""
    property bool compact: false

    property real sliderWidth: 514

    signal brightnessMoved(real value)

    implicitWidth: sliderWidth
    implicitHeight: compact ? 36 : 56

    readonly property real edge: 20                          // left/right margin, as VolumeSlider
    readonly property real trackWidth: sliderWidth - edge * 2

    // The track follows the pointer while dragging, not the real value (which only catches up after the round trip to
    // brightnessctl / ddcutil). -1 = not driven by a drag.
    property bool dragging: false
    property real dragBrightness: -1
    readonly property real shownBrightness: dragging && dragBrightness >= 0 ? dragBrightness : brightness

    readonly property color ink: mt.pInk

    Item {
        x: root.edge
        width: root.trackWidth
        height: root.compact ? 22 : 32

        MaterialIcon {
            id: glyph
            x: 0
            y: (parent.height - height) / 2
            size: root.compact ? 16 : 24
            color: root.ink
            name: "light_mode"
        }
        Text {
            id: readout
            text: Math.round(root.shownBrightness) + "%"
            color: root.ink
            font.family: mt.fontFamily
            font.pixelSize: root.compact ? 14 : 17
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            anchors.verticalCenter: parent.verticalCenter
            // With a name shown, the value reads from the right edge; without one it stays beside the icon.
            anchors.left: root.label !== "" ? undefined : glyph.right
            anchors.leftMargin: 8
            anchors.right: root.label !== "" ? parent.right : undefined
        }
        Text {
            visible: root.label !== ""
            text: root.label
            color: root.ink
            opacity: 0.72
            elide: Text.ElideRight
            font.family: mt.fontFamily
            font.pixelSize: root.compact ? 13 : 15
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: glyph.right
            anchors.leftMargin: 8
            anchors.right: readout.left
            anchors.rightMargin: 10
        }
    }

    Rectangle {
        id: track
        x: root.edge
        y: root.compact ? 26 : 42
        width: root.trackWidth
        height: root.compact ? 8 : 14
        radius: height / 2
        color: mt.pSurfaceDivider
        antialiasing: true

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.shownBrightness / 100))
            height: parent.height
            radius: parent.radius
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mt.accentMint }
                GradientStop { position: 1.0; color: mt.accentCyan }
            }
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 150 }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function setFromX(mx) {
                root.dragBrightness = Math.max(0, Math.min(1, mx / track.width)) * 100
                root.brightnessMoved(root.dragBrightness)
                PanelActivity.touch()
            }

            function endDrag() {
                root.dragging = false
                root.dragBrightness = -1
            }

            onPressed: mouse => {
                root.dragBrightness = -1
                root.dragging = true
                setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed)
                    setFromX(mouse.x)
            }
            onReleased: endDrag()
            onCanceled: endDrag()
        }
    }
}
