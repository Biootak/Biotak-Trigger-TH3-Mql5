//+------------------------------------------------------------------+
//|                                              Sessions_Draw.mqh   |
//|                    Copyright 2026, Biotak Project                |
//|                                                                  |
//|  P-SESS — THE SESSION RENDERER (chart objects only; no UI reads,  |
//|  no Pnl*/menu calls — compiles in BOTH entries, P-BUILD-01).      |
//|                                                                  |
//|  WHAT IT PAINTS, per enabled slot:                                |
//|    boxes + tag labels  for the last g_sessHistDays zone days      |
//|    H/L lines + price labels + range caption  on the live window   |
//|      (or the nearest completed one when today has not opened yet) |
//|    prior H/L as dotted levels carried across the live window      |
//|      (g_sessPrior, default off)                                   |
//|    ghost outlines for the next g_sessFutDays upcoming windows     |
//|    overlap rectangles  for today's intersecting windows           |
//|    one countdown text at the next boundary (engine, per instant)  |
//|                                                                  |
//|  CADENCE — the coop pump drives SessionsTick every 250 ms:        |
//|    * idle            : a hash compare, a day compare and one      |
//|                        high/low compare per live slot — no writes |
//|    * new day         : full wipe + repaint                        |
//|    * settings change : full wipe + repaint (hash)                 |
//|    * open/close flip : full wipe + repaint (+ alert, if enabled)  |
//|    * otherwise       : extend the live H/L in place               |
//|  P-SESS-13: idle also asks ONE more question — "is the family I   |
//|  built still on the chart?" — through a two-name witness pair, so |
//|  a foreign sweep repaints on the next tick instead of tomorrow.   |
//|  TIME-FRAME-FREE NAMES (date-keyed, no period in the name), so a  |
//|  TF switch keeps every box; REASON_REMOVE sweeps them with the    |
//|  instance (one inpObjectPrefix wipe, EventHandlers_Tail).         |
//|                                                                  |
//|  DEPENDENCIES (all precede this file): Sessions_Model,            |
//|  Runtime_A (g_sess*), GlobalVariables (IsIndicatorHidden),        |
//|  Util_A (ThrottledChartRedraw).                                   |
//+------------------------------------------------------------------+
#ifndef SESSIONS_DRAW_MQH
#define SESSIONS_DRAW_MQH

#include "Sessions_Model.mqh"

#define SESS_TAG         "SESS_"
#define SESS_FONT        "Arial"
#define SESS_PT_LBL      7     // box tags + ghosts
#define SESS_PT_PRICE    7     // H/L + range + countdown
#define SESS_FILL_ALPHA  86    // % of the fill ink given up to the background
#define SESS_PAST_ALPHA  45    // past windows: ink given up — the live box keeps it (P-SESS-06)
#define SESS_GHOST_ALPHA 62
#define SESS_PRIOR_ALPHA 55
#define SESS_MID_ALPHA   45
#define SESS_X_ALPHA     70
#define SESS_CD_COLOR    C'205,208,218'

//--- renderer state (this file's own; nothing outside reads it)
static bool     s_sessBuilt = false;
static long     s_sessHash = 0;
static int      s_sessDay = 0;
static bool     s_sessAlertSeeded = false;
static bool     s_sessWasOpen[SESS_SLOTS];

//--- per-slot live-window cache (the tick's extend path)
static bool     s_sessLiveValid[SESS_SLOTS];
static int      s_sessLiveStamp[SESS_SLOTS];
static datetime s_sessLiveS[SESS_SLOTS];
static datetime s_sessLiveE[SESS_SLOTS];
static datetime s_sessLiveBar[SESS_SLOTS];   // P-SESS-11: the bar the cached H/L was last synced on
static double   s_sessLiveHi[SESS_SLOTS];
static double   s_sessLiveLo[SESS_SLOTS];

//--- countdown cache (boundary recomputes at a rebuild; text at ~1 Hz)
static datetime s_sessCdNext = 0;
static int      s_sessCdSlot = -1;
static bool     s_sessCdIsOpen = false;
static string   s_sessCdText = "";
static uint     s_sessCdMs = 0;

//--- P-SESS-13: the two witnesses of the last paint. A and Z are the FIRST and
//--- the LAST object that paint declared — the oldest window's first edge and the
//--- tail (a ghost tag, the countdown). They bracket the family, so a sweep that
//--- eats its head or its tail is seen by ONE ObjectFind instead of a walk, and a
//--- family that was taken from under us repaints on the next tick instead of
//--- waiting for tomorrow. Cost when healthy: two kernel lookups per 250 ms tick.
static string   s_sessWitA = "";
static string   s_sessWitZ = "";
static uint     s_sessHealMs = 0;   // the self-heal's own budget (see SessionsTick)
static uint     s_sessEmptyMs = 0;  // P-SESS-14: the last paint that declared NOTHING

//--- P-SESS-15: the coverage of the last paint. A window is only drawn when its
//--- bars can be scanned, and a chart whose history is still downloading answers
//--- "no bars" for every window older than what it has - so a paint that lands
//--- during the sync declares only the newest windows and then looks healthy
//--- (witnesses exist), and nothing repaints it until the day turns.
//--- `CoverFrom` is the earliest window that paint WANTED, `BarFloor` the oldest
//--- bar it actually had: when the floor later recedes past CoverFrom, the tick
//--- repaints ONCE (and only once: a floor that stops moving buys no repaint).
static datetime s_sessCoverFrom = 0;
static datetime s_sessBarFloor = 0;
static uint     s_sessCovMs = 0;    // the coverage repair's own budget

