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

# Start helper if it is not already listening.
$already = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if (-not $already) {
    $pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = (Get-Command powershell.exe).Source }
    Start-Process -WindowStyle Hidden -FilePath $pwsh -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,$port)
    Start-Sleep -Milliseconds 300
}

ssh -t -R "127.0.0.1:$port`:127.0.0.1:$port" $Remote "TERM=xterm-256color COLORTERM=truecolor MU4E_OPEN_URL_ENDPOINT=http://127.0.0.1:$port/open /home/user/.local/bin/mu4e-inbox"
