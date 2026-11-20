// Group only visible announcements; each original stays in notification history.
function add(current, entry, limit) {
    const name = (entry.app || "").trim().toLowerCase()
    const removed = []
    let count = 1
    const rest = []
    for (const old of current) {
        const sameApp = name !== "" && (old.app || "").trim().toLowerCase() === name
        // A normal notification must never replace a critical one.
        if (sameApp && (old.urgency === 2) === (entry.urgency === 2)) {
            count += old.groupCount || 1
            removed.push(old)
        } else {
            rest.push(old)
        }
    }
    const list = [Object.assign({}, entry, { groupCount: count })].concat(rest)
    while (list.length > limit)
        removed.push(list.pop())
    return { list: list, removed: removed }
}

function readMs(entry) {
    const ms = 3500 + (entry.title.length + entry.body.length) * 45 + (entry.urgency === 2 ? 4000 : 0)
    return Math.min(12000, Math.max(entry.urgency === 2 ? 8500 : 5000, ms))
}

if (typeof module !== "undefined") module.exports = { add, readMs }
