//+------------------------------------------------------------------+
//|  RenderCore.mqh - Biotak render engine, layers 1..3 (MT5-ONLY)   |
//|  [1] Raster  : clip-aware pixel ops (fill/line/clear/blend)      |
//|  [2] Scene   : flat sorted arrays (serializable, unbounded N)    |
//|  [3] Painter : price->pixel map, frameKey/Skip, timer coalescing |
//|  Law 0: per-frame cost = f(output surface); N never in hot path. |
//+------------------------------------------------------------------+
#ifndef RENDER_CORE_MQH
#define RENDER_CORE_MQH
#include "RenderPlatform.mqh"

//==================== canvas identity (3 layers) ====================
// Zg = the ZONE layer: BACK=true, z=0 (the product's Z_CHART_ZONE) - the zone
// family AND the pattern's fill band sit BEHIND the candles. P-TH3-ZONE-07
// (2026-10-17): the band used to ride the FRONT slot and its opaque fill
// covered every candle inside it («کندل ها داخل ناحیه رنگی دیده نمیشه»); the
// line/text families stay on the front layers above.
uint   g_engFg[];
uint   g_engBg[];
uint   g_engZg[];
int    g_engW=0,g_engH=0;
bool   g_engReady=false;
string g_engResFg="",g_engResBg="",g_engResZg="",g_engObjFg="",g_engObjBg="",g_engObjZg="";

//==================== [2] Scene =====================================
// RLine.style is ENUM_LINE_STYLE as int (0=SOLID .. 4=DASHDOTDOT); the engine
// approximates the platform's dash patterns (they differ between MT4/MT5 anyway).
// RText.x sentinel: x<0 = "ride the right edge" (x resolved to the CURRENT width
// at draw time, so a resize never leaves a stale coordinate in the scene).
struct RLine { double price; uint argb; int width; int style; };
struct RBand { double p0;     double p1;  uint argb; };
// RText.t>0 = the text anchors to a TIME (the pattern family's labels); the
// pixel is resolved at draw time, so scroll/zoom never leaves a stale x behind.
// t=0 keeps the ladder convention: price + the x sentinel (x<0 = right edge).
struct RText { double price;  int x; uint anchor; string text; uint argb; int fontSize; uint fontFlags; string fontName; long t; bool visible; };
// RSeg: a segment between two (time,price) anchors - the pattern skeleton's
// primitive (AB/BC/CD, the fibo legs, target/zone border rays). rayRight
// stretches point 2 to the right edge along the same slope (the object path's
// OBJPROP_RAY_RIGHT). Segments ride the FRONT slot (with the texts): one drag
// move re-rasterizes a few strokes and a few labels, never the ladder rungs.
struct RSeg { long t1; double p1; long t2; double p2; uint argb; int width; int style; bool rayRight; bool visible; };
// RPatBand: the pattern zone's time-bounded fill (the FILLED style's rectangle,
// with RAY_RIGHT semantics). P-TH3-ZONE-07: rides the ZONE slot (BACK=true,
// behind the candles) - the front slot's opaque fill hid every candle inside
// the band («کندل ها داخل ناحیه رنگی دیده نمیشه»). Bands are time-anchored, so
// a horizontal scroll re-rasters the zone slot along with the front.
struct RPatBand { long t0; long t1; double p0; double p1; uint argb; bool rayRight; bool visible; };
// RPatDot: the mother-pivot Head/Tail markers (OBJ_ARROW 159's filled circle).
struct RPatDot { long t; double p; int radius; uint argb; bool visible; };
// RZoneObj: a pipeline zone's picture - the fill band plus its own two horizontal
// edge segments (top lit, bottom shaded; the left vertical edge is documented
// out - see RenderBridge). The colours arrive PRE-BLENDED (opaque), exactly the
// colours the MT4 objects carry, so the layer needs no alpha compositing. The
// zone NAME lives in the bridge's recs; the scene is paint-only.
struct RZoneObj { double top; double bottom; uint fillArgb; bool hasFill; uint topArgb; uint botArgb; bool hasEdge; int style; int width; bool visible; };

RLine g_rLines[];
RBand g_rBands[];
RText g_rTexts[];
RSeg  g_rSegs[];
RPatBand g_rPatBands[];
RPatDot  g_rPatDots[];
RZoneObj g_rZones[];
bool  g_rLinesSorted=true;
bool  g_rBandsSorted=true;
int   g_rSceneVer=1;   // the UNDER slot (bands + lines) content version
int   g_rTextsVer=0;   // the FRONT slot content version (texts + segments)
int   g_rZonesVer=0;   // the ZONE slot content version

void RSceneClear()
{
   ArrayResize(g_rLines,0); ArrayResize(g_rBands,0); ArrayResize(g_rTexts,0);
   ArrayResize(g_rSegs,0); ArrayResize(g_rPatBands,0); ArrayResize(g_rPatDots,0);
   ArrayResize(g_rZones,0);
   g_rLinesSorted=true; g_rBandsSorted=true;
   g_rSceneVer++; g_rTextsVer++; g_rZonesVer++;
}
void RSceneReserveLines(int n){ ArrayResize(g_rLines,0,n+16); }
void RSceneReserveBands(int n){ ArrayResize(g_rBands,0,n+16); }

