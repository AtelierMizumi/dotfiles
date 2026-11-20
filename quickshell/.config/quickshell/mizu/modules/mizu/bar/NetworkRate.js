function format(bytesPerSecond) {
    const rate = Math.max(0, bytesPerSecond || 0)
    if (rate >= 1048576)
        return (rate / 1048576).toFixed(1) + " MB/s"
    if (rate >= 1024)
        return Math.round(rate / 1024) + " KB/s"
    return Math.round(rate) + " B/s"
}

if (typeof module !== "undefined") module.exports = { format }
