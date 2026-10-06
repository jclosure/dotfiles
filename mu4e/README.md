# mu4e helpers

This stow package installs helpers for the remote Ubuntu mu4e setup.

## What this provides

- `mu4e-inbox`: runs on the Ubuntu mail host. Starts terminal Emacs, opens
  mu4e, jumps to `/INBOX`, and starts a mail sync/index update.
- `mu4e-ubuntu.ps1` / `.cmd`: Windows client launchers. They also make links
  clicked inside remote mu4e open quickly in the local Windows browser.
- `mu4e-ubuntu.sh`: macOS/Linux client launcher. It also makes links clicked
  inside remote mu4e open quickly in the local Mac/Linux browser.
- `mu4e-url-opener.ps1` / `.sh`: localhost-only URL opener helpers used by the
  launchers.

The important trick is a reverse SSH port forward. The client launcher starts a
small URL opener on the **client** machine, then runs SSH with `-R` so Ubuntu
sees that opener as `127.0.0.1:<port>`. Remote Emacs posts clicked links to
that endpoint via `MU4E_OPEN_URL_ENDPOINT`, so links open in the local browser
without a new SSH login per click.

```text
remote Emacs/mu4e on Ubuntu
  -> http://127.0.0.1:<port>/open on Ubuntu
  -> SSH reverse forward
  -> localhost-only URL opener on client
  -> local browser tab
```

The URL opener listens only on `127.0.0.1`; it is not exposed to the LAN.

## Ubuntu mail host setup

Prereqs on Ubuntu:

- Emacs + mu4e already configured
- `curl` available, used by Emacs to post URLs to the forwarded opener
- this dotfiles repo checked out at `~/dotfiles`

Install from `~/dotfiles` on the Ubuntu machine:

```sh
cd ~/dotfiles
stow mu4e
```

That creates:

```text
~/.local/bin/mu4e-inbox -> ~/dotfiles/mu4e/.local/bin/mu4e-inbox
```

Direct usage on Ubuntu:

```sh
mu4e-inbox
```

## Windows client setup

From a Windows clone of this dotfiles repo:

```powershell
cd ~/dotfiles
./winstow.ps1 mu4e
~/.local/bin/mu4e-ubuntu.ps1
```

The `.cmd` launcher delegates to the PowerShell launcher:

```cmd
%USERPROFILE%\.local\bin\mu4e-ubuntu.cmd
```

What the PowerShell launcher does:

1. Starts `mu4e-url-opener.ps1` hidden if it is not already listening.
2. SSHes to `ubuntu` with a reverse forward from Ubuntu back to the local URL
   opener.
3. Runs `mu4e-inbox` remotely with `MU4E_OPEN_URL_ENDPOINT` set.

## macOS/Linux client setup

Prereqs on the macOS/Linux client:

- `ssh`
- `python3` for the local URL opener and port probe
- `open` on macOS, or `xdg-open` on Linux
- this dotfiles repo stowed so `~/.local/bin/mu4e-ubuntu.sh` exists

Install:

```sh
cd ~/dotfiles
stow mu4e
```

Run, passing the SSH target explicitly:

```sh
~/.local/bin/mu4e-ubuntu.sh user@ubuntu
```

Or set a default target:

```sh
export MU4E_UBUNTU_HOST=user@ubuntu
~/.local/bin/mu4e-ubuntu.sh
```

If your SSH config has a host alias with the correct user, that also works:

```sh
~/.local/bin/mu4e-ubuntu.sh ubuntu
```

What the Unix launcher does:

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

Optional knobs:

```sh
# Use a fixed port instead of a random high port.
MU4E_URL_OPENER_PORT=8765 ~/.local/bin/mu4e-ubuntu.sh user@ubuntu

# Use a default SSH target.
MU4E_UBUNTU_HOST=user@ubuntu.local ~/.local/bin/mu4e-ubuntu.sh
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

Use the current `mu4e-ubuntu.sh`. It chooses a random high port and uses
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

If it is nil, you launched with plain `ssh` instead of `mu4e-ubuntu.ps1` or
`mu4e-ubuntu.sh`.

### Manual fallback launch

Without the link-forwarding launcher, you can still connect manually:

```sh
ssh -t user@ubuntu 'TERM=xterm-256color COLORTERM=truecolor ~/.local/bin/mu4e-inbox'
```

In that mode, links use the slower fallback path instead of the fast forwarded
local opener.

## SSH keepalives

Configure keepalives in the client-side `~/.ssh/config` for your Ubuntu host,
for example:

```sshconfig
Host ubuntu
  HostName ubuntu.local
  User user
  ServerAliveInterval 30
  ServerAliveCountMax 120
  TCPKeepAlive yes
```
