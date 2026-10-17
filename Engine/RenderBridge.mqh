//+------------------------------------------------------------------+
//|  RenderBridge.mqh - Biotak render engine, product seam (MT5-ONLY)|
//|                                                                  |
//|  R-RENDER-ENGINE (2026-10-17): the ladder's trigger LINES and (until |
//|  P-LBL-11) its pip LABELS are drawn by the canvas engine instead of  |
//|  one chart object per element. The labels retired on 2026-10-17, so  |
//|  the text family (RBridgeLevelLabel, RTexts) stays in the engine but |
//|  dormant - the product stages no label text any more. Step 2 (same   |
//|  day): the ZONE family (the fill band + its two horizontal edge       |
//|  segments, on a dedicated BACK                                      |
//|  layer at z=0 = Z_CHART_ZONE) is engine-owned too - the press-time |
//|  walks (trigger overlay, structure recolour) work over the scene  |
//|  recs instead of the object cache. Everything else (High/Low,     |
//|  custom price, the step-1 handle, toolbars) stays object-owned.   |
//|                                                                   |
//|  Zone parity notes (the deliberate divergences, each spelled at   |
//|  its owner below): the left vertical edge segment is not drawn    |
//|  (it stands at the oldest bar); the thin-zone pixel guard SKIPS   |
//|  the rec (the object path masks the family), re-decided by the    |
//|  next render that sees the scale.                                 |
//|                                                                  |
//|  The seam is a staging + diff-commit pipe, mirroring the object   |
//|  path's own stages exactly:                                       |
//|    - RenderTriggerLines stages the whole family every pass it     |
//|      runs (BUILD_STAGE_LINES stages lines; steady frames stage    |
//|      everything — the BUILD_STAGE_LABELS rung retired with the    |
//|      pip labels, P-LBL-11, and RBridgeBegin's second flag arrives |
//|      as a fixed false since no product stage feeds the text       |
//|      family any more) - the commit                            |
//|      compares against the last committed copy and repaints only   |
//|      on a real change.                                            |
//|    - The step-1 handle pair (+ the live drag name) are PINNED to  |
//|      objects: the native drag reads the object's price and the    |
//|      face owner (Step1HandleOwnFace) writes SELECTABLE/ZORDER/    |
//|      tooltip on it. A pinned name is excluded from the canvas and |
//|      produced by the untouched object path; when a name leaves    |
//|      the pin set its object is retired here (delete is tokenized  |
//|      by MQL5Compat, so no product handler ever sees it).          |
//|    - Visibility is FAMILY-level, exactly like the product's       |
//|      lineTf/labelTf masks were: the pump owns the two layer       |
//|      masks (L switch / hide-all) with                           |
//|      change-guarded property writes.                              |
//|                                                                  |
//|  Law 0: the hot path costs f(output surface) - a steady frame     |
//|  walks the staged arrays (compare doubles), commits nothing,      |
//|  paints nothing. N (levels) never reaches the terminal per frame. |
//|                                                                  |
//|  Requires: MQL5Compat.mqh (object shims + event tokens) and       |
//|  ObjectCache.mqh (CacheRemoveObject) included above. Call sites   |
//|  live in LevelPipeline.mqh; the entry owns Init/Pump/Shutdown.    |
//+------------------------------------------------------------------+
#ifndef RENDER_BRIDGE_MQH
#define RENDER_BRIDGE_MQH
#include "RenderPlatform.mqh"
#include "RenderCore.mqh"

//==================== bridge state ==================================
bool g_rbrArmed=false;               // OnInit armed it: from the first render on, the
                                     // object path is REPLACED (never mixed with canvas)
bool g_rbrStageLines=false, g_rbrStageLabels=false;
int  g_rbrLCursor=0, g_rbrTCursor=0;   // per-pass order cursors (O(N) steady staging)
bool g_rbrDirtyUnder=false, g_rbrDirtyTexts=false;
bool g_rbrMaskInited=false, g_rbrLineShow=true, g_rbrTextShow=true;
bool g_rbrLastHidden=false;

struct RBrLineRec { string name; double price; uint argb; int style; int width; bool seen; };
struct RBrTextRec { string name; double price; string text;  uint argb; int size; string font; bool seen; };
RBrLineRec g_rbrLines[];
RBrTextRec g_rbrTexts[];

