//+------------------------------------------------------------------+
//|                                            ATRCalculations.mqh   |
//|                                                                  |
//| ATR-Based Calculations for Biotak Trigger TH3                   |

//|                                                                  |
//| This module implements ATR calculations for informational        |
//| labels and display purposes.                                     |
//|                                                                  |
//| Key Features:                                                    |
//| - Weighted ATR calculation (multiple periods with weights)       |
//| - Hybrid ATR (current TF + fractal scaling for others)          |
//| - Batch ATR calculation for performance                          |
//| - ATR values displayed as info labels only (not for drawing)     |
//|                                                                  |
//| AUDIT UPDATE v3.11 (2026-02-02):                                 |
//| [OK] Added FloatingPointHelper integration for safe comparisons    |
//| [OK] Implemented SafeDivide/SafeSqrt for all calculations          |
//| [OK] Enhanced validation for all inputs and outputs                |
//| [OK] Multi-timeframe caching for better performance                |
//| [OK] Comprehensive error handling with debug logs                  |
//| [OK] Overflow protection in weighted calculations                  |
//| [OK] Array bounds checking in batch operations                     |
//+------------------------------------------------------------------+
#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"

//+------------------------------------------------------------------+
//| ATR Calculation Constants (matching Java OptimizedCalculations)  |

//+------------------------------------------------------------------+

// Default periods for Weighted ATR (matching Java)

#define ATR_PERIOD_1    5
#define ATR_PERIOD_2    10
#define ATR_PERIOD_3    21
#define ATR_PERIOD_4    66
#define ATR_PERIOD_5    132
#define ATR_PERIOD_6    264

// Weights for each period (matching Java)

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
//| ATR Cache Structure for Performance                              |

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
        int timeframeMinutes;        // Timeframe in minutes
    double atrValue;             // Cached ATR value
    datetime lastUpdate;         // Last update time
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
    void InitializeATRCache() {
    g_atrCache.weightedATR = 0.0;
    g_atrCache.lastUpdate = 0;
    g_atrCache.barCount = 0;
    g_atrCache.cachedTimeframe = 0;
    g_atrCache.valid = false;
    g_atrCacheInitialized = true;
    
    // AUDIT FIX: Initialize multi-TF cache
    for(int i = 0; i < MAX_TF_CACHE_SIZE; i++) {
        g_multiTFCache[i].timeframeMinutes = 0;
    g_multiTFCache[i].atrValue = 0.0;
    g_multiTFCache[i].lastUpdate = 0;
    g_multiTFCache[i].valid = false;
    }
    g_multiTFCacheCount = 0;
    g_multiTFCacheInitialized = true;
}
    void CleanupATRCache() {
    g_atrCache.valid = false;
    g_atrCacheInitialized = false;
    
    // AUDIT FIX: Cleanup multi-TF cache
    g_multiTFCacheCount = 0;
    g_multiTFCacheInitialized = false;
}

//+------------------------------------------------------------------+
//| Get effective timeframe (respects timeframe lock)                |

//+------------------------------------------------------------------+
int GetEffectiveTimeframe() {
    // Use locked timeframe if lock is active, otherwise use chart timeframe
    
    if(g_timeframeLocked && g_lockedPeriod > 0) {
        return g_lockedPeriod;
    }
    return GetCachedPeriod();
}

//+------------------------------------------------------------------+
//| Get bar count for effective timeframe                            |

//+------------------------------------------------------------------+
int GetEffectiveBars() {
        int tf = GetEffectiveTimeframe();
    if(tf == GetCachedPeriod()) {
        return Bars(_Symbol, _Period);
    }
    return iBars(_Symbol, (ENUM_TIMEFRAMES)tf);
}

