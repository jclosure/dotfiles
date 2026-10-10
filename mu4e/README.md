# mu4e helpers

Mail is Gmail, read in Emacs with mu4e, in a terminal:

```text
Gmail --IMAP, mbsync--> ~/Mail on a mail host --mu index--> mu4e in Emacs
```

A **mail host** is a Mac or Linux machine that keeps a full copy of the
mailbox in `~/Mail` (see [Remote mail-host setup](#remote-mail-host-setup)).
Any machine, Windows included, can read from it over SSH, with links opening
in the local browser.

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

- Emacs + mu4e configured (`stow emacs-ide`)
- mu and isync: `sudo apt install maildir-utils mu4e isync` on Linux,
  `brew install mu isync` on a Mac
- `curl` available, used by Emacs to post URLs to the forwarded opener and
  for one-click unsubscribe
- this dotfiles repo checked out at `~/dotfiles`

Install on the remote mail host. The Gmail app password goes in a private
file, never in this repo (see [mbsync](../mbsync/README.md)):

```sh
mkdir -p ~/.config/mbsync
( umask 077; printf '%s' 'xxxx xxxx xxxx xxxx' > ~/.config/mbsync/gmail-password )
cd ~/dotfiles
stow mbsync mu4e
mbsync -l gmail          # logs in and lists folders, changes nothing
```

First sync and index:

```sh
mbsync -a
mu init --maildir ~/Mail --my-address you@gmail.com
mu index
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

## Keys

mu4e's own keys work as usual; these matter most. `M-s`, `M-u` and `W` are ours.

| Key | Does |
|---|---|
| `d` | Trash: moves to Gmail's Trash, which Gmail empties after 30 days |
| `r` | Archive (refile to All Mail): leaves the Inbox, kept for good |
| `D` | Delete. In Trash or Spam this deletes for good; elsewhere Gmail normally just archives it |
| `x` / `U` | Execute the marks / unmark everything |
| `g` | Pick a link in the message to open |
| `M-s` | Show all mail from this message's sender ([details](#unsubscribe-and-trash-all)) |
| `\` | Back to the previous search |
| `M-u` | Unsubscribe, then mark all of the sender's mail for trash ([details](#unsubscribe-and-trash-all)) |
| `W` | Open this message in Gmail ([details](#open-in-webmail)) |

mu4e syncs with Gmail every 5 minutes (`U` on its main screen syncs now).
Each mail host syncs on its own, so a change made on one shows up on another
after both have synced: up to about 10 minutes.

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
- characters a browser doesn't draw are removed: zero-width spaces and
  non-joiners (preheader padding, anti-autolink breaks like `I‌nc.`), the
  combining grapheme joiner, soft hyphens, word joiners, BOMs and emoji
  variation selectors. Terminal Emacs counts most as zero columns but draws a
  one-column placeholder (stray `_`), so lines holding them stuck out past
  their panel; U+FE0F makes the terminal draw an emoji wider than Emacs counts
  (this also covers shr's `⚠` suspicious-link warning). A zero-width joiner
  stays where it joins emoji
- newline characters carry no face: shr left cell colors on some line ends, and
  a terminal paints that position as one more cell, so those lines looked a
  column wider
- text with no background of its own joins the panel around it, and once a
  mail has panels, other plain text sits on the neutral surface (a browser's
  white page) instead of the darker theme background
- an image without alt text shows as `[image]` instead of shr's bare `*` (a
  linked one stays a link), and tracking pixels (1-2 px images a browser
  doesn't show either) show as nothing
- runs of blank lines collapse to one: fixed-height spacer cells and image rows
  otherwise spread an image-heavy mail (Pinterest, product feeds) over pages of
  empty lines; only whitespace-only lines are removed
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

## Unsubscribe and trash all

`M-u` in the headers list or an open message unsubscribes from the sender's
mailing list, then lists every synced message from that sender marked for
trash and asks mu4e's usual "execute N marks?". Answer `n` to keep them; `U`
unmarks. `C-u M-u` only unsubscribes.

It reads the message's `List-Unsubscribe` headers from the file (mu does not
index them) and uses the best method on offer:

- one-click (`List-Unsubscribe-Post: List-Unsubscribe=One-Click`, RFC 8058):
  a `curl` POST from the mail host, the same request Gmail's button sends
- `mailto:`: sends the requested unsubscribe mail through smtpmail
- a web link only: opens it in the browser through link forwarding

Mail in `/[Gmail]/Spam` is never unsubscribed, since that tells a spammer the
address is live; `M-u` there goes straight to trashing it. The trash search
lists every copy (Inbox, label folders, `/[Gmail]/All Mail`) so all of them
move to `/[Gmail]/Trash`.

Trash is recoverable: mu4e's trash moves mail to `/[Gmail]/Trash` without
the Trashed flag, and Gmail purges it after 30 days. (With the flag, which is
mu4e's default, Gmail deleted it for good at once.) `D` still deletes
outright. See `../mbsync` for the sync side.

`M-s` on a message shows all mail from its sender, archived mail included,
each message once (other people's messages in the same thread are left out);
`\` or `M-left` goes back to the previous search.

Tests: `emacs --batch -Q -l mu4e/tests/unsubscribe-test.el -f ert-run-tests-batch-and-exit`

## Open in webmail

A message view shows a `Web: Open in Gmail` line with the headers; click it,
press `RET` on it, or press `W` (headers list or view) to open the message in
the provider's web UI through `browse-url` (forwarded to the client's browser
over SSH). It is listed by `g` like any link in the mail.

Providers are entries in `my/mu4e-webmail-providers` (name, a predicate for
"this message is ours", a URL builder); the line only appears when one matches.
Gmail is the only one: a message counts as Gmail mail when it is in a
`/[Gmail]/` folder or the account's folders or address are Gmail's. Gmail has no
URL for a Message-ID, so the link is a search for `rfc822msgid:<id>`, which
lists exactly that message.


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
