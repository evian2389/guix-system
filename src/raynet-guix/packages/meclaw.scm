(define-module (raynet-guix packages meclaw)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define-public meclaw
  (package
    (name "meclaw")
    (version "0.76.6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://github.com/mmeyerlein/meclaw/releases/download/v"
                           version "/meclaw-" version "-x86_64-unknown-linux-musl.tar.gz"))
       (sha256 (base32 "0izikrszyb5s1zqhx5494pxxjw4fb8fzbljnxk2kcdah5i5wfic1"))))
    (build-system copy-build-system)
    (arguments (list #:install-plan #~'(("meclaw" "bin/meclaw"))))
    (supported-systems '("x86_64-linux"))
    (home-page "https://meclaw.ai")
    (synopsis "Rust actor substrate for agentic workflows")
    (description "Pinned upstream static musl release.  Local colony and integration
configuration are managed separately by the Guix Home MeClaw service.")
    (license (list license:expat license:asl2.0))))
