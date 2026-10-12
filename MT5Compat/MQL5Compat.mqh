#ifndef MQL5_COMPAT_MQH
#define MQL5_COMPAT_MQH

//+------------------------------------------------------------------+
//| COMPAT LEDGER - WHERE THE MT5 EMULATION ACTUALLY SPENDS ITS TIME   |
//|                                                                  |
//| Every name below is an MQL4 API this file emulates. On MT4 each of|
//| them is a direct variable read or a single terminal call. On MT5|
//| each one is a REAL call into the kernel, and the indicator reads |
//| them everywhere - 156 Period(), 59 iBarShift, 22 iATR, 28 Bid/Ask|
//| across the shared modules. That gap is invisible in the source   |
//| and invisible in a compile; it only shows up as "MT5 lags".       |
//|                                                                  |
//| So: count the calls and time them, and print the ledger. It is   |
//| MT5-ONLY by construction (this file has no MT4 twin) and costs   |
//| two GetTickCount per measured call, so it is a MEASUREMENT build |
//| - set COMPAT_LEDGER to 0 for a release.                           |
//+------------------------------------------------------------------+
#define COMPAT_LEDGER 1

struct CompatLedger {
   long refreshCalls, refreshMs;     // CompatRefreshChartData, whole
   long seriesFull, seriesShift;     // full CopyRates vs in-memory shift
   long seriesBars;                  // bars touched by the shift
   long atrCalls, atrMs, atrFallback;// iATR -> handle / rates fallback
   long atrMemoHit, atrMemoMiss;     // the same bar priced again, or not
   long barShiftCalls, barShiftMs;   // iBarShift
   long periodCalls;                 // Period()
   long marketInfoCalls;             // MarketInfo()
   long bidAskCalls;                 // Bid / Ask
};
static CompatLedger g_cl;

string CL(const string tag, const long n, const long ms)
{
   return IntegerToString(n) + "/" + IntegerToString(ms) + "ms";
}

void CompatLedgerReport(const string tag)
{
   Print("[MT5-COMPAT] ", tag,
         " | refresh=", CL("r", g_cl.refreshCalls, g_cl.refreshMs),
         " (full=", IntegerToString(g_cl.seriesFull),
         " shift=", IntegerToString(g_cl.seriesShift),
         " bars=", IntegerToString(g_cl.seriesBars), ")",
         " | iATR=", CL("a", g_cl.atrCalls, g_cl.atrMs),
         " memo hit/miss=", IntegerToString(g_cl.atrMemoHit), "/", IntegerToString(g_cl.atrMemoMiss),
         " fallback=", IntegerToString(g_cl.atrFallback),
         " | iBarShift=", CL("b", g_cl.barShiftCalls, g_cl.barShiftMs),
         " | Period()=", IntegerToString(g_cl.periodCalls),
         " MarketInfo=", IntegerToString(g_cl.marketInfoCalls),
         " Bid/Ask=", IntegerToString(g_cl.bidAskCalls));
   g_cl.refreshCalls = 0; g_cl.refreshMs = 0;
   g_cl.seriesFull = 0; g_cl.seriesShift = 0; g_cl.seriesBars = 0;
   g_cl.atrCalls = 0; g_cl.atrMs = 0; g_cl.atrFallback = 0;
   g_cl.atrMemoHit = 0; g_cl.atrMemoMiss = 0;
   g_cl.barShiftCalls = 0; g_cl.barShiftMs = 0;
   g_cl.periodCalls = 0; g_cl.marketInfoCalls = 0; g_cl.bidAskCalls = 0;
}

// Bid / Ask were plain macro expansions of SymbolInfoDouble. They are now
// counting functions so the ledger can see them; the VALUE is identical.
double CompatBid() { g_cl.bidAskCalls++; return SymbolInfoDouble(_Symbol, SYMBOL_BID); }
double CompatAsk() { g_cl.bidAskCalls++; return SymbolInfoDouble(_Symbol, SYMBOL_ASK); }

#define Bid    CompatBid()
#define Ask    CompatAsk()
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
#ifdef COMPAT_LEDGER
   uint _t0 = GetTickCount();
   int _r = iBarShiftReal(symbol, tf, time, exact);
   g_cl.barShiftCalls++; g_cl.barShiftMs += (GetTickCount() - _t0);
   return _r;
#else
   return iBarShiftReal(symbol, tf, time, exact);
#endif
}

