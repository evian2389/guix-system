(define-module (raynet-guix home-services mcron)
  #:use-module (gnu home services mcron)
  #:use-module (gnu services)
  #:use-module (guix gexp)
  #:export (home-mcron-config-service-type))

(define home-mcron-config-service-type
  (service-type
   (name 'home-mcron-config)
   (extensions
    (list (service-extension
           home-mcron-service-type
           (lambda (config)
             ;; Add your jobs here. 
             ;; Example: run gd-notes.guile every hour
             (list #~(job '(next-hour)
                          (string-append (getenv "HOME") "/.config/cron/gd-notes.guile")))))))
   (default-value #f)
   (description "Personal mcron service configuration.")))
