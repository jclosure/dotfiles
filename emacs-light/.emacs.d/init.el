;;; init.el --- emacs-light -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded when this stow module is active (`stow emacs-light`, after
;; unstowing whichever other emacs-* module was active — they all target
;; ~/.emacs.d, so only one can be stowed at a time). Meant to sit between
;; emacs-minimal and emacs-ide: a package manager and a handful of
;; quality-of-life packages, but no IDE-weight tooling (LSP, DAP, etc).
;; Flesh this out as needed — it's intentionally a stub for now.

;;; Code:

;; Keep Custom's writes out of this file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; package.el + a couple of standard archives, ready for `package-install'
(require 'package)
(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; Small UX defaults
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(setq inhibit-startup-screen t)
(global-display-line-numbers-mode t)

;;; init.el ends here
