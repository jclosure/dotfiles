;;; init.el --- minimal profile -*- lexical-binding: t; -*-

;;; Commentary:

;; Placeholder profile, loaded via Chemacs2 as "minimal" (see
;; ../.emacs-profiles.el). Meant to stay close to stock Emacs: no package
;; manager bootstrap, no third-party packages, just enough to be usable.
;; Flesh this out as needed — it's intentionally a stub for now.

;;; Code:

;; Keep Custom's writes out of this file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Small UX defaults
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-screen t)
(global-display-line-numbers-mode t)

;;; init.el ends here
