#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

#define Bid SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask SymbolInfoDouble(_Symbol, SYMBOL_ASK)
#define Digits _Digits
#define Point  _Point

// PERF: Cached Bid/Ask to avoid repeated SymbolInfoDouble() syscalls per tick.
// Call CacheTickPrices() once at the top of OnCalculateHandler/RedrawAllObjects,
// then use GetCachedBid()/GetCachedAsk() everywhere else in that tick.
static double g_cachedBid = 0.0;
static double g_cachedAsk = 0.0;
static uint   g_tickPriceCacheTime = 0;

void CacheTickPrices() {
    g_cachedBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    g_cachedAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    g_tickPriceCacheTime = GetTickCount();
}

double GetCachedBid() {
    if(g_tickPriceCacheTime == 0) CacheTickPrices();
    return g_cachedBid;
}

double GetCachedAsk() {
    if(g_tickPriceCacheTime == 0) CacheTickPrices();
    return g_cachedAsk;
}

// MQL4 MarketInfo mode constants
#define MODE_POINT          16
#define MODE_DIGITS         12
#define MODE_SPREAD         13
#define MODE_TICKSIZE       18
#define MODE_TICKVALUE      17
#define MODE_SWAPLONG       19
#define MODE_SWAPSHORT      20
#define MODE_STOPLEVEL      14
#define MODE_LOTSIZE        15
#define MODE_MINLOT         23
#define MODE_LOTSTEP        24
#define MODE_MAXLOT         25
#define MODE_MARGINREQUIRED 37
#define MODE_BID            9
#define MODE_ASK            10
#define MODE_TIME           5
#define MODE_LOW            1
#define MODE_HIGH           2
#define MODE_FREEZELEVEL    33

double MarketInfo(string symbol, int mode) {
    switch(mode) {
        case MODE_POINT:          return SymbolInfoDouble(symbol, SYMBOL_POINT);
    case MODE_DIGITS:         return (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    case MODE_SPREAD:         return (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    case MODE_TICKSIZE:       return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    case MODE_TICKVALUE:      return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    case MODE_SWAPLONG:       return SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
    case MODE_SWAPSHORT:      return SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
    case MODE_STOPLEVEL:      return (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    case MODE_LOTSIZE:        return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    case MODE_MINLOT:         return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    case MODE_LOTSTEP:        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    case MODE_MAXLOT:         return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    case MODE_MARGINREQUIRED: return SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
    case MODE_BID:            return SymbolInfoDouble(symbol, SYMBOL_BID);
    case MODE_ASK:            return SymbolInfoDouble(symbol, SYMBOL_ASK);
    case MODE_TIME:           return (double)SymbolInfoInteger(symbol, SYMBOL_TIME);
    case MODE_LOW:            return SymbolInfoDouble(symbol, SYMBOL_LASTLOW);
    case MODE_HIGH:           return SymbolInfoDouble(symbol, SYMBOL_LASTHIGH);
    case MODE_FREEZELEVEL:    return (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    default:                  return 0.0;
    }
}
// PERF: Reuse a single static MqlDateTime struct to avoid stack allocation per call
static MqlDateTime g_tempDt;

    int TimeHour(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.hour;
}
    int TimeMinute(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.min;
}
    int TimeSeconds(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.sec;
}
    int TimeDay(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.day;
}
    int TimeMonth(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.mon;
}
    int TimeYear(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.year;
}
    int TimeDayOfWeek(datetime time) {
    TimeToStruct(time, g_tempDt); return g_tempDt.day_of_week;
}
    int PeriodMinutes(ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
        if(tf == PERIOD_CURRENT || tf == 0) tf = (ENUM_TIMEFRAMES)GetCachedPeriod();
    return PeriodSeconds(tf) / 60;
}

// ATR Handle Cache (multi-slot, round-robin eviction)
#define ATR_CACHE_SIZE 16

struct ATRHandleCacheEntry {
        int handle;
    string symbol;
    ENUM_TIMEFRAMES tf;
    int period;
};

ATRHandleCacheEntry g_atrHandleCache[];
int g_atrHandleCacheCount = 0;
bool g_atrHandleCacheInitialized = false;
    void InitATRCache() {
    if(!g_atrHandleCacheInitialized) {
        ArrayResize(g_atrHandleCache, ATR_CACHE_SIZE);
    for(int i = 0; i < ATR_CACHE_SIZE; i++) {
            g_atrHandleCache[i].handle = INVALID_HANDLE;
    g_atrHandleCache[i].symbol = "";
    g_atrHandleCache[i].tf = PERIOD_CURRENT;
    g_atrHandleCache[i].period = 0;
        }
        g_atrHandleCacheInitialized = true;
    }
}
    double iATRMQL4(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period, int shift) {
        if(symbol == NULL || symbol == "") symbol = _Symbol;
    // PERF: InitATRCache() is called from OnInit; skip redundant per-call init check
    if(!g_atrHandleCacheInitialized) InitATRCache();
    int handle = INVALID_HANDLE;
    for(int i = 0; i < g_atrHandleCacheCount; i++) {
        if(g_atrHandleCache[i].symbol == symbol &&
           g_atrHandleCache[i].tf == timeframe &&
           g_atrHandleCache[i].period == atr_period) {
            handle = g_atrHandleCache[i].handle;
    break;
        }
    }
    if(handle == INVALID_HANDLE) {
        handle = iATR(symbol, timeframe, atr_period);
    if(handle == INVALID_HANDLE) {
            LOG_E(LOG_CAT_ATR, "iATRMQL4: Failed ATR handle " + symbol + "/" + EnumToString(timeframe) + "/" + IntegerToString(atr_period));
    return 0.0;
        }
    static int g_atrEvictSlot = 0;
    int slot = g_atrHandleCacheCount;
    if(slot >= ATR_CACHE_SIZE) {
            slot = g_atrEvictSlot;
    if(g_atrHandleCache[slot].handle != INVALID_HANDLE)
                IndicatorRelease(g_atrHandleCache[slot].handle);
    g_atrEvictSlot = (g_atrEvictSlot + 1) % ATR_CACHE_SIZE;
        } else {
            g_atrHandleCacheCount++;
        }
        g_atrHandleCache[slot].handle = handle;
    g_atrHandleCache[slot].symbol = symbol;
    g_atrHandleCache[slot].tf = timeframe;
    g_atrHandleCache[slot].period = atr_period;
    }
    double buffer[];
    ArraySetAsSeries(buffer, true);
    if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0) return 0.0;
    return buffer[0];
}
    void ReleaseATRHandle() {
    for(int i = 0; i < g_atrHandleCacheCount; i++) {
        if(g_atrHandleCache[i].handle != INVALID_HANDLE) {
            IndicatorRelease(g_atrHandleCache[i].handle);
    g_atrHandleCache[i].handle = INVALID_HANDLE;
        }
    }
    g_atrHandleCacheCount = 0;
}
    int WindowFirstVisibleBar() {
    return (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
}
    int WindowBarsPerChart() {
    return (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
}
    bool ObjectSetText(string name, string text, int font_size = 0, string font_name = "", color text_color = clrNONE) {
        bool result = ObjectSetString(0, name, OBJPROP_TEXT, text);
    if(font_size > 0)
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
    if(font_name != "")
        ObjectSetString(0, name, OBJPROP_FONT, font_name);
    if(text_color != clrNONE)
        ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
    return result;
}
    #endif
    // MQL5_COMPAT_MQH