# Local URL opener for remote mu4e sessions.
# Listens only on 127.0.0.1. The SSH launcher forwards a remote localhost port
# back here, so remote Emacs can ask the *local desktop session* to open URLs
# without doing a slow SSH-back for every click.

$ErrorActionPreference = 'Stop'
$port = if ($args.Count -gt 0) { [int]$args[0] } else { 8765 }

# If already listening, do nothing.
$already = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($already) { exit 0 }

Add-Type -AssemblyName System.Web
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), $port)
$listener.Start()

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
        $requestLine = $reader.ReadLine()
        $contentLength = 0
        while (($line = $reader.ReadLine()) -ne $null -and $line -ne '') {
            if ($line -match '^Content-Length:\s*(\d+)') { $contentLength = [int]$Matches[1] }
        }
        $body = ''
        if ($contentLength -gt 0) {
            $buf = New-Object char[] $contentLength
            [void]$reader.ReadBlock($buf, 0, $contentLength)
            $body = -join $buf
        }

        $url = $null
        if ($body -match '(^|&)url=([^&]*)') {
            $url = [System.Web.HttpUtility]::UrlDecode($Matches[2])
        }

        if ($requestLine -like 'POST /open *' -and $url -match '^https?://') {
            Start-Process $url
            $response = "HTTP/1.1 204 No Content`r`nConnection: close`r`n`r`n"
        } else {
            $response = "HTTP/1.1 400 Bad Request`r`nConnection: close`r`nContent-Length: 0`r`n`r`n"
        }
        $bytes = [Text.Encoding]::ASCII.GetBytes($response)
        $stream.Write($bytes, 0, $bytes.Length)
    } catch {
        # Best effort; keep serving future clicks.
    } finally {
        $client.Close()
    }
}
