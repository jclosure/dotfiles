DOTFILES=${0:a:h}

# UTF-8 LOCALE
# Some terminals (seen with cmux on macOS, and plain ssh sessions) start the
# shell with LANG unset, i.e. the C locale. zsh then can't expand $'\uXXXX'
# ("character not in range") -- which broke the prompt's Apple logo below --
# and zle mis-measures any non-ASCII text on the command line. zsh re-reads
# the locale as soon as these are assigned.
if [[ "${LC_ALL:-${LC_CTYPE:-$LANG}}" != *(UTF-8|utf-8|UTF8|utf8)* ]]; then
  export LANG=en_US.UTF-8
  [[ -n "$LC_ALL" ]] && export LC_ALL=en_US.UTF-8
  [[ -n "$LC_CTYPE" ]] && export LC_CTYPE=en_US.UTF-8
fi

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

## FZF SETUP
# Built from https://github.com/junegunn/fzf source (not a package manager) so the
# binary and shell integration always match; same self-bootstrap pattern as zplug above.
if [[ ! -x ~/.fzf/bin/fzf ]]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --bin --no-update-rc
fi
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# Vendored oh-my-zsh pieces (see zsh/lib/) — clipboard.zsh + git-prompt.zsh,
# no Oh-My-Zsh install required
source $DOTFILES/lib/clipboard.zsh
source $DOTFILES/lib/gpg-card-ssh.zsh

# Custom keybindings for system clipboard integration
source $DOTFILES/clipboard_wrapper.zsh

# Alt+Left/Right for word-wise cursor movement. zsh's default Meta-f/Meta-b
# already do this, but most terminal emulators send xterm-style CSI
# sequences for Alt+Arrow (ESC[1;3C / ESC[1;3D) rather than a bare ESC f /
# ESC b, so without these the arrow-key chord does nothing.
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word

# Region (Ctrl+Space mark) color, Emacs-style, same as the PowerShell setup:
# bright white on blue #264F78. zsh's default is reverse video, which is
# nearly the terminal's block-cursor color, so the character under the
# cursor lost its highlight. 24-bit where the terminal says it supports it,
# otherwise the nearest 256-color (zsh/nearcolor).
[[ "$COLORTERM" == (truecolor|24bit) ]] || zmodload zsh/nearcolor 2>/dev/null
zle_highlight=(region:fg=#ffffff,bg=#264f78)

# HOST-SPECIFIC CUSTOMIZATIONS
#
# This machine (pop-os) has gcc-14/libgcc-14-dev installed (C only) without
# g++-14 -- so /usr/lib/gcc/x86_64-linux-gnu/14 exists but has no C++
# standard library headers at all (/usr/include/c++/14 doesn't exist).
# The bare `gcc`/`g++`/`cc`/`c++` commands already correctly resolve to 13
# here (only the 13 packages provide those unversioned symlinks), so this
# doesn't change anything by itself -- it's a defensive/explicit pin for
# any tool that does look at $CC/$CXX, in case that ever changes (e.g. a
# future g++-14 install). It does NOT fix clangd specifically: clangd's own
# GCC-toolchain auto-detection ignores $CC/$CXX and defaults to the
# newest-numbered install it finds, landing on the broken 14 regardless --
# see emacs-ide/.emacs.d/cpp-demo/.clangd's explicit --gcc-install-dir for
# where that actually gets fixed.
case "$(hostname)" in
  pop-os)
    export CC=gcc-13
    export CXX=g++-13
    ;;
esac

# PROMPT
# Only apply ours (colors, git prompt segment, PROMPT) when no Oh-My-Zsh
# theme is selected (ZSH_THEME=""), so setting ZSH_THEME to a real theme
# name (see install.sh) overrides it cleanly instead of us clobbering that
# theme's own git-prompt styling/functions.
if [[ -z "$ZSH_THEME" ]]; then
  source $DOTFILES/lib/git-prompt.zsh

  # Nerd Font OS logo, matching the PowerShell prompt's Windows logo idea.
  # Codepoints used:
  #   Linux/Tux: U+F31A, macOS/Apple: U+F8FF (Apple's, not Nerd Font), BSD/Beastie: U+F28F,
  #   Windows: U+E62A (for zsh under MSYS/Cygwin/Git Bash).
  function _dotfiles_prompt_os_icon() {
    case "$(uname -s 2>/dev/null)" in
      Linux) print -r -- $'\uf31a ' ;;
      # Apple's own logo (U+F8FF), not the Nerd Font one: macOS fonts
      # (Monaco, Helvetica, SF) have it, so it shows in iTerm2 with a plain
      # font and in cmux via system fallback. It won't render when ssh'ing
      # in from Windows/Linux, whose fonts don't have it.
      Darwin) print -r -- $'\uf8ff ' ;;
      FreeBSD|OpenBSD|NetBSD|DragonFly) print -r -- $'\uf28f ' ;;
      CYGWIN*|MINGW*|MSYS*) print -r -- $'\ue62a ' ;;
    esac
  }
  DOTFILES_PROMPT_OS_ICON="$(_dotfiles_prompt_os_icon)"

  PROMPT='%{$fg_bold[blue]%}${DOTFILES_PROMPT_OS_ICON}%{$fg_bold[white]%}%M %(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )%{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)'
fi

# PATH CUSTOMIZATION
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:$PATH