//+------------------------------------------------------------------+
//| Calculate True Range for a single bar                            |

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
        _LOG_GATE_E Print("[E][ATR] CalculateTrueRange: Invalid bar index (", barIndex, "/", totalBars, ")");
    return 0.0;
    }
    double high, low, prevClose;
    
    // Use iHigh/iLow/iClose/iOpen for timeframe-aware access
    
    if(tf == GetCachedPeriod()) {
        // Current chart timeframe - use iHigh/iLow/iOpen/iClose (MQL5 compatible)
        // Validate array bounds before access
        int currentBars = Bars(_Symbol, _Period);
    if(barIndex >= currentBars) {
            _LOG_GATE_W Print("[W][ATR] CalculateTrueRange: barIndex exceeds Bars (", barIndex, "/", currentBars, ")");
    return 0.0;
        }
        
        high = iHigh(_Symbol, _Period, barIndex);
    low = iLow(_Symbol, _Period, barIndex);
        
        // For first bar, use Open as previous close
        // Check barIndex + 1 bounds before access
        if(barIndex >= currentBars - 1) {
            prevClose = iOpen(_Symbol, _Period, barIndex);
        } else {
            prevClose = iClose(_Symbol, _Period, barIndex + 1);  // Previous bar's close
        }
    } else {
        // Locked timeframe - use iHigh/iLow/iClose/iOpen
        high = iHigh(_Symbol, (ENUM_TIMEFRAMES)tf, barIndex);
    low = iLow(_Symbol, (ENUM_TIMEFRAMES)tf, barIndex);
        
        // For first bar, use Open as previous close
        // Check barIndex + 1 bounds
        if(barIndex >= totalBars - 1 || totalBars <= 1) {
            prevClose = iOpen(_Symbol, (ENUM_TIMEFRAMES)tf, barIndex);
        } else {
            prevClose = iClose(_Symbol, (ENUM_TIMEFRAMES)tf, barIndex + 1);  // Previous bar's close
        }
    }
    
    // AUDIT FIX: Use FloatingPointHelper for validation
    if(!IsValidPrice(high, EPSILON_PRICE) || 
       !IsValidPrice(low, EPSILON_PRICE) || 
       !IsValidPrice(prevClose, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][ATR] CalculateTrueRange: Invalid price data (H:", high, " L:", low, " PC:", prevClose, ")");
    return 0.0;
    }
    
    // AUDIT FIX: Validate high >= low
    if(IsLess(high, low, EPSILON_PRICE)) {
        _LOG_GATE_W Print("[W][ATR] CalculateTrueRange: High < Low (H:", high, " L:", low, ")");
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

//|                                                                  |
//| Matches Java: OptimizedCalculations.calculateATROptimized()      |
//| NOTE: Respects timeframe lock - uses GetEffectiveBars()          |
//| AUDIT FIX: Added validation and SafeDivide                       |
//+------------------------------------------------------------------+
double CalculateSimpleATR(const int period) {
    // AUDIT FIX: Validate period range
    if(period <= 0 || period > 10000) {
        _LOG_GATE_E Print("[E][ATR] CalculateSimpleATR: Invalid period (", period, ")");
    return 0.0;
    }
    
    // Use GetEffectiveBars() to respect timeframe lock
    
    int barsAvailable = GetEffectiveBars();
    if(barsAvailable <= period) {
        _LOG_GATE_W Print("[W][ATR] CalculateSimpleATR: Not enough bars (", barsAvailable, " < ", period, ")");
    return 0.0;
    }
    double sumTR = 0.0;
    int validBars = 0;
    
    // Start from bar 1 (completed bar), not bar 0 (current bar)
    // Bar 0 is still forming and its High/Low/Close can change
    // Calculate ATR from completed bars only (index 1 = last completed bar)
    for(int i = 1; i <= period && i < barsAvailable; i++) {
        double tr = CalculateTrueRange(i);
        
        // AUDIT FIX: Use IsZero for comparison
        if(!IsZero(tr, EPSILON_PRICE)) {
            sumTR += tr;
    validBars++;
        }
    }
    
    // AUDIT FIX: Use SafeDivide
    return SafeDivide(sumTR, (double)validBars, 0.0, EPSILON_GENERAL);
}

//+------------------------------------------------------------------+
//| SHARED HELPER: Compute True Range array from batch HLC data      |
//| Returns count of valid TR values written to trValues[]            |
//| trValues[] must be pre-allocated with at least maxPeriod elements |
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
//| Uses SMA (not Wilder's RMA). Requires >= 50% valid bars per period|
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
//|                                                                  |
//| Standard Wilder's ATR (RMA) formula:                             |
//| Step 1: Initial ATR = SMA(TR, period) for first N bars           |
//| Step 2: ATR[n] = (ATR[n-1] × (period-1) + TR[n]) / period       |
//|                                                                  |
//| CopyXxx array ordering: arr[0]=OLDEST, arr[count-1]=NEWEST       |
//| Copies 3× maxPeriod bars for proper Wilder's convergence (~95%)  |
//| Fibonacci-weighted: {1,1,2,3,5,8}/20 over periods {5..264}      |
//+------------------------------------------------------------------+
void CalculateATRBatchWilders(double &results[], const ENUM_TIMEFRAMES tf) {
    ArrayResize(results, 6);
    ArrayInitialize(results, 0.0);
    
    int barsAvailable = iBars(_Symbol, tf);
    
    if(barsAvailable <= 0) {
        _LOG_GATE_W Print("[W][ATR] CalculateATRBatchWilders: No bars available for TF=", tf);
        return;
    }
    
    if(barsAvailable < ATR_PERIOD_1 + 2) {
        _LOG_GATE_W Print("[W][ATR] CalculateATRBatchWilders: Not enough bars (", barsAvailable, ") for TF=", tf);
        return;
    }
    
    int maxPeriod = ATR_PERIOD_6; // 264
    
    // Copy 3× maxPeriod + 2 bars for Wilder's smoothing convergence (~95%)
    // +1 for prevClose of oldest bar, +1 for current bar (skipped)
    // CopyXxx docs: "oldest element will be located at the start of physical memory"
    // So: arr[0]=OLDEST bar, arr[copyCount-1]=NEWEST (bar 0, current)
    int copyCount = MathMin(maxPeriod * 3 + 2, barsAvailable);
    
    double highArr[], lowArr[], closeArr[];
    int copiedHigh  = CopyHigh(_Symbol, tf, 0, copyCount, highArr);
    int copiedLow   = CopyLow(_Symbol, tf, 0, copyCount, lowArr);
    int copiedClose = CopyClose(_Symbol, tf, 0, copyCount, closeArr);
    
    if(copiedHigh < copyCount || copiedLow < copyCount || copiedClose < copyCount) {
        _LOG_GATE_E Print("[E][ATR] CalculateATRBatchWilders: CopyXxx failed for TF=", tf);
        // Fallback: per-bar CalculateTrueRange with Wilder's (only for current TF)
        if(tf == _Period || tf == PERIOD_CURRENT) {
            int periods_fb[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3,
                                ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
            for(int p = 0; p < 6; p++) {
                int period = periods_fb[p];
                int convergeBars = MathMin(period * 3, barsAvailable - 1);
                if(convergeBars < period) { results[p] = 0.0; continue; }
                
                // Wilder's ATR using per-bar CalculateTrueRange
                // CalculateTrueRange uses bar index: 0=current, 1=last completed, etc.
                // Process from oldest (bar convergeBars) to newest (bar 1)
                double sumTR = 0.0;
                for(int b = convergeBars; b > convergeBars - period; b--) {
                    sumTR += CalculateTrueRange(b);
                }
                double atr = sumTR / (double)period; // Initial SMA
                
                for(int b = convergeBars - period; b >= 1; b--) {
                    atr = (atr * (double)(period - 1) + CalculateTrueRange(b)) / (double)period;
                }
                results[p] = (IsValidPrice(atr, EPSILON_PRICE) && atr > 0) ? atr : 0.0;
            }
        }
        return;
    }
    
    // CopyXxx returns chronological data:
    //   arr[0] = OLDEST bar copied
    //   arr[copyCount-1] = NEWEST bar (bar 0, current/forming)
    //
    // Skip arr[copyCount-1] = current forming bar (High/Low/Close still changing)
    // Skip arr[0] = no prevClose available for True Range
    // Valid TR range: array indices 1 to copyCount-2
    // TR[k] = max(high[k]-low[k], |high[k]-close[k-1]|, |low[k]-close[k-1]|)
    
    int trCount = copyCount - 2;
    if(trCount < ATR_PERIOD_1) {
        ArrayFree(highArr); ArrayFree(lowArr); ArrayFree(closeArr);
        return;
    }
    
    double trValues[];
    ArrayResize(trValues, trCount);
    
    // Calculate TR chronologically: arr[1] (2nd oldest) to arr[copyCount-2] (newest completed)
    // trValues[0] = oldest valid TR, trValues[trCount-1] = newest completed TR
    for(int k = 1; k <= trCount; k++) {
        double high = highArr[k];
        double low  = lowArr[k];
        double prevClose = closeArr[k - 1]; // Chronologically older bar's close
        
        if(!IsValidPrice(high, EPSILON_PRICE) || !IsValidPrice(low, EPSILON_PRICE) ||
           !IsValidPrice(prevClose, EPSILON_PRICE) || IsLess(high, low, EPSILON_PRICE)) {
            trValues[k - 1] = 0.0;
            continue;
        }
        
        double hl = high - low;
        double hc = MathAbs(high - prevClose);
        double lc = MathAbs(low - prevClose);
        double tr = hl;
        if(hc > tr) tr = hc;
        if(lc > tr) tr = lc;
        trValues[k - 1] = tr;
    }
    
    ArrayFree(highArr);
    ArrayFree(lowArr);
    ArrayFree(closeArr);
    
    // Apply Wilder's ATR (RMA) for each period using shared TR data
    // trValues is chronological: [0]=oldest, [trCount-1]=newest completed
    int periods[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3,
                     ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    
    for(int p = 0; p < 6; p++) {
        int period = periods[p];
        
        if(trCount < period) {
            results[p] = 0.0;
            continue;
        }
        
        // Step 1: Initial ATR = Simple Moving Average of first 'period' TRs (oldest end)
        double sumTR = 0.0;
        for(int i = 0; i < period; i++) {
            sumTR += trValues[i];
        }
        double atr = sumTR / (double)period;
        
        // Step 2: Wilder's smoothing (RMA) for remaining bars toward newest
        // ATR[n] = (ATR[n-1] × (period-1) + TR[n]) / period
        for(int i = period; i < trCount; i++) {
            atr = (atr * (double)(period - 1) + trValues[i]) / (double)period;
        }
        
        results[p] = (IsValidPrice(atr, EPSILON_PRICE) && atr > 0) ? atr : 0.0;
    }
    
    ArrayFree(trValues);
    
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastWildersLog = 0;
    datetime now = TimeCurrent();
    if(now - s_lastWildersLog > 300) {
        Print("[I][ATR] CalculateATRBatchWilders: TF=", tf, " bars=", barsAvailable,
              " copied=", copyCount, " trCount=", trCount);
        for(int p = 0; p < 6; p++) {
            Print("[D][ATR]    ATR[", periods[p], "]=", DoubleToString(results[p], _Digits));
        }
        s_lastWildersLog = now;
    }
    #endif
}

//+------------------------------------------------------------------+
//| Batch ATR Calculation for Multiple Periods                       |

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
    
    int barsAvailable = GetEffectiveBars();
    
    // AUDIT FIX: Validate bars available
    if(barsAvailable <= 0) {
        _LOG_GATE_W Print("[W][ATR] CalculateATRBatch: No bars available");
    return;
    }
    
    // Calculate only periods we have enough data for
    
    // Need period + 1 bars: period bars for TR + 1 for prevClose
    // But start from bar 1 (completed), so need period + 2 total bars
    if(barsAvailable < ATR_PERIOD_1 + 2) {
        _LOG_GATE_W Print("[W][ATR] CalculateATRBatch: Not enough bars (", barsAvailable, "), need at least ", ATR_PERIOD_1 + 2);
    return;
    }
    
    // If limited bars, calculate what we can and skip larger periods
    if(barsAvailable <= ATR_PERIOD_6 + 2) {
        _LOG_GATE_W Print("[W][ATR] CalculateATRBatch: Limited bars (", barsAvailable, "), calculating available periods only");
    int periods_limited[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3, 
                                 ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    for(int p = 0; p < 6; p++) {
            // Only calculate if we have enough bars (period + 2: period bars + 1 prevClose + skip bar 0)
            if(barsAvailable >= periods_limited[p] + 2) {
                results[p] = CalculateSimpleATR(periods_limited[p]);
            } else {
                results[p] = 0.0;
                _LOG_GATE_W Print("[W][ATR] CalculateATRBatch: Skipping ATR period ", periods_limited[p]);
    }
        }
        return;
    }
    
    // Pre-calculate True Range for all bars we need using batch CopyXxx
    // Use CopyHigh/CopyLow/CopyClose/CopyOpen batch calls instead of
    // per-bar iHigh/iLow/iClose/iOpen (reduces ~1000 API calls to ~4)
    int maxPeriod = ATR_PERIOD_6;
    int tf = GetEffectiveTimeframe();
    ENUM_TIMEFRAMES etf = (ENUM_TIMEFRAMES)tf;
    
    // Batch copy HLC data in 3 calls instead of ~1000 individual calls
    // PERF: CopyOpen removed — not needed for True Range (H-L, |H-prevC|, |L-prevC|)
    double highArr[], lowArr[], closeArr[];
    int copyCount = MathMin(maxPeriod + 2, barsAvailable);
    int copiedHigh  = CopyHigh(_Symbol, etf, 0, copyCount, highArr);
    int copiedLow   = CopyLow(_Symbol, etf, 0, copyCount, lowArr);
    int copiedClose = CopyClose(_Symbol, etf, 0, copyCount, closeArr);
    if(copiedHigh < copyCount || copiedLow < copyCount || 
       copiedClose < copyCount) {
        _LOG_GATE_E Print("[E][ATR] CalculateATRBatch: CopyXxx failed (H:", copiedHigh, " L:", copiedLow);
        // Fallback to per-bar method
        // Use completed bars only (start from bar 1)
        double trFallback[];
    if(ArrayResize(trFallback, maxPeriod) != maxPeriod) return;
        
        // Calculate TR for completed bars (bar 1 to bar maxPeriod)
        for(int i = 1; i <= maxPeriod && i < barsAvailable; i++) {
            trFallback[i-1] = CalculateTrueRange(i);  // Store at i-1
        }
    int periods_fb[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3, 
                            ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    for(int p = 0; p < 6; p++) {
        double sum_fb = 0.0; int count_fb = 0;
    int limit_fb = MathMin(periods_fb[p], maxPeriod);
    for(int i = 0; i < limit_fb; i++) {
                if(!IsZero(trFallback[i], EPSILON_PRICE)) { 
                    sum_fb += trFallback[i];
    count_fb++; 
                }
            }
            
            // Only calculate if we have at least 50% of required bars
            if(count_fb >= periods_fb[p] / 2) {
                results[p] = SafeDivide(sum_fb, (double)count_fb, 0.0, EPSILON_GENERAL);
            } else {
                results[p] = 0.0;
            }
        }
        ArrayFree(trFallback);
    return;
    }
    
    // Compute TR from batch arrays using shared helper
    double trValues[];
    if(ArrayResize(trValues, maxPeriod) != maxPeriod) {
        _LOG_GATE_E Print("[E][ATR] CalculateATRBatch: Failed to resize TR array");
        return;
    }
    
    ComputeTRFromBatchArrays(trValues, highArr, lowArr, closeArr, copyCount, maxPeriod);
    
    ArrayFree(highArr);
    ArrayFree(lowArr);
    ArrayFree(closeArr);
    
    // Calculate ATR for each period using shared helper
    CalculateSimpleATRFromTR(results, trValues, maxPeriod);
    
    ArrayFree(trValues);
}

//+------------------------------------------------------------------+
//| Calculate Weighted ATR                                           |

//|                                                                  |
//| Formula (matching Java OptimizedCalculations.calculateWeightedATR): |
//| ATR = (ATR₅×1 + ATR₁₀×1 + ATR₂₁×2 + ATR₆₆×3 + ATR₁₃₂×5 + ATR₂₆₄×8) / 20 |
//|                                                                  |
//| This provides a more stable ATR value by combining multiple      |
//| periods with different weights.                                  |
//| NOTE: Respects timeframe lock - invalidates cache on TF change   |
//| AUDIT FIX: Enhanced validation, SafeDivide, and error handling   |
//+------------------------------------------------------------------+
double CalculateWeightedATR() {
    // Get effective timeframe (respects lock)
    int effectiveTF = GetEffectiveTimeframe();
    int effectiveBars = GetEffectiveBars();
    
    // AUDIT FIX: Validate bars available
    if(effectiveBars <= 0) {
        _LOG_GATE_W Print("[W][ATR] CalculateWeightedATR: No bars available");
    return 0.0;
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        _LOG_GATE_W Print("[W][ATR] CalculateWeightedATR: TimeCurrent() returned 0");
        // Use cached value if available
        if(g_atrCacheInitialized && g_atrCache.valid) {
        return g_atrCache.weightedATR;
        }
    return 0.0;
    }
    
    // Check cache first
    if(g_atrCacheInitialized && g_atrCache.valid) {
        // Cache is valid if:
        // 1. Bar count hasn't changed significantly
        // 2. Less than ATR_CACHE_TTL_SECONDS since last update
        // 3. Timeframe hasn't changed (important for lock detection)
        
        if(MathAbs(effectiveBars - g_atrCache.barCount) <= ATR_CACHE_BAR_TOLERANCE && 
           (currentTime - g_atrCache.lastUpdate) < ATR_CACHE_TTL_SECONDS &&
           g_atrCache.cachedTimeframe == effectiveTF) {
        return g_atrCache.weightedATR;
        }
    }
    
    // Initialize cache if needed
    if(!g_atrCacheInitialized) {
        InitializeATRCache();
    }
    
    // Calculate ATR for all periods using Wilder's ATR (RMA)
    double atrValues[];
    CalculateATRBatchWilders(atrValues, (ENUM_TIMEFRAMES)effectiveTF);
    
    // AUDIT FIX: Validate array size before access
    if(ArraySize(atrValues) < 6) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATR: ATR batch calculation failed, array size=", ArraySize(atrValues));
    return 0.0;
    }
    
    // Calculate weighted sum
    double weightedSum = 0.0;
    int totalWeight = 0;
    int weights[] = {ATR_WEIGHT_1, ATR_WEIGHT_2, ATR_WEIGHT_3, 
                     ATR_WEIGHT_4, ATR_WEIGHT_5, ATR_WEIGHT_6};
    
    // AUDIT FIX: Validate weights array size
    if(ArraySize(weights) != 6) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATR: Invalid weights array size");
    return 0.0;
    }
    
    // Only use periods with valid ATR values
    // If some periods are missing (not enough bars), adjust weights accordingly
    for(int i = 0; i < 6; i++) {
        // AUDIT FIX: Use IsZero for comparison
        if(!IsZero(atrValues[i], EPSILON_PRICE)) {
            // AUDIT FIX: Check for potential overflow before multiplication
            double temp = atrValues[i] * weights[i];
    if(temp > 1e10) {  // Sanity check
                _LOG_GATE_W Print("[W][ATR] CalculateWeightedATR: Overflow detected in weighted sum");
    continue;
            }
            weightedSum += temp;
    totalWeight += weights[i];
        } else {
        #ifdef ENABLE_DEBUG_LOGS
            static datetime s_lastSkipLog = 0;
    datetime now = TimeCurrent();
    if(now - s_lastSkipLog > 300) {  // Log every 5 minutes
                Print("[W][ATR] CalculateWeightedATR: Skipping ATR period ", i, " (value is zero)");
    s_lastSkipLog = now;
            }
    #endif
    }
    }
    
    // If no valid ATR values, return 0
    if(totalWeight == 0) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATR: No valid ATR values available");
    return 0.0;
    }
    
    // AUDIT FIX: Use SafeDivide
    double result = SafeDivide(weightedSum, (double)totalWeight, 0.0, EPSILON_GENERAL);
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(result, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATR: Invalid result (", result, ")");
    return 0.0;
    }
    
    // Update cache (including timeframe for lock detection)
    g_atrCache.weightedATR = result;
    // PERFORMANCE: Use cached currentTime instead of calling TimeCurrent() again
    g_atrCache.lastUpdate = currentTime;
    g_atrCache.barCount = effectiveBars;
    g_atrCache.cachedTimeframe = effectiveTF;
    g_atrCache.valid = true;
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastATRLog = 0;
    if(currentTime - s_lastATRLog > 300) {  // Log every 5 minutes
        Print("[D][ATR] ========== WEIGHTED ATR CALCULATION ==========");
    Print("[D][ATR] ATR₅: ", DoubleToString(atrValues[0], Digits));
    Print("[D][ATR] ATR₁₀: ", DoubleToString(atrValues[1], Digits));
    Print("[D][ATR] ATR₂₁: ", DoubleToString(atrValues[2], Digits));
    Print("[D][ATR] ATR₆₆: ", DoubleToString(atrValues[3], Digits));
    Print("[D][ATR] ATR₁₃₂: ", DoubleToString(atrValues[4], Digits));
    Print("[D][ATR] ATR₂₆₄: ", DoubleToString(atrValues[5], Digits));
    Print("[D][ATR] Weighted ATR: ", DoubleToString(result, Digits));
    Print("[D][ATR] Effective TF: ", effectiveTF, " Bars: ", effectiveBars);
    Print("[D][ATR] ==============================================");
    s_lastATRLog = TimeCurrent();
    }
    #endif
    
    // Free array AFTER debug logging
    ArrayFree(atrValues);
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Hybrid ATR for Target Timeframe                        |

//|                                                                  |
//| Uses Weighted ATR for current timeframe and scales using         |
//| fractal relationship for other timeframes.                       |
//|                                                                  |
//| Formula (matching Java OptimizedCalculations.calculateHybridATR): |
//| ATR_target = ATR_current × √(target_minutes / current_minutes)   |
//| AUDIT FIX: Added validation and SafeSqrt                         |
//+------------------------------------------------------------------+
double CalculateHybridATR(const int currentMinutes, const int targetMinutes) {
    // AUDIT FIX: Validate input parameters
    if(currentMinutes <= 0 || targetMinutes <= 0) {
        _LOG_GATE_E Print("[E][ATR] CalculateHybridATR: Invalid timeframe minutes (current:", currentMinutes, " target:", targetMinutes, ")");
    return 0.0;
    }
    
    // Calculate weighted ATR for current timeframe
    double currentATR = CalculateWeightedATR();
    
    // AUDIT FIX: Use IsZero for comparison
    if(IsZero(currentATR, EPSILON_PRICE)) {
        _LOG_GATE_W Print("[W][ATR] CalculateHybridATR: Current ATR is zero");
    return 0.0;
    }
    
    // If same timeframe, return current ATR
    if(currentMinutes == targetMinutes) {
        return currentATR;
    }
    
    // AUDIT FIX: Use SafeDivide for ratio calculation
    double ratioValue = SafeDivide((double)targetMinutes, (double)currentMinutes, 1.0, EPSILON_GENERAL);
    
    // AUDIT FIX: Use SafeSqrt for square root
    double ratio = SafeSqrt(ratioValue, 1.0, EPSILON_GENERAL);
    
    // AUDIT FIX: Validate ratio range (sanity check)
    if(ratio < 0.01 || ratio > 100.0) {
        _LOG_GATE_W Print("[W][ATR] CalculateHybridATR: Ratio out of range (", ratio, ")");
    return currentATR; // Return current ATR as fallback
    }
    
    // Scale using fractal relationship: ATR scales with √(timeframe ratio)
    // ATR_target = ATR_current × √(target_minutes / current_minutes)
    double result = currentATR * ratio;
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(result, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][ATR] CalculateHybridATR: Invalid result (", result, ")");
    return currentATR; // Return current ATR as fallback
    }
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Weighted ATR for Specific Timeframe                    |
//| BUGFIX: Direct calculation from target TF data (no scaling)      |
//+------------------------------------------------------------------+
double CalculateWeightedATRForTimeframe(const ENUM_TIMEFRAMES targetTF) {
    // Validate target timeframe
    if(targetTF == PERIOD_CURRENT || targetTF == _Period) {
        return CalculateWeightedATR(); // Use existing function for current TF
    }
    
    // Get bars available for target timeframe
    int targetBars = iBars(_Symbol, targetTF);
    if(targetBars <= 0) {
        _LOG_GATE_W Print("[W][ATR] CalculateWeightedATRForTimeframe: No bars available for TF=", targetTF);
        return 0.0;
    }
    
    // Calculate ATR for all periods using Wilder's ATR (RMA) on target TF
    double atrValues[];
    CalculateATRBatchWilders(atrValues, targetTF);
    
    // Validate array size
    if(ArraySize(atrValues) < 6) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATRForTimeframe: Batch calculation failed for TF=", targetTF);
        return 0.0;
    }
    
    // Calculate weighted sum
    double weightedSum = 0.0;
    int totalWeight = 0;
    int weights[] = {ATR_WEIGHT_1, ATR_WEIGHT_2, ATR_WEIGHT_3, 
                     ATR_WEIGHT_4, ATR_WEIGHT_5, ATR_WEIGHT_6};
    
    for(int i = 0; i < 6; i++) {
        if(!IsZero(atrValues[i], EPSILON_PRICE)) {
            double temp = atrValues[i] * weights[i];
            if(temp < 1e10) {  // Overflow check
                weightedSum += temp;
                totalWeight += weights[i];
            }
        }
    }
    
    if(totalWeight == 0) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATRForTimeframe: No valid ATR values for TF=", targetTF);
        return 0.0;
    }
    
    double result = SafeDivide(weightedSum, (double)totalWeight, 0.0, EPSILON_GENERAL);
    
    if(!IsValidPrice(result, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][ATR] CalculateWeightedATRForTimeframe: Invalid result for TF=", targetTF);
        return 0.0;
    }
    
    ArrayFree(atrValues);
    return result;
}