string g_rbrPin[3];        // this pass: 0=step-1 above, 1=step-1 below, 2=live drag name
string g_rbrPrevPin[3];    // previous pass (a name that left the set returns to the canvas)

//==================== zone family (step 2) ==========================
// A zone is one fill band plus two horizontal edge segments (top lit, bottom
// shaded) - the picture CreateZone builds as one OBJ_RECTANGLE + its `_B_*`
// trend segments, minus the LEFT vertical segment (it stands at the oldest
// bar; off-screen except when the user scrolls to the start of history - the
// one documented divergence of the zone layer). The rec mirrors the object
// path's inputs so the press-time walks repaint exactly what a recompute
// would have stored - the contract StructureRecolourWalk keeps object-side.
// Colours arrive pre-blended (opaque) exactly like the MT4 objects'.
struct RBrZoneRec {
   string name;
   double top,bottom;
   int    step;             // parsed from the name, like every object-side walk
   bool   isTrigger;
   bool   visible;          // = !(isTrigger && trigger overlay off)
   bool   filled, outline;
   uint   fillArgb;         // computed picture
   bool   hasFill;
   uint   topArgb, botArgb;
   bool   hasEdge;
   int    style, width;
   bool   seen;
};
RBrZoneRec g_rbrZones[];
int  g_rbrZCursor=0;
bool g_rbrStageZones=false, g_rbrDirtyZones=false;
bool g_rbrZoneShow=true;   // the zone layer's mask (F + the MID ZONES master)

bool RBridgeActive() { return g_rbrArmed; }

bool RBrNameIn3(const string nm)
{
   for(int i=0;i<3;i++) if(g_rbrPin[i]!="" && g_rbrPin[i]==nm) return true;
   return false;
}
bool RBridgePinned(const string nm)
{
   if(!g_rbrArmed) return false;
   return RBrNameIn3(nm);
}

//==================== lifecycle =====================================
void RBridgeInit()
{
   // one-shot sweep of a previous instance's layers (a crash or a failed
   // deinit can leave BTRS_OBJ_* behind; safe on every attach)
   ObjectsDeleteAll(0,"BTRS_OBJ_",0,OBJ_BITMAP_LABEL);
   ArrayResize(g_rbrLines,0);
   ArrayResize(g_rbrTexts,0);
   ArrayResize(g_rbrZones,0);
   for(int i=0;i<3;i++){ g_rbrPin[i]=""; g_rbrPrevPin[i]=""; }
   g_rbrDirtyUnder=false; g_rbrDirtyTexts=false; g_rbrDirtyZones=false;
   g_rbrStageZones=false; g_rbrZCursor=0; g_rbrZoneShow=true;
   g_rbrMaskInited=false; g_rbrLastHidden=true;   // no paint before the first mask sync
   g_engManageTimer=false;     // the product's 250 ms timer is not ours to re-arm
   g_engUnderBack=false;       // ladder lines draw OVER the candles, like their HLINEs did
   g_engUnderZ=2;              // above zones (0) and Factor's line rung (1)
   g_engTextZ=3;               // labels above their own lines
   g_rbrArmed=true;
   REngineEnsure();            // creates the layers now if the chart is measurable
}

void RBridgeShutdown()
{
   if(!g_rbrArmed) return;
   REngineShutdown();
   g_rbrArmed=false;
}

//==================== staging (called from RenderTriggerLines) ======
// small helper for the pin diff (takes the candidate array explicitly so the
// diff cannot read a half-updated g_rbrPin)
bool RBrNameIn3Old2(const string nm,const string &arr[])
{
   for(int i=0;i<3;i++) if(arr[i]!="" && arr[i]==nm) return true;
   return false;
}

