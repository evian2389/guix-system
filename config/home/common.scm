(define-module (config home common)
  #:use-module (gnu)
  #:use-module (guix-home)
  #:use-module (guix-home services)
  #:use-module (gnu home services shells) ; Added for zsh
  #:use-module (gnu packages fcitx5) ; Added for fcitx5
  #:use-module (gnu packages admin) ; For htop
  #:use-module (config home-services video)      ; For home-video-service-type
  #:use-module (selected-guix-works packages fonts) ; For font-nerd-fonts-jetbrains-mono
  #:use-module (abbe packages nerd-fonts)    ; For font-nerd-font-d2coding
  #:use-module (guix)
  #:use-module (gnu services)
  #:export (common-home-environment))

(define common-home-environment
  (home-environment
   (packages
    (list
     "git"
     "htop"    ; Moved back to common
     "zsh"
     "fcitx5"
     "fcitx5-hangul"
     "fcitx5-gtk"  ; For GTK integration
     "fcitx5-qt"
     "font-nerd-fonts-jetbrains-mono"
     "font-nerd-font-d2coding"))      ; Added D2Coding Nerd Font
   (session-variables
    '(("GTK_IM_MODULE" . "fcitx")
      ("QT_IM_MODULE" . "fcitx")
      ("XMODIFIERS" . "@im=fcitx")))
   (services
    (list
     (service home-shell-profile-service-type
              (home-shell-profile-configuration
               (shell zsh))) ; Configured zsh as default shell
     (service home-video-service-type)      ; For ffmpeg and v4l-utils
     ;; Add common home services here
     ))))