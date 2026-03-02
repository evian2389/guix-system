#!/usr/bin/env bash

# This script installs/updates non-Guix packages from Nix and Flatpak.

set -e

echo "Installing/Updating Nix packages..."
if command -v nix-env &> /dev/null; then
    export NIXPKGS_ALLOW_UNFREE=1
    # hyprlax is available in nixpkgs
    nix-env -iA nixpkgs.hyprlax
    nix-env -iA nixpkgs.wiremix
else
    echo "Warning: nix-env not found. Skipping Nix packages."
fi

echo "Installing/Updating Flatpak packages..."
if command -v flatpak &> /dev/null; then
    # Add flathub if not already present
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    flatpak install -y flathub com.saivert.pwvucontrol
    flatpak install -y flathub com.google.Chrome
    # flatpak install -y flathub com.valvesoftware.Steam
else
    echo "Warning: flatpak not found. Skipping Flatpak packages."
fi


# echo "Installing/Updating Rust packages..."
# if command -v cargo &> /dev/null; then
#     # xtask ; steel scheme is available in cargo repo
#     # cargo xtask install
#     #cargo install wiremix
# else
#     echo "Warning: cargo not found. Skipping cargo packages."
# fi


echo "Non-Guix package installation/update complete."
