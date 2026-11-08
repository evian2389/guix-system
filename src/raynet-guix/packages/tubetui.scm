(define-module (raynet-guix packages tubetui)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages base)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (nonguix build-system binary)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (tubetui))

;; Repackage the upstream Linux release and patch its ELF runtime paths for Guix.
(define-public tubetui
  (package
    (name "tubetui")
    (version "0.8.8")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/polblancoo/tubetui/releases/download/v"
             version "/tubetui-x86_64-linux.tar.gz"))
       (sha256
        (base32 "1kiizbwjzk2wv302dkfkvr6fakf4djw97q133wyfpfdkp0ylpxw0"))))
    (build-system binary-build-system)
    (arguments
     `(#:strip-binaries? #f
       #:validate-runpath? #f
       #:patchelf-plan '(("tubetui" ("gcc:lib" "glibc")))
       #:install-plan '(("tubetui" "bin/tubetui"))))
    (inputs
     `(("gcc:lib" ,gcc "lib")
       ("glibc" ,glibc)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://polblancoo.github.io/tubetui/")
    (synopsis "YouTube and local media terminal user interface")
    (description
     "TubeTUI is a terminal interface for browsing YouTube and local media,
with playback through mpv and video extraction through yt-dlp.")
    (license license:agpl3)))
