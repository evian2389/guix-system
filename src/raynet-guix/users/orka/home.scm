(define-module (raynet-guix users orka home)
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
  #:use-module (raynet-guix users common)
  #:use-module (raynet-guix packages base-utils)
  #:export (orka-home-environment))

(define orka-extra-packages
  (append development-tools
          system-tools))

(define orka-home-environment
  (common-home-environment
   #:extra-packages (append orka-extra-packages extra-packages)
   #:extra-services
   (list
    (service home-games-service-type)
    (service home-emacs-config-service-type)
    (service home-finance-service-type)
    ; (service home-dotfiles-service-type
    ;          (home-dotfiles-configuration
    ;           (source-directory (string-append (dirname (current-filename)) "/files"))
    ;           (directories (list ".config" ".local"))
    ;           (files `((".zshrc" ,(local-file (string-append (dirname (current-filename)) "/files/.zshrc")))))))
              )))

orka-home-environment
