import QtQuick
import Quickshell
import qs.modules.common

// One diamond of the beat: the clock widget's BeatDiamond, as a part the
// popups share. Off it is a pale, outlined square turned on its corner; lit
// it takes `litColor`. `pop` springs from big to normal when it lights (or
// whenever something calls `bump()`), like the clock's diamonds.
Rectangle {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool lit: false
    property color litColor: mt.accentMint
    property color offColor: mt.surfaceDivider
    property color lineColor: mt.line
    property real size: 12
    property real pop: 1

    width: root.size
    height: root.size
    radius: Math.max(2, root.size * 0.25)
    rotation: 45
    scale: root.pop
    color: root.lit ? root.litColor : root.offColor
    border.width: 2
    border.color: root.lineColor
    antialiasing: true

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    onLitChanged: {
        if (root.lit)
            root.bump()
    }

    function bump() {
        bumpAnim.restart()
    }

    NumberAnimation {
        id: bumpAnim
        target: root
        property: "pop"
        from: 1.7
        to: 1
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.2
    }
}
