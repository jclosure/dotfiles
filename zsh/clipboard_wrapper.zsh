# OSC 52 is the terminal clipboard protocol.  It is what Herdr and Emacs
# use to copy through an SSH PTY to the terminal on the other side.  Keep the
# existing clipcopy call too: it preserves the host-local clipboard behavior
# (pbcopy, wl-copy, tmux, etc.) and remains the fallback when OSC 52 is not
# accepted by the outer terminal.
_osc52_copy () {
  emulate -L zsh

  # Do not change ordinary local shells.  In particular, this keeps local
  # Herdr/macOS behavior exactly as it was; only an SSH session needs the
  # extra hop to the terminal on which the user is sitting.
  [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_TTY:-}" ]] || return 0
  [[ -w /dev/tty ]] || return 0
  (( $+commands[base64] )) || return 0

  local encoded
  encoded=$(printf '%s' "$1" | base64 | tr -d '\r\n') || return 0
  printf '\e]52;c;%s\a' "$encoded" > /dev/tty
}

_clip_copy () {
  _osc52_copy "$1"
  if which clipcopy &>/dev/null; then
    printf "%s" "$1" | clipcopy
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
