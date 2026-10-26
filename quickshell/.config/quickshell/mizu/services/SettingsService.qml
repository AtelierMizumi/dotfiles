pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// The Settings Panel's own options, in one place.
//
// Most of what the panel changes already has an owner (ThemeService,
// BarStyleService, ClockService, ShellScale, ...) and the panel just calls
// that owner. This singleton holds the rest: switches and numbers that used
// to be fixed values inside some file (is the weather pill on the bar? how
// long does the Quick Panel's hot edge wait?) and so had nowhere to live.
//
// Reading is a plain function call, so a binding stays live:
//
//     visible: SettingsService.flag("bar.weather")
//     interval: SettingsService.get("panel.hotDwell")
//
// Only what differs from `defaults` is saved (scripts/state/settings-state.sh,
// ~/.config/quickshell/mizu-user/settings.json), so adding a new key later never
// disturbs an old file, and removing a key from `defaults` just ignores it.
//
// From a keybind or a script:
//   qs -c mizu ipc call options get bar.weather
//   qs -c mizu ipc call options set bar.weather false
//   qs -c mizu ipc call options reset            (everything back to default)
// (`settings` is the panel itself: `ipc call settings toggle`, see QuickPanel.qml.)
Singleton {
    id: root

    // Every option, with the value it has when nothing is saved. The key is
    // `group.name`; the type of the default is the type of the option.
    readonly property var defaults: ({
        // ===== Bar =====
        "bar.visible": true,
        "bar.hideMode": "off",          // off | auto (slides off its edge until the pointer touches that edge; reserves no space)
        "bar.compactWindow": true,     // the bar window is the strip (+ room) instead of the whole screen; off = whole screen
        "bar.perMonitor": false,        // each monitor keeps its own bar layout (off = one layout on all of them)
        "bar.workspaces": true,
        "bar.activeWindow": true,
        "bar.media": true,
        "bar.resources": false,         // CPU & RAM pill: off in the default bar (switch it on here)
        "bar.battery": true,
        "bar.keyboardLayout": true,
        "bar.notifications": true,
        "bar.tray": true,
        "bar.weather": true,
        "bar.date": true,
        "bar.clock": true,
        // Who is using the mic / screen.
        "bar.privacy": true,
        // Wi-Fi / Bluetooth / speaker icons in one pill.
        "bar.status": true,
        // ===== General =====
        "time.use24h": true,
        // The bar's and the desktop clock's date text, a Qt date format ("M月d日 ddd" gives 10月25日 土 with a Japanese
        // locale on the shell process). Empty = the locale's short date.
        "time.dateFormat": "",
        "weather.fahrenheit": false,
        // How a new notification announces itself: phone (the Quick Panel's phone rises and buzzes; the default) | popups (a stack of cards in the corner).
        "notify.style": "phone",
        // The Quick Panel's Notifications tile: false is do-not-disturb (nothing announces itself).
        "notify.on": true,
        // Hold announcements back (no popup / rising phone / buzz) while the focused monitor shows a fullscreen window. Same as do-not-disturb otherwise: they still land in the list, critical ones still break through.
        "notify.quietFullscreen": false,
        "notify.buzz": true,
        // Low-battery notifications at 20 / 15 / 10 / 5 % while running on battery (services/BatteryAlertService.qml). A desktop with no battery never sees them.
        "battery.alerts": true,
        "panel.hotEdge": true,
        "panel.hotDwell": 140,
        "panel.peek": 76,
        // The Quick Panel phone drawn flat (2D: no tilt, no side wall, buttons cast their shadow straight down like the bar's pills) instead of the 2.5D pose.
        "quick.flat": false,
        // The soft shadow under every phone (Quick Panel, Apps, Wallpapers, Settings). Off = no shadow at all.
        "quick.phoneShadow": true,
        // A plain letter typed while the phone is up on Quick starts a search on the Apps screen.
        "panel.typeToSearch": true,
        // Which window opens when you pick the avatar or banner: auto (kdialog, else zenity, else yad) | kdialog | zenity (the desktop portal's dialog) | yad.
        "files.chooser": "auto",
        // Search suggestions from the web while typing in the launcher: off, because each keystroke would be sent out.
        "launcher.webSuggestions": false,
        "launcher.clipboard": true,
        // The Apps screen's old on / off switch for its wallpaper; read only while phone.wallpaper is "".
        "launcher.lcdWallpaper": true,
        // What the phone's screens show behind them: "off", "desktop" or "picture";
        // "" = not chosen yet, launcher.lcdWallpaper decides (PanelImages.phoneMode).
        "phone.wallpaper": "",
        "pictures.framing": "",         // JSON: which part of the banner / avatar / phone picture shows (PanelImages, Framing.js)
        "lock.blur": false,
        // The Settings page you left off on (a page id from SettingsFace.qml), "" = the menu.
        "settings.page": "",
        // Calendar lockscreen: where each frame's picture comes from: auto (the interesting parts of the wallpaper) | fixed (always the same spots).
        "lock.crop": "auto",
        // Calendar lockscreen: the pictures in colour (your theme's colours around them) | mono (black and white).
        "lock.tone": "color",
        // Calendar lockscreen: Restart and Shut down keys beside the password field.
        "lock.powerButtons": true,
        // While the screen is locked nothing but the lockscreen can be seen, so the desktop widgets are unloaded (their memory and
        // work come back) and the bar's audio tap stops; unlocking builds them again. Off = leave everything running while locked.
        "lock.sleepDesktop": true,
        // Fingerprint unlock: a second PAM context using pam_fprintd.so runs alongside
        // the password field. Off by default: machines without fprintd will skip it cleanly.
        "lock.fingerprint": false,
        // ===== Idle (services/Idle.qml) =====
        "idle.screenOffMinutes": 30,    // the screens turn off after this many idle minutes (0 = never)
        "idle.lockMinutes": 45,         // the session locks after this many idle minutes (0 = never); no automatic suspend
        // ===== Media pill =====
        "media.leftClick": "panel",
        // ===== Bar and tray =====
        "bar.workspaceCount": 5,        // how many workspace badges the bar shows, 1-10
        "bar.scrollHints": true,        // a small marker on modules that react to the scroll wheel
        "tray.scroll": true,            // the wheel over a tray icon is sent to the app
        // ===== Weather =====
        // VKU Campus, Hoa Hai, Ngu Hanh Son, Da Nang (OSM way/1169542373: 15.97262°N, 108.24891°E)
        "weather.location": "15.9726, 108.2489 (VKU, Da Nang)", // lat,lon (label) or city name. If empty, falls back to GeoIP.
        "weather.view": "days",         // the popup's second row: days | hourly
        // Stars stuck on days in the calendar popup: "2026-10-09:2,..." (date : attribute colour 1-5).
        "calendar.marks": "",
        // ===== Colors =====
        // The palette tool follows the wallpaper. auto = light for a bright wallpaper, else dark.
        "theme.mode": "auto",
        // ===== Wallpaper =====
        "wallpaper.enabled": true,      // Show or hide the desktop wallpaper
        "wallpaper.folder": "",         // the folder the picker lists, searched recursively ("" = ~/Pictures/Wallpapers)
        "wallpaper.duration": 450,      // crossfade between two wallpapers, ms
        "wallpaper.randomMinutes": 0    // change to a random wallpaper every N minutes (0 = never)
    })

    // What has been changed from the defaults.
    property var values: ({})

    // True once the saved file has been read (or there is none).
    property bool loaded: false
    // Set once something was changed this session, so the startup load below
    // can't land late and undo it.
    property bool touched: false

    function get(key) {
        const v = root.values
        return (key in v) ? v[key] : root.defaults[key]
    }

    function flag(key) {
        return !!root.get(key)
    }

    // Which bar modules are on, by the names Status_Bar.qml uses.
    readonly property var barModules: ({
        workspaces: root.flag("bar.workspaces"),
        activeWindow: root.flag("bar.activeWindow"),
        media: root.flag("bar.media"),
        resources: root.flag("bar.resources"),
        battery: root.flag("bar.battery"),
        keyboardLayout: root.flag("bar.keyboardLayout"),
        notifications: root.flag("bar.notifications"),
        tray: root.flag("bar.tray"),
        weather: root.flag("bar.weather"),
        date: root.flag("bar.date"),
        clock: root.flag("bar.clock"),
        privacy: root.flag("bar.privacy"),
        status: root.flag("bar.status")
    })

    // Number of keys that differ from the defaults (shown on About).
    readonly property int changedCount: Object.keys(root.values).length

    function set(key, value) {
        if (!(key in root.defaults))
            return
        root.touched = true
        // Nothing to do when the option already has this value. Sliders (SettingSlider.qml)
        // call this on every mouse-move event, and most of those land on the value the
        // slider already snapped to; each call used to replace `values`, which re-runs
        // every binding that reads an option (about 190 of them across the shell), and to
        // start a save of the settings file. Only once the saved file has been read, so a
        // change made before that still gets written.
        if (root.loaded && root.get(key) === value)
            return
        const next = Object.assign({}, root.values)
        if (value === root.defaults[key])
            delete next[key]
        else
            next[key] = value
        root.values = next
        saver.save(JSON.stringify(next))
    }

    function toggle(key) {
        root.set(key, !root.flag(key))
    }

    function reset() {
        root.touched = true
        root.values = ({})
        saver.save("{}")
    }

    // ===== persistence =====
    readonly property string script: Directories.script("state/settings-state.sh")

    function restore(text) {
        try {
            const j = JSON.parse(text)
            const next = {}
            for (const k in j) {
                // Only keys we know, of the type we expect.
                if (k in root.defaults && typeof j[k] === typeof root.defaults[k] && j[k] !== root.defaults[k])
                    next[k] = j[k]
            }
            root.values = next
        } catch (e) {
            console.warn("SettingsService: couldn't read settings.json (" + e + ") — using the defaults")
        }
    }

    Process {
        running: true
        command: ["sh", root.script, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.touched && text.trim() !== "")
                    root.restore(text)
                root.loaded = true
            }
        }
        onExited: root.loaded = true
    }

    Process {
        id: saver

        property string pending: ""

        function save(json) {
            if (saver.running) {
                saver.pending = json
                return
            }
            saver.pending = ""
            saver.exec(["sh", root.script, "save", json])
        }

        onExited: {
            if (saver.pending !== "") {
                const json = saver.pending
                saver.pending = ""
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }

    IpcHandler {
        target: "options"

        function get(key: string): string {
            return key + " = " + JSON.stringify(root.get(key))
        }

        function set(key: string, value: string): void {
            if (!(key in root.defaults))
                return
            const d = root.defaults[key]
            if (typeof d === "boolean")
                root.set(key, value === "true" || value === "1" || value === "on")
            else if (typeof d === "number") {
                const n = Number(value)
                if (isFinite(n))
                    root.set(key, n)
            }
            else
                root.set(key, value)
        }

        function reset(): void {
            root.reset()
        }
    }
}
