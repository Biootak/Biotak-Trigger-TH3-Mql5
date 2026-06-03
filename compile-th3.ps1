<#
.SYNOPSIS
    MQL5 Compiler Script for MetaTrader 5
    Compiles .mq5 files using metaeditor64.exe from the command line.

.DESCRIPTION
    This script provides easy compilation of MQL5 indicators/EAs/scripts
    without needing to press Compile in MetaEditor.
    
    It supports:
    - Compiling this workspace project
    - Compiling installed original/refactored projects (optional)
    - Compiling any arbitrary .mq5 file
    - Colored output with error/warning highlighting
    - Automatic error extraction and summary
    - Automatic MetaEditor/MQL5 path detection

.NOTES
    Optional environment variables:
    - MT5_METAEDITOR : full path to metaeditor64.exe
    - MT5_MQL5_DIR   : full path to MQL5 folder

.PARAMETER Project
    Which project to compile:
    - "workspace" (default): compile current project file in this repository
    - "installed-original": compile original installed indicator path
    - "installed-refactored": compile refactored installed indicator path
    - "all": compile all of the above

.PARAMETER SourceFile
    Optional: Full path to a specific .mq5 file to compile.
    Overrides the -Project parameter.

.EXAMPLE
    .\compile-th3.ps1
    # Compiles the workspace project (default)

.EXAMPLE
    .\compile-th3.ps1 -Project all
    # Compiles workspace + installed original + installed refactored

.EXAMPLE
    .\compile-th3.ps1 -Project installed-original
    # Compiles only the installed original project

.EXAMPLE
    .\compile-th3.ps1 -SourceFile "C:\path\to\file.mq5"
    # Compiles a specific file
#>

param(
    [ValidateSet("workspace", "installed-original", "installed-refactored", "all")]
    [string]$Project = "workspace",
    
    [string]$SourceFile = "",

    [bool]$PrintLog = $true,

    [ValidateRange(0, 5000)]
    [int]$LogTailLines = 120,

    [bool]$IncludeRuntimeLogs = $true,

    [ValidateRange(0, 5000)]
    [int]$RuntimeLogTailLines = 80,

    [bool]$IncrementalRuntimeLogs = $true,

    [bool]$EnableLogCleanup = $true,

    [ValidateRange(1, 365)]
    [int]$LogRetentionDays = 14,

    [ValidateRange(10, 5000)]
    [int]$MaxBuildLogs = 400,

    [bool]$WatchRuntimeLogs = $false,

    [ValidateRange(5, 3600)]
    [int]$WatchSeconds = 60,

    [ValidateRange(250, 5000)]
    [int]$WatchPollMs = 1000,

    [string]$MetaEditorPath = "",

    [string]$Mql5Dir = ""
)

# ============================================================
# CONFIGURATION - Edit these if your paths differ
# ============================================================

$SCRIPT_ROOT    = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$DEFAULT_MT5_INSTALL = "C:\Program Files\AMarkets - MetaTrader 5"
$DEFAULT_METAEDITOR  = Join-Path $DEFAULT_MT5_INSTALL "metaeditor64.exe"
$APPDATA_TERMINAL_ROOT = Join-Path $env:APPDATA "MetaQuotes\Terminal"
$PROJECT_LOG_DIR = Join-Path $SCRIPT_ROOT "build-logs"
$RUNTIME_STATE_FILE = Join-Path $PROJECT_LOG_DIR ".runtime-log-state.json"
$WORKSPACE_SOURCE = Join-Path $SCRIPT_ROOT "Biotak Trigger TH3.mq5"

# ============================================================
# FUNCTIONS
# ============================================================

function Write-Banner {
    param([string]$Text)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
}