void RBridgePinsBegin(const string above,const string below,const string drag)
{
   string np[3]; np[0]=above; np[1]=below; np[2]=drag;
   for(int i=0;i<3;i++)
   {
      const string was=g_rbrPrevPin[i];
      if(was!="" && !RBrNameIn3Old2(was,np))
      {
         // the name left the pin set: retire its objects (the line AND the
         // Product's pip label, "<name>_Label" - a pinned name is object-owned
         // end to end), and the canvas stages both again from this very pass
         // on. The deletes are tokenized by the compat shim, so no product
         // handler reacts to them.
         if(ObjectFind(0,was)>=0) ObjectDelete(0,was);
         CacheRemoveObject(was);
         const string wasL=was+"_Label";
         if(ObjectFind(0,wasL)>=0) ObjectDelete(0,wasL);
         CacheRemoveObject(wasL);
      }
   }
   for(int i=0;i<3;i++){ g_rbrPin[i]=np[i]; g_rbrPrevPin[i]=np[i]; }
}

void RBridgeBegin(const bool stageLines,const bool stageLabels)
{
   g_rbrStageLines=stageLines;
   g_rbrStageLabels=stageLabels;
   g_rbrLCursor=0;
   g_rbrTCursor=0;
}

void RBridgeLevelLine(const string name,const double price,const color clr,const int style,const int width)
{
   const uint argb=RCol(clr,255);
   const int n=ArraySize(g_rbrLines);
   // The ladder's name sequence is stable across passes, so the cursor is the
   // steady O(1) path; a topology change falls back to one linear scan per
   // call until the order re-syncs (once per change, not per frame).
   int hit=-1;
   if(g_rbrLCursor<n && g_rbrLines[g_rbrLCursor].name==name) hit=g_rbrLCursor;
   else
   {
      for(int i=0;i<n;i++)
         if(!g_rbrLines[i].seen && g_rbrLines[i].name==name){ hit=i; break; }
   }
   if(hit>=0)
   {
      g_rbrLCursor=hit+1;
      if(g_rbrLines[hit].price!=price || g_rbrLines[hit].argb!=argb ||
         g_rbrLines[hit].style!=style || g_rbrLines[hit].width!=width) g_rbrDirtyUnder=true;
      g_rbrLines[hit].price=price; g_rbrLines[hit].argb=argb;
      g_rbrLines[hit].style=style; g_rbrLines[hit].width=width;
      g_rbrLines[hit].seen=true;
      return;
   }
   if(ArrayResize(g_rbrLines,n+1)!=n+1) return;
   g_rbrLines[n].name=name;   g_rbrLines[n].price=price;
   g_rbrLines[n].argb=argb;   g_rbrLines[n].style=style;
   g_rbrLines[n].width=width; g_rbrLines[n].seen=true;
   g_rbrLCursor=n+1;
   g_rbrDirtyUnder=true;
}

void RBridgeLevelLabel(const string name,const double price,const string text,
                       const color clr,const int fontSize,const string fontName)
{
   const uint argb=RCol(clr,255);
   const int n=ArraySize(g_rbrTexts);
   int hit=-1;
   if(g_rbrTCursor<n && g_rbrTexts[g_rbrTCursor].name==name) hit=g_rbrTCursor;
   else
   {
      for(int i=0;i<n;i++)
         if(!g_rbrTexts[i].seen && g_rbrTexts[i].name==name){ hit=i; break; }
   }
   if(hit>=0)
   {
      g_rbrTCursor=hit+1;
      if(g_rbrTexts[hit].price!=price || g_rbrTexts[hit].argb!=argb ||
         g_rbrTexts[hit].text!=text || g_rbrTexts[hit].size!=fontSize ||
         g_rbrTexts[hit].font!=fontName) g_rbrDirtyTexts=true;
      g_rbrTexts[hit].price=price; g_rbrTexts[hit].argb=argb;
      g_rbrTexts[hit].text=text;   g_rbrTexts[hit].size=fontSize;
      g_rbrTexts[hit].font=fontName;
      g_rbrTexts[hit].seen=true;
      return;
   }
   if(ArrayResize(g_rbrTexts,n+1)!=n+1) return;
   g_rbrTexts[n].name=name;   g_rbrTexts[n].price=price;
   g_rbrTexts[n].text=text;   g_rbrTexts[n].argb=argb;
   g_rbrTexts[n].size=fontSize; g_rbrTexts[n].font=fontName;
   g_rbrTexts[n].seen=true;
   g_rbrTCursor=n+1;
   g_rbrDirtyTexts=true;
}

