pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The two `wl-paste --watch cliphist store` processes (text and images) that fill the
// clipboard history, started ONCE for the whole shell (Settings -> launcher.clipboard).
//
// They used to live in ExtrasSource, which exists twice (the phone launcher and the
// Quick Panel each have one), so every copy was stored twice. And `wl-paste --watch`
// outlives the shell: each restart left the old pair running under init, so after a
// few restarts one copy ran `cliphist store` ten times (an image copy spiked the CPU).
// Now, before starting, any watcher left over from an earlier shell is stopped first.
//
//   import qs.services
//   ClipboardWatcher.watching   // read it once (ExtrasSource does) to start the singleton
Singleton {
    id: root

    property bool available: false
    property bool cleaned: false
    readonly property bool watching: SettingsService.flag("launcher.clipboard") && root.available && root.cleaned

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-copy >/dev/null"]
        onExited: (code, status) => root.available = (code === 0)
    }

    // Leftovers from an earlier shell (or from both launchers) go first.
    Process {
        running: true
        command: ["pkill", "-f", "wl-paste --type (text|image) --watch cliphist store$"]
        onExited: root.cleaned = true
    }

    Process {
        running: root.watching
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
    }
    Process {
        running: root.watching
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }
}
