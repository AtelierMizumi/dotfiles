import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// The password prompt card, in the same sticker style as everything else:
// navy outline, white ring, hard offset shadow, mint/cyan primary button.
//
//   [ (lock)  Authentication Required        ]
//   [         Authentication is required to  ]
//   [         install software               ]
//   [ ( Password ...........................) ]
//   [ (!) Sorry, that didn't work.            ]   <- only after a wrong try
//   [                 ( Cancel ) ( Unlock )   ]
//
// Pure UI: PolkitPrompt.qml feeds it the
// text and turns its two signals into PolkitService calls. It never
// touches PolkitService itself.
//
//   Enter submits, Escape cancels. The field re-focuses (and clears)
//   whenever it becomes typeable again, so after a wrong password you
//   can just start typing.
Pill {
    id: root

    property string message: ""
    property string prompt: "Password"
    property bool passwordMode: true
    property bool interactionAvailable: true
    property bool failed: false

    signal submitted(string text)
    signal cancelled()

    readonly property real pad: 22

    width: 440
    // The card is as tall as its content needs: column + padding + the
    // ring on both sides + the shadow strip Pill reserves.
    height: col.implicitHeight + pad * 2 + ringWidth * 2 + shadowDy

    cornerRadius: 26
    ringWidth: 6
    fillColor: mt.surface
    borderWidth: mt.borderWidth
    shadowDx: 6
    shadowDy: 6

    // Pop-in: fades up and settles with a little overshoot, the same
    // "keycap" spring the pills use.
    property bool shown: false
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: 140 } }
    Behavior on scale {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }

    // Escape cancels from anywhere inside the card: TextInput ignores the
    // key, so it bubbles up the parent chain to here.
    focus: true
    Keys.onEscapePressed: root.cancelled()

    function trySubmit() {
        if (root.interactionAvailable)
            root.submitted(input.text)
    }

    onInteractionAvailableChanged: {
        if (interactionAvailable) {
            input.text = ""
            input.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        shown = true
        input.forceActiveFocus()
    }

    // A square-ish button on a Pill, with the same press behavior as the
    // workspace and media pills (Pill.pressed <- MouseArea.pressed).
    component DialogButton: Item {
        id: btn

        // This monitor's theme: Theme.of() gives the shell's own unless the monitor has one.
        readonly property var mt: Theme.of(QsWindow.window)

        property string text: ""
        property bool primary: false
        signal clicked()

        implicitWidth: 128
        implicitHeight: 44
        opacity: enabled ? 1 : 0.45

        Gradient {
            id: primaryGradient
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: mt.accentMint }
            GradientStop { position: 1.0; color: mt.accentCyan }
        }

        Pill {
            anchors.fill: parent
            ringWidth: 4
            shadowDx: 3
            shadowDy: 3
            pressed: area.pressed && btn.enabled
            fillColor: mt.surface
            fillGradient: btn.primary ? primaryGradient : null

            Text {
                anchors.centerIn: parent
                text: btn.text
                color: btn.primary ? mt.colBorder : mt.ink
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    Column {
        id: col
        x: root.pad
        y: root.pad
        width: parent.width - root.pad * 2
        spacing: 16

        // ===== header =====
        Row {
            spacing: 14

            Rectangle {
                id: badge
                width: 48
                height: 48
                radius: 24
                color: mt.accentMint
                border.width: mt.borderWidth
                border.color: mt.line
                antialiasing: true

                MaterialIcon {
                    color: mt.colBorder
                    anchors.centerIn: parent
                    size: 26
                    name: "lock"
                }
            }

            Column {
                anchors.verticalCenter: badge.verticalCenter
                width: col.width - badge.width - 14
                spacing: 3

                Text {
                    width: parent.width
                    text: "Authentication Required"
                    elide: Text.ElideRight
                    color: mt.ink
                    font.family: mt.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }

                Text {
                    width: parent.width
                    visible: root.message !== ""
                    text: root.message
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: mt.inkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 13
                }
            }
        }

        // ===== password field =====
        Rectangle {
            id: field
            width: parent.width
            height: 46
            radius: 23
            color: mt.surface
            // A wrong password tints the outline pink instead of navy —
            // pink is the "Cute" attribute colour from Theme.
            border.width: mt.borderWidth
            border.color: root.failed ? mt.attributeColors[1] : mt.line
            antialiasing: true
            opacity: root.interactionAvailable ? 1 : 0.6

            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Hint text, shown only while the field is empty.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 20
                width: parent.width - 40
                elide: Text.ElideRight
                visible: input.text === ""
                text: root.prompt
                color: mt.inkSub
                font.family: mt.fontFamily
                font.pixelSize: 15
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                x: 20
                width: parent.width - 40
                clip: true
                enabled: root.interactionAvailable
                echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
                passwordCharacter: "●"
                color: mt.ink
                selectionColor: mt.accentCyan
                selectedTextColor: mt.colBorder
                font.family: mt.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                cursorDelegate: Rectangle {
                    width: 2
                    color: mt.line
                }

                onAccepted: root.trySubmit()
            }
        }

        // ===== wrong-password note =====
        Rectangle {
            visible: root.failed
            width: parent.width
            height: visible ? 34 : 0
            radius: 17
            color: mt.attributeColors[1]
            antialiasing: true

            Row {
                anchors.centerIn: parent
                spacing: 8

                MaterialIcon {
                    color: mt.colBorder
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    name: "error"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sorry, that didn't work. Try again."
                    color: mt.colBorder
                    font.family: mt.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }
            }
        }

        // ===== buttons =====
        Item {
            width: parent.width
            height: 47   // button (44) + its 3px shadow

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 3   // room for the hard shadow
                spacing: 14

                DialogButton {
                    text: "Cancel"
                    onClicked: root.cancelled()
                }

                DialogButton {
                    text: "Unlock"
                    primary: true
                    enabled: root.interactionAvailable
                    onClicked: root.trySubmit()
                }
            }
        }
    }

}