//+------------------------------------------------------------------+
//| Batch ATR Calculation for Specific Timeframe                     |
//| BUGFIX: Calculate from target TF data directly                   |
//| REFACTORED: Uses shared ComputeTRFromBatchArrays + SimpleATRFromTR|
//+------------------------------------------------------------------+
void CalculateATRBatchForTimeframe(double &results[], const ENUM_TIMEFRAMES targetTF) {
    ArrayResize(results, 6);
    ArrayInitialize(results, 0.0);
    
    int barsAvailable = iBars(_Symbol, targetTF);
    
    if(barsAvailable <= 0) {
        _LOG_GATE_D Print("[D][ATR] CalculateATRBatchForTimeframe: No bars available for TF=", targetTF);
        return;
    }
    
    if(barsAvailable < ATR_PERIOD_1 + 2) {
        _LOG_GATE_D Print("[D][ATR] CalculateATRBatchForTimeframe: Not enough bars for TF=", targetTF);
        return;
    }
    
    int maxPeriod = ATR_PERIOD_6;
    double highArr[], lowArr[], closeArr[];
    int copyCount = MathMin(maxPeriod + 2, barsAvailable);
    
    int copiedHigh  = CopyHigh(_Symbol, targetTF, 0, copyCount, highArr);
    int copiedLow   = CopyLow(_Symbol, targetTF, 0, copyCount, lowArr);
    int copiedClose = CopyClose(_Symbol, targetTF, 0, copyCount, closeArr);
    
    if(copiedHigh < copyCount || copiedLow < copyCount || 
       copiedClose < copyCount) {
        _LOG_GATE_E Print("[E][ATR] CalculateATRBatchForTimeframe: CopyXxx failed for TF=", targetTF);
        return;
    }
    
    double trValues[];
    if(ArrayResize(trValues, maxPeriod) != maxPeriod) return;
    
    ComputeTRFromBatchArrays(trValues, highArr, lowArr, closeArr, copyCount, maxPeriod);
    
    ArrayFree(highArr);
    ArrayFree(lowArr);
    ArrayFree(closeArr);
    
    CalculateSimpleATRFromTR(results, trValues, maxPeriod);
    
    ArrayFree(trValues);
}

