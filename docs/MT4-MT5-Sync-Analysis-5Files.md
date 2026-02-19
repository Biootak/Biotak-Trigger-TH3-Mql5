# MT4 → MT5 Synchronization Analysis: 5 Files

> **Source of truth**: MT5 (`Biotak-Trigger-TH3-Mql5/Biotak/`)
> **Target to modify**: MT4 (`Biotak-Trigger-TH3/Biotak/`)
> **Rule**: All shared functions must behave identically to MT5.
> **Exception**: KEEP all wave analysis functions in MT4 TH3Tool.mqh.
> **Exception**: REMOVE ATR basis variables from MT4 GlobalVariables.mqh.

---

## 1. THCalculations.mqh

**MT5**: 298 lines | **MT4**: 388 lines

### 1A. Functions/Variables to ADD to MT4

| Item | Description | Dependencies |
|------|-------------|--------------|
| `CalculateStandardPercentage()` | MT5-only function with local static cache for standard percentage calculation | None (self-contained with local cache) |
| `#include "MathConstants.mqh"` | MT5 imports MathConstants.mqh for `SS_MULTIPLIER`, `LS_MULTIPLIER`, `E_MULTIPLIER`, `ATR_FACTOR_M` | Create or port `MathConstants.mqh` for MT4 |
| `#include "CalculationCache.mqh"` | MT5 uses centralized caching (`GetCachedTHCalculation()` / `StoreTHCalculation()`) | Create or port `CalculationCache.mqh` for MT4 **OR** keep local static cache pattern but ensure identical behavior |

### 1B. Functions/Variables to REMOVE from MT4

| Item | Reason |
|------|--------|
| `CalculateControlValue()` | MT4-only, not in MT5 |
| `InvalidateLocalFactorCache()` | MT4-only cache invalidation, not in MT5 |
| Local constant definitions (`SS_MULTIPLIER 1.5`, `LS_MULTIPLIER 2.0`, `ATR_FACTOR 3.0`) | Should come from `MathConstants.mqh` or match MT5 naming (`ATR_FACTOR_M`) |

### 1C. Functions/Variables to CHANGE in MT4

| Item | MT4 Current | MT5 Target | Impact |
|------|-------------|------------|--------|
| `CalculateEStep()` | Uses hardcoded `0.75` | Uses `E_MULTIPLIER` constant | **MATH CHANGE** - verify `E_MULTIPLIER` value matches 0.75 |
| `CalculateTH()` caching | Local static variables | `GetCachedTHCalculation()` / `StoreTHCalculation()` from CalculationCache.mqh | Architectural change OR keep local cache but match logic exactly |
| ATR constant naming | `ATR_FACTOR` (value 3.0) | `ATR_FACTOR_M` | Naming change, verify value matches |
| `GetSymbolPoint` usage | Uses `Point` / `Digits` directly | Uses `GetCachedPoint()` and similar cached accessors | Depends on whether MT4 has cached accessor equivalents |
| `#property strict` | Present | Not present (uses `#ifndef` guard instead) | MT4 requires `#property strict`, keep it |
| Logging pattern | `#ifdef ENABLE_DEBUG_LOGS Print(...)` | `_LOG_GATE_E(...)` macros | Keep MT4 logging pattern (platform-specific) |

### 1D. Dependencies

- `MathConstants.mqh` (needed for constant values)
- `CalculationCache.mqh` (optional - could keep local cache if behavior matches)
- Verify `E_MULTIPLIER` actual value in MT5

---

## 2. GlobalVariables.mqh

**MT5**: 199 lines | **MT4**: 264 lines

### 2A. Functions/Variables to ADD to MT4

| Item | Description | Dependencies |
|------|-------------|--------------|
| `g_redrawNeeded` (bool) | MT5 flag for throttled redraw | Used by `ThrottledChartRedraw()` |
| `g_labelsRelayoutNeeded` (bool) | MT5 flag for labels relayout | Used by label positioning system |
| `g_th3FreqLabelName` | MT5 has this for frequency label management | None |
| `IsIndicatorHidden()` TTL-based cache | MT5 uses `HIDDEN_CACHE_TTL_MS` with `GetTickCount()` for cached check | `HIDDEN_CACHE_TTL_MS` constant from PerformanceOptimizations.mqh |
| `SanitizeSymbolName()` PERF cache | MT5 caches result with `static string s_lastResult` pattern | None (self-contained) |
| `RestoreBoolGlobalVar()` epsilon validation | MT5 uses `MathAbs(val - 1.0) < 0.01` with corruption detection | None |
| `DEFAULT_TH3_FREQ_INDEX` usage | MT5 uses `g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX` | Constant from ConstantsAndEnums.mqh |