function Resolve-MetaEditorPath {
    param([string]$CustomPath)

    $candidates = @()

    if ($CustomPath) {
        $candidates += $CustomPath
    }
    if ($env:MT5_METAEDITOR) {
        $candidates += $env:MT5_METAEDITOR
    }

    $candidates += $DEFAULT_METAEDITOR

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $programRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($root in $programRoots) {
        $dirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue
        foreach ($dir in $dirs) {
            if ($dir.Name -like "*MetaTrader 5*") {
                $editor = Join-Path $dir.FullName "metaeditor64.exe"
                if (Test-Path -LiteralPath $editor -PathType Leaf) {
                    return $editor
                }
            }
        }
    }

    return $null
}

function Resolve-Mql5Directory {
    param([string]$CustomPath)

    function Normalize-Mql5Path {
        param([string]$PathCandidate)

        if (-not $PathCandidate) {
            return $null
        }
        if (-not (Test-Path -LiteralPath $PathCandidate -PathType Container)) {
            return $null
        }

        $leaf = Split-Path -Path $PathCandidate -Leaf
        if ($leaf -ieq "MQL5") {
            return (Resolve-Path -LiteralPath $PathCandidate).Path
        }

        $mql5Child = Join-Path $PathCandidate "MQL5"
        if (Test-Path -LiteralPath $mql5Child -PathType Container) {
            return (Resolve-Path -LiteralPath $mql5Child).Path
        }

        return $null
    }

    $candidates = @()
    if ($CustomPath) {
        $candidates += $CustomPath
    }
    if ($env:MT5_MQL5_DIR) {
        $candidates += $env:MT5_MQL5_DIR
    }

    foreach ($candidate in $candidates) {
        $normalized = Normalize-Mql5Path -PathCandidate $candidate
        if ($normalized) {
            return $normalized
        }
    }

    if (Test-Path -LiteralPath $APPDATA_TERMINAL_ROOT -PathType Container) {
        $terminalDirs = Get-ChildItem -Path $APPDATA_TERMINAL_ROOT -Directory -ErrorAction SilentlyContinue
        $found = @()
        foreach ($terminalDir in $terminalDirs) {
            $mql5Path = Join-Path $terminalDir.FullName "MQL5"
            if (Test-Path -LiteralPath $mql5Path -PathType Container) {
                $found += [pscustomobject]@{
                    Path = $mql5Path
                    LastWriteTime = (Get-Item -LiteralPath $mql5Path).LastWriteTime
                }
            }
        }

        if ($found.Count -gt 0) {
            return ($found | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Path
        }
    }

    return $null
}

function Get-IncludePath {
    param(
        [string]$SourcePath,
        [string]$ScriptRoot,
        [string]$ResolvedMql5Dir
    )

    if ($SourcePath.StartsWith($ScriptRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $ScriptRoot
    }

    if ($ResolvedMql5Dir -and $SourcePath.StartsWith($ResolvedMql5Dir, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $ResolvedMql5Dir
    }

    return (Split-Path -Parent $SourcePath)
}

function Wait-ForFile {
    param(
        [string]$Path,
        [int]$TimeoutMs = 10000,
        [int]$IntervalMs = 250
    )

    $elapsed = 0
    while ($elapsed -lt $TimeoutMs) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            return $true
        }
        Start-Sleep -Milliseconds $IntervalMs
        $elapsed += $IntervalMs
    }

    return $false
}

function Read-LogContent {
    param([string]$Path)

    $encodings = @("Unicode", "UTF8", "Default")
    foreach ($encoding in $encodings) {
        $content = Get-Content -LiteralPath $Path -Encoding $encoding -ErrorAction SilentlyContinue
        if ($content -and $content.Count -gt 0) {
            return $content
        }
    }

    return (Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
}

function Resolve-TerminalRoot {
    param([string]$ResolvedMql5Dir)

    if (-not $ResolvedMql5Dir) {
        return $null
    }

    $mql5Folder = Get-Item -LiteralPath $ResolvedMql5Dir -ErrorAction SilentlyContinue
    if (-not $mql5Folder -or -not $mql5Folder.Directory) {
        return $null
    }

    return $mql5Folder.Directory.FullName
}

function Get-LatestLogFile {
    param([string]$DirPath)

    if (-not $DirPath -or -not (Test-Path -LiteralPath $DirPath -PathType Container)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $DirPath -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Append-RuntimeLogs {
    param(
        [string]$CompileLogPath,
        [string]$ResolvedMql5Dir,
        [string]$TerminalRoot,
        [int]$TailLines,
        [bool]$PrintToConsole,
        [bool]$UseIncremental,
        [hashtable]$State
    )

    $expertsDir = ""
    if ($ResolvedMql5Dir) {
        $expertsDir = Join-Path $ResolvedMql5Dir "Logs"
    }

    $journalDir = ""
    if ($TerminalRoot) {
        $journalDir = Join-Path $TerminalRoot "logs"
    }

    $expertsLog = Get-LatestLogFile -DirPath $expertsDir
    $journalLog = Get-LatestLogFile -DirPath $journalDir

    $runtimeSources = @()
    if ($expertsLog) {
        $runtimeSources += [pscustomobject]@{ Type = "Experts"; File = $expertsLog }
    }
    if ($journalLog) {
        $runtimeSources += [pscustomobject]@{ Type = "Journal"; File = $journalLog }
    }

    if ($runtimeSources.Count -eq 0) {
        Add-Content -LiteralPath $CompileLogPath -Value "`r`n==== RUNTIME LOG SNAPSHOT ====`r`nNo runtime logs found.`r`n" -Encoding UTF8
        if ($PrintToConsole) {
            Write-Host "  Runtime logs: none found (Experts/Journal)." -ForegroundColor Yellow
        }
        return
    }

    Add-Content -LiteralPath $CompileLogPath -Value "`r`n==== RUNTIME LOG SNAPSHOT ====" -Encoding UTF8

    foreach ($src in $runtimeSources) {
        $content = Read-LogContent -Path $src.File.FullName
        if (-not $content) {
            continue
        }

        $stateKey = ("{0}|{1}" -f $src.Type, $src.File.FullName)
        $tail = @()

        if ($UseIncremental) {
            $previousLineCount = 0
            if ($State.ContainsKey($stateKey)) {
                $previousLineCount = [int]$State[$stateKey]
            }

            $currentLineCount = [int]$content.Count
            if ($previousLineCount -lt $currentLineCount) {
                $tail = $content | Select-Object -Skip $previousLineCount
            }
            elseif ($previousLineCount -gt $currentLineCount) {
                # Log rotated or truncated
                $tail = if ($TailLines -gt 0) { $content | Select-Object -Last $TailLines } else { $content }
            }
            else {
                $tail = @()
            }

            $State[$stateKey] = $currentLineCount
        }
        else {
            $tail = if ($TailLines -gt 0) { $content | Select-Object -Last $TailLines } else { $content }
        }

        $header = "---- $($src.Type) | File: $($src.File.FullName) | LastWrite: $($src.File.LastWriteTime) ----"
        Add-Content -LiteralPath $CompileLogPath -Value $header -Encoding UTF8

        if ($tail.Count -gt 0) {
            Add-Content -LiteralPath $CompileLogPath -Value $tail -Encoding UTF8
        }
        else {
            Add-Content -LiteralPath $CompileLogPath -Value "(no new lines since previous snapshot)" -Encoding UTF8
        }

        Add-Content -LiteralPath $CompileLogPath -Value "" -Encoding UTF8

        if ($PrintToConsole -and $tail.Count -gt 0) {
            Write-Host "  Runtime $($src.Type): $($src.File.Name)" -ForegroundColor Cyan
            $consoleTail = $tail | Select-Object -Last ([Math]::Min(12, [Math]::Max(1, $TailLines)))
            foreach ($line in $consoleTail) {
                Write-Host "    $line" -ForegroundColor DarkGray
            }
        }
        elseif ($PrintToConsole) {
            Write-Host "  Runtime $($src.Type): no new lines since previous snapshot" -ForegroundColor DarkGray
        }
    }
}

function Load-RuntimeState {
    param([string]$StatePath)

    $state = @{}
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) {
        return $state
    }

    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $obj = $raw | ConvertFrom-Json -ErrorAction Stop
            foreach ($p in $obj.PSObject.Properties) {
                $state[$p.Name] = [int]$p.Value
            }
        }
    }
    catch {
        # ignore bad state file and rebuild fresh
    }

    return $state
}

function Save-RuntimeState {
    param(
        [string]$StatePath,
        [hashtable]$State
    )

    try {
        $json = $State | ConvertTo-Json -Depth 5
        Set-Content -LiteralPath $StatePath -Value $json -Encoding UTF8
    }
    catch {
        # do not fail compilation for state write issues
    }
}

function Cleanup-BuildLogs {
    param(
        [string]$LogDir,
        [int]$RetentionDays,
        [int]$MaxFiles,
        [string]$StateFilePath
    )

    if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) {
        return
    }

    $removed = 0
    $threshold = (Get-Date).AddDays(-1 * $RetentionDays)

    $logFiles = Get-ChildItem -LiteralPath $LogDir -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    foreach ($f in ($logFiles | Where-Object { $_.LastWriteTime -lt $threshold })) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        $removed++
    }

    $remaining = Get-ChildItem -LiteralPath $LogDir -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending

    if ($remaining.Count -gt $MaxFiles) {
        $extra = $remaining | Select-Object -Skip $MaxFiles
        foreach ($f in $extra) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }

    if ($removed -gt 0) {
        Write-Host "  Log cleanup: removed $removed old log file(s)." -ForegroundColor Gray
    }

    # prune stale runtime state keys pointing to removed files
    if (Test-Path -LiteralPath $StateFilePath -PathType Leaf) {
        $state = Load-RuntimeState -StatePath $StateFilePath
        $keysToRemove = @()
        foreach ($key in $state.Keys) {
            $parts = $key -split '\|', 2
            if ($parts.Count -eq 2) {
                $filePath = $parts[1]
                if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    $keysToRemove += $key
                }
            }
        }

        foreach ($k in $keysToRemove) {
            $state.Remove($k) | Out-Null
        }

        if ($keysToRemove.Count -gt 0) {
            Save-RuntimeState -StatePath $StateFilePath -State $state
        }
    }
}

