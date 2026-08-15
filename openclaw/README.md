# OpenClaw dotfiles module

This GNU Stow module installs a reviewed set of portable OpenClaw preferences without committing the private, mutable contents of `~/.openclaw/`.

## Install

```sh
cd ~/dotfiles
stow openclaw
openclaw-dotfiles-apply
```

OpenClaw itself must be installed separately. The helper dry-runs the portable patch, applies it through OpenClaw's validated config command, and validates the resulting private configuration.

## Tracked

- `~/.openclaw/dotfiles/portable.json5`: portable model, session, tool, hook, and built-in-skill preferences
- `~/.local/bin/openclaw-dotfiles-apply`: safe patch and validation helper

The patch merges into the existing config. It does not replace `~/.openclaw/openclaw.json` or delete unrelated local settings.

## Never track

The live OpenClaw directory contains credentials, identity material, private conversations, browser profiles, personal files, and runtime databases. Never add any of these to the public dotfiles repository:

- `.env`, `openclaw.json`, backups, auth profiles, secret-provider state, or service environment files
- credentials, pairing data, channel identifiers, allowlists, device identity, or gateway tokens
- sessions, trajectories, memories, logs, queues, locks, caches, databases, or temporary files
- browser profiles, cookies, history, downloaded/inbound/outbound media, or generated previews
- the private workspace and its `AGENTS.md`, `IDENTITY.md`, `SOUL.md`, `USER.md`, `MEMORY.md`, work queues, projects, and artifacts
- plugins, npm dependencies, generated completions, installation state, or registry-managed skills

Cross-agent third-party skills remain managed under `~/.agents/skills/`. Compatibility links under `~/.openclaw/skills/` are installer-managed and are not part of this module.

## Updating portable preferences

Edit `.openclaw/dotfiles/portable.json5` in this module, review it for private values, run `openclaw-dotfiles-apply`, and commit only after a credential-pattern scan. Keep machine-local paths, account identifiers, messaging configuration, and network exposure settings out of the patch.
