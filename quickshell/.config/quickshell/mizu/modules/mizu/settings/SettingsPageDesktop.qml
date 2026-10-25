import QtQuick
import qs.services

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
    }
}
