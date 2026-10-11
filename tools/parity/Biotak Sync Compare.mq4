//+------------------------------------------------------------------+
//| Biotak Sync Compare                                              |
//|                                                                  |
//| SYNC VERIFICATION TOOL - not a product build.                     |
//|                                                                  |
//| It IS the production indicator (same include chain, same five      |
//| handlers, copied verbatim from `Biotak Trigger TH3` by             |
//| tools/make_sync_compare.py) plus a dump that runs on every new bar |
//| and on the timer:                                                  |
//|                                                                  |
//|   MQL4/Files or MQL5/Files\biotak_sync_values.csv   core values   |
//|   MQL4/Files or MQL5/Files\biotak_sync_objects.csv  drawn objects |
//|                                                                  |
//| PROCEDURE                                                          |
//|   1. Attach ONLY this indicator - remove the real one first, or    |
//|      use a NEW chart - same symbol, same timeframe, IDENTICAL      |
//|      settings in MT4 and MT5 (the defaults are identical by        |
//|      construction: one PropertiesAndInputs.mqh).                   |
//|   2. Let it run for a couple of bars (the timer also dumps, so a   |
//|      tick-less chart still lands inside a second).                 |
//|   3. `python tools/parity/parity-diff.py <mt4-csv> <mt5-csv>`.     |
//|                                                                  |
//| The two feeds are different brokers, so absolute prices answer a   |
//| DIFFERENT question - the tool reports the ladder in BASE-RELATIVE  |
//| units for that reason (see tools/parity/parity-diff.py).           |
//+------------------------------------------------------------------+
  //+------------------------------------------------------------------+
//|                                           Biotak Trigger TH3.mq4 |
//+------------------------------------------------------------------+
#property copyright "  Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"
#property version   "3.11"
#property strict
#property indicator_chart_window
#property description "Version 3.10 - GOLD: Post-Audit - All Critical Issues Fixed"
#property description "Race conditions fixed | Memory leaks eliminated | Buffer overflow prevented"

//                                                                    
// BUILD CONFIG - Must be first include!
//                      BuildConfig.mqh               
//                                                                    
#include "Biotak\BuildConfig.mqh"

#include "Biotak\MathConstants.mqh"
#include "Biotak\Logger.mqh"

#ifndef BUILD_LITE
#include "Biotak\Profiler.mqh"
#endif

#include "Biotak\PropertiesAndInputs.mqh"
#include "Biotak\ConstantsAndEnums.mqh"
#include "Biotak\ProjectConstants.mqh"
#include "Biotak\InputValidator.mqh"

//                                                                    
// Security & Performance Foundations (must precede GlobalVariables)
//                                                                    
#include "Biotak\FloatingPointHelper.mqh"
#include "Biotak\ObjectCountManager.mqh"
#include "Biotak\PerformanceOptimizations.mqh"
#include "Biotak\InputValidationEnhanced.mqh"

//                                                                    
// RUNTIME SETTINGS - single owner of panel-editable setting mirrors.
// MUST follow PropertiesAndInputs.mqh (input declarations) and precede
// GlobalVariables.mqh + all consumers (redirection #defines start here).
//                                                                    
#include "Biotak\RuntimeSettings.mqh"

#include "Biotak\GlobalVariables.mqh"

#include "Biotak\UtilityFunctions.mqh"

// Base / Knot Measurement Tool (two-click base box + Entry/SL/TP).
// Included here (before EventHandlers/menu) so both Full and Lite compile:
// Lite has no ring menu but keeps drag/delete/badge handling alive.
#include "Biotak\BaseKnotTool.mqh"
// P-HR-01: Horizontal Ray (Tools cell → 1 click places; same layer, same rule).
#include "Biotak\HRayTool.mqh"
#include "Biotak\PathTool.mqh"

//                                                                    
// Cache & Object Management Systems
//                                                                    
#include "Biotak\CalculationCache.mqh"
#include "Biotak\ZoneFactory.mqh"
#include "Biotak\ZoneConfig.mqh"       // single owner of zone settings
#include "Biotak\ZoneConstants.mqh"

#include "Biotak\ObjectCache.mqh"
#include "Biotak\PropertyChangeDetector.mqh"
#include "Biotak\VisibilityManager.mqh"

//                                                                    
// Timeframe & Calculation Modules
//                                                                    
#include "Biotak\TimeframeFunctions.mqh"
#include "Biotak\FractalTimeframes.mqh"
#include "Biotak\StandardTimeframes.mqh"

#include "Biotak\THCalculations.mqh"
#include "Biotak\ATRCalculations.mqh"
#include "Biotak\TradePlanFormulas.mqh"   // single source of trade-plan math (R-TRADEPLAN)
#include "Biotak\AdaptiveScaling.mqh"
#include "Biotak\BasePriceManager.mqh"

