import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// About: what this shell is and who made the parts it is built from.
SettingsPage {
    id: page

    SectionCard {
        title: "This shell"

        // The mark: a ring with a drop in it, in the palette's accent colours.
        Item {
            width: 96
            height: 96

            Rectangle {
                x: mt.quickFlat ? 0 : 5
                y: 4
                width: 90
                height: 90
                radius: 45
                color: mt.pLineShadow
                antialiasing: true
            }

            Rectangle {
                width: 90
                height: 90
                radius: 45
                color: mt.pSurface
                border.width: 5
                border.color: mt.pLine
                antialiasing: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 11
                    radius: width / 2
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mt.accentMint }
                        GradientStop { position: 1.0; color: mt.accentCyan }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 38
                        name: "water_drop"
                        weight: mt.settingsIconWeight
                        fill: mt.iconFill
                        color: mt.colBorder
                    }
                }
            }
        }

        Column {
            width: page.fullWidth - 96 - 16
            height: 96
            spacing: 2

            Text {
                text: "mizu"
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 34
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A Quickshell shell for niri. Its colours come from the wallpaper."
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 17
            }

            Row {
                spacing: 10
                topPadding: 8

                SettingChip {
                    label: SettingsService.changedCount === 0 ? "Default settings"
                        : SettingsService.changedCount + (SettingsService.changedCount === 1 ? " setting changed" : " settings changed")
                    icon: "tune"
                }

                SettingChip {
                    label: "GPL-3.0"
                    icon: "balance"
                }
            }
        }
    }

    SectionCard {
        title: "Credits"

        Repeater {
            model: [
                { who: "Upstream shell · Blapples", what: "Built on upstream shell (GPL-3.0) by Blapples (see UPSTREAM.md)" },
                { who: "end4 · dots-hyprland", what: "The foundation of the upstream shell, and of how these pages are organised (GPL-3.0)" },
                { who: "Quickshell & niri", what: "The toolkit and the compositor this runs on" },
                { who: "noctalia", what: "The colour generator behind the wallpaper palette" },
                { who: "Material Symbols & Google Sans Flex", what: "Every icon and every letter" },
                { who: "emojibase", what: "The emoji data in the launcher (MIT)" },
                { who: "Open-Meteo & lyric providers", what: "Weather, and lyrics from LRCLIB, LyricsPlus, NetEase, QQ Music and Kugou" }
            ]

            delegate: Column {
                required property var modelData
                width: page.fullWidth
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: modelData.who
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: modelData.what
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 15
                }
            }
        }
    }
}