void RSceneAddLine(double price,uint argb,int width=1,int style=0)
{
   int n=ArraySize(g_rLines);
   if(n>0 && g_rLinesSorted && g_rLines[n-1].price>price) g_rLinesSorted=false;
   if(ArrayResize(g_rLines,n+1)!=n+1) return;
   g_rLines[n].price=price; g_rLines[n].argb=argb; g_rLines[n].width=width; g_rLines[n].style=style;
   g_rSceneVer++;
}
void RSceneAddBand(double p0,double p1,uint argb)
{
   if(p0>p1){ double t=p0; p0=p1; p1=t; }
   int n=ArraySize(g_rBands);
   if(n>0 && g_rBandsSorted && g_rBands[n-1].p0>p0) g_rBandsSorted=false;
   if(ArrayResize(g_rBands,n+1)!=n+1) return;
   g_rBands[n].p0=p0; g_rBands[n].p1=p1; g_rBands[n].argb=argb;
   g_rSceneVer++;
}
void RSceneAddText(double price,int x,uint anchor,const string text,uint argb,int fontSize,uint fontFlags,const string fontName="",const long t=0)
{
   int n=ArraySize(g_rTexts);
   if(ArrayResize(g_rTexts,n+1)!=n+1) return;
   g_rTexts[n].price=price; g_rTexts[n].x=x; g_rTexts[n].anchor=anchor;
   g_rTexts[n].text=text;   g_rTexts[n].argb=argb;
   g_rTexts[n].fontSize=fontSize; g_rTexts[n].fontFlags=fontFlags;
   g_rTexts[n].fontName=fontName; g_rTexts[n].t=t;
   g_rTexts[n].visible=true;
   g_rTextsVer++;
}
void RSceneSetSegs(RSeg &src[],int count)
{
   ArrayResize(g_rSegs,count);
   for(int i=0;i<count;i++) g_rSegs[i]=src[i];
   g_rTextsVer++;   // the FRONT slot version owns the segment family too
}
void RSceneSetPatBands(RPatBand &src[],int count)
{
   ArrayResize(g_rPatBands,count);
   for(int i=0;i<count;i++) g_rPatBands[i]=src[i];
   g_rZonesVer++;   // P-TH3-ZONE-07: the ZONE slot version owns the band family now
}
void RSceneSetPatDots(RPatDot &src[],int count)
{
   ArrayResize(g_rPatDots,count);
   for(int i=0;i<count;i++) g_rPatDots[i]=src[i];
   g_rTextsVer++;   // and the dot family
}

// WHOLESALE REPLACEMENT (the bridge's commit): the owner of a family computes
// the new array off-scene and lands it in one call. No incremental edits, no
// per-element bookkeeping — one version bump, sortedness re-checked once.
void RSceneSetLines(RLine &src[],int count)
{
   ArrayResize(g_rLines,count);
   for(int i=0;i<count;i++) g_rLines[i]=src[i];
   bool sorted=true;
   for(int i=1;i<count;i++) if(g_rLines[i-1].price>g_rLines[i].price){ sorted=false; break; }
   g_rLinesSorted=sorted;
   g_rSceneVer++;
}
void RSceneSetTexts(RText &src[],int count)
{
   ArrayResize(g_rTexts,count);
   for(int i=0;i<count;i++) g_rTexts[i]=src[i];
   g_rTextsVer++;
}
void RSceneSetZones(RZoneObj &src[],int count)
{
   ArrayResize(g_rZones,count);
   for(int i=0;i<count;i++) g_rZones[i]=src[i];
   g_rZonesVer++;
}

int RSceneMoveLine(int idx,double newPrice)
{
   int n=ArraySize(g_rLines);
   if(idx<0||idx>=n) return -1;
   g_rLines[idx].price=newPrice;
   while(idx>0 && g_rLines[idx-1].price>newPrice)
   { RLine t=g_rLines[idx-1]; g_rLines[idx-1]=g_rLines[idx]; g_rLines[idx]=t; idx--; }
   while(idx+1<n && g_rLines[idx+1].price<newPrice)
   { RLine t=g_rLines[idx+1]; g_rLines[idx+1]=g_rLines[idx]; g_rLines[idx]=t; idx++; }
   g_rSceneVer++;
   return idx;
}

void RSortLinesByPrice()
{
   int n=ArraySize(g_rLines);
   for(int gap=n/2; gap>0; gap/=2)
      for(int i=gap;i<n;i++)
      {
         RLine tmp=g_rLines[i];
         int j=i;
         while(j>=gap && g_rLines[j-gap].price>tmp.price){ g_rLines[j]=g_rLines[j-gap]; j-=gap; }
         g_rLines[j]=tmp;
      }
   g_rLinesSorted=true;
}
void RSortBandsByP0()
{
   int n=ArraySize(g_rBands);
   for(int gap=n/2; gap>0; gap/=2)
      for(int i=gap;i<n;i++)
      {
         RBand tmp=g_rBands[i];
         int j=i;
         while(j>=gap && g_rBands[j-gap].p0>tmp.p0){ g_rBands[j]=g_rBands[j-gap]; j-=gap; }
         g_rBands[j]=tmp;
      }
   g_rBandsSorted=true;
}

