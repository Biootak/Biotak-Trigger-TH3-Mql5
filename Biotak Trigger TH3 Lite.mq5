// ========================================================================
// OWNED MT5 ENTRY - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak Trigger TH3 Lite.mq4
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
//|                                      Biotak Trigger TH3 Lite.mq4 |
//+------------------------------------------------------------------+
#property copyright "Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"
#property version   "3.12"
#property strict
#property indicator_chart_window
// MT5-ONLY PLATFORM PROPERTY: MQL5 warns when an indicator declares no plot;
// MQL4 never needed to say it. The indicator draws objects, not buffers.
#property indicator_plots 0

#property description "Biotak Trigger TH3 Lite v3.12 - Freeware, not for sale."
#property description "Light edition: core levels and hand drawings. By Biotak."

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
// LITE MODE ACTIVATION
//                                                                    
#define BUILD_LITE

//                                                                    
// BUILD CONFIG - Must be first include!
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

// Base / Knot Measurement Tool (Lite: no ring menu to arm it, but committed
// boxes keep their drag/delete/badge behavior via EventHandlers).
#include "Biotak\BaseKnotTool.mqh"
// P-HR-01: Horizontal Ray (Lite: nothing arms it, committed rays keep drag/snap/delete).
#include "Biotak\HRayTool.mqh"
// MT5-ONLY (P-PATH-CANVAS, 2026-10-29): the rubber band is canvas pixels, so
// PathTool needs the engine's declarations (see the Full entry's note).
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
// TH3TOOL-ON (2026-09-19): restored from TH3TOOL-OFF (Lite keeps its
// #ifndef BUILD_LITE guard, so this line compiles out here).
#include "Biotak\TH3Tool.mqh"
#endif

//                                                                    
// Drawing & Rendering Pipeline
//                                                                    
#include "Biotak\ObjectFunctions.mqh"
// P-DRAW-01/02: the user's own drawings and their style memory. Compiled in BOTH
// entries — the module owns no UI (the strip lives in the panels, which Lite does
// not have), so the style the user's drawings wear is the same in Lite as in Full
// (P-BUILD-01: a shared module that reached for a UI function would break here).
#include "Biotak\DrawToolbar.mqh"
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
    // MT5-ONLY (P-PERF-117b): BEFORE this instance creates one object, name what
    // the chart already carries (see the Full entry for the census' two moments).
    P4LeftoverCensus("oninit");
    // P-PERF-04: attach / timeframe-switch budget (silent unless it overruns).
    // P-PERF-10: Lite has no UI half, but it carries the same domain phases
    // (settings / history / base-price file load / ATR) in the report.
    uint p4i = GetTickCount();
    int result = OnInitHandler();
    // P-PERF-106 (2026-10-16) — THE CROSS-RELOAD RESOLUTIONS RUN LAST.
    // Same position as the Full entry (after every input is final — Lite has
    // no UI kit, so OnInitHandler is that point). See the Full entry for the
    // 144-vs-352 stamp mismatch they used to read from inside OnInitHandler.
    ResolveTopologyAdoption();
    ResolvePeriodChangeAttach();
    // MT5-ONLY (R-RENDER-ENGINE): arm the canvas layers (created on the
    // first pump if the chart window is not mapped yet).
#ifdef BIOTAK_RENDER_ENGINE
    RBridgeInit();
#endif
    uint p4ind = GetTickCount() - p4i;
    P4ReportSlow("OnInit (" + (result == INIT_SUCCEEDED ? "ok" : "fail") + ")" +
                 P4InitLedgerTag(p4ind, 0),
                 p4ind, P_P4_INIT_WARN_MS);
    return result;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CompatDeinitBegin();   // MT5-ONLY P-PERF-99: no event can be consumed after this
    uint p4d = GetTickCount();
#ifdef BIOTAK_RENDER_ENGINE
    RBridgeShutdown();   // MT5-ONLY (R-RENDER-ENGINE): the canvas layers die with the instance
