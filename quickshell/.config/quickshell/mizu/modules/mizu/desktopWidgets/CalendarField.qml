import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// A one-line text box on the calendar card (the To-Do card's add box): click anywhere
// in it to type. `bad` outlines it in `badInk`; Enter fires `accepted`, Esc `cancelled`.
//
//   CalendarField { hint: "Title"; icon: "title"; onAccepted: save() }
//
// `text` is the typed text; `input` is the TextInput itself (to give it the keyboard).
Rectangle {
    id: field

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property alias input: ti
    property alias text: ti.text
    property string hint: ""
    property string icon: ""
    property bool bad: false
    property color badInk: mt.danger
    signal accepted()
    signal cancelled()

    height: 34
    radius: 11
    color: ti.activeFocus ? mt.pSurface : mt.pSurfaceHover
    border.width: 2.5
    border.color: field.bad ? field.badInk : mt.pLine

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.IBeamCursor
        onPressed: ti.forceActiveFocus()
    }

    MaterialIcon {
        id: fieldIcon
        visible: field.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 9
        anchors.verticalCenter: parent.verticalCenter
        name: field.icon
        size: 16
        weight: 600
        fill: 0
        color: mt.pInkSub
    }

    TextInput {
        id: ti
        anchors.left: fieldIcon.visible ? fieldIcon.right : parent.left
        anchors.leftMargin: fieldIcon.visible ? 6 : 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        selectByMouse: true
        color: mt.pInk
        selectionColor: mt.accentCyan
        selectedTextColor: mt.colBorder
        font.family: mt.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold

        onAccepted: field.accepted()
        Keys.onEscapePressed: field.cancelled()

        Text {
            visible: ti.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: field.hint
            color: mt.pInkSub
            font: ti.font
        }
    }
}
