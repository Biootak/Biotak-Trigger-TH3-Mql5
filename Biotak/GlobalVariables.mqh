// GOLD FIX #8: Explicit initialization for all static variables in GlobalVariables.mqh
static double g_highestHigh = EMPTY_VALUE;
static double g_lowestLow = EMPTY_VALUE;
static double g_currentPrice = 0.0;  // Close of last completed bar (matches MotiveWave's getBidClose)
static bool g_isHidden = false; // Toggles indicator visibility
static datetime g_lastCalculation = 0;
static datetime g_lastHistoricalUpdate = 0;
static bool g_initialized = false;
static bool g_calculatedOnce = false;
static double g_dailyClosePriceForTH = EMPTY_VALUE;
bool g_redrawTHLevelsNeeded = true;

// PERFORMANCE: Force ClearAllLevels on next draw (set by keyboard handlers like +/-/E/etc.)
// Needed when object names/counts change but mode stays the same
bool g_forceClearOnNextDraw = false;

// Redraw flag for flickering fix optimization
// Controls when drawing operations should occur in OnCalculate
static bool g_redrawNeeded = true; // Default: true to draw on first load

// GOLD FIX #8: Performance tracking with explicit initialization
static int g_objectCountLast = 0;
static datetime g_lastObjectCleanup = 0;
// NOTE: g_cachedMarketPrice and g_cachedMarketPriceTime are declared in ZoneConstants.mqh
static bool g_performanceMetricsInitialized = false;

// TH basePrice 30-minute update (matching MotiveWave/Java implementation EXACTLY)
// بیس پرایس هر 30 دقیقه با کلوز آخرین کندل بلاک قبلی آپدیت میشه
// Base price updates every 30 minutes using close of last completed 30-minute candle
// Updates at: 00:00, 00:30, 01:00, 01:30, 02:00, 02:30, ...
// NOTE: These variables are now managed by BasePriceManager.mqh
// Legacy variables removed


// Custom price selection variables
static bool g_waitingForCustomPriceClick = false; // Flag to indicate waiting for chart click
// No vertical line needed as per user request
static string g_customPriceHorizontalLineName = "CustomPriceHorizontalLine"; // Name for horizontal line object
static bool g_customPriceLineCreated = false; // Flag to indicate if custom price line is created
static double g_customTHStartPrice = 0.0; // Store custom TH start price
static ENUM_TH_START_POINT_TYPE g_thStartPointType = TH_START_POINT_MIDPOINT; // Store TH start point type
static uint g_lastClickTickCount = 0; // For detecting double clicks using GetTickCount()
static bool g_customPriceLineDragging = false; // Track if custom price line is being dragged
static double g_lastCustomPriceLinePos = 0.0; // Last known position of custom price line
static bool g_customPriceKeyboardOverride = false; // Flag: user pressed C key to override input parameter

// Trigger Levels toggle state (controlled by hotkey T)
static bool g_triggerLevelsEnabled = true; // Default: enabled (follows inpShowTrigger initially)

// Lines visibility toggle state (controlled by hotkey L)
static bool g_linesVisible = true; // Default: visible (follows inpShowLines initially)

// Step Mode override (controlled by hotkey E - cycles through modes)
// When -1, uses inpStepCalculationMode from settings
// When >= 0, overrides with the selected mode
// Modes: 0=TH, 1=SS/LS, 2=M, 3=TP, 4=Combo, 5=Factor
static int g_stepModeOverride = -1; // -1 = use input parameter, 0-5 = override mode

// Factor value override (controlled by hotkeys + and -)
// When <= 0, uses inpFactorValue from settings (or Auto mode)
// When > 0, overrides with the user-adjusted value
static double g_factorValueOverride = 0; // 0 = use input parameter, >0 = override value

// Factor color override (controlled by hotkey - allows runtime color change)
// When -1, uses inpFactorLevelColor from settings
// When >= 0, overrides with the selected color
static int g_factorColorOverride = -1; // -1 = use input parameter, >=0 = override color

// Calculation Basis override (controlled by hotkey B - toggles TH/ATR)
// When -1, uses inpCalculationBasis from settings
// When >= 0, overrides with the selected basis
static int g_calculationBasisOverride = -1; // -1 = use input parameter, 0=TH, 1=ATR

// Alert tracking to prevent spam
static datetime g_lastAlertTime = 0;
static string g_lastAlertLevel = "";

