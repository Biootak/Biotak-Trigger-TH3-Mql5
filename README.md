# Biotak Trigger TH3

**MetaTrader 5 custom indicator** implementing Professor Saeed Khakestar's TH (Time Harmonic) levels formula.

## Version

**3.05**

## Features

- TH level display with multiple step modes (TH, SS/LS, M, TP, Combo)
- Fractal timeframes (M1, M4, M16, H1+M4, H4+M16, etc.)
- 30-minute base price updates
- Custom price selection
- Alert system
- Performance-focused modular architecture

---

## Build Modes (Production/Debug)

To switch build mode, edit `Biotak/BuildConfig.mqh` and uncomment/comment `#define DEBUG_BUILD`.

---

## Compile (PowerShell)

Use the project compile script:

- `./compile-th3.ps1` → compile workspace project (default)
- `./compile-th3.ps1 -Project all` → workspace + installed original + installed refactored
- `./compile-th3.ps1 -Project installed-original`
- `./compile-th3.ps1 -SourceFile "C:\path\to\file.mq5"`

### Optional parameters

- `-PrintLog $true|$false`
- `-LogTailLines 120`
- `-IncludeRuntimeLogs $true|$false` (collect Experts/Journal snapshot)
- `-RuntimeLogTailLines 80`
- `-IncrementalRuntimeLogs $true|$false` (default: only new runtime lines)
- `-EnableLogCleanup $true|$false`
- `-LogRetentionDays 14`
- `-MaxBuildLogs 400`
- `-WatchRuntimeLogs $true|$false` (live watch after compile)
- `-WatchSeconds 60`
- `-WatchPollMs 1000`
- `-MetaEditorPath "C:\...\metaeditor64.exe"`
- `-Mql5Dir "C:\Users\...\AppData\Roaming\MetaQuotes\Terminal\...\MQL5"`

### Optional environment variables

- `MT5_METAEDITOR` (full path to `metaeditor64.exe`)
- `MT5_MQL5_DIR` (full path to `MQL5` folder)

Script output logs are saved in: `build-logs/`.

Each build log can include:
- compile output from MetaEditor
- runtime snapshot from latest `MQL5/Logs` (Experts)
- runtime snapshot from latest terminal `logs` (Journal)

Runtime snapshot behavior:
- incremental mode (default) appends only new runtime lines since last script run
- state file is stored at `build-logs/.runtime-log-state.json`
- if a runtime log is rotated/truncated, script falls back to tail snapshot

Cleanup behavior:
- old build logs are removed automatically (`LogRetentionDays`)
- log count is capped (`MaxBuildLogs`)

Watch mode behavior:
- after compile, script can watch runtime logs live for a short duration
- prints only new lines during watch interval

---

## Installation (MT5)

1. Copy the project to your MT5 indicators path.
2. Compile `Biotak Trigger TH3.mq5` in MetaEditor, or use `compile-th3.ps1`.
3. Attach the indicator to a chart.

---

## File Structure

```
├── Biotak Trigger TH3.mq5      # Main indicator file
├── compile-th3.ps1             # Project compile script
├── Biotak/
│   ├── BuildConfig.mqh
│   ├── PropertiesAndInputs.mqh
│   ├── ConstantsAndEnums.mqh
│   ├── GlobalVariables.mqh
│   ├── THCalculations.mqh
│   ├── BasePriceManager.mqh
│   ├── TimeframeFunctions.mqh
│   ├── ObjectFunctions.mqh
│   ├── LabelFunctions.mqh
│   ├── EventHandlers.mqh
│   └── ...
```

---

## License

© Formula by Professor Saeed Khakestar, Indicator by Biotak.

