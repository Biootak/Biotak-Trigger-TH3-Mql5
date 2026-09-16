#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

#define Bid    SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask    SymbolInfoDouble(_Symbol, SYMBOL_ASK)
#define Digits _Digits
#define Point  _Point

// MQL5 has no Symbol(); the shared MQL4 modules call it 110 times.
#define Symbol() _Symbol

// MQL4 series-function bridges: MQL5's iHigh/iLow/iOpen/iClose/iTime/
// iBars take ENUM_TIMEFRAMES, while the shared MQL4 modules pass int
// timeframes (e.g. from GetEffectiveTimeframe()). The self-referential
// macros insert the cast without infinite expansion.
#define iBars(sym, tf)  iBars(sym, (ENUM_TIMEFRAMES)(tf))
#define iTime(sym, tf, sh)  iTime(sym, (ENUM_TIMEFRAMES)(tf), sh)
#define iHigh(sym, tf, sh)  iHigh(sym, (ENUM_TIMEFRAMES)(tf), sh)
#define iLow(sym, tf, sh)   iLow(sym, (ENUM_TIMEFRAMES)(tf), sh)
#define iOpen(sym, tf, sh)  iOpen(sym, (ENUM_TIMEFRAMES)(tf), sh)
#define iClose(sym, tf, sh) iClose(sym, (ENUM_TIMEFRAMES)(tf), sh)

// NOTE: no PeriodSeconds() macro here. MQL5's preprocessor expands a
// one-parameter macro even when it is invoked with an empty argument list, so
// "#define PeriodSeconds(tf) PeriodSeconds((ENUM_TIMEFRAMES)(tf))" rewrites the
// very common zero-argument PeriodSeconds() into PeriodSeconds((ENUM_TIMEFRAMES)())
// and breaks the parse. The single int-argument call site in the shared source
// carries an explicit cast instead.

// MQL4 chart-window helpers with no MQL5 counterpart.
double WindowPriceMin(const int window = 0) { return ChartGetDouble(0, CHART_PRICE_MIN, window); }
double WindowPriceMax(const int window = 0) { return ChartGetDouble(0, CHART_PRICE_MAX, window); }

// MQL4 ObjectType(name) -> MQL5 OBJPROP_TYPE.
int ObjectType(const string name) { return (int)ObjectGetInteger(0, name, OBJPROP_TYPE); }

// MQL4 DoubleToStr(value, digits) -> MQL5 DoubleToString(value, digits).
string DoubleToStr(const double value, const int digits = 8) { return DoubleToString(value, digits); }

//+------------------------------------------------------------------+
//| StringTrimLeft / StringTrimRight - SEMANTIC shims, not syntax.    |
//|                                                                  |
//| MQL4 returns the TRIMMED STRING:                                 |
//|     string StringTrimLeft(string text)                           |
//| MQL5 returns the NUMBER OF CHARACTERS REMOVED and trims the      |
//| argument in place:                                                |
//|     int StringTrimLeft(string& string_value)                      |
//|                                                                  |
//| Proven by compiling both forms against the MT4 compiler:          |
//|     int    n = StringTrimLeft(s);  -> warning 180 'string' to 'number' |
//|     string r = StringTrimLeft(s);  -> clean                        |
//| and against MT5, where the string form raises warning 94.          |
//|                                                                  |
//| The shared source uses the MQL4 return-value form in eight places  |
//| (BasePriceHistoryManager 78/79, 241/242, 453/454, 667/668). Under  |
//| MQL5's own semantics those lines would silently store the removal  |
//| COUNT into a string instead of the trimmed text, which is a real   |
//| behaviour difference in the history-stamp reader. The Real helpers  |
//| below are defined BEFORE the renames, so their bodies still reach  |
//| the built-ins.                                                     |
//+------------------------------------------------------------------+
string StringTrimLeftReal(const string value)
{
    string s = value;
    StringTrimLeft(s);
    return s;
}

