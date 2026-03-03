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
    (start #~(make-forkexec-constructor
              (list (string-append (getenv "HOME") "/.npm-global/bin/openclaw")
                    "gateway" "run")
              #:environment-variables
              (list (string-append "PATH=" (getenv "HOME") "/.npm-global/bin:" (getenv "PATH")))))
    (stop #~(make-kill-destructor)))))

(define home-openclaw-service-type
  (service-type (name 'home-openclaw)
                (description "A service for launching OpenClaw.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-openclaw-shepherd-service)))
                (default-value #f)))
