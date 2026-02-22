(define-module (raynet-guix users orka manifest)
  #:use-module (guix profiles)
  #:use-module (gnu packages video)         ; for mpv
  #:use-module (gnu packages text-editors)   ; for helix
  #:use-module (gnu packages vim)   ; neovim
  #:use-module (gnu packages emacs)   ; emacs
  #:use-module (abbe packages neovim)        ; for neovim
  #:use-module (nongnu packages chrome)      ; for google-chrome-stable
  #:use-module (nongnu packages mozilla)     ; for firefox
  #:use-module (px packages editors)         ; for antigravity
  #:export (orka-manifest))

(define orka-manifest
  (packages->manifest
   (list 
         )))

orka-manifest