string StringTrimRightReal(const string value)
{
    string s = value;
    StringTrimRight(s);
    return s;
}

#define StringTrimLeft StringTrimLeftReal
#define StringTrimRight StringTrimRightReal

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
// 64 slots hold every (period x timeframe) combo the multi-TF label/scaling
// path uses (6 periods x 9 TFs = 54), so handles warm up once and persist
// instead of being evicted and restarted on every poll.
#define ATR_HANDLE_CACHE_SIZE 64

struct ATRHandleCacheEntry {
    int handle;
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    int period;
};

static ATRHandleCacheEntry g_atrHandleCache[];
static int  g_atrHandleCacheCount = 0;
static bool g_atrHandleCacheInitialized = false;
static string g_atrSelectedSymbol = "";

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

// Forward declaration: implemented below iATRMQL4 (MQL5 needs prototypes
// before use).
double iATRRatesFallback(string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, int shift);

// Fallback history cache. During MT5 handle warm-up, one weighted ATR needs
// six periods for the same timeframe. Re-reading the same CopyRates block for
// every period was the main startup cost (especially for W1/MN1). Keep one
// shared history block and the already-computed period values; the formula is
// unchanged and the cache is invalidated when the source timeframe advances.
#define ATR_FALLBACK_CACHE_BASE_PERIOD 264
#define ATR_FALLBACK_VALUE_SLOTS       8
static MqlRates g_atrFallbackRates[];
static string g_atrFallbackSymbol = "";
static ENUM_TIMEFRAMES g_atrFallbackTimeframe = PERIOD_CURRENT;
static int g_atrFallbackShift = -1;
static int g_atrFallbackSourceBars = -1;
static datetime g_atrFallbackLatestBar = 0;
static int g_atrFallbackCopied = 0;
static bool g_atrFallbackRatesValid = false;
static int g_atrFallbackPeriods[ATR_FALLBACK_VALUE_SLOTS];
static double g_atrFallbackValues[ATR_FALLBACK_VALUE_SLOTS];
static bool g_atrFallbackValueValid[ATR_FALLBACK_VALUE_SLOTS];
static int g_atrFallbackValueCount = 0;

double CalculateATRFallbackFromRates(const MqlRates &rates[], const int copied,
                                      const int atrPeriod, const int shift)
{
    if(atrPeriod <= 0 || shift < 0 || copied < atrPeriod + shift + 2)
        return 0.0;

    // Match the previous per-call CopyRates request. The shared cache may
    // contain more history, but using this period's requested length keeps
    // the seed and Wilder smoothing identical to the old calculation.
    int requestedBars = MathMax(atrPeriod * 3, 60) + shift + 2;
    int usableBars = (copied < requestedBars) ? copied : requestedBars;
    if(usableBars < atrPeriod + shift + 2) return 0.0;

    // TR[i] = max(high-low, |high-prevClose|, |low-prevClose|),
    // prevClose = rates[i+1].close. Initial ATR is the simple average of
    // the oldest computable TRs, followed by Wilder smoothing.
    int anchor = usableBars - 2;
    double sum = 0.0;
    for(int i = 0; i < atrPeriod; i++) {
        int idx = anchor - i;
        double tr = rates[idx].high - rates[idx].low;
        double hc = MathAbs(rates[idx].high - rates[idx + 1].close);
        if(hc > tr) tr = hc;
        double lc = MathAbs(rates[idx].low - rates[idx + 1].close);
        if(lc > tr) tr = lc;
        sum += tr;
    }

    double atr = sum / atrPeriod;
    for(int idx = anchor - 1; idx >= shift; idx--) {
        double tr = rates[idx].high - rates[idx].low;
        double hc = MathAbs(rates[idx].high - rates[idx + 1].close);
        if(hc > tr) tr = hc;
        double lc = MathAbs(rates[idx].low - rates[idx + 1].close);
        if(lc > tr) tr = lc;
        atr = (atr * (atrPeriod - 1) + tr) / atrPeriod;
    }
    return atr;
}

