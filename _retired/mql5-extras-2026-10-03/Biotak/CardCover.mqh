#ifndef CARD_COVER_MQH
#define CARD_COVER_MQH

#property strict

//+------------------------------------------------------------------+
//| P-UI-131l — THE OPEN SURFACES' COVER: ONE OWNER, ONE QUESTION.   |
//|                                                                  |
//| User report: the bar-close countdown tag AND chart art land ON an |
//| open settings card. P-UI-98r found the reason for the HTF boxes — |
//| a chart-anchored object paints over the panel's screen skins at   |
//| ANY rung — and answered it with ABSENCE. This module is that     |
//| answer as ONE question every family can ask with the geometry it  |
//| already owns: PIXELS (corner labels, plates), a full-width ROW at |
//| one price (the level lines), or a CHART-SPACE BOX (the TH3 legs). |
//| The surfaces are the three rects the UI already publishes (card,  |
//| palette, strip — the P-UI-98r/P-DRAW-31 contract), so no layout   |
//| rule is copied here and a new surface only has to publish a rect. |
//|                                                                  |
//| COST: the rects are projected to a price band + a time window ONCE|
//| per mapping change (<= 2 ChartXYToTimePrice per surface, 4 chart  |
//| reads) and shared by every caller; a caller pays compares and a   |
//| chart write only on a real flip. Everything fails OPEN: no surface|
//| published, an unprojectable rect, a zero-size chart = nothing is  |
//| covered (the pre-fix behaviour) — so Lite, which publishes none,  |
//| is inert by construction.                                        |
//+------------------------------------------------------------------+

#define CARD_COVER_SURF   3     // card / palette / strip (add a publisher to add a row)

struct SCardCoverRect
{
   int      x1, y1, x2, y2;     // the published rect, in chart pixels
   datetime t1, t2;             // its time window   (BoxBlk)
   double   pLo, pHi;           // its price band    (RowBlk / RowXBlk / BoxBlk)
   bool     ok;                 // did the projection answer?
};

static SCardCoverRect s_ccRect[CARD_COVER_SURF];
static int      s_ccN     = 0;               // rects in the memo (0 = nothing published)
static int      s_ccPub[CARD_COVER_SURF * 4];// the published ints the memo was built from
static long     s_ccW     = -1, s_ccH = -1;
static double   s_ccHi    = 0.0, s_ccLo = 0.0;
static double   s_ccOneRow = 0.0;            // one text row, in price, at this mapping

//--- Publish readers -------------------------------------------------
// The three rects the UI hands over, in the order CARD_COVER_SURF names.
int CardCoverCollect(int &pub[])
{
   if(ArraySize(pub) < CARD_COVER_SURF * 4) ArrayResize(pub, CARD_COVER_SURF * 4);
   int n = 0;
   if(g_UIPanelRX >= 0 && g_UIPanelRW > 0 && g_UIPanelRH > 0)
   {
      pub[0] = g_UIPanelRX; pub[1] = g_UIPanelRY; pub[2] = g_UIPanelRW; pub[3] = g_UIPanelRH; n++;
   }
   if(g_UIPPalRX >= 0 && g_UIPPalRW > 0 && g_UIPPalRH > 0)
   {
      pub[n * 4] = g_UIPPalRX; pub[n * 4 + 1] = g_UIPPalRY;
      pub[n * 4 + 2] = g_UIPPalRW; pub[n * 4 + 3] = g_UIPPalRH; n++;
   }
   if(g_UIStripRX >= 0 && g_UIStripRW > 0 && g_UIStripRH > 0)
   {
      pub[n * 4] = g_UIStripRX; pub[n * 4 + 1] = g_UIStripRY;
      pub[n * 4 + 2] = g_UIStripRW; pub[n * 4 + 3] = g_UIStripRH; n++;
   }
   return n;
}

// Is any surface published? (No projection — the ONE cheap gate.)
bool CardCoverOpen()
{
   return ((g_UIPanelRX >= 0 && g_UIPanelRW > 0 && g_UIPanelRH > 0) ||
           (g_UIPPalRX  >= 0 && g_UIPPalRW  > 0 && g_UIPPalRH  > 0) ||
           (g_UIStripRX >= 0 && g_UIStripRW > 0 && g_UIStripRH > 0));
}