int iBarShiftCompat(const string symbol, const int tf, const datetime time, const bool exact = false)
{
#ifdef COMPAT_LEDGER
   uint _t0 = GetTickCount();
   int _r = iBarShiftReal(symbol, CompatTF(tf), time, exact);
   g_cl.barShiftCalls++; g_cl.barShiftMs += (GetTickCount() - _t0);
   return _r;
#else
   return iBarShiftReal(symbol, CompatTF(tf), time, exact);
#endif
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
    g_cl.marketInfoCalls++;
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

double iATRMQL4Impl(string symbol, int timeframe, int atrPeriod, int shift)
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
    g_cl.atrFallback++;
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
#ifdef COMPAT_LEDGER
    // The teardown is the one moment the whole session's emulation cost can be
    // read in one number, and ReleaseATRHandleCache is already the declared
    // MT5-only call on this path - so the ledger prints here and nowhere else.
    CompatLedgerReport("session");
#endif
}

//+------------------------------------------------------------------+
//| THE VALUE MEMO - why MT5 lags and MT4 does not, in one number.    |
//|                                                                  |
//| MT4's iATR returns a value the terminal has already computed. On |
//| MT5 an iATR is a HANDLE LOOKUP + BarsCalculated + CopyBuffer, and|
//| the shared source calls it from inside a 400-bar scan, twice per  |
//| structure timeframe, per new bar - and then repeats that whole   |
//| scan six times per pattern draw (TH3SixPivotsHasPivotAt bypasses|
//| the scan's own memo by design).                                   |
//|                                                                  |
//| So the SAME bar is priced four times through the kernel, and     |
//| MT4 prices it once. That gap is invisible in the source and is   |
//| exactly the shape of "MT4 is smooth, MT5 lags".                  |
//|                                                                  |
//| The memo is keyed on (symbol, tf, period, shift, bar), so a hit  |
//| returns bit-identical data to a miss - it is a cache, not an      |
//| approximation - and it expires the moment a new bar arrives.     |
//+------------------------------------------------------------------+
#define ATR_MEMO_SLOTS 1024
struct ATRMemoEntry {
   string symbol;
   ENUM_TIMEFRAMES tf;
   int period, shift, stamp;
   double value;
   bool used;
};
static ATRMemoEntry g_atrMemo[ATR_MEMO_SLOTS];
static bool g_atrMemoReady = false;

int ATRMemoSlot(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift, const int stamp)
{
   uint h = 2166136261u;
   const string parts = symbol + "|" + IntegerToString((int)tf) + "|" +
                        IntegerToString(period) + "|" + IntegerToString(shift);
   for(int i = 0; i < (int)StringLen(parts); i++)
      h = (h ^ (uchar)StringGetCharacter(parts, i)) * 16777619u;
   int slot = (int)(h % (uint)ATR_MEMO_SLOTS);
   if(g_atrMemo[slot].used && g_atrMemo[slot].symbol == symbol &&
      g_atrMemo[slot].tf == tf && g_atrMemo[slot].period == period &&
      g_atrMemo[slot].shift == shift && g_atrMemo[slot].stamp == stamp)
      return ~slot;                       // hit: negative marker carries the slot
   return slot;
}

