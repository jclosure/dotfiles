# dotfiles

Sane command-line with:

- delete highlighted text normally
- the Ctrl+Space region is highlighted bright white on blue (`#264F78`),
  Emacs-style, so the letter under the block cursor doesn't lose its
  highlight (zsh's default reverse video is nearly the cursor's color)
- system clipboard integration (for all oses)
- a Nerd Font OS logo in the prompt: Tux on Linux, Apple on macOS, Beastie on BSD
  The logo needs a Nerd Font in the terminal. Ghostty and cmux have the
  symbols built in; iTerm2 doesn't (see below).

## iTerm2 profile (macOS)

`Development.json` here is the iTerm2 profile to import on a new Mac:
Monaco 16, with **Symbols Nerd Font Mono 16 for non-ASCII text** and
iTerm's Nerd Font mapping (`Special Font Config`, icon ranges → `SymbolsNF`),
so the prompt's Apple logo and other Nerd Font icons render.

1. Install the fonts it refers to. `SymbolsNFM` (Symbols Nerd Font Mono) and
   `SymbolsNF` (Symbols Nerd Font):

   ```sh
   brew install --cask font-symbols-only-nerd-font
   ```

   (Or: iTerm's own Nerd Font bundle, offered in Settings → Profiles → Text,
   installs `SymbolsNF` into `~/Library/Application Support/iTerm2/Fonts/`,
   and GUI Emacs from `emacs-ide` installs `SymbolsNFM` as `NFM.ttf` on first
   start.)
2. iTerm2 → Settings → Profiles → "Other Actions…" (under the profile list)
   → **Import JSON Profiles…** → `~/dotfiles/zsh/Development.json`.
3. Select **Development** → "Other Actions…" → **Set as Default**.

If you change the profile in iTerm, re-export it over this file ("Other
Actions…" → Save Profile as JSON). Left out on purpose: the `Triggers` iTerm
3.7 adds by itself (its built-in agent "workgroup" triggers). Without the
non-ASCII font, iTerm draws the logo as blank or a box: macOS won't fall back
to a Nerd Font for those private-use characters.
- a UTF-8 locale even when the terminal starts the shell with `LANG` unset
  (cmux does). In the C locale zsh can't expand the logo's `$'\uXXXX'`
  ("character not in range"), so the logo showed up broken.

Installation

```sh
cd ~
git clone git@github.com:jclosure/dotfiles.git
echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc
```

`install.sh` also adds a small loader to `~/.zshenv` so non-interactive zsh
sessions, such as `ssh host command`, source `zsh/zshenv`.  That file performs
minimal Homebrew PATH setup on macOS so commands installed by brew are visible
to remote launchers.
