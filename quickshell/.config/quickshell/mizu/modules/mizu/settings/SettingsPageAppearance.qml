import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Appearance: how the shell's colours are made. The wallpaper (folder chips, a thumbnail
// grid to pick from, next / random), the colour mode, the palette scheme and the accent
// for this wallpaper, and a read-out of what the palette tool made of it (the colours and
// their contrast).
//
// The wallpaper is the only input: the palette tool (palette/mizu_palette.py) turns it into
// ~/.cache/mizu/tokens.json, which Tokens.qml watches. What this page adds are the knobs:
//   - the mode is the setting theme.mode (auto | dark | light);
//   - the scheme and the accent are overrides kept per wallpaper in
//     ~/.cache/mizu/state/palette-overrides.json, written by scripts/state/palette-override.sh.
// After an override changes, the tool runs again (WallpaperService.runPalette()).
SettingsPage {
    id: page

    readonly property string overrideScript: Directories.script("state/palette-override.sh")
    readonly property string wallpaper: WallpaperService.current

    // The override entry of the current wallpaper: {} or { scheme, mode, accent }.
    property var entry: ({})
    readonly property string schemeChoice: typeof page.entry.scheme === "string" ? page.entry.scheme : "auto"
    readonly property string accentChoice: typeof page.entry.accent === "string" ? page.entry.accent : ""
    readonly property bool hasOverride: Object.keys(page.entry).length > 0
    // A write is on its way: the controls wait for it, so the file is never written twice at once.
    readonly property bool busy: writer.running

    readonly property var schemes: [
        { id: "auto", label: "Auto", icon: "auto_awesome" },
        { id: "faithful", label: "Faithful" },
        { id: "soft", label: "Soft" },
        { id: "vibrant", label: "Vibrant" },
        { id: "m3-content", label: "M3 content" },
        { id: "m3-tonal-spot", label: "M3 tonal spot" },
        { id: "m3-monochrome", label: "M3 monochrome" }
    ]

    readonly property var modes: [
        { id: "auto", label: "Auto", icon: "brightness_auto" },
        { id: "dark", label: "Dark", icon: "dark_mode" },
        { id: "light", label: "Light", icon: "light_mode" }
    ]

    // The roles shown in the read-out, in the order of the page.
    readonly property var roles: [
        { name: "accent", color: Tokens.accent },
        { name: "accent 2", color: Tokens.accent2 },
        { name: "chip", color: Tokens.chip },
        { name: "surface", color: Tokens.surface },
        { name: "hover", color: Tokens.surfaceHover },
        { name: "paper", color: Tokens.paper },
        { name: "ink", color: Tokens.ink },
        { name: "ink muted", color: Tokens.inkMuted },
        { name: "on accent", color: Tokens.accentInk },
        { name: "line", color: Tokens.line },
        { name: "danger", color: Tokens.danger },
        { name: "warning", color: Tokens.warning }
    ]

    // Contrast numbers of Tokens.data.contrast ("bar.ink": 7.1, ...) by surface and by what is drawn on it.
    readonly property var contrast: Tokens.data && Tokens.data.contrast ? Tokens.data.contrast : ({})
    readonly property var contrastSurfaces: ["bar", "phone", "widget"]
    readonly property var contrastKinds: [
        { id: "ink", label: "Ink" },
        { id: "inkMuted", label: "Muted ink" },
        { id: "accent", label: "Accent" }
    ]
    // WCAG's bar for body text.
    readonly property real textContrast: 4.5

    function fileName(path) {
        return path.slice(path.lastIndexOf("/") + 1)
    }

    function contrastOf(surface, kind) {
        const v = page.contrast[surface + "." + kind]
        return typeof v === "number" ? v : -1
    }

    // ===== the override file =====
    function reload() {
        if (page.wallpaper === "") {
            page.entry = ({})
            return
        }
        if (reader.running) {
            reader.again = true
            return
        }
        reader.again = false
        reader.exec(["sh", page.overrideScript, "get", page.wallpaper])
    }

    function write(args) {
        if (page.wallpaper === "" || writer.running)
            return
        writer.exec(["sh", page.overrideScript].concat(args))
    }

    function setOverride(key, value) {
        page.write(["set", page.wallpaper, key, value])
    }

    function clearOverrides() {
        page.write(["clear", page.wallpaper])
    }

    onWallpaperChanged: page.reload()
    Component.onCompleted: {
        page.reload()
        page.loadThumbs()
        // Open on the page that holds the picture on the desktop now.
        const at = WallpaperService.files.indexOf(WallpaperService.current)
        if (at > 0)
            grid.pageIndex = Math.floor(at / grid.perPage)
    }

    // ===== the picker's thumbnails =====
    // wallpaper-thumbs.sh keeps small cached copies (720 px) of the folder's pictures in
    // ~/.cache/mizu/wallpaper/thumbs, so the grid never decodes a full-size wallpaper. The
    // map is global — absolute paths, never cleared — so switching folders never blanks
    // the grid: a scan of the new folder merges its cached thumbs in, and a cell whose
    // thumb is not there yet shows the original picture decoded small. A niced sweep
    // makes every missing thumb of the whole tree in the background, so every folder is
    // instant from then on.
    readonly property string thumbsScript: Directories.script("thumbnails/wallpaper-thumbs.sh")
    property var thumbs: ({})
    property string scanWanted: ""
    property int filesRev: 0

    function loadThumbs() {
        const dir = WallpaperService.directory
        if (thumbScan.running) {
            page.scanWanted = dir
            return
        }
        page.scanWanted = dir
        thumbScan.dir = dir
        thumbScan.exec(["sh", page.thumbsScript, "scan", dir])
    }

    // The sweep: one make over the whole tree (the script lists it recursively), re-run
    // when the folders changed while one was going. Niced — background work, not the
    // desktop's frames.
    function sweepThumbs() {
        if (thumbSweep.running)
            return
        thumbSweep.rev = page.filesRev
        thumbSweep.exec(["nice", "-n", "19", "sh", page.thumbsScript, "make", WallpaperService.rootDirectory])
    }

    Timer {
        id: sweepDebounce

        interval: 2000
        onTriggered: page.sweepThumbs()
    }

    // The folder chips: the default root's first-level subfolders and, when one is set,
    // the custom folder's own.
    readonly property var folderChoices: {
        const out = [{ path: "", label: "All" }]
        const seen = ({})
        for (let i = 0; i < WallpaperService.folders.length; i++) {
            const f = WallpaperService.folders[i]
            if (f in seen)
                continue
            seen[f] = true
            const name = f.slice(f.lastIndexOf("/") + 1)
            out.push({ path: f, label: name.charAt(0).toUpperCase() + name.slice(1) })
        }
        return out
    }

    Connections {
        target: WallpaperService

        function onFilesChanged() {
            page.filesRev++
            page.loadThumbs()
            page.sweepDebounce.restart()
            if (grid.pageIndex > grid.pageCount - 1)
                grid.pageIndex = Math.max(0, grid.pageCount - 1)
        }

        // A folder switch goes back to its first page and previews at once (the scan does
        // not wait for the listing); a wallpaper changed from elsewhere (Next, Random, the
        // timer) opens the page it sits on.
        function onDirectoryChanged() {
            grid.pageIndex = 0
            page.loadThumbs()
        }

        function onCurrentChanged() {
            const at = WallpaperService.files.indexOf(WallpaperService.current)
            if (at >= 0)
                grid.pageIndex = Math.floor(at / grid.perPage)
        }
    }

    Process {
        id: thumbScan

        property string dir: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const map = Object.assign({}, page.thumbs)
                const lines = text.split("\n")
                let count = 0
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length === 3 && parts[1] !== "" && parts[2] === "1") {
                        map[parts[0]] = parts[1]
                        count++
                    }
                }
                page.thumbs = map
                console.log("Appearance thumbs: scan " + thumbScan.dir + " -> "
                            + count + " thumbs of " + lines.length + " lines")
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("Appearance thumbs: scan: " + text.trim())
            }
        }
        onExited: {
            // The picker moved on while this scan ran: scan where it is now.
            if (page.scanWanted !== "" && page.scanWanted !== thumbScan.dir) {
                thumbScan.dir = page.scanWanted
                thumbScan.exec(["sh", page.thumbsScript, "scan", page.scanWanted])
            }
        }
    }

    Process {
        id: thumbSweep

        property int rev: 0

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("\t")
                if (parts.length === 3 && parts[0] === "ok") {
                    const map = Object.assign({}, page.thumbs)
                    map[parts[1]] = parts[2]
                    page.thumbs = map
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("Appearance thumbs: sweep: " + text.trim())
            }
        }
        onExited: {
            if (page.filesRev !== thumbSweep.rev)
                page.sweepThumbs()
        }
    }

    Process {
        id: reader

        property bool again: false

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = ({})
                try {
                    parsed = JSON.parse(text)
                } catch (e) {
                    parsed = ({})
                }
                page.entry = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({})
            }
        }
        onExited: {
            if (reader.again)
                page.reload()
        }
    }

    Process {
        id: writer

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("SettingsPageAppearance: palette-override.sh: " + text.trim())
            }
        }
        // The file is final now: read it back, and make the palette again from it.
        onExited: (code, status) => {
            page.reload()
            if (code === 0)
                WallpaperService.runPalette()
        }
    }

    // A segmented switch: a track with a thumb that slides under the chosen label.
    component Segments: Item {
        id: seg

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property var options: []
        property string current: ""

        signal picked(string id)

        readonly property real slot: (seg.width - 8) / Math.max(1, seg.options.length)
        readonly property int index: {
            for (let i = 0; i < seg.options.length; i++) {
                if (seg.options[i].id === seg.current)
                    return i
            }
            return 0
        }

        height: 56

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: mt.pSurfaceHover
            border.width: 3
            border.color: mt.pLine
            antialiasing: true
        }

        Rectangle {
            x: 4 + seg.index * seg.slot
            y: 4
            width: seg.slot
            height: seg.height - 8
            radius: height / 2
            antialiasing: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mt.accentMint }
                GradientStop { position: 1.0; color: mt.accentCyan }
            }

            Behavior on x {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }
        }

        Repeater {
            model: seg.options

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                x: 4 + cell.index * seg.slot
                y: 4
                width: seg.slot
                height: seg.height - 8

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 22
                        name: cell.modelData.icon
                        weight: mt.settingsIconWeight
                        color: cell.index === seg.index ? mt.colBorder : mt.pInkSub
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.modelData.label
                        color: cell.index === seg.index ? mt.colBorder : mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(cell.modelData.id)
                }
            }
        }
    }

    // ===== the wallpaper =====
    SectionCard {
        title: "Wallpaper"

        Rectangle {
            id: frame

            width: 360
            height: 203
            radius: 22
            color: mt.pSurfaceHover
            border.width: 3
            border.color: mt.pLine
            antialiasing: true

            RoundClip {
                anchors.fill: parent
                anchors.margins: 3
                radii: [19, 19, 19, 19]

                Image {
                    anchors.fill: parent
                    visible: page.wallpaper !== ""
                    source: page.wallpaper !== "" ? "file://" + page.wallpaper : ""
                    // A thumbnail: never decode the full picture on the UI thread.
                    sourceSize: Qt.size(720, 406)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: page.wallpaper === ""
                size: 48
                name: "image"
                weight: mt.settingsIconWeight
                color: mt.pInkSub
            }
        }

        Column {
            width: page.fullWidth - frame.width - 24
            spacing: 14

            Text {
                width: parent.width
                elide: Text.ElideMiddle
                text: page.wallpaper !== "" ? page.fileName(page.wallpaper) : "No wallpaper yet"
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 22
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: WallpaperService.files.length === 0 ? "The folder " + WallpaperService.directoryShort + " has no pictures"
                    : (WallpaperService.files.indexOf(page.wallpaper) + 1) + " of " + WallpaperService.files.length
                      + " in " + WallpaperService.directoryShort
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }

            Row {
                spacing: 16

                SettingAction {
                    tileWidth: 230
                    icon: "skip_next"
                    label: "Next"
                    detail: "The next picture"
                    onActivated: WallpaperService.next(1)
                }

                SettingAction {
                    tileWidth: 230
                    icon: "shuffle"
                    label: "Random"
                    detail: "Any other picture"
                    onActivated: WallpaperService.random()
                }
            }
        }

        // Which folder the picker lists: a chip per first-level folder, All for the whole tree.
        Flow {
            width: page.fullWidth
            spacing: 10

            Repeater {
                model: page.folderChoices

                delegate: SettingChip {
                    required property var modelData

                    label: modelData.label
                    icon: modelData.path === "" ? "photo_library" : "folder"
                    selected: WallpaperService.customFolder === modelData.path
                    onClicked: WallpaperService.setFolder(modelData.path)
                }
            }
        }

        // The folder's pictures: a thumbnail per one, click to put it on the desktop.
        // Pages of three rows of four with a pager under them, so a big folder stays
        // one screen tall; an empty folder keeps room for its note.
        Item {
            width: page.fullWidth
            height: WallpaperService.files.length === 0
                    ? 140 : grid.height + (pager.visible ? pager.height + 10 : 0)

            GridView {
                id: grid

                readonly property real gap: 12
                readonly property int columns: 4
                readonly property int rows: 3
                readonly property int perPage: grid.rows * grid.columns
                property int pageIndex: 0
                readonly property int pageCount: Math.max(1, Math.ceil(WallpaperService.files.length / grid.perPage))

                // The cell gives up the trailing gap the view adds after it, so four
                // cells and three gaps fill the width exactly.
                readonly property real cellW: Math.floor(grid.width / grid.columns) - grid.gap
                readonly property real cellH: Math.round(grid.cellW * 9 / 16)

                width: page.fullWidth
                height: grid.rows * grid.cellH + (grid.rows - 1) * grid.gap
                visible: WallpaperService.files.length > 0
                interactive: false
                clip: true
                cellWidth: grid.cellW + grid.gap
                cellHeight: grid.cellH + grid.gap
                model: WallpaperService.files.slice(grid.pageIndex * grid.perPage, (grid.pageIndex + 1) * grid.perPage)

                delegate: Rectangle {
                    id: cell

                    required property string modelData

                    readonly property string thumb: page.thumbs[cell.modelData] ?? ""
                    readonly property bool current: cell.modelData === WallpaperService.current
                    readonly property bool hovered: area.containsMouse

                    width: grid.cellW
                    height: grid.cellH
                    radius: 14
                    color: mt.pSurfaceHover
                    border.width: 3
                    border.color: cell.current ? mt.accentMint : cell.hovered ? mt.pInkSub : mt.pLine
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation { duration: 120 }
                    }

                    RoundClip {
                        anchors.fill: parent
                        anchors.margins: 3
                        radii: [11, 11, 11, 11]

                        Image {
                            anchors.fill: parent
                            // The cached thumbnail when it exists; the original decoded
                            // small until the sweep has made it, so a folder never sits
                            // on placeholders.
                            source: "file://" + (cell.thumb !== "" ? cell.thumb : cell.modelData)
                            // Smaller than the 720 px thumbnail itself: the grid cell never needs more.
                            sourceSize: Qt.size(grid.cellW * 1.5, grid.cellH * 1.5)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    // The one on the desktop now.
                    Rectangle {
                        anchors.centerIn: parent
                        visible: cell.current
                        width: 44
                        height: 44
                        radius: 22
                        color: Qt.rgba(0, 0, 0, 0.45)
                        antialiasing: true

                        MaterialIcon {
                            anchors.centerIn: parent
                            size: 28
                            name: "check"
                            weight: mt.settingsIconWeight
                            color: mt.accentMint
                        }
                    }

                    MouseArea {
                        id: area

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.setWallpaper(cell.modelData, "")
                    }
                }
            }

            // The pager: a page back or forward, only when the folder spans more than one.
            Row {
                id: pager

                visible: WallpaperService.files.length > 0 && grid.pageCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: grid.bottom
                anchors.topMargin: 10
                spacing: 14

                SettingChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_left"
                    opacity: grid.pageIndex > 0 ? 1 : 0.45
                    onClicked: if (grid.pageIndex > 0)
                                   grid.pageIndex--
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (grid.pageIndex + 1) + " / " + grid.pageCount
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                SettingChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_right"
                    opacity: grid.pageIndex < grid.pageCount - 1 ? 1 : 0.45
                    onClicked: if (grid.pageIndex < grid.pageCount - 1)
                                   grid.pageIndex++
                }
            }

            Column {
                anchors.centerIn: parent
                visible: WallpaperService.files.length === 0
                spacing: 8

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 40
                    name: "folder_open"
                    weight: mt.settingsIconWeight
                    color: mt.pInkSub
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No pictures in " + WallpaperService.directoryShort
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // ===== mode, scheme, accent =====
    SectionCard {
        title: "Colour mode"

        Column {
            width: page.fullWidth
            spacing: 10

            Segments {
                width: Math.min(page.fullWidth, 560)
                options: page.modes
                current: SettingsService.get("theme.mode")
                onPicked: id => SettingsService.set("theme.mode", id)
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: SettingsService.get("theme.mode") === "auto"
                    ? "Auto picks light for a bright wallpaper and dark otherwise. Now: " + Tokens.mode + "."
                    : "Always " + SettingsService.get("theme.mode") + ", whatever the wallpaper is."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 16
            }
        }
    }

    SectionCard {
        title: "Scheme"

        SettingChoice {
            enabled: !page.busy
            opacity: page.busy ? 0.6 : 1
            label: "Palette scheme"
            sublabel: "How the colours are built from this wallpaper. Auto lets the tool choose: grey pictures get a quiet scheme"
            current: page.schemeChoice
            options: page.schemes
            onPicked: id => page.setOverride("scheme", id)
        }

        Text {
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: "Used now: " + Tokens.data.scheme + (page.schemeChoice === "auto" ? " (chosen by the tool)" : " (your choice)")
                + ". A choice is kept for this wallpaper only."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 16
        }

        SettingAction {
            visible: page.hasOverride
            enabled: !page.busy
            tileWidth: 310
            icon: "restart_alt"
            label: "Reset this wallpaper"
            detail: "Forget its scheme and accent"
            onActivated: page.clearOverrides()
        }
    }

    SectionCard {
        title: "Accent"

        Text {
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: "Pick the accent from this wallpaper's colours, or let the tool choose. The palette is made again from your choice."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 16
        }

        Row {
            id: accentRow

            spacing: 14
            enabled: !page.busy
            opacity: page.busy ? 0.6 : 1

            SettingChip {
                anchors.verticalCenter: parent.verticalCenter
                label: "Auto"
                icon: "auto_awesome"
                selected: page.accentChoice === ""
                onClicked: page.setOverride("accent", "auto")
            }

            Repeater {
                model: Tokens.series

                delegate: Item {
                    id: dot

                    required property string modelData
                    readonly property bool picked: page.accentChoice !== "" && page.accentChoice === dot.modelData.toLowerCase()

                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    height: 56

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: dot.modelData
                        border.width: dot.picked ? 5 : 3
                        border.color: dot.picked ? mt.colBorder : mt.pLine
                        antialiasing: true
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: dot.picked
                        size: 28
                        name: "check"
                        weight: mt.settingsIconWeight
                        color: mt.colBorder
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.setOverride("accent", dot.modelData)
                    }
                }
            }
        }

        Text {
            visible: page.accentChoice !== ""
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: "Your accent for this wallpaper: " + page.accentChoice
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 16
        }
    }

    // ===== what the tool made =====
    SectionCard {
        title: "Palette"

        Text {
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: "Scheme " + Tokens.data.scheme + "  ·  " + Tokens.mode + " mode"
                + (Tokens.data.analysis && typeof Tokens.data.analysis.L === "number"
                   ? "  ·  the picture: lightness " + Tokens.data.analysis.L + ", colourfulness " + Tokens.data.analysis.chroma : "")
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }

        Repeater {
            model: page.roles

            delegate: Column {
                id: swatch

                required property var modelData

                width: Math.floor((page.fullWidth - 16 * 5) / 6)
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 46
                    radius: 14
                    color: swatch.modelData.color
                    border.width: 3
                    border.color: mt.pLine
                    antialiasing: true
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: swatch.modelData.name
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    SectionCard {
        title: "Contrast"

        Text {
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: Object.keys(page.contrast).length === 0
                ? "The palette tool has not reported contrast yet."
                : "Contrast of the ink and the accent against the wallpaper behind each surface. " + page.textContrast + " or more reads as text."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 16
        }

        Grid {
            visible: Object.keys(page.contrast).length > 0
            columns: 4
            columnSpacing: 14
            rowSpacing: 10

            // header row
            Item { width: 110; height: 24 }

            Repeater {
                model: page.contrastKinds

                delegate: Text {
                    required property var modelData

                    width: Math.floor((page.fullWidth - 110 - 14 * 3) / 3)
                    text: modelData.label
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: page.contrastSurfaces.length * 4

                delegate: Item {
                    id: cell

                    required property int index

                    readonly property int row: Math.floor(cell.index / 4)
                    readonly property int col: cell.index % 4
                    readonly property string surface: page.contrastSurfaces[cell.row]
                    readonly property real value: cell.col === 0 ? -1 : page.contrastOf(cell.surface, page.contrastKinds[cell.col - 1].id)

                    width: cell.col === 0 ? 110 : Math.floor((page.fullWidth - 110 - 14 * 3) / 3)
                    height: 40

                    Text {
                        visible: cell.col === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: cell.surface.charAt(0).toUpperCase() + cell.surface.slice(1)
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }

                    Rectangle {
                        visible: cell.col > 0
                        width: parent.width
                        height: parent.height
                        radius: 14
                        color: mt.pSurfaceHover
                        border.width: 3
                        border.color: cell.value >= 0 && cell.value < page.textContrast ? mt.warning : mt.pLine
                        antialiasing: true

                        Rectangle {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: cell.value < 0 ? mt.pLine : (cell.value >= page.textContrast ? mt.accentMint : mt.warning)
                            antialiasing: true
                        }

                        Text {
                            x: 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: cell.value < 0 ? "n/a" : cell.value.toFixed(1) + " : 1"
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