int RLowerBoundLine(double p)
{
   int n=ArraySize(g_rLines), lo=0, hi=n-1, res=n;
   while(lo<=hi){ int m=(lo+hi)>>1; if(g_rLines[m].price<p) lo=m+1; else { res=m; hi=m-1; } }
   return res;
}
int RUpperBoundLine(double p)
{
   int n=ArraySize(g_rLines), lo=0, hi=n-1, res=n;
   while(lo<=hi){ int m=(lo+hi)>>1; if(g_rLines[m].price<=p) lo=m+1; else { res=m; hi=m-1; } }
   return res;
}
int RLowerBoundBand(double p)
{
   int n=ArraySize(g_rBands), lo=0, hi=n-1, res=n;
   while(lo<=hi){ int m=(lo+hi)>>1; if(g_rBands[m].p0<p) lo=m+1; else { res=m; hi=m-1; } }
   return res;
}
int RNearestLineIndex(double price)
{
   int n=ArraySize(g_rLines);
   if(n==0) return -1;
   if(!g_rLinesSorted) RSortLinesByPrice();
   int lb=RLowerBoundLine(price);
   int best=-1; double bd=1e300;
   if(lb<n){ bd=MathAbs(g_rLines[lb].price-price); best=lb; }
   if(lb>0){ double d=MathAbs(g_rLines[lb-1].price-price); if(d<bd) best=lb-1; }
   return best;
}

//==================== [1] Raster (clip-aware) =======================
uint RCol(color clr,int alpha=255){ return ColorToARGB(clr,(uchar)alpha); }

void RBufClear(uint &buf[],int total,uint argb)
{
   if(total>0) ArrayFill(buf,0,total,argb);
}
void RFillRect(uint &buf[],int w,int h,int x0,int y0,int x1,int y1,uint argb)
{
   if(x0<0) x0=0; if(y0<0) y0=0;
   if(x1>w-1) x1=w-1; if(y1>h-1) y1=h-1;
   if(x0>x1||y0>y1) return;
   if(x0==0 && x1==w-1){ ArrayFill(buf,y0*w,(y1-y0+1)*w,argb); return; }
   for(int y=y0;y<=y1;y++)
   {
      int base=y*w;
      for(int x=x0;x<=x1;x++) buf[base+x]=argb;
   }
}
bool RTextBlit(uint &buf[],int w,int h,const string text,int x,int y,uint anchor,uint argb,int fontSize,uint fontFlags,const string fontName="")
{
   if(text=="") return false;
   if(!RPlatTextSetFont(fontName==""?"Arial":fontName,fontSize,fontFlags,0)) return false;
   return RPlatTextOut(text,x,y,anchor,buf,w,h,argb);
}

class IRPaintHook
{
public:
   virtual void RPaintExt(uint &fg[],int w,int h){}
};
IRPaintHook *g_rPaintHook=NULL;

//==================== [3] Painter ===================================
// Slot semantics: the "under" slot (g_engBg bitmap) carries bands + lines, the
// "text" slot (g_engFg bitmap) carries texts + the paint hook. Each slot has its
// own content version, so a level commit repaints only the slot it touched.
string g_rLastKey="";
// P-PERF-119c: the bucket the PRESENTED raster carries (not "the last bucket
// seen" - a scroll ride below leaves it behind on purpose) plus the scroll
// detector. g_rHaveBucket=false until the first raster of an instance/size.
long   g_rPmn=0,g_rPmx=0;
bool   g_rHaveBucket=false;
uint   g_rTimeMovedMs=0;
const uint SCROLL_SETTLE_MS=2000;   // quiet time after the last time-axis move
const long SCROLL_SLACK_PX=3;       // in-motion map drift the raster rides out
string g_rTimeStamp="";   // the time axis (horizontal scroll/zoom): the pattern
                          // family's segments/labels are the only time-anchored
                          // pixels, so a move dirties the FRONT slot alone
double g_rMsRaster=0,g_rMsPresent=0;
int    g_rPaints=0,g_rSkips=0,g_rWants=0,g_rNoops=0;
int    g_rPeriodMs=15;
bool   g_rWant=false;
bool   g_engManageTimer=false;   // spike=true (owns the timer); product=false (250 ms product timer)
bool   g_engUnderBack=true;      // spike keeps bands behind candles; the product's lines ride FRONT
int    g_engUnderZ=0,g_engTextZ=1;
int    g_rHover=-1,g_rDragIdx=-1;
int    g_rVisible=0,g_rDrawn=0,g_rStride=1;
int    g_rBandsVisible=0,g_rBandsDrawn=0,g_rBandStride=1;
int    g_rUnderPresented=-1,g_rTextsPresented=-1,g_rZonesPresented=-1;
int    g_rBgPresents=0,g_rBgSkips=0;
int    g_rLastHoverP=-1,g_rLastDragP=-1;
double g_rMapPmin=0,g_rMapPmax=1,g_rMapK=1;

