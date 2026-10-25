import QtQuick

// Upstream showed a "2x2 / full" key on a selected widget while editing. Widgets are selected only in Edit Desktop,
// which does not exist here, so the key is never shown; the properties and the signal stay for the widgets that
// declare it.
Item {
    property bool shown: false
    property bool small: true
    signal toggled()

    visible: false
}
