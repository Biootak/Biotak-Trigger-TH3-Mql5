# EventHandlers.mqh — MT4→MT5 Rewrite Plan

> **Reference (MT5):** `Biotak-Trigger-TH3-Mql5/Biotak/EventHandlers.mqh` — 2 213 lines  
> **Target (MT4):** `Biotak-Trigger-TH3/Biotak/EventHandlers.mqh` — 3 100 lines  
> Goal: rewrite the MT4 file so its behaviour matches the MT5 version.

---

## 1  Function-by-Function Comparison

### 1.1  `OnInitHandler()`

| Aspect | MT5 (lines 3–297) | MT4 (lines 7–421) |
|---|---|---|
| **Bool-state restore** | Calls `RestoreBoolGlobalVar()` (from GlobalVariables.mqh) for each bool GV — one-liner per variable | Inline epsilon-based restore (~6 lines per variable) duplicated many times |
| **TF-switch debounce** | Detects rapid TF switches via `g_lastInitTime`; skips heavy work when the user is still scrolling through time-frames | Not implemented |
| **Deferred heavy init** | Deferred: `UpdateHistoricalValues()`, heavy drawing, etc. only execute after ATR warmup (`g_atrWarmedUp`) and first OnCalculate | Always runs `UpdateHistoricalValues()` + drawing unconditionally during OnInit |
| **ATR warmup gating** | Uses `g_atrWarmedUp` flag; first Calculate verifies readiness before proceeding | Uses `WarmupATRMultiTFCache()` unconditionally in OnInit |
| **Calc-basis restore** | *Removed* — no `g_calculationBasisOverride` concept | Restores `g_calculationBasisOverride` (ATR vs TH basis) from GV |
| **Net result** | ~295 lines, DRY, resilient to rapid-init spam | ~415 lines, lots of duplicated inline code |

**To port:** replace every inline GV-bool-restore block with `RestoreBoolGlobalVar()`; add TF-switch debounce guard at the top; wrap heavy work in a deferred-init block gated on ATR warmup; remove calc-basis restore (ATR_BASIS removed from MT5).

---

### 1.2  `OnDeinitHandler()`

| Aspect | MT5 (lines 440–524) | MT4 (lines 529–679) |
|---|---|---|
| **ATR handle cleanup** | Calls `ReleaseATRHandle()` | Not present (MT4 has no iATR handle model) |
| **Object deletion style** | Calls `ObjectDelete()` directly — no preceding `ObjectFind()` check | Always checks `ObjectFind() >= 0` before deleting |
| **Prefix cleanup** | Deletes `g_th3PatternPrefix`, `g_th3TempPrefix` objects via a loop | Explicit per-object cleanup for `g_basisModeLabelName` etc. |
| **Zone cleanup** | Uses `GetAllModeSuffixes()` registry | Inline explicit mode list |

**To port:** remove `ObjectFind` guards (MT5 `ObjectDelete` is idempotent); add `ReleaseATRHandle()` call; switch to `GetAllModeSuffixes()` registry for cleanup loop; remove `g_basisModeLabelName` cleanup (basis mode removed).

---

### 1.3  `CreateCustomPriceLine()`

| Aspect | MT5 (lines 298–330) | MT4 (lines 424–444) |
|---|---|---|
| **Return type** | `bool` | `void` |
| **Optional params** | `selected = false`, `tooltipSuffix = ""` with defaults | No optional params |
| **Existence check** | Creates only if the object doesn't already exist (returns early) | Always deletes then re-creates |

**To port:** change return type to `bool`; add optional params; guard creation with an existence check instead of delete-recreate.

---

### 1.4  `HideAllTHObjects()`

| Aspect | MT5 (lines 337–371) | MT4 (lines 453–500) |
|---|---|---|
| **First-char rejection** | Uses `StringGetCharacter(name, 0)` to skip objects whose first char doesn't match any known prefix — O(1) rejection for the vast majority of chart objects | Not implemented; checks `ObjectFind` per object |
| **Label names** | References `g_th3FreqLabelName` | References `g_basisModeLabelName`, `g_frequencyLabelName` |
| **Visibility set** | Direct `ObjectSetInteger(..., OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)` | Uses `ObjectSet` with visibility property |

