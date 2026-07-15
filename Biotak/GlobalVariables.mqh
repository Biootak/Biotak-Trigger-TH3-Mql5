  #ifndef GLOBAL_VARIABLES_MQH
#define GLOBAL_VARIABLES_MQH

// Core State
static double g_highestHigh = EMPTY_VALUE;
static double g_lowestLow = EMPTY_VALUE;
static double g_currentPrice = 0.0;
static datetime g_lastCalculation = 0;
static datetime g_lastHistoricalUpdate = 0;
static bool g_initialized = false;

// PERF (2026): Chart-change fast path. OnChartEvent(CHART_CHANGE) compares
// the current symbol/timeframe against these caches. If both match, we
// early-exit without invoking any heavy path. If they differ, we set
// g_pendingChartChange=true and let the next OnCalculate pick it up —
// no need to trigger OnDeinit/OnInit for a pure chart-property change.
static string g_lastChartSymbol = "";
static ENUM_TIMEFRAMES g_lastChartPeriod = PERIOD_CURRENT;
// FIX (LBL-1, 2026): chart pixel dimensions cached alongside symbol/period
// so CHARTEVENT_CHART_CHANGE can distinguish scroll/zoom (no-op) from a
// real resize (labels must relayout). Pixel values default to 0 to force
// the first post-init seed-write to fire.
static long g_lastChartWidthPx  = 0;
static long g_lastChartHeightPx = 0;
static bool g_pendingChartChange = false;
// PERF (2026): Track prev_calculated state so we can distinguish
// "new tick on existing bar" (no-op), "new bar" (incremental work), and
// "history reload" (full recalc). The OnCalculate hot path skips almost
// all work in the new-tick-on-existing-bar case.
static int g_lastRatesTotal = 0;
static int g_lastPrevCalculated = 0;
static bool g_wasLastTickNoOp = true;
static bool g_calculatedOnce = false;
static bool g_labelsRelayoutNeeded = false;
static double g_dailyClosePriceForTH = EMPTY_VALUE;
bool g_redrawTHLevelsNeeded = true;
bool g_forceClearOnNextDraw = false;
// g_viewportOnlyRedraw removed   scroll no longer triggers level redraw
int g_currentLabelYOffset = 0;       // Cumulative Y offset for stacking top label sections (ATR)
int g_currentLabelYOffsetBottom = 0;  // Cumulative Y offset for stacking bottom label sections (TH)
int g_modeLabelYOffset = 0;           // Final Y offset after all labels rendered
static bool g_redrawNeeded = true;

// Performance Tracking
static int g_objectCountLast = 0;
static datetime g_lastObjectCleanup = 0;

// Custom Price Selection
static bool g_waitingForCustomPriceClick = false;
static string g_customPriceHorizontalLineName = "CustomPriceHorizontalLine";
static bool g_customPriceLineCreated = false;
static double g_customTHStartPrice = 0.0;
static ENUM_TH_START_POINT_TYPE g_thStartPointType = TH_START_POINT_MIDPOINT;
static uint g_lastClickTickCount = 0;
static bool g_customPriceLineDragging = false;
static double g_lastCustomPriceLinePos = 0.0;
static bool g_customPriceKeyboardOverride = false;

// Toggle States (hotkey-controlled)
static bool g_triggerLevelsEnabled = true;
static bool g_linesVisible = true;
static bool g_atrLabelsVisible = true;
static bool g_thLabelsVisible = true;
static int  g_thLabelsMode = 0; // 0=OFF, 1=FRACTAL, 2=STANDARD, 3=BOTH
static int g_stepModeOverride = -1;        // -1 = use input, 0-5 = override
static double g_factorValueOverride = 0;   // 0 = use input, >0 = override
static int g_factorColorOverride = -1;     // -1 = use input
#ifndef BUILD_LITE
static double g_th3FreqOverride = 0;       // 0 = use input, >0 = override
static int    g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX; // Binary subdivision index
#endif

