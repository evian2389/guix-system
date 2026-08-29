#!/usr/bin/env bash

# Use Nix native steam-run (buildFHSEnv) for Nix binaries
exec ~/.nix-profile/bin/steam-run ~/.nix-profile/bin/warp-terminal "$@"
