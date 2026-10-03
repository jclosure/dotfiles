# Bridge a Windows GnuPG AF_UNIX socket to a loopback TCP port.
#
# Native Windows OpenSSH cannot use a drive-letter AF_UNIX path as the local
# endpoint of `RemoteForward`, while GnuPG's Windows socket is represented by
# a small file containing a localhost port and nonce.  This bridge speaks that
# little GnuPG socket wrapper, then carries the agent's Assuan bytes over TCP.
# It is started and stopped by sshmail in profile.ps1; it is not a public
# listener (the listener is bound to loopback only).

param(
    [Parameter(Mandatory = $true)]
    [string] $SocketPath,

    [int] $ListenPort = 0,

    [Parameter(Mandatory = $true)]
    [string] $ReadyFile
)

$ErrorActionPreference = 'Stop'

$socketBytes = [IO.File]::ReadAllBytes($SocketPath)
$lineEnd = [Array]::IndexOf($socketBytes, [byte] 10)
if ($lineEnd -lt 1 -or $lineEnd -ge ($socketBytes.Length - 1)) {
    throw "GnuPG socket file is not in the expected Windows format: $SocketPath"
}

$agentPort = [int]([Text.Encoding]::ASCII.GetString($socketBytes, 0, $lineEnd).Trim())
$nonce = $socketBytes[($lineEnd + 1)..($socketBytes.Length - 1)]

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $ListenPort)
$listener.Start()
$actualPort = ([Net.IPEndPoint] $listener.LocalEndpoint).Port
[IO.File]::WriteAllText($ReadyFile, [string] $actualPort)

function Copy-AgentConnection([Net.Sockets.TcpClient] $Client) {
    $agent = $null
    try {
        $agent = [Net.Sockets.TcpClient]::new('127.0.0.1', $agentPort)
        $agentStream = $agent.GetStream()
        # Windows GnuPG authenticates a localhost socket with the nonce stored
        # beside it before it emits the normal Assuan greeting.
        $agentStream.Write($nonce, 0, $nonce.Length)
        $agentStream.Flush()

        $clientStream = $Client.GetStream()
        $toAgent = $clientStream.CopyToAsync($agentStream)
        $toClient = $agentStream.CopyToAsync($clientStream)
        [Threading.Tasks.Task]::WaitAny([Threading.Tasks.Task[]] @($toAgent, $toClient)) | Out-Null
    }
    finally {
        if ($agent) { $agent.Dispose() }
        if ($Client) { $Client.Dispose() }
    }
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        # GnuPG opens agent connections serially for the operations used by
        # gpg/mu4e.  Handle one at a time; keeping this in the same PowerShell
        # scope also preserves the socket nonce and agent port variables.
        Copy-AgentConnection $client
    }
}
finally {
    $listener.Stop()
    Remove-Item -LiteralPath $ReadyFile -Force -ErrorAction SilentlyContinue
}