// Timeframe lock state (persisted via GlobalVariables)
static bool g_timeframeLocked = false;         // Whether timeframe is locked
static int g_lockedPeriod = 0;                 // ENUM_TIMEFRAMES value when locked (e.g., PERIOD_M15)
static string g_lockStatusLabelName = "Biotak_LockStatus_Label"; // Name for lock status label on chart
static string g_stepModeLabelName = "Biotak_StepMode_Label"; // Name for step mode label on chart
static string g_basisModeLabelName = "Biotak_BasisMode_Label"; // Name for calculation basis label on chart
static string g_factorLabelName = "Biotak_Factor_Label"; // Name for Factor value label on chart

// GOLD FIX: ChartRedraw throttling to prevent excessive redraws
static datetime g_lastChartRedrawTime = 0;
#define CHART_REDRAW_THROTTLE_MS 100  // Minimum 100ms between ChartRedraw calls

static uint g_lastDragRedrawTime = 0;     // Last time RedrawAllObjects was called during drag
#define DRAG_REDRAW_THROTTLE_MS 50        // Minimum 50ms between RedrawAllObjects during drag (20 fps)
static string g_frequencyLabelName = "Biotak_Frequency_Label"; // Name for TH3 frequency label on chart

// TH3 Frequency Cycling System
// سیستم چرخش فرکانس TH3
static double g_th3FrequencyOverride = 0.0; // Override for TH3 frequency (0 = use input parameter)
static int g_th3FrequencyIndex = 16; // Current frequency index (default: 28.125% at index 16)

// AB=CD Pattern State (4-point input: X, A, B, C → calculates D)
// حالت پترن AB=CD (ورودی 4 نقطه: X, A, B, C → محاسبه D)
static bool g_abcdDrawing = false;           // آیا در حال رسم AB=CD هستیم؟
static int g_abcdPointCount = 0;             // تعداد نقاط کلیک شده (0, 1, 2, 3, 4)
static datetime g_abcdTimeX = 0;             // زمان نقطه X (شروع موج اول)
static double g_abcdPriceX = 0.0;            // قیمت نقطه X
static datetime g_abcdTimeA = 0;             // زمان نقطه A
static double g_abcdPriceA = 0.0;            // قیمت نقطه A
static datetime g_abcdTimeB = 0;             // زمان نقطه B
static double g_abcdPriceB = 0.0;            // قیمت نقطه B
static datetime g_abcdTimeC = 0;             // زمان نقطه C
static double g_abcdPriceC = 0.0;            // قیمت نقطه C
static uint g_abcdLastClickTime = 0;         // آخرین زمان کلیک (برای debounce)

// NOTE: We now collect 4 points (X, A, B, C) for proper 3-wave analysis
// توجه: الان 4 نقطه جمع می‌کنیم (X, A, B, C) برای تحلیل درست 3 موج

// Active pattern tracking (for info label display)
// ردیابی پترن فعال (برای نمایش info label)
static string g_activeABCDPattern = "";      // فقط این پترن info label نشون میده

// NOTE: TH Cache is now managed by CalculationCache.mqh
// Removed duplicate g_thCache definition

struct TimeframeTH {
    string timeframeName;
    double thValue;
};
TimeframeTH g_storedTHs[];

// In-memory base price history for today (similar to MotiveWave table, but not persisted)
// Each entry is a fully formatted row string for logging purposes.
string g_todayBasePriceHistory[];
int    g_todayHistoryDay  = -1;
int    g_todayHistoryYear = -1;

struct LabelPosition {
    string name;
    int xPos;
    int yPos;
};
LabelPosition g_labelPositions[];

//+------------------------------------------------------------------+
//| Check if Indicator is Hidden (Helper Function)                   |
//| بررسی مخفی بودن اندیکاتور (تابع کمکی)                            |
//| PERFORMANCE: Cached — only queries GlobalVariable every 500ms   |
//| Call RefreshIsHiddenCache() when F key toggles state             |
//+------------------------------------------------------------------+
bool g_isHiddenCached = false;
uint  g_isHiddenCacheTime = 0;

void RefreshIsHiddenCache() {
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    // PERF FIX: Single GlobalVariableGet + GetLastError instead of Check+Get pair
    double val = GlobalVariableGet(gvar_name);
    if(GetLastError() == ERR_GLOBALVARIABLE_NOT_FOUND) {
        g_isHiddenCached = false;
    } else {
        g_isHiddenCached = (bool)val;
    }
    g_isHiddenCacheTime = GetTickCount();
}

