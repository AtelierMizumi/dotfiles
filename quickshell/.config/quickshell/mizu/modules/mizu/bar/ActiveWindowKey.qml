import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// The Active window on a standing bar: there is no room for two lines of text
// beside the screen edge, so it is a small square key, the same size as the
// other square keys on the bar (updates, utility). It shows the focused app's
// icon (or the first letter of its name while no icon can be found, or the
// workspace number while nothing is focused), and the full "App - title" in the
// hover tag, which opens towards the inside of the screen like the other tags.
// Pure UI: Status_Bar feeds it plain strings.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool hasWindow: false
    property string app: ""
    property string title: ""
    property string icon: ""          // resolved file url, "" when unknown
    property int workspace: 1
    property string barPosition: "left"

    implicitWidth: mt.pillHeight
    implicitHeight: mt.pillHeight + mt.shadowOffset

    // One line, whatever the title holds (a newline would grow the tag).
    readonly property string tipText: !root.hasWindow
        ? "Workspace " + root.workspace
        : (root.title !== "" && root.title.toLowerCase() !== root.app.toLowerCase()
            ? root.app + " \u2014 " + root.title.replace(/\s+/g, " ")
            : root.app)

    // The glyph in the key: the icon if it loaded, else a letter / number.
    readonly property bool iconReady: root.hasWindow && root.icon !== "" && iconImage.status === Image.Ready
    readonly property string letter: !root.hasWindow
        ? String(root.workspace)
        : (root.app !== "" ? root.app.charAt(0).toUpperCase() : "?")

    Pill {
        id: pill
        anchors.fill: parent
        cornerRadius: mt.radiusBadge
        ringWidth: 8
        pressed: area.pressed
        fillGradient: Gradient {
            GradientStop { position: 0.0; color: mt.accentMint }
            GradientStop { position: 1.0; color: mt.accentCyan }
        }

        Image {
            id: iconImage
            anchors.centerIn: parent
            width: 18
            height: 18
            sourceSize: Qt.size(36, 36)   // twice the size: stays sharp when the shell is scaled up
            source: root.hasWindow ? root.icon : ""
            asynchronous: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            visible: root.iconReady
        }

        Text {
            anchors.centerIn: parent
            visible: !root.iconReady
            text: root.letter
            color: mt.accentInk
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    BarTip {
        shown: area.containsMouse
        text: root.tipText
        barPosition: root.barPosition
    }
}
