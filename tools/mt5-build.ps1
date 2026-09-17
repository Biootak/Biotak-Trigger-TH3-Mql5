# mt5-build.ps1 - deterministic MetaEditor compile for the MT5 mirror.
#
# Why this exists: compile-th3.ps1 uses Start-Process, which throws
# "Item has already been added. Key in dictionary: 'http_proxy'" on this
# machine because the environment carries both http_proxy and HTTP_PROXY.
# The duplicate is dropped here before anything is spawned.
#
# Usage:
#   .\tools\mt5-build.ps1 -Source "Biotak Trigger TH3.mq5"
#   .\tools\mt5-build.ps1 -Source "Biotak Trigger TH3 Lite.mq5" -ErrorsOnly
#   .\tools\mt5-build.ps1 -Source "<terminal junction path>\Biotak Trigger TH3.mq5" -Tag junction
#
# A summary file is always written next to the log ("<name>-<stamp>.summary.txt")
# so the outcome is readable even when this script's stdout is not captured.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [switch]$ErrorsOnly,
    [string]$Tag = "",
    [string]$Compiler = "C:\Program Files\Vittaverse  MT5 Terminal\MetaEditor64.exe"
)

$ErrorActionPreference = 'Stop'

foreach ($n in @('http_proxy', 'https_proxy', 'no_proxy', 'all_proxy')) {
    if (Test-Path "Env:$n") { Remove-Item "Env:$n" -Force }
}

$root = Split-Path -Parent $PSScriptRoot
$meta = $Compiler
if (-not (Test-Path $meta)) { throw "compiler not found at $meta" }

$src = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $root $Source }
if (-not (Test-Path $src)) { throw "source not found: $src" }

$logDir = Join-Path $root 'build-logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

# Names carry spaces ("Biotak Trigger TH3"); Start-Process splits ArgumentList on
# whitespace, so the log path must be quote-free. Sanitise it.
$name = [System.IO.Path]::GetFileNameWithoutExtension($src) -replace '\s+', '-'
if ($Tag) { $name = "$name--$Tag" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$raw = Join-Path $logDir "_raw-$name-$stamp.log"
$txt = Join-Path $logDir "$name-$stamp.log"
$summaryPath = Join-Path $logDir "$name-$stamp.summary.txt"

# Start-Process joins the array with spaces WITHOUT quoting, so both paths are
# wrapped explicitly - "Biotak Trigger TH3.mq5" is two arguments otherwise.
Start-Process -FilePath $meta -ArgumentList "/compile:`"$src`"", "/log:`"$raw`"" -Wait -WindowStyle Hidden

if (-not (Test-Path $raw)) { throw "MetaEditor produced no log for $src" }

$lines = Get-Content $raw -Encoding Unicode | ForEach-Object { $_.TrimEnd() }
$lines | Set-Content -Path $txt -Encoding UTF8

$errs = @($lines | Where-Object { $_ -match ':\s*error\s+\d+:' })
$warns = @($lines | Where-Object { $_ -match ':\s*warning\s+\d+:' })
$result = @($lines | Where-Object { $_ -match '^Result:' }) | Select-Object -Last 1

# The .ex5 is emitted next to the source. Report it so a junction build can be
# told apart from a workspace build by more than the log name.
$ex5 = [System.IO.Path]::ChangeExtension($src, '.ex5')
$ex5Info = if (Test-Path $ex5) {
    $f = Get-Item $ex5
    "$($f.FullName)  [$($f.Length) bytes, $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))]"
} else { "(no .ex5 produced)" }

$report = @()
$report += "source : $src"
$report += "log    : $txt"
$report += "ex5    : $ex5Info"
$report += "errors : $($errs.Count)"
$report += "warns  : $($warns.Count)"
$report += "result : $result"
$errs   | ForEach-Object { $report += "ERR  $_" }
$warns  | ForEach-Object { $report += "WARN $_" }
$report | Set-Content -Path $summaryPath -Encoding UTF8

if ($ErrorsOnly) {
    $errs | ForEach-Object { $_ }
} else {
    $lines | Where-Object { $_ -match ':\s*(error|warning)\s+\d+:' -or $_ -match '^Result:' } | ForEach-Object { $_ }
}

"----"
"source : $src"
"log    : $txt"
"summary: $summaryPath"
"ex5    : $ex5Info"
"errors : $($errs.Count)"
"warns  : $($warns.Count)"
"result : $result"
