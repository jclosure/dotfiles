# Oh My Zsh-style PowerShell: Oh My Posh prompt + icons + git + PSReadLine.
#
# Stowed to ~/.config/powershell/profile.ps1 and dot-sourced from $PROFILE by a
# one-line loader (see powershell/README.md), since $PROFILE lives under
# OneDrive, which doesn't handle symlinks.

# Prompt theme with git status (installed via: winget install JanDeDobbeleer.OhMyPosh).
# robbyrussell = the Oh My Zsh default; local copy of the upstream theme from
# https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json
# customized with a Windows logo + hostname before the arrow (logo needs a Nerd Font).
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\robbyrussell.omp.json" | Invoke-Expression
}

Import-Module Terminal-Icons   # icons in ls / Get-ChildItem
Import-Module posh-git         # git tab completion

# History-based suggestions shown as a list, with Emacs key bindings.
# Needs PSReadLine 2.2+ (installed to CurrentUser; the built-in 2.0.0 is too old).
# Predictions error out when output is redirected (scripts, Emacs shell buffers),
# so only enable them in a real console.
Import-Module PSReadLine -MinimumVersion 2.2
Set-PSReadLineOption -EditMode Emacs
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
}
