# mt5-reload.ps1 - build BOTH entries, then restart the terminal so the new
# .ex5 is actually the code the charts run. One command, no manual timeframe
# flip, no stale resident build.
#
# Usage:
#   .\tools\mt5-reload.ps1              # Full + Lite, then restart
#   .\tools\mt5-reload.ps1 -FullOnly    # Full only, then restart
#   .\tools\mt5-reload.ps1 -NoRestart   # build only (diagnostics)
#
# A compile is not a reload: MetaEditor only writes bytes. Only the graceful
# restart in mt5-restart.ps1 makes those bytes live (OnDeinit saves, the fresh
# start loads the new .ex5). tools/mt5-verify.ps1 remains the instrumented loop.

[CmdletBinding()]
param(
    [string]$TerminalHash = "D0694EE1816B0E3A2D24B3606A663CE8",
    [switch]$FullOnly,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Build-One([string]$src) {
    Write-Output "== build $src =="
    & (Join-Path $PSScriptRoot 'mt5-build.ps1') -Source $src -TerminalHash $TerminalHash -NoRestart |
        Select-Object -Last 4 | ForEach-Object { Write-Output $_ }
    $sum = Get-ChildItem (Join-Path $root 'build-logs\*-*.summary.txt') -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $sum) { throw "no build summary produced for $src" }
    $errs = [int](((Get-Content $sum.FullName | Where-Object { $_ -match '^errors :' }) -replace '\D', ''))
    if ($errs -ne 0) { throw "build not green: $src ($errs errors; $($sum.FullName))" }
}

Build-One "Biotak Trigger TH3.mq5"
if (-not $FullOnly) { Build-One "Biotak Trigger TH3 Lite.mq5" }

if ($NoRestart) {
    Write-Output "== restart skipped (-NoRestart) =="
    exit 0
}

Write-Output "== restart terminal (the new .ex5 becomes the resident code) =="
& (Join-Path $PSScriptRoot 'mt5-restart.ps1') -TerminalHash $TerminalHash
