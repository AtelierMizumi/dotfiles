import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The desktop picture of one screen, on the background layer. Two images lie on top of each other: a new picture is
// loaded into the hidden one and faded in over the one that is showing (wallpaper.duration ms), so a change never
// shows a black frame. One per screen, from `Variants { model: Quickshell.screens }` in shell.qml.
PanelWindow {
    id: win

    required property var modelData
    screen: win.modelData

    color: "black"
    visible: SettingsService.flag("wallpaper.enabled") && !WallpaperService.covered(win.screen ? win.screen.name : "")

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "mizu-wallpaper"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    property bool firstOnTop: true
    readonly property url wanted: WallpaperService.imageFor(win.screen ? win.screen.name : "")
    readonly property real fadeMs: SettingsService.get("wallpaper.duration")

    onWantedChanged: win.load()
    Component.onCompleted: win.load()

    function load() {
        const top = win.firstOnTop ? first : second
        const hidden = win.firstOnTop ? second : first
        if (String(top.source) === String(win.wanted))
            return
        if (String(hidden.source) === String(win.wanted) && hidden.status === Image.Ready) {
            win.firstOnTop = hidden === first
            return
        }
        hidden.source = win.wanted
    }

    // An image that finished loading becomes the top one if it is the picture that is wanted now.
    function ready(image) {
        if (String(image.source) === String(win.wanted))
            win.firstOnTop = image === first
    }

    Image {
        id: first
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        autoTransform: true
        sourceSize.width: win.width * (win.screen ? win.screen.devicePixelRatio : 1)
        sourceSize.height: win.height * (win.screen ? win.screen.devicePixelRatio : 1)
        opacity: win.firstOnTop ? 1 : 0
        onStatusChanged: if (status === Image.Ready) win.ready(first)
        Behavior on opacity { NumberAnimation { duration: win.fadeMs; easing.type: Easing.InOutQuad } }
    }

    Image {
        id: second
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        autoTransform: true
        sourceSize.width: win.width * (win.screen ? win.screen.devicePixelRatio : 1)
        sourceSize.height: win.height * (win.screen ? win.screen.devicePixelRatio : 1)
        opacity: win.firstOnTop ? 0 : 1
        onStatusChanged: if (status === Image.Ready) win.ready(second)
        Behavior on opacity { NumberAnimation { duration: win.fadeMs; easing.type: Easing.InOutQuad } }
    }
}
