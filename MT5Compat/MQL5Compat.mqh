#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

#define Bid    SymbolInfoDouble(_Symbol, SYMBOL_BID)
#define Ask    SymbolInfoDouble(_Symbol, SYMBOL_ASK)
#define Digits _Digits
#define Point  _Point

// MQL5 has no Symbol(); the shared MQL4 modules call it 110 times.
#define Symbol() _Symbol

// MQL4 series-function bridges: MQL5's iHigh/iLow/iOpen/iClose/iTime/iBars
// take ENUM_TIMEFRAMES, while the shared MQL4 modules pass a timeframe in
// MINUTES (the MQL4 model - see R-TF-UNIT in Biotak/BuildConfig.mqh). The
// self-referential macros route the argument through CompatTF() without
// infinite expansion.
//
// This used to be a bare "(ENUM_TIMEFRAMES)(tf)" cast, which was harmless only
// for as long as every caller happened to pass a value that was already an enum
// constant. Once the minutes model is made explicit that cast would turn 60
// into an invalid timeframe instead of H1, so the conversion is the point.
#define iBars(sym, tf)  iBars(sym, CompatTF(tf))
#define iTime(sym, tf, sh)  iTime(sym, CompatTF(tf), sh)
#define iHigh(sym, tf, sh)  iHigh(sym, CompatTF(tf), sh)
#define iLow(sym, tf, sh)   iLow(sym, CompatTF(tf), sh)
#define iOpen(sym, tf, sh)  iOpen(sym, CompatTF(tf), sh)
#define iClose(sym, tf, sh) iClose(sym, CompatTF(tf), sh)

