#!/bin/sh

# Helper for PanelImages.qml: lets you pick the Quick Panel's avatar and
# banner pictures, and the phone's own wallpaper, with a normal file chooser,
# and keeps them.
#
#   pick-image.sh pick  avatar|banner|phone
#                                       open a file chooser; the chosen
#                                       picture is copied into the data
#                                       folder and its path is printed
#   pick-image.sh load                  print "<kind> <path>" for each
#                                       picture already picked
#   pick-image.sh clear avatar|banner|phone
#                                       forget one (back to the default)
#   pick-image.sh drop <path>           delete one stored picture (only a
#                                       <kind>-* file in the data folder)
#
# MIZU_PICK_KEEP=1 makes `pick` keep the previous picture of the kind: the
# framer opens on a new pick, and Cancel there puts the old one back, so it is
# only dropped once the new one is kept (PanelImages.qml, docs/PICTURE-FRAMING.md).
#
# The pictures live in ${XDG_DATA_HOME:-~/.local/share}/sekaipop/ (copied,
# so moving or deleting the original doesn't break the panel). Each pick
# gets a fresh file name — avatar-<time>.<ext> — so the image is really
# reloaded instead of the old one coming out of a cache.
#
# The chooser is the first of kdialog, zenity or yad that's installed. kdialog
# comes first because it opens its own window at once; GTK4 zenity goes through
# the desktop portal, which can take seconds to wake up. Settings > General >
# Quick Panel > "Picture picker" sets MIZU_CHOOSER (kdialog, zenity
# or yad) to try one of them first; "Auto" leaves it unset. A chooser that is
# not installed is skipped, so a wrong choice never leaves you without one.
#
# A picture much bigger than the avatar / banner can show is scaled down while
# it is copied (shrink-image.sh), so the shell doesn't have to decode a huge
# photo several times over right after you pick it.

mode="$1"
kind="$2"
dir="${XDG_CACHE_HOME:-$HOME/.cache}/mizu/data"
here=$(cd "$(dirname "$0")" && pwd)

[ "$mode" = drop ] || case "$kind" in
    avatar|banner|phone|"") ;;
    *) echo "unknown kind: $kind" >&2; exit 2 ;;
esac

case "$mode" in
    load)
        for k in avatar banner phone; do
            f=$(ls -1t "$dir/$k"-* 2>/dev/null | head -n 1)
            [ -n "$f" ] || continue
            # An older copy left by a pick that was never settled (the shell stopped while
            # the framer was open): the newest is the one shown, the rest go.
            for old in "$dir/$k"-*; do
                [ "$old" != "$f" ] && rm -f -- "$old"
            done
            printf '%s %s\n' "$k" "$f"
        done
        exit 0
        ;;
    clear)
        [ -n "$kind" ] && rm -f -- "$dir/$kind"-*
        exit 0
        ;;
    drop)
        # $2 is a path here, not a kind: only ever one of our own copies.
        f="$2"
        case "$(basename -- "$f")" in
            avatar-*|banner-*|phone-*) ;;
            *) exit 1 ;;
        esac
        [ "$(dirname -- "$f")" = "$dir" ] && [ -f "$f" ] && rm -f -- "$f"
        exit 0
        ;;
    pick) ;;
    *) echo "usage: $0 pick|load|clear [avatar|banner|phone] | drop <path>" >&2; exit 2 ;;
esac

[ -n "$kind" ] || exit 2

case "$kind" in
    avatar) title="Choose your avatar" ;;
    banner) title="Choose your banner" ;;
    phone) title="Choose the phone's wallpaper" ;;
esac

# Start in the Pictures folder if there is one.
start=$(xdg-user-dir PICTURES 2>/dev/null)
[ -d "$start" ] || start="$HOME/Pictures"
[ -d "$start" ] || start="$HOME"

# "*.png *.PNG *.jpg ..." — the choosers match case-sensitively.
patterns=""
for e in png jpg jpeg webp gif bmp svg; do
    up=$(printf '%s' "$e" | tr 'a-z' 'A-Z')
    patterns="$patterns *.$e *.$up"
done
patterns="${patterns# }"

chooser=""
for c in ${MIZU_CHOOSER:-} kdialog zenity yad; do
    case "$c" in
        zenity|kdialog|yad) ;;
        *) continue ;;
    esac
    if command -v "$c" >/dev/null 2>&1; then
        chooser="$c"
        break
    fi
done

case "$chooser" in
    zenity)
        f=$(zenity --file-selection --title="$title" --filename="$start/" \
            --file-filter="Images | $patterns" 2>/dev/null)
        ;;
    kdialog)
        f=$(kdialog --title "$title" --getopenfilename "$start" "$patterns|Images" 2>/dev/null)
        ;;
    yad)
        f=$(yad --file --title="$title" --filename="$start/" \
            --file-filter="Images | $patterns" 2>/dev/null)
        ;;
    *)
        echo "no file chooser found: install zenity (or kdialog / yad)" >&2
        exit 127
        ;;
esac

# Cancelled, or nothing usable picked.
[ -n "$f" ] && [ -f "$f" ] || exit 1

ext="${f##*.}"
ext=$(printf '%s' "$ext" | tr 'A-Z' 'a-z')
mkdir -p "$dir" || exit 1
new="$dir/$kind-$(date +%s).$ext"
sh "$here/shrink-image.sh" "$kind" "$f" "$new" || exit 1

# Drop the previous picture of this kind (unless the caller drops it itself once
# the new one is kept: MIZU_PICK_KEEP).
if [ "${MIZU_PICK_KEEP:-}" != 1 ]; then
    for old in "$dir/$kind"-*; do
        [ "$old" != "$new" ] && rm -f -- "$old"
    done
fi

printf '%s\n' "$new"
