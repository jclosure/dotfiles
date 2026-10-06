# Launch remote Ubuntu terminal Emacs directly into mu4e Inbox and start a sync.
# Starts a local localhost-only URL opener and forwards a remote localhost port
# to it so mu4e HTML links open quickly on this Windows desktop.

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Remote
)

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
