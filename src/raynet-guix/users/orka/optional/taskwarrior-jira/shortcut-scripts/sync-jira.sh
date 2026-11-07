#!/usr/bin/env bash
set -euo pipefail

# Guix Home has no systemd user units; run the sync detached (the periodic
# run is the mcron job in ~/.config/cron/taskwarrior.guile).
nohup "$HOME/.local/bin/bugwarrior" pull --quiet >/dev/null 2>&1 </dev/null &
