pragma Singleton
import QtQuick
import qs.modules.common

// The colours of the lockscreen, driven by Tokens.
QtObject {
    id: root

    // ===== accents =====
    readonly property color mint: Tokens.accent2
    readonly property color mintDeep: Tokens.accent
    readonly property color pink: Tokens.accent
    readonly property color paper: Tokens.paper

    // ===== slate parts =====
    readonly property color panel: Tokens.surface
    readonly property color panelEdge: Tokens.line
    readonly property color divider: Tokens.surfaceDivider
    readonly property color cap: Tokens.surfaceHover
    readonly property color well: Tokens.outline

    // ===== glow and text =====
    readonly property color periwinkle: Tokens.accent
    readonly property color band: Tokens.surfaceHover
    readonly property color bandClear: "transparent"
    readonly property color lavenderText: Tokens.inkMuted

    readonly property color shadow: Tokens.shadow

    // ===== behind everything =====
    readonly property color scrimBase: Tokens.scrim
    readonly property color scrimTop: Qt.rgba(0, 0, 0, 0.1)
    readonly property color scrimClear: "transparent"
    readonly property color scrimBottom: Qt.rgba(0, 0, 0, 0.6)

    readonly property color fallbackTop: Tokens.surface
    readonly property color fallbackBottom: Tokens.outline
    readonly property color sparkle: Tokens.accent

    // ===== the Calendar lockscreen =====
    readonly property color calPaper: Tokens.paper
    readonly property color calAccent: Tokens.accent
    readonly property color calMint: Tokens.accent2
    readonly property color calLilac: Tokens.accent
    readonly property color calMuted: Tokens.inkMuted
}
