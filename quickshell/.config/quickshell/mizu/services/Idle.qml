import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Item {
    id: root

    readonly property int screenOffMinutes: SettingsService.get("idle.screenOffMinutes") ?? 30
    readonly property int lockMinutes: SettingsService.get("idle.lockMinutes") ?? 45

    readonly property int screenOffSeconds: Math.max(0, root.screenOffMinutes * 60)
    readonly property int lockSeconds: Math.max(0, root.lockMinutes * 60)

    IdleMonitor {
        id: screenOffMonitor
        enabled: root.screenOffSeconds > 0
        timeout: root.screenOffSeconds
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                Compositor.powerOffMonitors()
            }
        }
    }

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
}