### 2B. Functions/Variables to REMOVE from MT4

| Item | Reason |
|------|--------|
| `g_calculationBasisOverride` | ATR basis variable - user says REMOVE |
| `g_basisModeLabelName` | ATR basis UI label - user says REMOVE |
| `"Biotak_CalcBasis_"` in `CleanupAllGlobalVariables()` | ATR basis global variable cleanup - REMOVE |
| `CacheEntry` struct / `g_thCache[]` array | MT4-only local cache system, not in MT5. REMOVE if switching to CalculationCache.mqh, or refactor to match |
| `g_performanceMetricsInitialized` | MT4-only, not in MT5 |

### 2C. Functions/Variables to CHANGE in MT4

| Item | MT4 Current | MT5 Target | Impact |
|------|-------------|------------|--------|
| `g_isHidden` | Simple `bool g_isHidden` variable | **REMOVED** - MT5 uses `IsIndicatorHidden()` with TTL cache | Refactor all `g_isHidden` references to use `IsIndicatorHidden()` |
| `g_th3FreqIndex` default | Hardcoded `= 16` | `= DEFAULT_TH3_FREQ_INDEX` | Use constant |
| `CHART_REDRAW_THROTTLE_MS` | `50` | `100` | Timing change |
| `RestoreBoolGlobalVar()` | `(val > 0.5)` simple check | Epsilon-based: `MathAbs(val - 1.0) < 0.01` + corruption detection | Logic change |
| `CleanupAllGlobalVariables()` | Includes ATR basis cleanup, different item count | Array-based approach with 13 items (no ATR basis) | Remove ATR items, match array approach |
| `IsIndicatorHidden()` | No cache, simple query | TTL-based cache (`HIDDEN_CACHE_TTL_MS = 100ms`) | Add caching |
| `SanitizeSymbolName()` | No cache | Static cache for last result | Add caching |

### 2D. Dependencies

- `PerformanceOptimizations.mqh` (for `HIDDEN_CACHE_TTL_MS`)
- `ConstantsAndEnums.mqh` (for `DEFAULT_TH3_FREQ_INDEX`)
- All files referencing `g_isHidden` need updating
- All files referencing `g_calculationBasisOverride` need updating (removal)

---

## 3. PerformanceOptimizations.mqh

**MT5**: 143 lines | **MT4**: 437 lines

### 3A. Functions/Variables to ADD to MT4

| Item | Description | Dependencies |
|------|-------------|--------------|
| Pip size initialization in `InitializeGlobalCache()` | MT5 sets `g_cachedPipSize` during init | None |

### 3B. Functions/Variables to REMOVE from MT4

