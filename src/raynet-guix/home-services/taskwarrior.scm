(define-module (raynet-guix home-services taskwarrior)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (guix gexp)
  #:export (home-taskwarrior-service-type))

(define taskwarrior-config
  (local-file "../users/orka/guix-managed/task/taskrc"))

(define-public home-taskwarrior-service-type
  (service-type (name 'home-taskwarrior)
                (description "Taskwarrior configuration and data location.")
                (extensions
                 (list (service-extension
                        home-files-service-type
                        (lambda (_)
                          `((".config/task/taskrc" ,taskwarrior-config))))))
                (default-value #f)))
