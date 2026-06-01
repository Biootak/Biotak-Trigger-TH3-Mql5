# Comprehensive Code Analysis Report — Biotak Trigger TH3

**Generated:** 2025  
**Scope:** All `.mqh` files in `Biotak/` directory (~33 files, ~15,000+ lines)  
**Categories:** Division by zero, Array bounds, Memory leaks, Missing error handling, Magic numbers, Deep nesting, Long functions, Dead code, Performance issues, Object creation every tick

---

## Summary

| Priority | Count |
|----------|-------|
| CRITICAL | 4     |
| HIGH     | 12    |
| MEDIUM   | 16    |

---

## CRITICAL Issues (Crashes, Memory Leaks, Division by Zero)

### C1. Array Out-of-Bounds via Macro — `BasePriceManager.mqh`

**File:** `BasePriceManager.mqh` lines 183–189  
**Category:** CRITICAL — Array Bounds / Crash  
**Description:** Seven macros access `g_symbolStates[GetCachedSymbolStateIndex()]` without checking if the index is `-1`. `GetCachedSymbolStateIndex()` delegates to `GetSymbolStateIndex()` which returns `-1` on failure (e.g., array limit hit, resize failure). Accessing `g_symbolStates[-1]` is undefined behavior and will crash the terminal.

**Problematic code:**
```mql5
#define g_basePriceCached (g_symbolStates[GetCachedSymbolStateIndex()].basePriceCached)
#define g_lastProcessedBlockTimestamp (g_symbolStates[GetCachedSymbolStateIndex()].lastProcessedBlockTimestamp)
#define g_referenceM1Power (g_symbolStates[GetCachedSymbolStateIndex()].referenceM1Power)
#define g_historyCount (g_symbolStates[GetCachedSymbolStateIndex()].historyCount)
#define g_lastHistoryDay (g_symbolStates[GetCachedSymbolStateIndex()].lastHistoryDay)
#define g_lastHistoryYear (g_symbolStates[GetCachedSymbolStateIndex()].lastHistoryYear)
#define g_systemInitialized (g_symbolStates[GetCachedSymbolStateIndex()].systemInitialized)
```

**Suggested fix:** Add a safe accessor function:
```mql5
BasePriceState* GetSafeSymbolState() {
    int idx = GetCachedSymbolStateIndex();
    if(idx < 0 || idx >= g_symbolStateCount) {
        // Return a static fallback state instead of crashing
        static BasePriceState s_fallback;
        return &s_fallback;
    }
    return &g_symbolStates[idx];
}
```
Or at minimum, gate every macro caller with an `if(GetCachedSymbolStateIndex() >= 0)` check. The helper functions `GetHistoryEntry`, `SetHistoryEntry`, `ResizeHistory`, etc. already check `stateIdx < 0`, but the macros bypass this entirely.

---

### C2. Recursive Call After Eviction — `ObjectCache.mqh`

**File:** `ObjectCache.mqh` lines ~195  
**Category:** CRITICAL — Stack Overflow  
**Description:** `CacheAddObject()` calls `EvictLRUEntry()` when the cache is full, then calls itself recursively. If eviction fails to free space (e.g., `g_objectCacheSize` tracking is corrupted), this creates infinite recursion and a stack overflow crash.

**Problematic code:**
```mql5
// All probed slots occupied - force eviction
_LOG_GATE_W Print("[W][SYNC] Object cache collision - forcing LRU eviction");
EvictLRUEntry();

// Try again after eviction
CacheAddObject(name, price, clr, style, width);  // ← RECURSIVE CALL
```

**Suggested fix:** Replace recursion with a single retry using a flag:
```mql5
// After EvictLRUEntry(), retry insertion inline:
slot = HashObjectName(name);
for(int probe2 = 0; probe2 < CACHE_HASH_BUCKETS; probe2++) {
    int insertIdx = (slot + probe2) % CACHE_HASH_BUCKETS;
    if(!g_objectCacheHash[insertIdx].occupied || g_objectCacheHash[insertIdx].deleted) {
        // Insert here (same code as above)
        break;
    }
}
// If still no slot, log error and return without crashing
```

---

