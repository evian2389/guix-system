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
    nix profile upgrade --extra-experimental-features "nix-command flakes" --impure --all || true

    nix_install_if_missing hyprlax nixpkgs#hyprlax
    # Install the non-Guix Rust toolchain before installing Cargo applications.
    nix_install_if_missing rustc nixpkgs#rustc
    nix_install_if_missing cargo nixpkgs#cargo
    nix_install_if_missing rust-analyzer nixpkgs#rust-analyzer
    nix_install_if_missing wiremix nixpkgs#wiremix
    nix_install_if_missing yazi nixpkgs#yazi
    # Locale data for Nix-built programs (they ignore Guix's GUIX_LOCPATH).
    nix_install_if_missing glibc-locales nixpkgs#glibcLocales
    nix_install_if_missing bun nixpkgs#bun
    nix_install_if_missing ripasso-cursive nixpkgs#ripasso-cursive
    nix_install_if_missing nodejs nixpkgs#nodejs
    nix_install_if_missing overskride nixpkgs#overskride
    nix_install_if_missing emulsion nixpkgs#emulsion
    nix_install_if_missing ollama nixpkgs#ollama
    nix_install_if_missing glab nixpkgs#glab
    nix_install_if_missing warp-terminal nixpkgs#warp-terminal
    nix_install_if_missing steam-run nixpkgs#steam-run
    # Toad (ACP TUI) needs Python>=3.14; Guix tops out at 3.13 and uv's own builds lack /lib64.
    nix_install_if_missing python314 nixpkgs#python314
    nix_install_if_missing xclip nixpkgs#xclip
    nix_install_if_missing wl-clipboard nixpkgs#wl-clipboard

    if command -v uv &> /dev/null && [ -x "$HOME/.nix-profile/bin/python3.14" ]; then
        uv tool install -U --python "$HOME/.nix-profile/bin/python3.14" batrachian-toad || true
    fi

    if command -v npm &> /dev/null; then
        npm config set prefix ~/.npm-global
        npm install -g @anthropic-ai/claude-code
        # OpenAI Codex CLI — native install (not in Guix at the pinned rev; the
        # official package builds from source and OOM-kills rustc here). The npm
        # package ships a static musl binary, so it runs on Guix without a
        # loader wrapper; herdr detects it by process name (`codex`).
        npm install -g @openai/codex
        npm install -g ctx7
        # Martty: ACP terminal client (alternative to Toad) for the MeClaw shim.
        npm install -g martty
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


echo "Installing OKF (Open Knowledge Format) reference tooling via uv..."
# Pinned to a commit; used for `reference-agent visualize --bundle ~/work/ai-wiki/docs`.
# Not in Guix or nixpkgs. Heavy deps (google-adk) are only needed for the
# BigQuery enrich agent, but the CLI imports them, so a full install is used.
if command -v uv &> /dev/null; then
    uv tool install --python 3.12 --force \
        "git+https://github.com/GoogleCloudPlatform/open-knowledge-format@ad30107c31c06aec8a7d5636e0d1058118604e6f" \
        || echo "Warning: OKF tool install failed"
else
    echo "Warning: uv not found. Skipping OKF tooling."
fi

echo "Installing/Updating Rust packages..."
export PATH="$HOME/.nix-profile/bin:$HOME/.cargo/bin:$PATH"

if command -v cargo &> /dev/null; then
     # xtask ; steel scheme is available in cargo repo
     # cargo xtask install
     # cargo install satty
     cargo install pi-discord-rs
     cargo install cargo-watch   # not in Guix — file watcher for cargo
     cargo install --git https://github.com/e-tho/bzmenu
     cargo install zeekstd_cli
     # Mail stack (Gmail later): himalaya CLI + sirup (pre-authenticated IMAP/SMTP
     # sockets). Installed via cargo first; himalaya is also in Guix (px channel).
     cargo install --locked himalaya
     cargo install --locked --git https://github.com/pimalaya/sirup.git sirup
     # herdr self-updates from its own release channel; the crates.io `herdr`
     # crate is a stale 0.1.0 and must not be used.
     if command -v herdr &> /dev/null; then
         # Refuses to replace a running server; stop sessions and rerun if skipped.
         herdr update || echo "Warning: herdr update failed or skipped"
     else
         curl -fsSL https://herdr.dev/install.sh | sh \
             || echo "Warning: herdr install failed"
     fi
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
     # Not published to crates.io; workspace crate, MSRV 1.86.
     cargo install --git https://github.com/eikarna/kerux kerux-cli
     # MicroClaw's server CLI is distributed as a release binary, not a
     # crates.io executable. Keep the ELF binary out of PATH and expose it via
     # the Guix-compatible wrapper installed from files/.local/bin/microclaw.
     echo "Installing MicroClaw release..."
     (
         MICROCLAW_INSTALLER="$(mktemp "${TMPDIR:-/tmp}/microclaw-install.XXXXXX")"
         trap 'rm -f "$MICROCLAW_INSTALLER"' EXIT
         curl --fail --silent --show-error --location \
             https://microclaw.org/install.sh --output "$MICROCLAW_INSTALLER"
         mkdir -p "$HOME/.local/libexec"
         MICROCLAW_INSTALL_DIR="$HOME/.local/libexec" \
             MICROCLAW_INSTALL_SKIP_RUN=1 sh "$MICROCLAW_INSTALLER" --skip-run
     )
     # Remove the manually tested binary from cargo/bin so the wrapper on PATH
     # always supplies Guix's loader and native runtime library paths.
     rm -f "$HOME/.cargo/bin/microclaw" "$HOME/.local/bin/moltis"
     # The old moltis service may no longer exist in the home config; only stop it
     # when shepherd still knows about it (otherwise herd prints an error).
     if command -v herd &> /dev/null && herd status moltis &> /dev/null; then
         herd stop moltis || true
     fi

