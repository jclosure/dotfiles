#!/usr/bin/env zsh
#
# Installs Oh My Zsh (if not already present), then sources this repo's
# zsh/init.zsh into the current shell.
#
# Note: nothing in zsh/ actually requires Oh My Zsh anymore — the pieces it
# used to provide (system clipboard integration, git-aware prompt) are
# vendored in zsh/lib/ and sourced directly by init.zsh. This script exists
# for anyone who still wants OMZ itself available for its own themes/plugins.
#
# Intended to be sourced, typically from ~/.zshrc:
#
#   echo "source $HOME/dotfiles/install.sh" >> ~/.zshrc.bak


if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
fi

export ZSH="$HOME/.oh-my-zsh"

DOTFILES_ROOT=${0:a:h}

# Ensure non-interactive zsh sessions, e.g. `ssh host command`, get the
# minimal dotfiles environment too.  This is where macOS/Homebrew PATH setup
# belongs; ~/.zshrc is not read for those sessions.
_dotfiles_zshenv_source="source \"$DOTFILES_ROOT/zsh/zshenv\""
if [[ -f "$DOTFILES_ROOT/zsh/zshenv" ]]; then
  touch "$HOME/.zshenv"
  if ! grep -Fqx -- "$_dotfiles_zshenv_source" "$HOME/.zshenv"; then
    {
      echo ""
      echo "# dotfiles: minimal setup for non-interactive zsh/ssh sessions"
      echo "$_dotfiles_zshenv_source"
    } >> "$HOME/.zshenv"
  fi
fi
unset _dotfiles_zshenv_source

ZSH_THEME=""

plugins=(
    git
    common-aliases
)

source "$ZSH/oh-my-zsh.sh"


# our prompt overrides omz
source "$DOTFILES_ROOT/zsh/init.zsh"

# Ghostty sends TERM=xterm-ghostty over ssh. Hosts that don't know it make
# zle redraw wrong (repeated chars, leftover partial text), so compile the
# definition into ~/.terminfo on first login wherever it's missing.
if (( $+commands[tic] )) && ! infocmp xterm-ghostty &>/dev/null; then
  tic -x "$DOTFILES_ROOT/ghostty/xterm-ghostty.terminfo" 2>/dev/null && export TERM=$TERM  # re-read by zle
fi
