import QtQuick
import "../functions/ImageMath.js" as IM

// A picture drawn into its own rectangle by a framing ({ zoom 1..6, panX / panY -1..1 },
// Framing.js): scaled to cover, zoomed, panned, the overflow clipped, exactly the Custom
// Image widget's CROP mode (ImageMath.drawRect). A centred framing is PreserveAspectCrop,
// so this stands in for an Image with that fill mode wherever a framed picture is shown:
// the Quick Panel's banner and avatar, the user card's, the phone's wallpaper. Masks and
// outlines stay the caller's.
//
//   FramedImage {
//       anchors.fill: parent
//       source: PanelImages.banner
//       framing: PanelImages.framingFor("banner")
//       decodeScale: 2          // texture pixels per design pixel
//   }
//
// It needs the picture's shape before it can place it: a tiny probe (64 px wide) is read
// first, then the picture itself at the size it ends up drawn (`decodeScale` of the
// drawn rectangle, capped at `maxDecode`), so a 6x zoom is sharp and a centred banner
// costs what it always did. `status` is Image.Ready once both are in.
Item {
    id: root

    property url source: ""
    property var framing: null
    // Texture pixels per design pixel of the drawn picture (2 = sharp on a 2x monitor).
    property real decodeScale: 2
    // Never decode bigger than this along either side.
    property int maxDecode: 4096
    // A fixed decode size instead of following the zoom (the framer: no re-decode on
    // every wheel notch). 0 = follow the drawn size.
    property real fixedDecodeWidth: 0
    property bool smoothing: true
    // Cut what overflows this item. Off inside a layer that is masked anyway (a layer only
    // covers its item, so the overflow is gone there too): a clipped child inside a masked
    // layer drew square over the mask.
    property bool clipped: true

    readonly property int status: root.aspect > 0 ? img.status : (probe.status === Image.Error ? Image.Error : (root.source.toString() === "" ? Image.Null : Image.Loading))
    readonly property bool ready: root.status === Image.Ready
    // width / height of the picture itself (0 until known).
    readonly property real aspect: probe.status === Image.Ready && probe.implicitHeight > 0
        ? probe.implicitWidth / probe.implicitHeight : 0
    // Where the picture is drawn, relative to this item (its overflow is clipped).
    readonly property var drawn: {
        if (!(root.aspect > 0) || !(root.width > 0) || !(root.height > 0))
            return { x: 0, y: 0, w: root.width, h: root.height }
        const f = root.framing || {}
        return IM.drawRect(root.width, root.height, root.aspect * 1000, 1000, "crop",
                           f.zoom === undefined ? 1 : f.zoom, f.panX || 0, f.panY || 0)
    }
    // The decoded picture, for a Canvas that measures it (the banner's ink sampler).
    readonly property alias image: img

    clip: root.clipped

    Image {
        id: probe
        source: root.source
        sourceSize.width: 64
        asynchronous: true
        visible: false
    }

    Image {
        id: img
        x: root.drawn.x
        y: root.drawn.y
        width: root.drawn.w
        height: root.drawn.h
        visible: root.aspect > 0
        source: root.aspect > 0 ? root.source : ""
        fillMode: Image.Stretch
        asynchronous: true
        smooth: root.smoothing
        mipmap: root.smoothing
        // A new size keeps showing the old decode until the new one is in, so a zoom
        // change never flashes empty.
        retainWhileLoading: true
        sourceSize: {
            const w = root.fixedDecodeWidth > 0 ? root.fixedDecodeWidth : root.drawn.w * root.decodeScale
            const cw = Math.max(1, Math.min(root.maxDecode, Math.ceil(w)))
            const ch = Math.max(1, Math.min(root.maxDecode, Math.ceil(cw / Math.max(0.01, root.aspect))))
            return Qt.size(Math.round(ch * root.aspect), ch)
        }
    }
}
