# Claude Code dotfiles module

This GNU Stow module installs a helper that marks folders as trusted in Claude Code, so the "Do you trust the files in this folder?" prompt stops appearing.

## Install

```sh
cd ~/dotfiles
stow claude-code
claude-code-dotfiles-apply            # trusts $HOME
claude-code-dotfiles-apply ~/src ...  # or any other folders
```

Claude Code must be installed and started at least once first, so that `~/.claude.json` exists.

## Why a script instead of a tracked file

Claude Code saves trust per path in `~/.claude.json` as `projects["<path>"].hasTrustDialogAccepted`. Accepting the prompt in the home directory only lasts for that session and is never saved. Setting the flag directly makes it stick.

`~/.claude.json` also holds OAuth account data, caches, and per-project history, so it is never tracked in this public repository. The script changes only the trust flag and writes the file atomically, keeping its `0600` permissions.

Close every running `claude` session before running it. A running session can write its in-memory copy back over the change when it exits. If the prompt comes back, run the script again.

## Caveat

The trust prompt exists so a repository can't run its own hooks, MCP servers, or `.claude/` settings without your consent. If Claude Code also applies trust to subfolders, trusting `$HOME` covers everything under it, including freshly cloned repositories.
