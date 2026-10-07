# mu4e helpers

This stow package installs one mail-check command per shell:

- `check-mail.sh` for Unix/macOS/Linux
- `check-mail.ps1` for PowerShell
- `check-mail.cmd` for cmd.exe

## Modes

### Local Unix/Linux mail

On a Unix/Linux machine where Emacs, mu, mu4e, and the Maildir are local:

```sh
check-mail.sh
```

This starts terminal Emacs, opens mu4e, jumps to `/INBOX`, and starts a
mail sync/index update. No SSH is used.

### Remote mail host

On any client, pass `--remote user@host`:

```sh
check-mail.sh --remote user@ubuntu
```

```powershell
check-mail.ps1 --remote user@ubuntu
```

```cmd
check-mail.cmd --remote user@ubuntu
```

Windows has no native mu/mu4e support in this setup, so the Windows scripts
only support the `--remote` form and print usage otherwise.

## Remote link forwarding

For `--remote`, the launcher starts a localhost-only URL opener on the
**client** machine, then runs SSH with a reverse port forward. Remote Emacs
posts clicked links to `MU4E_OPEN_URL_ENDPOINT`, which reaches the local opener
and opens a browser tab on the client.

```text
remote Emacs/mu4e
  -> http://127.0.0.1:<port>/open on remote host
  -> SSH reverse forward
  -> localhost-only URL opener on client
  -> local browser tab
```

The URL opener listens only on `127.0.0.1`; it is not exposed to the LAN.

## Remote mail-host setup

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

## Client setup

### Unix/macOS/Linux client

Prereqs:

- `ssh`
- `python3`
- `open` on macOS, or `xdg-open` on Linux

Install:

```sh
cd ~/dotfiles
stow mu4e
```

Run:

```sh
~/.local/bin/check-mail.sh --remote user@ubuntu
```

The Unix launcher chooses a random high local port by default to avoid stale
port conflicts.

### Windows client

Install from a Windows clone of this dotfiles repo.  Stow both `powershell`
(for `~/.local/bin/sshmail.ps1`) and `mu4e`:

```powershell
cd ~/dotfiles
./winstow.ps1 powershell mu4e
~/.local/bin/check-mail.ps1 --remote user@ubuntu
```

Or from cmd.exe:

```cmd
%USERPROFILE%\.local\bin\check-mail.cmd --remote user@ubuntu
```

## Optional fixed URL-forwarding port

Unix/macOS/Linux:

```sh
MU4E_URL_OPENER_PORT=8765 check-mail.sh --remote user@ubuntu
```

PowerShell:

```powershell
$env:MU4E_URL_OPENER_PORT = 8765
check-mail.ps1 --remote user@ubuntu
```

## Emacs integration

The Emacs config in `emacs-ide` does three things for this setup:

1. `browse-url` first tries `MU4E_OPEN_URL_ENDPOINT` using `curl`.
2. HTML mail links rendered by `shr` bind `mouse-1` to open the hidden
   `shr-url`, so link text like `View messages` works even though the literal
   URL is not visible.
3. If the forwarded opener is unavailable, it falls back to SSH-back/OSC52.

## HTML email readability

The `emacs-ide` config disables sender-specified HTML colors while SHR renders
mu4e views, including table cells. Mail text uses the active Emacs theme
(normally Catppuccin) instead of potentially low-contrast HTML colors.
HTML structure, links, and image behavior are unchanged; colors baked into
images cannot be overridden. EWW and other SHR consumers are unaffected.

Restart Emacs after updating the config, then reopen the message.
The `my/mu4e-use-theme-colors` advice around `shr-insert-document` binds
`shr-use-colors` to nil only for a render originating in `mu4e-view-mode`.
A mode-hook buffer-local setting alone is insufficient because SHR renders
table cells in temporary buffers.

## Troubleshooting

### Windows usage without `--remote`

Expected: Windows has no native mu/mu4e here. Use:

```powershell
check-mail.ps1 --remote user@ubuntu
```

### `connect to port failed`

Use the current `check-mail.sh --remote ...`. It chooses a random high port and
uses `ExitOnForwardFailure=yes`, which avoids stale fixed-port conflicts. If
you set `MU4E_URL_OPENER_PORT`, try unsetting it.

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

If it is nil, you launched with plain `ssh` instead of `check-mail --remote`.

### Manual fallback launch

Without the link-forwarding launcher, you can still connect manually:

```sh
ssh -t user@ubuntu 'TERM=xterm-256color COLORTERM=truecolor ~/.local/bin/mu4e-inbox'
```

In that mode, links use the slower fallback path instead of the fast forwarded
local opener.

### macOS remote: `emacs: not found`

If the remote mail host is macOS and `mu4e-inbox` says `exec: emacs: not
found`, the SSH command is not seeing Homebrew's PATH.  Install/source the zsh
dotfiles on the Mac:

```sh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
source ~/dotfiles/install.sh
```

That adds a small `~/.zshenv` loader for `zsh/zshenv`, which prepends
`/opt/homebrew/bin` or `/usr/local/bin` for non-interactive SSH commands.

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
