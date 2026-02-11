#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#ifndef ZONE_CONSTANTS_MQH
#define ZONE_CONSTANTS_MQH

// Zone Configuration
const int MAX_ALPHA_VALUE = 255;
const int MIN_ALPHA_VALUE = 0;
const double MIN_STEP_SIZE_RATIO = 0.000001;

// Error Codes
const int ERR_ZONE_NONE = 0;
const int ERR_ZONE_INVALID_CONFIG = 3;
const int ERR_ZONE_RENDER_FAILED = 4;
const int ERR_ZONE_NO_DATA = 7;

// Cached Market Price
static double g_cachedMarketPrice = 0;
static datetime g_cachedMarketPriceTime = 0;

double GetCachedMarketPrice()
{
    datetime now = TimeCurrent();
    if(g_cachedMarketPriceTime > 0 && (now - g_cachedMarketPriceTime) < 1)
        return g_cachedMarketPrice;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    g_cachedMarketPrice = (bid > 0 && ask > 0) ? (bid + ask) / 2.0 : MathMax(bid, ask);
    g_cachedMarketPriceTime = now;
    return g_cachedMarketPrice;
}

#endif // ZONE_CONSTANTS_MQH
