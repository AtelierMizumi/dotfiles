pragma Singleton
import QtQuick
import qs.services

// The shell's theme: one ThemeSet (ThemeSet.qml holds every color, size and font). Components read it as
//
//   readonly property var mt: Theme.of(QsWindow.window)    (an Item; needs `import Quickshell`)
//   readonly property var mt: Theme.of(screen)             (a PanelWindow's own file)
//   ... color: mt.surface
//
// Upstream could give each monitor a theme of its own; here every monitor wears the one wallpaper palette, so of()
// ignores its argument. It stays so the 270 call sites in the harvested files need no change.
ThemeSet {
    id: theme

    function of(w) {
        return theme
    }
}