**To port:** add first-char rejection; replace `g_basisModeLabelName` with `g_th3FreqLabelName`; update label name set to match MT5.

---

### 1.5  `ShowAllTHObjects` *(not a standalone function)*

Neither codebase has a separate `ShowAllTHObjects()` function.  
The "show" path is handled **inside `OnChartEventHandler()`** in the F-key toggle handler:

| MT5 | MT4 |
|---|---|
| Uses **fast visibility toggle** — sets `OBJPROP_TIMEFRAMES` back to `OBJ_ALL_PERIODS` on existing objects | Uses **delete + recreate** strategy — calls `RedrawAllObjects()` from scratch |

**To port:** replace the F-key "show" branch with a fast visibility-toggle loop matching MT5.

---

### 1.6  `ClearAllLevels()`

| Aspect | MT5 (lines 530–630) | MT4 (lines 684–840) |
|---|---|---|
| **Suffix source** | `GetAllZoneSuffixes()` + `GetAllLevelSuffixes()` (registry-based) | Hand-crafted arrays of 24 level + 5 zone prefixes |
| **`clearZones` param** | Has optional `bool clearZones = true` param | No param — always clears everything |
| **Retry logic** | None (trusts single pass) | Has retry loop with fallback manual cleanup |
| **Cache invalidation** | Calls cache-invalidation helpers after clearing | Not present |

**To port:** switch to `GetAllZoneSuffixes()` / `GetAllLevelSuffixes()` registries; add `clearZones` parameter; remove retry logic; add cache-invalidation calls.

---

### 1.7  `GetAdaptiveLevelCounts()`

| Aspect | MT5 (lines 631–638) | MT4 (lines 842–876) |
|---|---|---|
| **Complexity** | **Trivial** — returns `inpMaxLevels` for both above/below | **Complex** — trigger multiplier logic, separate `inpCustomPriceMaxLevels`, separate `inpMaxTHLevelsAbove`/`Below` for historical |
| **Parameters** | Single `inpMaxLevels` determines count | Multiple inputs depending on mode |

**To port:** replace the entire function body with a simple assignment from `inpMaxLevels`. Remove references to `inpCustomPriceMaxLevels`, `inpMaxTHLevelsAbove`, `inpMaxTHLevelsBelow`.

---

### 1.8  `CalculateCommonStepData()`

| Aspect | MT5 (lines 645–729) | MT4 (lines 903–1004) |
|---|---|---|
| **Basis support** | TH basis ONLY — no ATR basis | Supports both `CALC_BASIS_TH` and `CALC_BASIS_ATR` |
| **`isATRBasis` field** | Struct has NO `isATRBasis` field | `StepCalculationData.isATRBasis` field exists |
| **Scaling** | Uses `GetCurrentScalingFactor()`, `GetAdaptedStepSize()` | Uses inline calculations without adaptive scaling helpers |
| **Cache key** | Caches by mode + scaling factor | Caches by mode + basis |

**To port:** remove all `CALC_BASIS_ATR` branches; remove `isATRBasis` from `StepCalculationData`; switch to `GetCurrentScalingFactor()` / `GetAdaptedStepSize()` calls; update cache key to include scaling factor.

---

### 1.9  `DrawLevelsBasedOnMode()`

| Aspect | MT5 (lines 868–1111) | MT4 (lines 1007–1366) |
|---|---|---|
| **Drawing strategy** | Uses `ExecutePipeline()` for ALL modes via the unified pipeline system | Uses legacy draw functions: `DrawSSLSLevels()`, `DrawMLevels()`, `DrawFibBase()`, `DrawFibLevels()`, etc. |
| **Mode-change tracking** | `g_lastDrawnMode` + smart skip when mode unchanged | Not present |
| **`ClearAllLevels()` call** | NOT called here — caller (`RedrawAllObjects`) handles it | Called at the TOP of this function |
| **TH_STEP ATR/TH split** | No split — TH basis only | Has `if(isATRBasis)` branch under TH_STEP mode |
| **Factor label update** | Handled by pipeline hooks | Calls `UpdateFactorLabel()` inline |

