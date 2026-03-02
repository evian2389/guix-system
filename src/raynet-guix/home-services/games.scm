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
  ))

(define-public home-games-service-type
  (service-type (name 'home-games)
                (description "Packages and configuration for Steam.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-games-profile-service)))
                (default-value #f)))