double RPriceToY(double p){ return (g_rMapPmax-p)*g_rMapK; }
double RYToPrice(double y){ return g_rMapPmax - (g_rMapK>0 ? y/g_rMapK : 0); }
void RMapUpdate()
{
   g_rMapPmin=RPlatPriceMin();
   g_rMapPmax=RPlatPriceMax();
   double d=g_rMapPmax-g_rMapPmin;
   if(d<=0) d=1;
   g_rMapK=(double)(g_engH-1)/d;
}

// P-PERF-119 (2026-10-17, user: «موقعی که چارت رو اسکرول میکنم به عقب و جلو،
// هی سطوح اپدیت میشه؛ تو متاتریدر ۴ اصلاً اینطوری نیست»): the map's fingerprint
// is the RASTER's, not the raw scale. Every live scroll step re-fits the
// auto-scale by a fraction of a pixel (the measured 1-point ≈ 0.3-0.4 px
// drift), and the old %.8f prices made each of those a NEW key - the frame
// re-rastered and re-uploaded all three layers and paid a full-chart redraw
// for a picture that did not move by one row. One pixel of price is the
// quantum: under it the raster already holds the frame this map would paint
// (the same ±1 px the native object path lives within), past it the frame is
// owed a re-map. The raster itself still uses the raw map (RMapUpdate).
//
// P-PERF-119b: THE QUANTUM MUST GUARD BOTH SIDES OF THE GATE. The first cut
// quantized the KEY but left the slot invalidation below it on the raw stamp -
// so the moment the key moved for ANY reason (and every scroll step moves the
// time axis), the raw stamp re-invalidated all three slots and the storm
// survived the gate. This bucket is now the single map fingerprint for both.
string RMapBucketKey(long &pmn,long &pmx)
{
   double d=g_rMapPmax-g_rMapPmin;
   if(d<=0) d=1;
   double q=d/(double)(g_engH>1?g_engH-1:1);
   pmn=(long)MathRound(g_rMapPmin/q);
   pmx=(long)MathRound(g_rMapPmax/q);
   return StringFormat("%d|%d|%I64d|%I64d",g_engW,g_engH,pmn,pmx);
}

string RFrameKey(const string mk)
{
   return mk
          +StringFormat("|%d|%d|%d|%d|%d",
                        g_rSceneVer,g_rTextsVer,g_rZonesVer,g_rHover,g_rDragIdx)
          +"|"+IntegerToString(RPlatTimeAxisStamp());
}

bool REngineResize()
{
   int w=RPlatChartW(), h=RPlatChartH();
   if(w<=0||h<=0) return false;
   g_engW=w; g_engH=h;
   g_engResFg=RPlatResName("FG"); g_engResBg=RPlatResName("BG"); g_engResZg=RPlatResName("ZG");
   g_engObjFg=RPlatObjName("FG"); g_engObjBg=RPlatObjName("BG"); g_engObjZg=RPlatObjName("ZG");
   if(ArrayResize(g_engFg,w*h)!=w*h) return false;
   if(ArrayResize(g_engBg,w*h)!=w*h) return false;
   if(ArrayResize(g_engZg,w*h)!=w*h) return false;
   RBufClear(g_engFg,w*h,0); RBufClear(g_engBg,w*h,0); RBufClear(g_engZg,w*h,0);
   bool okFg=RPlatResourceCreate(g_engResFg,g_engFg,w,h);
   bool okBg=RPlatResourceCreate(g_engResBg,g_engBg,w,h);
   bool okZg=RPlatResourceCreate(g_engResZg,g_engZg,w,h);
   if(!g_engReady)
   {
      RPlatLayerCreate(g_engObjBg,g_engResBg,0,0,w,h,g_engUnderBack,g_engUnderZ);
      RPlatLayerCreate(g_engObjFg,g_engResFg,0,0,w,h,false,g_engTextZ);
      // the zone layer is BACK (behind the candles) at z=0 == the product's
      // Z_CHART_ZONE, one rung under the under slot's ladder lines
      RPlatLayerCreate(g_engObjZg,g_engResZg,0,0,w,h,true,0);
      g_engReady=true;
   }
   else
   {
      RPlatLayerRefresh(g_engObjBg,g_engResBg,w,h);
      RPlatLayerRefresh(g_engObjFg,g_engResFg,w,h);
      RPlatLayerRefresh(g_engObjZg,g_engResZg,w,h);
   }
   g_rUnderPresented=-1;
   g_rTextsPresented=-1;
   g_rZonesPresented=-1;
   g_rHaveBucket=false;
   g_rTimeMovedMs=0;
   g_rTimeStamp="";
   g_rLastKey="";
   return okFg && okBg && okZg;
}
bool REngineEnsure()
{
   int w=RPlatChartW(), h=RPlatChartH();
   if(w<=0||h<=0) return false;
   if(!g_engReady || w!=g_engW || h!=g_engH) return REngineResize();
   return true;
}
void REngineShutdown()
{
   if(g_engReady)
   {
      RPlatLayerDelete(g_engObjFg);
      RPlatLayerDelete(g_engObjBg);
      RPlatLayerDelete(g_engObjZg);
   }
   RPlatResourceFree(g_engResFg);
   RPlatResourceFree(g_engResBg);
   RPlatResourceFree(g_engResZg);
   g_engReady=false;
}

