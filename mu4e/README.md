# mu4e helpers

This stow package installs helpers for the remote Ubuntu mu4e setup.

## Ubuntu mail host

From `~/dotfiles` on the Ubuntu machine:

```sh
stow mu4e
```

That creates:

```text
~/.local/bin/mu4e-inbox -> ~/dotfiles/mu4e/.local/bin/mu4e-inbox
```

Usage on Ubuntu:

```sh
mu4e-inbox
```

It starts terminal Emacs, opens mu4e, opens the Inbox, and immediately kicks
off a mail sync/index update.

## Windows client launcher

On Windows, stow/winstow this package so these scripts are available under
`~/.local/bin`:

```powershell
./winstow.ps1 mu4e
~/.local/bin/mu4e-ubuntu.ps1
```

`mu4e-ubuntu.ps1` starts a tiny localhost-only URL opener on the Windows
machine, then SSHes to Ubuntu with a reverse port forward:

```text
Ubuntu Emacs -> 127.0.0.1:8765 on Ubuntu -> SSH reverse forward ->
Windows 127.0.0.1:8765 -> Start-Process URL
```

That makes HTML email links such as `View messages` open quickly in the local
Windows browser without a new SSH login for each click. The helper listens only
on `127.0.0.1`; it is not exposed to the LAN.

The `.cmd` launcher delegates to the PowerShell launcher:

```cmd
%USERPROFILE%\.local\bin\mu4e-ubuntu.cmd
```

## macOS/Linux client launcher

On Unix-like clients, stow this package and run:

```sh
~/.local/bin/mu4e-ubuntu.sh
```

By default it connects to `user@ubuntu`. Override that either by passing the
SSH target as the first argument or by setting `MU4E_UBUNTU_HOST`:

```sh
~/.local/bin/mu4e-ubuntu.sh user@ubuntu
MU4E_UBUNTU_HOST=user@ubuntu.local ~/.local/bin/mu4e-ubuntu.sh
```

The launcher starts a tiny localhost-only URL opener on the Mac/Linux client
and reverse-forwards it into the Ubuntu SSH session, just like the Windows
launcher. It chooses a random high port per session to avoid stale-port
collisions; set `MU4E_URL_OPENER_PORT` if you need a fixed port. HTML email
links such as `View messages` should open quickly in the local browser without
holding Ctrl.

## Generic SSH usage

Without the Windows launcher/forwarder, you can still connect manually:

```sh
ssh -t ubuntu 'TERM=xterm-256color COLORTERM=truecolor ~/.local/bin/mu4e-inbox'
```

SSH keepalives should be configured in the client-side `~/.ssh/config` for the
`ubuntu` host.
