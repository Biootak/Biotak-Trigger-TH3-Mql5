// ========================================================================
// OWNED MT5 ENTRY - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak Trigger TH3.mq4
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: the MT5-only changes live
// here directly, marked MT5-ONLY / R-RENDER-ENGINE / P-PERF-*. The retired
// generator (tools/parity/_retired/resync-module.py) must never run on this
// tree - it would overwrite every MT5-only edit.
//
// The MT5-specific blocks below are the ONLY differences from MT4:
//   * the MQL5Compat include (the series-array emulation and the resource
//     adaptations MQL5 needs),
//   * #define BIOTAK_RENDER_ENGINE (the canvas engine, see below),
//   * the RBridgeInit / RBridgeShutdown / RBridgePump calls,
//   * CompatRefreshChartData() in OnCalculate / OnTimer,
//   * the P4Report* census / teardown stamps.
// ========================================================================
  //+------------------------------------------------------------------+
//|                                           Biotak Trigger TH3.mq4 |
//+------------------------------------------------------------------+
#property copyright "Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"
#property version   "3.12"
#property strict
#property indicator_chart_window
// MT5-ONLY PLATFORM PROPERTY: MQL5 warns when an indicator declares no plot;
// MQL4 never needed to say it. The indicator draws objects, not buffers.
#property indicator_plots 0

#property description "Biotak Trigger TH3 v3.12 - Freeware, not for sale."
#property description "Trigger/TH/TH3 levels, HTF candles, hand drawings. By Biotak."

// MT5-ONLY (R-RENDER-ENGINE, 2026-10-17): the ladder's trigger lines and pip
// labels are painted by the canvas engine (Engine\RenderBridge.mqh) instead of
// one chart object per element. Comment this ONE line out to return to the
// object path for A/B — every call site on both sides is guarded by the flag.
#define BIOTAK_RENDER_ENGINE

// MT5-ONLY DIAGNOSTIC (R-RENDER-ENGINE): uncomment to compile the scene dump
// (RBridgeDumpCsv in RenderBridge.mqh). With that build running, set the global
// variable BTRS_DUMP=1 in the terminal and the next frames write the drawn
// family to MQL5\Files\BTRS_scene_MT5.csv; tools/mt4-scene-dump.mq4 writes the
// same rows from the MT4 chart and tools/parity/scene-diff.py diffs the two.
//#define BTRS_SCENE_DUMP

//                                                                    
// BUILD CONFIG - Must be first include!
//                      BuildConfig.mqh               
//                                                                    
#include "Biotak\BuildConfig.mqh"

#include "Biotak\MathConstants.mqh"
#include "Biotak\Logger.mqh"
// MT5-ONLY PLATFORM LAYER - MQL4 API shims (Symbol/Digits/Point/Bid/Ask,
// MarketInfo, value iATR, the Time[]..Close[]/Bars series emulation, the MQL4
// object-call forms and ObjectSetText). It must precede every shared module.
// It adds NO feature: it is what lets the MT4 source compile and behave as MT4.
#include "MT5Compat\MQL5Compat.mqh"


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
// MT5-ONLY (P-PATH-CANVAS, 2026-10-29): the path's rubber band is painted on the
// engine's FRONT layer instead of dragging a chart object behind the cursor, so
// PathTool has to see the engine's declarations. RenderCore pulls only
// RenderPlatform (pure MQL calls) and needs no product module, which is why it
// is safe this early; the bridge (the product seam) still comes last.
#ifdef BIOTAK_RENDER_ENGINE
#include "Engine\RenderCore.mqh"
#endif
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
// MT5-ONLY (R-RENDER-ENGINE): the canvas bridge. Must precede its only call
// site (LevelPipeline) and follow ObjectCache (pin retirement removes cache
// slots). Compiled away entirely when BIOTAK_RENDER_ENGINE is undefined.
#ifdef BIOTAK_RENDER_ENGINE
#include "Engine\RenderBridge.mqh"
#endif
#include "Biotak\LevelPipeline.mqh"
#include "Biotak\ModeDefinitions.mqh"

