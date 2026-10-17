//+------------------------------------------------------------------+
//|  canvas-spike.mq5 - phase-0 spike of the Biotak render engine    |
//|  (MT5-ONLY). Proves: 289 lines / 144 bands / labels mimic, and   |
//|  the 100k-500k element stress mode. Controls: mouse move=hover,  |
//|  drag a line=move it, horizontal pan=Skip, zoom=repaint (HUD).   |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_plots 0

#include "..\Engine\RenderCore.mqh"

input int InpNormalLines = 289;   // normal mode line count
input int InpBands       = 144;   // normal mode band count
input int InpLabelsEvery = 32;    // right-edge label every Nth line
input int InpStressLines = 0;     // >0 = stress mode count (100000 / 500000)
input int InpTimerMs     = 15;    // pump period (ms)

bool   g_spkBuilt=false;
double g_spkBuildMs=0;
int    g_spkMouseX=0,g_spkMouseY=0;
bool   g_spkWasLeft=false;
int    g_spkDragIdx=-1;

void RSpikeWant(){ g_rWant=true; g_rWants++; }

void RSpikeBuildScene()
{
   double pmin=RPlatPriceMin(), pmax=RPlatPriceMax();
   if(pmax<=pmin) return;
   double t0=RPlatNowMs();
   RSceneClear();
   int n=InpStressLines>0 ? InpStressLines : InpNormalLines;
   if(n<2) n=2;
   RSceneReserveLines(n);
   double step=(pmax-pmin)/(double)(n-1);
   for(int i=0;i<n;i++)
   {
      double p=pmin+i*step;
      RSceneAddLine(p,RCol(clrSilver),1);
      if(InpStressLines<=0 && InpLabelsEvery>0 && (i%InpLabelsEvery)==0)
         RSceneAddText(p,g_engW-6,TA_RIGHT|TA_TOP,DoubleToString(p,_Digits),RCol(clrGainsboro,230),-80,FW_NORMAL);
   }
   if(InpStressLines<=0 && InpBands>0)
   {
      RSceneReserveBands(InpBands);
      for(int i=0;i<InpBands && i+1<n;i++)
         RSceneAddBand(pmin+i*step,pmin+(i+1)*step,RCol((i%2==0)?clrTeal:clrDarkOrange,34));
   }
   g_spkBuildMs=RPlatNowMs()-t0;
   g_spkBuilt=true;
   PrintFormat("[SPIKE] built lines=%d bands=%d stress=%d build_ms=%.1f",
               ArraySize(g_rLines),ArraySize(g_rBands),InpStressLines,g_spkBuildMs);
}

void RSpikeDrawHud(uint &fg[],int w,int h)
{
   RFillRect(fg,w,h,8,8,480,124,RCol(clrBlack,150));
   RTextBlit(fg,w,h,StringFormat("SPIKE  lines=%d vis=%d drawn=%d stride=%d  bands vis/drawn/stride=%d/%d/%d",
             ArraySize(g_rLines),g_rVisible,g_rDrawn,g_rStride,
             g_rBandsVisible,g_rBandsDrawn,g_rBandStride),
             14,12,TA_LEFT|TA_TOP,RCol(clrWhite),-80,FW_BOLD);
   RTextBlit(fg,w,h,StringFormat("raster=%.1fms present=%.1fms period=%dms build=%.0fms",
             g_rMsRaster,g_rMsPresent,g_rPeriodMs,g_spkBuildMs),
             14,28,TA_LEFT|TA_TOP,RCol(clrLightGreen),-80,FW_NORMAL);
   RTextBlit(fg,w,h,StringFormat("paint=%d skip=%d want=%d  bg present/skip=%d/%d",
             g_rPaints,g_rSkips,g_rWants,g_rBgPresents,g_rBgSkips),
             14,44,TA_LEFT|TA_TOP,RCol(clrKhaki),-80,FW_NORMAL);
   RTextBlit(fg,w,h,StringFormat("hover=%d drag=%d mouse=(%d,%d) price=%.5f",
             g_rHover,g_rDragIdx,g_spkMouseX,g_spkMouseY,RYToPrice(g_spkMouseY)),
             14,60,TA_LEFT|TA_TOP,RCol(clrLightBlue),-80,FW_NORMAL);
   RTextBlit(fg,w,h,"move=hover  drag line=move  horizontal pan=Skip  zoom=repaint",
             14,84,TA_LEFT|TA_TOP,RCol(clrSilver),-75,FW_NORMAL);
}

class RSpikeHud : public IRPaintHook
{
public:
   virtual void RPaintExt(uint &fg[],int w,int h){ RSpikeDrawHud(fg,w,h); }
};
RSpikeHud *g_spkHud=NULL;

int OnInit()
{
   RPlatEnableMouse(true);
   g_engManageTimer=true;   // the spike owns its own timer; adaptive period stays live
   g_spkHud=new RSpikeHud();
   g_rPaintHook=g_spkHud;
   g_rPeriodMs=InpTimerMs;
   if(!RPlatTimerStart(InpTimerMs)) return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   RPlatTimerStop();
   REngineShutdown();
   g_rPaintHook=NULL;
   if(CheckPointer(g_spkHud)==POINTER_DYNAMIC) delete g_spkHud;
   g_spkHud=NULL;
   ChartRedraw(0);
}

void OnTimer()
{
   if(!g_spkBuilt)
   {
      if(!REngineEnsure()) return;
      RSpikeBuildScene();
      if(!g_spkBuilt) return;
      RSpikeWant();
   }
   if(!g_rWant) return;
   g_rWant=false;
   REnginePaint();
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(prev_calculated==0) RSpikeWant();
   return rates_total;
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE){ RSpikeWant(); return; }
   if(id!=CHARTEVENT_MOUSE_MOVE) return;
   g_spkMouseX=(int)lparam; g_spkMouseY=(int)dparam;
   if(!g_engReady || g_rMapK<=0) return;
   int flags=(int)StringToInteger(sparam);
   bool left=(flags&1)!=0;
   bool changed=false;

   double price=RYToPrice(g_spkMouseY);
   int near=RNearestLineIndex(price);
   int hov=-1;
   if(near>=0)
   {
      double dy=MathAbs(RPriceToY(g_rLines[near].price)-g_spkMouseY);
      if(dy<=8.0) hov=near;
   }
   if(hov!=g_rHover){ g_rHover=hov; changed=true; }

   if(g_spkDragIdx>=0)
   {
      if(!left){ g_spkDragIdx=-1; g_rDragIdx=-1; changed=true; }
      else if(ArraySize(g_rLines)<=5000)
      {
         int ni=RSceneMoveLine(g_spkDragIdx,price);
         if(ni>=0){ g_spkDragIdx=ni; g_rDragIdx=ni; changed=true; }
      }
   }
   else if(left && !g_spkWasLeft && g_rHover>=0 && ArraySize(g_rLines)<=5000)
   {
      g_spkDragIdx=g_rHover; g_rDragIdx=g_rHover; changed=true;
   }
   g_spkWasLeft=left;
   if(changed) RSpikeWant();
}
