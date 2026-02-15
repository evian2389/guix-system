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
  #:use-module (guix utils)
  #:use-module (raynet-guix users common))

(define orka-home-environment
  (common-home-environment
   #:extra-packages %base-packages ;; Assuming %base-packages are orka-specific
   #:extra-services
   (list
    (service home-games-service-type)
    (service home-emacs-config-service-type)
    (service home-finance-service-type)
    ;;(service home-files-service-type
    ;;         `(( ".bashrc" . ,(local-file (string-append (dirname (current-filename)) "/files/bashrc")))))
    (service home-dotfiles-service-type
              (home-dotfiles-configuration
               (source-directory "./src/raynet-guix/users/orka/files")
               (directories (list ".config")))))))