else
    echo "Warning: cargo not found. Skipping cargo packages."
fi

# Herdr Orch: build the CLI from its source checkout, install a wrapper that
# keeps each project's orchestration state on a verified RAM-backed tmpfs,
# and install the controller/participant skills for Codex.
HERDR_ORCH_SRC="$HOME/tools/herdr-orchestrator"
HERDR_ORCH_URL="https://github.com/kylezk777/herdr-orchestrator.git"
if ! command -v cargo &> /dev/null; then
    echo "Error: cargo is required to build herdr-orchestrator."
    exit 1
fi
if [ ! -e "$HERDR_ORCH_SRC" ]; then
    mkdir -p "$(dirname "$HERDR_ORCH_SRC")"
    git clone "$HERDR_ORCH_URL" "$HERDR_ORCH_SRC"
elif [ ! -d "$HERDR_ORCH_SRC/.git" ]; then
    echo "Error: Orch source path exists but is not a Git checkout: $HERDR_ORCH_SRC"
    exit 1
fi
if [ "$(git -C "$HERDR_ORCH_SRC" remote get-url origin)" != "$HERDR_ORCH_URL" ]; then
    echo "Error: unexpected Orch origin at $HERDR_ORCH_SRC"
    exit 1
fi
HERDR_ORCH_PATCH="$(dirname "$0")/herdr-orchestrator-rust-1.93.patch"
if ! git -C "$HERDR_ORCH_SRC" apply --reverse --check "$HERDR_ORCH_PATCH" 2>/dev/null; then
    git -C "$HERDR_ORCH_SRC" apply "$HERDR_ORCH_PATCH"
fi
(cd "$HERDR_ORCH_SRC" && cargo build --release --locked)
HERDR_ORCH_WRAPPER="$(dirname "$0")/files/.local/bin/orch"
if [ -e "$HOME/.local/bin/orch" ] && [ "$HERDR_ORCH_WRAPPER" -ef "$HOME/.local/bin/orch" ]; then
    chmod 755 "$HOME/.local/bin/orch"
else
    install -Dm755 "$HERDR_ORCH_WRAPPER" "$HOME/.local/bin/orch"
fi
bash "$HERDR_ORCH_SRC/scripts/install-skills.sh" \
    --mode controller \
    --target-dir "${CODEX_HOME:-$HOME/.codex}/skills"
for HERDR_SKILL_DIR in "$HOME/.claude/skills" "$HOME/.gemini/antigravity-cli/skills"; do
    bash "$HERDR_ORCH_SRC/scripts/install-skills.sh" \
        --mode participant \
        --target-dir "$HERDR_SKILL_DIR"
done
echo "Installed Herdr Orch CLI, RAM-backed state wrapper, and Codex skills."

# Let herdr recognize coding agents (installs SessionStart/state hooks into each
# agent's config dir, e.g. ~/.claude, ~/.codex, ~/.gemini/config). Idempotent.
if command -v herdr &> /dev/null; then
    for agent in claude codex antigravity-cli; do
        herdr integration install "$agent" || true
    done
fi

# The old ZeroClaw service is removed by Guix Home reconfiguration above.
# Remove its standalone binaries while keeping ~/.zeroclaw data for recovery.
rm -f "$HOME/.local/bin/zeroclaw" "$HOME/.local/bin/zeroclaw.bak"

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

# DeepTutor Matrix channel (Matrix SDK is not packaged in Guix).
DEEPTUTOR_MATRIX_PIP="$HOME/work/ai-tutor/.deeptutor-1.7.1-venv/bin/pip"
if [ -x "$DEEPTUTOR_MATRIX_PIP" ]; then
    "$DEEPTUTOR_MATRIX_PIP" install "deeptutor[matrix-e2e]==1.7.1"
else
    echo "Warning: DeepTutor venv not found; skipping Matrix extra."
fi

echo "Non-Guix package installation/update complete."
