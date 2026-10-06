#!/usr/bin/env bash
# Open local terminal Emacs directly into mu4e Inbox and start a sync.
# This is the no-SSH/local-machine counterpart to check-remote-mail.*.
set -euo pipefail

exec emacs -nw \
  --eval "(progn
             (require 'mu4e)
             (mu4e--init-handlers)
             (mu4e--start
              (lambda ()
                (mu4e-search-maildir \"/INBOX\")
                (mu4e-update-mail-and-index t))))"
