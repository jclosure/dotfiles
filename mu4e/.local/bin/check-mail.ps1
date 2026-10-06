# Check mail with mu4e from Windows.
#
# Windows has no native mu/mu4e support here, so use a remote mail host:
#   check-mail.ps1 --remote user@ubuntu

param(
    [Parameter(Position = 0)]
    [string]$Mode,

    [Parameter(Position = 1)]
    [string]$Remote
)

function Show-Usage {
    Write-Host @'
Usage:
  check-mail.ps1 --remote user@host

Windows has no native mu/mu4e support in this setup. Use --remote to SSH to a
Linux mail host. The launcher starts a localhost-only URL opener and reverse
forwards it so links clicked in remote mu4e open in the local Windows browser.

Optional:
  $env:MU4E_URL_OPENER_PORT = 8765   # fixed URL-forwarding port
'@
}

if ($Mode -ne '--remote' -or [string]::IsNullOrWhiteSpace($Remote)) {
    Show-Usage
    exit 2
}

$ErrorActionPreference = 'Stop'
$port = if ($env:MU4E_URL_OPENER_PORT) { [int]$env:MU4E_URL_OPENER_PORT } else { 8765 }
$helper = Join-Path $PSScriptRoot 'mu4e-url-opener.ps1'
$sshmail = Join-Path $HOME '.local\bin\sshmail.ps1'
if (-not (Test-Path -LiteralPath $sshmail)) {
    $sshmail = Join-Path $HOME 'dotfiles\powershell\.local\bin\sshmail.ps1'
}
if (-not (Test-Path -LiteralPath $sshmail)) {
    Write-Error 'check-mail.ps1: sshmail.ps1 not found; run ./winstow.ps1 powershell or sync dotfiles'
    exit 1
}

# Start helper if it is not already listening.
$already = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $already) {
    $pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell.exe).Source }
    Start-Process -WindowStyle Hidden -FilePath $pwsh -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,$port)
    Start-Sleep -Milliseconds 300
}

$remoteCommand = "export TERM=xterm-256color COLORTERM=truecolor MU4E_OPEN_URL_ENDPOINT=http://127.0.0.1:$port/open; if command -v mu4e-inbox >/dev/null 2>&1; then exec mu4e-inbox; elif [ -x `"`$HOME/.local/bin/mu4e-inbox`" ]; then exec `"`$HOME/.local/bin/mu4e-inbox`"; else echo 'check-mail.ps1: mu4e-inbox not found on remote host; install dotfiles/mu4e there with: cd ~/dotfiles && stow mu4e' >&2; exit 127; fi"

& $sshmail -SshArg @('-t', '-R', "127.0.0.1:$port`:127.0.0.1:$port") $Remote $remoteCommand
exit $LASTEXITCODE
