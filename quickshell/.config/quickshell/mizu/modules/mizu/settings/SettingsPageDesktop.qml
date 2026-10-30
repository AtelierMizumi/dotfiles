import QtQuick
import Quickshell
import qs.services
import qs.modules.common.widgets

// Desktop: the wallpaper and how it changes, and the widgets on the desktop.
// (The palette that follows the wallpaper is on the Appearance page.)
SettingsPage {
    id: page

    SectionCard {
        title: "Wallpaper"

        SettingToggle {
            icon: "image"
            label: "Desktop wallpaper"
            detail: "ON or OFF the desktop wallpaper"
            checked: SettingsService.flag("wallpaper.enabled")
            onToggled: SettingsService.toggle("wallpaper.enabled")
        }

        SettingAction {
            icon: "skip_next"
            label: "Next wallpaper"
            detail: "The next picture of the folder"
            onActivated: WallpaperService.next(1)
        }

        SettingAction {
            icon: "shuffle"
            label: "Random wallpaper"
            detail: "Pick one now"
            onActivated: WallpaperService.random()
        }

        SettingSlider {
            width: page.halfWidth
            icon: "autorenew"
            label: "Change randomly every"
            from: 0
            to: 240
            step: 5
            suffix: " min"
            specialValue: 0
            specialText: "Never"
            value: SettingsService.get("wallpaper.randomMinutes")
            onMoved: v => SettingsService.set("wallpaper.randomMinutes", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "timelapse"
            label: "Crossfade"
            from: 100
            to: 3000
            step: 100
            suffix: " ms"
            value: SettingsService.get("wallpaper.duration")
            onMoved: v => SettingsService.set("wallpaper.duration", v)
        }

        SettingText {
            label: "Wallpaper folder"
            sublabel: "Searched recursively. Empty: " + WallpaperService.directoryShort
                + (WallpaperService.customFolder === "" ? " (the default)" : "")
            value: WallpaperService.customFolder
            placeholder: "~/Pictures/Wallpapers"
            onSubmitted: text => {
                let folder = text.trim()
                if (folder.startsWith("~/"))
                    folder = WallpaperService.home + folder.slice(1)
                if (folder === WallpaperService.customFolder)
                    return
                SettingsService.set("wallpaper.folder", folder)
                WallpaperService.rescan()
            }
            onCleared: {
                WallpaperService.resetFolder()
                WallpaperService.rescan()
            }
        }

        SettingAction {
            icon: "refresh"
            label: "Rescan the folder"
            detail: WallpaperService.files.length + (WallpaperService.files.length === 1 ? " picture" : " pictures")
            onActivated: WallpaperService.rescan()
        }
    }

    SectionCard {
        id: l2dCard
        title: "Live2D"
        icon: "animation"

        SettingToggle {
            icon: "animation"
            label: "Live2D wallpaper"
            detail: L2dService.statusText
            checked: L2dService.state === "running" || L2dService.state === "starting"
            onToggled: L2dService.toggle()
        }

        SettingChoice {
            label: "Screens"
            sublabel: "Where the Live2D canvas is drawn (empty for all)"
            current: L2dService.currentOutputs === "" ? "all" : L2dService.currentOutputs
            options: [{ id: "all", label: "All monitors", icon: "desktop_windows" }].concat(
                Quickshell.screens.map(s => ({ id: s.name, label: s.name, icon: "tv" }))
            )
            onPicked: id => L2dService.setOutputs(id === "all" ? "" : id)
        }

        SettingToggle {
            icon: "visibility"
            label: "Interaction hints"
            detail: "Show interactive touch zones (hotspots) and dialogue triggers on the model"
            checked: L2dService.tips
            onToggled: L2dService.toggleTips()
        }

        Rectangle {
            id: l2dActiveFrame
            width: l2dCard.innerWidth
            implicitHeight: Math.max(l2dThumbFrame.height, activeDetailsCol.implicitHeight) + 24
            radius: 16
            color: mt.pSurfaceHover
            border.width: 1
            border.color: mt.pLine
            antialiasing: true

            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Rectangle {
                    id: l2dThumbFrame
                    width: 220
                    height: 124
                    radius: 12
                    color: mt.pSurface
                    border.width: 2
                    border.color: mt.accentCyan
                    antialiasing: true

                    RoundClip {
                        anchors.fill: parent
                        anchors.margins: 2
                        radii: [10, 10, 10, 10]

                        Image {
                            anchors.fill: parent
                            source: L2dService.previewFor(L2dService.currentModel)
                            sourceSize: Qt.size(440, 248)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }

                Column {
                    id: activeDetailsCol
                    width: parent.width - l2dThumbFrame.width - 24
                    spacing: 8

                    Row {
                        spacing: 10
                        Text {
                            text: L2dService.currentSkinInfo.shipName
                            color: mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.ExtraBold
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: L2dService.currentSkinInfo.shipSub
                            color: mt.pInkSub
                            font.family: mt.fontFamily
                            font.pixelSize: 13
                        }
                    }

                    Text {
                        text: L2dService.currentSkinInfo.skinName + " (" + L2dService.currentModel + ")"
                        color: mt.accentCyan
                        font.family: mt.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Drag desktop background to move, mouse wheel to zoom."
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 12
                    }

                    Row {
                        spacing: 10

                        SettingChip {
                            capH: 36
                            fontSize: 14
                            icon: "restart_alt"
                            label: "Reset"
                            onClicked: L2dService.resetCamera()
                        }

                        SettingChip {
                            capH: 36
                            fontSize: 14
                            icon: "zoom_in"
                            label: "Zoom In"
                            onClicked: L2dService.zoomCamera(1.15)
                        }

                        SettingChip {
                            capH: 36
                            fontSize: 14
                            icon: "zoom_out"
                            label: "Zoom Out"
                            onClicked: L2dService.zoomCamera(0.85)
                        }
                    }
                }
            }
        }

        Item {
            id: l2dBrowser
            width: l2dCard.innerWidth
            implicitHeight: browserCol.implicitHeight

            property string query: ""
            property string expandedShipId: ""

            Column {
                id: browserCol
                width: parent.width
                spacing: 12

                SettingText {
                    width: parent.width
                    label: "Search model"
                    sublabel: "Filter ships by name or skin prefab"
                    placeholder: "e.g. Takao, Laffey, gaoxiong..."
                    value: l2dBrowser.query
                    onSubmitted: text => l2dBrowser.query = text.trim()
                    onCleared: l2dBrowser.query = ""
                }

                Repeater {
                    model: {
                        const q = l2dBrowser.query.toLowerCase()
                        const all = L2dService.catalog || []
                        if (!q) {
                            const downloaded = []
                            const others = []
                            for (let i = 0; i < all.length; i++) {
                                const ship = all[i]
                                const hasDl = (ship.skins || []).some(s => L2dService.isDownloaded(s.prefab))
                                if (hasDl) downloaded.push(ship)
                                else if (others.length < 15) others.push(ship)
                            }
                            return downloaded.concat(others).slice(0, 15)
                        }
                        return all.filter(ship => {
                            if (ship.name.toLowerCase().includes(q)) return true
                            if (ship.cnName && ship.cnName.toLowerCase().includes(q)) return true
                            if (ship.jpName && ship.jpName.toLowerCase().includes(q)) return true
                            for (let j = 0; j < (ship.skins || []).length; j++) {
                                const s = ship.skins[j]
                                if (s.prefab.toLowerCase().includes(q) || s.name.toLowerCase().includes(q))
                                    return true
                            }
                            return false
                        }).slice(0, 30)
                    }

                    delegate: Item {
                        id: shipRow
                        required property var modelData
                        readonly property var ship: modelData
                        readonly property bool isExpanded: l2dBrowser.expandedShipId === ship.id
                        readonly property bool hasActive: (ship.skins || []).some(s => s.prefab === L2dService.currentModel)
                        readonly property bool hasDownloaded: (ship.skins || []).some(s => L2dService.isDownloaded(s.prefab))

                        width: browserCol.width
                        implicitHeight: shipHeader.implicitHeight + (isExpanded ? skinsCol.implicitHeight + 10 : 0)

                        Rectangle {
                            id: shipHeader
                            width: parent.width
                            height: 48
                            radius: 10
                            color: isExpanded ? mt.pSurfaceHover : mt.pSurface
                            border.color: hasActive ? mt.accentCyan : (isExpanded ? mt.accentCyan : mt.pSurfaceDivider)
                            border.width: hasActive ? 2 : 1

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: isExpanded ? "▼" : "▶"
                                    color: mt.pInkSub
                                    font.pixelSize: 12
                                    font.family: mt.fontFamily
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ship.name + (ship.cnName ? (" (" + ship.cnName + ")") : "")
                                    color: hasActive ? mt.accentCyan : mt.pInk
                                    font.family: mt.fontFamily
                                    font.bold: hasActive || isExpanded
                                    font.pixelSize: 15
                                }

                                Item {
                                    width: 1
                                    height: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    visible: hasDownloaded
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 20
                                    width: dlTagText.implicitWidth + 10
                                    radius: 10
                                    color: mt.chipFill

                                    Text {
                                        id: dlTagText
                                        anchors.centerIn: parent
                                        text: "Downloaded"
                                        color: mt.chipInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (ship.skins ? ship.skins.length : 0) + " skin(s)"
                                    color: mt.pInkSub
                                    font.family: mt.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (l2dBrowser.expandedShipId === ship.id) {
                                        l2dBrowser.expandedShipId = ""
                                    } else {
                                        l2dBrowser.expandedShipId = ship.id
                                    }
                                }
                            }
                        }

                        Column {
                            id: skinsCol
                            visible: isExpanded
                            anchors.top: shipHeader.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: parent.right
                            spacing: 8

                            Repeater {
                                model: ship.skins || []
                                delegate: Rectangle {
                                    id: skinCard
                                    required property var modelData
                                    readonly property var skin: modelData
                                    readonly property bool downloaded: L2dService.isDownloaded(skin.prefab)
                                    readonly property bool isCurrent: L2dService.currentModel === skin.prefab
                                    readonly property bool isDownloadingThis: L2dService.downloadingPrefab === skin.prefab

                                    width: skinsCol.width
                                    height: 56
                                    radius: 10
                                    color: isCurrent ? mt.pSurfaceHover : mt.pSurface
                                    border.color: isCurrent ? mt.accentCyan : mt.pSurfaceDivider
                                    border.width: isCurrent ? 2 : 1
                                    antialiasing: true

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 12

                                        // Mini preview thumbnail
                                        Rectangle {
                                            id: miniThumb
                                            width: 78
                                            height: 44
                                            radius: 6
                                            color: mt.pSurfaceHover
                                            border.width: 1
                                            border.color: mt.pLine
                                            antialiasing: true

                                            RoundClip {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                radii: [5, 5, 5, 5]

                                                Image {
                                                    anchors.fill: parent
                                                    source: L2dService.previewFor(skin.prefab)
                                                    sourceSize: Qt.size(156, 88)
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                }
                                            }
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - miniThumb.width - actionButtons.width - 24
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: skin.name
                                                color: isCurrent ? mt.accentCyan : mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 13
                                                font.bold: isCurrent
                                            }

                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: skin.prefab + (skin.cnName ? (" · " + skin.cnName) : "")
                                                color: mt.pInkSub
                                                font.family: mt.fontFamily
                                                font.pixelSize: 11
                                            }
                                        }

                                        Item {
                                            id: actionButtons
                                            width: rightRow.implicitWidth
                                            height: parent.height
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                id: rightRow
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.right: parent.right
                                                spacing: 8

                                                Rectangle {
                                                    visible: isCurrent
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 24
                                                    width: activeText.implicitWidth + 12
                                                    radius: 12
                                                    color: mt.accentCyan

                                                    Text {
                                                        id: activeText
                                                        anchors.centerIn: parent
                                                        text: "Active"
                                                        color: mt.textWhite
                                                        font.family: mt.fontFamily
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }
                                                }

                                                Rectangle {
                                                    visible: !isCurrent
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 30
                                                    width: btnLabel.implicitWidth + 18
                                                    radius: 8
                                                    color: isDownloadingThis ? mt.chipFill : (downloaded ? mt.pSurfaceHover : mt.accentCyan)
                                                    border.width: downloaded ? 1 : 0
                                                    border.color: mt.pLine

                                                    Text {
                                                        id: btnLabel
                                                        anchors.centerIn: parent
                                                        text: isDownloadingThis ? "Downloading..." : (downloaded ? "Use" : "Download")
                                                        color: isDownloadingThis ? mt.chipInk : (downloaded ? mt.pInk : mt.textWhite)
                                                        font.family: mt.fontFamily
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: isDownloadingThis ? Qt.ArrowCursor : Qt.PointingHandCursor
                                                        enabled: !isDownloadingThis
                                                        onClicked: {
                                                            if (downloaded) {
                                                                L2dService.setModel(skin.prefab)
                                                            } else {
                                                                L2dService.downloadModel(skin.prefab, (ok, _) => {
                                                                    if (ok) {
                                                                        L2dService.setModel(skin.prefab)
                                                                    }
                                                                })
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SectionCard {
        title: "Widgets"

        SettingChoice {
            label: "Default monitor"
            sublabel: "Where a widget goes when it has no monitor of its own, or its monitor is switched off"
            current: DesktopMonitors.defaultScreen
            options: DesktopMonitors.choices
            onPicked: id => DesktopMonitors.setDefault(id)
        }

        SettingToggle {
            icon: EditMode.widgetsLocked ? "lock" : "lock_open"
            label: "Unlock widgets to move them"
            detail: EditMode.widgetsLocked ? "Locked" : "Drag them on the desktop"
            checked: !EditMode.widgetsLocked
            onToggled: EditMode.toggleWidgetsLocked()
        }

        SettingToggle {
            icon: "schedule"
            label: "Clock"
            checked: ClockService.shown
            onToggled: ClockService.setShown(!ClockService.shown)
        }

        SettingChoice {
            label: "Clock design"
            current: String(ClockService.design)
            options: [
                { id: "0", label: "Keys", icon: "piano" },
                { id: "1", label: "Tower", icon: "view_column" },
                { id: "2", label: "Sticker", icon: "sticky_note_2" },
                { id: "3", label: "Stack", icon: "stacks" }
            ]
            onPicked: id => ClockService.setDesign(Number(id))
        }

        SettingToggle {
            icon: "partly_cloudy_day"
            label: "Weather card"
            detail: "Place and unit: Settings > General > Weather"
            checked: WeatherCardService.shown
            onToggled: WeatherCardService.setShown(!WeatherCardService.shown)
        }

        SettingChoice {
            label: "Weather card style"
            sublabel: "Minimal keeps the plate and the next hours, nothing else. Same 2 x 2 size"
            current: WeatherCardService.style
            options: [
                { id: "classic", label: "Classic", icon: "dashboard" },
                { id: "minimal", label: "Minimal", icon: "crop_square" }
            ]
            onPicked: id => WeatherCardService.setStyle(id)
        }

        SettingToggle {
            icon: "calendar_month"
            label: "Calendar card"
            checked: CalendarCardService.shown
            onToggled: CalendarCardService.setShown(!CalendarCardService.shown)
        }

        SettingChoice {
            label: "Calendar card size"
            sublabel: "2 x 2 is the same size as the clock and weather cards"
            current: CalendarCardService.size
            options: [
                { id: "full", label: "Full", icon: "open_in_full" },
                { id: "2x2", label: "2 x 2", icon: "close_fullscreen" }
            ]
            onPicked: id => CalendarCardService.setSize(id)
        }

        SettingToggle {
            icon: "task_alt"
            label: "To-Do"
            checked: TodoService.shown
            onToggled: TodoService.setShown(!TodoService.shown)
        }

        SettingChoice {
            label: "To-Do size"
            sublabel: "2 x 2 is the same size as the clock and weather cards"
            current: TodoService.size
            options: [
                { id: "full", label: "Full", icon: "open_in_full" },
                { id: "2x2", label: "2 x 2", icon: "close_fullscreen" }
            ]
            onPicked: id => TodoService.setSize(id)
        }

        SettingToggle {
            icon: "lyrics"
            label: "Lyrics"
            detail: "The words of the song that is playing, on the desktop"
            checked: LyricsService.shown
            onToggled: LyricsService.setShown(!LyricsService.shown)
        }

        SettingChoice {
            label: "Lyrics source"
            sublabel: "Auto takes the best one for each song. Pick one to use it whenever it has the song"
            current: LyricsService.preferred
            options: [{ id: "auto", label: "Auto", icon: "auto_awesome" }].concat(LyricsService.providers.map(p => ({ id: p.id, label: p.name })))
            onPicked: id => LyricsService.setPreferred(id)
        }

        SettingToggle {
            icon: "text_fields"
            label: "Word by word"
            detail: "Light each word when it is sung, where a source has the timing. Off lights the whole line at once"
            checked: LyricsService.wordsOn
            onToggled: LyricsService.setWords(!LyricsService.wordsOn)
        }

        SettingToggle {
            icon: "comments_disabled"
            label: "Hide no-lyrics messages"
            detail: "Show nothing in the middle when a song has no synced lyrics or is an instrumental. The track title stays"
            checked: LyricsService.hideNotes
            onToggled: LyricsService.setHideNotes(!LyricsService.hideNotes)
        }

        SettingToggle {
            icon: "badge"
            label: "User card"
            detail: "Player ID card with avatar, system info, uptime, and daily progress lane"
            checked: UserCardService.shown
            onToggled: UserCardService.setShown(!UserCardService.shown)
        }

        SettingToggle {
            icon: "sticky_note_2"
            label: "Sticky notes"
            detail: "Desktop sticky notes with washi tapes, color chips, and pinning"
            checked: NotesService.shown
            onToggled: NotesService.setShown(!NotesService.shown)
        }
    }
}