### C3. Potential Division by Zero in `pointsPerPip` Calculation — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` line ~82  
**Category:** CRITICAL — Division by Zero (mitigated but fragile)  
**Description:** `pointsPerPip = s_cachedPointValue / s_cachedPipSize` is guarded by an `IsZero` check a few lines above, but the check uses `EPSILON_PRICE` which may not cover all edge cases (e.g., extremely small pip sizes on exotic instruments). The `IsZero` function itself may not catch values like `1e-15` that still cause floating-point precision issues.

**Problematic code:**
```mql5
if(IsZero(s_cachedPointValue, EPSILON_PRICE) || IsZero(s_cachedPipSize, EPSILON_PRICE)) {
    _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid point/pip size...");
    return;
}
const double pointsPerPip = s_cachedPointValue / s_cachedPipSize;
```

**Suggested fix:** Use `SafeDivide()` instead, which already exists in the codebase:
```mql5
const double pointsPerPip = SafeDivide(s_cachedPointValue, s_cachedPipSize, 1.0, EPSILON_PRICE);
```

---

### C4. Unguarded Array Access in `intervals[]` — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~170–180 (debug block)  
**Category:** CRITICAL — Array Out-of-Bounds  
**Description:** The debug print statement accesses `intervals[0]` through `intervals[4]` after only checking `intervalSize == 0`. If `intervalSize` is 1–4, accessing `intervals[4]` is out of bounds.

**Problematic code:**
```mql5
int intervalSize = ArraySize(intervals);
if(intervalSize == 0) {
    return;
}
#ifdef ENABLE_DEBUG_LOGS
Print("[D][LBL] DrawTHLevels using Base Multiplier: ", baseMultiplier,
      " L1=", intervals[0], ", L2=", intervals[1], ", L3=", intervals[2],
      ", L4=", intervals[3], ", L5=", intervals[4]);  // ← OOB if size < 5
#endif
```

**Suggested fix:** Guard the debug print:
```mql5
#ifdef ENABLE_DEBUG_LOGS
if(intervalSize >= 5) {
    Print("[D][LBL] DrawTHLevels using Base Multiplier: ", baseMultiplier,
          " L1=", intervals[0], ", L2=", intervals[1], ", L3=", intervals[2],
          ", L4=", intervals[3], ", L5=", intervals[4]);
}
#endif
```

---

## HIGH Issues (Performance, Missing Error Handling)

### H1. `DrawTHLevels` is ~550 lines — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines 65–615  
**Category:** HIGH — Long Function  
**Description:** `DrawTHLevels()` spans ~550 lines with two nearly-identical while loops (above/below midpoint). This violates DRY and makes maintenance error-prone — any fix to the "above" loop must be duplicated in the "below" loop.

**Suggested fix:** Extract a helper function:
```mql5
void DrawTHLevelsOneDirection(
    const string prefix, double startPrice, double stepSize,
    int maxLevels, bool isAbove, /* ... shared params ... */) {
    // Single parameterized loop for both directions
}
```

---

### H2. `DisplayATRLabels` is ~250+ lines — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~700–950  
**Category:** HIGH — Long Function  
**Description:** Large function with multi-timeframe ATR label layout, centering calculations, and object management all in one body.

**Suggested fix:** Extract layout calculation, text formatting, and object creation into separate helper functions.

---

### H3. Deep Nesting (5+ levels) — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~250–500  
**Category:** HIGH — Deep Nesting  
**Description:** The while loops in `DrawTHLevels` contain `if(levelType == 1)` → `switch(structLevel)` → `case N:` → string building, reaching 5+ levels of indentation. This reduces readability significantly.

**Suggested fix:** Extract the switch-case block into a dedicated function like `BuildLevelProperties()` that returns a struct with name, tooltip, color, style, and width.

---

### H4. Magic Number `0.6` for Font Width Factor — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~638, ~644, ~655  
**Category:** HIGH — Magic Numbers  
**Description:** The character width estimation `StringLen(text) * inpFontSize * 0.6` appears multiple times with the hardcoded `0.6` factor. If the font changes, all instances must be found and updated.

