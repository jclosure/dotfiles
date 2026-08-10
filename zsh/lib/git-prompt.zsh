# Trimmed, self-contained vendoring of oh-my-zsh's color/git-prompt support,
# MIT licensed. Sources:
#   https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/theme-and-appearance.zsh
#   https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/git.zsh
#   https://github.com/ohmyzsh/ohmyzsh/blob/master/themes/robbyrussell.zsh-theme
# Vendored 2026-08-10 — only what init.zsh's PROMPT needs: the $fg/$fg_bold/
# $reset_color color arrays, and a synchronous git_prompt_info. Deliberately
# drops OMZ's async-prompt path (_omz_register_handler, add-zsh-hook, etc.),
# since that machinery lives in oh-my-zsh.sh itself, not in these library
# files, and isn't needed for a plain synchronous prompt.

# Sets color variables $fg, $fg_bold, $bg, $color and $reset_color
autoload -U colors && colors

# Expand $(...) and variables in PROMPT
setopt prompt_subst

# Git prompt segment styling (colors match the robbyrussell theme this was
# originally paired with)
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"

# The git prompt's git commands are read-only and shouldn't interfere with
# other processes, hence GIT_OPTIONAL_LOCKS=0 (see git(1)).
function __git_prompt_git() {
  GIT_OPTIONAL_LOCKS=0 command git "$@"
}

# Echoes $ZSH_THEME_GIT_PROMPT_DIRTY if the working tree has changes, else
# $ZSH_THEME_GIT_PROMPT_CLEAN
function parse_git_dirty() {
  local STATUS
  STATUS=$(__git_prompt_git status --porcelain --ignore-submodules=dirty 2>/dev/null | tail -n 1)
  if [[ -n $STATUS ]]; then
    echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
  else
    echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
  fi
}

# Outputs the current branch/tag/SHA wrapped in the prefix/suffix above, or
# nothing when outside a git repo
function git_prompt_info() {
  local ref
  __git_prompt_git rev-parse --git-dir &>/dev/null || return 0
  ref=$(__git_prompt_git symbolic-ref --short HEAD 2>/dev/null) \
    || ref=$(__git_prompt_git describe --tags --exact-match HEAD 2>/dev/null) \
    || ref=$(__git_prompt_git rev-parse --short HEAD 2>/dev/null) \
    || return 0
  echo "${ZSH_THEME_GIT_PROMPT_PREFIX}${ref//\%/%%}$(parse_git_dirty)${ZSH_THEME_GIT_PROMPT_SUFFIX}"
}
