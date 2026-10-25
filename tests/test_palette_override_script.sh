#!/usr/bin/env bash
# Tests for scripts/state/palette-override.sh of the mizu shell: the per-wallpaper palette overrides
# (~/.cache/mizu/state/palette-overrides.json) that Settings > Appearance writes and the palette tool reads.
#   palette-override.sh set <wallpaper> <scheme|mode|accent> <value>
#   palette-override.sh clear <wallpaper>
#   palette-override.sh get <wallpaper>
# Every test runs in a throwaway HOME / XDG_CACHE_HOME; nothing outside it is touched.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MIZU="$ROOT/quickshell/.config/quickshell/mizu"
SCRIPT="$MIZU/scripts/state/palette-override.sh"
PALETTE="$MIZU/palette"
SCHEMES="auto faithful soft vibrant m3-content m3-tonal-spot m3-monochrome"
WP="/tmp/mizu-test/wall.png"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
CACHE="$TMP/cache"
STORE="$CACHE/mizu/state/palette-overrides.json"
OUT="$TMP/out"
ERR="$TMP/err"
CODE=0

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Run the script in the sandbox; sets CODE and fills $OUT / $ERR.
run() {
  CODE=0
  HOME="$TMP/home" XDG_CACHE_HOME="$CACHE" sh "$SCRIPT" "$@" >"$OUT" 2>"$ERR" || CODE=$?
}

fresh() {
  rm -rf "${CACHE:?}" "${TMP:?}/home"
  mkdir -p "$TMP/home"
}

# The stored JSON re-printed with sorted keys, to compare whole files.
stored() {
  python3 -I -B -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True))' "$STORE"
}

expect_code() {
  [[ "$CODE" -eq "$1" ]] || fail "exit code $CODE, expected $1 (stderr: $(cat "$ERR"))"
}

expect_refused() {
  expect_code 2
  [[ -s "$ERR" ]] || fail "no message on stderr"
  [[ ! -e "$STORE" ]] || fail "a refused call still wrote $STORE"
}

t_set_writes_the_entry_for_the_wallpaper() {
  fresh
  run set "$WP" scheme soft
  expect_code 0
  [[ "$(stored)" == '{"/tmp/mizu-test/wall.png": {"scheme": "soft"}}' ]] || fail "unexpected file: $(stored)"
}

t_set_merges_keys_and_keeps_other_entries() {
  fresh
  run set "$WP" scheme vibrant && expect_code 0
  run set /other/pic.jpg accent '#112233' && expect_code 0
  run set "$WP" mode dark && expect_code 0
  run set "*" mode light && expect_code 0
  [[ "$(stored)" == '{"*": {"mode": "light"}, "/other/pic.jpg": {"accent": "#112233"}, "/tmp/mizu-test/wall.png": {"mode": "dark", "scheme": "vibrant"}}' ]] ||
    fail "unexpected file: $(stored)"
}

t_get_prints_the_entry() {
  fresh
  run set "$WP" scheme m3-content && expect_code 0
  run set "$WP" accent '#a1b2c3' && expect_code 0
  run get "$WP"
  expect_code 0
  [[ "$(python3 -I -B -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))' <"$OUT")" == '{"accent": "#a1b2c3", "scheme": "m3-content"}' ]] ||
    fail "get printed: $(cat "$OUT")"
}

t_get_without_a_file_or_entry_prints_an_empty_object() {
  fresh
  run get "$WP"
  expect_code 0
  [[ "$(tr -d ' \n' <"$OUT")" == '{}' ]] || fail "no file: got $(cat "$OUT")"
  [[ ! -e "$STORE" ]] || fail "get created the file"
  run set /other/pic.jpg scheme soft && expect_code 0
  run get "$WP"
  expect_code 0
  [[ "$(tr -d ' \n' <"$OUT")" == '{}' ]] || fail "no entry: got $(cat "$OUT")"
}

t_clear_removes_only_that_wallpaper() {
  fresh
  run set "$WP" scheme soft && expect_code 0
  run set /other/pic.jpg scheme vibrant && expect_code 0
  run set "*" mode dark && expect_code 0
  run clear "$WP"
  expect_code 0
  [[ "$(stored)" == '{"*": {"mode": "dark"}, "/other/pic.jpg": {"scheme": "vibrant"}}' ]] || fail "unexpected file: $(stored)"
}

t_clear_with_nothing_stored_is_a_no_op() {
  fresh
  run clear "$WP"
  expect_code 0
  [[ ! -e "$STORE" ]] || fail "clear created the file"
}

t_auto_removes_scheme_and_accent_and_drops_an_empty_entry() {
  fresh
  run set "$WP" scheme soft && expect_code 0
  run set "$WP" accent '#445566' && expect_code 0
  run set "$WP" scheme auto && expect_code 0
  [[ "$(stored)" == '{"/tmp/mizu-test/wall.png": {"accent": "#445566"}}' ]] || fail "scheme auto kept something: $(stored)"
  run set "$WP" accent auto && expect_code 0
  [[ "$(stored)" == '{}' ]] || fail "empty entry stayed: $(stored)"
  grep -q '"auto"' "$STORE" && fail "the word auto was stored"
  return 0
}

t_mode_auto_is_a_real_value() {
  fresh
  run set "$WP" mode auto
  expect_code 0
  [[ "$(stored)" == '{"/tmp/mizu-test/wall.png": {"mode": "auto"}}' ]] || fail "unexpected file: $(stored)"
}

