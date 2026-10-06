<#
.SYNOPSIS
Mail-aware ssh wrapper.

.DESCRIPTION
For Linux mail hosts, forwards the local Gpg4win gpg-agent socket through a
loopback TCP bridge so remote Emacs/mu4e can sign/decrypt with the local
YubiKey. For macOS/non-Linux mail hosts, falls back to normal ssh; those hosts
usually have their own local agent/key setup.

.EXAMPLE
sshmail.ps1 user@ubuntu '~/.local/bin/mu4e-inbox'

.EXAMPLE
sshmail.ps1 -SshArg -t -SshArg '-R 127.0.0.1:8765:127.0.0.1:8765' user@ubuntu 'echo hi'
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]] $SshArg = @(),

    [Parameter(Mandatory = $true, Position = 0)]
    [string] $HostName,

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]] $Command
)

$ErrorActionPreference = 'Stop'

function Invoke-SshPlain {
    param([string[]] $ExtraSshArg = @())
    & ssh.exe -o ServerAliveInterval=15 -o ServerAliveCountMax=3 @ExtraSshArg $HostName @Command
    exit $LASTEXITCODE
}

function Get-Gpg4winGpgconf {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'GnuPG\bin\gpgconf.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'GnuPG\bin\gpgconf.exe')
    }
    $candidates += (Get-Command gpgconf.exe -All -ErrorAction SilentlyContinue | ForEach-Object Source)

    foreach ($candidate in ($candidates | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $candidate)) { continue }
        $socket = (& $candidate --list-dirs agent-socket 2>$null).Trim()
        # Gpg4win reports a normal Windows path whose file contains the
        # localhost port + nonce. Git/MSYS GnuPG reports /c/... and cannot be
        # forwarded by this Windows OpenSSH bridge.
        if ($socket -match '^[A-Za-z]:\\') { return $candidate }
    }

    throw 'sshmail: Gpg4win gpgconf.exe was not found; install Gpg4win or put it on PATH before Git\usr\bin'
}

function Get-RemoteKernelName {
    $out = & ssh.exe -o BatchMode=yes -o ConnectTimeout=5 $HostName 'uname -s' 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($out | Select-Object -First 1).Trim()
}

$kernel = Get-RemoteKernelName
if ($kernel -ne 'Linux') {
    Invoke-SshPlain -ExtraSshArg $SshArg
}

$gpgconf = Get-Gpg4winGpgconf
$null = & $gpgconf --launch gpg-agent 2>$null
$localSocket = (& $gpgconf --list-dirs agent-socket).Trim()
if (-not $localSocket) {
    throw 'sshmail: could not determine the local GPG agent socket'
}

# Ask the target for its standard socket and stop its own agent/socket units
# before the forward is created. Ubuntu's systemd socket units can otherwise
# reclaim the path after gpgconf --kill, defeating the forward.
$queryOut = [IO.Path]::GetTempFileName()
$queryErr = [IO.Path]::GetTempFileName()
$query = Start-Process -FilePath (Get-Command ssh.exe -ErrorAction Stop).Source -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $queryOut -RedirectStandardError $queryErr `
    -ArgumentList @('-o', 'ControlPath=none', '-o', 'ConnectTimeout=5', $HostName, 'gpgconf --list-dirs agent-socket')
$null = $query.WaitForExit()
$remoteSocket = (Get-Content -LiteralPath $queryOut -Raw -ErrorAction SilentlyContinue).Trim()
Remove-Item -LiteralPath $queryOut, $queryErr -Force -ErrorAction SilentlyContinue
if ($remoteSocket -notmatch '^/') {
    throw "sshmail: could not determine the remote GPG socket for $HostName"
}

& ssh.exe -o ControlPath=none -o ConnectTimeout=5 $HostName `
    'systemctl --user stop gpg-agent.socket gpg-agent-extra.socket gpg-agent-browser.socket gpg-agent-ssh.socket >/dev/null 2>&1 || true; gpgconf --kill gpg-agent; rm -f /run/user/1000/gnupg/S.gpg-agent /run/user/1000/gnupg/S.gpg-agent.extra /run/user/1000/gnupg/S.gpg-agent.browser /run/user/1000/gnupg/S.gpg-agent.ssh' 1>$null 2>$null

$packageRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$proxy = Join-Path $packageRoot '.config\powershell\gpg-agent-proxy.ps1'
if (-not (Test-Path -LiteralPath $proxy)) {
    throw "sshmail: proxy helper not found: $proxy"
}

$ready = [IO.Path]::GetTempFileName()
Remove-Item -LiteralPath $ready -Force
$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source }
$proxyOut = [IO.Path]::GetTempFileName()
$proxyErr = [IO.Path]::GetTempFileName()
$proxyProcess = Start-Process -FilePath $pwsh -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput $proxyOut -RedirectStandardError $proxyErr `
    -ArgumentList @('-NoProfile', '-File', $proxy, '-SocketPath', $localSocket, '-ReadyFile', $ready)

$mailExitCode = 1
try {
    $localPort = $null
    for ($i = 0; $i -lt 50 -and -not $localPort; $i++) {
        Start-Sleep -Milliseconds 100
        if ($proxyProcess.HasExited) {
            $proxyError = (Get-Content -LiteralPath $proxyErr -Raw -ErrorAction SilentlyContinue).Trim()
            if (-not $proxyError) { $proxyError = (Get-Content -LiteralPath $proxyOut -Raw -ErrorAction SilentlyContinue).Trim() }
            if ($proxyError) {
                throw "GPG agent proxy exited with code $($proxyProcess.ExitCode): $proxyError"
            }
            throw "GPG agent proxy exited with code $($proxyProcess.ExitCode)"
        }
        if (Test-Path -LiteralPath $ready) {
            $localPort = [int](Get-Content -LiteralPath $ready -Raw).Trim()
        }
    }
    if (-not $localPort) { throw 'timed out waiting for the GPG agent proxy' }

    $forward = "${remoteSocket}:127.0.0.1:${localPort}"
    & ssh.exe -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -R $forward @SshArg $HostName @Command
    $mailExitCode = $LASTEXITCODE
}
finally {
    if ($proxyProcess -and -not $proxyProcess.HasExited) {
        Stop-Process -Id $proxyProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $ready, $proxyOut, $proxyErr -Force -ErrorAction SilentlyContinue
    & ssh.exe -o ControlPath=none -o ConnectTimeout=5 $HostName `
        'systemctl --user start gpg-agent.socket gpg-agent-extra.socket gpg-agent-browser.socket gpg-agent-ssh.socket' 1>$null 2>$null
}

exit $mailExitCode
