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
// family sits BEHIND the candles exactly like its MT4 rectangle/BACK objects,
// while lines and texts ride the front layers above.
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
struct RText { double price;  int x; uint anchor; string text; uint argb; int fontSize; uint fontFlags; string fontName; };
// RZoneObj: a pipeline zone's picture - the fill band plus its own two horizontal
// edge segments (top lit, bottom shaded; the left vertical edge is documented
// out - see RenderBridge). The colours arrive PRE-BLENDED (opaque), exactly the
// colours the MT4 objects carry, so the layer needs no alpha compositing. The
// zone NAME lives in the bridge's recs; the scene is paint-only.
struct RZoneObj { double top; double bottom; uint fillArgb; bool hasFill; uint topArgb; uint botArgb; bool hasEdge; int style; int width; bool visible; };

RLine g_rLines[];
RBand g_rBands[];
RText g_rTexts[];
RZoneObj g_rZones[];
bool  g_rLinesSorted=true;
bool  g_rBandsSorted=true;
int   g_rSceneVer=1;   // the UNDER slot (bands + lines) content version
int   g_rTextsVer=0;   // the TEXT slot content version
int   g_rZonesVer=0;   // the ZONE slot content version

void RSceneClear()
{
   ArrayResize(g_rLines,0); ArrayResize(g_rBands,0); ArrayResize(g_rTexts,0);
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
void RSceneAddText(double price,int x,uint anchor,const string text,uint argb,int fontSize,uint fontFlags,const string fontName="")
{
   int n=ArraySize(g_rTexts);
   if(ArrayResize(g_rTexts,n+1)!=n+1) return;
   g_rTexts[n].price=price; g_rTexts[n].x=x; g_rTexts[n].anchor=anchor;
   g_rTexts[n].text=text;   g_rTexts[n].argb=argb;
   g_rTexts[n].fontSize=fontSize; g_rTexts[n].fontFlags=fontFlags;
   g_rTexts[n].fontName=fontName;
   g_rTextsVer++;
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
string g_rMapStamp="";
double g_rMsRaster=0,g_rMsPresent=0;
int    g_rPaints=0,g_rSkips=0,g_rWants=0;
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

string RFrameKey()
{
   return StringFormat("%d|%d|%.8f|%.8f|%d|%d|%d|%d|%d",
                        g_engW,g_engH,g_rMapPmin,g_rMapPmax,
                        g_rSceneVer,g_rTextsVer,g_rZonesVer,g_rHover,g_rDragIdx);
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
   g_rMapStamp="";
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

void RDrawTexts()
{
   int n=ArraySize(g_rTexts), w=g_engW, h=g_engH;
   for(int i=0;i<n;i++)
   {
      int y=(int)(RPriceToY(g_rTexts[i].price)+0.5);
      if(y<-16||y>h+16) continue;
      int tx=g_rTexts[i].x;
      if(tx<0) tx=w;   // sentinel: the right edge at the CURRENT width
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

bool REnginePaint()
{
   if(!REngineEnsure()) return false;
   RMapUpdate();
   string key=RFrameKey();
   if(key==g_rLastKey){ g_rSkips++; return false; }

   // A moved map (scroll/zoom) or a resize re-maps every pixel: every slot is
   // stale even when its content version did not move.
   string mk=StringFormat("%d|%d|%.8f|%.8f",g_engW,g_engH,g_rMapPmin,g_rMapPmax);
   if(mk!=g_rMapStamp){ g_rMapStamp=mk; g_rUnderPresented=-1; g_rTextsPresented=-1; g_rZonesPresented=-1; }
   // The hover/drag highlight lives in the UNDER slot: moving it dirties that slot.
   if(g_rHover!=g_rLastHoverP || g_rDragIdx!=g_rLastDragP) g_rUnderPresented=-1;

   double t0=RPlatNowMs();
   bool underDirty=(g_rUnderPresented!=g_rSceneVer);
   bool textsDirty=(g_rTextsPresented!=g_rTextsVer);
   bool zonesDirty=(g_rZonesPresented!=g_rZonesVer);
   if(underDirty)
   {
      RBufClear(g_engBg,g_engW*g_engH,0);
      RDrawBands();
      RDrawLines();
   }
   if(zonesDirty)
   {
      RBufClear(g_engZg,g_engW*g_engH,0);
      RDrawZones();
   }
   if(textsDirty)
   {
      RBufClear(g_engFg,g_engW*g_engH,0);
      RDrawTexts();
      if(g_rPaintHook!=NULL) g_rPaintHook.RPaintExt(g_engFg,g_engW,g_engH);
   }
   double t1=RPlatNowMs();

   double t2=RPlatNowMs();
   if(underDirty){ RPlatResourceCreate(g_engResBg,g_engBg,g_engW,g_engH); g_rUnderPresented=g_rSceneVer; g_rBgPresents++; }
   else g_rBgSkips++;
   if(textsDirty) { RPlatResourceCreate(g_engResFg,g_engFg,g_engW,g_engH); g_rTextsPresented=g_rTextsVer; }
   if(zonesDirty) { RPlatResourceCreate(g_engResZg,g_engZg,g_engW,g_engH); g_rZonesPresented=g_rZonesVer; }
   RPlatRedraw();
   double t3=RPlatNowMs();

   g_rMsRaster=t1-t0; g_rMsPresent=t3-t2;
   g_rLastKey=key; g_rPaints++;
   g_rLastHoverP=g_rHover; g_rLastDragP=g_rDragIdx;
   RAdaptivePeriod();
   return true;
}

#endif
