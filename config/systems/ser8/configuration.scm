(define-module (config systems ser8 configuration)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu services)
  #:use-module (gnu services audio)     ; For PipeWire
  #:use-module (gnu services desktop)
  #:use-module (config home-services games)   ; For Steam support service
  #:use-module (gnu services udev)      ; For udev service type
  #:use-module (gnu services xorg)
  #:use-module (gnu system uuid)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)
  #:use-module (gnu home)
  #:use-module (config users orka home))

(operating-system
  (host-name "ser8")
  (timezone "Asia/Seoul")
  (locale "ko_KR.utf8")

  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (target "/boot/efi")))

  (mapped-devices
   (list (mapped-device
           (source (uuid "YOUR_LUKS_PARTITION_UUID_HERE"))
           (target "enc")
           (type luks-device-mapping))))

  (file-systems
   (cons*
    (file-system
      (device (file-system-label "guixroot")) ; Btrfs filesystem on the unlocked device
      (mount-point "/")
      (type "btrfs")
      (options "subvol=@,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/boot")
      (type "btrfs")
      (options "subvol=@boot,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/home")
      (type "btrfs")
      (options "subvol=@home,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/gnu")
      (type "btrfs")
      (options "subvol=@gnu,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/data")
      (type "btrfs")
      (options "subvol=@data,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/var")
      (type "btrfs")
      (options "subvol=@var,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/var/log")
      (type "btrfs")
      (options "subvol=@var_log,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/opt")
      (type "btrfs")
      (options "subvol=@opt,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (file-system-label "guixroot"))
      (mount-point "/swap")
      (type "btrfs")
      (options "subvol=@swap,compress=zstd,noatime,discard=async,space_cache=v2")
      (dependencies mapped-devices))
    (file-system
      (device (uuid "YOUR_EFI_PARTITION_UUID_HERE" 'fat32))
      (mount-point "/boot/efi")
      (type "vfat"))
    %base-file-systems))

  (swap-devices (list "/swap/swapfile"))

  (users (cons* (user-account
                  (name "orka")
                  (comment "Orka")
                  (group "users")
                  (home-directory "/home/orka")
                  (supplementary-groups '("wheel" "netdev" "audio" "video"))
                  ;; Replace the placeholder below with the hash generated from the guile command
                  (password "$6$mbu/ym8zacwsRcoV$Vyw7sVe8MP0Wf/e223Mcqn7Isuw1/QNpN078tpm5wNRGtD.hKvmAxvpYjvLHa3.NoyOJ06hsmjYrYim/GkSN90")
                  (email "evian2389@gmail.com"))
                %base-user-accounts))

  (packages
   (append
    (list
     ;; Add system-wide packages here
     )
    %base-packages))

  (services
   (cons*
    (service pipewire-service-type)      ; Explicitly set PipeWire as the audio server
    steam-support-service                 ; For Steam controller udev rules
    (service gnome-desktop-service-type)
    (service gdm-service-type) ; Display manager for GNOME
    (home-environment-service-type
     orka-home-environment)
    %base-services))

  (keyboard-layout (keyboard-layout "kr"))
  (operating-system-user-accounts %base-user-accounts))
