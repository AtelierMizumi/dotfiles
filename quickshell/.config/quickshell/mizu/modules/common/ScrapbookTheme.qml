pragma Singleton
import QtQuick
import qs.modules.common

// Palette for the paper/tape styled surfaces in the shell, reading from Tokens.
QtObject {
    id: root

    // ===== paper =====
    readonly property color page: Tokens.paper
    readonly property color ink: Tokens.ink
    readonly property color inkSoft: Tokens.inkMuted

    // ===== accents =====
    readonly property color tapeTeal: (Tokens.series && Tokens.series.length > 0) ? Tokens.series[0] : Tokens.accent
    readonly property color tapeCoral: (Tokens.series && Tokens.series.length > 1) ? Tokens.series[1] : Tokens.accent
    readonly property color tapeMint: (Tokens.series && Tokens.series.length > 2) ? Tokens.series[2] : Tokens.accent2
    readonly property color tapePink: (Tokens.series && Tokens.series.length > 3) ? Tokens.series[3] : Tokens.accent
    readonly property color tag: (Tokens.series && Tokens.series.length > 4) ? Tokens.series[4] : Tokens.warning
    readonly property color accentCurrent: Tokens.accent
    readonly property color accentPink: Tokens.accent

    // ===== cork board =====
    readonly property color cork: Tokens.surface
    readonly property color corkLight: Tokens.surfaceHover
    readonly property color corkDark: Tokens.surfaceDivider
    readonly property color corkSpeck: Tokens.outline
    readonly property color frameWood: Tokens.outline
    readonly property color frameHighlight: Tokens.line
    readonly property color frameShade: Tokens.outline
    readonly property color noteShadow: Tokens.shadow
    readonly property color pinPink: Tokens.accent

    // ===== film strip =====
    readonly property color filmBase: Tokens.surface
    readonly property color filmEdge: Tokens.outline
    readonly property color filmFrame: Tokens.surfaceHover
    readonly property color filmScreen: Tokens.surface
    readonly property color filmScreenHover: Tokens.surfaceHover
    readonly property color filmHole: Tokens.paper
    readonly property color filmHoleShade: Tokens.surfaceDivider
    readonly property color filmPrint: Tokens.accent
    readonly property color filmPrintSoft: Tokens.inkMuted

    // ===== wallpaper board =====
    readonly property color boardBg: Tokens.surface
    readonly property color boardBgClear: "transparent"
    readonly property color boardDot: Tokens.surfaceDivider
    readonly property color labelPaper: Tokens.paper
}
