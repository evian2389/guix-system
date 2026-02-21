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
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages linux)
  #:use-module (saayix packages terminals)         ; for ghostty
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
    rust
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
    ghostty
    zoxide
    ripgrep
    dunst
    sshfs))