//--- The memo -------------------------------------------------------
// Rebuilt only when the mapping or WHO published what moved; the steady
// state is 4 chart reads + <= 12 int compares and then a few compares per
// caller. Every rect that fails to project keeps ok=false and is skipped
// by the chart-space forms (the pixel form needs no projection at all).
void CardCoverRefresh()
{
   // Nothing to cover (the whole session on a Lite chart, and every frame with no
   // surface open): twelve compares and out, never a chart-property read.
   if(s_ccN == 0 && !CardCoverOpen()) return;

   int pub[CARD_COVER_SURF * 4];
   int n = CardCoverCollect(pub);
   int cw   = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int ch   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   double pMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double pMin = ChartGetDouble(0, CHART_PRICE_MIN);

   bool same = (n == s_ccN);
   for(int k = 0; same && k < n * 4; k++)
      if(pub[k] != s_ccPub[k]) same = false;
   if(same && (cw != s_ccW || ch != s_ccH || pMax != s_ccHi || pMin != s_ccLo))
      same = false;
   if(same) return;

   s_ccN = n; s_ccW = cw; s_ccH = ch; s_ccHi = pMax; s_ccLo = pMin;
   for(int k2 = 0; k2 < n * 4; k2++) s_ccPub[k2] = pub[k2];
   s_ccOneRow = 0.0;
   if(n == 0) return;
   if(ch > 0 && pMax > pMin)
      s_ccOneRow = (pMax - pMin) * (double)(inpFontSize + 6) / (double)ch;

   for(int i = 0; i < n; i++)
   {
      int rx = pub[i * 4], ry = pub[i * 4 + 1], rw = pub[i * 4 + 2], rh = pub[i * 4 + 3];
      s_ccRect[i].x1 = rx;      s_ccRect[i].y1 = ry;
      s_ccRect[i].x2 = rx + rw; s_ccRect[i].y2 = ry + rh;
      s_ccRect[i].ok = false;
      s_ccRect[i].t1 = 0; s_ccRect[i].t2 = 0;
      s_ccRect[i].pLo = 0.0; s_ccRect[i].pHi = 0.0;
      // ONE projection pair answers both axes: the top-left corner gives
      // (left time, top price) and the bottom-right (right time, bottom price).
      int subA = 0, subB = 0;
      datetime tA = 0, tB = 0;
      double pA = 0.0, pB = 0.0;
      if(!ChartXYToTimePrice(0, rx, ry, subA, tA, pA)) continue;
      if(!ChartXYToTimePrice(0, rx + rw, ry + rh, subB, tB, pB)) continue;
      s_ccRect[i].t1  = (tA < tB ? tA : tB);
      s_ccRect[i].t2  = (tA < tB ? tB : tA);
      s_ccRect[i].pHi = (pA > pB ? pA : pB);
      s_ccRect[i].pLo = (pA > pB ? pB : pA);
      s_ccRect[i].ok  = (s_ccRect[i].pHi > s_ccRect[i].pLo);
   }
}

// One text row in price (the labels' own lift, the same `inpFontSize + 6`
// CreatePipDistanceLabel measures with). 0 = no mapping to measure on.
double CardCoverOneRowPrice() { CardCoverRefresh(); return s_ccOneRow; }

//--- The three questions -------------------------------------------
// A PIXEL rect (corner labels, plates): no projection, no price scale.
bool CardCoverPxBlk(const int x1, const int y1, const int x2, const int y2)
{
   CardCoverRefresh();
   for(int i = 0; i < s_ccN; i++)
      if(x1 <= s_ccRect[i].x2 && x2 >= s_ccRect[i].x1 &&
         y1 <= s_ccRect[i].y2 && y2 >= s_ccRect[i].y1) return true;
   return false;
}

// A full-width ROW at one price (OBJ_HLINE always spans the whole plot).
bool CardCoverRowBlk(const double pLo, const double pHi)
{
   CardCoverRefresh();
   for(int i = 0; i < s_ccN; i++)
      if(s_ccRect[i].ok && pLo <= s_ccRect[i].pHi && pHi >= s_ccRect[i].pLo) return true;
   return false;
}

// A ROW that only reaches part of the width (a right-edge label, a pill).
bool CardCoverRowXBlk(const double pLo, const double pHi, const int x1, const int x2)
{
   CardCoverRefresh();
   for(int i = 0; i < s_ccN; i++)
      if(s_ccRect[i].ok && pLo <= s_ccRect[i].pHi && pHi >= s_ccRect[i].pLo &&
         x1 <= s_ccRect[i].x2 && x2 >= s_ccRect[i].x1) return true;
   return false;
}

