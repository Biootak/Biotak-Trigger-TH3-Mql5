//+------------------------------------------------------------------+
//|                                          PerformanceMetrics.mqh |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Performance Metrics Collection and Monitoring   |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                     |
//| Tracks various performance indicators for optimization analysis  |
//| Requirements: 20.1, 20.2, 20.3, 20.4, 20.5                      |
//+------------------------------------------------------------------+
struct SPerformanceMetrics {
    // OnCalculate metrics
    int onCalculateCalls;       // Total OnCalculate calls
    int skippedCalls;           // Calls skipped by throttling
    uint totalExecutionTimeMs;  // Total execution time in milliseconds
    uint minExecutionTimeMs;    // Minimum execution time
    uint maxExecutionTimeMs;    // Maximum execution time
    
    // Cache metrics
    int thCacheHits;            // TH calculation cache hits
    int thCacheMisses;          // TH calculation cache misses
    int factorCacheHits;        // Factor calculation cache hits
    int factorCacheMisses;      // Factor calculation cache misses
    int geometryCacheHits;      // Geometry cache hits
    int geometryCacheMisses;    // Geometry cache misses
    int extensionCacheHits;     // Extension multiplier cache hits
    int extensionCacheMisses;   // Extension multiplier cache misses
    
    // API call metrics
    int objectFindCalls;        // ObjectFind API calls
    int objectCreateCalls;      // ObjectCreate API calls
    int objectDeleteCalls;      // ObjectDelete API calls
    int objectSetCalls;         // ObjectSet API calls
    int chartRedrawCalls;       // ChartRedraw API calls
    
    // Zone operation metrics
    int zoneCreationAttempts;   // Zone creation attempts
    int zoneCreationSuccesses;  // Successful zone creations
    int zoneCreationFailures;   // Failed zone creations
    int zoneUpdateOperations;   // Zone update operations
    
    // Timestamp
    datetime lastReset;         // Last metrics reset time
    datetime collectionStart;   // Metrics collection start time
};

//+------------------------------------------------------------------+
//| Global Metrics Instance                                          |
//+------------------------------------------------------------------+
static SPerformanceMetrics g_performanceMetrics;
static bool g_metricsInitialized = false;

// Metrics logging configuration
static int g_metricsLogInterval = 100;  // Log every N OnCalculate calls
static bool g_metricsEnabled = true;    // Enable/disable metrics collection

//+------------------------------------------------------------------+
//| Initialize Performance Metrics                                   |
//| Call from OnInit to reset all counters                           |
//| Requirements: 20.1, 20.2, 20.3, 20.4                            |
//+------------------------------------------------------------------+
void InitializePerformanceMetrics() {
    g_performanceMetrics.onCalculateCalls = 0;
    g_performanceMetrics.skippedCalls = 0;
    g_performanceMetrics.totalExecutionTimeMs = 0;
    g_performanceMetrics.minExecutionTimeMs = UINT_MAX;
    g_performanceMetrics.maxExecutionTimeMs = 0;
    
    g_performanceMetrics.thCacheHits = 0;
    g_performanceMetrics.thCacheMisses = 0;
    g_performanceMetrics.factorCacheHits = 0;
    g_performanceMetrics.factorCacheMisses = 0;
    g_performanceMetrics.geometryCacheHits = 0;
    g_performanceMetrics.geometryCacheMisses = 0;
    g_performanceMetrics.extensionCacheHits = 0;
    g_performanceMetrics.extensionCacheMisses = 0;
    
    g_performanceMetrics.objectFindCalls = 0;
    g_performanceMetrics.objectCreateCalls = 0;
    g_performanceMetrics.objectDeleteCalls = 0;
    g_performanceMetrics.objectSetCalls = 0;
    g_performanceMetrics.chartRedrawCalls = 0;
    
    g_performanceMetrics.zoneCreationAttempts = 0;
    g_performanceMetrics.zoneCreationSuccesses = 0;
    g_performanceMetrics.zoneCreationFailures = 0;
    g_performanceMetrics.zoneUpdateOperations = 0;
    
    g_performanceMetrics.lastReset = TimeCurrent();
    g_performanceMetrics.collectionStart = TimeCurrent();
    
    g_metricsInitialized = true;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("📊 Performance Metrics Initialized");
    #endif
}

//+------------------------------------------------------------------+
//| Reset Performance Metrics                                        |
//| Clears all counters and restarts collection                      |
//+------------------------------------------------------------------+
void ResetPerformanceMetrics() {
    InitializePerformanceMetrics();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 Performance Metrics Reset");
    #endif
}

