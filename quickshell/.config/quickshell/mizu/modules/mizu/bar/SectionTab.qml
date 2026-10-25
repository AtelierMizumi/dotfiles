import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A small slanted label tab with a diamond, the way the game's menus name
// their sections ("FORECAST", "POWER MODE"). The popups use it to give every
// block of a card a heading, in the same plate shape.
//
//   SectionTab { text: "forecast" }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string text: ""
    property color tabColor: mt.chipFill
    property color inkColor: mt.chipInk
    property color gemColor: mt.dark ? mt.accentMint : mt.colBorder

    implicitWidth: Math.ceil(label.implicitWidth + 40 + tab.lean)
    implicitHeight: 24

    Slant {
        id: tab
        anchors.fill: parent
        skew: 0.22
        radius: 8
        color: root.tabColor
        borderColor: mt.line
        borderWidth: 2
    }

    DiamondDot {
        x: tab.lean / 2 + 10
        y: (root.height - height) / 2
        size: 7
        lit: true
        litColor: root.gemColor
        lineColor: root.tabColor
    }

    Text {
        id: label
        x: tab.lean / 2 + 26
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        color: root.inkColor
        font.family: mt.fontFamily
        font.pixelSize: 10
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        font.letterSpacing: 1.2
    }
}