bool IsIndicatorHidden() {
    uint now = GetTickCount();
    if(now - g_isHiddenCacheTime > HIDDEN_CACHE_TTL_MS) {
        RefreshIsHiddenCache();
    }
    return g_isHiddenCached;
}

//+------------------------------------------------------------------+
//| Sanitize Symbol Name for GlobalVariable Usage                    |
//| پاکسازی نام سیمبل برای استفاده در GlobalVariable                 |
//| CRITICAL FIX: Prevents collision and injection-like issues      |
//+------------------------------------------------------------------+
string SanitizeSymbolName(const string symbol) {
    string safe = symbol;
    
    // SECURITY FIX: Remove potentially problematic characters
    StringReplace(safe, "_", "");
    StringReplace(safe, "|", "");
    StringReplace(safe, ":", "");
    StringReplace(safe, "/", "");
    StringReplace(safe, "\\", "");
    StringReplace(safe, " ", "");
    StringReplace(safe, ".", "");
    StringReplace(safe, "-", "");
    StringReplace(safe, "*", "");
    StringReplace(safe, "?", "");
    StringReplace(safe, "<", "");
    StringReplace(safe, ">", "");
    StringReplace(safe, "\"", "");
    StringReplace(safe, "'", "");
    
    // Ensure result is not empty
    if(StringLen(safe) == 0) {
        safe = "UNKNOWN";
    }
    
    // SECURITY: Limit length to prevent buffer issues
    if(StringLen(safe) > 50) {
        safe = StringSubstr(safe, 0, 50);
    }
    
    return safe;
}

// Helper function to cleanup all GlobalVariables for this indicator
void CleanupAllGlobalVariables() {
    // PERFORMANCE: Use cached ChartID string
    string chartIdStr = GetCachedChartIdStr();
    string symbolName = SanitizeSymbolName(GetCachedSymbol()); // CRITICAL FIX: Sanitize symbol name
    
    // Clean up each GlobalVariable individually (MQL4 doesn't support dynamic arrays)
    string gvar1 = "Biotak_isHidden_" + chartIdStr;
    string gvar2 = "Biotak_CustomPrice_" + symbolName;
    string gvar3 = "Biotak_LockTF_" + chartIdStr;
    string gvar4 = "Biotak_LockTFPeriod_" + chartIdStr;
    string gvar5 = "Biotak_TriggerLevels_" + chartIdStr;
    string gvar6 = "Biotak_CustomPriceOverride_" + symbolName;
    string gvar7 = "Biotak_StepMode_" + chartIdStr;
    string gvar8 = "Biotak_CalcBasis_" + chartIdStr;  // Calculation Basis
    string gvar9 = "Biotak_Factor_" + chartIdStr;     // Factor value
    string gvar10 = "Biotak_TH3Freq_" + chartIdStr;   // TH3 Frequency
    string gvar11 = "Biotak_TH3FreqIdx_" + chartIdStr; // TH3 Frequency Index
    string gvar12 = "Biotak_LinesVisible_" + chartIdStr; // Lines visibility
    
    if(GlobalVariableCheck(gvar1)) GlobalVariableDel(gvar1);
    if(GlobalVariableCheck(gvar2)) GlobalVariableDel(gvar2);
    if(GlobalVariableCheck(gvar3)) GlobalVariableDel(gvar3);
    if(GlobalVariableCheck(gvar4)) GlobalVariableDel(gvar4);
    if(GlobalVariableCheck(gvar5)) GlobalVariableDel(gvar5);
    if(GlobalVariableCheck(gvar6)) GlobalVariableDel(gvar6);
    if(GlobalVariableCheck(gvar7)) GlobalVariableDel(gvar7);
    if(GlobalVariableCheck(gvar8)) GlobalVariableDel(gvar8);
    if(GlobalVariableCheck(gvar9)) GlobalVariableDel(gvar9);
    if(GlobalVariableCheck(gvar10)) GlobalVariableDel(gvar10);
    if(GlobalVariableCheck(gvar11)) GlobalVariableDel(gvar11);
    if(GlobalVariableCheck(gvar12)) GlobalVariableDel(gvar12);
}
