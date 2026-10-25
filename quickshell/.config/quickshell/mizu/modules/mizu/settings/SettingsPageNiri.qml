import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Niri: what the compositor tells the shell, read only. The outputs and their
// scale, the workspaces on each of them, which output has the focus, and the
// file niri reads its own settings from (with a button that opens it).
SettingsPage {
    id: page

    readonly property string configPath: Quickshell.env("HOME") + "/.config/niri/config.kdl"
    readonly property string focused: Compositor.focusedOutput

    // niri's workspaces on one output, top to bottom.
    function workspacesOn(output) {
        return Compositor.workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx)
    }

    // One line of facts: a small grey name over its value.
    component Fact: Column {
        id: fact

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property string name: ""
        property string value: ""

        spacing: 1

        Text {
            text: fact.name
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            width: fact.width
            elide: Text.ElideMiddle
            text: fact.value
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 19
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    SectionCard {
        title: "Outputs"

        Fact {
            name: "Compositor"
            value: Compositor.running ? "niri, connected" : "not running under niri"
            width: page.halfWidth
        }

        Fact {
            name: "Focused output"
            value: page.focused !== "" ? page.focused : "unknown"
            width: page.halfWidth
        }

        Repeater {
            model: Quickshell.screens

            delegate: Rectangle {
                id: tile

                required property var modelData
                readonly property bool isFocused: tile.modelData.name === page.focused

                width: page.tileWidth + 40
                height: 96
                radius: 22
                color: tile.isFocused ? mt.pSurfaceHover : mt.pSurface
                border.width: 3
                border.color: tile.isFocused ? mt.colBorder : mt.pLine
                antialiasing: true

                MaterialIcon {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    size: 34
                    name: "monitor"
                    weight: mt.settingsIconWeight
                    color: mt.pInk
                }

                Column {
                    x: 70
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70 - 14
                    spacing: 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: tile.modelData.name + (tile.isFocused ? "  ·  focused" : "")
                        color: mt.pInk
                        font.family: mt.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Math.round(tile.modelData.width * tile.modelData.devicePixelRatio) + " × "
                            + Math.round(tile.modelData.height * tile.modelData.devicePixelRatio)
                            + " px  ·  scale " + Number(tile.modelData.devicePixelRatio.toFixed(2))
                        color: mt.pInkSub
                        font.family: mt.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    SectionCard {
        title: "Workspaces"

        Text {
            width: page.fullWidth
            wrapMode: Text.WordWrap
            text: "Lit: the workspace shown on its output. A dot: it has windows. Each output numbers its own from the top."
            color: mt.pInkSub
            font.family: mt.fontFamily
            font.pixelSize: 15
        }

        Text {
            visible: Compositor.workspaces.length === 0
            width: page.fullWidth
            text: "niri has not reported any workspaces."
            color: mt.pInk
            font.family: mt.fontFamily
            font.pixelSize: 17
        }

        Repeater {
            model: Quickshell.screens

            delegate: Row {
                id: line

                required property var modelData
                readonly property var list: page.workspacesOn(line.modelData.name)

                visible: line.list.length > 0
                spacing: 16

                Text {
                    width: 150
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: line.modelData.name
                    color: mt.pInk
                    font.family: mt.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                Repeater {
                    model: line.list

                    delegate: Rectangle {
                        id: badge

                        required property var modelData
                        readonly property bool occupied: badge.modelData.active_window_id !== null
                            && badge.modelData.active_window_id !== undefined

                        width: 52
                        height: 44
                        radius: 15
                        color: badge.modelData.is_active ? mt.accentCyan : mt.pSurface
                        border.width: 3
                        border.color: badge.modelData.is_focused ? mt.colBorder : mt.pLine
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: badge.modelData.name ? badge.modelData.name : String(badge.modelData.idx)
                            elide: Text.ElideRight
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            color: badge.modelData.is_active ? mt.colBorder : mt.pInk
                            font.family: mt.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.ExtraBold
                            font.styleName: mt.fontStyleBold
                        }

                        Rectangle {
                            visible: badge.occupied
                            x: parent.width - 14
                            y: 5
                            width: 8
                            height: 8
                            radius: 4
                            color: badge.modelData.is_active ? mt.colBorder : mt.accentMint
                            antialiasing: true
                        }
                    }
                }
            }
        }
    }

    SectionCard {
        title: "Config file"

        Fact {
            name: "niri reads its settings from"
            value: page.configPath.startsWith(Quickshell.env("HOME")) ? "~" + page.configPath.slice(Quickshell.env("HOME").length)
                                                                      : page.configPath
            width: page.fullWidth
        }

        SettingAction {
            icon: "description"
            label: "Open config.kdl"
            detail: "With the app xdg-open picks"
            onActivated: Quickshell.execDetached(["xdg-open", page.configPath])
        }
    }
}