**Problematic code:**
```mql5
int mainTextWidth = (int)(StringLen(mainText) * inpFontSize * 0.6);
int stepsTextWidth = (int)(StringLen(stepsText) * inpFontSize * 0.6);
// ... and more
```

**Suggested fix:** Define a named constant:
```mql5
#define FONT_CHAR_WIDTH_FACTOR 0.6
```

---

### H5. `ObjectsTotal` Called in Hot Path — `HideAllTHObjects` in `EventHandlers.mqh`

**File:** `EventHandlers.mqh` lines ~354–370  
**Category:** HIGH — Performance  
**Description:** `HideAllTHObjects()` iterates ALL chart objects via `ObjectsTotal` + `ObjectName` in an O(n) loop. This is called on F-key toggle (user-interactive path). With 1000+ chart objects from other indicators, this becomes slow.

**Problematic code:**
```mql5
int total = ObjectsTotal(0, -1, -1);
for(int i = total - 1; i >= 0; i--) {
    string objName = ObjectName(0, i, -1, -1);
    // prefix string comparison for each
}
```

**Suggested fix:** Use the object cache (like `SetAllTHObjectsVisibility` in `VisibilityManager.mqh` already does) instead of scanning all chart objects:
```mql5
void HideAllTHObjects() {
    SetAllTHObjectsVisibility(false);
    // Also hide special labels
}
```

---

### H6. `CacheRebuild` Only Caches "TH" Prefixed Objects — `ObjectCache.mqh`

**File:** `ObjectCache.mqh` lines ~275–295  
**Category:** HIGH — Missing Error Handling  
**Description:** `CacheRebuild()` only adds objects starting with "TH" to the cache, but the indicator creates objects with many prefixes (`Zone_`, `Mid_`, `ATR_`, `ABCD_Pattern_`, custom prefix from `inpObjectPrefix`). This means after a rebuild, most objects are cache-miss, causing redundant `ObjectFind` calls.

**Problematic code:**
```mql5
if(StringLen(objName) >= 2 && StringGetCharacter(objName, 0) == 'T' && StringGetCharacter(objName, 1) == 'H') {
    // Only caches "TH*" objects
}
```

**Suggested fix:** Cache objects matching the configured `inpObjectPrefix`, or cache all indicator-owned objects by checking the actual prefix.

---

### H7. No Error Check on `iBarShift` Return in Multiple Locations — `TH3Tool.mqh`

**File:** `TH3Tool.mqh` lines ~577–580  
**Category:** HIGH — Missing Error Handling  
**Description:** `CreateABCDTempPoint` calls `iBarShift` and guards `-1` return, but the fix sets `barIndex = 0` as fallback, which silently uses the current bar instead of the intended bar. The same pattern appears several times. While documented as a "BUG FIX", the fallback behavior may produce visually incorrect results.

**Suggested fix:** When `iBarShift` returns `-1`, either skip drawing the temp point with a warning, or use time-based interpolation (as done in `CalculateABCDPointD`).

---

### H8. Emergency Cleanup Deletes Non-Indicator Objects — `ObjectCountManager.mqh`

**File:** `ObjectCountManager.mqh` lines ~125–145  
**Category:** HIGH — Missing Error Handling  
**Description:** `EmergencyCleanupObjects()` Phase 1 deletes ANY old object on the chart that doesn't match the indicator prefix. This could delete drawings from other indicators or manual user objects. Phase 2 uses prefix-based `ObjectsDeleteAll` on "Zone_" and "Mid_" which could also affect other indicators using similar naming.

**Problematic code:**
```mql5
// Delete if older than cutoff
if(objTime > 0 && objTime < cutoffTime) {
    CacheRemoveObject(objName);
    if(ObjectDelete(0, objName)) {
        deletedCount++;
    }
}
```

**Suggested fix:** Only delete objects that match `inpObjectPrefix` in Phase 1, and use the full prefix in Phase 2:
```mql5
if(StringSubstr(objName, 0, prefixLen) == cachedPrefix && objTime > 0 && objTime < cutoffTime) {
    // Only delete OUR objects
}
```

---

### H9. Static Variables Inside Functions Prevent Multi-Instance — Multiple files

