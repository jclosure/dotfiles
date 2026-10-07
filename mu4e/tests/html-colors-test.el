;;; html-colors-test.el --- Mail-only SHR contrast tests -*- lexical-binding: t; -*-
;; Run from the dotfiles root:
;; emacs --batch -Q -l mu4e/tests/html-colors-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'shr)
(require 'shr-color)

;; Load just the color configuration, not the package/mail startup code.
(let ((init (expand-file-name "../../emacs-ide/.emacs.d/init.el"
                              (file-name-directory load-file-name))))
  (with-temp-buffer
    (insert-file-contents init)
    (emacs-lisp-mode)
    (check-parens)
    (goto-char (point-min))
    (search-forward "(defvar shr-use-colors)")
    (let ((start (match-beginning 0)))
      (search-forward ";; Color the Gnus/mu4e MIME")
      (eval-region start (match-beginning 0)))))

(ert-deftest mail-contrast-settings-are-scoped-and-restored ()
  (let ((shr-use-colors nil)
        (shr-color-visible-distance-min 7)
        (shr-color-visible-luminance-min 45))
    (with-temp-buffer
      ;; No live mu4e/Maildir needed: the advice checks derived-mode-p.
      (setq major-mode 'mu4e-view-mode)
      (should
       (equal (my/mu4e-readable-html-colors
               (lambda ()
                 (list shr-use-colors shr-color-visible-distance-min
                       shr-color-visible-luminance-min)))
              '(t 10 60)))
      (should-error
       (my/mu4e-readable-html-colors (lambda () (error "Render failed")))))
    (with-temp-buffer
      (should
       (equal (my/mu4e-readable-html-colors
               (lambda ()
                 (list shr-use-colors shr-color-visible-distance-min
                       shr-color-visible-luminance-min)))
              '(nil 7 45))))))

(ert-deftest mail-backgrounds-use-curated-palette ()
  (should (equal (my/mu4e-html-background-color "#ffffff") "#313244"))
  (should (equal (my/mu4e-html-background-color "#eeeeee") "#313244"))
  (should (equal (my/mu4e-html-background-color "#ffcccc") "#4a303b"))
  (should (equal (my/mu4e-html-background-color "#ccddff") "#303a52"))
  (let ((my/mu4e-rendering t))
    (should
     (equal (my/mu4e-palette-color-check
             (lambda (fg bg) (list fg bg)) "#111111" "#ffffff")
            '("#111111" "#313244")))))

(ert-deftest mail-terminal-backgrounds-stay-bounded ()
  (let ((my/mu4e-rendering t))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) nil)))
      (should
       (equal
        (my/mu4e-no-terminal-background-extension
         (lambda (_start _end face &optional _append _object) face)
         1 2 '(:background "#313244" :extend t))
        '(:background "#313244"))))))

(ert-deftest mail-html-retains-colors-links-and-table-contrast ()
  (let ((html "<html><body text='#aaaaaa' bgcolor='#eeeeee'><h1 style='color:#ff0000'>Heading</h1><p style='color:#bbbbbb;background-color:#ffffff'>Body <a href='https://example.org/'>Link</a></p><table><tr><td style='color:#cccccc;background-color:#222222'>Cell</td></tr></table></body></html>")
        (shr-use-colors t)
        (shr-color-visible-distance-min 5)
        (shr-color-visible-luminance-min 40)
        (shr-use-fonts nil)
        (shr-inhibit-images t))
    (dolist (mail '(nil t))
      (with-temp-buffer
        (when mail (setq major-mode 'mu4e-view-mode))
        (let (calls)
          ;; Emulate color-capable output; test SHR's actual HTML/table paths.
          (cl-letf (((symbol-function 'display-color-cells) (lambda (&rest _) 256))
                    ((symbol-function 'shr-color-check)
                     (lambda (fg bg)
                       (push (list fg bg shr-color-visible-distance-min
                                   shr-color-visible-luminance-min) calls)
                       (list bg fg))))
            (insert html)
            (shr-render-region (point-min) (point-max)))
          (should calls)
          (should (cl-find "#cccccc" calls :key #'car :test #'equal))
          (dolist (call calls)
            (should (equal (nthcdr 2 call) (if mail '(10 60) '(5 40)))))
        (goto-char (point-min))
        (search-forward "Heading")
        (should (get-text-property (1- (point)) 'face))
        (search-forward "Body")
        (let ((body-face (get-text-property (1- (point)) 'face)))
          (should body-face)
          (search-forward "Link")
          (should (equal (get-text-property (1- (point)) 'shr-url)
                         "https://example.org/"))
          (search-forward "Cell")
          (should-not (equal body-face (get-text-property (1- (point)) 'face)))))))))

(ert-deftest obsolete-color-stripping-advice-is-absent ()
  (should-not (advice-member-p 'my/mu4e-use-theme-colors 'shr-insert-document))
  (should (advice-member-p 'my/mu4e-readable-html-colors 'shr-insert-document)))

(ert-deftest mail-contrast-keeps-palette-background ()
  ;; Dark email text on a dark palette panel: only the text may change, or
  ;; shr lifts the panel to light gray and theme link colors vanish on it.
  (let ((shr-color-visible-distance-min 10)
        (shr-color-visible-luminance-min 60))
    (let* ((my/mu4e-rendering t)
           (result (shr-color-visible "#313244" "#333333")))
      (should (equal (car result) "#313244"))
      (should (> (car (apply #'color-srgb-to-lab
                             (color-name-to-rgb (cadr result))))
                 70)))
    (let ((my/mu4e-rendering nil))
      (should-not (equal (car (shr-color-visible "#313244" "#333333"))
                         "#313244")))))

(ert-deftest mail-panel-color-beats-named-face-background ()
  ;; shr-h5 inherits `default', so with a theme it carries the theme
  ;; background and comes first in the face list; the email color must win.
  (let ((face (make-symbol "test-heading")))
    (face-spec-set face '((t :background "#1e1e2e")))
    (with-temp-buffer
      (insert (propertize "word" 'face (list face '(:background "#313244"))))
      (my/mail-pin-backgrounds (point-min) (point-max))
      (should (equal (car (get-text-property 1 'face))
                     '(:background "#313244"))))))