| Item | Reason |
|------|--------|
| `FunctionCache` system (GOLD FIX #13) | Not in MT5 |
| `String builders` (GOLD FIX #14) | Not in MT5 |
| `ObjectExistsCached()` (GOLD FIX #15) | Not in MT5 |
| `PreAllocateArray()` (GOLD FIX #16) | Not in MT5 |
| `BatchObjectOperation` system (GOLD FIX #17) | Not in MT5 |
| `MemoryPool` system (GOLD FIX #18) | Not in MT5 |
| `UpdatePeriodCache()` | MT4-only function |

> **WARNING**: Removing GOLD FIX #13–#18 may impact MT4 performance. These were added specifically for MT4 optimization. Consider: (a) keeping them as MT4-only additions outside the shared API surface, or (b) verifying MT4 performance is acceptable without them.

### 3C. Functions/Variables to CHANGE in MT4

| Item | MT4 Current | MT5 Target | Impact |
|------|-------------|------------|--------|
| `g_cachedPeriod` | Named `g_cachedPeriod` | Named `g_cachedPeriodValue` | Rename + update all references |
| `g_cachedPipSizePerf` | Named `g_cachedPipSizePerf` | Named `g_cachedPipSize` | Rename + update all references |
| `HIDDEN_CACHE_TTL_MS` | `100` | `100` | Already matches ✓ |
| `InitializeGlobalCache()` | Does NOT set pip size | Sets pip size during init | Add pip size init |
| `CleanupPerformanceOptimizations()` | May include GOLD FIX cleanup | Simpler cleanup | Match MT5 |

### 3D. Dependencies

- All files using `g_cachedPeriod` → rename to `g_cachedPeriodValue`
- All files using `g_cachedPipSizePerf` → rename to `g_cachedPipSize`
- Files using GOLD FIX functions need alternative solutions or removal of calls

---

## 4. ConstantsAndEnums.mqh

**MT5**: 499 lines | **MT4**: 628 lines

### 4A. Functions/Variables to ADD to MT4

| Item | Description | Dependencies |
|------|-------------|--------------|
| `#ifndef CONSTANTS_AND_ENUMS_MQH` / `#define` guard | MT5 has include guard, MT4 does not | None |
| `OBJ_ALL_PERIODS` / `OBJ_NO_PERIODS` | Visibility constants for object timeframe control | Used by TH3Tool.mqh for info label visibility |
| `FRACTAL_SHORT_NAMES[]` array | Short names for fractal display | Used by fractal UI functions |

### 4B. Functions/Variables to REMOVE from MT4

| Item | Reason |
|------|--------|
| `FREQ_HISTORY_SIZE 20` define | Not in MT5 (or verify if needed by MT4-only wave functions) |

> **NOTE**: `ENUM_CALCULATION_BASIS` enum is in both MT4 and MT5. Since user wants ATR basis REMOVED from GlobalVariables, verify whether this enum should stay (it may be used by other non-ATR calculations).

### 4C. Functions/Variables to CHANGE in MT4

| Item | MT4 Current | MT5 Target | Impact |
|------|-------------|------------|--------|
| **`ENUM_STRUCTURE_BASE_MULTIPLIER`** | **Power formula**: L1=base^1, L2=base^2, L3=base^3 (e.g. Base 3: L1=3, L2=9, L3=27) | **2× ratio (fractal)**: L1=base×1, L2=base×2, L3=base×4 (e.g. Base 3: L1=3, L2=6, L3=12) | **⚠️ CRITICAL MATH CHANGE** - affects ALL level calculations |
| TH3 suffix definitions | `#define` macros (`#define TH3_SUFFIX_LINE_AB "_Line_AB"`) | `const string` variables (`const string TH3_SUFFIX_LINE_AB = "_Line_AB"`) | Change from macros to const strings |
| `MAX_SAFE_LEVELS` | `2000` | `200` | **10× reduction** - verify MT4 doesn't need higher limit |
| `MAX_SAFE_OBJECTS` | `5000` | `3000` | Reduction |
| `OBJECT_COUNT_INCREASE_THRESHOLD` | `100` | `30` | Reduction |
| `REDRAW_THROTTLE_SECONDS` | `10` | `0` | MT5 has no throttle (uses ThrottledChartRedraw instead) |
| `CLEANUP_INTERVAL_SECONDS` | `300` (5 min) | `60` (1 min) | More frequent cleanup |
| `ENUM_ADAPTIVE_MODE` position | Defined separately near bottom | Defined inline with other enums | Reposition |
| `MIN_SCALING_FACTOR` / `MAX_SCALING_FACTOR` | Same values but different definition style | Match MT5 style | Minor |

### 4D. Dependencies

- **`ENUM_STRUCTURE_BASE_MULTIPLIER` change is the HIGHEST RISK item in this entire analysis** - it changes the mathematical formula for level calculations. Every file that uses structure base multiplier calculations will be affected.
- `OBJ_ALL_PERIODS` / `OBJ_NO_PERIODS` needed by TH3Tool.mqh (MT4 already using them in DrawABCDPattern line ~2770 - verify they're actually defined somewhere for MT4)
- Safety constant changes may affect object creation limits

---

## 5. TH3Tool.mqh

**MT5**: 931 lines | **MT4**: 3,464 lines

This is the most complex file with the largest divergence.

### 5A. Functions to ADD to MT4 (from MT5)

These are functions MT5 has that MT4 is missing. The MT5 version is much more modular.

| Function | Purpose | Notes |
|----------|---------|-------|
| `CreateOrUpdateTrendLine()` | Utility to create or update a trend line object | Used by DrawABCDPattern, reduces code duplication |
| `DeletePatternObjects()` | Separate function for comprehensive pattern cleanup | MT4 has this inline in OnABCDMouseEvent CHARTEVENT_OBJECT_DELETE handler |
| `DrawABCDPoints()` | Draws the A/B/C/D arrow points and labels | MT4 has this inline in DrawABCDPattern (~200 lines) |
| `DrawABCDTargetLevels()` | Draws Step1/3/5/7 target levels with zones | MT4 has this inline in DrawABCDPattern (~150 lines) |
| `DrawABCDInfoLabel()` | Draws the info label with FrequencyResult display | MT4 has this inline in DrawABCDPattern (~50 lines). MT5 version shows FrequencyResult data |
| `CreateABCDTempPoint()` | Creates temporary point during drawing | MT4 has this inline in OnABCDMouseEvent |
| `CreateABCDTempLine()` | Creates temporary line during drawing | MT4 has this inline in OnABCDMouseEvent |
| `CleanupABCDTempObjects()` | Cleans up all temp objects | MT4 has this inline (repeated 3+ times) |
| `CancelABCDDrawing()` | Cancels drawing mode and cleans up | MT4 has this inline (repeated 2+ times) |
| `HandleABCDPointPlacement()` | Handles the 4-point click workflow (X→A→B→C) | MT4 has this inline in OnABCDMouseEvent with duplicated code paths |
| `ExtractPatternBaseName()` | Extracts base pattern name from any pattern object name | MT4 has this inline in delete handler |
| `ProcessABCDClick()` | Processes chart click for point placement | MT4 has this inline |
| `HandleABCDMouseMove()` | Handles mouse move preview during drawing | MT4 handles inline |
| `HandleABCDObjectDrag()` | Handles point drag with re-optimization | MT4 has inline with smart magnet |
| `HandleABCDObjectDelete()` | Handles pattern object deletion | MT4 has inline |

### 5B. Functions to REMOVE from MT4

**NONE** — per user instruction, ALL wave analysis functions are to be KEPT.

**MT4-ONLY functions to KEEP** (not in MT5, but retained per user requirement):

| Function | Lines | Purpose |
|----------|-------|---------|
| `GetCachedDailyATR()` | ~30 | Cached daily ATR via `iATR()` |
| `CalculateOptimalDefaultFrequency()` | ~40 | Default frequency calculation |
| `GetCurrentTH3Frequency()` | ~20 | Get current TH3 frequency |
| `WaveAnalysis` struct | ~30 | Wave analysis data structure |
| `AnalyzeThreeWaves()` | ~400 | 3-wave pattern analysis |
| `CalculateWaveAngle()` | ~30 | Wave angle calculation |
| `CalculateRequiredRestCandles()` | ~30 | Rest candle calculation |
| `DetermineReferenceTimeframe()` | ~80 | Reference timeframe via Gann |
| `CalculateConsolidationFactor()` | ~60 | Gann-based consolidation |
| `CalculateFrequencyFromWaves()` | ~40 | Frequency from wave analysis |
| `CalculateMovementSpeed()` | ~40 | Movement speed via ATR |
| `CalculateTimeSymmetry()` | ~30 | Time symmetry analysis |
| `FrequencySearchResult` struct | ~20 | Search result data structure |
| `AnalyzeHarmonicProperties()` | ~60 | Pythagorean means + Golden ratio |
| `CalculateFrequencyError()` | ~50 | Frequency error with div-by-zero protection |
| `CalculateFibonacciDeviation()` | ~40 | Fibonacci deviation analysis |
| `FindOptimalFrequencyForABCD()` | ~600 | Massive multi-factor frequency optimizer |
| `AutoSelectBestFrequency()` | ~100 | Auto-select with X point estimation |
| `FindOptimalFrequencyForABCD_WithLearningData()` | ~40 | Wrapper with learning data output |
| `CycleTH3Frequency()` | ~20 | Increment frequency (key 3) |
| `DecrementTH3Frequency()` | ~20 | Decrement frequency (key 4) |

### 5C. Functions to CHANGE in MT4

| Function | What to Change | Impact |
|----------|---------------|--------|
| **`SetActiveABCDPattern()`** | (1) Use `TH3_SUFFIX_INFO` constant instead of `"_Info"` string literal. (2) Replace `ChartRedraw()` with `ThrottledChartRedraw()`. (3) Match MT5's `IsIndicatorHidden()` usage instead of `g_isHidden`. (4) Match MT5's visibility toggle logic with `OBJ_ALL_PERIODS`/`OBJ_NO_PERIODS`. | Medium |
| **`CalculateABCDPointD()`** | (1) MT5 uses `GetCachedPoint()` instead of `Point`. (2) Match MT5's validation logic (may be stricter or more relaxed — compare exactly). (3) Time calculation: MT5 may use different bar-shift approach. | Medium — math logic |
| **`DrawABCDPattern()`** | **Major refactor**: Break monolithic ~500 line function into modular calls matching MT5: `DrawABCDPoints()`, `DrawABCDTargetLevels()`, `DrawABCDInfoLabel()`. MT5 version also displays `FrequencyResult` data in info label. | **HIGH** — largest single change |
| **`UpdateAllTH3Objects()`** | (1) MT5 uses `ObjectsTotal(0, 0, -1)` / `ObjectName(0, i, 0, -1)` (MT5 API). MT4 uses `ObjectsTotal(0, -1, OBJ_TREND)` / `ObjectName(0, i, -1, OBJ_TREND)` — keep MT4 API. (2) Replace `ChartRedraw()` with `ThrottledChartRedraw()`. | Low |
| **`OnABCDMouseEvent()`** | **Major refactor**: (1) Break monolithic handler into separate functions matching MT5: `HandleABCDPointPlacement()`, `ProcessABCDClick()`, `HandleABCDMouseMove()`, `HandleABCDObjectDrag()`, `HandleABCDObjectDelete()`. (2) Keep MT4's MOUSE_MOVE rising-edge click detection (MT4-specific). (3) Keep MT4's CHARTEVENT_CLICK fallback (MT4-specific). (4) Keep MT4's smart magnet effect (may be MT4-only enhancement). (5) In point C completion: Keep MT4's `FindOptimalFrequencyForABCD_WithLearningData()` call instead of MT5's `FindOptimalFrequency()+ApplyOptimalFrequency()`. (6) In drag handler: Keep MT4's wave-analysis-based re-optimization. (7) Replace all `ChartRedraw()` with `ThrottledChartRedraw()`. | **HIGH** — most complex change |
| **`ToggleTH3Tool()`** | Replace `ChartRedraw()` with `ThrottledChartRedraw()`. Minor differences in temp object cleanup. | Low |
| **Pattern Registry** (`FindTH3PatternRegistryIndex`, etc.) | MT4 uses `ObjectsTotal()` (no params) vs MT5 `ObjectsTotal(0, 0, -1)`. MT4 uses `ObjectFind(name)` or `ObjectFind(0, name)` inconsistently vs MT5's `ObjectFind(0, name)` consistently. Keep MT4 API but ensure logic matches. | Low |
| **`RepositionABCDInfoLabels()`** | Match MT5's positioning logic, use `TH3_SUFFIX_INFO`. | Low |

### 5D. Architectural Changes Required

1. **Modularization**: MT5 has 15+ small focused functions where MT4 has 3-4 large monolithic ones. The refactor should extract inline code into separate functions matching MT5's names and signatures, while keeping MT4-specific implementations where needed (wave analysis, smart magnet, click detection).

2. **ChartRedraw → ThrottledChartRedraw**: MT4 calls `ChartRedraw()` directly in ~10 places. All should be replaced with `ThrottledChartRedraw()` (needs to be available in MT4).

3. **Include guard**: Add `#ifndef TH3_TOOL_MQH` / `#define TH3_TOOL_MQH` at the top.

4. **Frequency optimization integration**: Where MT5 calls `FindOptimalFrequency()` + `ApplyOptimalFrequency()` (from FrequencyOptimizer.mqh), MT4 should continue calling its own `FindOptimalFrequencyForABCD_WithLearningData()` + `AutoSelectBestFrequency()` wave analysis system.

### 5E. Dependencies

- `ThrottledChartRedraw()` function must exist in MT4
- `TH3_SUFFIX_INFO` and other suffix constants must be `const string` (after ConstantsAndEnums change)
- `IsIndicatorHidden()` with cache (after GlobalVariables change)
- `OBJ_ALL_PERIODS` / `OBJ_NO_PERIODS` (after ConstantsAndEnums change)
- `GetCachedPoint()` or equivalent cached accessor

---

## Summary: Risk Assessment & Recommended Order

### Highest Risk Items

| # | Item | File | Risk | Reason |
|---|------|------|------|--------|
| 1 | `ENUM_STRUCTURE_BASE_MULTIPLIER` formula change | ConstantsAndEnums.mqh | **CRITICAL** | Changes power formula → 2× ratio — affects ALL level calculations across entire codebase |
| 2 | `DrawABCDPattern()` modularization | TH3Tool.mqh | **HIGH** | Breaking ~500 line monolithic function into 3+ sub-functions |
| 3 | `OnABCDMouseEvent()` refactor | TH3Tool.mqh | **HIGH** | Breaking ~700 line monolithic handler into 5+ sub-functions while preserving MT4-specific click detection |
| 4 | Safety constant reductions | ConstantsAndEnums.mqh | **MEDIUM** | `MAX_SAFE_LEVELS` 2000→200, `MAX_SAFE_OBJECTS` 5000→3000 may cause truncation on MT4 |
| 5 | `g_isHidden` → `IsIndicatorHidden()` migration | GlobalVariables.mqh | **MEDIUM** | All references to `g_isHidden` across codebase need updating |

### Recommended Implementation Order

1. **ConstantsAndEnums.mqh** — Foundation changes (include guard, constants, enums). **WARNING**: `ENUM_STRUCTURE_BASE_MULTIPLIER` change needs careful testing.
2. **PerformanceOptimizations.mqh** — Variable renames, pip size init. Consider keeping GOLD FIX systems as MT4-only.
3. **GlobalVariables.mqh** — Remove ATR basis, add caching, update IsIndicatorHidden.
4. **THCalculations.mqh** — Constant alignment, add CalculateStandardPercentage, remove CalculateControlValue.
5. **TH3Tool.mqh** — Modularize DrawABCDPattern and OnABCDMouseEvent. This is the largest task and should be done last after all dependencies are in place.

### Quick Stats

| File | Functions to ADD | Functions to REMOVE | Functions to CHANGE | Net Complexity |
|------|-----------------|--------------------|--------------------|----------------|
| THCalculations.mqh | 1 | 2 | 5 | Medium |
| GlobalVariables.mqh | 7 | 5 | 7 | Medium |
| PerformanceOptimizations.mqh | 1 | 6 systems | 4 | Medium (high if removing GOLD FIX) |
| ConstantsAndEnums.mqh | 3 | 1 | 9 | High (due to math change) |
| TH3Tool.mqh | 15 | 0 | 7 | Very High |

---

## Open Questions for User

1. **`ENUM_STRUCTURE_BASE_MULTIPLIER`**: The MT5 formula (2× ratio: 3→6→12) is fundamentally different from MT4 (power: 3→9→27). Changing this will alter every level calculation. **Is this intentional?** If MT5 is source of truth, this must change, but it's the single highest-impact change.

2. **GOLD FIX #13–#18 in PerformanceOptimizations.mqh**: These MT4-only optimizations (FunctionCache, StringBuilders, ObjectExistsCached, PreAllocateArray, BatchObjectOperation, MemoryPool) are not in MT5. Should they be:
   - (a) Removed entirely (match MT5)?
   - (b) Kept as MT4-only additions (wrapped in `#ifdef`)?

3. **Safety constants** (`MAX_SAFE_LEVELS` 2000→200, `MAX_SAFE_OBJECTS` 5000→3000): MT4 historically needed higher limits. Should these be reduced to match MT5, or kept higher for MT4?

4. **`FREQ_HISTORY_SIZE`**: This is defined in MT4 ConstantsAndEnums.mqh but not MT5. Is it used by MT4-only wave analysis functions? If so, it should be kept.

5. **`REDRAW_THROTTLE_SECONDS`** changing from 10→0: MT5 uses `ThrottledChartRedraw()` instead. Does MT4 have `ThrottledChartRedraw()` available, or does it need to be created?

6. **Smart Magnet effect** in MT4 TH3Tool.mqh drag handler (snap to H/L/O/C within 5-pip threshold): This is MT4-only. Keep it?
