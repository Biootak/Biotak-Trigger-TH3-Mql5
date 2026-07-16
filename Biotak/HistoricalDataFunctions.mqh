  #ifndef HISTORICAL_DATA_FUNCTIONS_MQH
#define HISTORICAL_DATA_FUNCTIONS_MQH

#property strict

bool UpdateHistoricalValues() {
    // Only update if necessary
    datetime currentTime = TimeCurrent();
    if(currentTime - g_lastHistoricalUpdate < 3600 && g_initialized) return true;

    // FIX (M13): when inpHistoricalPeriods == 0 the user is asking for "all
    // available bars" which on M1/M5 brokers can be 100k+ bars. Copying that
    // many bars + running iHighest/iLowest over them is a multi-second stall
    // on every chart change. Cap with a hard ceiling that still covers a
    // trading week on the smallest timeframe (M1) with margin.
    const int MAX_HISTORICAL_BARS = 20000;
    int availableBars = iBars(Symbol(), inpHistoricalTimeframe);
    int totalBars = (inpHistoricalPeriods == 0)
                    ? MathMin(availableBars, MAX_HISTORICAL_BARS)
                    : MathMin(inpHistoricalPeriods, MathMin(availableBars, MAX_HISTORICAL_BARS));
    
    if(totalBars <= 0) {
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
    
    switch(priceType) {
        case PRICE_OPEN: return cachedPrices[1];
        case PRICE_HIGH: return cachedPrices[2];
        case PRICE_LOW: return cachedPrices[3];
        case PRICE_MEDIAN: return cachedPrices[4];
        case PRICE_TYPICAL: return cachedPrices[5];
        case PRICE_CLOSE: default: return cachedPrices[0];
    }
    return EMPTY_VALUE;
}
#endif // HISTORICAL_DATA_FUNCTIONS_MQH
