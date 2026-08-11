;; V1

;;;;; EARLY SET
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode -1)

(setq inhibit-startup-screen t)

(global-hl-line-mode +1)
(line-number-mode +1)
(global-display-line-numbers-mode 1)
(column-number-mode t)
(size-indication-mode t)


;; Minimal garbage collection during user idle time to keep memory stable
(run-with-idle-timer 5 t #'garbage-collect)


;;;;;; IMMEDIATE LOAD

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(when (< emacs-major-version 29)
  (add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)

;;; Package management (use-package)
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t) ; Ensure packages are always installed

;; Load theme immediately
(use-package modus-themes
  :defer nil
  :init (add-to-list 'custom-theme-load-path "~/.emacs.d/themes/")
  :config (load-theme 'modus-vivendi t))

;;;; LATER SET

(global-auto-revert-mode t)

;; the value is in 1/10pt, so 100 will give you 10pt, etc.
(set-face-attribute 'default nil :height 140) ;; 14 font

(fset 'yes-or-no-p 'y-or-n-p)

(setq mode-line-position
      '(;; %p print percent of buffer above top of window, o Top, Bot or All
        ;; (-3 "%p")
        ;; %I print the size of the buffer, with kmG etc
        ;; (size-indication-mode ("/" (-4 "%I")))
        ;; " "
        ;; %l print the current line number
        ;; %c print the current column
        (line-number-mode ("%l" (column-number-mode ":%c")))))

(setq org-src-fontify-natively t)

;; disable the bell when switching frame
(setq ring-bell-function 'ignore)

;;; Backup settings
(setq backup-directory-alist
      `(("." . ,(concat user-emacs-directory "backups"))))
(setq version-control t)
(setq kept-new-versions 2)
(setq kept-old-versions 2)
(setq delete-old-versions t)
(setq backup-by-copying t)
(setq vc-follow-symlinks nil)


;; Don't wrap lines
(setq-default truncate-lines t)


;;;;; DEFERRED LOAD

(use-package vertico
  :defer t
  :hook (after-init . vertico-mode))

(use-package orderless
  :defer t
  :after vertico
  :init (setq completion-styles '(orderless basic)))

(use-package marginalia
  :defer t
  :hook (after-init . marginalia-mode))

(use-package no-littering
  :defer t
  :ensure t)

(use-package executable
  :defer t
  :ensure t
  :hook
  ((after-save .
	       executable-make-buffer-file-executable-if-script-p)))

;; move where i mean
(use-package mwim
  :defer t
  :ensure t
  :bind
  ("C-a" . mwim-beginning-of-code-or-line)
  ("C-e" . mwim-end-of-code-or-line))

(use-package ws-butler
  :defer t
  :ensure t
  :hook (prog-mode . ws-butler-mode)
  :diminish ws-butler-mode)

(use-package volatile-highlights
  :defer t
  :ensure t
  :hook
  (after-init . volatile-highlights-mode))

;; the scratch buffer will persist between runs
(use-package persistent-scratch
  :ensure t
  :defer t
  ;; This tells use-package to load the package
  ;; automatically after Emacs finishes initializing
  :hook (after-init . persistent-scratch-setup-default)
  :config
  (progn
    (setq scratch-buffers '("*scratch*" "*copy-log*"))
    (persistent-scratch-autosave-mode)))

(use-package persp-mode
  :defer t
  :ensure t
  ;; :after (projectile) ; Ensure projectile is loaded first
  ;; :hook (after-init . persp-mode) ; Enable to make work by default
  :config
  (setq persp-save-dir (concat user-emacs-directory "perspectives/")) ; Custom perspective save directory
  (make-directory persp-save-dir t)
  (setq persp-state-management t)
  (setq persp-auto-save-when-idle t)
  ;; Save every 2 min
  (setq persp-auto-save-idle-time 120))


(use-package saveplace
  :defer t
  :ensure t
  :hook (after-init . save-place-mode)
  :config
  (setq save-place t) ; Enable save-place-mode
  (setq save-place-file (concat user-emacs-directory "places"))) ; Set the save file location


(use-package free-keys
  :defer t
  :ensure nil
  :commands free-keys)

(use-package helpful
  :defer t
  :ensure t
  :bind
  (("C-h f" . helpful-callable)
   ("C-h v" . helpful-variable)
   ("C-h k" . helpful-key)
   ("C-c C-d" . helpful-at-point)
   ("C-h F" . helpful-function)
   ("C-h C" . helpful-command)))


(use-package winner
  :defer t
  :ensure nil ;; Built-in package, so no installation is needed
  :hook (after-init . winner-mode) ;; Enable winner-mode after Emacs starts
  :bind (("C-c <left>"  . winner-undo)  ;; Undo window layout changes
         ("C-c <right>" . winner-redo)) ;; Redo window layout changes
  :custom
  (winner-boring-buffers '("*Completions*" "*Compile-Log*" "*helm*" "*Help*"))
  :config
  (message "Winner mode is active!"))



(use-package compile
  :ensure nil
  :defer t
  :config
  ;; Ensure the compilation window appears on the right
  (setq display-buffer-alist
        '(("\\*compilation\\*"
           (display-buffer-in-side-window)
           (side . right)  ;; Position the window on the right side
           (window-width . 80)  ;; Set the width of the window (adjust to your preference)
           (reusable-frames . t))))  ;; Make sure it's reusable in the same frame

  ;; Automatically scroll the compilation window without giving it focus
  (add-hook 'compilation-mode-hook
            (lambda ()
              (setq-local scroll-conservatively 101)))  ;; This keeps scrolling smoothly


  ;; Optional: Make sure the output scrolls automatically
  (setq compilation-scroll-output 'first-error)  ;; or 'all to scroll all output
  (setq compilation-window-height nil))            ;; Don't constrain the window height


;; Org-mode configuration
(use-package org
  :defer t
  :ensure t
  :mode ("\\.org\\'" . org-mode)
  :bind (("C-c l" . org-store-link)
         ("C-c a" . org-agenda)
         ("C-c c" . org-capture))
  :config
  ;; Basic org-mode settings
  (setq org-directory "~/org")
  (setq org-default-notes-file (concat org-directory "/notes.org"))

  ;; Agenda files
  (setq org-agenda-files (list org-directory))

  ;; Enable syntax highlighting in code blocks
  (setq org-src-fontify-natively t)
  (setq org-src-tab-acts-natively t)

  ;; Better code block editing
  (setq org-edit-src-content-indentation 0)
  (setq org-src-preserve-indentation t)

  ;; Log done items
  (setq org-log-done 'time)

  ;; Todo keywords
  (setq org-todo-keywords
        '((sequence "TODO(t)" "IN-PROGRESS(i)" "WAITING(w)" "|" "DONE(d)" "CANCELLED(c)")))

  ;; Prettier bullets
  (setq org-hide-leading-stars t))

;; Org-bullets for prettier heading bullets
(use-package org-bullets
  :defer t
  :ensure t
  :hook (org-mode . org-bullets-mode))

;; Enable extended chars in terminal mode
;; Critical package allows System Copy with mouse  in terminal
;; allows C-S-<char> in terminal
;; Install Kitty Keyboard Protocol (kkp) from MELPA if you haven't
(use-package kkp
  :ensure t
  :defer nil
  :config
  ;; This enables the protocol for all terminal frames
  (global-kkp-mode +1))

;; Multiple cursors
(use-package multiple-cursors
  :ensure t
  :defer nil
  :bind (("C-S-c C-S-c" . mc/edit-lines) ;; Edit a region of lines simultaneously
         ("C->" . mc/mark-next-like-this) ;; Add a cursor to the next matching instance
         ("C-<" . mc/mark-previous-like-this) ;; Add a cursor to the previous matching instance
         ("C-c C-<" . mc/mark-all-like-this)) ;; Mark all matching instances in the buffer
  :config
  (progn
  ;; Optional: Customize settings after the package has loaded
  (setq mc/insert-numbers-default 1)
  ;; Optional: Prevent <return> from exiting multiple-cursors-mode, allowing it to insert a newline (use C-g to exit instead)
  ;; (define-key mc/keymap (kbd "<return>") nil)

  ;; Don't ask to allow commands
  (setq mc/always-run-for-all t)))

(use-package clipetty
  :ensure t
  :defer nil
  :hook (after-init . global-clipetty-mode))

(use-package dired-x
  :ensure nil ;; dired-x is built-in to Emacs
  :after dired
  :defer t
  :bind (("C-x C-j" . dired-jump)
         ("C-x 4 C-j" . dired-jump-other-window))
  :custom
  ;; 1. Define what files you want to hide (regex)
  (dired-omit-files
   (concat dired-omit-files "\\|^\\..*$\\|^__pycache__$|\\.pyc$"))

  :config
  (progn
  ;; 3. Enable Omit Mode automatically when Dired starts
  (add-hook 'dired-mode-hook #'dired-omit-mode)
  (setq-default dired-dwim-target t)
  (setq dired-listing-switches "-alh")
  (setq dired-mouse-drag-files t)))




;; -- File associations
;; --- File Modes ---
;; HEX
(use-package hexl-mode
  :defer t
  :ensure nil
  :mode (("\\.bin\\'" . hexl-mode)
	 ("\\.a\\'" . hexl-mode)
	 ("\\.o\\'" . hexl-mode)
	 ("\\.so\\'" . hexl-mode)
	 ("\\.so.*\\'" . hexl-mode)
	 ("\\.exe\\'" . hexl-mode)
	 ("\\.dll\\'" . hexl-mode)))




;;;;;; PERSONAL BASE CONFIG

;; Terminal scrolling
(unless (display-graphic-p) ;; Only apply this in a terminal
  (xterm-mouse-mode 1)
  ;; Bind standard vertical scroll events
  (global-set-key (kbd "<mouse-4>") 'scroll-down-line)
  (global-set-key (kbd "<mouse-5>") 'scroll-up-line))


(defun mark-buffer-unmodified-if-same-as-file ()
  "Mark the current buffer as unmodified if its contents match the file on disk."
  (interactive)
  (when (and (buffer-file-name) ;; Ensure the buffer is associated with a file
             (not (buffer-modified-p))) ;; Skip if already unmodified
    (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max)))
          (file-contents (with-temp-buffer
                           (insert-file-contents (buffer-file-name))
                           (buffer-substring-no-properties (point-min) (point-max)))))
      (when (string= buffer-contents file-contents)
        (set-buffer-modified-p nil)))))

;; Automatically check buffers when focus is lost
(add-hook 'focus-out-hook 'mark-buffer-unmodified-if-same-as-file)


;; (defun mark-buffers-unmodified-on-timer ()
;;   "Iterate over file-backed buffers and mark them unmodified if their contents match the file."
;;   (dolist (buf (buffer-list))
;;     (with-current-buffer buf
;;       (when (and (buffer-file-name buf)  ;; Ensure buffer is file-backed
;;                  (buffer-modified-p))   ;; Skip unmodified buffers
;;         (let ((buffer-contents (buffer-substring-no-properties (point-min) (point-max)))
;;               (file-contents (with-temp-buffer
;;                                (insert-file-contents (buffer-file-name buf))
;;                                (buffer-substring-no-properties (point-min) (point-max)))))
;;           (when (string= buffer-contents file-contents)
;;             (set-buffer-modified-p nil)))))))

;; ;; Check buffers every 10 seconds, mark unmodified
;; (defvar buffer-cleanup-interval 10
;;   "Interval in seconds for checking if buffers match their associated files.")

;; ;; Set up a timer to run the function periodically
;; (run-with-timer 0 buffer-cleanup-interval #'mark-buffers-unmodified-on-timer)


;;; backward delete instead of backward kill
(defun backward-delete-word (arg)
  "Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
  (interactive "p")
  (delete-region (point) (progn (backward-word arg) (point))))


(global-set-key (kbd "M-DEL") 'backward-delete-word)


;;; MAIL AND ENCRYPTION - TODO: MAKE MORE GENERIC

;; location where mu4e is installed
;; sudo apt install mu4e
(add-to-list 'load-path "/usr/share/emacs/site-lisp/elpa/mu4e-1.10.8") ; Path may vary by OS

(use-package mu4e
  :ensure nil
  :defer t
  :config
  (setq mu4e-maildir "~/Mail"
	mu4e-get-mail-command "mbsync -a"
	mu4e-update-interval 300 ; Update every 5 minutes
	mu4e-attachment-dir  "~/Downloads")

  ;; Configure folders (Gmail uses [Gmail]/...)
  (setq mu4e-drafts-folder "/[Gmail]/Drafts"
	mu4e-sent-folder   "/[Gmail]/Sent Mail"
	mu4e-trash-folder  "/[Gmail]/Trash"
	mu4e-refile-folder "/[Gmail]/All Mail")

  ;; Sending Mail via SMTP
  (setq message-send-mail-function 'smtpmail-send-it
	smtpmail-starttls-credentials '(("smtp.gmail.com" 587 nil nil))
	smtpmail-default-smtp-server "smtp.gmail.com"
	smtpmail-smtp-server "smtp.gmail.com";13~
	smtpmail-smtp-service 587)

  (setq user-mail-address "jclosure@gmail.com")

  ;; Signing and Encryption hooks
  ;; Enable signing by default for all outgoing mail
  ;; (add-hook 'mu4e-compose-mode-hook 'mml-secure-message-sign-pgpmime)

  (defun my/mu4e-toggle-signing ()
    "Toggle PGP/MIME signing for the current message."
    (interactive)
    (save-excursion
      (goto-char (point-min))
      (if (re-search-forward "<#part [^>]*sign=pgpmime[^>]*>" nil t)
          (progn
            (replace-match "")
            (message "PGP Signing removed."))
	(mml-secure-message-sign-pgpmime)
	(message "PGP Signing enabled."))))

  ;; Bind it to a key in compose mode, e.g., C-c C-s
  (define-key mu4e-compose-mode-map (kbd "C-c C-s") 'my/mu4e-toggle-signing)


  ;; If you want to encrypt a specific message, use 'C-c C-m e p'
  ;; or use this helper to toggle encryption easily:
  (defun my/mu4e-toggle-encryption ()
    (interactive)
    (mml-secure-message-encrypt-pgpmime))


  ;; FINAL ADDS

  ;; Use the Emacs minibuffer for PIN entry (Modern & Seamless)
  (setq epa-pinentry-mode 'loopback)

  ;; Ensure the environment is set for every GPG call
  (defun my/mu4e-gpg-init ()
    (setenv "GPG_TTY" (shell-command-to-string "tty"))
    ;; This tells the underlying GPG process to use loopback
    (setq-local epg-pinentry-mode 'loopback))

  (add-hook 'mu4e-view-mode-hook 'my/mu4e-gpg-init)
  (add-hook 'mu4e-compose-mode-hook 'my/mu4e-gpg-init))


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(clipetty mu4e ws-butler volatile-highlights vertico undo-tree persp-mode persistent-scratch org-bullets orderless no-littering mwim modus-themes marginalia kkp key-chord helpful free-keys)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