// The measured front door. MT4's iATR is one terminal call that returns the
// value; on MT5 it is a handle lookup + BarsCalculated + CopyBuffer, and it is
// called from inside a 400-bar scan. The ledger is what makes that gap a number
// instead of a feeling.
double iATRMQL4(string symbol, int timeframe, int atrPeriod, int shift)
{
   if(symbol == NULL || symbol == "") symbol = _Symbol;
   if(timeframe == PERIOD_CURRENT || timeframe == 0) timeframe = CompatPeriodMinutes();

#ifdef COMPAT_LEDGER
   uint _t0 = GetTickCount();
   g_cl.atrCalls++;
#endif
   // The memo's lifetime is ONE BAR. The bar count is the stamp: it is already
   // the function's own "is there history" quantity, and it is what every other
   // cache in this file keys on.
   const int stamp = iBars(symbol, CompatTF(timeframe));
   const int _slot = ATRMemoSlot(symbol, CompatTF(timeframe), atrPeriod, shift, stamp);
   if(_slot < 0)
   {
#ifdef COMPAT_LEDGER
      g_cl.atrMemoHit++;
      g_cl.atrMs += (GetTickCount() - _t0);
#endif
      return g_atrMemo[~_slot].value;
   }
#ifdef COMPAT_LEDGER
   g_cl.atrMemoMiss++;
#endif
   const double _v = iATRMQL4Impl(symbol, timeframe, atrPeriod, shift);
   if(!g_atrMemoReady)
   {
      for(int i = 0; i < ATR_MEMO_SLOTS; i++) { g_atrMemo[i].used = false; g_atrMemo[i].value = 0.0; }
      g_atrMemoReady = true;
   }
   g_atrMemo[_slot].used = true;
   g_atrMemo[_slot].symbol = symbol;
   g_atrMemo[_slot].tf = CompatTF(timeframe);
   g_atrMemo[_slot].period = atrPeriod;
   g_atrMemo[_slot].shift = shift;
   g_atrMemo[_slot].stamp = stamp;
   g_atrMemo[_slot].value = _v;
#ifdef COMPAT_LEDGER
   g_cl.atrMs += (GetTickCount() - _t0);
#endif
   return _v;
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
// now it is ONE ~7 MB MqlRates read that the OS pages from one contiguous
// region. The five separate array unpackings below cost ~5 ns each (scalar
// stores into pre-allocated arrays) — the syscall saving is the whole win.
// The window is the WHOLE history, deliberately: see the P-MT5-TF-SPEED note
// below, where `Bars` is read as a value and not merely as an index bound.
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

// P-MT5-TF-SPEED (2026-10-03), REVERTED (2026-10-12) - THE WINDOW MUST BE THE
// WHOLE HISTORY, because `Bars` is a VALUE the shared modules reason with, not
// just an index bound.
//
// This layer used to cap the copy at COMPAT_SERIES_WINDOW (12 000) bars so a TF
// switch would not copy 100k MqlRates. The cap was bounds-safe but it quietly
// changed what `Bars` MEANS: MT4's Bars is the chart's loaded bar count, and
// three shared modules read it as "how much history is there", not as a guard.
//
//   BaseKnotTool.mqh:2860-2873   total = Bars; if(s >= total) return 0;
//       s comes from iBarShift(), which is NOT capped, so a base box older than
//       the window reported "no base" on MT5 and a real base on MT4.
//   ZoneFactory.mqh:337-338      startTime = Time[safeBars - 1]
//   ExtendedDrawingFunctions.mqh:381  startTime = Time[safeBars - 1]
//       the oldest bar. With the cap, a zone created without an explicit start
//       began at bar 11 999 instead of at the true left edge of history.
//
// So the full history is copied, exactly as many bars as the terminal has. The
// cost is O(history) per NEW BAR (the sync is gated on a bar-count change and
// throttled by COMPAT_FULL_SYNC_MIN_MS), not per tick, and the staging buffer is
// kept rather than freed so the copy is not preceded by a realloc every bar.

// R-TF-UNIT / P-MT5-PERF: overload that accepts the bar count already known
// from OnCalculate's `rates_total` parameter, skipping the iBars() kernel
// call on the per-tick path.  OnTimer / OnInit pass -1 (unknown) and the
// function falls back to iBars() as before.
//
// The live forming-bar values (close/high/low) are also passed from the
// OnCalculate parameter arrays when known: they are already in MQL5 memory
// (no kernel crossing), saving three iHigh/iLow/iClose kernel calls per tick
// in steady state.  Unknown callers pass EMPTY_VALUE for all three and the
// function uses the scalar series reads as before.
void CompatRefreshChartData(const int knownBars   = -1,
                            const double livClose = EMPTY_VALUE,
                            const double livHigh  = EMPTY_VALUE,
                            const double livLow   = EMPTY_VALUE)
{
    g_cl.refreshCalls++;
    uint _rt0 = GetTickCount();
    // P-MT5-PERF: use the bar count supplied by OnCalculate (free — already
    // a local in the caller's frame) rather than paying a kernel call per tick.
    int bars = (knownBars > 0) ? knownBars : iBars(_Symbol, PERIOD_CURRENT);
    if(bars <= 0) { g_cl.refreshMs += (GetTickCount() - _rt0); return; }

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

            // P-MT5-PERF: A NEW BAR IS THE COMMON CASE AND IT MUST NOT RE-READ
            // THE HISTORY. The terminal appended the bar at the RIGHT, so the
            // emulated series only has to SHIFT: whatever sat at index i is now
            // at i+1, and index 0 is the new bar - which the live-value block at
            // the foot of this function already writes from values the caller
            // passed in. That is O(bars) scalar copies and ZERO kernel
            // crossings, where the full path below pays a CopyRates of the
            // ENTIRE history (a 7 MB struct copy on a 100k-bar chart) plus a
            // 5 x bars field-by-field unpack, on every single new bar.
            //
            // Correctness: the oldest bar does not move when a bar is appended,
            // and it survives the shift at the new last index - so Time[Bars-1]
            // still answers the same bar it did before, which is the whole
            // reason the window is the full history.
            //
            // The preconditions are strict on purpose. A jump of anything other
            // than exactly +1 is a timeframe switch or a history download, not
            // a new bar, and falls through to the full copy; so does a history
            // shorter than iBars reported (g_seriesBars then lags the stamp),
            // and a first sync.
            if(g_seriesBars > 0 && g_seriesBars == g_seriesSyncedAt &&
               bars == g_seriesSyncedAt + 1)
            {
                const int n = g_seriesBars;
                ArrayResize(g_seriesTime,  n + 1);
                ArrayResize(g_seriesOpen,  n + 1);
                ArrayResize(g_seriesHigh,  n + 1);
                ArrayResize(g_seriesLow,   n + 1);
                ArrayResize(g_seriesClose, n + 1);
                for(int i = n; i >= 1; i--)
                {
                    g_seriesTime[i]  = g_seriesTime[i-1];
                    g_seriesOpen[i]  = g_seriesOpen[i-1];
                    g_seriesHigh[i]  = g_seriesHigh[i-1];
                    g_seriesLow[i]   = g_seriesLow[i-1];
                    g_seriesClose[i] = g_seriesClose[i-1];
                }
                g_seriesBars     = n + 1;
                g_seriesSyncedAt = bars;
                s_lastFullSyncMs  = nowMs;
                g_cl.seriesShift++;
                g_cl.seriesBars += n;
                // NO return: index 0 is the new bar and is written below.
            }
            else
            {
            // R-TF-UNIT: the WHOLE history, because `Bars` is read as a value by
            // BaseKnotTool (a base older than the window read as "no base") and by
            // ZoneFactory/ExtendedDrawingFunctions (Time[Bars-1] IS the oldest
            // bar). See the P-MT5-TF-SPEED note above the series block.
            const int copyCount = bars;
            ArraySetAsSeries(g_seriesRates, true);
            const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, copyCount, g_seriesRates);
            if(copied > 0)
            {
                s_lastFullSyncMs = nowMs;   // throttle ONLY after success
                g_cl.seriesFull++;
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
                // THE INVARIANT: Bars never exceeds what the arrays actually hold.
                // CopyRates normally returns exactly `copyCount`, so Bars equals
                // the terminal's true bar count and matches MT4; if history is
                // shorter than iBars reported, this keeps the bound safe instead
                // of handing out an index Time[99999] cannot serve.
                // Callers that need the true chart history depth regardless call
                // iBars(_Symbol, PERIOD_CURRENT) directly — that bypasses this
                // variable and hits the MT5 kernel.
                g_seriesBars     = copied;
                g_seriesSyncedAt = bars;
                // The staging buffer is deliberately NOT freed: ArrayResize only
                // grows, so keeping it means the next full sync reuses the same
                // allocation instead of taking (and releasing) the whole history
                // block on every new bar.
                g_cl.refreshMs += (GetTickCount() - _rt0);
                return;
            }
            }   // end else: full copy vs incremental shift
            // Copy failed (history still loading) — do NOT stamp s_lastFullSyncMs.
            // The next tick will retry immediately (due = true again) until the
            // history arrives. Once it does, the stamp fires and throttling begins.
        }
    }

    // Same bar count (or full sync not yet due / just failed): refresh only
    // the forming bar's moving values.
    // P-MT5-PERF: when called from OnCalculate the live values arrive as
    // parameters (already in MQL5 memory — zero extra kernel crossings).
    // Unknown callers (OnTimer, OnInit) still fall back to the scalar reads.
    if(g_seriesBars > 0)
    {
        if(livClose != EMPTY_VALUE && livHigh != EMPTY_VALUE && livLow != EMPTY_VALUE)
        {
            g_seriesHigh[0]  = livHigh;
            g_seriesLow[0]   = livLow;
            g_seriesClose[0] = livClose;
        }
        else
        {
            g_seriesHigh[0]  = iHigh(_Symbol, PERIOD_CURRENT, 0);
            g_seriesLow[0]   = iLow(_Symbol, PERIOD_CURRENT, 0);
            g_seriesClose[0] = iClose(_Symbol, PERIOD_CURRENT, 0);
        }
    }
    g_cl.refreshMs += (GetTickCount() - _rt0);
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
// The read half of the TIME1/TIME2 mapping the setter already performs below.
// Defined before the "#define ObjectGetInteger" rename so its body still reaches
// the built-in. On MT4 `ObjectGetInteger(0, nm, OBJPROP_TIME1)` is a legal read
// of the first anchor; on MQL5 the id 2010 is not a property at all, so without
// this the call silently returns 0 and every reader believes an object has no
// anchors.
long ObjectGetIntegerRealT(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier)
{
    if(prop == OBJPROP_TIME1) return ObjectGetInteger(chart_id, name, OBJPROP_TIME, 0);
    if(prop == OBJPROP_TIME2) return ObjectGetInteger(chart_id, name, OBJPROP_TIME, 1);
    return ObjectGetInteger(chart_id, name, prop, modifier);
}

#define ObjectGetInteger ObjectGetIntegerCompat

long ObjectGetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier = 0)
{
    return ObjectGetIntegerRealT(chart_id, name, prop, modifier);
}

long ObjectGetIntegerCompat(const long chart_id, const string name, const int prop, const int modifier = 0)
{
    return ObjectGetIntegerRealT(chart_id, name, (ENUM_OBJECT_PROPERTY_INTEGER)prop, modifier);
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