//+------------------------------------------------------------------+
//| Enable/Disable Metrics Collection                                |
//+------------------------------------------------------------------+
void SetMetricsEnabled(bool enabled) {
    g_metricsEnabled = enabled;
}

//+------------------------------------------------------------------+
//| Set Metrics Logging Interval                                     |
//| interval: Number of OnCalculate calls between log outputs        |
//+------------------------------------------------------------------+
void SetMetricsLogInterval(int interval) {
    if(interval > 0) {
        g_metricsLogInterval = interval;
    }
}

//+------------------------------------------------------------------+
//| OnCalculate Execution Time Tracking                              |
//| Requirements: 20.1                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Start Execution Time Measurement                                 |
//| Returns: Start timestamp in milliseconds                         |
//+------------------------------------------------------------------+
uint StartExecutionTimer() {
    if(!g_metricsEnabled) return 0;
    return GetTickCount();
}

//+------------------------------------------------------------------+
//| End Execution Time Measurement                                   |
//| startTime: Timestamp from StartExecutionTimer                    |
//| skipped: true if call was skipped by throttling                  |
//+------------------------------------------------------------------+
void EndExecutionTimer(uint startTime, bool skipped = false) {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    
    uint endTime = GetTickCount();
    uint executionTime = endTime - startTime;
    
    g_performanceMetrics.onCalculateCalls++;
    
    if(skipped) {
        g_performanceMetrics.skippedCalls++;
    } else {
        g_performanceMetrics.totalExecutionTimeMs += executionTime;
        
        if(executionTime < g_performanceMetrics.minExecutionTimeMs) {
            g_performanceMetrics.minExecutionTimeMs = executionTime;
        }
        
        if(executionTime > g_performanceMetrics.maxExecutionTimeMs) {
            g_performanceMetrics.maxExecutionTimeMs = executionTime;
        }
    }
    
    // Periodic logging
    if(g_performanceMetrics.onCalculateCalls % g_metricsLogInterval == 0) {
        LogPerformanceMetrics();
    }
}

//+------------------------------------------------------------------+
//| Cache Hit/Miss Tracking                                          |
//| Requirements: 20.2                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Record TH Cache Hit                                              |
//+------------------------------------------------------------------+
void RecordTHCacheHit() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.thCacheHits++;
}

//+------------------------------------------------------------------+
//| Record TH Cache Miss                                             |
//+------------------------------------------------------------------+
void RecordTHCacheMiss() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.thCacheMisses++;
}

//+------------------------------------------------------------------+
//| Record Factor Cache Hit                                          |
//+------------------------------------------------------------------+
void RecordFactorCacheHit() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.factorCacheHits++;
}

//+------------------------------------------------------------------+
//| Record Factor Cache Miss                                         |
//+------------------------------------------------------------------+
void RecordFactorCacheMiss() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.factorCacheMisses++;
}

//+------------------------------------------------------------------+
//| Record Geometry Cache Hit                                        |
//+------------------------------------------------------------------+
void RecordGeometryCacheHit() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.geometryCacheHits++;
}

//+------------------------------------------------------------------+
//| Record Geometry Cache Miss                                       |
//+------------------------------------------------------------------+
void RecordGeometryCacheMiss() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.geometryCacheMisses++;
}

//+------------------------------------------------------------------+
//| Record Extension Multiplier Cache Hit                            |
//+------------------------------------------------------------------+
void RecordExtensionCacheHit() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.extensionCacheHits++;
}

//+------------------------------------------------------------------+
//| Record Extension Multiplier Cache Miss                           |
//+------------------------------------------------------------------+
void RecordExtensionCacheMiss() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.extensionCacheMisses++;
}

//+------------------------------------------------------------------+
//| API Call Tracking                                                |
//| Requirements: 20.3                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Record ObjectFind Call                                           |
//+------------------------------------------------------------------+
void RecordObjectFindCall() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.objectFindCalls++;
}

//+------------------------------------------------------------------+
//| Record ObjectCreate Call                                         |
//+------------------------------------------------------------------+
void RecordObjectCreateCall() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.objectCreateCalls++;
}

//+------------------------------------------------------------------+
//| Record ObjectDelete Call                                         |
//+------------------------------------------------------------------+
void RecordObjectDeleteCall() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.objectDeleteCalls++;
}

//+------------------------------------------------------------------+
//| Record ObjectSet Call                                            |
//+------------------------------------------------------------------+
void RecordObjectSetCall() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.objectSetCalls++;
}

//+------------------------------------------------------------------+
//| Record ChartRedraw Call                                          |
//+------------------------------------------------------------------+
void RecordChartRedrawCall() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.chartRedrawCalls++;
}

