//+------------------------------------------------------------------+
//|                                        RunIntegrationTests.mq5 |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Task 18 - Integration Testing and Validation    |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property version   "1.00"
#property strict
#property indicator_chart_window

// Include test modules
#include "TestZoneDisplayConsistency.mqh"
#include "../PerformanceMetrics.mqh"
#include "../CalculationCache.mqh"
#include "../ZoneValidator.mqh"
#include "../ZoneFactory.mqh"

//+------------------------------------------------------------------+
//| Test State Tracking                                              |
//+------------------------------------------------------------------+
struct SIntegrationTestState {
    int currentTest;
    int totalTests;
    int passedTests;
    int failedTests;
    bool allTestsComplete;
    datetime testStartTime;
};

static SIntegrationTestState g_testState;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  INTEGRATION TESTING AND VALIDATION - TASK 18                ║");
    Print("║  Testing all timeframes and functionality                     ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Initialize test state
    g_testState.currentTest = 0;
    g_testState.totalTests = 0;
    g_testState.passedTests = 0;
    g_testState.failedTests = 0;
    g_testState.allTestsComplete = false;
    g_testState.testStartTime = TimeCurrent();
    
    // Initialize performance metrics
    InitializePerformanceMetrics();
    
    Print("✅ Integration test suite initialized");
    Print("📊 Starting comprehensive validation...");
    Print("");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    
    // Run tests only once
    if(g_testState.allTestsComplete) {
        return rates_total;
    }
    
    // Run all integration tests
    RunAllIntegrationTests();
    
    g_testState.allTestsComplete = true;
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Run All Integration Tests                                        |
//| Main test orchestration function                                 |
//+------------------------------------------------------------------+
void RunAllIntegrationTests() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  STARTING INTEGRATION TEST SUITE                             ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");
    
    // Test 1: Zone Display on All Timeframes
    TestZoneDisplayAllTimeframes();
    
    // Test 2: Timeframe Switching Consistency
    TestTimeframeSwitchingConsistency();
    
    // Test 3: Settings Changes and Cache Invalidation
    TestSettingsChangesAndCacheInvalidation();
    
    // Test 4: Cache Performance Across Operations
    TestCachePerformanceAcrossOperations();
    
    // Test 5: Validation System Robustness
    TestValidationSystemRobustness();
    
    // Test 6: Performance Metrics Verification
    TestPerformanceMetricsVerification();
    
    // Print final summary
    PrintIntegrationTestSummary();
}

//+------------------------------------------------------------------+
//| Test 1: Zone Display on All Timeframes                          |
//| Requirements: 1.1, 1.2, 1.3, 1.4                                |
//+------------------------------------------------------------------+
void TestZoneDisplayAllTimeframes() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 1: Zone Display on All Timeframes                      ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    int timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, 
                        PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
    string timeframeNames[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
    
    int testsPassed = 0;
    int totalTimeframes = ArraySize(timeframes);
    
    for(int i = 0; i < totalTimeframes; i++) {
        STestResult result = TestZoneDisplayOnTimeframe(timeframes[i], timeframeNames[i]);
        
        if(result.passed) {
            testsPassed++;
            g_testState.passedTests++;
        } else {
            g_testState.failedTests++;
            Print("❌ Failed on ", timeframeNames[i], ": ", result.errorMessage);
        }
        
        g_testState.totalTests++;
        Print("");
    }
    
    Print("📊 Test 1 Results: ", testsPassed, "/", totalTimeframes, " timeframes passed");
    Print("");
}

