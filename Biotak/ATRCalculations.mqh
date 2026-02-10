//+------------------------------------------------------------------+
//|                                            ATRCalculations.mqh   |
//|                                                                  |
//| ATR-Based Calculations for Biotak Trigger TH3                   |
//| محاسبات مبتنی بر ATR برای بایوتک تریگر                          |
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
//| ✅ Added FloatingPointHelper integration for safe comparisons    |
//| ✅ Implemented SafeDivide/SafeSqrt for all calculations          |
//| ✅ Enhanced validation for all inputs and outputs                |
//| ✅ Multi-timeframe caching for better performance                |
//| ✅ Comprehensive error handling with debug logs                  |
//| ✅ Overflow protection in weighted calculations                  |
//| ✅ Array bounds checking in batch operations                     |
//+------------------------------------------------------------------+
#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"

//+------------------------------------------------------------------+
//| ATR Calculation Constants (matching Java OptimizedCalculations)  |
//| ثابت‌های محاسبه ATR (مطابق با جاوا)                              |
//+------------------------------------------------------------------+

// Default periods for Weighted ATR (matching Java)
// دوره‌های پیش‌فرض برای ATR وزن‌دار
#define ATR_PERIOD_1    5
#define ATR_PERIOD_2    10
#define ATR_PERIOD_3    21
#define ATR_PERIOD_4    66
#define ATR_PERIOD_5    132
#define ATR_PERIOD_6    264

// Weights for each period (matching Java)
// وزن‌ها برای هر دوره
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
//| ساختار کش ATR برای بهینه‌سازی                                    |
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
        g_multiTFCache[i].timeframeMinutes = 0;
        g_multiTFCache[i].atrValue = 0.0;
        g_multiTFCache[i].lastUpdate = 0;
        g_multiTFCache[i].valid = false;
    }
    g_multiTFCacheCount = 0;
    g_multiTFCacheInitialized = true;
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
}

//+------------------------------------------------------------------+
//| Get effective timeframe (respects timeframe lock)                |
//| دریافت تایم‌فریم مؤثر (با احترام به قفل تایم‌فریم)               |
//+------------------------------------------------------------------+
int GetEffectiveTimeframe() {
    // Use locked timeframe if lock is active, otherwise use chart timeframe
    // اگه قفل فعاله از تایم‌فریم قفل شده استفاده کن، وگرنه از تایم‌فریم چارت
    if(g_timeframeLocked && g_lockedPeriod > 0) {
        return g_lockedPeriod;
    }
    return Period();
}

//+------------------------------------------------------------------+
//| Get bar count for effective timeframe                            |
//| دریافت تعداد کندل‌ها برای تایم‌فریم مؤثر                         |
//+------------------------------------------------------------------+
int GetEffectiveBars() {
    int tf = GetEffectiveTimeframe();
    if(tf == Period()) {
        return Bars(_Symbol, _Period);
    }
    return iBars(_Symbol, (ENUM_TIMEFRAMES)tf);
}

