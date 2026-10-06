#!/usr/bin/env bash
# Launch remote Ubuntu terminal Emacs directly into mu4e Inbox and start a sync.
# Also starts a local localhost-only URL opener and reverse-forwards a remote
# localhost port to it so HTML email links open quickly on this Mac/Linux client.
set -euo pipefail

host="${1:-${MU4E_UBUNTU_HOST:-user@ubuntu}}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
helper="$script_dir/mu4e-url-opener.sh"

if ! command -v python3 >/dev/null 2>&1; then
    echo "mu4e-ubuntu.sh: python3 is required for the local URL opener" >&2
    exit 1
fi

# Use a per-session high port by default.  A fixed 8765 can collide with an old
# helper/session and then ssh reports confusing "connect to port failed" errors.
if [[ -n "${MU4E_URL_OPENER_PORT:-}" ]]; then
    port="$MU4E_URL_OPENER_PORT"
else
    port="$(python3 - <<'PY'
import random
print(random.randint(20000, 60999))
PY
)"
fi

port_is_listening() {
    python3 - "$port" <<'PY'
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
}

# Start helper if the chosen port is not already listening, then wait until it is.
if ! port_is_listening; then
    nohup "$helper" "$port" >/tmp/mu4e-url-opener.log 2>&1 &
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if port_is_listening; then
            break
        fi
        sleep 0.2
    done
fi

if ! port_is_listening; then
    echo "mu4e-ubuntu.sh: local URL opener failed to listen on 127.0.0.1:$port" >&2
    echo "See /tmp/mu4e-url-opener.log" >&2
    exit 1
fi

exec ssh -t \
  -o ExitOnForwardFailure=yes \
  -R "127.0.0.1:${port}:127.0.0.1:${port}" \
  "$host" \
  "TERM=xterm-256color COLORTERM=truecolor MU4E_OPEN_URL_ENDPOINT=http://127.0.0.1:${port}/open /home/user/.local/bin/mu4e-inbox"
