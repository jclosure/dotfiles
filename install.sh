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

ZSH_THEME=""

plugins=(
    git
    common-aliases
)

source "$ZSH/oh-my-zsh.sh"


# our prompt overrides omz
DOTFILES_ROOT=${0:a:h}
source "$DOTFILES_ROOT/zsh/init.zsh"
