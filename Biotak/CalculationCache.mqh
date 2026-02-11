//+------------------------------------------------------------------+
//|                                            CalculationCache.mqh |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Multi-Layer Calculation Caching for Performance |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict

// Include dependencies
#include "FloatingPointHelper.mqh"
#include "MathConstants.mqh"

//+------------------------------------------------------------------+
//| TH Calculation Cache Entry Structure                             |
//| Caches TH calculation results to avoid redundant arithmetic      |
//+------------------------------------------------------------------+
struct STHCacheEntry {
    double basePrice;        // Input: base price
    double percentage;       // Input: percentage
    int digits;             // Input: digits for normalization
    double result;          // Output: calculated TH value
    datetime lastUpdate;    // Cache timestamp
    bool valid;             // Cache validity flag
};

//+------------------------------------------------------------------+
//| Factor Calculation Cache Entry Structure                         |
//| Caches Factor step size calculations                             |
//+------------------------------------------------------------------+
struct SFactorCacheEntry {
    double highPrice;           // Input: high price
    double lowPrice;            // Input: low price
    double factorValue;         // Input: factor value
    int historicalPeriods;      // Input: historical periods setting
    int period;                 // Input: current period
    double stepSize;            // Output: calculated step size
    datetime lastUpdate;        // Cache timestamp
    bool valid;                 // Cache validity flag
};

//+------------------------------------------------------------------+
//| Timeframe Cache Entry Structure                                  |
//| Caches timeframe conversion and lookup results                   |
//+------------------------------------------------------------------+
struct STimeframeCacheEntry {
    int period;                 // Input: MT5 period
    string fractalTimeframe;    // Output: fractal timeframe string
    double percentage;          // Output: fractal percentage
    int periodSeconds;          // Output: period in seconds
    datetime lastUpdate;        // Cache timestamp
    bool valid;                 // Cache validity flag
};

//+------------------------------------------------------------------+
//| Zone Geometry Cache Entry Structure                              |
//| Caches zone geometry calculations (startTime, endTime)           |
//+------------------------------------------------------------------+
struct SGeometryCacheEntry {
    double topPrice;            // Input: top price
    double bottomPrice;         // Input: bottom price
    int extensionMultiplier;    // Input: extension multiplier
    int historicalPeriods;      // Input: historical periods
    datetime startTime;         // Output: calculated start time
    datetime endTime;           // Output: calculated end time
    datetime lastUpdate;        // Cache timestamp
    bool valid;                 // Cache validity flag
};

//+------------------------------------------------------------------+
//| Extension Multiplier Cache Entry Structure                       |
//| Caches adaptive extension multiplier per timeframe               |
//+------------------------------------------------------------------+
struct SExtensionMultiplierCacheEntry {
    int period;                 // Input: timeframe period
    int periodSeconds;          // Input: period in seconds
    double multiplier;          // Output: calculated multiplier
    datetime lastUpdate;        // Cache timestamp
    bool valid;                 // Cache validity flag
};

//+------------------------------------------------------------------+
//| Global Cache Storage                                              |
//| Single-entry caches for most recent calculations                 |
//+------------------------------------------------------------------+

// TH Calculation Cache (single entry - most recent)
static STHCacheEntry g_thCache;

// Factor Calculation Cache (single entry)
static SFactorCacheEntry g_factorCache;

// Timeframe Cache (single entry for current timeframe)
static STimeframeCacheEntry g_timeframeCache;

// Geometry Cache (single entry for most recent zone)
static SGeometryCacheEntry g_geometryCache;

// Extension Multiplier Cache (single entry for current timeframe)
static SExtensionMultiplierCacheEntry g_extensionMultiplierCache;

// PeriodSeconds Cache (simple value cache)
static int g_cachedPeriod = -1;
static int g_cachedPeriodSeconds = -1;
static datetime g_cachedPeriodSecondsUpdate = 0;

//+------------------------------------------------------------------+
//| Minimum safe divisions threshold (from FloatingPointHelper)      |
//+------------------------------------------------------------------+
#ifndef MIN_SAFE_DIVISIONS
#define MIN_SAFE_DIVISIONS 0.001
#endif

