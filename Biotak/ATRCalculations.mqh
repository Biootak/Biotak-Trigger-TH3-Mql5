  //+------------------------------------------------------------------+
//|                                            ATRCalculations.mqh   |
//|                                                                  |
//| ATR-Based Calculations for Biotak Trigger TH3                   |
//|                  ATR                                            |
//|                                                                  |
//| This module implements ATR_BASIS calculation mode matching       |
//| the Java/MotiveWave implementation exactly.                      |
//|                                                                  |
//| Key Features:                                                    |
//| - Weighted ATR calculation (multiple periods with weights)       |
//| - Hybrid ATR (current TF + fractal scaling for others)          |
//| - Batch ATR calculation for performance                          |
//| - Full compatibility with existing TH_BASIS mode                 |
//|                                                                  |
//| AUDIT UPDATE v3.11 (2026-02-02):                                 |
//|   Added FloatingPointHelper integration for safe comparisons    |
//|   Implemented SafeDivide/SafeSqrt for all calculations          |
//|   Enhanced validation for all inputs and outputs                |
//|   Multi-timeframe caching for better performance                |
//|   Comprehensive error handling with debug logs                  |
//|   Overflow protection in weighted calculations                  |
//|   Array bounds checking in batch operations                     |
//+------------------------------------------------------------------+
#property copyright "  Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"
#property strict

//+------------------------------------------------------------------+
//| ATR Calculation Constants (matching Java OptimizedCalculations)  |
//|                 ATR (             )                              |
//+------------------------------------------------------------------+

// Default periods for Weighted ATR (matching Java)
//                       ATR        
#define ATR_PERIOD_1    5
#define ATR_PERIOD_2    10
#define ATR_PERIOD_3    21
#define ATR_PERIOD_4    66
#define ATR_PERIOD_5    132
#define ATR_PERIOD_6    264

// Weights for each period (matching Java)
//                    
#define ATR_WEIGHT_1    1
#define ATR_WEIGHT_2    1
#define ATR_WEIGHT_3    2
#define ATR_WEIGHT_4    3
#define ATR_WEIGHT_5    5
#define ATR_WEIGHT_6    8

// Total weight = 1+1+2+3+5+8 = 20
#define ATR_TOTAL_WEIGHT 20

// AUDIT FIX: Cache configuration constants
#define ATR_CACHE_TTL_SECONDS 30        // Cache time-to-live (30 seconds)
#define ATR_CACHE_BAR_TOLERANCE 1       // Max bar count difference for cache validity

//+------------------------------------------------------------------+
//| New Bar-Based ATR Cache for Label Timeframes (v2026)             |
//|                                                                  |
//| Each label timeframe has its own cache slot. Updates only occur  |
//| when a new bar opens on that timeframe. Values are computed from |
//| that timeframe's own price data, never scaled from chart TF.     |
//+------------------------------------------------------------------+
#define ATR_LABEL_TF_COUNT 9
static ENUM_TIMEFRAMES g_atrLabelTFs[ATR_LABEL_TF_COUNT] = {
    PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
    PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1
};

struct SATRLabelCache {
    ENUM_TIMEFRAMES timeframe;
    double weightedATR;
    datetime lastBarTime;
    bool valid;
};
static SATRLabelCache g_atrLabelCache[ATR_LABEL_TF_COUNT];
static bool g_atrLabelCacheInitialized = false;

// FIX: time-based TTL for ATR label cache. The bar-time check alone never
// invalidates W1/MN1 entries (weekly/monthly bars), so values stay stale
// until the next bar forms. This forces a refresh every ATR_LABEL_TTL_SECONDS.
static datetime g_atrLabelCacheLastCheck[ATR_LABEL_TF_COUNT];
#define ATR_LABEL_TTL_SECONDS 5

//+------------------------------------------------------------------+
//| ATR Cache Structure for Performance                              |
//|           ATR                                                    |
//| AUDIT FIX: Enhanced with multi-timeframe support                 |
//+------------------------------------------------------------------+
struct ATRCacheEntry {
    double weightedATR;          // Cached weighted ATR value
    datetime lastUpdate;         // Last update time
    int barCount;                // Bar count when cached
    int cachedTimeframe;         // Timeframe when cached (for lock detection)
    bool valid;                  // Is cache valid?
};

// AUDIT FIX: Multi-timeframe cache for better performance
struct ATRMultiTFCache {
    ENUM_TIMEFRAMES timeframe;   // Timeframe enum
    double atrValue;             // Cached ATR value
    datetime lastUpdate;         // Last update time
    int lastBarCount;            // Bar count at last update
    bool valid;                  // Is cache valid?
};

// Global ATR cache
static ATRCacheEntry g_atrCache;
static bool g_atrCacheInitialized = false;

// AUDIT FIX: Multi-timeframe cache (up to 10 timeframes)
#define MAX_TF_CACHE_SIZE 10
static ATRMultiTFCache g_multiTFCache[MAX_TF_CACHE_SIZE];
static int g_multiTFCacheCount = 0;
static bool g_multiTFCacheInitialized = false;

//+------------------------------------------------------------------+
//| Initialize ATR Cache                                             |
//| AUDIT FIX: Initialize both single and multi-TF caches            |
//+------------------------------------------------------------------+
void InitializeATRCache() {
    g_atrCache.weightedATR = 0.0;
    g_atrCache.lastUpdate = 0;
    g_atrCache.barCount = 0;
    g_atrCache.cachedTimeframe = 0;
    g_atrCache.valid = false;
    g_atrCacheInitialized = true;
    
    // AUDIT FIX: Initialize multi-TF cache
    for(int i = 0; i < MAX_TF_CACHE_SIZE; i++) {
        g_multiTFCache[i].timeframe = PERIOD_CURRENT;
        g_multiTFCache[i].atrValue = 0.0;
        g_multiTFCache[i].lastUpdate = 0;
        g_multiTFCache[i].lastBarCount = 0;
        g_multiTFCache[i].valid = false;
    }
    g_multiTFCacheCount = 0;
    g_multiTFCacheInitialized = true;

    // v2026: Initialize label timeframe cache
    InitATRLabelCache();
}

//+------------------------------------------------------------------+
//| Cleanup ATR Cache (call from OnDeinit)                           |
//| AUDIT FIX: Cleanup both caches                                   |
//+------------------------------------------------------------------+
void CleanupATRCache() {
    g_atrCache.valid = false;
    g_atrCacheInitialized = false;
    
    // AUDIT FIX: Cleanup multi-TF cache
    g_multiTFCacheCount = 0;
    g_multiTFCacheInitialized = false;

    // v2026: Cleanup label cache
    CleanupATRLabelCache();
}

