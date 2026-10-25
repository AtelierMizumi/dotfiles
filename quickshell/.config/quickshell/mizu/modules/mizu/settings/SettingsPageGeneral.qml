import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// General: how the shell behaves, apart from how it looks. Time and units,
// what the Quick Panel and notifications do, the launcher, the lockscreen,
// and the shell itself.
SettingsPage {
    id: page

    SectionCard {
        title: "Time & alerts"

        SettingToggle {
            icon: "schedule"
            label: "24-hour time"
            checked: SettingsService.flag("time.use24h")
            onToggled: {
                const on = !SettingsService.flag("time.use24h")
                SettingsService.set("time.use24h", on)
                // The desktop clock card keeps its own copy of this.
                ClockService.setUse24h(on)
            }
        }

        SettingToggle {
            icon: "thermostat"
            label: "Fahrenheit"
            detail: SettingsService.flag("weather.fahrenheit") ? "°F" : "°C"
            checked: SettingsService.flag("weather.fahrenheit")
            onToggled: SettingsService.toggle("weather.fahrenheit")
        }

        SettingChoice {
            label: "Notification alert"
            sublabel: "Phone: the Quick Panel's phone rises. Popups: a stack of cards in the corner"
            current: SettingsService.get("notify.style")
            options: [
                { id: "phone", label: "Phone", icon: "smartphone" },
                { id: "popups", label: "Popups", icon: "notifications_active" }
            ]
            onPicked: id => SettingsService.set("notify.style", id)
        }

        SettingToggle {
            icon: "do_not_disturb_on"
            label: "Quiet while fullscreen"
            detail: "No popups or buzz while a window is fullscreen. They still wait in the list; urgent ones break through"
            checked: SettingsService.flag("notify.quietFullscreen")
            onToggled: SettingsService.toggle("notify.quietFullscreen")
        }

        SettingToggle {
            icon: "battery_alert"
            label: "Low battery warnings"
            detail: "A notification at 20, 15, 10 and 5 % on battery. The last two are urgent and break through do-not-disturb"
            checked: SettingsService.flag("battery.alerts")
            onToggled: SettingsService.toggle("battery.alerts")
        }

        SettingToggle {
            icon: "vibration"
            label: "Buzz on arrival"
            detail: SettingsService.get("notify.style") === "phone" ? "" : "Phone alert only"
            checked: SettingsService.flag("notify.buzz")
            onToggled: SettingsService.toggle("notify.buzz")
        }

        SettingAction {
            icon: "clear_all"
            label: "Clear all"
            detail: page.host && page.host.notificationSource
                ? (page.host.notificationSource.count === 0 ? "Nothing waiting" : page.host.notificationSource.count + " waiting") : ""
            onActivated: if (page.host && page.host.notificationSource) page.host.notificationSource.clearAll()
        }
    }

    SectionCard {
        title: "Weather"

        SettingText {
            label: "Location"
            sublabel: "Type your city, like Hue or Paris, France, or lat,lon. Empty: no weather"
            value: SettingsService.get("weather.location")
            placeholder: "city name"
            onSubmitted: text => SettingsService.set("weather.location", text)
            onCleared: SettingsService.set("weather.location", "")
        }

        SettingChoice {
            label: "Popup shows"
            sublabel: "The row under the details"
            current: SettingsService.get("weather.view")
            options: [
                { id: "days", label: "Next days", icon: "calendar_view_week" },
                { id: "hourly", label: "Hourly", icon: "schedule" }
            ]
            onPicked: id => SettingsService.set("weather.view", id)
        }

    }

    SectionCard {
        title: "Quick Panel"

        SettingToggle {
            icon: "swipe_up"
            label: "Hot edge"
            detail: SettingsService.flag("panel.hotEdge") ? "Bottom centre" : "OFF"
            checked: SettingsService.flag("panel.hotEdge")
            onToggled: SettingsService.toggle("panel.hotEdge")
        }

        SettingStepper {
            icon: "timer"
            label: "Edge delay"
            from: 40
            to: 800
            step: 20
            suffix: " ms"
            value: SettingsService.get("panel.hotDwell")
            onMoved: v => SettingsService.set("panel.hotDwell", v)
        }

        SettingSlider {
            width: page.halfWidth
            icon: "vertical_align_top"
            label: "How much of the phone shows"
            from: 40
            to: 100
            step: 2
            suffix: "%"
            value: SettingsService.get("panel.peek")
            onMoved: v => SettingsService.set("panel.peek", v)
        }

        SettingToggle {
            icon: "keyboard"
            label: "Type to search apps"
            detail: SettingsService.flag("panel.typeToSearch") ? "A letter opens Apps" : "OFF"
            checked: SettingsService.flag("panel.typeToSearch")
            onToggled: SettingsService.toggle("panel.typeToSearch")
        }

        // Behind the Quick and Apps screens alike (PanelImages.phoneWallpaperFor).
        SettingChoice {
            label: "Phone wallpaper"
            sublabel: "Behind the Quick and Apps screens, seen as an LCD. Desktop: the current wallpaper"
            current: PanelImages.phoneMode === "off" ? "off" : "desktop"
            options: [
                { id: "off", label: "Off", icon: "hide_image" },
                { id: "desktop", label: "Desktop", icon: "wallpaper" }
            ]
            onPicked: id => SettingsService.set("phone.wallpaper", id)
        }
    }

    SectionCard {
        title: "Launcher & lock"

        SettingToggle {
            icon: "search"
            label: "Web suggestions"
            detail: SettingsService.flag("launcher.webSuggestions") ? "Sent to DuckDuckGo" : "OFF"
            checked: SettingsService.flag("launcher.webSuggestions")
            onToggled: SettingsService.toggle("launcher.webSuggestions")
        }

        SettingToggle {
            icon: "content_paste"
            label: "Clipboard history"
            detail: SettingsService.flag("launcher.clipboard") ? "Recording" : "OFF"
            checked: SettingsService.flag("launcher.clipboard")
            onToggled: SettingsService.toggle("launcher.clipboard")
        }

        SettingChoice {
            label: "Lockscreen pictures"
            sublabel: "Auto looks at your wallpaper for the parts worth showing (needs ImageMagick); Fixed always shows the same spots"
            current: SettingsService.get("lock.crop")
            options: [
                { id: "auto", label: "Auto", icon: "auto_awesome" },
                { id: "fixed", label: "Fixed", icon: "crop" }
            ]
            onPicked: id => SettingsService.set("lock.crop", id)
        }

        SettingChoice {
            label: "Lockscreen colours"
            sublabel: "Colour keeps your wallpaper's colours and prints the palette's inks around it; Black & white is a monochrome poster"
            current: SettingsService.get("lock.tone")
            options: [
                { id: "color", label: "Colour", icon: "palette" },
                { id: "mono", label: "Black & white", icon: "contrast" }
            ]
            onPicked: id => SettingsService.set("lock.tone", id)
        }

        SettingToggle {
            icon: "power_settings_new"
            label: "Restart / Shut down keys"
            detail: SettingsService.flag("lock.powerButtons") ? "On the lockscreen" : "OFF (Ctrl + Enter still sleeps)"
            checked: SettingsService.flag("lock.powerButtons")
            onToggled: SettingsService.toggle("lock.powerButtons")
        }

        SettingToggle {
            icon: "bedtime"
            label: "Sleep the desktop while locked"
            detail: SettingsService.flag("lock.sleepDesktop") ? "Widgets are unloaded and the audio tap stops; unlocking brings them back" : "OFF (everything keeps running while locked)"
            checked: SettingsService.flag("lock.sleepDesktop")
            onToggled: SettingsService.toggle("lock.sleepDesktop")
        }

        SettingToggle {
            icon: "blur_on"
            label: "Blur lock wallpaper"
            checked: SettingsService.flag("lock.blur")
            onToggled: SettingsService.toggle("lock.blur")
        }

        SettingToggle {
            icon: "fingerprint"
            label: "Fingerprint unlock"
            detail: SettingsService.flag("lock.fingerprint") ? "Scans alongside the password field (needs fprintd and enrolled prints)" : "OFF"
            checked: SettingsService.flag("lock.fingerprint")
            onToggled: SettingsService.toggle("lock.fingerprint")
        }

        SettingAction {
            icon: "lock"
            label: "Lock now"
            detail: "Lock the screen"
            onActivated: {
                if (page.host)
                    page.host.closeRequested()
                LockState.lock()
            }
        }
    }

    SectionCard {
        title: "Shell"

        SettingAction {
            icon: "refresh"
            label: "Reload shell"
            detail: "Rebuild every window"
            onActivated: Quickshell.reload(true)
        }

        SettingAction {
            icon: "restart_alt"
            label: "Reset settings"
            detail: SettingsService.changedCount === 0 ? "Nothing changed"
                : SettingsService.changedCount + (SettingsService.changedCount === 1 ? " change" : " changes")
            onActivated: SettingsService.reset()
        }
    }

}