void RDrawBands()
{
   int n=ArraySize(g_rBands), w=g_engW, h=g_engH;
   g_rBandsVisible=0; g_rBandsDrawn=0; g_rBandStride=1;
   if(n==0) return;
   if(!g_rBandsSorted) RSortBandsByP0();
   double pBot=RYToPrice((double)(h-1)+2.0), pTop=RYToPrice(-2.0);
   int i0=RLowerBoundBand(pBot);
   while(i0>0 && g_rBands[i0-1].p1>=pBot) i0--;
   int j=0;
   for(int i=i0;i<n && g_rBands[i].p0<=pTop;i++) j++;
   g_rBandsVisible=j;
   if(j==0) return;
   int maxDraw=h*2+64;
   if(j>maxDraw) g_rBandStride=(j+maxDraw-1)/maxDraw;
   int drawn=0;
   for(int i=i0,k=0;i<n && g_rBands[i].p0<=pTop;i++,k++)
   {
      if(g_rBandStride>1 && (k%g_rBandStride)!=0) continue;
      int y0=(int)(RPriceToY(g_rBands[i].p1)+0.5);
      int y1=(int)(RPriceToY(g_rBands[i].p0)+0.5);
      if(y1<0||y0>=h) continue;
      RFillRect(g_engBg,w,h,0,y0,w-1,y1,g_rBands[i].argb);
      drawn++;
   }
   g_rBandsDrawn=drawn;
}

// Approximate dash patterns. The platform's own object rendering of
// STYLE_DASH/DOT differs between MT4/MT5 builds anyway; these are the visual
// equivalents at 1 px width. x is the pixel column along the row.
bool RLinePixelOn(const int style,const int x)
{
   if(style<=0) return true;                                   // SOLID
   if(style==1) return ((x%12)<8);                             // DASH
   if(style==2) return ((x%3)==0);                             // DOT
   if(style==3){ int m=x%16; return (m<8)||(m>=11&&m<13); }    // DASHDOT
   if(style==4){ int m=x%22; return (m<8)||(m>=11&&m<13)||(m>=16&&m<18); } // DASHDOTDOT
   return true;
}

void RDrawLines()
{
   int n=ArraySize(g_rLines), w=g_engW, h=g_engH;
   g_rVisible=0; g_rDrawn=0; g_rStride=1;
   if(n==0) return;
   if(!g_rLinesSorted) RSortLinesByPrice();
   double pTop=RYToPrice(-8.0), pBot=RYToPrice((double)(h-1)+8.0);
   int i0=RLowerBoundLine(pBot);
   int i1=RUpperBoundLine(pTop)-1;
   if(i0>i1) return;
   int span=i1-i0+1;
   g_rVisible=span;
   int maxDraw=h*2+64;
   if(span>maxDraw) g_rStride=(span+maxDraw-1)/maxDraw;
   int lastY=-1000000, drawn=0;
   for(int i=i0;i<=i1;i+=g_rStride)
   {
      int yi=(int)(RPriceToY(g_rLines[i].price)+0.5);
      if(yi<0||yi>=h) continue;
      if(yi==lastY) continue;
      int lw=g_rLines[i].width; if(lw<1) lw=1;
      int st=g_rLines[i].style;
      uint argb=g_rLines[i].argb;
      if(st<=0)
         RFillRect(g_engBg,w,h,0,yi,w-1,yi+lw-1,argb);
      else
      {
         for(int y=yi;y<=yi+lw-1;y++)
         {
            if(y<0||y>=h) continue;
            int base=y*w;
            for(int x=0;x<w;x++)
               if(RLinePixelOn(st,x)) g_engBg[base+x]=argb;
         }
      }
      lastY=yi; drawn++;
   }
   g_rDrawn=drawn;
   int hl=(g_rDragIdx>=0)?g_rDragIdx:g_rHover;
   if(hl>=0 && hl<n)
   {
      int yi=(int)(RPriceToY(g_rLines[hl].price)+0.5);
      if(yi>=0&&yi<h) RFillRect(g_engBg,w,h,0,yi-1,w-1,yi+1,RCol(clrOrange,255));
   }
}

// one horizontal line row (the zone edges wear the same style/width treatment
// as every ladder line - one raster convention, one look)
void RPlotRow(uint &buf[],const int y,const uint argb,const int style,const int width)
{
   int lw=width; if(lw<1) lw=1;
   if(style<=0)
      RFillRect(buf,g_engW,g_engH,0,y,g_engW-1,y+lw-1,argb);
   else
   {
      for(int yy=y;yy<=y+lw-1;yy++)
      {
         if(yy<0||yy>=g_engH) continue;
         int base=yy*g_engW;
         for(int x=0;x<g_engW;x++)
            if(RLinePixelOn(style,x)) buf[base+x]=argb;
      }
   }
}

