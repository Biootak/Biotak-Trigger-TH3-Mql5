# mt5-verify.ps1 - the closed loop the user asked for: build, prune old logs,
# restart the ONE terminal this repo owns, watch its fresh log, and report a
# verdict against measured thresholds. No manual steps remain.
#
# Usage:
#   .\tools\mt5-verify.ps1                                   # everything
#   .\tools\mt5-verify.ps1 -NoRestart                        # build + prune only
#   .\tools\mt5-verify.ps1 -WaitSec 90 -MenuBudgetMs 100     # tighter loop
#
# What "verified" means, each with the evidence it reads:
#   BUILD ....... errors = 0            (mt5-build summary)
#   GEST ........ no [gest] lines       (the census stays off unless GESTURE_CENSUS)
#   TEARDOWN .... menu <= budget        (DeleteMenu must not take a second)
#   INIT ........ reported, no threshold (warm ~359ms; kept as a number, not a gate)
#   LEDGER ...... reported verbatim     (compat cost must be ~0ms)
#
# Why TWO shutdowns: MetaEditor writing a new .ex5 does NOT reload the code an
# attached indicator is already running - the terminal keeps executing the old
# bytes until the indicator is removed, the timeframe flips, or the terminal
# restarts. So the first shutdown tears down the PREVIOUS build (still resident
# in memory) and only the second one - after a restart has loaded the fresh
# .ex5 - measures THIS build. The loop therefore ends with the terminal left
# RUNNING (one final start) and reports both numbers: prev vs curr.
#
# Why a restart verifies: a graceful close runs every OnDeinit (so the teardown
# ledger prints), a fresh start runs every OnInit and the 60 s compat heartbeat.
# A force-kill would skip OnDeinit - this script never force-kills; if the
# terminal does not close gracefully on its own, the script aborts and says so.

[CmdletBinding()]
param(
    [string]$Source = "Biotak Trigger TH3.mq5",
    [string]$TerminalHash = "D0694EE1816B0E3A2D24B3606A663CE8",
    [switch]$NoRestart,
    [switch]$NoPrune,
    [int]$WaitSec = 150,
    [int]$MenuBudgetMs = 150,
    [string]$Compiler = "C:\Program Files\Vittaverse  MT5 Terminal\MetaEditor64.exe"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$termRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\$TerminalHash"
$mqlLogDir = Join-Path $termRoot 'MQL5\logs'
$platLogDir = Join-Path $termRoot 'logs'
$todayName = (Get-Date).ToString('yyyyMMdd') + '.log'
$shutdownMark = 0   # line count of today's log before this run; only newer lines are judged

function Say($s) { Write-Output $s }

# ---------------------------------------------------------------- build ---
Say "== 1/5 build =="
& (Join-Path $root 'tools\mt5-build.ps1') -Source $Source -Compiler $Compiler -Tag verify |
    Select-Object -Last 4 | ForEach-Object { Say $_ }
$sum = Get-ChildItem (Join-Path $root 'build-logs\*-verify-*.summary.txt') -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$buildErr = -1
if ($sum) {
    $buildErr = [int]((Get-Content $sum.FullName | Where-Object { $_ -match '^errors :' }) -replace '\D','')
}
Say "build errors: $buildErr"
if ($buildErr -ne 0) { Say "ABORT: build is not green."; exit 1 }

# ---------------------------------------------------------------- prune ---
if (-not $NoPrune) {
    Say "== 2/5 prune old logs (only today stays) =="
    $gone = @()
    Get-ChildItem $mqlLogDir -Filter *.log -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $todayName } | ForEach-Object {
            $gone += "MQL5\logs\$($_.Name)"; Remove-Item $_.FullName -Force
        }
    Get-ChildItem $platLogDir -Filter *.log -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $todayName -and $_.Name -ne 'metaeditor.log' } |
        ForEach-Object { $gone += "logs\$($_.Name)"; Remove-Item $_.FullName -Force }
    if ($gone.Count) { $gone | ForEach-Object { Say "  del $_" } } else { Say "  nothing old to delete" }
}