#include "Biotak\LabelFunctions.mqh"
#include "Biotak\AlertFunctions.mqh"
#include "Biotak\HistoricalDataFunctions.mqh"
// P-SESS: the sessions engine + model + renderer. Ahead of EventHandlers -
// the coop pump (EventHandlers_Tail) calls SessionsTick, and top-down
// resolution needs the definition before its use. Shared module rules:
// no UI reads (P-BUILD-01).
#include "Biotak\Sessions_Time.mqh"
#include "Biotak\Sessions_Model.mqh"
#include "Biotak\Sessions_Draw.mqh"
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
int OnInit()
{

    // MT5-ONLY PLATFORM CALL, AND IT MUST BE THE FIRST STATEMENT.
    // MQL4 fills the predefined series arrays (Bars, Time[]..Close[]) before
    // OnInit is entered; MQL5 has no such arrays, so MT5Compat emulates them and
    // something has to fill them. The shared modules read those values during
    // init (ZoneFactory's safeBars, ExtendedDrawingFunctions' startTime,
    // BaseKnotTool's span, ATRCalculations' effective bars), so refreshing here
    // is what makes the first paint match MT4 exactly.
    CompatRefreshChartData();
    // MT5-ONLY (P-UI-223): decode the UI skins before any label exists.
    CompatWarmUiSkins();
    // MT5-ONLY (P-PERF-117b): BEFORE this instance creates one object, name what
    // the chart already carries — an orphan from the previous instance names
    // itself here, and so does the fix's target family.
    P4LeftoverCensus("oninit");
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
    // (EURUSD,M5, report «روی stroke که کلیک‌می‌کنم متن‌ها این‌طوری ناقص هست»): the
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
    uint p4i = GetTickCount();
    int result = OnInitHandler();
    uint p4ind = GetTickCount() - p4i;
    p4i = GetTickCount();
    if(result == INIT_SUCCEEDED)
    {
        // P-DRAW-120: the sweep is a chart WRITE — after the seed, after the refusal.
#ifndef BUILD_LITE
        DrawStripSweepStale();
#endif
        // --- Circular menu / settings panels / HTF candles ---
        // P-PERF-110: each UI quarter is timed AT ITS CALL SITE so a ui=1266
        // names its owner (menu / kit / htf / states) instead of one opaque total.
        uint p4q = GetTickCount();
        InitializeUIStates();      // menu + UI globals
        g_pInitMsStates = GetTickCount() - p4q;  p4q = GetTickCount();
        InitializeBiotakKit();   // panel state, colors, boxes, custom lines
        g_pInitMsKit = GetTickCount() - p4q;  p4q = GetTickCount();
        InitializeHTFCandles();    // HTF candle engine
        g_pInitMsHTF = GetTickCount() - p4q;  p4q = GetTickCount();
        CreateMenu();              // orb + ring + tools
        g_pInitMsMenu = GetTickCount() - p4q;
        // P-PERF-106 (2026-10-16) — THE CROSS-RELOAD RESOLUTIONS RUN LAST.
        //
        // ResolveTopologyAdoption/ResolvePeriodChangeAttach must read every
        // fingerprint input FINAL: InitializeUIStates set the OV_ persist
        // prefix (BiotakMenu) and InitializeBiotakKit loaded the runtime
        // overrides (inpMaxLevels is `g_maxLevels` there) — so this is the
        // first point where the fingerprint the dying instance wrote and the
        // one computed here agree. Inside OnInitHandler they read the 144
        // seed against a stored 352: every attach printed a stamp mismatch
        // and the adoption fell back to a ~1 s whole-chart walk (measured
        // 2026-10-16, M5 ind=1344 ms). Both entries place them here.
        ResolveTopologyAdoption();
        ResolvePeriodChangeAttach();
        // MT5-ONLY (R-RENDER-ENGINE): arm the canvas layers (created on the
        // first pump if the chart window is not mapped yet).
#ifdef BIOTAK_RENDER_ENGINE
        RBridgeInit();
#endif
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
    CompatDeinitBegin();   // MT5-ONLY P-PERF-99: no event can be consumed after this
    uint p4d = GetTickCount();   // P-PERF-04: teardown budget (timeframe switch)
#ifdef BIOTAK_RENDER_ENGINE
    RBridgeShutdown();   // MT5-ONLY (R-RENDER-ENGINE): the canvas layers die with the instance
#endif
    // P-PERF-96 (BUG-13, 2026-10-13) — THE COMPAT LEDGER IS READ, NOT JUST WRITTEN.
    //
    // Every counter in MT5Compat/MQL5Compat.mqh (Period(), MarketInfo(), Bid/Ask,
    // the ATR rates sync engine (P-ATR-SYNC: memo hits/misses, engine calls),
    // iBarShift, the series full-copy vs in-memory
    // shift) was incremented and NEVER printed: the measurement existed and no
    // report read it, so "MT5 lags" could not be attributed to a call site.
    // One call here closes that loop for a MEASUREMENT build (uncomment
    // `#define COMPAT_LEDGER 1` in the shim). In a release build the shim's own
    // guard returns immediately and this line costs one call and prints nothing.
    CompatLedgerReport("OnDeinit reason=" + IntegerToString(reason));
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
    SnapshotOpenSurfaces();   // P-UI-142: record open panel/tools BEFORE the closes below clear them
    // P-PERF-116 (2026-10-17) — A TIMEFRAME SWITCH KEEPS WHAT A RELOAD CAN ADOPT (MT5-ONLY).
    //
    // MT5 does not delete chart objects when the chart's period changes (the
    // P-PERF-38b note in OnDeinitHandler and the orphan-purge note in
    // InitializeUIStates both ride that fact). The teardown until now deleted
    // the whole UI anyway and the init rebuilt it from scratch - the live log
    // priced it at ~450 ms per switch, htf=187 ms of it deleting the HTF
    // family the next instance was about to draw again.
    //
    // So on REASON_CHARTCHANGE the two families whose state is PERSISTED are
    // kept, not deleted:
    //   * the MENU - menuVisible / ToolsOpen / the homes all restore from GVs
    //     (LoadUIState), and CreateMenu re-asserts ring and orb in place
    //     through their own ObjectFind-guarded creators;
    //   * the HTF CANDLES - a pure function of persisted settings + history;
    //     the drawn COUNT crosses the reload as a one-shot handoff key so the
    //     first draw rewrites [0,count) in place and prunes the surplus.
    // What CANNOT survive stays deleted: the panels, the palette and the
    // strip reset their open-state with the instance - a kept panel would be
    // a dead surface (the orphan purge's own law) - so PnlCloseAll and
    // DrawStripClose still run in every direction.
    const bool p116keep = (reason == REASON_CHARTCHANGE);
    PnlCloseAll();
    p15Pnl = GetTickCount() - p15t; p15t = GetTickCount();
    // P-DRAW-08: the drawing strip's own objects die with the instance — the
    // removal path owns them, so no PnlDrawS_* button survives a REASON_REMOVE
    // (the name was `Biotak_DS_*` in the note that first said this; the objects
    // have been `PnlDrawS_*` since birth — P-DRAW-73, catalogue 24).
    DrawStripClose();
    if(!p116keep)
       DeleteMenu();          // P-PERF-116: kept on a switch - CreateMenu adopts it back
    p15Menu = GetTickCount() - p15t; p15t = GetTickCount();
    if(!p116keep)
       DeleteHTFCandles();    // P-PERF-116: kept on a switch - the first draw re-adopts and prunes
    else
       SaveHTFHandoffStamp(); // P-PERF-116: ...and the count crosses the reload with it
    p15Htf = GetTickCount() - p15t; p15t = GetTickCount();
    SaveBiotakKit();
    p15Save = GetTickCount() - p15t; p15t = GetTickCount();
    CleanupUIStates(reason);
    p15Cleanup = GetTickCount() - p15t; p15t = GetTickCount();
    // P-PERF-111 (2026-10-17): every UI family is swept by now (Pnl/Pal_/SW*,
    // Circ/Tools/Sub, the strip) - stamp it so the next instance's orphan
    // purge + ghost sweeps stand down (they never see this session's IDs from
    // an older session, so a restart still purges). One-shot, consumed in
    // InitializeUIStates; see UITearStampName in EventHandlers.
    StampCleanUITeardown();
    OnDeinitHandler(reason);
    // MT5-ONLY (P-PERF-117b): the teardown's last word — anything named here
    // survived every sweep above (a switch keeps its family by design and is
    // not a moment; only a real removal is).
    if(reason == REASON_REMOVE) P4LeftoverCensus("remove");
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
              "ms handler=", (int)p15Handler, "ms keep=", (p116keep ? 1 : 0), " | ovr w=", RSSaveWrites(), "/",
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

    // MT5-ONLY PLATFORM CALL: fill the global Time[]/Open[]/High[]/Low[]/Close[]
    // emulated series (index 0 = current bar) used by the shared modules.
    // NOTE: ArraySetAsSeries is NOT called on the OnCalculate parameter arrays.
    // The shared OnCalculateHandler was written for MQL4 convention where these
    // parameters are NOT timeseries: close[0]=oldest, close[rates_total-1]=current.
    // Reversing them would make close[rates_total-1] point to the OLDEST bar,
    // causing currentPrice/currentBarTime to read the wrong end of history.
    // The global CompatRefreshChartData arrays (Time[]/Close[] etc.) are correctly
    // filled as timeseries by CompatRefreshChartData and are what all shared code
    // reads - the parameter arrays are only used for the two index lookups in
    // OnCalculateHandler (currentPrice, currentBarTime). MT5-ONLY fix.
    // P-MT5-PERF: pass rates_total (free - already a parameter) so
    // CompatRefreshChartData skips the iBars() kernel call; pass the forming
    // bar's live values from the OnCalculate arrays (zero extra kernel
    // crossings) so the steady-state path skips three iHigh/iLow/iClose calls.
    // close/high/low[rates_total-1] is the CURRENT (newest) bar - same bar
    // index 0 in the emulated timeseries.
    // MT5-ONLY FIX (2026-10-13): time/open travel with them for the same
    // reason - the emulated series' new-bar shift must fill Time[0]/Open[0]
    // with the NEW bar's values, not keep the previous bar's.
    CompatRefreshChartData(
        rates_total,
        (rates_total > 0) ? close[rates_total - 1] : EMPTY_VALUE,
        (rates_total > 0) ? high[rates_total - 1]  : EMPTY_VALUE,
        (rates_total > 0) ? low[rates_total - 1]   : EMPTY_VALUE,
        (rates_total > 0) ? time[rates_total - 1]  : (datetime)0,
        (rates_total > 0) ? open[rates_total - 1]  : EMPTY_VALUE);
    int result = OnCalculateHandler(rates_total, prev_calculated, time, open, high, low, close, tick_volume, real_volume, spread);
    // --- UI kit: HTF forming-candle live update + new-bar redraw ---
    RefreshKitOnBar();
    return result;
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
// P-DIAG-166: the timer's worst body, defined beside OnTimer below — declared here
// because the average ledger inside OnChartEvent reads it (definition before use).
uint DiagUsTimerMax();
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
  // MT5-ONLY PLATFORM FILTER (2026-10-13): our own programmatic
  // ObjectCreate/ObjectDelete/ObjectsDeleteAll calls queue one chart event
  // EACH on MT5 - MT4 never sends them, and every heal, style-apply and
  // witness in the shared source is written against the MT4 meaning of
  // these two events. A tokened event is dropped here, before ANY handler
  // runs, exactly as if the terminal had not sent it. Full note:
  // MT5Compat\MQL5Compat.mqh, "THE PROGRAMMATIC OBJECT EVENT STORM".
  if((id == CHARTEVENT_OBJECT_CREATE || id == CHARTEVENT_OBJECT_DELETE) &&
     CompatConsumeObjEvent(id, sparam)) return;
  // MT5-ONLY P-MT5-ONECLICK (2026-10-23): ONE RELEASE, ONE CLICK — the same
  // shape as the filter above, one layer down. MT5 can report a single
  // button-up twice (the OBJECT click and then the CHART click, and in the
  // measured cases the OBJECT click itself twice), while every handler in the
  // shared source is written for MT4's single delivery. The second copy then
  // reads as a SECOND GESTURE: the strip toggles shut what it just opened and
  // its close path writes OBJPROP_SELECTED=false, a card switch flips twice
  // and looks dead, a click-to-plant tool plants two points. Dropped here,
  // before ANY handler runs. Full note: MT5Compat\MQL5Compat.mqh.
  // P-DRAW-148: ...and only when the object click was OURS (see ClickOwnedByUs).
  if(CompatOneClickDedupe(id, sparam, ClickOwnedByUs(sparam))) return;
  // BUG-15 (2026-10-13, resolved 2026-10-16) — NO LEAVE EVENT EXISTS ON EITHER
  // PLATFORM, SO THERE IS NOTHING TO FILTER HERE.
  //
  // The staged attempt watched CHARTEVENT_MOUSE_LEAVE, which is not an MQL4 or
  // MQL5 identifier (proven by compiling it: error 256). MQL5 documents that
  // mouse events simply STOP when the cursor leaves the chart's client area;
  // the exit is never reported under any id. If the terminal ever delivers a
  // displaced MOUSE_MOVE, the coordinates fall outside the chart rect — the
  // same shape MT4 reports — and the shared hover drivers already read that as
  // "no cell" (`PalHoverPreview`'s `if(reg < 0) PalHoverRestore()` and
  // `DrawStripColorHoverCellAt`'s -1), restoring exactly as MT4 does. Only a
  // GetCursorPos+timer (user32 import, needs "Allow DLL imports") could see a
  // no-button exit, and that price is not worth a hover rim. The shared
  // modules therefore stay pristine and the filter stays absent.
  // P-PERF-04: name the phase behind an interaction hitch (indicator half vs
  // menu/panel half). Logs only when the pair blows the 40 ms budget.
  // P-PERF-34: scope the frame deferral to this window. A forced frame inside
  // an event is SCHEDULED, never executed - see the EventHandlers note. Setting
  // the flag here (not in the handlers) is what makes the guarantee hold for
  // every path they call, including ones added later.
  g_inChartEvent = true;
  CompatFrameBegin();   // MT5-ONLY R-POINTER-FRAME: one frame per event, see MQL5Compat
  uint p4t = GetTickCount();
  //--- P-DIAG-162 (temporary): microseconds for the event the hand feels. The ms
  //--- ledger below cannot resolve anything under one 15.6 ms Windows tick, so a
  //--- 30 ms mouse move reads "indicator=0 ui=0" — the reason the lag has no owner
  //--- in the log. These four stamps bracket the same three calls and name them.
  uint p4u0 = CompatUsNow();
  OnChartEventHandler(id,lparam,dparam,sparam);
  uint p4u1 = CompatUsNow();
  uint p4a = GetTickCount() - p4t;
  p4t = GetTickCount();
  // P-UI-114: the strip opens on a LEFT hold inside DrawStripOnEvent below.
  // --- Circular menu / settings panels / palette ---
  HandleUIChartEvent(id,lparam,dparam,sparam);
  uint p4u2 = CompatUsNow();
  // P-DRAW-08: the drawing strip's own buttons and its dismiss clicks. Its own
  // owner, its own objects — it shares no state with the panels.
  //
  // MT5-ONLY P-PERF-58 (2026-10-23) — `strip=` IS ITS OWN FIELD, and the reason
  // is a measurement this ledger could not answer. A live drag's lag report is
  // answered by `ui=`, but `ui=` is THREE owners glued together (the ring/cards,
  // the strip, and the palette bridges below), so a 47 ms `ui=` names no one —
  // and the day's log carries MOUSE_MOVE events at 438..906 ms with `ui=` 875
  // while ring+panel+hold measured under 40 ms (P-PERF-15's own breakdown), i.e.
  // the heavy half was the strip or the bridges and the ledger could not say
  // which. One GetTickCount pair per event: the split names the owner on the
  // NEXT report instead of another round of guessing. `ui=` keeps its meaning
  // (the whole half) — this field is carved OUT of it, never added to it.
  uint p4sT = GetTickCount();
  DrawStripOnEvent(id,lparam,dparam,sparam);
  uint p4s = GetTickCount() - p4sT;
  uint p4u3 = CompatUsNow();
  // P-PAL-19 (2026-10-02) — THE ONE BRIDGE. DrawStrip is include 99 and the panels
  // are 124, and MQL4 needs a definition before its use, so the strip cannot call
  // `PalOpenDraw` itself: it leaves a REQUEST (DrawStripPalAsk) and this line — the
  // first place in the program that sees BOTH sides — performs the open. One
  // direction, one place, no forward declaration, and the strip has no knowledge of
  // the palette's existence beyond this handshake.
  int palAsk = DrawStripPalAsked();
  if(palAsk >= 0) PalOpenDraw(DrawStripPlateX(), DrawStripPlateY(), DrawStripPlateW());
  // P-ANCHOR-LAST-MOVE (2026-10-22) — the strip's SECOND one-way bridge, same shape as
  // the line above. The anchor seat changes an ATR that the label/level/plan pass reads,
  // and `RefreshDisplay` (BiotakKit, include 128) is unreachable from the strip (99).
  // The press leaves a request; this is the first place that sees both sides, so it
  // performs it. One press -> one full pass in the SAME event; a still frame leaves the
  // request empty and pays nothing. MT5's `UISyncDrain` at the tail of this handler is
  // not a substitute: it settles the ring light and the open card's switch bitmaps and
  // never runs that pass, so without this line LAST OBJECT flipped and nothing moved.
  int dsAsk = DrawStripRefreshTake();
  if(dsAsk > 0) RefreshDisplay(REFRESH_ALL);
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
  //--- P-DIAG-162 (temporary): ONE line per second at most, only when the move
  //--- costs more than a frame. `strip=` is carved out of `ui=` (P-PERF-58), and
  //--- `knot`/`ray`/`abcd`/`leg`/`hs`/`cp` are carved out of `indicator=`, so the
  //--- names below are disjoint and the biggest one is the owner.
  //--- P-DIAG-164 (2026-10-29): OBJECT_DRAG is in the gate too — a drag's own
  //--- event was the one channel this ledger could not see, and `rest=` is the
  //--- leftover nobody has named yet (it must read ~0 once every owner has a
  //--- stamp). `nm=` is the object the terminal named, so ours and the
  //--- terminal's own tools can be told apart in the same log.
  if(id == CHARTEVENT_MOUSE_MOVE || id == CHARTEVENT_OBJECT_DRAG)
  {
     uint _usTot = (uint)((p4u3 - p4u0) / 1000);
     if(_usTot >= 8)
     {
        static uint _usGate = 0;
        uint _usNow = GetTickCount();
        if(_usGate == 0 || _usNow - _usGate >= 1000)
        {
           _usGate = _usNow;
           int _usInd  = (int)((p4u1 - p4u0) / 1000);
           int _usOwn  = (int)((DiagUsKnot() + DiagUsRay() + DiagUsAbcd() +
                                DiagUsLeg() + DiagUsHs() + DiagUsCp()) / 1000);
           Print("[mvus] id=", id, " total=", (int)_usTot,
                 " ind=", _usInd,
                 " knot=", (int)(DiagUsKnot() / 1000),
                 " ray=", (int)(DiagUsRay() / 1000),
                 " abcd=", (int)(DiagUsAbcd() / 1000),
                 " leg=", (int)(DiagUsLeg() / 1000),
                 " hs=", (int)(DiagUsHs() / 1000),
                 " cp=", (int)(DiagUsCp() / 1000),
                 " rest=", (_usInd > _usOwn ? _usInd - _usOwn : 0),
                 " ui=", (int)((p4u2 - p4u1) / 1000),
                 " strip=", (int)((p4u3 - p4u2) / 1000),
                 " nm=\"", sparam, "\"");
        }
     }
  }
  //--- P-DIAG-165 (temporary): THE AVERAGE, NOT THE OUTLIER. The `[mvus]` gate above
  //--- prints ONE event per second, so it answers "how bad can a move be" but not "why
  //--- does the whole gesture feel slow": a gesture is 60-100 moves a second and what
  //--- the hand feels is the SUM, not the worst sample — a 10 ms move repeated a hundred
  //--- times hides behind a 40 ms outlier that prints every second. This block adds up
  //--- EVERY mouse move of the second and prints the per-move average of each owner:
  //--- the number that has to come down, and the one the sampled line cannot show.
  if(id == CHARTEVENT_MOUSE_MOVE)
  {
     static uint s_anN = 0, s_anTot = 0, s_anInd = 0, s_anRay = 0, s_anAbcd = 0;
     static uint s_anHs = 0, s_anKnot = 0, s_anLeg = 0, s_anCp = 0, s_anUi = 0, s_anStrip = 0;
     static uint s_anGate = 0;
     //--- P-DIAG-166: THE GAP IS THE HAND'S OWN MEASUREMENT. A move that costs 0 ms and
     //--- arrives 60 ms after the one before it was QUEUED, not computed — so the second
     //--- half of the answer is the interval between moves (`gmax`, the worst one this
     //--- second) and the timer body that held the thread (`tmr`, its worst run).
     static uint s_anPrevMs = 0, s_anGapMax = 0;
     uint _anNowMs = GetTickCount();
     if(s_anPrevMs != 0)
     {
        uint _g = _anNowMs - s_anPrevMs;
        if(_g > s_anGapMax) s_anGapMax = _g;
     }
     s_anPrevMs = _anNowMs;
     s_anN++;
     s_anTot   += (uint)((p4u3 - p4u0) / 1000);
     s_anInd   += (uint)((p4u1 - p4u0) / 1000);
     s_anRay   += DiagUsRay()  / 1000;
     s_anAbcd  += DiagUsAbcd() / 1000;
     s_anHs    += DiagUsHs()   / 1000;
     s_anKnot  += DiagUsKnot() / 1000;
     s_anLeg   += DiagUsLeg()  / 1000;
     s_anCp    += DiagUsCp()   / 1000;
     s_anUi    += (uint)((p4u2 - p4u1) / 1000);
     s_anStrip += (uint)((p4u3 - p4u2) / 1000);
     uint s_anNow = GetTickCount();
     if(s_anGate == 0) s_anGate = s_anNow;
     if(s_anNow - s_anGate >= 1000)
     {
        if(s_anN > 0)
           Print("[mvus-avg] n=", s_anN,
                 " tot=", (int)(s_anTot / s_anN),
                 " ind=", (int)(s_anInd / s_anN),
                 " ray=", (int)(s_anRay / s_anN),
                 " abcd=", (int)(s_anAbcd / s_anN),
                 " hs=", (int)(s_anHs / s_anN),
                 " knot=", (int)(s_anKnot / s_anN),
                 " leg=", (int)(s_anLeg / s_anN),
                 " cp=", (int)(s_anCp / s_anN),
                 " ui=", (int)(s_anUi / s_anN),
                 " strip=", (int)(s_anStrip / s_anN),
                 " gmax=", (int)s_anGapMax,
                 " tmr=", (int)(DiagUsTimerMax() / 1000));
        s_anGate = s_anNow; s_anN = 0; s_anTot = 0; s_anInd = 0; s_anRay = 0;
        s_anAbcd = 0; s_anHs = 0; s_anKnot = 0; s_anLeg = 0; s_anCp = 0;
        s_anUi = 0; s_anStrip = 0; s_anGapMax = 0;
     }
  }
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
#ifdef BIOTAK_RENDER_ENGINE
  // MT5-ONLY (R-RENDER-ENGINE): the repaint/mask channel — scroll, zoom and
  // resize re-map the canvas; KEYDOWN/OBJECT_CLICK carry the F/L hide and the
  // menu toggles so a hidden family masks in the same event, not a timer tick
  // later. frameKey-guarded, so an unchanged chart costs two chart reads.
  if(id == CHARTEVENT_CHART_CHANGE || id == CHARTEVENT_KEYDOWN || id == CHARTEVENT_OBJECT_CLICK)
     RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones);
#endif
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
  // MT5-ONLY R-POINTER-FRAME (2026-10-23) — THE ONE FRAME THIS EVENT OWES.
  // It is painted HERE, after the LAST writer of the event (both halves, the
  // pump, the render bridge and the UI drain), so what lands on screen is the
  // complete picture and every `ChartRedraw()` the handlers made was a flag in
  // `p4fr`, not a synchronous full-chart paint of a half-written frame. Its
  // cost lands in `panels=` (the same budget the drain is charged to — a frame
  // that hides its own cost would be the defect this ledger exists to catch).
  // Full law and the measurement behind it: MT5Compat\MQL5Compat.mqh.
  int p4fr = CompatFrameEnd();
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
               P4MsTag(p4a) + " ui=" + P4MsTag(p4b) + " strip=" + P4MsTag(p4s) + " settle=" + P4MsTag(p4c) +
               " panels=" + P4MsTag(p4e) + " frame=" + IntegerToString(p4fr) + "]",
               p4tot, P_P4_EVENT_WARN_MS);
}

