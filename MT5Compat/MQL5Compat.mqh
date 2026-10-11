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

// iBarShift carries the SAME minute-vs-enum crossing as the family above, but
// it was the one member left unwrapped because MQL5 now ships it as a built-in
// (note below). Every shared call that passes a minute count - `iBarShift(NULL,
// tf, t)` on a TH3 pivot scan, `iBarShift(_Symbol, Period(), t)` in the math
// helpers - was therefore rejected with `error 262: cannot convert enum`, while
// the sites that pass the literal 0 ("current timeframe", 0 on both platforms)
// compiled and hid the gap.
//
// Two overloads restore the MQL4 contract without touching a shared line: the
// enum form passes through, the int form is a minute count and crosses through
// CompatTF() - which is also what makes a call that ALREADY carries an enum
// (BaseKnotTool's CompatTF(tfMin)) still land on the right timeframe. The 4th
// `exact` argument is honoured on both. The name is re-pointed at the pair, so
// a future call site cannot fall through to the built-in and trap a minute
// value inside an enum parameter again.
int iBarShiftReal(const string symbol, const ENUM_TIMEFRAMES tf, const datetime time, const bool exact)
{
    return iBarShift(symbol, tf, time, exact);
}

#define iBarShift iBarShiftCompat

int iBarShiftCompat(const string symbol, const ENUM_TIMEFRAMES tf, const datetime time, const bool exact = false)
{
    return iBarShiftReal(symbol, tf, time, exact);
}

int iBarShiftCompat(const string symbol, const int tf, const datetime time, const bool exact = false)
{
    return iBarShiftReal(symbol, CompatTF(tf), time, exact);
}

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

// MQL4 StringGetChar(text, pos) -> MQL5 StringGetCharacter(text, pos).
// MQL4 returns the code point as int, MQL5 as ushort - same number, and every
// shared caller compares it against an ASCII literal (95 '_', 72 'H', 48..57
// digits). PathTool.mqh is the caller that made this necessary: it is MT4 code
// carried into a terminal whose only spelling of the function has the long name.
int StringGetChar(const string text, const int pos) { return (int)StringGetCharacter(text, pos); }

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
// shared history block and the already-computed period values; the cache is
// invalidated when the source timeframe advances. Its window is the MT4-equal
// one from ATRFallbackWindow() - see the note above that function.
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

//----------------------------------------------------------------------------
// ATR fallback window - MT4-EQUALITY FIX (2026-10-03)
//
// Wilder's ATR is a recursion: the seed (a simple mean of the oldest computable
// true ranges) never fully disappears, it decays by (1 - 1/period) per bar.
// Seeding only 3*period bars back left ~e^-2 = 13% of that seed inside the
// answer for period 14 - a DIFFERENT number from MQL4's iATR and from MQL5's
// own built-in ATR, both of which smooth over the whole loaded history. That
// difference reached the ladder step, so every drawn level moved.
//
// The window below and a seed at the OLDEST copied bar make the residual
// smaller than 1e-5 for every period this project uses (the largest is 264 on
// MN1): 3000+ bars back, or every bar the terminal actually has, whichever is
// fewer - which is exactly what MT4 does when history is short.
#define ATR_FALLBACK_MIN_BARS 3000

int ATRFallbackWindow(const int atrPeriod, const int shift, const int sourceBars)
{
    int need = atrPeriod * 3 + shift + 2;
    if(need < ATR_FALLBACK_MIN_BARS) need = ATR_FALLBACK_MIN_BARS;
    if(sourceBars > 0 && need > sourceBars) need = sourceBars;
    if(need < atrPeriod + shift + 2) need = atrPeriod + shift + 2;
    return need;
}

