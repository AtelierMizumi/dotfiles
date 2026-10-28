// Brightness for several monitors at once, KDE-style ratios.
//
// Each monitor carries its own percent (0-100, normalized by its own
// hardware max, so very different panels can still be "equally bright"
// at the same percent). The global value — what the OSD shows and what
// the keyboard steps move — is the brightest monitor's percent, and a
// global change multiplies every monitor by the same factor instead of
// shifting each one by the same amount, so the ratios between monitors
// hold: (100%, 50%) halved is (50%, 25%), and back up to 100% restores
// (100%, 50%). A fixed-step shift would drag the dimmer monitor to zero
// and lose the ratio forever.
//
// Percents stay real numbers here; rounding happens only where the
// hardware demands it (raw device units at write time), so a
// down-then-up round trip does not drift.
//
// Monitors are plain {name, percent} as far as these functions care —
// a caller's other fields (bus, device, ...) are rebuilt by it.

// The global value: the brightest monitor's percent.
function globalPercent(monitors) {
    let max = 0
    for (const m of monitors)
        max = Math.max(max, m.percent)
    return max
}

// Move the global value to `to` (0-100): scale every monitor by
// to/current-global. All-dark (global 0) carries no ratio information,
// so the monitors simply come up equal at `to`.
function scaleAll(monitors, to) {
    const from = globalPercent(monitors)
    const factor = from > 0 ? to / from : 1
    return monitors.map(m => ({
        name: m.name,
        percent: from > 0 ? m.percent * factor : to
    }))
}

// One keyboard step: `delta` percent on the global value, distributed
// like scaleAll above. At the top (100 + delta) this lands on no
// change, which is what preserves the ratios there too.
function stepAll(monitors, delta) {
    return scaleAll(monitors, Math.max(0, Math.min(100, globalPercent(monitors) + delta)))
}

// One monitor's own slider, independent of the rest: set its percent
// outright. Past the current global value it becomes the new reference
// the OSD shows; the other monitors keep their percents.
function setOne(monitors, name, value) {
    const pct = Math.max(0, Math.min(100, value))
    return monitors.map(m => ({
        name: m.name,
        percent: m.name === name ? pct : m.percent
    }))
}

// node tests can require() this file; QML's engine has no `module`.
if (typeof module !== "undefined")
    module.exports = { globalPercent: globalPercent, scaleAll: scaleAll, stepAll: stepAll, setOne: setOne }
