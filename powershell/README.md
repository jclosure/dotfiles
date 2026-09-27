# powershell (Windows)

Makes PowerShell feel like the zsh + Oh My Zsh setup. PowerShell 7 is the
main shell. The same profile also works in the built-in Windows PowerShell
5.1. It gives you:

- **Oh My Posh** prompt using the `robbyrussell` theme (the Oh My Zsh
  default), customized with a Windows logo and the hostname. The logo is a
  Nerd Font glyph, so GitHub can't display it here:

  ```
  <windows logo> singulator ➜  dotfiles git:(main ?1 ~1) ✗
  ```
  The arrow turns red when the last command failed. `?1 ~1` means one
  untracked and one modified file. `✗` means uncommitted changes.
- **Plain `ls`**: no icons, no per-file-type colors. In PowerShell 7 only
  directories are colored, in bold blue like GNU `ls`.
- **posh-git**: git tab completion.
- **PSReadLine 2.2+**: Emacs key bindings.
- **Fish-like suggestions**, like zsh-autosuggestions: as you type, the
  most recent matching command from history appears inline in gray after
  the cursor. Right arrow, End or Ctrl+E at the end of the line accepts it
  all; Alt+F, Alt+Right or Ctrl+Right accepts one word. Suggestions only
  turn on in a real console, because PSReadLine errors on redirected output.
  No syntax coloring while you type, like our zsh: commands, `--parameters`,
  strings and so on are all plain text, so only the suggestion is gray.
  PSReadLine's default colors parameters the same gray as the suggestion,
  which made accepted text look like it was still a suggestion.
- **Ctrl-r = fzf history search** (via PSFzf), like fzf's zsh widget. Type
  to fuzzy-filter your history, and Enter puts the command on the prompt.
- **zle-style editing**, matching `zsh/init.zsh` and
  `zsh/clipboard_wrapper.zsh` (with `zsh-delsel-mode`):

  | Key | Does |
  |-----|------|
  | Alt+Left / Alt+Right (also Alt+b / Alt+f, Ctrl+Left / Ctrl+Right) | Word left / right. Word boundaries follow zsh's default `WORDCHARS`, so `~/dotfiles/emacs-ide` is one word |
  | Ctrl+Space | Set the mark. Movement keys then extend a highlighted region; typing or Backspace replaces or deletes it. Ctrl+Space again starts a new region, and Ctrl+G cancels |
  | Ctrl+W | Cut the region to the system clipboard |
  | Alt+W (or Alt+Shift+W) | Copy the region to the system clipboard |
  | Ctrl+Y | Paste from the system clipboard |
  | Ctrl+/ (also Ctrl+_) | Undo the last edit, like zle's `undo` |

  The region is drawn bright white on blue (`#264F78`), Emacs-style, so the
  whole region stays visible and the character under the cursor shows as the
  cursor block on top. PSReadLine's default, black on light gray, is almost
  the cursor's color, so that character turned black.

  With no region, Ctrl+W and Alt+W act from the start of the line to the
  cursor, like zle's `kill-region` with the mark at its default of 0. Other
  Emacs keys (Ctrl+K, Alt+D, Alt+Backspace, Alt+Y, ...) are PSReadLine's
  Emacs defaults. zsh's `ESC o` (show buffers) isn't ported.

  Windows Terminal binds Alt+Arrow to "move focus to pane" by default, so
  Alt+Left/Right never reach the shell. We move pane focus to
  **Ctrl+Alt+Arrow** and free Alt+Arrow, in Terminal's `settings.json`
  (`"keybindings"`):

  ```json
  { "id": null, "keys": "alt+left" },
  { "id": null, "keys": "alt+right" },
  { "id": null, "keys": "alt+up" },
  { "id": null, "keys": "alt+down" },
  { "id": "Terminal.MoveFocusLeft", "keys": "ctrl+alt+left" },
  { "id": "Terminal.MoveFocusRight", "keys": "ctrl+alt+right" },
  { "id": "Terminal.MoveFocusUp", "keys": "ctrl+alt+up" },
  { "id": "Terminal.MoveFocusDown", "keys": "ctrl+alt+down" },
  ```

  (Ctrl+Alt+Left was Terminal's default for "focus the previous pane"; that
  command is still in the command palette, Ctrl+Shift+P.)

| File | Stowed to |
|------|-----------|
| `.config/powershell/profile.ps1` | `~/.config/powershell/profile.ps1` (the actual profile) |
| `.config/oh-my-posh/robbyrussell.omp.json` | `~/.config/oh-my-posh/robbyrussell.omp.json` (the theme) |

## Setup

