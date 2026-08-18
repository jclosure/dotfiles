# Card-aware ssh: when connecting to a known OpenPGP/YubiKey host, forward
# THIS machine's gpg-agent back so signing/decryption/auth happen on the
# physical card wherever you're actually sitting -- but only if the target
# doesn't already have its own card plugged in. A machine with its own card
# always wins for its own local work; forwarding never overrides that.
#
# Add new hosts to the case pattern below as they join the setup. Anything
# not listed there falls straight through to plain ssh, untouched.
#
# `command ssh` is used throughout to bypass this function itself (avoids
# recursion) and to reach the real binary from scripts/non-interactive shells
# that never source this file in the first place.

ssh() {
  local host="$1"
  case "$host" in
    ubuntu.local|ubuntu|loops-mac-mini.local|pop-os.local|pop-os) ;;
    *) command ssh "$@"; return $? ;;
  esac
  shift

  # If a control-master connection is already up for this host, its forwarding
  # state (or lack of it) was already decided when it was established; just
  # reuse it. (SSH silently ignores -R on a connection that joins an existing
  # master, so re-deciding here wouldn't do anything anyway.)
  if command ssh -O check "$host" >/dev/null 2>&1; then
    command ssh "$host" "$@"
    return $?
  fi

  # No live master: decide once, before establishing the connection that
  # becomes the master. -o ControlPath=none keeps this probe off the shared
  # socket so it can never itself become (or block) that master.
  #
  # Non-interactive ssh commands don't source login-shell rc files, so on a
  # box where gpg/gpgconf only live under Homebrew (not on the default PATH
  # in that context) they'd silently fail to run at all - hence the explicit
  # PATH prefix below, and the line-count sanity check afterward rather than
  # trusting positional output blindly.
  local probe remote_std has_card local_extra nlines
  probe=$(command ssh -o ControlPath=none -o ConnectTimeout=5 "$host" \
    'PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; gpgconf --list-dirs agent-socket; gpg --card-status >/dev/null 2>&1 && echo HAS_CARD || echo NO_CARD' \
    2>/dev/null)
  nlines=$(print -r -- "$probe" | wc -l | tr -d ' ')
  remote_std=$(print -r -- "$probe" | sed -n 1p)
  has_card=$(print -r -- "$probe" | sed -n 2p)

  if [[ "$nlines" != "2" || "$remote_std" != /* || "$has_card" == "HAS_CARD" ]]; then
    # Remote already has its own card, or the probe didn't come back looking
    # like we expect (unreachable, PATH/tooling missing, etc.) - either way,
    # don't touch its agent socket.
    command ssh "$host" "$@"
  else
    local_extra="$(PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" gpgconf --list-dirs agent-extra-socket)"
    command ssh -o StreamLocalBindUnlink=yes -R "${remote_std}:${local_extra}" "$host" "$@"
  fi
}
