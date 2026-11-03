import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common/functions/WeatherMath.js" as WM
import qs.services
import qs.modules.common
import qs.modules.common.widgets
// The desktop weather card: the bar's weather popup (WeatherPopup.qml), put on the desktop. Same look, same parts,
// same Open-Meteo reading (through WeatherSource.qml), squeezed into the clock card's footprint (320 x 276) so the
// two sit side by side or stacked. It lives under your windows, over the wallpaper, and can be dragged while the
// desktop is unlocked (EditMode.desktopDragAllowed), by any part of the card that is not a key.
//
//   The plate      (NumberPlate, the header the bar popups share) the
//                  temperature as a white sticker numeral, today's high and
//                  low beside it, the conditions above it, and the weather as
//                  a tilted dark disc: poke it, it squashes and throws a puff
//                  of diamonds. The place hangs off the plate's lower edge on
//                  a slanted tab, with two keys beside it: the view switch
//                  (Hourly / Days) and refresh.
//   The gauges     humidity as a tank that fills, the wind as a dial whose
//                  arrow turns to where the wind is going, UV as a five-
//                  diamond meter.
//   The forecast   the same two views as the popup, and the same setting
//                  (SettingsService "weather.view"; the key on the plate
//                  flips it too):
//                    Hourly  the next readings as a melody: a note on a curve
//                            that rises and falls with the temperature.
//                    Days    a song list: one row per day with its weather,
//                            high and low, a range bar and the chance of rain
//                            filling the row from the left.
//                  Point at a note or a row and the plate's top line tells
//                  you the details.
//
// Two styles, the same footprint (`ipc call weathercard style minimal|classic`):
//   Classic  everything above.
//   Minimal  the same housing, plate, disc, place tab and refresh key, with only the
//            temperature, the weather, today's high and low, and the next four readings
//            in one lane (time, glyph, temperature; the first is "now" on a mint tab).
//            No gauges, no Hourly / Days switch, no top-line readout.
//
// Feels like, pressure and visibility are not here (there is no room); they are in the popup. The place comes
// from SettingsService "weather.location" and Fahrenheit from "weather.fahrenheit". Nothing runs on its own: the
// pop-ins play when a reading lands or the view changes, the rest answers the pointer (the refresh arrow spins
// while it loads). One reading every 15 minutes while the card is on screen.
//
// State (position, shown) lives in services/WeatherCardService.qml and is remembered across restarts.
//
// How the moving works: exactly like ClockWidget.qml. ONE transparent window on WlrLayer.Background with the card
// as an Item inside it. Dragging just moves that Item, so it stays smooth, and the window's input `mask` is only
// the card, so every click anywhere else passes straight through to whatever is underneath. The card never takes
// keyboard focus.
//
// Bind a key / call it from a script:
//   qs -c mizu ipc call weathercard toggle         (show / hide)
//   qs -c mizu ipc call weathercard refresh        (ask Open-Meteo again now)
//   qs -c mizu ipc call weathercard style minimal  (or classic)
//   qs -c mizu ipc call weathercard resetPosition  (if it ever ends up off-screen)

