(define-module (raynet-guix home-services audio)
  #:use-module (gnu home services)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages music)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages rust-apps))

(define (home-audio-profile-service config)
  (list ardour

        ;; Pipewire (for pw-jack)
        pipewire
        qpwgraph
        helvum
        pavucontrol
        ;; coppwr ;; Not currently in Guix

        ;; Guitar

        ;; guitarix
        ;; guitarix-lv2

        ;; Effects
        calf
        g2reverb
        wolf-shaper
        dragonfly-reverb

        ;; Synths
        helm
        amsynth
        ;;geonkick  ;; redkick is not building right now
        fluidsynth
        ;; surge-synth  ;; Build fails
        zynaddsubfx
        avldrums-lv2

        ;; Mixing Tools
        wolf-spectrum

        ;; Possibly unused
        jack-keyboard
        ;carla
        ))

(define-public home-audio-service-type
  (service-type (name 'home-audio)
                (description "Packages and configuration for video audio.")
                (extensions
                 (list (service-extension
                        home-profile-service-type
                        home-audio-profile-service)))
                (default-value #f)))
