(define-module (raynet-guix home-services desktop)
  #:use-module (raynet-guix packages fonts)
  #:use-module (gnu)
  #:use-module (gnu home services)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (guix gexp)
  #:export (home-desktop-service-type))

(use-package-modules admin compression curl fonts freedesktop gimp glib gnome gnome-xyz
                     gstreamer kde-frameworks linux lsof music package-management
                     password-utils pdf pulseaudio shellutils ssh syncthing terminals tmux
                     video web-browsers wget window-management xdisorg xorg)

(define (home-desktop-profile-service config)
  (list niri
        sway
        swayidle
        swaylock
        hypridle
        wl-clipboard
        mako
        foot
        gammastep
        grimshot ;; grimshot --notify copy area
        network-manager-applet

        ;; Compatibility for older Xorg applications
        xorg-server-xwayland

        ;; Flatpak and XDG utilities
        flatpak
        xdg-desktop-portal
        xdg-desktop-portal-gtk
        xdg-desktop-portal-wlr
        xdg-utils ;; For xdg-open, etc
        xdg-dbus-proxy
        shared-mime-info
        (list glib "bin")

        ;; Appearance
        matcha-theme
        papirus-icon-theme
        breeze-icons ;; For KDE apps
        gnome-themes-extra
        adwaita-icon-theme

        ;; Fonts
        font-jost
        font-iosevka-ss08
        font-iosevka-aile
        font-microsoft-cascadia
        font-jetbrains-mono
        font-google-noto
        font-google-noto-emoji
        font-liberation
        font-awesome

        ;; Remote terminal access
        tmux
        mosh

        ;; Browsers
        (specification->package "qtwayland")
        ;qutebrowser
        ;vimb

        ;; Authentication
        password-store

        ;; Audio devices and media playback
        mpv
        mpv-mpris
        yt-dlp
        playerctl
        gstreamer
        gst-plugins-base
        gst-plugins-good
        gst-plugins-bad
        gst-plugins-ugly
        gst-libav
        alsa-utils

        ;; Graphics
        gimp

        ;; PDF reader
        zathura
        zathura-pdf-mupdf

        ;; File syncing
        syncthing-gtk

        ;; General utilities
        curl
        wget
        openssh
        zip
        unzip
        trash-cli

        ;; System monitoring and network tools
        btop
        lsof
        netcat
        (specification->package+output "bind" "utils")))

(define (home-desktop-environment-variables config)
  '(("_JAVA_AWT_WM_NONREPARENTING" . "1")
    ;; BROWSER is used by agents and terminal tools that bypass xdg-open.
    ;; Point it at the local Flatpak wrapper because google-chrome.desktop is
    ;; still registered as the default handler but its executable is absent.
    ("BROWSER" . "/home/orka/.local/bin/zen")
    ("XDG_DATA_DIRS" . "$HOME/.nix-profile/share:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS")))

(define (home-desktop-mimeapps config)
  (list
   `( ".local/share/applications/mimeapps.list"
      ,(plain-file "mimeapps.list"
                   "[Default Applications]\nx-scheme-handler/http=app.zen_browser.zen.desktop\nx-scheme-handler/https=app.zen_browser.zen.desktop\ntext/html=app.zen_browser.zen.desktop\napplication/xhtml+xml=app.zen_browser.zen.desktop\n"))))

(define home-desktop-service-type
  (service-type (name 'home-desktop)
                (description "My desktop environment service.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-desktop-profile-service)
                       (service-extension
                        home-environment-variables-service-type
                        home-desktop-environment-variables)
                       (service-extension
                        home-files-service-type
                        home-desktop-mimeapps)))
                (default-value #f)))
