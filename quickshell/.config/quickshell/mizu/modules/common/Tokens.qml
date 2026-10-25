pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's colors, read from ~/.cache/mizu/tokens.json (schema mizu.tokens/1), which the palette tool
// (palette/mizu_palette.py) writes from the current wallpaper. Nothing else in the shell holds a color of its own:
// ThemeSet.qml maps its old role names onto these.
//
// - The file is watched. The tool replaces it atomically, so a change always arrives as a whole file.
// - A file that is missing, unreadable, from another schema or with a color that is not plain #rrggbb is ignored and
//   the last good tokens (at first the neutral defaults below) stay in use.
// - A change fades in: `blend` runs from 0 to 1 over 450 ms and every color is the mix of the previous tokens and the
//   new ones. (One animated number, not a `Behavior` per color: a Behavior declared on a property of a Singleton
//   crashes Qt 6.12's QML engine here.)
Singleton {
    id: root

    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string path: root.cacheHome + "/mizu/tokens.json"

    // True once a tokens file has been read and accepted (the defaults are in use until then).
    property bool loaded: false
    readonly property int fadeMs: 450

    readonly property var defaults: ({
        schema: "mizu.tokens/1", wallpaper: "", scheme: "faithful", mode: "dark",
        color: {
            accent: "#7aa7ff", accent2: "#b79cff", outline: "#0f1114", line: "#6b7280", shadow: "#07080a",
            surface: "#1c1f24", surfaceHover: "#262a30", surfaceDivider: "#3a3f47", surfaceRing: "#33373e",
            ring: "#485978", ink: "#e3e6ea", inkMuted: "#b4bac2", onAccent: "#0b1b3a", chip: "#2c3a52",
            onChip: "#d3e0f7", scrim: "#000000", hoverTint: "#232c3d", paper: "#181b1f", danger: "#ff6b7a",
            warning: "#e0b252", series: ["#7aa7ff", "#9aa5b8", "#b79cff", "#ff6b7a", "#b79cff"]
        },
        surface: {
            bar: { housing: "#1c1f24", alpha: 0.7 },
            phone: { housing: "#1c1f24", alpha: 0.7 },
            widget: { housing: "#1c1f24", alpha: 0.7 }
        },
        phone: {
            rimHighlight: "#33373e", bezel: "#000000", wallLight: "#262a30", wallMid: "#1c1f24",
            wallDark: "#181b1f", hardware: "#3a3f47", lens: "#0f1114", lensGlint: "#e3e6ea", shadowAlpha: 0.17
        }
    })

    // The tokens in use (the target of the fade) and the ones the fade starts from.
    property var data: root.defaults
    property var previous: root.defaults
    property real blend: 1

    function mix(from, to, t) {
        const a = Qt.color(from)
        const b = Qt.color(to)
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    function pick(source, group, key) {
        const g = source[group]
        return (g && g[key] !== undefined) ? g[key] : root.defaults[group][key]
    }

    // A color of `group` ("color" or "phone"), faded between the previous and the current tokens.
    function faded(group, key) {
        return root.mix(root.pick(root.previous, group, key), root.pick(root.data, group, key), root.blend)
    }

    function fadedHousing(name) {
        return root.mix(root.previous.surface[name].housing, root.pick(root.data, "surface", name).housing, root.blend)
    }

    function surfaceAlpha(name) {
        const s = root.data.surface
        return (s && s[name] && typeof s[name].alpha === "number") ? s[name].alpha : root.defaults.surface[name].alpha
    }

    readonly property string mode: root.data.mode === "light" ? "light" : "dark"
    readonly property bool dark: root.mode === "dark"

    readonly property color accent: root.faded("color", "accent")
    readonly property color accent2: root.faded("color", "accent2")
    readonly property color outline: root.faded("color", "outline")
    readonly property color line: root.faded("color", "line")
    readonly property color shadow: root.faded("color", "shadow")
    readonly property color surface: root.faded("color", "surface")
    readonly property color surfaceHover: root.faded("color", "surfaceHover")
    readonly property color surfaceDivider: root.faded("color", "surfaceDivider")
    readonly property color surfaceRing: root.faded("color", "surfaceRing")
    readonly property color ring: root.faded("color", "ring")
    readonly property color ink: root.faded("color", "ink")
    readonly property color inkMuted: root.faded("color", "inkMuted")
    readonly property color accentInk: root.faded("color", "onAccent")
    readonly property color chip: root.faded("color", "chip")
    readonly property color chipInk: root.faded("color", "onChip")
    readonly property color scrim: root.faded("color", "scrim")
    readonly property color hoverTint: root.faded("color", "hoverTint")
    readonly property color paper: root.faded("color", "paper")
    readonly property color danger: root.faded("color", "danger")
    readonly property color warning: root.faded("color", "warning")
    readonly property var series: root.data.color && root.data.color.series ? root.data.color.series
                                                                             : root.defaults.color.series

    readonly property color phoneRimHighlight: root.faded("phone", "rimHighlight")
    readonly property color phoneBezel: root.faded("phone", "bezel")
    readonly property color phoneWallLight: root.faded("phone", "wallLight")
    readonly property color phoneWallMid: root.faded("phone", "wallMid")
    readonly property color phoneWallDark: root.faded("phone", "wallDark")
    readonly property color phoneHardware: root.faded("phone", "hardware")
    readonly property color phoneLens: root.faded("phone", "lens")
    readonly property color phoneLensGlint: root.faded("phone", "lensGlint")
    readonly property real phoneShadowAlpha: root.pick(root.data, "phone", "shadowAlpha")

    // How the palette tool fitted each surface to the wallpaper behind it: housing color and opacity.
    readonly property color barHousing: root.fadedHousing("bar")
    readonly property real barAlpha: root.surfaceAlpha("bar")
    readonly property color phoneHousing: root.fadedHousing("phone")
    readonly property real phoneAlpha: root.surfaceAlpha("phone")
    readonly property color widgetHousing: root.fadedHousing("widget")
    readonly property real widgetAlpha: root.surfaceAlpha("widget")

    function isHex(value) {
        return typeof value === "string" && /^#[0-9a-f]{6}$/.test(value)
    }

    // The same checks the palette tool's own output satisfies (palette_core/build.py): the schema name, every color
    // role of the defaults present as plain #rrggbb, five series colors, and an opacity per surface in 0..1.
    function acceptable(t) {
        if (!t || t.schema !== "mizu.tokens/1" || !t.color || !t.phone || !t.surface)
            return false
        for (const key of Object.keys(root.defaults.color)) {
            if (key === "series")
                continue
            if (!root.isHex(t.color[key]))
                return false
        }
        if (!Array.isArray(t.color.series) || t.color.series.length !== 5 || !t.color.series.every(root.isHex))
            return false
        for (const key of Object.keys(root.defaults.phone)) {
            if (key === "shadowAlpha" ? typeof t.phone[key] !== "number" : !root.isHex(t.phone[key]))
                return false
        }
        for (const name of ["bar", "phone", "widget"]) {
            const s = t.surface[name]
            if (!s || !root.isHex(s.housing) || typeof s.alpha !== "number" || s.alpha < 0 || s.alpha > 1)
                return false
        }
        return true
    }

    function apply(text) {
        let parsed = null
        try {
            parsed = JSON.parse(text)
        } catch (e) {
            console.warn("Tokens: " + root.path + " is not valid JSON, keeping the last tokens")
            return
        }
        if (!root.acceptable(parsed)) {
            console.warn("Tokens: " + root.path + " is not a usable mizu.tokens/1 file, keeping the last tokens")
            return
        }
        // The first file read replaces the defaults at once; later ones fade in.
        root.previous = root.loaded ? root.data : parsed
        root.data = parsed
        root.blend = root.loaded ? 0 : 1
        if (root.loaded)
            fade.restart()
        root.loaded = true
    }

    NumberAnimation {
        id: fade
        target: root
        property: "blend"
        from: 0
        to: 1
        duration: root.fadeMs
        easing.type: Easing.InOutQuad
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onLoaded: root.apply(file.text())
        onFileChanged: file.reload()
    }

    // A file that does not exist yet (the first start, before the palette tool has run) cannot be watched: ask again
    // every second until it has been read once.
    Timer {
        interval: 1000
        repeat: true
        running: !root.loaded
        onTriggered: file.reload()
    }
}