double CalculateATRFallbackFromRates(const MqlRates &rates[], const int copied,
                                      const int atrPeriod, const int shift)
{
    if(atrPeriod <= 0 || shift < 0 || copied < atrPeriod + shift + 2)
        return 0.0;

    // Use EVERY bar the caller could obtain: the more history behind the seed,
    // the closer this is to the value MQL4's iATR reports (see the window note
    // above - the seed sits at the oldest bar of this array).
    int usableBars = copied;
    if(usableBars < atrPeriod + shift + 2) return 0.0;

    // TR[i] = max(high-low, |high-prevClose|, |low-prevClose|),
    // prevClose = rates[i+1].close. Initial ATR is the simple average of
    // the oldest computable TRs, followed by Wilder smoothing - the seed is at
    // the OLDEST end of the copied window (MT4's own convention).
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
        int needBars = ATRFallbackWindow(atrPeriod, shift, iBars(symbol, tf));
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        int copied = CopyRates(symbol, tf, 0, needBars, rates);
        return CalculateATRFallbackFromRates(rates, copied, atrPeriod, shift);
    }

    int sourceBars = iBars(symbol, tf);
    datetime latestBar = iTime(symbol, tf, 0);
    int widestPeriod = (atrPeriod > ATR_FALLBACK_CACHE_BASE_PERIOD)
                       ? atrPeriod : ATR_FALLBACK_CACHE_BASE_PERIOD;
    int requiredForCache = ATRFallbackWindow(widestPeriod, shift, sourceBars);
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
// P-MT5-01: MQL4 predefined series arrays emulation.
// P-PERF-MT5-01 (2026-10-11): ONE CopyRates call replaces five separate
// Copy* calls. Five independent kernel-side locks per full sync → one lock.
// On a 100k-bar chart that was 5 × 800 KB = 4 MB of independent copies;
// now it is ONE 4.8 MB MqlRates read that the OS pages from one contiguous
// region. The five separate array unpackings below cost ~5 ns each (scalar
// stores into pre-allocated arrays) — the syscall saving is the whole win.
//
// Open[] is kept: CalculateTrueRange uses it for the oldest bar's prevClose
// fallback (ATRCalculations.mqh:225). Removing it would break that edge case.
//
// STEADY-STATE PATH (same bar count): only 3 scalar iHigh/iLow/iClose reads
// for the forming bar — unchanged and unchanged in cost.
static MqlRates    g_seriesRates[];
static datetime    g_seriesTime[];
static double      g_seriesOpen[];
static double      g_seriesHigh[];
static double      g_seriesLow[];
static double      g_seriesClose[];
static int         g_seriesBars     = 0;
static int         g_seriesSyncedAt = -1;

#define Time  g_seriesTime
#define Open  g_seriesOpen
#define High  g_seriesHigh
#define Low   g_seriesLow
#define Close g_seriesClose
#define Bars  g_seriesBars

// Floor between full-sync attempts: history-download churn cannot turn
// every tick into a full-history copy attempt.
#define COMPAT_FULL_SYNC_MIN_MS 500

// P-MT5-TF-SPEED (2026-10-XX) — CAP THE FULL-SYNC WINDOW.
// MT4 never copies "all history" on a TF switch — its Time[]/Close[] are
// predefined kernel arrays that the terminal fills instantly. The MQL5 compat
// layer used to call CopyRates(0, bars, ...) where `bars` is the TOTAL chart
// history (up to 100k+ bars on XAUUSD H1). That one call alone accounted for
// the TF-switch stall: 100k × 72 bytes MqlRates → 5 × 100k scalar unpacks.
//
// The shared modules only ever look back MAX_BARS_LOOKBACK (10 000) bars.
// ZoneFactory and ExtendedDrawingFunctions reference Time[safeBars-1] where
// safeBars = Bars; that is bounded by this cap, and iBarShift / iATR calls
// use explicit shifts that are capped to their own callers' ranges (400 for
// the pivot scanner, 500 for TH3RealDAt). Adding a 20% safety margin gives
// 12 000 bars — well above any real caller depth.
//
// On a TF switch: instead of copying 100k bars in O(n), we copy 12k and the
// visible chart settles at the same latency as MT4 does.
//
// g_seriesBars continues to reflect the ACTUAL available bar count (from
// iBars), so any caller that reads Bars for range-checking still gets the
// true number; only the backing arrays are capped.
#define COMPAT_SERIES_WINDOW 12000

