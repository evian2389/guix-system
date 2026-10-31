(define-module (raynet-guix home-services meclaw)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages python)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (raynet-guix packages meclaw)
  #:export (home-meclaw-service-type home-meclaw-configuration))

(define-record-type* <home-meclaw-configuration>
  home-meclaw-configuration make-home-meclaw-configuration
  home-meclaw-configuration?
  (repository home-meclaw-configuration-repository (default "~/work/workflow-evolution"))
  (telegram? home-meclaw-configuration-telegram? (default #t)))

(define integration-script
  (local-file "../users/orka/files/.local/bin/meclaw-workflow"))

(define (activation config)
  #~(unless (zero? (system* #$(file-append python "/bin/python3") #$integration-script
                           "setup" "--repository" #$(home-meclaw-configuration-repository config)))
      (error "MeClaw state wiring failed; clone workflow-evolution first")))

(define (services config)
  (list
   (shepherd-service
    (provision '(meclaw))
    (documentation "MeClaw coordinator, authenticated local bridge and Telegram.")
    (requirement '())
    (start #~(let* ((home (getenv "HOME"))
                   (ca "/run/current-system/profile/etc/ssl/certs/ca-certificates.crt"))
               (make-forkexec-constructor
                (append (list #$(file-append python "/bin/python3") #$integration-script
                              "serve" "--binary" #$(file-append meclaw "/bin/meclaw"))
                        '#$(if (home-meclaw-configuration-telegram? config) '("--telegram") '()))
                #:directory home
                #:log-file (string-append home "/.local/state/meclaw.log")
                #:environment-variables
                (list (string-append "HOME=" home)
                      (string-append "PATH=" #$(file-append python "/bin") ":" home "/.local/bin:"
                                     home "/.cargo/bin:" home "/.npm-global/bin:" home "/.nix-profile/bin:"
                                     home "/.guix-home/profile/bin:/run/current-system/profile/bin")
                      (string-append "SSL_CERT_FILE=" ca)
                      (string-append "SSL_CERT_DIR=" "/run/current-system/profile/etc/ssl/certs")
                      (string-append "CURL_CA_BUNDLE=" ca)))))
    (stop #~(make-kill-destructor)))))

(define home-meclaw-service-type
  (service-type
   (name 'home-meclaw)
   (description "A small MeClaw colony with shared evolution evidence and Codex integration.")
   (extensions
    (list (service-extension home-profile-service-type (const (list meclaw)))
          (service-extension home-activation-service-type activation)
          (service-extension home-shepherd-service-type services)))
   (default-value (home-meclaw-configuration))))
