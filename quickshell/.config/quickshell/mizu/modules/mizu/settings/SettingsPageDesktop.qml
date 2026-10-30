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

        SettingToggle {
            icon: L2dService.placementLocked ? "lock" : "lock_open"
            label: "Lock character placement"
            detail: "Freeze position & zoom to enable interactive touch & drag on the character"
            checked: L2dService.placementLocked
            onToggled: L2dService.togglePlacementLocked()
        }

        SettingToggle {
            icon: "remove_red_eye"
            label: "Gaze follow cursor"
            detail: "Model head & eyes smoothly follow cursor across the screen"
            checked: L2dService.gaze
            onToggled: L2dService.toggleGaze()
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
                        text: L2dService.placementLocked
                            ? "Position locked. Touch and drag the character directly to interact."
                            : "Drag desktop background to move, mouse wheel to zoom."
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
            property string filterTab: "all"
            property int displayLimit: 24

            Column {
                id: browserCol
                width: parent.width
                spacing: 14

                SettingText {
                    width: parent.width
                    label: "Search character"
                    sublabel: "Filter ships by name or skin prefab"
                    placeholder: "e.g. Takao, Laffey, gaoxiong, bikini..."
                    value: l2dBrowser.query
                    onSubmitted: text => {
                        l2dBrowser.query = text.trim()
                        l2dBrowser.displayLimit = 24
                    }
                    onCleared: {
                        l2dBrowser.query = ""
                        l2dBrowser.displayLimit = 24
                    }
                }

                // Filter tabs: All vs Downloaded
                Row {
                    spacing: 8

                    SettingChip {
                        capH: 34
                        fontSize: 12
                        icon: "grid_view"
                        label: "All Models"
                        selected: l2dBrowser.filterTab === "all"
                        onClicked: {
                            l2dBrowser.filterTab = "all"
                            l2dBrowser.displayLimit = 24
                        }
                    }

                    SettingChip {
                        capH: 34
                        fontSize: 12
                        icon: "download_done"
                        label: "Downloaded (" + (L2dService.downloadedModels ? L2dService.downloadedModels.length : 0) + ")"
                        selected: l2dBrowser.filterTab === "downloaded"
                        onClicked: {
                            l2dBrowser.filterTab = "downloaded"
                            l2dBrowser.displayLimit = 24
                        }
                    }
                }

                // Inventory Grid of Cards
                Flow {
                    id: inventoryGrid
                    width: parent.width
                    spacing: 10

                    readonly property var skinList: {
                        const q = l2dBrowser.query.toLowerCase()
                        const tab = l2dBrowser.filterTab
                        const allShips = L2dService.catalog || []
                        const list = []

                        for (let i = 0; i < allShips.length; i++) {
                            const ship = allShips[i]
                            const skins = ship.skins || []
                            for (let j = 0; j < skins.length; j++) {
                                const s = skins[j]
                                const isDl = L2dService.isDownloaded(s.prefab)
                                if (tab === "downloaded" && !isDl) continue

                                if (q) {
                                    const matchShip = (ship.name && ship.name.toLowerCase().includes(q))
                                        || (ship.cnName && ship.cnName.toLowerCase().includes(q))
                                        || (ship.jpName && ship.jpName.toLowerCase().includes(q))
                                    const matchSkin = (s.name && s.name.toLowerCase().includes(q))
                                        || (s.prefab && s.prefab.toLowerCase().includes(q))
                                        || (s.cnName && s.cnName.toLowerCase().includes(q))
                                        || (s.jpName && s.jpName.toLowerCase().includes(q))
                                    if (!matchShip && !matchSkin) continue
                                }

                                list.push({
                                    shipName: ship.name,
                                    shipCn: ship.cnName || "",
                                    skinName: s.name,
                                    prefab: s.prefab,
                                    isDownloaded: isDl,
                                    isActive: s.prefab === L2dService.currentModel
                                })
                            }
                        }
                        list.sort((a, b) => {
                            if (a.isActive) return -1
                            if (b.isActive) return 1
                            if (a.isDownloaded !== b.isDownloaded) return a.isDownloaded ? -1 : 1
                            return a.shipName.localeCompare(b.shipName)
                        })
                        return list
                    }

                    Repeater {
                        model: inventoryGrid.skinList.slice(0, l2dBrowser.displayLimit)

                        delegate: Rectangle {
                            id: itemCard
                            required property var modelData
                            readonly property var skin: modelData
                            readonly property bool isCurrent: skin.isActive
                            readonly property bool isDownloaded: skin.isDownloaded
                            readonly property bool isDownloadingThis: L2dService.downloadingPrefab === skin.prefab

                            width: Math.floor((inventoryGrid.width - 20) / 3)
                            height: 172
                            radius: 12
                            color: isCurrent ? mt.pSurfaceHover : (cardMouse.containsMouse ? mt.pSurfaceHover : mt.pSurface)
                            border.color: isCurrent ? mt.accentCyan : (cardMouse.containsMouse ? mt.accentCyan : mt.pSurfaceDivider)
                            border.width: isCurrent ? 2 : 1
                            antialiasing: true

                            Column {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                // 16:9 Thumbnail
                                Rectangle {
                                    width: parent.width
                                    height: Math.floor(parent.width * 9 / 16)
                                    radius: 8
                                    color: mt.surface
                                    clip: true

                                    RoundClip {
                                        anchors.fill: parent
                                        radii: [8, 8, 8, 8]

                                        Image {
                                            anchors.fill: parent
                                            source: L2dService.previewFor(skin.prefab)
                                            sourceSize: Qt.size(240, 135)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                    }

                                    // Active Badge
                                    Rectangle {
                                        visible: isCurrent
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 4
                                        height: 18
                                        width: activeBadgeText.implicitWidth + 8
                                        radius: 4
                                        color: mt.accentCyan

                                        Text {
                                            id: activeBadgeText
                                            anchors.centerIn: parent
                                            text: "ACTIVE"
                                            color: mt.textWhite
                                            font.family: mt.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    // Ready Badge
                                    Rectangle {
                                        visible: !isCurrent && isDownloaded
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 4
                                        height: 18
                                        width: readyBadgeText.implicitWidth + 8
                                        radius: 4
                                        color: mt.scrim

                                        Text {
                                            id: readyBadgeText
                                            anchors.centerIn: parent
                                            text: "READY"
                                            color: mt.accentMint
                                            font.family: mt.fontFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }

                                    // Downloading Overlay
                                    Rectangle {
                                        visible: isDownloadingThis
                                        anchors.fill: parent
                                        color: Qt.rgba(mt.scrim.r, mt.scrim.g, mt.scrim.b, 0.82)

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MaterialIcon {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                name: "downloading"
                                                size: 20
                                                color: mt.accentCyan
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: L2dService.downloadProgress || "Downloading..."
                                                color: mt.accentCyan
                                                font.family: mt.fontFamily
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }

                                // Ship & Skin Info
                                Column {
                                    width: parent.width
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: skin.shipName
                                        color: isCurrent ? mt.accentCyan : mt.pInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 12
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: skin.skinName
                                        color: mt.pInkSub
                                        font.family: mt.fontFamily
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: isDownloadingThis ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onClicked: {
                                    if (isDownloadingThis) return
                                    if (isDownloaded) {
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

                // Show more button
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: inventoryGrid.skinList.length > l2dBrowser.displayLimit

                    SettingChip {
                        capH: 36
                        fontSize: 13
                        icon: "expand_more"
                        label: "Load more (" + (inventoryGrid.skinList.length - l2dBrowser.displayLimit) + " remaining)"
                        onClicked: l2dBrowser.displayLimit += 24
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
