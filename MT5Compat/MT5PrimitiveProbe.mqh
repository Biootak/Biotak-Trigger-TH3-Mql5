//+------------------------------------------------------------------+
//| MT5PrimitiveProbe.mqh - MT5-ONLY DIAGNOSTIC                       |
//|                                                                  |
//| WHY THIS EXISTS                                                  |
//|                                                                  |
//| The MT4 build feels smooth and the MT5 build does not, from ONE   |
//| shared source. The interaction ledger measures a hard floor of    |
//| ~31 ms on any press (button=31ms, panel=31ms, 62ms, ring=125ms)   |
//| and those numbers are suspiciously QUANTISED - a fixed tax, not   |
//| a growing one. A quantised cost is a terminal-call cost, and      |
//| MQL5's object / chart / global-variable APIs are not MQL4's.      |
//|                                                                  |
//| Rather than guess WHICH call carries the tax, this probe times    |
//| each primitive and each interaction composite on the LIVE         |
//| terminal, once, and prints a table. Then the fix is aimed.        |
//|                                                                  |
//| COST WHEN DISABLED: the whole file is #ifdef'd away. This file is |
//| in MT5Compat/, which is NOT junctioned into the MT4 tree, so the  |
//| MT4 build can never see it - zero parity risk by construction.    |
//+------------------------------------------------------------------+
#ifndef MT5_PRIMITIVE_PROBE_MQH
#define MT5_PRIMITIVE_PROBE_MQH

// Turn ON for a measurement build, OFF to ship. Nothing else changes.
//
// P-PERF-48 (2026-09-16) - SHIPPED OFF. The table this probe exists to produce
// HAS been produced (docs/CACHE-LIFECYCLE-PERF47_FA.md §1: ObjectFind(missing)
// 88.0 us, ObjectName 31.7 us, ChartGetInteger 33.5 us, ObjectSetInteger 0.245
// us ...) and it is now the yardstick every optimisation in that document is
// argued from. Its own header prices the run: it freezes the terminal for a few
// seconds ~1.5 s after every attach, on the user's live chart.
//
// Uncomment the line below ONLY for a measurement build.
//#define ENABLE_MT5_PRIMITIVE_PROBE

#ifdef ENABLE_MT5_PRIMITIVE_PROBE

static bool s_probeDone = false;

// One run per TERMINAL burst, not per chart instance: the latch lives in the
// terminal's global-variable table, which every instance shares, so the four
// charts that attach together produce ONE table instead of four. It expires
// after a minute, so re-attaching later (after a fix) re-measures.
#define PROBE_LATCH     "TH5PROBE_DONE"
#define PROBE_LATCH_MS  60000

#define PROBE_OBJ    "TH5PROBE_OBJ"
#define PROBE_BMPOBJ "TH5PROBE_BMPOBJ"
#define PROBE_BMP    "::Files\\Icons\\circ_off.bmp"

// Time one statement block N times and print the per-call cost.
// Usage:  PROBE_N(20000, "ObjectFind(existing)") { ObjectFind(0, PROBE_OBJ); }
#define PROBE_N(n, label)                                                   \
   {                                                                        \
      ulong _pt0 = GetMicrosecondCount();                                   \
      for(int _pi = 0; _pi < (n); _pi++)

#define PROBE_DONE(n, label)                                                \
      ulong _pt1 = GetMicrosecondCount();                                   \
      double _pus = (double)(_pt1 - _pt0) / (double)(n);                    \
      Print("[PROBE] ", label, " | n=", (int)(n),                           \
            " per-call=", DoubleToString(_pus, 3), "us  total=",            \
            DoubleToString((double)(_pt1 - _pt0) / 1000.0, 2), "ms");       \
   }

