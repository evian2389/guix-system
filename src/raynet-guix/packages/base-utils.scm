(define-module (raynet-guix packages base-utils)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages containers)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages golang-apps)
  #:use-module (gnu packages ocaml)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages video)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages text-editors)   ; for helix
  #:use-module (gnu packages vim)   ; neovim
  #:use-module (gnu packages emacs)   ; neovim
  #:use-module (abbe packages neovim)        ; for neovim
  #:use-module (nongnu packages chrome)      ; for google-chrome-stable
  #:use-module (nongnu packages mozilla)     ; for firefox
  #:use-module (px packages editors)         ; for antigravity
  #:use-module (px packages tools)         ; for antigravity
  #:use-module (saayix packages terminals)         ; for ghostty
  #:use-module (saayix packages file-managers)         ; for ghostty
  #:use-module (abbe packages zsh)         ; for ghostty
  #:export (development-tools
            system-tools))

(define development-tools
  (list
    git
    gcc-toolchain
    clang-toolchain
    binutils
    cmake
    autoconf
    pkg-config
    patch
    gdb
    node
    python
    go
    gopls
    rust
    (list rust "cargo")
    rust-analyzer
    ocaml
    ocaml-lsp-server
    sed
    flatpak
    podman
    slirp4netns
    fuse-overlayfs
    distrobox
    coreutils))

(define system-tools
  (list
    fd
    eza
    broot
    yazi
    ghostty
    emacs
    zoxide
    ripgrep
    dunst
    sshfs
    ;;google-chrome-stable
    firefox
    mpv
    helix
    neovim
    antigravity
    powerlevel-10k
    ))