int FindATRFallbackValueSlot(const int atrPeriod)
{
    for(int i = 0; i < g_atrFallbackValueCount; i++) {
        if(g_atrFallbackPeriods[i] == atrPeriod) return i;
    }
    if(g_atrFallbackValueCount >= ATR_FALLBACK_VALUE_SLOTS) return -1;
    int slot = g_atrFallbackValueCount++;
    g_atrFallbackPeriods[slot] = atrPeriod;
    g_atrFallbackValues[slot] = 0.0;
    g_atrFallbackValueValid[slot] = false;
    return slot;
}

void ResetATRFallbackCache()
{
    g_atrFallbackRatesValid = false;
    g_atrFallbackSymbol = "";
    g_atrFallbackTimeframe = PERIOD_CURRENT;
    g_atrFallbackShift = -1;
    g_atrFallbackSourceBars = -1;
    g_atrFallbackLatestBar = 0;
    g_atrFallbackCopied = 0;
    g_atrFallbackValueCount = 0;
    ArrayFree(g_atrFallbackRates);
}

double iATRMQL4(string symbol, int timeframe, int atrPeriod, int shift)
{
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    if(timeframe == PERIOD_CURRENT || timeframe == 0) timeframe = (int)Period();
    if(atrPeriod <= 0 || shift < 0) return 0.0;

    // SymbolSelect is a terminal-side operation; do it once per symbol rather
    // than once for every period in the six-period weighted ATR batch.
    if(g_atrSelectedSymbol != symbol) {
        if(!SymbolSelect(symbol, true)) {
            LOG_E(LOG_CAT_ATR, "iATRMQL4: symbol is not selectable " + symbol);
            return 0.0;
        }
        g_atrSelectedSymbol = symbol;
    }

    int bars = iBars(symbol, timeframe);
    // FIX (2026-07-13): Relaxed the history requirement. Previously this
    // required bars > atrPeriod + shift, which for MN1 (period 264) meant
    // ~22 years of monthly history that most terminals never have loaded.
    // Now we only require enough bars to read at the requested shift; if the
    // period exceeds available bars, iATR returns empty/0 and the caller
    // falls back to a rates-based ATR computed from whatever history exists.
    if(bars <= shift) return 0.0;

    InitATRHandleCache();

    int handle = INVALID_HANDLE;
    int cacheIndex = -1;
    for(int i = 0; i < g_atrHandleCacheCount; i++) {
        if(g_atrHandleCache[i].symbol == symbol &&
           g_atrHandleCache[i].timeframe == (ENUM_TIMEFRAMES)timeframe &&
           g_atrHandleCache[i].period == atrPeriod) {
            handle = g_atrHandleCache[i].handle;
            cacheIndex = i;
            break;
        }
    }

    // NOTE: a handle with BarsCalculated()<=0 must NOT be released. Releasing
    // it restarts the terminal's async calculation from scratch on every call
    // (the label retry polls each second), so slow-to-build timeframes (MN1,
    // W1, D1 - synthesized from M1 on demand) never finish calculating. Keep
    // the handle and serve instant rates-based values until it is ready.
    if(handle == INVALID_HANDLE) {
        handle = iATR(symbol, (ENUM_TIMEFRAMES)timeframe, atrPeriod);
        if(handle == INVALID_HANDLE) {
            LOG_E(LOG_CAT_ATR, "iATRMQL4: failed ATR handle " + symbol + "/" + EnumToString((ENUM_TIMEFRAMES)timeframe));
            return iATRRatesFallback(symbol, (ENUM_TIMEFRAMES)timeframe, atrPeriod, shift);
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
        g_atrHandleCache[slot].timeframe = (ENUM_TIMEFRAMES)timeframe;
        g_atrHandleCache[slot].period = atrPeriod;
    }

    // While the handle is still calculating, return an identical value
    // computed directly from CopyRates (instant, MT4-like) instead of 0.
    if(BarsCalculated(handle) <= 0) {
        return iATRRatesFallback(symbol, (ENUM_TIMEFRAMES)timeframe, atrPeriod, shift);
    }

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
        // Transient data rebuild - serve the rates-based value meanwhile.
        return iATRRatesFallback(symbol, (ENUM_TIMEFRAMES)timeframe, atrPeriod, shift);
    }
    return s_atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Manual Wilder's ATR fallback (MT4-like instant values)           |
//|                                                                  |
//| MT5 iATR handles calculate asynchronously: after creation,       |
//| BarsCalculated() stays 0/-1 until the terminal has built the     |
//| timeframe's history AND run the indicator over all of it. For    |
//| timeframes synthesized from M1 on demand (MN1/W1/D1...) this can |
//| take seconds. CopyRates returns the bars as soon as they exist,  |
//| so computing Wilder's ATR directly from them yields the same     |
//| value instantly - no handle warmup wait. Used only while the     |
//| handle is not ready; once ready, the handle path takes over.     |
//+------------------------------------------------------------------+
double iATRRatesFallback(string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod, const int shift)
{
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    if(atrPeriod <= 0 || shift < 0) return 0.0;

    // Shift 0 includes the forming candle and therefore must remain live.
    // The weighted ATR path requests shift 1, which is stable until a new bar.
    if(shift != 1) {
        int needBars = MathMax(atrPeriod * 3, 60) + shift + 2;
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        int copied = CopyRates(symbol, tf, 0, needBars, rates);
        return CalculateATRFallbackFromRates(rates, copied, atrPeriod, shift);
    }

    int sourceBars = iBars(symbol, tf);
    datetime latestBar = iTime(symbol, tf, 0);
    int requiredForCache = MathMax(atrPeriod * 3,
                                   ATR_FALLBACK_CACHE_BASE_PERIOD * 3) + shift + 2;
    bool cacheMatches = (g_atrFallbackRatesValid &&
                         g_atrFallbackSymbol == symbol &&
                         g_atrFallbackTimeframe == tf &&
                         g_atrFallbackShift == shift &&
                         g_atrFallbackSourceBars == sourceBars &&
                         g_atrFallbackLatestBar == latestBar &&
                         (g_atrFallbackCopied >= requiredForCache ||
                          sourceBars <= g_atrFallbackCopied));

    if(!cacheMatches) {
        ArrayResize(g_atrFallbackRates, requiredForCache);
        ArraySetAsSeries(g_atrFallbackRates, true);
        int copied = CopyRates(symbol, tf, 0, requiredForCache, g_atrFallbackRates);
        if(copied <= 0) {
            ResetATRFallbackCache();
            return 0.0;
        }

        g_atrFallbackSymbol = symbol;
        g_atrFallbackTimeframe = tf;
        g_atrFallbackShift = shift;
        g_atrFallbackSourceBars = sourceBars;
        g_atrFallbackLatestBar = latestBar;
        g_atrFallbackCopied = copied;
        g_atrFallbackRatesValid = true;
        g_atrFallbackValueCount = 0;
    }

    int slot = FindATRFallbackValueSlot(atrPeriod);
    if(slot >= 0 && g_atrFallbackValueValid[slot])
        return g_atrFallbackValues[slot];

    double result = CalculateATRFallbackFromRates(g_atrFallbackRates,
                                                   g_atrFallbackCopied,
                                                   atrPeriod, shift);
    if(slot >= 0) {
        g_atrFallbackValues[slot] = result;
        g_atrFallbackValueValid[slot] = true;
    }
    return result;
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
    g_atrSelectedSymbol = "";
    ResetATRFallbackCache();
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

//+------------------------------------------------------------------+
//| MQL4 predefined series arrays (Time[], Open[], High[], Low[],    |
//| Close[], Bars) emulation. MQL5 has no built-in series variables,  |
//| so the shared modules read these globals (index 0 = current bar,  |
//| exactly like MQL4). CompatRefreshChartData() must be called from  |
//| the indicator main file on every OnCalculate and OnTimer.        |
//+------------------------------------------------------------------+
static MqlRates   g_seriesRates[];
static datetime   g_seriesTime[];
static double     g_seriesOpen[];
static double     g_seriesHigh[];
static double     g_seriesLow[];
static double     g_seriesClose[];
static int        g_seriesBars     = 0;
static int        g_seriesSyncedAt = -1;

#define Time  g_seriesTime
#define Open  g_seriesOpen
#define High  g_seriesHigh
#define Low   g_seriesLow
#define Close g_seriesClose
#define Bars  g_seriesBars

void CompatRefreshChartData()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if(bars <= 0) return;

    // Full re-sync whenever the visible bar count changes (new bar /
    // history download). Otherwise only the forming bar (index 0) moves.
    if(bars != g_seriesSyncedAt)
    {
        ResetLastError();
        ArraySetAsSeries(g_seriesRates, true);
        int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, bars, g_seriesRates);
        if(copied > 0)
        {
            ArrayResize(g_seriesTime, copied);
            ArrayResize(g_seriesOpen, copied);
            ArrayResize(g_seriesHigh, copied);
            ArrayResize(g_seriesLow, copied);
            ArrayResize(g_seriesClose, copied);
            ArraySetAsSeries(g_seriesTime, true);
            ArraySetAsSeries(g_seriesOpen, true);
            ArraySetAsSeries(g_seriesHigh, true);
            ArraySetAsSeries(g_seriesLow, true);
            ArraySetAsSeries(g_seriesClose, true);
            for(int i = 0; i < copied; i++)
            {
                g_seriesTime[i]  = g_seriesRates[i].time;
                g_seriesOpen[i]  = g_seriesRates[i].open;
                g_seriesHigh[i]  = g_seriesRates[i].high;
                g_seriesLow[i]   = g_seriesRates[i].low;
                g_seriesClose[i] = g_seriesRates[i].close;
            }
            g_seriesBars = copied;
            g_seriesSyncedAt = bars;
            return;
        }
        // CopyRates failed (history still loading) - keep old arrays,
        // refresh only the current bar below and retry next call.
    }

    // Same bar count (or failed full sync): refresh only the forming bar's
    // moving values (Time[0]/Open[0] are fixed once a bar starts).
    if(g_seriesBars > 0)
    {
        g_seriesHigh[0]  = iHigh(_Symbol, PERIOD_CURRENT, 0);
        g_seriesLow[0]   = iLow(_Symbol, PERIOD_CURRENT, 0);
        g_seriesClose[0] = iClose(_Symbol, PERIOD_CURRENT, 0);
    }
}

