# AGENTS.md — Biotak Trigger TH3

## What this repo is
A single MQL5 custom indicator (no EA, no script, no library). It draws TH (Time Harmonic) levels, zones, and labels on MetaTrader 5 charts. **Not a typical multi-package software project** — there is no package manager, no test runner, no linter, no typechecker, and no CI. The only verification step is a successful compile.

## Entry points
- `Biotak Trigger TH3.mq5` — 118-line facade. The only `.mq5` file. Pure delegates to `OnInitHandler/OnDeinitHandler/OnCalculateHandler/OnChartEventHandler/OnTimer` defined in headers.
- `Biotak/EventHandlers.mqh` — the actual 2175-line orchestrator (largest file, slated for split per `docs/EventHandlers-Rewrite-Plan.md`).
- `compile-th3.ps1` — build script (PowerShell 5.1). Wraps `metaeditor64.exe`.
- `copilot-rtl-fix.js` — **unrelated browser-only helper** for VS Code Copilot RTL rendering. Not part of the MT5 indicator. Do not touch when working on the indicator.

## Build & verify (the only command that matters)
```powershell
.\compile-th3.ps1
```
That is the **lint + typecheck + test** all in one. Required result: `Result: 0 errors, 0 warnings`. Anything else is a failure. Logs land in `build-logs/<Project>-<Timestamp>.log`.

Useful flags (see `README.md` for full list): `-SourceFile`, `-MetaEditorPath`, `-Mql5Dir`, `-WatchRuntimeLogs`, `-IncludeRuntimeLogs $false` (faster).

Environment overrides: `MT5_METAEDITOR`, `MT5_MQL5_DIR`.

## Build mode toggle
Edit `Biotak/BuildConfig.mqh`:
- Production (default, committed): `#define DEBUG_BUILD` is **commented out**.
- Debug: uncomment `#define DEBUG_BUILD`. Also unlocks `ENABLE_TH3_PROFILER` and `ENABLE_DEBUG_LOGS`.
- Profiler can be enabled independently of DEBUG via `#define ENABLE_TH3_PROFILER`.

When in doubt, **stay on production**. The committed config is what ships.

## Source layout & include order (rigid contract)
40 `.mqh` files in `Biotak/`. The include order in `Biotak Trigger TH3.mq5:12-62` is the source of truth. Reordering breaks compilation (forward declarations, struct dependencies, `g_*` macro resolution). If you add a new `.mqh`, slot it into the existing groups:
1. Build/MQL5Compat (first — `BuildConfig.mqh` sets `_LOGGER_OVERRIDE_LEGACY` and includes `Logger.mqh`)
2. Properties/Constants/Enums/ProjectConstants/InputValidator
3. Security/Performance/ObjectCountManager/PerformanceOptimizations
4. GlobalVariables (all `static`/global state declarations)
5. UtilityFunctions
6. Zone system (CalculationCache → ZoneFactory → ZoneConstants)
7. Object cache & visibility
8. Timeframes → Calculations (TH/ATR/Adaptive/BasePrice/Wave/Frequency/TH3Tool)
9. Drawing (Object/Extended/Unified/LevelPipeline)
10. Labels/Alerts/HistoricalData
11. **EventHandlers last** (it depends on everything above)

## Pre-existing instruction files (authoritative — read these before non-trivial work)
- `.github/instructions/instructions-mt5.md` — MQL5 dev rules (applyTo `**/*.{mq5,mqh}`). Encodes module separation, non-repaint rules, `prev_calculated` usage, prohibited patterns.
- `.github/instructions/review.md` — Persian bug-free architecture review protocol (applyTo: always). Defines mandatory pre-code gate, output template, and definition of done.
- `.github/skills/*` — 12 skills (architecture-analysis, refactor, bug-hunting, code-review, performance-optimization, etc.). Load via the `skill` tool when relevant.
- `docs/Code-Analysis-Report.md` — 32 known issues (4 CRITICAL / 12 HIGH / 16 MEDIUM). Stale in places: C1 in the report is partially mitigated by `GetSafeSymbolStateIndex()` (BasePriceManager.mqh:204), but a fallback `return 0;` at line 245 still has the original OOB risk when `g_symbolStateCount == 0`. Cross-check before citing.
- `docs/EventHandlers-Rewrite-Plan.md` — function-by-function refactor plan for the MT4 port; useful as a structural map of `EventHandlers.mqh`.

