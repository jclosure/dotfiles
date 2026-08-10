;;; init.el --- experimental profile -*- lexical-binding: t; -*-

;;; Commentary:

;; Placeholder profile, loaded via Chemacs2 as "experimental" (see
;; ../.emacs-profiles.el). A scratch space for trying out packages/config
;; without risking minimal, light, or ide — safe to break, reset, or
;; rewrite entirely. Starts as a copy of light's baseline. Flesh this out
;; as needed — it's intentionally a stub for now.

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