#ifndef BUILD_LITE
#include "Biotak\WaveAnalysis.mqh"
#include "Biotak\FrequencyOptimizer.mqh"
// TH3TOOL-ON (2026-09-19): restored from TH3TOOL-OFF — the TH3 tool is LIVE again.
#include "Biotak\TH3Tool.mqh"
#endif

//                                                                    
// Drawing & Rendering Pipeline
//                                                                    
#include "Biotak\ObjectFunctions.mqh"
// P-DRAW-01: the user's OWN drawings (fib, trend, hline, channel, box, …) and
// the style memory behind their toolbar. Above EventHandlers/BiotakPanels so
// both halves can ask it (the strip lives in the panels, the create hook in the
// event handlers).
#include "Biotak\DrawToolbar.mqh"
// P-DRAW-116: the CARD SURFACE'S OWN NUMBER TABLE, as a standalone header. BiotakPanels
// owns these names and re-includes this itself, so the cards are byte-identical — the
// only change is that it now sits ABOVE the strip. DrawStrip is include 99 and
// BiotakPanels is 118, so the strip's settings panel could never reach a `PNL_*` name
// and could only retype the value (DSTRIP_GEAR_W 312 = PNL_WEL 312, and five more).
// One table, two readers: from here the panel and the cards CANNOT drift.
#include "Biotak\CardMetrics.mqh"
// P-DRAW-08: the floating strip the drawings' hold opens. Full only — it is a
// screen surface, and Lite owns none (P-BUILD-01).
#include "Biotak\DrawStrip.mqh"
#include "Biotak\ExtendedDrawingFunctions.mqh"
#include "Biotak\ComboEngine.mqh"
#include "Biotak\FactorMode.mqh"
#include "Biotak\LevelPipeline.mqh"
#include "Biotak\ModeDefinitions.mqh"

#include "Biotak\LabelFunctions.mqh"
#include "Biotak\AlertFunctions.mqh"
#include "Biotak\HistoricalDataFunctions.mqh"
#include "Biotak\EventHandlers.mqh"

//                                                                    
// UI MODULES — Circular Menu, Settings Panels & HTF Candles          
// (BiotakKit must precede BiotakMenu; HTFCandles precede the kit)  
//                                                                    
#include "Biotak\HTFCandles.mqh"
#include "Biotak\BiotakKit.mqh"
#include "Biotak\BiotakMenu.mqh"
#include "Biotak\BiotakPanels.mqh"

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SYNC COMPARE - THE DUMP (byte-identical on MT4 and MT5)           |
//|                                                                  |
//| Every call below exists on BOTH compilers: ObjectsTotal,          |
//| ObjectName, ObjectGetDouble/Integer/String, FileOpen/Write/Seek/  |
//| Size, TimeToString, DoubleToString, Time[0]/Open[0]/High[0]/       |
//| Low[0]/Close[0]. On MT5 the two object enumerators arrive through  |
//| the MT5Compat shims - which is exactly why one file can carry      |
//| both builds and the CSVs stay comparable by construction.          |
//+------------------------------------------------------------------+
datetime g_syncLastDumpedBar = 0;
int      g_syncValuesFile    = INVALID_HANDLE;
int      g_syncObjectsFile   = INVALID_HANDLE;
int      g_syncStateFile     = INVALID_HANDLE;

#define SYNC_VALUES_FILE  "biotak_sync_values.csv"
#define SYNC_OBJECTS_FILE "biotak_sync_objects.csv"
#define SYNC_STATE_FILE   "biotak_sync_state.csv"
#define SYNC_MAX_OBJECTS  2000

string SyncDumpStr(const double v)
{
    return DoubleToString(v, 10);
}

