//+------------------------------------------------------------------+
//|                                      DiagnosticZoneDisplay.mq5   |
//|                                      Biotak Trigger TH3 Indicator |
//|                   Task 16 - Diagnostic Tool for Zone Display     |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property version   "1.00"
#property strict
#property script_show_inputs

input bool ShowDetailedInfo = true;  // Show detailed diagnostic information

// Include MQL5 compatibility layer
#include "../MQL5Compat.mqh"
#include "../BuildConfig.mqh"
#include "../ConstantsAndEnums.mqh"
#include "../FloatingPointHelper.mqh"
#include "../PerformanceOptimizations.mqh"

//+------------------------------------------------------------------+
//| Check Timeframe Data Availability                                |
//+------------------------------------------------------------------+
void CheckTimeframeData(int period, string timeframeName) {
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  Timeframe: ", timeframeName, "                                ");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    
    // Check Bars
    int barsCount = Bars(_Symbol, period);
    Print("   Bars Count: ", barsCount);
    
    if(barsCount <= 0) {
        Print("   ❌ ERROR: No bars available");
    } else {
        Print("   ✅ Bars available");
    }
    
    // Check PeriodSeconds
    int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)period);
    Print("   Period Seconds: ", periodSeconds);
    
    if(periodSeconds <= 0) {
        Print("   ❌ ERROR: Invalid PeriodSeconds");
    } else {
        Print("   ✅ PeriodSeconds valid");
    }
    
    // Check time data
    if(barsCount > 0) {
        datetime time0 = iTime(_Symbol, period, 0);
        Print("   Latest Bar Time: ", TimeToString(time0, TIME_DATE|TIME_MINUTES));
        
        if(time0 <= 0) {
            Print("   ❌ ERROR: Cannot retrieve bar time");
        } else {
            Print("   ✅ Bar time accessible");
        }
    }
    
    // Check price data
    if(barsCount > 0) {
        double close0 = iClose(_Symbol, period, 0);
        Print("   Latest Close: ", DoubleToString(close0, _Digits));
        
        if(close0 <= 0) {
            Print("   ❌ ERROR: Cannot retrieve price data");
        } else {
            Print("   ✅ Price data accessible");
        }
    }
    
    // Summary
    bool allOk = (barsCount > 0) && (periodSeconds > 0);
    if(allOk) {
        Print("   ✅ Timeframe ", timeframeName, " is READY for zone display");
    } else {
        Print("   ❌ Timeframe ", timeframeName, " has ISSUES");
    }
    
    Print("");
}

//+------------------------------------------------------------------+
//| Count Existing Zones on Chart                                    |
//+------------------------------------------------------------------+
int CountZonesOnChart() {
    int zoneCount = 0;
    int totalObjects = ObjectsTotal(0, 0, OBJ_RECTANGLE);
    
    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i, 0, OBJ_RECTANGLE);
        
        // Check if it's a zone object (typically contains "ZONE" in name)
        if(StringFind(objName, "ZONE") >= 0 || StringFind(objName, "Zone") >= 0) {
            zoneCount++;
            
            if(ShowDetailedInfo) {
                double topPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
                double bottomPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);
                datetime startTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
                datetime endTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
                
                Print("   Zone: ", objName);
                Print("      Top: ", DoubleToString(topPrice, _Digits));
                Print("      Bottom: ", DoubleToString(bottomPrice, _Digits));
                Print("      Start: ", TimeToString(startTime, TIME_DATE|TIME_MINUTES));
                Print("      End: ", TimeToString(endTime, TIME_DATE|TIME_MINUTES));
            }
        }
    }
    
    return zoneCount;
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  BIOTAK TRIGGER TH3 - ZONE DISPLAY DIAGNOSTICS               ║");
    Print("║  Task 16 - Verification Tool                                 ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");
    Print("Symbol: ", _Symbol);
    Print("Current Timeframe: ", EnumToString((ENUM_TIMEFRAMES)_Period));
    Print("Current Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
    Print("Current Bid: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
    Print("Current Ask: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits));
    Print("");
    
    // Check data availability for target timeframes
    Print("═══════════════════════════════════════════════════════════════");
    Print("CHECKING TIMEFRAME DATA AVAILABILITY");
    Print("═══════════════════════════════════════════════════════════════");
    Print("");
    
    CheckTimeframeData(PERIOD_M1, "M1");
    CheckTimeframeData(PERIOD_M5, "M5");
    CheckTimeframeData(PERIOD_M15, "M15");
    CheckTimeframeData(PERIOD_M30, "M30");
    
    // Count existing zones on current chart
    Print("═══════════════════════════════════════════════════════════════");
    Print("ZONE COUNT ON CURRENT CHART");
    Print("═══════════════════════════════════════════════════════════════");
    Print("");
    
    int zoneCount = CountZonesOnChart();
    Print("Total Zones Found: ", zoneCount);
    Print("");
    
    // Check for common issues
    Print("═══════════════════════════════════════════════════════════════");
    Print("COMMON ISSUE CHECKS");
    Print("═══════════════════════════════════════════════════════════════");
    Print("");
    
    // Check 1: Market hours
    bool isMarketOpen = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL);
    Print("Market Status: ", isMarketOpen ? "OPEN" : "CLOSED");
    
    // Check 2: Symbol info
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    Print("Symbol Digits: ", digits);
    Print("Symbol Point: ", DoubleToString(point, digits + 1));
    
    // Check 3: Object limits
    int totalObjects = ObjectsTotal(0);
    Print("Total Chart Objects: ", totalObjects, " / 64000 (MT5 limit)");
    
    if(totalObjects > 60000) {
        Print("   ⚠️ WARNING: Approaching object limit");
    }
    
    Print("");
    Print("═══════════════════════════════════════════════════════════════");
    Print("DIAGNOSTIC COMPLETE");
    Print("═══════════════════════════════════════════════════════════════");
    Print("");
    Print("Next Steps:");
    Print("1. Review the timeframe data availability above");
    Print("2. If any timeframe shows errors, check market data");
    Print("3. Load indicator and verify zones display on each timeframe");
    Print("4. Compare zone counts across timeframes for consistency");
    Print("5. Check Expert log for validation errors");
    Print("");
}
//+------------------------------------------------------------------+
