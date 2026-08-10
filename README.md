# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level
directory is a module; most are stow packages that get symlinked into
`$HOME`, but not all of them — see below.

## Modules

| Module  | Type          | What it does                                                                 |
|---------|---------------|-------------------------------------------------------------------------------|
| `emacs` | stow package  | [Chemacs2](https://github.com/plexus/chemacs2) (submodule) stowed to `~/.emacs.d`, plus `.emacs-profiles.el` stowed to `~/.emacs-profiles.el`. Chemacs2 is a profile switcher — see [Emacs profiles](#emacs-profiles) below. |
| `zsh`   | lib (not stowed) | Zsh enhancements — highlighted-text delete, cross-OS system clipboard integration. Its `.stow-local-ignore` excludes the whole directory from stow, so it's never symlinked; instead it's sourced directly from `~/.zshrc`. |

### Emacs profiles

Four Emacs profiles live under `emacs/`, selected via Chemacs2:

| Profile        | Source                                                              |
|----------------|----------------------------------------------------------------------|
| `minimal`      | `emacs/minimal/` — plain directory in this repo, near-stock Emacs. |
| `light`        | `emacs/light/` — plain directory in this repo, package.el + a few QoL packages. |
| `ide`          | `emacs/ide/` — submodule: [jclosure/vscode-flavored-emacs-2026](https://github.com/jclosure/vscode-flavored-emacs-2026). |
| `experimental` | `emacs/experimental/` — plain directory in this repo, scratch space for trying things out. |

None of the four are stowed into `$HOME` themselves (`emacs/.stow-local-ignore` excludes them) — Chemacs2 references them directly by their path in this checkout via `emacs/.emacs-profiles.el`. Plain `emacs` with no flags loads the `default` profile, aliased there to `ide` to match this repo's prior single-profile behavior. Switch explicitly with:

```sh
emacs --with-profile minimal
emacs --with-profile light
emacs --with-profile ide
emacs --with-profile experimental
```

or persist a different default with `echo minimal > ~/.emacs-profile`.

Want to add another profile? See [`emacs/README.md`](emacs/README.md#adding-another-profile).

## Installation

```sh
cd ~
git clone --recurse-submodules git@github.com:jclosure/dotfiles.git
cd dotfiles

# stow packages (symlinked into $HOME)
stow emacs

# zsh is a lib, not a stow package — install.sh installs Oh My Zsh if it's
# missing, then sources zsh/init.zsh
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```

Already cloned without `--recurse-submodules`? Run `git submodule update --init --recursive` instead.
