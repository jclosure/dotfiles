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

(ert-deftest mail-gap-between-panels-continues-enclosing-color ()
  ;; A blank line between a section and a button row inside an outer
  ;; wrapper: emptying it showed the theme background as a dark stripe.
  (with-temp-buffer
    (let ((outer '(:background "#313244"))
          (section '(:background "#4b3b2f"))
          (button '(:background "#4a303b")))
      (insert (propertize "  " 'face outer) (propertize "  text" 'face section) "\n"
              "\n"
              (propertize "  " 'face outer) (propertize " " 'face section)
              (propertize "go   " 'face button) "\n")
      (my/mail-paint-gap 10 1 11 8)
      (goto-char 10)
      (should (equal (buffer-substring-no-properties 10 (line-end-position))
                     "        "))
      ;; Shared columns keep their color; where the section and the
      ;; button differ, the section (the enclosing panel) continues.
      (should (equal (my/mail-background-at 10) "#313244"))
      (should (equal (my/mail-background-at 12) "#4b3b2f"))
      (should (equal (my/mail-background-at 17) "#4b3b2f")))))

(ert-deftest mail-gap-without-both-neighbors-is-emptied ()
  (with-temp-buffer
    (insert "   \n" (propertize "text" 'face '(:background "#313244")) "\n")
    (my/mail-paint-gap 1 nil 5 4)
    (should (equal (buffer-substring-no-properties 1 2) "\n"))))

(ert-deftest mail-thin-wrapper-stripes-take-surrounding-color ()
  ;; Nested #fff wrapper tables show through shr's per-table indent as
  ;; 1-2 column stripes inside a colored section; wider gutters stay.
  (with-temp-buffer
    (let ((b '(:background "#4b3b2f")) (n '(:background "#313244")))
      (insert (propertize "  " 'face b) (propertize "  " 'face n)
              (propertize " " 'face b) (propertize "  " 'face n)
              (propertize "text" 'face b) (propertize "   " 'face n)
              (propertize "more" 'face b))
      (my/mail-close-slivers (point-min) (point-max))
      (should (equal (my/mail-background-at 3) "#4b3b2f"))
      (should (equal (my/mail-background-at 6) "#4b3b2f"))
      (should (equal (my/mail-background-at 12) "#313244")))))

(ert-deftest mail-panel-left-edge-is-evened-out ()
  (with-temp-buffer
    (let ((b '(:background "#4b3b2f")))
      (insert "     " (propertize "logo" 'face b) "\n"
              "  " (propertize "   text" 'face b) "\n")
      (let ((lines (vector (vector (copy-marker 1) "#4b3b2f" nil)
                           (vector (copy-marker 11) "#4b3b2f" nil))))
        (my/mail-align-panel-left-edges lines))
      (should (equal (my/mail-background-at 3) "#4b3b2f"))
      (should-not (my/mail-background-at 2)))))

(ert-deftest mail-suspicious-link-warning-is-one-column ()
  (with-temp-buffer
    (insert "link" (propertize "⚠️" 'help-echo "suspicious") " more")
    (my/mail-text-style-warnings (point-min) (point-max))
    (should (equal (buffer-string) "link⚠ more"))
    (should (get-text-property 5 'help-echo))))

(ert-deftest mail-url-numbers-take-panel-padding ()
  (with-temp-buffer
    (insert "see https://example.org      \nnext\n")
    (let ((ov (make-overlay 5 24)))
      (overlay-put ov 'mu4e-overlay t)
      (overlay-put ov 'after-string "​[1]")
      (my/mu4e-make-room-for-url-numbers)
      (should (equal (overlay-get ov 'after-string) "[1]"))
      (goto-char 1)
      (should (equal (buffer-substring 1 (line-end-position))
                     "see https://example.org   ")))))

(ert-deftest mail-gap-fills-left-edge-and-falls-back-to-page ()
  (with-temp-buffer
    (let ((n '(:background "#313244")) (teal '(:background "#2d4144"))
          (green '(:background "#304338")))
      ;; Above: page gray.  Below: a teal row with a gray name label.
      ;; Columns 0-1 differ, so they take the first shared color to the right.
      (insert (propertize "    " 'face n) "\n"
              "\n"
              (propertize "  " 'face teal) (propertize "  " 'face n) "\n")
      (my/mail-paint-gap 6 1 7 4 "#313244")
      (should (equal (my/mail-background-at 6) "#313244"))
      (should (equal (my/mail-background-at 9) "#313244"))
      ;; Two rows that share no color at all: the gap takes the page color.
      (erase-buffer)
      (insert (propertize "    " 'face teal) "\n" "\n"
              (propertize "    " 'face green) "\n")
      (my/mail-paint-gap 6 1 7 4 "#313244")
      (should (equal (buffer-substring-no-properties 6 10) "    "))
      (should (equal (my/mail-background-at 6) "#313244")))))

(ert-deftest mail-table-content-outside-cells-is-kept ()
  ;; Reddit digests put each post in a table placed directly in a <tr>.
  ;; shr renders that (and re-inserts the table's images) in one pass
  ;; after the table; in terminal mail only the image copies are dropped.
  (let ((html "<table><tr><td><img alt='Logo' src='x.png'></td></tr><tr><table><tr><td>Post text</td></tr></table></tr></table>")
        (my/mail-html-rendering t)
        (shr-use-fonts nil))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) nil)))
      (with-temp-buffer
        (insert html)
        (shr-render-region (point-min) (point-max))
        (let ((text (buffer-string)))
          (should (string-search "Post text" text))
          (should (= 1 (how-many "Logo" (point-min) (point-max)))))))))

(ert-deftest mail-unlabeled-images-and-tracking-pixels ()
  (let ((html "<p>A <img src='a.png' width='148' height='74'> B <img src='t.gif' width='1' height='1' alt=''> C <img src='s.png' style='max-width:600px;width:1px;height:1px'> D <img src='l.png' alt='Logo'></p>")
        (my/mail-html-rendering t)
        (shr-use-fonts nil))
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&optional _) nil)))
      (with-temp-buffer
        (insert html)
        (shr-render-region (point-min) (point-max))
        (let ((text (buffer-string)))
          ;; shr puts wide images on their own line.
          (should (string-match-p "A[ \n]+\\[image\\][ \n]+B" text))
          ;; 1x1 pixels, in attributes or (not max-width) in style, vanish.
          (should (string-match-p "B +C +D" text))
          (should (string-search "Logo" text))
          (should-not (string-search "*" text)))))))

(ert-deftest mail-blank-line-runs-collapse-to-one ()
  (with-temp-buffer
    (insert "one\n\n   \n\t\ntwo\n\nthree\n  \n")
    (my/mail-collapse-blank-lines (point-min) (point-max))
    (should (equal (buffer-string) "one\n\ntwo\n\nthree\n  \n"))))