// The raw builtin, reachable from anywhere in this shim that genuinely needs
// the ENUM_TIMEFRAMES rather than the minute count. It must stay ABOVE the
// "#define Period()" at the foot of this file, where the builtin still exists.
ENUM_TIMEFRAMES CompatRawPeriod() { return Period(); }

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
// MQL4 returns -1 when the object does not exist. MQL5's ObjectGetInteger
// returns 0 on failure, and 0 is a REAL object type (OBJ_VLINE), so without
// the existence test a missing object would read as a live vertical line.
int ObjectType(const string name)
{
    if(ObjectFind(0, name) < 0) return -1;
    return (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
}

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
    if(tf == PERIOD_CURRENT || tf == 0) tf = CompatRawPeriod();
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
    // `timeframe` arrives in EITHER unit: the shared ATR modules pass minutes
    // (the MQL4 model - ATRCalculations' own ladders are built on it) while
    // CalculateATRBatchTrex/GetTriggerDurationSeconds pass a real
    // ENUM_TIMEFRAMES. CompatTF() resolves both, which is why every handoff
    // below goes through it rather than through a bare cast. The bare cast used
    // to be harmless purely by accident: callers were passing enum constants.
    if(timeframe == PERIOD_CURRENT || timeframe == 0) timeframe = CompatPeriodMinutes();
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
           g_atrHandleCache[i].timeframe == CompatTF(timeframe) &&
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
        handle = iATR(symbol, CompatTF(timeframe), atrPeriod);
        if(handle == INVALID_HANDLE) {
            LOG_E(LOG_CAT_ATR, "iATRMQL4: failed ATR handle " + symbol + "/" + EnumToString(CompatTF(timeframe)));
            return iATRRatesFallback(symbol, CompatTF(timeframe), atrPeriod, shift);
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
        g_atrHandleCache[slot].timeframe = CompatTF(timeframe);
        g_atrHandleCache[slot].period = atrPeriod;
    }

    // While the handle is still calculating, return an identical value
    // computed directly from CopyRates (instant, MT4-like) instead of 0.
    if(BarsCalculated(handle) <= 0) {
        return iATRRatesFallback(symbol, CompatTF(timeframe), atrPeriod, shift);
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
        Print("iATRMQL4: CopyBuffer failed for ", symbol, "/", EnumToString(CompatTF(timeframe)),
              " period=", atrPeriod, " shift=", shift, " error=", GetLastError());
        #endif
        // Transient data rebuild - serve the rates-based value meanwhile.
        return iATRRatesFallback(symbol, CompatTF(timeframe), atrPeriod, shift);
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
// P-MT5-01: the MqlRates staging array is GONE with the CopyRates path it
// existed for - five native Copy* calls fill the arrays below directly.
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

// P-MT5-01 (2026-09-16) - THE FULL RE-SYNC WAS THE EXPENSIVE HALF, AND IT
// COULD RUN ON EVERY TICK.
//
// The full re-sync used to be
//     CopyRates(..., bars, g_seriesRates)   +   a 5-array per-element copy loop
// which on a 100k-bar chart allocated a ~6 MB MqlRates array and then ran
// 500,000 interpreter-level assignments. Worse, it re-ran on EVERY CALL while
// the copy kept failing or while history was still arriving: the bar count
// changes as history downloads, and a FAILED copy deliberately leaves
// `g_seriesSyncedAt` untouched so the next call tries the whole thing again.
// `OnCalculate` calls this once per tick - and this terminal is exactly the
// case that trips it, logging "Waiting for historical data (PERIOD_MN1)" and
// error 4401. MT4 has no equivalent cost at all: its series arrays are native.
//
// Two changes, both MT5-only:
//
//   1. FIVE NATIVE Copy* CALLS instead of CopyRates + the element loop. Same
//      values, same series order (the AS_SERIES flag is set before the copy,
//      exactly as the rates array always had it), but no 6 MB intermediate and
//      no 500k-statement loop.
//
//   2. A FLOOR BETWEEN FULL-SYNC ATTEMPTS. A failing or still-growing history
//      can no longer turn every tick into a full-history copy attempt. A
//      legitimate new bar is therefore delayed by at most this floor, which is
//      invisible next to a 15.6 ms tick - and the forming-bar refresh below
//      keeps the current bar live on every call either way.
#define COMPAT_FULL_SYNC_MIN_MS 500

void CompatRefreshChartData()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if(bars <= 0) return;

    // Full re-sync whenever the bar count changes (new bar / history
    // download). Otherwise only the forming bar (index 0) moves.
    if(bars != g_seriesSyncedAt)
    {
        static uint s_lastFullSyncMs = 0;
        const uint nowMs = GetTickCount();
        const bool due = (s_lastFullSyncMs == 0) ||
                         ((nowMs - s_lastFullSyncMs) >= (uint)COMPAT_FULL_SYNC_MIN_MS);
        if(due)
        {
            s_lastFullSyncMs = nowMs;
            ResetLastError();
            // The AS_SERIES flag must be set BEFORE the copy so the copied
            // data lands in timeseries order (index 0 = current bar) - the
            // same contract the old rates array was given.
            ArraySetAsSeries(g_seriesTime, true);
            ArraySetAsSeries(g_seriesOpen, true);
            ArraySetAsSeries(g_seriesHigh, true);
            ArraySetAsSeries(g_seriesLow, true);
            ArraySetAsSeries(g_seriesClose, true);

            const int cT  = CopyTime (_Symbol, PERIOD_CURRENT, 0, bars, g_seriesTime);
            const int cO  = CopyOpen (_Symbol, PERIOD_CURRENT, 0, bars, g_seriesOpen);
            const int cH  = CopyHigh (_Symbol, PERIOD_CURRENT, 0, bars, g_seriesHigh);
            const int cL  = CopyLow  (_Symbol, PERIOD_CURRENT, 0, bars, g_seriesLow);
            const int cC  = CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, g_seriesClose);

            // All five must describe the SAME bars, because every consumer
            // indexes all of them with one index. Trim to the shortest.
            const int copied = MathMin(cT, MathMin(cO, MathMin(cH, MathMin(cL, cC))));
            if(copied > 0)
            {
                ArrayResize(g_seriesTime,  copied);
                ArrayResize(g_seriesOpen,  copied);
                ArrayResize(g_seriesHigh,  copied);
                ArrayResize(g_seriesLow,   copied);
                ArrayResize(g_seriesClose, copied);
                g_seriesBars     = copied;
                g_seriesSyncedAt = bars;
                return;
            }
            // Copy failed (history still loading) - keep the old arrays and
            // retry after the floor above, not on the next tick.
        }
    }

    // Same bar count (or a full sync not yet due / just failed): refresh only
    // the forming bar's moving values (Time[0]/Open[0] are fixed once a bar
    // starts).
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
//+------------------------------------------------------------------+
//| MT5-ONLY: redundant-property-write filter.                        |
//|                                                                  |
//| Included HERE, before the ObjectSet* shims below, because those   |
//| shims are its call sites - and before every shared module, so the  |
//| whole codebase's object writes pass through it on MT5 while MT4    |
//| (which never includes this folder) is untouched by construction.   |
//| See the file's own header for why this is safe and what it fixes.  |
//+------------------------------------------------------------------+
#include "MT5ObjWriteFilter.mqh"

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
    // MT5-ONLY: a write of the value we already wrote is redundant, so the
    // terminal call is skipped and `true` (the state the caller asked for)
    // is returned. See MT5ObjWriteFilter.mqh for the safety argument.
    if(OwSkipDbl(chart_id, name, (int)prop, 0, value)) return true;
    const bool ok = ObjectSetDoubleReal(chart_id, name, prop, value);
    if(ok) OwNoteDbl(chart_id, name, (int)prop, 0, value);
    return ok;
}

