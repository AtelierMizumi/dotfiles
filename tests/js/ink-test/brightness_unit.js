// The picture samplers that pick light or dark ink over a wallpaper (the launcher's LauncherLcd.qml and the quick panel's
// banner in QuickPanelFace.qml) each carry a `brightness(ctx, x, y, w, h)` function. When the canvas hands back no
// pixels (all alpha 0, which is what it does when drawImage had nothing to draw) it used to answer 1 = "white", so dark
// ink was chosen on a dark picture and the clock and date vanished. No data must be reported as -1, never as a colour.
// Run: node brightness_unit.js
const fs = require("fs")
const assert = require("assert")
const locate = require("../lib/locate.js")

// The source text of `function brightness(...) { ... }`, cut out by matching braces.
function extract(file) {
    const text = fs.readFileSync(locate(file), "utf8")
    const start = text.indexOf("function brightness(")
    assert.ok(start >= 0, file + ": no brightness function")
    let depth = 0
    for (let i = text.indexOf("{", start); i < text.length; i++) {
        if (text[i] === "{") depth++
        if (text[i] === "}" && --depth === 0) return text.slice(start, i + 1)
    }
    throw new Error(file + ": unbalanced braces")
}

const ctxWith = pixels => ({ getImageData: () => ({ data: Uint8ClampedArray.from(pixels.flat()) }) })
const transparent = ctxWith([[0, 0, 0, 0], [0, 0, 0, 0]])
const black = ctxWith([[0, 0, 0, 255], [0, 0, 0, 255]])
const white = ctxWith([[255, 255, 255, 255], [255, 255, 255, 255]])
const half = ctxWith([[255, 255, 255, 255], [0, 0, 0, 255]])

for (const file of ["modules/mizu/launcher/LauncherLcd.qml", "modules/mizu/quickPanel/QuickPanelFace.qml"]) {
    const brightness = new Function("return " + extract(file).replace("function brightness", "function"))()
    assert.strictEqual(brightness(transparent, 0, 0, 1, 1), -1, file + ": no pixels must be reported as -1")
    assert.ok(brightness(black, 0, 0, 1, 1) < 0.01, file + ": black")
    assert.ok(brightness(white, 0, 0, 1, 1) > 0.99, file + ": white")
    const mid = brightness(half, 0, 0, 1, 1)
    assert.ok(mid > 0.4 && mid < 0.6, file + ": half black, half white is about 0.5 (got " + mid + ")")
}

console.log("brightness_unit ok")
