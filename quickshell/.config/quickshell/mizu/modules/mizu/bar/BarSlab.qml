import QtQuick
import QtQuick.Shapes

// The bar's body: a keycap-style slab (hard shadow, outline, pale ring, fill) whose FILL may be translucent.
// With a see-through fill the usual trick (a solid shadow rectangle under the face) would show through, so the
// shadow is only the crescent that peeks out below the face (the offset shape minus the face), and the outline
// and ring are drawn as borders rather than as solid layers under the fill.
//
// The face is this item minus `shadowDy` at the bottom; the shadow is the face moved down by `shadowDy`.
Item {
    id: root

    property real radius: 13
    property real shadowDy: 4
    property color shadowColor: "black"

    property real outlineWidth: 3
    property color outlineColor: "black"
    // The pale ring between the outline and the fill (0 = none).
    property real ringWidth: 0
    property color ringColor: "white"
    property color fillColor: "white"

    readonly property real faceHeight: Math.max(0, root.height - root.shadowDy)

    function roundedRect(x, y, w, h, r) {
        const k = Math.max(0, Math.min(r, w / 2, h / 2))
        return "M " + (x + k) + " " + y
            + " L " + (x + w - k) + " " + y
            + " A " + k + " " + k + " 0 0 1 " + (x + w) + " " + (y + k)
            + " L " + (x + w) + " " + (y + h - k)
            + " A " + k + " " + k + " 0 0 1 " + (x + w - k) + " " + (y + h)
            + " L " + (x + k) + " " + (y + h)
            + " A " + k + " " + k + " 0 0 1 " + x + " " + (y + h - k)
            + " L " + x + " " + (y + k)
            + " A " + k + " " + k + " 0 0 1 " + (x + k) + " " + y + " Z"
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.shadowColor
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: root.roundedRect(0, root.shadowDy, root.width, root.faceHeight, root.radius) }
            PathSvg { path: root.roundedRect(0, 0, root.width, root.faceHeight, root.radius) }
        }
    }

    // The fill goes under the outline and the ring (they are opaque), so no seam shows between them.
    Rectangle {
        id: face
        width: root.width
        height: root.faceHeight
        radius: root.radius
        color: root.fillColor
        antialiasing: true
    }

    // The ring, inside the outline.
    Rectangle {
        x: root.outlineWidth
        y: root.outlineWidth
        width: face.width - 2 * root.outlineWidth
        height: face.height - 2 * root.outlineWidth
        visible: root.ringWidth > 0
        radius: Math.max(0, root.radius - root.outlineWidth)
        color: "transparent"
        border.width: root.ringWidth
        border.color: root.ringColor
        antialiasing: true
    }

    // The outline.
    Rectangle {
        width: face.width
        height: face.height
        radius: root.radius
        color: "transparent"
        border.width: root.outlineWidth
        border.color: root.outlineColor
        antialiasing: true
    }
}