1. Install the tools (per user, no admin needed):

   ```powershell
   winget install Microsoft.PowerShell          # PowerShell 7
   winget install JanDeDobbeleer.OhMyPosh
   winget install junegunn.fzf
   # then, in a new PowerShell 7 window:
   Install-Module posh-git, PSFzf -Scope CurrentUser
   ```

   PowerShell 7 and Windows PowerShell 5.1 keep **separate** per-user module
   folders (`Documents\PowerShell\Modules` and
   `Documents\WindowsPowerShell\Modules`), so a module installed from one
   isn't visible to the other. If you also use 5.1, run the install there
   too, plus a newer PSReadLine (5.1 ships 2.0.0, which is too old for the
   profile; PowerShell 7 includes 2.4+):

   ```powershell
   Install-Module posh-git, PSFzf -Scope CurrentUser
   Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
   ```

   (Watch out: a `pwsh` started *from* 5.1 inherits 5.1's `PSModulePath`
   and can see 5.1's modules. A `pwsh` from Terminal can't. Test from
   Terminal.)

2. Stow the package with [`winstow`](../winstow.ps1):

   ```powershell
   cd ~\dotfiles
   .\winstow.ps1 powershell
   ```

3. Point each shell's `$PROFILE` at the stowed profile. `$PROFILE` lives
   under Documents, which is often redirected into OneDrive, and OneDrive
   doesn't sync symlinks properly. So instead of linking the profile there,
   make `$PROFILE` a one-line loader. Run this once in **PowerShell 7**
   (`Documents\PowerShell\...`), and once in **Windows PowerShell 5.1**
   (`Documents\WindowsPowerShell\...`) if you use it:

   ```powershell
   New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
   Set-Content $PROFILE '. "$HOME\dotfiles\powershell\.config\powershell\profile.ps1"'
   ```

   Use the real `~/dotfiles/...` path rather than the stowed
   `~/.config/powershell/profile.ps1` symlink. Local interactive shells can
   follow the symlink, but Windows OpenSSH sessions may reject it as an
   "untrusted mount point" and then the prompt/profile will not load.

   Leave any sibling `profile.ps1` (all hosts) alone. `conda init`, for
   example, manages its own block there, and it's machine-specific.

4. In Windows Terminal, make **PowerShell** (7) the default profile
   (Settings → Startup → Default profile) and use a Nerd Font for the
   prompt's Windows logo (Settings → Defaults → Appearance → Font face).
   Nerd Fonts v3 register short family names, for example **`JetBrainsMono NFM`**
   rather than `JetBrainsMono Nerd Font Mono`. If the old name is set,
   Terminal quietly falls back to a plain font and the logo shows as a box.

5. VS Code's integrated terminal has its own font setting and doesn't use
   Windows Terminal's. Set it to the same Nerd Font, or the logo shows as a
   box there. In VS Code's user `settings.json` (Ctrl+, → search "terminal
   font family"):

   ```json
   "terminal.integrated.fontFamily": "JetBrainsMono NFM"
   ```

## SSH into Windows from the Mac

For passwordless SSH from `loops-mac-mini`/macOS into this Windows machine,
there are two Windows OpenSSH quirks to remember:

1. **Admin users do not use `~/.ssh/authorized_keys`.** If the Windows user is
   in the local Administrators group, OpenSSH uses this file instead:

   ```text
   C:\ProgramData\ssh\administrators_authorized_keys
   ```

   Copy the same keys there and lock the ACL down from an elevated PowerShell:

   ```powershell
   Copy-Item $HOME\.ssh\authorized_keys $env:ProgramData\ssh\administrators_authorized_keys -Force
   icacls $env:ProgramData\ssh\administrators_authorized_keys /inheritance:r
   icacls $env:ProgramData\ssh\administrators_authorized_keys /grant:r 'Administrators:F' 'SYSTEM:F'
   icacls $env:ProgramData\ssh\administrators_authorized_keys /remove:g $env:USERNAME
   ```

2. **Set the SSH default shell to PowerShell 7.** Otherwise SSH lands in the
   stock Windows shell/Windows PowerShell experience rather than the configured
   PowerShell 7 prompt:

   ```powershell
   $pwsh = (Get-Command pwsh.exe).Source
   New-Item HKLM:\SOFTWARE\OpenSSH -Force | Out-Null
   New-ItemProperty HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -Value $pwsh -PropertyType String -Force | Out-Null
   New-ItemProperty HKLM:\SOFTWARE\OpenSSH -Name DefaultShellCommandOption -Value '-c' -PropertyType String -Force | Out-Null
   Restart-Service sshd -Force
   ```

Also keep the `$PROFILE` loader and Oh My Posh config path pointed at the real
`$HOME\dotfiles\...` files, not the stowed `~/.config/...` symlinks; SSH
sessions can fail to traverse those symlinks as untrusted mount points.

Quick remote test from the Mac:

```sh
ssh joel_@singulator.local '$PSVersionTable.PSVersion.ToString(); (Get-Command prompt).Definition'
```

It should report PowerShell 7 and the `prompt` function should contain
Oh My Posh code.

## Customizing

- **Theme:** a normal Oh My Posh config. The Windows logo is the `os`
  segment (``, blue `#00A4EF`), and the hostname is the `session`
  segment (`{{ .HostName | lower }}`).
- **`ls` colors (PowerShell 7):** `$PSStyle.FileInfo`. The profile only
  changes `.Directory`. Run `$PSStyle.FileInfo` to see the rest.

Preview changes with `. $PROFILE` in the current shell.
