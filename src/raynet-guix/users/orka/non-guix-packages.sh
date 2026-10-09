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

    # Hermes Agent (NousResearch) — Python agent + TUI, built from its own
    # flake (uv2nix). Native pip/uv installs are fragile on Guix: uv's managed
    # CPython hardcodes /lib64/ld-linux, and a venv bound to a Guix store python
    # dies on the next `guix gc` / `guix home reconfigure`. The Nix package is
    # patchelf'd and GC-managed, so it survives both. `hermes` on PATH is the
    # ~/.local/bin/hermes symlink pointing at ~/.nix-profile/bin/hermes.
    # herdr already ships a `hermes` integration + ~/.hermes/plugins hook, so
    # `hermes --tui` gets real idle/working/blocked reporting in herdr panes.
    HERMES_SRC="$HOME/.hermes/hermes-agent"
    if [ ! -d "$HERMES_SRC/.git" ]; then
        echo "Cloning hermes-agent..."
        mkdir -p "$HOME/.hermes"
        git clone https://github.com/NousResearch/hermes-agent.git "$HERMES_SRC"
    fi
    if [ -d "$HERMES_SRC/.git" ] && \
       ! nix profile list --extra-experimental-features "nix-command flakes" \
         | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Name:[[:space:]]*hermes-agent$"; then
        # Build from whatever revision is checked out (pull + rebuild manually
        # to update — avoids clobbering local edits and surprise rebuilds).
        # --impure: the flake reads its own git rev for the version string.
        echo "Installing hermes-agent from local flake..."
        nix profile install --extra-experimental-features "nix-command flakes" \
            --impure "git+file://$HERMES_SRC#default" || \
            echo "Warning: hermes-agent nix build failed; skipping."
    fi
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
     # Bookokrat — terminal EPUB/PDF/DJVU reader.
     CC=clang CXX=clang++ cargo install bookokrat
     # Miro PDF — native Wayland/X11 PDF viewer.
     # Bindgen needs libclang, which is in the Clang store input rather than
     # necessarily exposed in the active profile's library path.
     LIBCLANG_PATH="$(dirname "$(readlink -f "$(clang -print-file-name=libclang.so)")")"
     CC=clang CXX=clang++ LIBCLANG_PATH="$LIBCLANG_PATH" \
         CARGO_BUILD_JOBS=1 cargo install miro-pdf
     # hermes-agent-cli removed: hermes-agent-cli-core 1.14.19 fails to build on
     # Unix (broken fs::Permissions usage in auth.rs, missing libc dep — it's a
     # Windows-first crate). Use kerux below instead.
     # kerux — "hermes-rs", a self-contained Rust AI agent runtime (`kerux` binary).
     # Not published to crates.io; workspace crate, MSRV 1.86 (ok on rustc 1.93).
     cargo install --git https://github.com/eikarna/kerux kerux-cli
     # NOTE: Pinned to 0.1.18 because newer versions (e.g. 0.1.22) require rustc >= 1.95,
     # but the system's pinned Guix channels currently provide rustc 1.93.0.
     cargo install pi_agent_rust --version 0.1.18
     # ZeroClaw is built from the Herdr integration PR until that change lands
     # upstream. The PR is closed but its head remains available, so pin the
     # exact commit rather than following a moving branch. Override
     # ZEROCLAW_HERDR_REV to test another commit, or set it empty to install the
     # official MUSL release instead.
     if [ "${ZEROCLAW_HERDR_REV+x}" != x ]; then
         ZEROCLAW_HERDR_REV="5d32cfd10bb88a20045121f070602309b95e7e9f"
         RUSTC_VERSION="$(rustc --version | awk '{print $2}')"
         if [ "$(printf '%s\n' "$RUSTC_VERSION" 1.96.0 | sort -V | head -n1)" != "1.96.0" ]; then
             echo "rustc $RUSTC_VERSION is older than ZeroClaw's 1.96.0 MSRV; using the official release binary."
             ZEROCLAW_HERDR_REV=""
         fi
     fi
     if [ -n "$ZEROCLAW_HERDR_REV" ]; then
         echo "Installing ZeroClaw with Herdr integration ($ZEROCLAW_HERDR_REV)..."
         cargo install --locked --force --root "$HOME/.local" \
             --git https://github.com/zeroclaw-labs/zeroclaw \
             --rev "$ZEROCLAW_HERDR_REV" zeroclaw
     else
         # Official MUSL release fallback. Override ZEROCLAW_VERSION for a
         # controlled rollback or staging test.
         ZEROCLAW_VERSION="${ZEROCLAW_VERSION:-0.8.5}"
     ZEROCLAW_MACHINE="$(uname -m)"
     case "$ZEROCLAW_MACHINE" in
         x86_64) ZEROCLAW_TARGET="x86_64-unknown-linux-musl" ;;
         aarch64) ZEROCLAW_TARGET="aarch64-unknown-linux-musl" ;;
         *)
             echo "Warning: unsupported ZeroClaw architecture: $ZEROCLAW_MACHINE"
             ZEROCLAW_TARGET=""
             ;;
     esac
     if [ -n "$ZEROCLAW_TARGET" ]; then
         ZEROCLAW_ASSET="zeroclaw-${ZEROCLAW_TARGET}.tar.gz"
         ZEROCLAW_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/v${ZEROCLAW_VERSION}/${ZEROCLAW_ASSET}"
         ZEROCLAW_SUMS_URL="https://github.com/zeroclaw-labs/zeroclaw/releases/download/v${ZEROCLAW_VERSION}/SHA256SUMS"
         ZEROCLAW_TMP="$(mktemp -d "${TMPDIR:-/tmp}/zeroclaw.XXXXXX")"
         trap 'rm -rf "$ZEROCLAW_TMP"' EXIT
         curl --fail --silent --show-error --location "$ZEROCLAW_URL" \
             --output "$ZEROCLAW_TMP/$ZEROCLAW_ASSET"
         curl --fail --silent --show-error --location "$ZEROCLAW_SUMS_URL" \
             --output "$ZEROCLAW_TMP/SHA256SUMS"
         (cd "$ZEROCLAW_TMP" && grep "  $ZEROCLAW_ASSET$" SHA256SUMS \
             | sha256sum --check --strict -)
         tar --extract --gzip --file "$ZEROCLAW_TMP/$ZEROCLAW_ASSET" \
             --directory "$ZEROCLAW_TMP"
         install -Dm755 "$ZEROCLAW_TMP/zeroclaw" "$HOME/.local/bin/zeroclaw"
         echo "Installed ZeroClaw v$ZEROCLAW_VERSION ($ZEROCLAW_TARGET)"
     fi
     fi

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

# Render ~/.zeroclaw/config.toml from the committed template, injecting bot
# tokens from `pass`. ZeroClaw has no keyring support and rewrites its config in
# place, so this re-asserts the declarative config on every reconfigure-home.
"$(dirname "$0")/zeroclaw/render-config.sh" || echo "Warning: zeroclaw config render failed"

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
