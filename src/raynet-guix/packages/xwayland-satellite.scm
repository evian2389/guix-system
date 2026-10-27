(define-module (raynet-guix packages xwayland-satellite)
  #:use-module (gnu packages xorg)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:export (xwayland-satellite-0.8.3))

(define-public xwayland-satellite-0.8.3
  (package
    (inherit xwayland-satellite)
    (version "0.8.3")
    (source
     (origin
       (method url-fetch)
       (uri "https://github.com/Supreeeme/xwayland-satellite/archive/refs/tags/v0.8.3.tar.gz")
       (file-name "xwayland-satellite-0.8.3.tar.gz")
       (sha256
        (base32 "0y649waryw6vjyjgm3rfknw7c0bxq51zng7skv7460blglyqfclb"))))
    (inputs
     (modify-inputs (package-inputs xwayland-satellite)
       (append (@@ (gnu packages rust-crates) rust-syslog-7.0.0)
               (@@ (gnu packages rust-crates) rust-hostname-0.4.2))))))
