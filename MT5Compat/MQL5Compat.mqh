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
//|                                                                  |
//| RELEASE (2026-10-13): OFF. MQL5's preprocessor has no `#if`, so  |
//| "0" is spelled as a COMMENTED define - every touch point below    |
//| asks `#ifdef COMPAT_LEDGER`, and an un-commented line turns the   |
//| whole ledger back on. The counters AND their GetTickCount pairs   |
//| compile away, which is the minimum-load build the user asked for. |
//+------------------------------------------------------------------+
#define COMPAT_LEDGER 1

struct CompatLedger {
   long refreshCalls, refreshMs;     // CompatRefreshChartData, whole
   long seriesFull, seriesShift;     // full CopyRates vs in-memory shift
   long seriesBars;                  // bars touched by the shift
   long atrCalls, atrMs, atrFallback;// iATR -> rates sync engine (P-ATR-SYNC)
   long atrMemoHit, atrMemoMiss;     // the same bar priced again, or not
   long barShiftCalls, barShiftMs;   // iBarShift
   long periodCalls;                 // Period()
   long marketInfoCalls;             // MarketInfo()
   long bidAskCalls;                 // Bid / Ask
   // P-PERF-156: the OBJECT side - what the memo answered, what still crossed
   // into the terminal, and what the crossings cost. `omSyncUs` is the honest
   // number: microseconds spent inside synchronous (queue-draining) calls.
   long omFindHit, omFindLive;       // ObjectFind from memory / from the chart
   long omGetHit, omGetLive;         // property reads, same split
   long omSetSkip, omSetWrite;       // enqueues the memo removed / it made
   long omRebirth, omTouch, omFlush; // identity changes, user touches, sweeps
   long omSyncUs;                    // us paid to the terminal's sync calls
};
static CompatLedger g_cl;

string CL(const string tag, const long n, const long ms)
{
   return IntegerToString(n) + "/" + IntegerToString(ms) + "ms";
}

void CompatLedgerReport(const string tag)
{
   // P-PERF-96 (BUG-13, 2026-10-13) — A RELEASE BUILD PRINTS NOTHING.
   // With COMPAT_LEDGER off every counter above is a constant zero, so the line
   // below would report "refresh=0/0ms iATR=0/0ms ..." on every deinit: noise
   // that reads as a measurement and is not one. The call site is unconditional
   // so a measurement build needs no edit; this guard is what makes that safe.
#ifndef COMPAT_LEDGER
   return;
#else
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
         " Bid/Ask=", IntegerToString(g_cl.bidAskCalls),
         " | obj find memo/live=", IntegerToString(g_cl.omFindHit), "/",
         IntegerToString(g_cl.omFindLive),
         " get memo/live=", IntegerToString(g_cl.omGetHit), "/",
         IntegerToString(g_cl.omGetLive),
         " set skip/write=", IntegerToString(g_cl.omSetSkip), "/",
         IntegerToString(g_cl.omSetWrite),
         " sync=", IntegerToString(g_cl.omSyncUs), "us",
         " birth=", IntegerToString(g_cl.omRebirth),
         " touch=", IntegerToString(g_cl.omTouch),
         " flush=", IntegerToString(g_cl.omFlush));
   g_cl.refreshCalls = 0; g_cl.refreshMs = 0;
   g_cl.seriesFull = 0; g_cl.seriesShift = 0; g_cl.seriesBars = 0;
   g_cl.atrCalls = 0; g_cl.atrMs = 0; g_cl.atrFallback = 0;
   g_cl.atrMemoHit = 0; g_cl.atrMemoMiss = 0;
   g_cl.barShiftCalls = 0; g_cl.barShiftMs = 0;
   g_cl.periodCalls = 0; g_cl.marketInfoCalls = 0; g_cl.bidAskCalls = 0;
   g_cl.omFindHit = 0; g_cl.omFindLive = 0; g_cl.omGetHit = 0; g_cl.omGetLive = 0;
   g_cl.omSetSkip = 0; g_cl.omSetWrite = 0;
   g_cl.omRebirth = 0; g_cl.omTouch = 0; g_cl.omFlush = 0; g_cl.omSyncUs = 0;
#endif
}

//--- P-PERF-59 (2026-10-23) — THE LEDGERS GET A CLOCK THAT CAN SEE.
//
// Every `[W][PERF]` number in this product is a GetTickCount() delta, and
// GetTickCount() steps in the Windows tick — 15.625 ms here. That is why the
// day's log carries the same eight values over and over (47, 63, 78, 94, 109,
// 125, 141, 156 — n x 15.6) and why the owner of a mouse-move stall could not
// be named: every phase under one tick reads 0 ms, so a 30 ms move can report
// "ring=0 panel=0 hold=0". EventHandlers:7191 says exactly this and points at
// the next step — "anything finer needs GetMicrosecondCount(), which is
// MT5-only". This file is the only MT5-only source in the tree, so the clock
// lives here and the shared modules keep their GetTickCount arithmetic.
//
// One call, no allocation: the value is a plain read of the platform counter.
uint CompatUsNow() { return (uint)GetMicrosecondCount(); }

// Bid / Ask were plain macro expansions of SymbolInfoDouble. They are now
// counting functions so the ledger can see them; the VALUE is identical.
// With COMPAT_LEDGER 0 the counter disappears - the call is the plain read.
double CompatBid()
{
#ifdef COMPAT_LEDGER
   g_cl.bidAskCalls++;
#endif
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}
double CompatAsk()
{
#ifdef COMPAT_LEDGER
   g_cl.bidAskCalls++;
#endif
   return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
}

// MT5-ONLY: MQL4's IsConnected() has no MQL5 twin. The terminal's own flag is
// the same answer — TERMINAL_CONNECTED goes false when the trade server drops,
// which is exactly the state P-SESS-25 refuses to learn a broker hour from.
bool CompatIsConnected() { return (TerminalInfoInteger(TERMINAL_CONNECTED) != 0); }

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
#ifdef COMPAT_LEDGER
    g_cl.marketInfoCalls++;
#endif
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
    // P-PERF-93 (BUG-16, 2026-10-13) — THE MONTHLY BAR IS NOMINAL, NOT CALENDAR.
    //
    // PeriodSeconds(PERIOD_MN1) counts down to the start of NEXT month, so a
    // 31-day month answers 44640 where the project's minute ladder says 43200.
    // This is the same unit bug that stopped Weekly/Monthly levels drawing
    // (R-TF-UNIT, commit 4ad14af) — it was pinned in CompatPeriodMinutes()
    // (Biotak/BuildConfig.mqh) but NOT here, so the two readers of "the current
    // period in minutes" disagreed on exactly one timeframe.
    //
    // Today this function has NO caller in the shared source, so the wrong
    // answer is dormant. Pinned anyway: the next caller must not have to
    // rediscover why a monthly chart reports 44640.
    if(tf == PERIOD_W1)  return 10080;
    if(tf == PERIOD_MN1) return 43200;
    int seconds = PeriodSeconds(tf);
    if(seconds > 0) return seconds / 60;

    int rawTf = (int)tf;
    if(rawTf > 0 && (rawTf <= 10080 || rawTf == 43200)) return rawTf;

    return 0;
}

