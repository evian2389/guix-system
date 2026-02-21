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
  #:use-module (gnu packages fonts) ; For Google Noto CJK fonts
  #:use-module (gnu packages rust)
  #:use-module (gnu packages video)
  #:use-module (raynet-guix home-services video)      ; For home-video-service-type
  #:use-module (selected-guix-works packages fonts) ; For font-nerd-fonts-jetbrains-mono
  #:use-module (abbe packages nerd-fonts)    ; For font-nerd-font-d2coding
  #:use-module (gnu services)
  #:use-module (guix gexp) ; For define*
  #:export (common-home-environment
            extra-packages))

(define extra-packages
  (list
   htop
   fastfetch
   zsh
   mpv
   fcitx5
   fcitx5-configtool
   fcitx5-hangul
   fcitx5-gtk
   fcitx5-qt
   font-google-noto-sans-cjk
   font-google-noto-serif-cjk
   font-nerd-font-d2coding
   font-nerd-font-jetbrainsmono
   ))

(define* (common-home-environment #:key (extra-packages extra-packages) (extra-services '()))
  (home-environment
   (packages extra-packages)
   (services
    (append extra-services
            (list
             (service home-dbus-service-type)
             (service home-pipewire-service-type (home-pipewire-configuration))
             (service home-zsh-service-type
                      (home-zsh-configuration
                       (zprofile (list (plain-file "zprofile" "[[ -f ~/.zshrc ]] && . ~/.zshrc\n")))))
             (simple-service 'common-environment-variables
                             home-environment-variables-service-type
                             '(("XMODIFIERS" . "@im=fcitx")
                               ("GTK_IM_MODULE" . "fcitx")
                               ("QT_IM_MODULE" . "fcitx")
                               ("SDL_IM_MODULE" . "fcitx")
                               ;; Best setup for KDE Plasma 5.27+ Wayland:
                               ;; Do not set GTK_IM_MODULE, QT_IM_MODULE, or SDL_IM_MODULE.
                               ;; They should be unset to use the text-input protocol.
                               ;; However, Steam (Xwayland) and many games (SDL) still need them.
                               ("GLFW_IM_MODULE" . "fcitx")))
             (service home-xdg-configuration-files-service-type
                      `(("google-chrome-flags.conf"
                         ,(plain-file "google-chrome-flags.conf"
                                      "--enable-features=UseOzonePlatform\n--ozone-platform=wayland\n--enable-wayland-ime\n"))))
             (service home-video-service-type)      ; For ffmpeg and v4l-utils
             ;; Add common home services here
             )))))