//+------------------------------------------------------------------+
//| Initialize Label ATR Cache (v2026)                               |
//+------------------------------------------------------------------+
void InitATRLabelCache() {
    for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
        g_atrLabelCache[i].timeframe = g_atrLabelTFs[i];
        g_atrLabelCache[i].weightedATR = 0.0;
        g_atrLabelCache[i].lastBarTime = 0;
        g_atrLabelCache[i].valid = false;
    }
    g_atrLabelCacheInitialized = true;
}

//+------------------------------------------------------------------+
//| Cleanup Label ATR Cache (v2026)                                  |
//+------------------------------------------------------------------+
void CleanupATRLabelCache() {
    for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
        g_atrLabelCache[i].valid = false;
    }
    g_atrLabelCacheInitialized = false;
}

//+------------------------------------------------------------------+
//| Find Label ATR Cache Index by Timeframe (v2026)                  |
//+------------------------------------------------------------------+
int FindATRLabelCacheIndex(const ENUM_TIMEFRAMES tf) {
    for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
        if(g_atrLabelCache[i].timeframe == tf) return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Release ATR handles (MT4 no-op: no indicator handles in MT4)     |
//+------------------------------------------------------------------+
void ReleaseATRHandle() {
    // In MT4, iATR uses direct function calls without handles
    // This is a compatibility stub matching the MT5 interface
    ReleaseATRHandleCache();
    CleanupATRCache();
}

//+------------------------------------------------------------------+
//| Get effective timeframe (respects timeframe lock)                |
//|                       (                          )               |
//+------------------------------------------------------------------+
int GetEffectiveTimeframe() {
    // Use locked timeframe if lock is active, otherwise use chart timeframe
    //                                                                       
    if(g_timeframeLocked && g_lockedPeriod > 0) {
        return g_lockedPeriod;
    }
    return Period();
}

//+------------------------------------------------------------------+
//| Get bar count for effective timeframe                            |
//|                                                                  |
//+------------------------------------------------------------------+
int GetEffectiveBars() {
    int tf = GetEffectiveTimeframe();
    if(tf == Period()) {
        return Bars(Symbol(), (ENUM_TIMEFRAMES)Period());
    }
    return iBars(Symbol(), (ENUM_TIMEFRAMES)tf);
}

//+------------------------------------------------------------------+
//| Calculate True Range for a single bar                            |
//|        True Range                                                |
//|                                                                  |
//| Formula: TR = max(High-Low, |High-PrevClose|, |Low-PrevClose|)  |
//| NOTE: Respects timeframe lock - uses locked TF data if active    |
//| AUDIT FIX: Added FloatingPointHelper validation                  |
//+------------------------------------------------------------------+
double CalculateTrueRange(const int barIndex) {
    int tf = GetEffectiveTimeframe();
    int totalBars = GetEffectiveBars();
    
    // AUDIT FIX: Validate bar index
    if(barIndex < 0 || barIndex >= totalBars) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateTrueRange: Invalid bar index (", barIndex, "/", totalBars, ")");
        #endif
        return 0.0;
    }
    
    double high, low, prevClose;
    
    ENUM_TIMEFRAMES effectiveTF = (ENUM_TIMEFRAMES)tf;
    high = iHigh(Symbol(), effectiveTF, barIndex);
    low = iLow(Symbol(), effectiveTF, barIndex);

    // For first bar, use Open as previous close
    // CRITICAL FIX: Check barIndex + 1 bounds
    if(barIndex >= totalBars - 1 || totalBars <= 1) {
        prevClose = iOpen(Symbol(), effectiveTF, barIndex);
    } else {
        prevClose = iClose(Symbol(), effectiveTF, barIndex + 1);
    }
    
    // AUDIT FIX: Use FloatingPointHelper for validation
    if(!IsValidPrice(high, EPSILON_PRICE) || 
       !IsValidPrice(low, EPSILON_PRICE) || 
       !IsValidPrice(prevClose, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateTrueRange: Invalid price data (H:", high, " L:", low, " PC:", prevClose, ")");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Validate high >= low
    if(IsLess(high, low, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateTrueRange: High < Low (H:", high, " L:", low, ")");
        #endif
        return 0.0;
    }
    
    // Calculate True Range components
    double hl = high - low;
    double hc = MathAbs(high - prevClose);
    double lc = MathAbs(low - prevClose);
    
    // Return maximum
    double tr = hl;
    if(hc > tr) tr = hc;
    if(lc > tr) tr = lc;
    
    return tr;
}

//+------------------------------------------------------------------+
//| Calculate Simple ATR for a given period                          |
//|        ATR                                                       |
//|                                                                  |
//| Matches Java: OptimizedCalculations.calculateATROptimized()      |
//| NOTE: Respects timeframe lock - uses GetEffectiveBars()          |
//| AUDIT FIX: Added validation and SafeDivide                       |
//+------------------------------------------------------------------+
double CalculateSimpleATR(const int period) {
    // AUDIT FIX: Validate period range
    if(period <= 0 || period > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateSimpleATR: Invalid period (", period, ")");
        #endif
        return 0.0;
    }

    // Use GetEffectiveBars() to respect timeframe lock
    //            GetEffectiveBars()
    int barsAvailable = GetEffectiveBars();
    if(barsAvailable <= period) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateSimpleATR: Not enough bars (", barsAvailable, " < ", period, ")");
        #endif
        return 0.0;
    }

    // PERF (2026): batch iHigh/iLow/iClose/iOpen via a single CopyRates.
    // The previous implementation called CalculateTrueRange() once per bar,
    // which in turn made 3-4 sync timeseries syscalls (iHigh, iLow, iOpen
    // or iClose) per bar. Over a period of e.g. 14 bars that's 42-56 sync
    // timeseries requests per ATR call - and CalculateATRBatch calls this
    // for 6 different periods, so the cost compounded. One CopyRates pulls
    // all OHLC at once; the inner loop becomes pure math.
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    ENUM_TIMEFRAMES effectiveTF = (ENUM_TIMEFRAMES)GetEffectiveTimeframe();
    int copied = CopyRates(Symbol(), effectiveTF, 0, period + 1, rates);
    if(copied < period + 1) return 0.0;

    double sumTR = 0.0;
    int validBars = 0;
    for(int i = 0; i < period; i++) {
        double high  = rates[i].high;
        double low   = rates[i].low;
        double prevClose = rates[i + 1].close;
        if(!IsValidPrice(high, EPSILON_PRICE) ||
           !IsValidPrice(low, EPSILON_PRICE) ||
           !IsValidPrice(prevClose, EPSILON_PRICE)) {
            continue;
        }
        if(IsLess(high, low, EPSILON_PRICE)) {
            continue;
        }
        double tr = MathMax(high - low,
                            MathMax(MathAbs(high - prevClose),
                                    MathAbs(low - prevClose)));
        if(!IsZero(tr, EPSILON_PRICE)) {
            sumTR += tr;
            validBars++;
        }
    }

    // AUDIT FIX: Use SafeDivide
    return SafeDivide(sumTR, (double)validBars, 0.0, EPSILON_GENERAL);
}

//+------------------------------------------------------------------+
//| Batch ATR Calculation for Multiple Periods                       |
//|                ATR                                               |
//|                                                                  |
//| OPTIMIZATION: Calculates TR once and reuses for all periods      |
//| Matches Java: OptimizedCalculations.calculateATRBatch()          |
//| NOTE: Respects timeframe lock - uses GetEffectiveBars()          |
//| AUDIT FIX: Added validation, SafeDivide, and error handling      |
//+------------------------------------------------------------------+
void CalculateATRBatch(double &results[]) {
    // Initialize results array
    ArrayResize(results, 6);
    ArrayInitialize(results, 0.0);
    
    // Use GetEffectiveBars() to respect timeframe lock
    //            GetEffectiveBars()                             
    int barsAvailable = GetEffectiveBars();
    
    // AUDIT FIX: Validate bars available
    if(barsAvailable <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateATRBatch: No bars available");
        #endif
        return;
    }
    
    if(barsAvailable <= ATR_PERIOD_6) {
        // Not enough data - calculate what we can
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateATRBatch: Limited bars (", barsAvailable, "), using fallback");
        #endif
        results[0] = CalculateSimpleATR(ATR_PERIOD_1);
        results[1] = CalculateSimpleATR(ATR_PERIOD_2);
        results[2] = CalculateSimpleATR(ATR_PERIOD_3);
        results[3] = CalculateSimpleATR(ATR_PERIOD_4);
        results[4] = CalculateSimpleATR(ATR_PERIOD_5);
        results[5] = CalculateSimpleATR(ATR_PERIOD_6);
        return;
    }
    
    // Pre-calculate True Range for all bars we need
    int maxPeriod = ATR_PERIOD_6;
    double trValues[];
    
    // AUDIT FIX: Check array resize success
    if(ArrayResize(trValues, maxPeriod) != maxPeriod) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CalculateATRBatch: Failed to resize TR array");
        #endif
        return;
    }
    
    // Calculate TR for all bars
    for(int i = 0; i < maxPeriod; i++) {
        trValues[i] = CalculateTrueRange(i);
    }
    
    // Calculate ATR for each period using pre-computed TR values
    int periods[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3, 
                     ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    
    for(int p = 0; p < 6; p++) {
        int period = periods[p];
        double sum = 0.0;
        int count = 0;
        
        // AUDIT FIX: Validate period bounds
        int loopLimit = (period < maxPeriod) ? period : maxPeriod;
        
        for(int i = 0; i < loopLimit; i++) {
            // AUDIT FIX: Use IsZero for comparison
            if(!IsZero(trValues[i], EPSILON_PRICE)) {
                sum += trValues[i];
                count++;
            }
        }
        
        // AUDIT FIX: Use SafeDivide
        results[p] = SafeDivide(sum, (double)count, 0.0, EPSILON_GENERAL);
    }
    
    // Free array
    ArrayFree(trValues);
}


//+------------------------------------------------------------------+
//| Calculate Weighted ATR (Indicator Core)                           |
//| v3.13: Wrapper for unified function, respects timeframe lock      |
//+------------------------------------------------------------------+
double CalculateWeightedATR_Locked() {
    return CalculateWeightedATR(PERIOD_CURRENT);
}

//+------------------------------------------------------------------+
//| Get Current Timeframe in Minutes                                 |
//|                                                                  |
//| AUDIT FIX: Added validation for Period()                         |
//+------------------------------------------------------------------+
int GetCurrentTimeframeMinutes() {
    int period = Period();
    
    // AUDIT FIX: Validate period
    if(period <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   GetCurrentTimeframeMinutes: Invalid period (", period, ")");
        #endif
        return 0;
    }

    int minutes = PeriodMinutes((ENUM_TIMEFRAMES)period);
    if(minutes > 0) {
        return minutes;
    }

    #ifdef ENABLE_DEBUG_LOGS
    Print("   GetCurrentTimeframeMinutes: Unusual period (", period, ")");
    #endif
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Step Value                                   |
//|              Step         ATR                                    |
//|                                                                  |
//| This replaces TH calculation when ATR_BASIS is selected.         |
//| Returns step value in PRICE units (same as TH).                  |
//| AUDIT FIX: Added validation using FloatingPointHelper            |
//+------------------------------------------------------------------+
double CalculateATRBasedStep() {
    // Get weighted ATR for current timeframe (respects lock)
    double weightedATR = CalculateWeightedATR_Locked();
    
    // AUDIT FIX: Use IsZero for comparison
    if(IsZero(weightedATR, EPSILON_PRICE)) {
        Print("   CalculateATRBasedStep: Invalid weighted ATR value");
        return 0.0;
    }
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(weightedATR, EPSILON_PRICE)) {
        Print("   CalculateATRBasedStep: ATR value out of valid range (", weightedATR, ")");
        return 0.0;
    }
    
    // ATR is already in price units, return directly
    // This matches how TH returns price units
    return weightedATR;
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Fractal Values                               |
//|                               ATR                                |
//|                                                                  |
//| Structure = ATR (current timeframe)                              |
//| Pattern = 0.5   Structure                                        |
//| Trigger = 0.25   Structure                                       |
//| AUDIT FIX: Added validation and error handling                   |
//+------------------------------------------------------------------+
void CalculateATRFractalValues(double &structureValue, double &patternValue, double &triggerValue) {
    // Initialize outputs to zero
    structureValue = 0.0;
    patternValue = 0.0;
    triggerValue = 0.0;
    
    // Get ATR-based step as structure
    structureValue = CalculateWeightedATR_Locked();
    
    // AUDIT FIX: Validate structure value
    if(IsZero(structureValue, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateATRFractalValues: Structure value is zero");
        #endif
        return;
    }
    
    // Pattern = 0.5 * Structure (same ratio as TH)
    patternValue = structureValue * 0.5;
    
    // Trigger = 0.25 * Structure (same ratio as TH)
    triggerValue = structureValue * 0.25;
    
    // AUDIT FIX: Validate calculated values
    if(!IsValidPrice(patternValue, EPSILON_PRICE) || 
       !IsValidPrice(triggerValue, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CalculateATRFractalValues: Invalid calculated values");
        #endif
        structureValue = 0.0;
        patternValue = 0.0;
        triggerValue = 0.0;
    }
}

//+------------------------------------------------------------------+
//| Convert minutes to ENUM_TIMEFRAMES (v2026)                       |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES MinutesToTimeframe(const int minutes) {
    switch(minutes) {
        case 1:     return PERIOD_M1;
        case 5:     return PERIOD_M5;
        case 15:    return PERIOD_M15;
        case 30:    return PERIOD_M30;
        case 60:    return PERIOD_H1;
        case 240:   return PERIOD_H4;
        case 1440:  return PERIOD_D1;
        case 10080: return PERIOD_W1;
        case 43200: return PERIOD_MN1;
    }
    return PERIOD_CURRENT;
}

//+------------------------------------------------------------------+
//| Per-timeframe ATR period cap (user request, 2026-07-13)          |
//|                                                                  |
//| The user wants RECENT volatility only and explicitly does not    |
//| want "far" periods. For monthly, ~12 candles (1 year) is enough. |
//| We cap the longest period per timeframe so the ATR never demands |
//| decades of history and always reflects recent volatility.        |
//+------------------------------------------------------------------+
int GetMaxATRPeriodForTimeframe(const ENUM_TIMEFRAMES tf) {
    switch(tf) {
        case PERIOD_MN1: return 12;    // ~1 year of monthly bars
        case PERIOD_W1:  return 13;    // ~1 quarter of weekly bars
        case PERIOD_D1:  return 21;    // ~1 month of daily bars
        case PERIOD_H4:  return 60;    // ~10 days
        case PERIOD_H1:  return 120;   // ~5 days
        case PERIOD_M30: return 120;
        case PERIOD_M15: return 120;
        case PERIOD_M5:  return 120;
        case PERIOD_M1:  return 120;   // ~2 hours
        default:         return 120;
    }
}

//+------------------------------------------------------------------+
//| Build a deduped, capped (period, weight) set for a timeframe     |
//| The base 6 periods are clamped to the TF cap; collapsed periods  |
//| merge their weights. Longest period is capped as above.          |
//+------------------------------------------------------------------+
void GetATRPeriodWeightsForTimeframe(const ENUM_TIMEFRAMES tf, int &outPeriods[], int &outWeights[], int &outCount) {
    int maxP = GetMaxATRPeriodForTimeframe(tf);
    int basePeriods[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3,
                         ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    int baseWeights[] = {ATR_WEIGHT_1, ATR_WEIGHT_2, ATR_WEIGHT_3,
                         ATR_WEIGHT_4, ATR_WEIGHT_5, ATR_WEIGHT_6};

    ArrayResize(outPeriods, 6);
    ArrayResize(outWeights, 6);
    outCount = 0;

    for(int i = 0; i < 6; i++) {
        int p = MathMin(basePeriods[i], maxP);
        if(p < 2) p = 2;
        // Merge into an already-added period (clamping can collapse periods)
        bool found = false;
        for(int j = 0; j < outCount; j++) {
            if(outPeriods[j] == p) {
                outWeights[j] += baseWeights[i];
                found = true;
                break;
            }
        }
        if(!found) {
            outPeriods[outCount] = p;
            outWeights[outCount] = baseWeights[i];
            outCount++;
        }
    }
}
double GetATRForTimeframe(const int targetMinutes) {
    ENUM_TIMEFRAMES tf = MinutesToTimeframe(targetMinutes);
    if(tf == PERIOD_CURRENT) return 0.0;
    return CalculateWeightedATR(tf);
}

//+------------------------------------------------------------------+
//| Check whether a valid (exact) ATR is cached for a timeframe      |
//| Used to bound one-time history sync attempts (no per-tick load)  |
//+------------------------------------------------------------------+
bool IsATRCacheValidForTF(const ENUM_TIMEFRAMES tf) {
    if(!g_multiTFCacheInitialized) return false;
    for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].timeframe == tf && g_multiTFCache[i].valid) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Nudge the terminal to load a timeframe's price history           |
//|                                                                  |
//| SeriesSync() is unavailable on this terminal build, so we use    |
//| CopyRates which triggers the terminal's background history sync. |
//| Once downloaded, iATR returns the EXACT ATR on subsequent ticks. |
//| This is called at most once per timeframe (until a valid value   |
//| is cached), so it adds no steady-state load.                      |
//+------------------------------------------------------------------+
void EnsureTimeframeHistory(const ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    // Request enough bars to cover the longest capped ATR period for this TF.
    // A single CopyRates(0,1) does not always trigger the terminal to download
    // the deeper history that iATR needs. Asking for maxPeriod+2 bars forces
    // the history sync to start immediately on first use.
    int maxP = GetMaxATRPeriodForTimeframe(tf);
    int needed = MathMax(maxP + 2, ATR_PERIOD_1 + 2);
    ArrayResize(rates, needed);
    CopyRates(Symbol(), tf, 0, needed, rates);
    ArrayFree(rates);
}

//+------------------------------------------------------------------+
//| Update Multi-Timeframe Cache                                     |
//| v3.14: Updated to handle ENUM_TIMEFRAMES and bar count           |
//+------------------------------------------------------------------+
void UpdateMultiTFCache(const ENUM_TIMEFRAMES tf, const double atrValue, const int barCount) {
    if(!IsValidPrice(atrValue, EPSILON_PRICE)) return;
    if(!g_multiTFCacheInitialized) InitializeATRCache();
    
    datetime currentTime = TimeCurrent();
    int targetIndex = -1;
    
    // Look for existing entry
    for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].timeframe == tf) {
            targetIndex = i;
            break;
        }
    }
    
    // If not found and space available, create new entry
    if(targetIndex < 0 && g_multiTFCacheCount < MAX_TF_CACHE_SIZE) {
        targetIndex = g_multiTFCacheCount;
        g_multiTFCacheCount++;
    }
    
    // If still not found, replace oldest entry
    if(targetIndex < 0) {
        datetime oldestTime = currentTime;
        int oldestIndex = 0;
        for(int i = 0; i < MAX_TF_CACHE_SIZE; i++) {
            if(g_multiTFCache[i].lastUpdate < oldestTime) {
                oldestTime = g_multiTFCache[i].lastUpdate;
                oldestIndex = i;
            }
        }
        targetIndex = oldestIndex;
    }
    
    // Update entry
    if(targetIndex >= 0 && targetIndex < MAX_TF_CACHE_SIZE) {
        g_multiTFCache[targetIndex].timeframe = tf;
        g_multiTFCache[targetIndex].atrValue = atrValue;
        g_multiTFCache[targetIndex].lastUpdate = currentTime;
        g_multiTFCache[targetIndex].lastBarCount = barCount;
        g_multiTFCache[targetIndex].valid = true;
    }
}

//+------------------------------------------------------------------+
//| Invalidate ATR Cache (call when data changes significantly)      |
//|              ATR                                                 |
//| AUDIT FIX: Invalidate both caches with logging                   |
//+------------------------------------------------------------------+
void InvalidateATRCache() {
    #ifdef ENABLE_DEBUG_LOGS
    int invalidatedCount = 0;
    #endif
    
    // Invalidate main cache
    if(g_atrCache.valid) {
        g_atrCache.valid = false;
        #ifdef ENABLE_DEBUG_LOGS
        invalidatedCount++;
        #endif
    }
    
    // AUDIT FIX: Invalidate multi-TF cache
    for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].valid) {
            g_multiTFCache[i].valid = false;
            #ifdef ENABLE_DEBUG_LOGS
            invalidatedCount++;
            #endif
        }
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    if(invalidatedCount > 0) {
        Print("   InvalidateATRCache: Invalidated ", invalidatedCount, " cache entries");
    }
    #endif
}

