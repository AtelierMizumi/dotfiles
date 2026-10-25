#!/bin/sh

# Used by QuickSource.qml's Log out action: end the session.

grace="${1:-1.5}"

if command -v niri >/dev/null 2>&1; then
    niri msg action quit --skip-confirmation >/dev/null 2>&1
fi
sleep 1
if [ -n "$XDG_SESSION_ID" ]; then
    loginctl terminate-session "$XDG_SESSION_ID" >/dev/null 2>&1
else
    loginctl terminate-user "$USER" >/dev/null 2>&1
fi
