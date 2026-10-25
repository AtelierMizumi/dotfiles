import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

// "Click anywhere else closes the popup" for the bar's popups (PopupFrame, TrayPopups). niri has no focus-grab
// protocol, so this is a Catcher (modules/common/Catcher.qml): a transparent window over the whole screen. Its input
// region leaves the bar's own strip out, so the bar's buttons still work (a click on another button swaps the popup).
// It is mapped a beat after `wanted` turns true, so the click that opened the popup does not close it at once.
//
//   BarCatcher { parentWindow: bar; wanted: popup.visible; onDismissed: close() }
Scope {
    id: root

    // The bar's PanelWindow.
    property var parentWindow: null
    property bool wanted: false

    signal dismissed()

    onWantedChanged: {
        if (wanted)
            delay.restart()
        else {
            delay.stop()
            catcher.open = false
        }
    }

    Timer {
        id: delay
        interval: 80
        onTriggered: catcher.open = root.wanted
    }

    // The bar's strip in screen pixels (the bar's window may be a few pixels bigger than the strip itself).
    readonly property string edge: root.parentWindow && root.parentWindow.barPosition ? root.parentWindow.barPosition : "top"
    readonly property real strip: root.parentWindow && root.parentWindow.stripSize ? root.parentWindow.stripSize : 0
    readonly property real screenW: root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.width : 0
    readonly property real screenH: root.parentWindow && root.parentWindow.screen ? root.parentWindow.screen.height : 0
    readonly property bool onSide: root.edge === "left" || root.edge === "right"

    Catcher {
        id: catcher
        screen: root.parentWindow ? root.parentWindow.screen : null
        layer: WlrLayer.Top
        onDismissed: root.dismissed()

        // The whole screen minus the bar's strip.
        mask: Region {
            x: 0
            y: 0
            width: root.screenW
            height: root.screenH
            regions: [
                Region {
                    intersection: Intersection.Subtract
                    x: root.edge === "right" ? root.screenW - root.strip : 0
                    y: root.edge === "bottom" ? root.screenH - root.strip : 0
                    width: root.onSide ? root.strip : root.screenW
                    height: root.onSide ? root.screenH : root.strip
                }
            ]
        }
    }
}
