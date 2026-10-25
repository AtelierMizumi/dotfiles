import QtQuick
import Quickshell.Widgets

// A box with its own corner radii that clips what is put in it to that shape. (An Item can
// only clip square: `clip` on a rounded Rectangle still lets a picture's corners out.)
// Quickshell's ClippingRectangle does the clipping itself, so these nest and sit inside
// layers freely; a masked layer (MultiEffect) does not: one inside another drew square.
//
//   RoundClip {
//       width: 192; height: 77
//       radii: [24, 24, 16, 16]          // top-left, top-right, bottom-left, bottom-right
//       FramedImage { anchors.fill: parent; source: ...; framing: ... }
//   }
ClippingRectangle {
    id: rc

    property var radii: [0, 0, 0, 0]

    color: "transparent"
    topLeftRadius: rc.radii[0]
    topRightRadius: rc.radii[1]
    bottomLeftRadius: rc.radii[2]
    bottomRightRadius: rc.radii[3]
}