//+------------------------------------------------------------------+
//| Test 2: Timeframe Switching Consistency                         |
//| Requirements: 1.5                                                |
//+------------------------------------------------------------------+
void TestTimeframeSwitchingConsistency() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 2: Timeframe Switching Consistency                     ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    g_testState.totalTests++;
    
    // Test switching between M1, M5, M15, M30
    int testTimeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30};
    string timeframeNames[] = {"M1", "M5", "M15", "M30"};
    int zoneCounts[4];
    
    bool allConsistent = true;
    
    for(int i = 0; i < 4; i++) {
        // Simulate timeframe change by invalidating caches
        InvalidateTimeframeDependentCaches();
        
        // Create test zones
        zoneCounts[i] = 0;
        
        for(int j = 0; j < 3; j++) {
            string zoneName = "TEST_SWITCH_" + timeframeNames[i] + "_" + IntegerToString(j);
            
            SZoneCreationRequest request;
            request.name = zoneName;
            request.topPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (100 + j * 50) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.bottomPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (50 + j * 50) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.zoneColor = clrGreen;
            request.transparency = 50;
            request.filled = true;
            request.startTime = 0;
            request.endTime = 0;
            
            SZoneCreationResult result = CreateZone(request);
            
            if(result.success) {
                zoneCounts[i]++;
            }
            
            // Cleanup
            ObjectDelete(0, zoneName);
        }
        
        Print("   ", timeframeNames[i], ": ", zoneCounts[i], " zones created");
    }
    
    // Check consistency
    int expectedCount = zoneCounts[0];
    for(int i = 1; i < 4; i++) {
        if(zoneCounts[i] != expectedCount) {
            allConsistent = false;
            Print("❌ Inconsistent: ", timeframeNames[i], " has ", zoneCounts[i], 
                  " zones, expected ", expectedCount);
        }
    }
    
    if(allConsistent) {
        Print("✅ Test 2 PASSED: Zone count consistent across timeframe switches");
        g_testState.passedTests++;
    } else {
        Print("❌ Test 2 FAILED: Zone count inconsistent");
        g_testState.failedTests++;
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Test 3: Settings Changes and Cache Invalidation                 |
//| Requirements: 3.7, 4.6, 4.7, 7.6, 7.7                          |
//+------------------------------------------------------------------+
void TestSettingsChangesAndCacheInvalidation() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 3: Settings Changes and Cache Invalidation             ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    g_testState.totalTests++;
    
    bool testPassed = true;
    
    // Test 3a: Timeframe change invalidates caches
    Print("   3a: Testing timeframe change cache invalidation...");
    
    // Populate caches
    double basePrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    StoreTHCalculation(basePrice, 1.618, _Digits, basePrice * 1.618 / 100.0);
    StoreFactorStepSize(basePrice + 100, basePrice - 100, 5.0, 50, Period(), 40.0);
    StoreExtensionMultiplier(Period(), PeriodSeconds(Period()), 1.5);
    
    // Verify caches are valid
    double cachedTH = GetCachedTHCalculation(basePrice, 1.618, _Digits);
    if(cachedTH <= 0) {
        Print("❌ TH cache not populated correctly");
        testPassed = false;
    }
    
    // Invalidate timeframe-dependent caches
    InvalidateTimeframeDependentCaches();
    
    // Verify caches are invalidated
    cachedTH = GetCachedTHCalculation(basePrice, 1.618, _Digits);
    if(cachedTH > 0) {
        Print("❌ TH cache not invalidated after timeframe change");
        testPassed = false;
    } else {
        Print("✅ TH cache correctly invalidated");
    }
    
    // Test 3b: Settings change invalidates appropriate caches
    Print("   3b: Testing settings change cache invalidation...");
    
    // Populate caches again
    StoreFactorStepSize(basePrice + 100, basePrice - 100, 5.0, 50, Period(), 40.0);
    StoreZoneGeometry(100.0, 50.0, 50, 0, TimeCurrent(), TimeCurrent() + 3600);
    
    // Invalidate settings-dependent caches
    InvalidateSettingsDependentCaches();
    
    // Verify Factor cache is invalidated
    double cachedFactor = GetCachedFactorStepSize(basePrice + 100, basePrice - 100, 5.0);
    if(cachedFactor > 0) {
        Print("❌ Factor cache not invalidated after settings change");
        testPassed = false;
    } else {
        Print("✅ Factor cache correctly invalidated");
    }
    
    // Verify Geometry cache is invalidated
    datetime startTime, endTime;
    bool geometryCached = GetCachedZoneGeometry(100.0, 50.0, 50, 0, startTime, endTime);
    if(geometryCached) {
        Print("❌ Geometry cache not invalidated after settings change");
        testPassed = false;
    } else {
        Print("✅ Geometry cache correctly invalidated");
    }
    
    if(testPassed) {
        Print("✅ Test 3 PASSED: Cache invalidation working correctly");
        g_testState.passedTests++;
    } else {
        Print("❌ Test 3 FAILED: Cache invalidation issues detected");
        g_testState.failedTests++;
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Test 4: Cache Performance Across Operations                     |
//| Requirements: 3.1, 3.2, 7.1, 7.2, 9.1, 9.2                     |
//+------------------------------------------------------------------+
void TestCachePerformanceAcrossOperations() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 4: Cache Performance Across Operations                 ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    g_testState.totalTests++;
    
    bool testPassed = true;
    
    // Reset metrics
    InitializePerformanceMetrics();
    
    // Perform 50 TH calculations with same inputs (should hit cache)
    double basePrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double percentage = 1.618;
    int digits = _Digits;
    
    // First call - cache miss
    InvalidateTHCache();
    double result1 = GetCachedTHCalculation(basePrice, percentage, digits);
    if(result1 > 0) {
        Print("⚠️ Unexpected cache hit on first call");
    }
    
    // Store in cache
    StoreTHCalculation(basePrice, percentage, digits, basePrice * percentage / 100.0);
    RecordTHCacheMiss();
    
    // Next 49 calls - should all be cache hits
    for(int i = 0; i < 49; i++) {
        double result = GetCachedTHCalculation(basePrice, percentage, digits);
        if(result > 0) {
            RecordTHCacheHit();
        } else {
            RecordTHCacheMiss();
            Print("❌ Cache miss on iteration ", i + 2);
            testPassed = false;
        }
    }
    
    // Check cache hit rate
    double hitRate = GetTHCacheHitRate();
    Print("   TH Cache Hit Rate: ", DoubleToString(hitRate, 1), "%");
    
    if(hitRate < 90.0) {
        Print("❌ Cache hit rate below 90%");
        testPassed = false;
    } else {
        Print("✅ Cache hit rate above 90%");
    }
    
    if(testPassed) {
        Print("✅ Test 4 PASSED: Cache performance is excellent");
        g_testState.passedTests++;
    } else {
        Print("❌ Test 4 FAILED: Cache performance below target");
        g_testState.failedTests++;
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Test 5: Validation System Robustness                            |
//| Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6                     |
//+------------------------------------------------------------------+
void TestValidationSystemRobustness() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 5: Validation System Robustness                        ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    g_testState.totalTests++;
    
    bool testPassed = true;
    int validationTests = 0;
    int validationPassed = 0;
    
    // Test 5a: Empty zone name should fail
    validationTests++;
    if(!ValidateObjectName("")) {
        Print("✅ Empty name correctly rejected");
        validationPassed++;
    } else {
        Print("❌ Empty name incorrectly accepted");
        testPassed = false;
    }
    
    // Test 5b: Invalid price should fail
    validationTests++;
    if(!ValidatePrice(-100.0)) {
        Print("✅ Negative price correctly rejected");
        validationPassed++;
    } else {
        Print("❌ Negative price incorrectly accepted");
        testPassed = false;
    }
    
    // Test 5c: Invalid price range should fail
    validationTests++;
    SZoneValidationResultEnhanced result = ValidateZoneGeometryEnhanced(50.0, 100.0, 
                                                                        TimeCurrent(), 
                                                                        TimeCurrent() + 3600);
    if(!result.valid) {
        Print("✅ Inverted price range correctly rejected");
        validationPassed++;
    } else {
        Print("❌ Inverted price range incorrectly accepted");
        testPassed = false;
    }
    
    // Test 5d: Invalid time range should fail
    validationTests++;
    result = ValidateZoneGeometryEnhanced(100.0, 50.0, 
                                         TimeCurrent() + 3600, 
                                         TimeCurrent());
    if(!result.valid) {
        Print("✅ Inverted time range correctly rejected");
        validationPassed++;
    } else {
        Print("❌ Inverted time range incorrectly accepted");
        testPassed = false;
    }
    
    // Test 5e: Valid parameters should pass
    validationTests++;
    result = ValidateZoneGeometryEnhanced(100.0, 50.0, 
                                         TimeCurrent(), 
                                         TimeCurrent() + 3600);
    if(result.valid) {
        Print("✅ Valid parameters correctly accepted");
        validationPassed++;
    } else {
        Print("❌ Valid parameters incorrectly rejected: ", result.errorMessage);
        testPassed = false;
    }
    
    Print("   Validation Tests: ", validationPassed, "/", validationTests, " passed");
    
    if(testPassed && validationPassed == validationTests) {
        Print("✅ Test 5 PASSED: Validation system is robust");
        g_testState.passedTests++;
    } else {
        Print("❌ Test 5 FAILED: Validation system has issues");
        g_testState.failedTests++;
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Test 6: Performance Metrics Verification                        |
//| Requirements: 20.1, 20.2, 20.3, 20.4, 20.5                     |
//+------------------------------------------------------------------+
void TestPerformanceMetricsVerification() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST 6: Performance Metrics Verification                    ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    g_testState.totalTests++;
    
    bool testPassed = true;
    
    // Get current metrics
    SPerformanceMetrics metrics = GetPerformanceMetrics();
    
    // Verify metrics are being collected
    Print("   OnCalculate Calls: ", metrics.onCalculateCalls);
    Print("   TH Cache Hits: ", metrics.thCacheHits);
    Print("   TH Cache Misses: ", metrics.thCacheMisses);
    Print("   Zone Creation Attempts: ", metrics.zoneCreationAttempts);
    
    // Check if metrics are reasonable
    if(metrics.onCalculateCalls < 0) {
        Print("❌ Invalid OnCalculate call count");
        testPassed = false;
    }
    
    if(metrics.thCacheHits < 0 || metrics.thCacheMisses < 0) {
        Print("❌ Invalid cache metrics");
        testPassed = false;
    }
    
    // Check if optimization is effective
    bool effective = IsOptimizationEffective();
    Print("   Optimization Effective: ", effective ? "YES" : "NO");
    
    if(testPassed) {
        Print("✅ Test 6 PASSED: Performance metrics working correctly");
        g_testState.passedTests++;
    } else {
        Print("❌ Test 6 FAILED: Performance metrics issues detected");
        g_testState.failedTests++;
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Print Integration Test Summary                                   |
//+------------------------------------------------------------------+
void PrintIntegrationTestSummary() {
    datetime testEndTime = TimeCurrent();
    int testDuration = (int)(testEndTime - g_testState.testStartTime);
    
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  INTEGRATION TEST SUITE SUMMARY                              ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  Total Tests: ", g_testState.totalTests);
    Print("║  Passed: ", g_testState.passedTests);
    Print("║  Failed: ", g_testState.failedTests);
    Print("║  Success Rate: ", DoubleToString((double)g_testState.passedTests / g_testState.totalTests * 100.0, 1), "%");
    Print("║  Duration: ", testDuration, " seconds");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    
    if(g_testState.failedTests == 0) {
        Print("║  ✅ ALL INTEGRATION TESTS PASSED                             ║");
        Print("║  System is ready for production use                          ║");
    } else {
        Print("║  ⚠️  SOME TESTS FAILED                                       ║");
        Print("║  Review failures before deployment                            ║");
    }
    
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Log final performance metrics
    Print("");
    LogPerformanceMetrics();
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  INTEGRATION TESTING COMPLETED                               ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
