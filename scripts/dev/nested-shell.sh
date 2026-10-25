#!/usr/bin/env bash
# Dev harness: run a Quickshell config inside a nested niri (a window of the current session), isolated from it.
#
#   nested-shell.sh start <shell dir>   start nested niri, which starts `qs -p <shell dir>`
#   nested-shell.sh shot <name>         screenshot the nested screen to <state>/shots/<name>.png and print the path
#   nested-shell.sh ipc <qs ipc args>   e.g. `ipc call quickpanel show`
#   nested-shell.sh run <command...>    start a program inside the nested session
#   nested-shell.sh log [lines]         tail the shell's log (default 40)
#   nested-shell.sh status | stop
#
# The shell sees a private HOME, private XDG directories and a private session D-Bus, so scripts of a config under test
# (theme sync, gsettings, ...) cannot reach the real files. quickshell comes from the staging directory made by
# scripts/dev/stage-quickshell.sh (RICE_STAGE, default ~/.cache/rice-staging), not from the system.
# State lives in MIZU_DEV_STATE (default ~/.cache/mizu-dev). Exit codes: 0 ok, 1 status "stopped", 2 failed, 64 usage.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}
STATE=${MIZU_DEV_STATE:-$CACHE/mizu-dev}
STAGE=${RICE_STAGE:-$CACHE/rice-staging}

usage() {
  echo "usage: nested-shell.sh start <shell dir> | shot <name> | ipc <args...> | run <cmd...> | log [lines] | status | stop" >&2
  exit 64
}

die() {
  echo "nested-shell.sh: $*" >&2
  exit 2
}

nested_socket() {
  sed -n 1p "$STATE/env" 2>/dev/null
}

is_running() {
  local pid
  pid=$(cat "$STATE/niri.pid" 2>/dev/null) || return 1
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# The nested socket, after checking that a nested session is running and is not the one this shell lives in.
require_session() {
  local socket
  is_running || die "the nested session is not running (start one with: nested-shell.sh start <shell dir>)"
  socket=$(nested_socket)
  [[ -n "$socket" ]] || die "the nested session has not published its socket yet"
  [[ "$socket" != "${NIRI_SOCKET:-}" ]] || die "refusing to drive the outer session: the socket in $STATE/env is this session's own"
  printf '%s\n' "$socket"
}

# Private HOME and D-Bus, then the staged quickshell. Called by the nested niri, not by people.
run_qs() {
  local sandbox="$STATE/sandbox-home" font
  mkdir -p "$sandbox/.config" "$sandbox/.local/state" "$sandbox/.local/share/fonts" "$sandbox/.cache"
  for font in "$STAGE"/root/usr/share/fonts/*/*aterial*ymbols*Rounded*; do
    [[ -f "$font" ]] && cp -n "$font" "$sandbox/.local/share/fonts/"
  done
  [[ -x "$STAGE/root/usr/bin/quickshell" ]] || die "no staged quickshell in $STAGE (run scripts/dev/stage-quickshell.sh)"
  export HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/.config" XDG_STATE_HOME="$sandbox/.local/state" \
    XDG_DATA_HOME="$sandbox/.local/share" XDG_CACHE_HOME="$sandbox/.cache"
  export LD_LIBRARY_PATH="$STAGE/root/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export QML_IMPORT_PATH="$STAGE/root/usr/lib/qt6/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
  export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
  exec dbus-run-session -- "$STAGE/root/usr/bin/quickshell" "$@"
}

start() {
  local shell_dir
  [[ $# -eq 1 ]] || usage
  shell_dir=$(realpath -- "$1" 2>/dev/null) && [[ -d "$shell_dir" ]] || die "no such shell directory: $1"
  [[ -f "$shell_dir/shell.qml" ]] || die "no shell.qml in $shell_dir"
  is_running && die "a nested session is already running (stop it first)"
  mkdir -p "$STATE/shots"
  rm -f "$STATE/env" "$STATE/qs.log" "$STATE/niri.log"
  printf '%s\n' "$shell_dir" >"$STATE/shell_dir"
  NESTED_STATE="$STATE" NESTED_HERE="$HERE" NESTED_SHELL_DIR="$shell_dir" RICE_STAGE="$STAGE" MIZU_DEV_STATE="$STATE" \
    env -u NIRI_SOCKET setsid niri -c "$HERE/nested-niri.kdl" >"$STATE/niri.log" 2>&1 &
  echo $! >"$STATE/niri.pid"
  local _
  for _ in $(seq 60); do
    [[ -s "$STATE/env" ]] && break
    is_running || die "the nested niri exited: $(tail -3 "$STATE/niri.log" | tr '\n' ' ')"
    sleep 0.25
  done
  [[ -s "$STATE/env" ]] || die "the nested niri did not publish its socket"
  echo "nested niri up (socket $(nested_socket)); log: $STATE/qs.log"
}

stop() {
  local socket pid
  if is_running; then
    socket=$(nested_socket)
    if [[ -n "$socket" && "$socket" != "${NIRI_SOCKET:-}" ]]; then
      NIRI_SOCKET="$socket" niri msg action quit --skip-confirmation >/dev/null 2>&1
      sleep 1
    fi
    pid=$(cat "$STATE/niri.pid")
    kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
  fi
  rm -f "$STATE/niri.pid" "$STATE/env"
  return 0
}

case "${1:-}" in
  start) shift; start "$@" ;;
  stop) stop ;;
  status)
    if is_running; then echo "running (socket $(nested_socket))"; else echo "stopped"; exit 1; fi
    ;;
  shot)
    [[ $# -eq 2 ]] || usage
    socket=$(require_session) || exit 2
    mkdir -p "$STATE/shots"
    NIRI_SOCKET="$socket" niri msg action screenshot-screen --write-to-disk true --path "$STATE/shots/$2.png" >/dev/null ||
      die "the screenshot failed"
    sleep 0.7
    echo "$STATE/shots/$2.png"
    ;;
  ipc)
    shift
    [[ $# -ge 1 ]] || usage
    require_session >/dev/null || exit 2
    shell_dir=$(cat "$STATE/shell_dir")
    # After a hot reload Quickshell 0.3.2 no longer lists the instance under its shell path, so `-p <dir> ipc` finds
    # "no running instances"; the process id still works.
    shell_pid=$(pgrep -n -f "^$STAGE/root/usr/bin/quickshell -p $shell_dir\$") || die "the shell is not running (see: nested-shell.sh log)"
    MIZU_DEV_STATE="$STATE" run_qs ipc --pid "$shell_pid" "$@"
    ;;
  run)
    shift
    [[ $# -ge 1 ]] || usage
    socket=$(require_session) || exit 2
    NIRI_SOCKET="$socket" niri msg action spawn -- "$@"
    ;;
  log)
    require_session >/dev/null || exit 2
    tail -n "${2:-40}" "$STATE/qs.log"
    ;;
  _qs)
    shift
    run_qs "$@"
    ;;
  *) usage ;;
esac