// The right-edge TEXT row (the pip/fibo label family: OBJ_TEXT, ANCHOR_RIGHT,
// one row above its line, part of which sits under the price scale).
#define CARD_COVER_ROW_BAND 140   // the widest row (`M1 +3 | 45.2 pips` at the shared size)
bool CardCoverRightRowBlk(const double pLo, const double pHi)
{
   CardCoverRefresh();
   if(s_ccW <= 0) return false;
   int x2 = (int)s_ccW;
   int x1 = x2 - MathMax(8, inpLabelsMarginLeft) - CARD_COVER_ROW_BAND;
   return CardCoverRowXBlk(pLo, pHi, x1, x2);
}

// A CHART-SPACE BOX (time x price) — the TH3 legs and every trend segment.
bool CardCoverBoxBlk(const datetime t1, const datetime t2, const double pLo, const double pHi)
{
   CardCoverRefresh();
   for(int i = 0; i < s_ccN; i++)
      if(s_ccRect[i].ok && t1 <= s_ccRect[i].t2 && t2 >= s_ccRect[i].t1 &&
         pLo <= s_ccRect[i].pHi && pHi >= s_ccRect[i].pLo) return true;
   return false;
}

//--- The LINE family's answer: SINK, do not delete -------------------
// A text or a plate that the card covers is masked (a text behind the
// candles would be unreadable anyway), but a full-width level LINE is not:
// masking it would take the whole ruler away for a card that covers a third
// of it. `OBJPROP_BACK = true` is the platform's own "behind the chart"
// layer, and the card is in FRONT of the chart while it is open
// (PnlLockForeground) — so a sunk line cannot paint over it under any
// layering model, and the line itself stays readable outside the card.
//
// Guarded: the steady state (nothing sunk, or nothing covered) costs two
// compares; a write happens only when a line really flips. The set is
// tracked, so the release gives back exactly what the sink took.
static string s_ccSunk[];
static double s_ccSunkP[];
static int    s_ccSunkN = 0;

int CardCoverSunkFind(const string name)
{
   for(int i = 0; i < s_ccSunkN; i++)
      if(s_ccSunk[i] == name) return i;
   return -1;
}
bool CardCoverSunk(const string name) { return CardCoverSunkFind(name) >= 0; }

void CardCoverSunkDrop(const int idx)
{
   if(idx < 0 || idx >= s_ccSunkN) return;
   s_ccSunk[idx]  = s_ccSunk[s_ccSunkN - 1];
   s_ccSunkP[idx] = s_ccSunkP[s_ccSunkN - 1];
   s_ccSunkN--;
   ArrayResize(s_ccSunk, s_ccSunkN);
   ArrayResize(s_ccSunkP, s_ccSunkN);
}

// Un-sink one tracked slot. The write may fail (the object is gone) — the
// slot is dropped either way: a tracked name that no longer exists must not
// linger, or the sweep would re-test a ghost for the rest of the session.
void CardCoverSunkRestore(const int idx)
{
   if(idx < 0 || idx >= s_ccSunkN) return;
   string nm = s_ccSunk[idx];
   CardCoverSunkDrop(idx);
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
}

void CardCoverSinkForget(const string name)
{
   int i = CardCoverSunkFind(name);
   if(i >= 0) CardCoverSunkDrop(i);
}

// Ask for one line: blocked = its row sits under an open surface.
bool CardCoverSink(const string name, const bool blocked, const double price)
{
   if(!blocked && s_ccSunkN <= 0) return false;      // the steady state
   int idx = CardCoverSunkFind(name);
   if(blocked)
   {
      if(idx >= 0) { s_ccSunkP[idx] = price; return true; }
      if(!ObjectSetInteger(0, name, OBJPROP_BACK, true)) return false;
      ArrayResize(s_ccSunk,  s_ccSunkN + 1);
      ArrayResize(s_ccSunkP, s_ccSunkN + 1);
      s_ccSunk[s_ccSunkN]  = name;
      s_ccSunkP[s_ccSunkN] = price;
      s_ccSunkN++;
      return true;
   }
   if(idx >= 0) CardCoverSunkRestore(idx);
   return false;
}

// Give every sunk line back to the foreground (cover gone, or shutting down).
void CardCoverSinkReleaseAll()
{
   while(s_ccSunkN > 0) CardCoverSunkRestore(s_ccSunkN - 1);
}

// The net under the family owners (250 ms clock): a line whose row left the
// card — or a card that closed while the render was idle — is restored here.
void CardCoverSinkSweep()
{
   if(s_ccSunkN <= 0) return;
   if(!CardCoverOpen()) { CardCoverSinkReleaseAll(); return; }
   CardCoverRefresh();
   for(int i = s_ccSunkN - 1; i >= 0; i--)
      if(!CardCoverRowBlk(s_ccSunkP[i], s_ccSunkP[i])) CardCoverSunkRestore(i);
}

#endif // CARD_COVER_MQH
