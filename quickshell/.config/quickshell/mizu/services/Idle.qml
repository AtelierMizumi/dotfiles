import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// The idle timers: lock the session, then turn the screens off. Never suspend —
// builds, downloads and other background work keep running the whole time.
// Both timers respect idle inhibitors, so a video player keeps the session awake.
Item {
    id: root

    readonly property int lockMinutes: SettingsService.get("idle.lockMinutes") ?? 30
    readonly property int screenOffMinutes: SettingsService.get("idle.screenOffMinutes") ?? 45

    readonly property int lockSeconds: Math.max(0, root.lockMinutes * 60)
    readonly property int screenOffSeconds: Math.max(0, root.screenOffMinutes * 60)

    // Lock first: with "Screens off when locking" on, the lock ends in the dark, so this
    // alone is the whole screensaver. While the lockscreen is lit, it is the screensaver.
    IdleMonitor {
        id: lockMonitor
        enabled: root.lockSeconds > 0
        timeout: root.lockSeconds
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                LockState.lock()
            }
        }
    }

    // Keep the standalone screen-off for sessions that never lock (idle.lockMinutes = 0).
    // When locking is on and this fires first anyway (screenOffMinutes < lockMinutes),
    // a dark screen must not be an open one: lock alongside it, so waking the screens
    // always lands on the lockscreen.
    IdleMonitor {
        id: screenOffMonitor
        enabled: root.screenOffSeconds > 0
        timeout: root.screenOffSeconds
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                Compositor.powerOffMonitors()
                if (root.lockSeconds > 0)
                    LockState.lock()
            }
        }
    }
}