**To port:** replace all legacy `Draw*Levels()` calls with `ExecutePipeline()` invocations; remove `ClearAllLevels()` call from here; remove ATR basis branching; add mode-change tracking; remove inline `UpdateFactorLabel()` (let pipeline handle it).

---

### 1.10  `RedrawAllObjects()`

| Aspect | MT5 (lines 1113–1318) | MT4 (lines 1368–1718) |
|---|---|---|
| **Burst coalescing** | ms-level burst guard (`g_lastRedrawMs`) — prevents redundant redraws within a threshold | Not present — every call redraws |
| **Tick-price caching** | `CacheTickPrices()` + `GetCachedBid()` at top — avoids repeated `SymbolInfoDouble()` calls | Uses `Bid` global directly |
| **Hidden detection** | `IsIndicatorHidden()` with `RefreshIsHiddenCache()` | Reads GlobalVariable inline every time |
| **Lazy base-price init** | Base price only computed when needed | Always computed |
| **30-min boundary gating** | Skips redraw if not on a 30-min boundary for timer-driven calls | Not present |
| **Topology signature** | `g_lastTopologySignature` — skips `ClearAllLevels()` when mode+inputs haven't changed | Not present |
| **Labels relayout** | `g_labelsRelayoutNeeded` flag + `RedrawLabelsOnly()` sub-path | Not present |
| **Custom price lines** | Single consolidated creation block | Inline creation duplicated 6+ times |

**To port (high-complexity):** add ms-burst guard; add `CacheTickPrices()` / `GetCachedBid()` calls; replace inline GV hidden-check with `IsIndicatorHidden()` + `RefreshIsHiddenCache()`; add topology signature guard; add labels relayout system; consolidate custom-price-line creation into single block; add 30-min boundary gating.

---

### 1.11  `OnCalculateHandler()`

| Aspect | MT5 (lines 1320–1447) | MT4 (lines 1720–1808) |
|---|---|---|
| **Tick throttling** | 50 ms minimum between calculations | None — runs on every tick |
| **Significance check** | Only redraws when price change exceeds threshold | Not present |
| **Cache invalidation** | Uses `ECacheInvalidationFlags` enum + `ApplyCacheInvalidation()` | Not present |
| **Chart redraw** | `ThrottledChartRedraw()` — rate-limited | `ChartRedraw()` on every pass |
| **Tick-price caching** | `CacheTickPrices()` at entry | Not present |

**To port:** add 50 ms tick throttle; add significance check; add cache-invalidation flags system; replace `ChartRedraw()` with `ThrottledChartRedraw()`.

---

### 1.12  `OnChartEventHandler()`

| Aspect | MT5 (lines 1576–2213) | MT4 (lines 1858–2880) |
|---|---|---|
| **Key matching** | `IsHotkeyPressed()` for ALL keys — clean and DRY | Mix of direct lparam comparisons and partial `IsHotkeyPressed()` use |
| **CHART_CHANGE handler** | Detects viewport changes (scroll/zoom) with `CHART_CHANGE_THROTTLE_MS`; triggers `g_labelsRelayoutNeeded` | Not present at all |
| **F-key visibility** | Fast visibility toggle (set `OBJPROP_TIMEFRAMES`) | Delete + recreate via `RedrawAllObjects()` |
| **Factor key (1/2)** | Calls `AdjustFactorValue()` extracted helper | Full inline logic duplicated for each key |
| **Frequency key (3/4)** | Calls `CycleTH3Frequency()` / `DecrementTH3Frequency()` | Inline logic |
| **W key (basis toggle)** | *Removed* — no basis toggle in MT5 | Toggles between ATR/TH basis |
| **F key (freq analysis)** | *Removed or relocated* | Opens frequency analysis |
| **Custom price drag** | ms-throttle (`DRAG_REDRAW_THROTTLE_MS`) + `GetCachedBid()` | No throttling; inline `Bid` usage |
| **ABCD object_click** | Streamlined handling | Similar but with more inline code |
| **Double-click** | `DOUBLE_CLICK_THRESHOLD_MS` constant for detection | Inline hard-coded threshold |

