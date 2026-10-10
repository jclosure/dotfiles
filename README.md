# dotfiles

My shell, terminal, editor and agent setup for **macOS**, **Linux** and
**Windows**.

**How to use this page:** find your operating system below and run the steps
in order. Every command can be copied and pasted as is. Where a step has more
to it, the link goes to the exact section in that module's README.

- [Set up a Mac](#set-up-a-mac)
- [Set up Linux](#set-up-linux)
- [Set up Windows](#set-up-windows)
- [Keep machines up to date](#keep-machines-up-to-date)
- [Read email](#read-email)
- [Control herdr](#control-herdr)
- [What each module is](#what-each-module-is)
- [Tips](#tips)

> **What "stow" means here.** Each folder in this repo is a *module*.
> `stow <module>` links that module's files into your home folder, so editing
> them edits this repo. On Windows, `.\winstow.ps1 <module>` does the same.
> Always run them from `~/dotfiles`.

---

## Set up a Mac

**1. Install Homebrew, git and stow.**

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git stow
```

**2. Get the dotfiles.**

```sh
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

**3. Set up zsh.** Installs Oh My Zsh if needed and loads our zsh settings.

```sh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
exec zsh
```

**4. Set up your terminal.** Link the ones you use:

```sh
cd ~/dotfiles
stow ghostty
stow cmux
```

Using iTerm2? Follow [zsh → iTerm2 profile](zsh/README.md#iterm2-profile-macos).

**5. Set up Emacs.** Install Emacs as described in the
[emacs-ide README](https://github.com/jclosure/vscode-flavored-emacs-2026), then:

```sh
cd ~/dotfiles
stow emacs-ide
```

**6. Set up herd** (agent dashboard and voice typing). Follow
[herd → macOS](herd/README.md#macos), steps 1–5.

**7. Optional: agent tools.** Install each tool first, then link its module:

```sh
cd ~/dotfiles
stow claude-code && claude-code-dotfiles-apply    # needs Claude Code run once
stow pi                                           # Pi agent instructions
stow agent-skills                                 # shared agent skills
stow agent-secrets                                # Keychain-backed agent credentials
stow hermes && hermes-dotfiles-apply              # needs Hermes installed
stow openclaw && openclaw-dotfiles-apply          # needs OpenClaw installed
```

---

## Set up Linux

These commands are for Debian, Ubuntu and Pop!_OS. On Fedora, use `dnf` in
place of `apt`.

**1. Install git, stow, curl and zsh.**

```sh
sudo apt update
sudo apt install git stow curl zsh
```

**2. Get the dotfiles.**

```sh
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

**3. Set up zsh.** If zsh isn't your shell yet, switch to it, then log out and
back in:

```sh
chsh -s "$(which zsh)"
```

Then load our zsh settings:

```sh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
exec zsh
```

**4. Set up your terminal.** Link the ones you use:

```sh
cd ~/dotfiles
stow ghostty
stow terminator
```

**5. Set up Emacs.** Install Emacs as described in the
[emacs-ide README](https://github.com/jclosure/vscode-flavored-emacs-2026), then:

```sh
cd ~/dotfiles
stow emacs-ide
```

**6. Set up herd** (agent dashboard and voice typing). Follow
[herd → Linux](herd/README.md#linux), steps 1–5.

**7. Optional: mail.** If this machine reads mail with mu4e, see
[mu4e → Modes](mu4e/README.md#modes) and link it with `stow mu4e`; on a
mail host, also `stow mbsync` (see [mbsync](mbsync/README.md) for the password
file).

**8. Optional: agent tools.** Install each tool first, then link its module:

```sh
cd ~/dotfiles
stow claude-code && claude-code-dotfiles-apply    # needs Claude Code run once
stow pi                                           # Pi agent instructions
stow agent-skills                                 # shared agent skills
stow hermes && hermes-dotfiles-apply              # needs Hermes installed
stow openclaw && openclaw-dotfiles-apply          # needs OpenClaw installed
```

---

## Set up Windows

**1. Turn on Developer Mode.** Settings → System → For developers →
**Developer Mode** on. This lets the dotfiles create links without admin rights.

**2. Install git and PowerShell 7.** Open **Windows PowerShell** (the
built-in one) and run:

```powershell
winget install --id Git.Git -e
winget install --id Microsoft.PowerShell -e
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
[Environment]::SetEnvironmentVariable('HOME', $env:USERPROFILE, 'User')
```

The last two lines let local scripts run and make `~` mean `C:\Users\<you>`.
Now close it and open **PowerShell 7** (Windows Terminal → PowerShell). Use
PowerShell 7 for every step after this one.

**3. Get the dotfiles.**

```powershell
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~\dotfiles
cd ~\dotfiles
```

**4. Set up PowerShell** (prompt, git status, Emacs keys, fzf history search):

```powershell
winget install JanDeDobbeleer.OhMyPosh
winget install junegunn.fzf
Install-Module posh-git, PSFzf -Scope CurrentUser
cd ~\dotfiles
.\winstow.ps1 powershell
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
Set-Content $PROFILE '. "$HOME\dotfiles\powershell\.config\powershell\profile.ps1"'
```

Then set Windows Terminal's default profile to PowerShell and its font to a
Nerd Font such as `JetBrainsMono NFM`. Those are steps 4–5 of
[powershell → Setup](powershell/README.md#setup), which also covers Windows
PowerShell 5.1 and VS Code's terminal.

**5. Set up Emacs.**

```powershell
winget install GNU.Emacs
$bin = (Get-ChildItem 'C:\Program Files\Emacs' -Directory -Filter 'emacs-*' | Sort-Object Name | Select-Object -Last 1).FullName + '\bin'
[Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path', 'User') + ";$bin", 'User')
cd ~\dotfiles
.\winstow.ps1 emacs-ide
```

Mail (mu4e) doesn't work on Windows. For tree-sitter and C/C++ support, see
[emacs-ide → Windows](https://github.com/jclosure/vscode-flavored-emacs-2026#windows).

**6. Set up herd** (agent dashboard and voice typing). Follow
[herd → Windows](herd/README.md#windows), steps 1–5.

The zsh, terminal and agent modules aren't used on Windows.

---

## Keep machines up to date

After you push a change from one machine, run this on each of the others:

```sh
git -C ~/dotfiles pull --ff-only
herd setup
```

`herd update` does the same and also upgrades herdr and Handy.

---

## Read email

Mail is Gmail, read in Emacs with mu4e, in a terminal.

```text
Gmail --IMAP, mbsync--> ~/Mail on a mail host --mu index--> mu4e in Emacs
```

A **mail host** is a Mac or Linux machine that keeps a full copy of the
mailbox in `~/Mail`. Any machine, Windows included, can read from a mail host
over SSH; links you open in mail then open in the browser on the machine
you're sitting at.

### Set up a mail host

1. Install mu (with mu4e) and isync: `sudo apt install maildir-utils mu4e
   isync` on Linux, `brew install mu isync` on a Mac. Emacs comes from step 5
   of your OS's setup above.
2. Put the Gmail app password in a private file (it never goes in this repo),
   then link the sync config and the mail launchers:

   ```sh
   mkdir -p ~/.config/mbsync
   ( umask 077; printf '%s' 'xxxx xxxx xxxx xxxx' > ~/.config/mbsync/gmail-password )
   cd ~/dotfiles && stow mbsync mu4e
   mbsync -l gmail          # logs in and lists folders, changes nothing
   ```

3. First sync and index: `mbsync -a && mu init --maildir ~/Mail
   --my-address you@gmail.com && mu index`.

Details: [mbsync](mbsync/README.md), [mu4e → Remote mail-host
setup](mu4e/README.md#remote-mail-host-setup).

### Open mail

| From | Run |
|---|---|
| the mail host itself | `check-mail.sh` |
| another Mac or Linux machine | `check-mail.sh --remote user@mailhost` |
| Windows | `check-mail.ps1 --remote user@mailhost` |

mu4e syncs with Gmail every 5 minutes (`U` on its main screen syncs now).
Each mail host syncs on its own, so a change made on one shows up on another
after both have synced: up to about 10 minutes.

### Keys

mu4e's own keys work as usual; these matter most, and the last five are ours.

| Key | Does |
|---|---|
| `d` | Trash: moves to Gmail's Trash, which Gmail empties after 30 days |
| `r` | Archive (refile to All Mail): leaves the Inbox, kept for good |
| `D` | Delete. In Trash or Spam this deletes for good; elsewhere Gmail normally just archives it |
| `x` / `U` | Execute the marks / unmark everything |
| `g` | Pick a link in the message to open |
| `M-s` | Show all mail from this message's sender |
| `\` | Back to the previous search |
| `M-u` | Unsubscribe from this sender's list, then mark all their mail for trash (`C-u M-u`: only unsubscribe). Never unsubscribes from Spam. |
| `W` | Open this message in Gmail (also the `Web:` link in the headers) |

HTML mail is drawn to read well in a dark terminal: colored sections become
solid panels, invisible padding characters are removed, and images without
text show as `[image]`. Nothing visible is dropped. See [mu4e → HTML email
readability](mu4e/README.md#html-email-readability).

---

## Control herdr

[herdr](https://herdr.dev) runs every coding agent in its own pane, inside
workspaces and tabs, and keeps them running when you disconnect. The `herd`
module sets it up the same way on every OS ([herd](herd/README.md)).

**Start and come back**

| Run or press | Does |
|---|---|
| `herd` | Starts herdr if needed and opens the `shepherd` dashboard, which lists every agent with its status |
| **F1**, or **Ctrl+B** then `a` | Back to the dashboard from anywhere |
| `herdr` | Attach to the running session without opening the dashboard |
| `herd doctor` | Check the install and config when something looks wrong |
| `herd setup` | Rewrite the config from this repo and reload herdr |

**Move around**

| Key | Does |
|---|---|
| **Alt+1…9** | Jump to agent N |
| **Alt+Shift+↑ / ↓** (or **Ctrl+B** then **Alt+k / Alt+j**) | Previous / next agent |
| **Shift+←/↓/↑/→** | Move to the pane in that direction, windmove-style as in Emacs (replaces herdr's default **Ctrl+B** then `h/j/k/l`) |
| **Ctrl+B** then `w` | Open the workspace list (↑↓ or Ctrl+P/N to move) |
| **Ctrl+B** then **Shift+R** | Reload the config |

**Start work from the dashboard:** type a task and press Enter to start a new
agent on it; `/who` and `/where` pick the kind of agent and its directory. Every
line typed there that isn't a command starts a real agent, so to restart the
dashboard press Ctrl+C in it and run `herd dash`, rather than sending it text.
The full key list is in [herd → Using the dashboard](herd/README.md#using-the-dashboard).

**From the command line or a script**, `herdr` controls the running session:

```sh
herdr workspace list              # workspaces
herdr agent list                  # agents and their state
herdr agent read <id>             # an agent's recent output
herdr agent prompt <id> "..."     # give an agent a prompt
herdr agent wait <id> --until done  # wait for a state (repeat --until)
herdr pane read <id>              # any pane's output
herdr server reload-config        # what herd setup does after writing config
```

Every group (`workspace`, `tab`, `pane`, `agent`) has `--help`.

---

## What each module is

| Module | Used on | What it sets up | More |
|---|---|---|---|
| `herd` | Mac, Linux, Windows | Agent dashboard for herdr, and voice typing with Handy (**Ctrl+Shift+Space**) | [README](herd/README.md) |
| `emacs-ide` | Mac, Linux, Windows | Full Emacs IDE (a git submodule) | [README](https://github.com/jclosure/vscode-flavored-emacs-2026) |
| `emacs-light` `emacs-minimal` `emacs-experimental` | Mac, Linux, Windows | Lighter Emacs configs. Use one `emacs-*` at a time. | [Tips](#switch-emacs-configs) |
| `zsh` | Mac, Linux | Prompt, clipboard, selected-text delete, Oh My Zsh | [README](zsh/README.md) |
| `powershell` | Windows | Oh My Zsh–style PowerShell | [README](powershell/README.md) |
| `ghostty` | Mac, Linux | Ghostty terminal | |
| `cmux` | Mac | cmux terminal | |
| `terminator` | Linux | Terminator terminal | |
| `claude-code` | Mac, Linux | Stops Claude Code's folder-trust prompt in `$HOME` | [README](claude-code/README.md) |
| `pi` | Mac, Linux | Pi agent instructions | |
| `agent-skills` | Mac, Linux | Skills shared by Pi and Hermes | [README](agent-skills/README.md) |
| `agent-secrets` | Mac | Agent credentials stored in the Keychain | [README](agent-secrets/README.md) |
| `hermes` | Mac, Linux | Hermes settings | [README](hermes/README.md) |
| `openclaw` | Mac, Linux | OpenClaw settings | [README](openclaw/README.md) |
| `mu4e` | Mac, Linux, Windows | Mail-check launchers for mu4e | [README](mu4e/README.md) |
| `mbsync` | Mac, Linux | Gmail IMAP sync config (`~/.mbsyncrc`) | [README](mbsync/README.md) |

---

## Tips

### Switch Emacs configs

All `emacs-*` modules use `~/.emacs.d`, so only one can be linked at a time.
Unlink the current one, then link the new one:

```sh
cd ~/dotfiles
stow -D emacs-minimal && stow emacs-ide                # Mac, Linux
.\winstow.ps1 -D emacs-minimal -S emacs-ide            # Windows
```

### Unlink a module

```sh
cd ~/dotfiles
stow -D <module>                # Mac, Linux
.\winstow.ps1 -D <module>       # Windows
```

### When stow refuses

If stow says a file **already exists** or is **not owned by stow**, a real
file is in the way, and nothing has been changed. Move or delete that file and
run the command again. To keep your file instead, add `--adopt`, which moves
it into the module.

To preview what stow will do without changing anything, add `-n -v`.

### Cloned without submodules?

```sh
git -C ~/dotfiles submodule update --init --recursive
```

Only `emacs-ide` needs this.

### Notes for editing this repo

- `cmux`'s config is kept private (`0600`) because cmux treats it as
  sensitive. This repo is public, so check it before committing if you've set
  `socketPassword`.
- `winstow.ps1` is a port of GNU Stow 2.4.1 to PowerShell. It takes the same
  options and creates the same relative links.