//+------------------------------------------------------------------+
//| Calculate True Range for a single bar                            |
//| محاسبه True Range برای یک کندل                                   |
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
        Print("⚠️ CalculateTrueRange: Invalid bar index (", barIndex, "/", totalBars, ")");
        #endif
        return 0.0;
    }
    
    double high, low, prevClose;
    
    // Use iHigh/iLow/iClose/iOpen for timeframe-aware access
    // استفاده از iHigh/iLow/iClose/iOpen برای دسترسی آگاه از تایم‌فریم
    if(tf == Period()) {
        // Current chart timeframe - use iHigh/iLow/iOpen/iClose (MQL5 compatible)
        // CRITICAL FIX: Validate array bounds before access
        int currentBars = Bars(_Symbol, _Period);
        if(barIndex >= currentBars) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CalculateTrueRange: barIndex exceeds Bars (", barIndex, "/", currentBars, ")");
            #endif
            return 0.0;
        }
        
        high = iHigh(_Symbol, _Period, barIndex);
        low = iLow(_Symbol, _Period, barIndex);
        
        // For first bar, use Open as previous close
        // CRITICAL FIX: Check barIndex + 1 bounds before access
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
        // CRITICAL FIX: Check barIndex + 1 bounds
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateTrueRange: Invalid price data (H:", high, " L:", low, " PC:", prevClose, ")");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Validate high >= low
    if(IsLess(high, low, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateTrueRange: High < Low (H:", high, " L:", low, ")");
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
//| محاسبه ATR ساده برای یک دوره مشخص                                |
//|                                                                  |
//| Matches Java: OptimizedCalculations.calculateATROptimized()      |
//| NOTE: Respects timeframe lock - uses GetEffectiveBars()          |
//| AUDIT FIX: Added validation and SafeDivide                       |
//+------------------------------------------------------------------+
double CalculateSimpleATR(const int period) {
    // AUDIT FIX: Validate period range
    if(period <= 0 || period > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateSimpleATR: Invalid period (", period, ")");
        #endif
        return 0.0;
    }
    
    // Use GetEffectiveBars() to respect timeframe lock
    // استفاده از GetEffectiveBars() برای احترام به قفل تایم‌فریم
    int barsAvailable = GetEffectiveBars();
    if(barsAvailable <= period) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateSimpleATR: Not enough bars (", barsAvailable, " < ", period, ")");
        #endif
        return 0.0;
    }
    
    double sumTR = 0.0;
    int validBars = 0;
    
    // CRITICAL FIX: Start from bar 1 (completed bar), not bar 0 (current bar)
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
//| Batch ATR Calculation for Multiple Periods                       |
//| محاسبه دسته‌ای ATR برای چند دوره                                 |
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
    // استفاده از GetEffectiveBars() برای احترام به قفل تایم‌فریم
    int barsAvailable = GetEffectiveBars();
    
    // AUDIT FIX: Validate bars available
    if(barsAvailable <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBatch: No bars available");
        #endif
        return;
    }
    
    // CRITICAL FIX: Calculate only periods we have enough data for
    // محاسبه فقط دوره‌هایی که داده کافی داریم
    // Need period + 1 bars: period bars for TR + 1 for prevClose
    // But start from bar 1 (completed), so need period + 2 total bars
    if(barsAvailable < ATR_PERIOD_1 + 2) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBatch: Not enough bars (", barsAvailable, "), need at least ", ATR_PERIOD_1 + 2);
        #endif
        return;
    }
    
    // If limited bars, calculate what we can and skip larger periods
    if(barsAvailable <= ATR_PERIOD_6 + 2) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBatch: Limited bars (", barsAvailable, "), calculating available periods only");
        #endif
        
        int periods_limited[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3, 
                                 ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
        
        for(int p = 0; p < 6; p++) {
            // Only calculate if we have enough bars (period + 2: period bars + 1 prevClose + skip bar 0)
            if(barsAvailable >= periods_limited[p] + 2) {
                results[p] = CalculateSimpleATR(periods_limited[p]);
            } else {
                results[p] = 0.0;
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ CalculateATRBatch: Skipping ATR period ", periods_limited[p], 
                      " (need ", periods_limited[p] + 2, " bars, have ", barsAvailable, ")");
                #endif
            }
        }
        return;
    }
    
    // Pre-calculate True Range for all bars we need using batch CopyXxx
    // PERF FIX: Use CopyHigh/CopyLow/CopyClose/CopyOpen batch calls instead of
    // per-bar iHigh/iLow/iClose/iOpen (reduces ~1000 API calls to ~4)
    int maxPeriod = ATR_PERIOD_6;
    int tf = GetEffectiveTimeframe();
    ENUM_TIMEFRAMES etf = (ENUM_TIMEFRAMES)tf;
    
    // Batch copy OHLC data in 4 calls instead of ~1000 individual calls
    double highArr[], lowArr[], closeArr[], openArr[];
    // CRITICAL FIX: Need maxPeriod + 3 bars for complete TR calculation
    // - maxPeriod bars for TR calculation (bar 1 to bar maxPeriod)
    // - 1 extra bar (bar 0, current - we'll skip it)
    // - 1 extra bar for prevClose of bar maxPeriod (bar maxPeriod+1)
    // Total: maxPeriod + 2 bars to copy, but we need maxPeriod + 3 to have prevClose for oldest
    // Actually: We copy bars 0 to maxPeriod+1, which is maxPeriod+2 bars
    // For bar maxPeriod, we need close of bar maxPeriod+1
    int copyCount = MathMin(maxPeriod + 2, barsAvailable);
    
    int copiedHigh  = CopyHigh(_Symbol, etf, 0, copyCount, highArr);
    int copiedLow   = CopyLow(_Symbol, etf, 0, copyCount, lowArr);
    int copiedClose = CopyClose(_Symbol, etf, 0, copyCount, closeArr);
    int copiedOpen  = CopyOpen(_Symbol, etf, 0, copyCount, openArr);
    
    if(copiedHigh < copyCount || copiedLow < copyCount || 
       copiedClose < copyCount || copiedOpen < copyCount) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBatch: CopyXxx failed (H:", copiedHigh, " L:", copiedLow,
              " C:", copiedClose, " O:", copiedOpen, " needed:", copyCount, "), falling back");
        #endif
        // Fallback to per-bar method
        // CRITICAL FIX: Use completed bars only (start from bar 1)
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
    
    // CopyXxx returns data in chronological order [oldest..newest]
    // We need index 0 = newest bar. Convert: bar_i -> arr[copyCount - 1 - i]
    double trValues[];
    if(ArrayResize(trValues, maxPeriod) != maxPeriod) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateATRBatch: Failed to resize TR array");
        #endif
        return;
    }
    
    // Calculate TR from batch arrays (no more per-bar API calls)
    // CRITICAL FIX: Start from bar 1 (completed bar), not bar 0 (current forming bar)
    // Stop at copyCount - 1 to ensure we have prevClose available
    for(int i = 1; i <= maxPeriod && i < copyCount - 1; i++) {
        int arrIdx = copyCount - 1 - i;  // Convert bar index to array index
        
        double high = highArr[arrIdx];
        double low  = lowArr[arrIdx];
        double prevClose;
        
        // For prevClose, use previous bar's close (arrIdx-1 in chronological order)
        // Since we stop at i < copyCount - 1, arrIdx will always be >= 1
        // So arrIdx - 1 >= 0, which is safe
        if(arrIdx > 0) {
            prevClose = closeArr[arrIdx - 1];
        } else {
            // This should never happen due to loop condition, but keep as safety
            prevClose = openArr[arrIdx];
        }
        
        // Validate prices
        if(!IsValidPrice(high, EPSILON_PRICE) || !IsValidPrice(low, EPSILON_PRICE) || 
           !IsValidPrice(prevClose, EPSILON_PRICE) || IsLess(high, low, EPSILON_PRICE)) {
            trValues[i-1] = 0.0;  // Store at i-1 because we start from i=1
            continue;
        }
        
        // True Range = max(H-L, |H-prevC|, |L-prevC|)
        double hl = high - low;
        double hc = MathAbs(high - prevClose);
        double lc = MathAbs(low - prevClose);
        double tr = hl;
        if(hc > tr) tr = hc;
        if(lc > tr) tr = lc;
        trValues[i-1] = tr;  // Store at i-1 because we start from i=1
    }
    
    // Free batch arrays
    ArrayFree(highArr);
    ArrayFree(lowArr);
    ArrayFree(closeArr);
    ArrayFree(openArr);
    
    // Calculate ATR for each period using pre-computed TR values
    int periods[] = {ATR_PERIOD_1, ATR_PERIOD_2, ATR_PERIOD_3, 
                     ATR_PERIOD_4, ATR_PERIOD_5, ATR_PERIOD_6};
    
    for(int p = 0; p < 6; p++) {
        int period = periods[p];
        
        // CRITICAL FIX: Check if we have enough data (need period bars, not period+1)
        // maxPeriod already includes the extra bar for prevClose calculation
        if(period > maxPeriod) {
            results[p] = 0.0;
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CalculateATRBatch: Skipping period ", period, " (maxPeriod=", maxPeriod, ")");
            #endif
            continue;
        }
        
        double sum = 0.0;
        int count = 0;
        
        // Calculate average TR for this period
        for(int i = 0; i < period && i < maxPeriod; i++) {
            // AUDIT FIX: Use IsZero for comparison
            if(!IsZero(trValues[i], EPSILON_PRICE)) {
                sum += trValues[i];
                count++;
            }
        }
        
        // CRITICAL FIX: Only calculate if we have enough valid bars
        // Need at least 50% of period for reliable ATR
        if(count >= period / 2) {
            results[p] = SafeDivide(sum, (double)count, 0.0, EPSILON_GENERAL);
        } else {
            results[p] = 0.0;
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CalculateATRBatch: Insufficient valid bars for period ", period, 
                  " (", count, "/", period, ")");
            #endif
        }
    }
    
    // Free array
    ArrayFree(trValues);
}


