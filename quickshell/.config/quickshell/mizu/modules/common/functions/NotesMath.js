.pragma library

// The maths behind the Sticky Notes widget (services/NotesService.qml keeps the
// notes, StickyNotesWidget.qml / StickyNote.qml draw them). Pure functions on
// plain numbers in DESIGN pixels.

var MAX_NOTES = 12
var MIN_W = 200
var MIN_H = 130
var DEF_W = 240
var DEF_H = 200
var MAX_CHARS = 3000

var COLORS = [
    { id: "yellow",   name: "Yellow" },
    { id: "pink",     name: "Pink" },
    { id: "mint",     name: "Mint" },
    { id: "cyan",     name: "Cyan" },
    { id: "lavender", name: "Lavender" },
    { id: "peach",    name: "Peach" }
]

function validTint(id) {
    for (var i = 0; i < COLORS.length; i++)
        if (COLORS[i].id === id)
            return true
    return false
}

function nextTint(count) {
    return COLORS[((count % COLORS.length) + COLORS.length) % COLORS.length].id
}

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function fit(r, roomW, roomH) {
    var w = clamp(Math.round(r.w), Math.min(MIN_W, roomW), Math.max(1, roomW))
    var h = clamp(Math.round(r.h), Math.min(MIN_H, roomH), Math.max(1, roomH))
    return {
        x: clamp(Math.round(r.x), 0, Math.max(0, roomW - w)),
        y: clamp(Math.round(r.y), 0, Math.max(0, roomH - h)),
        w: w,
        h: h
    }
}

function cascade(n, roomW, roomH) {
    var step = 30
    var k = ((n % 6) + 6) % 6
    return fit({ x: roomW - DEF_W - 80 - k * step, y: 110 + k * step, w: DEF_W, h: DEF_H }, roomW, roomH)
}

function move(start, dx, dy, roomW, roomH) {
    return fit({ x: start.x + dx, y: start.y + dy, w: start.w, h: start.h }, roomW, roomH)
}

function resize(start, dx, dy, edge, roomW, roomH) {
    var w = start.w
    var h = start.h
    if (edge === "r" || edge === "rb")
        w = clamp(start.w + dx, MIN_W, Math.max(MIN_W, roomW - start.x))
    if (edge === "b" || edge === "rb")
        h = clamp(start.h + dy, MIN_H, Math.max(MIN_H, roomH - start.y))
    return fit({ x: start.x, y: start.y, w: w, h: h }, roomW, roomH)
}

function topZ(zs) {
    var m = 0
    for (var i = 0; i < zs.length; i++)
        if (zs[i] > m)
            m = zs[i]
    return m + 1
}

function windowRect(r, ox, oy, k) {
    var x = Math.max(0, Math.round(ox + r.x * k))
    var y = Math.max(0, Math.round(oy + r.y * k))
    return {
        x: x,
        y: y,
        w: Math.max(0, Math.ceil(ox + (r.x + r.w) * k) - x),
        h: Math.max(0, Math.ceil(oy + (r.y + r.h) * k) - y)
    }
}

function cleanNotes(list) {
    var out = []
    if (!Array.isArray(list))
        return out
    var seen = {}
    var num = function (v, d) { return typeof v === "number" && isFinite(v) ? v : d }
    for (var i = 0; i < list.length && out.length < MAX_NOTES; i++) {
        var n = list[i]
        if (!n || typeof n !== "object")
            continue
        var id = typeof n.id === "string" && n.id !== "" ? n.id : "n" + i
        if (seen[id])
            continue
        seen[id] = true
        out.push({
            id: id,
            body: typeof n.body === "string" ? n.body.slice(0, MAX_CHARS) : "",
            tint: validTint(n.tint) ? n.tint : nextTint(i),
            x: num(n.x, 0),
            y: num(n.y, 0),
            w: Math.max(MIN_W, num(n.w, DEF_W)),
            h: Math.max(MIN_H, num(n.h, DEF_H)),
            z: Math.round(num(n.z, i + 1)),
            pinned: n.pinned === true
        })
    }
    return out
}

function parse(text) {
    var out = { shown: true, scale: 0, notes: [], setName: "", sets: {} }
    var s
    try {
        s = JSON.parse(text)
    } catch (e) {
        return out
    }
    if (!s || typeof s !== "object")
        return out
    out.shown = s.shown !== false
    if (typeof s.scale === "number" && s.scale > 0)
        out.scale = s.scale
    out.notes = cleanNotes(s.notes)
    if (typeof s.setName === "string")
        out.setName = s.setName
    if (s.sets && typeof s.sets === "object" && !Array.isArray(s.sets)) {
        var names = Object.keys(s.sets)
        for (var k = 0; k < names.length; k++) {
            var e = s.sets[names[k]]
            if (names[k] === "" || !e || typeof e !== "object")
                continue
            out.sets[names[k]] = { shown: e.shown !== false, notes: cleanNotes(e.notes) }
        }
    }
    return out
}
