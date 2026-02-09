//+------------------------------------------------------------------+
//|                                      TestCheckpoint14Runner.mq4  |
//|                                      Biotak Trigger TH3 Indicator |
//|                    Test Runner for Checkpoint 14                  |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property version   "1.00"
#property strict
#property indicator_chart_window

// Include build configuration first
#include "Biotak/BuildConfig.mqh"

// Include required dependencies
#include "Biotak/PropertiesAndInputs.mqh"
#include "Biotak/ConstantsAndEnums.mqh"
#include "Biotak/PerformanceOptimizations.mqh"
#include "Biotak/GlobalVariables.mqh"

// Include test files
#include "Biotak/Tests/TestCoreSystemsCheckpoint.mqh"
#include "Biotak/Tests/TestIntegratedOptimizations.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("");
    Print("========================================================");
    Print("= CHECKPOINT 14 TEST RUNNER                            =");
    Print("= Testing All Optimizations Work Together              =");
    Print("========================================================");
    Print("");
    
    bool checkpoint5Passed = false;
    bool checkpoint14Passed = false;
    
    // Run Checkpoint 5 tests (core systems)
    Print("Running Checkpoint 5 Tests (Core Systems)...");
    checkpoint5Passed = RunCheckpoint5Tests();
    
    Print("");
    Print("--------------------------------------------------------");
    Print("");
    
    // Run Checkpoint 14 tests (integrated optimizations)
    Print("Running Checkpoint 14 Tests (Integrated Optimizations)...");
    checkpoint14Passed = RunCheckpoint14Tests();
    
    Print("");
    Print("========================================================");
    Print("= FINAL RESULTS                                        =");
    Print("========================================================");
    Print("Checkpoint 5 (Core Systems):        ", checkpoint5Passed ? "PASSED ✓" : "FAILED ✗");
    Print("Checkpoint 14 (Integration):        ", checkpoint14Passed ? "PASSED ✓" : "FAILED ✗");
    Print("========================================================");
    
    if(checkpoint5Passed && checkpoint14Passed) {
        Print("= ALL TESTS PASSED ✓                                   =");
        Print("= All optimizations work together correctly           =");
    } else {
        Print("= SOME TESTS FAILED ✗                                  =");
        Print("= Review failures above                                =");
    }
    Print("========================================================");
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
                const int &spread[])
{
    // No calculation needed for test runner
    return(rates_total);
}
//+------------------------------------------------------------------+