//==================== zone family (step 2): staging =================
// The ONE ink computer for the canvas zone picture. It multiplies the SAME
// helpers CreateZone's PHASE 3 multiplies (GetZoneRenderColor +
// BioZoneEdgeTones + GetCachedChartBgColor) with the same live inputs, so the
// canvas and the object path cannot bake two different pictures - the
// P-UI-131m/P-UI-131h law, preserved across the seam. bandTr arrives already
// owned by PipelineBandTransparency (the caller's read, like the request's).
void RBrZoneInk(const color zc,const int bandTr,const bool filled,const bool outline,
                uint &fillArgb,bool &hasFill,uint &topArgb,uint &botArgb,bool &hasEdge,
                int &style,int &width)
{
   int tr=bandTr;
   if(tr<0) tr=0; if(tr>100) tr=100;
   color finalColor=GetZoneRenderColor(zc,tr);
   int edgeTransparency=tr;
   if(inpMidZoneBorderTransparency>=0 && inpMidZoneBorderTransparency<=100)
      edgeTransparency=inpMidZoneBorderTransparency;
   color borderColor=GetZoneRenderColor(zc,edgeTransparency);
   color edgeUnder=filled?finalColor:GetCachedChartBgColor();
   int edgeTopTr=(inpZoneEdgeTopTransparency>=0 && inpZoneEdgeTopTransparency<=100)
                     ?inpZoneEdgeTopTransparency:edgeTransparency;
   int edgeBotTr=(inpZoneEdgeBottomTransparency>=0 && inpZoneEdgeBottomTransparency<=100)
                     ?inpZoneEdgeBottomTransparency:edgeTransparency;
   color edgeTopBase=GetZoneRenderColor(zc,edgeTopTr);
   color edgeBotBase=GetZoneRenderColor(zc,edgeBotTr);
   color litT=borderColor,shdT=borderColor,edgeLit=borderColor,edgeShade=borderColor;
   BioZoneEdgeTones(edgeTopBase,edgeUnder,litT,shdT);
   edgeLit=litT;
   BioZoneEdgeTones(edgeBotBase,edgeUnder,litT,shdT);
   edgeShade=shdT;
   if(inpZoneEdgeTopColor!=clrNONE)    edgeLit  =GetZoneRenderColor(inpZoneEdgeTopColor,edgeTopTr);
   if(inpZoneEdgeBottomColor!=clrNONE) edgeShade=GetZoneRenderColor(inpZoneEdgeBottomColor,edgeBotTr);
   // the same defensive clamps CreateZone applies (callers pass raw inputs)
   style=inpMidZoneBorderStyle;
   if(style<STYLE_SOLID||style>STYLE_DASHDOTDOT) style=STYLE_SOLID;
   width=inpMidZoneBorderWidth;
   if(width<1||width>5) width=1;
   hasFill=filled;  fillArgb=RCol(finalColor,255);
   hasEdge=outline; topArgb=RCol(edgeLit,255); botArgb=RCol(edgeShade,255);
}

void RBridgeZonesBegin(){ g_rbrStageZones=true; g_rbrZCursor=0; }

