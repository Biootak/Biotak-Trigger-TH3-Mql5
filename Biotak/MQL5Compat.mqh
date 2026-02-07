//+------------------------------------------------------------------+
//|                                                  MQL5Compat.mqh |
//|              MQL4 → MQL5 Compatibility Layer                     |
//|              Provides MQL4 functions/variables for MQL5          |
//+------------------------------------------------------------------+
#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

//+------------------------------------------------------------------+
//| Bid / Ask predefined variables (MQL4 → MQL5)                    |
//| در MQL4 این متغیرها مستقیم در دسترس هستند                        |
//| در MQL5 باید از SymbolInfoDouble استفاده شود                      |
//+------------------------------------------------------------------+
#define Bid SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask SymbolInfoDouble(_Symbol, SYMBOL_ASK)

//+------------------------------------------------------------------+
//| Digits / Point predefined variables (MQL4 → MQL5)               |
//| در MQL4: Digits و Point مستقیم در دسترس هستند                    |
//| در MQL5: باید از _Digits و _Point استفاده شود                     |
//+------------------------------------------------------------------+
#define Digits _Digits
#define Point  _Point

//+------------------------------------------------------------------+
//| MarketInfo() compatibility (MQL4 → MQL5)                         |
//| در MQL4: MarketInfo(symbol, MODE_POINT) و غیره                   |
//| در MQL5: SymbolInfoDouble/Integer                                |
//+------------------------------------------------------------------+
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

// NOTE: iBarShift() is now built-in in MQL5 (newer builds)
// No custom implementation needed

//+------------------------------------------------------------------+
//| Time decomposition functions (MQL4 → MQL5)                      |
//| در MQL4 این توابع مستقیم وجود دارند                               |
//| در MQL5 باید از MqlDateTime استفاده شود                           |
//+------------------------------------------------------------------+
int TimeHour(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.hour;
}

int TimeMinute(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.min;
}

int TimeSeconds(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.sec;
}

int TimeDay(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.day;
}

int TimeMonth(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.mon;
}

int TimeYear(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.year;
}

int TimeDayOfWeek(datetime time) {
    MqlDateTime dt;
    TimeToStruct(time, dt);
    return dt.day_of_week;
}

//+------------------------------------------------------------------+
//| PeriodMinutes() - Get current period in minutes                  |
//| در MQL4 مقدار Period() برابر دقیقه بود                            |
//| در MQL5 مقدار Period() یک ENUM_TIMEFRAMES است                     |
//| (مثلاً PERIOD_H1 = 16385 و نه 60)                                 |
//+------------------------------------------------------------------+
int PeriodMinutes(ENUM_TIMEFRAMES tf = PERIOD_CURRENT) {
    if(tf == PERIOD_CURRENT || tf == 0) tf = Period();
    return PeriodSeconds(tf) / 60;
}

//+------------------------------------------------------------------+
//| iATR compatibility (MQL4 4-param → MQL5 handle-based)            |
//| PERFORMANCE: Handle is cached to avoid create/destroy each call. |
//| بهینه‌سازی: هندل ATR کش می‌شود تا هر بار ساخته نشود               |
//+------------------------------------------------------------------+
int _g_atrHandleCache_handle = INVALID_HANDLE;
string _g_atrHandleCache_symbol = "";
ENUM_TIMEFRAMES _g_atrHandleCache_tf = PERIOD_CURRENT;
int _g_atrHandleCache_period = 0;

double iATRMQL4(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period, int shift) {
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    
    // Reuse cached handle if params match
    if(_g_atrHandleCache_handle != INVALID_HANDLE &&
       _g_atrHandleCache_symbol == symbol &&
       _g_atrHandleCache_tf == timeframe &&
       _g_atrHandleCache_period == atr_period) {
        // Use cached handle
    } else {
        // Release old handle if any
        if(_g_atrHandleCache_handle != INVALID_HANDLE)
            IndicatorRelease(_g_atrHandleCache_handle);
        
        _g_atrHandleCache_handle = iATR(symbol, timeframe, atr_period);
        _g_atrHandleCache_symbol = symbol;
        _g_atrHandleCache_tf = timeframe;
        _g_atrHandleCache_period = atr_period;
        
        if(_g_atrHandleCache_handle == INVALID_HANDLE) {
            PrintFormat("iATRMQL4: Failed to create ATR handle for %s/%s/%d", 
                        symbol, EnumToString(timeframe), atr_period);
            return 0.0;
        }
    }
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    int copied = CopyBuffer(_g_atrHandleCache_handle, 0, shift, 1, buffer);
    if(copied <= 0) {
        return 0.0;
    }
    
    return buffer[0];
}

// Call this from OnDeinit to release cached ATR handle
void ReleaseATRHandle() {
    if(_g_atrHandleCache_handle != INVALID_HANDLE) {
        IndicatorRelease(_g_atrHandleCache_handle);
        _g_atrHandleCache_handle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| WindowFirstVisibleBar / WindowBarsPerChart compatibility         |
//| (if used in the codebase)                                        |
//+------------------------------------------------------------------+
int WindowFirstVisibleBar() {
    return (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
}

int WindowBarsPerChart() {
    return (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
}

//+------------------------------------------------------------------+
//| ObjectSetText compatibility (MQL4 → MQL5)                        |
//| MQL4: ObjectSetText(name, text, font_size, font_name, color)    |
//| MQL5: Use ObjectSetString/Integer individually                    |
//+------------------------------------------------------------------+
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

#endif // MQL5_COMPAT_MQH
