(define-module (raynet-guix users common)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells) ; Added for zsh
  #:use-module (gnu home services sound) ; Added for pipewire
  #:use-module (gnu home services desktop)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages fcitx5) ; Added for fcitx5
  #:use-module (gnu packages admin) ; For htop
  #:use-module (gnu packages version-control) ; For git
  #:use-module (gnu packages shells) ; For zsh
  #:use-module (gnu packages shellutils) ; For shell utils
  #:use-module (gnu packages terminals) ; For terminal utils
  #:use-module (gnu packages fonts) ; For Google Noto CJK fonts
  #:use-module (gnu packages rust)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages video)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnome-xyz)
  #:use-module (gnu packages xorg)
  #:use-module (nongnu packages chrome)
  #:use-module (raynet-guix home-services video)      ; For home-video-service-type
  #:use-module (raynet-guix home-services audio)
  #:use-module (raynet-guix home-services niri)
  #:use-module (raynet-guix home-services finance)
  #:use-module (selected-guix-works packages fonts) ; For font-nerd-fonts-jetbrains-mono
  #:use-module (abbe packages nerd-fonts)    ; For font-nerd-font-d2coding
  #:use-module (gnu services)
  #:use-module (guix gexp) ; For define*
  #:use-module (ice-9 optargs)
  #:export (common-home-environment
            extra-packages))

(define extra-packages
  (list
   htop
   fastfetch
   xdg-utils
   desktop-file-utils
   fcitx5
   fcitx5-configtool
   fcitx5-hangul
   fcitx5-gtk
   fcitx5-qt
   font-google-noto-sans-cjk
   font-google-noto-serif-cjk
   font-nerd-font-d2coding
   font-nerd-font-jetbrainsmono
   font-iosevka-aile
   font-iosevka-ss08
   zsh-autosuggestions
   adwaita-icon-theme
   bibata-cursor-theme
   xrdb
   xwayland-run
   xwayland-satellite
   xorg-server-xwayland
   ))

(define* (common-home-environment #:key (extra-packages extra-packages) (extra-services '()))
  (home-environment
   (packages extra-packages)
   (services
    (append extra-services
            (list
             (service home-dbus-service-type)
             (service home-finance-service-type)
             (service home-pipewire-service-type
                      (home-pipewire-configuration
                       (enable-pulseaudio? #t)))
             (simple-service 'common-environment-variables
                             home-environment-variables-service-type
                             '(("PATH" . "$HOME/.guix-home/profile/bin:$PATH:$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-packages/bin:$HOME/.config/emacs/bin/:$HOME/.nix-profile/bin:$HOME/.local/share/flatpak/exports/bin")
                               ("XMODIFIERS" . "@im=fcitx")
                               ;;("GTK_IM_MODULE" . "fcitx")
                               ;;("QT_IM_MODULE" . "fcitx")
                               ;;("SDL_IM_MODULE" . "fcitx")
                               ("XDG_DATA_DIRS" . "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$HOME/.local/share:$HOME/.guix-home/profile/share:$XDG_DATA_DIRS")
                               ;; Best setup for KDE Plasma 5.27+ Wayland:
                               ;; Do not set GTK_IM_MODULE, QT_IM_MODULE, or SDL_IM_MODULE.
                               ;; They should be unset to use the text-input protocol.
                               ;; However, Steam (Xwayland) and many games (SDL) still need them.
                               ("GLFW_IM_MODULE" . "fcitx")))
             (simple-service 'dbus-env-update
                home-run-on-first-login-service-type
                #~(spawn "dbus-update-activation-environment" '("--all")))
             (service home-xdg-configuration-files-service-type
                      `(("google-chrome-flags.conf"
                         ,(plain-file "google-chrome-flags.conf"
                                      "--enable-features=UseOzonePlatform\n--ozone-platform=wayland\n--enable-wayland-ime\n"))))
             (simple-service 'source-extra-profiles
                             home-shell-profile-service-type
                             (list
                              (plain-file "extra-profiles"
                                          "\
# Source .session-profile for consistent environment variables
if [ -f \"$HOME/.session-profile\" ]; then
  source \"$HOME/.session-profile\"
fi

# Also source home profile just in case session-profile is missing
if [ -f \"$HOME/.guix-home/profile/etc/profile\" ]; then
  source \"$HOME/.guix-home/profile/etc/profile\"
fi
")))

             (service home-video-service-type)      ; For ffmpeg and v4l-utils
             (service home-audio-service-type)
             (service home-niri-service-type)
             ;; Add common home services here
             )))))
