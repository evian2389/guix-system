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
    (auto-start? #t)
    (start #~(let ((home (passwd:dir (getpwuid (getuid)))))
               (make-forkexec-constructor
                (list (string-append home "/.local/bin/claude-code.sh")
                      "--channels" "plugin:discord@claude-plugins-official")
                #:directory home)))
    (stop #~(make-kill-destructor)))))

(define home-claude-code-service-type
  (service-type (name 'home-claude-code)
                (description "A service for launching Claude Code with channels enabled.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-claude-code-shepherd-service)))
                (default-value #f)))
