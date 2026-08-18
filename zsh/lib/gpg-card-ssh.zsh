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
  # OS - /run/user/UID/gnupg on Linux, ~/.gnupg on macOS) and kill any agent
  # of its own listening there, then establish the connection with the
  # forward included from the start (adding one to an already-multiplexed
  # connection doesn't work). Killing the remote agent first matters: on
  # macOS (and possibly elsewhere), StreamLocalBindUnlink silently fails to
  # take over a path an agent is actively listening on - a brand-new path
  # works fine, but replacing a live one doesn't - and that failure is silent
  # unless ExitOnForwardFailure is set, so without this the session would
  # quietly fall back to using the target's own local card instead of
  # yours. gpg-agent auto-restarts on its own next local invocation, so this
  # has no lasting effect once the forwarding session ends.
  #
  # Non-interactive ssh commands don't source login-shell rc files, so on a
  # box where gpgconf only lives under Homebrew (not on the default PATH in
  # that context) it would silently fail to run at all - hence the explicit
  # PATH prefix, and checking the result actually looks like a path before
  # trusting it.
  local remote_std local_extra
  remote_std=$(command ssh -o ControlPath=none -o ConnectTimeout=5 "$host" \
    'PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"; gpgconf --list-dirs agent-socket; gpgconf --kill gpg-agent' \
    2>/dev/null | sed -n 1p)

  if [[ "$remote_std" != /* ]]; then
    # Couldn't determine the remote socket path - don't guess, just connect plainly.
    command ssh "$host" "$@"
  else
    # Make sure OUR OWN agent is actually alive before offering its socket as
    # the forward target - it may not be, e.g. if this same machine was on
    # the receiving end of a forward (and thus had ITS agent killed by this
    # same logic) since the last time anything local touched gpg.
    PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" gpgconf --launch gpg-agent >/dev/null 2>&1
    local_extra="$(PATH="/opt/homebrew/bin:/usr/local/bin:$PATH" gpgconf --list-dirs agent-extra-socket)"
    command ssh -o StreamLocalBindUnlink=yes -o ExitOnForwardFailure=yes \
      -R "${remote_std}:${local_extra}" "$host" "$@"
  fi
}
