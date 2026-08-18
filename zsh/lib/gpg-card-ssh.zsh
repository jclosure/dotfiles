# Card-aware ssh: when connecting to a known OpenPGP/YubiKey host, forward
# THIS machine's gpg-agent back so signing/decryption/auth happen on the
# physical card wherever you're actually sitting, for the duration of that
# SSH session - even if the target also has its own card plugged in. You
# can't touch hardware you're not standing next to, so "I'm ssh'd in" always
# means "use the client's card". A target's own card only ever matters for
# someone directly at ITS console, which never goes through this function at
# all - that's just default gpg-agent behavior, nothing to build.
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

  # If a control-master connection is already up for this host, forwarding
  # was already set up (or not) when it was established; just reuse it. (SSH
  # silently ignores -R on a connection that joins an existing master, so
  # re-deciding here wouldn't do anything anyway.)
  if command ssh -O check "$host" >/dev/null 2>&1; then
    command ssh "$host" "$@"
    return $?
  fi

  # No live master: learn the remote's standard agent-socket path (differs by
  # OS - /run/user/UID/gnupg on Linux, ~/.gnupg on macOS) so we know where to
  # bind our forward, then establish the connection with it from the start
  # (adding a forward to an already-multiplexed connection doesn't work).
  #
  # Non-interactive ssh commands don't source login-shell rc files, so on a
  # box where gpgconf only lives under Homebrew (not on the default PATH in
  # that context) it would silently fail to run at all - hence the explicit
  # PATH prefix, and checking the result actually looks like a path before
  # trusting it.
  local remote_std local_extra
  remote_std=$(command ssh -o ControlPath=none -o ConnectTimeout=5 "$host" \
    'PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; gpgconf --list-dirs agent-socket' \
    2>/dev/null)

  if [[ "$remote_std" != /* ]]; then
    # Couldn't determine the remote socket path - don't guess, just connect plainly.
    command ssh "$host" "$@"
  else
    local_extra="$(PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" gpgconf --list-dirs agent-extra-socket)"
    command ssh -o StreamLocalBindUnlink=yes -R "${remote_std}:${local_extra}" "$host" "$@"
  fi
}
