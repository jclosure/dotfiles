# mu4e helpers

This stow package installs `mu4e-inbox`, a small launcher for the remote
Ubuntu mail setup.

## Install on Ubuntu

From `~/dotfiles` on the Ubuntu machine:

```sh
stow mu4e
```

That creates:

```text
~/.local/bin/mu4e-inbox -> ~/dotfiles/mu4e/.local/bin/mu4e-inbox
```

Make sure `~/.local/bin` is on `PATH`, or run it by full path.

## Usage

```sh
mu4e-inbox
```

It starts terminal Emacs, opens mu4e, opens the Inbox, and immediately kicks
off a mail sync/index update.

From another machine, connect and launch it with a TTY:

```sh
ssh -t ubuntu 'TERM=xterm-256color COLORTERM=truecolor ~/.local/bin/mu4e-inbox'
```

The Windows/macOS/Linux wrapper scripts can simply run that command from any
local directory. SSH keepalives should be configured in the client-side
`~/.ssh/config` for the `ubuntu` host.