//+------------------------------------------------------------------+
//| MQL4 object API shims. This MQL5 build does not define the        |
//| OBJPROP_PRICE1/PRICE2/TIME1/TIME2 constants, so they are mapped  |
//| onto OBJPROP_PRICE/OBJPROP_TIME with the anchor-point modifier.  |
//| The MQL4 call forms of ObjectsTotal/ObjectName/ObjectFind are    |
//| provided via rename macros; the built-ins stay reachable through |
//| the *_Real helpers defined before the renames.                   |
//+------------------------------------------------------------------+
#ifndef OBJPROP_TIME1
#define OBJPROP_TIME1  ((ENUM_OBJECT_PROPERTY_INTEGER)2010)
#endif
#ifndef OBJPROP_TIME2
#define OBJPROP_TIME2  ((ENUM_OBJECT_PROPERTY_INTEGER)2012)
#endif
#ifndef OBJPROP_PRICE1
#define OBJPROP_PRICE1 ((ENUM_OBJECT_PROPERTY_DOUBLE)2011)
#endif
#ifndef OBJPROP_PRICE2
#define OBJPROP_PRICE2 ((ENUM_OBJECT_PROPERTY_DOUBLE)2013)
#endif

bool ObjectSetDoubleReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const double value)
{
    return ObjectSetDouble(chart_id, name, prop, value);
}