// Nominal seconds for the current chart period. MT4's PeriodSeconds() was
// exactly Period()*60, including W1/MN1; MT5's is calendar truth and is wrong
// on the monthly bar. The zero-argument call sites in the shared modules go
// through here so the minute ladder keeps one meaning.
int CompatPeriodSeconds() { return CompatPeriodMinutes() * 60; }

// Nominal seconds for a timeframe value already in minutes. Used by the
// period-seconds caches, where the caller has GetCachedPeriod() (which may be
// the locked timeframe) rather than the chart's builtin Period().
int CompatSecondsForMinutes(const int minutes) { return (minutes > 0) ? minutes * 60 : 0; }

// MQL4-style iATR(symbol, timeframe, period, shift).
//
// P-ATR-SYNC (2026-10-17) — THE RATES ENGINE IS THE ENGINE.
//
// The report this closes: «ATR در متاتریدر 4 خیلی سریع است، در متاتریدر 5 چرا
// کند؟» — and the "why" behind it: MQL5's iATR is a HANDLE, and a handle's
// value is served asynchronously (BarsCalculated -> CopyBuffer). The old
// bridge created up to 54 handles per pass, RELEASED every one of them in the
// teardown (ReleaseATRHandleCache OnDeinit), and recreated the whole herd at
// every reattach — so every TF switch re-queued async ATR calculations for
// its heaviest TFs (MN1/W1/D1 are synthesized from M1 on demand and take
// seconds to become BarsCalculated>0). Until then every answer came from
// iATRRatesFallback, was stamped provisional by P-PERF-94, the adaptive
// scaling seed refused to latch, and the seedWait gate held the first paint —
// the "MT5 answers, MT4 is instant" gap in one chain.
// Worse: the moment a handle DID warm up, the answer flipped from the rates
// value to the terminal's — a mid-bar step the chart could see.
//
// The new model is MT4's own model: ONE synchronous engine. Ask -> compute
// from a CopyRates window NOW -> answer:
//   * window = ATRFallbackWindow() (3000+ bars or every bar the tf has) and
//     the Wilder recursion in CalculateATRFallbackFromRates() — the exact
//     function this bridge used as its fallback, already proven
//     MT4-equality-grade (<1e-5 residual vs a whole-history recursion for
//     every period this project uses, including MN1's 264);
//   * the one-bar value memo below stays the front door (memo hits are
//     bit-identical and cost nothing);
//   * NO handles, NO BarsCalculated, NO CopyBuffer, NO IndicatorRelease.
//
// "Provisional" now means exactly one thing: the CopyRates answer came back
// with FEWER bars than both the wanted window AND the tf's bar count — the
// terminal is still synthesizing or downloading that timeframe. A complete
// read (all wanted bars, or all bars the tf has — MT4's own short-history
// case) is FINAL for this bar, exactly like MT4, and seeds immediately.
//
// Per-call cost: a CopyRates of the shared window (cached per tf+shift+bar,
// so a six-period batch copies ONCE) plus one Wilder pass per period — tens
// of microseconds, no wait states, and zero terminal-side indicator work to
// undo on the way out.
static string g_atrSelectedSymbol = "";

// Forward declaration: implemented below iATRMQL4 (MQL5 needs prototypes
// before use).
double iATRRatesFallback(string symbol, ENUM_TIMEFRAMES tf, int atrPeriod, int shift);

// Fallback history cache. Under P-ATR-SYNC this block is the ENGINE'S window:
// one weighted ATR needs six periods for the same timeframe, and re-reading
// the same CopyRates block for every period was the main batch cost
// (especially for W1/MN1). Keep one shared history block and the
// already-computed period values; the cache is invalidated whenever the
// source tf advances. Its window is the MT4-equal one from
// ATRFallbackWindow() - see the note above that function.
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
// P-PERF-94 (BUG-02, 2026-10-13) — IS THIS ATR THE TERMINAL'S OWN, OR OURS?
//
// The rates-based fallback is MT4-equal only when it can see the same history
// MT4 sees. While a timeframe is still being built, CopyRates returns fewer
// bars than both the wanted window and the tf's bar count, so the Wilder seed
// sits on a TRUNCATED window and the number is provisional — it WILL move
// once the terminal finishes synthesizing/downloading. THE ONE REMAINING
// MOVER: P-ATR-SYNC removed the handle path entirely (no BarsCalculated case
// left), and a COMPLETE read — all wanted bars, or all bars the tf has — is
// now as final as MT4's answer on the same data, so the seed latches on the
// first frame instead of waiting out an async indicator.
//
// The adaptive-scaling seed keys its "the first paint waits for the real ATR"
// gate on g_scalingInitialized. A provisional value used to satisfy that gate,
// so the first frame painted at one fractal shift, the real ATR landed a
// moment later, the shift moved, and the user watched the levels appear, get
// deleted and be rebuilt — «سطوح یکبار رسم میشه و بعد حذف میشه بعد فراکتال
// جامپ اعمال میشه».
//
// This flag is the honest signal that the value can still change. It is set by
// every iATRRatesFallback() call, cleared at the top of iATRMQL4Impl(), and
// read by the two consumers that must not treat a provisional value as final:
// the value memo below (never store it) and AdaptiveScaling (never seed from
// it).
static bool g_atrLastProvisional = false;

bool CompatATRLastProvisional() { return g_atrLastProvisional; }

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
    // P-ATR-SYNC: a miss starts "final, the engine answered". Only an
    // incomplete CopyRates read inside iATRRatesFallback() may flip it back
    // to provisional — never a handle state, there are no handles anymore.
    g_atrLastProvisional = false;
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
    // period exceeds available bars, the rates engine answers from whatever
    // history the terminal has — the short-history case MT4 itself computes
    // through with the same finality.
    if(bars <= shift) return 0.0;

    // P-ATR-SYNC: one engine, synchronous, the MT4 model. The window
    // (ATRFallbackWindow: 3000+ bars or every bar the tf has) is shared
    // across the callers' multi-period batches and persisted on
    // (symbol, tf, shift, latest bar), so a six-period batch copies ONCE and
    // each period costs one Wilder pass. There is no second (handle-backed)
    // implementation to flip to mid-bar anymore, so a finished value stays
    // finished until the next bar.
    return iATRRatesFallback(symbol, CompatTF(timeframe), atrPeriod, shift);
}

