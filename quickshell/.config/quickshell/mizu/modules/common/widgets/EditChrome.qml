import QtQuick

// Edit Desktop is not part of this shell (upstream drew selection handles, a shield and a remove key here while the
// desktop was being edited). The desktop widgets are still built around this item, so it stays as an inert one with
// the properties and signals they read. Widgets are moved by dragging them while the desktop is unlocked
// (EditMode.desktopDragAllowed), which their own mouse areas handle.
Item {
    id: root

    property string widgetId: ""
    property Item target: null
    property real roomW: 0
    property real roomH: 0
    property string screenName: ""

    readonly property bool selected: false
    readonly property bool editing: false
    readonly property bool dragging: false
    readonly property bool ownDrag: false
    readonly property bool raised: false

    signal moved()
    signal removeRequested()
}