bool ObjectSetDoubleRealMod(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier, const double value)
{
    return ObjectSetDouble(chart_id, name, prop, modifier, value);
}

#define ObjectSetDouble ObjectSetDoubleCompat

bool ObjectSetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const double value)
{
    if(prop == OBJPROP_PRICE1) return ObjectSetDoubleRealMod(chart_id, name, OBJPROP_PRICE, 0, value);
    if(prop == OBJPROP_PRICE2) return ObjectSetDoubleRealMod(chart_id, name, OBJPROP_PRICE, 1, value);
    return ObjectSetDoubleReal(chart_id, name, prop, value);
}

bool ObjectSetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier, const double value)
{
    return ObjectSetDoubleRealMod(chart_id, name, prop, modifier, value);
}

double ObjectGetDoubleReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier)
{
    return ObjectGetDouble(chart_id, name, prop, modifier);
}

#define ObjectGetDouble ObjectGetDoubleCompat

double ObjectGetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier = 0)
{
    if(prop == OBJPROP_PRICE1) return ObjectGetDoubleReal(chart_id, name, OBJPROP_PRICE, 0);
    if(prop == OBJPROP_PRICE2) return ObjectGetDoubleReal(chart_id, name, OBJPROP_PRICE, 1);
    return ObjectGetDoubleReal(chart_id, name, prop, modifier);
}

