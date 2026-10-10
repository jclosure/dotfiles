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

## Setting up a new machine

Every OS goes through the same five stages. Only the commands differ:

1. **Install the prerequisites:** git, Python 3.8+, a linking tool and herdr,
   with `~/.local/bin` on `PATH`.
2. **Clone the dotfiles and link herd** into `~/.local/bin`.
3. **Run `herd setup`.** It writes the herdr config, installs Handy and opens
   it.
4. **Finish Handy's first-run setup, then run `herd setup` again.** Pick the
   model, grant permissions, and let herd apply the shared voice settings.
5. **Check it:** `herd doctor`, the voice shortcut, and that Handy starts at
   login.

`herd setup` is safe to re-run at any time. If a step fails, fix it and run
it again.

| | Windows | macOS | Linux |
|---|---|---|---|
| Shell to run these in | PowerShell 7 (`pwsh`) | zsh | bash or zsh |
| Linking tool | `winstow.ps1` (in this repo) | GNU Stow (`brew`) | GNU Stow (`apt`/`dnf`) |
| herdr's default shell | `pwsh.exe` (from `herdr/windows.toml`), so PowerShell 7 is required | your login shell | your login shell |
| How Handy is installed | `winget install cjpais.Handy` | `brew install --cask handy` | `.deb`/`.rpm` from Handy's GitHub releases, with `sudo` |
| Voice shortcut handled by | Handy | Handy | Handy (X11) or the desktop (Wayland) |
| Extra permissions | Developer Mode, for symlinks | Microphone and **Accessibility** for Handy | `sudo` for the Handy package |

### Windows

**1. Prerequisites.** In PowerShell:

```powershell
winget install --id Git.Git -e
winget install --id Python.Python.3.14 -e
winget install --id Microsoft.PowerShell -e
irm https://herdr.dev/install.ps1 | iex
```

- Turn on **Developer Mode** (Settings → System → For developers) so
  `winstow.ps1` can create symlinks. Without it, link from an elevated shell.
- Allow local scripts such as `winstow.ps1` to run:
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- Put `~/.local/bin` on your **user** `PATH`. The herdr server must find
  `herd` there, or F1 does nothing, so adding it in your PowerShell profile
  isn't enough:

  ```powershell
  $p = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($p -notlike "*$HOME\.local\bin*") {
      [Environment]::SetEnvironmentVariable('Path', "$HOME\.local\bin;$p", 'User')
  }
  ```

- Close every terminal and open a new PowerShell 7 window so the new `PATH`
  takes effect.

**2. Clone and link.** Skip the `git clone` line if you already have `~/dotfiles`:

```powershell
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~\dotfiles
cd ~\dotfiles
.\winstow.ps1 herd
```