//+------------------------------------------------------------------+
//| Zone Operation Tracking                                          |
//| Requirements: 20.4                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Record Zone Creation Attempt                                     |
//+------------------------------------------------------------------+
void RecordZoneCreationAttempt() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.zoneCreationAttempts++;
}

//+------------------------------------------------------------------+
//| Record Zone Creation Success                                     |
//+------------------------------------------------------------------+
void RecordZoneCreationSuccess() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.zoneCreationSuccesses++;
}

//+------------------------------------------------------------------+
//| Record Zone Creation Failure                                     |
//+------------------------------------------------------------------+
void RecordZoneCreationFailure() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.zoneCreationFailures++;
}

//+------------------------------------------------------------------+
//| Record Zone Update Operation                                     |
//+------------------------------------------------------------------+
void RecordZoneUpdateOperation() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    g_performanceMetrics.zoneUpdateOperations++;
}

//+------------------------------------------------------------------+
//| Metrics Calculation and Reporting                                |
//| Requirements: 20.5                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Average Execution Time                                 |
//| Returns: Average execution time in milliseconds                  |
//+------------------------------------------------------------------+
double GetAverageExecutionTime() {
    if(!g_metricsInitialized) return 0.0;
    
    int executedCalls = g_performanceMetrics.onCalculateCalls - g_performanceMetrics.skippedCalls;
    if(executedCalls <= 0) return 0.0;
    
    return (double)g_performanceMetrics.totalExecutionTimeMs / (double)executedCalls;
}

