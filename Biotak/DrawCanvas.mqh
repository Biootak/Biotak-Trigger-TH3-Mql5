// ============================================================================
// DrawCanvas.mqh — the user's own drawings, painted as PIXELS (P-DRAW-CANVAS).
//
// WHY THIS FILE EXISTS
// The reference product (MQL5 "Chart Drawing Toolkit") owns exactly ONE
// ObjectCreate in 37 126 lines: every trendline, fib, box and path is a pixel
// run on a full-chart canvas. That is why its tools feel attached to the hand:
// a mouse move costs buffer writes, never a terminal round-trip and never a
// chart invalidation.
//
// Our product could not follow it while the drawings were the terminal's own
// objects (DrawToolbar is a STYLER for MT5's native drawings, not a tool set —
// see its header). This module is the missing half: our own tool palette, our
// own model, our own canvas.
//
// ARCHITECTURE (the same three laws as Engine/RenderCore)
//   [1] MODEL   flat struct array, (time, price) anchors only. Serializable.
//   [2] PAINT   one full-chart bitmap; clear + rasterize + ONE ResourceCreate
//               + ONE ChartRedraw per frame, capped at 16 ms (60 fps).
//   [3] INPUT   arm -> click(s) -> commit; hit-test in PIXELS; drag by delta.
//
// LAW 0: a frame costs f(output surface). N drawings never reach the terminal
// per frame — the whole family is one bitmap upload.
//
// This is v1 of the palette: 6 tools, selection, drag, delete, CSV persistence.
// Adding a tool is three sites here (the enum, DCPaintObj's switch, DCHitTest)
// and one entry in the palette table — never a new surface.
// ============================================================================
#ifndef DRAW_CANVAS_MQH
#define DRAW_CANVAS_MQH

#ifdef BIOTAK_RENDER_ENGINE   // the canvas engine owns the platform helpers

#define DC_FILE          "Biotak\\DrawCanvas.csv"
#define DC_FRAME_MS      16      // 60 fps, the reference's own budget
#define DC_GRAB_PX       7       // hit tolerance around a stroke
#define DC_HANDLE_PX     4       // selection handle half-size
#define DC_BAR_CELL      24
#define DC_BAR_GAP       2
#define DC_BAR_PAD       2
#define DC_BAR_X         8       // inset from the left edge
#define DC_BAR_Y         34      // ...and from the BOTTOM edge: the top-left corner
                                 // belongs to the terminal (legend, one-click panel)
                                 // and to this product's own cards. Bottom-left
                                 // is the one strip nothing else claims.
#define DC_TOOL_N        10      // cells that arm a tool (cell 0 is "select")

//--- tools. The order IS the palette order; DCT_NONE is the pointer cell.
//--- Every tool here is TWO-ANCHOR by construction (a third anchor would change
//--- the CSV row, and the row is the only memory these drawings have). A tool
//--- that needs three points gets one when the format grows a version column.
enum EDCTool
{
   DCT_NONE    = 0,
   DCT_TREND   = 1,
   DCT_HLINE   = 2,
   DCT_VLINE   = 3,
   DCT_RAY     = 4,
   DCT_RECT    = 5,
   DCT_FIB     = 6,
   DCT_ARROW   = 7,
   DCT_ELLIPSE = 8,
   DCT_POS     = 9,    // long/short position: entry + stop, target at 1:2
   DCT_CROSS   = 10    // a full crosshair through one point
};

//--- one drawing. No dynamic members, no strings: ArrayResize/assignment stay cheap.
struct DCObj
{
   int    id;
   int    tool;
   long   t1, t2;
   double p1, p2;
   color  ink;
   int    width;
   int    style;
   bool   visible;
};

//==================== [1] model =====================================
DCObj  g_dc[];
int    g_dcNextId  = 1;
int    g_dcSel     = -1;      // index into g_dc, -1 = nothing selected
int    g_dcArmed   = DCT_NONE;
int    g_dcStage   = 0;       // 0 = first click pending, 1 = second click pending
long   g_dcT1      = 0;
double g_dcP1      = 0.0;
long   g_dcCurT    = 0;       // the cursor, in chart units (the live preview)
double g_dcCurP    = 0.0;
bool   g_dcCurOk   = false;
bool   g_dcDragging = false;
int    g_dcDragIdx  = -1;
int    g_dcDragAnchor = -1;   // -1 = the whole drawing, 0/1 = that anchor alone
bool   g_dcLeft     = false;  // the button bit of the previous move (press edge)
bool   g_dcSwallow  = false;  // the CLICK that follows a release is the same gesture
long   g_dcDragT0   = 0;
double g_dcDragP0   = 0.0;
long   g_dcDragT1   = 0;      // the object's anchor at the grab
double g_dcDragP1   = 0.0;
long   g_dcDragT2   = 0;
double g_dcDragP2   = 0.0;
bool   g_dcDirty   = false;   // the CSV is stale
uint   g_dcFrameMs = 0;

//==================== [2] surfaces ==================================
uint   g_dcPix[];             // the drawings' full-chart buffer
uint   g_dcBar[];             // the palette's small buffer
int    g_dcW = 0, g_dcH = 0;
bool   g_dcReady = false;
string g_dcResDraw = "", g_dcObjDraw = "";
string g_dcResBar  = "", g_dcObjBar  = "";
int    g_dcBarW = 0, g_dcBarH = 0;
int    g_dcBarPx = 0, g_dcBarPy = 0;   // the bar's resolved top-left, in chart pixels

