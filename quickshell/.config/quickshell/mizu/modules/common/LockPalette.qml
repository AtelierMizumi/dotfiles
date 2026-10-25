pragma Singleton
import QtQuick
import qs.modules.common

// The colours of the lockscreen, driven by Tokens.
QtObject {
    id: root

    // ===== accents =====
    readonly property color mint: Tokens.accentMint
    readonly property color mintDeep: Tokens.accentCyan
    readonly property color pink: Tokens.accent
    readonly property color paper: Tokens.paper

    // ===== slate parts =====
    readonly property color panel: Tokens.surface
    readonly property color panelEdge: Tokens.line
    readonly property color divider: Tokens.surfaceDivider
    readonly property color cap: Tokens.surfaceHover
    readonly property color well: Tokens.colBorder

    // ===== glow and text =====
    readonly property color periwinkle: Tokens.accentCyan
    readonly property color band: Tokens.surfaceHover
    readonly property color bandClear: "transparent"
    readonly property color lavenderText: Tokens.inkSub

    readonly property color shadow: Tokens.lineShadow

    // ===== behind everything =====
    readonly property color scrimBase: Tokens.scrim
    readonly property color scrimTop: Qt.rgba(0, 0, 0, 0.1)
    readonly property color scrimClear: "transparent"
    readonly property color scrimBottom: Qt.rgba(0, 0, 0, 0.6)

    readonly property color fallbackTop: Tokens.surface
    readonly property color fallbackBottom: Tokens.colBorder
    readonly property color sparkle: Tokens.accent

    // ===== the Calendar lockscreen =====
    readonly property color calPaper: Tokens.paper
    readonly property color calAccent: Tokens.accent
    readonly property color calMint: Tokens.accentMint
    readonly property color calLilac: Tokens.accentCyan
    readonly property color calMuted: Tokens.inkSub
}
