import QtQuick

// Upstream shrank the whole desktop into a framed card while Edit Desktop was open and this item carried that
// transform. There is no Edit Desktop here, so the stage is a plain item the size of its parent.
Item {
    id: root

    property var screenObj: null
    property real uiScale: 1
    readonly property string screenName: root.screenObj ? root.screenObj.name : ""
    property real originX: 0
    property real originY: 0
    property real refWidth: root.width
    property real refHeight: root.height
    readonly property bool editing: false

    width: root.parent ? root.parent.width : 0
    height: root.parent ? root.parent.height : 0
}
