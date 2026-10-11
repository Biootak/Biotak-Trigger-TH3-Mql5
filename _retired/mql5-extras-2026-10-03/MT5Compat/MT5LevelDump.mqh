//+------------------------------------------------------------------+
//| MT5LevelDump.mqh - MT5-ONLY DIAGNOSTIC                            |
//|                                                                  |
//| WHY THIS EXISTS                                                  |
//|                                                                  |
//| The report is: on MT5 the LEVELS are missing in the MIDDLE of the  |
//| chart - a band roughly 70 pips tall, centred on the current price, |
//| contains no level objects at all, while dense ladders of lines    |
//| continue above and below it. MT4 draws the whole ladder.          |
//|                                                                  |
//| Static reading of the pipeline EXHAUSTS every candidate:          |
//|   * CalculateLevels() walks outward from ONE anchor with a strict |
//|     arithmetic (or SS/LS alternating) ladder - it cannot emit a   |
//|     gap, and boundByHistorical only BREAKS the far end.           |
//|   * BuildZonesAndLines() only drops a level that fails to ADVANCE |
//|     the sequence - again no gap.                                  |
//|   * the viewport cull is a SINGLE interval test                  |
//|     (`price >= vpBottom && price <= vpTop`), and the complement   |
//|     of an interval cannot be a hole in the middle of a contiguous |
//|     ladder.                                                       |
//|   * no live caller draws a two-anchored ladder any more           |
//|     (DrawFactorLevelsAligned has no callers; the unified pipeline |
//|     owns Factor mode).                                            |
//|                                                                  |
//| So the question "are those objects ABSENT, or are they present    |
//| and HIDDEN?" cannot be answered by reading code - it needs the    |
//| live chart. This file answers it, and nothing else.               |
//|                                                                  |
//| WHAT IT WRITES                                                    |
//|                                                                  |
//| MQL5/Files/biotak-level-dump.txt, rewritten every few seconds:    |
//|   1. the chart state the render decides from (viewport, hidden    |
//|      flag, line mask, build stage, draw generation, anchors);     |
//|   2. EVERY object carrying the indicator prefix, with its type,   |
//|      price and OBJPROP_TIMEFRAMES mask;                           |
//|   3. a per-family step histogram, so "steps 1..7 never created"   |
//|      is distinguishable from "steps 1..7 exist but are masked    |
//|      OBJ_NO_PERIODS";                                             |
//|   4. the sorted level prices, so the gap is visible as numbers.   |
//|                                                                  |
//| COST: a few hundred terminal reads every few seconds while the    |
//| switch is on. It reads only - it never creates, moves, deletes or |
//| repaints anything.                                                |
//|                                                                  |
//| This file lives in MT5Compat/, which is NOT junctioned into the   |
//| MT4 tree, so the MT4 build can never see it - zero parity risk by |
//| construction. Turn the switch OFF to ship.                        |
//+------------------------------------------------------------------+
#ifndef MT5_LEVEL_DUMP_MQH
#define MT5_LEVEL_DUMP_MQH

// Turn ON for a diagnosis build, OFF to ship. Nothing else changes.
//
// P-PERF-48 (2026-09-16) - SHIPPED OFF. Its own header prices the switch: "a few
// hundred terminal reads every few seconds", and on MT5 a terminal read is the
// expensive primitive by an order of magnitude (~32-88 us against ~0.25 us for a
// write). The write also re-runs CalculateLevels() and rewrites the dump file.
//
// MEASURED, NOT ASSUMED: it ran every LEVEL_DUMP_EVERY=4000 ms on the live Full
// build (Biotak Trigger TH3.mq5:291 OnCalculate + :412 OnTimer). Its cost is a
// full-chart walk plus a FileOpen/FileWrite/FileClose of ~27 KB plus a re-run of
// CalculateLevels() - and the walk is charged per OBJECT, so it is small on a
// thin chart (the 19:15:58 dump: 65 objects) and tens of milliseconds on the
// busy ones today's log shows (total=856). Either way it is a stutter with no
// line in the perf ledger, because a diagnostic is not a job. The diagnosis it
// was built for is closed (docs/LEVELS-FOREIGN-GEOMETRY_FA.md), so it goes off.
//
// Uncomment the line below ONLY for a diagnosis build.
// DIAGNOSIS BUILD 2026-09-17 (H1-empty + W1/MN-density): temporarily ON.
// Revert to OFF before shipping the fix.
//#define ENABLE_MT5_LEVEL_DUMP