t_every_scheme_is_accepted() {
  local scheme
  for scheme in $SCHEMES; do
    fresh
    run set "$WP" scheme "$scheme"
    expect_code 0
  done
}

t_unknown_key_is_refused() {
  fresh
  run set "$WP" wallpaper /etc/passwd
  expect_refused
  run set "$WP" "" soft
  expect_refused
}

t_bad_values_are_refused() {
  fresh
  local pair key value
  for pair in "scheme:neon" "scheme:" "scheme:Soft" "scheme:soft;rm" "mode:night" "mode:" "accent:red" "accent:#12345" \
    "accent:#1234567" "accent:#12345g" "accent:112233" "accent:#11223 3"; do
    key=${pair%%:*}
    value=${pair#*:}
    run set "$WP" "$key" "$value"
    expect_refused
  done
}

t_a_refused_call_leaves_the_file_alone() {
  fresh
  run set "$WP" scheme soft && expect_code 0
  local before
  before=$(cat "$STORE")
  run set "$WP" scheme neon
  expect_code 2
  [[ "$(cat "$STORE")" == "$before" ]] || fail "file changed after a refused call"
}

t_bad_usage_is_refused() {
  fresh
  run
  expect_refused
  run frobnicate "$WP"
  expect_refused
  run set "$WP" scheme
  expect_refused
  run set "$WP"
  expect_refused
  run clear
  expect_refused
  run get
  expect_refused
  run set relative/pic.png scheme soft
  expect_refused
  run set "" scheme soft
  expect_refused
}

t_odd_paths_round_trip() {
  fresh
  local odd="/tmp/my pics/it's \"q\" ñ 画像.png"
  run set "$odd" scheme faithful && expect_code 0
  run set "$odd" accent '#AbCdEf' && expect_code 0
  run get "$odd"
  expect_code 0
  [[ "$(python3 -I -B -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))' <"$OUT")" == '{"accent": "#abcdef", "scheme": "faithful"}' ]] ||
    fail "round trip failed: $(cat "$OUT")"
  run clear "$odd"
  expect_code 0
  [[ "$(stored)" == '{}' ]] || fail "clear missed the odd path: $(stored)"
}

t_a_corrupt_file_is_not_overwritten() {
  fresh
  mkdir -p "$(dirname "$STORE")"
  printf '{"/a": {"scheme": "soft"' >"$STORE"
  run set "$WP" scheme vibrant
  expect_code 1
  [[ -s "$ERR" ]] || fail "no message on stderr"
  [[ "$(cat "$STORE")" == '{"/a": {"scheme": "soft"' ]] || fail "the corrupt file was replaced"
  run clear "$WP"
  expect_code 1
  printf '[1,2]' >"$STORE"
  run set "$WP" scheme vibrant
  expect_code 1
  [[ "$(cat "$STORE")" == '[1,2]' ]] || fail "a non-object file was replaced"
}

t_writes_atomically_under_the_cache_state_directory() {
  fresh
  run set "$WP" scheme soft
  expect_code 0
  [[ -d "$CACHE/mizu/state" ]] || fail "the state directory was not created"
  local files
  files=$(find "$CACHE" "$TMP/home" -type f | sort)
  [[ "$files" == "$STORE" ]] || fail "unexpected files (a temp file left behind?): $files"
}

t_falls_back_to_home_dot_cache() {
  fresh
  CODE=0
  env -u XDG_CACHE_HOME HOME="$TMP/home" sh "$SCRIPT" set "$WP" scheme soft >"$OUT" 2>"$ERR" || CODE=$?
  expect_code 0
  [[ -f "$TMP/home/.cache/mizu/state/palette-overrides.json" ]] || fail "not written under \$HOME/.cache"
}

t_the_palette_tool_reads_what_the_script_writes() {
  fresh
  run set "$WP" scheme m3-content && expect_code 0
  run set "$WP" accent '#336699' && expect_code 0
  run set "*" mode light && expect_code 0
  local got
  got=$(cd "$PALETTE" && python3 -I -B -c '
import json, sys
sys.path.insert(0, ".")
import mizu_palette
from pathlib import Path
print(json.dumps(mizu_palette._load_overrides(Path(sys.argv[1]), sys.argv[2]), sort_keys=True))
' "$STORE" "$WP") || fail "the palette tool could not load the file"
  [[ "$got" == '{"accent": "#336699", "mode": "light", "scheme": "m3-content"}' ]] || fail "the tool read: $got"
}

t_the_color_generator_accepts_every_scheme_name() {
  command -v noctalia >/dev/null 2>&1 || {
    echo "    noctalia not installed" >&2
    return 77
  }
  local scheme
  for scheme in $SCHEMES; do
    [[ "$scheme" == auto ]] && continue
    noctalia theme "$MIZU/assets/images/default-wallpaper.png" --scheme "$scheme" --dark >/dev/null 2>&1 ||
      fail "noctalia theme rejects the scheme $scheme"
  done
}

passed=0
failed=0
skipped=0
for name in $(compgen -A function | grep '^t_' | sort); do
  ("$name")
  code=$?
  if [[ $code -eq 0 ]]; then
    echo "PASS ${name#t_}"
    passed=$((passed + 1))
  elif [[ $code -eq 77 ]]; then
    echo "SKIP ${name#t_}"
    skipped=$((skipped + 1))
  else
    echo "FAIL ${name#t_}"
    failed=$((failed + 1))
  fi
done
echo "RESULT passed=$passed failed=$failed skipped=$skipped"
[[ $failed -eq 0 ]]