//+------------------------------------------------------------------+
//| TH Calculation Cache Functions                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached TH Calculation Result                                 |
//| Returns cached result if inputs match, 0 if cache miss           |
//+------------------------------------------------------------------+
double GetCachedTHCalculation(double basePrice, double percentage, int digits) {
    // Validate cache
    if(!g_thCache.valid) {
        return 0.0;
    }
    
    // Normalize inputs for comparison
    double normalizedPrice = NormalizeDouble(basePrice, digits);
    double normalizedPercentage = NormalizeDouble(percentage, 6);
    
    // Use dynamic epsilon for price comparison
    double priceEpsilon = GetDynamicEpsilonForPrice(normalizedPrice);
    
    // Check if cache matches
    bool priceMatch = MathAbs(normalizedPrice - g_thCache.basePrice) < priceEpsilon;
    bool percentageMatch = MathAbs(normalizedPercentage - g_thCache.percentage) < EPSILON_PERCENTAGE;
    bool digitsMatch = (digits == g_thCache.digits);
    
    if(priceMatch && percentageMatch && digitsMatch) {
        #ifdef ENABLE_DEBUG_LOGS
        static int s_thCacheHits = 0;
        s_thCacheHits++;
        if(s_thCacheHits % 100 == 0) {
            Print("✅ TH Cache Hit #", s_thCacheHits);
        }
        #endif
        return g_thCache.result;
    }
    
    // Cache miss
    return 0.0;
}

//+------------------------------------------------------------------+
//| Store TH Calculation Result in Cache                             |
//+------------------------------------------------------------------+
void StoreTHCalculation(double basePrice, double percentage, int digits, double result) {
    g_thCache.basePrice = NormalizeDouble(basePrice, digits);
    g_thCache.percentage = NormalizeDouble(percentage, 6);
    g_thCache.digits = digits;
    g_thCache.result = result;
    g_thCache.lastUpdate = TimeCurrent();
    g_thCache.valid = true;
}