//+------------------------------------------------------------------+
//| Get ATR Cache Statistics (for debugging)                         |
//|                ATR (          )                                  |
//| AUDIT FIX: Include multi-TF cache stats                          |
//+------------------------------------------------------------------+
string GetATRCacheStats() {
    string stats = "";
    
    if(!g_atrCacheInitialized || !g_atrCache.valid) {
        stats += "ATR Cache: Not initialized or invalid\n";
    } else {
        stats += StringFormat("ATR Cache: Value=%.6f, Age=%d sec, Bars=%d, TF=%d\n",
                           g_atrCache.weightedATR,
                           (int)(TimeCurrent() - g_atrCache.lastUpdate),
                           g_atrCache.barCount,
                           g_atrCache.cachedTimeframe);
    }
    
    // AUDIT FIX: Multi-TF cache stats
    if(g_multiTFCacheInitialized && g_multiTFCacheCount > 0) {
        stats += StringFormat("Multi-TF Cache: %d entries\n", g_multiTFCacheCount);
        
        for(int i = 0; i < g_multiTFCacheCount; i++) {
            if(g_multiTFCache[i].valid) {
                int cachedMins = 0;
                switch(g_multiTFCache[i].timeframe) {
                    case PERIOD_M1:  cachedMins = 1; break;
                    case PERIOD_M5:  cachedMins = 5; break;
                    case PERIOD_M15: cachedMins = 15; break;
                    case PERIOD_M30: cachedMins = 30; break;
                    case PERIOD_H1:  cachedMins = 60; break;
                    case PERIOD_H4:  cachedMins = 240; break;
                    case PERIOD_D1:  cachedMins = 1440; break;
                    case PERIOD_W1:  cachedMins = 10080; break;
                    case PERIOD_MN1: cachedMins = 43200; break;
                }
                stats += StringFormat("  TF=%d min: ATR=%.6f, Age=%d sec\n",
                                   cachedMins,
                                   g_multiTFCache[i].atrValue,
                                   (int)(TimeCurrent() - g_multiTFCache[i].lastUpdate));
            }
        }
    }
    
    return stats;
}

