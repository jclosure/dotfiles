# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a module; most are stow packages that get symlinked into
`$HOME`, but not all of them — see below.

## Modules

| Module            | Type          | What it does                                                                 |
|--------------------|---------------|-------------------------------------------------------------------------------|
| `emacs-minimal`    | stow package  | Symlinks `.emacs.d` into `$HOME`. Near-stock Emacs, no third-party packages.  |
| `emacs-light`      | stow package  | Symlinks `.emacs.d` into `$HOME`. package.el + a few quality-of-life packages. |
| `emacs-ide`        | stow package  | Symlinks `.emacs.d` into `$HOME`. `.emacs.d` is a submodule: [jclosure/vscode-flavored-emacs-2026](https://github.com/jclosure/vscode-flavored-emacs-2026). |
| `emacs-experimental` | stow package | Symlinks `.emacs.d` into `$HOME`. Scratch space for trying things out.       |
| `zsh`              | lib (not stowed) | Zsh enhancements — highlighted-text delete, cross-OS system clipboard integration. Its `.stow-local-ignore` excludes the whole directory from stow, so it's never symlinked; instead it's sourced directly from `~/.zshrc`. |
| `cmux`             | stow package  | Symlinks `.config/cmux` into `$HOME`. **Note:** `cmux.json` is stored with `0600` perms locally since cmux treats it as sensitive; this repo is public, so double-check it before committing if you ever set `socketPassword` or similar. |
| `ghostty`          | stow package  | Symlinks `.config/ghostty` into `$HOME`. |
| `terminator`       | stow package (Linux) | Symlinks `.config/terminator` into `$HOME`. Ctrl+Alt+Arrow pane focus; F1 unbound from Terminator help so it passes through to the app. Edits made in Terminator's Preferences dialog write through the symlink into this repo. |
| `pi`               | stow package  | Symlinks global Pi agent instructions under `.pi/agent/`. Credentials, sessions, caches, and machine-local settings remain untracked. |
| `agent-skills`     | stow package  | Installs personal cross-agent skills under `.agents/skills`; Pi discovers them directly and Hermes reads them as an external skill directory. |
| `claude-code`      | stow package  | Installs `claude-code-dotfiles-apply`, which marks `$HOME` (or given folders) as trusted in `~/.claude.json` so Claude Code stops showing the folder-trust prompt. The config file itself is never tracked. See [`claude-code/README.md`](claude-code/README.md). |
| `hermes`           | stow package  | Installs a safe Hermes integration helper without tracking `.env`, mutable/private configuration, memories, sessions, databases, or runtime state. |
| `openclaw`         | stow package  | Installs a reviewed portable OpenClaw config patch and apply helper while excluding credentials, identities, conversations, browser data, workspaces, and runtime state. |
| `powershell`       | stow package (Windows) | Oh My Zsh-style PowerShell 7 (also works in 5.1): Oh My Posh `robbyrussell` prompt with Windows logo + hostname, plain `ls` (directories bold blue), posh-git, Emacs keys, fzf history search on Ctrl-r, fish-like gray history suggestions (like zsh-autosuggestions). Stow with `winstow`; `$PROFILE` is a one-line loader (see [`powershell/README.md`](powershell/README.md)). |
| `mu4e`             | stow package (Ubuntu/Linux/Windows client) | Installs `mu4e-inbox` on the Ubuntu mail host plus Windows launchers that SSH in, open the Inbox, sync, and forward HTML email links back to the local browser. See [`mu4e/README.md`](mu4e/README.md). |
| `agent-secrets`    | stow package  | Installs macOS Keychain-backed `agent-secret` and `with-agent-secrets` utilities plus a version-controlled environment-variable map containing names only. |
| `herd`             | stow package (macOS, Linux, Windows) | herdr set up identically everywhere: `herd` command + agent dashboard, generated per-OS herdr config, and Handy push-to-talk voice (installed and configured per OS, including the Wayland desktop shortcut on Linux; press **Ctrl+Shift+Space** on every OS to start recording and again to type the text). Run `herd setup` after stowing; `herd update` upgrades everything. See [`herd/README.md`](herd/README.md). |

### Switching Emacs configs

All four `emacs-*` modules symlink to the same target, `~/.emacs.d`, so
only one can be stowed at a time — stow refuses (safely; it aborts before
touching the filesystem) if you try to stow a second one on top of an
active one. Switch by unstowing the current one first:

```sh
stow -D emacs-minimal      # deactivate current
stow emacs-ide             # activate another
```

or in one step:

```sh
stow -D emacs-minimal && stow emacs-ide
```

## Installation

```sh
cd ~
git clone --recurse-submodules git@github.com:jclosure/dotfiles.git
cd dotfiles

# pick one emacs-* module (see table above)
stow emacs-ide

# terminal setup
stow cmux
stow ghostty
stow terminator   # Linux
# iTerm2 (macOS): Nerd symbol fonts, then import zsh/Development.json as the
# default profile. See zsh/README.md "iTerm2 profile"
brew install --cask font-symbols-only-nerd-font

# global Pi agent instructions (never credentials or session history)
stow pi

# personal skills shared by compatible agents
stow agent-skills

# Claude Code: trust $HOME so the folder-trust prompt stops appearing
stow claude-code
claude-code-dotfiles-apply

# safe Hermes integration; then apply portable settings
stow hermes
hermes-dotfiles-apply

# safe OpenClaw integration; then apply portable settings
stow openclaw
openclaw-dotfiles-apply

# mu4e helper launcher on the Ubuntu mail host
stow mu4e

# shared agent credentials (values remain in macOS Keychain)
stow agent-secrets

# herdr + dashboard + voice (Windows: .\winstow.ps1 herd)
stow herd
herd setup

# zsh is a lib, not a stow package — install.sh installs Oh My Zsh if it's
# missing, then sources zsh/init.zsh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```

Already cloned without `--recurse-submodules`? Run `git submodule update --init --recursive` instead (only needed for `emacs-ide`, the only module with a submodule).

### Windows

Quick start for a fresh Windows 11 machine. The main shell is PowerShell 7,
which gets installed first from the built-in Windows PowerShell 5.1. Everything
below also works in 5.1.

**1. One-time prerequisites**

```powershell
# Symlinks without admin: Settings → System → For developers → Developer Mode = On

# PowerShell 7; then open it (Windows Terminal → PowerShell) for the rest
winget install Microsoft.PowerShell

# Allow local scripts (winstow.ps1, the profile) to run
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Make ~ mean C:\Users\<you> for Emacs and friends (otherwise %APPDATA%)
[Environment]::SetEnvironmentVariable('HOME', $env:USERPROFILE, 'User')

# Then open a new terminal and clone
cd ~
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git
cd dotfiles
```

**2. winstow: stow for Windows**

GNU Stow doesn't run natively on Windows. [`winstow.ps1`](winstow.ps1) is a
PowerShell port of Stow 2.4.1 that takes the same options and behaves the
same way: ignore files, `.stowrc`, tree folding, conflict checks,
`--adopt`, `--dotfiles`. It creates the same relative symlinks. It was
tested against the real stow source and gave identical results.

```powershell
.\winstow.ps1 emacs-ide                       # stow emacs-ide
.\winstow.ps1 -n -v emacs-ide                 # dry run: show what it would do
.\winstow.ps1 -D emacs-ide -S emacs-minimal   # switch in one step; aborts before touching anything on conflict
```

PowerShell 7 also accepts `.\winstow.ps1 -D emacs-ide && .\winstow.ps1 emacs-minimal`.
Windows PowerShell 5.1 has no `&&`, so use the single call above there. As with stow, winstow won't
replace files or links it doesn't own. It reports `existing target is not
owned by stow`: remove the file first, or use `--adopt` to move it into
the package.

**3. Emacs**

```powershell
winget install GNU.Emacs
# add C:\Program Files\Emacs\emacs-<version>\bin to your user PATH
.\winstow.ps1 emacs-ide
```

On Windows, `emacs-ide` works except for mail: mu/mu4e has no Windows
build, so the config skips it. Tree-sitter grammars need a C compiler, and
C/C++ support needs LLVM. See the Windows section of the
[emacs-ide README](https://github.com/jclosure/vscode-flavored-emacs-2026#windows).

**4. PowerShell that feels like Oh My Zsh**

The `powershell` module sets up an Oh My Posh `robbyrussell` prompt with a
Windows logo and the hostname, plain `ls` (only directories colored), git
completion, Emacs keys, and fzf history search on Ctrl-r. Full details are in
[`powershell/README.md`](powershell/README.md).

```powershell
winget install JanDeDobbeleer.OhMyPosh
winget install junegunn.fzf
Install-Module posh-git, PSFzf -Scope CurrentUser

.\winstow.ps1 powershell
Set-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'   # loader; $PROFILE is under OneDrive, which doesn't sync symlinks
```

Run these in **PowerShell 7**. `$PROFILE` and the module folders differ per
shell, so if you also use Windows PowerShell 5.1, repeat the `Install-Module`
and `Set-Content` lines there (5.1 also needs a newer PSReadLine; see the
module README).
In Windows Terminal, make **PowerShell** (7) the default profile, and set the
font to a Nerd Font by its v3 short name, for example `JetBrainsMono NFM`.
Otherwise the prompt's Windows logo shows as a box. Do the same for VS Code's
terminal, which has its own font setting: `"terminal.integrated.fontFamily": "JetBrainsMono NFM"`.

**Which modules apply on Windows:** `emacs-*` and `powershell`. `zsh`,
`cmux`, `ghostty`, `terminator` and `agent-secrets` (macOS Keychain) are for mac/linux
only. The agent modules haven't been tried on Windows.
