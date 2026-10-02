# Over SSH, clipcopy only reaches the *remote* machine's clipboard (pbcopy,
# clip.exe, ...) or none at all.  OSC 52 asks the terminal you're actually
# sitting at to set its clipboard instead; herdr forwards it and Ghostty
# accepts it, so the copy lands on the local machine.  Always sent, not just
# when $SSH_CONNECTION is set: a shell in a herdr/tmux server that was started
# outside ssh doesn't have it, and locally it's harmless (same clipboard).
_osc52_copy () {
  printf '\e]52;c;%s\a' "$(printf "%s" "$1" | base64 | tr -d '\n')" > /dev/tty
}

_clip_copy () {
  _osc52_copy "$1"
  if which clipcopy &>/dev/null; then
    printf "%s" "$1" | clipcopy 2>/dev/null
  else
    echo "clipcopy function not found. Make sure zsh/lib/clipboard.zsh was sourced."
  fi
}

cutbuffer () {
  emulate -L zsh
  zle kill-region
  zle set-mark-command -n -1
  killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
  _clip_copy "$CUTBUFFER"
}

copybuffer () {
  emulate -L zsh
  zle copy-region-as-kill
  zle set-mark-command -n -1
  killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
  _clip_copy "$CUTBUFFER"
}

pastebuffer () {
  if which clippaste &>/dev/null; then
    local pasted=$(clippaste)
    if [[ $pasted != $CUTBUFFER ]]; then
      CUTBUFFER=${pasted}
      killring=("$CUTBUFFER" "${(@)killring[1,-2]}")
    fi
  else
    echo "clippaste function not found. Make sure zsh/lib/clipboard.zsh was sourced."
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
