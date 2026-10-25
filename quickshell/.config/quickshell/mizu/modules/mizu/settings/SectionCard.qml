import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mizu.phone

// A panel with the Quick Panel's outline and hard shadow, wearing a
// leaning name plate on its top edge, a few
// slanted stripes on the other end and a halftone in its corner. Each card
// in a page takes the next of the five card-attribute colours for its plate
// (cool, cute, happy, mysterious, pure), so a page reads as a row of
// different things instead of the same box repeated.
//
// Put controls inside; they wrap into rows (a Flow), so give each one the
// width it wants and a full-width one (`width: card.innerWidth`) for a row
// of its own.
//
//   SectionCard {
//       title: "Modules"
//       icon: "extension"           // optional; most titles already have one
//       SettingToggle { ... }
//   }
Item {
    id: root

    // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
    readonly property var mt: Theme.of(QsWindow.window)

    property string title: ""
    property string icon: ""
    property real inset: 26
    width: parent ? parent.width : 600
    property real gap: 16
    default property alias content: flow.data

    // The width a full-width control inside the card may take.
    readonly property real innerWidth: card.width - inset * 2

    readonly property bool isSectionCard: true
    // Which card of its page this is (counted among its siblings), so the
    // plates take the attribute colours in turn.
    property int slot: 0

    Component.onCompleted: {
        if (!parent)
            return
        let n = 0
        for (let i = 0; i < parent.children.length; i++) {
            const c = parent.children[i]
            if (c === root)
                break
            if (c.isSectionCard === true)
                n++
        }
        slot = n
    }

    readonly property color accent: mt.attributeColors[slot % mt.attributeColors.length]

    readonly property var iconFor: ({
        "look": "palette", "shell": "widgets", "bar": "toast", "desktop widgets": "dashboard",
        "time & alerts": "schedule", "quick panel": "instant_mix", "launcher & lock": "lock",
        "modules": "extension", "size": "aspect_ratio", "wallpaper": "wallpaper", "widgets": "dashboard",
        "this shell": "info", "credits": "favorite", "colour mode": "contrast", "scheme": "auto_awesome",
        "accent": "colorize", "palette": "palette", "outputs": "monitor", "workspaces": "grid_view",
        "config file": "description"
    })
    readonly property string shownIcon: icon !== "" ? icon : (iconFor[title.toLowerCase()] || "star")

    implicitHeight: 30 + flow.implicitHeight + 30 + 4

    // hard shadow
    Rectangle {
        x: mt.quickFlat ? 0 : 5
        y: 4
        width: card.width
        height: card.height
        radius: 30
        color: mt.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card
        width: root.width - 5
        height: root.height - 4
        radius: 30
        color: mt.pSurface
        border.width: 3
        border.color: mt.pLine
        antialiasing: true

        DotField {
            x: card.width - width - 16
            y: card.height - height - 16
            width: 300
            height: 110
            corner: "br"
            spacing: 16
            maxRadius: 3
            dotColor: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.07)
        }

        Flow {
            id: flow
            x: root.inset
            y: 30
            width: card.width - root.inset * 2
            spacing: root.gap
        }
    }

    // The name plate, leaning, lying across the card's top edge.
    LeanKey {
        id: plate

        x: 34
        y: -22
        capW: 18 + 36 + 10 + tagText.implicitWidth + 38
        capH: 44
        skew: 0.3 * mt.settingsLean
        radius: 15
        shadowBaseX: 3
        shadowBaseY: 3
        flatShadow: mt.quickFlat
        idleColor: root.accent

        Rectangle {
            x: 40
            y: (plate.capH - height) / 2
            width: 28
            height: 28
            radius: 8
            rotation: 45
            color: mt.colBg
            border.width: 2.5
            border.color: mt.pLine
            antialiasing: true
        }

        MaterialIcon {
            x: 40 + 14 - 11
            y: (plate.capH - height) / 2
            size: 22
            name: root.shownIcon
            weight: mt.settingsIconWeight
            color: mt.colBorder
        }

        Text {
            id: tagText
            x: 40 + 28 + 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: mt.colBorder
            font.family: mt.fontFamily
            font.pixelSize: 21
            font.weight: Font.ExtraBold
            font.styleName: mt.fontStyleBold
        }
    }

    // Three stripes at the other end of the edge.
    Repeater {
        model: 3

        delegate: Slant {
            required property int index

            x: card.width - 108 + index * 22
            y: -13
            width: 30
            height: 27
            skew: 0.55
            radius: 3
            color: mt.attributeColors[(root.slot + 1 + index) % mt.attributeColors.length]
        }
    }
}
