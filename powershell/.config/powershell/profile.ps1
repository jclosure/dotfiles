# Oh My Zsh-style PowerShell: Oh My Posh prompt + git + PSReadLine + fzf.
#
# Stowed to ~/.config/powershell/profile.ps1 and dot-sourced from $PROFILE by a
# one-line loader (see powershell/README.md), since $PROFILE lives under
# OneDrive, which doesn't handle symlinks. Shared by PowerShell 7 (the main
# shell) and Windows PowerShell 5.1; each has its own $PROFILE loader.
#
# No Terminal-Icons: plain `ls`. In PowerShell 7, $PSStyle colors only
# directories, which is close to Oh My Zsh's default ls.

# PowerShell 7's default directory style is bold on a blue *background*;
# use bold blue text instead, like GNU ls (di=01;34).
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.FileInfo.Directory = "`e[1;34m"
}

# Prompt theme with git status (installed via: winget install JanDeDobbeleer.OhMyPosh).
# robbyrussell = the Oh My Zsh default; local copy of the upstream theme from
# https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/robbyrussell.omp.json
# customized with a Windows logo + hostname before the arrow (logo needs a Nerd Font).
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$HOME\.config\oh-my-posh\robbyrussell.omp.json" | Invoke-Expression
}

Import-Module posh-git         # git tab completion

# Emacs key bindings, and no as-you-type suggestions: history only comes up
# on demand with Ctrl-r (below). PSReadLine 2.2+ turns predictions on by
# default, so switch them off explicitly. (Installed to CurrentUser; the
# built-in 2.0.0 is too old for -PredictionSource.)
Import-Module PSReadLine -MinimumVersion 2.2
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -PredictionSource None

# Ctrl-r = fzf over command history, like fzf's zsh widget: fuzzy filter,
# Enter puts the command on the prompt to edit or run.
# Needs: winget install junegunn.fzf; Install-Module PSFzf -Scope CurrentUser
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}
