(define-module (raynet-guix systems base-system)
  #:export (base-operating-system)
  #:use-module (gnu system)
  #:use-module (gnu system locale)
  #:use-module (gnu system keyboard)
  #:use-module (gnu system accounts)
  #:use-module (gnu system shadow)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices) ; Moved for potential order dependency
  #:use-module (gnu system nss)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services linux)
  #:use-module (gnu services audio)
  #:use-module (gnu services sound)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (gnu services networking)
  #:use-module (gnu services cups)
  #:use-module (gnu services dbus)
  #:use-module (gnu services nix)
  #:use-module (gnu services ssh)            ;; For openssh-service-type
  #:use-module (gnu services guix)           ;; For guix-service-type
  #:use-module (guix gexp)                  ;; For plain-file
  #:use-module (guix store)
  #:use-module (gnu packages base)           ;; For libc/nscd
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages admin)           ;; lynis
  #:use-module (gnu packages gnupg)           ;; For libc/nscd
  #:use-module (gnu packages shells)         ;; For zsh
  #:use-module (gnu packages linux)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages ncdu)           ;;ncdu
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages kde-plasma)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages tex)
  #:use-module (gnu packages cups)        ;; For splix
  #:use-module (gnu packages scanner)     ;; For sane-airscan
  #:use-module (gnu packages games)       ;; For steam-devices-udev-rules
  #:use-module (gnu packages android)     ;; For android-udev-rules
  #:use-module (raynet-guix home-services games)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (nongnu packages linux)
  #:use-module (abbe packages ghostty)
  #:use-module (srfi srfi-1)                 ;; fold, filter
  #:use-module (srfi srfi-13))               ;; string-prefix?

