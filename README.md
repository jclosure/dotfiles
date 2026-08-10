# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a module; most are stow packages that get symlinked into
`$HOME`, but not all of them — see below.

## Modules

| Module  | Type          | What it does                                                                 |
|---------|---------------|-------------------------------------------------------------------------------|
| `emacs` | stow package  | Symlinks `.emacs.d` (`init.el`, `early-init.el`) into `$HOME`.                |
| `zsh`   | lib (not stowed) | Zsh enhancements — highlighted-text delete, cross-OS system clipboard integration. Its `.stow-local-ignore` excludes the whole directory from stow, so it's never symlinked; instead it's sourced directly from `~/.zshrc`. |

## Installation

```sh
cd ~
git clone git@github.com:jclosure/dotfiles.git
cd dotfiles

# stow packages (symlinked into $HOME)
stow emacs

# zsh is a lib, not a stow package — install.sh installs Oh My Zsh if it's
# missing, then sources zsh/init.zsh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```
