(define-module (raynet-guix packages moltis)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (nonguix build-system binary)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (moltis))

;; Moltis: self-hosted persistent personal agent server (Rust). Repackages the
;; upstream glibc release tarball (SPIKE, evaluated against MeClaw; see
;; doc/ai-workflow/MOLTIS-SPIKE.md). Not built from source: ~270K LoC, 59 crates.
(define-public moltis
  (package
    (name "moltis")
    (version "20261023.01")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/moltis-org/moltis/releases/download/" version
             "/moltis-" version "-x86_64-unknown-linux-gnu.tar.gz"))
       (sha256
        (base32 "096w228rqc76ra57p0adqpsd76s32qdrsfz5mcnv5pfr8s3dsf4h"))))
    (build-system binary-build-system)
    (arguments
     `(#:strip-binaries? #f
       #:validate-runpath? #f
       #:patchelf-plan '(("moltis" ("zlib" "gcc:lib" "glibc")))
       #:install-plan '(("moltis" "bin/")
                        ("share/moltis" "share/"))
       #:phases (modify-phases %standard-phases
                  ;; The tarball has `moltis` and `share/` at its top level; the
                  ;; default unpack would chdir into `share/` (the only directory).
                  (replace 'unpack
                    (lambda* (#:key source #:allow-other-keys)
                      (invoke "tar" "xzf" source)))
                  (add-before 'patchelf 'patchelf-writable
                    (lambda _
                      (for-each make-file-writable '("moltis")))))))
    (inputs
     `(("zlib" ,zlib)
       ("gcc:lib" ,gcc "lib")
       ("glibc" ,glibc)))
    (supported-systems '("x86_64-linux"))
    (home-page "https://www.moltis.org/")
    (synopsis "Secure persistent personal agent server")
    (description "Moltis is a self-hosted personal AI agent server written in
Rust, with long-term memory, messaging channels (Matrix, Telegram, ...), MCP
and ACP support.  This package repackages the upstream binary release.")
    (license license:expat)))