(define (nonguix-substitute-service config)
  (guix-configuration
    (inherit config)
    ;; /tmp is a ~14 GiB tmpfs (50% of RAM); a from-source kernel build
    ;; overflows it ("No space left on device" linking vmlinux).  Send
    ;; guix-daemon builds to the disk-backed btrfs instead.  /var/tmp always
    ;; exists, so no activation-time mkdir is required.
    (tmpdir "/var/tmp")
    (substitute-urls
     (append (list "https://nonguix-proxy.ditigal.xyz"
                   "https://mirrors.sjtug.sjtu.edu.cn/guix"
                   "https://mirrors.sjtug.sjtu.edu.cn/guix-bordeaux")
             %default-substitute-urls))
    (authorized-keys
     (append (list (plain-file "nonguix.pub"
                               "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))
                   %default-authorized-guix-keys))))

(define my-bluetooth-service-type
  (service-type
   (inherit bluetooth-service-type)
   (extensions
    (map (lambda (extension)
           (if (eq? (service-extension-target extension) etc-service-type)
               (service-extension etc-service-type
                                  (lambda (config)
                                    `(("bluetooth"
                                       ,(computed-file "etc-bluetooth"
                                                       #~(begin
                                                           (mkdir #$output)
                                                           (chdir #$output)
                                                           (call-with-output-file "main.conf"
                                                             (lambda (port)
                                                               (display #$((@@ (gnu services desktop) bluetooth-configuration-file) config)
                                                                        port)))
                                                           (call-with-output-file "input.conf"
                                                             (lambda (port)
                                                               (display "[General]\nClassicBondedOnly=false\nUserspaceHID=false\n"
                                                                        port)))))))))
               extension))
         (service-type-extensions bluetooth-service-type)))))

(define* (base-operating-system #:key hostname
                                 firmware
                                 bootloader
                                 ;;mapped-devices
                                 file-systems
                                 (kernel-arguments %default-kernel-arguments)
                                 swap-devices
                                 (packages %base-packages)
                                 (locale "en_US.utf8")
                                 (locale-definitions (list (locale-definition (name "en_US.utf8") (source "en_US"))
                                                           (locale-definition (name "ko_KR.utf8") (source "ko_KR"))))
                                 (home-environment #f))
  (operating-system
    (host-name hostname)
    (timezone "Asia/Seoul")
    (locale locale)
    (locale-definitions locale-definitions)
    (name-service-switch %mdns-host-lookup-nss)
    (kernel linux)
    (bootloader bootloader)
    ;;(mapped-devices mapped-devices)
    (file-systems file-systems)
    (swap-devices
     ;; For a swap *file*, make its shepherd service depend on the file system
     ;; that holds it — otherwise Guix only adds a udev dependency and `swapon`
     ;; runs before the subvolume is mounted, failing the service at boot.
     (let* ((holding-fs
             (lambda (path)
               (fold (lambda (fs best)
                       (let ((mp (file-system-mount-point fs)))
                         (if (and (string-prefix? mp path)
                                  (or (not best)
                                      (> (string-length mp)
                                         (string-length
                                          (file-system-mount-point best)))))
                             fs best)))
                     #f file-systems)))
            (device->swap-space
             (lambda (device)
               (if (string? device)
                   (let ((fs (holding-fs device)))
                     (swap-space (target device)
                                 (dependencies (if fs (list fs) '()))))
                   device))))
       (map device->swap-space swap-devices)))
    (firmware firmware)
    (kernel-arguments kernel-arguments)
    ;; Allow orka to run `guix` as root without a password, so unattended
    ;; `guix system reconfigure` (deploy.sh / the mcron one-shot) doesn't stall
    ;; on a sudo prompt. SETENV: is needed because the Makefile prefixes
    ;; GUILE_LOAD_PATH=... before the command.
    (sudoers-file
     (plain-file "sudoers"
                 (string-append
                  "root ALL=(ALL) ALL\n"
                  "%wheel ALL=(ALL) ALL\n"
                  "orka ALL=(root) NOPASSWD:SETENV: "
                  "/run/current-system/profile/bin/guix, "
                  "/home/orka/.config/guix/current/bin/guix, "
                  "/home/orka/guix-system/env/profile/bin/guix\n")))
    (packages (append (list
                        btrfs-progs
                        fuse-exfat
                        exfat-utils
                        exfatprogs
                        lynis
                        btop
                        ncdu
                        gnupg
                        pinentry
                        gpgme
                        font-jetbrains-mono
                        font-gnu-unifont
                        font-dejavu
                        font-liberation
                        font-gnu-freefont
                        font-un
                        texlive-baekmuk
                        zsh
                        alacritty
                        ghostty
                        (@ (gnu packages window-management) niri)
                        greetd
                        tuigreet
                        util-linux
                        bluedevil
                        (@ (gnu packages window-management) hypridle)
                        simple-scan
                        (@ (gnu packages dns) nss-mdns)
                        (@ (gnu packages dns) avahi)
                        print-manager
                        cups
                        )
                  packages))

    (services
      (append
       (list
             (service openssh-service-type)      ;; Enable OpenSSH server
             (service nix-service-type)      ;; Nix
             (service plasma-desktop-service-type)
             ;; Add udev rules for Steam devices
             (udev-rules-service 'steam-devices steam-devices-udev-rules)
             ;; Add udev rules for Android devices
             (udev-rules-service 'android-udev android-udev-rules)
             (udev-rules-service 'disable-intel-bluetooth
                                 (udev-rule "99-disable-intel-bluetooth.rules"
                                            "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"8087\", ATTR{idProduct}==\"0029\", ATTR{authorized}=\"0\"\n"))
             (service subids-service-type
                      (subids-configuration
                       (subuids (list (subid-range (name "orka") (start 100000) (count 65536))))
                       (subgids (list (subid-range (name "orka") (start 100000) (count 65536))))))
             (service my-bluetooth-service-type
                      (bluetooth-configuration
                       (auto-enable? #t)))
             (service cups-service-type
                      (cups-configuration
                       (web-interface? #t)
                       (extensions (list cups-filters splix foo2zjs hplip-minimal))))
             (service sane-service-type
                      (sane-configuration
                       (backends (list sane-airscan))))
             (service gnome-keyring-service-type
                      (gnome-keyring-configuration
                       (pam-services
                        '(("passwd" . passwd)
                          ("sddm" . login)
                          ("greetd" . login)
                          ("gdm-password" . login)
                          ("gdm-autologin" . login)
                          ("login" . login)))))
             ;; tuigreet (Rust TUI greeter) on greetd, launching niri by default.
             (service greetd-service-type
                      (greetd-configuration
                       (greeter-supplementary-groups '("video" "input"))
                       (terminals
                        (list (greetd-terminal-configuration
                               (terminal-vt "7")
                               (terminal-switch #t)
                               (default-session-command
                                 (program-file
                                  "tuigreet-niri"
                                  #~(execl #$(file-append tuigreet "/bin/tuigreet")
                                           "tuigreet"
                                           "--time"
                                           "--remember"
                                           "--remember-user-session"
                                           "--asterisks"
                                           "--sessions"
                                           "/run/current-system/profile/share/wayland-sessions"
                                           "--xsessions"
                                           "/run/current-system/profile/share/xsessions"
                                           "--cmd" "niri --session")))))))))
       (if home-environment
           (list (service guix-home-service-type
                          `(("orka" ,home-environment))))
           '())
       (modify-services %desktop-services
         (delete pulseaudio-service-type)
         ;; Replace GDM with greetd + tuigreet (configured above).
         (delete gdm-service-type)
         (guix-service-type config => (nonguix-substitute-service config)))))

    (keyboard-layout (keyboard-layout "kr"))
    (groups (cons* (user-group (name "render") (system? #t))
                   (user-group (name "nix-users") (system? #t))
                   (user-group (name "adbusers") (system? #t))
                   %base-groups))
    (users
      (cons* (user-account
               (name "orka")
               (comment "Orka")
               (group "users")
               (home-directory "/home/orka")
               (shell (file-append zsh "/bin/zsh")) ;; Set zsh as default login shell
               ;; User Groups: Your user account must be part of the video and lp
               ;; (sometimes required for specific compute tasks) groups to have
               ;; permission to access the /dev/dri/ device files.
               (supplementary-groups '("wheel" "netdev" "audio" "video" "render" "lp" "scanner" "nix-users" "adbusers"))
               (password "$6$randomsalt$XNp4oTKzawAP8oMfu5HfpSLdBBJjQfGng8k8zfafP/13Z0WNgB4X7qe27uNMqPgx50rQ8h6e2MM7m5nrdwM1h0"))
              %base-user-accounts)))
  )