void CompatRefreshChartData()
{
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if(bars <= 0) return;

    // Full re-sync whenever the bar count changes (new bar / history download).
    // Otherwise only the forming bar (index 0) moves.
    if(bars != g_seriesSyncedAt)
    {
        static uint s_lastFullSyncMs = 0;
        const uint nowMs = GetTickCount();
        const bool due = (s_lastFullSyncMs == 0) ||
                         ((nowMs - s_lastFullSyncMs) >= (uint)COMPAT_FULL_SYNC_MIN_MS);
        if(due)
        {
            // R-TF-UNIT: stamp AFTER a successful copy, not before.
            // Stamping before meant: if CopyRates fails (history still
            // downloading on a TF switch), the 500 ms throttle fires and
            // every OnCalculate call within that window skips the retry.
            // The indicator then runs with g_seriesBars = 0 (arrays empty)
            // until a new bar arrives — on H4 that can be hours.
            // Stamping after success means a failed attempt is retried on
            // the very next tick, while a successful one is throttled
            // normally so history-churn cannot monopolise the CPU.
            ResetLastError();
            // P-MT5-TF-SPEED: copy only the working window, not the entire history.
            const int copyCount = (bars < COMPAT_SERIES_WINDOW) ? bars : COMPAT_SERIES_WINDOW;
            ArraySetAsSeries(g_seriesRates, true);
            const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, copyCount, g_seriesRates);
            if(copied > 0)
            {
                s_lastFullSyncMs = nowMs;   // throttle ONLY after success
                // Unpack MqlRates into the five named series arrays.
                // ArrayResize with the exact count avoids reallocating on every
                // tick when the count is stable (MQL5 only grows, never shrinks).
                ArrayResize(g_seriesTime,  copied);
                ArrayResize(g_seriesOpen,  copied);
                ArrayResize(g_seriesHigh,  copied);
                ArrayResize(g_seriesLow,   copied);
                ArrayResize(g_seriesClose, copied);
                for(int i = 0; i < copied; i++)
                {
                    g_seriesTime[i]  = g_seriesRates[i].time;
                    g_seriesOpen[i]  = g_seriesRates[i].open;
                    g_seriesHigh[i]  = g_seriesRates[i].high;
                    g_seriesLow[i]   = g_seriesRates[i].low;
                    g_seriesClose[i] = g_seriesRates[i].close;
                }
                // R-TF-UNIT (P-MT5-TF-SPEED): g_seriesBars = copied, NOT bars.
                // The arrays have exactly `copied` elements (capped at
                // COMPAT_SERIES_WINDOW). Any code that reads Time[Bars-1] must
                // find a valid index; setting g_seriesBars = bars (total history,
                // possibly 100k) while the array is only 12k causes out-of-bounds
                // access in ZoneFactory and ExtendedDrawingFunctions.
                // Callers that need the true chart history depth call
                // iBars(_Symbol, PERIOD_CURRENT) directly — that bypasses this
                // variable and hits the MT5 kernel.
                g_seriesBars     = copied;
                g_seriesSyncedAt = bars;
                ArrayFree(g_seriesRates);   // release staging memory immediately
                return;
            }
            // Copy failed (history still loading) — do NOT stamp s_lastFullSyncMs.
            // The next tick will retry immediately (due = true again) until the
            // history arrives. Once it does, the stamp fires and throttling begins.
        }
    }

    // Same bar count (or full sync not yet due / just failed): refresh only
    // the forming bar's moving values (Time[0]/Open[0] are fixed once the bar
    // opens).
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
// NOTE: the MT5-only redundant-property-write filter was REMOVED (2026-10-03,
// "exactly like MT4 - nothing more"). Every ObjectSet* call below now reaches
// the terminal like it does on MT4.

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

//+------------------------------------------------------------------+
//| MT5-ONLY: the MQL4 PROPERTY-ID form of the object accessors.      |
//|                                                                  |
//| MQL4 declares the property as a plain int - `ObjectGetInteger(0,  |
//| name, int prop_id, int modifier=0)`, `ObjectSetString(0, name,    |
//| int prop_id, string value)` - while MQL5 requires                  |
//| ENUM_OBJECT_PROPERTY_INTEGER / _STRING. The shared source contains |
//| generic writers that receive the property as `const int prop`      |
//| (DrawStripSetInt/SetStr/SetStr2 - the strip's whole write path,    |
//| BoxSetInt/BoxSetColor for the base box, PathFamilySet for the path |
//| segments) and forwards it untouched, exactly as MQL4 asks. Under   |
//| MQL5 every one of those lines is `error 262: cannot convert enum`. |
//|                                                                  |
//| The shared source must keep compiling on MT4, so the crossing      |
//| belongs HERE: an int overload that casts once and delegates to the |
//| enum form above/below it. Delegating (rather than casting straight |
//| to the built-in) keeps the write filter and the MQL4 TIME1/TIME2    |
//| anchor translation in the path for an int-prop write too.          |
//+------------------------------------------------------------------+
long ObjectGetIntegerReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier)
{
    return ObjectGetInteger(chart_id, name, prop, modifier);
}

#define ObjectGetInteger ObjectGetIntegerCompat

long ObjectGetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier = 0)
{
    return ObjectGetIntegerReal(chart_id, name, prop, modifier);
}