//==================== helpers =======================================
bool DCProject(const long t, const double p, int &x, int &y)
{
   return RPlatTimePriceToXY(t, p, x, y);
}
double DCPointSegPx(const int px, const int py, const int x1, const int y1, const int x2, const int y2)
{
   double dx = (double)(x2 - x1), dy = (double)(y2 - y1);
   double len2 = dx * dx + dy * dy;
   if(len2 <= 0.0)
   {
      double ax = (double)(px - x1), ay = (double)(py - y1);
      return MathSqrt(ax * ax + ay * ay);
   }
   double k = ((double)(px - x1) * dx + (double)(py - y1) * dy) / len2;
   if(k < 0.0) k = 0.0;
   if(k > 1.0) k = 1.0;
   double cx = (double)x1 + k * dx, cy = (double)y1 + k * dy;
   double ex = (double)px - cx, ey = (double)py - cy;
   return MathSqrt(ex * ex + ey * ey);
}

//==================== raster (into an arbitrary buffer) =============
void DCPut(uint &buf[], const int w, const int h, const int x, const int y, const uint argb)
{
   if(x < 0 || y < 0 || x >= w || y >= h) return;
   buf[y * w + x] = argb;
}
// A stroke of `width` px. The reference supersamples an SDF; a canvas at this
// size reads the same at width 1..3, and the pattern hook (RLinePixelOn) is the
// engine's own dash law, so a dashed drawing here is dashed the same way a
// dashed ladder rung is.
void DCPlotSeg(uint &buf[], const int w, const int h,
               const int x1, const int y1, const int x2, const int y2,
               const uint argb, const int width, const int style)
{
   int lw = width; if(lw < 1) lw = 1;
   int dx = x2 - x1, dy = y2 - y1;
   int adx = (dx < 0 ? -dx : dx), ady = (dy < 0 ? -dy : dy);
   int steps = (adx > ady) ? adx : ady;
   int r = lw / 2;
   if(steps <= 0)
   {
      for(int a = -r; a <= r; a++)
         for(int b = -r; b <= r; b++) DCPut(buf, w, h, x1 + a, y1 + b, argb);
      return;
   }
   double sx = (double)dx / (double)steps, sy = (double)dy / (double)steps;
   for(int s = 0; s <= steps; s++)
   {
      if(style > 0 && !RLinePixelOn(style, s)) continue;
      int x = x1 + (int)MathRound(sx * (double)s);
      int y = y1 + (int)MathRound(sy * (double)s);
      for(int a = -r; a <= r; a++)
         for(int b = -r; b <= r; b++) DCPut(buf, w, h, x + a, y + b, argb);
   }
}
void DCPlotHLine(uint &buf[], const int w, const int h, const int y,
                 const uint argb, const int width, const int style)
{
   int r = width / 2;
   for(int k = -r; k <= r; k++)
      for(int x = 0; x < w; x++)
      {
         if(style > 0 && !RLinePixelOn(style, x)) continue;
         DCPut(buf, w, h, x, y + k, argb);
      }
}
void DCPlotVLine(uint &buf[], const int w, const int h, const int x,
                 const uint argb, const int width, const int style)
{
   int r = width / 2;
   for(int k = -r; k <= r; k++)
      for(int y = 0; y < h; y++)
      {
         if(style > 0 && !RLinePixelOn(style, y)) continue;
         DCPut(buf, w, h, x + k, y, argb);
      }
}
void DCPlotHandle(uint &buf[], const int w, const int h, const int x, const int y, const uint argb)
{
   for(int a = -DC_HANDLE_PX; a <= DC_HANDLE_PX; a++)
      for(int b = -DC_HANDLE_PX; b <= DC_HANDLE_PX; b++)
      {
         if(a > -DC_HANDLE_PX && a < DC_HANDLE_PX && b > -DC_HANDLE_PX && b < DC_HANDLE_PX)
            continue;   // a hollow square: the drawing stays visible through it
         DCPut(buf, w, h, x + a, y + b, argb);
      }
}
// A translucent plate. The buffer is ARGB_NORMALIZE, so a low alpha here really
// does blend with the candles behind it — the position tool's two zones are the
// only place in this file that leans on that.
void DCFillRect(uint &buf[], const int w, const int h,
                const int x1, const int y1, const int x2, const int y2, const uint argb)
{
   //--- CLAMPED, not just bounds-checked in DCPut: a position tool whose stop is
   //--- dragged far off the page would otherwise loop over tens of thousands of
   //--- rows, each one a full width of rejected writes. The page is the whole
   //--- area this can ever touch, so the loop starts and ends there.
   int xa = (x1 < x2) ? x1 : x2, xb = (x1 < x2) ? x2 : x1;
   int ya = (y1 < y2) ? y1 : y2, yb = (y1 < y2) ? y2 : y1;
   if(xa < 0) xa = 0;  if(ya < 0) ya = 0;
   if(xb > w - 1) xb = w - 1;  if(yb > h - 1) yb = h - 1;
   if(xa > xb || ya > yb) return;
   for(int y = ya; y <= yb; y++)
      for(int x = xa; x <= xb; x++) buf[y * w + x] = argb;
}
double DCPointPtPx(const int px, const int py, const int x, const int y)
{
   double dx = (double)(px - x), dy = (double)(py - y);
   return MathSqrt(dx * dx + dy * dy);
}

