# Guix System Configuration - Context & Structure Guide

This repository contains the declarative Guix System and Guix Home configurations for the system (`ser8`).
This guide serves as a map and rule set for AI agents to easily understand the layout and make changes without scanning the entire workspace.

---

## 🗺️ Project Architecture & File Index

The core configuration is located under `src/raynet-guix/`.

### 1. Systems Configuration (System level)
*   **[base-system.scm](file:///home/orka/guix-system/src/raynet-guix/systems/base-system.scm)**: Defines the common operating system template `base-operating-system`. Contains core system packages (e.g., `btrfs-progs`, `zsh`, `niri`, `gnupg`), groups, user account specs (default: `orka`), and system-level services (`cups`, `openssh`, `sane`, `nix`).
*   **[ser8/configuration.scm](file:///home/orka/guix-system/src/raynet-guix/systems/ser8/configuration.scm)**: Machine-specific configuration for the `ser8` host. Inherits `base-operating-system` from `base-system.scm` and defines the hardware bootloader, Btrfs subvolumes/mounts, swap file, non-free firmwares, and basic machine packages (e.g., `mesa`, `bluez`, `vim`).

### 2. Users & Home Configuration (User level)
*   **[users/common.scm](file:///home/orka/guix-system/src/raynet-guix/users/common.scm)**: Defines the `common-home-environment` and `extra-packages` list shared across users (e.g., `htop`, `zsh-autosuggestions`, CJK fonts, desktop themes).
*   **[users/orka/home.scm](file:///home/orka/guix-system/src/raynet-guix/users/orka/home.scm)**: Home environment for the user `orka`. Inherits `common-home-environment` and adds custom home services (like `home-games-service-type`, `home-emacs-config-service-type`, etc.) and packages from `orka-extra-packages` (which compiles `development-tools` and `system-tools`).
*   **[users/orka/manifest.scm](file:///home/orka/guix-system/src/raynet-guix/users/orka/manifest.scm)**: A standalone manifest file used for extra user profiles. Installed via `make install-user-packages`.

### 3. Packages Modules
Define custom derivations or organize packages:
*   **[packages/base-utils.scm](file:///home/orka/guix-system/src/raynet-guix/packages/base-utils.scm)**: Defines:
    *   `development-tools`: List of programming/development packages (`gcc-toolchain`, `python`, `rust`, `docker`, etc.).
    *   `system-tools`: List of system/shell utilities (`fd`, `bat`, `ripgrep`, `zstd`, `archivemount`, `squashfs-tools`, etc.).
*   **[packages/emacs.scm](file:///home/orka/guix-system/src/raynet-guix/packages/emacs.scm)**: Custom Emacs packages.
*   **[packages/fonts.scm](file:///home/orka/guix-system/src/raynet-guix/packages/fonts.scm)**: Custom font configurations.
*   **[packages/kubernetes.scm](file:///home/orka/guix-system/src/raynet-guix/packages/kubernetes.scm)**: Kubernetes tools.
*   **[packages/linux.scm](file:///home/orka/guix-system/src/raynet-guix/packages/linux.scm)**: Custom Linux kernels or drivers.
*   **[packages/video.scm](file:///home/orka/guix-system/src/raynet-guix/packages/video.scm)**: Video/graphics utilities.
*   **[packages/zellij-bin.scm](file:///home/orka/guix-system/src/raynet-guix/packages/zellij-bin.scm)**: Zellij terminal multiplexer binary package.

### 4. Custom Home Services (`home-services/`)
Declares custom Guix home services that configure software configurations (dotfiles, daemons, etc.):
*   [audio.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/audio.scm): Pipewire/wireplumber home services.
*   [claude-code.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/claude-code.scm): Claude Code environment integration.
*   [desktop.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/desktop.scm): Wayland/desktop helpers.
*   [emacs.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/emacs.scm): Emacs config home service.
*   [games.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/games.scm): Steam and gaming rules.
*   [niri.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/niri.scm): Niri window manager config.
*   [mcron.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/mcron.scm): User-level cron jobs.
*   [ollama.scm](file:///home/orka/guix-system/src/raynet-guix/home-services/ollama.scm): Ollama background daemon service.
*   [vpn.scm](file:///home/orka/guix-system/src/raynet-guix/services/vpn.scm): System-level VPN configuration services.

---

## 🛠️ How to Add/Change Packages

### Rule 1: Check availability in Guix
Always run `guix package -A <package>` or check using a quick REPL verification:
```bash
echo '(use-modules (gnu packages <module>)) (format #t "~a~%" <package-name>)' | guix repl
```
If the package **is** available in Guix:
1. Locate the correct Guix module (e.g., `(gnu packages compression)`).
2. Ensure the module is imported in `base-utils.scm` (or `base-system.scm`).
3. Add the package symbol to the appropriate list:
    *   System tools / CLI utils: Append to `system-tools` in `base-utils.scm`.
    *   Programming tools: Append to `development-tools` in `base-utils.scm`.
    *   Hardware or global tools: Append to the list in `base-system.scm` or `configuration.scm`.

### Rule 2: Fallback to `non-guix-packages.sh`
If a package is **not** available in Guix, do not write custom system configurations for it. Instead:
1. Append the installation command to **[non-guix-packages.sh](file:///home/orka/guix-system/src/raynet-guix/users/orka/non-guix-packages.sh)**.
2. The script supports:
    *   `nix_install_if_missing` for Nix packages.
    *   `flatpak install` for desktop applications.
    *   `cargo install` for Rust tools.
    *   Direct downloads / curls for standalone binaries.

---

## ⚙️ Key Deployment Commands (via Makefile)

Deployment is managed via the top-level **[Makefile](file:///home/orka/guix-system/Makefile)**:
*   `make reconfigure-system`: Reconfigures the core operating system (`sudo guix system reconfigure`).
*   `make reconfigure-home`: Reconfigures Guix Home, installs extra packages, and runs `non-guix-packages.sh`.
*   `make all`: Runs both system and home reconfiguration.

---

## 📌 Known Package Pinning & Workarounds

*   **`pi_agent_rust`**: Pinned to version `0.1.18` in **[non-guix-packages.sh](file:///home/orka/guix-system/src/raynet-guix/users/orka/non-guix-packages.sh)** because newer versions require a newer Rust compiler (>= 1.95), whereas the pinned Guix channels currently provide Rust `1.93.0`. Update/remove this pin once Guix channels are updated to include a newer Rust compiler.

