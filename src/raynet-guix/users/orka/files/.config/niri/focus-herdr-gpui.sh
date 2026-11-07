#!/bin/sh
set -eu

find_herdr_window() {
    niri msg --json windows | jq -r '
        [.[] | select((.app_id + " " + .title) | test("herdr"; "i"))][0].id // empty'
}

window_id=$(find_herdr_window)
if [ -z "$window_id" ]; then
    herdr-gpui >/dev/null 2>&1 &
    i=0
    while [ "$i" -lt 100 ]; do
        sleep 0.1
        window_id=$(find_herdr_window)
        [ -n "$window_id" ] && break
        i=$((i + 1))
    done
fi

if [ -n "$window_id" ]; then
    niri msg action focus-window --id "$window_id"
fi
