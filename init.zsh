DOTFILES=${0:a:h}

# PROMPT
PROMPT='%{$fg_bold[white]%}%M ${ret_status} %{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)'
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:$PATH


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
# zplug "robbyrussell/oh-my-zsh", use:"lib/clipboard.zsh" # integrate zsh clipboard into system clipboard
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


# LOAD OTHER STUFF

# keybindings for ~/.oh-my-zsh/lib/clipboard.zsh
source $DOTFILES/clipboard_wrapper.zsh

