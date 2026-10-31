(define-module (raynet-guix services meclaw)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages python)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (raynet-guix packages meclaw)
  #:export (meclaw-service-type meclaw-configuration))

;;; Why a *system* service: cgroup v2 only lets a process migrate into a cgroup
;;; when the writer may also write the common ancestor's cgroup.procs. Here
;;; that is the root cgroup, owned by root, and elogind (no systemd) delegates
;;; nothing to users. So a root-owned wrapper creates /sys/fs/cgroup/<name>,
;;; delegates it to USER (kernel cgroup-v2 "Delegation" files), moves itself
;;; in, drops privileges and execs the bridge. All children (native MeClaw,
;;; Telegram adapter) inherit the cgroup; USER may create sub-cgroups for jobs.

(define-record-type* <meclaw-configuration>
  meclaw-configuration make-meclaw-configuration
  meclaw-configuration?
  (user       meclaw-configuration-user       (default "orka"))
  (telegram?  meclaw-configuration-telegram?  (default #t))
  (cgroup     meclaw-configuration-cgroup     (default "meclaw"))
  ;; Hard ceilings for the whole colony. memory.high throttles before the
  ;; memory.max OOM kill so a runaway job degrades instead of dying abruptly.
  (memory-high meclaw-configuration-memory-high (default "6G"))
  (memory-max  meclaw-configuration-memory-max  (default "8G"))
  (pids-max    meclaw-configuration-pids-max    (default "2048"))
  (log-file    meclaw-configuration-log-file    (default "/var/log/meclaw.log")))

(define integration-script
  (local-file "../users/orka/files/.local/bin/meclaw-workflow"))

(define (cgroup-exec config)
  (match-record config <meclaw-configuration>
    (user cgroup memory-high memory-max pids-max log-file)
    (program-file
     "meclaw-cgroup-exec"
     #~(let* ((pw   (getpwnam #$user))
              (uid  (passwd:uid pw))
              (gid  (passwd:gid pw))
              (root "/sys/fs/cgroup")
              (dir  (string-append root "/" #$cgroup))
              (put  (lambda (file value)
                      (call-with-output-file file
                        (lambda (port) (display value port))))))
         ;; Controllers must be enabled in the parent before limits exist.
         (for-each (lambda (c)
                     (catch 'system-error
                       (lambda () (put (string-append root "/cgroup.subtree_control") c))
                       (lambda _ (format (current-error-port)
                                         "meclaw: controller ~a unavailable~%" c))))
                   '("+cpu" "+memory" "+pids"))
         (unless (file-exists? dir) (mkdir dir #o755))
         (for-each (lambda (pair)
                     (let ((file (string-append dir "/" (car pair))))
                       (when (file-exists? file) (put file (cdr pair)))))
                   '(("memory.high" . #$memory-high)
                     ("memory.max"  . #$memory-max)
                     ("pids.max"    . #$pids-max)))
         ;; Delegation: the directory plus the three files the kernel names.
         ;; Limit files stay root-owned so USER cannot raise its own ceilings.
         (chown dir uid gid)
         (for-each (lambda (f) (chown (string-append dir "/" f) uid gid))
                   '("cgroup.procs" "cgroup.threads" "cgroup.subtree_control"))
         (when (file-exists? #$log-file)
           (chown #$log-file uid gid))
         ;; Move ourselves while still root, then drop privileges for good.
         (put (string-append dir "/cgroup.procs") (number->string (getpid)))
         (setgroups #())
         (setgid gid)
         (setuid uid)
         (let ((argv (cdr (command-line))))
           (apply execl (car argv) argv))))))

(define (meclaw-shepherd-service config)
  (match-record config <meclaw-configuration> (user telegram? log-file)
    (list
     (shepherd-service
      (provision '(meclaw))
      (documentation "MeClaw coordinator and bridge inside a delegated cgroup.")
      (requirement '(user-processes networking))
      (start
       #~(let* ((home (passwd:dir (getpwnam #$user)))
                (ca "/run/current-system/profile/etc/ssl/certs/ca-certificates.crt"))
           (make-forkexec-constructor
            (append (list #$(cgroup-exec config)
                          #$(file-append python "/bin/python3") #$integration-script
                          "serve" "--binary" #$(file-append meclaw "/bin/meclaw"))
                    '#$(if telegram? '("--telegram") '()))
            #:directory home
            #:log-file #$log-file
            #:environment-variables
            (list (string-append "HOME=" home)
                  (string-append "USER=" #$user)
                  (string-append "PATH=" #$(file-append python "/bin") ":" home "/.local/bin:"
                                 home "/.cargo/bin:" home "/.npm-global/bin:" home "/.nix-profile/bin:"
                                 home "/.guix-home/profile/bin:/run/current-system/profile/bin")
                  (string-append "SSL_CERT_FILE=" ca)
                  "SSL_CERT_DIR=/run/current-system/profile/etc/ssl/certs"
                  (string-append "CURL_CA_BUNDLE=" ca)))))
      (stop #~(make-kill-destructor))))))

(define meclaw-service-type
  (service-type
   (name 'meclaw)
   (description "MeClaw colony run by the system Shepherd inside its own cgroup.")
   (extensions
    (list (service-extension shepherd-root-service-type meclaw-shepherd-service)))
   (default-value (meclaw-configuration))))
