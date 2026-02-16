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

## Copilot RTL/LTR Helper (Browser-only)

File: `copilot-rtl-fix.js`

This helper is independent from MT5 compilation and is intended for browser/webview injection scenarios.

### Current behavior

- Supports mixed-language text (English/Persian in both orders) with `unicode-bidi: plaintext` strategy.
- Honors explicit direction markers (`dir="rtl"`, `dir="ltr"`, `dir="auto"`, `bdi`).
- Keeps code blocks LTR while preserving safer inline behavior.
- Applies styles in scoped chat-like roots (not the entire page by default).
- Auto-heal monitors DOM, shadow roots, and accessible iframes.

### 2026 best-practice strategy

- Prefer semantic direction with HTML `dir` over forced CSS whenever possible.
- Use tight wrapping for opposite-direction inline phrases.
- For unknown runtime direction, use `dir="auto"` or `bdi`.
- For plain-text-only channels, use isolate controls (`LRI/RLI/FSI ... PDI`) instead of legacy embedding controls.
- Keep technical tokens (`code`, URL-like strings, part numbers) isolated from surrounding RTL text.

### Helper APIs (added)

- `CopilotRTLFix.toUnicodeIsolate(text, dir)`
	- Returns plain text wrapped by Unicode isolates.
	- `dir` values: `"rtl" | "ltr" | "auto"`.
- `CopilotRTLFix.createBidiNode(text, options)`
	- Creates a DOM element (`span` by default) with safe bidi settings.
	- Options: `dir`, `tagName`, `className`, `documentRef`.
- `CopilotRTLFix.appendBidiText(target, text, options)`
	- Appends a safe bidi node into a target element.
	- Returns `{ ok, node | message }`.
- `CopilotRTLFix.runSelfCheck()`
	- Runs a comprehensive runtime sanity audit.
	- Reports health, missing rules, isolate wrapper checks, and potential risk signals.

Suggested usage model:

- If you can render markup: use `createBidiNode` / `appendBidiText`.
- If you must emit plain text only: use `toUnicodeIsolate`.

### Limitations

- Cross-origin iframes cannot be styled due to browser security policy.
- Closed shadow roots are not accessible by design.
- This script does not run inside MetaTrader terminal runtime.

### Quick manual verification

After injecting the script, verify these render correctly:

- `English فارسی`
- `فارسی English`
- `ABC 123 فارسی`
- `سلام \`inline code\` دنیا`
- A markdown/code block inside Persian paragraph

Extra edge-case matrix:

- `EN then FA`: `Version 3.05 نسخه`
- `FA then EN`: `نسخه Version 3.05`
- `RTL + number + punctuation`: `قیمت (USD 120)!`
- `URL in RTL`: `لینک: https://example.com/a/b?x=1&y=2`
- `Part number in RTL`: `شماره قطعه: AB-120C`
- `Unknown user input`: append text via `appendBidiText(..., { dir: "auto" })`

Health utilities:

- `CopilotRTLFix.healthCheck()`
- `CopilotRTLFix.runSelfCheck()`
- `CopilotRTLFix.status()`

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

