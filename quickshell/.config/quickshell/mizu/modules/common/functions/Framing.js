.pragma library

// How each of the shell's own pictures (the Quick Panel's banner and avatar, the phone's
// wallpaper: PanelImages.qml) is framed in its slot: which part shows. The same three numbers
// the Custom Image widget's CROP mode uses (ImageMath.drawRect draws with them):
//   zoom   1..6, 1 = the picture just covers the slot
//   panX   -1..1, -1 = its left edge, 0 = centred, 1 = its right edge
//   panY   the same, top to bottom
// { zoom: 1, panX: 0, panY: 0 } is exactly what the shell drew before framing existed
// (fillMode PreserveAspectCrop), so a picture nobody framed looks as it always did.
//
// Stored in the setting `pictures.framing` as JSON, one entry per kind:
//   { "banner": { "file": "banner-1792536409.jpg", "zoom": 1.6, "panX": 0.8, "panY": -0.3 }, ... }
// `file` is the picture's own name in the data folder (pick-image.sh names each copy
// <kind>-<epoch>.<ext>), so a framing belongs to one picture: picking another one, or a
// preset putting its own copy back, starts centred unless a framing comes with it.
//
// No QML here: tests/framing-test/framing_unit.js runs it under node.

var KINDS = ["banner", "avatar", "phone"]
var MAX_ZOOM = 6
var CENTRED = { zoom: 1, panX: 0, panY: 0 }

function clamp(v, lo, hi) {
    v = Number(v)
    if (!isFinite(v))
        return lo
    return Math.max(lo, Math.min(hi, v))
}

// A framing with every number in range (anything missing or broken: centred).
function normalize(f) {
    if (!f || typeof f !== "object")
        return { zoom: 1, panX: 0, panY: 0 }
    return {
        zoom: clamp(f.zoom === undefined ? 1 : f.zoom, 1, MAX_ZOOM),
        panX: f.panX === undefined ? 0 : clamp(f.panX, -1, 1),
        panY: f.panY === undefined ? 0 : clamp(f.panY, -1, 1)
    }
}

function isCentred(f) {
    var n = normalize(f)
    return Math.abs(n.zoom - 1) < 1e-6 && Math.abs(n.panX) < 1e-6 && Math.abs(n.panY) < 1e-6
}

function same(a, b) {
    var x = normalize(a), y = normalize(b)
    return Math.abs(x.zoom - y.zoom) < 1e-6 && Math.abs(x.panX - y.panX) < 1e-6 && Math.abs(x.panY - y.panY) < 1e-6
}

// "/home/me/.local/share/sekaipop/banner-17.jpg" -> "banner-17.jpg"
function baseName(path) {
    var s = String(path || "")
    var i = s.lastIndexOf("/")
    return i >= 0 ? s.slice(i + 1) : s
}

// The setting's text -> { kind: { file, zoom, panX, panY } }, dropping what does not fit.
function parse(text) {
    var raw
    try {
        raw = typeof text === "string" && text !== "" ? JSON.parse(text) : {}
    } catch (e) {
        raw = {}
    }
    var out = {}
    if (!raw || typeof raw !== "object")
        return out
    for (var i = 0; i < KINDS.length; i++) {
        var k = KINDS[i]
        var e = raw[k]
        if (!e || typeof e !== "object" || typeof e.file !== "string" || e.file === "")
            continue
        var n = normalize(e)
        out[k] = { file: e.file, zoom: n.zoom, panX: n.panX, panY: n.panY }
    }
    return out
}

function stringify(map) {
    var keys = Object.keys(map || {})
    return keys.length > 0 ? JSON.stringify(map) : ""
}

// The framing of the picture at `path` (centred unless one was saved for this very file).
function forPicture(map, kind, path) {
    var e = map ? map[kind] : null
    if (!e || !path || e.file !== baseName(path))
        return normalize(null)
    return normalize(e)
}

// The map with `kind`'s picture at `path` framed `f`. A centred framing (or no picture)
// removes the entry, so the setting only holds what differs from the default.
function withFraming(map, kind, path, f) {
    var out = {}
    var keys = Object.keys(map || {})
    for (var i = 0; i < keys.length; i++)
        if (keys[i] !== kind)
            out[keys[i]] = map[keys[i]]
    if (path && !isCentred(f)) {
        var n = normalize(f)
        out[kind] = { file: baseName(path), zoom: round(n.zoom), panX: round(n.panX), panY: round(n.panY) }
    }
    return out
}

function round(v) {
    return Math.round(v * 1000) / 1000
}

// One zoom step of the framer's keys (+ / - and the round keys): 0.25, kept in range.
function stepZoom(zoom, dir) {
    return Math.round(clamp(zoom + 0.25 * dir, 1, MAX_ZOOM) * 100) / 100
}

// One mouse-wheel notch: 8 % in or out, as the design has it.
function wheelZoom(zoom, up) {
    return Math.round(clamp(zoom * (up ? 1.08 : 1 / 1.08), 1, MAX_ZOOM) * 100) / 100
}

// The zoom as the slider shows it: 0..1 along its track.
function zoomFraction(zoom) {
    return (clamp(zoom, 1, MAX_ZOOM) - 1) / (MAX_ZOOM - 1)
}

function zoomFromFraction(t) {
    return Math.round((1 + clamp(t, 0, 1) * (MAX_ZOOM - 1)) * 20) / 20
}

// "1.60×"
function zoomText(zoom) {
    return clamp(zoom, 1, MAX_ZOOM).toFixed(2) + "×"
}

if (typeof module !== "undefined")
    module.exports = { KINDS: KINDS, MAX_ZOOM: MAX_ZOOM, normalize: normalize, isCentred: isCentred, same: same,
                       baseName: baseName, parse: parse, stringify: stringify, forPicture: forPicture,
                       withFraming: withFraming, stepZoom: stepZoom, wheelZoom: wheelZoom,
                       zoomFraction: zoomFraction, zoomFromFraction: zoomFromFraction, zoomText: zoomText }