$exe = (Get-Content (Join-Path $termRoot 'origin.txt') -ErrorAction Stop).Trim() + '\terminal64.exe'
$todayLog = Join-Path $mqlLogDir $todayName

if ($NoRestart) { Say "== restart skipped (-NoRestart) =="; exit 0 }

# ------------------------------------------------- graceful shutdown ------
function Close-Terminal($exe) {
    $procs = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
    if ($procs.Count -eq 0) { Say "  (not running)"; return $false }
    foreach ($p in $procs) {
        Say "  closing pid $($p.Id) ..."
        if (-not $p.CloseMainWindow()) { Say "ABORT: no main window to close; refusing to force-kill."; exit 1 }
    }
    $deadline = (Get-Date).AddSeconds(90)
    do {
        Start-Sleep 2
        $procs = @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
    } while ($procs.Count -gt 0 -and (Get-Date) -lt $deadline)
    if ($procs.Count -gt 0) {
        Say "ABORT: terminal did not exit in 90 s (a modal dialog may be open). Left untouched."
        exit 1
    }
    Say "  exited cleanly"
    return $true
}

function Log-Lines($from, $to) {
    if (-not (Test-Path $todayLog)) { return @() }
    $n = (Get-Content $todayLog | Measure-Object -Line).Lines
    $skip = [Math]::Min($from, $n)
    $take = [Math]::Max(0, [Math]::Min($to, $n) - $skip)
    if ($take -le 0) { return @() }
    return @(Get-Content $todayLog | Select-Object -Skip $skip | Select-Object -First $take)
}

function Menu-Of($lines) {
    $out = @()
    foreach ($ln in $lines) {
        if ($ln -match 'OnDeinit breakdown:\s*pnl=\d+ms\s+menu=(\d+)ms') { $out += [int]$Matches[1] }
    }
    return $out
}

Say "== 3/6 shutdown #1 (tears down the PREVIOUS resident build) =="
$mark0 = 0
if (Test-Path $todayLog) { $mark0 = (Get-Content $todayLog | Measure-Object -Line).Lines }
Close-Terminal $exe
$mark1 = $mark0
if (Test-Path $todayLog) { $mark1 = (Get-Content $todayLog | Measure-Object -Line).Lines }
$prevLines = Log-Lines $mark0 $mark1

# ----------------------------------------------------------- restart ------
Say "== 4/6 start (loads THIS build) + watch ${WaitSec}s =="
Start-Process -FilePath $exe | Out-Null
$deadline = (Get-Date).AddSeconds($WaitSec)
$seen = @{}
do {
    Start-Sleep 5
    if (Test-Path $todayLog) {
        $fresh = Get-Content $todayLog | Select-Object -Skip $shutdownMark
        foreach ($ln in $fresh) {
            if ($ln -match 'OnDeinit breakdown') { $seen['teardown'] = $true }
            if ($ln -match 'OnInit \(ok\)') { $seen['init'] = $true }
            if ($ln -match 'MT5-COMPAT\] 60s') { $seen['beat'] = $true }
        }
    }
} while ((Get-Date) -lt $deadline -and -not ($seen['teardown'] -and $seen['init'] -and $seen['beat']))

# --------------------------------------------------------------- check ----
Say "== 5/6 shutdown #2 (tears down THIS build - the measured verdict) =="
$mark2 = 0
if (Test-Path $todayLog) { $mark2 = (Get-Content $todayLog | Measure-Object -Line).Lines }
Close-Terminal $exe
$mark3 = $mark2
if (Test-Path $todayLog) { $mark3 = (Get-Content $todayLog | Measure-Object -Line).Lines }
$currLifeLines = Log-Lines $mark1 $mark2      # init + heartbeats + interaction, new build only
$currDownLines = Log-Lines $mark2 $mark3      # teardowns of the new build only
Say "== 6/6 final start (leave the terminal running for the user) =="
Start-Process -FilePath $exe | Out-Null
Start-Sleep 10
# --------------------------------------------------------------- check ----
Say "== 7/7 verdict (windowed: prev teardown / new life / new teardown) =="