**To port (high-complexity):** replace all direct key comparisons with `IsHotkeyPressed()`; add CHART_CHANGE handler with throttle; replace F-key delete-recreate with visibility toggle; extract factor/frequency handlers to helper functions; remove W key handler; add ms-throttle for drag redraw; add double-click constant.

---

### 1.13  `RestoreBoolGlobalVar()` *(helper — currently inline in MT4)*

| Aspect | MT5 (GlobalVariables.mqh:182–210) | MT4 (EventHandlers.mqh:345 area) |
|---|---|---|
| **Location** | Standalone function in GlobalVariables.mqh | Inline code blocks inside `OnInitHandler()` |
| **Reuse** | Called ~8 times from OnInit with one-liner syntax | Same logic repeated manually each time |

**To port:** extract a `RestoreBoolGlobalVar()` function to GlobalVariables.mqh (or a shared include); replace all inline restore blocks in `OnInitHandler()`.

---

### 1.14  `OnTimerHandler` *(not a named handler function)*

Neither codebase has a function called `OnTimerHandler`. In MT5, the entry point `OnTimer()` (in `Biotak Trigger TH3.mq5:113–121`) calls:

```mql5
void OnTimer()
{
   RunIncrementalObjectCleanup();
   CheckAndClearExpiredLabels();
}
```

Both helper functions already exist in the MT4 codebase. MT4's `OnTimer()` should mirror this pattern.

---

### 1.15  Helper functions already ported to MT4 (bottom of MT4 file, lines 2881–3100)

The MT4 file already contains ported stubs/implementations for:
- `IsHotkeyPressed()`
- `DeleteAllIndicatorObjects()`
- `EmergencyCleanupIndicatorObjects()`
- `ApplyCacheInvalidation()`
- `LogRedrawDecision()`
- `RunIncrementalObjectCleanup()`
- `RedrawLabelsOnly()`
- `AdjustFactorValue()`

These exist but may not be wired up (e.g. `IsHotkeyPressed` is defined but not used for all keys in the MT4 `OnChartEventHandler`).

---

## 2  Complete MT5 Dependency List

Every function/constant called **from MT5 EventHandlers.mqh** and its status in the MT4 codebase.

### 2.1  Present in MT4 ✅

