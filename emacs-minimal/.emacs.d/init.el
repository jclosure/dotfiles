;;; init.el --- emacs-minimal -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded when this stow module is active (`stow emacs-minimal`, after
;; unstowing whichever other emacs-* module was active — they all target
;; ~/.emacs.d, so only one can be stowed at a time). Meant to stay close
;; to stock Emacs: no package manager bootstrap, no third-party packages,
;; just enough to be usable. Flesh this out as needed — it's
;; intentionally a stub for now.

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
