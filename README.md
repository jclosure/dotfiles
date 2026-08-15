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
| `pi`               | stow package  | Symlinks global Pi agent instructions under `.pi/agent/`. Credentials, sessions, caches, and machine-local settings remain untracked. |
| `agent-skills`     | stow package  | Installs personal cross-agent skills under `.agents/skills`; Pi discovers them directly and Hermes reads them as an external skill directory. |
| `hermes`           | stow package  | Installs a safe Hermes integration helper without tracking `.env`, mutable/private configuration, memories, sessions, databases, or runtime state. |
| `openclaw`         | stow package  | Installs a reviewed portable OpenClaw config patch and apply helper while excluding credentials, identities, conversations, browser data, workspaces, and runtime state. |
| `agent-secrets`    | stow package  | Installs macOS Keychain-backed `agent-secret` and `with-agent-secrets` utilities plus a version-controlled environment-variable map containing names only. |

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

# global Pi agent instructions (never credentials or session history)
stow pi

# personal skills shared by compatible agents
stow agent-skills

# safe Hermes integration; then apply portable settings
stow hermes
hermes-dotfiles-apply

# safe OpenClaw integration; then apply portable settings
stow openclaw
openclaw-dotfiles-apply

# shared agent credentials (values remain in macOS Keychain)
stow agent-secrets

# zsh is a lib, not a stow package — install.sh installs Oh My Zsh if it's
# missing, then sources zsh/init.zsh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```

Already cloned without `--recurse-submodules`? Run `git submodule update --init --recursive` instead (only needed for `emacs-ide`, the only module with a submodule).