| Dependency | MT4 Location |
|---|---|
| `ObjectCreate`, `ObjectDelete`, `ObjectSetInteger`, `ObjectSetDouble`, `ObjectSetString`, `ObjectGetDouble`, `ObjectsTotal`, `ObjectName`, `ObjectType`, `ObjectFind` | MQL4 built-ins |
| `GlobalVariableCheck`, `GlobalVariableGet`, `GlobalVariableSet`, `GlobalVariableDel`, `GlobalVariableTemp` | MQL4 built-ins |
| `ChartRedraw`, `ChartSetInteger`, `ChartGetInteger`, `ChartGetDouble`, `ChartID`, `ChartPeriod`, `ChartSymbol` | MQL4 built-ins |
| `SymbolInfoDouble`, `StringGetCharacter`, `StringSubstr`, `StringFind`, `StringLen` | MQL4 built-ins |
| `EventSetMillisecondTimer`, `EventKillTimer` | MQL4 built-ins |
| `GetTickCount` | MQL4 built-in |
| `CalculateTHValue` | ✅ THCalculations.mqh |
| `UpdateHistoricalValues` | ✅ HistoricalDataFunctions.mqh |
| `DrawMainLevels`, `DrawExtendedLevels`, `DrawReverseLevels` | ✅ ExtendedDrawingFunctions.mqh |
| `DrawSSLSLevels`, `DrawMLevels`, `DrawFibBase`, `DrawFibLevels`, `DrawFibPRZone` | ✅ (Legacy draw functions) |
| `ExecutePipeline` | ✅ LevelPipeline.mqh |
| `GetAllModeSuffixes`, `GetAllZoneSuffixes`, `GetAllLevelSuffixes` | ✅ ZoneConstants.mqh / ZoneFactory.mqh |
| `UpdateFactorLabel` | ✅ LabelFunctions.mqh |
| `CreateStatusLabel`, `DeleteTemporaryModeLabels` | ✅ LabelFunctions.mqh |
| `IsIndicatorHidden`, `SetIndicatorHidden` | ✅ VisibilityManager.mqh |
| `ApplyLinesVisibility` | ✅ EventHandlers.mqh (MT4) |
| `WarmupATRMultiTFCache` | ✅ ATRCalculations.mqh |
| `GetCurrentScalingFactor`, `GetAdaptedStepSize` | ✅ AdaptiveScaling.mqh |
| `ValidateAllInputs` | ✅ InputValidator.mqh |
| `GetObjectCountForMode` | ✅ ObjectCountManager.mqh |
| `ShouldSkipDrawing` | ✅ VisibilityManager.mqh |
| `UpdatePropertyChangeState` | ✅ PropertyChangeDetector.mqh |
| `CheckAndClearExpiredLabels` | ✅ UtilityFunctions.mqh |
| `ClearAllTemporaryModeLabels` | ✅ UtilityFunctions.mqh |
| `FormatTimeframeString` | ✅ TimeframeFunctions.mqh |
| `SendTH3Alert` | ✅ AlertFunctions.mqh |
| `LogInfo`, `LogDebug`, `LogWarn`, `LogError` | ✅ Logger.mqh |
| `g_th3Prefix`, `g_th3PatternPrefix`, `g_th3TempPrefix` | ✅ ProjectConstants.mqh |
| `g_th3FreqLabelName` | ✅ GlobalVariables.mqh / ProjectConstants.mqh |
| `g_isHidden`, `g_currentMode`, `g_factorValue`, `g_selectedFrequency` | ✅ GlobalVariables.mqh |
| `g_lastRedrawMs` | ✅ GlobalVariables.mqh |
| `g_atrWarmedUp` | ✅ GlobalVariables.mqh |
| `g_labelsRelayoutNeeded` | ✅ GlobalVariables.mqh |
| `g_lastTopologySignature` | ✅ GlobalVariables.mqh |
| `MODE_TH_STEP`, `MODE_SSL_LEVELS`, `MODE_MATHEMATICAL`, `MODE_FIB_BASE`, `MODE_FIB_LEVELS`, `MODE_FIB_PRZONE` | ✅ ConstantsAndEnums.mqh |
| `IsHotkeyPressed` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `DeleteAllIndicatorObjects` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `EmergencyCleanupIndicatorObjects` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `ApplyCacheInvalidation` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `LogRedrawDecision` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `RunIncrementalObjectCleanup` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `RedrawLabelsOnly` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `AdjustFactorValue` | ✅ MT4 EventHandlers.mqh:2881+ (already ported) |
| `CycleTH3Frequency` | ✅ EventHandlers.mqh or FrequencyOptimizer.mqh |
| `DecrementTH3Frequency` | ✅ EventHandlers.mqh or FrequencyOptimizer.mqh |
| `ThrottledChartRedraw` | ✅ UtilityFunctions.mqh |

### 2.2  Missing from MT4 ❌

| Dependency | MT5 Location | Action Required |
|---|---|---|
| `RestoreBoolGlobalVar()` | GlobalVariables.mqh:182 | **Create** in MT4 GlobalVariables.mqh — simple GV read + epsilon compare + bool return |
| `CacheTickPrices()` | MQL5Compat.mqh / ObjectCache.mqh | **Create** in MT4 — caches `Bid`/`Ask` per tick to avoid repeated calls |
| `GetCachedBid()` | MQL5Compat.mqh / ObjectCache.mqh | **Create** in MT4 — returns the cached `Bid` value |
| `RefreshIsHiddenCache()` | VisibilityManager.mqh | **Create** in MT4 — refreshes the `g_isHidden` cache from GlobalVariable |
| `ReleaseATRHandle()` | ATRCalculations.mqh | **Create** as no-op or adapt — MT4 doesn't use indicator handles; may be empty |
| `CHART_CHANGE_THROTTLE_MS` | ConstantsAndEnums.mqh or EventHandlers.mqh | **Add constant** — e.g. `#define CHART_CHANGE_THROTTLE_MS 200` |
| `DOUBLE_CLICK_THRESHOLD_MS` | ConstantsAndEnums.mqh or EventHandlers.mqh | **Add constant** — e.g. `#define DOUBLE_CLICK_THRESHOLD_MS 400` |
| `DRAG_REDRAW_THROTTLE_MS` | ConstantsAndEnums.mqh or EventHandlers.mqh | **Add constant** — e.g. `#define DRAG_REDRAW_THROTTLE_MS 100` |

