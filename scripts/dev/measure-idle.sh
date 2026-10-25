#!/usr/bin/env bash
# Idle cost of the shell: starts it in the nested niri (scripts/dev/nested-shell.sh), lets it settle, and prints the
# process's resident memory, CPU over a window, thread and child counts, and its busiest threads. Stops the session.
#
#   measure-idle.sh <shell dir> [settle seconds (25)] [measure seconds (15)]
#   measure-idle.sh quickshell/.config/quickshell/mizu
#
# Reading it: CPU of the "quickshell" thread is the QML main thread (timers, bindings); QSGRender* are the render
# threads (animations that never stop show up there). Exit codes: 0 measured, 2 failed, 64 usage.
set -euo pipefail

usage() {
  echo "usage: measure-idle.sh <shell dir> [settle seconds] [measure seconds]" >&2
  exit 64
}

[[ $# -ge 1 && $# -le 3 ]] || usage
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
harness="$here/nested-shell.sh"
settle="${2:-25}"
window="${3:-15}"
[[ "$settle" =~ ^[0-9]+$ && "$window" =~ ^[0-9]+$ ]] || usage

shell_dir=$(realpath -- "$1" 2>/dev/null) && [[ -f "$shell_dir/shell.qml" ]] || {
  echo "measure-idle.sh: no shell.qml in $1" >&2
  exit 2
}

trap '"$harness" stop >/dev/null 2>&1 || true' EXIT
"$harness" stop >/dev/null 2>&1 || true
"$harness" start "$shell_dir" >/dev/null || {
  echo "measure-idle.sh: the nested session did not start" >&2
  exit 2
}
sleep "$settle"

qs_bin=$(command -v quickshell)
pid=$(pgrep -n -f "^$qs_bin -p $shell_dir\$") || {
  echo "measure-idle.sh: the shell is not running (see: nested-shell.sh log)" >&2
  exit 2
}

ticks() { awk '{print $14 + $15}' "/proc/$pid/stat"; }
tck=$(getconf CLK_TCK)
before=$(ticks)
top -H -b -n 2 -d "$window" -p "$pid" | awk '/^top/{n++} n==2' | sed -n 7,13p >"${TMPDIR:-/tmp}/measure-idle.$$.threads"
after=$(ticks)

cpu=$(awk -v a="$before" -v b="$after" -v t="$tck" -v s="$window" 'BEGIN { printf "%.2f", (b - a) / t / s * 100 }')
rss=$(awk '/VmRSS/ { printf "%d", $2 / 1024 }' "/proc/$pid/status")
echo "rss=${rss}MB cpu=${cpu}% threads=$(awk '/Threads/ {print $2}' "/proc/$pid/status") children=$(pgrep -P "$pid" | wc -l)"
echo "busiest threads:"
cat "${TMPDIR:-/tmp}/measure-idle.$$.threads"
rm -f "${TMPDIR:-/tmp}/measure-idle.$$.threads"