void RBridgeZone(const string name,const double top,const double bottom,const color zc,
                 const bool isTrigger,const bool visible,const bool filled,const bool outline)
{
   int trRaw=inpMidZoneTransparency;
   if(trRaw<0) trRaw=0; if(trRaw>100) trRaw=100;
   const int bandTr=PipelineBandTransparency(isTrigger,trRaw);
   uint fillArgb=0,topArgb=0,botArgb=0; bool hasFill=false,hasEdge=false; int st=0,wd=1;
   RBrZoneInk(zc,bandTr,filled,outline,fillArgb,hasFill,topArgb,botArgb,hasEdge,st,wd);

   const int n=ArraySize(g_rbrZones);
   int hit=-1;
   if(g_rbrZCursor<n && g_rbrZones[g_rbrZCursor].name==name) hit=g_rbrZCursor;
   else
   {
      for(int i=0;i<n;i++)
         if(!g_rbrZones[i].seen && g_rbrZones[i].name==name){ hit=i; break; }
   }
   if(hit>=0)
   {
      g_rbrZCursor=hit+1;
      if(g_rbrZones[hit].top!=top || g_rbrZones[hit].bottom!=bottom ||
         g_rbrZones[hit].isTrigger!=isTrigger || g_rbrZones[hit].visible!=visible ||
         g_rbrZones[hit].filled!=filled || g_rbrZones[hit].outline!=outline ||
         g_rbrZones[hit].fillArgb!=fillArgb || g_rbrZones[hit].hasFill!=hasFill ||
         g_rbrZones[hit].topArgb!=topArgb || g_rbrZones[hit].botArgb!=botArgb ||
         g_rbrZones[hit].hasEdge!=hasEdge || g_rbrZones[hit].style!=st || g_rbrZones[hit].width!=wd)
         g_rbrDirtyZones=true;
      g_rbrZones[hit].top=top; g_rbrZones[hit].bottom=bottom;
      g_rbrZones[hit].isTrigger=isTrigger; g_rbrZones[hit].visible=visible;
      g_rbrZones[hit].filled=filled; g_rbrZones[hit].outline=outline;
      g_rbrZones[hit].fillArgb=fillArgb; g_rbrZones[hit].hasFill=hasFill;
      g_rbrZones[hit].topArgb=topArgb; g_rbrZones[hit].botArgb=botArgb;
      g_rbrZones[hit].hasEdge=hasEdge; g_rbrZones[hit].style=st; g_rbrZones[hit].width=wd;
      g_rbrZones[hit].seen=true;
      return;
   }
   if(ArrayResize(g_rbrZones,n+1)!=n+1) return;
   g_rbrZones[n].name=name;
   g_rbrZones[n].step=StructureZoneStepFromName(name);
   g_rbrZones[n].top=top; g_rbrZones[n].bottom=bottom;
   g_rbrZones[n].isTrigger=isTrigger; g_rbrZones[n].visible=visible;
   g_rbrZones[n].filled=filled; g_rbrZones[n].outline=outline;
   g_rbrZones[n].fillArgb=fillArgb; g_rbrZones[n].hasFill=hasFill;
   g_rbrZones[n].topArgb=topArgb; g_rbrZones[n].botArgb=botArgb;
   g_rbrZones[n].hasEdge=hasEdge; g_rbrZones[n].style=st; g_rbrZones[n].width=wd;
   g_rbrZones[n].seen=true;
   g_rbrZCursor=n+1;
   g_rbrDirtyZones=true;
}

// scene push: recs order = the object path's creation order = MT4's
// equal-zorder paint order (band, its edge, the next zone)
void RBridgeZonesPush()
{
   const int n=ArraySize(g_rbrZones);
   RZoneObj tmp[];
   ArrayResize(tmp,n);
   for(int i=0;i<n;i++)
   {
      tmp[i].top     =g_rbrZones[i].top;
      tmp[i].bottom  =g_rbrZones[i].bottom;
      tmp[i].fillArgb=g_rbrZones[i].fillArgb;
      tmp[i].hasFill =g_rbrZones[i].hasFill;
      tmp[i].topArgb =g_rbrZones[i].topArgb;
      tmp[i].botArgb =g_rbrZones[i].botArgb;
      tmp[i].hasEdge =g_rbrZones[i].hasEdge;
      tmp[i].style   =g_rbrZones[i].style;
      tmp[i].width   =g_rbrZones[i].width;
      tmp[i].visible =g_rbrZones[i].visible;
   }
   RSceneSetZones(tmp,n);
}

void RBridgeZonesCommit()
{
   if(!g_rbrStageZones) return;
   g_rbrStageZones=false;
   int w=0;
   const int n=ArraySize(g_rbrZones);
   for(int i=0;i<n;i++)
   {
      if(g_rbrZones[i].seen)
      {
         if(w!=i) g_rbrZones[w]=g_rbrZones[i];
         g_rbrZones[w].seen=false;
         w++;
      }
      else g_rbrDirtyZones=true;   // a vanished name
   }
   ArrayResize(g_rbrZones,w);
   if(!g_rbrDirtyZones) return;
   g_rbrDirtyZones=false;
   RBridgeZonesPush();
   if(!g_rbrLastHidden) REnginePaint();
}

