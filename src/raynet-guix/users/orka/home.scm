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
;; sirup: pre-authenticated Gmail IMAP/SMTP sessions on Unix sockets
    ;; ($XDG_RUNTIME_DIR/sirup/gmail-{imap,smtp}.sock, tmpfs) for himalaya / himalaya.nvim.
    ;; Auto-started at login: starting reads the OAuth token (ortie -> pass -> gpg),
    ;; which shows the GUI pinentry. The graphical session may not be ready yet at
    ;; that moment, so failures are retried (a few times, then it gives up);
    ;; restart manually with `herd restart sirup`.
    ;; shepherd has no DISPLAY/WAYLAND_DISPLAY, so pass them for the GUI pinentry.
    (simple-service 'sirup-service
                    home-shepherd-service-type
                    (list (shepherd-service
                           (provision '(sirup))
                           (documentation "sirup: Gmail IMAP/SMTP sessions on Unix sockets for himalaya.")
                           (respawn? #t)
                           (respawn-limit #~'(5 . 300))
                           (auto-start? #t)
                           (start #~(let* ((home (getenv "HOME"))
                                           (runtime (or (getenv "XDG_RUNTIME_DIR") "/run/user/1000"))
                                           (ca "/run/current-system/profile/etc/ssl/certs/ca-certificates.crt"))
                                      ;; a killed sirup leaves its socket files behind
                                      (for-each (lambda (f)
                                                  (when (file-exists? f) (delete-file f)))
                                                (list (string-append runtime "/sirup/gmail-imap.sock")
                                                      (string-append runtime "/sirup/gmail-smtp.sock")))
                                      (make-forkexec-constructor
                                       ;; wait (up to ~2 min) for the Wayland socket, so the GUI
                                       ;; pinentry can show up when started right at login
                                       (list "/run/current-system/profile/bin/bash" "-c"
                                             (string-append
                                              "for i in $(seq 60); do [ -S \"$XDG_RUNTIME_DIR/wayland-1\" ] && break; sleep 2; done; "
                                              "exec " home "/.cargo/bin/sirup start --account gmail"))
                                       #:directory home
                                       #:log-file (string-append home "/.local/state/sirup.log")
                                       #:environment-variables
                                       (list (string-append "HOME=" home)
                                             (string-append "XDG_RUNTIME_DIR=" runtime)
                                             (string-append "GNUPGHOME=" home "/.gnupg")
                                             (string-append "DBUS_SESSION_BUS_ADDRESS=unix:path=" runtime "/bus")
                                             "DISPLAY=:0"
                                             "WAYLAND_DISPLAY=wayland-1"
                                             (string-append "PATH=" home "/.cargo/bin:" home "/.local/bin:"
                                                            home "/.guix-home/profile/bin:"
                                                            "/run/current-system/profile/bin")
                                             (string-append "SSL_CERT_FILE=" ca)
                                             (string-append "SSL_CERT_DIR=/run/current-system/profile/etc/ssl/certs")))))
                           (stop #~(make-kill-destructor)))))
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
;; fontdb-based GUI apps (herdr-gpui) only scan ~/.local/share/fonts, ~/.fonts and
    ;; the <dir>s of the fonts.conf named by FONTCONFIG_FILE (DejaVu) -- not the Guix
    ;; profile's share/fonts -- so they report "Configured fonts not installed".
    ;; Verified via /proc/<pid>/maps: only DejaVu and ~/.local/share/fonts/* are loaded.
    ;; Copy the few needed files there (a copy: fontdb's symlink handling is
    ;; unverified, and ~/.local/share/fonts/guix-cjk already uses real files).
    (simple-service 'gui-app-fonts
                    home-activation-service-type
                    #~(begin
                        (let ((dir (string-append (getenv "HOME") "/.local/share/fonts/guix-nerd")))
                          (unless (file-exists? dir)
                            (mkdir dir))
                          (for-each
                           (lambda (src+files)
                             (for-each
                              (lambda (f)
                                (let ((dst (string-append dir "/" f)))
                                  (when (file-exists? dst) (delete-file dst))
                                  (copy-file (string-append (car src+files) "/" f) dst)
                                  (chmod dst #o644)))
                              (cdr src+files)))
                           (list
                            (cons #$(file-append (@ (gnu packages fonts) font-nerd-symbols)
                                                 "/share/fonts/truetype")
                                  '("SymbolsNerdFontMono-Regular.ttf" "SymbolsNerdFont-Regular.ttf"))
                            (cons #$(file-append (@ (raynet-guix packages fonts) font-jetbrains-mono-hangul-nerd-font-mono)
                                                 "/share/fonts/truetype")
                                  '("JetBrainsMonoHangulNerdFontMono-Regular.ttf"
                                    "JetBrainsMonoHangulNerdFontMono-Bold.ttf"
                                    "JetBrainsMonoHangulNerdFontMono-Italic.ttf"
                                    "JetBrainsMonoHangulNerdFontMono-BoldItalic.ttf")))))))
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