bool ObjectSetIntegerReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const long value)
{
    return ObjectSetInteger(chart_id, name, prop, value);
}

bool ObjectSetIntegerRealMod(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier, const long value)
{
    return ObjectSetInteger(chart_id, name, prop, modifier, value);
}

#define ObjectSetInteger ObjectSetIntegerCompat

bool ObjectSetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const long value)
{
    if(prop == OBJPROP_TIME1) return ObjectSetIntegerRealMod(chart_id, name, OBJPROP_TIME, 0, value);
    if(prop == OBJPROP_TIME2) return ObjectSetIntegerRealMod(chart_id, name, OBJPROP_TIME, 1, value);
    return ObjectSetIntegerReal(chart_id, name, prop, value);
}

bool ObjectSetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier, const long value)
{
    return ObjectSetIntegerRealMod(chart_id, name, prop, modifier, value);
}

int ObjectsTotalReal(const long chart_id, const int type, const bool selected)
{
    return ObjectsTotal(chart_id, type, selected);
}

#define ObjectsTotal ObjectsTotalCompat

int ObjectsTotalCompat()
{
    return ObjectsTotalReal(0, -1, false);
}

int ObjectsTotalCompat(const long chart_id, const int type, const int selected)
{
    return ObjectsTotalReal(chart_id, type, selected != 0);
}

string ObjectNameReal(const long chart_id, const int pos, const int sub_window, const int type)
{
    return ObjectName(chart_id, pos, sub_window, type);
}

#define ObjectName ObjectNameCompat

string ObjectNameCompat(const int pos)
{
    return ObjectNameReal(0, pos, -1, -1);
}

string ObjectNameCompat(const long chart_id, const int pos)
{
    return ObjectNameReal(chart_id, pos, -1, -1);
}

string ObjectNameCompat(const long chart_id, const int pos, const int sub_window, const int type)
{
    return ObjectNameReal(chart_id, pos, sub_window, type);
}

int ObjectFindReal(const long chart_id, const string name)
{
    return ObjectFind(chart_id, name);
}

#define ObjectFind ObjectFindCompat

int ObjectFindCompat(const string name)
{
    return ObjectFindReal(0, name);
}

int ObjectFindCompat(const long chart_id, const string name)
{
    return ObjectFindReal(chart_id, name);
}

#endif // MQL5_COMPAT_MQH
