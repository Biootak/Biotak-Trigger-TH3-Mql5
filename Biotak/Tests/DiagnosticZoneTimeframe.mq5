//+------------------------------------------------------------------+
//|                                    DiagnosticZoneTimeframe.mq5   |
//|                                  Diagnostic Test for Zone Display|
//|                                  Tests zone visibility on M1-M30 |
//+------------------------------------------------------------------+
#property copyright "Biotak Project"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include "../BuildConfig.mqh"
#include "../MQL5Compat.mqh"
#include "../ConstantsAndEnums.mqh"
#include "../GlobalVariables.mqh"
#include "../FloatingPointHelper.mqh"
#include "../PerformanceOptimizations.mqh"
#include "../ZoneFactory.mqh"
#include "../ZoneConstants.mqh"
#include "../CalculationCache.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("═══════════════════════════════════════════════════════════");
    Print("DIAGNOSTIC: Zone Timeframe Test Started");
    Print("═══════════════════════════════════════════════════════════");
    Print("Current Timeframe: ", Period(), " (", PeriodMinutes(), " minutes)");
    Print("Current Symbol: ", _Symbol);
    
    // Test zone creation on current timeframe
    TestZoneCreation();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Test Zone Creation                                               |
//+------------------------------------------------------------------+
void TestZoneCreation()
{
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double testZoneTop = currentPrice + 100 * _Point;
    double testZoneBottom = currentPrice - 100 * _Point;
    
    Print("───────────────────────────────────────────────────────────");
    Print("TEST: Creating diagnostic zone");
    Print("Current Price: ", DoubleToString(currentPrice, _Digits));
    Print("Zone Top: ", DoubleToString(testZoneTop, _Digits));
    Print("Zone Bottom: ", DoubleToString(testZoneBottom, _Digits));
    
    // Create zone using ZoneFactory
    SZoneCreationRequest request;
    request.name = "DIAGNOSTIC_Zone_Test";
    request.topPrice = testZoneTop;
    request.bottomPrice = testZoneBottom;
    request.zoneColor = clrYellow;
    request.transparency = 50;
    request.filled = true;
    request.startTime = 0;  // Auto-calculate
    request.endTime = 0;    // Auto-calculate
    
    SZoneCreationResult result = CreateZone(request);
    
    if(result.success) {
        Print("✅ Zone created successfully: ", result.zoneName);
        
        // Check zone properties
        if(ObjectFind(0, result.zoneName) >= 0) {
            long timeframes = ObjectGetInteger(0, result.zoneName, OBJPROP_TIMEFRAMES);
            datetime time1 = (datetime)ObjectGetInteger(0, result.zoneName, OBJPROP_TIME, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, result.zoneName, OBJPROP_TIME, 1);
            double price1 = ObjectGetDouble(0, result.zoneName, OBJPROP_PRICE, 0);
            double price2 = ObjectGetDouble(0, result.zoneName, OBJPROP_PRICE, 1);
            
            Print("Zone Properties:");
            Print("  OBJPROP_TIMEFRAMES: ", timeframes, 
                  " (OBJ_ALL_PERIODS=", OBJ_ALL_PERIODS, ", OBJ_NO_PERIODS=", OBJ_NO_PERIODS, ")");
            Print("  Time1: ", TimeToString(time1));
            Print("  Time2: ", TimeToString(time2));
            Print("  Price1: ", DoubleToString(price1, _Digits));
            Print("  Price2: ", DoubleToString(price2, _Digits));
            
            // Check if zone is visible on current timeframe
            if(timeframes == OBJ_ALL_PERIODS) {
                Print("✅ Zone is set to be visible on ALL timeframes");
            }
            else if(timeframes == OBJ_NO_PERIODS) {
                Print("❌ Zone is set to be HIDDEN on all timeframes");
            }
            else {
                Print("⚠️ Zone has custom timeframe visibility: ", timeframes);
            }
        }
        else {
            Print("❌ Zone object not found after creation!");
        }
    }
    else {
        Print("❌ Zone creation failed: ", result.errorMessage, " (Code: ", result.errorCode, ")");
    }
    
    Print("───────────────────────────────────────────────────────────");
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
                const long &real_volume[],
                const int &spread[])
{
    // Only run once
    static bool tested = false;
    if(!tested) {
        tested = true;
        TestZoneCreation();
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up test zone
    ObjectDelete(0, "DIAGNOSTIC_Zone_Test");
    
    Print("═══════════════════════════════════════════════════════════");
    Print("DIAGNOSTIC: Zone Timeframe Test Ended");
    Print("═══════════════════════════════════════════════════════════");
}
