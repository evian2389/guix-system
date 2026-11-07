(define-module (raynet-guix users orka home)
  #:use-module (gnu)
  #:use-module (guix)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services)
  #:use-module (gnu home services dotfiles)
  #:use-module (gnu packages task-management) ; zk and Taskwarrior
  #:use-module (gnu packages gnome) ; Fractal Matrix client
  #:use-module (raynet-guix users common)
  #:use-module (raynet-guix home-services games)      ; For home-steam-service-type
  ;; #:use-module (raynet-guix home-services emacs)      ; For home-emacs-config-service-type
  #:use-module (raynet-guix home-services finance)    ; For home-finance-service-type
  #:use-module (raynet-guix home-services openclaw)   ; For home-openclaw-service-type
  #:use-module (raynet-guix home-services claude-code) ; For home-claude-code-service-type
  #:use-module (raynet-guix home-services mcron)      ; For home-mcron-config-service-type
  #:use-module (raynet-guix home-services ollama)     ; For home-ollama-service-type
  #:use-module (raynet-guix home-services microclaw)  ; For home-microclaw-service-type
  #:use-module (raynet-guix home-services meclaw)
  #:use-module (raynet-guix home-services taskwarrior)
  #:use-module (srfi srfi-1)
  #:use-module (guix utils)
  #:use-module (raynet-guix packages base-utils)
  #:use-module (raynet-guix users common)
  #:export (orka-home-environment))

(define orka-extra-packages
  (append development-tools
          system-tools
          (list zk fractal taskwarrior)))

(define orka-home-environment
  (common-home-environment
   #:extra-packages (append orka-extra-packages extra-packages)
   #:extra-services
   (list
    (simple-service 'deeptutor-service
                    home-shepherd-service-type
                    (list (shepherd-service
                           (provision '(deeptutor))
                           (documentation "Run DeepTutor for access through Tailscale Serve.")
                           (respawn? #t)
                           (respawn-limit #~'(5 . 30))
                           (auto-start? #t)
                           (start #~(make-forkexec-constructor
                                     (list "/home/orka/work/ai-tutor/start-deeptutor.sh")
                                     #:directory "/home/orka/work/ai-tutor"
                                     #:log-file "/home/orka/work/ai-tutor/data/logs/deeptutor-service.log"))
                           (stop #~(make-kill-destructor)))))
    (simple-service 'notes-vault-environment
                    home-environment-variables-service-type
                    '(("NOTES_VAULT_DIR" . "$HOME/notes/nvim-vault")
                      ("ZK_NOTEBOOK_DIR" . "$HOME/notes/nvim-vault")))
    (service home-games-service-type)
    ;; (service home-emacs-config-service-type)
    (service home-finance-service-type)
    ;; (service home-openclaw-service-type)
    (service home-claude-code-service-type)
    (service home-mcron-config-service-type)
    (service home-ollama-service-type)
    (service home-microclaw-service-type
             (home-microclaw-configuration
              (repository "~/work/workflow-evolution")
              (gateway-enabled? #f)))
    (service home-meclaw-service-type
             (home-meclaw-configuration
              (repository "~/work/workflow-evolution")
              (telegram? #f)
              (matrix? #t)))
    (service home-taskwarrior-service-type)
    ; (service home-dotfiles-service-type
    ;          (home-dotfiles-configuration
    ;           (source-directory (string-append (getcwd) "/src/raynet-guix/users/orka/files"))
    ;           (layout 'stow)))
    )))

orka-home-environment