//+------------------------------------------------------------------+
//| Names + primitives                                                |
//+------------------------------------------------------------------+
string SessWindowName(const int slot, const int stamp, const string tail)
{
   return inpObjectPrefix + SESS_TAG + IntegerToString(slot) + "_" + IntegerToString(stamp) + "_" + tail;
}

color SessBlend(const color base, const int alphaPct)
{
   int a = (int)MathMax(0, MathMin(100, alphaPct));
   if(a <= 0) return base;
   color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   int fr = ((int)base) & 0xFF, fg = (((int)base) >> 8) & 0xFF, fb = (((int)base) >> 16) & 0xFF;
   int br = ((int)bg) & 0xFF, bgg = (((int)bg) >> 8) & 0xFF, bb = (((int)bg) >> 16) & 0xFF;
   int r = (fr * (100 - a) + br * a) / 100;
   int g = (fg * (100 - a) + bgg * a) / 100;
   int b = (fb * (100 - a) + bb * a) / 100;
   return (color)(r | (g << 8) | (b << 16));
}

//+------------------------------------------------------------------+
//| P-SESS-13 — THE WITNESS PAIR.                                     |
//|                                                                  |
//| Every primitive below reports the name it just declared. The      |
//| FIRST name of a paint and the LAST one bracket the whole family:  |
//| the first is the oldest window's first edge (windows are declared |
//| oldest..newest), the last is the tail (a ghost tag or the          |
//| countdown). Two ObjectFind calls per idle tick therefore answer   |
//| "is the family still on the chart?" without walking it — and a    |
//| family that a foreign sweep deleted repaints on the next tick     |
//| instead of waiting for the day to turn.                           |
//+------------------------------------------------------------------+
void SessWitness(const string nm)
{
   if(s_sessWitA == "") s_sessWitA = nm;
   s_sessWitZ = nm;
}

//+------------------------------------------------------------------+
//| ONE box door, TWO build-proof bodies (P-SESS-05).                 |
//| A rectangle cannot be trusted to stay hollow: some MT4 builds     |
//| paint it filled whatever FILL says — ZoneFactory.mqh:143 already  |
//| pays this exact law (EMPTY boxes there are four border segments), |
//| and MEASURED on the reporting chart every session box shipped as  |
//| a solid saturated slab for it. So HOLLOW here is four border      |
//| SEGMENTS — guaranteed hollow on every build — and only the        |
//| FILLED style is a real rectangle, with its fill CLAIMED (FILL     |
//| written true, an explicit BGCOLOR), never assumed.                |
//+------------------------------------------------------------------+
void SessEdge(const string nm, const datetime t1, const double p1, const datetime t2, const double p2,
              const color clr, const int width, const ENUM_LINE_STYLE style, const string tip)
{
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, nm, OBJPROP_RAY, false);
   ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);   // the body sits behind the candles
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, tip);
   ObjectMove(0, nm, 0, t1, p1);
   ObjectMove(0, nm, 1, t2, p2);
   SessWitness(nm);   // P-SESS-13
}

void SessRect(const string nm, const datetime t1, const double p1, const datetime t2, const double p2,
              const color borderC, const color fillC, const int width, const ENUM_LINE_STYLE style,
              const string tip)
{
   if(fillC == clrNONE)
   {
      SessEdge(nm + "ET", t1, p1, t2, p1, borderC, width, style, tip);
      SessEdge(nm + "EB", t1, p2, t2, p2, borderC, width, style, tip);
      SessEdge(nm + "EL", t1, p1, t1, p2, borderC, width, style, tip);
      SessEdge(nm + "ER", t2, p1, t2, p2, borderC, width, style, tip);
      return;
   }
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, borderC);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, fillC);
   ObjectSetInteger(0, nm, OBJPROP_FILL, true);   // a fill is written, never assumed
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, tip);
   ObjectMove(0, nm, 0, t1, p1);
   ObjectMove(0, nm, 1, t2, p2);
   SessWitness(nm);   // P-SESS-13
}

void SessLine(const string nm, const datetime t1, const double p1, const datetime t2, const double p2,
              const color clr, const int width, const ENUM_LINE_STYLE style, const string tip)
{
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, nm, OBJPROP_RAY, false);
   ObjectSetInteger(0, nm, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, nm, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, style);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, tip);
   ObjectMove(0, nm, 0, t1, p1);
   ObjectMove(0, nm, 1, t2, p2);
   SessWitness(nm);   // P-SESS-13
}

void SessText(const string nm, const datetime t, const double p, const string txt,
              const color clr, const int pt, const ENUM_ANCHOR_POINT anchor, const string tip)
{
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, nm, OBJPROP_TEXT, txt);
   ObjectSetString(0, nm, OBJPROP_FONT, SESS_FONT);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, pt);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, tip);
   ObjectMove(0, nm, 0, t, p);
   SessWitness(nm);   // P-SESS-13
}