**File:** `LabelFunctions.mqh`, `HistoricalDataFunctions.mqh`, `VisibilityManager.mqh`  
**Category:** HIGH — Performance / Design  
**Description:** Extensive use of `static` local variables for caching (e.g., `s_lastHighPrice`, `cachedPrices[6]`, `s_lastAllTHVisible`). While these are effective single-instance caches, MQL5 allows multiple indicator instances on different charts. Static locals are shared across all instances in the same chart, but if two indicators run on the same chart with different settings, stale cache values may cause incorrect behavior.

**Suggested fix:** Document the single-instance assumption, or move cache state into a per-instance manager struct.

---

### H10. `GetPriceForPreviousDay` Returns Stale Cache After Weekend — `HistoricalDataFunctions.mqh`

**File:** `HistoricalDataFunctions.mqh` lines ~37–55  
**Category:** HIGH — Missing Error Handling  
**Description:** The cache TTL is `SECONDS_PER_DAY`, but it caches `iClose(_Symbol, PERIOD_D1, 1)`. On Monday at market open, bar index `1` is Friday's bar. If the cache was populated late Sunday from an initial load, the cached prices may reference Saturday (no bar) values from the previous `iClose` call. The code doesn't validate that the D1 bar is a trading day.

**Problematic code:**
```mql5
static datetime lastUpdate = 0;
if(currentTime - lastUpdate >= SECONDS_PER_DAY || lastUpdate == 0) {
    cachedPrices[0] = iClose(_Symbol, PERIOD_D1, 1);
    // ...
}
```

**Suggested fix:** Validate the returned bar time against known market open times, or use `iTime(PERIOD_D1, 1)` to verify it's a valid trading day.

---

### H11. LRU Tracking Can Go Stale — `ObjectCache.mqh`

**File:** `ObjectCache.mqh` lines ~175–185  
**Category:** HIGH — Performance  
**Description:** The `g_lruMinIdx` / `g_lruMinTime` O(1) LRU tracking becomes stale when entries are updated (`CacheUpdateObject` refreshes `lastAccess` but never updates the LRU tracker). This means the "O(1) fast path" may evict a recently-accessed entry instead of the actual LRU entry.

**Suggested fix:** When `CacheUpdateObject` refreshes `lastAccess`, check if the updated entry was the tracked LRU minimum and invalidate `g_lruMinIdx`:
```mql5
if(idx == g_lruMinIdx) {
    g_lruMinIdx = -1;
    g_lruMinTime = 0;
}
```

---

### H12. Missing `ArrayFree` for Dynamic Arrays in `FrequencyOptimizer.mqh`

**File:** `FrequencyOptimizer.mqh`  
**Category:** HIGH — Memory  
**Description:** Functions like `ScoreMultiStepResonance` declare fixed-size stack arrays (`midpointUsed[MAX_REFERENCE_MIDPOINTS]`, `stepPrices[4]`), which are fine. However, the main `OptimizeFrequency` function (not fully shown) likely builds candidate arrays and top-N tracking. If any dynamically resized arrays are used without `ArrayFree`, they persist across calls.

**Suggested fix:** Audit the full `OptimizeFrequency` function for any `ArrayResize` calls and ensure corresponding `ArrayFree` on all exit paths.

---

## MEDIUM Issues (Code Smells, Maintainability)

### M1. Magic Number `50.0` as Fallback Factor — `EventHandlers.mqh`

**File:** `EventHandlers.mqh` line ~233  
**Category:** MEDIUM — Magic Numbers  

```mql5
g_factorValueOverride = 50.0;
```

**Suggested fix:** Define `DEFAULT_FACTOR_VALUE 50.0` as a named constant.

---

### M2. Magic Number `1000.0` as Max Factor Clamp — `ConstantsAndEnums.mqh`

**File:** `ConstantsAndEnums.mqh`  
**Category:** MEDIUM — Magic Numbers  
**Description:** `MAX_SAFE_FACTOR` is defined but the bounds check in `EventHandlers.mqh` uses it. However, other magic thresholds like `1000000.0` for custom price validation and `100` for font size max exist without named constants.

**Suggested fix:** Define named constants for all validation limits.

---

