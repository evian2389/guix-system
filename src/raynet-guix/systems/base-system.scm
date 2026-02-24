(define-module (raynet-guix systems base-system)
  #:export (base-operating-system)
  #:use-module (gnu system)
  #:use-module (gnu system keyboard)
  #:use-module (gnu system accounts)
  #:use-module (gnu system shadow)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices) ; Moved for potential order dependency
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services linux)
  #:use-module (gnu services audio)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (gnu services networking)
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
  #:use-module (gnu packages kde-plasma)
  #:use-module (gnu packages tex)
  #:use-module (gnu packages games)       ;; For steam-devices-udev-rules
  #:use-module (raynet-guix home-services games)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (nongnu packages linux)
  #:use-module (saayix packages terminals)         ; for ghostty
  #:use-module (raynet-guix users orka home))

(define (nonguix-substitute-service config)
  (guix-configuration
    (inherit config)
    (substitute-urls
     (append (list "https://substitutes.nonguix.org"
                   "https://nonguix-proxy.ditigal.xyz"
                   "https://berlin-guix.jing.rocks"
                   "https://bordeaux-guix.jing.rocks"
                   "https://mirrors.sjtug.sjtu.edu.cn/guix"
                   "https://mirrors.sjtug.sjtu.edu.cn/guix-bordeaux")
             %default-substitute-urls))
    (authorized-keys
     (append (list (plain-file "nonguix.pub"
                               "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))
                   %default-authorized-guix-keys))))

(define* (base-operating-system #:key hostname
                                 firmware
                                 bootloader
                                 ;;mapped-devices
                                 file-systems
                                 (kernel-arguments %default-kernel-arguments)
                                 swap-devices
                                 (packages %base-packages))
  (operating-system
    (host-name hostname)
    (timezone "Asia/Seoul")
    (locale "en_US.utf8")
    (kernel linux)
    (bootloader bootloader)
    ;;(mapped-devices mapped-devices)
    (file-systems file-systems)
    (swap-devices
     (let ((device->swap-space
            (lambda (device)
              (if (string? device)
                  (swap-space (target device))
                  device))))
       (map device->swap-space swap-devices)))
    (firmware firmware)
    (kernel-arguments kernel-arguments)
    (packages (append (list
                        btrfs-progs
                        fuse-exfat
                        exfat-utils
                        exfatprogs
                        lynis
                        btop
                        ncdu
                        gnupg
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
                        rfkill
                        bluedevil
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
             (service subids-service-type
                      (subids-configuration
                       (subuids (list (subid-range (name "orka") (start 100000) (count 65536))))
                       (subgids (list (subid-range (name "orka") (start 100000) (count 65536))))))
             (service guix-home-service-type
              `(("orka" ,orka-home-environment))) ;; Use the alist format
             (service bluetooth-service-type
                      (bluetooth-configuration
                       (auto-enable? #t))))
       (modify-services %desktop-services
         (guix-service-type config => (nonguix-substitute-service config)))))

    (keyboard-layout (keyboard-layout "kr"))
    (groups (cons* (user-group (name "render") (system? #t))
                   (user-group (name "nix-users") (system? #t))
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
               (supplementary-groups '("wheel" "netdev" "audio" "video" "render" "lp" "nix-users"))
               (password "$6$randomsalt$XNp4oTKzawAP8oMfu5HfpSLdBBJjQfGng8k8zfafP/13Z0WNgB4X7qe27uNMqPgx50rQ8h6e2MM7m5nrdwM1h0"))
              %base-user-accounts)))
  )
