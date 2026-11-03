import QtQuick
import Quickshell
import qs.services
import qs.modules.common.widgets

// Desktop: the wallpaper and how it changes, and the widgets on the desktop.
// (The palette that follows the wallpaper is on the Appearance page.)
SettingsPage {
    id: page

    SectionCard {
        id: wallpaperCard
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

        // Folder choices: All plus first-level subfolders
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

        // Search wallpaper by filename
        SettingText {
            width: wallpaperCard.innerWidth
            label: "Search wallpaper"
            sublabel: "Filter pictures by filename"
            placeholder: "e.g. anime, mountain, cyberpunk..."
            value: wpBrowser.query
            onSubmitted: text => {
                wpBrowser.query = text.trim()
                wpGrid.pageIndex = 0
            }
            onCleared: {
                wpBrowser.query = ""
                wpGrid.pageIndex = 0
            }
        }

        // Folder Chips
        Flow {
            width: wallpaperCard.innerWidth
            spacing: 10

            Repeater {
                model: wallpaperCard.folderChoices

                delegate: SettingChip {
                    required property var modelData

                    label: modelData.label
                    icon: modelData.path === "" ? "photo_library" : "folder"
                    selected: WallpaperService.customFolder === modelData.path
                    onClicked: {
                        WallpaperService.setFolder(modelData.path)
                        wpGrid.pageIndex = 0
                    }
                }
            }
        }

        // Wallpaper Grid with 12 items per page (3 rows x 4 columns) & Pagination
        Item {
            id: wpBrowser
            width: wallpaperCard.innerWidth
            implicitHeight: wpBrowser.filteredFiles.length === 0
                    ? 140 : wpGrid.height + (wpPager.visible ? wpPager.height + 14 : 0)

            property string query: ""

            readonly property var filteredFiles: {
                const q = wpBrowser.query.toLowerCase().trim()
                const all = WallpaperService.files || []
                if (!q) return all
                return all.filter(f => {
                    const name = f.slice(f.lastIndexOf("/") + 1).toLowerCase()
                    return name.includes(q)
                })
            }

            GridView {
                id: wpGrid

                readonly property real gap: 12
                readonly property int columns: 4
                readonly property int rows: 3
                readonly property int perPage: wpGrid.rows * wpGrid.columns
                property int pageIndex: 0
                readonly property int pageCount: Math.max(1, Math.ceil(wpBrowser.filteredFiles.length / wpGrid.perPage))

                readonly property real cellW: Math.floor((wpBrowser.width - (wpGrid.columns - 1) * wpGrid.gap) / wpGrid.columns)
                readonly property real cellH: Math.round(wpGrid.cellW * 9 / 16)

                width: wpBrowser.width
                height: wpGrid.rows * wpGrid.cellH + (wpGrid.rows - 1) * wpGrid.gap
                visible: wpBrowser.filteredFiles.length > 0
                interactive: false
                clip: true
                cellWidth: wpGrid.cellW + wpGrid.gap
                cellHeight: wpGrid.cellH + wpGrid.gap
                model: wpBrowser.filteredFiles.slice(wpGrid.pageIndex * wpGrid.perPage, (wpGrid.pageIndex + 1) * wpGrid.perPage)

                delegate: Rectangle {
                    id: wpCell

                    required property string modelData

                    readonly property string thumb: WallpaperService.thumbs[wpCell.modelData] ?? ""
                    readonly property bool current: wpCell.modelData === WallpaperService.current
                    readonly property bool hovered: wpArea.containsMouse

                    width: wpGrid.cellW
                    height: wpGrid.cellH
                    radius: 14
                    color: mt.pSurfaceHover
                    border.width: 3
                    border.color: wpCell.current ? mt.accentMint : wpCell.hovered ? mt.pInkSub : mt.pLine
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
                            source: "file://" + (wpCell.thumb !== "" ? wpCell.thumb : wpCell.modelData)
                            sourceSize: Qt.size(wpGrid.cellW * 1.5, wpGrid.cellH * 1.5)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    // The one on the desktop now
                    Rectangle {
                        anchors.centerIn: parent
                        visible: wpCell.current
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
                        id: wpArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperService.setWallpaper(wpCell.modelData, "")
                    }
                }
            }

            // Pager for static wallpaper
            Row {
                id: wpPager

                visible: wpBrowser.filteredFiles.length > 0 && wpGrid.pageCount > 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: wpGrid.bottom
                anchors.topMargin: 14
                spacing: 14

                SettingChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_left"
                    opacity: wpGrid.pageIndex > 0 ? 1 : 0.45
                    onClicked: if (wpGrid.pageIndex > 0) wpGrid.pageIndex--
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (wpGrid.pageIndex + 1) + " / " + wpGrid.pageCount
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 18
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                SettingChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "chevron_right"
                    opacity: wpGrid.pageIndex < wpGrid.pageCount - 1 ? 1 : 0.45
                    onClicked: if (wpGrid.pageIndex < wpGrid.pageCount - 1) wpGrid.pageIndex++
                }
            }

            // Empty state notice
            Column {
                anchors.centerIn: parent
                visible: wpBrowser.filteredFiles.length === 0
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
                    text: wpBrowser.query !== "" ? "No wallpapers matching \"" + wpBrowser.query + "\""
                        : "No pictures in " + WallpaperService.directoryShort
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
            }
        }

        Connections {
            target: WallpaperService

            function onCurrentChanged() {
                const at = wpBrowser.filteredFiles.indexOf(WallpaperService.current)
                if (at >= 0)
                    wpGrid.pageIndex = Math.floor(at / wpGrid.perPage)
            }

            function onFilesChanged() {
                if (wpGrid.pageIndex > wpGrid.pageCount - 1)
                    wpGrid.pageIndex = Math.max(0, wpGrid.pageCount - 1)
            }
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

        SettingChoice {
            label: "Layout"
            sublabel: "Mirror draws the first screen's model on every other screen with one shared render, saving memory; only the first screen stays interactive"
            current: L2dService.currentLayout
            options: [
                { id: "independent", label: "Independent", icon: "grid_view" },
                { id: "mirror", label: "Mirror", icon: "content_copy" }
            ]
            onPicked: id => L2dService.setLayout(id)
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

        SettingToggle {
            icon: "speed"
            label: "High refresh rate (60 FPS)"
            detail: L2dService.currentFps === 60 ? "Smooth 60 FPS animation (Active). Toggle for 30 FPS power-save mode." : "Power-saving 30 FPS animation. Toggle for ultra-smooth 60 FPS."
            checked: L2dService.currentFps === 60
            onToggled: L2dService.toggleFps()
        }

        SettingToggle {
            icon: "power_settings_new"
            label: "Pause on fullscreen"
            detail: "Freeze rendering when an application is fullscreen to save GPU. Disable to keep animating under transparent acrylic windows and tiling gaps."
            checked: L2dService.currentPauseMode !== "never"
            onToggled: L2dService.setPauseMode(checked ? "fullscreen" : "never")
        }

        SettingToggle {
            icon: "palette"
            label: "Theme colors from character"
            detail: "The shell theme follows this model and its background while the wall runs; the wallpaper's own palette returns when it stops"
            checked: L2dService.liveTheme
            onToggled: L2dService.toggleLiveTheme()
        }

        SettingAction {
            icon: "brush"
            label: "Apply colors now"
            detail: "Re-extract the palette from the current model and background"
            onActivated: L2dService.applyPalette(true)
        }

        SettingAction {
            icon: "cleaning_services"
            label: "Model storage"
            detail: L2dService.cacheStatusText() + " — clean the oldest unpinned models down to the quota (the active model and pinned ones are kept, everything re-downloads on demand)"
            onActivated: L2dService.cacheClean()
        }

        Rectangle {
            id: l2dActiveFrame
            width: l2dCard.innerWidth
            height: implicitHeight
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
            height: implicitHeight
            implicitHeight: browserCol.implicitHeight

            property string query: ""
            property string filterTab: "all"
            readonly property int perPage: 12
            property int pageIndex: 0
            readonly property int pageCount: Math.max(1, Math.ceil(inventoryGrid.skinList.length / l2dBrowser.perPage))

            Column {
                id: browserCol
                width: parent.width
                spacing: 14
                height: childrenRect.height

                SettingText {
                    width: parent.width
                    label: "Search character"
                    sublabel: "Filter ships by name or skin prefab"
                    placeholder: "e.g. Takao, Laffey, gaoxiong, bikini..."
                    value: l2dBrowser.query
                    onSubmitted: text => {
                        l2dBrowser.query = text.trim()
                        l2dBrowser.pageIndex = 0
                    }
                    onCleared: {
                        l2dBrowser.query = ""
                        l2dBrowser.pageIndex = 0
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
                            l2dBrowser.pageIndex = 0
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
                            l2dBrowser.pageIndex = 0
                        }
                    }
                }

                // Inventory Grid of Cards (12 models per page, 3 columns)
                Flow {
                    id: inventoryGrid
                    width: parent.width
                    spacing: 10


                    readonly property var skinList: {
                        const q = l2dBrowser.query.toLowerCase()
                        const tab = l2dBrowser.filterTab
                        const allShips = L2dService.catalog || []
                        const list = []
                        const seenPrefabs = ({})

                        for (let i = 0; i < allShips.length; i++) {
                            const ship = allShips[i]
                            const skins = ship.skins || []
                            for (let j = 0; j < skins.length; j++) {
                                const s = skins[j]
                                seenPrefabs[s.prefab] = true
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

                        // Disk fallback: Ensure any model on disk in downloadedModels is never hidden
                        const dl = L2dService.downloadedModels || []
                        for (let k = 0; k < dl.length; k++) {
                            const pref = dl[k]
                            if (seenPrefabs[pref]) continue
                            if (q && !pref.toLowerCase().includes(q)) continue
                            list.push({
                                shipName: pref,
                                shipCn: "",
                                skinName: "Live2D Model",
                                prefab: pref,
                                isDownloaded: true,
                                isActive: pref === L2dService.currentModel
                            })
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
                        model: inventoryGrid.skinList.slice(l2dBrowser.pageIndex * l2dBrowser.perPage, (l2dBrowser.pageIndex + 1) * l2dBrowser.perPage)

                        delegate: Rectangle {
                            id: itemCard
                            required property var modelData
                            readonly property var skin: modelData
                            readonly property bool isCurrent: skin.isActive
                            readonly property bool isDownloaded: skin.isDownloaded
                            readonly property bool isDownloadingThis: L2dService.downloadingPrefab === skin.prefab

                            width: Math.floor((inventoryGrid.width - 20) / 3)
                            height: thumbBox.height + infoCol.height + 18
                            radius: 12
                            clip: true
                            color: isCurrent ? mt.pSurfaceHover : (cardMouse.containsMouse ? mt.pSurfaceHover : mt.pSurface)
                            border.color: isCurrent ? mt.accentCyan : (cardMouse.containsMouse ? mt.accentCyan : mt.pSurfaceDivider)
                            border.width: isCurrent ? 2 : 1
                            antialiasing: true

                            Column {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5

                                // 16:9 Thumbnail
                                Rectangle {
                                    id: thumbBox
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
                                            sourceSize: Qt.size(thumbBox.width * 2, thumbBox.height * 2)
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
                                    id: infoCol
                                    width: parent.width
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

                // Pager for Live2D
                Row {
                    id: l2dPager
                    visible: inventoryGrid.skinList.length > 0 && l2dBrowser.pageCount > 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    SettingChip {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_left"
                        opacity: l2dBrowser.pageIndex > 0 ? 1 : 0.45
                        onClicked: if (l2dBrowser.pageIndex > 0) l2dBrowser.pageIndex--
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (l2dBrowser.pageIndex + 1) + " / " + l2dBrowser.pageCount
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }

                    SettingChip {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_right"
                        opacity: l2dBrowser.pageIndex < l2dBrowser.pageCount - 1 ? 1 : 0.45
                        onClicked: if (l2dBrowser.pageIndex < l2dBrowser.pageCount - 1) l2dBrowser.pageIndex++
                    }
                }

                // Empty state
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: inventoryGrid.skinList.length === 0
                    spacing: 8

                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 40
                        name: "search_off"
                        weight: mt.settingsIconWeight
                        color: mt.pInkSub
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No models found matching \"" + l2dBrowser.query + "\""
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Connections {
            target: L2dService

            function onCurrentModelChanged() {
                const list = inventoryGrid.skinList
                for (let i = 0; i < list.length; i++) {
                    if (list[i].prefab === L2dService.currentModel) {
                        l2dBrowser.pageIndex = Math.floor(i / l2dBrowser.perPage)
                        break
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