//+------------------------------------------------------------------+
//| SHARED HELPER: Compute True Range array from batch HLC data      |
//+------------------------------------------------------------------+
int ComputeTRFromBatchArrays(double &trValues[], const double &highArr[], 
                              const double &lowArr[], const double &closeArr[],
                              int copyCount, int maxPeriod)
{
    int trCount = 0;
    for(int i = 1; i <= maxPeriod && i < copyCount - 1; i++) {
        double high = highArr[i];
        double low  = lowArr[i];
        double prevClose = closeArr[i + 1];
        if(!IsValidPrice(high, EPSILON_PRICE) || !IsValidPrice(low, EPSILON_PRICE) ||
           !IsValidPrice(prevClose, EPSILON_PRICE) || IsLess(high, low, EPSILON_PRICE)) {
            trValues[i - 1] = 0.0;
        } else {
            double hl = high - low;
            double hc = MathAbs(high - prevClose);
            double lc = MathAbs(low - prevClose);
            double tr = hl;
            if(hc > tr) tr = hc;
            if(lc > tr) tr = lc;
            trValues[i - 1] = tr;
        }
        trCount++;
    }
    return trCount;
}

//+------------------------------------------------------------------+
//| SHARED HELPER: Calculate simple average ATR from pre-computed TR  |
//+------------------------------------------------------------------+
void CalculateSimpleATRFromTR(double &results[], const double &trValues[], int maxPeriod)
{
    int periods[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3,
                     ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    for(int p = 0; p < 6; p++) {
        int period = periods[p];
        if(period > maxPeriod) {
            results[p] = 0.0;
            continue;
        }
        double sum = 0.0;
        int count = 0;
        for(int i = 0; i < period && i < maxPeriod; i++) {
            if(!IsZero(trValues[i], EPSILON_PRICE)) {
                sum += trValues[i];
                count++;
            }
        }
        if(count >= period / 2) {
            results[p] = SafeDivide(sum, (double)count, 0.0, EPSILON_GENERAL);
        } else {
            results[p] = 0.0;
        }
    }
}

//+------------------------------------------------------------------+
//| Core Wilder's ATR Batch Calculation for Any Timeframe            |
//| v3.13: Using built-in iATR for maximum reliability and speed     |
//+------------------------------------------------------------------+
void CalculateATRBatchWilders(double &results[], const ENUM_TIMEFRAMES tf) {
    int periods[6], weights[6], count;
    GetATRPeriodWeightsForTimeframe(tf, periods, weights, count);

    ArrayResize(results, count);
    ArrayInitialize(results, 0.0);

    for(int i = 0; i < count; i++) {
        // Use iATR with shift 1 for stable, non-flickering values
        double val = iATR(Symbol(), tf, periods[i], 1);
        results[i] = (val != EMPTY_VALUE && val > 0) ? val : 0.0;
    }
}

//+------------------------------------------------------------------+
//| Weighted ATR using Wilder's smoothing (iATR)                    |
//|                                                                  |
//| This is the production path. iATR uses standard Wilder's ATR,   |
//| which handles W1/MN1 history and incomplete bars correctly.     |
//| Fallback to simple average from rates only if iATR unavailable. |
//+------------------------------------------------------------------+
double CalculateWeightedATRWilders(const ENUM_TIMEFRAMES tf) {
    double results[];
    int periods[6], weights[6], count;
    GetATRPeriodWeightsForTimeframe(tf, periods, weights, count);
    CalculateATRBatchWilders(results, tf);

    double weightedSum = 0.0;
    int totalWeight = 0;
    for(int i = 0; i < count; i++) {
        if(results[i] > 0) {
            weightedSum += results[i] * weights[i];
            totalWeight += weights[i];
        }
    }

    return SafeDivide(weightedSum, (double)totalWeight, 0.0, EPSILON_GENERAL);
}

//+------------------------------------------------------------------+
//| Get Trigger Duration in Seconds for a given Timeframe            |
//| v3.15: Based on fractal logic (Trigger = 2 timeframes down)      |
//+------------------------------------------------------------------+
int GetTriggerDurationSeconds(ENUM_TIMEFRAMES tf) {
    int minutes = 0;
    switch(tf) {
        case PERIOD_MN1: minutes = 60;   break; // MN -> D1 -> H1 (Trigger is H1)
        case PERIOD_W1:  minutes = 240;  break; // W1 -> D1 -> H4 (Trigger is H4)
        case PERIOD_D1:  minutes = 60;   break; // D1 -> H4 -> H1 (Trigger is H1)
        case PERIOD_H4:  minutes = 15;   break; // H4 -> H1 -> M15 (Trigger is M15)
        case PERIOD_H1:  minutes = 5;    break; // H1 -> M15 -> M5 (Trigger is M5)
        case PERIOD_M30: minutes = 5;    break; // M30 -> M15 -> M5 (Trigger is M5)
        case PERIOD_M15: minutes = 1;    break; // M15 -> M5 -> M1 (Trigger is M1)
        case PERIOD_M5:  minutes = 1;    break; // M5 -> M1 (Trigger is M1)
        case PERIOD_M1:  minutes = 1;    break; // M1 (Minimum 1 min)
        default:         minutes = 1;    break;
    }
    return minutes * 60;
}

//+------------------------------------------------------------------+
//| Calculate Weighted ATR from pre-fetched MqlRates (v2026)         |
//|                                                                  |
//| Computes simple ATR for each fixed period using True Range from  |
//| the timeframe's own bars, then combines with fixed weights.      |
//+------------------------------------------------------------------+
double CalculateWeightedATRFromRates(const MqlRates &rates[], const int count, const ENUM_TIMEFRAMES tf) {
    // Allow partial history: on W1/MN1 the terminal may not have 264+ bars.
    // Each period uses as many bars as available and is excluded if insufficient.
    // Skip index 0 (current, incomplete bar) so W1/MN1 ATR is based on completed
    // candles only, matching the stable iATR(shift=1) behavior.
    if(count <= 2) return 0.0;

    int periods[6], weights[6], count_p;
    GetATRPeriodWeightsForTimeframe(tf, periods, weights, count_p);

    double atrValues[6];
    ArrayInitialize(atrValues, 0.0);

    for(int p = 0; p < count_p; p++) {
        int period = periods[p];
        double sum = 0.0;
        int valid = 0;

        for(int i = 1; i <= period && i < count - 1; i++) {
            double high = rates[i].high;
            double low  = rates[i].low;
            double prevClose = rates[i + 1].close;

            if(!IsValidPrice(high, EPSILON_PRICE) ||
               !IsValidPrice(low, EPSILON_PRICE) ||
               !IsValidPrice(prevClose, EPSILON_PRICE) ||
               IsLess(high, low, EPSILON_PRICE))
                continue;

            double hl = high - low;
            double hc = MathAbs(high - prevClose);
            double lc = MathAbs(low - prevClose);
            double tr = hl;
            if(hc > tr) tr = hc;
            if(lc > tr) tr = lc;

            sum += tr;
            valid++;
        }

        atrValues[p] = (valid >= period / 2) ? SafeDivide(sum, (double)valid, 0.0, EPSILON_GENERAL) : 0.0;
    }

    double weightedSum = 0.0;
    int totalWeight = 0;
    for(int i = 0; i < count_p; i++) {
        if(!IsZero(atrValues[i], EPSILON_PRICE)) {
            weightedSum += atrValues[i] * weights[i];
            totalWeight += weights[i];
        }
    }

    return SafeDivide(weightedSum, (double)totalWeight, 0.0, EPSILON_GENERAL);
}

//+------------------------------------------------------------------+
//| Refresh ATR for a single timeframe from its own price history    |
//| v2026: CopyRates-based, no indicator handles                     |
//+------------------------------------------------------------------+
double RefreshATRForTimeframe(const ENUM_TIMEFRAMES tf) {
    EnsureTimeframeHistory(tf);

    // PRIMARY: use standard Wilder's ATR (iATR). This gives correct values
    // on W1/MN1 and avoids issues with incomplete current bars.
    double wilderValue = CalculateWeightedATRWilders(tf);
    if(wilderValue > 0) return wilderValue;

    // FALLBACK: if iATR cannot return any value (insufficient history for the
    // longest period), compute a weighted ATR from whatever rates ARE available.
    // CalculateWeightedATRFromRates already handles partial history per period,
    // so even a handful of W1/MN1 bars yields a non-zero estimate instead of 0.
    MqlRates rates[];
    int maxBars = iBars(Symbol(), tf);
    if(maxBars < 1) maxBars = ATR_PERIOD_6 + 1;
    // Request as many bars as exist, but never more than the per-TF capped
    // period needs (e.g. MN1 only needs ~13 monthly bars) to keep copies small.
    int maxP = GetMaxATRPeriodForTimeframe(tf);
    int needed = MathMax(ATR_PERIOD_1 + 2, MathMin(maxBars, maxP + 1));
    int copied = CopyRates(Symbol(), tf, 0, needed, rates);
    if(copied <= 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ATR] RefreshATRForTimeframe: no usable history for ", EnumToString(tf),
              " (", copied, "/", needed, ")");
        #endif
        return 0.0;
    }

    double value = CalculateWeightedATRFromRates(rates, copied, tf);
    ArrayFree(rates);
    return value;
}

