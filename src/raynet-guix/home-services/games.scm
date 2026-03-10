(define-module (raynet-guix home-services games)
  #:use-module (gnu)
  #:use-module (guix)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages games)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu home services)
  #:use-module (nongnu packages game-client)
  )

;;
;; Home-level service for installing the Steam package.
;;

(define (home-games-profile-service config)
  (list
    steam
    mesa
    vulkan-loader
    mesa-utils
    vulkan-tools
  ))

(define-public home-games-service-type
  (service-type (name 'home-games)
                (description "Packages and configuration for Steam.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-games-profile-service)
                       (service-extension
                        home-files-service-type
                        (lambda (config)
                          `((".local/bin/steam"
                             ,(plain-file "steam-wrapper"
                                          "#!/bin/sh
export LD_LIBRARY_PATH=\"$HOME/.guix-home/profile/lib:$HOME/guix-system/env/profile/lib:$HOME/.guix-profile/lib:$HOME/.guix-profiles/orka-extra/lib:$LD_LIBRARY_PATH\"
# Use the absolute path to the profile's steam to avoid recursion
exec \"$HOME/.guix-home/profile/bin/steam\" \"$@\"
")))))))
                (default-value #f)))
