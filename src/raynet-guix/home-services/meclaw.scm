(define-module (raynet-guix home-services meclaw)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages python)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (raynet-guix packages meclaw)
  #:export (home-meclaw-service-type home-meclaw-configuration))

(define-record-type* <home-meclaw-configuration>
  home-meclaw-configuration make-home-meclaw-configuration
  home-meclaw-configuration?
  (repository home-meclaw-configuration-repository (default "~/work/workflow-evolution"))
  (telegram? home-meclaw-configuration-telegram? (default #t)))

(define integration-script
  (local-file "../users/orka/files/.local/bin/meclaw-workflow"))

(define pi-script
  (local-file "../users/orka/files/.local/bin/pi-meclaw"))

(define pi-bridge-helper
  (local-file "../users/orka/files/.local/bin/pi-microclaw"))

(define (activation config)
  #~(begin
      (unless (zero? (system* #$(file-append python "/bin/python3") #$integration-script
                             "setup" "--repository" #$(home-meclaw-configuration-repository config)))
        (error "MeClaw state wiring failed; clone workflow-evolution first"))
      (unless (zero? (system* #$(file-append python "/bin/python3") #$pi-script "setup"
                             "--bridge-helper" #$pi-bridge-helper))
        (error "MeClaw Pi frontend initialization failed"))))

;; The daemon itself is started by the system Shepherd, see
;; (raynet-guix services meclaw): only a root-started process can enter its
;; delegated cgroup. Home still owns the package and the state wiring.

(define home-meclaw-service-type
  (service-type
   (name 'home-meclaw)
   (description "A small MeClaw colony with shared evolution evidence and Codex integration.")
   (extensions
    (list (service-extension home-profile-service-type (const (list meclaw)))
          (service-extension home-activation-service-type activation)))
   (default-value (home-meclaw-configuration))))
