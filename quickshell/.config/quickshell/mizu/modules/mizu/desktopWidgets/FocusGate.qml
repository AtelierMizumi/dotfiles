import QtQuick

// What upstream called Desktop Focus Mode (hide the desktop widgets while a window covers the monitor) is not part of
// this shell: the widgets are on the Background layer, under every window, so there is nothing to hide. The gate is
// kept so each widget and the loaders in shell.qml read the same properties; it is always "visible".
QtObject {
    property string screenName: ""
    property string widgetId: ""
    // The gates beside the LazyLoaders in shell.qml set this; it changes nothing now.
    property bool unloads: false

    readonly property bool gone: false
    readonly property bool hidden: false
    readonly property bool show: true
    readonly property bool dimmed: false
    readonly property bool suspended: false
}
