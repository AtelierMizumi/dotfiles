import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mizu.mediaControls

// One of the files that talk to the system (the others: MediaSource.qml
// for MPRIS, TraySource.qml + TrayPopups.qml for the tray,
// NotificationSource.qml for notifications).
// Status_Bar.qml stays pure UI: this feeds it niri (Compositor) + clock + media
// + tray data and turns its signals into actions.
PanelWindow {
    id: win

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(screen)

    // One entry of shell.qml's bar model: { screen, position }. The edge is
    // part of the entry on purpose — this window is built for one edge and
    // never moves: when the bar is moved, the entry changes, this window
    // is dropped and a fresh one is built on the new edge (see the
    // comment on `bars` in shell.qml).
    required property var modelData
    screen: modelData.screen

    // The shell-wide tray (see shell.qml): what apps have put in the
    // system tray, and which ones are pinned.
    required property var traySource

    // The shell-wide Quick Panel (see shell.qml); the notification bell opens it.
    required property var quickPanel

    // The shell-wide picker (see shell.qml). The bar has no button for it any more (the utility keys are gone);
    // kept so shell.qml's instantiation does not change.
    property var picker: null

    // Which edge this bar is on (services/BarPositionService.qml chooses
    // it; it arrives here through modelData and is fixed for the life of
    // the window). The window sticks to that edge and both neighbouring
    // edges, so it runs the full length of the screen: top/bottom bars
    // lie flat, left/right bars stand up.
    readonly property string barPosition: modelData.position
    readonly property bool vertical: win.barPosition === "left" || win.barPosition === "right"
    anchors {
        top: win.barPosition !== "bottom"
        bottom: win.barPosition !== "top"
        left: win.barPosition !== "right"
        right: win.barPosition !== "left"
    }
    // The bar's design thickness is 63 when it lies flat and 74 when it
    // stands up; the whole bar is drawn inside a ScaleHost (see the end
    // of this file) so the window has to be that much thicker or thinner
    // for this monitor's scale (scale.json / services/ShellScale.qml).
    // Only the thickness is set: the other direction comes from the
    // anchors.
    // (This edge's own thickness, not BarPositionService.thickness: that
    // follows the *current* edge, and would resize this window while it
    // is being replaced.)
    readonly property real uiScale: ShellScale.forScreen(win.screen)
    readonly property real thickness: BarPositionService.thicknessFor(win.barPosition)
    // (The Capsule style is a slimmer bar: it reserves Theme.capStrip, or Theme.capStripV on
    // a standing bar, whatever the edge's usual thickness is.)
    readonly property real stripSize: Math.round((win.barStyle === 3 ? (win.vertical ? mt.capStripV : mt.capStrip)
    : win.thickness) * win.uiScale)

    // ===== Edit Desktop =====
    readonly property bool editing: win.screen !== null && EditMode.editing(win.screen.name)
    // The window is only the strip plus a few pixels of room, except while this monitor is in
    // Edit Desktop (EditStage below shrinks the whole picture into a card and needs the
    // whole screen). Why: a Qt window reports its whole surface as changed whenever it
    // draws, so a screen-sized transparent bar made the compositor re-composite the entire
    // screen for every frame the bar drew, and kept it busy at idle.
    // The window stays anchored to its edge and to both neighbouring edges, so the strip is
    // in the same place on screen and every position in this file (mask, popupX / popupY,
    // the status bar's x / y) keeps working in window pixels: they are all measured from
    // the edge the bar sits on. The room is for the popups' anchor points, which sit a few
    // pixels past the strip. `ipc call options set bar.compactWindow false` goes back to
    // the screen-sized window.
    //
    // Only for a bar on the TOP or LEFT edge. A layer-shell window anchored to the bottom or the
    // right edge that changes size shows its old picture at the new surface's top-left corner for
    // a frame or two, so a bottom bar jumped to the top of the screen (and a right bar to the
    // left) every time Edit Desktop started or ended and the window grew / shrank. A top or left
    // window grows away from its own origin, so the old picture is still in the right place.
    // The bottom and right edges therefore keep the screen-sized window (see EditMode.qml's
    // header: the same reason the bar and the dock never resized before this).
    readonly property bool growsFromOrigin: win.barPosition === "top" || win.barPosition === "left"
    readonly property bool compactWindow: SettingsService.flag("bar.compactWindow") && !win.editing && win.growsFromOrigin
    // (Only the popups' anchor points and the hover tags' anchor boxes sit past the strip, and
    // those are separate popup windows now, so a few pixels is enough. Smaller = less for
    // the compositor to composite; if a popup ever looks mis-placed, raise the 8.)
    readonly property real windowRoom: Math.ceil(8 * win.uiScale)
    implicitHeight: win.vertical ? 0 : (win.screen
    ? (win.compactWindow ? Math.min(Math.round(win.screen.height), win.stripSize + win.windowRoom)
    : Math.round(win.screen.height))
    : win.stripSize)
    implicitWidth: win.vertical ? (win.screen
    ? (win.compactWindow ? Math.min(Math.round(win.screen.width), win.stripSize + win.windowRoom)
    : Math.round(win.screen.width))
    : win.stripSize) : 0
    // Auto would reserve the whole window: spell out the strip.
    exclusionMode: ExclusionMode.Normal
    // Transparent style: the pills sit straight on the wallpaper, so the space
    // under (or beside) them should be small. Two things are taken off what the
    // bar reserves:
    //  - niri's `gaps` (gapsOut below), which it adds between the reserved strip
    //    and the windows. The pills are centred in the strip, so this alone
    //    makes the gap to the windows equal to the gap to the screen edge.
    //  - `transparentExtraGap` more, so the windows sit a little closer than
    //    that. Make this number bigger for a smaller gap, 0 for the equal one.
    // Float and Straight keep the full strip (the bar is a visible object
    // there). 
    readonly property real transparentExtraGap: 5
    // niri's layout gap (design px). The config does not export it, so it is fixed at niri's default.
    readonly property real gapsOut: 12
    // Capsule takes only the gap off (no extra): its strip already holds an 8 px
    // gap under the bar, so the windows end up that far below the bar's shadow.
    readonly property real transparentTrim: win.barStyle === 2
    ? Math.min(win.gapsOut + Math.round(win.transparentExtraGap * win.uiScale),
               Math.round(win.stripSize * 0.6))
    : (win.barStyle === 3
    ? Math.min(win.gapsOut, Math.round(win.stripSize * 0.6))
    : 0)
    // An auto-hiding bar reserves nothing: the windows use the whole screen and the bar
    // slides in over them.
    exclusiveZone: win.autoHide ? 0 : win.stripSize - win.transparentTrim
    color: "transparent"

    // Game Mode (GameModeService.qml): the bar is a fixed strip of date / clock /
    // weather that only shows. Nothing on it can be clicked or hovered, so every
    // click goes through to the game (the same 1 px as while editing).
    readonly property bool gameMode: GameModeService.enabled
    readonly property bool passive: win.editing || win.gameMode
    // What the bar shows in Game Mode, in this order (Status_Bar.qml only shows
    // these three, see its `gameMode`).
    readonly property var gameLayout: ({ left: [], center: ["date", "clock", "weather"], right: [] })

    // Only the strip takes input, and nothing while editing or in Game Mode (1 px
    // in the corner, which is never part of the card).
    // A bar on the bottom edge also gives up the Quick Panel's hot edge (the strip at the
    // bottom centre, QuickPanel.qml): that spot is cut out of the bar's input region, so the
    // pointer reaches the hot-edge window under it. (Same width / height / centring as that
    // window; the bar's pills never reach the last 4 px of the strip.)
    mask: Region {
        item: barMask
        regions: [ Region { item: hotCut; intersection: Intersection.Subtract } ]
    }
    Item {
        id: hotCut
        readonly property bool on: win.barPosition === "bottom" && !win.passive
        && !!win.quickPanel && !!win.quickPanel.hotEdge
        width: on ? Math.min(win.width, win.quickPanel.hotWidth) : 0
        height: on ? win.quickPanel.hotHeight : 0
        x: (win.width - width) / 2
        y: win.height - height
    }
    // Tucked away (auto-hide), only a thin line on the very edge takes input: the pointer
    // touching it brings the bar out.
    Item {
        id: barMask
        readonly property real across: win.tucked ? win.hotThick : win.stripSize
        x: win.passive ? 0 : (win.barPosition === "right" ? win.width - across : 0)
        y: win.passive ? 0 : (win.barPosition === "bottom" ? win.height - across : 0)
        width: win.passive ? 1 : (win.vertical ? across : win.width)
        height: win.passive ? 1 : (win.vertical ? win.height : across)
    }

    // ===== auto-hide (issue #61) =====
    // Settings -> Bar -> Auto-hide ("bar.hideMode": off | auto). The bar slides off its
    // edge and comes back while the pointer is on the edge or on the bar, while one of its
    // popups is open, in Edit Desktop, and for a moment on `ipc call bar peek`.
    readonly property bool autoHide: SettingsService.get("bar.hideMode") === "auto"
    property bool hoverWin: false
    readonly property bool popupOpen: win.trayOpen || trayPopups.showing || win.batteryPopupOpen
        || win.resourcePopupOpen || win.calendarPopupOpen || win.weatherPopupOpen || win.mediaPopupOpen
    readonly property bool revealed: !win.autoHide || win.editing || win.hoverWin || win.popupOpen
        || hideGrace.running || peekHold.running
    // How deep the line on the edge is, real pixels.
    readonly property real hotThick: Math.max(2, Math.round(3 * win.uiScale))
    // 0 = out, 1 = away; drawn as "whichever pushes it further" with a preset's slide.
    property real hideSlide: win.revealed ? 0 : 1
    Behavior on hideSlide {
        enabled: win.animReady
        NumberAnimation { duration: 220; easing.type: win.revealed ? Easing.OutCubic : Easing.InCubic }
    }
    readonly property bool tucked: win.autoHide && !win.revealed && win.hideSlide > 0.99
    // A bar built hidden (a shell start, a new monitor) is simply away; the slide starts
    // to animate once it is on screen.
    property bool animReady: false
    Timer {
        interval: 600
        running: win.visible && !win.animReady
        onTriggered: win.animReady = true
    }
    // So moving the pointer off the bar toward a window doesn't flick it away at once.
    Timer {
        id: hideGrace
        interval: 450
    }
    onHoverWinChanged: {
        if (!win.hoverWin && win.autoHide)
            hideGrace.restart()
    }
    onPopupOpenChanged: {
        if (!win.popupOpen && win.autoHide)
            hideGrace.restart()
    }
    Timer {
        id: peekHold
        interval: 2000
    }
    // Bring the bar out for a moment (`ipc call bar peek`); it hides again by itself.
    function peek() {
        peekHold.restart()
    }

    // Going into Game Mode puts every open popup away (nothing on the bar can
    // open or close one any more).
    Connections {
        target: GameModeService
        function onEnabledChanged() {
            if (GameModeService.enabled)
                win.closePopups()
        }
    }

    // Popups are closed as the mode starts.
    Connections {
        target: EditMode
        function onActiveChanged() {
            if (EditMode.active && win.editing)
                win.closePopups()
        }
    }

    // ===== where popups go =====
    // (Capsule: its strip already holds an 8 px gap beside the bar, so no extra.)
    readonly property real popupGap: win.barStyle === 3 ? 0 : 4
    function popupX(cx, cy, w, h) {
        if (win.vertical)
            return win.barPosition === "left" ? win.stripSize + win.popupGap : win.width - win.stripSize - win.popupGap
            const maxX = win.width - w - 8
            return Math.max(8, Math.min(cx - w / 2, maxX))
    }
    function popupY(cx, cy, w, h) {
        if (!win.vertical)
            return win.barPosition === "bottom" ? win.height - win.stripSize : win.stripSize
            const maxY = win.height - h - 8
            return Math.max(8, Math.min(cy - h / 2, maxY))
    }
    readonly property int popupGravity: {
        if (win.vertical)
            return win.barPosition === "left" ? (Edges.Bottom | Edges.Right)
            : (Edges.Bottom | Edges.Left)
            return win.barPosition === "bottom" ? (Edges.Top | Edges.Right)
            : (Edges.Bottom | Edges.Right)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Whether the tray dropdown is open. The button flips it; the popup
    // shows/hides from it and sets it back to false after you pick
    // something or click away — the button pulses by itself when that
    // happens.
    property bool trayOpen: false

    // Something left for the dropdown to show? (See Status_Bar.)
    readonly property bool trayAvailable: traySource.unpinnedItems.length > 0
    onTrayAvailableChanged: {
        if (!trayAvailable)
            trayOpen = false
    }

    // The dropdown + right-click menu, and what clicks on tray icons do.
    TrayPopups {
        id: trayPopups
        parentWindow: win
        source: win.traySource
        toggleAnchor: statusBar.trayToggle
        open: win.trayOpen
        onCloseRequested: win.trayOpen = false
    }

    // Whatever is playing (Spotify, mpv, a YouTube tab in the browser...)
    MediaSource {
        id: mediaSource
    }

    // CPU/RAM and battery — each Bar instance polls its own copy, same
    // as MediaSource (cheap enough not to bother sharing across
    // monitors; see ResourceSource.qml / BatterySource.qml).
    ResourceSource {
        id: resourceSource
        // Nothing reads the numbers while the module is switched off for this bar.
        wanted: statusBar.shows("resources") || win.resourcePopupOpen
    }

    // The status pill's Wi-Fi / Bluetooth look (StatusIconsService) runs only while some bar
    // shows the pill: it is one look for the whole shell, so each bar adds itself to a count
    // while its pill is on. `counted` makes adding and removing safe in any order of signals
    // (the first evaluation, a change, this bar being rebuilt or destroyed).
    QtObject {
        id: statusDemand

        property bool counted: false
        readonly property bool want: statusBar.shows("status")

        onWantChanged: statusDemand.sync()

        function sync() {
            if (statusDemand.want === statusDemand.counted)
                return
            statusDemand.counted = statusDemand.want
            StatusIconsService.watch(statusDemand.want ? 1 : -1)
        }

        Component.onCompleted: statusDemand.sync()
        Component.onDestruction: {
            if (statusDemand.counted) {
                statusDemand.counted = false
                StatusIconsService.watch(-1)
            }
        }
    }

    BatterySource {
        id: batterySource
    }

    WeatherSource {
        id: weatherSource
    }

    // Whether the battery / resource / ... popup is open. Same pattern as
    // trayOpen above: owned here, the indicator asks to flip it, the
    // popup's own click-away sets it back to false. Opening one closes
    // the others so they don't stack.
    property bool batteryPopupOpen: false
    property bool resourcePopupOpen: false
    property bool calendarPopupOpen: false
    property bool weatherPopupOpen: false
    property bool mediaPopupOpen: false

    function closePopups() {
        trayOpen = false
        batteryPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        mediaPopupOpen = false
    }

    // Flip one of the popups above by its property name, with the others put away.
    function togglePopup(name) {
        const wasOpen = win[name]
        batteryPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        mediaPopupOpen = false
        win[name] = !wasOpen
    }
    function toggleMediaPopup() { togglePopup("mediaPopupOpen") }
    function toggleBatteryPopup() { togglePopup("batteryPopupOpen") }
    function toggleResourcePopup() { togglePopup("resourcePopupOpen") }
    function toggleCalendarPopup() { togglePopup("calendarPopupOpen") }
    function toggleWeatherPopup() { togglePopup("weatherPopupOpen") }

    // The media panel under the media pill: a card per player.
    LazyLoader {
        id: mediaPopupLazy
        // Built the first time it is asked for (not at start-up on every monitor), then kept.
        property bool want: win.mediaPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        MediaPopup {
            // Starts closed and opens a beat later, so its open-handlers (outside-click
            // catcher, refresh, ...) run exactly as they do when the button is clicked.
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: mediaPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.mediaToggle
            source: mediaSource
            onCloseRequested: win.mediaPopupOpen = false
        }
    }

    LazyLoader {
        id: batteryPopupLazy
        // Built the first time it is asked for (not at start-up on every monitor), then kept.
        property bool want: win.batteryPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        BatteryPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: batteryPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.batteryToggle
            onCloseRequested: win.batteryPopupOpen = false

            percentage: batterySource.percentage
            statusLabel: batterySource.statusLabel
            timeRemaining: batterySource.timeRemaining
        }
    }

    // The month card under the date pill. `today` follows the bar's
    // SystemClock, so the highlighted day rolls over at midnight.
    LazyLoader {
        id: calendarPopupLazy
        property bool want: win.calendarPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        CalendarPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: calendarPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.dateToggle
            today: clock.date
            onCloseRequested: win.calendarPopupOpen = false
        }
    }

    // The weather card under the weather pill.
    LazyLoader {
        id: weatherPopupLazy
        property bool want: win.weatherPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        WeatherPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: weatherPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.weatherToggle
            source: weatherSource
            onCloseRequested: win.weatherPopupOpen = false
        }
    }

    LazyLoader {
        id: resourcePopupLazy
        property bool want: win.resourcePopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        ResourcePopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: resourcePopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.resourceToggle
            onCloseRequested: win.resourcePopupOpen = false

            cpuPercent: resourceSource.cpuPercent
            memPercent: resourceSource.memPercent
            memUsedLabel: resourceSource.memUsedLabel
            memTotalLabel: resourceSource.memTotalLabel
        }
    }

    // Keyboard layout: niri's xkb layouts (names + the active one), read from niri's event
    // stream while the module is on. The pill shows only when there is more than one layout.
    KeyboardLayoutSource {
        id: keyboardLayout
        wanted: statusBar.shows("keyboardLayout")
    }

    // This monitor's own workspace (niri numbers them per output)
    readonly property int activeWorkspace: Compositor.activeOn(screen?.name ?? "")

    // Indexes of workspaces that currently have windows. Lets the badges show the
    // ones above the configured count only while they are in use.
    readonly property var occupiedWorkspaces: Compositor.occupiedOn(screen?.name ?? "")

    // The focused window is global, so only the bar of the monitor the user is on names it
    // (the others say "Workspace N").
    readonly property var focusedWindow: (Compositor.focusedOutput === "" || Compositor.focusedOutput === (screen?.name ?? ""))
        ? ToplevelManager.activeToplevel
        : null

    // The window's class / app id ("org.mozilla.firefox", "kitty"...)
    readonly property string windowClass: focusedWindow ? (focusedWindow.appId || "") : ""

    // Display name for it: the .desktop entry's Name when there is one
    // ("Firefox", "Visual Studio Code"), else a tidied-up class.
    function appDisplayName(cls) {
        if (cls === "")
            return ""
        try {
            const entry = DesktopEntries.heuristicLookup(cls)
            if (entry && entry.name)
                return entry.name
        } catch (e) {}
        // "org.mozilla.firefox" -> "Firefox", "code-oss" -> "Code-oss"
        const last = cls.split(".").pop()
        return last.charAt(0).toUpperCase() + last.slice(1)
    }

    // The same app's icon as an image source, for the standing bar's Active window
    // key. "" when the class has no .desktop entry or the icon is not found
    // (the key then shows the app's first letter).
    readonly property string windowIconSource: {
        if (win.windowClass === "")
            return ""
        try {
            const entry = DesktopEntries.heuristicLookup(win.windowClass)
            if (entry && entry.icon)
                return Quickshell.iconPath(entry.icon, "application-x-executable")
        } catch (e) {}
        return ""
    }

    function pad(n) {
        return ("0" + n).slice(-2)
    }

    // "21:05" (Settings -> General -> 24-hour, the default) or "09:05 PM".
    function formatClock(d) {
        if (SettingsService.flag("time.use24h"))
            return pad(d.getHours()) + ":" + pad(d.getMinutes())
        const h = d.getHours()
        const h12 = h % 12 === 0 ? 12 : h % 12
        return pad(h12) + ":" + pad(d.getMinutes()) + " " + (h < 12 ? "AM" : "PM")
    }

    // The date pill: Settings' "time.dateFormat" (a Qt date format) when it is set, else the locale's short date.
    function formatDate(d) {
        const fmt = SettingsService.get("time.dateFormat")
        if (typeof fmt === "string" && fmt !== "")
            return d.toLocaleDateString(Qt.locale(), fmt)
        return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    // The bar's look (BarStyleService.qml): 0 Float, 1 Straight,
    // 2 Transparent, 3 Capsule. Float and Capsule are inset from the screen
    // edges, by the same gap the bar keeps outside its workspace badges
    // (Theme.barFloatInset); it glides in and out when the style changes.
    // Straight also sits flush with the screen edge the bar is on, and Capsule
    // keeps Theme.capEdgeGap off it.
    // Capsule is drawn on any edge: on a bar that stands up it is the same slim rounded bar, with
    // its chips stacked (Theme.capVChip wide).
    readonly property int barStyle: BarStyleService.index
    // (Held on a plain Item so the Behavior has an Item to animate on.)
    Item {
        id: geometry
        property real sideInset: (win.barStyle === 0 || win.barStyle === 3) ? mt.barFloatInset : 0
        Behavior on sideInset {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        // Wearing a desktop preset that changes the bar: it slides off the
        // edge it is on, the preset goes on, and it slides back (see
        // PresetMotion.qml). 0 = in place, 1 = away. Two fixed animations
        // started from the flag, not one Behavior (see ClockWidget's reveal).
        property real slide: 0
        NumberAnimation {
            id: slideOut
            target: geometry
            property: "slide"
            to: 1
            duration: PresetMotion.outMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            id: slideIn
            target: geometry
            property: "slide"
            to: 0
            duration: PresetMotion.inMs
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
        Connections {
            target: PresetMotion
            function onBarOutChanged() {
                if (PresetMotion.barOut) {
                    slideIn.stop()
                    slideOut.restart()
                } else {
                    slideOut.stop()
                    slideIn.restart()
                }
            }
        }
        // A bar built in the middle of a swap (a new edge builds a new
        // window) starts away and comes in once the others do.
        Component.onCompleted: {
            if (PresetMotion.barBusy) {
                geometry.slide = 1
                if (!PresetMotion.barOut)
                    slideIn.restart()
            }
        }
    }

    // The bar's picture. Out of edit mode it is exactly the window (scale 1, no
    // offset). While editing it is the same picture scaled down and moved to
    // where the card is, like the wallpaper's.
    EditStage {
        id: stage
        screenObj: win.screen
        uiScale: win.uiScale
        // The card is worked out from the SCREEN's size, not the window's: the window is only
        // the strip until it has grown for Edit Desktop, and for those first frames a card
        // worked out from the strip's size is in the wrong place (a top / left window's corner
        // is the screen's corner, so no origin is needed).
        refWidth: win.screen ? win.screen.width : win.width
        refHeight: win.screen ? win.screen.height : win.height
        // Cuts off what the Straight style bleeds past the screen edge (it was
        // the window's edge that hid that); here the card's edge does.
        clip: true

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Status_Bar {
                id: statusBar
                vertical: win.vertical
                barPosition: win.barPosition
                // The bar hugs the screen edge it's on (1px off it, except
                // Straight which is flush), and runs along the edge inset by
                // sideInset (only Float has an inset).
                readonly property real edgeGap: win.barStyle === 1 ? 0 : (win.barStyle === 3 ? mt.capEdgeGap : 1)
                // How far it is pushed off its edge while a preset swaps it
                // (geometry.slide, 0..1): its own thickness, the gap and room
                // for the shadow.
                readonly property real slideDist: (win.vertical ? width : height) + edgeGap + 20
                readonly property real slideBy: Math.max(geometry.slide, win.hideSlide) * statusBar.slideDist
                x: win.vertical
                ? (win.barPosition === "right" ? parent.width - width - edgeGap + slideBy : edgeGap - slideBy)
                : geometry.sideInset
                y: win.vertical
                ? geometry.sideInset
                : (win.barPosition === "bottom" ? parent.height - height - edgeGap + slideBy : edgeGap - slideBy)
                width: win.vertical ? (win.barStyle === 3 ? mt.capVBarFace : mt.barVBody) : parent.width - 2 * geometry.sideInset
                height: win.vertical ? parent.height - 2 * geometry.sideInset : (win.barStyle === 3 ? mt.capBarHeight : 61)
                barStyle: win.barStyle

                activeWorkspace: win.activeWorkspace
                occupiedWorkspaces: win.occupiedWorkspaces
                workspaceCount: Math.max(1, Math.min(10, Math.round(Number(SettingsService.get("bar.workspaceCount")) || 5)))
                gameMode: win.gameMode
                modules: BarLayoutService.modulesFor(win.screen ? win.screen.name : "")
                clockText: win.formatClock(clock.date)
                dateText: win.formatDate(clock.date)
                onDateClicked: win.toggleCalendarPopup()
                scaleValue: win.uiScale
                layout: win.gameMode ? win.gameLayout : BarLayoutService.layoutFor(win.screen ? win.screen.name : "")

                mediaActive: mediaSource.present
                mediaPlaying: mediaSource.playing
                mediaTitle: mediaSource.title
                mediaArtist: mediaSource.artist
                mediaArtUrl: mediaSource.artUrl
                mediaLeftOpensPanel: SettingsService.get("media.leftClick") === "panel"
                mediaVolumeAvailable: mediaSource.volumeAvailable
                onMediaPanelRequested: win.toggleMediaPopup()
                onMediaScrolled: direction => mediaSource.changeVolume(direction)
                onMediaToggleRequested: mediaSource.togglePlaying()
                onMediaNextRequested: mediaSource.next()
                onMediaPreviousRequested: mediaSource.previous()

                onNotificationsToggleRequested: win.quickPanel.toggleOn(win.screen)

                cpuPercent: resourceSource.cpuPercent
                memPercent: resourceSource.memPercent
                onResourcesClicked: win.toggleResourcePopup()

                // "--" until the first fetch lands (or if curl/the network
                // isn't available) rather than showing a blank pill.
                weatherTemperature: weatherSource.temperatureText !== "" ? weatherSource.temperatureText : "--"
                weatherIconName: weatherSource.iconName
                onWeatherClicked: win.toggleWeatherPopup()

                batteryAvailable: batterySource.available
                batteryPercentage: batterySource.percentage
                batteryCharging: batterySource.isCharging
                batteryLow: batterySource.isLow
                onBatteryClicked: win.toggleBatteryPopup()

                // Wi-Fi / Bluetooth / speaker as icons (StatusIconsService);
                // a click opens the Quick Panel, where the switches are.
                statusNetworkShown: StatusIconsService.networkShown
                statusNetworkIcon: StatusIconsService.networkIcon
                statusNetworkState: StatusIconsService.networkState
                statusBluetoothShown: StatusIconsService.bluetoothShown
                statusBluetoothIcon: StatusIconsService.bluetoothIcon
                statusBluetoothState: StatusIconsService.bluetoothState
                statusSpeakerShown: StatusIconsService.speakerShown
                statusSpeakerIcon: StatusIconsService.speakerIcon
                statusSpeakerState: StatusIconsService.speakerState
                statusDetail: StatusIconsService.detail
                onStatusClicked: win.quickPanel.toggleOn(win.screen)

                keyboardLayoutCode: keyboardLayout.code
                onKeyboardLayoutClicked: keyboardLayout.next()

                notificationCount: win.quickPanel?.notificationSource?.count ?? 0
                notificationsMuted: !(win.quickPanel?.source?.notificationsOn ?? true)

                // Who has the microphone, what is playing, or the screen (PrivacyService).
                privacyMic: PrivacyService.micLive
                privacyAudio: PrivacyService.audioLive
                privacyScreen: PrivacyService.screenLive
                // The hover tag: one line per thing in use.
                privacyDetail: {
                    const lines = []
                    if (PrivacyService.screenLive)
                        lines.push("Screen shared with: " + PrivacyService.screenApps.join(", "))
                    if (PrivacyService.micLive)
                        lines.push("Microphone in use by: " + PrivacyService.micApps.join(", "))
                    if (PrivacyService.audioLive)
                        lines.push("Desktop audio recorded by: " + PrivacyService.audioApps.join(", "))
                    return lines.join("\n")
                }

                trayOpen: win.trayOpen
                trayAvailable: win.trayAvailable
                trayMenuItem: trayPopups.menuItem
                trayLeavingItem: trayPopups.leavingItem
                trayAttention: win.traySource.unpinnedAttention
                trayScrollEnabled: SettingsService.flag("tray.scroll")
                onTrayItemScrolled: (item, delta, horizontal) => trayPopups.handleScroll(item, delta, horizontal)
                onTrayToggleRequested: win.trayOpen = !win.trayOpen
                trayPinned: win.traySource.pinnedItems
                onTrayItemClicked: (item, button, icon) => trayPopups.handleClick(item, button, icon, false)

                // Both are empty when nothing is focused on this bar's own
                // workspace; Status_Bar then falls back to "Workspace N".
                windowApp: win.appDisplayName(win.windowClass)
                windowTitle: win.focusedWindow?.title ?? ""
                windowIcon: win.windowIconSource

                // niri focuses a workspace by output + index, so a click on a non-focused monitor's bar
                // lands on its own monitor.
                onWorkspaceRequested: workspace => Compositor.focusWorkspace(win.screen.name, workspace)
            }
        }
    }

    // Sees the pointer on the bar and on the line at the edge, for auto-hide (only the
    // masked parts get pointer events). Last, so it is on top: a mouse area above it
    // could take the pointer away. A HoverHandler is passive, so clicks still go through.
    Item {
        anchors.fill: parent
        HoverHandler {
            onHoveredChanged: win.hoverWin = hovered
        }
    }
}
