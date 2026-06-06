(define-module (raynet-guix home-services claude-code)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services configuration)
  #:use-module (guix gexp)
  #:export (home-claude-code-service-type))

(define (home-claude-code-shepherd-service config)
  (list
   (shepherd-service
    (provision '(claude-code))
    (documentation "Run Claude Code as a channel service.")
    (respawn? #t)
    (respawn-limit #~'(5 . 30))
    (auto-start? #t)
    (start #~(let* ((home (passwd:dir (getpwuid (getuid))))
                    (log-file (string-append home "/.local/state/claude-code/claude-code.log")))
               (make-forkexec-constructor
                (list (string-append home "/.local/bin/claude-wrapper"))
                #:directory home
                #:log-file log-file
                #:environment-variables
                (list (string-append "HOME=" home)
                      (string-append "PATH=" home "/.npm-global/bin:"
                                     home "/.local/bin:"
                                     home "/.guix-home/profile/bin:"
                                     home "/.nix-profile/bin:/run/current-system/profile/bin")
                      "DISABLE_AUTOUPDATER=1"))))
    (stop #~(make-kill-destructor)))))

(define home-claude-code-service-type
  (service-type (name 'home-claude-code)
                (description "A service for launching Claude Code with channels enabled.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-claude-code-shepherd-service)))
                (default-value #f)))
