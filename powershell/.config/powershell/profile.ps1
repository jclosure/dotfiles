# Oh My Zsh-style PowerShell: Oh My Posh prompt + git + PSReadLine + fzf.
#
# Stowed to ~/.config/powershell/profile.ps1 and dot-sourced from $PROFILE by a
# one-line loader (see powershell/README.md), since $PROFILE lives under
# OneDrive, which doesn't handle symlinks. Shared by PowerShell 7 (the main
# shell) and Windows PowerShell 5.1; each has its own $PROFILE loader.
#
# No Terminal-Icons: plain `ls`. In PowerShell 7, $PSStyle colors only
# directories, which is close to Oh My Zsh's default ls.

# User commands: ad-hoc scripts in ~/bin plus stowed repo helpers in ~/.local/bin.
foreach ($userBin in @((Join-Path $HOME 'bin'), (Join-Path $HOME '.local\bin'))) {
    if (-not (Test-Path -LiteralPath $userBin)) { continue }
    $normalizedUserBin = [IO.Path]::GetFullPath($userBin).TrimEnd('\')
    $pathHasUserBin = $false
    foreach ($pathPart in ($env:Path -split [IO.Path]::PathSeparator)) {
        if (-not $pathPart) { continue }
        try {
            if ([IO.Path]::GetFullPath($pathPart).TrimEnd('\') -ieq $normalizedUserBin) {
                $pathHasUserBin = $true
                break
            }
        } catch { }
    }
    if (-not $pathHasUserBin) {
        $env:Path = $userBin + [IO.Path]::PathSeparator + $env:Path
    }
}
Remove-Variable userBin, normalizedUserBin, pathHasUserBin, pathPart -ErrorAction SilentlyContinue

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
    oh-my-posh init pwsh --config "$HOME\dotfiles\powershell\.config\oh-my-posh\robbyrussell.omp.json" | Invoke-Expression
}

Import-Module posh-git         # git tab completion

# Emacs key bindings. (PSReadLine 2.2+ is installed to CurrentUser for 5.1;
# the built-in 2.0.0 is too old for -PredictionSource.)
Import-Module PSReadLine -MinimumVersion 2.2
Set-PSReadLineOption -EditMode Emacs

# Fish-like suggestions, like zsh-autosuggestions: one gray inline
# completion from history after the cursor (not the ListView popup).
# Right/End/Ctrl+E at the end of the line accept it all, and
# Alt+F/Alt+Right/Ctrl+Right accept one word (wired into the motion keys
# below). Gray = zsh-autosuggestions' default fg=8. Predictions throw when
# output is redirected (scripts, Emacs shell buffers), so only turn them on
# in a real console.
if (-not [Console]::IsOutputRedirected) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
    Set-PSReadLineOption -Colors @{ InlinePrediction = "$([char]27)[38;5;8m" }
} else {
    Set-PSReadLineOption -PredictionSource None
}

# No syntax coloring while typing, like our zsh (no zsh-syntax-highlighting):
# everything you type is plain text and only the inline suggestion is gray.
# PSReadLine colors parameters (--foo) and operators dark gray (\e[90m), the
# same gray as the suggestion, so accepted text looked still-unaccepted; the
# command (first word) was yellow. Selection/search/error colors are kept.
$plain = (Get-PSReadLineOption).DefaultTokenColor
Set-PSReadLineOption -Colors @{
    Command = $plain; Parameter = $plain; Operator = $plain; Variable = $plain
    String = $plain; Number = $plain; Member = $plain; Type = $plain
    Keyword = $plain; Comment = $plain
}
Remove-Variable plain

# zle-style line editing (mark/region, clipboard cut/copy/paste, undo,
# zsh word motion): see zle.ps1. Real path, not the stowed symlink, so SSH
# sessions can load it (see README).
. "$HOME\dotfiles\powershell\.config\powershell\zle.ps1"

# Terminal modes that full-screen programs (herdr, vim, htop, ...) turn on and
# turn off again when they exit: mouse reporting, focus events, bracketed
# paste, application cursor keys and kitty/xterm keyboard modes. If the program
# never gets to exit cleanly, say an SSH connection that dies under herdr, they
# stay on in Windows Terminal: clicks and keys then print escape-sequence
# garbage like [<0;12;5M at the prompt. This string turns them all off again.
$global:TermModesOff = "$([char]27)[?1000l$([char]27)[?1002l$([char]27)[?1003l" +
    "$([char]27)[?1005l$([char]27)[?1006l$([char]27)[?1015l$([char]27)[?1016l$([char]27)[?9l" +
    "$([char]27)[?2004l$([char]27)[?1l$([char]27)>" +
    "$([char]27)[<99u$([char]27)[=0;1u$([char]27)[>4;0m$([char]27)[?25h"

# Fix a terminal left printing garbage: run `reset-term` (the text you type
# may be garbled; that's fine, Enter still works).
function global:reset-term {
    if (-not [Console]::IsOutputRedirected) { [Console]::Write($global:TermModesOff) }
}

# ssh with keepalives, then reset the terminal modes. Without keepalives a dead
# connection (network drop, the other machine asleep) leaves ssh waiting for a
# very long time, and the terminal looks frozen: keys go nowhere and nothing
# echoes. With them, ssh gives up after about 45s (3 missed 15s probes).
# Enter then ~. kills a hung session right away. Calls ssh.exe so this isn't
# recursive; sshmail goes through it too.
function global:ssh {
    & ssh.exe -o ServerAliveInterval=15 -o ServerAliveCountMax=3 @args
    $code = $LASTEXITCODE
    reset-term
    $global:LASTEXITCODE = $code
}

# Ctrl-r = fzf over command history, like fzf's zsh widget: fuzzy filter,
# Enter puts the command on the prompt to edit or run.
# Needs: winget install junegunn.fzf; Install-Module PSFzf -Scope CurrentUser
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Mail-aware ssh wrapper.  The implementation lives in ~/.local/bin so scripts
# like check-mail.ps1 can use the same portable command without loading this
# interactive profile.
function global:sshmail {
    $script = Join-Path $HOME '.local\bin\sshmail.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        $script = Join-Path $HOME 'dotfiles\powershell\.local\bin\sshmail.ps1'
    }
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Error 'sshmail.ps1 not found; run ./winstow.ps1 powershell or sync dotfiles'
        return
    }
    & $script @args
    $global:LASTEXITCODE = $LASTEXITCODE
}
