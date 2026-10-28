// Unit tests of BrightnessMath.js — the KDE-style ratio logic that BrightnessService.qml runs its keyboard steps and
// sliders through. The load-bearing cases are the ones the feature exists for: a global change keeps the ratios between
// monitors, (100%, 50%) halved is (50%, 25%), and the round trip restores the start.
// Run: node brightness_math_unit.js   (or tests/test_mizu_js.sh)
const assert = require("assert")
const BM = require(require("../lib/locate.js")("modules/common/functions/BrightnessMath.js"))

const two = [{ name: "eDP-1", percent: 100 }, { name: "HDMI-A-1", percent: 50 }]

// ===== globalPercent =====
assert.strictEqual(BM.globalPercent(two), 100, "global = brightest monitor")
assert.strictEqual(BM.globalPercent([]), 0, "no monitors = 0")

// ===== scaleAll: the ratio guarantee =====
assert.deepStrictEqual(BM.scaleAll(two, 50), [
    { name: "eDP-1", percent: 50 }, { name: "HDMI-A-1", percent: 25 }
], "halving the global halves every monitor proportionally")
assert.deepStrictEqual(BM.scaleAll(BM.scaleAll(two, 50), 100), two,
    "down then up restores the start exactly (no drift)")
assert.deepStrictEqual(BM.scaleAll(two, 100), two, "scale to current global is a no-op")

// Ratio survives across several moves, including past a different reference monitor.
let ms = BM.scaleAll(two, 40)                       // (40, 20)
assert.deepStrictEqual(BM.setOne(ms, "HDMI-A-1", 10).map(m => m.percent), [40, 10], "independent slider touches one monitor")
ms = BM.setOne(ms, "HDMI-A-1", 10)
assert.deepStrictEqual(BM.globalPercent(ms), 40, "a dimmer monitor does not move the global")
ms = BM.setOne(ms, "eDP-1", 80)
assert.deepStrictEqual(BM.globalPercent(ms), 80, "raising a monitor above the reference makes it the reference")
assert.deepStrictEqual(BM.scaleAll(ms, 40).map(m => m.percent), [40, 5], "ratios hold after the reference moved")

// All-dark: no ratio information, monitors come up equal.
assert.deepStrictEqual(BM.scaleAll([{ name: "a", percent: 0 }, { name: "b", percent: 0 }], 30), [
    { name: "a", percent: 30 }, { name: "b", percent: 30 }
], "scaling up from all-dark starts equal")
assert.deepStrictEqual(BM.scaleAll(two, 0).map(m => m.percent), [0, 0], "scale to 0 darkens everything")

// ===== stepAll: keyboard steps =====
assert.deepStrictEqual(BM.stepAll(two, -5).map(m => m.percent), [95, 47.5], "one step down scales, not shifts")
assert.deepStrictEqual(BM.stepAll(two, 5), two, "a step up at 100 changes nothing (ratio stays)")
assert.deepStrictEqual(BM.stepAll([{ name: "a", percent: 2 }, { name: "b", percent: 1 }], -5).map(m => m.percent),
    [0, 0], "a step down past the bottom lands at 0, evenly")

// ===== setOne: clamping =====
assert.deepStrictEqual(BM.setOne(two, "HDMI-A-1", 150).map(m => m.percent), [100, 100], "above 100 clamps")
assert.deepStrictEqual(BM.setOne(two, "HDMI-A-1", -3).map(m => m.percent), [100, 0], "below 0 clamps")

console.log("brightness_math_unit ok")