function Watch-RuntimeLogs {
    param(
        [string]$ResolvedMql5Dir,
        [string]$TerminalRoot,
        [int]$DurationSeconds,
        [int]$PollMs
    )

    $expertsDir = ""
    if ($ResolvedMql5Dir) {
        $expertsDir = Join-Path $ResolvedMql5Dir "Logs"
    }

    $journalDir = ""
    if ($TerminalRoot) {
        $journalDir = Join-Path $TerminalRoot "logs"
    }

    $sources = @()
    $expertsLog = Get-LatestLogFile -DirPath $expertsDir
    if ($expertsLog) {
        $sources += [pscustomobject]@{ Type = "Experts"; Path = $expertsLog.FullName; LastCount = [int](Read-LogContent -Path $expertsLog.FullName).Count }
    }

    $journalLog = Get-LatestLogFile -DirPath $journalDir
    if ($journalLog) {
        $sources += [pscustomobject]@{ Type = "Journal"; Path = $journalLog.FullName; LastCount = [int](Read-LogContent -Path $journalLog.FullName).Count }
    }

    if ($sources.Count -eq 0) {
        Write-Host "  Watch mode: no runtime logs found (Experts/Journal)." -ForegroundColor Yellow
        return
    }

    Write-Banner "WATCH RUNTIME LOGS"
    Write-Host "  Watching for ${DurationSeconds}s (poll ${PollMs}ms)..." -ForegroundColor Cyan
    foreach ($s in $sources) {
        Write-Host "  Source $($s.Type): $($s.Path)" -ForegroundColor Gray
    }
    Write-Host ""

    $endAt = (Get-Date).AddSeconds($DurationSeconds)
    while ((Get-Date) -lt $endAt) {
        foreach ($s in $sources) {
            if (-not (Test-Path -LiteralPath $s.Path -PathType Leaf)) {
                continue
            }

            $content = Read-LogContent -Path $s.Path
            if (-not $content) {
                continue
            }

            $currentCount = [int]$content.Count
            if ($currentCount -gt $s.LastCount) {
                $newLines = $content | Select-Object -Skip $s.LastCount
                foreach ($line in $newLines) {
                    Write-Host "  [$($s.Type)] $line" -ForegroundColor DarkGray
                }
            }
            elseif ($currentCount -lt $s.LastCount) {
                # file rotated/truncated
                Write-Host "  [$($s.Type)] log rotated/truncated, re-syncing..." -ForegroundColor Yellow
            }

            $s.LastCount = $currentCount
        }

        Start-Sleep -Milliseconds $PollMs
    }

    Write-Host ""
    Write-Host "  Watch mode completed." -ForegroundColor Green
}

