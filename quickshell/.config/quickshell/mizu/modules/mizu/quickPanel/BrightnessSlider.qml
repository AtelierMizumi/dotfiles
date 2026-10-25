import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mizu.phone

// Brightness as one slider in the Quick Panel: an icon and the value on top, a thin gradient track under it.
// (Upstream's slider carried a gamma stretch too; gamma needed a Hyprland-only tool.)
// Press anywhere on the track and drag: the value under the pointer follows it. Pure UI: QuickPanelFace feeds it
// `brightness` (0-100) and reads changes back out through `brightnessMoved`.
Item {
    id: root

    readonly property var mt: Theme.of(QsWindow.window)

    property real brightness: 100   // 0-100

    property real sliderWidth: 514

    signal brightnessMoved(real value)

    implicitWidth: sliderWidth
    implicitHeight: 56

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
        height: 32

        MaterialIcon {
            id: glyph
            x: 0
            y: (32 - height) / 2
            size: 24
            color: root.ink
            name: "light_mode"
        }
        Text {
            anchors.left: glyph.right
            anchors.leftMargin: 8
            y: (32 - height) / 2
            text: Math.round(root.shownBrightness) + "%"
            color: root.ink
            font.family: mt.fontFamily
            font.pixelSize: 17
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    Rectangle {
        id: track
        x: root.edge
        y: 42
        width: root.trackWidth
        height: 14
        radius: 7
        color: mt.pSurfaceDivider
        antialiasing: true

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.shownBrightness / 100))
            height: parent.height
            radius: 7
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
