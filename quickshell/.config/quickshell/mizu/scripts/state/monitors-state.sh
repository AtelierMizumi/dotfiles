#!/bin/sh

# Helper for DesktopMonitors.qml: remembers which monitor the desktop widgets use (the default one,
# and the one the To-Do and the Sticky Notes were given), BY NAME ("DP-1", "HDMI-A-1"), so the
# choice survives a restart even when the monitors are listed in another order at boot.
#
#   monitors-state.sh save <json>   replace the remembered state with <json>
#   monitors-state.sh load          print the remembered JSON (or nothing, if nothing was chosen)
#
# Lives in ~/.cache/mizu/state/monitors.json: state, not data, same
# convention the other *-state.sh helpers use. Written to a temp file and moved into place, so a
# crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/state"
file="$dir/monitors.json"

case "$mode" in
    save)
        mkdir -p "$dir" || exit 1
        printf '%s\n' "$2" > "$file.tmp" || exit 1
        mv "$file.tmp" "$file"
        ;;
    load)
        [ -f "$file" ] && cat "$file"
        exit 0
        ;;
    *)
        echo "usage: $0 save <json>|load" >&2
        exit 2
        ;;
esac