PanelWindow {
    id: win

    readonly property var mt: Theme.of(screen)

    function resetPosition(): void {
        win.clearSpot();
        win.place();
        win.saveSpot(card.x, card.y);
    }

    // Which monitor it lives on, by name (e.g. "DP-1"). Empty = the monitor the card was last dropped on
    // (remembered in WeatherCardService), or the default monitor if it has never been moved.
    property string monitor: ""

    // A copy on another monitor (WidgetClones.qml): the same widget, with a spot of its own. The main
    // copy keeps its spot in the service.
    property bool clone: false

    readonly property var cloneSpot: win.clone ? WidgetClones.spot("weathercard", win.wantedScreen) : null
    readonly property bool spotReady: win.clone ? (WidgetClones.loaded && win.cloneSpot !== null) : WeatherCardService.loaded
    readonly property real spotX: win.clone ? (win.cloneSpot ? win.cloneSpot.x : -1) : WeatherCardService.posX
    readonly property real spotY: win.clone ? (win.cloneSpot ? win.cloneSpot.y : -1) : WeatherCardService.posY
    readonly property real spotScale: win.clone ? (win.cloneSpot ? win.cloneSpot.scale : 0) : WeatherCardService.posScale

    function saveSpot(x, y): void {
        if (win.clone)
            WidgetClones.setSpot("weathercard", win.wantedScreen, x, y, win.uiScale)
        else
            WeatherCardService.setPosition(x, y, win.screen ? win.screen.name : "", win.uiScale)
    }

    function clearSpot(): void {
        if (win.clone) {
            WidgetClones.clearSpot("weathercard", win.wantedScreen)
        } else {
            WeatherCardService.posX = -1
            WeatherCardService.posY = -1
        }
    }

    function fixSpotScale(): void {
        if (win.clone) {
            WidgetClones.setSpot("weathercard", win.wantedScreen, win.spotX, win.spotY, win.uiScale)
        } else {
            WeatherCardService.posScale = win.uiScale
            WeatherCardService.persist()
        }
    }

    readonly property string wantedScreen: win.monitor !== "" ? win.monitor : WeatherCardService.screenName
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
        widgetId: "weathercard"
        screenName: win.screen ? win.screen.name : ""
    }

    readonly property bool switchedOn: WeatherCardService.shown && WeatherCardService.loaded
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
        running: WeatherCardService.loaded
        onTriggered: win.armed = true
    }

    // `live`: the card is on, or still being swallowed.
    readonly property bool live: win.want || win.reveal > 0.001

    // Not mapped while the widget is off: a full-screen transparent layer that is only sitting there still costs
    // the compositor a blend on every frame.
    visible: WeatherCardService.loaded && win.live

    // The widgets rest on Background (mapped after the wallpaper, so over it), under every window.
    WlrLayershell.layer: WallpaperService.covered(win.screen ? win.screen.name : "") ? WlrLayer.Bottom : WlrLayer.Background
    WlrLayershell.namespace: "mizu-weathercard"
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

    // On screen, or switched on: the reading runs (and polls) in both cases.
    readonly property bool working: win.live || win.switchedOn

    // ===== the weather =====
    // The same Open-Meteo reading the bar's pill and popup show. This card asks for its own copy (every Bar.qml
    // instance does too), and only while it is on screen.
    WeatherSource {
        id: wx
        polling: win.working
    }

    // A new reading has landed: the pop-ins play.
    signal landed()

    Connections {
        target: wx
        function onLastFetchMsChanged() {
            win.landed()
        }
    }

    // Ask again now (the refresh key, `ipc call weathercard refresh`).
    function refresh(): void {
        wx.refresh()
    }

    // The card's style (WeatherCardService.style): "classic" or "minimal". Same footprint.
    readonly property bool minimal: WeatherCardService.minimal

    readonly property bool hasData: wx.temperatureText !== ""
    readonly property bool hourlyView: SettingsService.get("weather.view") === "hourly"
        && win.hasData && wx.hourly.length > 0
    readonly property bool canSwitch: win.hasData && wx.hourly.length > 0
    readonly property bool night: wx.iconName.indexOf("night") >= 0

    // The accent as INK (icons, arrow): the mint is right on the dark looks but washes out on light surfaces,
    // so it is darkened there.
    readonly property color iconInk: mt.dark ? mt.accentMint : Qt.darker(mt.accentMint, 1.5)

    readonly property var temp: WM.splitTemp(win.hasData ? wx.temperatureText : "")
    readonly property var today: win.hasData && wx.forecast.length > 0 ? wx.forecast[0] : null

    // The days' shared temperature scale, for the range bars.
    readonly property var span: {
        if (!win.hasData || wx.forecast.length === 0)
            return { lo: 0, hi: 1 }
        let lo = 1e9
        let hi = -1e9
        for (const d of wx.forecast) {
            lo = Math.min(lo, WM.firstNumber(d.low))
            hi = Math.max(hi, WM.firstNumber(d.high))
        }
        return { lo: lo, hi: Math.max(hi, lo + 1) }
    }

    readonly property var windP: WM.windParts(win.hasData ? wx.windText : "")
    readonly property var windArrow: WM.windArrow(win.hasData ? wx.windText : "")
    readonly property real windNum: WM.firstNumber(win.windP.speed)
    readonly property string windUnit: String(win.windP.speed).replace(/^[\d.\s-]+/, "")
    readonly property real uv: WM.firstNumber(win.hasData ? wx.uvText : "")

    // ===== the pop-ins =====
    property real wave: 1
    readonly property real waveMs: 760

    NumberAnimation {
        id: waveAnim
        target: win
        property: "wave"
        from: 0
        to: 1
        duration: win.waveMs
    }

    onHourlyViewChanged: waveAnim.restart()
    onMinimalChanged: waveAnim.restart()
    onHasDataChanged: waveAnim.restart()
    onLanded: waveAnim.restart()

    // What the pointer is on.
    property int hoverHour: -1
    property int hoverDay: -1

    // The plate's top line while the pointer is on a note or a row.
    readonly property string readout: {
        if (!win.hasData)
            return ""
        if (win.hourlyView && win.hoverHour >= 0 && win.hoverHour < wx.hourly.length) {
            const h = wx.hourly[win.hoverHour]
            return h.label + "  \u00b7  " + h.condition + "  \u00b7  rain " + h.rain + "%"
        }
        if (!win.hourlyView && win.hoverDay >= 0 && win.hoverDay < wx.forecast.length) {
            const d = wx.forecast[win.hoverDay]
            return d.label + "  \u00b7  " + d.condition
        }
        return ""
    }

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: mt.accentMint }
        GradientStop { position: 1.0; color: mt.accentCyan }
    }

    // ===== placement =====
    function place(force) {
        if (win.roomW <= 0 || win.roomH <= 0)
            return
        // Not before the saved spot has been read, and not while the window is still smaller than the card (the
        // clamp below would put it at 0, 0).
        if (!force && (!WeatherCardService.loaded || win.roomW < card.width || win.roomH < card.height))
            return
        let x = win.spotX
        let y = win.spotY
        if (x < 0 || y < 0) {
            x = 384
            y = 396
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
                win.place(!win.placed && WeatherCardService.loaded)
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
        target: WeatherCardService
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


    // ===== parts =====

    // Water in a tank: a body that thins out towards the bottom (so the ink
    // resting on it stays readable) and a bright surface line on top, so the
    // level reads at a glance. Put it in the Pill it fills; `level` is 0..1
    // (already eased), `corner` is the Pill's inner radius. (WeatherPopup's.)
    component Water: Rectangle {
        id: water

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)
        property real level: 0
        property real corner: 10

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * Math.max(0, Math.min(1, water.level))
        radius: water.corner
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.36) }
            GradientStop { position: 1.0; color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.12) }
        }

        Rectangle {
            visible: water.height > water.corner
            x: water.corner * 0.7
            y: 1
            width: Math.max(0, water.width - water.corner * 1.4)
            height: 2
            radius: 1
            color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.85)
        }
    }

    // The small caps label every gauge tile carries. (WeatherPopup's.)
    component TileLabel: Text {

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)
        color: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.78)
        font.family: mt.fontFamily
        font.pixelSize: 9
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        font.letterSpacing: 0.8
        elide: Text.ElideRight
    }

    ScaleHost {
        anchors.fill: parent
        factor: win.uiScale

        Item {
            id: card

            // The same footprint as the clock's KEYS card: its content is 286 x 238, and the housing adds the
            // inset on every side plus the hard shadow underneath.
            readonly property int contentW: 286
            readonly property int contentH: 238
            readonly property int inset: mt.borderWidth + mt.outerRingWidth + 10

            width: card.contentW + card.inset * 2
            height: card.contentH + card.inset * 2 + mt.shadowOffset

            scale: Math.max(0, win.reveal) * (win.placed ? 1 : 0)
            transformOrigin: Item.Center

            // A new size (a different scale, a different monitor) keeps the card on screen; not while it is being
            // dragged, then the drag owns the position.
            onWidthChanged: {
                if (!dragArea.drag.active)
                    win.place()
            }

            onHeightChanged: {
                if (!dragArea.drag.active)
                    win.place()
            }

            // The housing: the same outline / pale ring / surface fill / hard shadow as the bar and the other cards.
            Pill {
                anchors.fill: parent
                cornerRadius: mt.radiusOuter
                ringWidth: mt.borderWidth + mt.outerRingWidth
                ringColorTop: mt.pSurfaceRing
                ringColorBottom: ringColorTop
                fillColor: mt.pSurface
            }

            // Left button: drag the card while the desktop is unlocked (EditMode.desktopDragAllowed). Sits UNDER
            // the content, so the keys and the disc win their own clicks and everything else on the card is "grab
            // here".
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

                // Remember the new spot when a drag ends (also when it is cut short). A plain click doesn't save
                // anything, so a card that is squeezed onto a small screen for a moment can't overwrite where you
                // put it.
                drag.onActiveChanged: {
                    if (!drag.active)
                        win.saveSpot(card.x, card.y)
                }
            }

            // ===== the content =====
            Item {
                id: content
                z: 2
                x: card.inset
                y: card.inset
                width: card.contentW
                height: card.contentH

                // ===== the two looks =====
                // Only the one in use is built (the other is not even created), so the minimal
                // card is also the lighter one. Style: WeatherCardService.style.
                Loader {
                    active: !win.minimal
                    sourceComponent: classicFace
                }

                Loader {
                    active: win.minimal
                    sourceComponent: minimalFace
                }

                // ===== the classic style =====
                Component {
                    id: classicFace

                    Item {
                        width: card.contentW
                        height: card.contentH

                        // ===== the plate, and the place hanging off it =====
                        Item {
                            id: head
                            width: card.contentW
                            height: 100

                            NumberPlate {
                                id: plate
                                width: head.width
                                height: 88

                                // The conditions: the details of the note or row you point at.
                                TileLabel {
                                    x: 14
                                    y: 9
                                    width: 188
                                    text: win.readout !== "" ? win.readout : condLabel.toUpperCase()
                                    color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.82)
                                    font.pixelSize: 10
                                    font.letterSpacing: win.readout !== "" ? 0.3 : 1.3

                                    readonly property string condLabel: win.hasData ? wx.conditionText
                                        : (wx.loading ? "Loading\u2026"
                                           : (wx.failed ? wx.problemText : "No weather data"))
                                }

                                StickerText {
                                    id: tempNum
                                    x: 6
                                    y: 13
                                    text: win.hasData ? win.temp.num : "--"
                                    pixelSize: 42
                                    fillColor: plate.numberFill
                                    ringColor: plate.numberRing
                                }

                                StickerText {
                                    id: tempUnit
                                    x: tempNum.x + tempNum.width - 6
                                    y: 19
                                    text: win.hasData ? win.temp.unit : ""
                                    pixelSize: 17
                                    fillColor: plate.numberFill
                                    ringColor: plate.numberRing
                                }

                                // Today's high and low, stacked beside the number.
                                Column {
                                    visible: win.today !== null
                                    x: tempUnit.x + tempUnit.width + 2
                                    y: 42
                                    spacing: 0

                                    Row {
                                        spacing: 0
                                        MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 13; weight: 700; color: mt.colBorder; fill: 0 }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.today ? win.today.high : ""
                                            color: mt.accentInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                    Row {
                                        spacing: 0
                                        MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 13; weight: 700; color: mt.colBorder; fill: 0 }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.today ? win.today.low : ""
                                            color: mt.accentInk
                                            opacity: 0.8
                                            font.family: mt.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                }

                                // The weather as a tilted dark disc: poke it.
                                Pill {
                                    id: disc
                                    x: plate.width - width - 12
                                    y: 8
                                    width: 68
                                    height: 70
                                    cornerRadius: 34
                                    ringWidth: mt.borderWidth + mt.whiteLine
                                    shadowDy: 4
                                    rotation: 6
                                    transformOrigin: Item.Center
                                    pressed: discArea.pressed
                                    fillColor: mt.chipFill

                                    property real sx: 1
                                    property real sy: 1

                                    transform: Scale {
                                        origin.x: disc.width / 2
                                        origin.y: disc.height / 2
                                        xScale: disc.sx
                                        yScale: disc.sy
                                    }

                                    WeatherGlyph {
                                        anchors.centerIn: parent
                                        name: wx.iconName
                                        size: 42
                                        color: mt.dark ? (win.night ? mt.accentCyan : mt.accentMint) : mt.colBorder
                                        scale: 0.5 + 0.5 * Math.min(win.wave * 1.2, 1.15)
                                    }
                                }

                                SequentialAnimation {
                                    id: squish
                                    ParallelAnimation {
                                        NumberAnimation { target: disc; property: "sx"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: disc; property: "sy"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation { target: disc; property: "sx"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                        NumberAnimation { target: disc; property: "sy"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                    }
                                }

                                MouseArea {
                                    id: discArea
                                    x: disc.x
                                    y: disc.y
                                    width: disc.width
                                    height: disc.height
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        squish.restart()
                                        puff.fire()
                                    }
                                }

                                Burst {
                                    id: puff
                                    x: disc.x + disc.width / 2
                                    y: disc.y + disc.height / 2
                                    radius: 58
                                    count: 8
                                }
                            }

                            // The place, hanging off the plate's lower edge.
                            Text {
                                id: placeProbe
                                visible: false
                                text: placeTab.label
                                font.family: mt.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.ExtraBold
                                font.styleName: mt.fontStyleBold
                            }

                            Slant {
                                id: placeTab
                                readonly property string label: win.hasData && wx.areaText !== "" ? wx.areaText : "Weather"
                                x: 2
                                y: 74
                                width: Math.min(placeProbe.implicitWidth + 44 + height * skew, 204)
                                height: 26
                                skew: 0.2
                                radius: 9
                                color: mt.chipFill
                                borderColor: mt.pLine
                                borderWidth: 3
                            }

                            // Text goes NEXT to the Slant (a child would lean with it).
                            Row {
                                x: placeTab.x + placeTab.lean / 2 + 10
                                y: placeTab.y
                                height: placeTab.height
                                spacing: 4

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "location_on"
                                    fill: 0
                                    size: 15
                                    weight: 700
                                    color: mt.dark ? mt.accentMint : mt.colBorder
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, placeTab.width - placeTab.lean - 36)
                                    elide: Text.ElideRight
                                    text: placeTab.label
                                    color: mt.chipInk
                                    font.family: mt.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.ExtraBold
                                    font.styleName: mt.fontStyleBold
                                }
                            }

                            // The view key: Hourly <-> Days (the popup's own setting).
                            Item {
                                visible: win.canSwitch
                                x: head.width - 34 - 6 - 34
                                y: 71
                                width: 34
                                height: 31

                                Pill {
                                    anchors.fill: parent
                                    shadowDy: 3
                                    cornerRadius: 11
                                    ringWidth: mt.borderWidth + mt.whiteLine
                                    fillColor: mt.chipFill
                                    pressed: viewArea.pressed

                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        name: win.hourlyView ? "calendar_view_day" : "schedule"
                                        fill: 0
                                        size: 17
                                        weight: 600
                                        color: mt.chipInk
                                    }
                                }

                                MouseArea {
                                    id: viewArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SettingsService.set("weather.view", win.hourlyView ? "days" : "hourly")
                                }
                            }

                            // The refresh key.
                            Item {
                                x: head.width - 34
                                y: 71
                                width: 34
                                height: 31

                                Pill {
                                    anchors.fill: parent
                                    shadowDy: 3
                                    cornerRadius: 11
                                    ringWidth: mt.borderWidth + mt.whiteLine
                                    fillColor: mt.chipFill
                                    pressed: refreshArea.pressed

                                    MaterialIcon {
                                        id: refreshIcon
                                        anchors.centerIn: parent
                                        name: "refresh"
                                        fill: 0
                                        size: 18
                                        weight: 600
                                        color: mt.chipInk

                                        RotationAnimator on rotation {
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: wx.loading
                                            onRunningChanged: {
                                                if (!running)
                                                    refreshIcon.rotation = 0
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: refreshArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.refresh()
                                }
                            }
                        }

                        // ===== the gauges =====
                        Row {
                            id: gauges
                            y: 106
                            visible: win.hasData
                            spacing: 8

                            // -- humidity: a tank --
                            Item {
                                id: humTile
                                width: 76
                                height: 54
                                readonly property real t: WM.clamp01((win.wave * win.waveMs - 0) / 300)
                                readonly property real value: WM.firstNumber(win.hasData ? wx.humidityText : "")

                                Item {
                                    anchors.fill: parent
                                    scale: (0.55 + 0.45 * WM.outBack(humTile.t, 2.2)) * (humArea.containsMouse ? 1.05 : 1)
                                    opacity: Math.min(1, humTile.t * 2.5)
                                    rotation: humArea.containsMouse ? 0 : -1.6
                                    transformOrigin: Item.Center
                                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                    Pill {
                                        anchors.fill: parent
                                        shadowDy: 4
                                        cornerRadius: 13
                                        ringWidth: 3
                                        fillColor: mt.pSurfaceHover

                                        Water {
                                            level: humTile.value / 100 * WM.outBack(humTile.t, 1.4)
                                            corner: 10
                                        }
                                        TileLabel { x: 8; y: 5; width: parent.width - 10; text: "HUMIDITY" }
                                        Text {
                                            x: 8
                                            y: 15
                                            width: parent.width - 12
                                            elide: Text.ElideRight
                                            text: win.hasData ? wx.humidityText : ""
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                }
                                MouseArea { id: humArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }

                            // -- wind: a dial --
                            Item {
                                id: windTile
                                width: 120
                                height: 54
                                readonly property real t: WM.clamp01((win.wave * win.waveMs - 55) / 300)

                                Item {
                                    anchors.fill: parent
                                    scale: (0.55 + 0.45 * WM.outBack(windTile.t, 2.2)) * (windArea.containsMouse ? 1.05 : 1)
                                    opacity: Math.min(1, windTile.t * 2.5)
                                    rotation: windArea.containsMouse ? 0 : 1.2
                                    transformOrigin: Item.Center
                                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                    Pill {
                                        anchors.fill: parent
                                        shadowDy: 4
                                        cornerRadius: 13
                                        ringWidth: 3
                                        fillColor: mt.pSurfaceHover

                                        TileLabel {
                                            x: 8
                                            y: 5
                                            width: parent.width - 14
                                            text: "WIND" + (win.windP.dir !== "" ? "  \u00b7  " + win.windP.dir : "")
                                        }

                                        Row {
                                            x: 8
                                            y: 15
                                            spacing: 3
                                            Text {
                                                id: windBig
                                                text: win.hasData ? String(win.windNum) : ""
                                                color: mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 19
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                            Text {
                                                anchors.baseline: windBig.baseline
                                                text: win.windUnit
                                                color: mt.pInkSub
                                                font.family: mt.fontFamily
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }

                                        // The dial: a ring with the arrow turning inside it, and a
                                        // diamond at north.
                                        Item {
                                            x: parent.width - width - 8
                                            y: 7
                                            width: 30
                                            height: 30

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: width / 2
                                                color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.35)
                                                border.width: 2
                                                border.color: mt.pLine
                                                antialiasing: true
                                            }
                                            DiamondDot {
                                                x: (parent.width - width) / 2
                                                y: -3
                                                size: 6
                                                lit: true
                                                litColor: mt.accentMint
                                                lineColor: mt.pLine
                                            }
                                            MaterialIcon {
                                                anchors.centerIn: parent
                                                name: win.windArrow !== null ? "arrow_upward" : "air"
                                                fill: 0
                                                size: 18
                                                weight: 700
                                                color: win.iconInk
                                                rotation: win.windArrow !== null ? win.windArrow * WM.outBack(windTile.t, 2.4) : 0
                                            }
                                        }
                                    }
                                }
                                MouseArea { id: windArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }

                            // -- UV: a meter --
                            Item {
                                id: uvTile
                                width: 74
                                height: 54
                                readonly property real t: WM.clamp01((win.wave * win.waveMs - 110) / 300)

                                Item {
                                    anchors.fill: parent
                                    scale: (0.55 + 0.45 * WM.outBack(uvTile.t, 2.2)) * (uvArea.containsMouse ? 1.05 : 1)
                                    opacity: Math.min(1, uvTile.t * 2.5)
                                    rotation: uvArea.containsMouse ? 0 : -1.2
                                    transformOrigin: Item.Center
                                    Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                    Pill {
                                        anchors.fill: parent
                                        shadowDy: 4
                                        cornerRadius: 13
                                        ringWidth: 3
                                        fillColor: mt.pSurfaceHover

                                        TileLabel { x: 8; y: 5; width: parent.width - 12; text: "UV INDEX" }
                                        Text {
                                            x: 8
                                            y: 13
                                            text: win.hasData ? wx.uvText : ""
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                        Row {
                                            x: 9
                                            y: 34
                                            spacing: 5
                                            Repeater {
                                                model: 5
                                                delegate: DiamondDot {
                                                    required property int index
                                                    size: 6
                                                    offColor: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.2)
                                                    lit: index < WM.uvLit(win.uv)
                                                    litColor: index < 2 ? mt.accentMint : (index < 4 ? mt.warning : mt.danger)
                                                }
                                            }
                                        }
                                    }
                                }
                                MouseArea { id: uvArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                            }
                        }

                        // ===== the forecast: hourly, a melody =====
                        Item {
                            id: hourly
                            y: 166
                            visible: win.hourlyView
                            width: card.contentW
                            height: 72

                            readonly property var readings: win.hasData ? wx.hourly : []
                            readonly property int n: hourly.readings.length
                            readonly property var pts: WM.curvePoints(hourly.readings.map(h => WM.firstNumber(h.temp)),
                                                                      20, card.contentW - 40, 40, 52)

                            // The lane the notes run along.
                            Rectangle {
                                anchors.fill: parent
                                radius: 13
                                color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.28)
                                border.width: 2
                                border.color: mt.pLine
                                antialiasing: true
                            }

                            // The curve through the notes: a navy line under a light one, like a sticker's edge.
                            Canvas {
                                id: curve
                                anchors.fill: parent
                                opacity: Math.min(1, win.wave * 2)
                                property color edge: mt.pLine
                                property color core: win.iconInk
                                property var pts: hourly.pts
                                onEdgeChanged: requestPaint()
                                onCoreChanged: requestPaint()
                                onPtsChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    const p = curve.pts
                                    if (!p || p.length < 2)
                                        return
                                    function trace() {
                                        ctx.beginPath()
                                        ctx.moveTo(p[0].x, p[0].y)
                                        for (let i = 1; i < p.length; i++) {
                                            const mx = (p[i - 1].x + p[i].x) / 2
                                            ctx.bezierCurveTo(mx, p[i - 1].y, mx, p[i].y, p[i].x, p[i].y)
                                        }
                                    }
                                    ctx.lineJoin = "round"
                                    ctx.lineCap = "round"
                                    trace()
                                    ctx.lineWidth = 6
                                    ctx.strokeStyle = curve.edge
                                    ctx.stroke()
                                    trace()
                                    ctx.lineWidth = 2.5
                                    ctx.strokeStyle = curve.core
                                    ctx.stroke()
                                }
                            }

                            Repeater {
                                model: hourly.readings

                                delegate: Item {
                                    id: note
                                    required property var modelData
                                    required property int index

                                    readonly property var pt: hourly.pts[note.index] || { x: 0, y: 46 }
                                    readonly property bool hovered: noteArea.containsMouse
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - note.index * 60) / 300)
                                    readonly property real pop: WM.outBack(note.t, 2.2)
                                    readonly property real colW: hourly.n > 1 ? Math.min(36, (card.contentW - 40) / (hourly.n - 1)) : 36

                                    x: note.pt.x - note.colW / 2
                                    width: note.colW
                                    height: hourly.height

                                    // The column under the pointer.
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: 10
                                        color: mt.pSurfaceHover
                                        opacity: note.hovered ? 1 : 0
                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }
                                    }

                                    WeatherGlyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 3
                                        name: note.modelData.iconName
                                        size: 17
                                        color: win.iconInk
                                        scale: 0.4 + 0.6 * note.pop
                                        opacity: Math.min(1, note.t * 2.5)
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: note.pt.y - 19
                                        text: note.modelData.temp
                                        color: mt.pInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                        opacity: Math.min(1, note.t * 2.5)
                                    }

                                    // The note itself: a diamond on the curve. The first is "now".
                                    Item {
                                        x: (parent.width - width) / 2
                                        y: note.pt.y - 6
                                        width: 12
                                        height: 12
                                        scale: (note.hovered ? 1.45 : (note.index === 0 ? 1.2 : 1)) * (0.3 + 0.7 * note.pop)
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                                        }

                                        DiamondDot {
                                            anchors.centerIn: parent
                                            size: 10
                                            lit: true
                                            litColor: note.index === 0 ? mt.accentMint : mt.pSurface
                                            lineColor: mt.pLine
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 59
                                        text: note.modelData.label
                                        color: mt.pInkSub
                                        font.family: mt.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        id: noteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        onEntered: win.hoverHour = note.index
                                        onExited: {
                                            if (win.hoverHour === note.index)
                                                win.hoverHour = -1
                                        }
                                    }
                                }
                            }
                        }

                        // ===== the forecast: days, a song list =====
                        Column {
                            id: days
                            y: 166
                            visible: win.hasData && !win.hourlyView && wx.forecast.length > 0
                            width: card.contentW
                            spacing: 3

                            Repeater {
                                model: win.hasData ? wx.forecast : []

                                delegate: Item {
                                    id: dayRow
                                    required property var modelData
                                    required property int index
                                    width: card.contentW
                                    height: 22

                                    readonly property bool hovered: rowArea.containsMouse
                                    readonly property bool isToday: dayRow.index === 0
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - dayRow.index * 90) / 320)
                                    readonly property real lo: WM.firstNumber(dayRow.modelData.low)
                                    readonly property real hi: WM.firstNumber(dayRow.modelData.high)

                                    Item {
                                        anchors.fill: parent
                                        opacity: Math.min(1, dayRow.t * 2.5)
                                        x: (1 - WM.outBack(dayRow.t, 1.6)) * 26
                                        scale: dayRow.hovered ? 1.015 : 1
                                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 11
                                            color: mt.pSurfaceHover
                                            border.width: 2
                                            border.color: dayRow.hovered ? mt.accentMint : mt.pLine
                                            antialiasing: true
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            // The chance of rain, filling the row from the left.
                                            Rectangle {
                                                x: 2
                                                y: 2
                                                height: parent.height - 4
                                                width: Math.max(0, (parent.width - 4) * Math.min(1, dayRow.modelData.rain / 100) * WM.outBack(dayRow.t, 1.4))
                                                radius: 9
                                                color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.2)
                                            }
                                        }

                                        // The day, on a slanted tab (today's is the gradient one).
                                        Slant {
                                            x: 5
                                            y: 3
                                            width: 56
                                            height: 16
                                            skew: 0.2
                                            radius: 6
                                            color: dayRow.isToday ? "transparent" : mt.chipFill
                                            gradient: dayRow.isToday ? accentGradient : null
                                            borderColor: mt.pLine
                                            borderWidth: 2
                                        }
                                        Text {
                                            x: 5
                                            y: 3
                                            width: 56
                                            height: 16
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            text: dayRow.modelData.label + (!dayRow.isToday && dayRow.modelData.date ? " " + dayRow.modelData.date : "")
                                            color: dayRow.isToday ? mt.accentInk : mt.chipInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }

                                        WeatherGlyph {
                                            x: 66
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: dayRow.modelData.iconName
                                            size: 18
                                            color: win.iconInk
                                        }

                                        Row {
                                            x: 92
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            Text {
                                                text: dayRow.modelData.high
                                                color: mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 13
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                            Text {
                                                anchors.baseline: parent.children[0].baseline
                                                text: dayRow.modelData.low
                                                color: mt.pInkSub
                                                font.family: mt.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        // High and low on the days' shared scale.
                                        Rectangle {
                                            id: track
                                            x: 148
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 70
                                            height: 5
                                            radius: 2.5
                                            color: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.16)

                                            Rectangle {
                                                x: (dayRow.lo - win.span.lo) / (win.span.hi - win.span.lo) * (track.width - width)
                                                width: Math.max(14, (dayRow.hi - dayRow.lo) / (win.span.hi - win.span.lo) * track.width)
                                                height: parent.height
                                                radius: 2.5
                                                gradient: accentGradient
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1
                                            MaterialIcon {
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: "water_drop"
                                                fill: 0
                                                size: 12
                                                weight: 700
                                                color: mt.pInk
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: dayRow.modelData.rain + "%"
                                                color: mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: rowArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        onEntered: win.hoverDay = dayRow.index
                                        onExited: {
                                            if (win.hoverDay === dayRow.index)
                                                win.hoverDay = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // ===== the minimal look =====
                // The same card, the same 2 x 2 footprint and the same parts (plate, disc,
                // place tab, refresh key, lane) with far less on it: the temperature, the
                // weather, today's high and low, and the next four readings in one lane.
                Component {
                    id: minimalFace

                    Item {
                        id: mini
                        width: card.contentW
                        height: card.contentH

                        // The plate's height (its face plus the hard shadow); the place
                        // tab and the refresh key hang off its lower edge, 14 px up.
                        readonly property real plateH: 128
                        readonly property real hangY: mini.plateH - 14
                        readonly property real laneY: 150
                        readonly property real laneH: card.contentH - mini.laneY
                        readonly property int cols: 4
                        // Big numbers fill the plate; three characters ("100", "-12") drop a size so
                        // they never run into the disc.
                        readonly property int numSize: String(win.hasData ? win.temp.num : "--").length > 2 ? 60 : 76
                        readonly property var reads: win.hasData ? wx.hourly.slice(0, mini.cols) : []

                        NumberPlate {
                            id: mplate
                            width: mini.width
                            height: mini.plateH

                            // The conditions.
                            TileLabel {
                                x: 14
                                y: 9
                                width: 176
                                text: condLabel.toUpperCase()
                                color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.82)
                                font.pixelSize: 10
                                font.letterSpacing: 1.3

                                readonly property string condLabel: win.hasData ? wx.conditionText
                                    : (wx.loading ? "Loading\u2026"
                                       : (wx.failed ? wx.problemText : "No weather data"))
                            }

                            // The temperature, big.
                            StickerText {
                                id: mNum
                                x: 8
                                y: 15
                                text: win.hasData ? win.temp.num : "--"
                                pixelSize: mini.numSize
                                fillColor: mplate.numberFill
                                ringColor: mplate.numberRing
                            }

                            StickerText {
                                x: mNum.x + mNum.width - 6
                                y: 27
                                text: win.hasData ? win.temp.unit : ""
                                pixelSize: 28
                                fillColor: mplate.numberFill
                                ringColor: mplate.numberRing
                            }

                            // The weather as a tilted dark disc: poke it.
                            Pill {
                                id: mdisc
                                x: mplate.width - width - 12
                                y: 8
                                width: 76
                                height: 78
                                cornerRadius: 38
                                ringWidth: mt.borderWidth + mt.whiteLine
                                shadowDy: 4
                                rotation: 6
                                transformOrigin: Item.Center
                                pressed: mdiscArea.pressed
                                fillColor: mt.chipFill

                                property real sx: 1
                                property real sy: 1

                                transform: Scale {
                                    origin.x: mdisc.width / 2
                                    origin.y: mdisc.height / 2
                                    xScale: mdisc.sx
                                    yScale: mdisc.sy
                                }

                                WeatherGlyph {
                                    anchors.centerIn: parent
                                    name: wx.iconName
                                    size: 50
                                    color: mt.dark ? (win.night ? mt.accentCyan : mt.accentMint) : mt.colBorder
                                    scale: 0.5 + 0.5 * Math.min(win.wave * 1.2, 1.15)
                                }
                            }

                            SequentialAnimation {
                                id: msquish
                                ParallelAnimation {
                                    NumberAnimation { target: mdisc; property: "sx"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: mdisc; property: "sy"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
                                }
                                ParallelAnimation {
                                    NumberAnimation { target: mdisc; property: "sx"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                    NumberAnimation { target: mdisc; property: "sy"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                }
                            }

                            MouseArea {
                                id: mdiscArea
                                x: mdisc.x
                                y: mdisc.y
                                width: mdisc.width
                                height: mdisc.height
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    msquish.restart()
                                    mpuff.fire()
                                }
                            }

                            Burst {
                                id: mpuff
                                x: mdisc.x + mdisc.width / 2
                                y: mdisc.y + mdisc.height / 2
                                radius: 62
                                count: 8
                            }

                            // Today's high and low, side by side under the disc.
                            Row {
                                visible: win.today !== null
                                x: mdisc.x + (mdisc.width - width) / 2
                                y: 92
                                spacing: 9

                                Row {
                                    spacing: 0
                                    MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 14; weight: 700; color: mt.colBorder; fill: 0 }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: win.today ? win.today.high : ""
                                        color: mt.accentInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                    }
                                }
                                Row {
                                    spacing: 0
                                    MaterialIcon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 14; weight: 700; color: mt.colBorder; fill: 0 }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: win.today ? win.today.low : ""
                                        color: mt.accentInk
                                        opacity: 0.8
                                        font.family: mt.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                    }
                                }
                            }
                        }

                        // The place, hanging off the plate's lower edge.
                        Text {
                            id: mplaceProbe
                            visible: false
                            text: mplaceTab.label
                            font.family: mt.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }

                        Slant {
                            id: mplaceTab
                            readonly property string label: win.hasData && wx.areaText !== "" ? wx.areaText : "Weather"
                            x: 2
                            y: mini.hangY
                            width: Math.min(mplaceProbe.implicitWidth + 44 + height * skew, 204)
                            height: 26
                            skew: 0.2
                            radius: 9
                            color: mt.chipFill
                            borderColor: mt.pLine
                            borderWidth: 3
                        }

                        // Text goes NEXT to the Slant (a child would lean with it).
                        Row {
                            x: mplaceTab.x + mplaceTab.lean / 2 + 10
                            y: mplaceTab.y
                            height: mplaceTab.height
                            spacing: 4

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "location_on"
                                fill: 0
                                size: 15
                                weight: 700
                                color: mt.dark ? mt.accentMint : mt.colBorder
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, mplaceTab.width - mplaceTab.lean - 36)
                                elide: Text.ElideRight
                                text: mplaceTab.label
                                color: mt.chipInk
                                font.family: mt.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.ExtraBold
                                font.styleName: mt.fontStyleBold
                            }
                        }

                        // The refresh key (the only key: the look has no Hourly / Days switch).
                        Item {
                            x: mini.width - 34
                            y: mini.hangY - 3
                            width: 34
                            height: 31

                            Pill {
                                anchors.fill: parent
                                shadowDy: 3
                                cornerRadius: 11
                                ringWidth: mt.borderWidth + mt.whiteLine
                                fillColor: mt.chipFill
                                pressed: mrefreshArea.pressed

                                MaterialIcon {
                                    id: mrefreshIcon
                                    anchors.centerIn: parent
                                    name: "refresh"
                                    fill: 0
                                    size: 18
                                    weight: 600
                                    color: mt.chipInk

                                    RotationAnimator on rotation {
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                        running: wx.loading
                                        onRunningChanged: {
                                            if (!running)
                                                mrefreshIcon.rotation = 0
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: mrefreshArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.refresh()
                            }
                        }

                        // ===== the lane: the next four readings =====
                        Item {
                            id: lane
                            y: mini.laneY
                            width: mini.width
                            height: mini.laneH

                            Rectangle {
                                anchors.fill: parent
                                radius: 13
                                color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.28)
                                border.width: 2
                                border.color: mt.pLine
                                antialiasing: true
                            }

                            // Nothing to show yet.
                            Text {
                                visible: !win.hasData
                                anchors.centerIn: parent
                                text: wx.loading ? "Fetching the forecast\u2026" : "Press refresh to try again"
                                color: mt.pInkSub
                                font.family: mt.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            // The readings: a time, a glyph and a temperature each. The
                            // first is "now" and sits on a mint tab.
                            Repeater {
                                model: mini.reads

                                delegate: Item {
                                    id: col
                                    required property var modelData
                                    required property int index

                                    readonly property real colW: (lane.width - 8) / mini.cols
                                    readonly property bool hovered: colArea.containsMouse
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - col.index * 70) / 300)
                                    readonly property real pop: WM.outBack(col.t, 2.2)

                                    x: 4 + col.index * col.colW
                                    y: 4
                                    width: col.colW
                                    height: lane.height - 8

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        radius: 10
                                        color: col.index === 0 ? Qt.rgba(mt.accentMint.r, mt.accentMint.g, mt.accentMint.b, 0.26)
                                            : mt.pSurfaceHover
                                        border.width: col.index === 0 ? 2 : 0
                                        border.color: mt.pLine
                                        opacity: col.index === 0 ? 1 : (col.hovered ? 1 : 0)
                                        antialiasing: true
                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 8
                                        text: col.modelData.label
                                        color: mt.pInkSub
                                        font.family: mt.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        opacity: Math.min(1, col.t * 2.5)
                                    }

                                    WeatherGlyph {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 24
                                        name: col.modelData.iconName
                                        size: 28
                                        color: win.iconInk
                                        scale: 0.4 + 0.6 * col.pop
                                        opacity: Math.min(1, col.t * 2.5)
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 55
                                        text: col.modelData.temp
                                        color: mt.pInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 16
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                        opacity: Math.min(1, col.t * 2.5)
                                    }

                                    MouseArea {
                                        id: colArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                }
                            }

                            // A reading with no forecast behind it (the service sent none):
                            // the two gauges that are left, as plain figures.
                            Row {
                                visible: win.hasData && mini.reads.length === 0
                                anchors.centerIn: parent
                                spacing: 40

                                Column {
                                    spacing: 2
                                    TileLabel { text: "HUMIDITY" }
                                    Text {
                                        text: wx.humidityText
                                        color: mt.pInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 19
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                    }
                                }
                                Column {
                                    spacing: 2
                                    TileLabel { text: "WIND" }
                                    Text {
                                        text: win.windP.speed
                                        color: mt.pInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 19
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
    }
}
