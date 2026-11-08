(define-module (raynet-guix home-services ff2mpv)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu packages python)
  #:use-module (guix gexp)
  #:export (home-ff2mpv-service-type))

(define ff2mpv-host-source
  (local-file "../users/orka/files/ff2mpv-native-host.py"
              "ff2mpv-native-host.py"
              #:recursive? #f))

(define ff2mpv-host
  (program-file "ff2mpv-native-host"
                #~(execl #$(file-append python "/bin/python3")
                        "python3" #$ff2mpv-host-source)))

(define (ff2mpv-files _)
  (let ((manifest
         (mixed-text-file "ff2mpv.json"
                          "{\n"
                          "  \"name\": \"ff2mpv\",\n"
                          "  \"description\": \"ff2mpv native host\",\n"
                          "  \"path\": \"" ff2mpv-host "\",\n"
                          "  \"type\": \"stdio\",\n"
                          "  \"allowed_extensions\": [\"ff2mpv@yossarian.net\"]\n"
                          "}\n")))
    `((".local/bin/ff2mpv-native-host" ,ff2mpv-host)
      (".mozilla/native-messaging-hosts/ff2mpv.json" ,manifest)
      (".zen/native-messaging-hosts/ff2mpv.json" ,manifest))))

(define-public home-ff2mpv-service-type
  (service-type (name 'home-ff2mpv)
                (description "Register ff2mpv native messaging host for Firefox-based browsers.")
                (extensions
                 (list (service-extension home-files-service-type ff2mpv-files)))
                (default-value #f)))
