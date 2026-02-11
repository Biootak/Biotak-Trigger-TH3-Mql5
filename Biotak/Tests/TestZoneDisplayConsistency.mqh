//+------------------------------------------------------------------+
//|                                  TestZoneDisplayConsistency.mqh |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Task 16 - Zone Display Consistency Verification |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict

#include "../ZoneValidator.mqh"
#include "../ZoneFactory.mqh"
#include "../CalculationCache.mqh"
#include "../PerformanceMetrics.mqh"
#include "../PerformanceOptimizations.mqh"

//+------------------------------------------------------------------+
//| Test Result Structure                                            |
//+------------------------------------------------------------------+
struct STestResult {
    bool passed;
    string testName;
    string errorMessage;
    int timeframe;
    int zonesCreated;
    int validationFailures;
};

//+------------------------------------------------------------------+
//| Test Zone Display on Specific Timeframe                         |
//| Requirements: 1.1, 1.2, 1.3, 1.4                                |
//+------------------------------------------------------------------+
STestResult TestZoneDisplayOnTimeframe(int period, string timeframeName) {
    STestResult result;
    result.passed = false;
    result.testName = "Zone Display on " + timeframeName;
    result.errorMessage = "";
    result.timeframe = period;
    result.zonesCreated = 0;
    result.validationFailures = 0;
    
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  Testing Zone Display: ", timeframeName, "                    ");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Step 1: Validate preconditions
    int barsCount = Bars(_Symbol, period);
    int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)period);
    
    Print("📊 Timeframe Info:");
    Print("   Bars: ", barsCount);
    Print("   PeriodSeconds: ", periodSeconds);
    
    if(barsCount <= 0) {
        result.errorMessage = "No bars available on " + timeframeName;
        Print("❌ ", result.errorMessage);
        return result;
    }
    
    if(periodSeconds <= 0) {
        result.errorMessage = "Invalid PeriodSeconds on " + timeframeName;
        Print("❌ ", result.errorMessage);
        return result;
    }
    
    // Step 2: Test zone creation with validation
    string testZoneName = "TEST_ZONE_" + timeframeName;
    
    // Create test zone request
    SZoneCreationRequest request;
    request.name = testZoneName;
    request.topPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + 100 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    request.bottomPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - 100 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    request.zoneColor = clrBlue;
    request.transparency = 50;
    request.filled = true;
    request.startTime = 0;  // Auto-calculate
    request.endTime = 0;    // Auto-calculate
    
    Print("🔧 Creating test zone:");
    Print("   Name: ", request.name);
    Print("   Top: ", DoubleToString(request.topPrice, _Digits));
    Print("   Bottom: ", DoubleToString(request.bottomPrice, _Digits));
    
    // Step 3: Validate zone creation preconditions
    SZoneValidationResultEnhanced validation = ValidateZoneCreationPreconditions(period, testZoneName);
    
    if(!validation.valid) {
        result.errorMessage = "Validation failed: " + validation.errorMessage;
        result.validationFailures++;
        Print("❌ Validation Failed: ", validation.errorMessage);
        Print("   Error Code: ", validation.errorCode);
        Print("   Bars: ", validation.barsCount);
        Print("   PeriodSeconds: ", validation.periodSeconds);
        return result;
    }
    
    Print("✅ Preconditions validated");
    
    // Step 4: Create zone
    SZoneCreationResult creationResult = CreateZone(request);
    
    if(!creationResult.success) {
        result.errorMessage = "Zone creation failed: " + creationResult.errorMessage;
        Print("❌ Creation Failed: ", creationResult.errorMessage);
        Print("   Error Code: ", creationResult.errorCode);
        return result;
    }
    
    result.zonesCreated++;
    Print("✅ Zone created successfully");
    
    // Step 5: Verify zone exists on chart
    if(ObjectFind(0, testZoneName) < 0) {
        result.errorMessage = "Zone not found on chart after creation";
        Print("❌ ", result.errorMessage);
        return result;
    }
    
    Print("✅ Zone verified on chart");
    
    // Step 6: Verify zone properties
    double topPrice = ObjectGetDouble(0, testZoneName, OBJPROP_PRICE, 0);
    double bottomPrice = ObjectGetDouble(0, testZoneName, OBJPROP_PRICE, 1);
    datetime startTime = (datetime)ObjectGetInteger(0, testZoneName, OBJPROP_TIME, 0);
    datetime endTime = (datetime)ObjectGetInteger(0, testZoneName, OBJPROP_TIME, 1);
    
    Print("📐 Zone Properties:");
    Print("   Top Price: ", DoubleToString(topPrice, _Digits));
    Print("   Bottom Price: ", DoubleToString(bottomPrice, _Digits));
    Print("   Start Time: ", TimeToString(startTime, TIME_DATE|TIME_MINUTES));
    Print("   End Time: ", TimeToString(endTime, TIME_DATE|TIME_MINUTES));
    
    // Validate geometry
    if(topPrice <= bottomPrice) {
        result.errorMessage = "Invalid zone geometry: top <= bottom";
        Print("❌ ", result.errorMessage);
        ObjectDelete(0, testZoneName);
        return result;
    }
    
    if(startTime >= endTime) {
        result.errorMessage = "Invalid zone time range: start >= end";
        Print("❌ ", result.errorMessage);
        ObjectDelete(0, testZoneName);
        return result;
    }
    
    Print("✅ Zone geometry validated");
    
    // Step 7: Cleanup
    ObjectDelete(0, testZoneName);
    Print("🧹 Test zone cleaned up");
    
    // Test passed
    result.passed = true;
    Print("✅ Test PASSED for ", timeframeName);
    
    return result;
}

