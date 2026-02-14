(define-module (raynet-guix users orka home)
  #:use-module (gnu)
  #:use-module (guix)
  #:use-module (guix-home)
  #:use-module (gnu home services files)   ; For home-directory-configuration
  #:use-module (raynet-guix home common)
  #:use-module (raynet-guix home-services games)      ; For home-steam-service-type
  #:use-module (raynet-guix home-services emacs)      ; For home-emacs-config-service-type
  #:use-module (raynet-guix home-services finance)    ; For home-finance-service-type
  #:use-module (srfi srfi-1))

(home-environment
 (inherit common-home-environment)
 (packages
  (append
   (list "rust" "rust-analyzer")                            ; emacs is now handled by home-emacs-config-service-type
   %base-packages))
 (services
  (list
   (service home-games-service-type)
   (service home-emacs-config-service-type)
   (service home-finance-service-type)
   (service home-files-service-type
            (list
             (home-directory-configuration
              (source "config/users/orka/files")
              (target ".")
              (recursive? #t))))))) ; Recursively link contents