//+------------------------------------------------------------------+
//| Timer function - periodic housekeeping                           |
//+------------------------------------------------------------------+
//--- P-DIAG-166 (temporary, remove with the lag fix): THE TIMER'S OWN PRICE. A mouse
//--- move costs under a millisecond and the hand still feels a stutter, so the question
//--- is no longer "what does a move cost" but "what holds the thread BETWEEN two moves".
//--- The 250 ms timer is the only other writer on this thread, so its worst body per
//--- second is the number that answers it. `[mvus-avg] tmr=` reads it and resets it.
//--- (Declared above OnChartEvent: the ledger reads it, and this compiler needs the
//--- definition before the use.)
static uint s_tmrMaxUs = 0;
uint DiagUsTimerMax() { uint v = s_tmrMaxUs; s_tmrMaxUs = 0; return v; }
void OnTimer()
{
    uint _tmA = CompatUsNow();

    // MT5-ONLY PLATFORM CALL - keep the emulated MQL4 series arrays live on a
    // chart that is not ticking (MQL4's arrays always were).
    CompatRefreshChartData();
    // MT5-ONLY COST LEDGER: a 60 s heartbeat, so the emulation's own price is
    // visible while the indicator runs instead of only at teardown. Gated by
    // COMPAT_LEDGER in MQL5Compat.mqh - undefined it and this compiles away.
#ifdef COMPAT_LEDGER
    static uint _clMs = 0;
    uint _clNow = GetTickCount();
    if(_clNow - _clMs >= 60000) { _clMs = _clNow; CompatLedgerReport("60s"); }
#endif
    // P-PERF-110c (2026-10-17): a TF-switch attach defers the legacy tool
    // restores (leg upgrade + TH3 pattern restore) to this first 250 ms frame,
    // so the ladder family paints at ~100 ms and the tools follow invisibly.
    TailRestoreDeferred();
    // P-UI-113-OFF (2026-09-23): no fast window — every tick is housekeeping.

    // P-TH3-REC-04 (2026-10-05): age out the recorder's one-second receipt. The
    // label is painted inside the M press and the DELETE is owed here, because
    // MT4 paints when the event handler returns — a Sleep in the press froze the
    // terminal for a second and showed nothing. One comparison per 250 ms, and
    // the first line of the function so a still chart settles the label.
    TH3RecorderFlashTick();

    // P-BK-124 (ported from MT4): age out the knot capture's one-second flash.
    // The press arms a label; the pump that ages the label out rides the TICKS,
    // so a market that stops ticking (a weekend, a dead symbol) kept the receipt
    // on the chart for ever. One int compare while no flash is armed.
    BaseKnotShotFlashTick();

    // P-PERF-16: the 250 ms safety refresh behind the cached UI metrics. Resizing
    // the chart also fires a chart-change event (which invalidates immediately);
    // this line covers a missed notification and costs two terminal reads per
    // quarter second instead of two per hit-test item.
    CircUIMetricsInvalidate();

    // P-UI-140: and the orb's and the chip's PLACES are re-derived from their
    // fractions on the same pass, so a window that comes back a different size
    // (a terminal restart is the report) puts both surfaces in the same relative
    // spot instead of clamping them somewhere else. Two compares when nothing
    // changed; the work runs only when the box really is a different box. The
    // CHART_CHANGE branch calls the same function first, so this line is the
    // safety net behind a missed notification — the exact shape of the line above.
    CircHomesRefresh();

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

#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): the net under the CHART_CHANGE channel —
    // family masks (L / hide-all) and any repaint a missed notification left
    // owed. Two chart reads when nothing moved.
    RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones);
#endif

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
    // else's fib or box («وقتی فیو یا باکس از همون محل می‌کشم کاستوم پرایس
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

    // P-TH3-LIVE-DRAG: the same net for a point drag — an off-chart release
    // leaves the latch and its view lock with nothing else to heal them.
    TH3LiveDragHeartbeat();

    // NOTE (2026-09-23, P-DRAW-18): `WindowPriceMax()/Min()` answer 0/0 during
    // OnInit - the chart window is not mapped yet (`run hi=0.00000 lo=0.00000` in
    // the terminal's log) - while a timer tick ~1 s later reads the real range
    // (`window hi=4410.70000 lo=4230.80000` on XAUUSD,H1). Anything needing the
    // visible window belongs HERE, never in OnInitHandler.
    { uint _tmD = CompatUsNow() - _tmA; if(_tmD > s_tmrMaxUs) s_tmrMaxUs = _tmD; }
}