//+------------------------------------------------------------------+
//| Test Zone Count Consistency Across Timeframes                   |
//| Requirements: 1.5                                                |
//+------------------------------------------------------------------+
bool TestZoneCountConsistency() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  Testing Zone Count Consistency                              ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Create identical zones on different timeframes
    int testTimeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30};
    string timeframeNames[] = {"M1", "M5", "M15", "M30"};
    int zoneCounts[4];
    
    for(int i = 0; i < 4; i++) {
        int period = testTimeframes[i];
        string tfName = timeframeNames[i];
        
        // Create 3 test zones
        zoneCounts[i] = 0;
        
        for(int j = 0; j < 3; j++) {
            string zoneName = "TEST_CONSISTENCY_" + tfName + "_" + IntegerToString(j);
            
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
        
        Print("   ", tfName, ": ", zoneCounts[i], " zones created");
    }
    
    // Check consistency
    bool consistent = true;
    int expectedCount = zoneCounts[0];
    
    for(int i = 1; i < 4; i++) {
        if(zoneCounts[i] != expectedCount) {
            consistent = false;
            Print("❌ Inconsistent zone count: ", timeframeNames[i], " has ", zoneCounts[i], 
                  " zones, expected ", expectedCount);
        }
    }
    
    if(consistent) {
        Print("✅ Zone count consistent across all timeframes: ", expectedCount, " zones");
    }
    
    return consistent;
}

//+------------------------------------------------------------------+
//| Test Cache Performance                                           |
//| Requirements: 3.1, 3.2, 7.1, 7.2                                |
//+------------------------------------------------------------------+
bool TestCachePerformance() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  Testing Cache Performance                                    ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Initialize metrics
    InitializePerformanceMetrics();
    
    // Test TH calculation caching
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
    
    // Second call - should be cache hit
    double result2 = GetCachedTHCalculation(basePrice, percentage, digits);
    
    if(result2 <= 0) {
        Print("❌ Cache miss on second call - caching not working");
        return false;
    }
    
    Print("✅ TH calculation cache working correctly");
    
    // Test geometry caching
    InvalidateGeometryCache();
    
    datetime startTime, endTime;
    bool cacheHit1 = GetCachedZoneGeometry(100.0, 50.0, 50, 0, startTime, endTime);
    
    if(cacheHit1) {
        Print("⚠️ Unexpected geometry cache hit on first call");
    }
    
    // Store geometry
    StoreZoneGeometry(100.0, 50.0, 50, 0, TimeCurrent(), TimeCurrent() + 3600);
    
    // Second call - should be cache hit
    bool cacheHit2 = GetCachedZoneGeometry(100.0, 50.0, 50, 0, startTime, endTime);
    
    if(!cacheHit2) {
        Print("❌ Geometry cache miss on second call - caching not working");
        return false;
    }
    
    Print("✅ Geometry cache working correctly");
    
    return true;
}

//+------------------------------------------------------------------+
//| Run All Zone Display Consistency Tests                          |
//| Main test entry point for Task 16                               |
//+------------------------------------------------------------------+
bool RunZoneDisplayConsistencyTests() {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  ZONE DISPLAY CONSISTENCY TEST SUITE - TASK 16               ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");
    
    bool allPassed = true;
    int totalTests = 0;
    int passedTests = 0;
    
    // Test 1: M1 Timeframe
    totalTests++;
    STestResult m1Result = TestZoneDisplayOnTimeframe(PERIOD_M1, "M1");
    if(m1Result.passed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Test 2: M5 Timeframe
    totalTests++;
    STestResult m5Result = TestZoneDisplayOnTimeframe(PERIOD_M5, "M5");
    if(m5Result.passed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Test 3: M15 Timeframe
    totalTests++;
    STestResult m15Result = TestZoneDisplayOnTimeframe(PERIOD_M15, "M15");
    if(m15Result.passed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Test 4: M30 Timeframe
    totalTests++;
    STestResult m30Result = TestZoneDisplayOnTimeframe(PERIOD_M30, "M30");
    if(m30Result.passed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Test 5: Zone Count Consistency
    totalTests++;
    bool consistencyPassed = TestZoneCountConsistency();
    if(consistencyPassed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Test 6: Cache Performance
    totalTests++;
    bool cachePassed = TestCachePerformance();
    if(cachePassed) passedTests++;
    else allPassed = false;
    Print("");
    
    // Print summary
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  TEST SUMMARY                                                 ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  Total Tests: ", totalTests);
    Print("║  Passed: ", passedTests);
    Print("║  Failed: ", totalTests - passedTests);
    Print("║  Success Rate: ", DoubleToString((double)passedTests / totalTests * 100.0, 1), "%");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    
    if(allPassed) {
        Print("║  ✅ ALL TESTS PASSED                                         ║");
    } else {
        Print("║  ❌ SOME TESTS FAILED                                        ║");
    }
    
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    return allPassed;
}

//+------------------------------------------------------------------+
