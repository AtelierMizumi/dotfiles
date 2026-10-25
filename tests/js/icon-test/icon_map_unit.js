// IconMap.candidates (modules/common/functions/IconMap.js): which SVG files MaterialIcon tries before it falls back to
// the Material Symbols font. The mizu fork ships no SVG icon set, so the style "font" must try no file at all;
// otherwise every icon logs "Cannot open .../assets/icons/..." once per attempt. Run: node icon_map_unit.js
const fs = require("fs")
const assert = require("assert")
const locate = require("../lib/locate.js")

const src = fs.readFileSync(locate("modules/common/functions/IconMap.js"), "utf8").replace(".pragma library", "")
const I = {}
new Function("I", src + ";I.candidates=candidates;")(I)

// 1. an SVG style still lists its files in the order to try (outline first, bold last)
assert.deepStrictEqual(I.candidates("lock", false, "outline"), ["icons/outline/lock.svg", "icons/bold/lock.svg"])

// 2. filled icons try the bold set first
assert.strictEqual(I.candidates("lock", true, "outline")[0], "icons/bold/lock.svg")

// 3. the font style tries no file, for filled and unfilled icons and for a mapped or an unmapped name
for (const name of ["lock", "wifi_off", "no_such_icon_name"])
    for (const filled of [false, true])
        assert.deepStrictEqual(I.candidates(name, filled, "font"), [], name + " filled=" + filled)

// 4. the theme asks for it: ThemeSet.qml names the font as the icon style
const theme = fs.readFileSync(locate("modules/common/ThemeSet.qml"), "utf8")
assert.match(theme, /readonly property string iconStyle: "font"/)

// 5. no icon file is shipped, so nothing may ask for one by default
assert.ok(!fs.existsSync(locate("assets/images").replace(/images$/, "icons")), "assets/icons must stay absent")

console.log("icon_map_unit ok")