// Alert Tracking
static datetime g_lastAlertTime = 0;
static string g_lastAlertLevel = "";

// PERF (2026): In-memory trigger level cache for CheckAlerts.
// Populated by DrawTHLevels during each redraw so CheckAlerts can iterate
// over a tight array instead of doing ~512 synchronous ObjectFind +
// ObjectGetDouble chart-API calls per redraw. The trigger lines are
// already computed in DrawTHLevels - this just records the resulting
// (price, step) pairs once instead of re-reading them through the chart
// engine from CheckAlerts.
static double g_triggerUpPrices[];
static int    g_triggerUpSteps[];
static int    g_triggerUpCount = 0;
static double g_triggerDownPrices[];
static int    g_triggerDownSteps[];
static int    g_triggerDownCount = 0;
static double g_midpointLevelCached = 0.0;
static bool   g_midpointLevelValid = false;
static int    g_triggerLevelCapacity = 0;

void ResetTriggerLevelCache()
{
   g_triggerUpCount = 0;
   g_triggerDownCount = 0;
   g_midpointLevelValid = false;
}

void EnsureTriggerLevelCapacity(const int need)
{
   if(need <= g_triggerLevelCapacity) return;
   int newCap = MathMax(need, g_triggerLevelCapacity > 0 ? g_triggerLevelCapacity * 2 : 64);
   ArrayResize(g_triggerUpPrices,   newCap);
   ArrayResize(g_triggerUpSteps,    newCap);
   ArrayResize(g_triggerDownPrices, newCap);
   ArrayResize(g_triggerDownSteps,  newCap);
   g_triggerLevelCapacity = newCap;
}

void RecordTriggerLevelUp(const int step, const double price)
{
   EnsureTriggerLevelCapacity(g_triggerUpCount + 1);
   g_triggerUpPrices[g_triggerUpCount] = price;
   g_triggerUpSteps[g_triggerUpCount]  = step;
   g_triggerUpCount++;
}

void RecordTriggerLevelDown(const int step, const double price)
{
   EnsureTriggerLevelCapacity(g_triggerDownCount + 1);
   g_triggerDownPrices[g_triggerDownCount] = price;
   g_triggerDownSteps[g_triggerDownCount]  = step;
   g_triggerDownCount++;
}

void RecordMidpointLevel(const double price)
{
   g_midpointLevelCached = price;
   g_midpointLevelValid  = (price > 0);
}

int GetTriggerUpCount()   { return g_triggerUpCount;   }
int GetTriggerDownCount() { return g_triggerDownCount; }
bool HasMidpointLevel()   { return g_midpointLevelValid; }
double GetMidpointLevel() { return g_midpointLevelCached; }

double GetTriggerUpPrice(const int idx)
{
   if(idx < 0 || idx >= g_triggerUpCount) return 0.0;
   return g_triggerUpPrices[idx];
}

double GetTriggerDownPrice(const int idx)
{
   if(idx < 0 || idx >= g_triggerDownCount) return 0.0;
   return g_triggerDownPrices[idx];
}

// Timeframe Lock
static bool g_timeframeLocked = false;
static int g_lockedPeriod = 0;
static string g_lockStatusLabelName = "Biotak_LockStatus_Label";
static string g_stepModeLabelName = "Biotak_StepMode_Label";
static string g_factorLabelName = "Biotak_Factor_Label";
#ifndef BUILD_LITE
static string g_th3FreqLabelName = "Biotak_TH3Freq_Label";
#endif

// Independent label expiry timestamps (tick count)
static uint g_stepModeLabelCreateTime = 0;
static uint g_factorLabelCreateTime = 0;
#ifndef BUILD_LITE
static uint g_th3FreqLabelCreateTime = 0;
#endif
static uint g_lockStatusLabelCreateTime = 0;
static uint g_resetCommentCreateTime = 0;  // For "[ RESET ]" comment auto-clear

// ChartRedraw Throttling
static uint g_lastChartRedrawTime = 0;
#define CHART_REDRAW_THROTTLE_MS 100
static uint g_lastDragRedrawTime = 0;
#define DRAG_REDRAW_THROTTLE_MS 50

