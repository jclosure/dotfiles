#!/usr/bin/env bash
# Launch remote Ubuntu terminal Emacs directly into mu4e Inbox and start a sync.
# Also starts a local localhost-only URL opener and reverse-forwards a remote
# localhost port to it so HTML email links open quickly on this Mac/Linux client.
set -euo pipefail

port="${MU4E_URL_OPENER_PORT:-8765}"
host="${1:-${MU4E_UBUNTU_HOST:-user@ubuntu}}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/mu4e-url-opener.sh"

# Start helper if the port is not already listening.  Use python for the probe
# to avoid depending on nc/lsof variants across macOS/Linux.
if ! python3 - "$port" <<'PY'
import socket, sys
s = socket.socket()
s.settimeout(0.25)
try:
    s.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
else:
    sys.exit(0)
PY
then
    nohup "$helper" "$port" >/tmp/mu4e-url-opener.log 2>&1 &
    sleep 0.3
fi

exec ssh -t \
  -R "127.0.0.1:${port}:127.0.0.1:${port}" \
  "$host" \
  "TERM=xterm-256color COLORTERM=truecolor MU4E_OPEN_URL_ENDPOINT=http://127.0.0.1:${port}/open /home/user/.local/bin/mu4e-inbox"
