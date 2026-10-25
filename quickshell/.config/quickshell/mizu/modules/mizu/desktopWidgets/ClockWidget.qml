import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
// The desktop clock widget: it sits on the desktop, under your windows, over the wallpaper, and can be dragged
// while the desktop is unlocked (EditMode.desktopDragAllowed; `qs -c mizu ipc call widgets unlock`).
//
//   double-click  switch between 12h and 24h
//
// Two designs (ClockService.design), built from the same parts (keys, diamonds, the Pill's outline + ring + hard
// shadow):
//
//   0 KEYS     the card: a date sticker, four keycaps in a shallow V (hours chip colour, minutes accent
//              gradient), a beat of two diamonds between them, a second lane with a hopping playhead, the week.
//   1 STACK    no card: only the time, as big sticker numerals (outline, white ring, accent hours / minutes,
//              hard shadow) straight on the wallpaper, hours over minutes, the two beat diamonds between.
//
// In both a digit pops when it changes, the diamonds take turns once a second, and nothing animates endlessly
// (the card is idle between ticks). The two knobs for the attitude are `tilt` and `stagger` on the card below;
// set both to 0 for perfectly level rows.
//
// The date text is SettingsService "time.dateFormat" (a Qt date format such as "M月d日 ddd") when it is set, else
// the locale's own names. The hours are 24h by default (SettingsService "time.use24h").
//
// State (position, shown, 12h / 24h, design) lives in services/ClockService.qml and is remembered across restarts.
//
// How the moving works: ONE full-screen, transparent window on WlrLayer.Background, with the card as an Item
// inside it. Dragging just moves that Item, so it stays smooth, and the window's input `mask` is only the card, so
// every click anywhere else passes straight through to whatever is underneath. The clock never takes keyboard
// focus.
//
// Bind a key / call it from a script:
//   qs -c mizu ipc call clock toggle         (show / hide)
//   qs -c mizu ipc call clock toggleFormat   (12h <-> 24h)
//   qs -c mizu ipc call clock nextDesign     (Keys -> Stack)
//   qs -c mizu ipc call clock setDesign 1    (0 Keys, 1 Stack)
//   qs -c mizu ipc call clock resetPosition  (if it ever ends up off-screen)

