# mbsync

[mbsync](https://isync.sourceforge.io/) (isync) syncs Gmail over IMAP into
`~/Mail`, where mu indexes it for mu4e (see `../mu4e`). This module holds the
one `~/.mbsyncrc` every mail host uses.

## Install

The Gmail app password is never in this repo. Each machine keeps it in a
private file, without a trailing newline:

```sh
mkdir -p ~/.config/mbsync
( umask 077; printf '%s' 'xxxx xxxx xxxx xxxx' > ~/.config/mbsync/gmail-password )
cd ~/dotfiles && stow mbsync
```

Check it logs in (lists folders, changes nothing):

```sh
mbsync -l gmail
```

mu4e runs `mbsync -a` itself (`mu4e-get-mail-command`).

## Choices

- **All folders, All Mail included.** Archived mail exists only in
  `[Gmail]/All Mail`, and it is mu4e's refile folder.
- **`Expunge Both`.** A message deleted on one side is really removed, on both.
  Without it, mail trashed on one machine stays on the others with only the
  Trashed flag, which mu4e shows struck through, indefinitely.
- **Trash stays recoverable.** mu4e's trash (from `emacs-ide`, "Gmail-safe
  trash") moves mail to `[Gmail]/Trash` without the Trashed flag, so
  `Expunge Both` never touches it and Gmail keeps it for its usual 30 days.
  Only mu4e's `D` (delete) removes mail outright.
- **`SSLType`, no `CertificateFile`.** Works on isync 1.4 (Ubuntu) and 1.5
  (Homebrew, which prints a harmless "SSLType is deprecated" notice; 1.4 does
  not know `TLSType`), using each OS's own CA store.