### 2.3  Exists in MT4 but Must Be Removed / Changed

| Item | Reason |
|---|---|
| `GetCurrentCalculationBasis()` | ATR basis removed in MT5 |
| `CALC_BASIS_ATR` enum / references | ATR basis removed in MT5 |
| `g_calculationBasisOverride` | ATR basis removed in MT5 |
| `g_basisModeLabelName` | Replaced by `g_th3FreqLabelName` concept |
| `StepCalculationData.isATRBasis` field | Struct field removed in MT5 |
| W key handler (basis toggle) | Feature removed in MT5 |
| `inpCustomPriceMaxLevels`, `inpMaxTHLevelsAbove`, `inpMaxTHLevelsBelow` inputs | Consolidated into single `inpMaxLevels` in MT5 |

---

## 3  Recommended Implementation Order

### Phase 0 — Prerequisites (no EventHandlers changes yet)

| Step | Task | Effort |
|---|---|---|
| 0.1 | Add `RestoreBoolGlobalVar()` to MT4 GlobalVariables.mqh | Small |
| 0.2 | Add `CacheTickPrices()` + `GetCachedBid()` to a utility/compat file | Small |
| 0.3 | Add `RefreshIsHiddenCache()` to VisibilityManager.mqh | Small |
| 0.4 | Add `ReleaseATRHandle()` stub to ATRCalculations.mqh | Trivial |
| 0.5 | Add the 3 throttle constants (`CHART_CHANGE_THROTTLE_MS`, `DOUBLE_CLICK_THRESHOLD_MS`, `DRAG_REDRAW_THROTTLE_MS`) to ConstantsAndEnums.mqh | Trivial |
| 0.6 | Verify `ExecutePipeline()`, `GetAllModeSuffixes()`, `GetAllZoneSuffixes()`, `GetAllLevelSuffixes()` work correctly in MT4 | Medium |

### Phase 1 — Leaf Functions (no cascading effects)

| Step | Function | Key Changes | Risk |
|---|---|---|---|
| 1.1 | `CreateCustomPriceLine()` | Return type → `bool`, add optional params, existence guard | Low |
| 1.2 | `GetAdaptiveLevelCounts()` | Simplify to single `inpMaxLevels` | Low |
| 1.3 | `CalculateCommonStepData()` | Remove ATR basis, add scaling helpers, remove `isATRBasis` field | Medium |
| 1.4 | `HideAllTHObjects()` | Add first-char rejection, update label names | Low |
| 1.5 | `ClearAllLevels()` | Switch to registry-based suffixes, add `clearZones` param, remove retry logic | Medium |

### Phase 2 — Core Drawing (depends on Phase 1)

| Step | Function | Key Changes | Risk |
|---|---|---|---|
| 2.1 | `DrawLevelsBasedOnMode()` | Replace legacy draw calls with `ExecutePipeline()`, remove `ClearAllLevels()` from here, add mode-change tracking | **High** |
| 2.2 | Wire up `RedrawLabelsOnly()` (already ported) | Ensure it's callable and tested | Low |

### Phase 3 — Central Orchestration (depends on Phase 2)

| Step | Function | Key Changes | Risk |
|---|---|---|---|
| 3.1 | `RedrawAllObjects()` | Add burst coalescing, tick caching, topology signature, labels relayout, consolidate custom price lines | **High** |
| 3.2 | `OnCalculateHandler()` | Add tick throttle, significance check, cache invalidation flags, `ThrottledChartRedraw()` | **High** |

