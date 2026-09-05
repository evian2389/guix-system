(define-module (raynet-guix home-services games)
  #:use-module (gnu)
  #:use-module (guix)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages games)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages vulkan)
  #:use-module (gnu home services)
  #:use-module (guix utils)
  #:use-module (nongnu packages game-client)
  )

(define (home-games-profile-service config)
  (list
    steam
    mesa
    vulkan-loader
    mesa-utils
    vulkan-tools
  ))

(define-public home-games-service-type
  (service-type (name 'home-games)
                (description "Packages and configuration for Steam.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-games-profile-service)
                       (service-extension
                        home-files-service-type
                        (lambda (config)
                          `((".local/bin/steam"
                             ,(computed-file "steam-wrapper"
                                             (with-imported-modules '((guix build utils))
                                               #~(begin
                                                   (use-modules (guix build utils))
                                                   (let ((port (open-output-file #$output)))
                                                     (display "#!/bin/sh
# for korean input
export XMODIFIERS=@im=fcitx
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export SDL_IM_MODULE=fcitx
export LANG=ko_KR.UTF-8

# Clear Guile load path variables to avoid version/bytecode mismatch on the host
unset GUILE_LOAD_PATH
unset GUILE_LOAD_COMPILED_PATH

# Share the host's locale data with the container.
# The nonguix steam wrapper sets GUIX_LOCPATH=/usr/lib/locale inside the container.
export GUIX_SANDBOX_EXTRA_SHARES=\"/run/current-system/locale=/usr/lib/locale${GUIX_SANDBOX_EXTRA_SHARES:+:$GUIX_SANDBOX_EXTRA_SHARES}\"

export LD_LIBRARY_PATH=\"$HOME/guix-system/env/profile/lib:$HOME/.guix-profile/lib:$HOME/.guix-profiles/orka-extra/lib:$LD_LIBRARY_PATH\"
# Use the absolute path to the profile's steam to avoid recursion
exec \"$HOME/.guix-home/profile/bin/steam\" \"$@\"
" port)
                                                     (close-port port))
                                                   (chmod #$output #o555))))))))))
                (default-value #f)))