// The zone family paints in the SCENE's own order - MT4's equal-zorder rule:
// band first, its edges next, then the next zone. Zones sit on the BACK layer,
// so this never touches the front slots.
void RDrawZones()
{
   int n=ArraySize(g_rZones), w=g_engW, h=g_engH;
   for(int i=0;i<n;i++)
   {
      if(!g_rZones[i].visible) continue;
      if(g_rZones[i].top<=g_rZones[i].bottom) continue;
      int y0=(int)(RPriceToY(g_rZones[i].top)+0.5);
      int y1=(int)(RPriceToY(g_rZones[i].bottom)+0.5);
      if(y1<0||y0>=h) continue;
      if(g_rZones[i].hasFill)
         RFillRect(g_engZg,w,h,0,y0,w-1,y1,g_rZones[i].fillArgb);
      if(g_rZones[i].hasEdge)
      {
         RPlotRow(g_engZg,y0,g_rZones[i].topArgb,g_rZones[i].style,g_rZones[i].width);
         RPlotRow(g_engZg,y1,g_rZones[i].botArgb,g_rZones[i].style,g_rZones[i].width);
      }
   }
}

// One segment stroke into the FRONT buffer: dominant-axis stepping keeps the
// gap <= 1 px on either slope, width grows downward like the object path's
// trendlines do, style reuses the ladder's dash approximator (path length, px).
void RPlotSeg(const int x1,const int y1,const int x2,const int y2,
              const uint argb,const int width,const int style)
{
   int lw=width; if(lw<1) lw=1;
   int dx=x2-x1, dy=y2-y1;
   int adx=(dx<0?-dx:dx), ady=(dy<0?-dy:dy);
   int steps=(adx>ady)?adx:ady;
   if(steps<=0)
   {
      if(x1<0||x1>=g_engW) return;
      for(int k=0;k<lw;k++)
      { int yy=y1+k; if(yy>=0&&yy<g_engH) g_engFg[yy*g_engW+x1]=argb; }
      return;
   }
   const double sx=(double)dx/(double)steps, sy=(double)dy/(double)steps;
   for(int s=0;s<=steps;s++)
   {
      if(style>0 && !RLinePixelOn(style,s)) continue;
      int x=x1+(int)MathRound(sx*(double)s);
      if(x<0||x>=g_engW) continue;
      int y=y1+(int)MathRound(sy*(double)s);
      for(int k=0;k<lw;k++)
      {
         int yy=y+k;
         if(yy<0||yy>=g_engH) continue;
         g_engFg[yy*g_engW+x]=argb;
      }
   }
}

// One filled dot into the FRONT buffer (the mother pivot's Head/Tail markers):
// row spans of the midpoint circle - the arrow-159 glyph it replaces.
void RPlotDot(const int x,const int y,const int r,const uint argb)
{
   for(int dy=-r;dy<=r;dy++)
   {
      const int yy=y+dy;
      if(yy<0||yy>=g_engH) continue;
      const int dx=(int)(MathSqrt((double)(r*r-dy*dy))+0.5);
      int x0=x-dx,x1=x+dx;
      if(x0<0)x0=0; if(x1>g_engW-1)x1=g_engW-1;
      for(int xx=x0;xx<=x1;xx++) g_engFg[yy*g_engW+xx]=argb;
   }
}

void RDrawSegs()
{
   const int n=ArraySize(g_rSegs), w=g_engW;
   for(int i=0;i<n;i++)
   {
      if(!g_rSegs[i].visible) continue;
      if(g_rSegs[i].t1<=0 || g_rSegs[i].t2<=0) continue;
      int x1=0,y1=0,x2=0,y2=0;
      const bool ok1=RPlatTimePriceToXY(g_rSegs[i].t1,g_rSegs[i].p1,x1,y1);
      const bool ok2=RPlatTimePriceToXY(g_rSegs[i].t2,g_rSegs[i].p2,x2,y2);
      if(!ok1 && !ok2) continue;
      // A FLAT segment (the pattern's rays and zone borders) may hang an anchor
      // past the time scale: keep the resolvable end and clamp the other to its
      // edge - the object path's off-chart anchor clips the same way. Non-flat
      // legs only sit between past bars, so they resolve; one that does not
      // still draws nothing, exactly like the object it mirrors.
      if(!ok1)
      {
         if(g_rSegs[i].p1!=g_rSegs[i].p2) continue;
         y1=y2;
         x1=(g_rSegs[i].t1<g_rSegs[i].t2)?0:w-1;
      }
      if(!ok2)
      {
         if(g_rSegs[i].p1!=g_rSegs[i].p2) continue;
         y2=y1;
         x2=(g_rSegs[i].t2>g_rSegs[i].t1)?w-1:0;
      }
      if(g_rSegs[i].rayRight && x2!=x1)
      {
         const double k=(double)(y2-y1)/(double)(x2-x1);
         x2=w-1;
         y2=y1+(int)MathRound(k*(double)(x2-x1));
      }
      RPlotSeg(x1,y1,x2,y2,g_rSegs[i].argb,g_rSegs[i].width,g_rSegs[i].style);
   }
}

