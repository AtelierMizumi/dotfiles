import QtQuick
import qs.services

// One whole theme: every color, size and font the shell draws with.
//
// Colors are tokens (Tokens.qml, from the wallpaper palette tool); nothing here derives a color from a fixed palette
// any more. The property names are the ones SekaiPop's components were written against (accentCyan, accentMint,
// pInk, colBorder...), so those components read them unchanged. Where upstream had a "classic" and a "darker"
// variant, the plain role is used for all of them (see classic / p* below). Sizes and fonts are design constants:
// they do not depend on the wallpaper.
QtObject {
    id: theme

    // ===== Mode =====
    readonly property string mode: Tokens.mode
    readonly property bool dark: Tokens.dark
    readonly property bool darker: false
    readonly property bool mono: false

    // ===== Roles (all from Tokens) =====
    readonly property color colBorder: Tokens.outline        // strong outline, shadows, dark text on accent fills
    readonly property color colBg: Tokens.surface
    readonly property color accentCyan: Tokens.accent        // first stop of every lit gradient
    readonly property color accentMint: Tokens.accent2       // second stop
    readonly property color textWhite: Tokens.onAccent       // text and icons on accent fills and over pictures

    readonly property color surface: Tokens.surface
    readonly property color surfaceHover: Tokens.surfaceHover
    readonly property color surfaceDivider: Tokens.surfaceDivider
    readonly property color surfaceRing: Tokens.surfaceRing  // the bar's and dock's housing ring
    readonly property color ringWhite: Tokens.ring           // the gap ring inside a Pill (upstream: white or cream)
    readonly property real cardRing: borderWidth             // flat cards get the inner ring in every mode now
    readonly property color surfaceTint: Tokens.hoverTint
    readonly property color ink: Tokens.ink
    readonly property color inkSub: Tokens.inkMuted
    readonly property color paper: Tokens.paper
    readonly property color paperHover: dark ? Qt.lighter(paper, 1.18) : Qt.darker(paper, 1.04)
    readonly property color paperEdge: dark ? Qt.lighter(paper, 1.4) : Qt.darker(paper, 1.1)
    readonly property color line: Tokens.line                // the OUTER border of every Pill, dialog and card
    readonly property color lineShadow: Tokens.shadow        // the hard drop shadow under them
    readonly property color chipFill: Tokens.chip
    readonly property color chipInk: Tokens.onChip
    readonly property color scrim: Tokens.scrim
    readonly property color danger: Tokens.danger
    readonly property color warning: Tokens.warning

    // Upstream's "classic panel" look is gone: its p* roles are the plain ones.
    readonly property bool classic: false
    readonly property color pSurface: surface
    readonly property color pSurfaceHover: surfaceHover
    readonly property color pSurfaceDivider: surfaceDivider
    readonly property color pSurfaceRing: surfaceRing
    readonly property color pRingWhite: ringWhite
    readonly property color pLine: line
    readonly property color pLineShadow: lineShadow
    readonly property color pInk: ink
    readonly property color pInkSub: inkSub
    function classicFor(item) {
        return false
    }

    readonly property color colDeep: Tokens.scrim
    readonly property color colHoverTint: Tokens.hoverTint
    readonly property color colOuterRing: Tokens.surfaceRing
    readonly property color colHover: Tokens.surfaceHover
    readonly property color colDivider: Tokens.surfaceDivider
    readonly property color colSubText: Tokens.inkMuted

    // The phone mock-up's plastics (PhoneBody.qml).
    readonly property color phoneRimHighlight: Tokens.phoneRimHighlight
    readonly property color phoneBezel: Tokens.phoneBezel
    readonly property color phoneWallLight: Tokens.phoneWallLight
    readonly property color phoneWallMid: Tokens.phoneWallMid
    readonly property color phoneWallDark: Tokens.phoneWallDark
    readonly property color phoneHardware: Tokens.phoneHardware
    readonly property color phoneLens: Tokens.phoneLens
    readonly property color phoneLensGlint: Tokens.phoneLensGlint
    readonly property real phoneShadowAlpha: Tokens.phoneShadowAlpha

    // How the palette tool fitted each surface to the wallpaper behind it.
    readonly property color barHousing: Tokens.barHousing
    readonly property real barAlpha: Tokens.barAlpha
    readonly property color phoneHousing: Tokens.phoneHousing
    readonly property real phoneAlpha: Tokens.phoneAlpha
    readonly property color widgetHousing: Tokens.widgetHousing
    readonly property real widgetAlpha: Tokens.widgetAlpha

    // Five friendly rotating colors (workspace dots, lock dots, battery tiers...): upstream's "attribute" pastels.
    readonly property var attributeColors: Tokens.series

    // ===== Scrolling =====
    // Pixels one mouse-wheel notch scrolls any list in the shell (WheelScroll.qml).
    readonly property real wheelStep: 110

    // How far one wheel event should move a list, in px: a mouse notch is `wheelStep`, a touchpad follows the
    // fingers 1:1. `sideways` is for horizontal rows: it takes whichever of the two axes moved more.
    function wheelPx(event, sideways) {
        const pd = event.pixelDelta
        const ad = event.angleDelta
        if (sideways) {
            if (pd.x !== 0 || pd.y !== 0)
                return Math.abs(pd.x) > Math.abs(pd.y) ? pd.x : pd.y
            return (Math.abs(ad.x) > Math.abs(ad.y) ? ad.x : ad.y) / 120 * wheelStep
        }
        return pd.y !== 0 ? pd.y : ad.y / 120 * wheelStep
    }

    // ===== Sizes =====
    readonly property int pillHeight: 36
    readonly property int radiusOuter: 13
    readonly property int radiusBadge: 15
    readonly property int borderWidth: 3
    // A block's ringWidth is borderWidth + whiteLine (the ring between a block's outline and its fill).
    readonly property real whiteLine: 2
    readonly property int shadowOffset: 4
    readonly property int outerRingWidth: 4

    // The phone's geometry: one place for the rim and bezel thickness, so PhoneBody and every dimming scrim that has
    // to cover exactly the visible glass stay in step.
    readonly property real phoneRimWidth: 10
    readonly property real phoneBezelWidth: 9
    readonly property real phoneScreenInset: phoneRimWidth + phoneBezelWidth
    readonly property real phoneCornerRadius: 100

    // The Quick Panel phone in its flat (2D) look: a setting, and always while Game Mode is on.
    readonly property bool quickFlat: SettingsService.flag("quick.flat") || GameModeService.enabled

    // A standing bar (left or right edge): how wide the bar body and its pills are.
    readonly property int barVBody: 72
    readonly property int barVPillWidth: 52
    // Float bar style: how far the bar is inset from the left and right screen edges.
    readonly property int barFloatInset: 16

    // ===== Capsule bar style (BarStyleService "capsule") =====
    // The slim bar and its pills (design px): 36 tall = 3 rim + 30 body + 3 rim, a hard shadow 3 px below, fully
    // rounded; the strip reserved for it is 8 + 39 + 8. Workspace dots: 12 fill + 3 ring = 18 across, the active one
    // 28 + 6 = 34 wide. Every other pill is a flat chip, 21 tall.
    readonly property real capBarHeight: 39
    readonly property real capBarFace: 36
    readonly property real capRimWidth: 3
    readonly property real capShadowDy: 3
    readonly property real capEdgeGap: 8
    readonly property real capStrip: 55
    readonly property real capPadX: 7
    readonly property real capGap: 6
    readonly property real capDotFill: 12
    readonly property real capDotRing: 3
    readonly property real capDot: capDotFill + 2 * capDotRing
    readonly property real capDotActive: 28 + 2 * capDotRing
    readonly property real capChipHeight: 21
    readonly property real capClockSize: 14

    // The same bar standing on the left / right edge.
    readonly property real capVChip: 40
    readonly property real capVPadX: 5
    readonly property real capVPadY: 8
    readonly property real capVBarFace: capVChip + 2 * (capRimWidth + capVPadX)
    readonly property real capStripV: capEdgeGap * 2 + capVBarFace

    readonly property color capBody: surface
    readonly property color capRim: dark ? Qt.lighter(surface, 1.87) : line
    readonly property color capShade: dark ? Qt.lighter(surface, 1.42) : lineShadow
    readonly property color capChip: capRim
    readonly property color capInk: ink
    readonly property color capLit: accentCyan
    readonly property color capLitSoft: accentMint
    readonly property var capWsColors: Tokens.series.map(c => Qt.color(c))

    // Is `item` inside a bar drawn in the Capsule style (on any edge)? Status_Bar.qml sets `capsuleBar` while that
    // style is up; Pill, MaterialIcon and the workspace badges ask this and redraw themselves as flat chips.
    function capsuleFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.capsuleBar === true)
                return true
        return false
    }

    // ...and is that bar standing on the left / right edge? (Status_Bar.qml sets `capsuleVertical` too.)
    function capsuleVerticalFor(item) {
        for (let p = item; p; p = p.parent)
            if (p.capsuleBar === true)
                return p.capsuleVertical === true
        return false
    }

    // ===== Fonts =====
    readonly property string fontFamily: "Noto Sans"
    readonly property int fontSize: 16
    // Icons come from the Material Symbols Rounded font (package ttf-material-symbols-variable); iconFill 0 =
    // outline, 1 = solid, iconWeight is the font's wght axis.
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property real iconFill: 0
    readonly property string iconStyle: "outline"
    readonly property real iconWeight: 400
    // The Settings panel's icons are heavier, so their outlines hold up against the panel's thick borders.
    readonly property real settingsIconWeight: 600
    // The style every bold text asks for, next to `font.weight: Font.ExtraBold`.
    readonly property string fontStyleBold: "ExtraBold"

    // Two-line pills (Media, Active Window): bold first line, lighter second line.
    readonly property int fontSizeTitle: 10
    readonly property int fontSizeSub: 7
    readonly property int fontSizeIdle: 12
    // Single-line info pills (Weather, Clock).
    readonly property int fontSizeInfo: 12

    // How much the Settings' keys, tiles and chips lean on top of the phone's own tilt (0 = upright).
    readonly property real settingsLean: 0
    readonly property int fontSizeMenu: 14
    readonly property int menuRowHeight: 32
}
