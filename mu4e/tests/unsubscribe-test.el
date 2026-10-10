;;; unsubscribe-test.el --- List-Unsubscribe handling tests -*- lexical-binding: t; -*-
;; Run from the dotfiles root:
;; emacs --batch -Q -l mu4e/tests/unsubscribe-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'mail-utils)
(require 'message)

;; Load just the unsubscribe code, not the package/mail startup code.
(let ((init (expand-file-name "../../emacs-ide/.emacs.d/init.el"
                              (file-name-directory load-file-name))))
  (with-temp-buffer
    (insert-file-contents init)
    (goto-char (point-min))
    (search-forward ";;; --- Unsubscribe and trash all")
    (let ((start (match-beginning 0)))
      (search-forward "(with-eval-after-load 'mu4e\n  (define-key mu4e-headers-mode-map (kbd \"M-u\")")
      (eval-region start (match-beginning 0)))))

(ert-deftest unsubscribe-prefers-one-click ()
  (should (equal (my/mu4e-unsubscribe-method
                  "<mailto:u@list.example?subject=stop>, <https://list.example/u?id=1>"
                  "List-Unsubscribe=One-Click")
                 '(one-click . "https://list.example/u?id=1"))))

(ert-deftest unsubscribe-falls-back-to-mailto-then-browser ()
  ;; An https link without the one-click promise needs a page: mail first.
  (should (equal (my/mu4e-unsubscribe-method
                  "<https://list.example/u>, <mailto:u@list.example>" nil)
                 '(mailto . "mailto:u@list.example")))
  (should (equal (my/mu4e-unsubscribe-method "<http://list.example/u>" nil)
                 '(browse . "http://list.example/u")))
  (should (equal (my/mu4e-unsubscribe-method "<https://list.example/u>" nil)
                 '(browse . "https://list.example/u")))
  (should-not (my/mu4e-unsubscribe-method nil nil)))

(ert-deftest unsubscribe-reads-folded-headers-from-file ()
  (let ((file (make-temp-file "unsub" nil ".eml")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "From: List <news@list.example>\n"
                    "List-Unsubscribe-Post: List-Unsubscribe=One-Click\n"
                    "List-Unsubscribe: <https://list.example/u?id=1&\n"
                    " k=2>, <mailto:u@list.example>\n"
                    "Subject: hi\n\nBody mentioning List-Unsubscribe: <https://evil.example>\n"))
          (let ((headers (my/mu4e-unsubscribe-headers file)))
            (should (equal (my/mu4e-unsubscribe-method (car headers) (cdr headers))
                           '(one-click . "https://list.example/u?id=1&k=2")))))
      (delete-file file))))

(ert-deftest unsubscribe-mailto-sends-requested-mail ()
  (let (sent)
    (cl-letf (((symbol-function 'message-send-and-exit)
               (lambda (&rest _)
                 (setq sent (list (message-fetch-field "To")
                                  (message-fetch-field "Subject")
                                  (progn (message-goto-body)
                                         (buffer-substring (point) (point-max)))))
                 (kill-buffer))))
      (should (equal (my/mu4e-unsubscribe-mailto
                      "mailto:leave%2Bx@list.example?subject=Remove%20me&body=bye")
                     "leave+x@list.example"))
      (should (equal (nth 0 sent) "leave+x@list.example"))
      (should (equal (nth 1 sent) "Remove me"))
      (should (string-prefix-p "bye" (nth 2 sent))))))

(ert-deftest sender-query-excludes-only-given-maildirs ()
  ;; All Mail is synced (archived mail lives only there): never left out.
  (should (equal (my/mu4e-sender-query "news@list.example")
                 "from:news@list.example"))
  (should (equal (my/mu4e-sender-query "news@list.example" "/[Gmail]/Trash")
                 "from:news@list.example AND NOT maildir:\"/[Gmail]/Trash\"")))

(ert-deftest sender-address-handles-both-contact-formats ()
  ;; mu4e 1.10 contacts are plists; older ones are (NAME . EMAIL).
  (cl-letf (((symbol-function 'mu4e-message-field)
             (lambda (msg _field) msg)))
    (should (equal (my/mu4e-sender-address '((:email "a@x.example" :name "A")))
                   "a@x.example"))
    (should (equal (my/mu4e-sender-address '(("A" . "a@x.example")))
                   "a@x.example"))))

;; The Gmail-safe trash block lives with the folder settings.
(let ((init (expand-file-name "../../emacs-ide/.emacs.d/init.el"
                              (file-name-directory load-file-name))))
  (with-temp-buffer
    (insert-file-contents init)
    (goto-char (point-min))
    (search-forward ";;; --- Gmail-safe trash")
    (let ((start (match-beginning 0)))
      (search-forward ";;; --- end Gmail-safe trash")
      (eval-region start (match-beginning 0)))))

(ert-deftest trash-mark-moves-without-trashed-flag ()
  ;; Stand-in for mu4e-mark's table; loading the feature runs the override.
  (defvar mu4e-marks)
  (setq mu4e-marks
        (list (list 'trash :char '("d" . "▼") :prompt "dtrash"
                    :action (lambda (&rest _) 'old))))
  (unless (featurep 'mu4e-mark) (provide 'mu4e-mark))
  (let (moved)
    (cl-letf (((symbol-function 'mu4e--server-move)
               (lambda (&rest args) (setq moved args)))
              ((symbol-function 'mu4e--mark-check-target) #'identity))
      (funcall (plist-get (alist-get 'trash mu4e-marks) :action)
               42 nil "/[Gmail]/Trash"))
    ;; "-N" only: no "+T", which Gmail would turn into a permanent delete.
    (should (equal moved '(42 "/[Gmail]/Trash" "-N")))
    (should (equal (plist-get (alist-get 'trash mu4e-marks) :prompt) "dtrash"))
    (should mu4e-trash-without-flag)))