//==================== zone family: press-time walks =================
// TriggerFamilyWalk's canvas branch: the T overlay is per-zone visibility
// inside ONE layer, so a press is a rec flip - no masks, no terminal writes.
// `seen` mirrors the object walk's count (0 = the chart carries no trigger
// band yet, the one case the caller still owes a build).
int RBridgeTriggerWalk(const bool on,int &seen)
{
   seen=0;
   int written=0;
   const int n=ArraySize(g_rbrZones);
   for(int i=0;i<n;i++)
   {
      if(!g_rbrZones[i].isTrigger) continue;
      seen++;
      if(g_rbrZones[i].visible!=on){ g_rbrZones[i].visible=on; written++; }
   }
   if(written>0)
   {
      RBridgeZonesPush();
      if(!g_rbrLastHidden) REnginePaint();
   }
   return written;
}

// StructureRecolourWalk's canvas branch: the SAME inputs the object walk
// reads (live switches + the ladder), the same classification test, the same
// two ink owners - over the scene recs instead of the object cache.
// Visibility is NOT this walk's to change (the object walk changes colours
// only; the next render re-asserts the overlay). The classification IS
// refreshed: a structure switch can move a tier, and isTrigger feeds the T
// walk before any render runs.
int RBridgeZoneRecolour()
{
   const bool trigOn=IsTriggerLevelsEnabled();
   const int baseMult=GetValidatedBaseMultiplier();
   int trRaw=inpMidZoneTransparency;
   if(trRaw<0) trRaw=0; if(trRaw>100) trRaw=100;
   int touched=0;
   const int n=ArraySize(g_rbrZones);
   for(int i=0;i<n;i++)
   {
      const int step=g_rbrZones[i].step;
      if(step<=0) continue;
      const bool isTrig=(GetHighestStructureLevel(step,g_cachedIntervals)<=0);
      const color zc=PipelineBandBaseColor(step,trigOn,baseMult);
      const int bandTr=PipelineBandTransparency(isTrig,trRaw);
      uint fillArgb=0,topArgb=0,botArgb=0; bool hasFill=false,hasEdge=false; int st=0,wd=1;
      RBrZoneInk(zc,bandTr,g_rbrZones[i].filled,g_rbrZones[i].outline,
                 fillArgb,hasFill,topArgb,botArgb,hasEdge,st,wd);
      if(g_rbrZones[i].isTrigger!=isTrig ||
         g_rbrZones[i].fillArgb!=fillArgb || g_rbrZones[i].hasFill!=hasFill ||
         g_rbrZones[i].topArgb!=topArgb || g_rbrZones[i].botArgb!=botArgb ||
         g_rbrZones[i].hasEdge!=hasEdge || g_rbrZones[i].style!=st || g_rbrZones[i].width!=wd)
      {
         g_rbrZones[i].isTrigger=isTrig;
         g_rbrZones[i].fillArgb=fillArgb; g_rbrZones[i].hasFill=hasFill;
         g_rbrZones[i].topArgb=topArgb; g_rbrZones[i].botArgb=botArgb;
         g_rbrZones[i].hasEdge=hasEdge; g_rbrZones[i].style=st; g_rbrZones[i].width=wd;
         touched++;
      }
   }
   if(touched>0)
   {
      RBridgeZonesPush();
      if(!g_rbrLastHidden) REnginePaint();
   }
   return touched;
}

// The MID ZONES master (RenderZones' `!zonesEnabled` branch): one layer
// mask, asserted with the same change guard the pump keeps.
void RBridgeZoneFamilyMask(const bool show)
{
   if(!g_rbrArmed) return;
   const bool want=(show && !g_rbrLastHidden);
   if(g_rbrZoneShow==want) return;
   if(!REngineEnsure()) return;
   RPlatLayerTimeframes(g_engObjZg,want);
   g_rbrZoneShow=want;
}

//==================== commit (end of the render pass) ===============
// "Arial Bold" carries its weight in the NAME on MT4; TextSetFont wants the
// family plus FW_BOLD (the same split MT5's own object renderer performs).
string RBrFaceName(const string nm)
{
   const int p=StringFind(nm," Bold");
   if(p>0) return StringSubstr(nm,0,p);
   return nm;
}
uint RBrFaceFlags(const string nm)
{
   return (StringFind(nm," Bold")>0) ? (uint)FW_BOLD : (uint)FW_NORMAL;
}

