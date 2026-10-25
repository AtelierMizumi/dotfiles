pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "functions/Framing.js" as FR

// The avatar and banner pictures — picked by clicking them on the Quick
// Panel (QuickPanelFace.qml -> QuickPanel.qml -> pick()) — and the phone's own
// wallpaper (Settings > General > Quick Panel > Phone wallpaper). A file chooser opens, the chosen
// picture is copied into ~/.cache/mizu/data/ and shown; it's found
// again there the next time the shell starts. The chooser itself and the
// copying are pick-image.sh's job.
//
// A singleton (like Theme.qml, WallpaperService.qml) rather than a
// per-window instance, so any window that shows the picture reads the
// same one with no wiring.
//
//   avatar / banner   a file:// URL, or "" for "nothing picked" (the panel
//                     then falls back to QuickPanel's own avatarSource /
//                     bannerSource, and after that the grey template)
//   avatarPath /      the same pictures as plain file paths (what the
//   bannerPath        desktop presets save), "" for nothing picked
//   loaded            true once the pictures from an earlier session have
//                     been looked for (a preset saved before then would
//                     wrongly hold "no avatar, no banner")
//   busy              true while a chooser is open — QuickPanel drops its
//                     click-away grab meanwhile, or the chooser window
//                     taking focus would close the panel
//   phone / phonePath the phone's own wallpaper, the same way ("" for none)
//   phoneMode         what the phone's screens (Quick and Apps) show behind
//                     them: "off", "desktop" (the monitor's wallpaper) or
//                     "picture" (phonePath)
//   phoneWallpaperFor(monitor)
//                     the picture they show on that monitor, as a file path
//                     ("" for none: off, or nothing picked / known yet)
//   pick(kind)        open the chooser for "avatar", "banner" or "phone"; a picture
//                     picked opens the framer on it (`frame(kind, true)`)
//   clear(kind)       forget the picked picture (right-click on it)
//
// Framing (docs/PICTURE-FRAMING.md): which part of each picture shows in its slot.
//   framingFor(kind)  { zoom, panX, panY } for the picture shown now (centred if it was
//                     never framed); bind to it, it changes when the framing does
//   setFraming(kind, f)   save one (Done in the framer)
//   frame(kind, fresh, screenName)
//                     open the framer on that picture (`fresh`: it was just picked, so
//                     the card says it starts centred); screenName "" = the focused monitor
//   framing / framingFresh / framingScreen / closeFramer()
//                     what the framer windows (FramerWindow.qml) show
Singleton {
    id: root

    property string avatar: ""
    property string banner: ""
    property string phone: ""
    property bool loaded: false

    // The file path behind a file:// URL made by urlFor() ("" for none).
    function pathFor(url) {
        if (url.indexOf("file://") !== 0)
            return ""
        try {
            return decodeURIComponent(url.slice(7))
        } catch (e) {
            return ""
        }
    }

    readonly property string avatarPath: pathFor(avatar)
    readonly property string bannerPath: pathFor(banner)
    readonly property string phonePath: pathFor(phone)

    // `phone.wallpaper`, "" until it has been chosen once: then the Apps screen's
    // old on / off switch (`launcher.lcdWallpaper`, from before the home screen had
    // a wallpaper) says it, so whoever had turned that off keeps a plain phone.
    readonly property string phoneMode: {
        const m = SettingsService.get("phone.wallpaper")
        if (m === "off" || m === "desktop" || m === "picture")
            return m
        return SettingsService.flag("launcher.lcdWallpaper") ? "desktop" : "off"
    }

    function phoneWallpaperFor(screenName) {
        if (root.phoneMode === "picture")
            return root.phonePath
        if (root.phoneMode === "desktop")
            return WallpaperService.pathFor(screenName)
        return ""
    }

    readonly property bool busy: picker.running

    // ===== framing =====
    readonly property var framings: FR.parse(SettingsService.get("pictures.framing"))

    function pathOf(kind) {
        return kind === "avatar" ? root.avatarPath : (kind === "banner" ? root.bannerPath : (kind === "phone" ? root.phonePath : ""))
    }

    function framingFor(kind) {
        return FR.forPicture(root.framings, kind, root.pathOf(kind))
    }

    function setFraming(kind, f) {
        const next = FR.withFraming(root.framings, kind, root.pathOf(kind), f)
        SettingsService.set("pictures.framing", FR.stringify(next))
    }

    // The framer: "" while closed, else the kind it frames. One for the whole shell, shown
    // on `framingScreen` (FramerWindow.qml, one per monitor, shows itself there).
    property string framing: ""
    property bool framingFresh: false
    property string framingScreen: ""
    // Counts every frame() call, so a framer already open starts over on the picture.
    property int framingSeq: 0

    function frame(kind, fresh, screenName) {
        if (FR.KINDS.indexOf(kind) < 0 || root.pathOf(kind) === "")
            return
        root.framingScreen = screenName || Compositor.focusedOutput
        root.framingFresh = fresh === true
        root.framing = kind
        root.framingSeq++
    }

    // A picture just picked, until the framer it opened is closed: Done keeps it (and
    // drops the one it replaced), Cancel puts the old one back (and its phone mode).
    //   { kind, prev, next, prevMode }
    property var pending: null

    function closeFramer(saved) {
        const p = root.pending
        if (p && p.kind === root.framing) {
            root.pending = null
            if (saved === true) {
                if (p.prev !== "")
                    root.drop(p.prev)
            } else {
                root.assign(p.kind, p.prev)
                root.drop(p.next)
                if (p.kind === "phone")
                    SettingsService.set("phone.wallpaper", p.prevMode)
            }
        }
        root.framing = ""
        root.framingFresh = false
    }

    function drop(path) {
        if (path !== "")
            Quickshell.execDetached(["sh", root.script, "drop", path])
    }

    readonly property string script: Directories.script("images/pick-image.sh")

    // Settings > General > Quick Panel > Picture picker. "auto" (or anything
    // unknown) leaves the choice to pick-image.sh; a name is tried first there.
    readonly property string chooser: {
        const c = SettingsService.get("files.chooser")
        return (c === "kdialog" || c === "zenity" || c === "yad") ? c : ""
    }

    function urlFor(path) {
        if (path === "")
            return ""
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }

    function assign(kind, path) {
        if (kind === "avatar")
            avatar = urlFor(path)
        else if (kind === "banner")
            banner = urlFor(path)
        else if (kind === "phone")
            phone = urlFor(path)
    }

    function pick(kind, screenName) {
        if (picker.running)
            return
        picker.kind = kind
        picker.screenName = screenName || Compositor.focusedOutput
        picker.running = true
    }

    // Kinds waiting for the script to forget them. A queue, not a single
    // slot: wearing a desktop preset with no avatar and no banner clears both
    // one straight after the other, and the second must not be dropped (the
    // file would come back at the next start).
    property var clearQueue: []

    function clear(kind) {
        if (root.pending && root.pending.kind === kind)
            root.pending = null
        if (root.framing === kind) {
            root.framing = ""
            root.framingFresh = false
        }
        assign(kind, "")
        root.clearQueue = root.clearQueue.concat([kind])
        root.pumpClear()
    }

    function pumpClear() {
        if (clearer.running || root.clearQueue.length === 0)
            return
        clearer.kind = root.clearQueue[0]
        root.clearQueue = root.clearQueue.slice(1)
        clearer.running = true
    }

    Process {
        id: picker

        property string kind: ""
        property string screenName: ""

        // KEEP: the picture it replaces stays until the framer is closed (see `pending`).
        command: root.chooser === ""
            ? ["env", "MIZU_PICK_KEEP=1", "sh", root.script, "pick", kind]
            : ["env", "MIZU_PICK_KEEP=1", "MIZU_CHOOSER=" + root.chooser, "sh", root.script, "pick", kind]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path === "")
                    return
                // Another pick while one is still waiting in the framer: that one is let go.
                if (root.pending && root.pending.kind === picker.kind && root.pending.next !== path)
                    root.drop(root.pending.next)
                const prev = root.pending && root.pending.kind === picker.kind ? root.pending.prev : root.pathOf(picker.kind)
                const prevMode = root.pending && root.pending.kind === picker.kind ? root.pending.prevMode : String(SettingsService.get("phone.wallpaper"))
                root.pending = { kind: picker.kind, prev: prev, next: path, prevMode: prevMode }
                root.assign(picker.kind, path)
                // Picking a phone wallpaper is asking to see it.
                if (picker.kind === "phone")
                    SettingsService.set("phone.wallpaper", "picture")
                // A new picture is framed straight away: it starts centred, so Done at once
                // is what the shell always showed.
                root.frame(picker.kind, true, picker.screenName)
            }
        }
    }

    Process {
        id: clearer

        property string kind: ""

        command: ["sh", root.script, "clear", kind]
        onExited: root.pumpClear()
    }

    // What was picked in an earlier session.
    Process {
        command: ["sh", root.script, "load"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const sp = lines[i].indexOf(" ")
                    if (sp > 0)
                        root.assign(lines[i].slice(0, sp), lines[i].slice(sp + 1))
                }
                // After the pictures are set, not when the script exits.
                root.loaded = true
            }
        }
    }
}