void SyncOpenFiles()
{
    if(g_syncValuesFile == INVALID_HANDLE)
        g_syncValuesFile = FileOpen(SYNC_VALUES_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
    if(g_syncObjectsFile == INVALID_HANDLE)
        g_syncObjectsFile = FileOpen(SYNC_OBJECTS_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
    if(g_syncStateFile == INVALID_HANDLE)
        g_syncStateFile = FileOpen(SYNC_STATE_FILE, FILE_WRITE|FILE_READ|FILE_CSV, ',');
}

void SyncWriteHeader(const int fh)
{
    if(fh == INVALID_HANDLE) return;
    if(FileSize(fh) > 0) return;
    if(fh == g_syncValuesFile)
        FileWrite(fh, "barTime","barOpen","barHigh","barLow","barClose",
                  "basePrice","thPct","thStep","adaptedStep","atrStep","comboStep",
                  "structVal","patternVal","triggerVal",
                  "atrStruct","atrPattern","atrTrigger","calcMs");
    else if(fh == g_syncObjectsFile)
        FileWrite(fh, "barTime","name","type","price1","price2","time1","time2",
                  "color","style","width","timeframes","back","fill","ray","zorder","text");
    else
        FileWrite(fh, "barTime","symbol","tfMinutes","digits","point",
                  "barsChart","barsEmul","barsM1","barsD1",
                  "basePrice","histCount","histFirst","histLast","m1Power",
                  "startTypeInput","startTypeLive","customStartPrice",
                  "thPct","thStep","adaptedStep","atrStep","comboStep",
                  "leg1","leg2","leg3","leg4","leg5","leg6","weightedATR");
}

//--- close every handle on deinit (nothing below the call site writes them).
void SyncCloseFiles()
{
    if(g_syncValuesFile != INVALID_HANDLE)  { FileClose(g_syncValuesFile);  g_syncValuesFile = INVALID_HANDLE; }
    if(g_syncObjectsFile != INVALID_HANDLE) { FileClose(g_syncObjectsFile); g_syncObjectsFile = INVALID_HANDLE; }
    if(g_syncStateFile != INVALID_HANDLE)   { FileClose(g_syncStateFile);   g_syncStateFile = INVALID_HANDLE; }
}

void SyncDumpValues()
{
    SyncOpenFiles();
    if(g_syncValuesFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncValuesFile);
    FileSeek(g_syncValuesFile, 0, SEEK_END);

    uint t0 = GetTickCount();

    double basePrice   = GetBasePriceForTH();
    double thPct       = GetTimeframeTH();
    double thStep      = CalculateTH(basePrice, Digits, thPct);
    double adaptedStep = GetAdaptedStepSize(thStep);
    double atrStep     = CalculateATRBasedStep();
    double comboStep   = GetComboStepSize(basePrice);

    double structVal = 0.0, patternVal = 0.0, triggerVal = 0.0;
    CalculateFractalValues(adaptedStep, structVal, patternVal, triggerVal);

    double atrStruct = 0.0, atrPattern = 0.0, atrTrigger = 0.0;
    CalculateATRFractalValues(atrStruct, atrPattern, atrTrigger);

    uint t1 = GetTickCount();

    FileWrite(g_syncValuesFile,
              TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS),
              SyncDumpStr(Open[0]), SyncDumpStr(High[0]), SyncDumpStr(Low[0]), SyncDumpStr(Close[0]),
              SyncDumpStr(basePrice), SyncDumpStr(thPct), SyncDumpStr(thStep), SyncDumpStr(adaptedStep),
              SyncDumpStr(atrStep), SyncDumpStr(comboStep),
              SyncDumpStr(structVal), SyncDumpStr(patternVal), SyncDumpStr(triggerVal),
              SyncDumpStr(atrStruct), SyncDumpStr(atrPattern), SyncDumpStr(atrTrigger),
              IntegerToString((int)(t1 - t0)));
}

//--- THE CAUSE, NOT THE SYMPTOM: every INPUT the level ladder reads, next to
//--- the values it produced. If two runs disagree on a level, this file says
//--- which input disagreed - the reference price (and whether it came from
//--- today's history file or from the live Bid), the history depth, the six ATR
//--- legs, or a custom TH anchor left over on the chart. Identical on both
//--- compilers: Symbol/Digits/Point, iBars(iBars(sym,tf) with minutes),
//--- the shared base-price state and the shared ATR batch.
void SyncDumpState()
{
    SyncOpenFiles();
    if(g_syncStateFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncStateFile);
    FileSeek(g_syncStateFile, 0, SEEK_END);

    double basePrice   = GetBasePriceForTH();
    double thPct       = GetTimeframeTH();
    double thStep      = CalculateTH(basePrice, Digits, thPct);
    double adaptedStep = GetAdaptedStepSize(thStep);
    double atrStep     = CalculateATRBasedStep();
    double comboStep   = GetComboStepSize(basePrice);

    // the six legs the weighted ATR averages - the ladder's volatility ruler
    double legs[];
    ArrayResize(legs, 6);
    ArrayInitialize(legs, 0.0);
    CalculateATRBatchTrex(legs, (ENUM_TIMEFRAMES)CompatTF(Period()), 1);
    double weightedATR = CalculateWeightedATR(PERIOD_CURRENT);

    FileWrite(g_syncStateFile,
              TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS),
              Symbol(),
              IntegerToString((int)Period()),
              IntegerToString((int)Digits),
              SyncDumpStr(Point),
              IntegerToString(iBars(_Symbol, 0)),
              // MT5-only emulation of MQL4's `Bars`: on MT4 this is the native
              // series count. If it lags barsChart, the MT5 run is reading a
              // shorter series than MT4 would (history still downloading).
              IntegerToString(Bars),
              IntegerToString(iBars(_Symbol, 1)),
              IntegerToString(iBars(_Symbol, 1440)),
              SyncDumpStr(basePrice),
              IntegerToString(g_historyCount),
              (g_historyCount > 0 ? GetHistoryEntry(0) : ""),
              (g_historyCount > 0 ? GetHistoryEntry(g_historyCount - 1) : ""),
              SyncDumpStr(g_referenceM1Power),
              IntegerToString((int)inpTHStartPointType),
              IntegerToString((int)g_thStartPointType),
              SyncDumpStr(g_customTHStartPrice),
              SyncDumpStr(thPct), SyncDumpStr(thStep), SyncDumpStr(adaptedStep),
              SyncDumpStr(atrStep), SyncDumpStr(comboStep),
              SyncDumpStr(legs[0]), SyncDumpStr(legs[1]), SyncDumpStr(legs[2]),
              SyncDumpStr(legs[3]), SyncDumpStr(legs[4]), SyncDumpStr(legs[5]),
              SyncDumpStr(weightedATR));

    // اگر لنگر سفارشی روی چارت باقی مانده باشد، همین خط در لاگ می‌گوید کدام طرف از قیمت سفارشی استفاده می‌کند.
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE)
        Print("[SYNC] TH anchor is CUSTOM on this chart: ", DoubleToString(g_customTHStartPrice, Digits),
              " (input asked for ", EnumToString(inpTHStartPointType), ")");
}