#ifdef ENABLE_MT5_LEVEL_DUMP

#define LEVEL_DUMP_FILE   "biotak-level-dump.txt"
#define LEVEL_DUMP_EVERY  4000   // ms between rewrites

// Highest step index the reconciliation table can hold. inpMaxLevels is 144,
// so 512 is generous and the table stays a fixed local array (no allocation).
#define LEVEL_DUMP_MAX_STEP 512

// One row per family: how many step indices were seen, and the mask split.
struct SLevelDumpFamily
{
   string suffix;      // e.g. "_Above_"
   int    seen;        // names found
   int    visible;     // mask == OBJ_ALL_PERIODS
   int    hidden;      // mask == OBJ_NO_PERIODS
   int    otherMask;   // any other mask (a per-timeframe subset)
   int    minStep;
   int    maxStep;
   string stepList;    // the actual step indices, ascending
};

void LevelDumpInitFamily(SLevelDumpFamily &f, const string suffix)
{
   f.suffix    = suffix;
   f.seen      = 0;
   f.visible   = 0;
   f.hidden    = 0;
   f.otherMask = 0;
   f.minStep   = -1;
   f.maxStep   = -1;
   f.stepList  = "";
}

// Trailing integer of a name ("PFXSSLS_Above_12_Label" -> 12), or -1.
int LevelDumpTrailingInt(const string nm)
{
   int n = StringLen(nm);
   int end = n - 1;
   // Strip one known sub-suffix if present, so "_Above_12_Label" reads as 12.
   if(end >= 5 && StringSubstr(nm, end - 5, 6) == "_Label") end -= 6;
   else if(end >= 4 && StringSubstr(nm, end - 4, 5) == "_Top") end -= 5;
   else if(end >= 7 && StringSubstr(nm, end - 7, 8) == "_Bottom") end -= 8;
   else if(end >= 6 && StringSubstr(nm, end - 6, 7) == "_B_Top") end -= 7;
   else if(end >= 9 && StringSubstr(nm, end - 9, 10) == "_B_Bottom") end -= 10;
   else if(end >= 8 && StringSubstr(nm, end - 8, 9) == "_B_Left") end -= 9;
   else if(end >= 9 && StringSubstr(nm, end - 9, 10) == "_B_Right") end -= 10;
   int start = end;
   while(start >= 0)
   {
      ushort c = StringGetCharacter(nm, (int)start);
      if(c < '0' || c > '9') break;
      start--;
   }
   if(start == end) return -1;
   return (int)StringToInteger(StringSubstr(nm, start + 1, end - start));
}

string LevelDumpTypeName(const int t)
{
   switch(t)
   {
      case OBJ_HLINE:     return "HLINE";
      case OBJ_TREND:     return "TREND";
      case OBJ_RECTANGLE: return "RECT";
      case OBJ_TEXT:      return "TEXT";
      case OBJ_LABEL:     return "LABEL";
      case OBJ_BITMAP:    return "BITMAP";
      case OBJ_BITMAP_LABEL: return "BITMAP_LABEL";
      case OBJ_ARROW:     return "ARROW";
      case OBJ_VLINE:     return "VLINE";
   }
   return "T" + IntegerToString(t);
}

