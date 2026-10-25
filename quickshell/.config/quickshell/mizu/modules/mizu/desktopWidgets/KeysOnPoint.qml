import QtQuick

// When a desktop widget's window may ask for the keyboard: only while the pointer is
// on it (so the click that starts typing finds it OnDemand), or while it already has
// the keyboard (typing goes on after the pointer has left). The rest of the time its
// keyboard interactivity is None.
//
// Why: Hyprland hands the keyboard to an OnDemand layer as it is mapped. Desktop Focus
// Mode maps the widgets again, one after another, whenever an empty workspace comes up,
// so every widget that was always OnDemand took the keyboard as it popped in, and a
// launcher opened right after (Rofi) could not be typed into for about a second
// (issue #72). A window that maps as None and only turns OnDemand under the pointer
// never takes it uninvited.
//
// Put one last in the window (on top, so nothing above takes the pointer from it; a
// HoverHandler is passive, so clicks still go through) and use `wanted`:
//
//   WlrLayershell.keyboardFocus: keys.wanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
//   KeysOnPoint { id: keys }
Item {
    id: root

    readonly property bool wanted: hover.hovered || root.Window.active

    anchors.fill: parent

    HoverHandler {
        id: hover
    }
}