PanelWindow {
    id: win

    readonly property var mt: Theme.of(screen)

    function resetPosition(): void {
        win.clearSpot();
        win.place();
        win.saveSpot(card.x, card.y);
    }

    // Which monitor it lives on, by name (e.g. "DP-1"). Empty = the monitor the card was last dropped on
    // (remembered in ClockService), or the default monitor if it has never been moved.
    property string monitor: ""

    // A copy on another monitor (WidgetClones.qml): the same widget, with a spot of its own. The main
    // copy keeps its spot in the service.
    property bool clone: false

    readonly property var cloneSpot: win.clone ? WidgetClones.spot("clock", win.wantedScreen) : null
    readonly property bool spotReady: win.clone ? (WidgetClones.loaded && win.cloneSpot !== null) : ClockService.loaded
    readonly property real spotX: win.clone ? (win.cloneSpot ? win.cloneSpot.x : -1) : ClockService.posX
    readonly property real spotY: win.clone ? (win.cloneSpot ? win.cloneSpot.y : -1) : ClockService.posY
    readonly property real spotScale: win.clone ? (win.cloneSpot ? win.cloneSpot.scale : 0) : ClockService.posScale

    function saveSpot(x, y): void {
        if (win.clone)
            WidgetClones.setSpot("clock", win.wantedScreen, x, y, win.uiScale)
        else
            ClockService.setPosition(x, y, win.screen ? win.screen.name : "", win.uiScale)
    }

    function clearSpot(): void {
        if (win.clone) {
            WidgetClones.clearSpot("clock", win.wantedScreen)
        } else {
            ClockService.posX = -1
            ClockService.posY = -1
        }
    }

    function fixSpotScale(): void {
        if (win.clone) {
            WidgetClones.setSpot("clock", win.wantedScreen, win.spotX, win.spotY, win.uiScale)
        } else {
            ClockService.posScale = win.uiScale
            ClockService.persist()
        }
    }

    readonly property string wantedScreen: win.monitor !== "" ? win.monitor : ClockService.screenName
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
        widgetId: "clock"
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: ClockService.shown && ClockService.loaded
    readonly property bool want: win.switchedOn && gate.show
    property real reveal: 0

    // Off while the saved state is read back, so a reload doesn't replay the pop.
    property bool armed: false

    // Stays false until the card has been put on its saved spot, and keeps it drawn at size 0 until then. After a
    // reload the window maps before the compositor has told it its real size, and a card placed (or clamped) in
    // that window sits at the top-left corner for a moment before it jumps to where it was saved. place() waits for
    // a believable window instead.
    property bool placed: false

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
        running: ClockService.loaded
        onTriggered: win.armed = true
    }

    // `live`: the card is on, or still being swallowed.
    readonly property bool live: win.want || win.reveal > 0.001

    // Not mapped while the widget is off: a full-screen transparent layer that is only sitting there still costs
    // the compositor a blend on every frame.
    visible: ClockService.loaded && win.live

    // The widgets rest on Background (mapped after the wallpaper, so over it), under every window.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "mizu-clock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
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
    mask: Region {
        item: cardMask
    }

    Item {
        id: cardMask
        readonly property real k: win.uiScale
        x: !win.live ? 0 : Math.max(0, Math.round(card.x * k))
        y: !win.live ? 0 : Math.max(0, Math.round(card.y * k))
        width: !win.live ? 1 : Math.max(0, Math.ceil((card.x + card.width) * k) - x)
        height: !win.live ? 1 : Math.max(0, Math.ceil((card.y + card.height) * k) - y)
    }

    // ===== the time =====
    SystemClock {
        id: clock
        enabled: win.live
        precision: SystemClock.Seconds
    }

    readonly property date now: clock.date
    readonly property int hours24: win.now.getHours()
    readonly property int mins: win.now.getMinutes()
    readonly property int secs: win.now.getSeconds()
    readonly property bool pm: win.hours24 >= 12
    readonly property int hoursShown: ClockService.use24h
        ? win.hours24
        : (win.hours24 % 12 === 0 ? 12 : win.hours24 % 12)

    function two(n) {
        return (n < 10 ? "0" : "") + n
    }

    readonly property string hh: win.two(win.hoursShown)
    readonly property string mm: win.two(win.mins)
    readonly property string ss: win.two(win.secs)

    // The date text: the user's Qt date format when there is one ("M月d日 ddd"), else the weekday name over
    // "month year" in the locale's own words.
    readonly property string dateFormat: String(SettingsService.get("time.dateFormat") ?? "")
    readonly property string dateTitle: win.dateFormat !== ""
        ? Qt.formatDate(win.now, win.dateFormat)
        : Qt.locale().dayName(win.now.getDay(), Locale.LongFormat)
    readonly property string dateSub: win.dateFormat !== "" ? "" : Qt.formatDate(win.now, "MMMM yyyy")

    // ===== placement =====
    function place(force) {
        if (win.roomW <= 0 || win.roomH <= 0)
            return
        // Not before the saved spot has been read, and not while the window is still smaller than the card (the
        // clamp below would put it at 0, 0).
        if (!force && (!ClockService.loaded || win.roomW < card.width || win.roomH < card.height))
            return
        let x = win.spotX
        let y = win.spotY
        if (x < 0 || y < 0) {
            x = win.roomW - card.width - 40
            y = (win.roomH - card.height) / 2
        } else if (win.spotScale > 0 && win.uiScale > 0) {
            // Saved at another shell scale: same spot on the screen, not the same design pixels (the card keeps
            // its top-left corner).
            const k = win.spotScale / win.uiScale
            x *= k
            y *= k
        }
        card.x = Math.max(0, Math.min(x, win.roomW - card.width))
        card.y = Math.max(0, Math.min(y, win.roomH - card.height))
        win.placed = true
    }

    // After a reload the window, the monitor list and the scale all settle over a few frames; place again once
    // they have, so the card always ends on its saved spot (never while it is being dragged).
    Timer {
        id: settle
        interval: 300
        onTriggered: {
            // A position saved before the scale was kept with it: it was in design pixels of the scale in use now
            // (nothing has changed it since), so keep that from here on.
            if (win.spotReady && win.spotX >= 0 && win.spotScale <= 0 && !dragArea.drag.active)
                win.fixSpotScale()
            if (!dragArea.drag.active)
                win.place(!win.placed && ClockService.loaded)
        }
    }

    // place() runs one turn of the event loop later (Qt.callLater, before the next frame, and several calls become
    // one): it changes card.x while the window's size is still being worked out.
    onWidthChanged: { Qt.callLater(win.place); settle.restart() }
    onHeightChanged: { Qt.callLater(win.place); settle.restart() }
    onUiScaleChanged: { win.place(); settle.restart() }
    onScreenChanged: { win.place(); settle.restart() }
    onVisibleChanged: settle.restart()
    Component.onCompleted: {
        win.reveal = win.want ? 1 : 0
        win.place()
    }

    // The spot of a copy changed (a drag, a reset): put the card there.
    Connections {
        target: WidgetClones
        enabled: win.clone
        function onSpotsChanged() { follow.restart() }
    }

    Connections {
        target: ClockService
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


    // ===== small parts shared by the designs =====

    component GlyphRing: Item {
        id: gr

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property string value: "0"
        property color ink: "black"
        property real radius: 5
        property real dx: 0
        property real dy: 0
        property int steps: 8

        Repeater {
            model: gr.steps

            Text {
                required property int index

                x: gr.dx + Math.cos(index * 2 * Math.PI / gr.steps) * gr.radius
                y: gr.dy + Math.sin(index * 2 * Math.PI / gr.steps) * gr.radius
                width: gr.width
                height: gr.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: gr.value
                color: gr.ink
                font.family: mt.fontFamily
                font.pixelSize: 84
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    component KeyTile: Item {
        id: kt
        property string digit: "0"
        property bool ghost: false
        property real tilt: 0
        property bool gradientFill: false

        width: 57
        height: 74
        rotation: kt.tilt

        Pill {
            anchors.fill: parent
            cornerRadius: 14
            ringWidth: 3
            fillColor: kt.ghost ? mt.surface : (kt.gradientFill ? mt.accentCyan : mt.accentMint)
            shadowDx: 2
            shadowDy: 3

            Text {
                anchors.centerIn: parent
                text: kt.digit
                color: kt.ghost ? mt.inkSub : mt.accentInk
                font.family: mt.fontFamily
                font.pixelSize: 38
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    // One sticker numeral, straight on the wallpaper: the navy outline and the
    // hard shadow in one (the shadow is the same outline moved down-right),
    // a white ring, then the colour. Pops when its digit changes.
    component StickerDigit: Item {
        id: sd

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property string value: "0"
        property color fillColor: mt.accentMint
        property bool ghost: false            // a leading 0 in 12h mode: pale grey fill, still fully solid
        property real tilt: 0
        property real pop: 1

        width: 56
        height: 96
        rotation: sd.tilt
        scale: sd.pop
        transformOrigin: Item.Center

        // (No `opacity` for the ghost: the numeral is many stacked copies of
        // the glyph, and fading each one lets the others show through, which
        // turns the outline muddy. A pale fill keeps every edge crisp.)
        onValueChanged: popAnim.restart()

        NumberAnimation {
            id: popAnim
            target: sd
            property: "pop"
            from: 0.82
            to: 1
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

        GlyphRing { anchors.fill: parent; value: sd.value; ink: mt.colBorder; radius: 6; dx: 3; dy: 4 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: mt.colBorder; radius: 6 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: "white"; radius: 3.2 }
        GlyphRing { anchors.fill: parent; value: sd.value; ink: sd.ghost ? mt.colOuterRing : sd.fillColor; radius: 0; steps: 1 }
    }

    // A diamond of the beat: lit on its turn, and it pops when it lights.
    component BeatDiamond: Rectangle {
        id: bd

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property bool lit: false
        property color litColor: mt.accentMint
        property color offColor: mt.pSurfaceDivider
        property color lineColor: mt.pLine
        property real pop: 1

        width: 12
        height: 12
        radius: 3
        rotation: 45
        scale: bd.pop
        color: bd.lit ? bd.litColor : bd.offColor
        border.width: 2
        border.color: bd.lineColor

        onLitChanged: {
            if (bd.lit)
                beatPop.restart()
        }

        NumberAnimation {
            id: beatPop
            target: bd
            property: "pop"
            from: 1.7
            to: 1
            duration: 360
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    // The tilted gradient sticker with today's date number.
    component DateSticker: Pill {
        id: ds

        property int day: 1

        width: 44
        height: 44
        cornerRadius: 13
        ringWidth: 3
        rotation: -5
        transformOrigin: Item.Center
        fillGradient: Gradient {
            GradientStop { position: 0.0; color: mt.accentMint }
            GradientStop { position: 1.0; color: mt.accentCyan }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: ds.day
            color: mt.accentInk
            font.family: mt.fontFamily
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // The AM / PM switch. In 12h mode the mint thumb sits under the current
    // half; in 24h mode it stretches over the whole track and reads "24H".
    component AmPmSwitch: Item {
        id: sw

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property bool full: false      // 24h
        property bool pm: false
        readonly property real half: (sw.width - 6) / 2

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: mt.pSurfaceHover
            border.width: mt.borderWidth
            border.color: mt.pLine
        }

        Rectangle {
            y: 3
            height: sw.height - 6
            radius: 7
            color: mt.accentMint
            x: 3 + (sw.full ? 0 : (sw.pm ? sw.half : 0))
            width: sw.full ? sw.width - 6 : sw.half

            Behavior on x {
                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }

            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            }
        }

        Text {
            x: 3
            width: sw.half
            height: sw.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "AM"
            opacity: sw.full ? 0 : 1
            color: sw.pm ? mt.pInkSub : mt.accentInk
            font.family: mt.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Text {
            x: 3 + sw.half
            width: sw.half
            height: sw.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "PM"
            opacity: sw.full ? 0 : 1
            color: sw.pm ? mt.accentInk : mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "24H"
            opacity: sw.full ? 1 : 0
            color: mt.accentInk
            font.family: mt.fontFamily
            font.pixelSize: 12
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
    }

    // The seconds, on a small navy chip.
    component SecChip: Pill {
        id: sc

        property string label: "00"
        property color ink: mt.chipInk

        width: 56
        height: 30
        cornerRadius: 10
        ringWidth: 3
        fillColor: mt.chipFill
        rotation: 3
        transformOrigin: Item.Center

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: sc.label
            color: sc.ink
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // The little AM / PM tag the two card-less designs show in 12h mode.
    component AmPmChip: Pill {
        id: chip

        property string label: "AM"

        width: 36
        height: 28
        cornerRadius: 9
        ringWidth: 2
        fillColor: mt.accentMint
        rotation: 3
        transformOrigin: Item.Center

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: chip.label
            color: mt.accentInk
            font.family: mt.fontFamily
            font.pixelSize: 11
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // One day of the week: today is raised, tilted and lit; days already gone
    // are dimmed. Fills whatever size it is given.
    component DayBadge: Item {
        id: db

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property int dow: 0
        property bool today: false
        property bool past: false

        // Today's hard shadow, like a Pill's.
        Rectangle {
            visible: db.today
            x: 0
            y: 5
            width: db.width
            height: db.height - 6
            radius: 9
            color: mt.pLineShadow
        }

        Rectangle {
            width: db.width
            height: db.height - (db.today ? 6 : 8)
            y: db.today ? 1 : 3
            radius: 9
            color: db.today ? "transparent" : mt.pSurfaceHover
            opacity: db.past ? 0.55 : 1
            rotation: db.today ? -3 : 0
            transformOrigin: Item.Center
            border.width: db.today ? mt.borderWidth : 0
            border.color: mt.pLine
            gradient: db.today ? todayFill : null

            Gradient {
                id: todayFill
                GradientStop { position: 0.0; color: mt.accentMint }
                GradientStop { position: 1.0; color: mt.accentCyan }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.locale().dayName(db.dow, Locale.ShortFormat).toUpperCase()
                color: db.today ? mt.accentInk : mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    ScaleHost {
        anchors.fill: parent
        factor: win.uiScale

        Item {
            id: card

            // Which design is showing. 0 sits on the card; 1 is only the time, straight on the wallpaper.
            readonly property int designIndex: ClockService.design
            readonly property bool housed: card.designIndex === 0

            // Where the content starts on the card: the pill's own border + ring, plus room. Without the card,
            // `pad` leaves room for the numerals' outline and shadow.
            readonly property int inset: mt.borderWidth + mt.outerRingWidth + 10
            readonly property int pad: 14

            // How much attitude the keys have. 0 / 0 = a flat, level row.
            readonly property real tilt: 2.5       // degrees, outer keys; inner keys lean 40% of it
            readonly property int stagger: 10      // px the inner keys sit lower (the V)

            // On the chip: bright accents in the dark modes, outline ink in light (where the chip is pale and the
            // accent would vanish).
            readonly property color glow: mt.dark ? mt.accentMint : mt.colBorder

            readonly property real contentW: content.item ? content.item.implicitWidth : 0
            readonly property real contentH: content.item ? content.item.implicitHeight : 0

            width: card.housed ? card.contentW + card.inset * 2 : card.contentW + card.pad * 2
            height: card.housed
                ? card.contentH + card.inset * 2 + mt.shadowOffset
                : card.contentH + card.pad * 2

            // Drop-and-settle bounce when the design changes.
            property real bump: 1
            scale: card.bump * Math.max(0, win.reveal) * (win.placed ? 1 : 0)
            transformOrigin: Item.Center

            SequentialAnimation {
                id: bumpAnim
                NumberAnimation { target: card; property: "bump"; to: 1.035; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "bump"; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 }
            }

            // A new design is a new size: keep the card on screen (not while it is being dragged: then the drag
            // owns the position).
            onWidthChanged: {
                if (!dragArea.drag.active)
                    win.place()
            }

            onHeightChanged: {
                if (!dragArea.drag.active)
                    win.place()
            }

            Connections {
                target: ClockService
                function onDesignChanged() {
                    // (Not for the saved design being read back at startup.)
                    if (ClockService.loaded)
                        bumpAnim.restart()
                }
            }

            // The housing: the same outline / ring / translucent fill / hard shadow as the other cards. Only the
            // card design has it; the other one is just the time.
            Pill {
                anchors.fill: parent
                visible: card.housed
                cornerRadius: mt.radiusOuter
                ringWidth: mt.borderWidth + mt.outerRingWidth
                ringColorTop: mt.pSurfaceRing
                ringColorBottom: ringColorTop
                fillColor: mt.pSurface
            }

            // Left button: drag the card while the desktop is unlocked (EditMode.desktopDragAllowed).
            // Double-click flips 12h / 24h.
            MouseArea {
                id: dragArea
                z: 10
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

                onDoubleClicked: ClockService.toggleFormat()

                // Remember the new spot when a drag ends (also when it is cut short). A plain click doesn't save
                // anything, so a card that is squeezed onto a small screen for a moment can't overwrite where you
                // put it.
                drag.onActiveChanged: {
                    if (!drag.active)
                        win.saveSpot(card.x, card.y)
                }
            }

            // ===== the current design =====
            Loader {
                id: content
                z: 2
                x: card.housed ? card.inset : card.pad
                y: card.housed ? card.inset : card.pad
                sourceComponent: card.designIndex === 0 ? keysDesign : stackDesign
            }


            // ===== 0 KEYS =====
            Component {
                id: keysDesign

                Item {
                    id: kroot
                    implicitWidth: 286
                    implicitHeight: kcol.implicitHeight

                    Column {
                        id: kcol
                        width: kroot.implicitWidth
                        spacing: 10

                        // ===== header =====
                        Item {
                            width: kcol.width
                            height: 46

                            DateSticker {
                                id: ksticker
                                x: 2
                                y: 1
                                day: win.now.getDate()
                            }

                            Column {
                                anchors.left: ksticker.right
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: kcol.width - ksticker.width - 14 - 84 - 14
                                spacing: 0

                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: win.dateTitle
                                    color: mt.pInk
                                    font.family: mt.fontFamily
                                    font.pixelSize: 20
                                    font.weight: Font.ExtraBold
                                    font.styleName: mt.fontStyleBold
                                }

                                Text {
                                    visible: win.dateSub !== ""
                                    text: win.dateSub
                                    color: mt.pInkSub
                                    font.family: mt.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            AmPmSwitch {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 84
                                height: 30
                                full: ClockService.use24h
                                pm: win.pm
                            }
                        }

                        // ===== the stage =====
                        Item {
                            id: kstage
                            width: kcol.width
                            height: 100

                            // Faint lane lines behind the keys, one per key.
                            Repeater {
                                model: 4

                                Rectangle {
                                    required property int index
                                    // Keys are 57 wide with 6 between, and the beat column is 24 wide.
                                    readonly property real rowW: 4 * 57 + 24 + 4 * 6
                                    readonly property real laneLeft: (kstage.width - rowW) / 2
                                    x: laneLeft + (index < 2 ? index * 63 : 2 * 63 + 24 + 6 + (index - 2) * 63) + 27 - 1
                                    y: 0
                                    width: 2
                                    height: kstage.height
                                    radius: 1
                                    color: mt.pSurfaceDivider
                                }
                            }

                            // The beat ring: starts at the lit diamond each second and
                            // grows and fades. Drawn behind the keys.
                            Rectangle {
                                id: kripple
                                property real r: 10
                                property real cy: kstage.height / 2
                                width: kripple.r * 2
                                height: kripple.r * 2
                                x: kstage.width / 2 - kripple.r
                                y: kripple.cy - kripple.r
                                radius: kripple.r
                                color: "transparent"
                                border.width: 3
                                border.color: win.secs % 2 === 0 ? mt.accentMint : mt.accentCyan
                                opacity: 0
                            }

                            ParallelAnimation {
                                id: krippleAnim
                                NumberAnimation { target: kripple; property: "r"; from: 10; to: 48; duration: 560; easing.type: Easing.OutCubic }
                                NumberAnimation { target: kripple; property: "opacity"; from: 0.85; to: 0; duration: 560; easing.type: Easing.OutQuad }
                            }

                            Connections {
                                target: win
                                function onSecsChanged() {
                                    kripple.cy = kstage.height / 2 + (win.secs % 2 === 0 ? -14 : 14)
                                    krippleAnim.restart()
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                height: kstage.height
                                spacing: 6

                                // 12h mode: a leading zero is ghosted, not removed, so
                                // nothing moves.
                                KeyTile {
                                    y: 4
                                    digit: win.hh.charAt(0)
                                    ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                                    tilt: -card.tilt
                                }

                                KeyTile {
                                    y: 4 + card.stagger
                                    digit: win.hh.charAt(1)
                                    tilt: -card.tilt * 0.4
                                }

                                // The beat: two diamonds that take turns.
                                Item {
                                    width: 24
                                    height: kstage.height

                                    BeatDiamond {
                                        x: 6
                                        y: kstage.height / 2 - 14 - 6
                                        lit: win.secs % 2 === 0
                                        litColor: mt.accentMint
                                    }

                                    BeatDiamond {
                                        x: 6
                                        y: kstage.height / 2 + 14 - 6
                                        lit: win.secs % 2 !== 0
                                        litColor: mt.accentCyan
                                    }
                                }

                                KeyTile {
                                    y: 4 + card.stagger
                                    gradientFill: true
                                    digit: win.mm.charAt(0)
                                    tilt: card.tilt * 0.4
                                }

                                KeyTile {
                                    y: 4
                                    gradientFill: true
                                    digit: win.mm.charAt(1)
                                    tilt: card.tilt
                                }
                            }
                        }

                        // ===== the second lane =====
                        Item {
                            id: klane
                            width: kcol.width
                            height: 30

                            SecChip {
                                id: ksec
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                label: win.ss
                                ink: card.glow
                            }

                            Item {
                                id: ktrack
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.right: ksec.left
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: -2
                                height: 20

                                readonly property real headSize: 12
                                // The playhead is a second ahead, so it is at the far end at :59.
                                readonly property real pos: ktrack.width * Math.min(60, win.secs + 1) / 60
                                readonly property real headX: Math.min(ktrack.width - ktrack.headSize, Math.max(0, ktrack.pos - ktrack.headSize / 2))

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 12
                                    radius: 6
                                    color: mt.pSurfaceDivider
                                    border.width: 2
                                    border.color: mt.pLine
                                }

                                // What has played this minute.
                                Rectangle {
                                    x: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 8
                                    radius: 4
                                    width: Math.max(0, ktrack.headX + ktrack.headSize / 2 - 2)

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mt.accentMint }
                                        GradientStop { position: 1.0; color: mt.accentCyan }
                                    }

                                    // At :00 the lane just resets instead of sweeping backwards.
                                    Behavior on width {
                                        enabled: win.secs !== 0
                                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                    }
                                }

                                // Gates at 15 / 30 / 45 s.
                                Repeater {
                                    model: 3

                                    Rectangle {
                                        required property int index
                                        x: ktrack.width * (index + 1) / 4 - 1.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: 12
                                        radius: 1.5
                                        color: mt.pLine
                                        opacity: 0.45
                                    }
                                }

                                // The playhead: a diamond note.
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: ktrack.headSize
                                    height: ktrack.headSize
                                    radius: 3
                                    rotation: 45
                                    color: mt.accentMint
                                    border.width: 2
                                    border.color: mt.pLine
                                    x: ktrack.headX

                                    Behavior on x {
                                        enabled: win.secs !== 0
                                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                                    }
                                }
                            }
                        }

                        // ===== the week =====
                        Row {
                            id: kweek
                            width: kcol.width
                            height: 32
                            spacing: 4

                            // Sunday = 0 ... Saturday = 6; Qt's firstDayOfWeek is Monday = 1 ... Sunday = 7.
                            readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
                            readonly property int todayIdx: (win.now.getDay() - kweek.firstDow + 7) % 7

                            Repeater {
                                model: 7

                                DayBadge {
                                    required property int index
                                    width: (kweek.width - 6 * kweek.spacing) / 7
                                    height: kweek.height
                                    dow: (kweek.firstDow + index) % 7
                                    today: index === kweek.todayIdx
                                    past: index < kweek.todayIdx
                                }
                            }
                        }
                    }
                }
            }


            // ===== 3 STACK =====
            Component {
                id: stackDesign

                Item {
                    id: aroot
                    implicitWidth: 2 * 56 + 2
                    implicitHeight: 2 * (96 + card.stagger) + 24 + 8

                    // Hours on top...
                    Row {
                        spacing: 2

                        StickerDigit {
                            y: 0
                            value: win.hh.charAt(0)
                            ghost: !ClockService.use24h && win.hh.charAt(0) === "0"
                            fillColor: mt.accentMint
                            tilt: -card.tilt
                        }

                        StickerDigit {
                            y: card.stagger
                            value: win.hh.charAt(1)
                            fillColor: mt.accentMint
                            tilt: -card.tilt * 0.4
                        }
                    }

                    // ...the beat in the middle...
                    BeatDiamond {
                        x: aroot.implicitWidth / 2 - 14 - 6
                        y: 96 + card.stagger + 4 + 12 - 6
                        lit: win.secs % 2 === 0
                        litColor: mt.accentMint
                        offColor: "white"
                        lineColor: mt.colBorder
                    }

                    BeatDiamond {
                        x: aroot.implicitWidth / 2 + 14 - 6
                        y: 96 + card.stagger + 4 + 12 - 6
                        lit: win.secs % 2 !== 0
                        litColor: mt.accentCyan
                        offColor: "white"
                        lineColor: mt.colBorder
                    }

                    // ...and minutes below.
                    Row {
                        y: 96 + card.stagger + 4 + 24 + 4
                        spacing: 2

                        StickerDigit {
                            y: card.stagger
                            value: win.mm.charAt(0)
                            fillColor: mt.accentCyan
                            tilt: card.tilt * 0.4
                        }

                        StickerDigit {
                            y: 0
                            value: win.mm.charAt(1)
                            fillColor: mt.accentCyan
                            tilt: card.tilt
                        }
                    }

                    AmPmChip {
                        visible: !ClockService.use24h
                        label: win.pm ? "PM" : "AM"
                        x: aroot.implicitWidth - width + 6
                        y: aroot.implicitHeight - height + 4
                    }
                }
            }
        }
    }
}
