;; -*- lexical-binding: t; -*-

;;; This file is generated from the Emacs.org file in my dotfiles repository!

;;; ----- Guix Home Writable Directory Fix -----

;; Change the user-emacs-directory to keep unwanted things out of ~/.config/emacs
;; which is a read-only symlink in Guix Home.
(setq user-emacs-directory (expand-file-name "~/.cache/emacs/")
      url-history-file (expand-file-name "url/history" user-emacs-directory)
      package-user-dir (expand-file-name "elpa" user-emacs-directory)
      package-quickstart nil ;; Don't try to write quickstart file to ~/.config/emacs
      package-quickstart-file (expand-file-name "package-quickstart.el" user-emacs-directory))

;; Ensure the directory exists
(unless (file-directory-p user-emacs-directory)
  (make-directory user-emacs-directory t))

;;; ----- Guix Home Profile Fix -----

(let ((guix-profile (expand-file-name "~/.guix-home/profile")))
  (when (file-directory-p guix-profile)
    (add-to-list 'load-path (expand-file-name "share/emacs/site-lisp" guix-profile))
    (require 'guix-emacs nil t)
    (when (fboundp 'guix-emacs-autoload-packages)
      (guix-emacs-autoload-packages))))

;; Use no-littering to automatically set common paths to the new user-emacs-directory
(use-package no-littering
  :ensure nil
  :demand t
  :config
  ;; Don't litter project folders with backup files
  (let ((backup-dir (no-littering-expand-var-file-name "backup/")))
    (make-directory backup-dir t)
    (setq backup-directory-alist
          `(("\\`/tmp/" . nil)
            ("\\`/dev/shm/" . nil)
            ("." . ,backup-dir))))

  (setq auto-save-default nil)

  ;; Tidy up auto-save files
  (let ((auto-save-dir (no-littering-expand-var-file-name "auto-save/")))
    (make-directory auto-save-dir t)
    (setq auto-save-file-name-transforms
          `(("\\`/[^/]*:\\([^/]*/\\)*\\([^/]*\\)\\'"
             ,(concat temporary-file-directory "\\2") t)
            ("\\`\\(/tmp\\|/dev/shm\\)\\([^/]*/\\)*\\(.*\\)\\'" "\\3")
            ("." ,auto-save-dir t)))))

;;; ----- Basic Configuration -----

;; Core settings
(setq ;; Yes, this is Emacs
      inhibit-startup-message t

      ;; Instruct auto-save-mode to save to the current file, not a backup file
      auto-save-default nil

      ;; No backup files, please
      make-backup-files nil

      ;; Make it easy to cycle through previous items in the mark ring
      set-mark-command-repeat-pop t

      ;; Don't warn on large files
      large-file-warning-threshold nil

      ;; Follow symlinks to VC-controlled files without warning
      vc-follow-symlinks t

      ;; Don't warn on advice
      ad-redefinition-action 'accept

      ;; Revert Dired and other buffers
      global-auto-revert-non-file-buffers t

      ;; Silence compiler warnings as they can be pretty disruptive
      native-comp-async-report-warnings-errors nil)

;; Core modes
(repeat-mode 1)                ;; Enable repeating key maps
(menu-bar-mode 0)              ;; Hide the menu bar
(tool-bar-mode 0)              ;; Hide the tool bar
(savehist-mode 1)              ;; Save minibuffer history
(recentf-mode 1)               ;; Track recently opened files
(scroll-bar-mode 0)            ;; Hide the scroll bar
(xterm-mouse-mode 1)           ;; Enable mouse events in terminal Emacs
(display-time-mode 1)          ;; Display time in mode line / tab bar
(column-number-mode 1)         ;; Show column number on mode line
(tab-bar-history-mode 1)       ;; Remember previous tab window configurations
(auto-save-visited-mode 1)     ;; Auto-save files at an interval
(global-visual-line-mode 1)    ;; Visually wrap long lines in all buffers
(global-auto-revert-mode 1)    ;; Refresh buffers with changed local files

;; Tabs to spaces
(setq-default indent-tabs-mode nil
	            tab-width 2)

