# mt5-restart.ps1 - graceful close + relaunch of the ONE terminal this repo owns.
#
# Why this exists: MetaEditor writing a new .ex5 does NOT reload the code an
# attached indicator is already executing. The terminal keeps the old bytes
# until the indicator is removed, the timeframe flips, or the terminal
# restarts. The user must never have to perform that timeframe flip by hand.
#
# A graceful close is mandatory: every OnDeinit runs (so the settings save),
# and the profile restores on the next start. This script NEVER force-kills -
# if the window will not close, it says so and leaves the terminal untouched.
#
# Usage:
#   .\tools\mt5-restart.ps1
#   .\tools\mt5-restart.ps1 -TerminalHash <hash> -CloseTimeoutSec 120
#
# The caller (tools/mt5-reload.ps1) builds first, then calls this.

[CmdletBinding()]
param(
    [string]$TerminalHash = "D0694EE1816B0E3A2D24B3606A663CE8",
    [int]$CloseTimeoutSec = 90,
    [int]$BootTimeoutSec = 45
)

$ErrorActionPreference = 'Stop'

$termRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalHash"
$originFile = Join-Path $termRoot 'origin.txt'
if (-not (Test-Path $originFile)) { throw "terminal data folder not found: $termRoot" }
$exe = Join-Path ((Get-Content $originFile -ErrorAction Stop).Trim()) 'terminal64.exe'
if (-not (Test-Path $exe)) { throw "terminal exe not found: $exe" }

$mqlLogDir = Join-Path $termRoot 'MQL5\logs'
$todayName = (Get-Date).ToString('yyyyMMdd') + '.log'
$todayLog = Join-Path $mqlLogDir $todayName

function Log-LineCount {
    if (Test-Path $todayLog) { return (Get-Content $todayLog | Measure-Object -Line).Lines }
    return 0
}

$mark = Log-LineCount
$procs = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
if ($procs.Count -eq 0) {
    Write-Output "terminal not running; starting it"
} else {
    foreach ($p in $procs) {
        Write-Output "closing pid $($p.Id) ..."
        if (-not $p.CloseMainWindow()) {
            throw "pid $($p.Id): no main window to close; refusing to force-kill"
        }
    }
    $deadline = (Get-Date).AddSeconds($CloseTimeoutSec)
    do {
        Start-Sleep -Milliseconds 500
        $alive = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
    } while ($alive.Count -gt 0 -and (Get-Date) -lt $deadline)
    if ($alive.Count -gt 0) {
        throw "terminal did not exit in $CloseTimeoutSec s (a modal dialog may be open); left untouched"
    }
    Write-Output "closed cleanly"
}

Start-Process -FilePath $exe | Out-Null

$deadline = (Get-Date).AddSeconds($BootTimeoutSec)
$fresh = @()
$ok = $false
do {
    Start-Sleep -Seconds 1
    $n = Log-LineCount
    $fresh = if ($n -gt $mark) { @(Get-Content $todayLog | Select-Object -Skip $mark) } else { @() }
    $ok = @($fresh | Where-Object { $_ -match 'OnInit|MT5-COMPAT' }).Count -gt 0
} while (-not $ok -and (Get-Date) -lt $deadline)

Write-Output ("started; fresh log lines: " + $fresh.Count)
$fresh | Where-Object { $_ -match 'OnInit|\[P-UI-223\]|MT5-COMPAT' } |
    Select-Object -First 10 | ForEach-Object { Write-Output ("  " + $_) }
if (-not $ok) {
    throw "terminal started but no OnInit/MT5-COMPAT line appeared in $BootTimeoutSec s"
}
