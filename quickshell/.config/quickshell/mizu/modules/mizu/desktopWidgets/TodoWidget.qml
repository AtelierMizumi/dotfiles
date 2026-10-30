import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
// The desktop To-Do widget: a card that sits on the desktop, under your windows, over the wallpaper.
//
//   Moving it: it can be dragged (anywhere that isn't a button or a task's checkbox) only while the desktop is
//   unlocked (EditMode.desktopDragAllowed; `qs -c mizu ipc call widgets unlock`).
//
//   double-click a task's text, or the pencil, to edit it; Enter saves,
//   Esc cancels (the row's buttons are hidden while you type). Tick the box
//   to check a task off; the bin deletes it.
//   hover a task and drag its grip (the dots at the right end) up or down
//   to put the list in the order you want; the order is remembered.
//
// State (tasks, position) lives in services/TodoService.qml and is remembered across restarts.
//
// How the moving works: this is ONE full-screen, transparent window on WlrLayer.Background (mapped after the
// wallpaper, so over it, below every window), with the card as an Item inside it. Dragging just moves that Item,
// so it stays smooth. The window's input `mask` is only the card, so every click anywhere else on the desktop
// passes straight through to whatever is underneath. Keyboard focus is OnDemand only while the pointer is on the
// card (KeysOnPoint): clicking the card lets you type into it, and clicking a real window hands the keyboard back.
//
// Bind a key / call it from a script:
//   qs -c mizu ipc call todo toggle        (show / hide)
//   qs -c mizu ipc call todo resetPosition (if it ever ends up off-screen)
PanelWindow {
    id: win

    readonly property var mt: Theme.of(screen)

    function resetPosition(): void {
        TodoService.posX = -1;
        TodoService.posY = -1;
        win.place();
        TodoService.setPosition(card.x, card.y, win.uiScale);
    }
    // Which monitor it lives on, by name, e.g. "DP-1".
    // Empty = the monitor chosen for the To-Do (DesktopMonitors.qml).
    property string monitor: ""

    readonly property int cardWidth: 320
    // Past this many pixels of tasks the list scrolls instead of growing.
    readonly property int maxListHeight: 340

    // The 2 x 2 size (TodoService.size): the footprint the clock and the weather card share, 320 x 276 with the
    // housing. The card keeps every part it has; the list is just a fixed window that scrolls, so the card never
    // grows or shrinks with the tasks. Everything else on the card has a fixed height, so the content comes to 238:
    //   header 36 + rule 2 + list + add box 40, with 10 between the four = 108 + list.
    // ("clear done" moves up into the header: a fifth row would not fit.)
    readonly property bool small: TodoService.small
    readonly property int smallContentH: 238
    readonly property int smallListH: win.smallContentH - 108

    // `monitor` when it is set (a copy), else the monitor chosen for the To-Do (DesktopMonitors.homeFor).
    // By name, so a reboot cannot swap them.
    readonly property string wantedScreen: win.monitor !== "" ? win.monitor : DesktopMonitors.homeFor("todo")

    screen: Quickshell.screens.find(s => s.name === win.wantedScreen) ?? DesktopMonitors.fallbackScreen

    // This monitor's scale (services/ShellScale.qml). The card is drawn in design pixels inside a ScaleHost, so
    // `roomW` x `roomH` is the screen as the card sees it (real size / scale); positions are kept in that same
    // design space.
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real fullW: win.screen ? win.screen.width : 0
    readonly property real fullH: win.screen ? win.screen.height : 0
    readonly property real roomW: win.fullW / win.uiScale
    readonly property real roomH: win.fullH / win.uiScale

    // On / off: the card pops in with a little overshoot and is swallowed (straight shrink, nothing before it) on
    // the way out, instead of fading. The window stays up until the swallow has finished.
    //
    // Two fixed animations, started from onWantChanged. (A Behavior whose easing is picked by a binding on the
    // same flag can start with the PREVIOUS direction's easing, which is what made the way out misbehave.)
    FocusGate {
        id: gate
        widgetId: "todo"
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: TodoService.shown && TodoService.loaded
    readonly property bool want: win.switchedOn && gate.show
    property real reveal: 0

    // Off while the saved state is read back, so a reload doesn't replay the pop.
    property bool armed: false

    onWantChanged: {
        if (!win.armed) {
            popIn.stop()
            swallow.stop()
            win.reveal = win.want ? 1 : 0
        } else if (win.want) {
            swallow.stop()
            popIn.restart()
        } else {
            popIn.stop()
            swallow.restart()
        }
    }

    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    NumberAnimation {
        id: swallow
        target: win
        property: "reveal"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
    }

    Timer {
        interval: 800
        running: TodoService.loaded
        onTriggered: win.armed = true
    }

    property bool placed: false

    // `live`: the card is on, or still being swallowed.
    readonly property bool live: win.want || win.reveal > 0.001

    // Not mapped while the widget is off: a full-screen transparent layer that is only sitting there still costs
    // the compositor a blend on every frame.
    visible: TodoService.loaded && win.live

    // The widgets rest on Background (mapped after the wallpaper, so over it), under every window.
    WlrLayershell.layer: WallpaperService.covered(win.screen ? win.screen.name : "") ? WlrLayer.Bottom : WlrLayer.Background
    WlrLayershell.namespace: "mizu-todo"
    WlrLayershell.keyboardFocus: keys.wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Only the card takes clicks; the rest of the screen falls through. (In real window pixels, so it is the
    // card's design rectangle times the scale.)
    mask: Region { item: cardMask }

    Item {
        id: cardMask
        readonly property real k: win.uiScale
        x: !win.live ? 0 : Math.max(0, Math.round(card.x * k))
        y: !win.live ? 0 : Math.max(0, Math.round(card.y * k))
        width: !win.live ? 1 : Math.max(0, Math.ceil((card.x + card.width) * k) - x)
        height: !win.live ? 1 : Math.max(0, Math.ceil((card.y + card.height) * k) - y)
    }

    // ===== placement =====
    function place() {
        if (win.roomW <= 0 || win.roomH <= 0)
            return
        let x = TodoService.posX
        let y = TodoService.posY
        if (x < 0 || y < 0) {
            x = win.roomW - card.width - 40
            y = 96
        } else if (TodoService.posScale > 0 && win.uiScale > 0) {
            // Saved at another shell scale: same spot on the screen, not the same design pixels (the card keeps
            // its top-left corner).
            const k = TodoService.posScale / win.uiScale
            x *= k
            y *= k
        }
        card.x = Math.max(0, Math.min(x, win.roomW - card.width))
        card.y = Math.max(0, Math.min(y, win.roomH - card.height))
        win.placed = true
    }

    // After a reload the window, the monitor list and the scale all settle over a few frames; place again once
    // they have, so the card always ends on its saved spot (never while it is being dragged). Same as the clock.
    Timer {
        id: settle
        interval: 300
        onTriggered: {
            // A position saved before the scale was kept with it: it was in design pixels of the scale in use now
            // (nothing has changed it since), so keep that from here on.
            if (TodoService.loaded && TodoService.posX >= 0 && TodoService.posScale <= 0 && !dragArea.drag.active) {
                TodoService.posScale = win.uiScale
                TodoService.persist()
            }
            if (!dragArea.drag.active)
                win.place()
        }
    }

    // place() runs one turn of the event loop later (Qt.callLater), not inside the window's own size change.
    onWidthChanged: { Qt.callLater(win.place); settle.restart() }
    onHeightChanged: { Qt.callLater(win.place); settle.restart() }
    onUiScaleChanged: { win.place(); settle.restart() }
    onScreenChanged: { win.place(); settle.restart() }
    onVisibleChanged: settle.restart()
    Component.onCompleted: {
        win.reveal = win.want ? 1 : 0
        win.place()
    }

    Connections {
        target: TodoService
        function onLoadedChanged() {
            win.place()
            settle.restart()
        }
        // The spot arrives as several properties one after the other (x, y, scale): wait a beat and place once.
        function onPosXChanged() { follow.restart() }
        function onPosYChanged() { follow.restart() }
        function onPosScaleChanged() { follow.restart() }
    }

    Timer {
        id: follow
        interval: 16
        onTriggered: {
            if (!dragArea.drag.active)
                win.place()
        }
    }

    // A small square button: transparent until hovered.
    component IconBtn: Rectangle {
        id: btn

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property string icon: ""
        property color hoverColor: mt.accentMint
        signal clicked()

        width: 26
        height: 26
        radius: 9
        color: btnArea.containsMouse ? btn.hoverColor : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        MaterialIcon {
            color: btnArea.containsMouse ? mt.accentInk : mt.pInk
            anchors.centerIn: parent
            name: btn.icon
            size: 18
            weight: 600
        }

        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    ScaleHost {
        anchors.fill: parent
        factor: win.uiScale

        Item {
            id: card

            // Where the content starts: the pill's own border + ring, plus room.
            readonly property int inset: mt.borderWidth + mt.outerRingWidth + 10

            width: win.cardWidth
            height: col.implicitHeight + card.inset * 2 + mt.shadowOffset

            // Drop-and-settle bounce (kept for anything that wants to nudge the card).
            property real bump: 1
            scale: card.bump * Math.max(0, win.reveal)
            transformOrigin: Item.Center

            // Growing (a new task) shouldn't push the bottom off-screen. This works from the SAVED spot each time
            // (place() clamps it), instead of moving the card for good: while the shell starts or reloads the
            // card's height jumps around, and a permanent nudge upwards is how it used to lose its place. When it
            // gets shorter again it goes back. (Not while it is being dragged: then the drag owns the position.)
            onWidthChanged: {
                if (!dragArea.drag.active)
                    win.place()
            }

            onHeightChanged: {
                if (!dragArea.drag.active) {
                    win.place()
                    settle.restart()
                }
            }

            // The housing: the same outline / pale ring / fill / hard shadow as the bar.
            Pill {
                anchors.fill: parent
                cornerRadius: mt.radiusOuter
                ringWidth: mt.borderWidth + mt.outerRingWidth
                ringColorTop: mt.pSurfaceRing
                ringColorBottom: ringColorTop
                fillColor: mt.pSurface
            }

            // Left button: drag the card while the desktop is unlocked (EditMode.desktopDragAllowed). Sits under
            // the content, so buttons and the checkboxes win their own clicks and everything else on the card is
            // "grab here".
            MouseArea {
                id: dragArea
                z: 1
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: EditMode.desktopDragAllowed
                    ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                drag.target: EditMode.desktopDragAllowed ? card : null
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: Math.max(0, win.roomW - card.width)
                drag.minimumY: 0
                drag.maximumY: Math.max(0, win.roomH - card.height)

                // Clicking the card itself takes the cursor out of any text box.
                onPressed: card.forceActiveFocus()

                // Remember the new spot when a drag ends (also when it is cut short). A plain click doesn't save
                // anything, so a card that is squeezed onto a small screen for a moment can't overwrite where you
                // put it.
                drag.onActiveChanged: {
                    if (!drag.active)
                        TodoService.setPosition(card.x, card.y, win.uiScale)
                }
            }

            Column {
                id: col
                z: 2
                x: card.inset
                y: card.inset
                width: card.width - card.inset * 2
                spacing: 10

                // ===== header =====
                Item {
                    width: col.width
                    height: 36

                    Rectangle {
                        id: tile
                        width: 36
                        height: 36
                        radius: 11
                        border.width: mt.borderWidth
                        border.color: mt.pLine
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: mt.accentMint }
                            GradientStop { position: 1.0; color: mt.accentCyan }
                        }

                        MaterialIcon {
                            color: mt.accentInk
                            anchors.centerIn: parent
                            name: "checklist"
                            size: 22
                            weight: 600
                        }
                    }

                    Column {
                        anchors.left: tile.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: "To-Do"
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }

                        Text {
                            text: TodoService.total === 0 ? "nothing yet"
                                : TodoService.doneCount === TodoService.total ? "all done!"
                                : (TodoService.total - TodoService.doneCount) + " left"
                            color: mt.pInkSub
                            font.family: mt.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    // 2 x 2 only: the footer row is gone, so "clear done" lives up here.
                    Rectangle {
                        visible: win.small && TodoService.doneCount > 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearTextSmall.implicitWidth + 22
                        height: 26
                        radius: 13
                        border.width: 2
                        border.color: mt.pLine
                        color: clearAreaSmall.containsMouse ? mt.danger : mt.pSurface

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            id: clearTextSmall
                            anchors.centerIn: parent
                            text: "clear done (" + TodoService.doneCount + ")"
                            color: clearAreaSmall.containsMouse ? mt.accentInk : mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }

                        MouseArea {
                            id: clearAreaSmall
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TodoService.clearDone()
                        }
                    }
                }

                Rectangle {
                    width: col.width
                    height: 2
                    radius: 1
                    color: mt.pSurfaceDivider
                }

                // ===== empty state =====
                Text {
                    visible: TodoService.total === 0
                    width: col.width
                    height: win.small ? win.smallListH : 44
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "add your first task below"
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // ===== the list =====
                Item {
                    id: listBox
                    visible: TodoService.total > 0
                    width: col.width
                    height: win.small ? win.smallListH : Math.min(list.contentHeight, win.maxListHeight)

                    Behavior on height {
                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    WheelScroll { scroller: list }
                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: 4
                        model: TodoService.items
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        // Keep every row instantiated, so the drag can always
                        // measure the rows and a scrolled-away row never loses
                        // the mouse grab half-way through a drag.
                        cacheBuffer: 4000

                        // ===== drag to reorder =====
                        property int dragFrom: -1        // index of the held row (follows it as it moves); -1 = not dragging
                        property string dragTitle: ""
                        property bool dragDone: false
                        property real dragHeight: 36
                        property real dragGrab: 0        // mouse's distance below the top of the held row
                        property real pointerY: 0        // mouse, in listBox coordinates
                        property real scrollCarry: 0     // sub-pixel leftover of the edge auto-scroll
                        readonly property bool dragging: dragFrom >= 0

                        // How far (px) the held task must go past a neighbour's middle
                        // before they swap. Together with the gap between rows this is
                        // the dead zone that stops the tasks flickering back and forth
                        // when the mouse rests right on a boundary.
                        readonly property real swapMargin: 3

                        // Top of the floating copy, kept inside the list's box.
                        readonly property real ghostTop:
                            Math.max(0, Math.min(pointerY - dragGrab, listBox.height - dragHeight))

                        function beginDrag(index, title, done, h, grab, py) {
                            list.dragTitle = title
                            list.dragDone = done
                            list.dragHeight = h
                            list.dragGrab = grab
                            list.pointerY = py
                            list.scrollCarry = 0
                            list.dragFrom = index
                        }

                        function moveDrag(py) {
                            list.pointerY = py
                            list.retarget()
                        }

                        function endDrag() {
                            if (list.dragFrom < 0)
                                return
                            list.dragFrom = -1
                            // The order is only written to disk once you let go, not
                            // on every hop (saving spawns a process; doing that
                            // mid-drag is a hitch whenever you pause over a row).
                            TodoService.commitOrder()
                        }

                        // Move the held task past a neighbour once the copy's LEADING
                        // edge (bottom edge going down, top edge going up) is past that
                        // neighbour's middle.
                        //
                        // The old rule ("whichever slot the copy's centre is over") broke
                        // as soon as tasks had different heights (a wrapped, two-line
                        // task next to a one-line one): after a swap the slot moved
                        // out from under the copy's centre, so the very next update
                        // swapped it straight back, and so on every frame. That was the
                        // shaking at specific spots. Here, after a swap the rule for
                        // swapping back is strictly harder to meet than the rule that
                        // just fired, whatever the heights, so it settles.
                        //
                        // All the geometry comes from the rows' own heights (not where
                        // they happen to be mid-animation), and several rows can be
                        // crossed in one call when the mouse is fast. The model is
                        // moved once, at the end.
                        function retarget() {
                            if (list.dragFrom < 0)
                                return
                            // Apply the previous hop first, so itemAtIndex() matches the model.
                            list.forceLayout()
                            const n = list.count
                            const hs = []
                            for (let i = 0; i < n; i++) {
                                const it = list.itemAtIndex(i)
                                if (!it)
                                    return
                                hs.push(it.height)
                            }
                            const sp = list.spacing
                            const m = list.swapMargin
                            const gTop = (list.contentY - list.originY) + list.ghostTop
                            const gBottom = gTop + list.dragHeight

                            let at = list.dragFrom
                            let top = 0                      // top of the held task's slot
                            for (let i = 0; i < at; i++)
                                top += hs[i] + sp

                            for (let guard = 0; guard < n; guard++) {
                                if (at < n - 1 && gBottom > top + hs[at] + sp + hs[at + 1] / 2 + m) {
                                    const nb = hs[at + 1]
                                    top += nb + sp
                                    hs[at + 1] = hs[at]
                                    hs[at] = nb
                                    at++
                                } else if (at > 0 && gTop < top - sp - hs[at - 1] / 2 - m) {
                                    const nb = hs[at - 1]
                                    top -= nb + sp
                                    hs[at - 1] = hs[at]
                                    hs[at] = nb
                                    at--
                                } else {
                                    break
                                }
                            }

                            if (at !== list.dragFrom && TodoService.move(list.dragFrom, at))
                                list.dragFrom = at
                        }

                        // A long list scrolls while you hold a task near its top or bottom
                        // edge. Driven by the frame clock and real elapsed time (a 16 ms
                        // Timer drifts against the screen's refresh, which made the
                        // scrolling, and the swaps it triggers, stutter), in whole pixels
                        // so the text isn't drawn on half-pixels while it moves.
                        FrameAnimation {
                            running: list.dragging && list.contentHeight > list.height
                            onTriggered: {
                                const edge = 30
                                const p = list.pointerY
                                let f = 0
                                if (p < edge)
                                    f = -(edge - p) / edge
                                else if (p > listBox.height - edge)
                                    f = (p - (listBox.height - edge)) / edge
                                f = Math.max(-1, Math.min(1, f))
                                if (f === 0) {
                                    list.scrollCarry = 0
                                    return
                                }
                                // Gentle just inside the edge, full speed (~560 px/s) at it.
                                const dt = Math.min(frameTime, 0.05)
                                list.scrollCarry += 560 * f * Math.abs(f) * dt
                                const step = Math.trunc(list.scrollCarry)
                                if (step === 0)
                                    return
                                list.scrollCarry -= step
                                const maxY = list.contentHeight - list.height - list.originY
                                const next = Math.max(list.originY, Math.min(maxY, list.contentY + step))
                                if (next !== list.contentY) {
                                    list.contentY = next
                                    list.retarget()
                                }
                            }
                        }

                        add: Transition {
                            NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        }
                        remove: Transition {
                            NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                        }
                        displaced: Transition {
                            NumberAnimation { property: "y"; duration: 160; easing.type: Easing.OutCubic }
                        }
                        move: Transition {
                            NumberAnimation { property: "y"; duration: 160; easing.type: Easing.OutCubic }
                        }

                        delegate: Item {
                            id: row

                            required property int index
                            required property string title
                            required property bool done

                            property bool editing: false
                            readonly property real textHeight: row.editing ? editor.implicitHeight : label.implicitHeight

                            width: ListView.view ? ListView.view.width : 0
                            height: Math.max(36, row.textHeight + 14)

                            function beginEdit() {
                                row.editing = true
                                editor.text = row.title
                                editor.forceActiveFocus()
                                editor.selectAll()
                            }

                            function commit() {
                                if (!row.editing)
                                    return
                                row.editing = false
                                const t = editor.text.trim()
                                if (t !== "" && t !== row.title)
                                    TodoService.edit(row.index, t)
                            }

                            function cancel() {
                                row.editing = false
                            }

                            HoverHandler {
                                id: hover
                            }

                            // Rows the mouse sweeps over mid-drag shouldn't light up and
                            // sprout buttons: that fading is what looked like flicker.
                            readonly property bool hot: hover.hovered && !list.dragging

                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: mt.pSurfaceHover
                                opacity: row.hot || row.editing ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 120 }
                                }
                            }

                            // While this row is being dragged it shows as an empty slot;
                            // the floating copy (`ghost`) is what you're holding.
                            Rectangle {
                                z: 10
                                anchors.fill: parent
                                radius: 10
                                visible: list.dragFrom === row.index
                                color: mt.pSurfaceHover
                                border.width: 2
                                border.color: mt.pLine
                            }

                            // The checkbox: navy outline, mint-to-cyan when ticked.
                            Rectangle {
                                id: box
                                x: 8
                                y: 7
                                width: 22
                                height: 22
                                radius: 7
                                color: mt.pSurface
                                border.width: 2.5
                                border.color: mt.pLine

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: box.border.width
                                    radius: box.radius - box.border.width
                                    opacity: row.done ? 1 : 0
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: mt.accentMint }
                                        GradientStop { position: 1.0; color: mt.accentCyan }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }
                                }

                                MaterialIcon {
                                    color: mt.accentInk
                                    anchors.centerIn: parent
                                    name: "check"
                                    size: 16
                                    weight: 700
                                    scale: row.done ? 1 : 0

                                    Behavior on scale {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: TodoService.toggle(row.index)
                                }
                            }

                            // The task text. Double-click to edit; the TapHandler only
                            // listens, so a left-drag starting on the text still moves
                            // the card.
                            Text {
                                id: label
                                x: 40
                                y: Math.round((row.height - label.implicitHeight) / 2)
                                width: row.width - 40 - 10
                                visible: !row.editing
                                text: row.title
                                wrapMode: Text.Wrap
                                color: row.done ? mt.pInkSub : mt.pInk
                                font.family: mt.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                font.strikeout: row.done

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onDoubleTapped: row.beginEdit()
                                }
                            }

                            TextInput {
                                id: editor
                                x: 40
                                y: Math.round((row.height - editor.implicitHeight) / 2)
                                width: row.width - 40 - 10
                                visible: row.editing
                                wrapMode: TextInput.Wrap
                                selectByMouse: true
                                color: mt.pInk
                                selectionColor: mt.accentCyan
                                selectedTextColor: mt.colBorder
                                font.family: mt.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.DemiBold

                                onAccepted: row.commit()
                                Keys.onEscapePressed: row.cancel()
                                onActiveFocusChanged: {
                                    if (!editor.activeFocus && row.editing)
                                        row.commit()
                                }
                            }

                            // Underline while editing.
                            Rectangle {
                                visible: row.editing
                                x: 40
                                y: editor.y + editor.height + 1
                                width: editor.width
                                height: 2
                                radius: 1
                                color: mt.accentCyan
                            }

                            // Grip / edit / delete, floating over the right end of the row on hover
                            // (not while it is being edited).
                            Rectangle {
                                id: actions
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                y: 5
                                width: actionRow.width + 4
                                height: 26
                                radius: 10
                                color: mt.pSurfaceHover
                                // Hidden while the text is being edited (no bin, no grip,
                                // no pencil there): Enter saves and Esc cancels.
                                opacity: !row.editing && (row.hot || list.dragFrom === row.index) ? 1 : 0
                                visible: opacity > 0.01

                                Behavior on opacity {
                                    NumberAnimation { duration: 120 }
                                }

                                Row {
                                    id: actionRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    // The grip: hold it and drag up / down to reorder.
                                    // It takes the mouse itself, so a drag here never
                                    // moves the card.
                                    Rectangle {
                                        id: grip
                                        width: 26
                                        height: 26
                                        radius: 9
                                        color: gripArea.containsMouse || gripArea.pressed ? mt.accentCyan : "transparent"

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        MaterialIcon {
                                            color: gripArea.containsMouse || gripArea.pressed ? mt.accentInk : mt.pInk
                                            anchors.centerIn: parent
                                            name: "drag_indicator"
                                            size: 18
                                            weight: 600
                                        }

                                        MouseArea {
                                            id: gripArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton
                                            preventStealing: true
                                            cursorShape: Qt.SizeVerCursor

                                            onPressed: mouse => {
                                                const p = gripArea.mapToItem(listBox, mouse.x, mouse.y)
                                                const top = row.mapToItem(listBox, 0, 0).y
                                                list.beginDrag(row.index, row.title, row.done, row.height, p.y - top, p.y)
                                            }
                                            onPositionChanged: mouse => {
                                                if (gripArea.pressed)
                                                    list.moveDrag(gripArea.mapToItem(listBox, mouse.x, mouse.y).y)
                                            }
                                            onReleased: list.endDrag()
                                            onCanceled: list.endDrag()
                                        }
                                    }

                                    IconBtn {
                                        icon: "edit"
                                        hoverColor: mt.accentMint
                                        onClicked: row.beginEdit()
                                    }

                                    IconBtn {
                                        icon: "delete"
                                        hoverColor: mt.danger
                                        onClicked: TodoService.remove(row.index)
                                    }
                                }
                            }
                        }
                    }

                    // Slim scroll indicator, only when the list overflows.
                    Rectangle {
                        visible: list.contentHeight > list.height
                        x: listBox.width - width
                        y: list.visibleArea.yPosition * listBox.height
                        width: 4
                        height: Math.max(20, list.visibleArea.heightRatio * listBox.height)
                        radius: 2
                        color: mt.pLine
                        opacity: 0.35
                    }

                    // The copy of the held task that follows the mouse: same
                    // navy outline and hard shadow as the card itself.
                    Item {
                        id: ghost
                        visible: list.dragging
                        z: 5
                        width: listBox.width
                        height: list.dragHeight
                        y: list.ghostTop

                        Rectangle {
                            x: 3
                            y: 3
                            width: parent.width
                            height: parent.height
                            radius: 10
                            color: mt.pLineShadow
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: mt.pSurface
                            border.width: 2.5
                            border.color: mt.pLine
                        }

                        Rectangle {
                            id: ghostBox
                            x: 8
                            y: 7
                            width: 22
                            height: 22
                            radius: 7
                            color: mt.pSurface
                            border.width: 2.5
                            border.color: mt.pLine

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: ghostBox.border.width
                                radius: ghostBox.radius - ghostBox.border.width
                                visible: list.dragDone
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: mt.accentMint }
                                    GradientStop { position: 1.0; color: mt.accentCyan }
                                }
                            }

                            MaterialIcon {
                                visible: list.dragDone
                                color: mt.accentInk
                                anchors.centerIn: parent
                                name: "check"
                                size: 16
                                weight: 700
                            }
                        }

                        Text {
                            x: 40
                            y: Math.round((ghost.height - implicitHeight) / 2)
                            width: ghost.width - 40 - 10   // same as a row's label, so it wraps the same
                            text: list.dragTitle
                            wrapMode: Text.Wrap
                            color: list.dragDone ? mt.pInkSub : mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            font.strikeout: list.dragDone
                        }

                        // The grip, on a small backing so it never sits on top of text.
                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            y: 5
                            width: 26
                            height: 26
                            radius: 9
                            color: mt.pSurface

                            MaterialIcon {
                                anchors.centerIn: parent
                                color: mt.pInk
                                name: "drag_indicator"
                                size: 18
                                weight: 600
                            }
                        }
                    }
                }

                // ===== add a task =====
                Rectangle {
                    id: addBox
                    width: col.width
                    height: 40
                    radius: 12
                    color: addInput.activeFocus ? mt.pSurface : mt.pSurfaceHover
                    border.width: 2.5
                    border.color: mt.pLine

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    // Click anywhere in the box to start typing.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.IBeamCursor
                        onPressed: addInput.forceActiveFocus()
                    }

                    TextInput {
                        id: addInput
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: addBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true
                        selectByMouse: true
                        color: mt.pInk
                        selectionColor: mt.accentCyan
                        selectedTextColor: mt.colBorder
                        font.family: mt.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold

                        onAccepted: addBtn.submit()
                        Keys.onEscapePressed: {
                            addInput.text = ""
                            card.forceActiveFocus()
                        }

                        Text {
                            visible: addInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "add a task…"
                            color: mt.pInkSub
                            font: addInput.font
                        }
                    }

                    Rectangle {
                        id: addBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 30
                        radius: 9
                        border.width: 2.5
                        border.color: mt.pLine
                        scale: addArea.pressed ? 0.9 : 1
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: mt.accentMint }
                            GradientStop { position: 1.0; color: mt.accentCyan }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 90 }
                        }

                        function submit() {
                            if (TodoService.add(addInput.text)) {
                                addInput.text = ""
                                // The list grows on the next layout pass.
                                Qt.callLater(() => list.positionViewAtEnd())
                            }
                        }

                        MaterialIcon {
                            color: mt.accentInk
                            anchors.centerIn: parent
                            name: "add"
                            size: 20
                            weight: 700
                        }

                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: addBtn.submit()
                        }
                    }
                }

                // ===== footer =====
                Item {
                    visible: TodoService.doneCount > 0 && !win.small
                    width: col.width
                    height: 26

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: clearText.implicitWidth + 22
                        height: 26
                        radius: 13
                        border.width: 2
                        border.color: mt.pLine
                        color: clearArea.containsMouse ? mt.danger : mt.pSurface

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            id: clearText
                            anchors.centerIn: parent
                            text: "clear done (" + TodoService.doneCount + ")"
                            color: clearArea.containsMouse ? mt.accentInk : mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TodoService.clearDone()
                        }
                    }
                }
            }
        }
    }

    // Asks for the keyboard only under the pointer or while typing: a window that is OnDemand all the time takes
    // the keyboard as it maps.
    KeysOnPoint {
        id: keys
    }
}
