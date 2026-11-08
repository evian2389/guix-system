(define-module (raynet-guix users orka manifest)
  #:use-module (guix profiles)
  #:use-module (gnu packages video)         ; for mpv
  #:use-module (gnu packages text-editors)   ; for helix
  #:use-module (gnu packages vim)   ; neovim
  #:use-module (gnu packages emacs)   ; emacs
  #:use-module (gnu packages game-development) ; for godot
  #:use-module (gnu packages matrix) ; for Matrix / Element partner support
  #:use-module (gnu packages python-xyz) ; for python-mistune
  #:use-module (gnu packages python-web) ; for python-nh3
  #:use-module (abbe packages neovim)        ; for neovim
  #:use-module (nongnu packages chrome)      ; for google-chrome-stable
  #:use-module (nongnu packages mozilla)     ; for firefox
  #:use-module (px packages ai)               ; for chatgpt
  #:use-module (saayix packages binaries)     ; for Zen Browser
  #:export (orka-manifest))

(define orka-manifest
  (packages->manifest
   (list
    godot
    zen-browser-bin
    chatgpt
    python-matrix-nio
    python-mistune
    python-nh3
         )))

orka-manifest
