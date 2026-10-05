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

# Ctrl-r = fzf over command history, like fzf's zsh widget: fuzzy filter,
# Enter puts the command on the prompt to edit or run.
# Needs: winget install junegunn.fzf; Install-Module PSFzf -Scope CurrentUser
if ((Get-Command fzf -ErrorAction SilentlyContinue) -and (Get-Module -ListAvailable PSFzf)) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'
}

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

# Full GPG-agent forwarding for Emacs/mu4e on Linux.  Windows OpenSSH cannot
# use GnuPG's drive-letter AF_UNIX socket as a RemoteForward endpoint, so the
# helper bridges that socket to a loopback TCP port and SSH forwards the TCP
# endpoint into Ubuntu.  The YubiKey stays attached to this Windows machine.
function global:sshmail {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $HostName,
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [string[]] $Command
    )

    switch ($HostName -replace '^.*@', '') {
        'ubuntu.local' { }
        'ubuntu'       { }
        default {
            Write-Error "sshmail: $HostName is not a known card-forwarding host"
            return
        }
    }

    $gpgconf = (Get-Command gpgconf -ErrorAction Stop).Source
    $null = & $gpgconf --launch gpg-agent 2>$null
    $localSocket = (& $gpgconf --list-dirs agent-socket).Trim()
    if (-not $localSocket) {
        Write-Error 'sshmail: could not determine the local GPG agent socket'
        return
    }

    # Ask the target for its standard socket and stop its own agent/socket
    # units before the forward is created.  Ubuntu's systemd socket units can
    # otherwise reclaim the path after gpgconf --kill, defeating the forward.
    # StreamLocalBindUnlink on sshd then replaces the removed path with this
    # session's forwarded endpoint.
    # Do not capture native ssh stdout through a PowerShell pipeline here:
    # Windows OpenSSH can keep that pipeline open when it is itself running
    # under sshd.  Redirect to a file and wait for the process instead.
    $sshExe = (Get-Command ssh.exe -ErrorAction Stop).Source
    $queryOut = [IO.Path]::GetTempFileName()
    $queryErr = [IO.Path]::GetTempFileName()
    $query = Start-Process -FilePath $sshExe -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $queryOut -RedirectStandardError $queryErr `
        -ArgumentList @('-o', 'ControlPath=none', '-o', 'ConnectTimeout=5',
            $HostName, 'gpgconf --list-dirs agent-socket')
    $null = $query.WaitForExit()
    $remoteSocket = (Get-Content -LiteralPath $queryOut -Raw -ErrorAction SilentlyContinue).Trim()
    Remove-Item -LiteralPath $queryOut, $queryErr -Force -ErrorAction SilentlyContinue
    if ($remoteSocket -notmatch '^/') {
        Write-Error "sshmail: could not determine the remote GPG socket for $HostName"
        return
    }
    & ssh -o ControlPath=none -o ConnectTimeout=5 $HostName `
        'systemctl --user stop gpg-agent.socket gpg-agent-extra.socket gpg-agent-browser.socket gpg-agent-ssh.socket >/dev/null 2>&1 || true; gpgconf --kill gpg-agent; rm -f /run/user/1000/gnupg/S.gpg-agent /run/user/1000/gnupg/S.gpg-agent.extra /run/user/1000/gnupg/S.gpg-agent.browser /run/user/1000/gnupg/S.gpg-agent.ssh' 1>$null 2>$null

    $proxy = Join-Path $HOME 'dotfiles\powershell\.config\powershell\gpg-agent-proxy.ps1'
    if (-not (Test-Path -LiteralPath $proxy)) {
        Write-Error "sshmail: proxy helper not found: $proxy"
        return
    }

    $ready = [IO.Path]::GetTempFileName()
    Remove-Item -LiteralPath $ready -Force
    $pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source }
    $proxyProcess = Start-Process -FilePath $pwsh -WindowStyle Hidden -PassThru -ArgumentList @(
        '-NoProfile', '-File', $proxy, '-SocketPath', $localSocket,
        '-ReadyFile', $ready
    )

    try {
        $localPort = $null
        for ($i = 0; $i -lt 50 -and -not $localPort; $i++) {
            Start-Sleep -Milliseconds 100
            if ($proxyProcess.HasExited) {
                throw "GPG agent proxy exited with code $($proxyProcess.ExitCode)"
            }
            if (Test-Path -LiteralPath $ready) {
                $localPort = [int](Get-Content -LiteralPath $ready -Raw).Trim()
            }
        }
        if (-not $localPort) { throw 'timed out waiting for the GPG agent proxy' }

        $forward = "${remoteSocket}:127.0.0.1:${localPort}"
        & ssh -o ExitOnForwardFailure=yes -R $forward $HostName @Command
        $exitCode = $LASTEXITCODE
        if ($null -ne $exitCode) {
            $global:LASTEXITCODE = $exitCode
            return
        }
    }
    finally {
        if ($proxyProcess -and -not $proxyProcess.HasExited) {
            Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -LiteralPath $ready -Force -ErrorAction SilentlyContinue
        # Put Ubuntu's normal socket activation back after the mail session.
        & ssh -o ControlPath=none -o ConnectTimeout=5 $HostName `
            'systemctl --user start gpg-agent.socket gpg-agent-extra.socket gpg-agent-browser.socket gpg-agent-ssh.socket' 1>$null 2>$null
    }
}
