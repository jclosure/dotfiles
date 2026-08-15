# Shared agent skills module

This GNU Stow module installs personal, version-controlled Agent Skills under the cross-agent standard path:

```text
~/.agents/skills
```

Install with:

```sh
cd ~/dotfiles
stow agent-skills
```

Consumers:

- Pi discovers `~/.agents/skills` automatically.
- Hermes is configured by the `hermes` module to include it as an external, read-only skill directory.
- Other Agent Skills-compatible tools can be pointed at the same directory.

Do not copy vendor-managed skill bundles into this module. Keep personal skills reviewable, portable, and free of credentials or private data. Update the Home Lab **Agent skills catalog** whenever a skill is created, substantially changed, renamed, installed, or removed.