### M3. Magic Number `300` for Max Cleanup Items — `ObjectCountManager.mqh`

**File:** `ObjectCountManager.mqh`  
**Category:** MEDIUM — Magic Numbers  
**Description:** Implicit limit of items to delete during Phase 1 cleanup is not explicitly capped, but the `EMERGENCY_CLEANUP_AGE = 3600` and various thresholds are hardcoded.

---

### M4. Magic Numbers in Font/Layout Constants — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~635–660  
**Category:** MEDIUM — Magic Numbers  
**Description:** Multiple hardcoded layout values:
- `0.6` — font character width estimation factor (3 occurrences)
- `6` — title gap offset
- `20` — bottom padding
- `0.7` — char width estimation in another location
- `4` — mode label spacing

**Suggested fix:** Define layout constants in `ConstantsAndEnums.mqh`:
```mql5
#define LABEL_CHAR_WIDTH_MULTIPLIER 0.6
#define LABEL_TITLE_GAP 6
#define LABEL_BOTTOM_PADDING 20
```

---

### M5. Duplicated Level Drawing Logic (Above/Below Loops) — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` lines ~200–600  
**Category:** MEDIUM — Code Duplication  
**Description:** The "above" and "below" loops in `DrawTHLevels` are ~200 lines each with nearly identical logic. The only differences are: direction of price movement, prefix naming (`_Up_` vs `_Down_`, `+` vs `-`), and initial price offset direction.

**Suggested fix:** Extract into a single parameterized function (see H1).

---

### M6. Inconsistent Tab/Space Indentation — Multiple files

**File:** All `.mqh` files  
**Category:** MEDIUM — Code Style  
**Description:** Indentation alternates between tabs and spaces throughout the codebase. Some blocks are indented at column 0, others at 4 spaces, others at 1 tab. This suggests code was auto-generated or merged from different sources.

---

### M7. `CalculationCache.mqh` Using `static` Globals Instead of Struct — `CalculationCache.mqh`

**File:** `CalculationCache.mqh`  
**Category:** MEDIUM — Design  
**Description:** Six separate cache structs (`STHCacheEntry`, `SFactorCacheEntry`, etc.) and their globals are defined separately. A single unified `CacheManager` struct containing all caches would improve encapsulation and make invalidation clearer.

---

### M8. Dead Code: `if(true)` Block — `LabelFunctions.mqh`

**File:** `LabelFunctions.mqh` line ~197  
**Category:** MEDIUM — Dead Code  

```mql5
// BASE PLAYER: Always draw levels — all steps are part of the subdivision grid
if (true) {
```

**Suggested fix:** Remove the `if(true)` wrapper — it serves no purpose and adds an indentation level.

---

### M9. Commented-Out Debug Code Patterns — Multiple files

**File:** Various  
**Category:** MEDIUM — Dead Code  
**Description:** Multiple files contain `#ifdef ENABLE_DEBUG_LOGS` blocks that are conditionally compiled. While this is a valid pattern, some blocks are substantial (~20 lines) and add visual noise. Consider moving debug output to a `DebugDump()` function.

---

### M10. `EvictLeastRecentlyUsedSymbolState` Missing Bounds Check — `BasePriceManager.mqh`

**File:** `BasePriceManager.mqh` lines ~60–80  
**Category:** MEDIUM — Array Bounds  
**Description:** The function iterates `g_symbolStates[0..g_symbolStateCount-1]` but doesn't verify `ArraySize(g_symbolStates) >= g_symbolStateCount`. Although `GetSymbolStateIndex` synchronizes these, a corrupted state could lead to OOB.

---

### M11. Font Validation Array Hardcoded — `ObjectFunctions.mqh`

**File:** `ObjectFunctions.mqh` lines ~175–185  
**Category:** MEDIUM — Magic Values  

```mql5
static string validFonts[9] = {"Arial", "Arial Black", "Courier New", "Tahoma", "Verdana",
                            "Times New Roman", "Calibri", "Segoe UI", "Consolas"};
```

**Suggested fix:** Move to `ConstantsAndEnums.mqh` as a global constant array.

---

### M12. `BuildPatternNamesFromRegistry` Modifies Array During Iteration — `TH3Tool.mqh`

