import Quickshell
import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A small hover tag for a bar module: dark rounded label that opens towards
// the inside of the screen, whichever edge the bar is on.
//
//   BarTip { shown: area.containsMouse; text: "12 updates"; barPosition: "top" }
//
// Declare it as a child of the module (the module's own box is what it hangs
// off), exactly as before.
//
// The tag is its OWN small window (a PopupWindow), not a picture inside the bar's
// window. Why: the bar's window is only the strip plus ~24 px of room (Bar.qml
// `compactWindow`, kept small so the compositor does not re-composite the whole
// screen for every frame the bar draws), so anything drawn inside it that is
// wider or taller than that room was cut off at the window's edge. A popup is
// a separate surface: it can be any size and sit anywhere on screen, and the
// bar's window does not change at all. It is click-through (empty mask), so it
// never steals the hover from the pill under it.
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property bool shown: false
    // Bind to the module's MouseArea.pressed: the tag is for hovering only, so any press
    // (click, right-click, middle-click) puts it away, and it stays away until the pointer
    // has left the module and come back.
    property bool pressed: false
    property string text: ""
    property string barPosition: "top"

    readonly property Item host: parent

    // The bar's PanelWindow this module lives in (null until it is on screen).
    readonly property var barWindow: QsWindow.window
    readonly property real uiScale: root.barWindow && root.barWindow.uiScale ? root.barWindow.uiScale : 1

    // Gap between the module and the tag, in design pixels. (Bigger = the tag sits
    // further from the pill. It is empty room inside the tag's own window, so it
    // never needs the bar's window to be any bigger.)
    readonly property real gap: 10
    readonly property real gapPx: Math.round(root.gap * root.uiScale)
    readonly property bool facingVertical: root.barPosition === "left" || root.barPosition === "right"


    // `shown` comes from a MouseArea's containsMouse, and that can stay true after the
    // pointer has really left (a press that opens a popup moves the pointer to another
    // surface, and the bar never gets the hover-leave). The tag is its own window, so it
    // would then stay up. A passive HoverHandler over the module tells the truth, and the
    // tag needs both. Coming back brings it back.
    property bool dismissed: false

    onShownChanged: {
        if (!shown)
            root.dismissed = false    // a real leave: the next hover may show it again
    }

    onPressedChanged: {
        if (pressed)
            root.dismissed = true
    }

    Item {
        width: root.host ? root.host.width : 0
        height: root.host ? root.host.height : 0
        HoverHandler {
            id: pointer
            onHoveredChanged: {
                // Once the pointer has been seen outside the module, a press-dismissal is over too.
                if (!hovered)
                    root.dismissed = false
            }
        }
    }

    readonly property bool pointerOver: pointer.hovered

    // Fades in and out like before; the window is only mapped while it is visible.
    property real fade: shown && pointerOver && !dismissed && text !== "" ? 1 : 0
    Behavior on fade {
        NumberAnimation { duration: 120 }
    }

    // The module's box in the bar window's real pixels (mapToItem folds in the
    // ScaleHost scale). The tag is centred on the middle of the side that faces the
    // inside of the screen. `void root.shown` re-reads it each time the tag is about
    // to show, because the module can have moved since the last time.
    readonly property rect hostRect: {
        void root.shown
        void root.text
        if (!root.host)
            return Qt.rect(0, 0, 0, 0)
        const a = root.host.mapToItem(null, 0, 0)
        const b = root.host.mapToItem(null, root.host.width, root.host.height)
        return Qt.rect(Math.round(a.x), Math.round(a.y), Math.round(b.x - a.x), Math.round(b.y - a.y))
    }

    PopupWindow {
        id: popup
        visible: root.fade > 0.01 && root.barWindow !== null && root.text !== ""

        anchor.window: root.barWindow
        anchor.rect: root.hostRect
        // Centred on the module's side that faces the inside of the screen.
        anchor.edges: root.barPosition === "bottom" ? Edges.Top
                    : (root.barPosition === "left" ? Edges.Right
                    : (root.barPosition === "right" ? Edges.Left : Edges.Bottom))
        anchor.gravity: anchor.edges
        // Near a screen corner it slides along the edge instead of running off.
        anchor.adjustment: PopupAdjustment.Slide

        // The window is the label plus the gap, on the side that faces the pill.
        implicitWidth: Math.ceil((label.implicitWidth + 16) * root.uiScale) + (root.facingVertical ? root.gapPx : 0)
        implicitHeight: Math.ceil((label.implicitHeight + 10) * root.uiScale) + (root.facingVertical ? 0 : root.gapPx)
        color: "transparent"

        // Click-through: an empty region takes no input.
        mask: Region {}

        ScaleHost {
            anchors.fill: parent
            factor: root.uiScale
            opacity: root.fade

            Rectangle {
                // Pushed away from the pill by the gap (top bar: down; bottom bar: stays
                // at the top of the window; left bar: right; right bar: stays left).
                x: root.barPosition === "left" ? root.gap : 0
                y: root.barPosition === "top" ? root.gap : 0
                width: label.implicitWidth + 16
                height: label.implicitHeight + 10
                radius: 8
                color: mt.colBorder

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                    color: mt.textWhite
                    font.family: mt.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
