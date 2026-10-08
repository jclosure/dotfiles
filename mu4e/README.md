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

The `emacs-ide` config preserves HTML colors so headings, body text, and
colored sections remain distinguishable, while asking SHR to correct
low-contrast foreground/background pairs more aggressively:

- `shr-use-colors`: `t`
- `shr-color-visible-distance-min`: `10` (default: `5`)
- `shr-color-visible-luminance-min`: `60` (default: `40`)

HTML-supplied backgrounds are remapped to a curated, muted Catppuccin-Mocha
palette: neutral white/gray becomes a dark surface, while colored backgrounds
keep a rose, peach, green, teal, blue, mauve, or pink hue family. This avoids
the usual gray-on-white mail styling without flattening visual distinctions.
HTML structure, links, and image behavior are unchanged; colors baked into
images cannot be overridden. Mail envelope headers (From/Subject/etc.) remain
theme-controlled.

Restart Emacs after updating the config, then reopen the message.
The `my/mu4e-readable-html-colors` advice around `shr-insert-document` binds
these settings only for a render originating in `mu4e-view-mode`, including
SHR's temporary table-cell buffers. EWW and other SHR consumers are unaffected.
The background palette is applied through the same dynamic render scope, so it
also covers table cells. On terminal Emacs, the config removes SHR's `:extend t`
from background faces; otherwise the terminal paints colored lines beyond the
actual mail block. Re-evaluating the new block removes old advice.

### Solid color panels in the terminal

SHR paints a background only under the text it draws, so in a terminal a
colored section looks like a stack of lines of different lengths.  After SHR
renders a mail part, `my/mm-shr-clean-layout` (advice around `mm-shr`) squares
each colored section off into a panel:

- table-cell padding, which SHR draws as one stretched `:align-to` character,
  becomes real spaces in the cell's color, so cells are solid rectangles
- every line of a section is padded with its color to one shared right edge
- gaps between runs of one color take that color; blank lines between lines of
  one panel are filled, and a blank line between two panels takes, column by
  column, the color the lines above and below share, continuing the enclosing
  panel's color where they differ (so the email's page background shows
  instead of a dark theme-colored stripe)
- blank stripes at most two columns wide with one color on both sides take that
  color: shr indents each nested table a column or two, which exposes the
  email's full-width wrapper tables (often `#fff`) as thin vertical stripes
  through a section that a browser would draw flush
- a panel's left edge is evened out: a line whose panel color starts up to three
  columns later than the rest of the panel (a notch at its top-left corner) is
  filled back to the edge
- mu4e's link numbers (`[1]` after a URL in the text, added after shr lays out
  the mail) take their width out of the line's trailing padding, so the line
  still ends at the panel's edge
- shr's suspicious-link warning (`⚠` plus the emoji selector U+FE0F) is reduced
  to the plain one-column `⚠`; terminals draw the emoji form two columns wide
- the email's color goes in front of named faces that carry a background
  (`shr-h5`/`shr-h6` inherit `default`, which otherwise shows the theme
  background behind every word of a heading)
- contrast correction keeps the palette background and adjusts only the text
  (`shr-color-visible` with a fixed background), so panels stay dark and theme
  link colors stay readable on them
- in terminal Emacs, SHR's copy of each table's images after the table is
  dropped; the alt text already shows inside the cell

It also fills mail to the window width (at most `my/mail-html-max-width`, 100
columns) and drops `aria-hidden` content such as hidden preheader text.

Examples and background:

- [Gnus FAQ: HTML mail contrast](https://www.gnu.org/software/emacs/manual/html_node/gnus/FAQ-4_002d16.html)
- [Tassilo Horn's 10/60 configuration](https://yhetil.org/emacs-user/877g3cfnwp.fsf@gnu.org/)
- [shrface: Org-style HTML headings and links, with visual examples](https://github.com/chenyanming/shrface)
  (optional; not installed by this change)

Regression tests (no live mailbox or mu4e installation required):

```sh
emacs --batch -Q -l mu4e/tests/html-colors-test.el -f ert-run-tests-batch-and-exit
```

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
