(define-module (raynet-guix home-services openclaw)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services configuration)
  #:use-module (guix gexp)
  #:export (home-openclaw-service-type))

(define (home-openclaw-shepherd-service config)
  (list
   (shepherd-service
    (provision '(openclaw))
    (documentation "Run the OpenClaw gateway.")
    (respawn? #t)
    (auto-start? #t)
    (start #~(let ((home (passwd:dir (getpwuid (getuid)))))
               (make-forkexec-constructor
                (list (string-append home "/.local/bin/openclaw.sh")
                      "gateway" "run")
                #:directory home)))
    (stop #~(make-kill-destructor)))))

(define home-openclaw-service-type
  (service-type (name 'home-openclaw)
                (description "A service for launching OpenClaw gateway.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-openclaw-shepherd-service)))
                (default-value #f)))
