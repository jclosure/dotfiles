# dotfiles

Sane command-line with:

- delete highlighted text normally
- the Ctrl+Space region is highlighted bright white on blue (`#264F78`),
  Emacs-style, so the letter under the block cursor doesn't lose its
  highlight (zsh's default reverse video is nearly the cursor's color)
- system clipboard integration (for all oses)
- a Nerd Font OS logo in the prompt: Tux on Linux, Apple on macOS, Beastie on BSD
- a UTF-8 locale even when the terminal starts the shell with `LANG` unset
  (cmux does). In the C locale zsh can't expand the logo's `$'\uXXXX'`
  ("character not in range"), so the logo showed up broken.

Installation

```sh
cd ~
git clone git@github.com:jclosure/dotfiles.git
echo "source $HOME/dotfiles/init.zsh" >> ~/.zshrc
```
