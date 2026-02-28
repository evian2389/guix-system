(define-module (raynet-guix packages base-utils)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
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
  #:use-module (gnu packages wm)
  #:use-module (gnu packages video)
  #:use-module (gnu packages linux)   ; for brightnessctl
  #:use-module (gnu packages music)   ; for playerctl
  #:use-module (gnu packages freedesktop) ; for xdg-desktop-portal
  #:use-module (gnu packages text-editors)   ; for helix
  #:use-module (gnu packages vim)   ; neovim
  #:use-module (gnu packages shells) ; For shell utils
  #:use-module (gnu packages shellutils) ; For shell utils
  #:use-module (gnu packages terminals) ; For terminal utils
  #:use-module (gnu packages image-viewers) ; For imv
  #:use-module (gnu packages emacs)   ; neovim
  #:use-module (gnu packages web-browsers)     ; for qutebrowser
  #:use-module (gnu packages compression)     ; pixz
  #:use-module (gnu packages xdisorg)     ; pixz
  #:use-module (nongnu packages chrome)      ; for google-chrome-stable
  #:use-module (nongnu packages mozilla)     ; for firefox
  #:use-module (px packages editors)         ; for antigravity
  #:use-module (px packages version-control)         ; for git hub cli
  #:use-module (px packages tools)         ; for antigravity
  #:use-module (saayix packages terminals)         ; for ghostty
  #:use-module (saayix packages file-managers)         ; for ghostty
  #:use-module (abbe packages zsh)         ; for ghostty
  #:use-module (abbe packages neovim)        ; for neovim
  #:export (development-tools
            system-tools
            ghostty-fixed))

(define-public ghostty-fixed
  (package
    (inherit ghostty)
    (arguments
     (substitute-keyword-arguments (package-arguments ghostty)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-after 'install 'fix-desktop-file
              (lambda _
                (let ((desktop-file (string-append #$output "/share/applications/com.mitchellh.ghostty.desktop")))
                  (substitute* desktop-file
                    (("^Exec=\\./bin/ghostty") (string-append "Exec=" #$output "/bin/ghostty"))
                    (("^TryExec=\\./bin/ghostty") (string-append "TryExec=" #$output "/bin/ghostty"))))))))))))

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
    coreutils
    gh))

(define system-tools
  (list
    fd
    eza
    bat
    fzf-tab  ; for default completion menu of the zsh
    fzf
    broot
    yazi
    imv
    brightnessctl
    playerctl
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    hyprlock
    ghostty-fixed
    zoxide
    ripgrep
    dunst
    sshfs
    pixz
    ;;google-chrome-stable
    firefox
    mpv
    yt-dlp
    zsh
    helix
    neovim
    emacs
    antigravity
    powerlevel-10k
    qutebrowser
    ))