void MT5LevelDumpWrite()
{
   const string pfx = inpObjectPrefix;
   const int    plen = StringLen(pfx);

   int    fh = FileOpen(LEVEL_DUMP_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(fh == INVALID_HANDLE) return;

   double cMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double cMin = ChartGetDouble(0, CHART_PRICE_MIN);
   long   cH   = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   FileWrite(fh, "==== Biotak Trigger TH3 - MT5 level dump ====");
   FileWrite(fh, "time=", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                  "  server=", TimeToString(TimeTradeServer(), TIME_DATE | TIME_SECONDS));
   FileWrite(fh, "symbol=", _Symbol, "  period=", EnumToString((ENUM_TIMEFRAMES)Period()),
                  "  digits=", (int)Digits, "  point=", DoubleToString(Point, 8));
   FileWrite(fh, "bid=", DoubleToString(Bid, 8), "  g_currentPrice=", DoubleToString(g_currentPrice, 8));
   FileWrite(fh, "prefix=[", pfx, "]  prefixLen=", plen);
   FileWrite(fh, "chartMax=", DoubleToString(cMax, 8), "  chartMin=", DoubleToString(cMin, 8),
                  "  heightPx=", (long)cH);
   FileWrite(fh, "linesVisible=", (GetCachedLinesVisible() ? 1 : 0),
                  "  indicatorHidden=", (IsIndicatorHidden() ? 1 : 0),
                  "  buildStage=", g_buildStage,
                  "  drawGeneration=", g_drawGeneration);
   FileWrite(fh, "startPointType=", (int)g_thStartPointType,
                  "  dailyCloseForTH=", DoubleToString(g_dailyClosePriceForTH, 8),
                  "  highestHigh=", DoubleToString(g_highestHigh, 8),
                  "  lowestLow=", DoubleToString(g_lowestLow, 8));
   FileWrite(fh, "inpMaxLevels=", inpMaxLevels,
                   "  stepMode=", (int)inpStepCalculationMode,
                   "  baseMult=", GetValidatedBaseMultiplier());
   // Zone paint state: distinguishes "zones off by switch" from "zones built
   // but painted invisible" without touching the chart.
   FileWrite(fh, "midZones=", (inpShowMidZones ? 1 : 0),
                   "  midZoneStyle=", (int)inpMidZoneStyle,
                   "  midZoneTr=", inpMidZoneTransparency,
                   "  bgColor=", ColorToString(GetCachedChartBgColor()));
   FileWrite(fh, "");

   // ---- families of interest ----
   SLevelDumpFamily fam[8];
   LevelDumpInitFamily(fam[0], "_Above_");
   LevelDumpInitFamily(fam[1], "_Below_");
   LevelDumpInitFamily(fam[2], "_Zone_Above_");
   LevelDumpInitFamily(fam[3], "_Zone_Below_");
   LevelDumpInitFamily(fam[4], "_Zone_Center_");
   LevelDumpInitFamily(fam[5], "_Midpoint_");
   LevelDumpInitFamily(fam[6], "Factor_");
   LevelDumpInitFamily(fam[7], "High");
   const int FAM_N = 8;

   int    total = ObjectsTotal(0, -1, -1);
   int    ours  = 0;
   int    lineRows = 0;
   string linePrices[];

   // Price ON CHART for each level-line step index, so the reconciliation table
   // below can compare "what the chart carries" against "what the live inputs
   // imply" per step. 0.0 = no such object. Zone rects are excluded: they are a
   // different family with their own step meaning.
   double chartAbove[LEVEL_DUMP_MAX_STEP];
   double chartBelow[LEVEL_DUMP_MAX_STEP];
   ArrayInitialize(chartAbove, 0.0);
   ArrayInitialize(chartBelow, 0.0);

   FileWrite(fh, "---- objects with our prefix (", total, " objects on chart) ----");
   FileWrite(fh, "name | type | price | tfmask | inViewportRange");

   for(int i = 0; i < total; i++)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringLen(nm) < plen) continue;
      if(StringSubstr(nm, 0, plen) != pfx) continue;
      ours++;

      int    t   = (int)ObjectGetInteger(0, nm, OBJPROP_TYPE);
      long   tf  = ObjectGetInteger(0, nm, OBJPROP_TIMEFRAMES);
      double pr  = 0.0;
      if(t == OBJ_HLINE || t == OBJ_TREND || t == OBJ_TEXT ||
         t == OBJ_ARROW || t == OBJ_RECTANGLE)
         pr = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);

      bool inRange = (pr > 0.0 && cMax > 0.0 && cMin > 0.0 && pr >= cMin && pr <= cMax);

      FileWrite(fh, nm, " | ", LevelDumpTypeName(t), " | ", DoubleToString(pr, 8),
                    " | tf=", (long)tf, " | ", (inRange ? "IN" : "-"));

      // Zone paint forensics: a RECT that exists with a visible mask but does
      // not paint is a colour/fill/geometry verdict, not an existence one.
      if(t == OBJ_RECTANGLE)
      {
         long zCol  = ObjectGetInteger(0, nm, OBJPROP_COLOR);
         long zFill = ObjectGetInteger(0, nm, OBJPROP_FILL);
         long zBack = ObjectGetInteger(0, nm, OBJPROP_BACK);
         long zOrd  = ObjectGetInteger(0, nm, OBJPROP_ZORDER);
         long zT1   = ObjectGetInteger(0, nm, OBJPROP_TIME, 0);
         long zT2   = ObjectGetInteger(0, nm, OBJPROP_TIME, 1);
         double zP1 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
         double zP2 = ObjectGetDouble(0, nm, OBJPROP_PRICE, 1);
         FileWrite(fh, "   RECTPAINT color=", zCol, " fill=", zFill, " back=", zBack,
                      " z=", zOrd,
                      " t1=", TimeToString((datetime)zT1, TIME_DATE | TIME_SECONDS),
                      " t2=", TimeToString((datetime)zT2, TIME_DATE | TIME_SECONDS),
                      " p1=", DoubleToString(zP1, 8), " p2=", DoubleToString(zP2, 8));
      }

      if(t == OBJ_HLINE)
      {
         int n2 = ArraySize(linePrices);
         ArrayResize(linePrices, n2 + 1);
         linePrices[n2] = DoubleToString(pr, 8);

         // Level-line price per step index (zone rects excluded - different family).
         if(StringFind(nm, "_Zone_") < 0)
         {
            int st2 = LevelDumpTrailingInt(nm);
            if(st2 > 0 && st2 < LEVEL_DUMP_MAX_STEP)
            {
               if(StringFind(nm, "_Above_") >= 0)      chartAbove[st2] = pr;
               else if(StringFind(nm, "_Below_") >= 0) chartBelow[st2] = pr;
            }
         }
      }

      // family accounting
      for(int f = 0; f < FAM_N; f++)
      {
         if(StringFind(nm, fam[f].suffix) < 0) continue;
         fam[f].seen++;
         if(tf == OBJ_ALL_PERIODS)      fam[f].visible++;
         else if(tf == OBJ_NO_PERIODS)  fam[f].hidden++;
         else                           fam[f].otherMask++;

         int st = LevelDumpTrailingInt(nm);
         if(st >= 0)
         {
            if(fam[f].minStep < 0 || st < fam[f].minStep) fam[f].minStep = st;
            if(st > fam[f].maxStep) fam[f].maxStep = st;
            fam[f].stepList += IntegerToString(st) + ",";
         }
      }
   }

   FileWrite(fh, "");
   FileWrite(fh, "ours=", ours, "  hlines=", ArraySize(linePrices));
   FileWrite(fh, "");

   // ---- per-family summary: created vs masked ----
   FileWrite(fh, "---- family summary (suffix | seen | visible | hidden | otherMask | minStep | maxStep) ----");
   for(int f = 0; f < FAM_N; f++)
      FileWrite(fh, fam[f].suffix, " | ", fam[f].seen, " | ", fam[f].visible, " | ",
                    fam[f].hidden, " | ", fam[f].otherMask, " | ",
                    fam[f].minStep, " | ", fam[f].maxStep);
   FileWrite(fh, "");
   for(int f = 0; f < FAM_N; f++)
      FileWrite(fh, "steps[", fam[f].suffix, "]=", fam[f].stepList);
   FileWrite(fh, "");

   // ---- the numbers behind the picture: every HLINE price, sorted ----
   int n = ArraySize(linePrices);
   for(int a = 1; a < n; a++)
   {
      string key = linePrices[a];
      int b = a - 1;
      while(b >= 0 && StringToDouble(linePrices[b]) > StringToDouble(key))
      {
         linePrices[b + 1] = linePrices[b];
         b--;
      }
      linePrices[b + 1] = key;
   }
   FileWrite(fh, "---- every HLINE price, ascending (gap = the report) ----");
   for(int a = 0; a < n; a++)
   {
      double p = StringToDouble(linePrices[a]);
      double gapPips = 0.0;
      if(a > 0)
      {
         double prev = StringToDouble(linePrices[a - 1]);
         double pip = GetCachedPipSize();
         if(pip > 0.0) gapPips = (p - prev) / pip;
      }
      FileWrite(fh, DoubleToString(p, 8), "   gapFromPrev=", DoubleToString(gapPips, 2), " pips");
   }

   // =====================================================================
   // CURRENT BUILD GEOMETRY  vs  WHAT THE CHART CARRIES
   //
   // This is the section that settles the question the header describes.
   // The pipeline is provably CONTIGUOUS, so if the chart holds a hole, the
   // objects flanking it cannot both belong to the live geometry: at least one
   // of them is STALE - left behind by an earlier geometry, never corrected
   // (the render only moves objects that are inside the viewport) and never
   // deleted (cleanup removes only step indices beyond the current count).
   //
   // Every disagreement is named here with its size in pips, per step index,
   // per direction. Nothing else in the project can produce this number.
   // =====================================================================
   FileWrite(fh, "");
   FileWrite(fh, "---- CURRENT BUILD GEOMETRY ----");

   double vpTop = 0.0, vpBottom = 0.0;
   GetViewportBounds(vpTop, vpBottom);
   double pipDump = GetCachedPipSize();
   if(pipDump <= 0.0) pipDump = GetCachedPoint() * 10.0;
   FileWrite(fh, "vpTop=", DoubleToString(vpTop, 8), "  vpBottom=", DoubleToString(vpBottom, 8),
                  "  widthPips=", DoubleToString((vpTop - vpBottom) / pipDump, 2));

   SCommonStepData gdata;
   bool gOk = CalculateCommonStepData(g_dailyClosePriceForTH, gdata);
   FileWrite(fh, "CalculateCommonStepData=", (gOk ? "ok" : "FAILED"),
                  "  midpointPrice=", DoubleToString(gdata.midpointPrice, 8));
   FileWrite(fh, "  th=", DoubleToString(gdata.thValue, 8),
                  "  struct=", DoubleToString(gdata.structureValue, 8),
                  "  shortStep=", DoubleToString(gdata.shortStep, 8),
                  "  longStep=", DoubleToString(gdata.longStep, 8),
                  "  maxAbove=", gdata.maxLevelsAbove, "  maxBelow=", gdata.maxLevelsBelow);

   ENUM_STEP_CALCULATION_MODE gmode = GetCurrentStepMode();
   SModeDefinition gdef = GetModeDefinition(gmode, pfx, gdata, g_dailyClosePriceForTH);
   FileWrite(fh, "mode=", EnumToString(gmode), "  def.success=", (gdef.success ? 1 : 0),
                  "  modeName=", gdef.config.modeName,
                  "  stepSizeCount=", gdef.stepSizeCount,
                  "  stepMode=", (int)gdef.stepMode,
                  "  classifyMode=", (int)gdef.classifyMode,
                  "  lsFirst=", (gdef.lsFirst ? 1 : 0));
   {
      string szTxt = "";
      for(int s = 0; s < gdef.stepSizeCount; s++)
         szTxt += DoubleToString(gdef.stepSizes[s], 8) + " (" +
                  DoubleToString(gdef.stepSizes[s] / pipDump, 4) + " pips)  ";
      FileWrite(fh, "stepSizes=", szTxt);
   }

   if(gOk && gdef.success)
   {
      double sizes[];
      ArrayResize(sizes, gdef.stepSizeCount);
      for(int s = 0; s < gdef.stepSizeCount; s++) sizes[s] = gdef.stepSizes[s];

      SCalculatedLevel calc[];
      int calcMaxStep = 0;
      int calcCount = CalculateLevels(gdata.midpointPrice, sizes, gdef.stepSizeCount,
                                      gdef.stepMode, gdef.lsFirst,
                                      gdata.maxLevelsAbove, gdata.maxLevelsBelow,
                                      gdef.config.boundByHistorical,
                                      gdef.config.maxPrice, gdef.config.minPrice,
                                      calc, calcMaxStep);

      // Order the geometry the way the chart names it, then derive the LINE price
      // the builder stores: lines[].price = midpoint of THIS level and the one
      // before it (BuildZonesAndLines), so `_Above_k` is NOT at level k's price.
      double abv[]; int nAbv = 0;
      double blw[]; int nBlw = 0;
      ArrayResize(abv, calcCount); ArrayResize(blw, calcCount);
      for(int i = 0; i < calcCount; i++)
      {
         if(calc[i].isMidpoint) continue;
         if(calc[i].direction > 0)      abv[nAbv++] = calc[i].price;
         else if(calc[i].direction < 0) blw[nBlw++] = calc[i].price;
      }
      FileWrite(fh, "CalculateLevels: count=", calcCount,
                     "  drawnAbove=", nAbv, "  drawnBelow=", nBlw,
                     "  maxStepOut=", calcMaxStep);

      FileWrite(fh, "");
      FileWrite(fh, "---- RECONCILE (step | onChart | expected | deltaPips | verdict) ----");
      FileWrite(fh, "  OK      = the object matches the live geometry");
      FileWrite(fh, "  STALE   = the object belongs to ANOTHER geometry (a hole maker)");
      FileWrite(fh, "  MISSING = geometry has this level, the chart does not carry it");
      FileWrite(fh, "  BEYOND  = object exists past the drawn count (must be deleted)");

      for(int dir = 0; dir < 2; dir++)
      {
         FileWrite(fh, (dir == 0 ? "ABOVE (dir=+1)" : "BELOW (dir=-1)"));
         // Seed with the SHIFTED CENTRE, not the raw anchor. CalculateLevels walks
         // outward from `shiftedCenter = centerPrice + stepSizes[0] * 0.5`
         // (LevelPipeline.mqh:190), and the builder stores each line at the
         // midpoint of consecutive levels. Seeding with `midpointPrice` therefore
         // makes step 1 disagree by exactly step/4 - 0.25 * 9.6609 = 2.42 pips in
         // the H1 case - in BOTH directions, i.e. a false STALE on every run.
         //
         // The shift is deliberately NOT signed by direction: the same
         // +0.5 * step applies to both ladders, which is precisely why
         // `_Above_1` and `_Below_1` sit one full step apart rather than being
         // mirror images of each other. Signing it here would re-break step 1 in
         // the below direction by half a step.
         double prev = gdata.midpointPrice + gdef.stepSizes[0] * 0.5;
         int    nDir = (dir == 0) ? nAbv : nBlw;
         int    kMax = MathMax(nDir, calcMaxStep);
         for(int k = 1; k <= kMax; k++)
         {
            double onChart  = (dir == 0) ? chartAbove[k] : chartBelow[k];
            double expected = 0.0;
            if(k <= nDir)
            {
               double cur = (dir == 0) ? abv[k - 1] : blw[k - 1];
               expected = (prev + cur) / 2.0;   // what the builder would store
               prev = cur;
            }

            string verdict = "";
            double delta = 0.0;
            if(expected > 0.0 && onChart > 0.0)
            {
               delta   = (onChart - expected) / pipDump;
               verdict = (MathAbs(delta) < 0.05) ? "OK" : "STALE";
            }
            else if(expected > 0.0) verdict = "MISSING";
            else if(onChart > 0.0)  verdict = "BEYOND";
            else continue;   // nothing on the chart and nothing expected: silent

            FileWrite(fh, "step=", k,
                          " | onChart=", (onChart  > 0.0 ? DoubleToString(onChart,  8) : "-"),
                          " | expected=", (expected > 0.0 ? DoubleToString(expected, 8) : "-"),
                          " | deltaPips=", DoubleToString(delta, 2),
                          " | ", verdict);
         }
      }

      ArrayFree(sizes);
   }

   FileClose(fh);
}

void MT5LevelDumpTick()
{
   static uint s_lastMs = 0;
   static uint s_armedAt = 0;
   if(s_armedAt == 0) { s_armedAt = GetTickCount(); return; }
   // Let the attach settle: dumping mid-build would report the churn.
   if(GetTickCount() - s_armedAt < 3000) return;
   uint now = GetTickCount();
   if(s_lastMs != 0 && (now - s_lastMs) < LEVEL_DUMP_EVERY) return;
   s_lastMs = now;
   MT5LevelDumpWrite();
}

#else

// Disabled: the dump compiles to nothing at all.
#define MT5LevelDumpTick()

#endif // ENABLE_MT5_LEVEL_DUMP

#endif // MT5_LEVEL_DUMP_MQH
