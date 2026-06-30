(define-module (raynet-guix packages base-utils)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages password-utils)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages containers)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages build-tools)
  #:use-module (gnu packages node)
  #:use-module (gnu packages python)
  #:use-module (gnu packages golang)
  #:use-module (gnu packages golang-apps)
  #:use-module (gnu packages guile-xyz)
  #:use-module (gnu packages ocaml)
  #:use-module (gnu packages haskell)
  #:use-module (gnu packages haskell-apps)
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages lua)
  #:use-module (gnu packages java)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages video)
  #:use-module (gnu packages linux)   ; for brightnessctl
  #:use-module (gnu packages music)   ; for playerctl
  #:use-module (gnu packages sync)   ; for rclone
  #:use-module (gnu packages freedesktop) ; for xdg-desktop-portal
  #:use-module (gnu packages text-editors)   ; for helix
  #:use-module (gnu packages vim)   ; neovim
  #:use-module (gnu packages shells) ; For shell utils
  #:use-module (gnu packages shellutils) ; For shell utils
  #:use-module (gnu packages terminals) ; For terminal utils
  #:use-module (gnu packages image-viewers) ; For imv
  #:use-module (gnu packages image) ; For grim screenshot
  #:use-module (gnu packages gimp) ; For gimp
  #:use-module (gnu packages emacs)   ; neovim
  #:use-module (gnu packages web-browsers)     ; for qutebrowser
  #:use-module (gnu packages networking)     ; for blueman
  #:use-module (gnu packages kde-internet)
  #:use-module (gnu packages compression)     ;
  #:use-module (gnu packages tls)
  #:use-module (gnu packages docker)
  #:use-module (gnu packages databases)      ; redis, postgresql, timescaledb
  #:use-module (gnu packages high-availability) ; nats-server
  #:use-module (gnu packages web)
  #:use-module (gnu packages xdisorg)     ; pixz, hyprlock
  #:use-module (gnu packages audio)       ; pipemixer
  #:use-module (gnu packages gnome)       ; for gnome-keyring, libsecret
  #:use-module (gnu packages tmux)       ; for tmux
  #:use-module (nongnu packages chrome)      ; for google-chrome-stable
  #:use-module (nongnu packages mozilla)     ; for firefox
  #:use-module (nongnu packages messaging)     ; for element desktop messenger
  #:use-module (abbe packages ghostty)         ; for ghostty
  #:use-module (abbe packages zsh)         ; for ghostty
  #:use-module (abbe packages neovim)        ; for neovim
  #:use-module (shika packages satty)
  ; #:use-module (px packages editors)
  ; #:use-module (px packages tools)
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

(define-public development-tools
  (list
    git
    github-cli
    password-store
    difftastic
    gcc-toolchain
    clang-toolchain
    binutils
    cmake
    ;make
    compiledb
    uv
    bear
    autoconf
    pkg-config
    openssl
    zlib
    patch
    gdb
    node
    python
    ghc
    ; haskell-language-server
    ; cabal-install
    go
    nginx
    docker
    esbuild
    gopls
    openjdk
    rust
    (list rust "cargo")
    rust-analyzer
    guile-lsp-server
    ocaml
    ocaml-lsp-server
    ;lua
    sed
    flatpak
    podman
    podman-compose
    nats-server
    redis
    postgresql
    timescaledb
    slirp4netns
    fuse-overlayfs
    distrobox
    coreutils
    ; zed  ;;px
    ; codex ;; px
    perl
    ))

(define-public system-tools
  (list
    fd
    eza
    bat
    fzf-tab  ; for default completion menu of the zsh
    fzf
    imv
    brightnessctl
    playerctl
    satty
    grim
    slurp
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    power-profiles-daemon
    wlogout
    ghostty-fixed
    zoxide
    ripgrep
    sshfs
    pixz
    element-desktop
    mpv
    yt-dlp
    zsh
    helix
    neovim
    powerlevel-10k
    qutebrowser
    blueman
    kdeconnect
    gnome-keyring
    libsecret
    mcron
    rclone
    nomacs
    tmux
    gimp
    dank-material-shell
    hyprlock
    ))