// PERF (2026, TF switch fast path): when the chart timeframe changes, the
// heavy RedrawAllObjects() pass is deferred to a timer so the OnCalculate
// tick that observes the new Period() can return immediately. Without this,
// the user saw 500-800 ms freezes on every TF switch because the rename
// (in OnChartEvent or RenamePrefixedObjects) AND the 290-zone recreate
// PERF (2026): The deferred TF-redraw buffer (g_deferredTFRedrawPending /
// g_deferredTFRedrawDueMs / DEFERRED_TF_REDRAW_DELAY_MS) was removed.
// Measured on M1 with the 158-line trigger set: the artificial 80ms delay
// added a full tick of latency before the user saw levels appear on a
// timeframe switch. RedrawAllObjects now runs synchronously on the TF-
// change tick because all of its work is in-place property writes on
// existing chart objects — no settle time required.
// (kept as a no-op define so any third-party include that still references
//  the symbol compiles cleanly; safe to delete in a later pass.)
#define DEFERRED_TF_REDRAW_DELAY_MS 0

// Suppression flag: prevents CHARTEVENT_OBJECT_DELETE cascade during programmatic deletions
static bool g_suppressDeleteEvents = false;
static uint g_suppressDeleteEventsUntilMs = 0;

#ifndef BUILD_LITE
// AB=CD Pattern State
static bool g_abcdDrawing = false;
static int g_abcdPointCount = 0;
static datetime g_abcdTimeX = 0;
static double g_abcdPriceX = 0.0;
static datetime g_abcdTimeA = 0;
static double g_abcdPriceA = 0.0;
static datetime g_abcdTimeB = 0;
static double g_abcdPriceB = 0.0;
static datetime g_abcdTimeC = 0;
static double g_abcdPriceC = 0.0;
static uint g_abcdLastClickTime = 0;
static string g_activeABCDPattern = "";

// Frequency Optimizer Result (last auto-find result for info label)
FrequencyResult g_lastFreqResult;

// Frequency History Ring Buffer   last FREQ_HISTORY_SIZE patterns
FrequencyHistoryEntry g_freqHistory[FREQ_HISTORY_SIZE];
int g_freqHistoryCount = 0;   // Total entries added (for < FREQ_HISTORY_SIZE check)
int g_freqHistoryHead  = 0;   // Next write position (wraps around)
#endif

// TH Storage
struct TimeframeTH {
    string timeframeName;
    double thValue;
};
TimeframeTH g_storedTHs[];

// Label Positioning
struct LabelPosition {
    string name;
    int xPos;
    int yPos;
};
LabelPosition g_labelPositions[];

//+------------------------------------------------------------------+
//| Hidden State Cache (TTL-based, matching MT5)                     |
//+------------------------------------------------------------------+
bool g_isHiddenCached = false;
uint g_isHiddenCacheTime = 0;

void RefreshIsHiddenCache() {
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    if(!GlobalVariableCheck(gvar_name))
        g_isHiddenCached = false;
    else
        g_isHiddenCached = (bool)GlobalVariableGet(gvar_name);
    g_isHiddenCacheTime = GetTickCount();
}

bool IsIndicatorHidden() {
    uint now = GetTickCount();
    if(now - g_isHiddenCacheTime > HIDDEN_CACHE_TTL_MS)
        RefreshIsHiddenCache();
    return g_isHiddenCached;
}

