# AGENTS.md

Guidance for coding agents working in this dotfiles repo.

## VS Code integrated terminal icons

The zsh and PowerShell prompts use Nerd Font glyphs for OS/logo icons. VS Code's integrated terminal does **not** inherit the font from Windows Terminal, Ghostty, iTerm, or the desktop terminal, so icons may render as boxes unless VS Code has an explicit terminal font setting.

When asked to fix missing prompt icons in VS Code, standardize it by updating the user's VS Code settings JSON:

- Linux desktop VS Code: `~/.config/Code/User/settings.json`
- VS Code Server / remote: `~/.vscode-server/data/Machine/settings.json` or `~/.vscode-server/data/User/settings.json`
- Windows VS Code: `%APPDATA%\Code\User\settings.json`

Set `terminal.integrated.fontFamily` to a normal monospace font plus a Nerd Font fallback. On Linux boxes where only the symbols fallback is installed, use:

```json
"terminal.integrated.fontFamily": "'DejaVu Sans Mono', 'Symbols Nerd Font Mono', monospace"
```

If a full Nerd Font is installed, prefer its registered family name, especially on Windows where Nerd Fonts v3 use short names, for example:

```json
"terminal.integrated.fontFamily": "JetBrainsMono NFM"
```

Useful checks:

```sh
fc-list : family | rg -i 'Nerd|NFM|NF|JetBrains|Meslo|Fira|Caskaydia|Hack|Symbols'
fc-match 'Symbols Nerd Font Mono'
```

## VS Code integrated terminal keybindings

Terminal programs such as shells, editors, TUIs, agents, multiplexers, and readline/fzf workflows often need raw keyboard shortcuts. VS Code may otherwise intercept keybindings before the integrated terminal sees them.

When standardizing VS Code terminal behavior, also set:

```json
"terminal.integrated.sendKeybindingsToShell": true
```

This makes VS Code pass most keybindings through to the shell/application running inside the terminal.

After changing VS Code terminal settings, tell the user to reload VS Code or kill/reopen the integrated terminal.

## Terminal UIs written in this repo

Tools here (for example `herd dash`) run on Windows (through ConPTY), macOS, and Linux, often nested inside herdr, tmux, or VS Code. Those layers can show the screen partway through a redraw, so a full-screen redraw that isn't sent as one piece flickers or shows the cursor jumping around, even in GPU-rendered terminals.

When a script draws a full-screen or live-updating view:

- Build the whole frame as one string and send it with a single write and flush. Skip the write if the frame hasn't changed.
- Wrap each frame as `ESC[?2026h` `ESC[?25l` <frame> `ESC[?25h` `ESC[?2026l`: synchronized output plus a hidden cursor, then move the cursor to where it belongs. Terminals that don't support 2026 ignore it.
- Use the alternate screen (`ESC[?1049h`/`l`), and in a `finally` block, restore the cursor, mouse modes, and console/tty modes.
- Keep a single code path for all operating systems. Put an OS branch only where the platform really differs (input handling, paths), not in rendering.
