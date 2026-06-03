#ifndef HISTORICAL_DATA_FUNCTIONS_MQH
#define HISTORICAL_DATA_FUNCTIONS_MQH

bool UpdateHistoricalValues() {
        datetime currentTime = TimeCurrent();
    if(currentTime - g_lastHistoricalUpdate < SECONDS_PER_HOUR && g_initialized) return true;
    double highArray[], lowArray[];
    int totalBars = inpHistoricalPeriods == 0 ?
                   iBars(_Symbol, inpHistoricalTimeframe) :
                   inpHistoricalPeriods;
    if(totalBars <= 0) return false;
    if(ArrayResize(highArray, totalBars) != totalBars ||
       ArrayResize(lowArray, totalBars) != totalBars) {
        ArrayFree(highArray);
    ArrayFree(lowArray);
    return false;
    }
    int copiedHigh = CopyHigh(_Symbol, inpHistoricalTimeframe, 0, totalBars, highArray);
    int copiedLow = CopyLow(_Symbol, inpHistoricalTimeframe, 0, totalBars, lowArray);
    if(copiedHigh <= 0 || copiedLow <= 0) {
        ArrayFree(highArray);
    ArrayFree(lowArray);
    return false;
    }

    g_highestHigh = highArray[ArrayMaximum(highArray)];
    g_lowestLow = lowArray[ArrayMinimum(lowArray)];
    ArrayFree(highArray);
    ArrayFree(lowArray);
    if(g_highestHigh <= 0 || g_lowestLow <= 0) return false;
    g_lastHistoricalUpdate = currentTime;
    InvalidateTHCache();
    return true;
}
    double GetPriceForPreviousDay(ENUM_APPLIED_PRICE priceType) {
        static datetime lastUpdate = 0;
    static double cachedPrices[6];
    datetime currentTime = TimeCurrent();
    if(currentTime - lastUpdate >= SECONDS_PER_DAY || lastUpdate == 0) {
        // BUG FIX: Verify D1 data is available before accessing
        // WHY: On terminal startup or symbol switch, D1 data may not be loaded yet.
        // iClose/iOpen/iHigh/iLow return 0.0 (not EMPTY_VALUE), which passes through
        // the caller's EMPTY_VALUE check, causing g_dailyClosePriceForTH=0.0
        // and persistent silent failure (no levels drawn until manual reload).
        if(iBars(_Symbol, PERIOD_D1) < 2) {
            // D1 data not ready — don't cache, let next call retry
            return 0.0;
        }
        cachedPrices[0] = iClose(_Symbol, PERIOD_D1, 1);
    cachedPrices[1] = iOpen(_Symbol, PERIOD_D1, 1);
    cachedPrices[2] = iHigh(_Symbol, PERIOD_D1, 1);
    cachedPrices[3] = iLow(_Symbol, PERIOD_D1, 1);
    cachedPrices[4] = (cachedPrices[2] + cachedPrices[3]) / 2.0;
    cachedPrices[5] = (cachedPrices[2] + cachedPrices[3] + cachedPrices[0]) / 3.0;
    lastUpdate = currentTime;
    }

    switch((int)priceType) {
        case PRICE_OPEN:    return cachedPrices[1];
    case PRICE_HIGH:    return cachedPrices[2];
    case PRICE_LOW:     return cachedPrices[3];
    case PRICE_MEDIAN:  return cachedPrices[4];
    case PRICE_TYPICAL: return cachedPrices[5];
    case PRICE_CLOSE:
        default:            return cachedPrices[0];
    }
}
    #endif
    // HISTORICAL_DATA_FUNCTIONS_MQH