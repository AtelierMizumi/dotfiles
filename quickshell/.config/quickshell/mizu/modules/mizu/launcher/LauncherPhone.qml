import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.services
import "../../common/functions/PhoneMath.js" as PM
import qs.modules.mizu.phone
// The launcher phone: the shell's app launcher, as ONE phone that lives in the bottom-left corner of the screen and
// behaves exactly like the Quick Panel's phone (QuickPanel.qml), just from the other side:
//
//   - it is the same 2.5D body (PhoneBody.qml), the same size, the same pose
//   - it comes up with the same bounce and the same pocket tilt that rings out as it lands
//   - it stays up with its lower part below the screen edge (`peek`, the same "How much of the phone shows" setting
//     as the Quick Panel)
//   - moving the mouse away does NOT close it; click outside it, press the keybind again, or pick an app. It then
//     drops back out of sight the way the Quick Panel does (a little pull up first)
//
// Its one screen is LauncherFace.qml: search, the built-ins, your pinned apps, and every installed app A to Z.
// (The Wallpapers screen this phone used to turn into is gone: the Settings' Appearance page replaced it.)
//
// Ways to open it:
//   - the `launcher` keybind:  qs -c mizu ipc call mizu launcher  (services/MizuIpc.qml)
//   - the clipboard keybind opens it with "clip " typed in the search box (`openWithText`)
//
// It opens on the monitor you pointed at (the focused one for a keybind). Like QuickPanel.qml, this is one of the
// files that talks to the system.
Scope {
    id: root

    // AppSource: the app index (`allApps`, `rank()`, `launch()`).
    required property var source

    // The Quick Panel: only one phone is up at a time.
    property var quickPanel: null

    property bool open: false
    // The window is mapped: from the moment it is asked for until the drop-out has finished.
    property bool shown: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    // ===== things you're likely to change (same names and values as QuickPanel.qml) =====
    // How much of the phone shows when it's up, as a fraction of its height (it shares the Quick Panel's setting).
    property real peek: SettingsService.get("panel.peek") / 100

    property real barHeight: 63
    property real edgeMargin: 10
    property real maxScale: 1
    // Empty room above the phone for the pull-out's overshoot.
    property real headroom: 44
    // How far (design px, scaled like everything else) the phone's left edge is from the screen's left edge.
    property real cornerGap: 24

    // The pull-out: how far (px) it rises past its resting spot before dropping back, and the degrees it is turned
    // while it is still "in the pocket".
    property real bounce: 34
    property real tiltRoll: 12
    property real tiltPitch: 10
    property real tiltYaw: -6

    // How far (px) the phone sits below its resting spot: 0 at rest, huge while it has never been shown; negative
    // during the overshoot. 1 = turned the way it is in the pocket, 0 = upright.
    property real lift: 100000
    property real tilt: 1
    // Where the pull-up before leaving peaks, and how long it takes.
    property real exitPeak: 0
    property real exitPeakMs: 130
    property real exitDrop: 0

    readonly property bool animating: enterAnim.running || exitAnim.running || exitDelay.running

    function focusedScreen() {
        return Compositor.focusedScreen()
    }

    readonly property alias face: face

    function openOn(screen) {
        if (screen)
            targetScreen = screen
        open = true
    }

    function openWithText(screen, text) {
        if (screen)
            targetScreen = screen
        open = true
        face.setText(text)
        face.focusSearch()
    }

    function close() {
        open = false
    }

    function toggleOn(screen) {
        if (open && (!screen || screen === targetScreen))
            close()
        else
            openOn(screen)
    }

    // How far (px) the phone has to drop to be completely out of sight from where it stands now.
    function dropDistance() {
        return Math.ceil(win.shownHeight) + 2
    }

    onOpenChanged: {
        if (open) {
            if (root.quickPanel && (root.quickPanel.open || root.quickPanel.settingsOpen))
                root.quickPanel.close()
            exitDelay.stop()
            exitAnim.stop()
            face.reset()
            root.shown = true
            // Coming up from nothing starts fully out of sight; coming back mid-way through leaving carries on from
            // where it is.
            const hidden = root.dropDistance()
            if (root.lift > hidden)
                root.lift = hidden
            enterAnim.restart()
            focusTimer.restart()
        } else {
            enterAnim.stop()
            // A small pull up first, unless it's still on its way up.
            const rising = root.lift > 20
            root.exitPeak = rising ? root.lift : -root.bounce * 0.7
            root.exitPeakMs = rising ? 1 : 130
            root.exitDrop = root.dropDistance()
            // Sitting still, the phone is drawn at full quality, which is too heavy to animate on. Switching down to
            // the light settings redraws it once, so that is done a couple of frames *before* it starts to move (the
            // same trick QuickPanel.qml's exit uses).
            if (phone.crisp)
                exitDelay.restart()
            else
                exitAnim.restart()
        }
    }

    // ===== the pull-out =====
    ParallelAnimation {
        id: enterAnim

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "lift"
                to: -root.bounce
                duration: 340
                easing.type: Easing.OutCubic
            }
            // The settle never goes below the resting spot (it would drag the phone's lower part under the screen
            // edge for a moment), so the bounce stays upward only.
            NumberAnimation {
                target: root
                property: "lift"
                to: 0
                duration: 170
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: -root.bounce * 0.14
                duration: 110
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: 0
                duration: 110
                easing.type: Easing.InQuad
            }
        }

        NumberAnimation {
            target: root
            property: "tilt"
            to: 0
            duration: 820
            easing.type: Easing.OutElastic
            easing.amplitude: 1
            easing.period: 0.4
        }
    }

    // A short beat between "close requested" and the drop actually starting.
    Timer {
        id: exitDelay
        interval: 40
        onTriggered: {
            if (!root.open)
                exitAnim.restart()
        }
    }

    // Going back: a little pull up (like lifting it clear of the pocket), then it drops away, speeding up, tilting
    // back as it goes.
    ParallelAnimation {
        id: exitAnim

        onFinished: {
            root.shown = false
            root.lift = 100000
            root.tilt = 1
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "lift"
                to: root.exitPeak
                duration: root.exitPeakMs
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "lift"
                to: root.exitDrop
                duration: 340
                easing.type: Easing.InCubic
            }
        }

        NumberAnimation {
            target: root
            property: "tilt"
            to: 1
            duration: 440
            easing.type: Easing.InQuad
        }
    }

    // The search box takes the keyboard once the window is up and the grab has taken hold.
    Timer {
        id: focusTimer
        interval: 140
        onTriggered: {
            if (root.open)
                face.focusSearch()
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: win.visible
    }

    // ===== click away =====
    PanelWindow {
        id: catcher

        screen: root.targetScreen
        visible: root.open && win.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "mizu-launcher-clickaway"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
        }
    }

    // ===== the window =====
    // Sits on the bottom-left corner of the screen and is only as big as the phone needs for everything it does in the
    // corner (the peek and the pull-out's overshoot). Its size is worked out once, up front, because a window that is
    // resized while it animates stutters. Only the phone itself takes the mouse (`mask`).
    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "mizu-launcherphone"
        // Exclusive, not OnDemand: OnDemand only hands the keyboard over once the compositor decides this window is
        // focused (pointer over it / clicked), so with the mouse elsewhere the search box got no keys. While the
        // launcher is open it owns the keyboard.
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            left: true
            bottom: true
        }

        // The window reaches `bleed` px past the bottom of the screen, so the compositor's own open animation lifting
        // the surface a few px can never show a gap under the phone (see QuickPanel.qml for the long story).
        readonly property real bleed: Math.max(24, Math.ceil(shownHeight * 0.04))
        margins.bottom: -Math.ceil(bleed)

        mask: Region {
            item: hitRect
        }

        // This monitor's scale (scale.json / services/ShellScale.qml).
        readonly property real uiScale: ShellScale.forScreen(root.targetScreen)
        readonly property real pixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
        readonly property real monitorW: root.targetScreen ? root.targetScreen.width : 1920
        readonly property real monitorH: root.targetScreen ? root.targetScreen.height : 1080

        readonly property real gapPx: Math.round(root.cornerGap * uiScale)
        readonly property real edgeMarginPx: root.edgeMargin * uiScale

        // As big as the Quick Panel's phone: shrunk to fit the screen's height (never past maxScale), times the
        // monitor's scale, but never so big that the whole phone would not fit under the top of the screen.
        readonly property real fit: {
            const room = monitorH - root.barHeight - 4 - root.edgeMargin - root.headroom
            const natural = Math.max(0.3, Math.min(root.maxScale, room / phone.implicitHeight))
            const tall = phone.swing.top + phone.implicitHeight
            const cap = (monitorH - (root.barHeight + root.headroom) * uiScale) / Math.max(1, tall)
            return Math.max(0.3, Math.min(natural * uiScale, Math.max(natural, cap)))
        }

        // The part that shows at rest, and the whole phone with a little room under it.
        readonly property real shownHeight: phone.implicitHeight * fit * Math.min(1, Math.max(0.2, root.peek))
        readonly property real fullBody: phone.implicitHeight * fit + edgeMarginPx
        // Where its screen's middle is: x from the window's left edge, u up from the monitor's bottom edge.
        readonly property real px0: gapPx + (phone.swing.left + phone.screenCenterX) * fit
        readonly property real pu0: shownHeight - phone.screenCenterY * fit

        // Height above the monitor's bottom edge, with room above for the bounce.
        readonly property real topU: Math.min(monitorH, Math.ceil(fullBody + phone.swing.top * fit
                                                                  + root.headroom * uiScale))
        readonly property real winW: Math.min(monitorW, Math.ceil(
            px0 + (phone.implicitWidth + phone.swing.right - phone.screenCenterX) * fit + 4))

        implicitWidth: winW
        implicitHeight: topU + Math.ceil(bleed)

        // ----- where the pivot (the middle of the phone's screen) is -----
        readonly property real pivotXRaw: px0
        readonly property real pivotYRaw: topU - pu0 + root.lift

        // The bottom of the face that is above the monitor's edge, in the face's own 654x1214 coordinates
        // (QuickPanel.qml's faceCutoffAt, at rest): the Home screen lays its bottom button out above it. The cutoff is
        // level on the monitor but slanted on the face, so the higher end is what counts.
        function faceCutoffAt(x) {
            const m = PM.baseFor(phone.faceWidth, phone.faceHeight, phone.thickness,
                                 phone.yaw, phone.pitch, phone.roll,
                                 phone.perspective, phone.pose)
            const Y = shownHeight / fit
            const den = Y * m[13] - m[5]
            if (Math.abs(den) < 1e-9)
                return phone.faceHeight
            return Math.min(phone.faceHeight, (m[4] * x + m[7] - Y * (m[12] * x + m[15])) / den)
        }
        readonly property real faceVisibleBottom: Math.min(faceCutoffAt(0), faceCutoffAt(phone.faceWidth))

        // ----- sharpness -----
        // Once it has settled, the picture is put on a whole device pixel (the same thing SettingsStage.qml does).
        readonly property bool settled: root.open && root.lift === 0 && root.tilt === 0 && !root.animating
        readonly property real gridPx: Math.max(1, pixelRatio)
        readonly property real sceneX: pivotXRaw - phone.screenCenterX * fit - (phone.layerSwing.left + 8) * fit
        readonly property real sceneY: pivotYRaw - phone.screenCenterY * fit - (phone.layerSwing.top + 8) * fit

        readonly property real snapX: settled ? Math.round(sceneX * gridPx) / gridPx - sceneX : 0
        readonly property real snapY: settled ? Math.round(sceneY * gridPx) / gridPx - sceneY : 0

        // What takes the mouse: the phone's own rectangle, and only while it is open. The window ends at the screen's
        // bottom edge, so what hangs below is simply off the screen.
        Item {
            id: hitRect

            readonly property real topY: win.topU - win.shownHeight

            x: win.px0 - phone.screenCenterX * win.fit
            y: topY
            width: root.open ? phone.implicitWidth * win.fit : 0
            height: root.open ? Math.max(0, win.topU + Math.ceil(win.bleed) - topY) : 0
        }

        // The point it turns about: the middle of the screen.
        Item {
            id: pivot

            x: win.pivotXRaw + win.snapX
            y: win.pivotYRaw + win.snapY

            PhoneBody {
                id: phone

                // Its screen's middle stays on the pivot whatever size it is.
                x: -phone.screenCenterX * win.fit
                y: -phone.screenCenterY * win.fit
                transformOrigin: Item.TopLeft
                scale: win.fit

                // Window not mapped: the layer buffers are given back after a while (PhoneBody `warm`).
                windowShown: win.visible

                // Drawn on the light settings while it moves and while it is away, the full-quality ones take over
                // once it has landed.
                moving: root.animating || !win.visible

                // Turned while it is coming out of / going into the pocket, and rings out past upright on the
                // overshoot (the Quick Panel's numbers).
                rollOffset: root.tilt * root.tiltRoll
                pitchOffset: root.tilt * root.tiltPitch
                yawOffset: root.tilt * root.tiltYaw
                swingRoll: root.tiltRoll
                swingPitch: root.tiltPitch
                swingYaw: root.tiltYaw

                // Draw the screen at the size it ends up on the monitor.
                renderScale: win.fit * win.pixelRatio

                LauncherFace {
                    id: face

                    source: root.source
                    renderScale: phone.renderScale
                    // Only this much of the phone shows at rest: the bottom button is laid out above the monitor's
                    // edge.
                    visibleBottom: win.faceVisibleBottom
                    clockText: Qt.formatDateTime(clock.date, SettingsService.flag("time.use24h") ? "HH:mm" : "hh:mmAP")
                    dateText: Qt.formatDate(clock.date, "ddd, d  MMM")

                    onAppActivated: app => {
                        root.close()
                        root.source.launch(app)
                    }
                    onCloseRequested: root.close()
                }
            }
        }
    }
}
