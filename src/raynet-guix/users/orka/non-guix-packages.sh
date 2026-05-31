#!/usr/bin/env bash

# This script installs/updates non-Guix packages from Nix and Flatpak.

set -e

echo "Installing/Updating Nix packages..."
if command -v nix-env &> /dev/null; then
    export NIXPKGS_ALLOW_UNFREE=1
    # hyprlax is available in nixpkgs
    nix-env -iA nixpkgs.hyprlax
    nix-env -iA nixpkgs.wiremix
    nix-env -iA nixpkgs.yazi
    nix-env -iA nixpkgs.bun
    nix-env -iA nixpkgs.ripasso-cursive
    nix-env -iA nixpkgs.nodejs
    npm config set prefix ~/.npm-global
    npm install -g @anthropic-ai/claude-code
    # nix-env -iA nixpkgs.oculante
else
    echo "Warning: nix-env not found. Skipping Nix packages."
fi

echo "Installing/Updating Flatpak packages..."
if command -v flatpak &> /dev/null; then
    # Add flathub if not already present
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    flatpak install -y flathub com.saivert.pwvucontrol
    flatpak install -y flathub com.google.Chrome
    flatpak install -y flathub io.github.woelper.Oculante
    flatpak install -y flathub com.usebottles.bottles
    # flatpak install flathub art.graphite.Graphite # image editor, not stable
    # flatpak install -y flathub com.valvesoftware.Steam
else
    echo "Warning: flatpak not found. Skipping Flatpak packages."
fi


echo "Installing/Updating Rust packages..."
if command -v cargo &> /dev/null; then
     # xtask ; steel scheme is available in cargo repo
     # cargo xtask install
     # cargo install satty
     cargo install pi-discord-rs
     cargo install cargo-watch   # not in Guix — file watcher for cargo
else
    echo "Warning: cargo not found. Skipping cargo packages."
fi

echo "Installing SurrealDB..."
if ! command -v surreal &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://install.surrealdb.com | sh
    echo "SurrealDB installed to ~/.surrealdb/surreal — ensure ~/.surrealdb is on PATH"
else
    echo "SurrealDB already installed: $(surreal version 2>/dev/null || echo 'version check failed')"
fi

mkdir -p ~/.local/state/claude-code

corepack enable --install-directory ~/.local/bin pnpm

echo "Updating wrapper scripts with current glibc path..."
GLIBC_LD=$(readlink -f ~/.guix-home/profile/lib/ld-linux-x86-64.so.2 2>/dev/null)
if [ -f "$GLIBC_LD" ]; then
    for wrapper in /home/orka/.local/bin/claude-wrapper /home/orka/.local/bin/agy-wrapper; do
        if [ -f "$wrapper" ]; then
            sed -i "s|/gnu/store/[a-z0-9]*-glibc-[^/]*/lib/ld-linux-x86-64\.so\.2|$GLIBC_LD|g" "$wrapper"
            echo "Updated $wrapper -> $GLIBC_LD"
        fi
    done
else
    echo "Warning: glibc ld-linux not found at $GLIBC_LD, skipping wrapper update"
fi

echo "Non-Guix package installation/update complete."