//+------------------------------------------------------------------+
//| Bar-scan high/low of one UTC span (skips windows with no bars —   |
//| a holiday or beyond-history window degrades to NO object, never   |
//| to a fake one).                                                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| P-SESS-16 (2026-10-29): the deepest bar this chart can actually   |
//| READ.                                                             |
//|                                                                  |
//| MT5's iTime() answers 0 for a slot whose timeseries has not been   |
//| built yet - even while iBars() still counts the bar. That is the   |
//| state of the first paints after an attach or a terminal restart,   |
//| while the oldest end is still syncing, and asking ONLY slot       |
//| `bars-1` turned it into "there is no history at all": every window |
//| failed its scan, the paint declared just the live box, and the     |
//| family looked healthy (a witness existed) so nothing repainted it. |
//| The measured signature is in the log:                          |
//|   [SESS] paint bars=100005 floor=1970.01.01 00:00 priced=1          |
//|                                                                  |
//| So probe upward for a slot that HAS a stamp, in growing steps      |
//| (8,16,32,...) - bounded at 20 reads and paid ONLY on that cold     |
//| path. The answer is deliberately conservative: it is the first     |
//| readable slot, never deeper than what the scan can prove, so a     |
//| window older than it is still skipped instead of being priced      |
//| from its tail bars and drawn short.                               |
//+------------------------------------------------------------------+
datetime SessHistFloor()
{
   int bars = iBars(NULL, 0);
   if(bars <= 0) return 0;
   datetime f = iTime(NULL, 0, bars - 1);
   if(f > 0) return f;
   int idx = bars - 1;
   int step = 8;
   for(int p = 0; p < 20 && idx > 0; p++)
   {
      idx -= step;
      if(idx < 0) idx = 0;
      f = iTime(NULL, 0, idx);
      if(f > 0) return f;
      step *= 2;
   }
   return 0;
}

bool SessHiLoFor(datetime t1, const datetime t2, double &hi, double &lo)
{
   hi = 0.0; lo = 0.0;
   if(t2 <= t1) return false;
   int bars = iBars(NULL, 0);
   if(bars <= 0) return false;
   datetime oldestT = SessHistFloor();   // P-SESS-16: the deepest READABLE bar
   if(oldestT <= 0) return false;
   if(t2 <= oldestT) return false;
   datetime from = (t1 < oldestT) ? oldestT : t1;
   int i1 = iBarShift(NULL, 0, from, false);
   int i2 = iBarShift(NULL, 0, t2 - 1, false);
   if(i1 < 0 || i2 < 0) return false;
   if(i1 > bars - 1) i1 = bars - 1;
   if(i2 > i1) i2 = i1;
   int count = i1 - i2 + 1;
   if(count < 1) return false;
   int iH = iHighest(NULL, 0, MODE_HIGH, count, i2);
   int iL = iLowest(NULL, 0, MODE_LOW, count, i2);
   if(iH < 0 || iL < 0) return false;
   hi = iHigh(NULL, 0, iH);
   lo = iLow(NULL, 0, iL);
   return (hi > 0.0 && lo > 0.0);
}

//+------------------------------------------------------------------+
//| The one purge: every SESS_ object of this instance. Called at the |
//| top of every repaint (stale objects cannot survive a settings or  |
//| day change) and when master/hide turns it off.                    |
//+------------------------------------------------------------------+
void SessWipe()
{
   if(StringLen(inpObjectPrefix) == 0) return;
   ObjectsDeleteAll(0, inpObjectPrefix + SESS_TAG, -1, -1);
}

//--- rebuild trigger: settings, slots, master, hide (TF is NOT here:
//--- a timeframe switch must never repaint the family)
//
// P-SESS-14 (2026-10-29) — `Period()` WAS here, and that one term is why a
// timeframe switch wiped the family. The names are date-keyed and a window's
// prices come from a bar scan, so a switch changes nothing the paint draws —
// but the hash differed, SessPaintAll ran, and its first act is SessWipe(). The
// repaint then reads the NEW timeframe's history, which is still syncing on the
// tick the switch lands: every `SessHiLoFor` fails, the paint declares nothing,
// and the tick still marked itself built - so the family stayed empty (no
// witnesses, no heal, no rebuild) until the day turned. That is the user's
// «تایم عوض میکنم دیگه رسم نمیشه»: the wipe was certain, the repaint was not.
// A switch must leave the family exactly where it is (P-PERF-38b's rule for the
// level family, and this file's own header).
long SessViewHash()
{
   long h = 1181783497276652981;
   h = h * 31 + (g_sessMaster ? 1 : 0);
   h = h * 31 + (IsIndicatorHidden() ? 1 : 0);
   h = h * 31 + (long)g_sessHistDays;
   h = h * 31 + (long)g_sessFutDays;
   h = h * 31 + (g_sessHlLines ? 1 : 0);
   h = h * 31 + (g_sessHlLabels ? 1 : 0);
   h = h * 31 + (g_sessRangeText ? 1 : 0);
   h = h * 31 + (g_sessPrior ? 1 : 0);
   h = h * 31 + (g_sessOverlap ? 1 : 0);
   h = h * 31 + (g_sessCountdown ? 1 : 0);
   h = h * 31 + (g_sessAlerts ? 1 : 0);
   for(int i = 0; i < SESS_SLOTS; i++)
      h = h * 31 + (long)g_sessSlot[i];
   return h;
}

//+------------------------------------------------------------------+
//| THE FULL PAINT — wipe, then declare every window the settings     |
//| admit. Windows are ordered by kk (oldest .. newest), so the       |
//| started block is a prefix and the ghosts are its tail.            |
//+------------------------------------------------------------------+
//--- P-UI-172 (2026-10-20): an OBJ_TEXT is anchored at the PIXEL of its time, so
//--- a time in the FUTURE has no pixel inside the chart area: the live session's
//--- H/L labels, its range caption and the countdown were anchored at the window's
//--- END (in the future while the session runs) and simply never appeared - the
//--- switches looked dead exactly when the session was live. ONE owner for the
//--- anchor: the window's end, clipped to NOW.
datetime SessLabelAnchor(const datetime endT, const datetime now)
{
   if(endT > now) return now;
   return endT;
}

