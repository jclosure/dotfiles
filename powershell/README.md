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
- **PSReadLine 2.2+**: Emacs key bindings, with no as-you-type suggestions.
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

  With no region, Ctrl+W and Alt+W act from the start of the line to the
  cursor, like zle's `kill-region` with the mark at its default of 0. Other
  Emacs keys (Ctrl+K, Alt+D, Alt+Backspace, Alt+Y, ...) are PSReadLine's
  Emacs defaults. zsh's `ESC o` (show buffers) isn't ported.

  Windows Terminal binds Alt+Left/Right to "move focus to pane" by default,
  so they never reach the shell. Unbind them in Terminal's `settings.json`
  (`"keybindings"`): `{ "id": null, "keys": "alt+left" }` and
  `{ "id": null, "keys": "alt+right" }`. Alt+Up/Down still move pane focus.

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
   Set-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'
   ```

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

## Customizing

- **Theme:** a normal Oh My Posh config. The Windows logo is the `os`
  segment (``, blue `#00A4EF`), and the hostname is the `session`
  segment (`{{ .HostName | lower }}`).
- **`ls` colors (PowerShell 7):** `$PSStyle.FileInfo`. The profile only
  changes `.Directory`. Run `$PSStyle.FileInfo` to see the rest.

Preview changes with `. $PROFILE` in the current shell.