//+------------------------------------------------------------------+
//| Calculate Weighted ATR                                           |
//| v2026: Per-timeframe, bar-based cache from own price data        |
//+------------------------------------------------------------------+
double CalculateWeightedATR(ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
    // If tf is PERIOD_CURRENT, use effective timeframe (respects lock)
    if(tf == PERIOD_CURRENT) {
        tf = (ENUM_TIMEFRAMES)GetEffectiveTimeframe();
    }

    // Initialize label cache if needed
    if(!g_atrLabelCacheInitialized) InitATRLabelCache();

    int idx = FindATRLabelCacheIndex(tf);
    if(idx < 0) {
        // Unknown timeframe: compute uncached (e.g. locked or exotic TF)
        return RefreshATRForTimeframe(tf);
    }

    datetime currentBarTime = iTime(Symbol(), tf, 0);
    datetime now = TimeCurrent();
    if(g_atrLabelCache[idx].valid &&
       g_atrLabelCache[idx].lastBarTime == currentBarTime &&
       currentBarTime > 0 &&
       now - g_atrLabelCacheLastCheck[idx] < ATR_LABEL_TTL_SECONDS) {
        return g_atrLabelCache[idx].weightedATR;
    }

    // THROTTLE (2026-07-13): When history is not yet available the cache stays
    // invalid (we never cache a 0). Without a throttle this would call
    // CopyRates/iATR on every tick while waiting for W1/MN1 history. So during
    // the "still loading" phase we only retry every ATR_LABEL_TTL_SECONDS.
    if(!g_atrLabelCache[idx].valid && currentBarTime > 0 &&
       now - g_atrLabelCacheLastCheck[idx] < ATR_LABEL_TTL_SECONDS) {
        return 0.0;
    }

    double value = RefreshATRForTimeframe(tf);
    // FIX (2026-07-13): Never cache a zero/empty result as "valid". On first
    // load the W1/MN1 history is often not downloaded yet, so RefreshATR...
    // returns 0. Caching that as valid would freeze the label at "—" until
    // the next bar forms (which for MN1 can be weeks away). Instead, leave
    // valid=false so subsequent ticks retry until real history arrives.
    // We always stamp lastCheck so the throttle above can pace retries.
    g_atrLabelCacheLastCheck[idx] = now;
    if(value > 0 && value != EMPTY_VALUE) {
        g_atrLabelCache[idx].weightedATR = value;
        g_atrLabelCache[idx].lastBarTime = currentBarTime;
        g_atrLabelCache[idx].valid = true;
    }
    return value;
}

