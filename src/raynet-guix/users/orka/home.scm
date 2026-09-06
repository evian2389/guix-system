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
  #:use-module (raynet-guix home-services openclaw)   ; For home-openclaw-service-type
  #:use-module (raynet-guix home-services claude-code) ; For home-claude-code-service-type
  #:use-module (raynet-guix home-services mcron)      ; For home-mcron-config-service-type
  #:use-module (raynet-guix home-services ollama)     ; For home-ollama-service-type
  #:use-module (srfi srfi-1)
  #:use-module (guix utils)
  #:use-module (raynet-guix packages base-utils)
  #:use-module (raynet-guix users common)
  #:export (orka-home-environment))

(define orka-extra-packages
  (append development-tools
          system-tools))

(define orka-home-environment
  (common-home-environment
   #:extra-packages (append orka-extra-packages extra-packages)
   #:extra-services
   (list
    ;; (service home-games-service-type)   ; disabled — Guix `steam` currently fails to build:
    ;; a flaky gst-plugins-good@1.28.1 matroskademux test (off-by-1ns duration assert) aborts
    ;; the build, and it lives in a non-substitutable nonguix closure. Re-enable once a channel
    ;; bump fixes/skips that test. Flatpak Steam is also disabled (non-guix-packages.sh).
    (service home-emacs-config-service-type)
    (service home-finance-service-type)
    ;; (service home-openclaw-service-type)
    (service home-claude-code-service-type)
    (service home-mcron-config-service-type)
    (service home-ollama-service-type)
    ; (service home-dotfiles-service-type
    ;          (home-dotfiles-configuration
    ;           (source-directory (string-append (getcwd) "/src/raynet-guix/users/orka/files"))
    ;           (layout 'stow)))
    )))

orka-home-environment