//==================== paint one drawing =============================
// The two "standing" anchors, refreshed once per frame (see DCRefreshStands).
// An HLINE owns a PRICE and an arbitrary time; a VLINE owns a TIME and an
// arbitrary price. If the anchor that does NOT matter leaves the page or the
// scale, the projection fails and the line vanishes — the classic broken
// horizontal line. These two stands are always resolvable.
datetime g_dcLastBarT = 0;
double   g_dcMidP     = 0.0;
void DCRefreshStands()
{
   // SeriesInfoInteger takes a SYMBOL, not a chart id: a bare 0 is converted to
   // the symbol "0" and the call quietly answers 0 (a warning at compile time,
   // a dead horizontal line at run time).
   g_dcLastBarT = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   g_dcMidP = (RPlatPriceMin() + RPlatPriceMax()) * 0.5;
}
// The anchor, projected with its tool's own fallback. One call site for paint
// and one for hit-test, so a line can never be drawn where it cannot be grabbed.
bool DCAnchorXY(const DCObj &o, int &x, int &y)
{
   if(DCProject(o.t1, o.p1, x, y)) return true;
   if(o.tool == DCT_HLINE && g_dcLastBarT > 0)
      return DCProject((long)g_dcLastBarT, o.p1, x, y);
   if(o.tool == DCT_VLINE && g_dcMidP > 0.0)
      return DCProject(o.t1, g_dcMidP, x, y);
   return false;
}
// Takes the object BY REFERENCE, never an index: the live preview is a struct
// that exists for one frame and must not be appended to the model (an
// ArrayResize per frame is the one allocation this hot path can avoid).
void DCPaintObj(uint &buf[], const int w, const int h, const DCObj &o, const bool sel)
{
   int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
   const bool ok1 = DCAnchorXY(o, x1, y1);
   const bool ok2 = DCProject(o.t2, o.p2, x2, y2);
   const uint ink = RCol(o.ink, 255);
   const uint hl  = RCol(clrWhite, 220);
   const int  lw  = o.width;
   const int  st  = o.style;

   switch(o.tool)
   {
      case DCT_TREND:
         if(ok1 && ok2) DCPlotSeg(buf, w, h, x1, y1, x2, y2, ink, lw, st);
         break;
      case DCT_HLINE:
         if(ok1) DCPlotHLine(buf, w, h, y1, ink, lw, st);
         break;
      case DCT_VLINE:
         if(ok1) DCPlotVLine(buf, w, h, x1, ink, lw, st);
         break;
      case DCT_RAY:
         if(ok1 && ok2)
         {
            if(x2 != x1)
            {
               double k = (double)(y2 - y1) / (double)(x2 - x1);
               int xr = (x2 >= x1) ? (w - 1) : 0;
               int yr = y1 + (int)MathRound(k * (double)(xr - x1));
               DCPlotSeg(buf, w, h, x1, y1, xr, yr, ink, lw, st);
            }
            else DCPlotVLine(buf, w, h, x1, ink, lw, st);
         }
         break;
      case DCT_RECT:
         if(ok1 && ok2)
         {
            DCPlotSeg(buf, w, h, x1, y1, x2, y1, ink, lw, st);
            DCPlotSeg(buf, w, h, x2, y1, x2, y2, ink, lw, st);
            DCPlotSeg(buf, w, h, x2, y2, x1, y2, ink, lw, st);
            DCPlotSeg(buf, w, h, x1, y2, x1, y1, ink, lw, st);
         }
         break;
      case DCT_FIB:
         if(ok1 && ok2)
         {
            const double r[7] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
            for(int i = 0; i < 7; i++)
            {
               double p = o.p1 + (o.p2 - o.p1) * r[i];
               int xa = 0, ya = 0, xb = 0, yb = 0;
               if(!DCProject(o.t1, p, xa, ya)) continue;
               if(!DCProject(o.t2, p, xb, yb)) continue;
               DCPlotSeg(buf, w, h, xa, ya, xb, yb, ink, (i == 0 || i == 6) ? lw : 1, (i == 0 || i == 6) ? 0 : st);
            }
         }
         break;
      case DCT_ARROW:
         if(ok1 && ok2)
         {
            DCPlotSeg(buf, w, h, x1, y1, x2, y2, ink, lw, st);
            //--- the head: two strokes back from the tip at +/- a fixed half-angle,
            //--- so it stays square to the shaft at every slope (a fixed dx/dy pair
            //--- would flatten on steep lines and open up on flat ones)
            const double ang = MathArctan2((double)(y2 - y1), (double)(x2 - x1));
            const double L = 12.0, A = 0.40;
            DCPlotSeg(buf, w, h, x2, y2,
                      x2 - (int)MathRound(L * MathCos(ang - A)),
                      y2 - (int)MathRound(L * MathSin(ang - A)), ink, lw, 0);
            DCPlotSeg(buf, w, h, x2, y2,
                      x2 - (int)MathRound(L * MathCos(ang + A)),
                      y2 - (int)MathRound(L * MathSin(ang + A)), ink, lw, 0);
         }
         break;
      case DCT_ELLIPSE:
         if(ok1 && ok2)
         {
            const int cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
            const int rx = (x1 > x2 ? x1 - x2 : x2 - x1) / 2;
            const int ry = (y1 > y2 ? y1 - y2 : y2 - y1) / 2;
            if(rx > 0 && ry > 0)
            {
               const int steps = (rx > ry ? rx : ry) * 6;
               const int rr = (lw > 1) ? lw / 2 : 0;
               for(int s = 0; s <= steps; s++)
               {
                  //--- the dash phase runs over the WHOLE ring, not per arc piece:
                  //--- restarting it every segment turns a dotted ellipse into a
                  //--- solid one, which is exactly what the live preview shows
                  if(st > 0 && !RLinePixelOn(st, s)) continue;
                  const double a = 2.0 * M_PI * (double)s / (double)steps;
                  const int x = cx + (int)MathRound((double)rx * MathCos(a));
                  const int y = cy + (int)MathRound((double)ry * MathSin(a));
                  for(int ddx = -rr; ddx <= rr; ddx++)
                     for(int ddy = -rr; ddy <= rr; ddy++)
                        DCPut(buf, w, h, x + ddx, y + ddy, ink);
               }
            }
         }
         break;
      case DCT_POS:
         if(ok1 && ok2)
         {
            //--- the STOP is the second click, so the side is implied by where the
            //--- hand put it: stop below entry is a long, above is a short. The
            //--- target is 1:2, which keeps this a two-anchor tool (a draggable
            //--- target would need a third anchor and a third CSV column).
            const int d = y2 - y1;
            const int yT = y1 - 2 * d;
            DCFillRect(buf, w, h, x1, y1, x2, yT, RCol(clrSeaGreen, 44));
            DCFillRect(buf, w, h, x1, y1, x2, y2, RCol(clrIndianRed, 56));
            DCPlotSeg(buf, w, h, x1, y2, x2, y2, ink, lw, 0);          // the stop
            DCPlotSeg(buf, w, h, x1, yT, x2, yT, ink, lw, st);         // the target
            DCPlotSeg(buf, w, h, x1, y1, x2, y1, ink, lw + 1, 0);      // the entry
         }
         break;
      case DCT_CROSS:
         if(ok1)
         {
            //--- a crosshair owns no second point: both arms run the whole page
            const int cs = (st > 0) ? st : 2;
            DCPlotHLine(buf, w, h, y1, ink, lw, cs);
            DCPlotVLine(buf, w, h, x1, ink, lw, cs);
         }
         break;
   }
   //--- selection: a hollow handle on every anchor the tool really owns
   if(sel)
   {
      if(ok1) DCPlotHandle(buf, w, h, x1, y1, hl);
      if(ok2 && o.tool != DCT_HLINE && o.tool != DCT_VLINE && o.tool != DCT_CROSS)
         DCPlotHandle(buf, w, h, x2, y2, hl);
   }
}

