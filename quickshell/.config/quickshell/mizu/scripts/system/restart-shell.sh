#!/bin/sh

# Restart the shell as a new process: stop every running copy of this config,
# wait for it to go, start one again, detached.
#
#   restart-shell.sh [config folder]   (default: the folder above scripts/)
#
# Why not Quickshell.reload(): a reload builds the shell again inside the same
# process, and some of Qt's state lives in the process rather than in the reload.
# After an update that state can be stale, so every reload fails the same way
# ("FaceKey is not a type" in issue #79, "UndoTile is not a type" before it) and
# only a new process clears it. Updates (Settings, install.sh) and the reload
# popup's Restart button come here for that reason.
#
# Run it detached (Quickshell.execDetached, setsid): it kills the shell that
# started it.

dir=${1:-$(cd "$(dirname "$0")/../.." && pwd)}
[ -f "$dir/shell.qml" ] || { echo "no shell.qml in $dir" >&2; exit 1; }
command -v qs >/dev/null 2>&1 || { echo "qs isn't installed" >&2; exit 1; }

running() { ! qs list -p "$dir" 2>/dev/null | grep -q "No running instances"; }

qs kill -p "$dir" >/dev/null 2>&1
# Up to 5 s for the old one to let go of its windows and its ipc socket.
i=0
while running && [ "$i" -lt 50 ]; do
    sleep 0.1
    i=$((i + 1))
done
running && { echo "the old shell didn't stop" >&2; exit 1; }

exec qs -p "$dir" -n -d >/dev/null 2>&1
