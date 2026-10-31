(define-module (raynet-guix home-services microclaw)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu home services mcron)
  #:use-module (gnu packages python)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:export (home-microclaw-service-type
            home-microclaw-configuration))

(define-record-type* <home-microclaw-configuration>
  home-microclaw-configuration make-home-microclaw-configuration
  home-microclaw-configuration?
  (repository home-microclaw-configuration-repository
              (default "~/work/workflow-evolution")))

(define evolve-script
  (local-file "../users/orka/files/.local/bin/microclaw-evolve"))

(define pi-microclaw-script
  (local-file "../users/orka/files/.local/bin/pi-microclaw"))

;; Seed mutable state once; subsequent reconfigurations preserve evolved skills.
(define (home-microclaw-activation config)
  #~(begin
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$evolve-script "--repository"
                             #$(home-microclaw-configuration-repository config)
                             "wire"))
        (error "Clone the workflow-evolution repository before Guix Home activation"))
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$evolve-script "init"))
        (error "MicroClaw workflow initialization failed"))
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$evolve-script "share-skills"))
        (error "Shared skill wiring failed; check for conflicting consumer skills"))
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$evolve-script "secure-web"))
        (error "MicroClaw Web password initialization failed"))
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$evolve-script "snapshot"))
        (error "Evolution snapshot failed"))
      (unless (zero? (system* #$(file-append python "/bin/python3")
                             #$pi-microclaw-script "setup"))
        (error "Pi MicroClaw profile initialization failed"))))

(define (home-microclaw-jobs config)
  (list #~(job '(next-minute '(0 30))
               (lambda ()
                 (system* #$(file-append python "/bin/python3")
                          #$evolve-script "tick"))
               "microclaw-evolution")))

;; The release binary needs Guix's ELF loader wrapper from files/.local/bin.
(define (home-microclaw-shepherd-service config)
  (list
   (shepherd-service
    (provision '(microclaw))
    (documentation "Run the MicroClaw agent gateway.")
    (respawn? #t)
    (respawn-limit #~'(5 . 30))
    (auto-start? #t)
    (start #~(let* ((home (passwd:dir (getpwuid (getuid))))
                    (log-file (string-append home "/.local/state/microclaw.log"))
                    (microclaw-bin (string-append home "/.local/bin/microclaw"))
                    (ca-bundle "/run/current-system/profile/etc/ssl/certs/ca-certificates.crt"))
               (mkdir-p (string-append home "/.local/state"))
               (make-forkexec-constructor
                (list microclaw-bin "--config"
                      (string-append home "/.local/share/microclaw-workflow/gateway.json")
                      "start")
                #:directory home
                #:log-file log-file
                #:environment-variables
                (list (string-append "HOME=" home)
                      (string-append "PATH=" home "/.cargo/bin:"
                                     home "/.local/bin:"
                                     home "/.npm-global/bin:"
                                     home "/.nix-profile/bin:"
                                     home "/.guix-home/profile/bin:"
                                     home "/.guix-profile/bin:"
                                     "/run/current-system/profile/bin")
                      (string-append "SSL_CERT_FILE=" ca-bundle)
                      (string-append "SSL_CERT_DIR=" "/run/current-system/profile/etc/ssl/certs")
                      (string-append "CURL_CA_BUNDLE=" ca-bundle)
                      (string-append "GIT_SSL_CAINFO=" ca-bundle)))))
    (stop #~(make-kill-destructor)))))

(define home-microclaw-service-type
  (service-type (name 'home-microclaw)
                (description "A service for launching the MicroClaw agent gateway.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-microclaw-shepherd-service)
                       (service-extension home-activation-service-type
                                          home-microclaw-activation)
                       (service-extension home-mcron-service-type
                                          home-microclaw-jobs)))
                (default-value (home-microclaw-configuration))))