//+------------------------------------------------------------------+
//| Manual Wilder's ATR — THE engine (MT4-like instant values).      |
//|                                                                  |
//| P-ATR-SYNC: this used to be a stop-gap while a terminal ATR      |
//| handle warmed up asynchronously (BarsCalculated 0/-1 for         |
//| synthesized-from-M1 TFs: seconds of provisional values). It is   |
//| now the ONLY implementation, which removes that wait state       |
//| entirely: CopyRates returns the bars as they exist, and the      |
//| Wilder recursion below answers in the same call frame.           |
//|                                                                  |
//| Provisional now tracks exactly what can still move: the copy     |
//| came back with FEWER bars than both the wanted window and the    |
//| tf's bar count (the terminal is still building that history).    |
//| A complete read — all wanted bars, or all bars the tf has, the   |
//| short-history case — is FINAL and seeds immediately, exactly as  |
//| MT4's own iATR behaves on the same data.                         |
//+------------------------------------------------------------------+
double iATRRatesFallback(string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod, const int shift)
{
#ifdef COMPAT_LEDGER
    g_cl.atrFallback++;
#endif
    if(symbol == NULL || symbol == "") symbol = _Symbol;
    if(atrPeriod <= 0 || shift < 0) return 0.0;

    // Shift 0 includes the forming candle and therefore must remain live.
    // The weighted ATR path requests shift 1, which is stable until a new bar.
    if(shift != 1) {
        int sourceBars = iBars(symbol, tf);
        int needBars = ATRFallbackWindow(atrPeriod, shift, sourceBars);
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        int copied = CopyRates(symbol, tf, 0, needBars, rates);
        if(copied <= 0) { g_atrLastProvisional = true; return 0.0; }
        // P-ATR-SYNC: incomplete = the history grew between CopyRates and
        // iBars (build in flight). copied == needBars or == sourceBars is
        // everything there is for this bar — final.
        g_atrLastProvisional = (copied < needBars && copied < sourceBars);
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
            g_atrLastProvisional = true;
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
        // P-ATR-SYNC: the one provisional sentence — a copy shorter than the
        // window AND shorter than the tf's own bar count can still grow.
        g_atrLastProvisional = (copied < requiredForCache && copied < sourceBars);
    } else {
        // A warm cache replays the same sentence from the stored window. The
        // cache is invalid whenever sourceBars changes, so a cache hit with
        // a growing history cannot happen — the replay is exact.
        g_atrLastProvisional = (g_atrFallbackCopied < requiredForCache &&
                                g_atrFallbackCopied < sourceBars);
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
    // P-ATR-SYNC: no handles exist anymore, so the teardown releases nothing
    // and the terminal runs no indicator calculations to unwind on the way
    // out — the TF-switch handle herd (create ~54 maps, wait async, release)
    // cannot come back. The rates window is per-instance state anyway; this
    // reset keeps a mid-session caller honest.
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
// value; on MT5 the sync engine answers from its CopyRates window + Wilder
// pass (or bit-identically from this memo), and it is called from inside a
// 400-bar scan. The ledger is what makes that gap a number instead of a
// feeling.
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
   // P-PERF-94: a provisional value must NOT enter the memo. The memo's whole
   // contract is "bit-identical data to a miss, valid until the next bar" —
   // a rates-based fallback value breaks the second half of that: it changes
   // while the SAME bar is still forming (history loading, handle warming), so
   // storing it would hand the caller a stale provisional number for the rest
   // of the bar and defeat every downstream "wait for the real ATR" guard.
   // The slot was only probed, never marked used, so skipping the write leaves
   // it free for the next call.
   if(CompatATRLastProvisional()) return _v;
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
//
// MT5-ONLY CORRECTNESS FIX (2026-10-13) - livTime / livOpen. The new-bar shift
// branch below moves the whole array one slot and must then fill index 0 with
// the NEW bar's values. The foot block only ever refreshed High/Low/Close, so
// Time[0] and Open[0] kept the PREVIOUS bar's values on every bar formed after
// the first full sync - and the shift then propagates the stale Time one slot
// further each bar. That is a visible logic difference from MT4: ZoneFactory
// reads Time[0] for the zone end edge (ZoneFactory.mqh:322/355) and
// ExtendedDrawingFunctions reads it for currentTime (line 390), so every
// zone/level anchor near the right edge sat one bar off the MT4 position.
// OnCalculate passes time[rates_total-1] / open[rates_total-1] (free, same
// arrays as the live H/L/C); OnInit/OnTimer pass nothing and the shift branch
// pays two kernel reads for exactly the one call where it runs.
void CompatRefreshChartData(const int knownBars   = -1,
                            const double livClose = EMPTY_VALUE,
                            const double livHigh  = EMPTY_VALUE,
                            const double livLow   = EMPTY_VALUE,
                            const datetime livTime = 0,
                            const double livOpen  = EMPTY_VALUE)
{
#ifdef COMPAT_LEDGER
    g_cl.refreshCalls++;
    uint _rt0 = GetTickCount();
#endif
    // P-MT5-PERF: use the bar count supplied by OnCalculate (free — already
    // a local in the caller's frame) rather than paying a kernel call per tick.
    int bars = (knownBars > 0) ? knownBars : iBars(_Symbol, PERIOD_CURRENT);
#ifdef COMPAT_LEDGER
    if(bars <= 0) { g_cl.refreshMs += (GetTickCount() - _rt0); return; }
#else
    if(bars <= 0) return;
#endif

    // Full re-sync whenever the bar count changes (new bar / history download).
    // Otherwise only the forming bar (index 0) moves.
    if(bars != g_seriesSyncedAt)
    {
        static uint s_lastFullSyncMs = 0;
        const uint nowMs = GetTickCount();
        const bool due = (s_lastFullSyncMs == 0) ||
                         ((nowMs - s_lastFullSyncMs) >= (uint)COMPAT_FULL_SYNC_MIN_MS);
        // P-MT5-SERIES-01 (MT5-PAR-013/014, 2026-10-28) — A COUNT THAT WENT UP
        // BY ONE IS NOT YET A NEW BAR. `bars == g_seriesSyncedAt + 1` has TWO
        // causes on MT5: the terminal opened a bar at the newest end (the shift
        // below is right), and a history download appended ONE bar at the OLDEST
        // end (the shift is wrong: every slot moves one bar too new and the
        // current bar lands at index 0 AND 1). MT4 cannot make that distinction
        // because the terminal owns its arrays; `tools/research/series_sync_parity.py`
        // replays both causes and shows the shipped branch corrupting the whole
        // series on the second one, permanently — the state machine only re-syncs
        // on the NEXT count change. So the shift now asks the question the count
        // cannot answer: did the newest bar's TIME move?
        const bool grewByOne = (g_seriesBars > 0 && g_seriesBars == g_seriesSyncedAt &&
                                bars == g_seriesSyncedAt + 1);
        // The one kernel read pays for itself only in the branch that needs it:
        // OnCalculate hands the newest bar's time over for free (livTime), and
        // OnInit/OnTimer are the only callers that must ask the terminal.
        const datetime newTime = grewByOne ? ((livTime > 0) ? livTime
                                                            : iTime(_Symbol, PERIOD_CURRENT, 0))
                                           : (datetime)0;
        const bool newBar = (grewByOne && newTime > g_seriesTime[0]);
        // P-MT5-SERIES-01b — THE THROTTLE NOW GATES THE COPY ONLY. The shift is
        // O(bars) scalar moves and ZERO kernel crossings; the 500 ms floor exists
        // to stop a download turning every tick into a full-history CopyRates.
        // Gating the shift with it cost something else: when it held, the code
        // fell through and wrote the LIVE high/low/close into index 0 while that
        // slot still carried the PREVIOUS bar's Time and Open — one torn bar, and
        // the first frame of a new bar painted from two bars at once.
        //
        // WHICH EVENTS COULD HIT IT (checked, not assumed). The stamp only exists
        // after a successful full copy, so the window opens on the event that
        // caused that copy: an attach, a history append, a count jump. An
        // ORDINARY timeframe switch is NOT one of them — the terminal
        // deinitialises the indicator on REASON_CHARTCHANGE (P-PERF-95 in
        // EventHandlers.mqh:1204-1216 says exactly this of the other static in
        // that file), and a fresh instance re-initialises this static to 0, so
        // the first frame after a switch is always `due`. What survives is the
        // rarer pair the review left standing: the timeframe LOCK toggle, which
        // moves Period() without a reload, and any count-change copy that lands
        // within 500 ms before a bar opens.
        if(newBar || due)
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
            // at i+1, and index 0 is the new bar - which THIS branch writes from
            // the values the caller passed (Time/Open here, High/Low/Close from
            // the foot block below). That is O(bars) scalar copies and ZERO kernel
            // crossings on the OnCalculate path, where the full path below pays a
            // CopyRates of the ENTIRE history (a 7 MB struct copy on a 100k-bar
            // chart) plus a 5 x bars field-by-field unpack, on every single new bar.
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
            // and a first sync. P-MT5-SERIES-01 adds the fourth: a +1 whose
            // NEWEST bar did not move is a download that reached the oldest end,
            // and the shift would move every slot one bar too new — full copy.
            if(newBar)
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
                // P-MT5-SERIES-01b: no stamp here. The 500 ms floor throttles the
                // full-history COPY (the expensive call it exists to protect);
                // stamping on the shift made a download that landed just after a
                // new bar wait out a window it had not earned.
                // MT5-ONLY FIX (2026-10-13): the shifted-in new bar's Time and
                // Open. The foot block below only refreshes High/Low/Close, so
                // without these two lines index 0 (and, from the NEXT shift on,
                // index 1 too) kept the previous bar's time and open - a silent
                // off-by-one the whole history accumulated bar by bar.
                g_seriesTime[0] = newTime;
                g_seriesOpen[0] = (livOpen != EMPTY_VALUE) ? livOpen
                                                           : iOpen(_Symbol, PERIOD_CURRENT, 0);
#ifdef COMPAT_LEDGER
                g_cl.seriesShift++;
                g_cl.seriesBars += n;
#endif
                // NO return: index 0's High/Low/Close are written by the foot block.
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
#ifdef COMPAT_LEDGER
                g_cl.seriesFull++;
#endif
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
#ifdef COMPAT_LEDGER
                g_cl.refreshMs += (GetTickCount() - _rt0);
#endif
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
    //
    // P-MT5-SERIES-01b: `bars == g_seriesSyncedAt` — the arrays must be aligned
    // with the count the caller just reported. When a count change was NOT
    // applied (throttled, or a copy that failed), index 0 still belongs to the
    // PREVIOUS bar, and writing this tick's high/low/close into it made one slot
    // speak two bars: Time[0]/Open[0] from the old one, High/Low/Close from the
    // new one. ZoneFactory reads Time[0] for the zone end edge and the shared
    // code reads Close[0] for currentPrice, so the first frame of that bar was
    // built from a pair that never existed. Holding the last consistent snapshot
    // for the rest of the window is MT4-inconsistent by a few hundred ms and
    // self-heals; tearing index 0 was inconsistent forever as far as that frame
    // is concerned, and silent.
    if(g_seriesBars > 0 && bars == g_seriesSyncedAt)
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
#ifdef COMPAT_LEDGER
    g_cl.refreshMs += (GetTickCount() - _rt0);
#endif
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
//
// P-PERF-156 (2026-10-28) REPLACES THAT DECISION WITH THE DOCUMENTED ONE. The
// official reference says the two halves of this API are not the same kind of
// call at all: ObjectSet* / ObjectCreate / ObjectMove are ASYNCHRONOUS - they
// only enqueue a command on the chart - while every function that REQUESTS a
// property (ObjectGet*, ObjectFind, ObjectName, ObjectsTotal, ObjectsDeleteAll)
// "uses a synchronous call, which means that the function waits for the
// execution of all commands that have been enqueued for this chart prior to its
// call, that is why this function can be time consuming", and the docs add that
// this must be considered "when working with a large number of objects on a
// chart". So the 2026-10-03 removal cut the wrong side: it guaranteed a deeper
// queue for every guard read to drain. The product is written in the guard
// pattern - `if(ObjectGet… != v) ObjectSet…` - hundreds of times a frame, which
// is the lag the delete-sweeping of the previous round could not reach, and
// what the memo below now removes: a program-owned property answer comes from
// memory after its first touch, and a value the terminal already holds is never
// enqueued again. Read MT5ObjMemo.mqh for the allowlist and the invalidation
// argument. MT4 never includes this folder, so its traffic stays exactly MT4's.
#include "MT5ObjMemo.mqh"

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

// MQL4's OBJPROP_RAY (one bool, "ray both ways") has no MQL5 spelling -
// MQL5 splits it into OBJPROP_RAY_LEFT / OBJPROP_RAY_RIGHT. Every shared
// use writes the MQL4 name and BOTH halves in one breath (Sessions_Draw's
// SessEdge/SessLine set RAY, RAY_LEFT and RAY_RIGHT to false in a row), so
// the MQL4 name maps onto the RIGHT half and the same call site's own
// OBJPROP_RAY_LEFT line spends the left.
#ifndef OBJPROP_RAY
#define OBJPROP_RAY OBJPROP_RAY_RIGHT
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
    // P-PERF-156: the terminal already holds this value - do not enqueue a
    // second command for it. Allowlisted properties only (MT5ObjMemo.mqh).
    if(OmSkipDbl(chart_id, name, (int)prop, 0, value)) return true;
    const bool ok = ObjectSetDoubleReal(chart_id, name, prop, value);
    if(ok) OmNoteDbl(chart_id, name, (int)prop, 0, value);
    return ok;
}

bool ObjectSetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier, const double value)
{
    if(OmSkipDbl(chart_id, name, (int)prop, modifier, value)) return true;
    const bool ok = ObjectSetDoubleRealMod(chart_id, name, prop, modifier, value);
    if(ok) OmNoteDbl(chart_id, name, (int)prop, modifier, value);
    return ok;
}

double ObjectGetDoubleReal(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier)
{
    return ObjectGetDouble(chart_id, name, prop, modifier);
}

#define ObjectGetDouble ObjectGetDoubleCompat

double ObjectGetDoubleCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_DOUBLE prop, const int modifier = 0)
{
    // P-PERF-156: an allowlisted read is answered from memory - the whole
    // point, because a property request is the SYNCHRONOUS half of this API
    // and every one of them drains the chart queue the pass just filled.
    double memo;
    if(OmKnownDbl(chart_id, name, (int)prop, modifier, memo)) return memo;
    const uint _t = OmMark();
    double v;
    if(prop == OBJPROP_PRICE1) v = ObjectGetDoubleReal(chart_id, name, OBJPROP_PRICE, 0);
    else if(prop == OBJPROP_PRICE2) v = ObjectGetDoubleReal(chart_id, name, OBJPROP_PRICE, 1);
    else v = ObjectGetDoubleReal(chart_id, name, prop, modifier);
    OmSpend(_t, 0);
    OmLearnDbl(chart_id, name, (int)prop, modifier, v);
    return v;
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
    // P-PERF-156: the guard read this product lives on, answered from memory
    // once the terminal has been asked for it - see MT5ObjMemo.mqh for what is
    // allowed to be remembered (STATE, SELECTED, TIME*, PRICE* never are).
    long memo;
    if(OmKnownInt(chart_id, name, (int)prop, modifier, memo)) return memo;
    const uint _t = OmMark();
    const long v = ObjectGetIntegerRealT(chart_id, name, prop, modifier);
    OmSpend(_t, 0);
    OmLearnInt(chart_id, name, (int)prop, modifier, v);
    return v;
}

long ObjectGetIntegerCompat(const long chart_id, const string name, const int prop, const int modifier = 0)
{
    long memo;
    if(OmKnownInt(chart_id, name, prop, modifier, memo)) return memo;
    const uint _t = OmMark();
    const long v = ObjectGetIntegerRealT(chart_id, name, (ENUM_OBJECT_PROPERTY_INTEGER)prop, modifier);
    OmSpend(_t, 0);
    OmLearnInt(chart_id, name, prop, modifier, v);
    return v;
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
    // P-PERF-156: an unchanged value is not a command. Writes are the cheap
    // half of this API (asynchronous enqueues) but every one of them is work
    // the NEXT synchronous call has to execute - so skipping them makes both
    // halves faster. Allowlist only.
    if(OmSkipInt(chart_id, name, (int)prop, 0, value)) return true;
    const bool ok = ObjectSetIntegerReal(chart_id, name, prop, value);
    if(ok) OmNoteInt(chart_id, name, (int)prop, 0, value);
    return ok;
}

bool ObjectSetIntegerCompat(const long chart_id, const string name, const ENUM_OBJECT_PROPERTY_INTEGER prop, const int modifier, const long value)
{
    if(OmSkipInt(chart_id, name, (int)prop, modifier, value)) return true;
    const bool ok = ObjectSetIntegerRealMod(chart_id, name, prop, modifier, value);
    if(ok) OmNoteInt(chart_id, name, (int)prop, modifier, value);
    return ok;
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
    return ObjectFindCompat(0, name);
}

int ObjectFindCompat(const long chart_id, const string name)
{
    // P-PERF-156: the existence gate in front of nearly every path. MQL5 makes
    // it a synchronous call and prices it BY THE NUMBER OF OBJECTS ON THE
    // CHART; MT4 answers it from its own list. After one look the memo owns the
    // answer for this name, and loses it the moment the name's identity
    // changes - our create/delete, a sweep, or the terminal's own
    // OBJECT_CREATE/OBJECT_DELETE event for a name the user touched.
    int memoWin;
    if(OmKnownFind(chart_id, name, memoWin)) return memoWin;
    const uint _t = OmMark();
    const int r = ObjectFindReal(chart_id, name);
    OmSpend(_t, 1);
    OmLearnFind(chart_id, name, r);
    return r;
}

//+------------------------------------------------------------------+
//| MT5-ONLY PLATFORM FILTER - THE PROGRAMMATIC OBJECT EVENT STORM.   |
//|                                                                  |
//| On MT4 an indicator's own ObjectCreate/ObjectDelete/               |
//| ObjectsDeleteAll calls NEVER fire CHARTEVENT_OBJECT_CREATE/DELETE; |
//| those events mean "the USER drew/deleted something" and every      |
//| heal, style-apply and witness in the shared source is written      |
//| against that meaning. On MT5 the same operations queue one chart   |
//| event EACH (the subscription lines in EventHandlers.mqh:1487/1514 |
//| open the channel), so a ~900-object rebuild delivers ~1800 events  |
//| through the full dispatch chain, leaked prefixed deletes re-arm    |
//| whole-family rebuilds (EventHandlers.mqh:5687 P-DEL-PROBE: "a     |
//| burst of them is churn the user feels"), and a non-prefixed create |
//| (every Pnl*/HTF/strip object - HTF candles are OBJ_TRENDs!) runs   |
//| DrawStyleApplyOnCreate + CustomPriceForeignDrawSeen, i.e. the      |
//| indicator restyles ITS OWN drawings with the user's style memory.  |
//| The 250 ms bulk windows cannot fix that: the terminal may deliver  |
//| the queued events later than the window (that is exactly what the  |
//| probe documents), and single-object deletes own no window at all.  |
//|                                                                  |
//| The fix restores the MT4 MEANING of the two events: an event is    |
//| invisible iff this program performed the operation that queued it. |
//| Every wrapped call drops a one-shot token under the object's name; |
//| the entry's OnChartEvent asks CompatConsumeObjEvent before ANY     |
//| dispatch and consumes one matching token - event dropped, MT4      |
//| behaviour. A token that is never consumed expires (10 s), and the  |
//| first event whose name has no token dispatches normally, so a      |
//| USER delete/create of the very same object is always honoured.     |
//| Cost per operation: one FNV hash over the name + up to 8 slot      |
//| probes - cheaper than the kernel crossing the operation itself     |
//| just paid.                                                         |
//+------------------------------------------------------------------+
#define COMPAT_OBJT_TABLE 16384          // power of two
#define COMPAT_OBJT_PROBE 8
#define COMPAT_OBJT_TTL_MS  10000

struct CompatObjToken { string name; uint stamp; };
static CompatObjToken g_objTokCreate[];
static CompatObjToken g_objTokDelete[];
static bool g_objTokInit = false;

void CompatInitObjTokens()
{
   if(g_objTokInit) return;
   ArrayResize(g_objTokCreate, COMPAT_OBJT_TABLE);
   ArrayResize(g_objTokDelete, COMPAT_OBJT_TABLE);
   for(int i = 0; i < COMPAT_OBJT_TABLE; i++)
   {
      g_objTokCreate[i].name = ""; g_objTokCreate[i].stamp = 0;
      g_objTokDelete[i].name = ""; g_objTokDelete[i].stamp = 0;
   }
   g_objTokInit = true;
}

uint CompatObjHash(const string nm)
{
   uint h = 2166136261;
   const int len = StringLen(nm);
   for(int i = 0; i < len; i++)
   {
      h ^= (uint)StringGetCharacter(nm, i);
      h *= 16777619;
   }
   return h;
}

void CompatTokenWrite(CompatObjToken &tab[], const string nm, const uint now)
{
   const uint h = CompatObjHash(nm);
   for(int k = 0; k < COMPAT_OBJT_PROBE; k++)
   {
      const int idx = (int)((h + (uint)k) % COMPAT_OBJT_TABLE);
      if(tab[idx].name == nm || tab[idx].name == "" ||
         (now - tab[idx].stamp) >= COMPAT_OBJT_TTL_MS)
      {
         tab[idx].name = nm; tab[idx].stamp = now; return;
      }
   }
   const int home = (int)(h % COMPAT_OBJT_TABLE);   // table crowded: refresh home
   tab[home].name = nm; tab[home].stamp = now;
}

void CompatNoteObjOp(const bool isDelete, const string nm)
{
   if(nm == "") return;
   CompatInitObjTokens();
   const uint now = GetTickCount();
   if(isDelete) CompatTokenWrite(g_objTokDelete, nm, now);
   else         CompatTokenWrite(g_objTokCreate, nm, now);
}

bool CompatTokenRead(CompatObjToken &tab[], const string nm, const uint now)
{
   const uint h = CompatObjHash(nm);
   for(int k = 0; k < COMPAT_OBJT_PROBE; k++)
   {
      const int idx = (int)((h + (uint)k) % COMPAT_OBJT_TABLE);
      if(tab[idx].name == nm && (now - tab[idx].stamp) < COMPAT_OBJT_TTL_MS)
      {
         tab[idx].name = ""; tab[idx].stamp = 0;
         return true;
      }
   }
   return false;
}

// Called from the entry's OnChartEvent BEFORE any dispatch. True = this
// event was queued by our own create/delete call: MT4 would never have
// seen it, so the entry returns without dispatching. (P-PERF-112: the body
// lives after the prefix-record machinery below - it consults both tables.)

// ObjectsDeleteAll removes a WHOLE set whose names the caller does not
// enumerate. P-PERF-112 (2026-10-17) - THE WALK IS GONE; A SWEEP RECORDS
// ITS PREFIX INSTEAD.
//
// P-PERF-99 measured the walk and skipped it in deinit context only; every
// LIVE-operation sweep (PnlCloseAll on user actions, family wipes during
// rendering, the init purges, ghost sweeps - the whole product) still paid
// one ObjectName() per chart object, on every call: the "deletes and redraws
// for nothing" the user lives with. The walk existed because the built-in
// does not say WHICH names it removed - but no consumer ever needed names:
// CompatConsumeObjEvent only asks "did OUR sweep queue this delete?", and
// the prefix the sweep ran under answers that by itself. So a sweep drops a
// (prefix, deadline) record; a delete event matching ANY live record is
// swallowed. The walk and its per-name token writes are deleted.
//
// A sweep with no prefix (the no-prefix overload purges the whole scoped
// set) records the WILDCARD "", which matches every name - exactly the set
// that call deleted. Name-exact tokens above remain the first line for
// every single delete; the bounded record band below covers the bulks.
//
// Bounded exactly like the name table: 64 records, 10 s TTL, refreshed when
// the same prefix sweeps again. The recorded prefixes name PROGRAM-OWNED
// namespaces (level/UI/HTF families), so swallowing a user delete inside
// the TTL band would take a rename into one of those families first.
#define COMPAT_OBJT_PREFIX_SLOTS 64

struct CompatDelPrefixRec { string prefix; uint stamp; };
static CompatDelPrefixRec g_objTokDelPrefixes[];
static bool g_objTokPrefixInit = false;

void CompatInitObjPrefixes()
{
   if(g_objTokPrefixInit) return;
   ArrayResize(g_objTokDelPrefixes, COMPAT_OBJT_PREFIX_SLOTS);
   for(int i = 0; i < COMPAT_OBJT_PREFIX_SLOTS; i++)
   {
      g_objTokDelPrefixes[i].prefix = "";
      g_objTokDelPrefixes[i].stamp = 0;
   }
   g_objTokPrefixInit = true;
}

void CompatNoteDeleteAllPrefix(const string prefix)
{
   CompatInitObjPrefixes();
   const uint now = GetTickCount();
   int freeSlot = -1, oldest = 0;
   uint oldestAge = 0;
   for(int i = 0; i < COMPAT_OBJT_PREFIX_SLOTS; i++)
   {
      const uint stampAge = now - g_objTokDelPrefixes[i].stamp;   // stamp 0 -> giant age
      const bool empty = (g_objTokDelPrefixes[i].stamp == 0) ||
                         (stampAge > COMPAT_OBJT_TTL_MS);
      if(empty) { if(freeSlot < 0) freeSlot = i; continue; }
      if(g_objTokDelPrefixes[i].prefix == prefix)
      { g_objTokDelPrefixes[i].stamp = now; return; }            // refresh
      if(stampAge >= oldestAge) { oldestAge = stampAge; oldest = i; }
   }
   const int slot = (freeSlot >= 0) ? freeSlot : oldest;
   g_objTokDelPrefixes[slot].prefix = prefix;
   g_objTokDelPrefixes[slot].stamp = now;
}

bool CompatDeleteMatchesPrefix(const string nm, const uint now)
{
   if(!g_objTokPrefixInit) return false;
   for(int i = 0; i < COMPAT_OBJT_PREFIX_SLOTS; i++)
   {
      const uint stamp = g_objTokDelPrefixes[i].stamp;
      if(stamp == 0 || (now - stamp) > COMPAT_OBJT_TTL_MS) continue;
      const string p = g_objTokDelPrefixes[i].prefix;
      if(p == "") return true;                                   // wildcard purge
      const int pl = StringLen(p);
      if(StringLen(nm) >= pl && StringSubstr(nm, 0, pl) == p) return true;
   }
   return false;
}

// Called from the entry's OnChartEvent BEFORE any dispatch. True = this
// event was queued by our own create/delete call: MT4 would never have
// seen it, so the entry returns without dispatching.
bool CompatConsumeObjEvent(const int id, const string nm)
{
   if(nm == "") return false;
   const uint now = GetTickCount();
   bool ours = false;
   if(id == CHARTEVENT_OBJECT_CREATE)
      ours = (g_objTokInit && CompatTokenRead(g_objTokCreate, nm, now));
   else if(id == CHARTEVENT_OBJECT_DELETE)
      ours = (g_objTokInit && CompatTokenRead(g_objTokDelete, nm, now)) ||
             CompatDeleteMatchesPrefix(nm, now);
   // P-PERF-156: the memo's event seam rides the SAME line the entries already
   // call for every event, so no new subscription and no shared line moves. A
   // create/delete the wrapper tokenised is our own command executing; a click,
   // drag, in-place edit or dialog change is the user, and the memo has to stop
   // answering for that object.
   OmEventHook(id, 0, nm, ours);
   return ours;
}

// P-PERF-99 (2026-10-16): the deinit gate stays - tokens/records have no
// consumer in a dying instance, so the teardown path writes none. Live
// operations keep their records: there the events DO reach this instance
// and MT4 semantics demand they stay invisible.
bool g_compatDeinitActive = false;

void CompatDeinitBegin() { g_compatDeinitActive = true; }

void CompatTokenizeDeleteAll(const long chart_id, const string prefix,
                             const int sub_window, const int type)
{
   if(g_compatDeinitActive) return;   // P-PERF-99: no consumer, no record
   // P-PERF-112: no walk, no per-name tokens - one prefix record answers the
   // whole sweep. A sub-window/type-SCOPED sweep is recorded family-wide too;
   // every scoped call site in the product sweeps its own program-owned names
   // in window 0, so a user delete inside the TTL band cannot carry one of
   // these prefixes without a rename into the family.
   CompatNoteDeleteAllPrefix(prefix);
}

bool ObjectCreateReal6(const long chart_id, const string name, const ENUM_OBJECT type,
                       const int sub_window, const datetime time1, const double price1)
{
   return ObjectCreate(chart_id, name, type, sub_window, time1, price1);
}

bool ObjectCreateReal8(const long chart_id, const string name, const ENUM_OBJECT type,
                       const int sub_window, const datetime time1, const double price1,
                       const datetime time2, const double price2)
{
   return ObjectCreate(chart_id, name, type, sub_window, time1, price1, time2, price2);
}

bool ObjectCreateReal10(const long chart_id, const string name, const ENUM_OBJECT type,
                        const int sub_window, const datetime time1, const double price1,
                        const datetime time2, const double price2,
                        const datetime time3, const double price3)
{
   return ObjectCreate(chart_id, name, type, sub_window, time1, price1, time2, price2, time3, price3);
}

#define ObjectCreate ObjectCreateCompat

bool ObjectCreateCompat(const long chart_id, const string name, const ENUM_OBJECT type,
                        const int sub_window, const datetime time1, const double price1)
{
   const bool r = ObjectCreateReal6(chart_id, name, type, sub_window, time1, price1);
   if(r) { CompatNoteObjOp(false, name); OmNoteCreate(chart_id, name, sub_window); }
   return r;
}

bool ObjectCreateCompat(const long chart_id, const string name, const ENUM_OBJECT type,
                        const int sub_window, const datetime time1, const double price1,
                        const datetime time2, const double price2)
{
   const bool r = ObjectCreateReal8(chart_id, name, type, sub_window, time1, price1, time2, price2);
   if(r) { CompatNoteObjOp(false, name); OmNoteCreate(chart_id, name, sub_window); }
   return r;
}

bool ObjectCreateCompat(const long chart_id, const string name, const ENUM_OBJECT type,
                        const int sub_window, const datetime time1, const double price1,
                        const datetime time2, const double price2,
                        const datetime time3, const double price3)
{
   const bool r = ObjectCreateReal10(chart_id, name, type, sub_window, time1, price1, time2, price2, time3, price3);
   if(r) { CompatNoteObjOp(false, name); OmNoteCreate(chart_id, name, sub_window); }
   return r;
}

bool ObjectDeleteReal(const long chart_id, const string name)
{
   return ObjectDelete(chart_id, name);
}

#define ObjectDelete ObjectDeleteCompat

bool ObjectDeleteCompat(const long chart_id, const string name)
{
   const bool r = ObjectDeleteReal(chart_id, name);
   if(r) { CompatNoteObjOp(true, name); OmNoteDelete(chart_id, name); }
   return r;
}

int ObjectsDeleteAllRealSub(const long chart_id, const int sub_window, const int type)
{
   return ObjectsDeleteAll(chart_id, sub_window, type);
}

int ObjectsDeleteAllRealPrefix(const long chart_id, const string prefix,
                               const int sub_window, const int type)
{
   return ObjectsDeleteAll(chart_id, prefix, sub_window, type);
}

#define ObjectsDeleteAll ObjectsDeleteAllCompat

// P-PERF-156: a sweep removes names this file cannot enumerate, so the whole
// generation goes stale at once - O(1), and the frame that swept has nothing
// left to remember.
int ObjectsDeleteAllCompat(const long chart_id, const int sub_window = -1, const int type = -1)
{
   CompatTokenizeDeleteAll(chart_id, "", sub_window, type);
   OmFlushAll();
   return ObjectsDeleteAllRealSub(chart_id, sub_window, type);
}

int ObjectsDeleteAllCompat(const long chart_id, const string prefix,
                           const int sub_window = -1, const int type = -1)
{
   CompatTokenizeDeleteAll(chart_id, prefix, sub_window, type);
   OmFlushAll();
   return ObjectsDeleteAllRealPrefix(chart_id, prefix, sub_window, type);
}

//+------------------------------------------------------------------+
//| P-UI-223 - DECODE THE UI SKINS BEFORE THE FIRST LABEL EXISTS.     |
//|                                                                  |
//| A bitmap label whose resource has never been DECODED can present  |
//| as an EMPTY box for its first frame(s). The object, its box, its  |
//| path and its pixels are all correct - the ring census at           |
//| 10:57:50 proved it, and ResourceReadImage reads 52x52 - yet the   |
//| 9 inner 44px seats drew a bare glyph while the 3 outer 32px seats |
//| drew their disc, until a click rebuilt the ring. The 52px ring    |
//| skin is the biggest and the last to decode, so a label created    |
//| against a cold cache paints blank.                                |
//|                                                                  |
//| One decode per attach (a few KB) puts the family in the cache     |
//| before any label is created; after that the terminal serves the   |
//| cached image and every show/rebuild paints on its first frame.    |
//+------------------------------------------------------------------+
void CompatWarmUiSkins()
{
   string skins =
      "circ_off;circ_on;circ_off_30;circ_on_30;circ_off_32;circ_on_32;"
      "circ_off_35;circ_on_35;circ_off_39;circ_on_39;circ_off_43;"
      "circ_on_43;cell_off;cell_on;orb_bg";
   string parts[];
   int n = StringSplit(skins, ';', parts);
   uint px[];
   uint w = 0, h = 0;
   int warmed = 0;
   for(int i = 0; i < n; i++)
      if(ResourceReadImage("::Files\\Icons\\" + parts[i] + ".bmp", px, w, h))
         warmed++;
   Print("[P-UI-223] ui skins warmed=", warmed, "/", n);
}

//+------------------------------------------------------------------+
//| P-MT5-ONECLICK (2026-10-23) - ONE PHYSICAL RELEASE, ONE CLICK.    |
//|                                                                  |
//| MT4 sends ONE click-family event per button-up. MT5 sends that    |
//| release on TWO channels: the OBJECT click (which names the        |
//| object under the cursor) and the CHART click (which names no       |
//| object at all), and in the measured cases the OBJECT click could  |
//| even arrive twice.                                                 |
//|                                                                  |
//| The shared source is written against the MT4 meaning - ONE event  |
//| per gesture - so the second delivery reads as a SECOND GESTURE:   |
//| the strip toggles closed what it had just opened and its close     |
//| path writes OBJPROP_SELECTED=false («خودش خودکار انسلکت می‌شه»),       |
//| a card switch flips twice and looks dead («چرا تاگل کار نمی‌کند»),  |
//| a tool that plants a point on click plants two.                   |
//|                                                                  |
//| The rule here is deliberately narrow, because this filter sits in  |
//| front of EVERY handler:                                          |
//|   * the same OBJECT click, same name, within the window -> drop    |
//|     (one release cannot name one object twice);                    |
//|   * a CHART click within the window of an OBJECT click -> drop     |
//|     (the chart half of the same release).                          |
//|   * anything else passes, so two genuinely separate clicks - a     |
//|     user's real double-click 300+ ms apart, a click on another     |
//|     object, a click on empty chart - are never touched.            |
//|                                                                  |
//| Window: 300 ms. MEASURED twins on the live terminal were 62-171 ms |
//| apart; the user's own repeat clicks in the same log were 1.4-2.1 s.|
//+------------------------------------------------------------------+
#define COMPAT_CLICK_TWIN_MS 300

static uint   g_ccObjMs = 0;      // when the last OBJECT click was dispatched
static string g_ccObjName = "";   // ...and what it named
static bool   g_ccObjOurs = false;   // P-DRAW-148: does that click own the release?
static uint   g_ccChartMs = 0;    // when the last CHART click was dispatched

// Returns true when this event is the SECOND channel of a release that has
// already been dispatched - the caller drops it, exactly as if MT4 had sent
// only one. Call it for CHARTEVENT_CLICK and CHARTEVENT_OBJECT_CLICK only.

//--- P-DRAW-148 (2026-10-23) — THE TWIN IS OURS, AND ONLY OURS.
//
// The rule above is right about the SHAPE: MT5 reports one button-up twice, so the
// chart click that follows an object click is the same physical release and the
// shared handlers are written for one. What it never asked is WHOSE object click
// it was following — and on a chart that carries another product's objects, the
// answer is "not ours":
//
//   [dsclick] DEDUPE dropped CHART_CLICK (obj="BTRS_OBJ_63661149136134_FG" 0ms before)
//
// That line repeats on every click the user makes anywhere on the chart. `BTRS_OBJ_*`
// is not built by this program (no such name in this tree), it sits over the chart,
// and every click on it armed this drop — so the CHART click, which is the only
// channel that can open the strip on a drawing the terminal will not name, was
// thrown away. MEASURED against the user's own report «این چیزها اصلا سلکت و حذف
// نمی‌شه»: their two trend lines are `LM_…_Line` (a leg ruler, and `DrawStripAnchorOwner`
// says the strip serves it), the press named it (`PENSTACKARM obj="LM_…_Line"`), and
// the release never reached the toggle because a foreign object owned the drop.
//
// So the caller now says whether the object click was on a name this product builds
// or serves. A foreign one arms nothing: its click means nothing to us, and the
// chart click behind it is the user's own release. Our own objects keep the exact
// behaviour they had.
bool CompatOneClickDedupe(const int id, const string sparam, const bool ours)
{
   // The entry calls this for EVERY event (one line, so the parity checker can
   // see the shim call on it), so the non-click traffic - the mouse-move stream
   // above all - must cost one comparison and no clock read.
   if(id != CHARTEVENT_CLICK && id != CHARTEVENT_OBJECT_CLICK) return false;
   const uint now = GetTickCount();
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // ONLY a repeat of the SAME name is dropped. An object click that follows a
      // chart click is never dropped, whatever the order: if the terminal ever
      // sends the pair the other way round, dropping this one would remove the
      // only event that carries the object's NAME (the strip would never open,
      // the card would never answer). One direction of caution costs nothing.
      const bool same = (g_ccObjMs != 0 && now - g_ccObjMs <= COMPAT_CLICK_TWIN_MS
                         && sparam == g_ccObjName);
      if(same) { g_ccObjMs = 0; g_ccChartMs = 0; return true; }
      g_ccObjMs = now; g_ccObjName = sparam; g_ccObjOurs = ours; g_ccChartMs = 0;
      return false;
   }
   if(id == CHARTEVENT_CLICK)
   {
      if(g_ccObjMs != 0 && g_ccObjOurs && now - g_ccObjMs <= COMPAT_CLICK_TWIN_MS)
      {
         // P-DIAG-160 (temporary, remove with P-DRAW-143): the one drop that can
         // eat a genuine dismissal — name it while the strip is being chased.
         Print("[dsclick] DEDUPE dropped CHART_CLICK (obj=\"", g_ccObjName, "\" ",
               (int)(now - g_ccObjMs), "ms before)");
         g_ccObjMs = 0; g_ccChartMs = 0; return true;
      }
      // A FOREIGN object click leaves nothing armed: the chart click is the release.
      g_ccChartMs = now; g_ccObjMs = 0; g_ccObjName = ""; g_ccObjOurs = false;
      return false;
   }
   return false;
}

