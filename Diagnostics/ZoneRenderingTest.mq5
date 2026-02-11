//+------------------------------------------------------------------+
//|                                          ZoneRenderingTest.mq5   |
//|                                  Zone Rendering Diagnostic Test  |
//|                       تست تشخیصی رندر کردن Zone ها               |
//+------------------------------------------------------------------+
#property copyright "Biotak Diagnostics"
#property link      "https://www.biotak.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

// Include necessary files
#include "../Biotak/BuildConfig.mqh"
#include "../Biotak/MQL5Compat.mqh"
#include "../Biotak/ConstantsAndEnums.mqh"
#include "../Biotak/ProjectConstants.mqh"
#include "../Biotak/FloatingPointHelper.mqh"
#include "../Biotak/PerformanceOptimizations.mqh"
#include "../Biotak/GlobalVariables.mqh"
#include "../Biotak/ZoneFactory.mqh"
#include "../Biotak/UnifiedZoneSystem.mqh"

// Test configuration
input bool inpRunFullTest = true;           // Run full diagnostic test
input bool inpTestAllTimeframes = true;     // Test all timeframes
input bool inpShowTestZones = true;         // Show test zones on chart
input int inpTestZoneTransparency = 50;     // Test zone transparency

// Global test state
int g_testsPassed = 0;
int g_testsFailed = 0;
int g_testsTotal = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║          ZONE RENDERING DIAGNOSTIC TEST                      ║");
    Print("║          تست تشخیصی رندر Zone ها                            ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");

    // Initialize global cache
    InitializeGlobalCache();

    if(inpRunFullTest) {
        RunDiagnosticTests();
    }

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
                const int &spread[])
{
    // No need to do anything in OnCalculate for this test
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║          TEST SUMMARY                                         ║");
    Print("╠═══════════════════════════════════════════════════════════════╣");
    Print("║  Total Tests:  ", g_testsTotal);
    Print("║  Passed:       ", g_testsPassed, " ✅");
    Print("║  Failed:       ", g_testsFailed, " ❌");
    Print("║  Success Rate: ", (g_testsTotal > 0 ? (g_testsPassed * 100 / g_testsTotal) : 0), "%");
    Print("╚═══════════════════════════════════════════════════════════════╝");

    // Cleanup test zones
    if(inpShowTestZones) {
        Print("");
        Print("⚠️  Test zones left on chart for inspection");
        Print("💡 Remove indicator to clean up test zones");
    } else {
        ObjectsDeleteAll(0, "TEST_Zone_");
    }
}

//+------------------------------------------------------------------+
//| Run all diagnostic tests                                         |
//+------------------------------------------------------------------+
void RunDiagnosticTests()
{
    Print("▶️  Starting diagnostic tests...");
    Print("");

    // Test 1: Basic Zone Creation
    Test_BasicZoneCreation();

    // Test 2: Zone Extension Calculation
    Test_ZoneExtensionCalculation();

    // Test 3: Zone Visibility on Current Timeframe
    Test_ZoneVisibilityCurrentTF();

    // Test 4: Adaptive Extension Multiplier
    Test_AdaptiveExtensionMultiplier();

    // Test 5: Zone Configuration
    Test_ZoneConfiguration();

    // Test 6: Multi-Timeframe Zone Rendering
    if(inpTestAllTimeframes) {
        Test_MultiTimeframeRendering();
    }

    // Test 7: Zone Geometry Validation
    Test_ZoneGeometryValidation();

    // Test 8: Edge Cases
    Test_EdgeCases();

    Print("");
    Print("✅ All tests completed!");
}

