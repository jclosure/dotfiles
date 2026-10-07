# dotfiles

My config for macOS, Linux and Windows. Each top-level directory is a
**module**. Most modules are [GNU Stow](https://www.gnu.org/software/stow/)
packages that get symlinked into your home directory. On Windows,
[`winstow.ps1`](winstow.ps1) does the same job.

- [Getting started](#getting-started)
- [Modules](#modules)
- [Day to day](#day-to-day)

---

## Getting started

### 1. Prerequisites

| macOS | Linux (Debian/Ubuntu/Pop!_OS) | Windows 11 |
|---|---|---|
| [Homebrew](https://brew.sh), then `brew install git stow` | `sudo apt install git stow curl` | See below |

**Windows only.** Run this in the built-in PowerShell, then do everything else
in **PowerShell 7**:

```powershell
winget install --id Git.Git -e
winget install --id Microsoft.PowerShell -e
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned               # lets winstow.ps1 and the profile run
[Environment]::SetEnvironmentVariable('HOME', $env:USERPROFILE, 'User')   # ~ means C:\Users\<you>
```

Also turn on **Developer Mode** (Settings → System → For developers) so
symlinks work without admin. Then open a new terminal.

### 2. Clone

```sh
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

Use `git@github.com:jclosure/dotfiles.git` if you'll push from this machine.
Already cloned without `--recurse-submodules`? Run
`git submodule update --init --recursive`. Only `emacs-ide` needs it.

### 3. Link the modules you want

From `~/dotfiles`, link one module at a time:

```sh
stow <module>              # macOS, Linux
.\winstow.ps1 <module>     # Windows
```

Some modules need an extra step after linking. Each module's README has the
details.

| Machine | Typical set | Then |
|---|---|---|
| **macOS** | `emacs-ide` `ghostty` `cmux` `herd` `claude-code` `pi` `agent-skills` `agent-secrets` `hermes` `openclaw` | zsh setup, `herd setup`, the `*-dotfiles-apply` helpers |
| **Linux** | `emacs-ide` `ghostty` `terminator` `herd` `claude-code` `pi` `agent-skills` `mu4e` | zsh setup, `herd setup`, `claude-code-dotfiles-apply` |
| **Windows** | `emacs-ide` `powershell` `herd` | [PowerShell setup](powershell/README.md), [herd setup](herd/README.md#windows) |

**zsh (macOS, Linux):** zsh isn't stowed. Source it instead:

```sh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```

**herd (all three):** herdr, the agent dashboard and Handy voice input. It has
its own prerequisites (herdr, Python), so follow
[herd → Setting up a new machine](herd/README.md#setting-up-a-new-machine).

---

## Modules

| Module | OS | What it does | Docs |
|---|---|---|---|
| `herd` | all | herdr set up the same everywhere: `herd` command, agent dashboard, per-OS herdr config, and Handy voice input (**Ctrl+Shift+Space**). `herd update` upgrades all of it. | [README](herd/README.md) |
| `emacs-ide` | all | Full Emacs IDE. `.emacs.d` is a submodule: [vscode-flavored-emacs-2026](https://github.com/jclosure/vscode-flavored-emacs-2026). | [upstream](https://github.com/jclosure/vscode-flavored-emacs-2026) |
| `emacs-light` | all | Emacs with package.el and a few quality-of-life packages. | |
| `emacs-minimal` | all | Near-stock Emacs, no third-party packages. | |
| `emacs-experimental` | all | Scratch space for trying things out. | |
| `zsh` | macOS, Linux | Zsh enhancements: selected-text delete, system clipboard, Oh My Zsh, iTerm2 profile. Sourced, not stowed. | [README](zsh/README.md) |
| `powershell` | Windows | PowerShell set up like Oh My Zsh: Oh My Posh prompt, posh-git, Emacs keys, fzf history search on Ctrl+R, gray history suggestions. | [README](powershell/README.md) |
| `ghostty` | macOS, Linux | Ghostty terminal config. | |
| `cmux` | macOS | cmux config. Kept at `0600` because cmux treats it as sensitive. This repo is public, so check it before committing if you set `socketPassword`. | |
| `terminator` | Linux | Terminator config: Ctrl+Alt+Arrow moves between panes; F1 passes through to the app. | |
| `claude-code` | all | `claude-code-dotfiles-apply` marks `$HOME` as trusted, so Claude Code stops asking. | [README](claude-code/README.md) |
| `pi` | all | Global Pi agent instructions. Contains no credentials or sessions. | |
| `agent-skills` | all | Personal skills under `~/.agents/skills`, used by Pi and Hermes. | [README](agent-skills/README.md) |
| `agent-secrets` | macOS | `agent-secret` and `with-agent-secrets`, backed by the Keychain. Only names are stored here. | [README](agent-secrets/README.md) |
| `hermes` | macOS, Linux | Hermes integration. Run `hermes-dotfiles-apply` after linking. | [README](hermes/README.md) |
| `openclaw` | macOS, Linux | Portable OpenClaw config patch. Run `openclaw-dotfiles-apply` after linking. | [README](openclaw/README.md) |
| `mu4e` | all | `check-mail` launchers for sh, PowerShell and cmd, plus helpers that open links from remote mu4e in your local browser. | [README](mu4e/README.md) |

The agent modules haven't been tried on Windows. Emacs on Windows works
except for mail, which needs mu/mu4e. Install it with `winget install GNU.Emacs`
and put its `bin` directory on `PATH`. The
[emacs-ide README](https://github.com/jclosure/vscode-flavored-emacs-2026#windows)
covers tree-sitter and LLVM.

---

## Day to day

**Update a machine** after pushing changes from another one:

```sh
git -C ~/dotfiles pull --ff-only
herd setup          # or `herd update`, which also upgrades herdr and Handy
```

**Switch Emacs configs.** All `emacs-*` modules link to `~/.emacs.d`, so only
one can be linked at a time. Unlink the current one first:

```sh
stow -D emacs-minimal && stow emacs-ide
.\winstow.ps1 -D emacs-ide -S emacs-minimal      # Windows, in one call
```

**Unlink a module:** `stow -D <module>`, or `.\winstow.ps1 -D <module>` on Windows.

**winstow** is a port of GNU Stow 2.4.1 to PowerShell. It takes the same
options (`-n -v` for a dry run, `--adopt`, `.stow-local-ignore`), creates the
same relative symlinks, and checks for conflicts before changing anything.
If it reports `existing target is not owned by stow`, delete that file, or
use `--adopt` to move it into the module.