;; Display line numbers in programming modes
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Delete trailing whitespace before saving buffers
(add-hook 'before-save-hook 'delete-trailing-whitespace)

;; Move customization settings out of init.el
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file t))

;;; ----- Completion System (Vertico + Orderless) -----

(use-package vertico
  :ensure nil
  :demand t
  :config
  (vertico-mode))

(use-package orderless
  :ensure nil
  :demand t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :ensure nil
  :demand t
  :config
  (marginalia-mode))

(use-package savehist
  :ensure nil
  :demand t
  :config
  (savehist-mode))

(setopt tab-always-indent 'complete
        read-buffer-completion-ignore-case t
        read-file-name-completion-ignore-case t
        completion-auto-help t
        completions-detailed t)

(keymap-set minibuffer-local-map "C-p" #'vertico-previous)
(keymap-set minibuffer-local-map "C-n" #'vertico-next)

;; Use Consult for improved search and navigation
(use-package consult
  :ensure nil
  :bind (;; C-x bindings (standard and improved)
         ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
         ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
         ;; Custom M-s bindings (search)
         ("M-s d" . consult-find)                  ;; Alternative: consult-fd
         ("M-s c" . consult-locate)
         ("M-s g" . consult-grep)
         ("M-s G" . consult-git-grep)
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)
         ("M-s L" . consult-line-multi)
         ("M-s k" . consult-keep-lines)
         ("M-s u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
         ("M-s l" . consult-line)                  ;; needed by consult-line to weild its magic
         ("M-s L" . consult-line-multi)            ;; needed by consult-line to weild its magic
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history)                 ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  ;; Enable recentf-mode for consult-recent-file
  :init
  (recentf-mode 1)
  :bind
  ("C-x C-r" . consult-recent-file))

(use-package ace-window
  :ensure nil
  :bind (("M-n" . ace-window)
         ("M-N" . ace-window))
  :custom
  (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)))

;;; ----- System Identification -----

(defvar dw/is-termux
  (string-suffix-p "Android" (string-trim (shell-command-to-string "uname -a"))))

(defvar dw/current-distro (or (and (eq system-type 'gnu/linux)
                                   (file-exists-p "/etc/os-release")
                                   (with-temp-buffer
                                     (insert-file-contents "/etc/os-release")
                                     (search-forward-regexp "^ID=\"?\\(.*\\)\"?$")
                                     (intern (or (match-string 1)
                                                 "unknown"))))
                              'unknown))

(defvar dw/is-guix-system (eql dw/current-distro 'guix))

;;; ----- Package Management -----

;; Automatically install packages (when not on Guix) but don't load
;; them until requested
(setq use-package-always-ensure (not dw/is-guix-system)
      use-package-always-defer t)

;;; ----- Configuration Management -----

(defvar dw/config-directory
  (file-name-directory (or load-file-name buffer-file-name))
  "The directory where the Emacs configuration is located.")

(defvar dw/use-config-modules '()
  "A list of module symbols to load once init.el is finished.")

(defvar dw/common-config-modules '(dw-auth
                                   dw-present
                                   dw-0x0
                                   dw-writing
                                   dw-workflow
                                   dw-extras
                                   dw-helix)
  "Configuration modules most commonly used across my machines.")

;; Add configuration modules to load path
(add-to-list 'load-path (expand-file-name "modules" dw/config-directory))

;; Load system-specific configuration
(let ((config-path
       (expand-file-name (format "systems/%s.el" system-name) dw/config-directory)))
  (if (file-exists-p config-path)
      (load-file config-path)
    (message "No per-system configuration found for %s!" system-name)))

;;; ----- Appearance -----

(defun dw/set-terminal-title (title)
  (send-string-to-terminal (format "\e]0;%s\a" title)))

(defun dw/clear-background-color (&optional frame)
  (interactive)
  (or frame (setq frame (selected-frame)))
  "unsets the background color in terminal mode"
  (unless (display-graphic-p frame)
    ;; Set the terminal to a transparent version of the background color
    (send-string-to-terminal
     (format "\033]11;[90]%s\033\\"
         (face-attribute 'default :background)))
    (set-face-background 'default "unspecified-bg" frame)))

;; Clear the background color for transparent terminals
(unless (display-graphic-p)
  (add-hook 'after-make-frame-functions 'dw/clear-background-color)
  (add-hook 'window-setup-hook 'dw/clear-background-color)
  (add-hook 'ef-themes-post-load-hook 'dw/clear-background-color))

;;; ----- which-key -----

(use-package which-key
  :ensure nil
  :demand t
  :custom
  (which-key-idle-delay 0.3)
  :config
  (which-key-mode))

;; Improve ESC key response in terminal
(setq-default echo-keystrokes 0.1)
(setq esc-delay 0.01)

;;; ----- Transparency and Theme (from dotfiles) -----

(set-frame-parameter nil 'alpha-background 95)
(add-to-list 'default-frame-alist '(alpha-background . 95))

(defun kb/toggle-window-transparency ()
  "Toggle transparency."
  (interactive)
  (let ((alpha-transparency 95))
    (if (< (or (frame-parameter nil 'alpha-background) 100) 100)
        (set-frame-parameter nil 'alpha-background 100)
      (set-frame-parameter nil 'alpha-background alpha-transparency))))

;; Use Gruvbox theme
(use-package gruvbox-theme
  :ensure nil
  :config
  (load-theme 'gruvbox-dark-hard t))

;;; ----- Fonts and Language Support (from dotfiles) -----

(defvar my/fixed-width-font "JetBrainsMono Nerd Font"
  "The font to use for monospaced (fixed width) text.")

(defvar my/variable-width-font "Iosevka Aile"
  "The font to use for variable-pitch (document) text.")

(defvar my/hangul-font "D2CodingLigature Nerd Font"
  "The font to use for hangul (document) text.")

;; NOTE: These settings might not be ideal for your machine, tweak them as needed!
(set-face-attribute 'default nil :font my/fixed-width-font :weight 'light :height 110)
(set-face-attribute 'fixed-pitch nil :font my/fixed-width-font :weight 'light :height 110)
(set-face-attribute 'variable-pitch nil :font my/variable-width-font :weight 'light :height 1.1)

;; Hangul support
(set-fontset-font t 'hangul (font-spec :family my/hangul-font))
(setq face-font-rescale-alist '(("D2CodingLigature Nerd Font" . 1.15)
                                ("NanumGothicCoding" . 1.1)))

;;; ----- Editor Settings (from dotfiles) -----

(setq display-line-numbers-type 'relative)
(setq-default truncate-lines t)
(global-display-line-numbers-mode 1)
(setq display-line-numbers-width 4
      display-line-numbers-grow-only t
      display-line-numbers-width-start t)

(setq select-enable-primary t)

;; Cursor settings
(set-cursor-color "coral")
(setq default-input-method "korean-hangul")
(global-set-key (kbd "S-SPC") 'toggle-input-method)
(add-hook 'post-command-hook
          (lambda ()
            (set-cursor-color
             (if current-input-method "tan" "coral"))))

(with-eval-after-load 'simple
  (setq-default display-fill-column-indicator-column 80)
  (add-hook 'prog-mode-hook 'display-fill-column-indicator-mode))

(when (display-graphic-p)
  (set-frame-parameter (selected-frame) 'fullscreen 'maximized)
  (add-to-list 'default-frame-alist '(fullscreen . maximized)))

(defun dw/apply-ayu-dark-style ()
  (interactive)
  (setopt modus-themes-italic-constructs t
          modus-themes-bold-constructs t
          modus-themes-common-palette-overrides
          `((bg-main "#0F111B")
            (bg-active bg-main)
            (fg-main "#C3CCDF")
            (fg-active fg-main)
            (fringe unspecified)
            (border-mode-line-active unspecified)
            (border-mode-line-inactive unspecified)
            (fg-mode-line-active "#B3B1AD")
            (bg-mode-line-active "#171B27")
            (fg-mode-line-inactive "#65737E")
            (bg-mode-line-inactive "#1C1F29")
            (bg-tab-bar      "#1C1F29")
            (bg-tab-current  bg-main)
            (bg-tab-other    "#171B27")
            (fg-prompt "#F6C177")
            (bg-prompt unspecified)
            (bg-hover-secondary "#65737E")
            (bg-completion "#2f447f")
            (fg-completion "#ffffff")
            (bg-region "#2B2E36")
            (fg-region "#ffffff")

            ;; Heading colors
            (fg-heading-0 "#81A1C1")
            (fg-heading-1 "#81A1C1")
            (fg-heading-2 "#F6C177")
            (fg-heading-3 "#FFB974")
            (fg-heading-4 "#C792EA")

            (fg-prose-verbatim "#A3BE8C")
            (bg-prose-block-contents "#171B27")
            (fg-prose-block-delimiter "#65737E")
            (bg-prose-block-delimiter "#171B27")

            (accent-1 "#7FDBCA")

            (keyword   "#F6C177")
            (builtin   "#81A1C1")
            (comment   "#65737E")
            (string    "#A3BE8C")
            (fnname    "#7FDBCA")
            (type      "#C792EA")
            (variable  "#FFB974")
            (docstring "#8996A2")
            (constant  "#F07178"))))

(defun dw/apply-palenight-style ()
  (interactive)
  (setopt modus-themes-italic-constructs t
          modus-themes-bold-constructs t
          modus-themes-common-palette-overrides
          `((bg-main "#292D3E")
            (bg-active bg-main)
            (fg-main "#EEFFFF")
            (fg-active fg-main)
            (fringe unspecified)
            (border-mode-line-active unspecified)
            (border-mode-line-inactive unspecified)
            (fg-mode-line-active "#A6Accd")
            (bg-mode-line-active "#232635")
            (fg-mode-line-inactive "#676E95")
            (bg-mode-line-inactive "#282c3d")
            (bg-tab-bar      "#242837")
            (bg-tab-current  bg-main)
            (bg-tab-other    bg-active)
            (fg-prompt "#c792ea")
            (bg-prompt unspecified)
            (bg-hover-secondary "#676E95")
            (bg-completion "#2f447f")
            (fg-completion white)
            (bg-region "#3C435E")
            (fg-region white)

            (fg-heading-0 "#82aaff")
            (fg-heading-1 "#82aaff")
            (fg-heading-2 "#c792ea")
            (fg-heading-3 "#bb80b3")
            (fg-heading-4 "#a1bfff")

            (fg-prose-verbatim "#c3e88d")
            (bg-prose-block-contents "#232635")
            (fg-prose-block-delimiter "#676E95")
            (bg-prose-block-delimiter bg-prose-block-contents)

            (accent-1 "#79a8ff")

            (keyword "#89DDFF")
            (builtin "#82aaff")
            (comment "#676E95")
            (string "#c3e88d")
            (fnname "#82aaff")
            (type "#c792ea")
            (variable "#ffcb6b")
            (docstring "#8d92af")
            (constant "#f78c6c"))))

(use-package modus-themes
  :ensure nil
  :demand t
  :init
  (load-theme 'modus-vivendi-tinted t)
  (dw/apply-ayu-dark-style)
  (add-hook 'modus-themes-after-load-theme-hook #'dw/clear-background-color))

;; Make vertical window separators look nicer in terminal Emacs
(set-display-table-slot standard-display-table 'vertical-border (make-glyph-code ?│))

;; Clean up the mode line
(setq-default mode-line-format
              '("%e" "  "
                (:propertize
                 ("" mode-line-mule-info mode-line-client mode-line-modified mode-line-remote))
                mode-line-frame-identification
                mode-line-buffer-identification
                "   "
                mode-line-position
                mode-line-format-right-align
                "  "
                (project-mode-line project-mode-line-format)
                " "
                (vc-mode vc-mode)
                "  "
                mode-line-modes
                mode-line-misc-info
                "  ")
              project-mode-line t
              mode-line-buffer-identification '(" %b")
              mode-line-position-column-line-format '(" %l:%c"))

(use-package emacs-solo-rainbow-delimiters
  :ensure nil
  :no-require t
  :defer t
  :init
  (defun emacs-solo/rainbow-delimiters ()
    "Apply simple rainbow coloring to parentheses, brackets, and braces in the current buffer.
Opening and closing delimiters will have matching colors."
    (interactive)
    (let ((colors '(font-lock-keyword-face
                    font-lock-type-face
                    font-lock-function-name-face
                    font-lock-variable-name-face
                    font-lock-constant-face
                    font-lock-builtin-face
                    font-lock-string-face
                    )))
      (font-lock-add-keywords
       nil
       `((,(rx (or "(" ")" "[" "]" "{" "}"))
          (0 (let* ((char (char-after (match-beginning 0)))
                    (depth (save-excursion
                             ;; Move to the correct position based on opening/closing delimiter
                             (if (member char '(?\) ?\] ?\}))
                                 (progn
                                   (backward-char) ;; Move to the opening delimiter
                                   (car (syntax-ppss)))
                               (car (syntax-ppss)))))
                    (face (nth (mod depth ,(length colors)) ',colors)))
               (list 'face face)))))))
    (font-lock-flush)
    (font-lock-ensure))

  (add-hook 'prog-mode-hook #'emacs-solo/rainbow-delimiters))

;; Move global mode string to the tab-bar and hide tab close buttons
(setq tab-bar-close-button-show nil
      tab-bar-separator " "
      tab-bar-format '(tab-bar-format-menu-bar
                       tab-bar-format-tabs-groups
                       tab-bar-separator
                       tab-bar-format-align-right
                       tab-bar-format-global))

;; Turn on the tab-bar
(tab-bar-mode 1)

;; Customize time display
(setq display-time-load-average nil
      display-time-format "%l:%M %p %b %d W%U"
      display-time-world-time-format "%a, %d %b %I:%M %p %Z"
      display-time-world-list
      '(("Etc/UTC" "UTC")
        ("Europe/Athens" "Athens")
        ("America/Los_Angeles" "Seattle")
        ("America/Denver" "Denver")
        ("America/New_York" "New York")
        ("Pacific/Auckland" "Auckland")
        ("Asia/Shanghai" "Shanghai")
        ("Asia/Kolkata" "Hyderabad")))

;; ----- Special Buffers as Popup Window -----

(setq display-buffer-alist
      '(("\\*\\(.*shell\\|.*term\\|.*eshell\\|help\\|compilation\\|Async Shell Command\\|Occur\\|xref\\).*\\*"
        (display-buffer-reuse-window display-buffer-in-side-window)
        (side . bottom)                  ; Popups go at the bottom
        (slot . 0)                       ; Use the first slot at the bottom
        (post-command-select-window . t) ; Select the window upon display
        (window-height . 0.3))))         ; 30% of the frame height

(defun dw/toggle-popup-window ()
  (interactive)
  (if-let* ((popup-window
            (get-window-with-predicate
             (lambda (window)
               (eq (window-parameter window 'window-side)
                   'bottom)))))

      ;; Focus the window if it is not selected, otherwise close it
      (if (eq popup-window (selected-window))
          (delete-window popup-window)
        (select-window popup-window))

    ;; Find the most recent buffer that matches the rule and show it
    ;; NOTE: This logic is somewhat risky because it makes the assumption
    ;;       that the popup rule comes first in `display-buffer-alist'.
    ;;       I chose to do this because maintaining a separate variable
    ;;       for this rule meant I had to re-evaluate 2 different forms
    ;;       to update my rule list.
    (if-let* ((popup-buffer
              (seq-find (lambda (buffer)
                          (buffer-match-p (caar display-buffer-alist)
                                          (buffer-name buffer)))
                        (if (project-current)
                            (project-buffers (project-current))
                          (buffer-list (selected-frame))))))
        (display-buffer popup-buffer (cdar display-buffer-alist))
      (message "No popup buffers found."))))

;; TODO: This binding may need to change
(keymap-global-set "C-c p" #'dw/toggle-popup-window)
(with-eval-after-load 'term
  (keymap-set term-raw-map "C-c p" #'dw/toggle-popup-window))

;;; ----- Essential Org Mode Configuration -----

(setq org-directory "~/notes/"
      org-roam-directory "~/notes/resources/")

(setq org-ellipsis " ▾"
      org-startup-folded 'content
      org-cycle-separator-lines 2
      org-fontify-quote-and-verse-blocks t
      org-hide-emphasis-markers t
      org-pretty-entities t)

;; Indent org-mode buffers for readability
(add-hook 'org-mode-hook #'org-indent-mode)

;; Set up Org Babel languages
(org-babel-do-load-languages
 'org-babel-load-languages
 '((emacs-lisp . t)
   (shell . t)))

;; Use org-tempo
(use-package org-tempo
  :ensure nil
  :demand t
  :config
  (dolist (item '(("sh" . "src sh")
                  ("el" . "src emacs-lisp")
                  ("li" . "src lisp")
                  ("sc" . "src scheme")
                  ("ts" . "src typescript")
                  ("py" . "src python")
                  ("yaml" . "src yaml")
                  ("json" . "src json")
                  ("einit" . "src emacs-lisp :tangle init.el")
                  ("emodule" . "src emacs-lisp :tangle modules/dw-MODULE.el")))
    (add-to-list 'org-structure-template-alist item)))

;; Beautiful bullets
(use-package org-superstar
  :ensure nil
  :hook (org-mode . org-superstar-mode)
  :config
  (setq org-superstar-leading-bullet ?\s)
  (setq org-superstar-leading-fallback ?\s)
  (setq org-hide-leading-stars t)
  ;;(setq org-superstar-headline-bullets-list '("◉" "○" "✸" "✿" "✤" "✜" "◆" "▶")
  ;;      org-superstar-item-bullet-alist '((?* . ?•) (?+ . ?➤) (?- . ?–))))
)

;;; ----- Document Centering -----

(defvar center-document-desired-width 90
  "The desired width of a document centered in the window.")

(defun center-document--adjust-margins ()
  ;; Reset margins first before recalculating
  (set-window-parameter nil 'min-margins nil)
  (set-window-margins nil nil)

  ;; Adjust margins if the mode is on
  (when center-document-mode
    (let ((margin-width (max 0
			     (truncate
			      (/ (- (window-width)
				    center-document-desired-width)
				 2.0)))))
      (when (> margin-width 0)
	(set-window-parameter nil 'min-margins '(0 . 0))
	(set-window-margins nil margin-width margin-width)))))

(define-minor-mode center-document-mode
  "Toggle centered text layout in the current buffer."
  :lighter " Centered"
  :group 'editing
  (if center-document-mode
      (add-hook 'window-configuration-change-hook #'center-document--adjust-margins 'append 'local)
    (remove-hook 'window-configuration-change-hook #'center-document--adjust-margins 'local))
  (center-document--adjust-margins))

(add-hook 'org-mode-hook #'center-document-mode)
(add-hook 'markdown-mode-hook #'center-document-mode)
(add-hook 'text-mode-hook #'center-document-mode)

;; Coming soon.

;;; ----- Dired -----

(defun dw/dired-mode-hook ()
  (interactive)
  (dired-hide-details-mode 1)
  (hl-line-mode 1))

(use-package dired
  :ensure nil
  :bind (:map dired-mode-map
              ("b" . dired-up-directory))
  :config
  (setq dired-listing-switches "-alv --group-directories-first"
        dired-omit-files "^\\.[^.].*"
        dired-omit-verbose nil
        dired-dwim-target 'dired-dwim-target-next
        dired-hide-details-hide-symlink-targets nil
        dired-kill-when-opening-new-dired-buffer t
        delete-by-moving-to-trash t)

  (add-hook 'dired-mode-hook #'dw/dired-mode-hook))

;; Make sure ripgrep is used everywhere
(setq xref-search-program 'ripgrep
      grep-command "rg -nS --noheading")

(defvar focus-mode--saved-mode-line-format nil
  "Stores the `mode-line-format' value before enabling focus mode.")

(define-minor-mode focus-mode
  "Hide unnecessary UI elements to increase focus."
  :global t
  :group 'editing
  :lighter " Focus"
  (if focus-mode
      (progn
        (setq-default focus-mode--saved-mode-line-format (default-value 'mode-line-format))
        (setq-default mode-line-format nil)
        (tab-bar-mode 0))
    (setq-default mode-line-format focus-mode--saved-mode-line-format)
    (tab-bar-mode 1)))

;;; ----- Finalization

;; Load requested configuration modules
(dolist (module dw/use-config-modules)
  (require module))