void RBridgeEnd()
{
   // --- sweep the families the caller staged this pass (produced-set law:
   //     what this pass did not produce is gone; an un-staged family keeps
   //     its last picture exactly like its objects kept their last state) ---
   if(g_rbrStageLines)
   {
      int w=0;
      const int n=ArraySize(g_rbrLines);
      for(int i=0;i<n;i++)
      {
         if(g_rbrLines[i].seen)
         {
            if(w!=i) g_rbrLines[w]=g_rbrLines[i];
            g_rbrLines[w].seen=false;
            w++;
         }
         else g_rbrDirtyUnder=true;   // a vanished name
      }
      ArrayResize(g_rbrLines,w);
   }
   if(g_rbrStageLabels)
   {
      int w=0;
      const int n=ArraySize(g_rbrTexts);
      for(int i=0;i<n;i++)
      {
         if(g_rbrTexts[i].seen)
         {
            if(w!=i) g_rbrTexts[w]=g_rbrTexts[i];
            g_rbrTexts[w].seen=false;
            w++;
         }
         else g_rbrDirtyTexts=true;
      }
      ArrayResize(g_rbrTexts,w);
   }

   // --- commit the changed families into the scene (wholesale replace) ---
   bool changed=false;
   if(g_rbrDirtyUnder)
   {
      g_rbrDirtyUnder=false; changed=true;
      const int n=ArraySize(g_rbrLines);
      RLine tmp[];
      ArrayResize(tmp,n);
      for(int i=0;i<n;i++)
      {
         tmp[i].price=g_rbrLines[i].price;
         tmp[i].argb =g_rbrLines[i].argb;
         tmp[i].width=g_rbrLines[i].width;
         tmp[i].style=g_rbrLines[i].style;
      }
      RSceneSetLines(tmp,n);
   }
   if(g_rbrDirtyTexts)
   {
      g_rbrDirtyTexts=false; changed=true;
      const int n=ArraySize(g_rbrTexts);
      RText tmp[];
      ArrayResize(tmp,n);
      for(int i=0;i<n;i++)
      {
         tmp[i].price   =g_rbrTexts[i].price;
         tmp[i].x       =-1;                       // sentinel: the right edge, resolved at draw
         tmp[i].anchor  =TA_RIGHT|TA_VCENTER;      // MT4's ANCHOR_RIGHT row, one text row up
         tmp[i].text    =g_rbrTexts[i].text;
         tmp[i].argb    =g_rbrTexts[i].argb;
         tmp[i].fontSize=-(g_rbrTexts[i].size*10); // MT4 FONTSIZE is points; TextSetFont wants tenths
         tmp[i].fontFlags=RBrFaceFlags(g_rbrTexts[i].font);
         tmp[i].fontName=RBrFaceName(g_rbrTexts[i].font);
      }
      RSceneSetTexts(tmp,n);
   }

   // Paint now: a level change lands on the frame that made it, not up to a
   // timer cadence later (the object path drew on this very frame too). The
   // frameKey skips this to two reads when nothing changed.
   if(changed && !g_rbrLastHidden) REnginePaint();
#ifdef BTRS_SCENE_DUMP
   if(GlobalVariableCheck("BTRS_DUMP")) RBridgeDumpCsv();   // a commit dumps at once
#endif
}

