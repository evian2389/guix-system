(use-modules (guix)
             (gnu packages screen)     ; For neofetch
             (gnu packages text-editors) ; For helix
             (gnu packages vim)        ; For neovim
             (gnu packages video)      ; For mpv
             (nongnu packages chrome)
             (nongnu packages vscode)
             (abbe packages ghostty))   ; For ghostty terminal

(specifications->manifest
 (list
  "google-chrome"
  "vscode"
  "mpv"
  "ghostty"
  "neofetch"
  "helix"
  "neovim"))