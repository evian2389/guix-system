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
    nix_install_if_missing ollama nixpkgs#ollama
    nix_install_if_missing glab nixpkgs#glab
    nix_install_if_missing warp-terminal nixpkgs#warp-terminal
    nix_install_if_missing steam-run nixpkgs#steam-run
    nix_install_if_missing xclip nixpkgs#xclip
    nix_install_if_missing wl-clipboard nixpkgs#wl-clipboard

    if command -v npm &> /dev/null; then
        npm config set prefix ~/.npm-global
        npm install -g @anthropic-ai/claude-code
        # OpenAI Codex CLI — native install (not in Guix at the pinned rev; the
        # official package builds from source and OOM-kills rustc here). The npm
        # package ships a static musl binary, so it runs on Guix without a
        # loader wrapper; herdr detects it by process name (`codex`).
        npm install -g @openai/codex
        npm install -g ctx7
        echo "Setting up Context7 for Antigravity..."
        ~/.npm-global/bin/ctx7 setup --antigravity -y < /dev/null || true
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
    flatpak install -y flathub app.zen_browser.zen
    #flatpak install -y flathub art.graphite.Graphite # image editor, not stable
    # Steam: prefer the Guix (nonguix) home-games-service-type. Flatpak Steam disabled —
    # re-enable this (and the home service) once Guix `steam` builds again.
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
     cargo install herdr
     # hermes-agent-cli removed: hermes-agent-cli-core 1.14.19 fails to build on
     # Unix (broken fs::Permissions usage in auth.rs, missing libc dep — it's a
     # Windows-first crate). Use kerux below instead.
     # kerux — "hermes-rs", a self-contained Rust AI agent runtime (`kerux` binary).
     # Not published to crates.io; workspace crate, MSRV 1.86 (ok on rustc 1.93).
     cargo install --git https://github.com/eikarna/kerux kerux-cli
     # NOTE: Pinned to 0.1.18 because newer versions (e.g. 0.1.22) require rustc >= 1.95,
     # but the system's pinned Guix channels currently provide rustc 1.93.0.
     cargo install pi_agent_rust --version 0.1.18

else
    echo "Warning: cargo not found. Skipping cargo packages."
fi

# Let herdr recognize coding agents (installs SessionStart/state hooks into each
# agent's config dir, e.g. ~/.claude, ~/.codex, ~/.gemini/config). Idempotent.
if command -v herdr &> /dev/null; then
    for agent in claude codex antigravity-cli; do
        herdr integration install "$agent" || true
    done
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
    for wrapper in /home/orka/.local/bin/agy-wrapper; do
        if [ -f "$wrapper" ]; then
            sed -i "s|/gnu/store/[a-z0-9]*-glibc-[^/]*/lib/ld-linux-x86-64\.so\.2|$GLIBC_LD|g" "$wrapper"
            echo "Updated $wrapper -> $GLIBC_LD"
        fi
    done
else
    echo "Warning: glibc ld-linux not found at $GLIBC_LD, skipping wrapper update"
fi

echo "Non-Guix package installation/update complete."