#endif
    OnDeinitHandler(reason);
    // MT5-ONLY (P-PERF-117b): the teardown's last word — name the survivors.
    if(reason == REASON_REMOVE) P4LeftoverCensus("remove");
    // P-UI-142: Lite owns no surfaces, but it shares the GV table (boxes,
    // custom price, recorder) — save its overrides and flush, like the Full
    // teardown does. Shadow-guarded: zero writes when nothing moved; the flush
    // commits only what is owed.
    RuntimeSettingsSaveOverrides();
    GVFlushCommit();
    P4ReportSlow("OnDeinit reason=" + IntegerToString(reason),
                 GetTickCount() - p4d, P_P4_INIT_WARN_MS);
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
    return OnCalculateHandler(rates_total, prev_calculated, time, open, high, low, close, tick_volume, real_volume, spread);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
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
  // MT5-ONLY P-MT5-ONECLICK (2026-10-23): ONE RELEASE, ONE CLICK — see the full
  // note in "Biotak Trigger TH3.mq5". MT5 can deliver a single button-up twice;
  // the second copy reads as a second gesture in every shared handler.
  // P-DRAW-148: ...and only when the object click was OURS (see ClickOwnedByUs).
  if(CompatOneClickDedupe(id, sparam, ClickOwnedByUs(sparam))) return;
  // P-PERF-34: scope the frame deferral to this window (see EventHandlers).
  g_inChartEvent = true;
  CompatFrameBegin();   // MT5-ONLY R-POINTER-FRAME: one frame per event, see MQL5Compat
  // P-PERF-04: interaction budget (Lite has no menu/panel half to time).
  // P-PERF-59 (2026-10-23): `p4a` USED TO BE MEASURED BEFORE THE CALL — the two
  // GetTickCounts sat above the handler, so the field was always 0 and the line
  // did not even print it. A half that reads zero is worse than an unmeasured
  // one: the Full entry's own log is read as "the UI is the heavy half", and on
  // Lite (no UI at all) the same reading would have said the indicator was free.
  // The clock now brackets the call it names, and the field is printed.
  uint p4t = GetTickCount();
  OnChartEventHandler(id,lparam,dparam,sparam);
  uint p4a = GetTickCount() - p4t;
  g_inChartEvent = false;
  // P-PERF-40: a user action settles the frame it owes, in the SAME event — see
  // the full note in "Biotak Trigger TH3.mq4". An event that only SCHEDULED its
  // frame was answered up to a timer cadence later (measured `waited=46..266ms`)
  // by a repaint of the OLD picture (`body=0ms`), which is the lag the user
  // reports. The pump owns owed work and is budget-bounded, so this cannot become
  // an unbounded in-event stall.
  p4t = GetTickCount();
  CoopPump();
#ifdef BIOTAK_RENDER_ENGINE
  // MT5-ONLY (R-RENDER-ENGINE): the repaint/mask channel — scroll, zoom and
  // resize re-map the canvas; KEYDOWN/OBJECT_CLICK carry the F/L hide and the
  // menu toggles so a hidden family masks in the same event, not a timer tick
  // later. frameKey-guarded, so an unchanged chart costs two chart reads.
  if(id == CHARTEVENT_CHART_CHANGE || id == CHARTEVENT_KEYDOWN || id == CHARTEVENT_OBJECT_CLICK)
     RBridgePump(IsIndicatorHidden(), g_linesVisible, inpShowMidZones);
#endif
  // MT5-ONLY R-POINTER-FRAME: the one frame this event owes, painted after every
  // writer (see the full note in "Biotak Trigger TH3.mq5" and MQL5Compat). Its
  // cost is inside `settle=` — the field brackets the pump AND the frame.
  int p4fr = CompatFrameEnd();
  uint p4c = GetTickCount() - p4t;
  // P-PERF-26: name + id (see EventHandlers: id=1 is OBJECT_CLICK, not the cursor).
  // `settle=` is in the budget check on purpose — a drain must not hide its cost.
   // P-PERF-50: same gate as the Full entry — the ledger message is string
   // garbage on every MOUSE_MOVE while P4ReportSlow would stay silent under
   // budget. Total first, message only when it prints; identical log lines.
   uint p4tot = p4a + p4c;
   if(p4tot >= P_P4_EVENT_WARN_MS)
      P4ReportSlow("chart event " + P4EventName(id) + "(id=" + IntegerToString(id) + ")" +
                   " [indicator=" + P4MsTag(p4a) + " settle=" + P4MsTag(p4c) +
                   " frame=" + IntegerToString(p4fr) + "]",
                   p4tot, P_P4_EVENT_WARN_MS);
}

//+------------------------------------------------------------------+
//| Timer function - periodic housekeeping                           |
//+------------------------------------------------------------------+
void OnTimer()
{

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
    // P-PERF-110c: the TF-switch defer's no-op path in Lite (no tool family).
    TailRestoreDeferred();
    // FIX: If indicator is not yet fully initialized (e.g. waiting for history),
    // retry drawing periodically even without new ticks.
    // P-PERF-06: a staged post-wipe rebuild (attach / TF switch / topology
    // toggle) also advances here, so a tick-less chart still settles in ~1 s.
    // P-PERF-35: the coop pump owns the timer's heavy work (see EventHandlers):
    // the sweep jobs are owed once per timer - the cadence they had - and the
    // owed frame is drained last under one millisecond slice.
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

    // P-UI-100 (2026-09-22): the selection net of the two hand-set lines — the
    // custom price line and the step-1 pair exist in this entry too, so the law
    // and its net are compiled in both (P-BUILD-01: one rule, one spelling).
    // Cost: one probe while the button is down, then three guarded reads.
    HandLinesSelectionNet();
}