//==================== the frame =====================================
bool DCEnsure()
{
   int w = RPlatChartW(), h = RPlatChartH();
   if(w <= 0 || h <= 0) return false;
   if(w != g_dcW || h != g_dcH || !g_dcReady)
   {
      g_dcW = w; g_dcH = h;
      if(ArrayResize(g_dcPix, w * h) != w * h) return false;
      g_dcResDraw = RPlatResName("DC");
      g_dcObjDraw = RPlatObjName("DC");
      if(!RPlatResourceCreate(g_dcResDraw, g_dcPix, w, h)) return false;
      //--- z above the engine's FRONT slot: a user drawing belongs over the
      //--- candles and over the indicator's own canvas, never under them
      if(!RPlatLayerCreate(g_dcObjDraw, g_dcResDraw, 0, 0, w, h, false, 2)) return false;
      g_dcReady = true;
   }
   return true;
}
void DCPaint()
{
   if(!DCEnsure()) return;
   const int w = g_dcW, h = g_dcH;
   DCRefreshStands();
   RBufClear(g_dcPix, w * h, 0);
   for(int i = 0; i < ArraySize(g_dc); i++)
   {
      if(!g_dc[i].visible) continue;
      DCPaintObj(g_dcPix, w, h, g_dc[i], i == g_dcSel);
   }
   //--- the gesture's own picture: the same painter, a struct that lives one frame
   if(g_dcArmed != DCT_NONE && g_dcCurOk)
   {
      DCObj pv;
      pv.id = -1; pv.tool = g_dcArmed; pv.visible = true;
      pv.ink = clrDodgerBlue; pv.width = 1; pv.style = 2;   // dotted = "not committed"
      if(g_dcStage == 1)
      {
         pv.t1 = g_dcT1; pv.p1 = g_dcP1;
         pv.t2 = g_dcCurT; pv.p2 = g_dcCurP;
         DCPaintObj(g_dcPix, w, h, pv, false);
      }
      else
      {
         //--- no anchor yet: a crosshair tip so the first click has a target
         int cx = 0, cy = 0;
         if(DCProject(g_dcCurT, g_dcCurP, cx, cy))
            DCPlotHandle(g_dcPix, w, h, cx, cy, RCol(clrDodgerBlue, 200));
      }
   }
   RPlatResourceCreate(g_dcResDraw, g_dcPix, w, h);
   RPlatRedraw();
}
// P-DRAW-CANVAS — one frame per 16 ms, the last sample wins. Same law as
// PATH_FRAME_MS: the geometry is always current, only the WRITE is rationed.
void DCRequestFrame()
{
   uint now = GetTickCount();
   if(g_dcFrameMs != 0 && (uint)(now - g_dcFrameMs) < DC_FRAME_MS) return;
   g_dcFrameMs = now;
   DCPaint();
}

