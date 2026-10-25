pragma Singleton
import QtQuick
import qs.modules.common

// Palette for the paper/tape styled surfaces in the shell, reading from Tokens.
QtObject {
    id: root

    // ===== paper =====
    readonly property color page: Tokens.paper
    readonly property color ink: Tokens.ink
    readonly property color inkSoft: Tokens.inkSub

    // ===== accents =====
    readonly property color tapeTeal: (Tokens.attributeColors && Tokens.attributeColors.length > 0) ? Tokens.attributeColors[0] : Tokens.accentCyan
    readonly property color tapeCoral: (Tokens.attributeColors && Tokens.attributeColors.length > 1) ? Tokens.attributeColors[1] : Tokens.accent
    readonly property color tapeMint: (Tokens.attributeColors && Tokens.attributeColors.length > 2) ? Tokens.attributeColors[2] : Tokens.accentMint
    readonly property color tapePink: (Tokens.attributeColors && Tokens.attributeColors.length > 3) ? Tokens.attributeColors[3] : Tokens.accent
    readonly property color tag: (Tokens.attributeColors && Tokens.attributeColors.length > 4) ? Tokens.attributeColors[4] : Tokens.warning
    readonly property color accentCurrent: Tokens.accent
    readonly property color accentPink: Tokens.accent

    // ===== cork board =====
    readonly property color cork: Tokens.surface
    readonly property color corkLight: Tokens.surfaceHover
    readonly property color corkDark: Tokens.surfaceDivider
    readonly property color corkSpeck: Tokens.colBorder
    readonly property color frameWood: Tokens.colBorder
    readonly property color frameHighlight: Tokens.line
    readonly property color frameShade: Tokens.colBorder
    readonly property color noteShadow: Tokens.lineShadow
    readonly property color pinPink: Tokens.accent

    // ===== film strip =====
    readonly property color filmBase: Tokens.surface
    readonly property color filmEdge: Tokens.colBorder
    readonly property color filmFrame: Tokens.surfaceHover
    readonly property color filmScreen: Tokens.surface
    readonly property color filmScreenHover: Tokens.surfaceHover
    readonly property color filmHole: Tokens.paper
    readonly property color filmHoleShade: Tokens.surfaceDivider
    readonly property color filmPrint: Tokens.accent
    readonly property color filmPrintSoft: Tokens.inkSub

    // ===== wallpaper board =====
    readonly property color boardBg: Tokens.surface
    readonly property color boardBgClear: "transparent"
    readonly property color boardDot: Tokens.surfaceDivider
    readonly property color labelPaper: Tokens.paper
}
