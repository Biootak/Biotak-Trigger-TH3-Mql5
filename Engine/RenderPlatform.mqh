//+------------------------------------------------------------------+
//|  RenderPlatform.mqh - Biotak render engine, layer 0 (MT5-ONLY)   |
//|  Only MQL calls live here: resources / objects / chart / text /  |
//|  timer / mouse. No drawing logic, no scene logic.                |
//+------------------------------------------------------------------+
#ifndef RENDER_PLATFORM_MQH
#define RENDER_PLATFORM_MQH

double RPlatNowMs()        { return (double)GetMicrosecondCount()/1000.0; }
int    RPlatChartW()       { return (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS); }
int    RPlatChartH()       { return (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS); }
double RPlatPriceMin()     { return ChartGetDouble(0,CHART_PRICE_MIN); }
double RPlatPriceMax()     { return ChartGetDouble(0,CHART_PRICE_MAX); }

// The pattern family's own need: its segments and labels anchor to (time,price),
// so both painters resolve through the chart page at paint time. The axis stamp
// lets the frameKey see a pure horizontal scroll/zoom that leaves the price
// scale untouched (a vertical move is already caught by the price map stamp).
bool RPlatTimePriceToXY(const long t,const double p,int &x,int &y)
{
   return ChartTimePriceToXY(0,0,(datetime)t,p,x,y);
}
long RPlatTimeAxisStamp()
{
   return (long)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR)*1000003
        + (long)ChartGetInteger(0,CHART_VISIBLE_BARS)*31
        + (long)ChartGetInteger(0,CHART_SHIFT);
}

string RPlatResName(const string tag) { return "BTRS_"+IntegerToString((long)ChartID())+"_"+tag; }
string RPlatObjName(const string tag) { return "BTRS_OBJ_"+IntegerToString((long)ChartID())+"_"+tag; }

bool RPlatResourceCreate(const string resName,const uint &px[],int w,int h)
{
   return ResourceCreate("::"+resName,px,(uint)w,(uint)h,0,0,(uint)w,COLOR_FORMAT_ARGB_NORMALIZE);
}
void RPlatResourceFree(const string resName){ ResourceFree("::"+resName); }

bool RPlatLayerCreate(const string objName,const string resName,int x,int y,int w,int h,bool back,int zorder=0)
{
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);
   if(!ObjectCreate(0,objName,OBJ_BITMAP_LABEL,0,0,0)) return false;
   ObjectSetInteger(0,objName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,objName,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,objName,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,objName,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,objName,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,objName,OBJPROP_BACK,(long)(back?1:0));
   ObjectSetInteger(0,objName,OBJPROP_ZORDER,zorder);
   ObjectSetInteger(0,objName,OBJPROP_SELECTABLE,0);
   ObjectSetInteger(0,objName,OBJPROP_HIDDEN,1);
   ObjectSetString(0,objName,OBJPROP_BMPFILE,"::"+resName);
   return true;
}
// The one bulk show/hide of a whole canvas layer (the L switch and the hide-all
// state own the layers wholesale; per-element visibility stays in the scene).
void RPlatLayerTimeframes(const string objName,const bool show)
{
   ObjectSetInteger(0,objName,OBJPROP_TIMEFRAMES,show?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
}
void RPlatLayerRefresh(const string objName,const string resName,int w,int h)
{
   ObjectSetInteger(0,objName,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,objName,OBJPROP_YSIZE,h);
   ObjectSetString(0,objName,OBJPROP_BMPFILE,"::"+resName);
}
void RPlatLayerDelete(const string objName)
{
   if(ObjectFind(0,objName)>=0) ObjectDelete(0,objName);
}
void RPlatEnableMouse(bool on){ ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,on); }
// R-POINTER-FRAME (2026-10-23): the coalescer by NAME — the `ChartRedraw()`
// macro does not match the one-argument call shape, and this is the only such
// call in the tree. Inside a chart event this records the ask (one frame, after
// every writer); outside one it is the terminal's own call, unchanged.
void RPlatRedraw(){ CompatChartRedraw(); }
bool RPlatTimerStart(int ms){ return EventSetMillisecondTimer(ms); }
void RPlatTimerStop(){ EventKillTimer(); }

bool RPlatTextSetFont(const string name,int size,uint flags,int orientation=0)
{
   return TextSetFont(name,size,flags,orientation);
}
bool RPlatTextOut(const string text,int x,int y,uint anchor,uint &buf[],int w,int h,uint argb)
{
   return TextOut(text,x,y,anchor,buf,(uint)w,(uint)h,argb,COLOR_FORMAT_ARGB_NORMALIZE);
}

#endif
