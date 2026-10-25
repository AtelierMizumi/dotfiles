#!/bin/sh

# Helper for WidgetClones.qml: remembers where each desktop widget's copies on the OTHER
# monitors are (a widget can be on several monitors, each with its own spot), so a shell
# restart brings them back as you left them.
#
#   clones-state.sh save <json>   replace the remembered state with <json>
#   clones-state.sh load          print the remembered JSON (or nothing at all, if no widget
#                                 has ever been put on a second monitor)
#
# Lives in ~/.cache/mizu/state/clones.json: state, not data, same
# convention lyrics-state.sh / clock-state.sh use. Written to a temp file and moved into place,
# so a crash mid-save can't leave half a file.

mode="$1"
dir="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/state"
file="$dir/clones.json"

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
