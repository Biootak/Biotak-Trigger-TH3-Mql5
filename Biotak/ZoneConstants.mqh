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

// Removed GetCachedMarketPrice() — duplicate of CacheTickPrices()/GetCachedBid() in MQL5Compat.mqh
// Use GetCachedBid() from MQL5Compat.mqh instead.

#endif // ZONE_CONSTANTS_MQH