void SyncDumpObjects()
{
    SyncOpenFiles();
    if(g_syncObjectsFile == INVALID_HANDLE) return;
    SyncWriteHeader(g_syncObjectsFile);
    FileSeek(g_syncObjectsFile, 0, SEEK_END);

    string barTag = TimeToString(Time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS);
    int total = ObjectsTotal();
    int dumped = 0;
    for(int i = 0; i < total && dumped < SYNC_MAX_OBJECTS; i++)
    {
        string name = ObjectName(i);
        if(StringFind(name, inpObjectPrefix) != 0) continue;

        long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
        double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
        double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
        long   t1 = ObjectGetInteger(0, name, OBJPROP_TIME, 0);
        long   t2 = ObjectGetInteger(0, name, OBJPROP_TIME, 1);

        FileWrite(g_syncObjectsFile,
                  barTag,
                  name,
                  IntegerToString((int)type),
                  SyncDumpStr(p1), SyncDumpStr(p2),
                  TimeToString((datetime)t1, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  TimeToString((datetime)t2, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_COLOR)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_STYLE)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_WIDTH)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_BACK)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_FILL)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_RAY_RIGHT)),
                  IntegerToString((int)ObjectGetInteger(0, name, OBJPROP_ZORDER)),
                  ObjectGetString(0, name, OBJPROP_TEXT));
        dumped++;
    }
}

//--- ONE trigger for both dumps: a NEW BAR (and the timer, for a quiet chart).
void SyncCompareTick()
{
    if(Bars <= 0) return;
    if(Time[0] == g_syncLastDumpedBar) return;
    g_syncLastDumpedBar = Time[0];
    SyncDumpValues();
    SyncDumpObjects();
    SyncDumpState();   // the inputs behind those values - see its header
}


