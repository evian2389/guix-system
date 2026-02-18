(define-module (raynet-guix systems ser8 configuration)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu system uuid)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)
  #:use-module (gnu system accounts)
  #:use-module (gnu packages linux) ;; <--- Add this for bluez
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages video)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages gnome)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages firmware)
  #:use-module (srfi srfi-1)                 ;; For 'filter'
  #:use-module (ice-9 match)                 ;; For 'match-lambda'
  #:use-module (ice-9 format)                ;; For 'format'
  #:use-module (raynet-guix systems base-system))

;; This is the machine-specific configuration for 'ser8'.
;; It inherits all the common settings from 'base-system.scm' and just
;; provides the details unique to this hardware.
;(define ser8-mapped-devices
;  (list (mapped-device
;         (source (uuid "672ede9b-bded-4f19-9f89-b758927e975f"))
;         (target "enc")
;         (type luks-device-mapping))))

(define btrfs-subvolumes
  (map (match-lambda
         ((subvol . mount-point)
          (file-system
            (device (file-system-label "guixroot"))
            (mount-point mount-point)
            (type "btrfs")
            (flags '(no-atime))
            (options
              (if (string=? subvol "@swap")
                  "subvol=@swap,nodatacow,compress=none"
                  (format #f "subvol=~a,compress=zstd,discard=async,space_cache=v2" subvol))))))
       '(("@" . "/")
         ("@boot" . "/boot")
         ("@home" . "/home")
         ("@gnu"  . "/gnu")
         ("@data" . "/data")
         ("@var"  . "/var")
         ("@var-log" . "/var/log")
         ("@opt"  . "/opt")
         ("@swap" . "/swap"))))

(define data-fs
  (car
   (filter
    (lambda (x) (equal? (file-system-mount-point x) "/data"))
    btrfs-subvolumes)))

(define boot-fs
  (car
   (filter
    (lambda (x) (equal? (file-system-mount-point x) "/boot"))
    btrfs-subvolumes)))

(define ser8-file-systems
  (append
   btrfs-subvolumes
   (list
    ;; persist all system data to data
    (file-system
      (mount-point "/boot/efi")
      (type "vfat")
      (device (uuid "57EE-1710" 'fat32))
      (dependencies (list boot-fs))) ;; TODO check UUIDs
    (file-system
                (mount-point "/tmp")
                (device "none")
                (type "tmpfs")
                (flags '(no-dev no-suid no-atime))
                (check? #f)))
      )) ;; Add %base-file-systems to the end

(base-operating-system
 #:hostname "ser8"

;; This safely adds your subvolume flag to the Guix defaults
 #:kernel-arguments
 (append '("rootflags=subvol=@") %default-kernel-arguments)

 #:bootloader
 (bootloader-configuration
   (bootloader grub-efi-bootloader)
   (targets '("/boot/efi")))

 #:firmware
 (list linux-firmware amdgpu-firmware)

 ;;#:mapped-devices ser8-mapped-devices

 #:file-systems ser8-file-systems

 #:swap-devices (list "/swap/swapfile")

 #:packages (append (list bluez
                           brightnessctl
                           exfatprogs
                           git
                           gvfs    ;; Enable user mounts
                           libva-utils
                           ntfs-3g
                           stow
                           vim)
                       %base-packages))
