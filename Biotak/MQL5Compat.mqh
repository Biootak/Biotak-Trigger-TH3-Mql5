#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

#define Bid    SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask    SymbolInfoDouble(_Symbol, SYMBOL_ASK)
#define Digits _Digits
#define Point  _Point

// MQL4 MarketInfo mode constants used by shared modules.
#define MODE_LOW            1
#define MODE_HIGH           2
#define MODE_TIME           5
#define MODE_BID            9
#define MODE_ASK            10
#define MODE_DIGITS         12
#define MODE_SPREAD         13
#define MODE_STOPLEVEL      14
#define MODE_LOTSIZE        15
#define MODE_POINT          16
#define MODE_TICKVALUE      17
#define MODE_TICKSIZE       18
#define MODE_SWAPLONG       19
#define MODE_SWAPSHORT      20
#define MODE_MINLOT         23
#define MODE_LOTSTEP        24
#define MODE_MAXLOT         25
#define MODE_FREEZELEVEL    33
#define MODE_MARGINREQUIRED 37

double MarketInfo(string symbol, int mode)
{
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    switch(mode) {
        case MODE_LOW:            return SymbolInfoDouble(symbol, SYMBOL_LASTLOW);
        case MODE_HIGH:           return SymbolInfoDouble(symbol, SYMBOL_LASTHIGH);
        case MODE_TIME:           return (double)SymbolInfoInteger(symbol, SYMBOL_TIME);
        case MODE_BID:            return SymbolInfoDouble(symbol, SYMBOL_BID);
        case MODE_ASK:            return SymbolInfoDouble(symbol, SYMBOL_ASK);
        case MODE_DIGITS:         return (double)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        case MODE_SPREAD:         return (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
        case MODE_STOPLEVEL:      return (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        case MODE_LOTSIZE:        return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        case MODE_POINT:          return SymbolInfoDouble(symbol, SYMBOL_POINT);
        case MODE_TICKVALUE:      return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        case MODE_TICKSIZE:       return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        case MODE_SWAPLONG:       return SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
        case MODE_SWAPSHORT:      return SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
        case MODE_MINLOT:         return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        case MODE_LOTSTEP:        return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        case MODE_MAXLOT:         return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        case MODE_FREEZELEVEL:    return (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
        case MODE_MARGINREQUIRED: return SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
        default:                  return 0.0;
    }
}

static MqlDateTime g_tempDt;

int TimeHour(datetime time)      { TimeToStruct(time, g_tempDt); return g_tempDt.hour; }
int TimeMinute(datetime time)    { TimeToStruct(time, g_tempDt); return g_tempDt.min; }
int TimeSeconds(datetime time)   { TimeToStruct(time, g_tempDt); return g_tempDt.sec; }
int TimeDay(datetime time)       { TimeToStruct(time, g_tempDt); return g_tempDt.day; }
int TimeMonth(datetime time)     { TimeToStruct(time, g_tempDt); return g_tempDt.mon; }
int TimeYear(datetime time)      { TimeToStruct(time, g_tempDt); return g_tempDt.year; }
int TimeDayOfWeek(datetime time) { TimeToStruct(time, g_tempDt); return g_tempDt.day_of_week; }

int PeriodMinutes(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
    if(tf == PERIOD_CURRENT || tf == 0) tf = (ENUM_TIMEFRAMES)Period();
    int seconds = PeriodSeconds(tf);
    if(seconds > 0) return seconds / 60;

    int rawTf = (int)tf;
    if(rawTf > 0 && (rawTf <= 10080 || rawTf == 43200)) return rawTf;

    return 0;
}

// MQL4-style iATR(symbol, timeframe, period, shift) bridge for MQL5 handles.
#define ATR_HANDLE_CACHE_SIZE 16

struct ATRHandleCacheEntry {
    int handle;
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    int period;
};

static ATRHandleCacheEntry g_atrHandleCache[];
static int  g_atrHandleCacheCount = 0;
static bool g_atrHandleCacheInitialized = false;

void InitATRHandleCache()
{
    if(g_atrHandleCacheInitialized) return;
    ArrayResize(g_atrHandleCache, ATR_HANDLE_CACHE_SIZE);
    for(int i = 0; i < ATR_HANDLE_CACHE_SIZE; i++) {
        g_atrHandleCache[i].handle = INVALID_HANDLE;
        g_atrHandleCache[i].symbol = "";
        g_atrHandleCache[i].timeframe = PERIOD_CURRENT;
        g_atrHandleCache[i].period = 0;
    }
    g_atrHandleCacheCount = 0;
    g_atrHandleCacheInitialized = true;
}

double iATRMQL4(string symbol, ENUM_TIMEFRAMES timeframe, int atrPeriod, int shift)
{
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    if(timeframe == PERIOD_CURRENT || timeframe == 0) timeframe = (ENUM_TIMEFRAMES)Period();
    if(atrPeriod <= 0 || shift < 0) return 0.0;

    if(!SymbolSelect(symbol, true)) {
        LOG_E(LOG_CAT_ATR, "iATRMQL4: symbol is not selectable " + symbol);
        return 0.0;
    }

    int bars = iBars(symbol, timeframe);
    if(bars <= atrPeriod + shift) return 0.0;

    InitATRHandleCache();

    int handle = INVALID_HANDLE;
    int cacheIndex = -1;
    for(int i = 0; i < g_atrHandleCacheCount; i++) {
        if(g_atrHandleCache[i].symbol == symbol &&
           g_atrHandleCache[i].timeframe == timeframe &&
           g_atrHandleCache[i].period == atrPeriod) {
            handle = g_atrHandleCache[i].handle;
            cacheIndex = i;
            break;
        }
    }

    if(handle != INVALID_HANDLE && BarsCalculated(handle) <= 0) {
        IndicatorRelease(handle);
        if(cacheIndex >= 0) g_atrHandleCache[cacheIndex].handle = INVALID_HANDLE;
        handle = INVALID_HANDLE;
    }

    if(handle == INVALID_HANDLE) {
        handle = iATR(symbol, timeframe, atrPeriod);
        if(handle == INVALID_HANDLE) {
            LOG_E(LOG_CAT_ATR, "iATRMQL4: failed ATR handle " + symbol + "/" + EnumToString(timeframe));
            return 0.0;
        }

        static int s_atrEvictSlot = 0;
        int slot = g_atrHandleCacheCount;
        if(slot >= ATR_HANDLE_CACHE_SIZE) {
            slot = s_atrEvictSlot;
            if(g_atrHandleCache[slot].handle != INVALID_HANDLE)
                IndicatorRelease(g_atrHandleCache[slot].handle);
            s_atrEvictSlot = (s_atrEvictSlot + 1) % ATR_HANDLE_CACHE_SIZE;
        } else {
            g_atrHandleCacheCount++;
        }

        g_atrHandleCache[slot].handle = handle;
        g_atrHandleCache[slot].symbol = symbol;
        g_atrHandleCache[slot].timeframe = timeframe;
        g_atrHandleCache[slot].period = atrPeriod;
    }

    if(BarsCalculated(handle) <= shift) return 0.0;

    static double s_atrBuffer[];
    static bool s_bufferReady = false;
    if(!s_bufferReady) {
        ArrayResize(s_atrBuffer, 1);
        ArraySetAsSeries(s_atrBuffer, true);
        s_bufferReady = true;
    }

    ResetLastError();
    if(CopyBuffer(handle, 0, shift, 1, s_atrBuffer) <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("iATRMQL4: CopyBuffer failed for ", symbol, "/", EnumToString(timeframe),
              " period=", atrPeriod, " shift=", shift, " error=", GetLastError());
        #endif
        return 0.0;
    }
    return s_atrBuffer[0];
}

void ReleaseATRHandleCache()
{
    for(int i = 0; i < g_atrHandleCacheCount; i++) {
        if(g_atrHandleCache[i].handle != INVALID_HANDLE) {
            IndicatorRelease(g_atrHandleCache[i].handle);
            g_atrHandleCache[i].handle = INVALID_HANDLE;
        }
    }
    g_atrHandleCacheCount = 0;
}

#define iATR iATRMQL4

int WindowFirstVisibleBar()
{
    return (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
}

int WindowBarsPerChart()
{
    return (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
}

bool ObjectSetText(string name, string text, int fontSize = 0, string fontName = "", color textColor = clrNONE)
{
    bool result = ObjectSetString(0, name, OBJPROP_TEXT, text);
    if(fontSize > 0) ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    if(fontName != "") ObjectSetString(0, name, OBJPROP_FONT, fontName);
    if(textColor != clrNONE) ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    return result;
}

#endif // MQL5_COMPAT_MQH
