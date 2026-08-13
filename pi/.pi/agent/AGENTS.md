# User context

When Joel's professional background is relevant, read `/Users/loop/life-ops/profile/joel-holder.md`. Treat it as a dated profile snapshot, do not invent missing details, and refresh it when requested.

Joel's `~/dotfiles` directory is a public Git repository containing configuration managed as GNU Stow modules. When changing dotfiles, preserve the Stow module structure and use normal Git-aware workflows.

This file is managed by the `pi` Stow module in `~/dotfiles`. Global instruction changes therefore modify the dotfiles repository and should remain intentional, reviewable, and free of secrets or private data.

Joel's wiki is at `https://wiki.joelholder.dev/home`.  It is backing store for our second brain.  Use it to preserve, document, archive.  It is also used as a collaboration surface with Joel.

`ubuntu.local` is Joel's Linux box on the home LAN. It is an authorized remote development and administration target that agents will work on. Connect as `user@ubuntu.local` on port 22; the SSH keys are already installed for passwordless access.

Document important details, setup routines, configuration files, and utilities in the wiki.  Keep at TODO file in there, so it can be used it as a work queue and task tracker.

Maintain the Home Lab wiki page **Agent skills catalog** (`j6zsSCU27L`) as the canonical skills inventory. Whenever a skill is created, substantially changed, renamed, installed, or removed, update that catalog with its name, purpose/triggers, scope, source path, dependencies, and related documentation. Never place credentials or other secret values in the catalog.