bool ObjectSetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier, const double value)
{
    if(OwSkipDbl(chart_id, name, (int)prop, modifier, value)) return true;
    const bool ok = ObjectSetDoubleRealMod(chart_id, name, prop, modifier, value);
    if(ok) OwNoteDbl(chart_id, name, (int)prop, modifier, value);
    return ok;
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
    // MT5-ONLY redundant-write filter (MT5ObjWriteFilter.mqh). Properties the
    // terminal or the user can change (STATE, SELECTED, TIME*, PRICE*) are not
    // in its allowlist, so this can never mask a write that was still needed.
    if(OwSkipInt(chart_id, name, (int)prop, 0, value)) return true;
    const bool ok = ObjectSetIntegerReal(chart_id, name, prop, value);
    if(ok) OwNoteInt(chart_id, name, (int)prop, 0, value);
    return ok;
}

bool ObjectSetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier, const long value)
{
    if(OwSkipInt(chart_id, name, (int)prop, modifier, value)) return true;
    const bool ok = ObjectSetIntegerRealMod(chart_id, name, prop, modifier, value);
    if(ok) OwNoteInt(chart_id, name, (int)prop, modifier, value);
    return ok;
}

//+------------------------------------------------------------------+
//| ObjectsTotal - the previous shim was CORRUPTING the object count. |
//|                                                                  |
//| MQL5 signature:                                                   |
//|     int ObjectsTotal(long chart_id, int sub_window=-1, int type=-1) |
//| The THIRD parameter is the object TYPE.                           |
//|                                                                  |
//| The old shim declared it as                                    |
//|     ObjectsTotalCompat(chart_id, type, selected)                  |
//|     { return ObjectsTotal(chart_id, type, selected != 0); }       |
//| so the call ObjectsTotal(0, -1, -1) - the form used by all 45 live |
//| call sites - became ObjectsTotal(0, -1, true) and `true` decayed to|
//| int 1. The function therefore returned the number of OBJ_HLINE     |
//| objects ONLY (OBJ_VLINE=0, OBJ_HLINE=1), not all objects.          |
//|                                                                  |
//| Every consumer then walked the chart with a truncated bound while  |
//| ObjectName(0, i) still indexed the FULL object list, so the count  |
//| and the enumeration disagreed:                                      |
//|   ObjectCache::CacheRebuild          - cached a fraction of objects |
//|   VisibilityManager::HideAllLegacyScan - hid only the first N,      |
//|                                          leaving ghost levels       |
//|   ObjectCountManager / MemoryManager  - budget and accounting wrong |
//|                                                                  |
//| The fix passes every argument through untouched, so the built-in    |
//| semantics apply and MT4 and MT5 agree. The zero-argument MQL4 form  |
//| is kept (MQL5 requires chart_id) and now means ALL objects.         |
//+------------------------------------------------------------------+
int ObjectsTotalReal(const long chart_id, const int sub_window, const int type)
{
    return ObjectsTotal(chart_id, sub_window, type);
}

#define ObjectsTotal ObjectsTotalCompat

int ObjectsTotalCompat()
{
    return ObjectsTotalReal(0, -1, -1);
}

int ObjectsTotalCompat(const long chart_id, const int sub_window, const int type)
{
    return ObjectsTotalReal(chart_id, sub_window, type);
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

//+------------------------------------------------------------------+
//| R-TF-UNIT, the MT5 half: make Period() mean what it means on MT4. |
//|                                                                  |
//| MQL5's Period() returns an ENUM_TIMEFRAMES (H1 == 16385). MQL4's  |
//| returned the length in minutes (H1 == 60). The shared source is   |
//| written against the MQL4 meaning in ~60 places - plain            |
//| comparisons, arithmetic, cache keys, BaseKnotTFName(), the ATR    |
//| timeframe ladders, the HTF snap ladder - and every one of those   |
//| is silently wrong on MT5 while still being a perfectly valid       |
//| integer.                                                          |
//|                                                                  |
//| Restoring the meaning here, once, is what makes the mirror         |
//| genuinely a mirror: it fixes all of those call sites without       |
//| touching a single shared line, and it keeps them fixed if someone  |
//| adds another one tomorrow.                                         |
//|                                                                  |
//| This MUST stay at the foot of this file: everything above it that  |
//| needs the raw builtin (PeriodMinutes(), CompatRawPeriod()) is      |
//| already compiled by the time the macro exists.                     |
//|                                                                  |
//| Anywhere that genuinely needs an ENUM_TIMEFRAMES goes through      |
//| CompatTF() - that is the one sanctioned crossing.                  |
//+------------------------------------------------------------------+
#define Period() CompatPeriodMinutes()

#endif // MQL5_COMPAT_MQH
