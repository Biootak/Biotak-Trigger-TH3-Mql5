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
    [string]$Compiler = "C:\Program Files\Vittaverse  MT5 Terminal\MetaEditor64.exe",
    # THE terminal this repository builds for. One hash, one target: the old
    # F5617C4B... instance is retired and its junction has been removed, so a
    # build that quietly lands in the wrong data folder is the failure mode this
    # parameter exists to prevent.
    [string]$TerminalHash = "D0694EE1816B0E3A2D24B3606A663CE8"
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

# --- deployment preflight -------------------------------------------------
# The terminal reaches this repository through ONE junction, and the indicator
# loads its icon assets from that terminal's MQL5\Files\Icons. Neither survives
# a terminal reinstall or a fresh clone, and both fail in a way that looks like
# an unrelated problem (a compile that cannot resolve "#resource", or a chart
# with blank buttons), so they are checked on every build instead.
$terminalRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalHash"
$linkPath     = Join-Path $terminalRoot 'MQL5\Indicators\Biotak-Trigger-TH3'
$iconDst      = Join-Path $terminalRoot 'MQL5\Files\Icons'
$iconSrc      = Join-Path $root 'Files\Icons'

if (-not (Test-Path $terminalRoot)) { throw "terminal data folder not found: $terminalRoot" }

$pre = @()
if (Test-Path $linkPath) {
    $tgt = (Get-Item $linkPath).Target
    if ($tgt -ne $root) {
        # rmdir takes the LINK off; it never walks into the target tree.
        cmd /c rmdir "$linkPath" | Out-Null
        cmd /c mklink /J "$linkPath" "$root" | Out-Null
        $pre += "junction: repointed $root"
    } else { $pre += "junction: ok" }
} else {
    cmd /c mklink /J "$linkPath" "$root" | Out-Null
    $pre += "junction: created"
}

$want = @(Get-ChildItem $iconSrc -Filter *.bmp -ErrorAction SilentlyContinue).Count
if (-not (Test-Path $iconDst)) { New-Item -ItemType Directory -Path $iconDst -Force | Out-Null }
Copy-Item (Join-Path $iconSrc '*.bmp') $iconDst -Force
$have = @(Get-ChildItem $iconDst -Filter *.bmp -ErrorAction SilentlyContinue).Count
$pre += "icons: $have/$want"

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
$report += "terminal: $TerminalHash"
$report += "preflight: $($pre -join '; ')"
$report += "source : $src"
$report += "log    : $txt"
$report += "ex5    : $ex5Info"
$report += "errors : $($errs.Count)"
$report += "warns  : $($warns.Count)"
$report += "result : $result"
$errs   | ForEach-Object { $report += "ERR  $_" }
$warns  | ForEach-Object { $report += "WARN $_" }
$report | Set-Content -Path $summaryPath -Encoding UTF8

# ---- prune old build-logs (keep last 5 per source name, drop all _raw-*) ---
# _raw-* are the temporary Unicode copies MetaEditor writes; after the UTF-8
# transcript is saved they are never read again but pile up to hundreds of MB.
# The cleaned .log + .summary pairs are kept (last 5 per source), so git blame
# can still see the last handful of builds without dragging 300+ files along.
try {
    # always nuke raw files
    Get-ChildItem $logDir -Filter '_raw-*.log' -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # per-source group: derived from the source-file stem (same logic that named $name)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($src) -replace '\s+', '-'
    # collect all .log files whose name STARTS with the stem (exclude raw already gone)
    $grp = @(Get-ChildItem $logDir -Filter "$stem-*.log" -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending)
    if ($grp.Count -gt 5) {
        $grp | Select-Object -Skip 5 | ForEach-Object {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            $sumFile = $_.FullName -replace '\.log$', '.summary.txt'
            if (Test-Path $sumFile) { Remove-Item $sumFile -Force -ErrorAction SilentlyContinue }
        }
    }
} catch { <# best-effort; never abort the build for a prune failure #> }

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