//==================== the palette bar ===============================
// The bar owns its OWN small buffer and never asks for the chart-sized one:
// during OnInit the chart may not be mapped yet, and a palette that waits for
// a resize is a palette the user thinks is missing.
void DCBarPlace();   // defined below: the paint calls it to put the plate down
void DCBarDraw()
{
   const int cw = DC_BAR_CELL, gp = DC_BAR_GAP, pad = DC_BAR_PAD;
   g_dcBarW = (DC_TOOL_N + 1) * (cw + gp) + pad * 2;   // one cell per tool, plus the pointer
   g_dcBarH = cw + pad * 2;
   if(ArrayResize(g_dcBar, g_dcBarW * g_dcBarH) != g_dcBarW * g_dcBarH) return;
   const uint bg     = RCol((color)0x202020, 232);
   const uint edge   = RCol((color)0x585858, 255);
   const uint idle   = RCol((color)0xE8E8E8, 255);
   const uint hotBg  = RCol((color)0x2F6FD0, 255);
   RBufClear(g_dcBar, g_dcBarW * g_dcBarH, 0);
   //--- the plate
   for(int y = 0; y < g_dcBarH; y++)
      for(int x = 0; x < g_dcBarW; x++)
         if(x == 0 || y == 0 || x == g_dcBarW - 1 || y == g_dcBarH - 1)
            DCPut(g_dcBar, g_dcBarW, g_dcBarH, x, y, edge);
         else
            DCPut(g_dcBar, g_dcBarW, g_dcBarH, x, y, bg);
   for(int c = 0; c <= DC_TOOL_N; c++)
   {
      const int x0 = pad + c * (cw + gp);
      const int y0 = pad;
      const bool active = (c == 0) ? (g_dcArmed == DCT_NONE) : (g_dcArmed == c);
      if(active)
         for(int y = y0; y < y0 + cw; y++)
            for(int x = x0; x < x0 + cw; x++)
               DCPut(g_dcBar, g_dcBarW, g_dcBarH, x, y, hotBg);
      const int mx = x0 + cw / 2, my = y0 + cw / 2, r = cw / 2 - 4;
      const uint ink = active ? RCol(clrWhite, 255) : idle;
      switch(c)
      {
         case 0:   // pointer: a small arrow, drawn as two strokes
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - 3, my - 5, mx + 3, my + 5, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - 3, my - 5, mx - 1, my + 1, ink, 1, 0);
            break;
         case DCT_TREND:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + r, mx + r, my - r, ink, 1, 0);
            break;
         case DCT_HLINE:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my, mx + r, my, ink, 1, 0);
            break;
         case DCT_VLINE:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx, my - r, mx, my + r, ink, 1, 0);
            break;
         case DCT_RAY:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + r, mx + r, my - r, ink, 1, 0);
            DCPut(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my - r, ink);
            DCPut(g_dcBar, g_dcBarW, g_dcBarH, mx + r - 1, my - r, ink);
            break;
         case DCT_RECT:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my - r, mx + r, my - r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my - r, mx + r, my + r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my + r, mx - r, my + r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + r, mx - r, my - r, ink, 1, 0);
            break;
         case DCT_FIB:
            for(int i = -1; i <= 1; i++)
               DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + i * (r / 2), mx + r, my + i * (r / 2), ink, 1, 0);
            break;
         case DCT_ARROW:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + r, mx + r, my - r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my - r, mx + r - 4, my - r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my - r, mx + r, my - r + 4, ink, 1, 0);
            break;
         case DCT_ELLIPSE:
         {
            const int rr = r - 1;
            for(int s = 0; s < 24; s++)
            {
               double a0 = 2.0 * M_PI * (double)s / 24.0;
               double a1 = 2.0 * M_PI * (double)(s + 1) / 24.0;
               DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH,
                         mx + (int)MathRound(rr * MathCos(a0)), my + (int)MathRound(rr * MathSin(a0)),
                         mx + (int)MathRound(rr * MathCos(a1)), my + (int)MathRound(rr * MathSin(a1)), ink, 1, 0);
            }
            break;
         }
         case DCT_POS:
            //--- the two zones, stacked: reward on top, risk below, entry between
            for(int y = my - r; y < my; y++)
               for(int x = mx - r; x <= mx + r; x++) DCPut(g_dcBar, g_dcBarW, g_dcBarH, x, y, ink);
            for(int x = mx - r; x <= mx + r; x++) DCPut(g_dcBar, g_dcBarW, g_dcBarH, x, my, ink);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my + r, mx + r, my + r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my, mx - r, my + r, ink, 1, 0);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx + r, my, mx + r, my + r, ink, 1, 0);
            break;
         case DCT_CROSS:
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx - r, my, mx + r, my, ink, 1, 2);
            DCPlotSeg(g_dcBar, g_dcBarW, g_dcBarH, mx, my - r, mx, my + r, ink, 1, 2);
            break;
      }
   }
   g_dcResBar = RPlatResName("DCBAR");
   g_dcObjBar = RPlatObjName("DCBAR");
   RPlatResourceCreate(g_dcResBar, g_dcBar, g_dcBarW, g_dcBarH);
   DCBarPlace();
}
// Positions the plate, and NOTHING else. Split from the paint because the chart
// fires CHART_CHANGE on every wheel notch: re-rastering the icons and uploading
// the bitmap for a scroll would put four kernel calls per notch on the one path
// this whole rewrite exists to keep free. A move that lands on the same pixel
// costs one ObjectFind.
void DCBarPlace()
{
   if(g_dcObjBar == "" || g_dcBarW <= 0) return;
   //--- bottom-left: the object's corner stays LEFT_UPPER (the platform helper's
   //--- own convention), so the distance is measured from the chart's bottom.
   //--- The resolved origin is kept, because the hit test must answer in the same
   //--- pixels the plate was drawn at — recomputing it there would drift by the
   //--- chart height the moment a resize lands between a draw and a click.
   const int ch = RPlatChartH();
   const int px = DC_BAR_X;
   const int py = (ch > g_dcBarH) ? (ch - DC_BAR_Y - g_dcBarH) : DC_BAR_Y;
   if(ObjectFind(0, g_dcObjBar) < 0)
   {
      g_dcBarPx = px; g_dcBarPy = py;
      RPlatLayerCreate(g_dcObjBar, g_dcResBar, px, py, g_dcBarW, g_dcBarH, false, 3);
      return;
   }
   if(px == g_dcBarPx && py == g_dcBarPy) return;   // already standing there
   g_dcBarPx = px; g_dcBarPy = py;
   ObjectSetInteger(0, g_dcObjBar, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, g_dcObjBar, OBJPROP_YDISTANCE, py);
}
int DCBarHit(const int x, const int y)
{
   if(x < g_dcBarPx || y < g_dcBarPy) return -1;
   if(x >= g_dcBarPx + g_dcBarW || y >= g_dcBarPy + g_dcBarH) return -1;
   int lx = x - g_dcBarPx - DC_BAR_PAD;
   if(lx < 0) return -1;
   int c = lx / (DC_BAR_CELL + DC_BAR_GAP);
   if(c < 0 || c > DC_TOOL_N) return -1;
   return c;
}