//+------------------------------------------------------------------+
//| R-POINTER-FRAME (2026-10-23) — ONE FRAME PER CHART EVENT.          |
//|                                                                  |
//| MEASURED, 2026-10-23: the terminal's own ledger carried 169       |
//| MOUSE_MOVE events over the 40 ms budget in one day (worst 906 ms,   |
//| with `ui=` 875) while the BOX drag the user was making measured     |
//| `move=0ms paint=0ms` — the drag's arithmetic is already free, and   |
//| what is not free is THE PAINT. `ChartRedraw` is 2.14 us on an idle  |
//| chart and is priced PER OBJECT on a full one (the project's own     |
//| measurement, EventHandlers P-PERF-49), and this chart carries 226-  |
//| 637 objects.                                                     |
//|                                                                  |
//| A chart event is a UNIT of work: its handlers write their objects   |
//| and the frame is owed once, at the end. What the shared source does  |
//| instead is call `ChartRedraw()` wherever a write lands, so one event  |
//| can ask for two or three SYNCHRONOUS full-chart paints — the first  |
//| of them painting a picture the next handler is about to change.      |
//| That is two costs for one frame: the extra paint, and the torn frame |
//| the notes throughout DrawStrip complained about («یک فریم عقب»).     |
//|                                                                  |
//| THE LAW (this shim, MT5-only by construction — the shared modules    |
//| keep their single `ChartRedraw()` line, byte-identical to MT4):     |
//|   * inside a chart event, a repaint request is a FLAG, never a paint;|
//|   * the entry opens the scope before its first handler and closes it  |
//|     after its last one, where the ONE owed frame is painted — after  |
//|     every writer, so the frame is complete;                         |
//|   * outside a chart event (OnCalculate / OnTimer / OnInit / OnDeinit)|
//|     nothing changes: the paint is immediate, exactly as before.      |
//| The ask count is kept so the ledger can print `frame=N`: N is how    |
//| many paints this event used to pay for, i.e. the saving is measured, |
//| not claimed. N==1 means the event was already minimal.               |
//|                                                                  |
//| The macro takes no parameters, so `ChartRedraw(0)` does NOT match it |
//| (measured: a one-parameter form makes every zero-argument call warn  |
//| 89 -- 99 of them in the Full build). The ONE explicit id call in the  |
//| tree, `RPlatRedraw` in Engine\RenderPlatform.mqh, is pointed at the   |
//| coalescer by name instead, so both call shapes reach it and the build |
//| stays at zero warnings.                                              |
//+------------------------------------------------------------------+
static bool s_cfInEvent = false;   // a chart event owns the frame
static bool s_cfOwed    = false;   // ...and someone asked for it
static int  s_cfAsked   = 0;       // how many owners asked (the ledger's N)
static int  s_cfWorst   = 0;       // worst N since the last read