//==================== diagnostic (R-RENDER-ENGINE verification) ======
// Compiled only when the entry defines BTRS_SCENE_DUMP (see the entry's flag
// block). Zero production cost: no code, no calls when the flag is off.
//
// The dump answers "does the canvas draw what the MT4 object path drew?".
// It writes the DRAWN family - the committed canvas rows PLUS the pinned
// objects (the only ladder objects left) - in the same row schema the MT4
// script (tools/mt4-scene-dump.mq4) writes:
//   type;name;price;color;style;width;size;font;text
// (L = line: style/width filled; T = text: size/font/text filled; color both.)
// tools/parity/scene-diff.py matches the two files by name and reports holes
// and field mismatches.
#ifdef BTRS_SCENE_DUMP
void RBridgeDumpCsv()
{
   const int h=FileOpen("BTRS_scene_MT5.csv",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h==INVALID_HANDLE) return;
   FileWriteString(h,"type;name;price;color;style;width;size;font;text\r\n");

   const int nl=ArraySize(g_rbrLines);
   for(int i=0;i<nl;i++)
      FileWriteString(h,StringFormat("L;%s;%.8f;0x%06X;%d;%d;;;\r\n",
         g_rbrLines[i].name, g_rbrLines[i].price,
         (uint)(g_rbrLines[i].argb & 0x00FFFFFF),
         g_rbrLines[i].style, g_rbrLines[i].width));

   const int nt=ArraySize(g_rbrTexts);
   for(int i=0;i<nt;i++)
      FileWriteString(h,StringFormat("T;%s;%.8f;0x%06X;;;%d;%s;%s\r\n",
         g_rbrTexts[i].name, g_rbrTexts[i].price,
         (uint)(g_rbrTexts[i].argb & 0x00FFFFFF),
         g_rbrTexts[i].size, g_rbrTexts[i].font, g_rbrTexts[i].text));

   // pinned names keep their objects: read them from the terminal so the dump
   // shows the same picture the screen does
   for(int i=0;i<3;i++)
   {
      const string nm=g_rbrPin[i];
      if(nm=="" || ObjectFind(0,nm)<0) continue;
      FileWriteString(h,StringFormat("L;%s;%.8f;0x%06X;%d;%d;;;\r\n",
         nm, ObjectGetDouble(0,nm,OBJPROP_PRICE,0),
         (uint)((long)ObjectGetInteger(0,nm,OBJPROP_COLOR) & 0x00FFFFFF),
         (int)ObjectGetInteger(0,nm,OBJPROP_STYLE),
         (int)ObjectGetInteger(0,nm,OBJPROP_WIDTH)));
      const string lb=nm+"_Label";
      if(ObjectFind(0,lb)>=0)
         FileWriteString(h,StringFormat("T;%s;%.8f;0x%06X;;;%d;%s;%s\r\n",
            lb, ObjectGetDouble(0,lb,OBJPROP_PRICE,0),
            (uint)((long)ObjectGetInteger(0,lb,OBJPROP_COLOR) & 0x00FFFFFF),
            (int)ObjectGetInteger(0,lb,OBJPROP_FONTSIZE),
            ObjectGetString(0,lb,OBJPROP_FONT),
            ObjectGetString(0,lb,OBJPROP_TEXT)));
   }
   FileClose(h);
}
// dump when the terminal holds BTRS_DUMP=1 (set it from Tools->Global
// Variables or a one-liner script), at most once a second on the timer net
void RBridgeDumpTick()
{
   if(!GlobalVariableCheck("BTRS_DUMP")) return;
   static uint last=0;
   const uint now=GetTickCount();
   if(last!=0 && now-last<1000) return;
   last=now;
   RBridgeDumpCsv();
}
#endif

//==================== pump (entry's timer + CHART_CHANGE) ============
void RBridgePump(const bool hidden,const bool linesVisible,const bool zonesVisible)
{
   if(!g_rbrArmed) return;
   g_rbrLastHidden=hidden;
   if(!REngineEnsure()) return;
   const bool wantLines=(!hidden && linesVisible);   // == lineTf != OBJ_NO_PERIODS
   const bool wantTexts=(!hidden);                   // == labelTf != OBJ_NO_PERIODS
   // the zone family answers to its OWN switch + F; L never owns it (the
   // `_Top`/`_Bottom` boundary-line names it used to mask are legacy - the
   // current object family is the rectangle + `_B_*` border segments)
   const bool wantZones=(!hidden && zonesVisible);
   if(!g_rbrMaskInited || g_rbrLineShow!=wantLines || g_rbrTextShow!=wantTexts ||
      g_rbrZoneShow!=wantZones)
   {
      RPlatLayerTimeframes(g_engObjBg,wantLines);
      RPlatLayerTimeframes(g_engObjFg,wantTexts);
      RPlatLayerTimeframes(g_engObjZg,wantZones);
      g_rbrLineShow=wantLines; g_rbrTextShow=wantTexts; g_rbrZoneShow=wantZones; g_rbrMaskInited=true;
   }
#ifdef BTRS_SCENE_DUMP
   RBridgeDumpTick();      // the timer net also has to serve a settled chart
#endif
   if(hidden) return;      // content paints are pointless while the family is masked off
   REnginePaint();         // frameKey-guarded: a settled chart costs two chart reads
}

#endif
