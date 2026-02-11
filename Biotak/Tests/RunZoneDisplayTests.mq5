//+------------------------------------------------------------------+
//|                                       RunZoneDisplayTests.mq5    |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Task 16 - Zone Display Consistency Test Runner |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property version   "1.00"
#property strict
#property script_show_inputs

// Include MQL5 compatibility layer
#include "../MQL5Compat.mqh"
#include "../BuildConfig.mqh"
#include "../ConstantsAndEnums.mqh"
#include "../ZoneConstants.mqh"
#include "../FloatingPointHelper.mqh"
#include "../MathConstants.mqh"
#include "../PerformanceOptimizations.mqh"
#include "../CalculationCache.mqh"
#include "../ZoneValidator.mqh"
#include "../ObjectCache.mqh"
#include "../PropertyChangeDetector.mqh"
#include "../VisibilityManager.mqh"
#include "../ZoneFactory.mqh"
#include "../PerformanceMetrics.mqh"

// Include test suite
#include "TestZoneDisplayConsistency.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  BIOTAK TRIGGER TH3 - ZONE DISPLAY CONSISTENCY TESTS         ║");
    Print("║  Task 16 Checkpoint Verification                             ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");
    Print("Symbol: ", _Symbol);
    Print("Current Timeframe: ", EnumToString((ENUM_TIMEFRAMES)_Period));
    Print("Current Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
    Print("");
    
    // Initialize caches
    InitializeCachedValues();
    InitializePerformanceMetrics();
    InitializeObjectCache();
    
    Print("✅ Test environment initialized");
    Print("");
    
    // Run test suite
    bool allTestsPassed = RunZoneDisplayConsistencyTests();
    
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════╗");
    
    if(allTestsPassed) {
        Print("║  ✅ TASK 16 CHECKPOINT: PASSED                               ║");
        Print("║                                                               ║");
        Print("║  Zone display is consistent across M1, M5, M15, M30          ║");
        Print("║  All validation checks passed                                ║");
        Print("║  Cache system working correctly                              ║");
    } else {
        Print("║  ❌ TASK 16 CHECKPOINT: FAILED                               ║");
        Print("║                                                               ║");
        Print("║  Some tests failed - review logs above for details           ║");
    }
    
    Print("╚═══════════════════════════════════════════════════════════════╝");
}
//+------------------------------------------------------------------+
