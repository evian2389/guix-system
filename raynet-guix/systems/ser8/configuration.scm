(define-module (raynet-guix systems ser8 configuration)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu system uuid)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages firmware)
  #:use-module (srfi srfi-1)                 ;; For 'filter'
  #:use-module (ice-9 match)                 ;; For 'match-lambda'
  #:use-module (ice-9 format)                ;; For 'format'
  #:use-module (raynet-guix systems base-system))

;; This is the machine-specific configuration for 'ser8'.
;; It inherits all the common settings from 'base-system.scm' and just
;; provides the details unique to this hardware.
(define btrfs-subvolumes
  (map (match-lambda
         ((subvol . mount-point)
          (file-system
            (device (file-system-label "guixroot"))
            (mount-point mount-point)
            (type "btrfs")
            (options (format #f "subvol=~a,compress=zstd,noatime,discard=async,space_cache=v2" subvol))
            (dependencies mapped-devices))))
       '(("@" . "/")
         ("@boot" . "/boot")
         ("@home" . "/home")
         ("@gnu"  . "/gnu")
         ("@data" . "/data")
         ("@var"  . "/var")
         ("@var_log" . "/var/log")
         ("@opt"  . "/opt")
         ("@swap" . "/swap"))))

(define data-fs
  (car
   (filter
    (lambda (x) (equal? (file-system-mount-point x) "/data"))
    btrfs-subvolumes)))

(define ser8-file-systems
  (append
   btrfs-subvolumes
   (list
    ;; persist all system data to data
    (file-system
      (device "/data/system/var/lib")
      (type "none")
      (mount-point "/var/lib")
      (flags '(bind-mount))
      ;; (options "bind")
      (dependencies (list data-fs)))
    (file-system
      (mount-point "/boot/efi")
      (type "vfat")
      (device (uuid "YOUR_EFI_PARTITION_UUID_HERE" 'fat32))) ;;TODO check UUIDs
    (file-system
                (mount-point "/tmp")
                (device "none")
                (type "tmpfs")
                (flags '(no-dev no-suid no-atime))
                (check? #f))
      %base-file-systems))) ;; Add %base-file-systems to the end

(base-operating-system
 #:hostname "ser8"

 #:bootloader
 (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (target "/boot/efi"))

 #:firmware
 (list linux-firmware amd-firmware)

 #:mapped-devices
 (list (mapped-device
         (source (uuid "YOUR_LUKS_PARTITION_UUID_HERE"))
         (target "enc")
         (type luks-device-mapping)))

 #:file-systems ser8-file-systems

 #:swap-devices (list "/swap/swapfile")

 #:packages (append (list bluez
                           bluez-alsa
                           brightnessctl
                           exfat-utils
                           fuse-exfat
                           git
                           gvfs    ;; Enable user mounts
                           intel-media-driver/nonfree
                           libva-utils
                           ntfs-3g
                           stow
                           vim)
                       %base-packages))
