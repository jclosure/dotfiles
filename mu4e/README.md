# mu4e helpers

This stow package installs helpers for local and remote mu4e mail checks.

## What this provides

- `mu4e-inbox`: shared implementation used on a mail host. Starts terminal
  Emacs, opens mu4e, jumps to `/INBOX`, and starts a mail sync/index update.
- `check-mail.sh`: local Unix/Linux launcher. Runs Emacs/mu4e locally, no SSH.
- `check-remote-mail.ps1` / `.cmd`: Windows client launchers. They SSH to a
  remote mail host and make links clicked inside remote mu4e open quickly in
  the local Windows browser.
- `check-remote-mail.sh`: macOS/Linux client launcher. It SSHes to a remote
  mail host and makes links clicked inside remote mu4e open quickly in the
  local Mac/Linux browser.
- `mu4e-url-opener.ps1` / `.sh`: localhost-only URL opener helpers used by the
  remote launchers.

The remote launchers all take the SSH target explicitly:

```sh
check-remote-mail.sh user@ubuntu
```

```powershell
check-remote-mail.ps1 user@ubuntu
```

This keeps behavior the same on Windows/macOS/Linux and avoids relying on a
client-specific SSH config to choose the remote user.

The remote-link trick is a reverse SSH port forward. The client launcher starts
a small URL opener on the **client** machine, then runs SSH with `-R` so the
remote mail host sees that opener as `127.0.0.1:<port>`. Remote Emacs posts
clicked links to that endpoint via `MU4E_OPEN_URL_ENDPOINT`, so links open in
the local browser without a new SSH login per click.

```text
remote Emacs/mu4e
  -> http://127.0.0.1:<port>/open on remote host
  -> SSH reverse forward
  -> localhost-only URL opener on client
  -> local browser tab
```

The URL opener listens only on `127.0.0.1`; it is not exposed to the LAN.

## Remote Ubuntu/mail-host setup

Prereqs on the remote mail host:

- Emacs + mu4e configured
- `curl` available, used by Emacs to post URLs to the forwarded opener
- this dotfiles repo checked out at `~/dotfiles`

Install on the remote mail host:

```sh
cd ~/dotfiles
stow mu4e
```

That creates:

```text
~/.local/bin/mu4e-inbox -> ~/dotfiles/mu4e/.local/bin/mu4e-inbox
```

Direct usage on the remote host:

```sh
mu4e-inbox
```

## Local Unix/Linux mail setup

For a machine where mu4e/mail are local, stow this package and run:

```sh
check-mail.sh
```

That does the same Inbox+sync startup as the remote version, but does not SSH
anywhere and does not start a URL-forwarding helper.

## Windows remote client setup

From a Windows clone of this dotfiles repo:

```powershell
cd ~/dotfiles
./winstow.ps1 mu4e
~/.local/bin/check-remote-mail.ps1 user@ubuntu
```

The `.cmd` launcher delegates to the PowerShell launcher:

```cmd
%USERPROFILE%\.local\bin\check-remote-mail.cmd user@ubuntu
```

What the PowerShell launcher does:

1. Starts `mu4e-url-opener.ps1` hidden if it is not already listening.
2. SSHes to the passed `user@host` with a reverse forward back to the local URL
   opener.
3. Runs `mu4e-inbox` remotely with `MU4E_OPEN_URL_ENDPOINT` set.

## macOS/Linux remote client setup

Prereqs on the macOS/Linux client:

- `ssh`
- `python3` for the local URL opener and port probe
- `open` on macOS, or `xdg-open` on Linux
- this dotfiles repo stowed so `~/.local/bin/check-remote-mail.sh` exists

Install:

```sh
cd ~/dotfiles
stow mu4e
```

Run, passing the SSH target explicitly:

```sh
~/.local/bin/check-remote-mail.sh user@ubuntu
```

What the Unix remote launcher does:

1. Chooses a random high local port for this session.
2. Starts `mu4e-url-opener.sh` on `127.0.0.1:<port>`.
3. Waits until the opener is actually listening.
4. SSHes with:

   ```sh
   ssh -t -o ExitOnForwardFailure=yes \
     -R 127.0.0.1:<port>:127.0.0.1:<port> \
     user@ubuntu \
     'TERM=xterm-256color COLORTERM=truecolor MU4E_OPEN_URL_ENDPOINT=http://127.0.0.1:<port>/open /home/user/.local/bin/mu4e-inbox'
   ```

5. In remote Emacs, clicking an HTML link like `View messages` posts the URL to
   the forwarded endpoint; the local opener calls `open <url>` on macOS or
   `xdg-open <url>` on Linux.

Optional fixed port:

```sh
MU4E_URL_OPENER_PORT=8765 ~/.local/bin/check-remote-mail.sh user@ubuntu
```

```powershell
$env:MU4E_URL_OPENER_PORT = 8765
~/.local/bin/check-remote-mail.ps1 user@ubuntu
```

## Emacs integration

The Emacs config in `emacs-ide` does three things for this setup:

1. `browse-url` first tries `MU4E_OPEN_URL_ENDPOINT` using `curl`.
2. HTML mail links rendered by `shr` bind `mouse-1` to open the hidden
   `shr-url`, so link text like `View messages` works even though the literal
   URL is not visible.
3. If the forwarded opener is unavailable, it falls back to SSH-back/OSC52.

## Troubleshooting

### `connect to port failed`

Use the current `check-remote-mail.sh`. It chooses a random high port and uses
`ExitOnForwardFailure=yes`, which avoids stale fixed-port conflicts. If you set
`MU4E_URL_OPENER_PORT`, try unsetting it.

### Local URL opener failed to listen

Check:

```sh
cat /tmp/mu4e-url-opener.log
```

Make sure `python3` exists and that `open`/`xdg-open` is available.

### Links do not open locally

Inside remote Emacs, verify the env var exists:

```elisp
(getenv "MU4E_OPEN_URL_ENDPOINT")
```

If it is nil, you launched with plain `ssh` instead of `check-remote-mail.ps1`
or `check-remote-mail.sh`.

### Manual fallback launch

Without the link-forwarding launcher, you can still connect manually:

```sh
ssh -t user@ubuntu 'TERM=xterm-256color COLORTERM=truecolor ~/.local/bin/mu4e-inbox'
```

In that mode, links use the slower fallback path instead of the fast forwarded
local opener.

## SSH keepalives

Configure keepalives in the client-side `~/.ssh/config` for your remote mail
host, for example:

```sshconfig
Host ubuntu
  HostName ubuntu.local
  ServerAliveInterval 30
  ServerAliveCountMax 120
  TCPKeepAlive yes
```
