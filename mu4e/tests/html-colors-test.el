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
