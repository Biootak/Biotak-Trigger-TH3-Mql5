//+------------------------------------------------------------------+
//|                              Test_ATR_Consistency_CrossTF.mq5    |
//|                                                                  |
//| Test ATR consistency across different chart timeframes           |
//| BUGFIX: Verify ATR values remain constant regardless of chart TF |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property link      "@biotak"
#property version   "1.00"
#property script_show_inputs

// Include necessary files
#include "../Biotak/FloatingPointHelper.mqh"
#include "../Biotak/MathConstants.mqh"
#include "../Biotak/ConstantsAndEnums.mqh"
#include "../Biotak/PropertiesAndInputs.mqh"
#include "../Biotak/GlobalVariables.mqh"
#include "../Biotak/ATRCalculations.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart() {
    Print("========== ATR CROSS-TIMEFRAME CONSISTENCY TEST ==========");
    Print("Current Chart Timeframe: ", EnumToString(_Period));
    
    // Initialize cache
    InitializeATRCache();
    
    // Test timeframes
    int testTimeframes[] = {1, 5, 15, 60, 240, 1440}; // M1, M5, M15, H1, H4, D1
    string tfNames[] = {"M1", "M5", "M15", "H1", "H4", "D1"};
    
    Print("\n--- ATR Values for All Timeframes ---");
    Print("NOTE: These values should be IDENTICAL regardless of chart timeframe!\n");
    
    // Calculate ATR for each timeframe
    for(int i = 0; i < ArraySize(testTimeframes); i++) {
        double atrValue = GetATRForTimeframe(testTimeframes[i]);
        
        if(atrValue > 0) {
            Print(tfNames[i], " ATR: ", DoubleToString(atrValue, Digits), 
                  " (", DoubleToString(atrValue / _Point / 10, 1), " pips)");
        } else {
            Print("❌ ", tfNames[i], " ATR: FAILED (returned 0 or negative)");
        }
    }
    
    Print("\n--- VERIFICATION INSTRUCTIONS ---");
    Print("1. Note down the ATR values above");
    Print("2. Switch to a DIFFERENT chart timeframe (e.g., M5 → H1)");
    Print("3. Run this script again");
    Print("4. Compare the values - they MUST be identical!");
    Print("5. If values change, the bug is NOT fixed");
    Print("6. If values stay the same, the bug IS fixed ✅");
    
    // Cache statistics
    Print("\n--- Cache Statistics ---");
    Print(GetATRCacheStats());
    
    // Cleanup
    CleanupATRCache();
    
    Print("\n========== TEST COMPLETE ==========");
}
