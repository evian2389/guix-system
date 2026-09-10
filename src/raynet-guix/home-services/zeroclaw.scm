(define-module (raynet-guix home-services zeroclaw)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu services configuration)
  #:use-module (guix gexp)
  #:export (home-zeroclaw-service-type))

;; Runs `zeroclaw daemon` (gateway + channels + heartbeat + cron scheduler) as a
;; Guix Home shepherd service so the Telegram bot answers 24/7.
;;
;; This is unrelated to herdr: herdr 0.8.2 has no `zeroclaw` agent kind, so
;; zeroclaw cannot be tracked as a herdr agent. herdr users just run
;; `zeroclaw agent` in a plain pane.
;;
;; The binary is the cargo install at ~/.cargo/bin/zeroclaw (see
;; users/orka/non-guix-packages.sh). Config is rendered to ~/.zeroclaw/config.toml
;; by users/orka/zeroclaw/render-config.sh; OAuth lives in
;; ~/.zeroclaw/auth-profiles.json (encrypted, not in git) — refresh out of band
;; with `zeroclaw auth refresh`.
(define (home-zeroclaw-shepherd-service config)
  (list
   (shepherd-service
    (provision '(zeroclaw))
    (documentation "Run the ZeroClaw daemon (gateway + channels + scheduler).")
    (respawn? #t)
    (respawn-limit #~'(5 . 30))
    (auto-start? #t)
    (start #~(let* ((home (passwd:dir (getpwuid (getuid))))
                    (log-file (string-append home "/.local/state/zeroclaw-daemon.log"))
                    (zeroclaw-bin (string-append home "/.cargo/bin/zeroclaw"))
                    (ca-bundle "/run/current-system/profile/etc/ssl/certs/ca-certificates.crt"))
               (mkdir-p (string-append home "/.local/state"))
               (make-forkexec-constructor
                (list zeroclaw-bin "daemon")
                #:directory home
                #:log-file log-file
                #:environment-variables
                (list (string-append "HOME=" home)
                      (string-append "PATH=" home "/.cargo/bin:"
                                     home "/.local/bin:"
                                     home "/.npm-global/bin:"
                                     home "/.nix-profile/bin:"
                                     home "/.guix-home/profile/bin:"
                                     "/run/current-system/profile/bin")
                      (string-append "SSL_CERT_FILE=" ca-bundle)
                      (string-append "SSL_CERT_DIR=" "/run/current-system/profile/etc/ssl/certs")
                      (string-append "CURL_CA_BUNDLE=" ca-bundle)
                      (string-append "GIT_SSL_CAINFO=" ca-bundle)))))
    (stop #~(make-kill-destructor)))))

(define home-zeroclaw-service-type
  (service-type (name 'home-zeroclaw)
                (description "A service for launching the ZeroClaw daemon.")
                (extensions
                 (list (service-extension
                        home-shepherd-service-type
                        home-zeroclaw-shepherd-service)))
                (default-value #f)))
