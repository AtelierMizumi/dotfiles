import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The clock card that drops down from the bar's clock pill: the desktop
// clock widget's KEYS design (services/ClockService, desktopWidgets/
// ClockWidget.qml), hung off the bar. The frame, focus grab, pop-in and
// swallow come from PopupFrame.qml; Bar.qml gives it `parentWindow` and
// `anchorItem`.
//
// Everything the widget has is here:
//   the header     the tilted gradient date sticker, the weekday (the shell's
//                  ja_JP names, or Settings' time.dateFormat) over "month
//                  year", and the AM / PM switch -- which, unlike the
//                  widget's, is a real switch: click it and the whole shell
//                  flips 12 h / 24 h with you (ClockService.toggleFormat).
//   the stage      four keycaps in the shallow V (hours mint, minutes the
//                  accent gradient), the two beat diamonds taking turns once
//                  a second, the ripple that starts at the lit one, and the
//                  faint lane lines behind the keys. A digit pops when it
//                  changes.
//   the lane       the minute's progress on its track (gates at 15 / 30 /
//                  45, a diamond playhead a beat ahead) and the seconds on
//                  a navy chip.
//   the week       seven day badges; today raised, tilted and lit, days
//                  already gone dimmed.
//
// And what the widget does not have, the popup adds: the zone chip at the
// left of the lane. Click it to cycle Local -> Tokyo -> UTC; every digit,
// the date, the sticker and the week badges then read that zone's wall
// clock (22:19 at home is 01:19 in Tokyo tomorrow, and the card says so).
PopupFrame {
    id: root

    // "Now", ticking every second from the card's own SystemClock.
    property date now: new Date()

    SystemClock {
        precision: SystemClock.Seconds
        onDateChanged: root.now = date
    }

    // ===== timezones =====
    // `off: null` means the system zone; the others are fixed offsets, so no
    // tz database is needed for the two that are not local.
    readonly property var zones: [
        { name: "Local", off: null },
        { name: "Tokyo", off: 9 * 60 },
        { name: "UTC", off: 0 }
    ]
    property int zoneIdx: 0
    readonly property var zone: root.zones[root.zoneIdx]

    // The wall clock of the viewed zone: shift the instant by the zone's
    // offset against the system's, then read the fields as usual.
    readonly property date zoned: root.zone.off === null ? root.now
        : new Date(root.now.getTime() + (root.zone.off + root.now.getTimezoneOffset()) * 60000)

    // The zone chip's short label.
    readonly property string zoneLabel: {
        const off = root.zone.off === null ? -root.now.getTimezoneOffset() : root.zone.off
        if (off === 0)
            return "±0"
        return (off > 0 ? "+" : "−") + Math.abs(off) / 60
    }

    // ===== the time =====
    readonly property int hours24: root.zoned.getHours()
    readonly property int mins: root.zoned.getMinutes()
    readonly property int secs: root.zoned.getSeconds()
    readonly property bool pm: root.hours24 >= 12
    readonly property int hoursShown: ClockService.use24h
        ? root.hours24
        : (root.hours24 % 12 === 0 ? 12 : root.hours24 % 12)

    function two(n) {
        return (n < 10 ? "0" : "") + n
    }

    readonly property string hh: root.two(root.hoursShown)
    readonly property string mm: root.two(root.mins)
    readonly property string ss: root.two(root.secs)

    // The date text: the user's Qt date format when there is one ("M月d日 ddd"),
    // else the weekday name over "month year" in the locale's own words -- of
    // the ZONE's day, so Tokyo's tomorrow is tomorrow's names.
    readonly property string dateFormat: String(SettingsService.get("time.dateFormat") ?? "")
    readonly property string dateTitle: root.dateFormat !== ""
        ? Qt.formatDate(root.zoned, root.dateFormat)
        : Qt.locale().dayName(root.zoned.getDay(), Locale.LongFormat)
    readonly property string dateSub: (root.dateFormat !== "" ? "" : Qt.formatDate(root.zoned, "MMMM yyyy"))
        + (root.zoneIdx === 0 ? "" : (root.dateTitle !== "" ? "  ·  " : "") + root.zone.name)

    // Layout, in design pixels -- the widget's card, plus the popup frame's
    // own breathing room.
    readonly property int innerW: 286
    readonly property int innerPad: 14

    contentWidth: root.innerW + 2 * root.innerPad
    contentHeight: stack.implicitHeight + 2 * root.innerPad - 2

    // On the chip: bright accents in the dark modes, outline ink in light
    // (where the chip is pale and the accent would vanish).
    readonly property color glow: mt.dark ? mt.accentMint : mt.colBorder

    // ===== small parts, from ClockWidget.qml =====

    // A keycap of the stage: a Pill key, ghosted when it is a leading zero
    // in 12 h mode.
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

    // A diamond of the beat: lit on its turn, and it pops when it lights.
    component BeatDiamond: Rectangle {
        id: bd
        property bool lit: false
        property color litColor: mt.accentMint
        property color offColor: mt.surfaceDivider
        property color lineColor: mt.line
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

    // The tilted gradient sticker with the zone's date number.
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

    // The AM / PM switch -- a real one here: click flips the shell's 12/24.
    // In 12 h mode the mint thumb sits under the current half; in 24 h mode
    // it stretches over the whole track and reads "24H".
    component AmPmSwitch: Item {
        id: sw
        property bool full: false      // 24h
        property bool pm: false
        readonly property real half: (sw.width - 6) / 2

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: mt.surfaceHover
            border.width: mt.borderWidth
            border.color: mt.line
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
            color: sw.pm ? mt.inkSub : mt.accentInk
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
            color: sw.pm ? mt.accentInk : mt.inkSub
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

    // The zone chip: where the card's clock is read. Click cycles
    // Local -> Tokyo -> UTC.
    component ZoneChip: Pill {
        id: zc

        property string label: "+7"
        property color ink: mt.chipInk

        width: 48
        height: 30
        cornerRadius: 10
        ringWidth: 3
        fillColor: mt.chipFill
        rotation: -3
        transformOrigin: Item.Center

        Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: zc.label
            color: zc.ink
            font.family: mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // One day of the week: today is raised, tilted and lit; days already
    // gone are dimmed.
    component DayBadge: Item {
        id: db
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
            color: mt.lineShadow
        }

        Rectangle {
            width: db.width
            height: db.height - (db.today ? 6 : 8)
            y: db.today ? 1 : 3
            radius: 9
            color: db.today ? "transparent" : mt.surfaceHover
            opacity: db.past ? 0.55 : 1
            rotation: db.today ? -3 : 0
            transformOrigin: Item.Center
            border.width: db.today ? mt.borderWidth : 0
            border.color: mt.line
            gradient: db.today ? todayFill : null

            Gradient {
                id: todayFill
                GradientStop { position: 0.0; color: mt.accentMint }
                GradientStop { position: 1.0; color: mt.accentCyan }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.locale().dayName(db.dow, Locale.ShortFormat).toUpperCase()
                color: db.today ? mt.accentInk : mt.inkSub
                font.family: mt.fontFamily
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }
    }

    Column {
        id: stack
        x: root.innerPad
        y: root.innerPad - 2
        width: root.innerW
        spacing: 10

        // ===== header: sticker, weekday, switch =====
        Item {
            width: stack.width
            height: 46

            DateSticker {
                id: hsticker
                x: 2
                y: 1
                day: root.zoned.getDate()
            }

            Column {
                anchors.left: hsticker.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: stack.width - hsticker.width - 14 - 84 - 14
                spacing: 0

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.dateTitle
                    color: mt.ink
                    font.family: mt.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                Text {
                    visible: root.dateSub !== ""
                    text: root.dateSub
                    color: mt.inkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Item {
                id: switchSlot
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 84
                height: 30

                AmPmSwitch {
                    anchors.fill: parent
                    full: ClockService.use24h
                    pm: root.pm
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ClockService.toggleFormat()
                }
            }
        }

        // ===== the stage: keys, beat, ripple =====
        Item {
            id: stage
            width: stack.width
            height: 100

            // Faint lane lines behind the keys, one per key.
            Repeater {
                model: 4

                Rectangle {
                    required property int index
                    // Keys are 57 wide with 6 between, and the beat column is 24 wide.
                    readonly property real rowW: 4 * 57 + 24 + 4 * 6
                    readonly property real laneLeft: (stage.width - rowW) / 2
                    x: laneLeft + (index < 2 ? index * 63 : 2 * 63 + 24 + 6 + (index - 2) * 63) + 27 - 1
                    y: 0
                    width: 2
                    height: stage.height
                    radius: 1
                    color: mt.surfaceDivider
                }
            }

            // The beat ring: starts at the lit diamond each second and grows
            // and fades. Drawn behind the keys.
            Rectangle {
                id: ripple
                property real r: 10
                property real cy: stage.height / 2
                width: ripple.r * 2
                height: ripple.r * 2
                x: stage.width / 2 - ripple.r
                y: ripple.cy - ripple.r
                radius: ripple.r
                color: "transparent"
                border.width: 3
                border.color: root.secs % 2 === 0 ? mt.accentMint : mt.accentCyan
                opacity: 0
            }

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "r"; from: 10; to: 48; duration: 560; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 0.85; to: 0; duration: 560; easing.type: Easing.OutQuad }
            }

            Connections {
                target: root
                function onSecsChanged() {
                    ripple.cy = stage.height / 2 + (root.secs % 2 === 0 ? -14 : 14)
                    rippleAnim.restart()
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: stage.height
                spacing: 6

                // 12h mode: a leading zero is ghosted, not removed, so
                // nothing moves.
                KeyTile {
                    y: 4
                    digit: root.hh.charAt(0)
                    ghost: !ClockService.use24h && root.hh.charAt(0) === "0"
                    tilt: -2.5
                }

                KeyTile {
                    y: 4 + 10
                    digit: root.hh.charAt(1)
                    tilt: -1
                }

                // The beat: two diamonds that take turns.
                Item {
                    width: 24
                    height: stage.height

                    BeatDiamond {
                        x: 6
                        y: stage.height / 2 - 14 - 6
                        lit: root.secs % 2 === 0
                        litColor: mt.accentMint
                    }

                    BeatDiamond {
                        x: 6
                        y: stage.height / 2 + 14 - 6
                        lit: root.secs % 2 !== 0
                        litColor: mt.accentCyan
                    }
                }

                KeyTile {
                    y: 4 + 10
                    gradientFill: true
                    digit: root.mm.charAt(0)
                    tilt: 1
                }

                KeyTile {
                    y: 4
                    gradientFill: true
                    digit: root.mm.charAt(1)
                    tilt: 2.5
                }
            }
        }

        // ===== the lane: zone chip, minute track, seconds =====
        Item {
            id: lane
            width: stack.width
            height: 30

            ZoneChip {
                id: zoneChip
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: root.zoneLabel
                ink: root.glow
                pressed: zoneArea.pressed
            }

            MouseArea {
                id: zoneArea
                anchors.fill: zoneChip
                cursorShape: Qt.PointingHandCursor
                onClicked: root.zoneIdx = (root.zoneIdx + 1) % root.zones.length
            }

            SecChip {
                id: secChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                label: root.ss
                ink: root.glow
            }

            Item {
                id: track
                anchors.left: zoneChip.right
                anchors.leftMargin: 12
                anchors.right: secChip.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                height: 20

                readonly property real headSize: 12
                // The playhead is a second ahead, so it is at the far end at :59.
                readonly property real pos: track.width * Math.min(60, root.secs + 1) / 60
                readonly property real headX: Math.min(track.width - track.headSize, Math.max(0, track.pos - track.headSize / 2))

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 12
                    radius: 6
                    color: mt.surfaceDivider
                    border.width: 2
                    border.color: mt.line
                }

                // What has played this minute.
                Rectangle {
                    x: 2
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    radius: 4
                    width: Math.max(0, track.headX + track.headSize / 2 - 2)

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: mt.accentMint }
                        GradientStop { position: 1.0; color: mt.accentCyan }
                    }

                    // At :00 the lane just resets instead of sweeping backwards.
                    Behavior on width {
                        enabled: root.secs !== 0
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                    }
                }

                // Gates at 15 / 30 / 45 s.
                Repeater {
                    model: 3

                    Rectangle {
                        required property int index
                        x: track.width * (index + 1) / 4 - 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 12
                        radius: 1.5
                        color: mt.line
                        opacity: 0.45
                    }
                }

                // The playhead: a diamond note.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: track.headSize
                    height: track.headSize
                    radius: 3
                    rotation: 45
                    color: mt.accentMint
                    border.width: 2
                    border.color: mt.line
                    x: track.headX

                    Behavior on x {
                        enabled: root.secs !== 0
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                    }
                }
            }
        }

        // ===== the week =====
        Row {
            id: week
            width: stack.width
            height: 32
            spacing: 4

            // Sunday = 0 ... Saturday = 6; Qt's firstDayOfWeek is Monday = 1 ... Sunday = 7.
            readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
            readonly property int todayIdx: (root.zoned.getDay() - week.firstDow + 7) % 7

            Repeater {
                model: 7

                DayBadge {
                    required property int index
                    width: (week.width - 6 * week.spacing) / 7
                    height: week.height
                    dow: (week.firstDow + index) % 7
                    today: index === week.todayIdx
                    past: index < week.todayIdx
                }
            }
        }
    }
}