//+------------------------------------------------------------------+
//| Sanitize Symbol Name (cached, matching MT5)                      |
//+------------------------------------------------------------------+
string SanitizeSymbolName(const string symbol) {
    // PERF: Cache result since symbol never changes during indicator lifetime
    static string s_cachedInput = "";
    static string s_cachedResult = "";
    if(symbol == s_cachedInput && s_cachedResult != "") return s_cachedResult;
    s_cachedInput = symbol;

    // FIX: single-pass scan over the unicode codepoints. The previous loop of
    // StringReplace allocated a fresh string on every pass (O(n*m)). Output
    // is byte-identical for the same unsafe-char set.
    int len = StringLen(symbol);
    ushort buf[];
    ArrayResize(buf, len + 1);
    int outIdx = 0;
    for(int i = 0; i < len; i++) {
        ushort c = StringGetCharacter(symbol, i);
        bool unsafe = false;
        switch(c) {
            case '_':  case '|':  case ':':  case '/':  case '\\':
            case ' ':  case '.':  case '*':  case '?':  case '<':
            case '>':  case '"':  case '\'': case '-':
                unsafe = true; break;
        }
        if(!unsafe) buf[outIdx++] = c;
    }

    string safe;
    if(outIdx == 0) {
        safe = "UNKNOWN";
    } else {
        safe = ShortArrayToString(buf, 0, outIdx);
    }
    if(StringLen(safe) > 50) safe = StringSubstr(safe, 0, 50);
    s_cachedResult = safe;
    return safe;
}

//+------------------------------------------------------------------+
//| Cleanup symbol-scoped GlobalVariables for a given symbol         |
//| Called when the chart's symbol changes so stale price state      |
//| from the previous symbol does not leak into the new symbol.      |
//+------------------------------------------------------------------+
void CleanupSymbolScopedGlobalVariables(const string symbol) {
    if(StringLen(symbol) == 0) return;
    string symbolName = SanitizeSymbolName(symbol);
    GlobalVariableDel("Biotak_CustomPrice_" + symbolName);
    GlobalVariableDel("Biotak_CustomPriceOverride_" + symbolName);
}

//+------------------------------------------------------------------+
//| Cleanup All GlobalVariables (array-based, matching MT5)          |
//+------------------------------------------------------------------+
void CleanupAllGlobalVariables() {
    string chartIdStr = GetCachedChartIdStr();
    string symbolName = SanitizeSymbolName(GetCachedSymbol());
    string gvars[];
    ArrayResize(gvars, 13);
    gvars[0]  = "Biotak_isHidden_" + chartIdStr;
    gvars[1]  = "Biotak_CustomPrice_" + symbolName;
    gvars[2]  = "Biotak_LockTF_" + chartIdStr;
    gvars[3]  = "Biotak_LockTFPeriod_" + chartIdStr;
    gvars[4]  = "Biotak_TriggerLevels_" + chartIdStr;
    gvars[5]  = "Biotak_CustomPriceOverride_" + symbolName;
    gvars[6]  = "Biotak_StepMode_" + chartIdStr;
    gvars[7]  = "Biotak_Factor_" + chartIdStr;
    gvars[8]  = "Biotak_TH3Freq_" + chartIdStr;
    gvars[9]  = "Biotak_TH3FreqIdx_" + chartIdStr;
    gvars[10] = "Biotak_LinesVisible_" + chartIdStr;
    gvars[11] = "Biotak_ATRLabels_" + chartIdStr;
    gvars[12] = "Biotak_THLabels_" + chartIdStr;
    for(int i = 0; i < ArraySize(gvars); i++) {
        if(GlobalVariableCheck(gvars[i])) GlobalVariableDel(gvars[i]);
    }
}

//+------------------------------------------------------------------+
//| Restore Bool GlobalVar (epsilon-based, matching MT5)             |
//+------------------------------------------------------------------+
bool RestoreBoolGlobalVar(const string gvarName, bool defaultVal) {
    if(GlobalVariableCheck(gvarName)) {
        double gvarValue = GlobalVariableGet(gvarName);
        bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
        bool isOne  = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
        if(isZero || isOne) {
            return isOne;
        } else {
            DEBUG_PRINTF2("OnInit: Corrupted state for ", gvarName, ", resetting");
            GlobalVariableSet(gvarName, defaultVal ? 1.0 : 0.0);
            return defaultVal;
        }
    }
    return defaultVal;
}

#endif // GLOBAL_VARIABLES_MQH
