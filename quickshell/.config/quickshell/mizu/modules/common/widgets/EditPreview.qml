import QtQuick

// Upstream snapped a picture of each widget for the Edit Desktop shelf. Nothing shows a shelf here, so this takes
// the same properties and does nothing.
QtObject {
    property string widgetId: ""
    property Item target: null
    property real pixelRatio: 1
}
