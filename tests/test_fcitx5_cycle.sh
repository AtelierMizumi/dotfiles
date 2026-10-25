#!/usr/bin/env bash
# Tests for niri/.config/niri/scripts/fcitx5-cycle: Mod+BackSpace moves to the NEXT input method of the current fcitx5
# group, in the order of ~/.config/fcitx5/profile, and wraps around. `fcitx5-remote -t` only toggled between the first
# item and the last used engine, so the third engine was never reached.
# A fake fcitx5-remote on PATH answers -n (current engine) and -q (current group) and logs every -s call.
# shellcheck disable=SC2317,SC2329
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/niri/.config/niri/scripts/fcitx5-cycle"

fail() {
  echo "    assertion failed: $*" >&2
  exit 1
}

# Sets up a temporary XDG_CONFIG_HOME and a fake fcitx5-remote, then runs the script once.
# Usage: run_cycle <current engine> <current group> [profile text]; leaves the -s log in $LOG and the exit code in $CODE.
run_cycle() {
  local current="$1" group="$2" profile="${3-}"
  TMP=$(mktemp -d)
  # Each test runs in its own subshell, so this cleans up after the test's assertions.
  trap 'rm -rf "$TMP"' EXIT
  mkdir -p "$TMP/bin" "$TMP/config/fcitx5"
  LOG="$TMP/switch.log"
  : >"$LOG"
  cat >"$TMP/bin/fcitx5-remote" <<EOF
#!/usr/bin/env bash
case "\$1" in
  -n) [[ -n "$current" ]] || exit 1; echo "$current" ;;
  -q) echo "$group" ;;
  -s) echo "\$2" >>"$LOG" ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$TMP/bin/fcitx5-remote"
  if [[ -n "$profile" ]]; then
    printf '%s\n' "$profile" >"$TMP/config/fcitx5/profile"
  fi
  PATH="$TMP/bin:$PATH" XDG_CONFIG_HOME="$TMP/config" bash "$SCRIPT" >/dev/null 2>&1
  CODE=$?
}

# The profile of this machine (fcitx5 writes it like this): one group, three items, comment lines included.
PROFILE_ONE_GROUP='[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=anthy

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
# Layout=

[Groups/0/Items/1]
# Name
Name=lotus
# Layout
# Layout=

[Groups/0/Items/2]
# Name
Name=anthy
# Layout
# Layout=

[GroupOrder]
0=Default'

PROFILE_TWO_GROUPS='[Groups/0]
Name=Default
Default Layout=us
DefaultIM=lotus

[Groups/0/Items/0]
Name=keyboard-us

[Groups/0/Items/1]
Name=lotus

[Groups/1]
Name=Work
Default Layout=us
DefaultIM=mozc

[Groups/1/Items/0]
Name=keyboard-us

[Groups/1/Items/1]
Name=mozc

[Groups/1/Items/2]
Name=pinyin

[GroupOrder]
0=Default
1=Work'

t_script_exists_and_is_executable() {
  [[ -x "$SCRIPT" ]] || fail "$SCRIPT is missing or not executable"
}

t_english_goes_to_vietnamese() {
  run_cycle keyboard-us Default "$PROFILE_ONE_GROUP"
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(cat "$LOG")" == "lotus" ]] || fail "switched to '$(cat "$LOG")', expected lotus"
}

t_vietnamese_goes_to_japanese() {
  run_cycle lotus Default "$PROFILE_ONE_GROUP"
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(cat "$LOG")" == "anthy" ]] || fail "switched to '$(cat "$LOG")', expected anthy"
}

t_last_engine_wraps_to_the_first() {
  run_cycle anthy Default "$PROFILE_ONE_GROUP"
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(cat "$LOG")" == "keyboard-us" ]] || fail "switched to '$(cat "$LOG")', expected keyboard-us"
}

t_engine_outside_the_group_goes_to_the_first() {
  run_cycle pinyin Default "$PROFILE_ONE_GROUP"
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(cat "$LOG")" == "keyboard-us" ]] || fail "switched to '$(cat "$LOG")', expected keyboard-us"
}

t_uses_the_items_of_the_current_group() {
  run_cycle mozc Work "$PROFILE_TWO_GROUPS"
  [[ $CODE -eq 0 ]] || fail "exit code $CODE"
  [[ "$(cat "$LOG")" == "pinyin" ]] || fail "switched to '$(cat "$LOG")', expected pinyin (group Work)"
}

t_missing_profile_fails_without_switching() {
  run_cycle keyboard-us Default ""
  [[ $CODE -ne 0 ]] || fail "exit code 0 without a profile"
  [[ ! -s "$LOG" ]] || fail "switched to '$(cat "$LOG")' without a profile"
}

t_fcitx5_not_running_fails_without_switching() {
  run_cycle "" Default "$PROFILE_ONE_GROUP"
  [[ $CODE -ne 0 ]] || fail "exit code 0 while fcitx5-remote -n fails"
  [[ ! -s "$LOG" ]] || fail "switched to '$(cat "$LOG")' while fcitx5 is not running"
}

passed=0
failed=0
skipped=0
for name in $(compgen -A function | grep '^t_' | sort); do
  if ("$name"); then
    echo "PASS ${name#t_}"
    passed=$((passed + 1))
  else
    echo "FAIL ${name#t_}"
    failed=$((failed + 1))
  fi
done
echo "RESULT passed=$passed failed=$failed skipped=$skipped"
[[ $failed -eq 0 ]]
