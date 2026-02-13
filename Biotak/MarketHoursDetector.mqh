#ifndef MARKET_HOURS_DETECTOR_MQH
#define MARKET_HOURS_DETECTOR_MQH

#property copyright "Biotak"

enum ENUM_MARKET_TYPE {
    MARKET_FOREX,
    MARKET_METALS,
    MARKET_CRYPTO,
    MARKET_STOCKS,
    MARKET_UNKNOWN
};

ENUM_MARKET_TYPE DetectMarketType(string symbol) {
        string s = symbol;
    StringToUpper(s);
    if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0 ||
       StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
        return MARKET_METALS;
    if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 ||
       StringFind(s, "USDT") >= 0 || StringFind(s, "CRYPTO") >= 0)
        return MARKET_CRYPTO;
    static string forexPairs[] = {"EUR","GBP","USD","JPY","CHF","CAD","AUD","NZD"};

    int forexCount = 0;
    for(int i = 0; i < ArraySize(forexPairs); i++)
        if(StringFind(s, forexPairs[i]) >= 0) forexCount++;
    if(forexCount >= 2) return MARKET_FOREX;
    if(StringFind(s, "US30") >= 0 || StringFind(s, "NAS100") >= 0 ||
       StringFind(s, "SPX") >= 0 || StringFind(s, "DAX") >= 0 ||
       StringFind(s, "FTSE") >= 0)
        return MARKET_STOCKS;
    return MARKET_UNKNOWN;
}
    int GetTradingDayStartHour(string symbol) {
    ENUM_MARKET_TYPE mt = DetectMarketType(symbol);
    switch(mt) {
        case MARKET_FOREX:
        case MARKET_METALS:  return 22;
    case MARKET_CRYPTO:  return 0;
    default:             return 0;
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
    if(startHour == 22 && currentTime < startTime)
        startTime -= 86400;
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