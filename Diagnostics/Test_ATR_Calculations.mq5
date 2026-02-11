//+------------------------------------------------------------------+
//|                                      Test_ATR_Calculations.mq5   |
//|                                                                  |
//| Test script to verify ATR calculation fixes                      |
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
    Print("========== ATR CALCULATION TEST START ==========");
    
    // Initialize cache
    InitializeATRCache();
    
    // Test 1: Calculate Weighted ATR
    Print("\n--- Test 1: Weighted ATR ---");
    double weightedATR = CalculateWeightedATR();
    Print("Weighted ATR: ", DoubleToString(weightedATR, Digits));
    
    if(weightedATR <= 0) {
        Print("❌ ERROR: Weighted ATR is zero or negative!");
    } else {
        Print("✅ SUCCESS: Weighted ATR calculated: ", DoubleToString(weightedATR, Digits));
    }
    
    // Test 2: Calculate Batch ATR for all periods
    Print("\n--- Test 2: Batch ATR Calculation ---");
    double atrValues[];
    CalculateATRBatch(atrValues);
    
    if(ArraySize(atrValues) == 6) {
        Print("ATR Period 5:   ", DoubleToString(atrValues[0], Digits));
        Print("ATR Period 10:  ", DoubleToString(atrValues[1], Digits));
        Print("ATR Period 21:  ", DoubleToString(atrValues[2], Digits));
        Print("ATR Period 66:  ", DoubleToString(atrValues[3], Digits));
        Print("ATR Period 132: ", DoubleToString(atrValues[4], Digits));
        Print("ATR Period 264: ", DoubleToString(atrValues[5], Digits));
        
        // Verify all values are positive
        bool allValid = true;
        for(int i = 0; i < 6; i++) {
            if(atrValues[i] <= 0) {
                Print("❌ WARNING: ATR[", i, "] is zero or negative: ", atrValues[i]);
                allValid = false;
            }
        }
        
        if(allValid) {
            Print("✅ SUCCESS: All ATR periods calculated successfully");
        }
    } else {
        Print("❌ ERROR: ATR batch calculation failed!");
    }
    
    // Test 3: Calculate Hybrid ATR for different timeframes
    Print("\n--- Test 3: Hybrid ATR (Fractal Scaling) ---");
    int currentMinutes = GetCurrentTimeframeMinutes();
    Print("Current Timeframe: ", currentMinutes, " minutes");
    
    int testTimeframes[] = {1, 5, 15, 60, 240, 1440}; // M1, M5, M15, H1, H4, D1
    string tfNames[] = {"M1", "M5", "M15", "H1", "H4", "D1"};
    
    for(int i = 0; i < ArraySize(testTimeframes); i++) {
        double hybridATR = CalculateHybridATR(currentMinutes, testTimeframes[i]);
        Print(tfNames[i], " ATR: ", DoubleToString(hybridATR, Digits));
        
        if(hybridATR <= 0) {
            Print("❌ WARNING: ", tfNames[i], " ATR is zero or negative");
        }
    }
    
    // Test 4: Verify True Range calculation for recent bars
    Print("\n--- Test 4: True Range for Recent Bars ---");
    for(int i = 1; i <= 5; i++) {
        double tr = CalculateTrueRange(i);
        double high = iHigh(_Symbol, _Period, i);
        double low = iLow(_Symbol, _Period, i);
        double prevClose = iClose(_Symbol, _Period, i + 1);
        
        Print("Bar ", i, ": TR=", DoubleToString(tr, Digits), 
              " H=", DoubleToString(high, Digits),
              " L=", DoubleToString(low, Digits),
              " PC=", DoubleToString(prevClose, Digits));
              
        // Verify TR >= High - Low
        double hl = high - low;
        if(tr < hl - 0.00001) { // Allow small epsilon
            Print("❌ ERROR: TR < H-L for bar ", i, "!");
        }
    }
    
    // Test 5: Cache statistics
    Print("\n--- Test 5: Cache Statistics ---");
    Print(GetATRCacheStats());
    
    // Cleanup
    CleanupATRCache();
    
    Print("\n========== ATR CALCULATION TEST END ==========");
}