### Phase 4 — Event Routing (depends on Phase 3)

| Step | Function | Key Changes | Risk |
|---|---|---|---|
| 4.1 | `OnChartEventHandler()` — Key handlers | Replace all key comparisons with `IsHotkeyPressed()`, wire `AdjustFactorValue()` / `CycleTH3Frequency()` / `DecrementTH3Frequency()` | Medium |
| 4.2 | `OnChartEventHandler()` — CHART_CHANGE | Add new viewport-change detection handler | Medium |
| 4.3 | `OnChartEventHandler()` — F-key show | Replace delete+recreate with fast visibility toggle | Medium |
| 4.4 | `OnChartEventHandler()` — Custom price drag | Add ms-throttle, use `GetCachedBid()` | Low |
| 4.5 | Remove W key handler, remove 'F' key handler | Feature removal | Low |

### Phase 5 — Init / Deinit (final — depends on helpers from Phase 0)

| Step | Function | Key Changes | Risk |
|---|---|---|---|
| 5.1 | `OnInitHandler()` | Replace inline bool-restores with `RestoreBoolGlobalVar()`, add TF-switch debounce, add deferred init, remove calc-basis restore | **High** |
| 5.2 | `OnDeinitHandler()` | Remove `ObjectFind` guards, add `ReleaseATRHandle()`, use `GetAllModeSuffixes()` registry, remove basis mode cleanup | Medium |

### Phase 6 — Cleanup

| Step | Task |
|---|---|
| 6.1 | Remove dead code: `GetCurrentCalculationBasis()`, ATR-basis branches, `g_calculationBasisOverride`, `g_basisModeLabelName`, `StepCalculationData.isATRBasis` |
| 6.2 | Remove unused inputs: `inpCustomPriceMaxLevels`, `inpMaxTHLevelsAbove`, `inpMaxTHLevelsBelow` (coordinate with PropertiesAndInputs.mqh) |
| 6.3 | Remove the now-redundant `ApplyLinesVisibility()` function if its logic is handled by the visibility toggle |
| 6.4 | Collapse duplicate inline custom-price-line blocks (should all now go through `CreateCustomPriceLine()`) |
| 6.5 | Final compilation + regression test on chart |

---

## 4  Summary of Line-Count Impact

| Area | MT4 Current | Expected After Port |
|---|---|---|
| `OnInitHandler` | 415 lines | ~295 lines |
| `OnDeinitHandler` | 150 lines | ~85 lines |
| `ClearAllLevels` | 157 lines | ~100 lines |
| `GetAdaptiveLevelCounts` | 35 lines | ~8 lines |
| `CalculateCommonStepData` | 102 lines | ~85 lines |
| `DrawLevelsBasedOnMode` | 360 lines | ~245 lines |
| `RedrawAllObjects` | 350 lines | ~205 lines |
| `OnCalculateHandler` | 88 lines | ~130 lines (gains throttle/cache logic) |
| `OnChartEventHandler` | 1022 lines | ~640 lines |
| **Total EventHandlers.mqh** | **~3100 lines** | **~2200 lines** |

Net reduction: **~900 lines** — primarily from deduplication of inline custom-price-line creation, extraction to helper functions, and removal of ATR-basis branches.

---

## 5  Risk Assessment

| Risk | Mitigation |
|---|---|
| `ExecutePipeline()` behaves differently under MT4's object model | Test each mode individually after Phase 2.1; keep legacy draw functions available as fallback |
| Removing ATR basis breaks user workflows | Communicate deprecation; if needed, keep as hidden/unsupported code path |
| Burst coalescing hides legitimate redraws | Use conservative thresholds initially (e.g. 50 ms); tune after testing |
| TF-switch debounce prevents init on legitimate timeframe change | Ensure the debounce only affects rapid successive inits (< 500 ms); always allow the final init to complete |
| Topology signature prevents needed redraws | Invalidate signature on any input change; log when skips occur during development |

---

*Document generated from analysis of MT5 EventHandlers.mqh (2213 lines) and MT4 EventHandlers.mqh (3100 lines).*
