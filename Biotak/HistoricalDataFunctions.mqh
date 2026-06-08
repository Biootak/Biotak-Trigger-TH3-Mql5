  #ifndef HISTORICAL_DATA_FUNCTIONS_MQH
#define HISTORICAL_DATA_FUNCTIONS_MQH

#property strict

bool UpdateHistoricalValues() {
    // Only update if necessary
    datetime currentTime = TimeCurrent();
    if(currentTime - g_lastHistoricalUpdate < 3600 && g_initialized) return true;
    
    int availableBars = iBars(Symbol(), inpHistoricalTimeframe);
    int totalBars = (inpHistoricalPeriods == 0) ? availableBars : MathMin(inpHistoricalPeriods, availableBars);
    
    if(totalBars <= 0) {
        // FIX: Don't just fail, log that we're waiting for data
        static datetime s_lastBarsWarning = 0;
        if(currentTime - s_lastBarsWarning > 30) {
            Print("UpdateHistoricalValues: Waiting for historical data (", EnumToString(inpHistoricalTimeframe), ")...");
            s_lastBarsWarning = currentTime;
        }
        return false;
    }

    int highIndex = iHighest(Symbol(), inpHistoricalTimeframe, MODE_HIGH, totalBars, 0);
    int lowIndex = iLowest(Symbol(), inpHistoricalTimeframe, MODE_LOW, totalBars, 0);
    if(highIndex < 0 || lowIndex < 0) {
        Print("UpdateHistoricalValues: Failed to locate high/low indexes. HighIdx=", highIndex, ", LowIdx=", lowIndex);
        return false;
    }

    g_highestHigh = iHigh(Symbol(), inpHistoricalTimeframe, highIndex);
    g_lowestLow = iLow(Symbol(), inpHistoricalTimeframe, lowIndex);
    
    if(g_highestHigh <= 0 || g_lowestLow <= 0) {
        Print("UpdateHistoricalValues: Invalid high/low values");
        return false;
    }
    
    g_lastHistoricalUpdate = currentTime;
    // g_thCache removed - matching MT5
    
    return true;
}

// Cache previous day prices
double GetPriceForPreviousDay(ENUM_APPLIED_PRICE priceType) {
    static datetime lastUpdate = 0;
    static double cachedPrices[6] = {0};
    
    datetime currentTime = TimeCurrent();
    if(currentTime-lastUpdate >= 86400 || lastUpdate==0) { // Update cache daily
        static MqlRates dailyRates[];
        if(ArraySize(dailyRates) < 1 && ArrayResize(dailyRates, 1) != 1) {
            return EMPTY_VALUE;
        }
        ResetLastError();
        int copied = CopyRates(Symbol(), PERIOD_D1, 1, 1, dailyRates);
        if(copied != 1 || dailyRates[0].time <= 0 ||
           dailyRates[0].close <= 0.0 || dailyRates[0].open <= 0.0 ||
           dailyRates[0].high <= 0.0 || dailyRates[0].low <= 0.0) {
            return EMPTY_VALUE;
        }
        cachedPrices[0]=dailyRates[0].close;
        cachedPrices[1]=dailyRates[0].open;
        cachedPrices[2]=dailyRates[0].high;
        cachedPrices[3]=dailyRates[0].low;
        cachedPrices[4]=(cachedPrices[2]+cachedPrices[3])/2.0;
        cachedPrices[5]=(cachedPrices[2]+cachedPrices[3]+cachedPrices[0])/3.0;
        lastUpdate = currentTime;
    }
    
    switch((int)priceType) {
        case 1: return cachedPrices[1]; // Open
        case 2: return cachedPrices[2]; // High
        case 3: return cachedPrices[3]; // Low
        case 4: return cachedPrices[4]; // Median
        case 5: return cachedPrices[5]; // Typical
        case 0: default: return cachedPrices[0]; // Close
    }
    return EMPTY_VALUE;
}
#endif // HISTORICAL_DATA_FUNCTIONS_MQH
