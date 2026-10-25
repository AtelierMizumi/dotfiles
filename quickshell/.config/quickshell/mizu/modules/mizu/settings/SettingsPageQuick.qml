import QtQuick
import Quickshell
import qs.services

// Quick: the things you reach for most, so they're a tap away instead of a
// page deep. Everything here is also somewhere else (the Quick Panel's
// tiles, the bar's buttons, the General / Bar / Desktop pages); it's the
// same state, so changing it here shows up there at once.
SettingsPage {
    id: page

    readonly property var src: host ? host.source : null
    SectionCard {
        title: "Look"

        SettingChoice {
            label: "Mode"
            sublabel: "Auto: light for a bright wallpaper, dark otherwise"
            current: SettingsService.get("theme.mode")
            options: [
                { id: "auto", label: "Auto", icon: "brightness_auto" },
                { id: "light", label: "Light", icon: "light_mode" },
                { id: "dark", label: "Dark", icon: "dark_mode" }
            ]
            onPicked: id => SettingsService.set("theme.mode", id)
        }

        SettingAction {
            tileWidth: 310
            icon: "palette"
            label: "Appearance"
            detail: "Wallpaper, scheme and accent"
            onActivated: if (page.host) page.host.goTo("appearance")
        }
    }

    SectionCard {
        title: "Quick Panel"

        SettingChoice {
            label: "Phone"
            sublabel: "Tilted 2.5D, or flat 2D, for this panel and the Settings (always flat in Game Mode)"
            current: SettingsService.flag("quick.flat") ? "flat" : "tilted"
            options: [
                { id: "tilted", label: "2.5D", icon: "view_in_ar" },
                { id: "flat", label: "2D", icon: "crop_portrait" }
            ]
            onPicked: id => SettingsService.set("quick.flat", id === "flat")
        }

        SettingToggle {
            icon: "blur_on"
            label: "Phone shadow"
            detail: "A soft shadow under the phone (Quick Panel, Apps, Wallpapers, Settings)"
            checked: SettingsService.flag("quick.phoneShadow")
            onToggled: SettingsService.toggle("quick.phoneShadow")
        }
    }

    SectionCard {
        title: "Shell"

        SettingToggle {
            icon: page.src && page.src.notificationsOn ? "notifications_active" : "notifications_off"
            label: "Notifications"
            checked: page.src ? page.src.notificationsOn : true
            onToggled: if (page.src) page.src.toggleNotifications()
        }

        SettingToggle {
            icon: "nightlight"
            label: "Night Light"
            checked: page.src ? page.src.nightLightOn : false
            onToggled: if (page.src) page.src.toggleNightLight()
        }

        SettingToggle {
            icon: "coffee"
            label: "Keep Awake"
            checked: page.src ? page.src.keepAwakeOn : false
            onToggled: if (page.src) page.src.toggleKeepAwake()
        }

        SettingToggle {
            icon: "sports_esports"
            label: "Game Mode"
            checked: page.src ? page.src.gameModeOn : false
            onToggled: if (page.src) page.src.toggleGameMode()
        }

        SettingAction {
            icon: "wallpaper"
            label: "Next wallpaper"
            detail: "The palette follows it"
            onActivated: WallpaperService.next(1)
        }

        SettingStepper {
            icon: "aspect_ratio"
            label: "Shell size"
            from: 0.5
            to: 3
            step: 0.05
            decimals: 2
            suffix: "×"
            value: page.host ? ShellScale.effectiveFor(page.host.screenName) : 1
            onMoved: v => { if (page.host) ShellScale.setScale(page.host.screenName, v) }
        }

        SettingToggle {
            icon: "visibility"
            label: "Bar"
            checked: SettingsService.flag("bar.visible")
            onToggled: SettingsService.toggle("bar.visible")
        }
    }

    SectionCard {
        title: "Bar"

        SettingChoice {
            label: "Style"
            current: BarStyleService.style
            options: [
                { id: "float", label: "Float", edge: "top", variant: "float" },
                { id: "straight", label: "Straight", edge: "top", variant: "straight" },
                { id: "transparent", label: "Transparent", edge: "top", variant: "transparent" },
                { id: "capsule", label: "Capsule", edge: "top", variant: "capsule" }
            ]
            onPicked: id => BarStyleService.setStyle(id)
        }

        SettingChoice {
            label: "Position"
            current: BarPositionService.position
            options: [
                { id: "top", label: "Top", edge: "top" },
                { id: "right", label: "Right", edge: "right" },
                { id: "bottom", label: "Bottom", edge: "bottom" },
                { id: "left", label: "Left", edge: "left" }
            ]
            onPicked: id => BarPositionService.setPosition(id)
        }
    }

    SectionCard {
        title: "Desktop widgets"

        SettingToggle {
            icon: "schedule"
            label: "Clock"
            checked: ClockService.shown
            onToggled: ClockService.setShown(!ClockService.shown)
        }

        SettingToggle {
            icon: "partly_cloudy_day"
            label: "Weather card"
            checked: WeatherCardService.shown
            onToggled: WeatherCardService.setShown(!WeatherCardService.shown)
        }

        SettingToggle {
            icon: "calendar_month"
            label: "Calendar card"
            checked: CalendarCardService.shown
            onToggled: CalendarCardService.setShown(!CalendarCardService.shown)
        }

        SettingToggle {
            icon: "lyrics"
            label: "Lyrics"
            detail: "The words of the song that is playing, on the desktop"
            checked: LyricsService.shown
            onToggled: LyricsService.setShown(!LyricsService.shown)
        }

        SettingToggle {
            icon: "task_alt"
            label: "To-Do"
            checked: TodoService.shown
            onToggled: TodoService.setShown(!TodoService.shown)
        }

        SettingToggle {
            icon: EditMode.widgetsLocked ? "lock" : "lock_open"
            label: "Unlock widgets to move them"
            checked: !EditMode.widgetsLocked
            onToggled: EditMode.toggleWidgetsLocked()
        }
    }
}