int OnInit()
{
    // P-PERF-04: attach / timeframe switch budget (both halves are measured:
    // OnInitHandler is the indicator, the UI kit restores menu + panels).
    // P-PERF-10: this entry measures BOTH halves of the init budget (the
    // indicator handler and the UI kit) so the report can name which one owns
    // the attach/timeframe-switch stall instead of reporting one opaque total.
    // P-DRAW-120 (2026-10-01) — AN ATTACH OWNS A CHART THAT CARRIES NO PANEL.
    // P-DRAW-85 wrote `DrawStripSweepStale()` for exactly this ("no orphan survives a
    // reattach") and documented its ONE call as "from the entry's OnInit beside the
    // teardown's own `DrawStripClose()`" — but `git grep SweepStale HEAD` finds the
    // definition and NO call site: the sweep was never wired, so the promise the rule
    // makes has never been delivered. What that costs was measured on 2026-10-01
    // (EURUSD,M5, report «روی stroke که کلیک می‌کنم متن‌ها این‌طوری ناقص هست»): the
    // terminal holds every object of the open Stroke tab at its own seat with its own
    // ink (`TABCENSUS GR2T "50 % line":14865611 z=1442`, `GS0T "STROKE"` in
    // `MQL4\Logs\20261001.log`), while the screen paints 31 of those 104 objects — and
    // the last gear paint in that log is 14:37:08, before the 15:10:39 reload whose
    // statics (`s_dsOpen=false`, `s_dsGear=0`) answer nothing. A family the previous
    // instance left is REUSED (`DrawStripSkinBmp`/`DrawStripFaceZ`/`DrawStripLblAt`
    // decide "create or rewrite?" from `ObjectFind(0,nm) < 0` alone), so one half keeps
    // the older build's own layer and the other half never gets a second writer at all.
    // This is the destroy an attach can prove: at OnInit this instance has painted
    // nothing, so every `PnlDrawS_*` object on the chart is someone else's. One prefix
    // scan per ATTACH, never per frame.
#ifndef BUILD_LITE
    DrawStripSweepStale();
#endif

    uint p4i = GetTickCount();
    int result = OnInitHandler();
    uint p4ind = GetTickCount() - p4i;
    p4i = GetTickCount();
    if(result == INIT_SUCCEEDED)
    {
        // --- Circular menu / settings panels / HTF candles ---
        InitializeUIStates();      // menu + UI globals
        InitializeBiotakKit();   // panel state, colors, boxes, custom lines
        InitializeHTFCandles();    // HTF candle engine
        CreateMenu();              // orb + ring + tools
        // P-UI-114: right-click era deleted — terminal menu untouched, strip on
        // LEFT hold (DrawStrip.mqh).
        ChartRedraw();
    }
    uint p4ui = GetTickCount() - p4i;
    P4ReportSlow("OnInit (" + (result == INIT_SUCCEEDED ? "ok" : "fail") + ")" +
                 P4InitLedgerTag(p4ind, p4ui),
                 p4ind + p4ui, P_P4_INIT_WARN_MS);
    return result;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    uint p4d = GetTickCount();   // P-PERF-04: teardown budget (timeframe switch)
    // P-PERF-44: the ledger is read by the breakdown line below, so it is cleared
    // HERE - at the start of the transaction it describes, never inside a saver
    // (a saver that returns early would leave the previous teardown's numbers).
    GVLedgerResetAll();
    // --- UI teardown (before the base handler clears chart objects) ---
    // P-UI-21: close panels/palette/strip/dropdowns FIRST (flushes the
    // card-12 text edit + releases the modal chart lock) — otherwise
    // REASON_REMOVE leaves Pnl*/Pal_* ghosts behind, swept only at next attach.
    // P-PERF-15: the teardown budget line says the switch costs ~300 ms and
    // cannot say which of the six owners spent it, so each one is timed here.
    // Reported only when the total blows the budget, like every other ledger.
    uint p15t = p4d;
    uint p15Pnl, p15Menu, p15Htf, p15Save, p15Cleanup, p15Handler;
    PnlCloseAll();
    p15Pnl = GetTickCount() - p15t; p15t = GetTickCount();
    // P-DRAW-08: the drawing strip's own objects die with the instance — the
    // removal path owns them, so no PnlDrawS_* button survives a REASON_REMOVE
    // (the name was `Biotak_DS_*` in the note that first said this; the objects
    // have been `PnlDrawS_*` since birth — P-DRAW-73, catalogue 24).
    DrawStripClose();
    DeleteMenu();
    p15Menu = GetTickCount() - p15t; p15t = GetTickCount();
    DeleteHTFCandles();
    p15Htf = GetTickCount() - p15t; p15t = GetTickCount();
    SaveBiotakKit();
    p15Save = GetTickCount() - p15t; p15t = GetTickCount();
    CleanupUIStates(reason);
    p15Cleanup = GetTickCount() - p15t; p15t = GetTickCount();
    OnDeinitHandler(reason);
    SyncCloseFiles();   // SYNC COMPARE: the two CSVs close here
    p15Handler = GetTickCount() - p15t;
    uint p15total = GetTickCount() - p4d;
    P4ReportSlow("OnDeinit reason=" + IntegerToString(reason),
                 p15total, P_P4_INIT_WARN_MS);
    // P-PERF-37: save= was the biggest single item of an ordinary timeframe
    // switch and nothing said WHY. The write shadow's whole promise is that an
    // untouched session costs zero terminal calls and no disk flush, so the pass
    // now reports what it actually did - how many keys it wrote, how many it
    // proved were already on disk, whether the terminal-wide `GlobalVariablesFlush`
    // ran, and the NAMES of the first writers. A number without a cause is what
    // this project refuses to act on; this line is the cause.
    // P-PERF-44: EVERY saver reports now, not only the override pass. The line
    // that carried `save writes=0/106 flushed=0` next to a 125 ms phase was a
    // number without an owner: the palette and UI-state blocks wrote 13 + 6 keys
    // plus a terminal-wide flush that no field of this line could see, and the HTF
    // block wrote 15 more with no guard at all. `flush=` counts the disk copies
    // this teardown actually performed (ONE owner, GVFlushCommit, so 1 is the
    // ceiling however many saver blocks ran).
    if(p15total > P_P4_INIT_WARN_MS)
        _LOG_GATE_W Print("[W][PERF] OnDeinit breakdown: pnl=", (int)p15Pnl, "ms menu=", (int)p15Menu,
              "ms htf=", (int)p15Htf, "ms save=", (int)p15Save, "ms cleanup=", (int)p15Cleanup,
              "ms handler=", (int)p15Handler, "ms | ovr w=", RSSaveWrites(), "/",
              (RSSaveWrites() + RSSaveSkipped()),
              " pal w=", GVLedgerWrites(GV_BLOCK_PALETTE), "/",
              (GVLedgerWrites(GV_BLOCK_PALETTE) + GVLedgerSkipped(GV_BLOCK_PALETTE)),
              " ui w=", GVLedgerWrites(GV_BLOCK_UI), "/",
              (GVLedgerWrites(GV_BLOCK_UI) + GVLedgerSkipped(GV_BLOCK_UI)),
              " htf w=", GVLedgerWrites(GV_BLOCK_HTF), "/",
              (GVLedgerWrites(GV_BLOCK_HTF) + GVLedgerSkipped(GV_BLOCK_HTF)),
              " flush=", GVFlushRuns(),
              " first=", RSSaveNamed(0), ",", RSSaveNamed(1), ",", RSSaveNamed(2),
              // P-PERF-45 evidence: frames that actually ran, over the ticks that
              // ended with the frame still owed (the starvation count). `starved`
              // must read ~0 - a number tracking the frame count means the pump is
              // starving the progress-maker again.
              " | coop frame=", CoopFrameRuns(), "/", (CoopFrameRuns() + CoopFrameStarved()));
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &real_volume[],
                const int &spread[])
{
    int result = OnCalculateHandler(rates_total, prev_calculated, time, open, high, low, close, tick_volume, real_volume, spread);

    SyncCompareTick();   // SYNC COMPARE: dump on a new bar
    // --- UI kit: HTF forming-candle live update + new-bar redraw ---
    RefreshKitOnBar();
    return result;
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  // P-PERF-04: name the phase behind an interaction hitch (indicator half vs
  // menu/panel half). Logs only when the pair blows the 40 ms budget.
  // P-PERF-34: scope the frame deferral to this window. A forced frame inside
  // an event is SCHEDULED, never executed - see the EventHandlers note. Setting
  // the flag here (not in the handlers) is what makes the guarantee hold for
  // every path they call, including ones added later.
  g_inChartEvent = true;
  uint p4t = GetTickCount();
  OnChartEventHandler(id,lparam,dparam,sparam);
  uint p4a = GetTickCount() - p4t;
  p4t = GetTickCount();
  // P-UI-114: the strip opens on a LEFT hold inside DrawStripOnEvent below.
  // --- Circular menu / settings panels / palette ---
  HandleUIChartEvent(id,lparam,dparam,sparam);
  // P-DRAW-08: the drawing strip's own buttons and its dismiss clicks. Its own
  // owner, its own objects — it shares no state with the panels.
  DrawStripOnEvent(id,lparam,dparam,sparam);
  // P-PAL-19 (2026-10-02) — THE ONE BRIDGE. DrawStrip is include 99 and the panels
  // are 124, and MQL4 needs a definition before its use, so the strip cannot call
  // `PalOpenDraw` itself: it leaves a REQUEST (DrawStripPalAsk) and this line — the
  // first place in the program that sees BOTH sides — performs the open. One
  // direction, one place, no forward declaration, and the strip has no knowledge of
  // the palette's existence beyond this handshake.
  int palAsk = DrawStripPalAsked();
  if(palAsk >= 0) PalOpenDraw(DrawStripPlateX(), DrawStripPlateY(), DrawStripPlateW());
  // P-PAL-20 (2026-10-02) — THE LEDGER, REWRITTEN WHOLE, EVERY EVENT, AND WRITTEN
  // LAST. This is the same bridge's second direction and it exists for one reason: a
  // colour pick is a release on TWO channels, `HandleUIChartEvent` serves the palette
  // first (above), and then the strip asks `DrawStripPointInside` about the release
  // PIXEL — a pixel on the popup, not on the plate — read false and closed the whole
  // strip (DrawStrip_Router:1113). The strip owns that popup, so its pixels are its
  // pixels. The strip cannot see `g_PalX/PalW()`; these lines are the only place that
  // can, and LAST is the whole discipline: the ledger answers for the chart as the
  // event LEFT it, so a popup closed above is already out of it.
  //
  // P-PAL-19f — AND THE REPAINT IS SPENT HERE, ONCE, AFTER the popup's route. The
  // apply owns a flag and nobody repaints from inside a gesture it does not own
  // (P-PERF-34's law, the same sentence the owed-frame comment below is built on).
  if(DrawStripPalRepaintTake()) { DrawStripPaint(); ChartRedraw(); }
  // P-PAL-19e — AND THE PALETTE CLOSES WITH ITS PARENT. A colour popup opened by
  // the STRIP belongs to the strip: when the strip goes (close, kind switch, deinit)
  // the popup must go with it, or it stays on the chart as a floater nobody owns
  // («همراه والدش بسته بشه»). One direction, same bridge.
  if(!DrawStripPalParentLive() && PalKindIsDrawing(g_PalKind)) PalClose();
  DrawStripSurfaceClear();
  if(g_PalOpen && PalKindIsDrawing(g_PalKind) && DrawStripPalTargetLive())
     DrawStripSurfacePublish(g_PalX, g_PalY, PalW(), PalH());
  uint p4b = GetTickCount() - p4t;
  g_inChartEvent = false;  // P-PERF-40: A USER ACTION SETTLES THE FRAME IT OWED — IN THE SAME EVENT.
  //
  // P-PERF-34 made a forced frame inside an event SCHEDULED instead of executed,
  // because the body it measured was 531 ms of rebuild and it froze the press
  // that asked for it. The edit was then left owed to the 250 ms timer, and the
  // live log measured what that costs:
  //
  //   [W][PERF] owed frame (chart-event) waited=46..266ms body=0ms stage=0 clear=0
  //
  // `waited` is the whole story — a press was answered between 0 and 266 ms
  // later, uniformly up to the timer's cadence — and `body=0ms` is worse than it
  // looks: by the time the timer ran the frame there was nothing left to draw,
  // because the discrete path had already repainted the OLD picture. So the
  // switch was acknowledged by a repaint that changed nothing and the real frame
  // arrived up to a quarter second afterwards. That is the "فسفس".
  //
  // The pump is the single owner of "run owed work": cheap sweeps first, the
  // frame on the leftover slice, budget-bounded (COOP_BUDGET_MS) so this cannot
  // become an unbounded in-event stall, and single-flight so three fast presses
  // are one frame. It runs the frame with force_redraw = FALSE, which is exactly
  // what keeps RedrawAllObjects' event guard meaningful — the guard still
  // protects every event-path caller that does NOT pump, and this is the one
  // place that has explicitly earned the pass.
  //
  // Cost when nothing is owed: four flag reads and a couple of GetTickCount.
  // It is therefore correct to call it on EVERY event, not just the discrete
  // ones — and that is deliberate, because the entry point is the only place that
  // covers the paths inside both handlers (and the ones added later).
  p4t = GetTickCount();
  CoopPump();
  uint p4c = GetTickCount() - p4t;
  // P-UI-40: AND THE PANEL FOLLOWS WHAT IT DOES NOT OWN.
  //
  // A hotkey changes state that an OPEN card displays, but the hotkeys live in
  // EventHandlers and the panel in a later file, so they cannot repaint it — the
  // rows read the live value, the switch IMAGE is a bitmap only a paint pass
  // replaces. Draining the request HERE (same event) means a key press and the
  // panel switch it drives land together; RefreshKitOnBar drains it too, as the
  // net for any path that does not pass through this tail.
  //
  // `panels=` is in the budget check for the same reason `settle=` is: a sync
  // that hides its cost would be the defect this cycle is fixing, one level up.
  p4t = GetTickCount();
  UISyncDrain();
  uint p4e = GetTickCount() - p4t;
  // P-PERF-26: the NAME next to the id - a ledger nobody can read without
  // recalling which number means what is how id=1 (OBJECT_CLICK) got filed as a
  // cursor-move for two cycles.
  // P-PERF-40: `settle=` is the frame this event drained, and it is IN the budget
  // check on purpose — a drain that hides its own cost from the ledger would be
  // the same defect this cycle is fixing, one level up.
   // P-PERF-50: the ledger message is ~15 string ops (P4EventName + six
   // IntegerToString + concatenations) and P4ReportSlow no-ops under budget —
   // so building it on EVERY event (a MOUSE_MOVE storm is hundreds/sec) was
   // pure garbage for the same silence. The total is hoisted first and the
   // message is built only when it will actually print: identical log lines,
   // zero steady-state strings. Same gate in the Lite entry.
   uint p4tot = p4a + p4b + p4c + p4e;
   if(p4tot >= P_P4_EVENT_WARN_MS)
      P4ReportSlow("chart event " + P4EventName(id) + "(id=" + IntegerToString(id) + ") [indicator=" +
               P4MsTag(p4a) + " ui=" + P4MsTag(p4b) + " settle=" + P4MsTag(p4c) +
               " panels=" + P4MsTag(p4e) + "]",
               p4tot, P_P4_EVENT_WARN_MS);
}