long ObjectGetIntegerCompat(const long chart_id, const string name, const int prop, const int modifier = 0)
{
    return ObjectGetIntegerReal(chart_id, name, (ENUM_OBJECT_PROPERTY_INTEGER)prop, modifier);
}

string ObjectGetStringReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier)
{
    return ObjectGetString(chart_id, name, prop, modifier);
}

// The MQL4/MQL5 OUTPUT-parameter form (`ObjectGetString(0, nm, OBJPROP_TEXT,
// 0, tx)`) is used by the profiler's label scan, so the bridge must cover it
// too - the returning form alone would leave those five-argument calls without
// a match once the name is re-pointed below.
bool ObjectGetStringRealOut(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier, string &value)
{
    return ObjectGetString(chart_id, name, prop, modifier, value);
}

#define ObjectGetString ObjectGetStringCompat

string ObjectGetStringCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier = 0)
{
    return ObjectGetStringReal(chart_id, name, prop, modifier);
}

string ObjectGetStringCompat(const long chart_id, const string name, const int prop, const int modifier = 0)
{
    return ObjectGetStringReal(chart_id, name, (ENUM_OBJECT_PROPERTY_STRING)prop, modifier);
}

bool ObjectGetStringCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier, string &value)
{
    return ObjectGetStringRealOut(chart_id, name, prop, modifier, value);
}

bool ObjectGetStringCompat(const long chart_id, const string name, const int prop, const int modifier, string &value)
{
    return ObjectGetStringRealOut(chart_id, name, (ENUM_OBJECT_PROPERTY_STRING)prop, modifier, value);
}

bool ObjectSetStringReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const string value)
{
    return ObjectSetString(chart_id, name, prop, value);
}

bool ObjectSetStringRealMod(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier, const string value)
{
    return ObjectSetString(chart_id, name, prop, modifier, value);
}

#define ObjectSetString ObjectSetStringCompat

bool ObjectSetStringCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const string value)
{
    return ObjectSetStringReal(chart_id, name, prop, value);
}

bool ObjectSetStringCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_STRING prop, const int modifier, const string value)
{
    return ObjectSetStringRealMod(chart_id, name, prop, modifier, value);
}

bool ObjectSetStringCompat(const long chart_id, const string name, const int prop, const string value)
{
    return ObjectSetStringReal(chart_id, name, (ENUM_OBJECT_PROPERTY_STRING)prop, value);
}

bool ObjectSetStringCompat(const long chart_id, const string name, const int prop, const int modifier, const string value)
{
    return ObjectSetStringRealMod(chart_id, name, (ENUM_OBJECT_PROPERTY_STRING)prop, modifier, value);
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

// MT5-ONLY: the MQL4 int property-id form (see the note above the
// ObjectGetInteger pair). Delegates to the enum forms, so the guarded
// TIME1/TIME2 translation is the one that runs for a `const int prop`
// caller too.
bool ObjectSetIntegerCompat(const long chart_id, const string name, const int prop, const long value)
{
    return ObjectSetIntegerCompat(chart_id, name, (ENUM_OBJECT_PROPERTY_INTEGER)prop, value);
}

bool ObjectSetIntegerCompat(const long chart_id, const string name, const int prop, const int modifier, const long value)
{
    return ObjectSetIntegerCompat(chart_id, name, (ENUM_OBJECT_PROPERTY_INTEGER)prop, modifier, value);
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

//--- The TWO-argument MQL4 form. MQL4's own signature is
//---     int ObjectsTotal(int chart_id=0, int window=-1, int type=-1)
//--- so `ObjectsTotal(0, -1)` means "chart 0, every window, every type" — the
//--- third argument is the TYPE in both languages, but MQL4 lets it default
//--- while MQL5's shim above does not. Shared (MT4-origin) source carries the
//--- short form in the strip's snap readers, so it has to resolve here rather
//--- than force an edit of every ported module.
int ObjectsTotalCompat(const long chart_id, const int sub_window)
{
    return ObjectsTotalReal(chart_id, sub_window, -1);
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

//--- The THREE-argument MQL4 form: `ObjectName(0, i, -1)` — chart 0, index i,
//--- every window, every type (MQL4's 4th parameter, type, defaults to -1).
string ObjectNameCompat(const long chart_id, const int pos, const int sub_window)
{
    return ObjectNameReal(chart_id, pos, sub_window, -1);
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
