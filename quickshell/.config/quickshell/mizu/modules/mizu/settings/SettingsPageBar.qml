import QtQuick
import qs.services
import qs.modules.common

// Bar: whether it is there, where it sits and how it looks, which modules it
// carries (every pill and button can be switched off), and how big it is.
SettingsPage {
    id: page

    readonly property var modules: [
        { key: "bar.workspaces", icon: "grid_view", label: "Workspaces" },
        { key: "bar.activeWindow", icon: "web_asset", label: "Active window" },
        { key: "bar.media", icon: "music_note", label: "Media" },
        { key: "bar.weather", icon: "partly_cloudy_day", label: "Weather" },
        { key: "bar.date", icon: "calendar_month", label: "Date" },
        { key: "bar.clock", icon: "schedule", label: "Clock" },
        { key: "bar.resources", icon: "memory", label: "CPU & RAM" },
        { key: "bar.status", icon: "wifi", label: "Wi-Fi, Bluetooth & sound icons" },
        { key: "bar.battery", icon: "battery_android_full", label: "Battery" },
        { key: "bar.keyboardLayout", icon: "keyboard_alt", label: "Keyboard layout" },
        { key: "bar.notifications", icon: "notifications", label: "Notification bell" },
        { key: "bar.tray", icon: "apps", label: "Tray" },
        { key: "bar.privacy", icon: "shield_with_heart", label: "Privacy (mic / screen share)" }
    ]

    SectionCard {
        title: "Bar"

        SettingToggle {
            icon: "visibility"
            label: "Show bar"
            detail: SettingsService.flag("bar.visible") ? "ON" : "Hidden · gear in Quick Panel"
            checked: SettingsService.flag("bar.visible")
            onToggled: SettingsService.toggle("bar.visible")
        }

        SettingChoice {
            label: "Style"
            sublabel: "How the bar is drawn"
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
            sublabel: "Which edge it sits on"
            current: BarPositionService.position
            options: [
                { id: "top", label: "Top", edge: "top" },
                { id: "right", label: "Right", edge: "right" },
                { id: "bottom", label: "Bottom", edge: "bottom" },
                { id: "left", label: "Left", edge: "left" }
            ]
            onPicked: id => BarPositionService.setPosition(id)
        }

        SettingToggle {
            icon: "vertical_align_top"
            label: "Auto-hide"
            detail: SettingsService.get("bar.hideMode") === "auto"
                ? "Away until the pointer touches the edge · windows use the whole screen"
                : "Always shown"
            checked: SettingsService.get("bar.hideMode") === "auto"
            onToggled: SettingsService.set("bar.hideMode", checked ? "off" : "auto")
        }

    }

    SectionCard {
        title: "Modules"

        Repeater {
            model: page.modules

            delegate: SettingToggle {
                required property var modelData

                icon: modelData.icon
                label: modelData.label
                checked: SettingsService.flag(modelData.key)
                onToggled: SettingsService.toggle(modelData.key)
            }
        }

        SettingSlider {
            visible: SettingsService.flag("bar.workspaces")
            width: page.halfWidth
            icon: "grid_view"
            label: "Workspaces on the bar"
            from: 1
            to: 10
            step: 1
            value: SettingsService.get("bar.workspaceCount")
            onMoved: v => SettingsService.set("bar.workspaceCount", Math.round(v))
        }
    }

    SectionCard {
        title: "Media, tray & scrolling"

        SettingChoice {
            label: "Media pill click"
            sublabel: "Left click on the pill"
            current: SettingsService.get("media.leftClick")
            options: [
                { id: "panel", label: "Open panel", icon: "queue_music" },
                { id: "playpause", label: "Play / pause", icon: "play_pause" }
            ]
            onPicked: id => SettingsService.set("media.leftClick", id)
        }

        SettingToggle {
            icon: "swap_vert"
            label: "Scroll on tray icons"
            detail: "Sent to the app"
            checked: SettingsService.flag("tray.scroll")
            onToggled: SettingsService.toggle("tray.scroll")
        }

        SettingToggle {
            icon: "unfold_more"
            label: "Scroll hints"
            detail: "A marker where the wheel works"
            checked: SettingsService.flag("bar.scrollHints")
            onToggled: SettingsService.toggle("bar.scrollHints")
        }
    }

    SectionCard {
        title: "Size"

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

        SettingAction {
            icon: "restart_alt"
            label: "Reset size"
            detail: "Back to the default"
            onActivated: { if (page.host) ShellScale.resetScale(page.host.screenName) }
        }
    }
}
