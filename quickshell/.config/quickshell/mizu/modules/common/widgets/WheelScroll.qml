import QtQuick
import Quickshell
import qs.modules.common

// One mouse-wheel feel for every scrolling list in the shell (the phone's
// notifications, Settings, the launcher's clipboard, the Quick Panel dialogs...).
// Put it next to the Flickable / ListView / GridView (same parent) and point
// `scroller` at it:
//
//   WheelScroll { scroller: list }
//   ListView { id: list ... }
//
// A mouse notch moves `Theme.wheelStep` px (a bit more than Qt's own, which is
// small and differs from one list to the next); a touchpad moves 1:1 with the
// fingers (both through Theme.wheelPx). It only takes wheel events, so clicks and
// drags go through to the list as before. `orientation: Qt.Horizontal` is for a
// row that scrolls sideways. It is hidden / disabled whenever the list is, so a
// list that is faded out or switched off does not keep eating the wheel.
//
// `smooth: true` makes each mouse notch glide to its target instead of jumping
// (touchpads stay 1:1 either way). Off by default, so other lists are unchanged.
Item {
    id: root

    property Flickable scroller: null
    property real step: Theme.wheelStep
    property real pixelFactor: 1
    property int orientation: Qt.Vertical
    // Opt-in: mouse notches glide to their target instead of jumping.
    property bool smooth: false
    property int smoothDuration: 220
    // True while a glide is running (lists can use it, e.g. to pause hover effects).
    readonly property bool gliding: glide.running

    // Stops a glide in progress (for code that moves the list itself).
    function cancel() {
        glide.stop()
    }

    anchors.fill: scroller
    z: 50
    visible: root.scroller ? root.scroller.visible : true
    enabled: root.scroller ? root.scroller.enabled : true

    NumberAnimation {
        id: glide

        target: root.scroller
        property: root.orientation === Qt.Horizontal ? "contentX" : "contentY"
        duration: root.smoothDuration
        easing.type: Easing.OutCubic
    }

    // Grabbing or flicking the list takes over from a glide.
    Connections {
        target: root.scroller

        function onMovementStarted() {
            glide.stop()
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const f = root.scroller
            if (!f)
                return
                const sideways = root.orientation === Qt.Horizontal
                // `step` rescales a mouse notch when an instance asks for a different
                // size; a touchpad (pixelDelta) follows the fingers, times `pixelFactor`.
                const px = event.pixelDelta.y !== 0 || (sideways && event.pixelDelta.x !== 0)
                const d = Theme.wheelPx(event, sideways)
                * (px ? root.pixelFactor : root.step / Theme.wheelStep)
                if (d === 0)
                    return

                    // The same range a drag can reach: the list's own top / bottom
                    // margin is scroll room too (the phone's notification list keeps
                    // a big bottomMargin so its last card can come up clear of the
                    // screen edge). Clamping to the bare content left the wheel
                    // stopping short while a left-click drag went on further.
                    const lo = sideways ? f.originX - f.leftMargin : f.originY - f.topMargin
                    const hi = sideways
                    ? Math.max(lo, f.originX + f.contentWidth - f.width + f.rightMargin)
                    : Math.max(lo, f.originY + f.contentHeight - f.height + f.bottomMargin)
                    if (hi <= lo)
                        return
                        const cur = sideways ? f.contentX : f.contentY
                        f.cancelFlick()

                        if (root.smooth && !px) {
                            // Notches that arrive mid-glide extend the target, so fast
                            // spinning stays fluid instead of restarting each time.
                            const base = glide.running ? glide.to : cur
                            glide.stop()
                            glide.from = cur
                            glide.to = Math.max(lo, Math.min(hi, base - d))
                            glide.start()
                        } else {
                            glide.stop()
                            const v = Math.max(lo, Math.min(hi, cur - d))
                            if (sideways)
                                f.contentX = v
                                else
                                    f.contentY = v
                        }
        }
    }
}
