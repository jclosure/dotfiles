# Agent secrets

Shared CLI-agent credentials backed by the macOS Keychain. This Stow package contains only scripts and credential names; secret values never belong in this repository.

## Install

```sh
cd ~/dotfiles
stow agent-secrets
```

## Run an agent with credentials

```sh
with-agent-secrets -- pi
with-agent-secrets -- claude
with-agent-secrets -- codex
```

Load only a subset when practical:

```sh
with-agent-secrets --only GITHUB_TOKEN,GH_TOKEN -- gh auth status
```

The secrets exist only in the launched process and its descendants. They are not exported into every interactive shell.

## Manage values

```sh
agent-secret list
agent-secret set BRAVE_API_KEY
agent-secret delete BRAVE_API_KEY
```

`agent-secret get NAME` prints a value and should rarely be used. Avoid piping secrets into logs, clipboards, shell history, or agent context.

Variable-to-Keychain-account mappings live in `.config/agent-secrets/env-map`. Multiple environment variables may map to one Keychain item; currently `GITHUB_TOKEN` and `GH_TOKEN` share one value.

Keychain service name: `com.joelholder.agent-secrets`

## Adding a credential

1. Add `ENV_NAME=KEYCHAIN_ACCOUNT` to `.config/agent-secrets/env-map`.
2. Restow or reload the existing symlinked package if needed.
3. Run `agent-secret set ENV_NAME` and enter the value at the Keychain prompt.
4. Test with `with-agent-secrets --only ENV_NAME -- your-command`.

## Security notes

- Prefer provider OAuth when available.
- Use separate, least-privilege tokens for unrelated services.
- Restart shells and long-running agents after removing old exported values; a child process cannot clean its parent's environment.
- Rotate credentials after migrating them from plaintext or after accidental disclosure.
- macOS Keychain protects storage at rest, but processes running as the same logged-in user may still inherit or request credentials. Use a separate OS account or stronger sandbox for hostile workloads.
- Do not add `auth.json`, `.env`, session logs, credential exports, or secret values to this public repository.
