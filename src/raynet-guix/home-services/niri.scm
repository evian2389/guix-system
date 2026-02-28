(define-module (raynet-guix home-services niri)
  #:use-module (gnu home services)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages freedesktop)
  #:use-module (guix gexp)
  #:export (home-niri-service-type))

(define (home-niri-profile-service config)
  (list niri
        fuzzel
        waybar
        swaynotificationcenter
        swww
        wl-clipboard))

(define home-niri-service-type
  (service-type (name 'home-niri)
                (description "Packages for niri WM. Configuration is managed via GNU Stow.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-niri-profile-service)))
                (default-value #f)))
