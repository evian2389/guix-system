(define-module (raynet-guix home-services ollama)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services configuration)
  #:use-module (guix gexp)
  #:export (home-ollama-service-type))

(define (home-ollama-shepherd-service config)
  (list
   (shepherd-service
    (provision '(ollama))
    (documentation "Run Ollama server daemon.")
    (respawn? #t)
    (respawn-limit #~'(5 . 30))
    (auto-start? #t)
    (start #~(let* ((home (passwd:dir (getpwuid (getuid))))
                    (log-file (string-append home "/.local/state/ollama.log"))
                    (ollama-bin (string-append home "/.nix-profile/bin/ollama")))
               (mkdir-p (string-append home "/.local/state"))
               (make-forkexec-constructor
                (list ollama-bin "serve")
                #:directory home
                #:log-file log-file
                #:environment-variables
                (list (string-append "HOME=" home)
                      (string-append "PATH=" home "/.nix-profile/bin:"
                                     home "/.guix-home/profile/bin:/run/current-system/profile/bin")))))
    (stop #~(make-kill-destructor)))))

(define home-ollama-service-type
  (service-type (name 'home-ollama)
                (description "A service for launching Ollama server.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-ollama-shepherd-service)))
                (default-value #f)))