//+------------------------------------------------------------------+
//| Invalidate TH Calculation Cache                                  |
//+------------------------------------------------------------------+
void InvalidateTHCache() {
    g_thCache.valid = false;
    g_thCache.basePrice = 0.0;
    g_thCache.percentage = 0.0;
    g_thCache.digits = -1;
    g_thCache.result = 0.0;
    g_thCache.lastUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 TH Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Factor Calculation Cache Functions                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached Factor Step Size                                      |
//| Returns cached result if inputs match, 0 if cache miss           |
//+------------------------------------------------------------------+
double GetCachedFactorStepSize(double highPrice, double lowPrice, double factor) {
    // Validate cache
    if(!g_factorCache.valid) {
        return 0.0;
    }
    
    // Calculate relative tolerance based on price magnitude
    double priceTolerance = highPrice * EPSILON_PRICE_SCALE;
    
    // Check if cache matches
    bool rangeMatch = (MathAbs(highPrice - g_factorCache.highPrice) < priceTolerance) && 
                      (MathAbs(lowPrice - g_factorCache.lowPrice) < priceTolerance);
    bool factorMatch = MathAbs(factor - g_factorCache.factorValue) < 0.001;
    
    if(rangeMatch && factorMatch && g_factorCache.stepSize > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        static int s_factorCacheHits = 0;
        s_factorCacheHits++;
        if(s_factorCacheHits % 50 == 0) {
            Print("✅ Factor Cache Hit #", s_factorCacheHits);
        }
        #endif
        return g_factorCache.stepSize;
    }
    
    // Cache miss
    return 0.0;
}

//+------------------------------------------------------------------+
//| Store Factor Step Size in Cache                                  |
//+------------------------------------------------------------------+
void StoreFactorStepSize(double highPrice, double lowPrice, double factor, 
                         int historicalPeriods, int period, double stepSize) {
    g_factorCache.highPrice = highPrice;
    g_factorCache.lowPrice = lowPrice;
    g_factorCache.factorValue = factor;
    g_factorCache.historicalPeriods = historicalPeriods;
    g_factorCache.period = period;
    g_factorCache.stepSize = stepSize;
    g_factorCache.lastUpdate = TimeCurrent();
    g_factorCache.valid = true;
}

//+------------------------------------------------------------------+
//| Invalidate Factor Calculation Cache                              |
//+------------------------------------------------------------------+
void InvalidateFactorCache() {
    g_factorCache.valid = false;
    g_factorCache.highPrice = 0.0;
    g_factorCache.lowPrice = 0.0;
    g_factorCache.factorValue = 0.0;
    g_factorCache.historicalPeriods = -1;
    g_factorCache.period = 0;
    g_factorCache.stepSize = 0.0;
    g_factorCache.lastUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Factor Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Timeframe Cache Functions                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached Fractal Timeframe                                     |
//| Returns cached fractal timeframe string, empty if cache miss     |
//+------------------------------------------------------------------+
string GetCachedFractalTimeframe(int period) {
    if(!g_timeframeCache.valid || g_timeframeCache.period != period) {
        return "";
    }
    
    return g_timeframeCache.fractalTimeframe;
}

//+------------------------------------------------------------------+
//| Get Cached Fractal Percentage                                    |
//| Returns cached percentage, 0 if cache miss                       |
//+------------------------------------------------------------------+
double GetCachedFractalPercentage(int period) {
    if(!g_timeframeCache.valid || g_timeframeCache.period != period) {
        return 0.0;
    }
    
    return g_timeframeCache.percentage;
}

//+------------------------------------------------------------------+
//| Store Timeframe Conversion in Cache                              |
//+------------------------------------------------------------------+
void StoreTimeframeConversion(int period, string fractalTimeframe, 
                              double percentage, int periodSeconds) {
    g_timeframeCache.period = period;
    g_timeframeCache.fractalTimeframe = fractalTimeframe;
    g_timeframeCache.percentage = percentage;
    g_timeframeCache.periodSeconds = periodSeconds;
    g_timeframeCache.lastUpdate = TimeCurrent();
    g_timeframeCache.valid = true;
}

//+------------------------------------------------------------------+
//| Invalidate Timeframe Cache                                       |
//+------------------------------------------------------------------+
void InvalidateTimeframeCache() {
    g_timeframeCache.valid = false;
    g_timeframeCache.period = -1;
    g_timeframeCache.fractalTimeframe = "";
    g_timeframeCache.percentage = 0.0;
    g_timeframeCache.periodSeconds = -1;
    g_timeframeCache.lastUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Timeframe Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| PeriodSeconds Cache Functions                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached PeriodSeconds                                         |
//| Returns cached value, -1 if cache miss                           |
//+------------------------------------------------------------------+
int GetCachedPeriodSeconds(int period) {
    if(g_cachedPeriod != period || g_cachedPeriodSeconds < 0) {
        return -1;
    }
    
    return g_cachedPeriodSeconds;
}

//+------------------------------------------------------------------+
//| Store PeriodSeconds in Cache                                     |
//+------------------------------------------------------------------+
void StorePeriodSeconds(int period, int periodSeconds) {
    g_cachedPeriod = period;
    g_cachedPeriodSeconds = periodSeconds;
    g_cachedPeriodSecondsUpdate = TimeCurrent();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("💾 PeriodSeconds Cached: Period=", period, ", Seconds=", periodSeconds);
    #endif
}

//+------------------------------------------------------------------+
//| Invalidate PeriodSeconds Cache                                   |
//+------------------------------------------------------------------+
void InvalidatePeriodSecondsCache() {
    g_cachedPeriod = -1;
    g_cachedPeriodSeconds = -1;
    g_cachedPeriodSecondsUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 PeriodSeconds Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Zone Geometry Cache Functions                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached Zone Geometry                                         |
//| Returns true if cache hit, false if cache miss                   |
//| Output: startTime and endTime parameters filled                  |
//+------------------------------------------------------------------+
bool GetCachedZoneGeometry(double topPrice, double bottomPrice, 
                           int extensionMultiplier, int historicalPeriods,
                           datetime &startTime, datetime &endTime) {
    // Validate cache
    if(!g_geometryCache.valid) {
        return false;
    }
    
    // Use epsilon for price comparison
    double priceEpsilon = GetDynamicEpsilonForPrice(topPrice);
    
    // Check if cache matches
    bool pricesMatch = (MathAbs(topPrice - g_geometryCache.topPrice) < priceEpsilon) &&
                       (MathAbs(bottomPrice - g_geometryCache.bottomPrice) < priceEpsilon);
    bool paramsMatch = (extensionMultiplier == g_geometryCache.extensionMultiplier) &&
                       (historicalPeriods == g_geometryCache.historicalPeriods);
    
    if(pricesMatch && paramsMatch) {
        startTime = g_geometryCache.startTime;
        endTime = g_geometryCache.endTime;
        
        #ifdef ENABLE_DEBUG_LOGS
        static int s_geometryCacheHits = 0;
        s_geometryCacheHits++;
        if(s_geometryCacheHits % 50 == 0) {
            Print("✅ Geometry Cache Hit #", s_geometryCacheHits);
        }
        #endif
        
        return true;
    }
    
    // Cache miss
    return false;
}

//+------------------------------------------------------------------+
//| Store Zone Geometry in Cache                                     |
//+------------------------------------------------------------------+
void StoreZoneGeometry(double topPrice, double bottomPrice, 
                       int extensionMultiplier, int historicalPeriods,
                       datetime startTime, datetime endTime) {
    g_geometryCache.topPrice = topPrice;
    g_geometryCache.bottomPrice = bottomPrice;
    g_geometryCache.extensionMultiplier = extensionMultiplier;
    g_geometryCache.historicalPeriods = historicalPeriods;
    g_geometryCache.startTime = startTime;
    g_geometryCache.endTime = endTime;
    g_geometryCache.lastUpdate = TimeCurrent();
    g_geometryCache.valid = true;
}

//+------------------------------------------------------------------+
//| Invalidate Zone Geometry Cache                                   |
//+------------------------------------------------------------------+
void InvalidateGeometryCache() {
    g_geometryCache.valid = false;
    g_geometryCache.topPrice = 0.0;
    g_geometryCache.bottomPrice = 0.0;
    g_geometryCache.extensionMultiplier = 0;
    g_geometryCache.historicalPeriods = -1;
    g_geometryCache.startTime = 0;
    g_geometryCache.endTime = 0;
    g_geometryCache.lastUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Geometry Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Extension Multiplier Cache Functions                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cached Extension Multiplier                                  |
//| Returns cached multiplier, 0 if cache miss                       |
//+------------------------------------------------------------------+
double GetCachedExtensionMultiplier(int period, int periodSeconds) {
    if(!g_extensionMultiplierCache.valid || 
       g_extensionMultiplierCache.period != period ||
       g_extensionMultiplierCache.periodSeconds != periodSeconds) {
        return 0.0;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    static int s_extensionCacheHits = 0;
    s_extensionCacheHits++;
    if(s_extensionCacheHits % 50 == 0) {
        Print("✅ Extension Multiplier Cache Hit #", s_extensionCacheHits);
    }
    #endif
    
    return g_extensionMultiplierCache.multiplier;
}

//+------------------------------------------------------------------+
//| Store Extension Multiplier in Cache                              |
//+------------------------------------------------------------------+
void StoreExtensionMultiplier(int period, int periodSeconds, double multiplier) {
    g_extensionMultiplierCache.period = period;
    g_extensionMultiplierCache.periodSeconds = periodSeconds;
    g_extensionMultiplierCache.multiplier = multiplier;
    g_extensionMultiplierCache.lastUpdate = TimeCurrent();
    g_extensionMultiplierCache.valid = true;
}

//+------------------------------------------------------------------+
//| Invalidate Extension Multiplier Cache                            |
//+------------------------------------------------------------------+
void InvalidateExtensionMultiplierCache() {
    g_extensionMultiplierCache.valid = false;
    g_extensionMultiplierCache.period = -1;
    g_extensionMultiplierCache.periodSeconds = -1;
    g_extensionMultiplierCache.multiplier = 0.0;
    g_extensionMultiplierCache.lastUpdate = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Extension Multiplier Cache Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Master Cache Invalidation Functions                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Invalidate All Calculation Caches                                |
//| Call on major state changes (timeframe change, settings change)  |
//+------------------------------------------------------------------+
void InvalidateAllCalculationCaches() {
    InvalidateTHCache();
    InvalidateFactorCache();
    InvalidateTimeframeCache();
    InvalidatePeriodSecondsCache();
    InvalidateGeometryCache();
    InvalidateExtensionMultiplierCache();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 All Calculation Caches Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Invalidate Timeframe-Dependent Caches                            |
//| Call when timeframe changes                                      |
//+------------------------------------------------------------------+
void InvalidateTimeframeDependentCaches() {
    InvalidateTHCache();
    InvalidateFactorCache();
    InvalidateTimeframeCache();
    InvalidatePeriodSecondsCache();
    InvalidateGeometryCache();
    InvalidateExtensionMultiplierCache();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Timeframe-Dependent Caches Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Invalidate Settings-Dependent Caches                             |
//| Call when historical periods or other settings change            |
//+------------------------------------------------------------------+
void InvalidateSettingsDependentCaches() {
    InvalidateFactorCache();
    InvalidateGeometryCache();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Settings-Dependent Caches Invalidated");
    #endif
}

//+------------------------------------------------------------------+
//| Cache Statistics and Diagnostics                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Cache Status Summary                                         |
//| Returns formatted string with cache validity status              |
//+------------------------------------------------------------------+
string GetCacheStatusSummary() {
    string status = "Cache Status:\n";
    status += "  TH Cache: " + (g_thCache.valid ? "VALID" : "INVALID") + "\n";
    status += "  Factor Cache: " + (g_factorCache.valid ? "VALID" : "INVALID") + "\n";
    status += "  Timeframe Cache: " + (g_timeframeCache.valid ? "VALID" : "INVALID") + "\n";
    status += "  PeriodSeconds Cache: " + (g_cachedPeriodSeconds >= 0 ? "VALID" : "INVALID") + "\n";
    status += "  Geometry Cache: " + (g_geometryCache.valid ? "VALID" : "INVALID") + "\n";
    status += "  Extension Multiplier Cache: " + (g_extensionMultiplierCache.valid ? "VALID" : "INVALID");
    
    return status;
}

//+------------------------------------------------------------------+
//| Print Cache Diagnostics                                          |
//| Logs detailed cache state for debugging                          |
//+------------------------------------------------------------------+
void PrintCacheDiagnostics() {
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  CALCULATION CACHE DIAGNOSTICS                                ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print(GetCacheStatusSummary());
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
}

//+------------------------------------------------------------------+
