import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import qs.services
import qs.modules.common
import qs.modules.mizu.background
import qs.modules.mizu.bar
import qs.modules.mizu.desktopWidgets
import qs.modules.mizu.launcher
import qs.modules.mizu.lock
import qs.modules.mizu.notificationPopup
import qs.modules.mizu.onScreenDisplay
import qs.modules.mizu.polkit
import qs.modules.mizu.quickPanel

ShellRoot {
    id: shellRoot

    // Hot reload watch enabled during normal operation
    settings.watchFiles: true

    // The Wayland background layer: one per screen on WlrLayer.Background
    Variants {
        id: wallpaperLayers
        model: Quickshell.screens
        WallpaperLayer {}
    }

    // First-run convenience: seed default wallpaper if none is configured
    FolderListModel {
        id: fallbackWallpapers
        folder: WallpaperService.directoryUrl
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name

        onCountChanged: shellRoot.applyFallbackWallpaper()
    }

    Connections {
        target: WallpaperService
        function onRestoringChanged() {
            shellRoot.applyFallbackWallpaper()
        }
        function onReadyChanged() {
            shellRoot.applyFallbackWallpaper()
        }
    }

    property string defaultSeed: ""
    readonly property string bundledWallpaper: Directories.asset("images/default-wallpaper.png")
    readonly property string seedScript: Directories.script("wallpapers/default-wallpaper.sh")

    function applyFallbackWallpaper() {
        if (!WallpaperService.ready || WallpaperService.defaultPath.length > 0)
            return
        if (shellRoot.defaultSeed === "") {
            shellRoot.defaultSeed = "running"
            seedDefaultWallpaper.running = true
            return
        }
        if (shellRoot.defaultSeed === "failed" && fallbackWallpapers.count > 0)
            WallpaperService.ensureDefault(fallbackWallpapers.get(0, "filePath"))
    }

    Process {
        id: seedDefaultWallpaper
        command: ["sh", shellRoot.seedScript, "seed", shellRoot.bundledWallpaper, WallpaperService.directory]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path !== "") {
                    shellRoot.defaultSeed = "done"
                    WallpaperService.ensureDefault(path)
                } else {
                    shellRoot.defaultSeed = "failed"
                    shellRoot.applyFallbackWallpaper()
                }
            }
        }
    }

    // Core singletons & background services
    TraySource {
        id: trayState
    }

    PolkitPrompt {}

    OSDPopup {}

    ReloadPopup {}

    BatteryAlertService {}

    Idle {}

    // Quick Panel & Launcher state
    QuickSource {
        id: quickState
        active: panel.up || panel.settingsShown
    }

    NotificationSource {
        id: notificationState
        doNotDisturb: !quickState.notificationsOn
        quietWhenFullscreen: SettingsService.flag("notify.quietFullscreen")
        alertStyle: SettingsService.get("notify.style")
        popupsSuppressed: panel.up
    }

    NotificationPopup {
        source: notificationState
    }

    AppSource {
        id: appState
    }

    LauncherPhone {
        id: launcherPhone
        source: appState
        quickPanel: panel
    }

    QuickPanel {
        id: panel
        source: quickState
        notificationSource: notificationState
        barWindows: bars.instances
        picker: wallpaperEntry
        appSource: appState
        launcher: launcherPhone
    }

    QtObject {
        id: wallpaperEntry

        function openOn(screen, which) {
            panel.openWallpapers(screen, which)
        }

        function toggleOn(screen, which) {
            panel.toggleWallpapersOn(screen, which)
        }
    }

    Connections {
        target: panel

        function onOpenChanged() {
            if (panel.open)
                launcherPhone.close()
        }

        function onSettingsOpenChanged() {
            if (panel.settingsOpen)
                launcherPhone.close()
        }
    }

    // The Bar: one per screen on the configured position
    Variants {
        id: bars
        model: {
            const list = []
            if (BarPositionService.loaded && GameModeService.loaded && SettingsService.flag("bar.visible")) {
                for (const s of Quickshell.screens)
                    list.push({ screen: s, position: BarPositionService.position })
            }
            return list
        }
        Bar {
            traySource: trayState
            quickPanel: panel
            picker: wallpaperEntry
        }
    }

    // Session lockscreen
    Lockscreen {}

    // Bar IPC
    IpcHandler {
        target: "bar"

        function toggle(): void {
            SettingsService.toggle("bar.visible")
        }

        function show(): void {
            SettingsService.set("bar.visible", true)
        }

        function hide(): void {
            SettingsService.set("bar.visible", false)
        }

        function peek(): void {
            for (const b of bars.instances)
                b.peek()
        }

        function hidemode(mode: string): void {
            if (mode === "off" || mode === "auto")
                SettingsService.set("bar.hideMode", mode)
        }
    }

    // Unified Mizu IPC handler
    MizuIpc {
        launcher: launcherPhone
        quickPanel: panel
    }

    // Desktop Widgets: staggered lifecycle and lock sleep support
    readonly property bool widgetsAllowed: GameModeService.loaded && !GameModeService.enabled && !LockState.desktopAsleep
    property int wakeStep: 99

    function woke(n) {
        return shellRoot.wakeStep >= n
    }

    readonly property bool desktopAsleep: LockState.desktopAsleep
    onDesktopAsleepChanged: {
        wakeTimer.stop()
        shellRoot.wakeStep = 0
        if (shellRoot.desktopAsleep) {
            gcTimer.restart()
        } else {
            gcTimer.stop()
            wakeTimer.restart()
        }
    }

    Timer {
        id: wakeTimer
        interval: 90
        repeat: true
        onTriggered: {
            shellRoot.wakeStep = shellRoot.wakeStep + 1
            if (shellRoot.wakeStep >= 12)
                wakeTimer.stop()
        }
    }

    Timer {
        id: gcTimer
        interval: 1500
        onTriggered: {
            try {
                gc()
            } catch (e) {
            }
        }
    }

    property bool todoResetRequested: false
    property bool clockResetRequested: false
    property bool weatherCardResetRequested: false
    property bool calendarCardResetRequested: false
    property bool lyricsResetRequested: false
    property bool userCardResetRequested: false
    property bool notesResetRequested: false

    // Todo Widget
    FocusGate {
        id: todoGate
        widgetId: "todo"
        unloads: true
        screenName: DesktopMonitors.homeFor("todo")
    }

    LazyLoader {
        id: todoWidgetLoader
        active: shellRoot.woke(4) && shellRoot.widgetsAllowed && DesktopMonitors.loaded && ((TodoService.loaded && TodoService.shown && !todoGate.gone) || EditMode.active || shellRoot.todoResetRequested)
        TodoWidget {}
    }

    // Clock Widget
    FocusGate {
        id: clockGate
        widgetId: "clock"
        unloads: true
        screenName: EditMode.homeScreen(ClockService.screenName)
    }

    LazyLoader {
        id: clockWidgetLoader
        active: shellRoot.woke(0) && shellRoot.widgetsAllowed && ((ClockService.loaded && ClockService.shown && !clockGate.gone) || EditMode.active || shellRoot.clockResetRequested)
        ClockWidget {}
    }

    Variants {
        model: WidgetClones.screens["clock"] ?? []

        delegate: LazyLoader {
            id: clClockWidget
            required property string modelData
            active: shellRoot.woke(0) && shellRoot.widgetsAllowed && ClockService.loaded && ClockService.shown
            ClockWidget { clone: true; monitor: clClockWidget.modelData }
        }
    }

    // Weather Card Widget
    FocusGate {
        id: weathercardGate
        widgetId: "weathercard"
        unloads: true
        screenName: EditMode.homeScreen(WeatherCardService.screenName)
    }

    LazyLoader {
        id: weatherCardWidgetLoader
        active: shellRoot.woke(2) && shellRoot.widgetsAllowed && ((WeatherCardService.loaded && WeatherCardService.shown && !weathercardGate.gone) || EditMode.active || shellRoot.weatherCardResetRequested)
        WeatherCardWidget {}
    }

    Variants {
        model: WidgetClones.screens["weathercard"] ?? []

        delegate: LazyLoader {
            id: clWeatherCardWidget
            required property string modelData
            active: shellRoot.woke(2) && shellRoot.widgetsAllowed && WeatherCardService.loaded && WeatherCardService.shown
            WeatherCardWidget { clone: true; monitor: clWeatherCardWidget.modelData }
        }
    }

    // Calendar Card Widget
    FocusGate {
        id: calendarcardGate
        widgetId: "calendarcard"
        unloads: true
        screenName: EditMode.homeScreen(CalendarCardService.screenName)
    }

    LazyLoader {
        id: calendarCardWidgetLoader
        active: shellRoot.woke(3) && shellRoot.widgetsAllowed && ((CalendarCardService.loaded && CalendarCardService.shown && !calendarcardGate.gone) || EditMode.active || shellRoot.calendarCardResetRequested)
        CalendarCardWidget {}
    }

    Variants {
        model: WidgetClones.screens["calendarcard"] ?? []

        delegate: LazyLoader {
            id: clCalendarCardWidget
            required property string modelData
            active: shellRoot.woke(3) && shellRoot.widgetsAllowed && CalendarCardService.loaded && CalendarCardService.shown
            CalendarCardWidget { clone: true; monitor: clCalendarCardWidget.modelData }
        }
    }

    // Lyrics Widget
    FocusGate {
        id: lyricsGate
        widgetId: "lyrics"
        unloads: true
        screenName: EditMode.homeScreen(LyricsService.screenName)
    }

    LazyLoader {
        id: lyricsWidgetLoader
        active: shellRoot.woke(6) && shellRoot.widgetsAllowed && ((LyricsService.loaded && LyricsService.shown && !lyricsGate.gone) || EditMode.active || shellRoot.lyricsResetRequested)
        LyricsWidget {}
    }

    Variants {
        model: WidgetClones.screens["lyrics"] ?? []

        delegate: LazyLoader {
            id: clLyricsWidget
            required property string modelData
            active: shellRoot.woke(6) && shellRoot.widgetsAllowed && LyricsService.loaded && LyricsService.shown
            LyricsWidget { clone: true; monitor: clLyricsWidget.modelData }
        }
    }

    // User Card Widget
    FocusGate {
        id: usercardGate
        widgetId: "usercard"
        unloads: true
        screenName: EditMode.homeScreen(UserCardService.screenName)
    }

    LazyLoader {
        id: userCardWidgetLoader
        active: shellRoot.woke(5) && shellRoot.widgetsAllowed && ((UserCardService.loaded && UserCardService.shown && !usercardGate.gone) || EditMode.active || shellRoot.userCardResetRequested)
        UserCardWidget {}
    }

    Variants {
        model: WidgetClones.screens["usercard"] ?? []

        delegate: LazyLoader {
            id: clUserCardWidget
            required property string modelData
            active: shellRoot.woke(5) && shellRoot.widgetsAllowed && UserCardService.loaded && UserCardService.shown
            UserCardWidget { clone: true; monitor: clUserCardWidget.modelData }
        }
    }

    // Sticky Notes Widget
    LazyLoader {
        id: stickyNotesWidgetLoader
        active: shellRoot.woke(7) && shellRoot.widgetsAllowed && NotesService.loaded && (NotesService.shown || EditMode.active || shellRoot.notesResetRequested)
        StickyNotesWidget { pinnedLayer: false }
    }

    LazyLoader {
        id: stickyNotesPinnedLoader
        active: shellRoot.woke(7) && shellRoot.widgetsAllowed && NotesService.loaded && NotesService.shown && NotesService.pinnedCount > 0
        StickyNotesWidget { pinnedLayer: true }
    }

    // Widget IPCs
    IpcHandler {
        target: "todo"
        function toggle(): void { TodoService.setShown(!TodoService.shown) }
        function show(): void { TodoService.setShown(true) }
        function hide(): void { TodoService.setShown(false) }
        function size(mode: string): void { TodoService.setSize(mode) }
        function toggleSize(): void { TodoService.toggleSize() }
        function resetPosition(): void {
            shellRoot.todoResetRequested = true
            if (todoWidgetLoader.item) todoWidgetLoader.item.resetPosition()
            shellRoot.todoResetRequested = false
        }
    }

    IpcHandler {
        target: "clock"
        function toggle(): void { ClockService.setShown(!ClockService.shown) }
        function show(): void { ClockService.setShown(true) }
        function hide(): void { ClockService.setShown(false) }
        function toggleFormat(): void { ClockService.toggleFormat() }
        function nextDesign(): void { ClockService.cycleDesign() }
        function setDesign(index: int): void { ClockService.setDesign(index) }
        function resetPosition(): void {
            shellRoot.clockResetRequested = true
            if (clockWidgetLoader.item) clockWidgetLoader.item.resetPosition()
            WidgetClones.clearAll("clock")
            shellRoot.clockResetRequested = false
        }
    }

    IpcHandler {
        target: "weathercard"
        function toggle(): void { WeatherCardService.setShown(!WeatherCardService.shown) }
        function show(): void { WeatherCardService.setShown(true) }
        function hide(): void { WeatherCardService.setShown(false) }
        function style(mode: string): void { WeatherCardService.setStyle(mode) }
        function refresh(): void { if (weatherCardWidgetLoader.item) weatherCardWidgetLoader.item.refresh() }
        function resetPosition(): void {
            shellRoot.weatherCardResetRequested = true
            if (weatherCardWidgetLoader.item) weatherCardWidgetLoader.item.resetPosition()
            WidgetClones.clearAll("weathercard")
            shellRoot.weatherCardResetRequested = false
        }
    }

    IpcHandler {
        target: "calendarcard"
        function toggle(): void { CalendarCardService.setShown(!CalendarCardService.shown) }
        function show(): void { CalendarCardService.setShown(true) }
        function hide(): void { CalendarCardService.setShown(false) }
        function size(mode: string): void { CalendarCardService.setSize(mode) }
        function toggleSize(): void { CalendarCardService.toggleSize() }
        function add(title: string, date: string, time: string, kind: string): void {
            CalendarCardService.add({ title: title, date: date, time: time, kind: kind })
        }
        function resetPosition(): void {
            shellRoot.calendarCardResetRequested = true
            if (calendarCardWidgetLoader.item) calendarCardWidgetLoader.item.resetPosition()
            WidgetClones.clearAll("calendarcard")
            shellRoot.calendarCardResetRequested = false
        }
    }

    IpcHandler {
        target: "lyrics"
        function toggle(): void { LyricsService.setShown(!LyricsService.shown) }
        function show(): void { LyricsService.setShown(true) }
        function hide(): void { LyricsService.setShown(false) }
        function nudge(ms: int): void { LyricsService.nudge(ms) }
        function nudgeAll(ms: int): void { LyricsService.nudgeAll(ms) }
        function resetSync(): void { LyricsService.setTrackOffset(0); LyricsService.setSync(0) }
        function refresh(): void { LyricsService.refresh() }
        function words(on: bool): void { LyricsService.setWords(on) }
        function lineMode(on: bool): void { LyricsService.setWords(!on) }
        function hideNotes(on: bool): void { LyricsService.setHideNotes(on) }
        function source(id: string): string { return LyricsService.setPreferred(id) ? "source: " + id : "unknown source: " + id }
        function sources(): string { return LyricsService.sourceReport() }
        function picker(): void { LyricsService.togglePicker("", -1, -1) }
        function debug(): void { LyricsService.debug = !LyricsService.debug }
        function resetPosition(): void {
            shellRoot.lyricsResetRequested = true
            if (lyricsWidgetLoader.item) lyricsWidgetLoader.item.resetPosition()
            WidgetClones.clearAll("lyrics")
            shellRoot.lyricsResetRequested = false
        }
    }

    IpcHandler {
        target: "usercard"
        function toggle(): void { UserCardService.setShown(!UserCardService.shown) }
        function show(): void { UserCardService.setShown(true) }
        function hide(): void { UserCardService.setShown(false) }
        function resetPosition(): void {
            shellRoot.userCardResetRequested = true
            if (userCardWidgetLoader.item) userCardWidgetLoader.item.resetPosition()
            WidgetClones.clearAll("usercard")
            shellRoot.userCardResetRequested = false
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void { NotesService.setShown(!NotesService.shown) }
        function show(): void { NotesService.setShown(true) }
        function hide(): void { NotesService.setShown(false) }
        function add(text: string): void { NotesService.add(text) }
        function create(): void { NotesService.add("") }
        function remove(id: string): void { NotesService.remove(id) }
        function count(): int { return NotesService.count }
        function resetPosition(): void {
            shellRoot.notesResetRequested = true
            if (stickyNotesWidgetLoader.item) stickyNotesWidgetLoader.item.resetPosition()
            shellRoot.notesResetRequested = false
        }
    }

    IpcHandler {
        target: "timer"
        function toggleTimer(): void { TimerService.toggleTimer() }
        function resetTimer(): void { TimerService.resetTimer() }
        function setTimerMinutes(m: int): void { TimerService.setTimerMinutes(m) }
        function addTimerMinute(): void { TimerService.addTimerMinute() }
        function toggleStopwatch(): void { TimerService.toggleStopwatch() }
        function resetStopwatch(): void { TimerService.resetStopwatch() }
        function lapStopwatch(): void { TimerService.lapStopwatch() }
        function togglePomodoro(): void { TimerService.togglePomodoro() }
        function resetPomodoro(): void { TimerService.resetPomodoro() }
        function nextPhase(): void { TimerService.nextPhase(false) }
        function status(): string { return (TimerService.shownMode !== "" ? TimerService.shownMode : "idle") + ": " + TimerService.shownText }
    }
}