//+------------------------------------------------------------------+
//| Get Current Timeframe in Minutes                                 |

//| AUDIT FIX: Added validation for Period()                         |
//+------------------------------------------------------------------+
int GetCurrentTimeframeMinutes() {
        int period = GetCachedPeriod();
    
    // AUDIT FIX: Validate period
    if(period <= 0) {
        _LOG_GATE_E Print("[E][ATR] GetCurrentTimeframeMinutes: Invalid period (", period, ")");
    return 0;
    }
    
    switch(period) {
        case PERIOD_M1:  return 1;
    case PERIOD_M5:  return 5;
    case PERIOD_M15: return 15;
    case PERIOD_M30: return 30;
    case PERIOD_H1:  return 60;
    case PERIOD_H4:  return 240;
    case PERIOD_D1:  return 1440;
    case PERIOD_W1:  return 10080;
    case PERIOD_MN1: return 43200;
    default:         
            // For custom timeframes, return period directly
            // Validate it's reasonable (1 min to 1 month)
            if(period >= 1 && period <= 43200) {
        return period;
            }
            _LOG_GATE_W Print("[W][ATR] GetCurrentTimeframeMinutes: Unusual period (", period, ")");
    return period;
    }
}

//+------------------------------------------------------------------+
//| Get ATR for Specific Timeframe (DIRECT CALCULATION - NO SCALING) |
//|                                                                  |
//| BUGFIX: Calculate ATR directly from target timeframe data        |
//| Each timeframe gets its own real ATR, not scaled from current TF |
//| AUDIT FIX: Added validation and multi-TF caching                 |
//+------------------------------------------------------------------+
double GetATRForTimeframe(const int targetMinutes) {
    // AUDIT FIX: Validate target minutes
    if(targetMinutes <= 0) {
        _LOG_GATE_E Print("[E][ATR] GetATRForTimeframe: Invalid target minutes (", targetMinutes, ")");
    return 0.0;
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        _LOG_GATE_W Print("[W][ATR] GetATRForTimeframe: TimeCurrent() returned 0");
        // Try to find cached value
        if(g_multiTFCacheInitialized) {
            for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].timeframeMinutes == targetMinutes && 
                   g_multiTFCache[i].valid) {
        return g_multiTFCache[i].atrValue;
                }
            }
        }
    return 0.0;
    }
    
    // AUDIT FIX: Check multi-TF cache first
    if(g_multiTFCacheInitialized) {
        for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].timeframeMinutes == targetMinutes && 
               g_multiTFCache[i].valid &&
               (currentTime - g_multiTFCache[i].lastUpdate) < ATR_CACHE_TTL_SECONDS) {
                // Cache hit
                return g_multiTFCache[i].atrValue;
            }
        }
    }
    
    // BUGFIX: Calculate ATR directly from target timeframe (not scaled!)
    ENUM_TIMEFRAMES targetTF = MinutesToTimeframe(targetMinutes);
    double result = CalculateWeightedATRForTimeframe(targetTF);
    
    // AUDIT FIX: Update multi-TF cache
    if(g_multiTFCacheInitialized && !IsZero(result, EPSILON_PRICE)) {
        UpdateMultiTFCache(targetMinutes, result);
    }
    return result;
}

