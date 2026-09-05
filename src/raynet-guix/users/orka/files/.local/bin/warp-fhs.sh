#!/usr/bin/env bash

# Export TrueColor, CLICOLOR, and 256-color terminal variables
unset FONTCONFIG_FILE
export SHELL=/bin/zsh
export TERM=xterm-256color
export COLORTERM=truecolor
export CLICOLOR=1

exec ~/.nix-profile/bin/steam-run ~/.nix-profile/bin/warp-terminal "$@"
