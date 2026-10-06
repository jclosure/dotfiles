<#
.SYNOPSIS
Kill processes whose names contain a string.

.EXAMPLE
killp chrome

.EXAMPLE
killp node -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Name,

    [switch] $IncludeCurrentProcess
)

$needle = $Name
$currentPid = $PID

$matches = Get-Process | Where-Object {
    ($IncludeCurrentProcess -or $_.Id -ne $currentPid) -and
    ($_.ProcessName.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0)
} | Sort-Object ProcessName, Id

if (-not $matches) {
    Write-Error "killp: no process name contains '$Name'"
    exit 1
}

foreach ($process in $matches) {
    $target = "$($process.ProcessName) ($($process.Id))"
    if ($PSCmdlet.ShouldProcess($target, 'Stop-Process -Force')) {
        Stop-Process -Id $process.Id -Force -ErrorAction Stop
        Write-Host "Killed $target"
    }
}