void SessPaintAll(const datetime now, const int bkr)
{
   SessWipe();
   s_sessWitA = "";   // P-SESS-13: the witnesses belong to THIS paint
   s_sessWitZ = "";
   //--- P-SESS-15: what this paint asks for, and what history answered with
   s_sessCoverFrom = 0;
   s_sessBarFloor = SessHistFloor();   // P-SESS-16: readable depth, not slot bars-1
   s_sessCdNext = 0;
   s_sessCdSlot = -1;
   s_sessCdIsOpen = false;
   s_sessCdText = "";
   s_sessCdMs = 0;
   for(int z = 0; z < SESS_SLOTS; z++)
   {
      s_sessLiveValid[z] = false;
      s_sessLiveBar[z] = 0;
   }
   datetime noon = SessServerNoon();
   SessWindow wins[];
   ArrayResize(wins, 96);
   int n = 0;

   //--- today's windows across slots (for the overlap pass); static = the
   //--- compiler's own zero-init, and the loop below re-arms every entry each
   //--- paint (locals here would draw warning 60 on every guarded read)
   static bool     ovOk[SESS_SLOTS];
   static datetime ovS0[SESS_SLOTS], ovE0[SESS_SLOTS];
   static double   ovHi[SESS_SLOTS], ovLo[SESS_SLOTS];
   static color    ovColor[SESS_SLOTS];
   static bool     bandSet[SESS_SLOTS];
   static double   bandHi[SESS_SLOTS], bandLo[SESS_SLOTS];
   for(int z0 = 0; z0 < SESS_SLOTS; z0++)
   { ovOk[z0] = false; bandSet[z0] = false; bandHi[z0] = 0; bandLo[z0] = 0; ovColor[z0] = clrNONE; }

   for(int sl = 0; sl < SESS_SLOTS; sl++)
   {
      SessSlot s;
      SessSlotGet(sl, s);
      if(!s.enabled) continue;
      color base = SessColorOf(s.col);
      int n0 = n;
      SessCollectSlot(sl, s, -g_sessHistDays, g_sessFutDays, noon, bkr, wins, n);

      //--- price scan (past: full window · live: up to now)
      for(int w = n0; w < n; w++)
      {
         //--- P-SESS-15: EVERY window this paint wants, priced or not, counts
         //--- toward the coverage probe - the ones that failed are exactly the
         //--- ones a warmer chart could draw.
         if(s_sessCoverFrom == 0 || wins[w].sU < s_sessCoverFrom) s_sessCoverFrom = wins[w].sU;
         datetime rEnd = (wins[w].eU <= now) ? wins[w].eU : now;
         if(rEnd <= wins[w].sU) continue;
         wins[w].hasPrice = SessHiLoFor(wins[w].sU, rEnd, wins[w].hi, wins[w].lo);
      }
      //--- a just-opened window on a bar-less stretch degrades to bar 0
      for(int w = n0; w < n; w++)
      {
         if(wins[w].hasPrice) continue;
         if(SessWindowState(wins[w], now) != SESS_WS_LIVE) continue;
         double h0 = iHigh(NULL, 0, 0), l0 = iLow(NULL, 0, 0);
         if(h0 > 0.0 && l0 > 0.0)
         {
            wins[w].hi = h0; wins[w].lo = l0; wins[w].hasPrice = true;
         }
      }

      int sCnt = 0;   // started prefix
      while(n0 + sCnt < n && wins[n0 + sCnt].sU <= now) sCnt++;

      //--- boxes + tags (started windows), recording the nearest band
      for(int w = n0; w < n0 + sCnt; w++)
      {
         if(!wins[w].hasPrice) continue;
         bandSet[sl] = true; bandHi[sl] = wins[w].hi; bandLo[sl] = wins[w].lo;
         string tip = SessWindowTip(s, wins[w].sU, wins[w].hi, wins[w].lo, true);
         string nmB = SessWindowName(sl, wins[w].stamp, "B");
         bool wLive = (SessWindowState(wins[w], now) == SESS_WS_LIVE);   // P-SESS-06
         color ink = wLive ? base : SessBlend(base, SESS_PAST_ALPHA);    // live keeps the ink, past fades
         int bW = wLive ? 2 : 1;                                         // the live box is bold
         color fillC = (s.style == SESS_STYLE_FILLED) ? SessBlend(base, SESS_FILL_ALPHA) : clrNONE;
         SessRect(nmB, wins[w].sU, wins[w].hi, wins[w].eU, wins[w].lo, ink, fillC, bW, STYLE_SOLID, tip);
         SessText(nmB + "L", wins[w].sU, wins[w].hi, SessZoneTag(s.zone), ink, SESS_PT_LBL,
                  ANCHOR_LEFT_UPPER, tip);
         if(s.style == SESS_STYLE_MID && SessWindowState(wins[w], now) == SESS_WS_LIVE)
         {
            double mid = (wins[w].hi + wins[w].lo) / 2.0;
            SessLine(nmB + "M", wins[w].sU, mid, wins[w].eU, mid, SessBlend(base, SESS_MID_ALPHA),
                     1, STYLE_DOT, tip + " · mid");
         }
         if(SessWindowState(wins[w], now) == SESS_WS_LIVE)
         {
            ovOk[sl] = true;
            ovS0[sl] = wins[w].sU; ovE0[sl] = wins[w].eU;
            ovHi[sl] = wins[w].hi; ovLo[sl] = wins[w].lo;
            ovColor[sl] = base;
         }
      }

      //--- the live (or nearest completed) window owns lines/labels/range
      int wLin = -1;
      for(int w = n0 + sCnt - 1; w >= n0; w--)
      {
         if(wins[w].hasPrice) { wLin = w; break; }
      }
      if(wLin >= 0)
      {
         bool wLinLive = (SessWindowState(wins[wLin], now) == SESS_WS_LIVE);   // P-SESS-06
         //--- the live cache belongs to the WINDOW, not to the H/L lines:
         //--- the box extends per tick even when the lines are off
         if(wLinLive)
         {
            s_sessLiveValid[sl] = true;
            s_sessLiveStamp[sl] = wins[wLin].stamp;
            s_sessLiveS[sl] = wins[wLin].sU;
            s_sessLiveE[sl] = wins[wLin].eU;
            s_sessLiveHi[sl] = wins[wLin].hi;
            s_sessLiveLo[sl] = wins[wLin].lo;
            s_sessLiveBar[sl] = iTime(NULL, 0, 0);   // P-SESS-11
         }
         string tipL = SessWindowTip(s, wins[wLin].sU, wins[wLin].hi, wins[wLin].lo, true);
         if(g_sessHlLines)
         {
            int lw = wLinLive ? 2 : 1;   // P-SESS-06: the live window's H/L is bold with its box
            string nmHI = SessWindowName(sl, wins[wLin].stamp, "HI");
            SessLine(nmHI,      wins[wLin].sU, wins[wLin].hi, wins[wLin].eU, wins[wLin].hi, base, lw, STYLE_SOLID, tipL);
            SessLine(SessWindowName(sl, wins[wLin].stamp, "LO"),
                     wins[wLin].sU, wins[wLin].lo, wins[wLin].eU, wins[wLin].lo, base, lw, STYLE_SOLID, tipL);
         }
         if(g_sessHlLabels)
         {
            SessText(SessWindowName(sl, wins[wLin].stamp, "HIL"), SessLabelAnchor(wins[wLin].eU, now), wins[wLin].hi,
                     DoubleToString(wins[wLin].hi, _Digits), base, SESS_PT_PRICE, ANCHOR_RIGHT_LOWER, tipL);
            SessText(SessWindowName(sl, wins[wLin].stamp, "LOL"), SessLabelAnchor(wins[wLin].eU, now), wins[wLin].lo,
                     DoubleToString(wins[wLin].lo, _Digits), base, SESS_PT_PRICE, ANCHOR_RIGHT_UPPER, tipL);
         }
         if(g_sessRangeText)
            SessText(SessWindowName(sl, wins[wLin].stamp, "R"), SessLabelAnchor(wins[wLin].eU, now), wins[wLin].lo,
                     IntegerToString(SessPipsIn(wins[wLin].hi, wins[wLin].lo)) + "p",
                     SessBlend(base, SESS_MID_ALPHA), SESS_PT_PRICE, ANCHOR_RIGHT_LOWER,
                     "range of the session · pips");
         //--- prior H/L carried across this window (g_sessPrior)
         if(g_sessPrior && wLin > n0)
         {
            for(int w = wLin - 1; w >= n0; w--)
            {
               if(!wins[w].hasPrice) continue;
               string nmP = SessWindowName(sl, wins[wLin].stamp, "PHI");
               SessLine(nmP, wins[wLin].sU, wins[w].hi, wins[wLin].eU, wins[w].hi,
                        SessBlend(base, SESS_PRIOR_ALPHA), 1, STYLE_DOT, tipL + " · prior high");
               SessLine(SessWindowName(sl, wins[wLin].stamp, "PLO"),
                        wins[wLin].sU, wins[w].lo, wins[wLin].eU, wins[w].lo,
                        SessBlend(base, SESS_PRIOR_ALPHA), 1, STYLE_DOT, tipL + " · prior low");
               break;
            }
         }
      }

      //--- ghosts: the next unstarted windows (nearest first), wearing
      //--- the nearest known band — the honest answer to "where will it sit"
      int gN = (int)MathMin(n - (n0 + sCnt), g_sessFutDays);
      for(int gi = 0; gi < gN; gi++)
      {
         int w = n0 + sCnt + gi;
         if(!bandSet[sl]) break;
         string nmF = SessWindowName(sl, wins[w].stamp, "F");
         string tipF = SessZoneLabel(s.zone) + " " + SessHhMmFromMin(s.startMin) + "-"
                     + SessHhMmFromMin(s.endMin) + " · upcoming";
         SessRect(nmF, wins[w].sU, bandHi[sl], wins[w].eU, bandLo[sl],
                  SessBlend(base, SESS_GHOST_ALPHA), clrNONE, 1, STYLE_DOT, tipF);
         SessText(nmF + "T", wins[w].sU, bandHi[sl],
                  SessZoneTag(s.zone) + " " + SessHhMmFromMin(s.startMin),
                  SessBlend(base, SESS_GHOST_ALPHA), SESS_PT_LBL, ANCHOR_LEFT_UPPER, tipF);
      }

      //--- countdown candidate: the nearest boundary of this slot
      if(g_sessCountdown)
      {
         bool isOpen = false;
         datetime b = SessSlotNextBoundary(s, now, bkr, isOpen);
         if(b > 0 && (s_sessCdNext == 0 || b < s_sessCdNext))
         {
            s_sessCdNext = b;
            s_sessCdSlot = sl;
            s_sessCdIsOpen = isOpen;
         }
      }
   }

   //--- overlaps of today's live windows (pairwise)
   if(g_sessOverlap)
   {
      for(int a = 0; a < SESS_SLOTS; a++)
      {
         if(!ovOk[a]) continue;
         for(int b = a + 1; b < SESS_SLOTS; b++)
         {
            if(!ovOk[b]) continue;
            datetime t1 = (ovS0[a] > ovS0[b]) ? ovS0[a] : ovS0[b];
            datetime t2 = (ovE0[a] < ovE0[b]) ? ovE0[a] : ovE0[b];
            if(t2 <= t1) continue;
            double hi = MathMin(ovHi[a], ovHi[b]);
            double lo = MathMax(ovLo[a], ovLo[b]);
            if(hi <= lo) continue;
            string nmX = inpObjectPrefix + SESS_TAG + "X_" + IntegerToString(a) + "_" + IntegerToString(b);
            SessRect(nmX, t1, hi, t2, lo, SessBlend(ovColor[a], SESS_X_ALPHA), clrNONE,
                     1, STYLE_DOT, "overlap");
         }
      }
   }

   //--- the countdown object
   if(g_sessCountdown && s_sessCdNext > 0 && s_sessCdSlot >= 0)
   {
      SessSlot cs;
      SessSlotGet(s_sessCdSlot, cs);
      double cdP = 0.0;
      if(bandSet[s_sessCdSlot]) cdP = (bandHi[s_sessCdSlot] + bandLo[s_sessCdSlot]) / 2.0;
      else
      {
         double fh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, (int)MathMin(120, iBars(NULL, 0)), 0));
         if(fh > 0.0) cdP = fh * 0.995;
      }
      string nmC = inpObjectPrefix + SESS_TAG + "CDN";
      string nmU = SessZoneLabel(cs.zone);
      StringToUpper(nmU);
      s_sessCdText = nmU + (s_sessCdIsOpen ? " close " : " open ") + SessFmtDur((int)(s_sessCdNext - now));
      if(cdP > 0.0)
         SessText(nmC, SessLabelAnchor(s_sessCdNext, now), cdP, s_sessCdText, SESS_CD_COLOR, SESS_PT_PRICE,
                  ANCHOR_LEFT_LOWER, "next session boundary");
   }

   //--- P-SESS-15 diagnostic (one line per paint: a paint is an event, not a tick)
   int nPriced = 0;
   for(int wp = 0; wp < n; wp++) if(wins[wp].hasPrice) nPriced++;
   PrintFormat("[SESS] paint bars=%d floor=%s wantFrom=%s windows=%d priced=%d witA=%s",
               iBars(NULL, 0),
               TimeToString(s_sessBarFloor, TIME_DATE | TIME_MINUTES),
               TimeToString(s_sessCoverFrom, TIME_DATE | TIME_MINUTES),
               n, nPriced, s_sessWitA);
}