//+------------------------------------------------------------------+
//| Timer function - periodic housekeeping                           |
//+------------------------------------------------------------------+
void OnTimer()
{
    // P-UI-113-OFF (2026-09-23): no fast window — every tick is housekeeping.

    // P-PERF-16: the 250 ms safety refresh behind the cached UI metrics. Resizing
    // the chart also fires a chart-change event (which invalidates immediately);
    // this line covers a missed notification and costs two terminal reads per
    // quarter second instead of two per hit-test item.
    CircUIMetricsInvalidate();

    // FIX: If indicator is not yet fully initialized (e.g. waiting for history),
    // retry drawing periodically even without new ticks.
    // P-PERF-06: a staged post-wipe rebuild (attach / TF switch / topology
    // toggle) also advances here, so a tick-less chart still settles in ~1 s.
    // P-PERF-35: the coop pump owns the timer's heavy work. The sweep jobs are
    // OWED here - once per timer, exactly the cadence they had - and drained by
    // the pump under a millisecond slice, cheap jobs first and the owed frame
    // last. A job can therefore be delayed by the slice, but no job can hold the
    // terminal for its whole run, and the frame still advances on a tick-less
    // chart (the pump treats "rebuild in flight" as owed by definition).
    CoopOwe(COOP_JOB_OBJ_CLEANUP);
    CoopOwe(COOP_JOB_LABEL_EXPIRY);
    CoopOwe(COOP_JOB_STATUS_TEXT);
    CoopPump();

    // --- UI kit: HTF forming candle + new-bar redraw + chart-lock watchdog ---
    // (P-UI-40's UISyncDrain rides inside RefreshKitOnBar — one drain owner.)
    RefreshKitOnBar();
    ChartScrollReconcile();

    // P-LM-09: the leg meter's readout is a 4-second VISITOR, and this is its clock.
    // It belongs here and not in OnCalculate: a plate must expire on a chart that has
    // not ticked (a weekend, a dead symbol) exactly as on a busy one, and the timer is
    // the only thing already running when the market is asleep. The sweep is one
    // comparison while the tool has no measurement on the chart, and one bool per
    // measurement while it has; the four deletes of an expiry happen exactly once.
    // (P-LM-10's drag channel retired here with the native drag itself: P-LM-11's
    // edit owner moves the family in the mouse event, so there is nothing left
    // for a timer to chase.)
    LegMeasureExpireSweep();

    // P-LM-16b: the handles' third riding channel — the net under MOUSE_MOVE
    // (drag-pans) and CHART_CHANGE (wheel, keys, auto-scroll). Guarded writes:
    // a chart that has not moved costs one loop of reads and no ObjectSet*.
    LegMeasureRideChart();

    // P-UI-100 (2026-09-22): the selection net of the two hand-set lines — the
    // one owner that does not depend on any event reaching us. A selection that
    // outlived the gesture that made it is what lets MT4 drag the custom price
    // line (and the whole ladder derived from its price) along with somebody
    // else's fib or box («وقتی فیو یا باکس از همون محل میکشم کاستوم پرایس
    // جابجا میشه»). The 250 ms clock is the net under the layers whose events
    // are consumed whole (the box tool's draw session); the gesture starts
    // themselves clear it in their own event, so this is a floor, not the path.
    // Cost: one probe while the button is down, then three guarded reads.
    HandLinesSelectionNet();

    // P-TH3-INFO-11 (2026-09-22): the caption heal net - the active family's
    // one question every 250 ms (reads-only while healthy; one TH3CAP line
    // per action). Full entry only: Lite owns no caption UI (P-BUILD-01).
    TH3InfoCaptionHeal();

    // P-UI-98r: the net under the card-cull's event hooks (open/close/drag/
    // draw) - zoom, resize and forming-candle drift converge here within one
    // tick of the 250 ms clock. Closed / HTF-off / nothing drawn: three bool
    // reads and out.
    HTFCardCullRefresh();

    // P-TH3-PB-DRAG-LOCK (2026-09-22): the band's drag heartbeat - a stuck
    // terminal or an off-chart release leaves OBJECT_DRAG silent, and the
    // button-up MOUSE_MOVE never arrives; the 1.5 s idle here is the only
    // heal that does not need the terminal to cooperate.
    TH3BaseBandDragHeartbeat();

    SyncCompareTick();   // SYNC COMPARE: the timer's own dump

    // NOTE (2026-09-23, P-DRAW-18): `WindowPriceMax()/Min()` answer 0/0 during
    // OnInit - the chart window is not mapped yet (`run hi=0.00000 lo=0.00000` in
    // the terminal's log) - while a timer tick ~1 s later reads the real range
    // (`window hi=4410.70000 lo=4230.80000` on XAUUSD,H1). Anything needing the
    // visible window belongs HERE, never in OnInitHandler.
}
