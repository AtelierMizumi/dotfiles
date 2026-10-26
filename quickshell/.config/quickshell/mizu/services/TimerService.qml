pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The shell's Timer / Stopwatch / Pomodoro service.
//
// All three run on the clock (an end time, or a start time, not a count of ticks), so a
// slow frame or a busy shell never makes them drift. They live in memory only: a shell
// reload stops them.
//
//   Timer       counts down from `timerTotal`; notifies at zero.
//   Stopwatch   counts up, with laps.
//   Pomodoro    Focus / Short break / Long break in turn; the next phase starts by itself.
//
Singleton {
    id: root

    // ---- Timer ----
    property real timerTotal: 300          // seconds, what Start counts down from
    property real timerLeft: 300
    property bool timerRunning: false
    property real timerEnd: 0              // ms since epoch while running

    // ---- Stopwatch ----
    property real swElapsed: 0             // seconds
    property bool swRunning: false
    property real swStart: 0               // ms: when it (re)started, less what was already counted
    property var laps: []                  // [seconds, ...] newest first

    // ---- Pomodoro ----
    // phase: "focus" | "short" | "long"
    property string pomPhase: "focus"
    property int pomRound: 1               // which focus round we are in (1..rounds)
    property real pomLeft: root.phaseSeconds("focus")
    property bool pomRunning: false
    property real pomEnd: 0

    readonly property real pomWorkMin: SettingsService.get("timer.pomWork") || 25
    readonly property real pomShortMin: SettingsService.get("timer.pomShort") || 5
    readonly property real pomLongMin: SettingsService.get("timer.pomLong") || 15
    readonly property int pomRounds: Math.max(1, Math.round(SettingsService.get("timer.pomRounds") || 4))

    function phaseSeconds(phase) {
        const m = phase === "focus" ? root.pomWorkMin : (phase === "short" ? root.pomShortMin : root.pomLongMin)
        return Math.max(1, Math.round(m * 60))
    }

    readonly property string phaseLabel: root.pomPhase === "focus" ? "Focus"
        : (root.pomPhase === "short" ? "Short break" : "Long break")

    // ---- what the widget shows ----
    readonly property string shownMode: root.pomRunning ? "pomodoro"
        : (root.timerRunning ? "timer" : (root.swRunning ? "stopwatch" : ""))
    readonly property bool anyRunning: root.shownMode !== ""

    // 0..1, how full the key's fill is.
    readonly property real shownProgress: {
        if (root.shownMode === "pomodoro")
            return 1 - root.pomLeft / root.phaseSeconds(root.pomPhase)
        if (root.shownMode === "timer")
            return root.timerTotal > 0 ? 1 - root.timerLeft / root.timerTotal : 0
        if (root.shownMode === "stopwatch")
            return (root.swElapsed % 60) / 60
        return 0
    }

    // Short text: "24m" / "45s".
    readonly property string shownText: {
        const s = root.shownMode === "pomodoro" ? root.pomLeft
            : (root.shownMode === "timer" ? root.timerLeft : root.swElapsed)
        return root.short(s, root.shownMode === "stopwatch")
    }

    function short(seconds, up) {
        const s = Math.max(0, up ? Math.floor(seconds) : Math.ceil(seconds))
        if (s >= 3600)
            return Math.floor(s / 3600) + "h"
        if (s >= 60)
            return Math.floor(s / 60) + "m"
        return s + "s"
    }

    // 83.4 -> "01:23"
    function clock(seconds, up) {
        const s = Math.max(0, up ? Math.floor(seconds) : Math.ceil(seconds))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const r = s % 60
        const two = n => (n < 10 ? "0" : "") + n
        return (h > 0 ? h + ":" + two(m) : two(m)) + ":" + two(r)
    }

    // ===== Timer =====
    function setTimerMinutes(min) {
        if (root.timerRunning)
            return
        root.timerTotal = Math.max(1, Math.round(min * 60))
        root.timerLeft = root.timerTotal
    }

    function addTimerMinute() {
        root.timerTotal += 60
        root.timerLeft += 60
        if (root.timerRunning)
            root.timerEnd += 60000
    }

    function toggleTimer() {
        if (root.timerRunning) {
            root.timerLeft = Math.max(0, (root.timerEnd - Date.now()) / 1000)
            root.timerRunning = false
        } else {
            if (root.timerLeft <= 0)
                root.timerLeft = root.timerTotal
            root.timerEnd = Date.now() + root.timerLeft * 1000
            root.timerRunning = true
        }
    }

    function resetTimer() {
        root.timerRunning = false
        root.timerLeft = root.timerTotal
    }

    // ===== Stopwatch =====
    function toggleStopwatch() {
        if (root.swRunning) {
            root.swElapsed = (Date.now() - root.swStart) / 1000
            root.swRunning = false
        } else {
            root.swStart = Date.now() - root.swElapsed * 1000
            root.swRunning = true
        }
    }

    function lapStopwatch() {
        if (!root.swRunning && root.swElapsed <= 0)
            return
        const now = root.swRunning ? (Date.now() - root.swStart) / 1000 : root.swElapsed
        root.laps = [now].concat(root.laps).slice(0, 20)
    }

    function resetStopwatch() {
        root.swRunning = false
        root.swElapsed = 0
        root.laps = []
    }

    // ===== Pomodoro =====
    function togglePomodoro() {
        if (root.pomRunning) {
            root.pomLeft = Math.max(0, (root.pomEnd - Date.now()) / 1000)
            root.pomRunning = false
        } else {
            root.pomEnd = Date.now() + root.pomLeft * 1000
            root.pomRunning = true
        }
    }

    function resetPomodoro() {
        root.pomRunning = false
        root.pomPhase = "focus"
        root.pomRound = 1
        root.pomLeft = root.phaseSeconds("focus")
    }

    function nextPhase(keepRunning) {
        if (root.pomPhase === "focus") {
            if (root.pomRound >= root.pomRounds)
                root.pomPhase = "long"
            else
                root.pomPhase = "short"
        } else {
            if (root.pomPhase === "long")
                root.pomRound = 1
            else
                root.pomRound += 1
            root.pomPhase = "focus"
        }
        root.pomLeft = root.phaseSeconds(root.pomPhase)
        if (keepRunning) {
            root.pomEnd = Date.now() + root.pomLeft * 1000
            root.pomRunning = true
        } else {
            root.pomRunning = false
        }
    }

    // ===== notification =====
    function alarm(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Timer", title, body])
    }

    // ===== the clock =====
    Timer {
        interval: 200
        repeat: true
        running: root.timerRunning || root.swRunning || root.pomRunning
        onTriggered: {
            const now = Date.now()
            if (root.timerRunning) {
                const left = (root.timerEnd - now) / 1000
                if (left <= 0) {
                    root.timerLeft = 0
                    root.timerRunning = false
                    root.alarm("Timer finished", "Time is up!")
                } else {
                    root.timerLeft = left
                }
            }
            if (root.swRunning)
                root.swElapsed = (now - root.swStart) / 1000
            if (root.pomRunning) {
                const left = (root.pomEnd - now) / 1000
                if (left <= 0) {
                    const finishedPhase = root.pomPhase
                    root.nextPhase(true)
                    root.alarm(finishedPhase === "focus" ? "Break time!" : "Focus time!",
                               finishedPhase === "focus" ? "Great job. Take a break." : "Time to get back to work.")
                } else {
                    root.pomLeft = left
                }
            }
        }
    }
}