//+------------------------------------------------------------------+
//| The live extend: one compare per live slot; writes only when the  |
//| session really printed a new extreme.                             |
//+------------------------------------------------------------------+
void SessLiveRepaint(const int sl)
{
   SessSlot s;
   SessSlotGet(sl, s);
   //--- P-BE-07 (ported 2026-10-22): `base` was computed here and read nowhere —
   //--- the body follows `s.col` through the per-style ink below.
   string nmB = SessWindowName(sl, s_sessLiveStamp[sl], "B");
   //--- the body follows its OWN kind (P-SESS-05): 2 moves for the filled
   //--- rectangle, 8 for the hollow four-edge frame — and only when the
   //--- session really printed a new extreme (the caller's compare)
   if(s.style == SESS_STYLE_FILLED)
   {
      ObjectMove(0, nmB, 0, s_sessLiveS[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmB, 1, s_sessLiveE[sl], s_sessLiveLo[sl]);
   }
   else
   {
      ObjectMove(0, nmB + "ET", 0, s_sessLiveS[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmB + "ET", 1, s_sessLiveE[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmB + "EB", 0, s_sessLiveS[sl], s_sessLiveLo[sl]);
      ObjectMove(0, nmB + "EB", 1, s_sessLiveE[sl], s_sessLiveLo[sl]);
      ObjectMove(0, nmB + "EL", 0, s_sessLiveS[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmB + "EL", 1, s_sessLiveS[sl], s_sessLiveLo[sl]);
      ObjectMove(0, nmB + "ER", 0, s_sessLiveE[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmB + "ER", 1, s_sessLiveE[sl], s_sessLiveLo[sl]);
   }
   if(g_sessHlLines)
   {
      string nmHI = SessWindowName(sl, s_sessLiveStamp[sl], "HI");
      ObjectMove(0, nmHI, 0, s_sessLiveS[sl], s_sessLiveHi[sl]);
      ObjectMove(0, nmHI, 1, s_sessLiveE[sl], s_sessLiveHi[sl]);
      string nmLO = SessWindowName(sl, s_sessLiveStamp[sl], "LO");
      ObjectMove(0, nmLO, 0, s_sessLiveS[sl], s_sessLiveLo[sl]);
      ObjectMove(0, nmLO, 1, s_sessLiveE[sl], s_sessLiveLo[sl]);
   }
   if(g_sessHlLabels)
   {
      ObjectSetString(0, SessWindowName(sl, s_sessLiveStamp[sl], "HIL"), OBJPROP_TEXT,
                      DoubleToString(s_sessLiveHi[sl], _Digits));
      ObjectMove(0, SessWindowName(sl, s_sessLiveStamp[sl], "HIL"), 0, SessLabelAnchor(s_sessLiveE[sl], TimeCurrent()), s_sessLiveHi[sl]);
      ObjectSetString(0, SessWindowName(sl, s_sessLiveStamp[sl], "LOL"), OBJPROP_TEXT,
                      DoubleToString(s_sessLiveLo[sl], _Digits));
      ObjectMove(0, SessWindowName(sl, s_sessLiveStamp[sl], "LOL"), 0, SessLabelAnchor(s_sessLiveE[sl], TimeCurrent()), s_sessLiveLo[sl]);
   }
   if(g_sessRangeText)
   {
      ObjectSetString(0, SessWindowName(sl, s_sessLiveStamp[sl], "R"), OBJPROP_TEXT,
                      IntegerToString(SessPipsIn(s_sessLiveHi[sl], s_sessLiveLo[sl])) + "p");
      ObjectMove(0, SessWindowName(sl, s_sessLiveStamp[sl], "R"), 0, SessLabelAnchor(s_sessLiveE[sl], TimeCurrent()), s_sessLiveLo[sl]);
   }
   ThrottledChartRedraw();
}

void SessLiveUpdate(const datetime now)
{
   datetime bt = iTime(NULL, 0, 0);
   for(int sl = 0; sl < SESS_SLOTS; sl++)
   {
      if(!s_sessLiveValid[sl]) continue;
      if(now < s_sessLiveS[sl] || now >= s_sessLiveE[sl]) continue;
      //--- P-SESS-11: a bar that CLOSED unobserved (a slow tick, a sleep, a
      //--- reconnect) was never compared - its printed extreme is inside the
      //--- window but outside the cache. One scan of the window on the first
      //--- tick of a new bar answers every bar that passed; the bar-0 compare
      //--- below still carries the forming bar.
      bool newBar = (bt > 0 && s_sessLiveBar[sl] > 0 && bt != s_sessLiveBar[sl]);
      bool grew = false;
      if(newBar)
      {
         double hW = 0.0, lW = 0.0;
         datetime rEnd = (s_sessLiveE[sl] <= now) ? s_sessLiveE[sl] : now;
         if(SessHiLoFor(s_sessLiveS[sl], rEnd, hW, lW))
         {
            if(hW > s_sessLiveHi[sl]) { s_sessLiveHi[sl] = hW; grew = true; }
            if(lW < s_sessLiveLo[sl]) { s_sessLiveLo[sl] = lW; grew = true; }
         }
      }
      if(bt > 0) s_sessLiveBar[sl] = bt;
      double h0 = iHigh(NULL, 0, 0);
      double l0 = iLow(NULL, 0, 0);
      if(h0 <= 0.0 || l0 <= 0.0) continue;
      if(h0 > s_sessLiveHi[sl]) { s_sessLiveHi[sl] = h0; grew = true; }
      if(l0 < s_sessLiveLo[sl]) { s_sessLiveLo[sl] = l0; grew = true; }
      if(grew) SessLiveRepaint(sl);   // a still frame still costs zero writes
   }
}

//+------------------------------------------------------------------+
//| P-SESS-14: is there anything to draw at all? Asked only on the     |
//| empty-paint path, so the healthy tick never pays for it.           |
//+------------------------------------------------------------------+
bool SessAnySlotEnabled()
{
   for(int i = 0; i < SESS_SLOTS; i++)
   {
      SessSlot s;
      SessSlotGet(i, s);
      if(s.enabled) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| The tick (called from CoopPump's status job — 250 ms, both        |
//| entries). Order: want → state flips → rebuild-or-extend.          |
//+------------------------------------------------------------------+
void SessionsTick()
{
   if(StringLen(inpObjectPrefix) == 0) return;
   bool want = (g_sessMaster && !IsIndicatorHidden());
   if(!want)
   {
      if(s_sessBuilt)
      {
         SessWipe();
         s_sessBuilt = false;
         s_sessHash = 0;
         s_sessDay = 0;
         s_sessAlertSeeded = false;
         s_sessCdNext = 0;
         s_sessCdText = "";
         s_sessWitA = "";   // P-SESS-13: no witness outlives its family
         s_sessWitZ = "";
         s_sessEmptyMs = 0; // P-SESS-14: no retry owed by a family that was turned off
         s_sessCoverFrom = 0;   // P-SESS-15: neither is a coverage debt
         s_sessBarFloor = 0;
         s_sessCovMs = 0;
         for(int z = 0; z < SESS_SLOTS; z++)
         {
            s_sessWasOpen[z] = false;
            s_sessLiveValid[z] = false;
            s_sessLiveBar[z] = 0;
         }
         ThrottledChartRedraw(true);
      }
      return;
   }
   if(iBars(NULL, 0) <= 0) return;
   datetime now = TimeCurrent();
   int bkr = SessModelLiveDeltaMin();
   long h = SessViewHash();
   int day = SessServerDayStamp();
   bool settingsChanged = (s_sessBuilt && h != s_sessHash);

   //--- P-SESS-13 (2026-10-29) — THE FAMILY CAN BE TAKEN FROM UNDER US.
   //
   // Every rebuild decision below is a CHANGE: a new hash, a new day, a flip. A
   // family that a FOREIGN sweep deleted changes none of them, so the renderer
   // kept believing it was built and nothing ever repainted it - the boxes were
   // gone until tomorrow. That is not hypothetical: the object-count cleanup's
   // age rule was eating exactly the objects anchored at a window START (the
   // measured signature is in EventHandlers' skip, P-SESS-13), and the user sees
   // "the sessions vanish after a timeframe switch".
   //
   // The witness pair answers the one question the hash cannot: is the thing I
   // built still on the chart? Two ObjectFind calls per idle tick, no walk.
   // `s_sessHealMs` bounds the repair: if the family cannot be re-created (an
   // object-count emergency, a chart that refuses new objects), the tick must not
   // turn into a 4 Hz wipe-and-repaint - one attempt per 5 s, and the failure is
   // still visible as an empty family rather than a stall.
   if(s_sessBuilt && (s_sessWitA != "" || s_sessWitZ != ""))
   {
      bool gone = ((s_sessWitA != "" && ObjectFind(0, s_sessWitA) < 0) ||
                   (s_sessWitZ != "" && ObjectFind(0, s_sessWitZ) < 0));
      if(gone)
      {
         uint tHeal = GetTickCount();
         if(s_sessHealMs == 0 || tHeal - s_sessHealMs >= 5000)
         {
            s_sessHealMs = tHeal;
            s_sessBuilt = false;      // the rebuild branch below repaints this tick
            s_sessWitA = "";
            s_sessWitZ = "";
         }
      }
   }

   int  flippedSlot = -1;
   bool flippedOpen = false;
   for(int sl = 0; sl < SESS_SLOTS; sl++)
   {
      SessSlot s;
      SessSlotGet(sl, s);
      bool isOpen = false;
      if(s.enabled)
      {
         int ds; datetime sU, eU;
         isOpen = SessWindowAt(now, s.startMin, s.endMin, s.days, s.zone, s.customMin,
                               true, 0, SDST_NONE, bkr, ds, sU, eU);
      }
      if(s_sessAlertSeeded && !settingsChanged && isOpen != s_sessWasOpen[sl])
      {
         flippedSlot = sl;
         flippedOpen = isOpen;
      }
      s_sessWasOpen[sl] = isOpen;
   }

   //--- P-SESS-14: A PAINT THAT DECLARED NOTHING IS NOT A BUILD.
   //
   // The paint is wipe-then-declare, so if every window fails its price scan (a
   // timeframe whose history is still loading, a holiday stretch, an empty
   // account history) the family is now EMPTY while the renderer believed it
   // built. Nothing rebuilt it: the hash was stored, the day had not turned, no
   // slot flipped, and the witness pair was empty so even the heal had nothing
   // to ask about. The one attempt per 5 s below is the floor - a chart that
   // genuinely has nothing to draw costs one failed scan per 5 s, not 4 Hz.
   if(!s_sessBuilt && s_sessEmptyMs != 0 && SessAnySlotEnabled()
      && GetTickCount() - s_sessEmptyMs < 5000)
      return;

   //--- P-SESS-15 (2026-10-29) — A PAINT THAT RAN WHILE HISTORY WAS STILL SHORT.
   //
   // P-SESS-14 covered the paint that declared NOTHING. This is its narrower
   // sibling, and the one the user actually sees: attach the indicator (or open a
   // symbol) while the chart's history is still downloading and every window older
   // than the loaded bars fails `SessHiLoFor` - so the paint declares only the LIVE
   // session's box and looks perfectly healthy (a witness exists, the hash matches,
   // the day has not turned). The earlier sessions stay missing for the rest of the
   // day, which is the report «سشن روشن است ولی فقط همین یکی می‌آید».
   //
   // The answer is a coverage debt, not a timer: the paint records the earliest
   // window it wanted and the oldest bar it had. When that bar floor later recedes
   // past the wanted start, history has answered more than it could before, so the
   // family is rebuilt ONCE. A floor that has stopped moving buys no repaint (a
   // symbol with genuinely short history costs one probe per tick, zero writes), and
   // the 1 s budget keeps a streaming download from turning the repair into 4 Hz.
   //--- P-SESS-16 (2026-10-29) — AND THE FLOOR MAY BE UNKNOWN, NOT JUST SHALLOW.
   // The debt above asked `s_sessBarFloor != 0`, which silently disabled itself in
   // exactly the case that needs it: a paint whose deepest read answered 0 owns no
   // floor at all, so no later probe could ever look "deeper". A floor that is
   // still unknown is an outstanding debt, not a covered one.
   if(s_sessBuilt && s_sessCoverFrom != 0
      && (s_sessBarFloor == 0 || s_sessCoverFrom < s_sessBarFloor))
   {
      datetime covFloor = SessHistFloor();
      if(covFloor > 0 && (s_sessBarFloor == 0 || covFloor < s_sessBarFloor))
      {
         uint tCov = GetTickCount();
         if(s_sessCovMs == 0 || tCov - s_sessCovMs >= 1000)
         {
            s_sessCovMs = tCov;
            s_sessBarFloor = covFloor;   // the floor this rebuild will see
            s_sessBuilt = false;         // the rebuild branch below repaints
         }
      }
   }

   if(!s_sessBuilt || h != s_sessHash || day != s_sessDay || flippedSlot >= 0)
   {
      SessPaintAll(now, bkr);
      s_sessBuilt = (s_sessWitA != "");   // P-SESS-14: nothing declared -> not built
      s_sessEmptyMs = s_sessBuilt ? 0 : GetTickCount();
      s_sessHash = h;
      s_sessDay = day;
      s_sessAlertSeeded = true;
      if(flippedSlot >= 0 && g_sessAlerts)
      {
         SessSlot fs;
         SessSlotGet(flippedSlot, fs);
         Alert("TH3 Session: " + SessZoneLabel(fs.zone) + (flippedOpen ? " opened" : " closed")
               + " (" + SessHhMmFromMin(fs.startMin) + "-" + SessHhMmFromMin(fs.endMin) + ")");
      }
      ThrottledChartRedraw(true);
      return;
   }

   SessLiveUpdate(now);

   //--- countdown text refresh, ~1 Hz while a boundary is pending
   if(g_sessCountdown && s_sessCdNext > 0)
   {
      uint t = GetTickCount();
      if(t - s_sessCdMs >= 900)
      {
         s_sessCdMs = t;
         SessSlot cs;
         SessSlotGet(s_sessCdSlot, cs);
         string nmU = SessZoneLabel(cs.zone);
         StringToUpper(nmU);
         int left = (int)(s_sessCdNext - now);
         if(left < 0) left = 0;
         string txt = nmU + (s_sessCdIsOpen ? " close " : " open ") + SessFmtDur(left);
         if(txt != s_sessCdText)
         {
            s_sessCdText = txt;
            string nmC = inpObjectPrefix + SESS_TAG + "CDN";
            if(ObjectFind(0, nmC) >= 0)
               ObjectSetString(0, nmC, OBJPROP_TEXT, txt);
         }
      }
   }
}

#endif // SESSIONS_DRAW_MQH