## Repo-specific gotchas (would miss without help)
- **Globals in MQL5 indicators are per-chart-instance** (not process-shared). Each chart loads its own copy of the indicator with its own static/file-scope globals. The codebase's ~50+ `static` caches/flags are safe as written. To share state across charts you must use `GlobalVariable*` (which the code already does for cross-reload persistence, with `ChartID()` prefixes).
- **CRITICAL bug surface** in `Biotak/BasePriceManager.mqh:204-254` — the 7 `g_*` macros use `GetSafeSymbolStateIndex()`. The function's "FATAL" branch (line ~278) returns 0 even when the array is empty; in practice this is unreachable without an OOM, but any new code path that creates a new state (LRU eviction, resize) must keep it safe.
- **`#property` directives in `.mqh` files are ignored by MQL5** — they belong only in the `.mq5`. Many `.mqh` files violate this; harmless but misleading. Don't add new ones.
- **Hard-coded broker path** in `compile-th3.ps1:95` (`C:\Program Files\AMarkets - MetaTrader 5`). The script does fall back to any `*MetaTrader 5*` under `Program Files`, then to `%APPDATA%\MetaQuotes\Terminal\*\MQL5`, so standard MT5 installs work, but the default is wrong for non-AMarkets users.
- **Indentation is mixed 4-space / 8-space throughout the codebase.** Don't try to "fix" it in unrelated edits — it inflates diffs. The planned cleanup is part of the EventHandlers rewrite.
- **Magic global-variable name prefixes** (`"Biotak_*"`) are scattered across `EventHandlers.mqh` and `BasePriceHistoryManager.mqh`. Use the existing names; new ones should be added to a single registry.
- **MQL5-only API**: `CopyTime` is preferred over `iTime`; some legacy code still uses `iTime` in `AlertFunctions.mqh` and `DynamicTradingDayDetector.mqh`. Don't regress this when touching those files.
- **`.mqh` files use semicolons inconsistently** (e.g. `CalculationCache.mqh:14` `};` on same line as last field). Compiler accepts; matches existing style. Don't reformat unless doing a dedicated cleanup PR.

## Things to never do
- Do not introduce a new top-level state variable outside `Biotak/GlobalVariables.mqh`.
- Do not add a non-repaint-violating optimization (no `iClose(_Symbol,0,0)` style live-bar access).
- Do not add `Alert()` popups — use `LOG_E(LOG_CAT_*, ...)` or `Print`.
- Do not commit `*.ex5`, `*.log`, `build-logs/`, or `.mq5~`/`.mqh~` (see `.gitignore`).
- Do not create a separate `README.md` section or doc file for a change — inline comments only (`docs/` is for plans and reports).
- Do not commit without running `.\compile-th3.ps1` first. 0 errors / 0 warnings is the gate.

## Quick orientation checklist
1. Are you changing logic? → Read `.github/instructions/instructions-mt5.md` and the relevant section of `docs/Code-Analysis-Report.md` first.
2. Are you changing architecture? → Run the 4-step gate from `.github/instructions/review.md` (understand → impact → minimal design → pre-validate) before writing code.
3. Are you refactoring `EventHandlers.mqh`? → Start from `docs/EventHandlers-Rewrite-Plan.md`.
4. Did the build break? → Check the include order in `Biotak Trigger TH3.mq5:12-62` first; check `BuildConfig.mqh` for accidental `DEBUG_BUILD` toggles; check `Logger.mqh` (included transitively via `BuildConfig.mqh`).
5. Need a runtime log of the compiled indicator? → `.\compile-th3.ps1 -WatchRuntimeLogs` (60s default).
