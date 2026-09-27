# herd

[herdr](https://herdr.dev) set up the same way on Windows, macOS and Linux:
a shared config, an agent dashboard, and push-to-talk voice input.

`herd` is one Python 3 script (`.local/bin/herd`, plus a `herd.cmd` shim for
Windows). It is **not** the upstream [Shepherd](https://github.com/ryonakae/shepherd)
daemon/plugin; the two coexist. The dashboard workspace is still labelled
`shepherd` because that's the name we navigate by.

| Command       | What it does |
|---------------|--------------|
| `herd`        | Start the herdr server if needed, open (or create) the `shepherd` workspace running the dashboard, attach. |
| `herd dash`   | Run the dashboard in the current herdr pane. |
| `herd focus`  | Jump to the dashboard workspace, creating it if missing. Bound to **F1** and **prefix a** in herdr. |
| `herd setup`  | Write herdr's config for this OS, reload the running server (and print its answer), and apply the portable Handy settings. Safe to re-run. Does not open the dashboard: run `herd` or press F1. |
| `herd update` | `git pull --ff-only` the dotfiles, re-run setup, `herdr update`, and upgrade Handy (Windows; Handy updates itself on macOS). |
| `herd doctor` | Show paths, versions, and whether config/voice are in sync. |

## Layout

```
herd/
  .local/bin/herd        # the script (stowed into ~/.local/bin)
  .local/bin/herd.cmd    # Windows shim: python "%~dp0herd"
  herdr/base.toml        # shared herdr config (no [terminal] table)
  herdr/<os>.toml        # per-OS additions: windows sets default_shell = "pwsh.exe"
  voice/handy.json       # portable Handy settings: "all" + per-OS shortcut
```

Only `.local/bin` is stowed. `herd setup` reads `herdr/` and `voice/` straight
from this directory.

### Why the herdr config is generated, not symlinked

herdr has no config includes or per-OS sections. Windows needs
`default_shell = "pwsh.exe"` (herdr falls back to `$SHELL`, then `/bin/sh`),
and macOS/Linux must leave it unset. `herd setup` joins `base.toml` and
`<os>.toml` into herdr's `config.toml`, backing up any different existing
file as `config.toml.bak-<unix time>`, then reloads a running server.
**Edit the files here, not the generated config.**

| OS      | herdr config | Dashboard state |
|---------|--------------|-----------------|
| Windows | `%APPDATA%\herdr\config.toml` | `%LOCALAPPDATA%\herd\state.json` |
| macOS   | `~/.config/herdr/config.toml` | `~/.local/state/herd/state.json` |
| Linux   | `~/.config/herdr/config.toml` | `~/.local/state/herd/state.json` |

## Voice (Handy)

[Handy](https://handy.computer) does local speech-to-text: hold the shortcut,
speak, release, and the text is typed into whatever has focus (the dashboard's
task prompt, an agent pane, anything). Nothing in herdr needs to know about it.

`herd setup` installs Handy if it's missing (`winget install cjpais.Handy` or
`brew install --cask handy`), then merges `voice/handy.json` into Handy's
`settings_store.json`. It stops and restarts Handy around the edit, because
Handy rewrites that file on exit. Only the keys listed are touched.

| OS      | Push-to-talk | Why |
|---------|--------------|-----|
| Windows | `ctrl+space`   | Handy's default. |
| macOS   | `option+space` | `ctrl+space` is macOS's input-source switcher. |

Per machine, once: open Handy, pick a model, and grant microphone access (plus
Accessibility on macOS so it can type), then run `herd setup` again. Model
files and API keys are never stored here.

## Install

macOS / Linux:

```sh
cd ~/dotfiles && stow herd
herd setup
herd
```

Windows (Developer Mode on, for symlinks):

```powershell
cd ~\dotfiles; .\winstow.ps1 herd
herd setup
herd
```

`~/.local/bin` must be on `PATH`. herdr itself installs from
[herdr.dev](https://herdr.dev) and updates with `herdr update`.

## Dashboard keys

Type a task and press Enter to start an agent on it. Up/Down then Enter, or
`<number>` Enter, jumps to an agent. Tab cycles the working directory.
`/who <kind>`, `/where <path>`, `/x <number>` closes, `?` shows help, and
Ctrl+C quits.

Every line that isn't a command starts a real agent. Don't script input into
the dashboard pane with `herdr pane send-text`; restart it with Ctrl+C and
then `herd dash`.