**File:** `TH3Tool.mqh` lines ~91–105  
**Category:** MEDIUM — Fragile Logic  

```mql5
for(int i = 0; i < g_th3PatternRegistryCount; i++) {
    if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) {
        UnregisterTH3Pattern(baseName);
        i--; // array compacted, stay on same index
        continue;
    }
```

**Description:** `UnregisterTH3Pattern` shifts array elements and decrements `g_th3PatternRegistryCount`. The `i--` trick works but is fragile and confusing. If `UnregisterTH3Pattern` is ever changed to not compact the array, this breaks silently.

**Suggested fix:** Iterate backwards, or collect indices to remove and process in a second pass.

---

### M13. `UpdateHistoricalValues` Uses Uncapped Array Size — `HistoricalDataFunctions.mqh`

**File:** `HistoricalDataFunctions.mqh` lines ~4–10  
**Category:** MEDIUM — Performance  

```mql5
int totalBars = inpHistoricalPeriods == 0 ?
               iBars(_Symbol, inpHistoricalTimeframe) :
               inpHistoricalPeriods;
```

**Description:** When `inpHistoricalPeriods == 0`, this copies ALL available bars, which could be 100,000+ bars. The subsequent `CopyHigh`/`CopyLow` + `ArrayMaximum`/`ArrayMinimum` on 100K elements is expensive.

**Suggested fix:** Cap with a reasonable maximum:
```mql5
totalBars = MathMin(totalBars, 50000);
```

---

### M14. Inconsistent Error Return Values — `ObjectFunctions.mqh` vs `LabelFunctions.mqh`

**File:** Multiple  
**Category:** MEDIUM — Missing Error Handling  
**Description:** `CreateTHLineObject` returns `false` on failure, but some callers don't check the return value. `DrawMainLevels` checks it; `DrawTHLevels` inline calls don't propagate failures upward.

---

### M15. `GetCachedPeriod()` Not Defined in Visible Code — Referenced by `ObjectFunctions.mqh`

**File:** `ObjectFunctions.mqh` line ~30  
**Category:** MEDIUM — Missing Documentation  
**Description:** `GetCachedPeriod()` is called for period seconds caching but its definition is in `PerformanceOptimizations.mqh` (not audited in detail). Ensure it returns a valid `ENUM_TIMEFRAMES` cast-safe int, not a raw period that might be 0 or negative.

---

### M16. `FrequencyOptimizer.mqh` Has 1179 Lines — Single Responsibility

**File:** `FrequencyOptimizer.mqh`  
**Category:** MEDIUM — Long File  
**Description:** This file contains 5 independent scoring functions (`ScoreMultiStepResonance`, `ScoreTimeAlignment`, `ScorePatternProjection`, `ScoreHarmonicPhase`, `ScoreSquareRootHarmony`) plus the main optimizer. Each scoring function is 100–200 lines with complex math. Consider splitting into `FrequencyScoring.mqh` and `FrequencyOptimizer.mqh`.

---

## Summary of Well-Implemented Patterns

The codebase also demonstrates several strong practices worth noting:

1. **`SafeDivide()` utility** — Used consistently in `THCalculations.mqh` for protected division
2. **Viewport culling** — `DrawTHLevels` skips off-screen objects, saving thousands of API calls
3. **Object cache with hash table** — O(1) lookup instead of chart-wide `ObjectFind` scans
4. **Property change detection** — Only updates changed properties, avoiding redundant `ObjectSet` calls
5. **Safety counters** — `MAX_ITERATIONS_ABOVE = 1000` prevents infinite loops even with bad step sizes
6. **Input validation** — Comprehensive `ValidateInputs()` covers all user-configurable parameters
7. **LRU eviction** — Both `BasePriceManager` and `ObjectCache` implement proper eviction strategies
8. **Frame-time caching** — `CacheRefreshFrameTime()` eliminates thousands of `TimeCurrent()` syscalls per tick
9. **Visibility batching** — Per-frame visibility state tracking skips redundant `ObjectSetInteger` calls
10. **Throttled chart redraw** — Prevents excessive `ChartRedraw()` calls during rapid updates
