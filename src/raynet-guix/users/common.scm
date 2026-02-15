(define-module (raynet-guix users common)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells) ; Added for zsh
  #:use-module (gnu home services sound) ; Added for pipewire
  #:use-module (gnu home services desktop)
  #:use-module (gnu packages fcitx5) ; Added for fcitx5
  #:use-module (gnu packages admin) ; For htop
  #:use-module (gnu packages version-control) ; For git
  #:use-module (gnu packages shells) ; For zsh
  #:use-module (gnu packages rust)
  #:use-module (gnu packages video)
  #:use-module (raynet-guix home-services video)      ; For home-video-service-type
  #:use-module (selected-guix-works packages fonts) ; For font-nerd-fonts-jetbrains-mono
  #:use-module (abbe packages nerd-fonts)    ; For font-nerd-font-d2coding
  #:use-module (gnu services)
  #:use-module (guix gexp) ; For define*
  #:export (common-home-environment))

(define* (common-home-environment #:key (extra-packages '()) (extra-services '()))
  (home-environment
   (packages
    (append extra-packages
            (list
             git
             rust
             htop    ; Moved back to common
             zsh
             mpv
             fcitx5
             fcitx5-hangul
             fcitx5-gtk  ; For GTK integration
             fcitx5-qt
             font-nerd-fonts-jetbrains-mono
             font-nerd-font-d2coding)))      ; Added D2Coding Nerd Font
   (services
    (append extra-services
            (list
             (service home-dbus-service-type)
             (service home-pipewire-service-type)
             (service home-zsh-service-type)
             (simple-service 'common-environment-variables
                             home-environment-variables-service-type
                             '(("GTK_IM_MODULE" . "fcitx")
                               ("QT_IM_MODULE" . "fcitx")
                               ("XMODIFIERS" . "@im=fcitx")))
             (service home-video-service-type)      ; For ffmpeg and v4l-utils
             ;; Add common home services here
             )))))