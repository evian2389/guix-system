#!/usr/bin/env bash

# This script installs/updates non-Guix packages from Nix and Flatpak.

set -e

echo "Installing/Updating Nix packages..."
if command -v nix &> /dev/null; then
    export NIXPKGS_ALLOW_UNFREE=1

    nix_install_if_missing() {
        local pkg_name=$1
        local install_url=$2
        if nix profile list --extra-experimental-features "nix-command flakes" | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Name:[[:space:]]*$pkg_name$"; then
            echo "Nix package $pkg_name is already installed. Skipping..."
        else
            echo "Installing Nix package $pkg_name from $install_url..."
            nix profile install --extra-experimental-features "nix-command flakes" --impure "$install_url"
        fi
    }

    echo "Upgrading existing Nix packages..."
    nix profile upgrade --extra-experimental-features "nix-command flakes" '.*' || true

    nix_install_if_missing hyprlax nixpkgs#hyprlax
    nix_install_if_missing wiremix nixpkgs#wiremix
    nix_install_if_missing yazi nixpkgs#yazi
    nix_install_if_missing bun nixpkgs#bun
    nix_install_if_missing ripasso-cursive nixpkgs#ripasso-cursive
    nix_install_if_missing nodejs nixpkgs#nodejs
    nix_install_if_missing overskride nixpkgs#overskride
    nix_install_if_missing emulsion nixpkgs#emulsion

    if command -v npm &> /dev/null; then
        npm config set prefix ~/.npm-global
        npm install -g @anthropic-ai/claude-code
    fi

    # Install Google Antigravity GUI and IDE via Nix Flakes
    nix_install_if_missing antigravity-nix github:jacopone/antigravity-nix
    nix_install_if_missing google-antigravity-ide github:jacopone/antigravity-nix#google-antigravity-ide
else
    echo "Warning: nix command not found. Skipping Nix packages."
fi

echo "Installing/Updating Flatpak packages..."
if command -v flatpak &> /dev/null; then
    # Add flathub if not already present
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    flatpak install -y flathub com.saivert.pwvucontrol
    flatpak install -y flathub com.google.Chrome
    flatpak install -y flathub io.github.woelper.Oculante
    flatpak install -y flathub com.usebottles.bottles
    flatpak install -y flathub com.discordapp.Discord
    #flatpak install -y flathub art.graphite.Graphite # image editor, not stable
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
     cargo install --git https://github.com/e-tho/bzmenu
     cargo install zeekstd_cli

     echo "Installing/Updating ironbar..."
     if command -v guix &> /dev/null; then
         # Build ironbar: provide GTK4/Wayland dev headers via guix shell
         # gtk4 (not gtk=gtk3), libadwaita, and gtk4-layer-shell are the key ironbar deps
         # Note: Guix's luajit.pc has a bug where Version uses an undefined ${version} variable. We patch it dynamically.
         guix shell pkg-config gtk libadwaita graphene gtk4-layer-shell glib glib:bin cairo pango gdk-pixbuf wayland eudev libevdev luajit libinput gcc-toolchain -- bash -c '
             LUAJIT_PC_SRC=""
             IFS=":" read -ra ADDR <<< "$PKG_CONFIG_PATH"
             for dir in "${ADDR[@]}"; do
                 if [ -f "$dir/luajit.pc" ]; then
                     LUAJIT_PC_SRC="$dir/luajit.pc"
                     break
                 fi
             done
             if [ -n "$LUAJIT_PC_SRC" ]; then
                 mkdir -p /tmp/guix-pkgconfig
                 sed "s/Version: \${version}/Version: 2.1.0/" "$LUAJIT_PC_SRC" > /tmp/guix-pkgconfig/luajit.pc
                 export PKG_CONFIG_PATH="/tmp/guix-pkgconfig:$PKG_CONFIG_PATH"
             fi
             cargo install ironbar --locked
             rm -rf /tmp/guix-pkgconfig
         '
     else
         cargo install ironbar --locked
     fi
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

echo "Installing HelixDB..."
if ! command -v helix &> /dev/null; then
    curl -sSL "https://install.helix-db.com" | bash
    echo "HelixDB installed to ~/.local/bin — ensure it is on PATH"
else
    echo "HelixDB already installed: $(helix --version 2>/dev/null || echo 'version check failed')"
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