(Use `git@github.com:jclosure/dotfiles.git` instead if this machine has an
SSH key on GitHub and you'll push from it.)

**3. First `herd setup`.** This writes `%APPDATA%\herdr\config.toml`, installs
Handy with winget, and opens it.

**4. Handy's first run, then `herd setup` again.** In Handy, choose the
**Canary 180M Flash (Q8)** model, let it download, and allow microphone
access. Then run `herd setup` again. It prints each setting it changes and
restarts Handy.

**5. Check it:**

- `herd doctor` shows herdr, an up-to-date config, Handy as installed, and
  the shortcut as `ctrl+shift+space`.
- Click outside Windows Terminal, press **Ctrl+Shift+Space**, speak, and
  press it again. If Windows Terminal's new-tab menu opens instead, Handy
  isn't running.
- Handy starts at login if `reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v Handy`
  shows `...\Handy\handy.exe`. Handy writes that value every time it starts
  with `autostart_enabled` on.

### macOS

**1. Prerequisites.** Install [Homebrew](https://brew.sh), then:

```sh
brew install git python stow
curl -fsSL https://herdr.dev/install.sh | sh
```

Make sure `~/.local/bin` is on `PATH` in `~/.zshrc`. The herdr installer
puts herdr there:

```sh
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
exec zsh
```

**2. Clone and link.** Skip the `git clone` line if you already have `~/dotfiles`:

```sh
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~/dotfiles
cd ~/dotfiles && stow herd
```

**3. First `herd setup`.** This writes `~/.config/herdr/config.toml`, runs
`brew install --cask handy`, and opens Handy.

**4. Handy's first run, then `herd setup` again.** Choose **Canary 180M Flash
(Q8)**. When macOS asks, allow **Microphone**. Also go to System Settings →
Privacy & Security → **Accessibility** and turn on Handy, so it can type.
Then run `herd setup` again.

**5. Check it:**

- `herd doctor`, then try the shortcut, as on Windows. The shortcut is
  Ctrl+Shift+Space here too, not Cmd.
- Handy should appear under System Settings → General → **Login Items** after
  it has started once with `autostart_enabled` on. If it doesn't, add it there
  by hand. Autostart through the setting hasn't been confirmed on macOS yet.

The upstream Shepherd (`brew` + herdr plugin, `~/.shepherd`) can run
alongside herd on the Mac; herd doesn't touch it.

### Linux

**1. Prerequisites.** For Debian, Ubuntu or Pop!_OS (on Fedora, use `dnf`):

```sh
sudo apt install git python3 stow curl
curl -fsSL https://herdr.dev/install.sh | sh
```

`~/.local/bin` is on `PATH` through the default `~/.profile` once the
directory exists. Log out and back in after the first install, or run
`export PATH="$HOME/.local/bin:$PATH"` in the current shell. You need `sudo`,
because `herd setup` installs the Handy package.

**2. Clone and link.** Skip the `git clone` line if you already have `~/dotfiles`:

```sh
git clone --recurse-submodules https://github.com/jclosure/dotfiles.git ~/dotfiles
cd ~/dotfiles && stow herd
```

**3. First `herd setup`.** This writes `~/.config/herdr/config.toml`,
downloads the newest Handy `.deb`/`.rpm` from GitHub, and installs it with
`sudo`. It also installs the text-input helper: `wtype` on Wayland, `xdotool`
on X11. On **Wayland**, it binds Ctrl+Shift+Space to
`handy --toggle-transcription`: automatically on COSMIC, while on GNOME or KDE
it prints the shortcut to add by hand. herd reads the desktop session from
systemd, so this all works over SSH too, with Handy appearing on the desktop.

**4. Handy's first run, then `herd setup` again.** At the machine's desktop,
choose **Canary 180M Flash (Q8)** and allow the microphone. Then run
`herd setup` again.

**5. Check it:**

- `herd doctor` also shows the session (`wayland / COSMIC`) and whether the
  Wayland shortcut is set.
- On Wayland, tap the shortcut to start and tap it again to stop. Holding it
  doesn't work there.
- Handy starts at login if `~/.config/autostart/` contains a Handy entry
  after Handy has run once with `autostart_enabled` on.

### Keeping machines in sync

After you commit a change to this repo, bring every machine up to date:

```sh
herd update      # pull, herd setup, herdr update, upgrade Handy
# or, for config only:
git -C ~/dotfiles pull --ff-only && herd setup
```

If two machines behave differently, compare their Handy `settings_store.json`
files (paths are under [Voice](#what-herd-setup-does-for-voice)). Apart from
history and versions, they should differ only in the
[choices that stay per machine](#choices-that-stay-per-machine).

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
| **prefix, then Alt+j / Alt+k**, or **Alt+Shift+↓ / ↑** | Next / previous agent. |
| **Shift+←/↓/↑/→** | Move to the pane in that direction, windmove-style as in Emacs (replaces herdr's default prefix, then `h/j/k/l`). |
| **prefix, then `w`** | Opens the workspace list; ↑↓ or Ctrl+P / Ctrl+N move in it. |
| **prefix, then Shift+R** | Reloads the config (`herd setup` already does this). |

Plain `herdr` attaches to the running session without opening the dashboard.

The prefix is herdr's default, **Ctrl+B**. The top bar shows `F1 ◂ shepherd`
as a reminder.

> **Careful:** every line typed into the dashboard that isn't a command starts
> a real agent. Never script input into it with `herdr pane send-text`. To
> restart it, press Ctrl+C in its pane and run `herd dash`.

### Scripting herdr

The `herdr` command controls the running session from a shell or a script:

```sh
herdr workspace list                 # workspaces
herdr agent list                     # agents and their state
herdr agent read <id>                # an agent's recent output
herdr agent prompt <id> "..."        # give an agent a prompt
herdr agent wait <id> --until done   # wait for a state (repeat --until)
herdr pane read <id>                 # any pane's output
herdr server reload-config           # what herd setup does after writing config
```

Every group (`workspace`, `tab`, `pane`, `agent`) has `--help`.

---

## Voice

Hold the shortcut, speak, then let go (or tap it once to start and again to
stop). Handy transcribes on your machine and types the text where your cursor
is. That's usually the dashboard's task prompt or an agent's input box, and
nothing is submitted until you press Enter.

| OS | Shortcut | How it's triggered |
|---|---|---|
| Windows | **Ctrl+Shift+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut |
| macOS | **Ctrl+Shift+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut |
| Linux, X11 | **Ctrl+Shift+Space**, hold to talk (or tap to toggle) | Handy's own global shortcut; text typed with `xdotool` |
| Linux, Wayland | **Ctrl+Shift+Space**: tap to start, tap again to stop | Wayland doesn't let apps grab global keys, so the **desktop** runs `handy --toggle-transcription`. `herd setup` adds this shortcut to **COSMIC** automatically. On GNOME or KDE it prints the one shortcut to add by hand. Text is typed with `wtype`. |

### Using it: tap to start, tap to stop

This works the same on every machine: the shortcut is **Ctrl+Shift+Space**
everywhere, including macOS. It's deliberately not Ctrl+Space. Handy grabs its
shortcut globally, and Ctrl+Space is set-mark in the zsh and PowerShell setups
here and in Emacs (and the input-source switcher on macOS).

1. **Click where the text should go.** For example, the dashboard's task
   prompt, an agent's input box, an editor or a browser field.
2. **Press Ctrl+Shift+Space once and let go.** Handy starts recording. Its
   small overlay or tray icon shows that it's listening.
3. **Speak.** Pausing is fine; it keeps recording until you stop it.
4. **Press Ctrl+Shift+Space again.** Handy stops, transcribes on your machine
   and types the text at your cursor. Longer recordings take longer.
5. **Check the text and press Enter yourself.** Handy never submits anything.

To throw a recording away instead, press **Escape** while it's recording
(Windows, macOS and Linux X11). On Wayland Handy can't catch Escape globally,
so press Ctrl+Shift+Space to stop and delete the text it types.

On Windows, macOS and Linux X11 you can also **hold** the shortcut while you
talk and let go when you're done. Holding doesn't work on Linux Wayland; use
tap to start and tap to stop.

If nothing happens, see [Troubleshooting](#troubleshooting). The usual causes
are that Handy's first-run setup isn't finished, it has no microphone
permission, or the shortcut isn't bound.

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
   (we use Canary 180M Flash, Q8; see [Choices that stay per machine](#choices-that-stay-per-machine)) and
   grant microphone access. On macOS, also grant **Accessibility** so Handy
   can type. Then run `herd setup` again.
4. **Applies the shared settings** from [`voice/handy.json`](voice/handy.json)
   to Handy's `settings_store.json`: the shortcut, hold-or-toggle activation,
   filler-word removal, not touching the clipboard, and launching at login
   straight to the tray (`autostart_enabled`, `start_hidden`). Handy registers
   itself to start at login when it next starts with that setting on (on
   Windows, the `Handy` value under `HKCU\…\CurrentVersion\Run`). Handy rewrites that
   file when it exits, so herd stops Handy, edits the file, keeps a backup,
   and restarts it. Only the listed keys are changed. Your model choice,
   history and any API keys stay per machine and never go in this repo.

| OS | Handy app | Handy settings |
|---|---|---|
| Windows | `%LOCALAPPDATA%\Handy\handy.exe` | `%APPDATA%\com.pais.handy\settings_store.json` |
| macOS | `/Applications/Handy.app` | `~/Library/Application Support/com.pais.handy/settings_store.json` |
| Linux | `/usr/bin/handy` (package `handy`) | `~/.local/share/com.pais.handy/settings_store.json` |
| Linux, COSMIC shortcut | | `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom` |

### Choices that stay per machine

`herd setup` doesn't set these, so make the same choices by hand on a new
machine:

| Setting | Our choice | Why it isn't in `handy.json` |
|---|---|---|
| Model | **Canary 180M Flash (Q8)** (`handy-computer/canary-180m-flash-gguf/canary-180m-flash-Q8_0.gguf`), used on Windows and the Mac | Handy has to download it first; choose it during first-run setup. |
| Microphone | System default | Hardware differs per machine. |
| Post-processing (AI cleanup) | Off, with no API keys | API keys must never be committed. |

Everything else is left at Handy's defaults. A new machine matches when its
`settings_store.json` differs from another machine's only in the model,
microphone and the post-processing shortcut below.

**Post-processing shortcut.** Handy's default for *Transcribe with
Post-Processing* is Ctrl+Shift+Space on Windows (Option+Shift+Space on macOS),
the same key herd gives plain *Transcribe*. That's deliberate. Ctrl+Space is
reserved for Emacs and the shells, and post-processing is off, so plain
Transcribe is the one that fires. If you ever turn post-processing on, give
it a different key first.

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
| `herd: needs Python 3.8+ on PATH` | Install Python 3 (see [Setting up a new machine](#setting-up-a-new-machine)). |
| Voice shortcut does nothing | Run `herd doctor`. Finish Handy's first-run setup, then `herd setup`. macOS: grant Microphone and Accessibility to Handy. Linux on Wayland: check that `wayland shortcut` reports it's set; on desktops other than COSMIC, add the shortcut yourself. |
| Windows: Ctrl+Shift+Space opens Windows Terminal's new-tab menu | Handy isn't running, so the key reaches the terminal. Start `%LOCALAPPDATA%\Handy\handy.exe`, and run `herd setup` so it starts at login. |
| Text doesn't appear on Linux | Wayland needs `wtype` and X11 needs `xdotool`; `herd setup` installs them. On GNOME's Wayland, `wtype` doesn't work, so use `ydotool` (see Handy's README). |
| Dashboard shows `herdr: …` errors | herdr isn't reachable from that pane. Run `herdr status`. |

## Uninstall

```sh
cd ~/dotfiles && stow -D herd           # Windows: .\winstow.ps1 -D herd
```

Then delete the generated herdr config, or restore the newest
`config.toml.bak-*` next to it. Remove Handy with your package manager if you
no longer want it.
