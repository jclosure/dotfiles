;;; format-controls-test.el --- MIME format line and gap tests -*- lexical-binding: t; -*-
;; Run from the dotfiles root:
;; emacs --batch -Q -l mu4e/tests/format-controls-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)

;; Load just the format-line and gap functions.  Both run from
;; `post-command-hook', so every test also runs them a second time.
(let ((init (expand-file-name "../../emacs-ide/.emacs.d/init.el"
                              (file-name-directory load-file-name))))
  (with-temp-buffer
    (insert-file-contents init)
    (goto-char (point-min))
    (search-forward "(defun my/mu4e-format-status ()")
    (let ((start (match-beginning 0)))
      (search-forward "(defun my/mu4e-polish-format-controls ()")
      (eval-region start (match-beginning 0)))))

(ert-deftest format-gap-keeps-point-in-body ()
  ;; C-n from the blank line into the body must not be undone by the hook.
  (with-temp-buffer
    (insert "Web: x\n(*) text/html  ( ) text/plain\n\nBody one\nBody two\n")
    (my/mu4e-compact-format-gap)
    (goto-char (point-min))
    (forward-line 3)
    (my/mu4e-compact-format-gap)
    (should (= (line-number-at-pos) 4))
    (should (looking-at-p "Body one"))))

(ert-deftest format-gap-collapses-to-one-blank-line ()
  (with-temp-buffer
    (insert "Web: x\n(*) text/html\n\n \n\nBody\n")
    (dotimes (_ 2) (my/mu4e-compact-format-gap))
    (should (equal (buffer-string) "Web: x\n(*) text/html\n\nBody\n"))))

(ert-deftest format-gap-handles-empty-body ()
  (with-temp-buffer
    (insert "Web: x\n(*) text/html\n")
    (dotimes (_ 2) (my/mu4e-compact-format-gap))
    (should (equal (buffer-string) "Web: x\n(*) text/html\n\n"))))

(ert-deftest format-status-inserts-once ()
  (cl-letf (((symbol-function 'mu4e-message-at-point) (lambda (&rest _) 'msg))
            ((symbol-function 'my/mu4e-message-content-type)
             (lambda (_) "text/html")))
    (with-temp-buffer
      (insert "From: a\nWeb: x\n\nBody\n")
      (dotimes (_ 3) (my/mu4e-format-status))
      (should (equal (buffer-string)
                     "From: a\nWeb: x\nFormat: HTML only\n\nBody\n")))))

(ert-deftest format-status-skips-when-chooser-shown ()
  (cl-letf (((symbol-function 'mu4e-message-at-point) (lambda (&rest _) 'msg))
            ((symbol-function 'my/mu4e-message-content-type)
             (lambda (_) "text/html")))
    (with-temp-buffer
      (insert "Web: x\n(*) text/html  ( ) text/plain\n\nBody\n")
      (my/mu4e-format-status)
      (should-not (string-match-p "Format:" (buffer-string))))))
