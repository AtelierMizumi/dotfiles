#!/bin/sh

# Helper for NotesService.qml: remembers the desktop Sticky Notes (text,
# colour, position, size, pinned), so a shell restart brings them back
# exactly as you left them.
#
#   notes-state.sh save <json>   replace the remembered state with <json>
#   notes-state.sh load          print the remembered JSON (or nothing at
#                                all, if the widget has never been used)
#
# Lives in ~/.cache/mizu/state/notes.json — state, not
# data, same convention clock-state.sh / todo-state.sh use. Written to a temp
# file and moved into place, so a crash mid-save can't leave half a file behind.

mode="$1"
dir="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/state"
file="$dir/notes.json"

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