//==================== model edits ===================================
// A tool's own ink, so a page of drawings stays readable before the user has
// picked anything. The colour picker (the reference's swatch row) is the next
// layer on top of this; these are the defaults it will start from.
color DCDefaultInk(const int tool)
{
   switch(tool)
   {
      case DCT_HLINE:
      case DCT_VLINE:   return clrDeepSkyBlue;
      case DCT_RAY:     return clrOrange;
      case DCT_RECT:    return clrDodgerBlue;
      case DCT_FIB:     return clrGold;
      case DCT_ARROW:   return clrLimeGreen;
      case DCT_ELLIPSE: return clrViolet;
      case DCT_POS:     return clrWhite;
      case DCT_CROSS:   return clrSilver;
   }
   return clrGold;   // DCT_TREND
}
int DCAdd(const int tool, const long t1, const double p1, const long t2, const double p2)
{
   int n = ArraySize(g_dc);
   if(ArrayResize(g_dc, n + 1) != n + 1) return -1;
   g_dc[n].id      = g_dcNextId++;
   g_dc[n].tool    = tool;
   g_dc[n].t1      = t1; g_dc[n].p1 = p1;
   g_dc[n].t2      = t2; g_dc[n].p2 = p2;
   g_dc[n].ink     = DCDefaultInk(tool);
   g_dc[n].width   = 1;
   g_dc[n].style   = 0;
   g_dc[n].visible = true;
   g_dcDirty = true;
   return n;
}
void DCDel(const int idx)
{
   int n = ArraySize(g_dc);
   if(idx < 0 || idx >= n) return;
   for(int i = idx; i < n - 1; i++) g_dc[i] = g_dc[i + 1];
   ArrayResize(g_dc, n - 1);
   if(g_dcSel == idx) g_dcSel = -1;
   else if(g_dcSel > idx) g_dcSel--;
   g_dcDirty = true;
}
void DCCancel()
{
   g_dcArmed = DCT_NONE;
   g_dcStage = 0;
   g_dcT1 = 0; g_dcP1 = 0.0;
   g_dcCurOk = false;
   g_dcDragging = false;
   g_dcDragIdx = -1;
   g_dcDragAnchor = -1;
   g_dcSwallow = false;
   DCBarDraw();
   DCRequestFrame();
}

//==================== hit test (pixels, like the strip) =============
int DCHitTest(const int mx, const int my)
{
   DCRefreshStands();   // the same stands the painter used (two chart reads per press)
   int best = -1;
   double bestD = 1e12;
   for(int i = 0; i < ArraySize(g_dc); i++)
   {
      if(!g_dc[i].visible) continue;
      int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
      const bool ok1 = DCAnchorXY(g_dc[i], x1, y1);
      const bool ok2 = DCProject(g_dc[i].t2, g_dc[i].p2, x2, y2);
      if(!ok1) continue;
      double d = 1e12;
      switch(g_dc[i].tool)
      {
         case DCT_TREND: if(ok2) d = DCPointSegPx(mx, my, x1, y1, x2, y2); break;
         case DCT_HLINE: d = MathAbs((double)(my - y1)); break;
         case DCT_VLINE: d = MathAbs((double)(mx - x1)); break;
         case DCT_RAY:
            if(ok2 && x2 != x1)
            {
               double k = (double)(y2 - y1) / (double)(x2 - x1);
               int xr = (x2 >= x1) ? (g_dcW - 1) : 0;
               int yr = y1 + (int)MathRound(k * (double)(xr - x1));
               d = DCPointSegPx(mx, my, x1, y1, xr, yr);
            }
            break;
         case DCT_RECT:
            if(ok2)
            {
               double a = DCPointSegPx(mx, my, x1, y1, x2, y1);
               double b = DCPointSegPx(mx, my, x2, y1, x2, y2);
               double c = DCPointSegPx(mx, my, x2, y2, x1, y2);
               double e = DCPointSegPx(mx, my, x1, y2, x1, y1);
               d = MathMin(MathMin(a, b), MathMin(c, e));
            }
            break;
         case DCT_FIB:
            if(ok2)
            {
               const double r[7] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
               for(int k = 0; k < 7; k++)
               {
                  double p = g_dc[i].p1 + (g_dc[i].p2 - g_dc[i].p1) * r[k];
                  int xa = 0, ya = 0;
                  if(!DCProject(g_dc[i].t1, p, xa, ya)) continue;
                  double dd = MathAbs((double)(my - ya));
                  if(mx < MathMin(x1, x2) || mx > MathMax(x1, x2)) dd += 1000.0;
                  if(dd < d) d = dd;
               }
            }
            break;
         case DCT_ARROW:
            if(ok2) d = DCPointSegPx(mx, my, x1, y1, x2, y2);
            break;
         case DCT_ELLIPSE:
            if(ok2)
            {
               //--- the ellipse's own outline, not its box: a bounding-box test
               //--- would grab empty corners and let the real rim go untouched
               const int cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
               const int rx = (x1 > x2 ? x1 - x2 : x2 - x1) / 2;
               const int ry = (y1 > y2 ? y1 - y2 : y2 - y1) / 2;
               if(rx > 0 && ry > 0)
               {
                  const double nx = (double)(mx - cx) / (double)rx;
                  const double ny = (double)(my - cy) / (double)ry;
                  const double rho = MathSqrt(nx * nx + ny * ny);
                  const double scale = (double)((rx < ry) ? rx : ry);
                  d = MathAbs(rho - 1.0) * scale;
               }
            }
            break;
         case DCT_POS:
            if(ok2)
            {
               const int yT = y1 - 2 * (y2 - y1);
               double a = DCPointSegPx(mx, my, x1, y1, x2, y1);
               double b = DCPointSegPx(mx, my, x1, y2, x2, y2);
               double c = DCPointSegPx(mx, my, x1, yT, x2, yT);
               d = MathMin(MathMin(a, b), c);
            }
            break;
         case DCT_CROSS:
         {
            double a = MathAbs((double)(my - y1));
            double b = MathAbs((double)(mx - x1));
            d = MathMin(a, b);
            break;
         }
      }
      if(d <= (double)DC_GRAB_PX && d < bestD) { bestD = d; best = i; }
   }
   return best;
}
// Which ANCHOR the press landed on, if any. Tried before DCHitTest because an
// endpoint is the more specific target: with the body test first, the last few
// pixels of every line would drag the whole shape instead of bending it.
//   which: 0 = first anchor, 1 = second anchor
int DCHitAnchor(const int mx, const int my, int &which)
{
   which = -1;
   DCRefreshStands();
   int best = -1;
   double bestD = (double)(DC_HANDLE_PX + 5);
   for(int i = 0; i < ArraySize(g_dc); i++)
   {
      if(!g_dc[i].visible) continue;
      int x1 = 0, y1 = 0, x2 = 0, y2 = 0;
      if(DCAnchorXY(g_dc[i], x1, y1))
      {
         double d = DCPointPtPx(mx, my, x1, y1);
         if(d < bestD) { bestD = d; best = i; which = 0; }
      }
      if(g_dc[i].tool != DCT_HLINE && g_dc[i].tool != DCT_VLINE &&
         g_dc[i].tool != DCT_CROSS && DCProject(g_dc[i].t2, g_dc[i].p2, x2, y2))
      {
         double d = DCPointPtPx(mx, my, x2, y2);
         if(d < bestD) { bestD = d; best = i; which = 1; }
      }
   }
   return best;
}