// The pattern zone's fill: from x(t0) to the ray's edge (or x(t1)). A band
// whose start time is off the time scale draws nothing (its object would sit
// entirely off-chart too); an end past the scale becomes the right edge,
// which is what RAY_RIGHT buys on the object path.
// P-TH3-ZONE-07: painted into the ZONE buffer - behind the candles, exactly
// like the pipeline zones beside it.
void RDrawPatBands()
{
   const int n=ArraySize(g_rPatBands), w=g_engW, h=g_engH;
   for(int i=0;i<n;i++)
   {
      if(!g_rPatBands[i].visible) continue;
      double p0=g_rPatBands[i].p0, p1=g_rPatBands[i].p1;
      if(p0<p1){ const double tp=p0; p0=p1; p1=tp; }
      int y0=(int)(RPriceToY(p0)+0.5), y1=(int)(RPriceToY(p1)+0.5);
      if(y1<0||y0>=h) continue;
      int x0=0,ty=0;
      if(!RPlatTimePriceToXY(g_rPatBands[i].t0,g_rPatBands[i].p0,x0,ty)) continue;
      int x1=w-1;
      if(!g_rPatBands[i].rayRight &&
         !RPlatTimePriceToXY(g_rPatBands[i].t1,g_rPatBands[i].p1,x1,ty)) x1=w-1;
      if(x1<0||x0>=w||x1<x0) continue;
      RFillRect(g_engZg,w,h,x0,y0,x1,y1,g_rPatBands[i].argb);
   }
}

void RDrawPatDots()
{
   const int n=ArraySize(g_rPatDots);
   for(int i=0;i<n;i++)
   {
      if(!g_rPatDots[i].visible) continue;
      int x=0,y=0;
      if(!RPlatTimePriceToXY(g_rPatDots[i].t,g_rPatDots[i].p,x,y)) continue;
      RPlotDot(x,y,g_rPatDots[i].radius,g_rPatDots[i].argb);
   }
}

void RDrawTexts()
{
   int n=ArraySize(g_rTexts), w=g_engW, h=g_engH;
   for(int i=0;i<n;i++)
   {
      if(!g_rTexts[i].visible) continue;
      int y=(int)(RPriceToY(g_rTexts[i].price)+0.5);
      if(y<-16||y>h+16) continue;
      int tx=g_rTexts[i].x;
      if(g_rTexts[i].t>0)
      {
         // time-anchored (the pattern family): resolve both axes through the page
         if(!RPlatTimePriceToXY(g_rTexts[i].t,g_rTexts[i].price,tx,y)) continue;
      }
      else if(tx<0) tx=w;   // sentinel: the right edge at the CURRENT width
      RTextBlit(g_engFg,w,h,g_rTexts[i].text,tx,y,
                g_rTexts[i].anchor,g_rTexts[i].argb,
                g_rTexts[i].fontSize,g_rTexts[i].fontFlags,g_rTexts[i].fontName);
   }
}

void RAdaptivePeriod()
{
   if(!g_engManageTimer) return;   // product mode: the 250 ms product timer is not ours to re-arm
   double ms=g_rMsRaster+g_rMsPresent;
   int np=g_rPeriodMs;
   if(ms>40) np=50; else if(ms>22) np=33; else if(ms<8) np=15;
   if(np!=g_rPeriodMs){ g_rPeriodMs=np; RPlatTimerStart(np); }
}

// P-PERF-119: does the FRONT slot hold anything the time axis can move? (a text
// with t>0 is time-anchored; the t<=0 sentinel texts are right-edge, price-only)
bool RHasTimeTexts()
{
   for(int i=ArraySize(g_rTexts)-1;i>=0;i--)
      if(g_rTexts[i].t>0) return true;
   return false;
}

