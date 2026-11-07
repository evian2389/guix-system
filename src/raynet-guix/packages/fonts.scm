(define-module (raynet-guix packages fonts)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix build-system font)
  #:use-module ((guix licenses) #:prefix license:))

(define-public font-jost
  (package
    (name "font-jost")
    (version "3.5")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/indestructible-type/Jost"
                    "/releases/download/" version "/Jost.zip"))
              (sha256
               (base32
                "1nb92imnk1g7c5nyra2q3k298ym8dp3hcxr1saxyj8mg6gxsqc0h"))))
    (build-system font-build-system)
    (home-page "https://indestructibletype.com/Jost.html")
    (synopsis "The Jost* font")
    (description "Jost* font.")
    (license license:silofl1.1)))

;; JetBrains Mono with D2Coding's Hangul (two-cell wide) and Nerd Font icons, so
;; no fallback font is needed. Family: "JetBrainsMonoHangul Nerd Font Mono".
(define-public font-jetbrains-mono-hangul-nerd-font-mono
  (package
    (name "font-jetbrains-mono-hangul-nerd-font-mono")
    (version "20260222")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/jhyub/JetBrainsMonoHangul"
                    "/releases/download/" version
                    "/JetBrainsMonoHangulNerdFontMono-" version ".zip"))
              (sha256
               (base32
                "1rfdql3hpf7xygy3ck0kqmfy0r4yxygcc00hz7bzg8nzjr5q2zf7"))))
    (build-system font-build-system)
    (home-page "https://github.com/jhyub/JetBrainsMonoHangul")
    (synopsis "JetBrains Mono with D2Coding Hangul and Nerd Font icons")
    (description "JetBrains Mono (2.304) combined with the Hangul glyphs of
D2Coding, adjusted to exactly two Latin cells wide, patched with Nerd Fonts
(3.4.0), monospaced variant.")
    (license license:silofl1.1)))
