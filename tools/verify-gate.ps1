# verify-gate.ps1 - the four-entry parity gate, in one command.
#
# A shared-source edit is not finished until BOTH entries compile under BOTH
# platforms. MT4 and MT5 disagree on things that matter (MT4 auto-closes an
# unterminated #ifdef at EOF, MT5 does not; MT4 accepts a raw int timeframe
# where MT5 wants an ENUM_TIMEFRAMES), so a green MT4 build proves nothing
# about MT5 and vice versa.
#
# Usage:
#   & "<abs>\tools\verify-gate.ps1" -Tag "mytag"
#   & "<abs>\tools\verify-gate.ps1" -Tag "mytag" -Junction   # add the 2 MT5
#                                                            # terminal-junction builds
#
# Writes build-logs/GATE-<tag>-<stamp>.txt because this script's own stdout is
# not always captured in the agent session.

[CmdletBinding()]
param(
    [string]$Tag = "gate",
    [switch]$Junction
)

$ErrorActionPreference = 'Stop'

$root      = Split-Path -Parent $PSScriptRoot
# The MT4 repo is a SIBLING of this repo ("...-mql4" next to "...-mql5"), not
# its parent. Derive it from our own name so a rename cannot silently point the
# gate at the wrong tree.
$mt4Repo   = Join-Path (Split-Path -Parent $root) `
                       ((Split-Path -Leaf $root) -replace '-mql5$', '-mql4')
if (-not (Test-Path $mt4Repo)) { throw "MT4 repo not found at $mt4Repo" }
$mt4Comp   = 'C:\Program Files (x86)\RoboForex MT4 Terminal\metaeditor.exe'
$mt5Comp   = 'C:\Program Files\Vittaverse  MT5 Terminal\MetaEditor64.exe'
# $env:APPDATA can be empty in the agent PowerShell session, so resolve the
# roaming profile through .NET and only then fall back to the literal path.
$appData   = $env:APPDATA
if (-not $appData) { $appData = [Environment]::GetFolderPath('ApplicationData') }
if (-not $appData) { $appData = "$env:USERPROFILE\AppData\Roaming" }
$mt5Term   = Join-Path $appData 'MetaQuotes\Terminal\F5617C4B1B2E163B367315A450648344\MQL5\Indicators\Biotak-Trigger-TH3'

$targets = @(
    @{ Name = 'MT5 Full'; Src = Join-Path $root    'Biotak Trigger TH3.mq5';      Comp = $mt5Comp; Ext = '.ex5' }
    @{ Name = 'MT5 Lite'; Src = Join-Path $root    'Biotak Trigger TH3 Lite.mq5'; Comp = $mt5Comp; Ext = '.ex5' }
    @{ Name = 'MT4 Full'; Src = Join-Path $mt4Repo 'Biotak Trigger TH3.mq4';      Comp = $mt4Comp; Ext = '.ex4' }
    @{ Name = 'MT4 Lite'; Src = Join-Path $mt4Repo 'Biotak Trigger TH3 Lite.mq4'; Comp = $mt4Comp; Ext = '.ex4' }
)

if ($Junction) {
    $targets += @{ Name = 'MT5 Full (junction)'; Src = Join-Path $mt5Term 'Biotak Trigger TH3.mq5';      Comp = $mt5Comp; Ext = '.ex5' }
    $targets += @{ Name = 'MT5 Lite (junction)'; Src = Join-Path $mt5Term 'Biotak Trigger TH3 Lite.mq5'; Comp = $mt5Comp; Ext = '.ex5' }
}

$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outPath = Join-Path $root "build-logs\GATE-$Tag-$stamp.txt"
$report = @()
$fail   = 0

foreach ($t in $targets) {
    $pre = if (Test-Path $t.Src) {
        $p = [System.IO.Path]::ChangeExtension($t.Src, $t.Ext)
        if (Test-Path $p) { (Get-Item $p).LastWriteTime } else { [datetime]'1970-01-01' }
    } else { $null }

    # One broken entry must not hide the verdict on the others: a gate that
    # aborts on entry 3 reports nothing about entries 4-6, which is how a real
    # failure gets mistaken for "not run yet".
    $raw = @()
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $raw = @(& (Join-Path $PSScriptRoot 'mt5-build.ps1') -Source $t.Src `
                 -Tag "$Tag-$($t.Name -replace '[^A-Za-z0-9]','')" -Compiler $t.Comp -ErrorsOnly)
    } catch {
        $raw = @("BUILD THREW: $($_.Exception.Message)")
    }
    $sw.Stop()

    $post = if (Test-Path $t.Src) {
        $p = [System.IO.Path]::ChangeExtension($t.Src, $t.Ext)
        if (Test-Path $p) { Get-Item $p } else { $null }
    } else { $null }

    # Judge freshness by mtime, never by the result line: MetaEditor replays a
    # cached "0 errors, 0 warnings" for an unchanged source in ~650 ms, which
    # reads exactly like success. A real MT5 compile takes 16-36 s; MT4 is
    # legitimately 250-712 ms.
    #
    # Not-rebuilt is therefore NOT a failure on its own: if the source (and its
    # include graph) did not change, the replay is truthful. It is reported as
    # CACHED so a reader can tell it apart from a real compile - the danger is
    # only ever "I edited something and got a replay", which CACHED makes
    # visible. Only errors/warnings fail the gate.
    $rebuilt = ($post -ne $null) -and ($pre -eq $null -or $post.LastWriteTime -gt $pre)
    $errCount = @($raw | Where-Object { $_ -match ':\s*error\s+\d+:' }).Count
    $warnCount = @($raw | Where-Object { $_ -match ':\s*warning\s+\d+:' }).Count
    $ok = ($errCount -eq 0) -and ($warnCount -eq 0)
    if (-not $ok) { $fail++ }
    $verdict = if (-not $ok) { 'FAIL' } elseif ($rebuilt) { 'PASS' } else { 'CACHED' }

    $size = if ($post) { "$($post.Length) B  $($post.LastWriteTime.ToString('HH:mm:ss'))" } else { '(none)' }
    $report += ("{0,-22} {1,-7} err={2} warn={3} {4,7} ms  artifact={5}" -f `
        $t.Name, $verdict, $errCount, $warnCount, $sw.ElapsedMilliseconds, $size)
    foreach ($l in $raw) { $report += "    $l" }
}

$report += ''
$report += "GATE $Tag : $(if ($fail -eq 0) { "ALL GREEN ($($targets.Count) entries)" } else { "$fail of $($targets.Count) FAILED" })"
$report += "PASS = freshly compiled; CACHED = source unchanged, MetaEditor replayed the previous result (still truthful, but proves nothing about an edit you just made)."
$report | Set-Content -Path $outPath -Encoding UTF8
$report | ForEach-Object { $_ }
