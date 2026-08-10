
cutbuffer () {
  emulate -L zsh
  zle kill-region
  zle set-mark-command -n -1
  killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
  if which clipcopy &>/dev/null; then
    printf "%s" "$CUTBUFFER" | clipcopy
  else
    echo "clipcopy function not found. Please make sure you have Oh My Zsh installed correctly."
  fi
}

copybuffer () {
  emulate -L zsh
  zle copy-region-as-kill
  zle set-mark-command -n -1
  killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
  if which clipcopy &>/dev/null; then
    printf "%s" "$CUTBUFFER" | clipcopy
  else
    echo "clipcopy function not found. Please make sure you have Oh My Zsh installed correctly."
  fi
}

pastebuffer () {
  if which clippaste &>/dev/null; then
    local pasted=$(clippaste)
    if [[ $pasted != $CUTBUFFER ]]; then
      CUTBUFFER=${pasted}
      killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
    fi
  else
    echo "clippaste function not found. Please make sure you have Oh My Zsh installed correctly."
  fi
  zle yank
}

zle -N copybuffer
zle -N pastebuffer
zle -N cutbuffer

bindkey '\ew'  copybuffer
bindkey '\eW'  copybuffer
bindkey '^Y'   pastebuffer
bindkey '^w'  cutbuffer


# `ESC o` to show these buffers any time during typing
function _showbuffers()
{
    local nl=$'\n' kr
    typeset -T kr KR $'\n'
    KR=($killring)
    typeset +g -a buffers
    buffers+="      Pre: ${PREBUFFER:-$nl}"
    buffers+="  Buffer: $BUFFER$nl"
    buffers+="     Cut: $CUTBUFFER$nl"
    buffers+="       L: $LBUFFER$nl"
    buffers+="       R: $RBUFFER$nl"
    buffers+="Killring:$nl$nl$kr"
    zle -M "$buffers"
}
zle -N showbuffers _showbuffers
bindkey "^[o" showbuffers
