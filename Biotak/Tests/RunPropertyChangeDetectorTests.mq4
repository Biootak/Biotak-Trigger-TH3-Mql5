//+------------------------------------------------------------------+
//|                              RunPropertyChangeDetectorTests.mq4 |
//|                                      Biotak Trigger TH3 Indicator |
//|                         Test Runner for PropertyChangeDetector    |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict
#property indicator_chart_window

// Include test module
#include "TestPropertyChangeDetector.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    Print("========================================");
    Print("PropertyChangeDetector Test Suite");
    Print("Testing Task 8 Enhancements");
    Print("========================================");
    
    bool testsPassed = RunPropertyChangeDetectorTests();
    
    if(testsPassed) {
        Print("========================================");
        Print("SUCCESS: All PropertyChangeDetector tests passed");
        Print("Task 8 enhancements verified:");
        Print("  ✓ Epsilon-based price comparison (Req 10.1)");
        Print("  ✓ Exact comparison for color/style (Req 10.2, 10.3)");
        Print("  ✓ Short-circuit evaluation (Req 10.4)");
        Print("  ✓ Missing cache entry handling (Req 10.6)");
        Print("========================================");
    } else {
        Print("========================================");
        Print("FAILURE: Some PropertyChangeDetector tests failed");
        Print("========================================");
    }
    
    return INIT_SUCCEEDED;
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
    return rates_total;
}

//+------------------------------------------------------------------+