//+------------------------------------------------------------------+
//| Calculate Cache Hit Rate                                         |
//| Returns: Cache hit rate as percentage (0-100)                    |
//+------------------------------------------------------------------+
double GetTHCacheHitRate() {
    if(!g_metricsInitialized) return 0.0;
    
    int totalAccesses = g_performanceMetrics.thCacheHits + g_performanceMetrics.thCacheMisses;
    if(totalAccesses <= 0) return 0.0;
    
    return ((double)g_performanceMetrics.thCacheHits / (double)totalAccesses) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Factor Cache Hit Rate                                  |
//+------------------------------------------------------------------+
double GetFactorCacheHitRate() {
    if(!g_metricsInitialized) return 0.0;
    
    int totalAccesses = g_performanceMetrics.factorCacheHits + g_performanceMetrics.factorCacheMisses;
    if(totalAccesses <= 0) return 0.0;
    
    return ((double)g_performanceMetrics.factorCacheHits / (double)totalAccesses) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Zone Creation Success Rate                             |
//| Returns: Success rate as percentage (0-100)                      |
//+------------------------------------------------------------------+
double GetZoneCreationSuccessRate() {
    if(!g_metricsInitialized) return 0.0;
    
    if(g_performanceMetrics.zoneCreationAttempts <= 0) return 0.0;
    
    return ((double)g_performanceMetrics.zoneCreationSuccesses / 
            (double)g_performanceMetrics.zoneCreationAttempts) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Throttling Effectiveness                               |
//| Returns: Percentage of calls skipped by throttling (0-100)       |
//+------------------------------------------------------------------+
double GetThrottlingEffectiveness() {
    if(!g_metricsInitialized) return 0.0;
    
    if(g_performanceMetrics.onCalculateCalls <= 0) return 0.0;
    
    return ((double)g_performanceMetrics.skippedCalls / 
            (double)g_performanceMetrics.onCalculateCalls) * 100.0;
}

//+------------------------------------------------------------------+
//| Log Performance Metrics Summary                                  |
//| Requirements: 20.5, 20.6                                         |
//+------------------------------------------------------------------+
void LogPerformanceMetrics() {
    if(!g_metricsEnabled || !g_metricsInitialized) return;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  PERFORMANCE METRICS SUMMARY                                  ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    
    // OnCalculate metrics
    Print("║  OnCalculate Metrics:                                         ║");
    Print("║    Total Calls: ", g_performanceMetrics.onCalculateCalls, 
          " (Skipped: ", g_performanceMetrics.skippedCalls, ")");
    Print("║    Throttling: ", DoubleToString(GetThrottlingEffectiveness(), 1), "%");
    Print("║    Avg Execution: ", DoubleToString(GetAverageExecutionTime(), 2), " ms");
    Print("║    Min/Max: ", g_performanceMetrics.minExecutionTimeMs, " / ", 
          g_performanceMetrics.maxExecutionTimeMs, " ms");
    
    // Cache metrics
    Print("║  Cache Performance:                                           ║");
    Print("║    TH Cache: ", g_performanceMetrics.thCacheHits, " hits, ", 
          g_performanceMetrics.thCacheMisses, " misses (", 
          DoubleToString(GetTHCacheHitRate(), 1), "%)");
    Print("║    Factor Cache: ", g_performanceMetrics.factorCacheHits, " hits, ", 
          g_performanceMetrics.factorCacheMisses, " misses (", 
          DoubleToString(GetFactorCacheHitRate(), 1), "%)");
    Print("║    Geometry Cache: ", g_performanceMetrics.geometryCacheHits, " hits, ", 
          g_performanceMetrics.geometryCacheMisses, " misses");
    Print("║    Extension Cache: ", g_performanceMetrics.extensionCacheHits, " hits, ", 
          g_performanceMetrics.extensionCacheMisses, " misses");
    
    // API call metrics
    Print("║  API Calls:                                                   ║");
    Print("║    ObjectFind: ", g_performanceMetrics.objectFindCalls);
    Print("║    ObjectCreate: ", g_performanceMetrics.objectCreateCalls);
    Print("║    ObjectDelete: ", g_performanceMetrics.objectDeleteCalls);
    Print("║    ObjectSet: ", g_performanceMetrics.objectSetCalls);
    Print("║    ChartRedraw: ", g_performanceMetrics.chartRedrawCalls);
    
    // Zone operation metrics
    Print("║  Zone Operations:                                             ║");
    Print("║    Creation Attempts: ", g_performanceMetrics.zoneCreationAttempts);
    Print("║    Successes: ", g_performanceMetrics.zoneCreationSuccesses, 
          " (", DoubleToString(GetZoneCreationSuccessRate(), 1), "%)");
    Print("║    Failures: ", g_performanceMetrics.zoneCreationFailures);
    Print("║    Updates: ", g_performanceMetrics.zoneUpdateOperations);
    
    // Collection period
    datetime now = TimeCurrent();
    int collectionSeconds = (int)(now - g_performanceMetrics.collectionStart);
    Print("║  Collection Period: ", collectionSeconds, " seconds");
    
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
}

//+------------------------------------------------------------------+
//| Get Metrics Structure                                            |
//| Returns: Copy of current metrics for external analysis           |
//+------------------------------------------------------------------+
SPerformanceMetrics GetPerformanceMetrics() {
    return g_performanceMetrics;
}

//+------------------------------------------------------------------+
//| Check if Optimization is Effective                               |
//| Returns: true if metrics show good optimization                  |
//| Requirements: 20.6                                               |
//+------------------------------------------------------------------+
bool IsOptimizationEffective() {
    if(!g_metricsInitialized) return false;
    
    // Check if we have enough data
    if(g_performanceMetrics.onCalculateCalls < 50) return true;  // Not enough data yet
    
    // Target: Average execution time < 10ms
    double avgTime = GetAverageExecutionTime();
    bool timeTarget = (avgTime < 10.0);
    
    // Target: TH cache hit rate > 90%
    double thHitRate = GetTHCacheHitRate();
    bool cacheTarget = (thHitRate > 90.0 || g_performanceMetrics.thCacheHits + g_performanceMetrics.thCacheMisses < 10);
    
    // Target: Zone creation success rate = 100% (or close)
    double successRate = GetZoneCreationSuccessRate();
    bool successTarget = (successRate > 95.0 || g_performanceMetrics.zoneCreationAttempts < 5);
    
    return timeTarget && cacheTarget && successTarget;
}

//+------------------------------------------------------------------+
//| Export Metrics to String                                         |
//| Returns: Formatted string with all metrics                       |
//+------------------------------------------------------------------+
string ExportMetricsToString() {
    if(!g_metricsInitialized) return "Metrics not initialized";
    
    string output = "";
    output += "OnCalculate: " + IntegerToString(g_performanceMetrics.onCalculateCalls) + " calls\n";
    output += "Skipped: " + IntegerToString(g_performanceMetrics.skippedCalls) + " (" + 
              DoubleToString(GetThrottlingEffectiveness(), 1) + "%)\n";
    output += "Avg Time: " + DoubleToString(GetAverageExecutionTime(), 2) + " ms\n";
    output += "TH Cache: " + DoubleToString(GetTHCacheHitRate(), 1) + "% hit rate\n";
    output += "Factor Cache: " + DoubleToString(GetFactorCacheHitRate(), 1) + "% hit rate\n";
    output += "Zone Success: " + DoubleToString(GetZoneCreationSuccessRate(), 1) + "%\n";
    output += "ObjectFind Calls: " + IntegerToString(g_performanceMetrics.objectFindCalls) + "\n";
    
    return output;
}

//+------------------------------------------------------------------+