bool REnginePaint()
{
   if(!REngineEnsure()) return false;
   RMapUpdate();
   long pmn=0,pmx=0;
   string mk=RMapBucketKey(pmn,pmx);
   const bool bucketDiffers=(!g_rHaveBucket || pmn!=g_rPmn || pmx!=g_rPmx);
   const uint nowCc=GetTickCount();
   const bool scrollingNow=(g_rTimeMovedMs!=0 && (uint)(nowCc-g_rTimeMovedMs)<SCROLL_SETTLE_MS);
   string key=RFrameKey(mk);
   // the skip is defeated only when the SETTLE both owes and is allowed: the
   // bucket moved off the presented raster and the time axis has gone quiet
   if(key==g_rLastKey && !(bucketDiffers && !scrollingNow))
   { g_rSkips++; return false; }

   // A moved map (scroll/zoom) or a resize re-maps every pixel: every slot is
   // stale even when its content version did not move. A *raster* move is the
   // test (P-PERF-119b) - the same one-pixel quantum the key uses; a raw-scale
   // move smaller than a pixel re-maps nothing the eye can see.
   //
   // P-PERF-119c: this is what a live scroll really looks like - a step every
   // second or two, each re-fitting the auto-scale by a few pixels. Re-rastering
   // all three layers per step IS the "سطوح هی اپدیت میشه" the user sees, and no
   // scroll step is owed that picture: while the time axis is still moving, a
   // bucket move within SCROLL_SLACK_PX rides on the presented raster (the same
   // way the native object path lags a pixel mid-drag and snaps when it stops).
   // The moment the time axis goes quiet the settle below repaints EXACTLY once
   // at the true map, so the rest state is pixel-true as before.
   const bool nearEnough=(g_rHaveBucket &&
                          MathAbs(pmn-g_rPmn)<=SCROLL_SLACK_PX &&
                          MathAbs(pmx-g_rPmx)<=SCROLL_SLACK_PX);
   if(bucketDiffers && !(scrollingNow && nearEnough))
   { g_rUnderPresented=-1; g_rTextsPresented=-1; g_rZonesPresented=-1; }
   // The time axis owns the FRONT slot (segments + time-anchored labels) and,
   // since P-TH3-ZONE-07, the pattern bands on the ZONE slot; the ladder rungs
   // and the pipeline zones do not move with a horizontal scroll.
   string tk=IntegerToString(RPlatTimeAxisStamp());
   const bool timeMoved=(tk!=g_rTimeStamp);
   if(timeMoved)
   {
      g_rTimeStamp=tk;
      g_rTimeMovedMs=nowCc;   // P-PERF-119c: the scroll detector reads this
      // P-PERF-119: invalidate only what the time axis can MOVE. With no pattern
      // staged (no segments, no dots, no time-anchored texts) a pure horizontal
      // pan cannot change one pixel of the front slot; with no pattern bands it
      // cannot touch the zone slot, whose pipeline zones are full-width and
      // price-only. The old unconditional pair re-rastered and re-uploaded the
      // whole zone family on every scroll step for a picture that never moved.
      const bool frontMoves=(ArraySize(g_rSegs)>0 || ArraySize(g_rPatDots)>0 || RHasTimeTexts());
      if(frontMoves) g_rTextsPresented=-1;
      if(ArraySize(g_rPatBands)>0) g_rZonesPresented=-1;
   }
   // The hover/drag highlight lives in the UNDER slot: moving it dirties that slot.
   const bool hlMoved=(g_rHover!=g_rLastHoverP || g_rDragIdx!=g_rLastDragP);
   if(hlMoved) g_rUnderPresented=-1;

   bool underDirty=(g_rUnderPresented!=g_rSceneVer);
   bool frontDirty=(g_rTextsPresented!=g_rTextsVer);
   bool zonesDirty=(g_rZonesPresented!=g_rZonesVer);
   if(!underDirty && !frontDirty && !zonesDirty)
   {
      // P-PERF-119b: the frame key moved but nothing it guards reached the
      // raster - a pan that stayed inside the map's pixel quantum, or a
      // time-axis step with no time-anchored family staged. Consume the key,
      // touch no buffer, ask the terminal for nothing.
      g_rLastKey=key; g_rLastHoverP=g_rHover; g_rLastDragP=g_rDragIdx;
      g_rNoops++;
      return true;
   }
   double t0=RPlatNowMs();
   if(underDirty)
   {
      RBufClear(g_engBg,g_engW*g_engH,0);
      RDrawBands();
      RDrawLines();
   }
   if(zonesDirty)
   {
      RBufClear(g_engZg,g_engW*g_engH,0);
      RDrawPatBands();   // P-TH3-ZONE-07: the pattern fills, behind the candles
      RDrawZones();
   }
   if(frontDirty)
   {
      RBufClear(g_engFg,g_engW*g_engH,0);
      RDrawSegs();
      RDrawPatDots();    // the MP markers over their own bounds
      RDrawTexts();
      if(g_rPaintHook!=NULL) g_rPaintHook.RPaintExt(g_engFg,g_engW,g_engH);
   }
   double t1=RPlatNowMs();

   double t2=RPlatNowMs();
   if(underDirty){ RPlatResourceCreate(g_engResBg,g_engBg,g_engW,g_engH); g_rUnderPresented=g_rSceneVer; g_rBgPresents++; }
   else g_rBgSkips++;
   if(frontDirty) { RPlatResourceCreate(g_engResFg,g_engFg,g_engW,g_engH); g_rTextsPresented=g_rTextsVer; }
   if(zonesDirty) { RPlatResourceCreate(g_engResZg,g_engZg,g_engW,g_engH); g_rZonesPresented=g_rZonesVer; }
   RPlatRedraw();
   double t3=RPlatNowMs();

   // P-PERF-119c: every raster above drew with the CURRENT raw map (RMapUpdate
   // at the top), so what is presented now IS this bucket - whatever rides were
   // in flight are settled by this very frame.
   g_rPmn=pmn; g_rPmx=pmx; g_rHaveBucket=true;

   g_rMsRaster=t1-t0; g_rMsPresent=t3-t2;
   g_rLastKey=key; g_rPaints++;
   g_rLastHoverP=g_rHover; g_rLastDragP=g_rDragIdx;
   RAdaptivePeriod();
   return true;
}

#endif
