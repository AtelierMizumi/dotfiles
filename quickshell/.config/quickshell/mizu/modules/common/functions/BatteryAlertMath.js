.pragma library

// The rules behind the low-battery notifications (services/BatteryAlertService.qml).
// No QML here, so tests/battery-alert-test can run them under node.
//
// A warning goes out the first time the battery, running down on its own, reaches
// each of LEVELS. Plugging in forgets what was said, so the next discharge starts
// again from 20 %. Levels from CRITICAL_AT down are sent as critical: the shell's
// notification daemon lets those through do-not-disturb and "Quiet while fullscreen"
// (NotificationSource.qml), the level where a game or a movie should stop to say so.
var LEVELS = [20, 15, 10, 5];
var CRITICAL_AT = 10;

// Nothing is "fired" yet. Above every level, so any level counts as new.
var NONE = 101;

// The battery has to climb this far above the top level to count as recharged without
// a charger being reported (a dock that does not say "charging"). Without the gap a
// reading that wobbles 20 / 21 / 20 would warn again each time it came back.
var REARM_ABOVE = LEVELS[0] + 2;

// The lowest level that `pct` has reached (19 -> 20, 14 -> 15, 9 -> 10, 3 -> 5), or 0
// when it is above all of them.
function levelFor(pct) {
    var hit = 0;
    for (var i = 0; i < LEVELS.length; i++) {
        if (pct <= LEVELS[i])
            hit = LEVELS[i];
    }
    return hit;
}

function isCritical(level) {
    return level > 0 && level <= CRITICAL_AT;
}

// One reading in, what to do out.
//   pct      battery percentage, 0..100 (0 is taken as "not read yet", never as empty)
//   plugged  a charger is connected
//   fired    the lowest level already announced since the last charge (NONE at first)
//   first    this is the first reading since the shell started
// Returns { level, fired }: `level` is the warning to send now (0: none), `fired` is what
// to remember for the next reading.
//
// On the first reading a normal-level warning is not sent, only remembered: the shell was
// just (re)started at 18 %, which the red bar icon already says, and a shell reload should
// not repeat what was said before it. A critical level is always sent.
function decide(pct, plugged, fired, first) {
    if (!(pct > 0))
        return { level: 0, fired: fired };
    if (plugged || pct > REARM_ABOVE)
        return { level: 0, fired: NONE };
    var level = levelFor(pct);
    if (level === 0 || level >= fired)
        return { level: 0, fired: fired };
    if (first && !isCritical(level))
        return { level: 0, fired: level };
    return { level: level, fired: level };
}

// The text of a warning. `pct` is the real reading (it may have skipped a level), `time`
// is BatterySource.timeRemaining ("1h 12m", or "" when UPower has no estimate yet).
// Returns { title, body, urgency } with urgency as notify-send spells it.
function message(level, pct, time) {
    var left = pct + "% left" + (time ? ", about " + time : "");
    if (level <= 5)
        return { title: "Battery critical", body: left + ". Plug in now or save your work: the laptop may shut down.", urgency: "critical" };
    if (isCritical(level))
        return { title: "Battery very low", body: left + ". Plug in now.", urgency: "critical" };
    return { title: "Battery low", body: left + ". Plug in soon.", urgency: "normal" };
}
