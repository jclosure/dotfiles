DOTFILES=${0:a:h}

# PRE-REQUISITES CHECK
if ! command -v git &> /dev/null; then
  echo "Git is not installed. Please install Git to use this Zsh configuration."
  return  
fi

if ! command -v curl &> /dev/null;  then
  echo "Curl is not installed. Please install Curl to use this Zsh configuration."
  return  
fi

## ZPLUG SETUP
# Check if zplug is installed
if [[ ! -d ~/.zplug ]]; then
  git clone https://github.com/zplug/zplug ~/.zplug
  source ~/.zplug/init.zsh && zplug update --self
fi

# Load Zplug Init file
source ~/.zplug/init.zsh
zplug "zplug/zplug"                      # Manage zplug in the same way as any other packages<Paste>

zplug "jamesob/desk"                      # Desk shell plugin
zplug "zsh-users/zsh-autosuggestions"    #  fish-like autosuggestion for zsh
zplug "knu/zsh-delsel-mode", use:delsel-mode

# zplug romkatv/powerlevel10k, as:theme, depth:1 # powerlevel10k
# zplug "Valiev/almostontop"               # Almost On Top
# zplug "weizard/assume-role"              # AWS Assume-Role support

# Install packages that have not been installed yet
if ! zplug check --verbose; then
  printf "Install? [y/N]: "
  if read -q; then
    echo; zplug install
  else
    echo
  fi
fi

# Source plugins & add commands to $PATH
zplug load

# LOCAL CUSTOMIZATIONS

# Vendored oh-my-zsh pieces (see zsh/lib/) — clipboard.zsh + git-prompt.zsh,
# no Oh-My-Zsh install required
source $DOTFILES/lib/clipboard.zsh
source $DOTFILES/lib/git-prompt.zsh

# Custom keybindings for system clipboard integration
source $DOTFILES/clipboard_wrapper.zsh

# PROMPT
PROMPT='%{$fg_bold[white]%}%M %(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )%{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)'

# PATH CUSTOMIZATION
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:$PATH