//==================== persistence ===================================
void DCSave()
{
   int h = FileOpen(DC_FILE, FILE_WRITE | FILE_CSV | FILE_ANSI, ';');
   if(h == INVALID_HANDLE) return;
   FileWrite(h, "id", "tool", "t1", "p1", "t2", "p2", "ink", "width", "style", "visible");
   for(int i = 0; i < ArraySize(g_dc); i++)
      FileWrite(h,
                IntegerToString(g_dc[i].id),
                IntegerToString(g_dc[i].tool),
                IntegerToString((long)g_dc[i].t1),
                DoubleToString(g_dc[i].p1, 8),
                IntegerToString((long)g_dc[i].t2),
                DoubleToString(g_dc[i].p2, 8),
                IntegerToString((long)g_dc[i].ink),
                IntegerToString(g_dc[i].width),
                IntegerToString(g_dc[i].style),
                g_dc[i].visible ? "1" : "0");
   FileClose(h);
   g_dcDirty = false;
}
void DCLoad()
{
   if(!FileIsExist(DC_FILE)) return;
   int h = FileOpen(DC_FILE, FILE_READ | FILE_CSV | FILE_ANSI, ';');
   if(h == INVALID_HANDLE) return;
   ArrayResize(g_dc, 0);
   g_dcNextId = 1;
   bool header = true;
   while(!FileIsEnding(h))
   {
      string a = FileReadString(h);
      if(a == "" ) break;
      string b = FileReadString(h), c = FileReadString(h), d = FileReadString(h);
      string e = FileReadString(h), f = FileReadString(h), g = FileReadString(h);
      string i2 = FileReadString(h), j = FileReadString(h), k = FileReadString(h);
      //--- the column row must be CONSUMED, not skipped with `continue`: a
      //--- `continue` here would leave the reader mid-row and the next pass
      //--- would read "tool" as an id (a drawing at time 0, price 0).
      if(header) { header = false; continue; }
      int n = ArraySize(g_dc);
      if(ArrayResize(g_dc, n + 1) != n + 1) break;
      g_dc[n].id      = (int)StringToInteger(a);
      g_dc[n].tool    = (int)StringToInteger(b);
      g_dc[n].t1      = (long)StringToInteger(c);
      g_dc[n].p1      = StringToDouble(d);
      g_dc[n].t2      = (long)StringToInteger(e);
      g_dc[n].p2      = StringToDouble(f);
      g_dc[n].ink     = (color)StringToInteger(g);
      g_dc[n].width   = (int)StringToInteger(i2);
      g_dc[n].style   = (int)StringToInteger(j);
      g_dc[n].visible = (k != "0");
      if(g_dc[n].id >= g_dcNextId) g_dcNextId = g_dc[n].id + 1;
   }
   FileClose(h);
   g_dcDirty = false;
}