//+------------------------------------------------------------------+
//| Calculate Weighted ATR for Specific Timeframe                    |
//| v3.13: Just a wrapper for the unified CalculateWeightedATR       |
//+------------------------------------------------------------------+
double CalculateWeightedATRForTimeframe(const ENUM_TIMEFRAMES targetTF) {
    return CalculateWeightedATR(targetTF);
}

//+------------------------------------------------------------------+
//| Warmup ATR cache for common label timeframes                     |
//|                                                                  |
//| Pre-loads each label timeframe's ATR once at startup.            |
//| v2026: Uses the per-timeframe bar-based cache; no global bridge. |
//+------------------------------------------------------------------+
void WarmupATRMultiTFCache() {
    if(!inpShowATRLabels) return;
    if(!g_atrLabelCacheInitialized) InitATRLabelCache();
    for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
        CalculateWeightedATR(g_atrLabelTFs[i]);
    }
}


//+------------------------------------------------------------------+
//| Test ATR Calculations Module                                     |
//|                   ATR                                            |
//| AUDIT FIX: Comprehensive test suite for all ATR functions        |
//+------------------------------------------------------------------+
void TestATRCalculations() {
    Print("====================");
    Print("   ATR CALCULATIONS MODULE TESTS                                 ");
    Print("====================");
    
    int passCount = 0;
    int totalTests = 0;
    
    //                                                                
    // Test 1: Cache Initialization
    //                                                                
    totalTests++;
    InitializeATRCache();
    if(g_atrCacheInitialized && g_multiTFCacheInitialized) {
        Print("  Test 1: Cache initialization - PASS");
        passCount++;
    } else {
        Print("  Test 1: Cache initialization - FAIL");
    }
    
    //                                                                
    // Test 2: GetEffectiveTimeframe
    //                                                                
    totalTests++;
    int effectiveTF = GetEffectiveTimeframe();
    if(effectiveTF > 0) {
        Print("  Test 2: GetEffectiveTimeframe (", effectiveTF, ") - PASS");
        passCount++;
    } else {
        Print("  Test 2: GetEffectiveTimeframe - FAIL");
    }
    
    //                                                                
    // Test 3: GetEffectiveBars
    //                                                                
    totalTests++;
    int effectiveBars = GetEffectiveBars();
    if(effectiveBars > 0) {
        Print("  Test 3: GetEffectiveBars (", effectiveBars, ") - PASS");
        passCount++;
    } else {
        Print("  Test 3: GetEffectiveBars - FAIL");
    }
    
    //                                                                
    // Test 4: CalculateTrueRange
    //                                                                
    totalTests++;
    double tr = CalculateTrueRange(1);
    if(!IsZero(tr, EPSILON_PRICE) && IsValidPrice(tr, EPSILON_PRICE)) {
        Print("  Test 4: CalculateTrueRange (", DoubleToString(tr, Digits), ") - PASS");
        passCount++;
    } else {
        Print("  Test 4: CalculateTrueRange - FAIL (TR=", tr, ")");
    }
    
    //                                                                
    // Test 5: CalculateSimpleATR
    //                                                                
    totalTests++;
    double simpleATR = CalculateSimpleATR(14);
    if(!IsZero(simpleATR, EPSILON_PRICE) && IsValidPrice(simpleATR, EPSILON_PRICE)) {
        Print("  Test 5: CalculateSimpleATR(14) (", DoubleToString(simpleATR, Digits), ") - PASS");
        passCount++;
    } else {
        Print("  Test 5: CalculateSimpleATR - FAIL (ATR=", simpleATR, ")");
    }
    
    //                                                                
    // Test 6: CalculateATRBatch
    //                                                                
    totalTests++;
    double batchResults[];
    CalculateATRBatch(batchResults);
    if(ArraySize(batchResults) == 6 && !IsZero(batchResults[0], EPSILON_PRICE)) {
        Print("  Test 6: CalculateATRBatch - PASS");
        Print("   ATR =", DoubleToString(batchResults[0], Digits));
        Print("   ATR  =", DoubleToString(batchResults[1], Digits));
        Print("   ATR  =", DoubleToString(batchResults[2], Digits));
        passCount++;
    } else {
        Print("  Test 6: CalculateATRBatch - FAIL");
    }
    
    //                                                                
    // Test 7: CalculateWeightedATR
    //                                                                
    totalTests++;
    double weightedATR = CalculateWeightedATR();
    if(!IsZero(weightedATR, EPSILON_PRICE) && IsValidPrice(weightedATR, EPSILON_PRICE)) {
        Print("  Test 7: CalculateWeightedATR (", DoubleToString(weightedATR, Digits), ") - PASS");
        passCount++;
    } else {
        Print("  Test 7: CalculateWeightedATR - FAIL (ATR=", weightedATR, ")");
    }
    
    //                                                                
    // Test 8: Cache Validation
    //                                                                
    totalTests++;
    if(g_atrCache.valid && AreEqual(g_atrCache.weightedATR, weightedATR, EPSILON_PRICE)) {
        Print("  Test 8: Cache validation - PASS");
        passCount++;
    } else {
        Print("  Test 8: Cache validation - FAIL");
    }
    
    //                                                                
    // Test 9: GetCurrentTimeframeMinutes
    //                                                                
    totalTests++;
    int currentMinutes = GetCurrentTimeframeMinutes();
    if(currentMinutes > 0) {
        Print("  Test 9: GetCurrentTimeframeMinutes (", currentMinutes, ") - PASS");
        passCount++;
    } else {
        Print("  Test 9: GetCurrentTimeframeMinutes - FAIL");
    }
    
    //                                                                 
    // Test 10: GetATRForTimeframe (reads per-TF cache)
    //                                                                 
    totalTests++;
    double tfATR = GetATRForTimeframe(60); // H1
    if(!IsZero(tfATR, EPSILON_PRICE) && IsValidPrice(tfATR, EPSILON_PRICE)) {
        Print("  Test 10: GetATRForTimeframe H1 (", DoubleToString(tfATR, Digits), ") - PASS");
        passCount++;
    } else {
        Print("  Test 10: GetATRForTimeframe H1 - FAIL (ATR=", tfATR, ")");
    }
    
    //                                                                 
    // Test 11: Bar-based cache consistency for H1
    //                                                                 
    totalTests++;
    double tfATR1 = GetATRForTimeframe(60);
    double tfATR2 = GetATRForTimeframe(60); // Should hit cache
    if(AreEqual(tfATR1, tfATR2, EPSILON_PRICE)) {
        Print("  Test 11: Bar-based cache - PASS");
        passCount++;
    } else {
        Print("  Test 11: Bar-based cache - FAIL");
    }
    
    //                                                                
    // Test 12: CalculateATRBasedStep
    //                                                                
    totalTests++;
    double atrStep = CalculateATRBasedStep();
    if(!IsZero(atrStep, EPSILON_PRICE) && IsValidPrice(atrStep, EPSILON_PRICE)) {
        Print("  Test 12: CalculateATRBasedStep (", DoubleToString(atrStep, Digits), ") - PASS");
        passCount++;
    } else {
        Print("  Test 12: CalculateATRBasedStep - FAIL");
    }
    
    //                                                                
    // Test 13: CalculateATRFractalValues
    //                                                                
    totalTests++;
    double structure, pattern, trigger;
    CalculateATRFractalValues(structure, pattern, trigger);
    if(!IsZero(structure, EPSILON_PRICE) && 
       AreEqual(pattern, structure * 0.5, EPSILON_PRICE) &&
       AreEqual(trigger, structure * 0.25, EPSILON_PRICE)) {
        Print("  Test 13: CalculateATRFractalValues - PASS");
        Print("   Structure=", DoubleToString(structure, Digits));
        Print("   Pattern=", DoubleToString(pattern, Digits));
        Print("   Trigger=", DoubleToString(trigger, Digits));
        passCount++;
    } else {
        Print("  Test 13: CalculateATRFractalValues - FAIL");
    }
    
    //                                                                
    // Test 14: InvalidateATRCache
    //                                                                
    totalTests++;
    InvalidateATRCache();
    if(!g_atrCache.valid) {
        Print("  Test 14: InvalidateATRCache - PASS");
        passCount++;
    } else {
        Print("  Test 14: InvalidateATRCache - FAIL");
    }
    
    //                                                                
    // Test 15: GetATRCacheStats
    //                                                                
    totalTests++;
    // Recalculate to populate cache
    CalculateWeightedATR();
    string stats = GetATRCacheStats();
    if(StringLen(stats) > 0) {
        Print("  Test 15: GetATRCacheStats - PASS");
        Print(stats);
        passCount++;
    } else {
        Print("  Test 15: GetATRCacheStats - FAIL");
    }
    
    //                                                                
    // Test 16: Edge Case - Invalid Period
    //                                                                
    totalTests++;
    double invalidATR = CalculateSimpleATR(-1);
    if(IsZero(invalidATR, EPSILON_PRICE)) {
        Print("  Test 16: Edge case (invalid period) - PASS");
        passCount++;
    } else {
        Print("  Test 16: Edge case (invalid period) - FAIL");
    }
    
    //                                                                 
    // Test 17: Edge Case - Invalid Timeframe Minutes
    //                                                                 
    totalTests++;
    double zeroATR = GetATRForTimeframe(0);
    if(IsZero(zeroATR, EPSILON_PRICE)) {
        Print("  Test 17: Edge case (invalid minutes) - PASS");
        passCount++;
    } else {
        Print("  Test 17: Edge case (invalid minutes) - FAIL");
    }
    
    //                                                                
    // Final Results
    //                                                                
    Print("====================");
    Print("   TEST RESULTS                                                  ");
    Print("====================");
    Print("   Passed: ", passCount, " / ", totalTests);
    Print("   Success Rate: ", DoubleToString(100.0 * passCount / totalTests, 1), "%");
    
    if(passCount == totalTests) {
        Print("   Status:   ALL TESTS PASSED                                  ");
    } else {
        Print("   Status:    SOME TESTS FAILED                                 ");
    }
    
    Print("====================");
    
    // Cleanup
    CleanupATRCache();
}
