import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Appearance: how the shell's colours are made. The wallpaper (with next / random),
// the colour mode, the palette scheme and the accent for this wallpaper, and a
// read-out of what the palette tool made of it (the colours and their contrast).
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
        { name: "on accent", color: Tokens.onAccent },
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
    Component.onCompleted: page.reload()

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