// Opens the scope. Called ONCE per OnChartEvent, before the first handler, on
// the same line region as `g_inChartEvent = true` (P-PERF-34's scope).
void CompatFrameBegin()
{
   s_cfInEvent = true;
   s_cfOwed    = false;
   s_cfAsked   = 0;
}

// The repaint request every module already writes. Inside an event it records
// the ask and returns; outside it is the terminal's own call, unchanged.
void CompatChartRedraw()
{
   if(s_cfInEvent) { s_cfOwed = true; s_cfAsked++; return; }
   ChartRedraw();
}

// Closes the scope and paints the ONE frame it owes, AFTER every writer of the
// event. Returns the number of requests this event merged (1 = it was minimal).
int CompatFrameEnd()
{
   s_cfInEvent = false;
   const int asked = s_cfAsked;
   s_cfAsked = 0;
   if(asked > s_cfWorst) s_cfWorst = asked;
   if(s_cfOwed) { s_cfOwed = false; ChartRedraw(); }
   return asked;
}

// The worst merged count since the previous call — read by the ledger only.
int CompatFrameWorst()
{
   const int w = s_cfWorst;
   s_cfWorst = 0;
   return w;
}

// Everything BELOW this line — every shared module, the entries — asks the
// coalescer. (See the note above for the one call shape that does not match.)
#define ChartRedraw() CompatChartRedraw()

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