//+------------------------------------------------------------------+
//| Update Multi-Timeframe Cache                                     |

//| AUDIT FIX: New function for multi-TF cache management            |
//+------------------------------------------------------------------+
void UpdateMultiTFCache(const int timeframeMinutes, const double atrValue) {
    // AUDIT FIX: Validate inputs
    if(timeframeMinutes <= 0) {
        _LOG_GATE_E Print("[E][ATR] UpdateMultiTFCache: Invalid timeframe minutes (", timeframeMinutes, ")");
    return;
    }
    
    if(!IsValidPrice(atrValue, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][ATR] UpdateMultiTFCache: Invalid ATR value (", atrValue, ")");
    return;
    }
    
    if(!g_multiTFCacheInitialized) {
        InitializeATRCache();
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        _LOG_GATE_W Print("[W][ATR] UpdateMultiTFCache: TimeCurrent() returned 0, skipping cache update");
    return;
    }
    
    // Find existing entry or create new one
    int targetIndex = -1;
    
    // Look for existing entry
    for(int i = 0; i < g_multiTFCacheCount; i++) {
        if(g_multiTFCache[i].timeframeMinutes == timeframeMinutes) {
            targetIndex = i;
    break;
        }
    }
    
    // If not found and space available, create new entry
    if(targetIndex < 0 && g_multiTFCacheCount < MAX_TF_CACHE_SIZE) {
        targetIndex = g_multiTFCacheCount;
    g_multiTFCacheCount++;
    }
    
    // If still not found, replace oldest entry (LRU)
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
        _LOG_GATE_D Print("[D][ATR]  UpdateMultiTFCache: Cache full, replacing oldest entry (TF=");
    }
    
    // AUDIT FIX: Validate target index before update
    if(targetIndex >= 0 && targetIndex < MAX_TF_CACHE_SIZE) {
        g_multiTFCache[targetIndex].timeframeMinutes = timeframeMinutes;
    g_multiTFCache[targetIndex].atrValue = atrValue;
    g_multiTFCache[targetIndex].lastUpdate = currentTime;
    g_multiTFCache[targetIndex].valid = true;
    #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastCacheLog = 0;
    if(currentTime - s_lastCacheLog > 300) { // Log every 5 minutes
            Print("[I][ATR] UpdateMultiTFCache: Updated cache entry [", targetIndex, "] TF=",
                  timeframeMinutes, " min, ATR=", DoubleToString(atrValue, Digits));
    s_lastCacheLog = currentTime;
        }
    #endif
    } else {
        // AUDIT FIX: Log error if index is invalid
        _LOG_GATE_E Print("[E][ATR] UpdateMultiTFCache: Invalid target index (", targetIndex);
    }
}

