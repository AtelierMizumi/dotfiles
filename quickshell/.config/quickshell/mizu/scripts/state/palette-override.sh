#!/bin/sh

# Helper for Settings > Appearance: the per-wallpaper palette overrides that the
# palette tool (palette/mizu_palette.py) reads when it makes the tokens.
#
#   palette-override.sh set <wallpaper> <scheme|mode|accent> <value>
#   palette-override.sh clear <wallpaper>    forget every override of that wallpaper
#   palette-override.sh get <wallpaper>      print its entry as JSON ({} if none)
#
# <wallpaper> is an absolute path, or * for "every wallpaper". Values:
#   scheme  auto | faithful | soft | vibrant | m3-content | m3-tonal-spot | m3-monochrome
#   mode    auto | dark | light
#   accent  #rrggbb
# "auto" for a scheme, and "auto" for an accent, mean "let the tool choose": the key
# is removed instead of stored (the tool would pass the word on to the color generator,
# which rejects it). Anything else is refused with exit status 2 and a message.
# Exit status 1: the file could not be read or written (a file that is not a JSON
# object is never overwritten).
#
# Lives in ${XDG_CACHE_HOME:-~/.cache}/mizu/state/palette-overrides.json:
#   {"*": {...}, "<absolute wallpaper path>": {"scheme": "...", "mode": "...", "accent": "#rrggbb"}}
# Written to a temp file next to it and moved into place, so a crash cannot leave half a file.

usage() {
    echo "usage: $0 set <wallpaper> <scheme|mode|accent> <value> | clear <wallpaper> | get <wallpaper>" >&2
    exit 2
}

refuse() {
    echo "palette-override.sh: $1" >&2
    exit 2
}

dir="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/state"
file="$dir/palette-overrides.json"

# The JSON work. argv: operation, file, wallpaper, key, value. Prints the new file
# (set, clear) or the entry (get). Exit 3: the file is not a JSON object.
edit='
import json, os, sys

op, path, wallpaper, key, value = sys.argv[1:6]
if wallpaper != "*":
    wallpaper = os.path.normpath(wallpaper)
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("not a JSON object")
except FileNotFoundError:
    data = {}
except (OSError, ValueError) as exc:
    print("palette-override.sh: %s is unreadable: %s" % (path, exc), file=sys.stderr)
    sys.exit(3)

entry = data.get(wallpaper)
if not isinstance(entry, dict):
    entry = {}
if op == "get":
    print(json.dumps(entry, sort_keys=True))
    sys.exit(0)
if op == "clear":
    data.pop(wallpaper, None)
else:
    if value == "auto" and key != "mode":
        entry.pop(key, None)
    else:
        entry[key] = value
    if entry:
        data[wallpaper] = entry
    else:
        data.pop(wallpaper, None)
print(json.dumps(data, sort_keys=True, indent=2))
'

run_edit() {
    python3 -I -B -c "$edit" "$1" "$file" "$2" "$3" "$4"
}

op="$1"
case "$op" in
    set) [ $# -eq 4 ] || usage ;;
    clear | get) [ $# -eq 2 ] || usage ;;
    *) usage ;;
esac

wallpaper="$2"
case "$wallpaper" in
    '*' | /?*) ;;
    *) refuse "the wallpaper must be an absolute path (or *), not '$wallpaper'" ;;
esac

key=""
value=""
if [ "$op" = set ]; then
    key="$3"
    value="$4"
    case "$key" in
        scheme)
            case "$value" in
                auto | faithful | soft | vibrant | m3-content | m3-tonal-spot | m3-monochrome) ;;
                *) refuse "unknown scheme '$value'" ;;
            esac
            ;;
        mode)
            case "$value" in
                auto | dark | light) ;;
                *) refuse "mode must be auto, dark or light, not '$value'" ;;
            esac
            ;;
        accent)
            case "$value" in
                auto) ;;
                '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) value=$(printf '%s' "$value" | tr 'A-F' 'a-f') ;;
                *) refuse "accent must be #rrggbb or auto, not '$value'" ;;
            esac
            ;;
        *) refuse "only scheme, mode and accent can be overridden, not '$key'" ;;
    esac
fi

if [ "$op" = get ]; then
    run_edit get "$wallpaper" "" ""
    status=$?
    # A file the tool cannot read is ignored by the tool too: report it, answer "nothing".
    if [ "$status" -eq 3 ]; then
        echo '{}'
        exit 0
    fi
    exit "$status"
fi

new=$(run_edit "$op" "$wallpaper" "$key" "$value") || {
    status=$?
    [ "$status" -eq 3 ] && exit 1
    exit "$status"
}

# Nothing stored and nothing to store: do not create the file.
if [ ! -f "$file" ] && [ "$new" = '{}' ]; then
    exit 0
fi

mkdir -p "$dir" || exit 1
tmp=$(mktemp "$dir/.palette-overrides.XXXXXX") || exit 1
if printf '%s\n' "$new" >"$tmp" && mv -f "$tmp" "$file"; then
    exit 0
fi
rm -f "$tmp"
exit 1
