# herd

**herd** makes [herdr](https://herdr.dev), the terminal workspace manager for
coding agents, look and behave the same on Windows, macOS and Linux, and adds
voice input. After setup, every machine has:

- **An agent dashboard.** A herdr workspace called `shepherd` lists every agent
  in the session with its status: working, blocked, done or idle. Type a task
  there to start a new agent on it, or pick an agent to jump into it.
  **F1** brings you back from anywhere.
- **The same herdr config.** Theme, keys, tab bar and agent panel come from
  this repo; only what really differs per OS is kept separate.
- **Push-to-talk voice.** [Handy](https://handy.computer) turns speech into
  text on your own machine, with no audio sent anywhere. It types into
  whatever has focus: the dashboard's task prompt, an agent pane, anything.
- **One command to upgrade it all:** `herd update`.

herd is a single Python script. It is **not** the upstream
[Shepherd](https://github.com/ryonakae/shepherd) background process and herdr
plugin. The two can run side by side, and the Mac does. The dashboard
workspace keeps the name `shepherd` only because that's the name we're used to.

---

## Quick start

| | macOS | Linux | Windows |
|---|---|---|---|
| 1. Get the dotfiles | `git clone --recurse-submodules git@github.com:jclosure/dotfiles.git ~/dotfiles` | same | same, in PowerShell |
| 2. Link herd | `cd ~/dotfiles && stow herd` | `cd ~/dotfiles && stow herd` | `cd ~\dotfiles; .\winstow.ps1 herd` |
| 3. Configure | `herd setup` | `herd setup` | `herd setup` |
| 4. Voice, first time | Finish Handy's first-run setup, then `herd setup` again | same | same |
| 5. Use it | `herd` | `herd` | `herd` |

That's it. Details, prerequisites and per-OS notes follow.

### Prerequisites

| | macOS | Linux | Windows |
|---|---|---|---|
| herdr | [herdr.dev](https://herdr.dev) (lands in `~/.local/bin`) | same | same (installs to `%LOCALAPPDATA%\Programs\herdr`) |
| Python 3.8+ | Homebrew `python` | system `python3` | [python.org](https://www.python.org) or `winget install Python.Python.3.14` |
| Linking tool | `brew install stow` | `sudo apt install stow` | `winstow.ps1` in this repo; turn on **Developer Mode** (Settings → System → For developers) so it can create symlinks |
| `~/.local/bin` on `PATH` | yes | yes (`~/.profile` adds it) | yes (`%USERPROFILE%\.local\bin`) |
| Package manager for Handy | Homebrew | apt or dnf; uses `sudo` | winget |

On Windows, `herd` is available in PowerShell, cmd and Git Bash.

---

## Commands

| Command | What it does |
|---|---|
| `herd` | Starts the herdr server if it isn't running, opens the `shepherd` workspace (creating it with the dashboard in it if needed), and attaches. Inside herdr it just jumps to the dashboard. |
| `herd dash` | Runs the dashboard in the current herdr pane. |
| `herd focus` | Jumps to the dashboard, creating it if it's missing. Bound to **F1** and **prefix, then `a`**. |
| `herd setup` | Writes this machine's herdr config and asks the running server to reload it, printing the server's answer. Also installs and configures Handy (see [Voice](#voice)). Safe to run as often as you like. It does **not** open the dashboard; run `herd` or press F1 for that. |
| `herd update` | `git pull --ff-only` the dotfiles, re-runs `herd setup` with the new code, runs `herdr update`, and upgrades Handy. |
| `herd doctor` | Shows the Python in use, where herdr and its config are, whether the config is in sync, the Handy install and shortcut, and on Linux the desktop session and Wayland shortcut. Run this first when something looks wrong. |

## Using the dashboard

```
  (all-seeing eye)          7  agents
                            1  working
                            0  blocked
                            6  ready

                            who claude
                            where ~/projects/rag
 blog · 1
›  1 ● homepage-redesign     3m  2h  claude   Homepage redesign
 ...
› write a task · #N jump · ↑↓ enter · /who /where /x · ? help
```

| Input | Does |
|---|---|
| a task, then Enter | Starts a new agent of kind **who** in directory **where**, in its own tab, and gives it the task. |
| ↑ / ↓, then Enter | Selects an agent and jumps to it. |
| `<number>` Enter or `#<number>` Enter | Jumps to agent N. |
| Tab | Cycles **where** through directories that agents already use. |
| `/who <kind>` | Sets the agent kind: `claude`, `codex`, `pi`, … |
| `/where <path>` | Sets the working directory for new agents. |
| `/x <number>` | Closes that agent's pane. |
| `?` | Toggles help. Esc clears the input. |
| Ctrl+C or `/q` | Quits the dashboard. `herd dash` restarts it. |

Getting around herdr:

| Key | Does |
|---|---|
| **F1**, or **prefix, then `a`** | Back to the dashboard. |
| **Alt+1…9** | Jump straight to agent N. |
| **prefix, then Alt+j / Alt+k** | Next / previous agent. |

The prefix is herdr's default, **Ctrl+B**. The top bar shows `F1 ◂ shepherd`
as a reminder.

> **Careful:** every line typed into the dashboard that isn't a command starts
> a real agent. Never script input into it with `herdr pane send-text`. To
> restart it, press Ctrl+C in its pane and run `herd dash`.

---

## Voice

Hold the shortcut, speak, then let go (or tap it once to start and again to
stop). Handy transcribes on your machine and types the text where your cursor
is. That's usually the dashboard's task prompt or an agent's input box, and
nothing is submitted until you press Enter.

| OS | Shortcut | How it's triggered |
|---|---|---|
| Windows | **Ctrl+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut |
| macOS | **Option+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut. Ctrl+Space is macOS's input-source switcher. |
| Linux, X11 | **Ctrl+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut; text typed with `xdotool` |
| Linux, Wayland | **Ctrl+Space**: tap to start, tap again to stop | Wayland doesn't let apps grab global keys, so the **desktop** runs `handy --toggle-transcription`. `herd setup` adds this shortcut to **COSMIC** automatically. On GNOME or KDE it prints the one shortcut to add by hand. Text is typed with `wtype`. |

### What `herd setup` does for voice

1. **Installs Handy if it's missing:**
   - Windows: `winget install cjpais.Handy`
   - macOS: `brew install --cask handy`
   - Linux: downloads the latest `.deb` or `.rpm` from
     [Handy's releases](https://github.com/cjpais/Handy/releases) and installs
     it with `sudo apt-get` or `sudo dnf`, along with `wtype` (Wayland) or
     `xdotool` (X11). Your desktop session is read from the user systemd
     manager, so this works even when you run it over SSH.
2. **Linux on Wayland:** adds the desktop shortcut described above.
3. **The first time on each machine:** opens Handy so you can pick a model
   (Parakeet is fast on a normal processor; Whisper is better with a GPU) and
   grant microphone access. On macOS, also grant **Accessibility** so Handy
   can type. Then run `herd setup` again.
4. **Applies the shared settings** from [`voice/handy.json`](voice/handy.json)
   to Handy's `settings_store.json`: the shortcut, hold-or-toggle activation,
   filler-word removal, and not touching the clipboard. Handy rewrites that
   file when it exits, so herd stops Handy, edits the file, keeps a backup,
   and restarts it. Only the listed keys are changed. Your model choice,
   history and any API keys stay per machine and never go in this repo.

| OS | Handy app | Handy settings |
|---|---|---|
| Windows | `%LOCALAPPDATA%\Handy\handy.exe` | `%APPDATA%\com.pais.handy\settings_store.json` |
| macOS | `/Applications/Handy.app` | `~/Library/Application Support/com.pais.handy/settings_store.json` |
| Linux | `/usr/bin/handy` (package `handy`) | `~/.local/share/com.pais.handy/settings_store.json` |
| Linux, COSMIC shortcut | | `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` |

To change the shortcut or another setting, edit `voice/handy.json` (the
`wayland_shortcut` key covers Linux on Wayland), commit, and run `herd setup`
on each machine.

---

## How it's put together

```
herd/
  .local/bin/herd        # the script, linked into ~/.local/bin
  .local/bin/herd.cmd    # Windows launcher: python "%~dp0herd" %*
  herdr/base.toml        # herdr config shared by every OS (no [terminal] table)
  herdr/windows.toml     # default_shell = "pwsh.exe"
  herdr/macos.toml       # nothing to override
  herdr/linux.toml       # nothing to override
  voice/handy.json       # shared Handy settings + per-OS shortcut
  README.md
```

Only `.local/bin` is linked into your home directory (see
`.stow-local-ignore`). `herd setup` reads `herdr/` and `voice/` straight from
this directory, so a `git pull` is all an update needs.

### Why herdr's config is generated rather than linked

herdr can't include other config files, and it has no per-OS sections. Windows
needs `default_shell = "pwsh.exe"`, because herdr otherwise tries `$SHELL` and
then `/bin/sh`, neither of which exists there. macOS and Linux must leave it
unset. So `herd setup` joins `base.toml` with `<os>.toml` and writes the result
where herdr looks. A header in that file says it was generated. If the
existing file is different, it's backed up first as `config.toml.bak-<unix time>`.

**Edit the files in this directory, never the generated config.** Then run
`herd setup`; the running server reloads it.

| OS | herdr config (generated) | Dashboard state |
|---|---|---|
| Windows | `%APPDATA%\herdr\config.toml` | `%LOCALAPPDATA%\herd\state.json` |
| macOS | `~/.config/herdr/config.toml` | `~/.local/state/herd/state.json` |
| Linux | `~/.config/herdr/config.toml` (or `$XDG_CONFIG_HOME/herdr`) | `~/.local/state/herd/state.json` (or `$XDG_STATE_HOME/herd`) |

The dashboard state holds the chosen agent kind, the working directory, and
the agent numbering.

### One script for all three OSes

`.local/bin/herd` starts with a few lines of `sh` that look for a Python 3.8+
that actually runs, then hand over to it. This skips the Microsoft Store
`python3` placeholder that Git Bash finds on Windows. To Python, those same
lines are just a string. `.gitattributes` keeps the script's line endings
Unix-style (Windows-style line endings would break the `sh` part) and
`herd.cmd`'s Windows-style. Windows PowerShell and cmd run the script through
`herd.cmd`.

---

## Upgrading

```sh
herd update
```

| Component | How it updates |
|---|---|
| herd, herdr config, voice settings | `git pull --ff-only` of this repo, then `herd setup` |
| herdr | `herdr update`. A running server keeps the old version until it restarts; `herdr update --handoff` tries to hand live sessions over to the new version. |
| Handy | Windows: `winget upgrade cjpais.Handy`. Linux: reinstalls from the newest GitHub release when it's newer than what's installed. macOS: Handy updates itself. |

If the pull fails because of local changes or a diverged history, fix that
first; `herd update` stops rather than merging for you.

## Troubleshooting

| Symptom | Check |
|---|---|
| `herd setup` ran but herdr looks the same | Read the `herdr config:` lines it printed. `server reload applied` means the config is live; setup doesn't open the dashboard, so press F1 or run `herd`. `reload failed: …` or `no running server reachable` means the config applies the next time herdr starts. |
| F1 does nothing | Run `herd doctor`. The herdr **server** has to find `herd` on its `PATH`, so check that `~/.local/bin` is on it. |
| `herd: needs Python 3.8+ on PATH` | Install Python 3 (see [Prerequisites](#prerequisites)). |
| Voice shortcut does nothing | Run `herd doctor`. Finish Handy's first-run setup, then `herd setup`. macOS: grant Microphone and Accessibility to Handy. Linux on Wayland: check that `wayland shortcut` reports it's set; on desktops other than COSMIC, add the shortcut yourself. |
| Text doesn't appear on Linux | Wayland needs `wtype` and X11 needs `xdotool`; `herd setup` installs them. On GNOME's Wayland, `wtype` doesn't work, so use `ydotool` (see Handy's README). |
| Dashboard shows `herdr: …` errors | herdr isn't reachable from that pane. Run `herdr status`. |

## Uninstall

```sh
cd ~/dotfiles && stow -D herd           # Windows: .\winstow.ps1 -D herd
```

Then delete the generated herdr config, or restore the newest
`config.toml.bak-*` next to it. Remove Handy with your package manager if you
no longer want it.
