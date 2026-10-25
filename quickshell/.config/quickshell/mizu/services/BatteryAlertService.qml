import Quickshell
import Quickshell.Io
import QtQuick
import "../modules/common/functions/BatteryAlertMath.js" as BA

// Low-battery warnings, sent as ordinary notifications (the shell is the notification
// daemon, so they land in the Quick Panel's list like any other, with the shell's own
// badge). The rules are in BatteryAlertMath.js:
//
//   20 %  "Battery low", plug in soon
//   15 %  "Battery low", plug in soon
//   10 %  "Battery very low", critical
//    5 %  "Battery critical", critical
//
// Each level is announced once per discharge; plugging in starts over. Critical ones
// break through do-not-disturb and "Quiet while fullscreen" (NotificationSource.qml); the
// 20 / 15 % ones respect them, and still wait in the list. Settings > General > Time &
// alerts > "Low battery warnings" switches all of it off ("battery.alerts").
//
// A desktop has no battery: BatterySource.available stays false and nothing here ever
// runs. Nothing polls either, it only reacts when UPower changes the reading.
//
// Testing without draining the battery:
//   qs ipc call battery simulate 25    pretend 25 % on battery (re-arms)
//   qs ipc call battery simulate 19    -> "Battery low" (20)
//   qs ipc call battery simulate 14    -> "Battery low" (15)
//   qs ipc call battery simulate 9     -> "Battery very low" (10, critical)
//   qs ipc call battery simulate 4     -> "Battery critical" (5, critical)
//   qs ipc call battery simulate off   back to the real battery
//   qs ipc call battery preview 15     send one level's text, no state
//   qs ipc call battery status
Scope {
    id: root

    readonly property bool enabled: SettingsService.flag("battery.alerts")

    // -1: the real battery. 0..100: pretend that is the percentage, on battery (the test above).
    property int simulated: -1
    readonly property bool simulating: simulated >= 0

    BatterySource {
        id: battery
    }

    readonly property bool present: simulating || battery.available
    readonly property int percent: simulating ? simulated : battery.percentage
    readonly property bool plugged: simulating ? false : battery.isPluggedIn
    readonly property string timeLeft: simulating ? "" : battery.timeRemaining

    // The lowest level announced since the last charge, and whether a reading has
    // been judged yet (the first one only remembers, see BatteryAlertMath.decide).
    property int fired: BA.NONE
    property bool seen: false

    // UPower may still say 0 % for a moment after the shell starts; wait it out instead
    // of announcing an empty battery.
    property bool warm: false

    Timer {
        interval: 4000
        running: true
        onTriggered: root.warm = true
    }

    function check() {
        if (!root.enabled || !root.warm || !root.present || root.percent <= 0)
            return
        const r = BA.decide(root.percent, root.plugged, root.fired, !root.seen)
        root.seen = true
        root.fired = r.fired
        if (r.level > 0)
            root.send(r.level, root.percent, root.timeLeft)
    }

    function send(level, pct, time) {
        const m = BA.message(level, pct, time)
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", m.urgency, "-i", "material:battery_alert", m.title, m.body])
    }

    onPercentChanged: root.check()
    onPluggedChanged: root.check()
    onWarmChanged: root.check()
    onEnabledChanged: root.check()
    onPresentChanged: root.check()

    IpcHandler {
        target: "battery"

        // `simulate 19` pretends 19 % on battery; `simulate off` goes back to the real one.
        function simulate(percent: string): string {
            if (percent === "off") {
                root.simulated = -1
                root.fired = BA.NONE
                root.check()
                return "real battery"
            }
            const n = parseInt(percent)
            if (isNaN(n) || n < 1 || n > 100)
                return "give a percentage from 1 to 100, or off"
            root.warm = true
            root.seen = true
            root.simulated = n
            // Same value as before: no change signal, so judge it here.
            root.check()
            return "pretending " + n + "% on battery"
        }

        // The notification for one level, as if the battery had just reached it.
        function preview(level: int): string {
            if (BA.LEVELS.indexOf(level) < 0)
                return "levels: " + BA.LEVELS.join(", ")
            root.send(level, level, "")
            return "sent " + level
        }

        function status(): string {
            return JSON.stringify({
                enabled: root.enabled,
                present: root.present,
                simulating: root.simulating,
                percent: root.percent,
                plugged: root.plugged,
                fired: root.fired === BA.NONE ? "none yet" : root.fired
            })
        }
    }
}
