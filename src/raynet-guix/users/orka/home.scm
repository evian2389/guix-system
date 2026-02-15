(define-module (raynet-guix users orka home)
  #:export (orka-home-environment)
  #:use-module (gnu)
  #:use-module (guix)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services dotfiles)
  #:use-module (raynet-guix users common)
  #:use-module (raynet-guix home-services games)      ; For home-steam-service-type
  #:use-module (raynet-guix home-services emacs)      ; For home-emacs-config-service-type
  #:use-module (raynet-guix home-services finance)    ; For home-finance-service-type
  #:use-module (srfi srfi-1)
  #:use-module (raynet-guix users common))


(define orka-home-environment
  (home-environment
   (inherit common-home-environment)
   (packages
    (append
     (list) ;; Add specific orka packages here if needed
     %base-packages))
   (services
     (append
      (list
        (service home-games-service-type)
        (service home-emacs-config-service-type)
        (service home-finance-service-type)
        (service home-dotfiles-service-type
                  (home-dotfiles-configuration
                  (source-directory ".")
                  (directories '("config/users/orka/files")))))
      (home-environment-services common-home-environment)))))