function Compile-MQL5 {
    param(
        [string]$Name,
        [string]$SourcePath,
        [string]$CompilerPath,
        [string]$ResolvedMql5Dir,
        [string]$TerminalRoot
    )
    
    Write-Banner "Compiling: $Name"
    
    # Validate paths
    if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) {
        Write-Host "  ERROR: MetaEditor not found at: $CompilerPath" -ForegroundColor Red
        Write-Host "  Hint: Use -MetaEditorPath or MT5_METAEDITOR env variable." -ForegroundColor Yellow
        return $false
    }
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        Write-Host "  ERROR: Source file not found: $SourcePath" -ForegroundColor Red
        return $false
    }
    if ([System.IO.Path]::GetExtension($SourcePath) -ine ".mq5") {
        Write-Host "  ERROR: Source file must be a .mq5 file: $SourcePath" -ForegroundColor Red
        return $false
    }
    
    if (-not (Test-Path $PROJECT_LOG_DIR)) {
        New-Item -ItemType Directory -Path $PROJECT_LOG_DIR -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeName = ($Name -replace '[^A-Za-z0-9_-]', '-')
    $logFile = Join-Path $PROJECT_LOG_DIR ("{0}-{1}.log" -f $safeName, $timestamp)

    $includePath = Get-IncludePath -SourcePath $SourcePath -ScriptRoot $SCRIPT_ROOT -ResolvedMql5Dir $ResolvedMql5Dir
    
    Write-Host "  Source:   $SourcePath" -ForegroundColor Gray
    Write-Host "  Include:  $includePath" -ForegroundColor Gray
    Write-Host "  Log:      $logFile" -ForegroundColor Gray
    Write-Host ""
    
    # Run compiler
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $proc = Start-Process -FilePath $CompilerPath `
        -ArgumentList "/compile:`"$SourcePath`"", "/log:`"$logFile`"", "/include:`"$includePath`"" `
        -PassThru -Wait -NoNewWindow
    $stopwatch.Stop()
    $exitCode = $proc.ExitCode
    
    # Wait for log file to be written
    $logReady = Wait-ForFile -Path $logFile
    
    # Parse results
    if (-not $logReady) {
        Write-Host "  WARNING: Log file was not created" -ForegroundColor Yellow
        Write-Host "  Compiler exit code: $exitCode" -ForegroundColor Yellow
        return $false
    }
    
    $logContent = Read-LogContent -Path $logFile
    
    $errors   = @()
    $warnings = @()
    $resultLine = ""
    
    foreach ($line in $logContent) {
        if ($line -match ": error \d+:") {
            $errors += $line
        }
        elseif ($line -match ": warning \d+:") {
            $warnings += $line
        }
        elseif ($line -match "^Result:") {
            $resultLine = $line
        }
    }
    
    # Display errors
    if ($errors.Count -gt 0) {
        Write-Host "  ERRORS ($($errors.Count)):" -ForegroundColor Red
        foreach ($err in $errors) {
            # Shorten the path for readability
            $short = $err -replace [regex]::Escape($SCRIPT_ROOT + "\"), ""
            if ($ResolvedMql5Dir) {
                $short = $short -replace [regex]::Escape($ResolvedMql5Dir + "\Indicators\"), ""
            }
            Write-Host "    $short" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Display warnings
    if ($warnings.Count -gt 0) {
        Write-Host "  WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            $short = $w -replace [regex]::Escape($SCRIPT_ROOT + "\"), ""
            if ($ResolvedMql5Dir) {
                $short = $short -replace [regex]::Escape($ResolvedMql5Dir + "\Indicators\"), ""
            }
            Write-Host "    $short" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Result summary
    if ($resultLine) {
        if ($errors.Count -eq 0) {
            Write-Host "  $resultLine" -ForegroundColor Green
        } else {
            Write-Host "  $resultLine" -ForegroundColor Red
        }
    }

    if ($exitCode -ne 0 -and $errors.Count -gt 0) {
        Write-Host "  Compiler exit code: $exitCode" -ForegroundColor Red
    }
    elseif ($exitCode -ne 0) {
        Write-Host "  Compiler exit code: $exitCode (non-fatal, no compile errors in log)" -ForegroundColor Yellow
    }

    if ($PrintLog -and $logContent) {
        Write-Host ""
        if ($LogTailLines -gt 0) {
            Write-Host "  LOG OUTPUT (last $LogTailLines lines):" -ForegroundColor Cyan
            $linesToPrint = $logContent | Select-Object -Last $LogTailLines
        }
        else {
            Write-Host "  LOG OUTPUT (full):" -ForegroundColor Cyan
            $linesToPrint = $logContent
        }

        foreach ($l in $linesToPrint) {
            if ($l -match ": error \d+:") {
                Write-Host "    $l" -ForegroundColor Red
            }
            elseif ($l -match ": warning \d+:") {
                Write-Host "    $l" -ForegroundColor Yellow
            }
            else {
                Write-Host "    $l" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }

    if ($IncludeRuntimeLogs) {
        $runtimeState = Load-RuntimeState -StatePath $RUNTIME_STATE_FILE
        Append-RuntimeLogs -CompileLogPath $logFile -ResolvedMql5Dir $ResolvedMql5Dir -TerminalRoot $TerminalRoot -TailLines $RuntimeLogTailLines -PrintToConsole $PrintLog -UseIncremental $IncrementalRuntimeLogs -State $runtimeState
        Save-RuntimeState -StatePath $RUNTIME_STATE_FILE -State $runtimeState
        Write-Host "  Runtime snapshot appended to: $logFile" -ForegroundColor Gray
        Write-Host ""
    }
    
    $elapsed = $stopwatch.Elapsed.TotalSeconds.ToString("F1")
    Write-Host "  Compile time: ${elapsed}s" -ForegroundColor Gray
    
    # Check for .ex5 output
    $ex5Path = [System.IO.Path]::ChangeExtension($SourcePath, ".ex5")
    if (Test-Path $ex5Path) {
        $ex5Info = Get-Item $ex5Path
        $size = "{0:N0}" -f $ex5Info.Length
        Write-Host "  Output: $ex5Path ($size bytes)" -ForegroundColor Green
    }
    
    Write-Host ""
    
    if ($errors.Count -gt 0) {
        return $false
    }

    # MetaEditor can return non-zero in some environments even when compilation succeeded.
    # We trust log parsing as the primary success indicator.
    return $true
}

# ============================================================
# MAIN EXECUTION
# ============================================================

$startTime = Get-Date
$results = @{}

$resolvedCompiler = Resolve-MetaEditorPath -CustomPath $MetaEditorPath
if (-not $resolvedCompiler) {
    Write-Banner "ERROR"
    Write-Host "  MetaEditor not found." -ForegroundColor Red
    Write-Host "  Provide -MetaEditorPath or set MT5_METAEDITOR env variable." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$resolvedMql5Dir = Resolve-Mql5Directory -CustomPath $Mql5Dir
$terminalRoot = Resolve-TerminalRoot -ResolvedMql5Dir $resolvedMql5Dir

# Project paths (relative to resolved MQL5\Indicators)
$PROJECTS = @{
    "workspace" = @{
        Name   = "Biotak Trigger TH3 (Workspace)"
        Source = $WORKSPACE_SOURCE
    }
    "installed-original"   = @{
        Name   = "Biotak Trigger TH3 (Installed Original)"
        Source = if ($resolvedMql5Dir) { Join-Path $resolvedMql5Dir "Indicators\Biotak-Trigger-TH3\Biotak Trigger TH3.mq5" } else { "" }
    }
    "installed-refactored" = @{
        Name   = "Biotak Trigger TH3 (Installed Refactored)"
        Source = if ($resolvedMql5Dir) { Join-Path $resolvedMql5Dir "Indicators\Biotak-Trigger-TH3-Refactored\Biotak Trigger TH3.mq5" } else { "" }
    }
}

if ($SourceFile -ne "") {
    # Compile specific file
    if (-not [System.IO.Path]::IsPathRooted($SourceFile)) {
        $SourceFile = Join-Path $SCRIPT_ROOT $SourceFile
    }

    $name = [System.IO.Path]::GetFileName($SourceFile)
    $results[$name] = Compile-MQL5 -Name $name -SourcePath $SourceFile -CompilerPath $resolvedCompiler -ResolvedMql5Dir $resolvedMql5Dir -TerminalRoot $terminalRoot
}
else {
    # Compile project(s)
    $projectsToCompile = if ($Project -eq "all") {
        @("workspace", "installed-original", "installed-refactored")
    } else {
        @($Project)
    }
    
    foreach ($proj in $projectsToCompile) {
        $info = $PROJECTS[$proj]
        if (-not $info.Source) {
            Write-Banner "Compiling: $($info.Name)"
            Write-Host "  ERROR: Could not resolve MQL5 directory for installed project." -ForegroundColor Red
            Write-Host "  Hint: Use -Mql5Dir or set MT5_MQL5_DIR env variable." -ForegroundColor Yellow
            Write-Host ""
            $results[$info.Name] = $false
            continue
        }

        $results[$info.Name] = Compile-MQL5 -Name $info.Name -SourcePath $info.Source -CompilerPath $resolvedCompiler -ResolvedMql5Dir $resolvedMql5Dir -TerminalRoot $terminalRoot
    }
}

# Final summary
Write-Banner "SUMMARY"
$allSuccess = $true
foreach ($key in $results.Keys) {
    $status = if ($results[$key]) { "PASS" } else { "FAIL"; $allSuccess = $false }
    $color  = if ($results[$key]) { "Green" } else { "Red" }
    Write-Host "  [$status] $key" -ForegroundColor $color
}

$totalTime = ((Get-Date) - $startTime).TotalSeconds.ToString("F1")
Write-Host ""
Write-Host "  Total time: ${totalTime}s" -ForegroundColor Gray
Write-Host ""
Write-Host "  MetaEditor: $resolvedCompiler" -ForegroundColor Gray
if ($resolvedMql5Dir) {
    Write-Host "  MQL5 dir:  $resolvedMql5Dir" -ForegroundColor Gray
} else {
    Write-Host "  MQL5 dir:  (not resolved - workspace compile still works)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Logs folder: $PROJECT_LOG_DIR" -ForegroundColor Gray
Write-Host ""

if ($allSuccess) {
    Write-Host "  All compilations PASSED!" -ForegroundColor Green
} else {
    Write-Host "  Some compilations FAILED." -ForegroundColor Red
}
Write-Host ""

if ($EnableLogCleanup) {
    Cleanup-BuildLogs -LogDir $PROJECT_LOG_DIR -RetentionDays $LogRetentionDays -MaxFiles $MaxBuildLogs -StateFilePath $RUNTIME_STATE_FILE
}

if ($WatchRuntimeLogs) {
    Watch-RuntimeLogs -ResolvedMql5Dir $resolvedMql5Dir -TerminalRoot $terminalRoot -DurationSeconds $WatchSeconds -PollMs $WatchPollMs
}

# Return exit code
exit $(if ($allSuccess) { 0 } else { 1 })