void MT5PrimitiveProbeRunOnce()
{
   if(s_probeDone) return;
   // Let the attach settle first: measuring while the chart is still building
   // would report the init churn, not the steady-state primitive cost.
   static uint s_probeArmedAt = 0;
   if(s_probeArmedAt == 0) { s_probeArmedAt = GetTickCount(); return; }
   if(GetTickCount() - s_probeArmedAt < 1500) return;
   s_probeDone = true;
   // Terminal-wide latch: whoever gets here first owns the measurement.
   if(GlobalVariableCheck(PROBE_LATCH))
   {
      double ranAt = GlobalVariableGet(PROBE_LATCH);
      double since = (double)GetTickCount() - ranAt;
      if(ranAt > 0.0 && since >= 0.0 && since < (double)PROBE_LATCH_MS) return;
   }
   GlobalVariableSet(PROBE_LATCH, (double)GetTickCount());

   Print("[PROBE] ===== MT5 primitive cost table (one-shot) =====");
   Print("[PROBE] DIAGNOSTIC ONLY - the chart will flicker for a few seconds, ",
         "then never again this session. Set ENABLE_MT5_PRIMITIVE_PROBE off to remove.");
   Print("[PROBE] symbol=", _Symbol, " period=", EnumToString(CompatRawPeriod()),
         " objects=", ObjectsTotal(0, -1, -1), " bars=", iBars(_Symbol, PERIOD_CURRENT));

   // ---- fixture: a label (property writes) and a bitmap label (BMPFILE
   //      decode - the ring's own skin type) ----
   ObjectDelete(0, PROBE_OBJ);
   ObjectCreate(0, PROBE_OBJ, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PROBE_OBJ, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, PROBE_OBJ, OBJPROP_YDISTANCE, 10);

   ObjectDelete(0, PROBE_BMPOBJ);
   ObjectCreate(0, PROBE_BMPOBJ, OBJ_BITMAP_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PROBE_BMPOBJ, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, PROBE_BMPOBJ, OBJPROP_YDISTANCE, 10);

   // Chart props are USER property: read them, write the SAME value back, and
   // restore at the end. A write of an unchanged value costs exactly the same.
   long fgWas = ChartGetInteger(0, CHART_FOREGROUND);
   long msWas = ChartGetInteger(0, CHART_MOUSE_SCROLL);
   long cmWas = ChartGetInteger(0, CHART_CONTEXT_MENU);

   // ---- object lookup ----
   PROBE_N(20000, "ObjectFind(existing)")
   { ObjectFind(0, PROBE_OBJ); }
   PROBE_DONE(20000, "ObjectFind(existing)")

   PROBE_N(20000, "ObjectFind(missing)")
   { ObjectFind(0, "TH5PROBE_NOPE"); }
   PROBE_DONE(20000, "ObjectFind(missing)")

   PROBE_N(5000, "ObjectGetInteger(TYPE)")
   { ObjectGetInteger(0, PROBE_OBJ, OBJPROP_TYPE); }
   PROBE_DONE(5000, "ObjectGetInteger(TYPE)")

   // ---- object property writes (the per-move / per-rebuild atom) ----
   PROBE_N(5000, "ObjectSetInteger(XDISTANCE)")
   { ObjectSetInteger(0, PROBE_OBJ, OBJPROP_XDISTANCE, 10); }
   PROBE_DONE(5000, "ObjectSetInteger(XDISTANCE)")

   PROBE_N(5000, "ObjectSetString(TEXT)")
   { ObjectSetString(0, PROBE_OBJ, OBJPROP_TEXT, "probe"); }
   PROBE_DONE(5000, "ObjectSetString(TEXT)")

   PROBE_N(500, "ObjectSetString(BMPFILE) [decode]")
   { ObjectSetString(0, PROBE_BMPOBJ, OBJPROP_BMPFILE, 0, PROBE_BMP); }
   PROBE_DONE(500, "ObjectSetString(BMPFILE) [decode]")

   // ---- object create/delete (what a menu rebuild is made of) ----
   PROBE_N(2000, "ObjectCreate+Delete")
   {
      ObjectCreate(0, "TH5PROBE_TMP", OBJ_LABEL, 0, 0, 0);
      ObjectDelete(0, "TH5PROBE_TMP");
   }
   PROBE_DONE(2000, "ObjectCreate+Delete")

   PROBE_N(2000, "ObjectCreate+6 props+Delete")
   {
      ObjectCreate(0, "TH5PROBE_TMP", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "TH5PROBE_TMP", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "TH5PROBE_TMP", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "TH5PROBE_TMP", OBJPROP_YDISTANCE, 10);
      ObjectSetString(0, "TH5PROBE_TMP", OBJPROP_TEXT, "x");
      ObjectSetInteger(0, "TH5PROBE_TMP", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "TH5PROBE_TMP", OBJPROP_SELECTABLE, false);
      ObjectDelete(0, "TH5PROBE_TMP");
   }
   PROBE_DONE(2000, "ObjectCreate+6 props+Delete")

   // ---- enumeration (O(n) in the live object list) ----
   PROBE_N(2000, "ObjectsTotal(0,-1,-1)")
   { ObjectsTotal(0, -1, -1); }
   PROBE_DONE(2000, "ObjectsTotal(0,-1,-1)")

   PROBE_N(5000, "ObjectName(0,0)")
   { ObjectName(0, 0); }
   PROBE_DONE(5000, "ObjectName(0,0)")

   // ---- chart reads / writes ----
   PROBE_N(20000, "ChartGetInteger(WIDTH)")
   { ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0); }
   PROBE_DONE(20000, "ChartGetInteger(WIDTH)")

   PROBE_N(2000, "ChartSetInteger(CONTEXT_MENU,false)")
   { ChartSetInteger(0, CHART_CONTEXT_MENU, false); }
   PROBE_DONE(2000, "ChartSetInteger(CONTEXT_MENU,false)")

   PROBE_N(2000, "ChartSetInteger(FOREGROUND)")
   { ChartSetInteger(0, CHART_FOREGROUND, true); }
   PROBE_DONE(2000, "ChartSetInteger(FOREGROUND)")

   PROBE_N(2000, "ChartSetInteger(MOUSE_SCROLL)")
   { ChartSetInteger(0, CHART_MOUSE_SCROLL, false); }
   PROBE_DONE(2000, "ChartSetInteger(MOUSE_SCROLL)")

   PROBE_N(1000, "ChartRedraw()")
   { ChartRedraw(); }
   PROBE_DONE(1000, "ChartRedraw()")

   // ---- global variables (settings persistence) ----
   PROBE_N(5000, "GlobalVariableSet")
   { GlobalVariableSet("TH5PROBE_GV", 1.0); }
   PROBE_DONE(5000, "GlobalVariableSet")

   PROBE_N(5000, "GlobalVariableGet")
   { GlobalVariableGet("TH5PROBE_GV"); }
   PROBE_DONE(5000, "GlobalVariableGet")

   PROBE_N(50, "GlobalVariablesFlush")
   { GlobalVariablesFlush(); }
   PROBE_DONE(50, "GlobalVariablesFlush")

   // ---- series access ----
   PROBE_N(20000, "iBars(current)")
   { iBars(_Symbol, PERIOD_CURRENT); }
   PROBE_DONE(20000, "iBars(current)")

   PROBE_N(20000, "iClose(current,0)")
   { iClose(_Symbol, PERIOD_CURRENT, 0); }
   PROBE_DONE(20000, "iClose(current,0)")

   PROBE_N(500, "CopyRates(100)")
   {
      MqlRates r[];
      CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, r);
   }
   PROBE_DONE(500, "CopyRates(100)")

   // ---- string / formatting ----
   PROBE_N(20000, "IntegerToString")
   { IntegerToString(12345); }
   PROBE_DONE(20000, "IntegerToString")

   PROBE_N(20000, "StringConcatenate(prefix+idx)")
   { string s = "BiotakMenuV2_" + IntegerToString(1) + "_CircIcon" + IntegerToString(3); }
   PROBE_DONE(20000, "StringConcatenate(prefix+idx)")

   // =================================================================
   // COMPOSITES - the things the interaction path actually calls
   // =================================================================
   Print("[PROBE] ----- interaction composites -----");

   PROBE_N(20000, "CircItemAt (full ring hit test)")
   { CircItemAt(120, 200); }
   PROBE_DONE(20000, "CircItemAt (full ring hit test)")

   PROBE_N(20000, "CircTipFeatAt (hover hit test)")
   { CircTipFeatAt(120, 200); }
   PROBE_DONE(20000, "CircTipFeatAt (hover hit test)")

   PROBE_N(100, "SaveUIStates()")
   { SaveUIStates(); }
   PROBE_DONE(100, "SaveUIStates()")

   PROBE_N(200, "CircLock+UnlockChart")
   { CircLockChart(); CircUnlockChart(); }
   PROBE_DONE(200, "CircLock+UnlockChart")

   PROBE_N(100, "CircApplyMenuPosition()")
   { CircApplyMenuPosition(); }
   PROBE_DONE(100, "CircApplyMenuPosition()")

   // The orb toggle: delete the whole menu and build it again. Kept to a few
   // repetitions because it is the only composite that is visible on screen.
   PROBE_N(4, "ToggleMenuVisibility x2 (delete+create)")
   { ToggleMenuVisibility(); ToggleMenuVisibility(); }
   PROBE_DONE(4, "ToggleMenuVisibility x2 (delete+create)")

   // Opening a settings card: the panel press the ledger reports as 31-62 ms.
   PROBE_N(2, "PnlOpen(6)+PnlCloseAll()")
   { PnlOpen(6); PnlCloseAll(); }
   PROBE_DONE(2, "PnlOpen(6)+PnlCloseAll()")

   // ---- cleanup ----
   ChartSetInteger(0, CHART_FOREGROUND,   fgWas != 0);
   ChartSetInteger(0, CHART_MOUSE_SCROLL, msWas != 0);
   ChartSetInteger(0, CHART_CONTEXT_MENU, cmWas != 0);
   ObjectDelete(0, PROBE_OBJ);
   ObjectDelete(0, PROBE_BMPOBJ);
   ObjectDelete(0, "TH5PROBE_TMP");
   GlobalVariableDel("TH5PROBE_GV");
   Print("[PROBE] ===== end of table =====");
   ChartRedraw();
}

#else

// Disabled: the probe compiles to nothing at all.
#define MT5PrimitiveProbeRunOnce()

#endif // ENABLE_MT5_PRIMITIVE_PROBE

#endif // MT5_PRIMITIVE_PROBE_MQH
