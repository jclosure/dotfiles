# Hermes dotfiles module

This GNU Stow module installs portable Hermes Agent integration without committing credentials, private messaging identifiers, memories, sessions, or runtime state.

## Install

```sh
cd ~/dotfiles
stow hermes
hermes-dotfiles-apply
```

Hermes itself must be installed separately. Its installer-managed binaries, virtual environments, desktop application, and source checkout remain under `~/.hermes/` and are not managed by this module.

## Managed behavior

`hermes-dotfiles-apply` configures Hermes to read cross-agent skills from:

```text
~/.agents/skills
```

Hermes continues to manage bundled, registry-installed, and Hermes-authored skills under:

```text
~/.hermes/skills
```

## Deliberately not tracked

Do not add these to the public dotfiles repository:

- `~/.hermes/.env`
- `~/.hermes/auth.json`
- `~/.hermes/config.yaml` as a whole
- sessions, memories, pairing data, messaging routes or channel identifiers
- databases, logs, caches, checkpoints, cron state, process state
- `~/.hermes/hermes-agent/`, virtual environments, binaries, or desktop builds
- bundled/registry-managed `~/.hermes/skills` content

`config.yaml` is mutable and may contain private platform identifiers even though API keys are normally stored in `.env`. The apply script changes only the portable `skills.external_dirs` key using Hermes' own YAML parser and atomic writer.

## Skills

Personal cross-agent skills belong in the separate `agent-skills` Stow module:

```text
~/dotfiles/agent-skills/.agents/skills/
```

Pi discovers `~/.agents/skills` automatically. Hermes discovers it through `skills.external_dirs`. There is no standard `~/.agent` singular directory in this setup.