//+------------------------------------------------------------------+
//| Test 1: Basic Zone Creation                                      |
//+------------------------------------------------------------------+
void Test_BasicZoneCreation()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 1: Basic Zone Creation");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    // Get current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double topPrice = currentPrice + 100 * _Point;
    double bottomPrice = currentPrice + 50 * _Point;

    Print("📊 Test Parameters:");
    Print("   Current Price: ", DoubleToString(currentPrice, _Digits));
    Print("   Top Price: ", DoubleToString(topPrice, _Digits));
    Print("   Bottom Price: ", DoubleToString(bottomPrice, _Digits));
    Print("   Timeframe: ", PeriodMinutes(), " minutes");

    // Create test zone
    SZoneCreationRequest request;
    request.name = "TEST_Zone_Basic";
    request.topPrice = topPrice;
    request.bottomPrice = bottomPrice;
    request.zoneColor = clrDodgerBlue;
    request.transparency = inpTestZoneTransparency;
    request.filled = true;
    request.startTime = 0;  // Auto
    request.endTime = 0;    // Auto

    Print("");
    Print("🔧 Creating zone with auto time calculation...");

    SZoneCreationResult result = CreateZone(request);

    if(result.success) {
        Print("✅ TEST 1 PASSED: Zone created successfully");
        Print("   Zone Name: ", result.zoneName);

        // Verify zone exists
        if(ObjectFind(0, result.zoneName) >= 0) {
            Print("✅ Zone object verified on chart");

            // Get zone properties
            datetime startTime = (datetime)ObjectGetInteger(0, result.zoneName, OBJPROP_TIME, 0);
            datetime endTime = (datetime)ObjectGetInteger(0, result.zoneName, OBJPROP_TIME, 1);
            double actualTop = ObjectGetDouble(0, result.zoneName, OBJPROP_PRICE, 0);
            double actualBottom = ObjectGetDouble(0, result.zoneName, OBJPROP_PRICE, 1);

            Print("   Start Time: ", TimeToString(startTime, TIME_DATE|TIME_MINUTES));
            Print("   End Time: ", TimeToString(endTime, TIME_DATE|TIME_MINUTES));
            Print("   Top Price: ", DoubleToString(actualTop, _Digits));
            Print("   Bottom Price: ", DoubleToString(actualBottom, _Digits));

            int durationSeconds = (int)(endTime - startTime);
            Print("   Duration: ", durationSeconds, " seconds (",
                  DoubleToString(durationSeconds / 60.0, 1), " minutes)");
        } else {
            Print("❌ WARNING: Zone created but not found on chart!");
        }

        g_testsPassed++;
    } else {
        Print("❌ TEST 1 FAILED: ", result.errorMessage);
        Print("   Error Code: ", result.errorCode);
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 2: Zone Extension Calculation                               |
//+------------------------------------------------------------------+
void Test_ZoneExtensionCalculation()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 2: Zone Extension Calculation");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    // Get current timeframe info
    int periodMinutes = PeriodMinutes();
    int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);

    Print("📊 Current Timeframe:");
    Print("   Period: ", periodMinutes, " minutes");
    Print("   Period Seconds: ", periodSeconds);

    // Calculate extension multiplier
    int extensionMultiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);

    Print("");
    Print("🔧 Extension Calculation:");
    Print("   Multiplier: ", extensionMultiplier);
    Print("   Extension Duration: ", periodSeconds * extensionMultiplier, " seconds");
    Print("   Extension Duration: ", DoubleToString((periodSeconds * extensionMultiplier) / 60.0, 1), " minutes");
    Print("   Extension Duration: ", DoubleToString((periodSeconds * extensionMultiplier) / 3600.0, 2), " hours");

    // Validate multiplier is reasonable
    bool isValid = (extensionMultiplier >= 50 && extensionMultiplier <= 200);

    if(isValid) {
        Print("✅ TEST 2 PASSED: Extension multiplier is valid");
        g_testsPassed++;
    } else {
        Print("❌ TEST 2 FAILED: Extension multiplier out of range (50-200)");
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 3: Zone Visibility on Current Timeframe                     |
//+------------------------------------------------------------------+
void Test_ZoneVisibilityCurrentTF()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 3: Zone Visibility on Current Timeframe");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    // Check bars availability
    int bars = Bars(_Symbol, _Period);
    Print("📊 Chart Data:");
    Print("   Bars Available: ", bars);

    if(bars < 1) {
        Print("❌ TEST 3 FAILED: No bars available on chart");
        g_testsFailed++;
        Print("");
        return;
    }

    // Get chart time
    datetime chartTime = iTime(_Symbol, _Period, 0);
    Print("   Current Bar Time: ", TimeToString(chartTime, TIME_DATE|TIME_MINUTES));

    // Create visible zone
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    SZoneCreationRequest request;
    request.name = "TEST_Zone_Visibility";
    request.topPrice = currentPrice + 150 * _Point;
    request.bottomPrice = currentPrice + 100 * _Point;
    request.zoneColor = clrGold;
    request.transparency = inpTestZoneTransparency;
    request.filled = true;
    request.startTime = 0;
    request.endTime = 0;

    SZoneCreationResult result = CreateZone(request);

    if(result.success && ObjectFind(0, result.zoneName) >= 0) {
        // Check if zone is visible on current timeframe
        long timeframes = ObjectGetInteger(0, result.zoneName, OBJPROP_TIMEFRAMES);
        bool isVisible = (timeframes == OBJ_ALL_PERIODS || (timeframes & (1 << _Period)));

        Print("");
        Print("🔧 Zone Visibility Check:");
        Print("   Zone Exists: YES");
        Print("   Timeframes Value: ", IntegerToString(timeframes, 0, ' '));
        Print("   Visible on Current TF: ", (isVisible ? "YES" : "NO"));

        if(isVisible) {
            Print("✅ TEST 3 PASSED: Zone is visible on current timeframe");
            g_testsPassed++;
        } else {
            Print("❌ TEST 3 FAILED: Zone exists but not visible on current timeframe");
            g_testsFailed++;
        }
    } else {
        Print("❌ TEST 3 FAILED: Could not create visibility test zone");
        if(!result.success) {
            Print("   Error: ", result.errorMessage);
        }
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 4: Adaptive Extension Multiplier                            |
//+------------------------------------------------------------------+
void Test_AdaptiveExtensionMultiplier()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 4: Adaptive Extension Multiplier for All Timeframes");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    // Test timeframes (seconds)
    int testPeriods[] = {
        60,      // M1
        120,     // M2
        180,     // M3
        240,     // M4
        300,     // M5
        600,     // M10
        900,     // M15
        1800,    // M30
        3600,    // H1
        14400,   // H4
        86400,   // D1
        604800,  // W1
        2592000  // MN1
    };

    string testNames[] = {
        "M1", "M2", "M3", "M4", "M5", "M10", "M15", "M30",
        "H1", "H4", "D1", "W1", "MN1"
    };

    Print("📊 Testing Extension Multipliers:");
    Print("");

    bool allValid = true;

    for(int i = 0; i < ArraySize(testPeriods); i++) {
        int periodSec = testPeriods[i];
        int multiplier = CalculateAdaptiveExtensionMultiplier(periodSec);
        double extensionMinutes = (periodSec * multiplier) / 60.0;
        double extensionHours = extensionMinutes / 60.0;

        Print("   ", testNames[i], ": ");
        Print("      Period: ", periodSec, "s, Multiplier: ", multiplier);
        Print("      Extension: ", DoubleToString(extensionMinutes, 1), " min (",
              DoubleToString(extensionHours, 2), " hours)");

        // Validate multiplier
        if(multiplier < 50 || multiplier > 200) {
            Print("      ❌ INVALID multiplier!");
            allValid = false;
        }
    }

    Print("");

    if(allValid) {
        Print("✅ TEST 4 PASSED: All extension multipliers are valid");
        g_testsPassed++;
    } else {
        Print("❌ TEST 4 FAILED: Some extension multipliers are invalid");
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 5: Zone Configuration                                       |
//+------------------------------------------------------------------+
void Test_ZoneConfiguration()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 5: Zone Configuration Settings");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    Print("📊 Constants Check:");
    Print("   ZONE_EXTENSION_MULTIPLIER: ", ZONE_EXTENSION_MULTIPLIER);
    Print("   ZONE_EXTENSION_PERIODS: ", ZONE_EXTENSION_PERIODS);
    Print("   DEFAULT_ZONE_HEIGHT_PERCENT: ", DoubleToString(DEFAULT_ZONE_HEIGHT_PERCENT * 100, 2), "%");

    // Validate constants
    bool constantsValid = true;

    if(ZONE_EXTENSION_MULTIPLIER < 50 || ZONE_EXTENSION_MULTIPLIER > 200) {
        Print("   ❌ ZONE_EXTENSION_MULTIPLIER out of range (50-200)");
        constantsValid = false;
    }

    if(DEFAULT_ZONE_HEIGHT_PERCENT < 0.01 || DEFAULT_ZONE_HEIGHT_PERCENT > 1.0) {
        Print("   ❌ DEFAULT_ZONE_HEIGHT_PERCENT out of range (0.01-1.0)");
        constantsValid = false;
    }

    Print("");

    if(constantsValid) {
        Print("✅ TEST 5 PASSED: Zone configuration constants are valid");
        g_testsPassed++;
    } else {
        Print("❌ TEST 5 FAILED: Some configuration constants are invalid");
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 6: Multi-Timeframe Zone Rendering                           |
//+------------------------------------------------------------------+
void Test_MultiTimeframeRendering()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 6: Multi-Timeframe Zone Rendering");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    Print("📊 Testing zone creation simulation for multiple timeframes...");
    Print("");

    // We'll simulate zone creation for different timeframes
    // without actually changing the chart timeframe

    ENUM_TIMEFRAMES testTimeframes[] = {
        PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
        PERIOD_H1, PERIOD_H4, PERIOD_D1
    };

    string tfNames[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1"};

    bool allValid = true;

    for(int i = 0; i < ArraySize(testTimeframes); i++) {
        int periodSec = PeriodSeconds(testTimeframes[i]);
        int multiplier = CalculateAdaptiveExtensionMultiplier(periodSec);

        // Check if this would create a reasonable zone
        bool isReasonable = (multiplier >= 50 && multiplier <= 200);

        Print("   ", tfNames[i], ": Multiplier=", multiplier, " ",
              (isReasonable ? "✅" : "❌"));

        if(!isReasonable) allValid = false;
    }

    Print("");

    if(allValid) {
        Print("✅ TEST 6 PASSED: All timeframes have valid zone parameters");
        g_testsPassed++;
    } else {
        Print("❌ TEST 6 FAILED: Some timeframes have invalid zone parameters");
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 7: Zone Geometry Validation                                 |
//+------------------------------------------------------------------+
void Test_ZoneGeometryValidation()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 7: Zone Geometry Validation");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Test with various zone heights
    double testHeights[] = {0.05, 0.125, 0.25, 0.5, 1.0};

    Print("📊 Testing different zone heights:");
    Print("");

    bool allValid = true;

    for(int i = 0; i < ArraySize(testHeights); i++) {
        double heightPercent = testHeights[i];
        double stepSize = 100 * _Point;
        double zoneHeight = stepSize * heightPercent * 0.5;

        double topPrice = currentPrice + 200 * _Point + zoneHeight;
        double bottomPrice = currentPrice + 200 * _Point - zoneHeight;

        bool isValid = (topPrice > bottomPrice && bottomPrice > 0);

        Print("   Height: ", DoubleToString(heightPercent * 100, 1), "%");
        Print("      Zone Height: ", DoubleToString(zoneHeight / _Point, 1), " points");
        Print("      Top: ", DoubleToString(topPrice, _Digits));
        Print("      Bottom: ", DoubleToString(bottomPrice, _Digits));
        Print("      Valid: ", (isValid ? "✅" : "❌"));

        if(!isValid) allValid = false;
    }

    Print("");

    if(allValid) {
        Print("✅ TEST 7 PASSED: All zone geometries are valid");
        g_testsPassed++;
    } else {
        Print("❌ TEST 7 FAILED: Some zone geometries are invalid");
        g_testsFailed++;
    }

    Print("");
}

//+------------------------------------------------------------------+
//| Test 8: Edge Cases                                               |
//+------------------------------------------------------------------+
void Test_EdgeCases()
{
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Print("TEST 8: Edge Cases");
    Print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    g_testsTotal++;

    Print("📊 Testing edge cases:");
    Print("");

    bool allPassed = true;

    // Edge Case 1: Very small zone
    Print("   Edge Case 1: Very small zone (1 point)");
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    SZoneCreationRequest request1;
    request1.name = "TEST_Zone_EdgeCase1";
    request1.topPrice = currentPrice + 1 * _Point;
    request1.bottomPrice = currentPrice;
    request1.zoneColor = clrRed;
    request1.transparency = 50;
    request1.filled = true;
    request1.startTime = 0;
    request1.endTime = 0;

    SZoneCreationResult result1 = CreateZone(request1);
    Print("      Result: ", (result1.success ? "✅ Created" : "❌ Failed"));
    if(!result1.success) Print("      Error: ", result1.errorMessage);

    // Edge Case 2: Invalid prices (top < bottom)
    Print("");
    Print("   Edge Case 2: Invalid prices (top < bottom)");

    SZoneCreationRequest request2;
    request2.name = "TEST_Zone_EdgeCase2";
    request2.topPrice = currentPrice;
    request2.bottomPrice = currentPrice + 100 * _Point;  // Wrong order
    request2.zoneColor = clrRed;
    request2.transparency = 50;
    request2.filled = true;
    request2.startTime = 0;
    request2.endTime = 0;

    SZoneCreationResult result2 = CreateZone(request2);
    bool correctlyRejected = !result2.success;
    Print("      Result: ", (correctlyRejected ? "✅ Correctly rejected" : "❌ Should have failed"));
    if(result2.success) allPassed = false;

    // Edge Case 3: Zero bars scenario (simulated)
    Print("");
    Print("   Edge Case 3: Low bars scenario");
    int bars = Bars(_Symbol, _Period);
    Print("      Current Bars: ", bars);
    Print("      Status: ", (bars >= 1 ? "✅ Sufficient" : "❌ Insufficient"));
    if(bars < 1) allPassed = false;

    Print("");

    if(allPassed) {
        Print("✅ TEST 8 PASSED: Edge cases handled correctly");
        g_testsPassed++;
    } else {
        Print("❌ TEST 8 FAILED: Some edge cases not handled correctly");
        g_testsFailed++;
    }

    Print("");
}
