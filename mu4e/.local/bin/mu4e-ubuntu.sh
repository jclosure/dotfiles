#!/usr/bin/env bash
# Launch remote Ubuntu terminal Emacs directly into mu4e Inbox and start a sync.
# This portable Unix/macOS/Linux launcher does not start the Windows-only fast
# URL forwarder; links fall back to the Emacs config's normal ssh-back/OSC52 path.
set -euo pipefail
exec ssh -t ubuntu 'TERM=xterm-256color COLORTERM=truecolor /home/user/.local/bin/mu4e-inbox'