//==================== input =========================================
// The carry ends on the first event that reports the button UP — MT5 has no
// release event of its own, and every other tool in this product learns it the
// same way (PathTool's s_pathPrimed note is the long version).
void DrawCanvasOnRelease()
{
   if(!g_dcDragging) return;
   g_dcDragging = false;
   g_dcDragIdx = -1;
   g_dcDragAnchor = -1;
   g_dcSwallow  = true;   // the CLICK that follows is this gesture's own release
   DCSave();              // one write per gesture — never per frame
   DCRequestFrame();
}
bool DrawCanvasOnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- the chart moved or resized: the buffers must follow it
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      if(g_dcW != RPlatChartW() || g_dcH != RPlatChartH()) { g_dcReady = false; }
      //--- a scroll only MOVES the plate; the icons are unchanged, so only the
      //--- first CHART_CHANGE (before the window was mapped) pays for a raster
      if(g_dcResBar == "") DCBarDraw();
      else                 DCBarPlace();
      DCRequestFrame();
      return false;
   }
   if(id == CHARTEVENT_KEYDOWN)
   {
      if(lparam == 27)   // ESC: a half-drawn gesture first, then the selection
      {
         if(g_dcArmed != DCT_NONE) { DCCancel(); return true; }
         if(g_dcSel >= 0) { g_dcSel = -1; DCRequestFrame(); return true; }
         return false;
      }
      if(lparam == 46)   // DELETE: the selected drawing
      {
         if(g_dcSel >= 0) { DCDel(g_dcSel); DCSave(); DCRequestFrame(); return true; }
         return false;
      }
      return false;
   }
   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      const int mx = (int)lparam, my = (int)dparam;
      const int st = (int)StringToInteger(sparam);
      const bool leftDown = ((st & 1) != 0);
      // P-DRAW-CANVAS: the PRESS EDGE is the grab. MT5's CHARTEVENT_CLICK arrives
      // on the button UP, so a carry started there would begin after the hand had
      // already left — the drawing would sit still and then jump. Same edge test
      // PathTool uses (s_pathLeft / `pressed`), so both tools grab on the same rule.
      const bool pressed = (leftDown && !g_dcLeft);
      g_dcLeft = leftDown;
      //--- a new press is a new gesture: any release-swallow left over from a
      //--- drag that ended outside the chart must not eat this click
      if(pressed) g_dcSwallow = false;
      int sub = 0;
      datetime t = 0; double p = 0.0;
      if(ChartXYToTimePrice(0, mx, my, sub, t, p) && t > 0 && p > 0.0)
      {
         g_dcCurT = (long)t; g_dcCurP = p; g_dcCurOk = true;
      }
      //--- a carry in progress: the drawing follows the hand by DELTA from the
      //--- grab, so a long drag can never accumulate rounding into the anchors
      if(g_dcDragging)
      {
         //--- MT5 has no release event of its own: the first move that reports
         //--- the bit clear IS the release (PathTool's s_pathPrimed note).
         if(!leftDown) { DrawCanvasOnRelease(); return false; }
         if(g_dcCurOk)
         {
            int i = g_dcDragIdx;
            if(i >= 0 && i < ArraySize(g_dc))
            {
               double dp = g_dcCurP - g_dcDragP0;
               long   dt = g_dcCurT - g_dcDragT0;
               //--- one anchor or the whole shape. The delta is always measured
               //--- from the anchors the grab FOUND (g_dcDragT1/P1...), never from
               //--- the live values, so a long carry cannot accumulate drift.
               if(g_dcDragAnchor != 1)
               {
                  g_dc[i].t1 = g_dcDragT1 + dt; g_dc[i].p1 = g_dcDragP1 + dp;
               }
               if(g_dcDragAnchor != 0)
               {
                  g_dc[i].t2 = g_dcDragT2 + dt; g_dc[i].p2 = g_dcDragP2 + dp;
               }
               DCRequestFrame();
            }
         }
         return false;
      }
      //--- press on an anchor bends the drawing; on the body it moves it whole.
      //--- Never while a tool is armed: then the press is the placement gesture
      //--- and the hand is drawing, not editing.
      if(pressed && g_dcArmed == DCT_NONE && g_dcCurOk)
      {
         int which = -1;
         int hit = DCHitAnchor(mx, my, which);
         if(hit < 0) { hit = DCHitTest(mx, my); which = -1; }
         if(hit >= 0)
         {
            g_dcSel        = hit;
            g_dcDragging   = true;
            g_dcDragIdx    = hit;
            g_dcDragAnchor = which;
            g_dcDragT0     = g_dcCurT; g_dcDragP0 = g_dcCurP;
            g_dcDragT1     = g_dc[hit].t1; g_dcDragP1 = g_dc[hit].p1;
            g_dcDragT2     = g_dc[hit].t2; g_dcDragP2 = g_dc[hit].p2;
            DCRequestFrame();
            return false;
         }
      }
      //--- armed: the picture must track the hand even before the first click
      if(g_dcArmed != DCT_NONE && g_dcCurOk) DCRequestFrame();
      return false;
   }
   if(id == CHARTEVENT_CLICK)
   {
      const int mx = (int)lparam, my = (int)dparam;
      //--- the release of a carry: the same gesture, already handled
      if(g_dcSwallow) { g_dcSwallow = false; return true; }
      //--- the palette first: it is a UI surface, never free chart
      int cell = DCBarHit(mx, my);
      if(cell >= 0)
      {
         g_dcArmed = (cell == 0) ? DCT_NONE : cell;
         g_dcStage = 0;
         g_dcT1 = 0; g_dcP1 = 0.0;
         g_dcSel = -1;
         DCBarDraw();
         DCRequestFrame();
         return true;
      }
      int sub = 0;
      datetime t = 0; double p = 0.0;
      if(!ChartXYToTimePrice(0, mx, my, sub, t, p) || t <= 0 || p <= 0.0) return false;
      //--- placing
      if(g_dcArmed != DCT_NONE)
      {
         if(g_dcArmed == DCT_HLINE || g_dcArmed == DCT_VLINE || g_dcArmed == DCT_CROSS)
         {
            DCAdd(g_dcArmed, (long)t, p, (long)t, p);
            g_dcArmed = DCT_NONE;
            g_dcStage = 0;
            DCSave();
            DCBarDraw();
            DCRequestFrame();
            return true;
         }
         if(g_dcStage == 0)
         {
            g_dcT1 = (long)t; g_dcP1 = p; g_dcStage = 1;
            DCRequestFrame();
            return true;
         }
         DCAdd(g_dcArmed, g_dcT1, g_dcP1, (long)t, p);
         g_dcStage = 0;
         g_dcT1 = 0; g_dcP1 = 0.0;
         DCSave();
         DCRequestFrame();
         return true;
      }
      //--- a plain click selects; the grab itself already ran on the press edge
      int hit = DCHitTest(mx, my);
      if(hit >= 0) { g_dcSel = hit; DCRequestFrame(); return true; }
      if(g_dcSel >= 0) { g_dcSel = -1; DCRequestFrame(); }
      return false;
   }
   return false;
}

//==================== lifecycle =====================================
void DrawCanvasInit()
{
   ArrayResize(g_dc, 0);
   g_dcSel = -1;
   g_dcArmed = DCT_NONE;
   g_dcStage = 0;
   g_dcReady = false;
   g_dcDragging = false;
   g_dcDragIdx  = -1;
   g_dcDragAnchor = -1;
   g_dcLeft     = false;
   g_dcSwallow  = false;
   DCLoad();
   DCBarDraw();
   DCRequestFrame();
}
void DrawCanvasDeinit()
{
   if(g_dcDirty) DCSave();
   if(g_dcObjDraw != "") RPlatLayerDelete(g_dcObjDraw);
   if(g_dcObjBar  != "") RPlatLayerDelete(g_dcObjBar);
   //--- the bitmaps go with the objects: a resource that outlives its label is
   //--- memory the next instance re-creates under the same name anyway
   if(g_dcResDraw != "") RPlatResourceFree(g_dcResDraw);
   if(g_dcResBar  != "") RPlatResourceFree(g_dcResBar);
   g_dcReady = false;
   ArrayResize(g_dcPix, 0);
   ArrayResize(g_dcBar, 0);
}

#endif   // BIOTAK_RENDER_ENGINE
#endif   // DRAW_CANVAS_MQH
