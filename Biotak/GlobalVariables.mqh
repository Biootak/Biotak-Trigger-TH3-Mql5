#ifndef GLOBAL_VARIABLES_MQH
#define GLOBAL_VARIABLES_MQH

// Core State
static double g_highestHigh = EMPTY_VALUE;
static double g_lowestLow = EMPTY_VALUE;
static double g_currentPrice = 0.0;
static bool g_isHidden = false;
static datetime g_lastCalculation = 0;
static datetime g_lastHistoricalUpdate = 0;
static bool g_initialized = false;
static bool g_calculatedOnce = false;
static double g_dailyClosePriceForTH = EMPTY_VALUE;
bool g_redrawTHLevelsNeeded = true;
bool g_forceClearOnNextDraw = false;
int g_currentLabelYOffset = 0;  // Cumulative Y offset for stacking top label sections (ATR)
int g_currentLabelYOffsetBottom = 0;  // Cumulative Y offset for stacking bottom label sections (TH)
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
static int g_stepModeOverride = -1;        // -1 = use input, 0-5 = override
static double g_factorValueOverride = 0;   // 0 = use input, >0 = override
static int g_factorColorOverride = -1;     // -1 = use input
static double g_th3FreqOverride = 0;       // 0 = use input, >0 = override

// Alert Tracking
static datetime g_lastAlertTime = 0;
static string g_lastAlertLevel = "";

// Timeframe Lock
static bool g_timeframeLocked = false;
static int g_lockedPeriod = 0;
static string g_lockStatusLabelName = "Biotak_LockStatus_Label";
static string g_stepModeLabelName = "Biotak_StepMode_Label";
static string g_factorLabelName = "Biotak_Factor_Label";
static string g_th3FreqLabelName = "Biotak_TH3Freq_Label";

// ChartRedraw Throttling
static datetime g_lastChartRedrawTime = 0;
#define CHART_REDRAW_THROTTLE_MS 100
static uint g_lastDragRedrawTime = 0;
#define DRAG_REDRAW_THROTTLE_MS 50

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

// TH Storage
struct TimeframeTH {
        string timeframeName;
    double thValue;
};
TimeframeTH g_storedTHs[];

// Base Price History (in-memory, not persisted)
string g_todayBasePriceHistory[];
int    g_todayHistoryDay  = -1;
int    g_todayHistoryYear = -1;

// Label Positioning
struct LabelPosition {
        string name;
    int xPos;
    int yPos;
};
LabelPosition g_labelPositions[];

// Hidden State Cache
bool g_isHiddenCached = false;
uint g_isHiddenCacheTime = 0;
    void RefreshIsHiddenCache() {
        string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    double val = GlobalVariableGet(gvar_name);
    if(GetLastError() == ERR_GLOBALVARIABLE_NOT_FOUND)
        g_isHiddenCached = false;
    else
        g_isHiddenCached = (bool)val;
    g_isHiddenCacheTime = GetTickCount();
}
    bool IsIndicatorHidden() {
        uint now = GetTickCount();
    if(now - g_isHiddenCacheTime > HIDDEN_CACHE_TTL_MS)
        RefreshIsHiddenCache();
    return g_isHiddenCached;
}
    string SanitizeSymbolName(const string symbol) {
        string safe = symbol;
    StringReplace(safe, "_", "");  StringReplace(safe, "|", "");
    StringReplace(safe, ":", "");  StringReplace(safe, "/", "");
    StringReplace(safe, "\\", ""); StringReplace(safe, " ", "");
    StringReplace(safe, ".", "");  StringReplace(safe, "-", "");
    StringReplace(safe, "*", "");  StringReplace(safe, "?", "");
    StringReplace(safe, "<", "");  StringReplace(safe, ">", "");
    StringReplace(safe, "\"", ""); StringReplace(safe, "'", "");
    if(StringLen(safe) == 0) safe = "UNKNOWN";
    if(StringLen(safe) > 50) safe = StringSubstr(safe, 0, 50);
    return safe;
}
    void CleanupAllGlobalVariables() {
        string chartIdStr = GetCachedChartIdStr();
    string symbolName = SanitizeSymbolName(GetCachedSymbol());
    string gvars[];
    ArrayResize(gvars, 11);
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
    for(int i = 0; i < ArraySize(gvars); i++) {
        if(GlobalVariableCheck(gvars[i])) GlobalVariableDel(gvars[i]);
    }
}
    #endif
    // GLOBAL_VARIABLES_MQH