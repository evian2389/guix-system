(define-module (raynet-guix systems base-system)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services audio)
  #:use-module (gnu services desktop)
  #:use-module (gnu services ssh)            ;; For openssh-service-type
  #:use-module (gnu services guix)           ;; For guix-service-type
  #:use-module (gnu system extensions)       ;; For guix-extension
  #:use-module (guix store)                  ;; For plain-file
  #:use-module (nongnu packages games)       ;; For steam-devices-udev-rules
  #:use-module (raynet-guix home-services games)
  #:use-module (gnu home)
  #:use-module (raynet-guix users orka home))

(define* (base-operating-system #:key hostname
                                     firmware
                                     bootloader
                                     mapped-devices
                                     file-systems
                                     swap-devices
                                     #:packages (packages %base-packages))
                                       (operating-system
                                         (host-name hostname)
                                         (timezone "Asia/Seoul")
                                         (locale "ko_KR.utf8")
                                         (kernel linux)
                                         (bootloader bootloader)
                                         (mapped-devices mapped-devices)
                                         (file-systems file-systems)
                                         (swap-devices swap-devices)
                                         (firmware firmware)
                                         (packages packages)
    (services
     (append (list
      ;; Configure the Guix service and ensure we use Nonguix substitutes
      (simple-service 'add-nonguix-substitutes
                      guix-service-type
                      (guix-extension
                       (substitute-urls
                        (cons* "https://substitutes.nonguix.org"
                               "https://nonguix-proxy.ditigal.xyz"
                               %default-substitute-urls))
                       (authorized-keys
                        (append (list (plain-file "nonguix.pub"
                                                  "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))
                                %default-authorized-guix-keys))))
      ;; Add Guix substitutes from Asia
      (simple-service 'add-guix-asia-substitutes
                      guix-service-type
                      (guix-extension
                       (substitute-urls
                        (cons* "https://berlin-guix.jing.rocks"
                               "https://bordeaux-guix.jing.rocks"
                               "https://mirrors.sjtug.sjtu.edu.cn/guix"
                               "https://mirrors.sjtug.sjtu.edu.cn/guix-bordeaux"
                               %default-substitute-urls))))
      (service openssh-service-type)      ;; Enable OpenSSH server
      (service pipewire-service-type)
      ;; Add udev rules for Steam devices
      (udev-rules-service 'steam-devices steam-devices-udev-rules)
      (service gnome-desktop-service-type)
      (service gdm-service-type)
      (home-environment-service-type
       orka-home-environment))
      %base-services))

    (keyboard-layout (keyboard-layout "kr"))
    (operating-system-user-accounts
     (cons* (user-account
             (name "orka")
             (comment "Orka")
             (group "users")
             (home-directory "/home/orka")
             (supplementary-groups '("wheel" "netdev" "audio" "video"))
             (password "$6$randomsalt$XNp4oTKzawAP8oMfu5HfpSLdBBJjQfGng8k8zfafP/13Z0WNgB4X7qe27uNMqPgx50rQ8h6e2MM7m5nrdwM1h0")
             (email "evian2389@gmail.com"))
            %base-user-accounts))))
