(define-module (raynet-guix packages zellij-bin)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages bootstrap)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages cmake)
  #:use-module (gnu packages music)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages node)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages video)
  #:use-module (gnu packages wget)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (nonguix build-system binary)
  #:use-module (ice-9 match)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (zellij-bin))

(define-public zellij-bin
  (package
    (name "zellij-bin")
    (version "0.41.2")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/zellij-org/zellij/releases/download/v"
             version "/zellij-x86_64-unknown-linux-musl.tar.gz"))
       (file-name (string-append "zellij-" version ".tar.gz"))
       (sha256
        (base32 "0y3cpy20g984jrz8gnc6sqjskfwmfjngd617bksvm9fq2yl23hxi"))))
    (build-system binary-build-system)
    (arguments
     `(#:phases (modify-phases %standard-phases
                  (add-before 'patchelf 'patchelf-writable
                    (lambda _
                      (for-each make-file-writable
                                '("zellij")))))
       #:install-plan `(("zellij" "bin/"))))
    (supported-systems '("x86_64-linux"))
    (synopsis "A terminal workspace with batteries included")
    (description
     "Zellij is a workspace aimed at developers, ops-oriented people and anyone who loves the terminal. Similar programs are sometimes called Terminal Multiplexers.")
    (home-page "https://zellij.dev/")
    (license license:expat)))

zellij-bin