//+------------------------------------------------------------------+
//| Calculate Weighted ATR                                           |
//| محاسبه ATR وزن‌دار                                                |
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateWeightedATR: No bars available");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateWeightedATR: TimeCurrent() returned 0");
        #endif
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
    
    // Calculate ATR for all periods in batch
    double atrValues[];
    CalculateATRBatch(atrValues);
    
    // AUDIT FIX: Validate array size before access
    if(ArraySize(atrValues) < 6) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateWeightedATR: ATR batch calculation failed, array size=", ArraySize(atrValues));
        #endif
        return 0.0;
    }
    
    // Calculate weighted sum
    double weightedSum = 0.0;
    int totalWeight = 0;
    
    int weights[] = {ATR_WEIGHT_1, ATR_WEIGHT_2, ATR_WEIGHT_3, 
                     ATR_WEIGHT_4, ATR_WEIGHT_5, ATR_WEIGHT_6};
    
    // AUDIT FIX: Validate weights array size
    if(ArraySize(weights) != 6) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateWeightedATR: Invalid weights array size");
        #endif
        return 0.0;
    }
    
    // CRITICAL FIX: Only use periods with valid ATR values
    // If some periods are missing (not enough bars), adjust weights accordingly
    for(int i = 0; i < 6; i++) {
        // AUDIT FIX: Use IsZero for comparison
        if(!IsZero(atrValues[i], EPSILON_PRICE)) {
            // AUDIT FIX: Check for potential overflow before multiplication
            double temp = atrValues[i] * weights[i];
            if(temp > 1e10) {  // Sanity check
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ CalculateWeightedATR: Overflow detected in weighted sum");
                #endif
                continue;
            }
            weightedSum += temp;
            totalWeight += weights[i];
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            static datetime s_lastSkipLog = 0;
            datetime now = TimeCurrent();
            if(now - s_lastSkipLog > 300) {  // Log every 5 minutes
                Print("⚠️ CalculateWeightedATR: Skipping ATR period ", i, " (value is zero)");
                s_lastSkipLog = now;
            }
            #endif
        }
    }
    
    // CRITICAL FIX: If no valid ATR values, return 0
    if(totalWeight == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateWeightedATR: No valid ATR values available");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Use SafeDivide
    double result = SafeDivide(weightedSum, (double)totalWeight, 0.0, EPSILON_GENERAL);
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(result, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateWeightedATR: Invalid result (", result, ")");
        #endif
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
        Print("========== WEIGHTED ATR CALCULATION ==========");
        Print("ATR₅: ", DoubleToString(atrValues[0], Digits));
        Print("ATR₁₀: ", DoubleToString(atrValues[1], Digits));
        Print("ATR₂₁: ", DoubleToString(atrValues[2], Digits));
        Print("ATR₆₆: ", DoubleToString(atrValues[3], Digits));
        Print("ATR₁₃₂: ", DoubleToString(atrValues[4], Digits));
        Print("ATR₂₆₄: ", DoubleToString(atrValues[5], Digits));
        Print("Weighted ATR: ", DoubleToString(result, Digits));
        Print("Effective TF: ", effectiveTF, " Bars: ", effectiveBars);
        Print("==============================================");
        s_lastATRLog = TimeCurrent();
    }
    #endif
    
    // Free array AFTER debug logging
    ArrayFree(atrValues);
    
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Hybrid ATR for Target Timeframe                        |
//| محاسبه ATR ترکیبی برای تایم‌فریم هدف                             |
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateHybridATR: Invalid timeframe minutes (current:", currentMinutes, " target:", targetMinutes, ")");
        #endif
        return 0.0;
    }
    
    // Calculate weighted ATR for current timeframe
    double currentATR = CalculateWeightedATR();
    
    // AUDIT FIX: Use IsZero for comparison
    if(IsZero(currentATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateHybridATR: Current ATR is zero");
        #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateHybridATR: Ratio out of range (", ratio, ")");
        #endif
        return currentATR; // Return current ATR as fallback
    }
    
    // Scale using fractal relationship: ATR scales with √(timeframe ratio)
    // ATR_target = ATR_current × √(target_minutes / current_minutes)
    double result = currentATR * ratio;
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(result, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateHybridATR: Invalid result (", result, ")");
        #endif
        return currentATR; // Return current ATR as fallback
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Get Current Timeframe in Minutes                                 |
//| دریافت تایم‌فریم فعلی به دقیقه                                   |
//| AUDIT FIX: Added validation for Period()                         |
//+------------------------------------------------------------------+
int GetCurrentTimeframeMinutes() {
    int period = Period();
    
    // AUDIT FIX: Validate period
    if(period <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetCurrentTimeframeMinutes: Invalid period (", period, ")");
        #endif
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
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetCurrentTimeframeMinutes: Unusual period (", period, ")");
            #endif
            return period;
    }
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Step Value                                   |
//| محاسبه مقدار Step بر اساس ATR                                    |
//|                                                                  |
//| This replaces TH calculation when ATR_BASIS is selected.         |
//| Returns step value in PRICE units (same as TH).                  |
//| AUDIT FIX: Added validation using FloatingPointHelper            |
//+------------------------------------------------------------------+
double CalculateATRBasedStep() {
    // Get weighted ATR for current timeframe
    double weightedATR = CalculateWeightedATR();
    
    // AUDIT FIX: Use IsZero for comparison
    if(IsZero(weightedATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBasedStep: Invalid weighted ATR value");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Validate result
    if(!IsValidPrice(weightedATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRBasedStep: ATR value out of valid range (", weightedATR, ")");
        #endif
        return 0.0;
    }
    
    // ATR is already in price units, return directly
    // This matches how TH returns price units
    return weightedATR;
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Fractal Values                               |
//| محاسبه مقادیر فراکتال بر اساس ATR                                |
//|                                                                  |
//| Structure = ATR (current timeframe)                              |
//| Pattern = 0.5 × Structure                                        |
//| Trigger = 0.25 × Structure                                       |
//| AUDIT FIX: Added validation and error handling                   |
//+------------------------------------------------------------------+
void CalculateATRFractalValues(double &structureValue, double &patternValue, double &triggerValue) {
    // Initialize outputs to zero
    structureValue = 0.0;
    patternValue = 0.0;
    triggerValue = 0.0;
    
    // Get ATR-based step as structure
    structureValue = CalculateATRBasedStep();
    
    // AUDIT FIX: Validate structure value
    if(IsZero(structureValue, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateATRFractalValues: Structure value is zero");
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
        Print("⚠️ CalculateATRFractalValues: Invalid calculated values");
        #endif
        structureValue = 0.0;
        patternValue = 0.0;
        triggerValue = 0.0;
    }
}

//+------------------------------------------------------------------+
//| Get ATR for Specific Timeframe (with fractal scaling)            |
//| دریافت ATR برای تایم‌فریم مشخص (با مقیاس‌بندی فراکتالی)          |
//|                                                                  |
//| Uses hybrid approach: actual ATR for current TF, scaled for others |
//| AUDIT FIX: Added validation and multi-TF caching                 |
//+------------------------------------------------------------------+
double GetATRForTimeframe(const int targetMinutes) {
    // AUDIT FIX: Validate target minutes
    if(targetMinutes <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetATRForTimeframe: Invalid target minutes (", targetMinutes, ")");
        #endif
        return 0.0;
    }
    
    int currentMinutes = GetCurrentTimeframeMinutes();
    
    // AUDIT FIX: Validate current minutes
    if(currentMinutes <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetATRForTimeframe: Invalid current minutes (", currentMinutes, ")");
        #endif
        return 0.0;
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetATRForTimeframe: TimeCurrent() returned 0");
        #endif
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
    
    // Calculate ATR
    double result = CalculateHybridATR(currentMinutes, targetMinutes);
    
    // AUDIT FIX: Update multi-TF cache
    if(g_multiTFCacheInitialized && !IsZero(result, EPSILON_PRICE)) {
        UpdateMultiTFCache(targetMinutes, result);
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Update Multi-Timeframe Cache                                     |
//| به‌روزرسانی کش چند تایم‌فریمی                                    |
//| AUDIT FIX: New function for multi-TF cache management            |
//+------------------------------------------------------------------+
void UpdateMultiTFCache(const int timeframeMinutes, const double atrValue) {
    // AUDIT FIX: Validate inputs
    if(timeframeMinutes <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ UpdateMultiTFCache: Invalid timeframe minutes (", timeframeMinutes, ")");
        #endif
        return;
    }
    
    if(!IsValidPrice(atrValue, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ UpdateMultiTFCache: Invalid ATR value (", atrValue, ")");
        #endif
        return;
    }
    
    if(!g_multiTFCacheInitialized) {
        InitializeATRCache();
    }
    
    // AUDIT FIX: Validate TimeCurrent()
    datetime currentTime = TimeCurrent();
    if(currentTime == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ UpdateMultiTFCache: TimeCurrent() returned 0, skipping cache update");
        #endif
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
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("ℹ️ UpdateMultiTFCache: Cache full, replacing oldest entry (TF=", 
              g_multiTFCache[oldestIndex].timeframeMinutes, " min)");
        #endif
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
            Print("✅ UpdateMultiTFCache: Updated cache entry [", targetIndex, "] TF=", 
                  timeframeMinutes, " min, ATR=", DoubleToString(atrValue, Digits));
            s_lastCacheLog = currentTime;
        }
        #endif
    } else {
        // AUDIT FIX: Log error if index is invalid
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ UpdateMultiTFCache: Invalid target index (", targetIndex, 
              "), cache update failed");
        #endif
    }
}

//+------------------------------------------------------------------+
//| Invalidate ATR Cache (call when data changes significantly)      |
//| باطل کردن کش ATR                                                 |
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
        Print("ℹ️ InvalidateATRCache: Invalidated ", invalidatedCount, " cache entries");
    }
    #endif
}

//+------------------------------------------------------------------+
//| Get ATR Cache Statistics (for debugging)                         |
//| دریافت آمار کش ATR (برای دیباگ)                                  |
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
                stats += StringFormat("  TF=%d min: ATR=%.6f, Age=%d sec\n",
                                   g_multiTFCache[i].timeframeMinutes,
                                   g_multiTFCache[i].atrValue,
                                   (int)(TimeCurrent() - g_multiTFCache[i].lastUpdate));
            }
        }
    }
    
    return stats;
}


//+------------------------------------------------------------------+
//| Test ATR Calculations Module                                     |
//| تست ماژول محاسبات ATR                                            |
//| AUDIT FIX: Comprehensive test suite for all ATR functions        |
//+------------------------------------------------------------------+
void TestATRCalculations() {
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  ATR CALCULATIONS MODULE TESTS                                ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    
    int passCount = 0;
    int totalTests = 0;
    
    // ═══════════════════════════════════════════════════════════════
    // Test 1: Cache Initialization
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    InitializeATRCache();
    if(g_atrCacheInitialized && g_multiTFCacheInitialized) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 1: Cache initialization - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 1: Cache initialization - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 2: GetEffectiveTimeframe
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    int effectiveTF = GetEffectiveTimeframe();
    if(effectiveTF > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 2: GetEffectiveTimeframe (", effectiveTF, ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 2: GetEffectiveTimeframe - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 3: GetEffectiveBars
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    int effectiveBars = GetEffectiveBars();
    if(effectiveBars > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 3: GetEffectiveBars (", effectiveBars, ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 3: GetEffectiveBars - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 4: CalculateTrueRange
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double tr = CalculateTrueRange(1);
    if(!IsZero(tr, EPSILON_PRICE) && IsValidPrice(tr, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 4: CalculateTrueRange (", DoubleToString(tr, Digits), ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 4: CalculateTrueRange - FAIL (TR=", tr, ")");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 5: CalculateSimpleATR
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double simpleATR = CalculateSimpleATR(14);
    if(!IsZero(simpleATR, EPSILON_PRICE) && IsValidPrice(simpleATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 5: CalculateSimpleATR(14) (", DoubleToString(simpleATR, Digits), ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 5: CalculateSimpleATR - FAIL (ATR=", simpleATR, ")");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 6: CalculateATRBatch
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double batchResults[];
    CalculateATRBatch(batchResults);
    if(ArraySize(batchResults) == 6 && !IsZero(batchResults[0], EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 6: CalculateATRBatch - PASS");
        Print("   ATR₅=", DoubleToString(batchResults[0], Digits));
        Print("   ATR₁₀=", DoubleToString(batchResults[1], Digits));
        Print("   ATR₂₁=", DoubleToString(batchResults[2], Digits));
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 6: CalculateATRBatch - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 7: CalculateWeightedATR
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double weightedATR = CalculateWeightedATR();
    if(!IsZero(weightedATR, EPSILON_PRICE) && IsValidPrice(weightedATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 7: CalculateWeightedATR (", DoubleToString(weightedATR, Digits), ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 7: CalculateWeightedATR - FAIL (ATR=", weightedATR, ")");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 8: Cache Validation
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    if(g_atrCache.valid && AreEqual(g_atrCache.weightedATR, weightedATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 8: Cache validation - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 8: Cache validation - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 9: GetCurrentTimeframeMinutes
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    int currentMinutes = GetCurrentTimeframeMinutes();
    if(currentMinutes > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 9: GetCurrentTimeframeMinutes (", currentMinutes, ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 9: GetCurrentTimeframeMinutes - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 10: CalculateHybridATR
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double hybridATR = CalculateHybridATR(currentMinutes, 60); // Scale to H1
    if(!IsZero(hybridATR, EPSILON_PRICE) && IsValidPrice(hybridATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 10: CalculateHybridATR (", DoubleToString(hybridATR, Digits), ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 10: CalculateHybridATR - FAIL (ATR=", hybridATR, ")");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 11: GetATRForTimeframe with Multi-TF Cache
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double tfATR1 = GetATRForTimeframe(60);
    double tfATR2 = GetATRForTimeframe(60); // Should hit cache
    if(AreEqual(tfATR1, tfATR2, EPSILON_PRICE) && g_multiTFCacheCount > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 11: Multi-TF cache - PASS (", g_multiTFCacheCount, " entries)");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 11: Multi-TF cache - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 12: CalculateATRBasedStep
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double atrStep = CalculateATRBasedStep();
    if(!IsZero(atrStep, EPSILON_PRICE) && IsValidPrice(atrStep, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 12: CalculateATRBasedStep (", DoubleToString(atrStep, Digits), ") - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 12: CalculateATRBasedStep - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 13: CalculateATRFractalValues
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double structure, pattern, trigger;
    CalculateATRFractalValues(structure, pattern, trigger);
    if(!IsZero(structure, EPSILON_PRICE) && 
       AreEqual(pattern, structure * 0.5, EPSILON_PRICE) &&
       AreEqual(trigger, structure * 0.25, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 13: CalculateATRFractalValues - PASS");
        Print("   Structure=", DoubleToString(structure, Digits));
        Print("   Pattern=", DoubleToString(pattern, Digits));
        Print("   Trigger=", DoubleToString(trigger, Digits));
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 13: CalculateATRFractalValues - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 14: InvalidateATRCache
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    InvalidateATRCache();
    if(!g_atrCache.valid) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 14: InvalidateATRCache - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 14: InvalidateATRCache - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 15: GetATRCacheStats
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    // Recalculate to populate cache
    CalculateWeightedATR();
    string stats = GetATRCacheStats();
    if(StringLen(stats) > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 15: GetATRCacheStats - PASS");
        #endif
        Print(stats);
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 15: GetATRCacheStats - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 16: Edge Case - Invalid Period
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double invalidATR = CalculateSimpleATR(-1);
    if(IsZero(invalidATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 16: Edge case (invalid period) - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 16: Edge case (invalid period) - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Test 17: Edge Case - Zero Division Protection
    // ═══════════════════════════════════════════════════════════════
    totalTests++;
    double zeroATR = CalculateHybridATR(0, 60);
    if(IsZero(zeroATR, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Test 17: Edge case (zero division) - PASS");
        #endif
        passCount++;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Test 17: Edge case (zero division) - FAIL");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Final Results
    // ═══════════════════════════════════════════════════════════════
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST RESULTS                                                 ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  Passed: ", passCount, " / ", totalTests);
    Print("║  Success Rate: ", DoubleToString(100.0 * passCount / totalTests, 1), "%");
    #endif
    
    if(passCount == totalTests) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("║  Status: ✅ ALL TESTS PASSED                                 ║");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("║  Status: ⚠️ SOME TESTS FAILED                                ║");
        #endif
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    
    // Cleanup
    CleanupATRCache();
}