$fail = 0
# NOTE: a PowerShell function assigned to a variable captures EVERYTHING it
# emits, including Say. So Menu-Line communicates its text through a side
# channel and returns ONLY the number; anything else and both the verdict
# line and the number vanish into the same array.
$menuText = @{}
function Menu-Line($tag, $arr) {
    if ($arr.Count -eq 0) { $script:menuText[$tag] = "  TEARDOWN menu ($tag): (none observed)"; return }
    $worst = ($arr | Measure-Object -Maximum).Maximum
    $v = if ($worst -le $MenuBudgetMs) { 'PASS' } else { 'FAIL' }
    $script:menuText[$tag] = ("  TEARDOWN menu ({0}): {1} (worst of {2}, budget {3})" -f $tag, $v, ($arr -join '/'), $MenuBudgetMs)
    if ($worst -gt $MenuBudgetMs) { $script:fail = 1 }
    return $worst
}
$prevWorst = Menu-Line "previous build" (Menu-Of $prevLines)
$currWorst = Menu-Line "THIS build" (Menu-Of $currDownLines)
Say $script:menuText["previous build"]
Say $script:menuText["THIS build"]
if ($prevWorst -and $currWorst) {
    Say ("  DELTA: {0}ms -> {1}ms" -f $prevWorst, $currWorst)
}
# census + init + ledger + interaction: NEW build's lifetime only
$newLife = $currLifeLines
Say "  windows: prev-teardown=$(($prevLines|Measure-Object).Count) new-life=$(($newLife|Measure-Object).Count) new-teardown=$(($currDownLines|Measure-Object).Count)"
# census
$gest = @($newLife | Where-Object { $_ -match '\[gest\]\s+id=' }).Count
if ($gest -eq 0) { Say "  GEST census lines: PASS (0)" }
else { Say "  GEST census lines: FAIL ($gest)"; $fail = 1 }
# init
$inits = @($newLife | Where-Object { $_ -match 'OnInit \(ok\)[^\[]*\[ind=(\d+)' } | ForEach-Object { [int]$Matches[1] })
if ($inits.Count) { Say ("  INIT ind: {0}ms (reported, no gate)" -f (($inits | Measure-Object -Maximum).Maximum)) }
else { Say "  INIT: (no fresh init observed - was the indicator attached?)" }
# ledger
$beats = @($newLife | Where-Object { $_ -match 'MT5-COMPAT\] 60s' } | ForEach-Object { ($_ -replace '^.*MT5-COMPAT\]\s*','') })
if ($beats.Count) { Say "  LEDGER latest: $($beats[-1])" }
else { Say "  LEDGER: (no 60 s heartbeat yet)" }
# interactive totals
$mm = @($newLife | Where-Object { $_ -match 'chart event MOUSE_MOVE\(id=\d+\).* took (\d+)ms' } | ForEach-Object { [int]$Matches[1] })
if ($mm.Count) {
    Say ("  MOUSE_MOVE took: n={0} median={1} max={2} (budget 40)" -f $mm.Count,
        ((@($mm | Sort-Object))[[int]($mm.Count/2)]), (($mm | Measure-Object -Maximum).Maximum))
}
$cc = @($newLife | Where-Object { $_ -match 'chart event CHART_CHANGE\(id=\d+\).* took (\d+)ms' } | ForEach-Object { [int]$Matches[1] })
if ($cc.Count) {
    Say ("  CHART_CHANGE took: n={0} median={1} max={2} (budget 40)" -f $cc.Count,
        ((@($cc | Sort-Object))[[int]($cc.Count/2)]), (($cc | Measure-Object -Maximum).Maximum))
}

if ($fail -eq 0) { Say "VERDICT: GREEN" } else { Say "VERDICT: RED - see lines above" }
exit $fail
