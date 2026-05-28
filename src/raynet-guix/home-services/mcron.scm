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
             (list
              #~(begin
                  (let ((cron-dir (string-append (or (getenv "XDG_CONFIG_HOME")
                                                     (string-append (or (getenv "HOME") "") "/.config"))
                                                 "/cron")))
                    (when (file-exists? cron-dir)
                      ((@@ (mcron scripts mcron) process-files-in-user-directory) "guile")))))))))
   (default-value #f)
   (description "Personal mcron service configuration that uses native mcron directory scanning.")))
