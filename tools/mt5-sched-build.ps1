# mt5-sched-build.ps1 - compile through Task Scheduler.
#
# WHY: on this machine a MetaEditor64.exe spawned from an agent/automation process
# dies with 0xC0000139 (STATUS_ENTRYPOINT_NOT_FOUND) before it can write a log,
# while the same exe launched from Explorer works. A scheduled task runs it in the
# user's own interactive session, so the compile behaves exactly like a manual F7.
#
#   powershell -File tools/mt5-sched-build.ps1 -Source "Biotak Trigger TH3.mq5"
#   powershell -File tools/mt5-sched-build.ps1 -Source "Biotak Trigger TH3 Lite.mq5"
#
# Prints the Result: line and the error/warning lines, exits 1 on errors.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$Compiler = "C:\Program Files\Vittaverse  MT5 Terminal\MetaEditor64.exe",
    [int]$TimeoutSec = 300
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $root $Source }
if (-not (Test-Path $src)) { throw "source not found: $src" }
if (-not (Test-Path $Compiler)) { throw "compiler not found: $Compiler" }

$name = [System.IO.Path]::GetFileNameWithoutExtension($src) -replace '\s+', '-'
$logDir = Join-Path $root 'build-logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log = Join-Path $logDir "_sched-$name.log"
if (Test-Path $log) { Remove-Item $log -Force }

$taskName = "BiotakCompile-$name"
$act = New-ScheduledTaskAction -Execute $Compiler -Argument "/compile:`"$src`" /log:`"$log`""
$pr = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
Register-ScheduledTask -TaskName $taskName -Action $act -Principal $pr -Force | Out-Null
Start-ScheduledTask -TaskName $taskName

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$settled = $false
$last = -1
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    $info = Get-ScheduledTaskInfo -TaskName $taskName
    $state = (Get-ScheduledTask -TaskName $taskName).State
    if ($state -eq 'Ready' -and (Test-Path $log)) {
        $sz = (Get-Item $log).Length
        if ($sz -eq $last -and $sz -gt 0) { $settled = $true; break }
        $last = $sz
    }
}
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null

if (-not (Test-Path $log)) { Write-Output "NO LOG - compile never ran"; exit 2 }
$text = Get-Content $log -Encoding Unicode
$errs = @($text | Where-Object { $_ -match ':\s*error\s+\d+:' })
$warns = @($text | Where-Object { $_ -match ':\s*warning\s+\d+:' })
$result = @($text | Where-Object { $_ -match '^Result:' }) | Select-Object -Last 1
$out = Join-Path $logDir "$name-sched.log"
$text | Set-Content -Path $out -Encoding UTF8
Write-Output "source : $src"
Write-Output "result : $result"
Write-Output "errors : $($errs.Count)  warnings: $($warns.Count)"
$errs | ForEach-Object { Write-Output "ERR  $_" }
$warns | ForEach-Object { Write-Output "WARN $_" }
if ($errs.Count -gt 0 -or -not $result) { exit 1 }
exit 0
