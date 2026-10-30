import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Item {
    id: root

    property var launcher: null
    property var quickPanel: null

    IpcHandler {
        target: "mizu"

        // Live wallpaper host (mizu-l2d): comma-separated screen names it draws on; "" hands them back.
        function liveWallpaper(screens: string): void {
            WallpaperService.liveScreens = screens === "" ? [] : screens.split(",").map(s => s.trim())
        }

        function l2dEnable(on: bool): void {
            L2dService.setEnabled(on)
        }

        function l2dToggle(): void {
            L2dService.toggle()
        }

        function l2dModel(prefab: string): void {
            L2dService.setModel(prefab)
        }

        function launcher(): void {
            if (!root.launcher) return
            if (root.launcher.open) {
                root.launcher.close()
            } else {
                root.launcher.openOn(Compositor.focusedScreen())
            }
        }

        function quick(): void {
            if (!root.quickPanel) return
            root.quickPanel.toggleOn(Compositor.focusedScreen())
        }

        function settings(): void {
            if (!root.quickPanel) return
            if (root.quickPanel.settingsOpen) {
                root.quickPanel.close()
            } else {
                root.quickPanel.openSettings(Compositor.focusedScreen())
            }
        }

        function clipboard(): void {
            if (!root.launcher) return
            if (root.launcher.open) {
                root.launcher.close()
            } else {
                root.launcher.openWithText(Compositor.focusedScreen(), "clip ")
            }
        }

        function dnd(): void {
            QuickSource.toggleNotifications()
        }

        function lock(): void {
            LockState.lock()
        }

        function volumeUp(): void {
            OSDSource.volumeUp()
        }

        function volumeDown(): void {
            OSDSource.volumeDown()
        }

        function volumeMute(): void {
            OSDSource.toggleMute()
        }

        function micMute(): void {
            OSDSource.toggleMicMute()
        }

        function brightnessUp(): void {
            OSDSource.brightnessUp()
        }

        function brightnessDown(): void {
            OSDSource.brightnessDown()
        }

        function mediaPlay(): void {
            MediaSource.togglePlaying()
        }

        function mediaNext(): void {
            MediaSource.next()
        }

        function mediaPrev(): void {
            MediaSource.previous()
        }

        function wallpaperNext(): void {
            WallpaperService.next(1)
        }

        function wallpaper(path: string): void {
            WallpaperService.setWallpaper(path, "")
        }

        function palette(): void {
            WallpaperService.runPalette()
        }
    }
}
