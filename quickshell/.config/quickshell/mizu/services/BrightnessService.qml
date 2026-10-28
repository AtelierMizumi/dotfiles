pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common/functions/BrightnessMath.js" as BM

// Brightness for every connected monitor at once — OSDSource.qml and
// QuickSource.qml used to each carry a single screen's worth of this.
//
// One entry per controllable monitor in `monitors`:
//   {name, ddc, bus, device, rawMax, percent, fresh, misses}
//   name     the DRM connector, same string as the niri output ("DP-3",
//            "eDP-1") — the key everything else matches on
//   ddc      true: external monitor over DDC/CI (ddcutil, on `bus`)
//            false: laptop panel (brightnessctl, on backlight `device`)
//   percent  0-100, normalized by the monitor's own max — the source of
//            truth, written through on every change and re-read by the
//            poll; real number, rounding happens only at write time
//   fresh    percent came from a real read at least once (ops refuse to
//            move a monitor nobody has measured — see ensureReady)
//   misses   consecutive polls that produced no reading for it; at 2 the
//            monitor leaves the list (unplugged, or its read keeps dying)
//
// Two backends, both optional, discovered in one pass (detectScript):
//   External   ddcutil detect --brief, which names each display's DRM
//              connector and I2C bus — the bus is used directly (-b N)
//              so the slow part of ddcutil is paid once
//   Laptop     /sys/class/backlight, matched to the eDP connector by
//              GPU: a backlight device belongs to the panel only if it
//              sits under the same PCI device as the connector's card.
//              brightnessctl's own default pick is the first device of
//              the class, which on hybrid laptops is often a dGPU's
//              acpi_video that writes but dims nothing.
//
// The global value (what the OSD and the keyboard steps show and move)
// is the brightest monitor's percent, and a global change multiplies
// every monitor by the same factor so the ratios between monitors hold
// — (100%, 50%) halved is (50%, 25%) — exactly the arithmetic in
// BrightnessMath.js. One monitor's slider (the panel) sets just that
// monitor. Everything else here is plumbing: reads and writes go
// through one sh script each (all monitors in parallel), with the same
// optimistic-set-then-debounce and stale-poll generation guards the
// panel's sliders already use.
Singleton {
    id: root

    // ===== state =====
    property var monitors: []
    property var ddcMonitors: []      // [{name, busNum}] from ddcutil detect
    property var backlights: []       // [{connector, device}] eDP → sysfs match
    property bool detected: false
    property bool detecting: false

    // The global value: the brightest monitor's percent (BrightnessMath).
    readonly property real brightness: BM.globalPercent(monitors)

    // One generation per user action; a poll that started before it is
    // stale and must not stomp the optimistic percents (same pollGen/
    // actionGen guard the panel's network/audio poll uses).
    property int opGen: 0
    property int pollGen: 0

    // Per-monitor percents waiting for the debounced write: {name: percent}.
    property var pending: ({})

    // ===== detection =====
    Component.onCompleted: root.redetect()

    // Monitors came or went: the DDC bus list and the eDP→backlight match
    // may both be stale, so run the whole detection again.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.redetect()
        }
    }

    function redetect() {
        if (root.detecting)
            return
        root.detected = false
        root.detecting = true
        detectProc.running = true
    }

    // Runs `then` once detection has landed (immediately when it has).
    // Only the last waiter runs: rapid key presses during the one-shot
    // detect collapse into one.
    property var pendingDetect: null

    function ensureDetected(then) {
        if (root.detected) {
            then()
            return
        }
        root.pendingDetect = then
        if (!root.detecting)
            root.redetect()
    }

    // Internal-panel discovery is instant (sysfs reads); ddcutil detect is
    // the slow part (a few hundred ms per bus), so it's one process for
    // the whole setup, run at startup and again on hotplug — never per
    // poll. The ___MIZU_INTERNAL___ marker splits the two outputs apart:
    // everything before it is our own "conn"/"bl" lines, everything after
    // it is ddcutil's.
    readonly property string detectScript: [
        "command -v ddcutil >/dev/null 2>&1 && timeout 15 ddcutil detect --brief 2>/dev/null",
        "echo ___MIZU_INTERNAL___",
        "for d in /sys/class/drm/card*-eDP-*; do",
        "  [ -e \"$d\" ] || continue",
        "  n=${d#/sys/class/drm/}; n=${n#*-}",
        "  echo \"conn $n $(readlink -f \"$d/device\")\"",
        "done",
        "for b in /sys/class/backlight/*; do",
        "  [ -e \"$b\" ] || continue",
        "  echo \"bl ${b##*/} $(readlink -f \"$b\")\"",
        "done"
    ].join("\n")

    Process {
        id: detectProc
        command: ["sh", "-c", root.detectScript]
        stdout: StdioCollector {
            onStreamFinished: root.applyDetect(text)
        }
    }

    function applyDetect(text) {
        const parts = text.split("___MIZU_INTERNAL___")

        // ddcutil --brief prints one block per display. "Invalid display"
        // blocks (panels without DDC/CI, like this machine's own laptop
        // panel) are skipped: they name a connector that must NOT steal
        // the brightnessctl backend away from the real internal entry.
        const ddc = []
        let cur = null
        const close = () => {
            if (cur && cur.conn !== "" && cur.bus !== "") {
                ddc.push({
                    name: cur.conn.split("-").slice(1).join("-"),   // card1-HDMI-A-1 → HDMI-A-1
                    busNum: cur.bus.split("/dev/i2c-")[1]
                })
            }
            cur = null
        }
        for (const raw of (parts[0] || "").split("\n")) {
            const line = raw.trim()
            if (line.startsWith("Display ")) {
                close()
                cur = { conn: "", bus: "" }
            } else if (line.startsWith("Invalid")) {
                close()
            } else if (cur) {
                if (line.startsWith("DRM connector:"))
                    cur.conn = line.slice("DRM connector:".length).trim()
                else if (line.startsWith("I2C bus:"))
                    cur.bus = line.slice("I2C bus:".length).trim()
            }
        }
        close()

        // Internal-panel discovery: one "conn" line per eDP connector with
        // its GPU device path, one "bl" line per backlight device with
        // theirs. A backlight belongs to the panel only when it sits under
        // the same PCI device as the connector's card. First match wins —
        // some firmware registers two ACPI video devices for one panel,
        // they sort alphabetically and the first is the real one.
        const conns = []
        const bls = []
        for (const line of (parts[1] || "").split("\n")) {
            const p = line.trim().split(/\s+/)
            if (p[0] === "conn" && p.length >= 3)
                conns.push({ name: p[1], gpu: p.slice(2).join(" ") })
            else if (p[0] === "bl" && p.length >= 3)
                bls.push({ device: p[1], path: p.slice(2).join(" ") })
        }
        const backlights = []
        for (const c of conns) {
            const gpu = c.gpu.replace(/\/drm\/card[0-9]+$/, "")
            const bl = bls.find(b => b.path.startsWith(gpu + "/backlight/"))
            if (bl)
                backlights.push({ connector: c.name, device: bl.device })
        }

        root.ddcMonitors = ddc
        root.backlights = backlights
        root.detected = true
        root.detecting = false
        root.rebuild()
        root.refreshAll()
        const cb = root.pendingDetect
        root.pendingDetect = null
        if (cb)
            cb()
    }

    // The monitor list for the screens that exist right now, keeping each
    // screen's last-known percent across rebuilds (hotplug, detection
    // re-runs). Screens with no working backend are left out.
    function rebuild() {
        const prev = {}
        for (const m of root.monitors)
            prev[m.name] = m.percent
        const list = []
        for (const s of Quickshell.screens) {
            const ddc = root.ddcMonitors.find(m => m.name === s.name)
            const bl = root.backlights.find(b => b.connector === s.name)
            let entry = null
            if (ddc)
                entry = { name: s.name, ddc: true, bus: ddc.busNum, device: "" }
            else if (bl)
                entry = { name: s.name, ddc: false, bus: "", device: bl.device }
            if (!entry)
                continue
            entry.rawMax = 100
            entry.percent = prev[s.name] !== undefined ? prev[s.name] : 0
            entry.fresh = false
            entry.misses = 0
            list.push(entry)
        }
        root.monitors = list
    }

    // ===== reading =====
    function refreshAll(then) {
        if (!root.detected || root.monitors.length === 0)
            return
        root.pollGen = root.opGen
        root.refreshScript = root.buildRefreshScript(root.monitors)
        pollProc.pendingCallback = then || null
        pollProc.running = true
    }

    Timer {
        id: settleRead
        interval: 350
        onTriggered: root.refreshAll()
    }

    // One line "<name> <current> <max>" per monitor, all monitors in
    // parallel (& + wait): ddcutil over one bus never waits for another's.
    function buildRefreshScript(monitors) {
        const parts = []
        for (const m of monitors) {
            if (m.ddc) {
                parts.push("timeout 8 ddcutil -b " + m.bus + " getvcp 10 --brief 2>/dev/null"
                    + " | awk '/VCP 10/{print \"" + m.name + "\", $4, $5}' &")
            } else {
                const sel = m.device !== "" ? "-d " + m.device : "--class backlight"
                parts.push("( c=$(brightnessctl " + sel + " g 2>/dev/null)"
                    + "; m=$(brightnessctl " + sel + " m 2>/dev/null)"
                    + "; [ -n \"$c\" ] && [ -n \"$m\" ] && echo \"" + m.name + " $c $m\" ) &")
            }
        }
        parts.push("wait")
        return parts.join("\n")
    }

    property string refreshScript: ""

    Process {
        id: pollProc
        property var pendingCallback: null
        command: ["sh", "-c", root.refreshScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const cb = pollProc.pendingCallback
                pollProc.pendingCallback = null
                if (root.pollGen !== root.opGen) {
                    // A slider or keypress landed while this read was in
                    // flight — it's already stale, so it must not stomp
                    // the optimistic percents; look again once settled.
                    if (cb)
                        cb()
                    root.settleRead.restart()
                    return
                }
                const seen = {}
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/)
                    if (p.length < 3)
                        continue
                    const c = parseFloat(p[1])
                    const mx = parseFloat(p[2])
                    if (isNaN(c) || isNaN(mx) || mx <= 0)
                        continue
                    seen[p[0]] = { pct: c / mx * 100, max: mx }
                }
                root.monitors = root.monitors.map(m => {
                    const s = seen[m.name]
                    if (s)
                        return Object.assign({}, m, { rawMax: s.max, percent: s.pct, fresh: true, misses: 0 })
                    const misses = m.misses + 1
                    // Twice in a row with no answer: unplugged, or the read
                    // keeps dying — take it out rather than scale a value
                    // nobody can see.
                    return misses >= 2 ? null : Object.assign({}, m, { misses: misses })
                }).filter(Boolean)
                if (cb)
                    cb()
            }
        }
    }

    // ===== actions =====

    // Ops refuse to move a monitor that has never been measured (percent
    // would be a blind 0): one read first, then apply whatever we know.
    function ensureReady(then) {
        ensureDetected(() => {
            if (!root.monitors.some(m => !m.fresh)) {
                then()
                return
            }
            root.refreshAll(() => then())
        })
    }

    function brightnessUp() {
        root.step(5)
    }

    function brightnessDown() {
        root.step(-5)
    }

    // BrightnessMath returns plain {name, percent} pairs; pour each pair
    // back into the full monitor entry it came from so bus/device/rawMax
    // survive every operation.
    function merged(monitors, scaled) {
        return monitors.map(m => Object.assign({}, m, scaled.find(s => s.name === m.name)))
    }

    function step(delta) {
        root.ensureReady(() => {
            root.opGen++
            const list = root.merged(root.monitors, BM.stepAll(root.monitors, delta))
            root.markAllPending(list)
            root.monitors = list
            settleWrite.restart()
        })
    }

    function setGlobal(percent) {
        root.ensureReady(() => {
            root.opGen++
            const list = root.merged(root.monitors,
                BM.scaleAll(root.monitors, Math.max(0, Math.min(100, percent))))
            root.markAllPending(list)
            root.monitors = list
            settleWrite.restart()
        })
    }

    // One monitor's own slider. Independent of the rest: only that
    // monitor's percent moves (and it becomes the global reference if it
    // passes the current brightest).
    function setMonitor(name, percent) {
        root.ensureReady(() => {
            root.opGen++
            const list = root.merged(root.monitors, BM.setOne(root.monitors, name, percent))
            const entry = list.find(m => m.name === name)
            if (entry) {
                const next = Object.assign({}, root.pending)
                next[name] = entry.percent
                root.pending = next
            }
            root.monitors = list
            settleWrite.restart()
        })
    }

    function markAllPending(list) {
        const next = Object.assign({}, root.pending)
        for (const m of list)
            next[m.name] = m.percent
        root.pending = next
    }

    // The optimistic percent lands on screen at once; the actual hardware
    // writes go out 80ms after the last move of a burst, all monitors in
    // parallel, and a read-back corrects anything the hardware refused.
    Timer {
        id: settleWrite
        interval: 80
        onTriggered: {
            if (writeProc.running) {
                settleWrite.restart()
                return
            }
            if (Object.keys(root.pending).length === 0)
                return
            root.writeScript = root.buildWriteScript(root.monitors, root.pending)
            root.pending = {}
            writeProc.running = true
        }
    }

    function buildWriteScript(monitors, pending) {
        const parts = []
        for (const m of monitors) {
            const pct = pending[m.name]
            if (pct === undefined)
                continue
            if (m.ddc) {
                const raw = Math.max(1, Math.round(pct / 100 * m.rawMax))
                parts.push("timeout 10 ddcutil -b " + m.bus + " setvcp 10 " + raw + " &")
            } else {
                // A literal 0% can black the panel out on some drivers —
                // 1% is the same dimness without losing the display.
                const p = Math.max(1, Math.round(pct))
                const sel = m.device !== "" ? "-d " + m.device : "--class backlight"
                parts.push("brightnessctl -q " + sel + " s " + p + "% &")
            }
        }
        parts.push("wait")
        return parts.join("\n")
    }

    property string writeScript: ""

    Process {
        id: writeProc
        command: ["sh", "-c", root.writeScript]
        onExited: root.refreshAll()
    }
}
