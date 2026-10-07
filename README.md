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
[mu4e → Modes](mu4e/README.md#modes) and link it with `stow mu4e`.

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
