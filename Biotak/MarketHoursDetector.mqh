#ifndef MARKET_HOURS_DETECTOR_MQH
#define MARKET_HOURS_DETECTOR_MQH

#property copyright "Biotak"

#define FOREX_METALS_DAY_START_HOUR  22  // 10 PM GMT
#define CRYPTO_DEFAULT_DAY_START_HOUR 0  // Midnight GMT

enum ENUM_MARKET_TYPE {
    MARKET_FOREX,
    MARKET_METALS,
    MARKET_CRYPTO,
    MARKET_STOCKS,
    MARKET_UNKNOWN
};

ENUM_MARKET_TYPE DetectMarketType(string symbol) {
    // Cache: symbol doesn't change during indicator lifetime
    static string s_cachedSymbol = "";
    static ENUM_MARKET_TYPE s_cachedResult = MARKET_UNKNOWN;
    if(symbol == s_cachedSymbol && s_cachedSymbol != "")
        return s_cachedResult;
    
    string s = symbol;
    StringToUpper(s);
    ENUM_MARKET_TYPE result = MARKET_UNKNOWN;
    if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0 ||
       StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
        result = MARKET_METALS;
    else if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 ||
       StringFind(s, "USDT") >= 0 || StringFind(s, "CRYPTO") >= 0)
        result = MARKET_CRYPTO;
    else {
        static string forexPairs[] = {"EUR","GBP","USD","JPY","CHF","CAD","AUD","NZD"};
        int forexCount = 0;
        for(int i = 0; i < ArraySize(forexPairs); i++)
            if(StringFind(s, forexPairs[i]) >= 0) forexCount++;
        if(forexCount >= 2) result = MARKET_FOREX;
        else if(StringFind(s, "US30") >= 0 || StringFind(s, "NAS100") >= 0 ||
           StringFind(s, "SPX") >= 0 || StringFind(s, "DAX") >= 0 ||
           StringFind(s, "FTSE") >= 0)
            result = MARKET_STOCKS;
    }
    s_cachedSymbol = symbol;
    s_cachedResult = result;
    return result;
}
    int GetTradingDayStartHour(string symbol) {
    ENUM_MARKET_TYPE mt = DetectMarketType(symbol);
    switch(mt) {
        case MARKET_FOREX:
        case MARKET_METALS:  return FOREX_METALS_DAY_START_HOUR;
    case MARKET_CRYPTO:  return CRYPTO_DEFAULT_DAY_START_HOUR;
    default:             return CRYPTO_DEFAULT_DAY_START_HOUR;
    }
}
    datetime GetStartOfTradingDay(string symbol, datetime currentTime) {
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    int startHour = GetTradingDayStartHour(symbol);
    dt.hour = startHour;
    dt.min = 0;
    dt.sec = 0;
    datetime startTime = StructToTime(dt);
    if(startHour == FOREX_METALS_DAY_START_HOUR && currentTime < startTime)
        startTime -= SECONDS_PER_DAY;
    return startTime;
}
    string GetMarketTypeName(ENUM_MARKET_TYPE marketType) {
    switch(marketType) {
        case MARKET_FOREX:   return "FOREX";
    case MARKET_METALS:  return "METALS";
    case MARKET_CRYPTO:  return "CRYPTO";
    case MARKET_STOCKS:  return "STOCKS";
    default:             return "UNKNOWN";
    }
}
    #endif
    // MARKET_HOURS_DETECTOR_MQH