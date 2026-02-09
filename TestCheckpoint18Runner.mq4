//+------------------------------------------------------------------+
//|                                      TestCheckpoint18Runner.mq4  |
//|                                      Biotak Trigger TH3 Indicator |
//|                    Test Runner for Checkpoint 18 (Final)          |
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

// Include all test files
#include "Biotak/Tests/TestCoreSystemsCheckpoint.mqh"
#include "Biotak/Tests/TestIntegratedOptimizations.mqh"
#include "Biotak/Tests/TestFlickeringFix.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("");
    Print("##########################################################");
    Print("# CHECKPOINT 18: FINAL VALIDATION TEST RUNNER            #");
    Print("# Complete Validation of Zone and Level Flickering Fix  #");
    Print("##########################################################");
    Print("");
    
    bool checkpoint5Passed = false;
    bool checkpoint14Passed = false;
    bool propertyTestsPassed = false;
    
    // Run Checkpoint 5 tests (core systems)
    Print("========================================================");
    Print("PHASE 1: Core Systems Validation (Checkpoint 5)");
    Print("========================================================");
    checkpoint5Passed = RunCheckpoint5Tests();
    
    Print("");
    Print("--------------------------------------------------------");
    Print("");
    
    // Run Checkpoint 14 tests (integrated optimizations)
    Print("========================================================");
    Print("PHASE 2: Integrated Optimizations (Checkpoint 14)");
    Print("========================================================");
    checkpoint14Passed = RunCheckpoint14Tests();
    
    Print("");
    Print("--------------------------------------------------------");
    Print("");
    
    // Run comprehensive property-based tests
    Print("========================================================");
    Print("PHASE 3: Comprehensive Property-Based Tests (Task 16.1)");
    Print("========================================================");
    propertyTestsPassed = RunAllPropertyTests();
    
    Print("");
    Print("##########################################################");
    Print("# FINAL VALIDATION RESULTS                               #");
    Print("##########################################################");
    Print("");
    Print("Phase 1 - Core Systems (Checkpoint 5):     ", checkpoint5Passed ? "PASSED" : "FAILED");
    Print("Phase 2 - Integration (Checkpoint 14):     ", checkpoint14Passed ? "PASSED" : "FAILED");
    Print("Phase 3 - Property Tests (Task 16.1):      ", propertyTestsPassed ? "PASSED" : "FAILED");
    Print("");
    Print("##########################################################");
    
    if(checkpoint5Passed && checkpoint14Passed && propertyTestsPassed) {
        Print("# ALL TESTS PASSED                                       #");
        Print("#                                                        #");
        Print("# Zone and Level Flickering Fix: VALIDATED              #");
        Print("#                                                        #");
        Print("# All correctness properties verified                   #");
        Print("# All optimizations work together correctly             #");
        Print("# Implementation ready for production use               #");
    } else {
        Print("# SOME TESTS FAILED                                      #");
        Print("#                                                        #");
        Print("# Review failures above for details                     #");
        Print("# Fix failing tests before production deployment        #");
    }
    Print("##########################################################");
    Print("");
    
    // Provide summary statistics
    Print("========================================================");
    Print("TEST SUMMARY STATISTICS");
    Print("========================================================");
    Print("Total Test Phases: 3");
    Print("Total Property Tests: 32");
    Print("Iterations per Property Test: 100");
    Print("Total Test Iterations: ~3,200+");
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