//+------------------------------------------------------------------+
//| Invalidate ATR Cache (call when data changes significantly)      |
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

    // Invalidate multi-TF cache
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
        Print("[E][ATR]  InvalidateATRCache: Invalidated ", invalidatedCount, " cache entries");
    }
    #endif
}

//+------------------------------------------------------------------+
//| Warmup ATR cache for common label timeframes                     |
//| Purpose: precompute first heavy ATR calls during OnInit          |
//+------------------------------------------------------------------+
void WarmupATRMultiTFCache() {
    if(!inpShowATRLabels) return;

    int tfMinutes[] = {1, 5, 15, 60, 240, 1440, 10080, 43200};
    for(int i = 0; i < ArraySize(tfMinutes); i++) {
        // Best-effort warmup; keep behavior unchanged.
        double atrWarmup = GetATRForTimeframe(tfMinutes[i]);
    }

    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastWarmupLog = 0;
    datetime now = TimeCurrent();
    if(now > 0 && (s_lastWarmupLog == 0 || now - s_lastWarmupLog >= 60)) {
        Print("[I][ATR] [FAST] ATR warmup completed for label timeframes");
        s_lastWarmupLog = now;
    }
    #endif
}

//+------------------------------------------------------------------+
//| Get ATR Cache Statistics (for debugging)                         |
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

    if(g_multiTFCacheInitialized && g_multiTFCacheCount > 0) {
        stats += StringFormat("Multi-TF Cache: %d entries\n", g_multiTFCacheCount);
        for(int i = 0; i < g_multiTFCacheCount; i++) {
            if(g_multiTFCache[i].valid) {
                stats += StringFormat("  TF=%d min: ATR=%.6f, Age=%d sec\n",
                                   g_multiTFCache[i].timeframeMinutes,
                                   g_multiTFCache[i].atrValue,
                                   (int)(TimeCurrent() - g_multiTFCache[i].lastUpdate));
            }
        }
    }
    return stats;
}
