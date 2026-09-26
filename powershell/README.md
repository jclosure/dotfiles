# powershell (Windows)

Makes Windows PowerShell 5.1 feel like the zsh + Oh My Zsh setup. It gives you:

- **Oh My Posh** prompt using the `robbyrussell` theme (the Oh My Zsh
  default), customized with a Windows logo and the hostname. The logo is a
  Nerd Font glyph, so GitHub can't display it here:

  ```
  <windows logo> singulator ➜  dotfiles git:(main ?1 ~1) ✗
  ```
  The arrow turns red when the last command failed. `?1 ~1` means one
  untracked and one modified file. `✗` means uncommitted changes.
- **Terminal-Icons**: file-type icons in `ls` / `Get-ChildItem`.
- **posh-git**: git tab completion.
- **PSReadLine 2.2+**: Emacs key bindings, with no as-you-type suggestions.
- **Ctrl-r = fzf history search** (via PSFzf), like fzf's zsh widget. Type
  to fuzzy-filter your history, and Enter puts the command on the prompt.

| File | Stowed to |
|------|-----------|
| `.config/powershell/profile.ps1` | `~/.config/powershell/profile.ps1` (the actual profile) |
| `.config/oh-my-posh/robbyrussell.omp.json` | `~/.config/oh-my-posh/robbyrussell.omp.json` (the theme) |

## Setup

1. Install the tools (per user, no admin needed):

   ```powershell
   winget install JanDeDobbeleer.OhMyPosh
   Install-Module Terminal-Icons -Scope CurrentUser
   Install-Module posh-git -Scope CurrentUser
   # Windows PowerShell ships PSReadLine 2.0.0, which is too old for the
   # profile's settings. Install a newer one next to it:
   Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
   # fzf-powered Ctrl-r
   winget install junegunn.fzf
   Install-Module PSFzf -Scope CurrentUser
   ```

2. Stow the package with [`winstow`](../winstow.ps1):

   ```powershell
   cd ~\dotfiles
   .\winstow.ps1 powershell
   ```

3. Point `$PROFILE` at the stowed profile. `$PROFILE` usually lives under
   OneDrive (`OneDrive\Documents\WindowsPowerShell\...`), and OneDrive doesn't
   sync symlinks properly. So instead of linking the profile there, make
   `$PROFILE` a one-line loader:

   ```powershell
   New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
   Set-Content $PROFILE '. "$HOME\.config\powershell\profile.ps1"'
   ```

   Leave the sibling `profile.ps1` (all hosts) alone. `conda init` manages
   it, and it's machine-specific.

4. Use a Nerd Font in Windows Terminal. The Windows logo and the `ls` icons are
   Nerd Font glyphs. Settings → Defaults → Appearance → Font face.
   Nerd Fonts v3 register short family names, for example **`JetBrainsMono NFM`**
   rather than `JetBrainsMono Nerd Font Mono`. If the old name is set,
   Terminal quietly falls back to a plain font and the glyphs show as boxes.

## Customizing the theme

The theme is a normal Oh My Posh config. The Windows logo is the `os`
segment (``, blue `#00A4EF`), and the hostname is the `session` segment
(`{{ .HostName | lower }}`). Preview changes with `. $PROFILE` in the
current shell.
