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
    # A compile is NOT a reload: MetaEditor only writes the .ex5; the attached
    # chart keeps executing the old bytes. MT4's own editor notifies its
    # terminal; an external CLI compile (this script) does not. The standing
    # rule is therefore: a successful MT5 build restarts the terminal itself,
    # so the user never has to flip the timeframe by hand. -NoRestart is for
    # the wrapper (tools/mt5-reload.ps1), which restarts once after both entries.
    [switch]$NoRestart,
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

# --- the COMPILER's own data folder ---------------------------------------
# `#resource "\\Files\\Icons\\x.bmp"` is resolved by MetaEditor against the data
# folder of the terminal IT belongs to - not against the one this script builds
# into, and not against the source tree. The compiler here is another install
# (see $Compiler), so a raster copied only to the runtime terminal is "resource
# file not found" at compile time even though the .bmp sits in Files/Icons and
# on the chart's own terminal. MEASURED 2026-10-23: the compiler's folder held
# 370 icons and lacked bk_anchor_on/off.bmp, which is exactly the pair MT5's
# DrawStrip had no #resource line for - the port dropped the directives because
# the compile failed, and the LAST OBJECT cell painted no art ever since.
# Map the compiler back to its terminal through origin.txt (each terminal data
# folder records the install path it belongs to), then feed it the same set.
$compilerIcons = $null
$compilerDir = Split-Path -Parent $meta
try {
    foreach ($d in Get-ChildItem (Join-Path $env:APPDATA 'MetaQuotes\Terminal') -Directory -ErrorAction SilentlyContinue) {
        $origin = Join-Path $d.FullName 'origin.txt'
        if (-not (Test-Path $origin)) { continue }
        $raw = (Get-Content $origin -Raw -Encoding Unicode) -replace "`0", ''
        if ($raw.Trim().TrimEnd('\') -ieq $compilerDir.TrimEnd('\')) {
            $cand = Join-Path $d.FullName 'MQL5\Files\Icons'
            if (Test-Path $cand) { $compilerIcons = $cand; break }
        }
    }
} catch { $compilerIcons = $null }
if ($compilerIcons -and ($compilerIcons -ne $iconDst)) {
    Copy-Item (Join-Path $iconSrc '*.bmp') $compilerIcons -Force
    $cHave = @(Get-ChildItem $compilerIcons -Filter *.bmp -ErrorAction SilentlyContinue).Count
    $pre += "compiler icons: $cHave/$want"
} elseif (-not $compilerIcons) {
    $pre += "compiler icons: terminal of $compilerDir not found (a new #resource will fail to compile)"
}

# --- build identity -------------------------------------------------------
# MT4's tools/gen-build-hash.js owns Biotak/BuildHash.mqh and drops the same
# hash at <terminal>\MQL4\Files\th3-src.txt on every build, so a chart can
# contradict its own banner (TH3SourceStampTail -> srcfile=... match=yes|NO).
# This tree had neither: the hash was frozen at commit cf10c2d and every MT5
# build printed it, which is the eight-day confusion P-BUILD-08 ended on MT4.
# Ported 2026-10-23 - regenerate before the compile, then publish the stamp
# beside THIS terminal. A missing node is a warning, never a failed build.
$stampLine = $null
if ([System.IO.Path]::GetExtension($src).ToLower() -eq '.mq5') {
    $gen = Join-Path $root 'tools\gen-build-hash.js'
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ((Test-Path $gen) -and $node) {
        try {
            $line = @(& node $gen 2>&1 | ForEach-Object { "$_" }) | Select-Object -Last 1
            if ($line -match '^hash=[0-9a-f]{16} short=[0-9a-f]{8} files=\d+') {
                $stampLine = $line.Trim()
                $pre += "buildhash: $stampLine"
            } else {
                $pre += "buildhash: generator produced no hash ($line)"
            }
        } catch {
            $pre += "buildhash: generator failed ($($_.Exception.Message))"
        }
    } else {
        $pre += "buildhash: node or tools/gen-build-hash.js missing - BuildHash.mqh left as-is"
    }
    # FileOpen(FILE_TXT|FILE_ANSI) is what BuildConfig reads; plain ASCII, one line.
    $stampPath = Join-Path $terminalRoot 'MQL5\Files\th3-src.txt'
    if ($stampLine) {
        Set-Content -Path $stampPath -Value $stampLine -Encoding ASCII
        $pre += "stamp: th3-src.txt = $stampLine"
    }
}

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
#
# THE BROKER FALLBACK (2026-10-23). On this machine a MetaEditor64.exe spawned
# from an automation process can die before it writes a log with
#   0xC0000139 STATUS_ENTRYPOINT_NOT_FOUND
# ("The procedure entry point ... could not be located in the dynamic link
# library ...\MetaEditor64.exe") - a modal dialog the caller never sees, and no
# log at all. The SAME exe launched from Explorer or from Task Scheduler
# compiles normally, so the exe is not broken: the loader in this process tree
# is. `mt5-sched-build.ps1` already existed for that, and this is the same
# broker wired into the standard path so a session never has to know about it:
# try the direct spawn, and if it produces no log, hand the identical command
# line to Task Scheduler - which runs it in the user's own interactive session,
# exactly like a manual F7 - and wait for that log instead.
function Invoke-MetaCompile {
    param([string]$Exe, [string]$Source, [string]$LogPath, [int]$TimeoutSec = 300)
    if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
    # THE MEMORY OF THE FAILURE. The trap is a property of this machine, not of
    # one build, and every direct attempt costs the user a modal dialog they have
    # to dismiss by hand. So the first failure writes this marker and every later
    # build goes straight to the broker: at most ONE dialog, ever.
    $marker = Join-Path $logDir '.metaeditor-direct-broken'
    if (-not (Test-Path $marker)) {
        try {
            $p = Start-Process -FilePath $Exe -ArgumentList "/compile:`"$Source`"", "/log:`"$LogPath`"" -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
        } catch {
            Write-Output "direct compile spawn failed: $($_.Exception.Message)"
        }
        if (Test-Path $LogPath) { return 'direct' }
        # P-BUILD-15 (2026-10-24): `0xFFFFFFFF` is parsed by PowerShell 5.1 as
        # int32 -1, so `-band` returned the NEGATIVE code unchanged and the
        # [uint32] cast threw "Value was either too large or too small" — the
        # broker below never ran and the build died with no compile at all.
        # The `L` suffix makes the mask the int64 it has to be.
        $code = if ($p) { "0x{0:X8}" -f [uint32]([int64]$p.ExitCode -band 0xFFFFFFFFL) } else { 'spawn-failed' }
        Set-Content -Path $marker -Value ("$code " + (Get-Date -Format 's')) -Encoding ASCII
        Write-Output "direct spawn produced no log ($code) - brokering through Task Scheduler from now on"
    }

    $taskName = "BiotakCompile-" + [System.IO.Path]::GetFileNameWithoutExtension($Source).Replace(' ', '-')
    $act = New-ScheduledTaskAction -Execute $Exe -Argument "/compile:`"$Source`" /log:`"$LogPath`""
    $pr  = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
    Register-ScheduledTask -TaskName $taskName -Action $act -Principal $pr -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $last = -1
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $state = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
        if ((Test-Path $LogPath) -and $state -eq 'Ready') {
            $sz = (Get-Item $LogPath).Length
            if ($sz -eq $last -and $sz -gt 0) { break }
            $last = $sz
        }
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    if (Test-Path $LogPath) { return 'scheduler' }
    return ''
}

$how = Invoke-MetaCompile -Exe $meta -Source $src -LogPath $raw
if (-not $how) { throw "MetaEditor produced no log for $src (direct spawn and Task Scheduler both failed)" }
$pre += "compile: $how"

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

# MAKE THE BUILD LIVE. The terminal keeps the old .ex5 until it restarts, so a
# green compile without this step is a chart still running yesterday's code -
# exactly the "I must change the timeframe for it to apply" report. Only an
# MT5 source and only a green build; the MT4 sanity compile must never touch
# the MT5 terminal.
if (-not $NoRestart -and [System.IO.Path]::GetExtension($src).ToLower() -eq '.mq5' -and $errs.Count -eq 0) {
    & (Join-Path $PSScriptRoot 'mt5-restart.ps1') -TerminalHash $TerminalHash
}
