#ifndef PERFORMANCE_OPTIMIZATIONS_MQH
#define PERFORMANCE_OPTIMIZATIONS_MQH

#property copyright "© Biotak - Performance Optimized"

//+------------------------------------------------------------------+
//| PERFORMANCE FIX: Global Cache for Frequently Called Functions    |

//|                                                                  |
//| These values are expensive to compute and rarely change during   |
//| indicator lifetime. Cache them once in OnInit and use everywhere.|
//+------------------------------------------------------------------+

// Global cached values - initialized once per chart
static string g_cachedSymbol = "";           // Cached Symbol() - never changes
// NOTE: g_cachedPeriod is now managed by CalculationCache.mqh
static int g_cachedDigits = -1;              // Cached Digits - never changes per symbol
static double g_cachedPoint = 0.0;           // Cached Point - never changes per symbol
static long g_cachedChartId = 0;             // Cached ChartID() - never changes
static string g_cachedChartIdStr = "";       // Cached IntegerToString(ChartID()) - never changes
static bool g_globalCacheInitialized = false;

//+------------------------------------------------------------------+
//| Initialize Global Cache (call from OnInit)                       |

//+------------------------------------------------------------------+
void InitializeGlobalCache() {
    g_cachedSymbol = Symbol();
    // NOTE: g_cachedPeriod is managed by CalculationCache.mqh
    g_cachedDigits = Digits;
    g_cachedPoint = Point;
    g_cachedChartId = ChartID();
    g_cachedChartIdStr = IntegerToString(g_cachedChartId);
    g_cachedPipSize = (g_cachedDigits == 3 || g_cachedDigits == 5) ? g_cachedPoint * 10.0 : g_cachedPoint;
    g_globalCacheInitialized = true;
    #ifdef ENABLE_DEBUG_LOGS
        Print("Global cache initialized: Symbol=", g_cachedSymbol, ", ChartID=", g_cachedChartIdStr);
    #endif
    }

//+------------------------------------------------------------------+
//| Get Cached Symbol (use instead of Symbol())                      |

//+------------------------------------------------------------------+
string GetCachedSymbol() {
    if(!g_globalCacheInitialized) {
        return Symbol();  // Fallback if not initialized
    }
    return g_cachedSymbol;
}

//+------------------------------------------------------------------+
//| Get Cached Period (use instead of Period())                      |

//| NOTE: Period cache is now managed by CalculationCache.mqh        |
//+------------------------------------------------------------------+
int GetCachedPeriod() {
    // Period cache is now managed by CalculationCache.mqh
    return Period();
}

//+------------------------------------------------------------------+
//| Get Cached Digits (use instead of Digits)                        |

//+------------------------------------------------------------------+
int GetCachedDigits() {
    if(!g_globalCacheInitialized) {
        return Digits;  // Fallback if not initialized
    }
    return g_cachedDigits;
}

//+------------------------------------------------------------------+
//| Get Cached Point (use instead of Point)                          |

//+------------------------------------------------------------------+
double GetCachedPoint() {
    if(!g_globalCacheInitialized) {
        return Point;  // Fallback if not initialized
    }
    return g_cachedPoint;
}

//+------------------------------------------------------------------+
//| Get Cached ChartID (use instead of ChartID())                    |

//+------------------------------------------------------------------+
long GetCachedChartId() {
    if(!g_globalCacheInitialized) {
        return ChartID();  // Fallback if not initialized
    }
    return g_cachedChartId;
}

//+------------------------------------------------------------------+
//| Get Cached ChartID as String (use instead of IntegerToString)    |

//| CRITICAL: This replaces 20+ occurrences of:                      |
//|   IntegerToString(ChartID())                                     |
//+------------------------------------------------------------------+
string GetCachedChartIdStr() {
    if(!g_globalCacheInitialized) {
        return IntegerToString(ChartID());  // Fallback if not initialized
    }
    return g_cachedChartIdStr;
}

//+------------------------------------------------------------------+
//| Get Pip Size (cached, replaces 9+ inline duplications)           |

//| Replaces: (Digits==3||Digits==5) ? Point*10 : Point             |
//+------------------------------------------------------------------+
static double g_cachedPipSize = 0.0;
    double GetCachedPipSize() {
        if(g_cachedPipSize > 0.0) return g_cachedPipSize;
    int d = GetCachedDigits();
    double p = GetCachedPoint();
    g_cachedPipSize = (d == 3 || d == 5) ? p * 10.0 : p;
    return g_cachedPipSize;
}
    #define HIDDEN_CACHE_TTL_MS 500

    void CleanupPerformanceOptimizations() {
    // Note: Object cache is now managed by ObjectCache.mqh
    // Reset global cache
    g_globalCacheInitialized = false;
}
    #endif
    // PERFORMANCE_OPTIMIZATIONS_MQH
