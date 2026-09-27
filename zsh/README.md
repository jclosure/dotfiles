# dotfiles

Sane command-line with:

- delete highlighted text normally
- the Ctrl+Space region is highlighted bright white on blue (`#264F78`),
  Emacs-style, so the letter under the block cursor doesn't lose its
  highlight (zsh's default reverse video is nearly the cursor's color)
- system clipboard integration (for all oses)
- an OS logo in the prompt: Tux on Linux and Beastie on BSD (Nerd Font
  glyphs, so the terminal needs a Nerd Font; Ghostty and cmux have them
  built in), and on macOS Apple's own logo (U+F8FF). Mac fonts like Monaco
  and Helvetica include that one, so it shows in iTerm2, cmux and Terminal
  with no Nerd Font setup. It won't render when you ssh into the Mac from
  Windows or Linux, because their fonts don't have it.
- a UTF-8 locale even when the terminal starts the shell with `LANG` unset
  (cmux does). In the C locale zsh can't expand the logo's `$'\uXXXX'`
  ("character not in range"), so the logo showed up broken.

Installation

```sh
cd ~
git clone git@github.com:jclosure/dotfiles.git
echo "source $HOME/dotfiles/init.zsh" >> ~/.zshrc
```
