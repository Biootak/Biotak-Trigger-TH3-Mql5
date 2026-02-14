//+------------------------------------------------------------------+
//| TH3Tool.mqh - AB=CD Pattern Drawing & Interaction System         |
//+------------------------------------------------------------------+
#ifndef TH3_TOOL_MQH
#define TH3_TOOL_MQH

// Object naming constants
#define TH3_PATTERN_PREFIX      "ABCD_Pattern_"
#define TH3_TEMP_PREFIX         "ABCD_Temp_"
#define TH3_TEMP_LINE_PREFIX    "ABCD_Temp_Line_"
#define TH3_PATTERN_PREFIX_LEN  13

// Drawing constants
#define TH3_ARROW_CODE          159
#define TH3_POINT_WIDTH         3
#define TH3_POINT_ZORDER        10
#define TH3_TARGET_COUNT        4
#define TH3_TARGET_LINE_WIDTH   2
#define TH3_BAR_EXTENSION       100
#define TH3_SNAP_THRESHOLD_PIPS 5.0
#define TH3_MIN_BASENAME_LEN    20
#define TH3_MAX_TARGETS         7

//+------------------------------------------------------------------+
//| Create or update a trend line object                             |
//+------------------------------------------------------------------+
void CreateOrUpdateTrendLine(const string name, datetime t1, double p1,
                             datetime t2, double p2, color clr, int width,
                             ENUM_LINE_STYLE style, bool rayRight, bool back)
{
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, rayRight);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, back);
    } else {
        ObjectMove(0, name, 0, t1, p1);
        ObjectMove(0, name, 1, t2, p2);
    }
}

//+------------------------------------------------------------------+
//| Set active pattern for info label visibility                     |
//+------------------------------------------------------------------+
void SetActiveABCDPattern(string patternName)
{
    if(g_activeABCDPattern == patternName) return;

    if(g_activeABCDPattern != "") {
        string oldLabel = g_activeABCDPattern + TH3_SUFFIX_INFO;
        if(ObjectFind(0, oldLabel) >= 0)
            ObjectSetInteger(0, oldLabel, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    }

    g_activeABCDPattern = patternName;

    if(patternName != "") {
        string newLabel = patternName + TH3_SUFFIX_INFO;
        if(ObjectFind(0, newLabel) >= 0) {
            // Respect indicator hidden state — don't force visible when hidden
            long vis = IsIndicatorHidden() ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
            ObjectSetInteger(0, newLabel, OBJPROP_TIMEFRAMES, vis);
        }
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculate AB=CD Point D (equal price movement projection)        |
//+------------------------------------------------------------------+
bool CalculateABCDPointD(datetime tA, double pA, datetime tB, double pB,
                         datetime tC, double pC, datetime &tD, double &pD)
{
    if(tA <= 0 || tB <= 0 || tC <= 0) return false;
    if(pA <= 0 || pB <= 0 || pC <= 0) return false;

    double abDist = MathAbs(pB - pA);
    if(abDist < GetCachedPoint() * ABCD_MIN_DISTANCE_POINTS) return false;

    bool isBullish = (pB > pA);
    pD = isBullish ? (pC + abDist) : (pC - abDist);
    if(pD <= 0) return false;

    int bcBars = MathAbs(iBarShift(_Symbol, _Period, tB) - iBarShift(_Symbol, _Period, tC));
    if(bcBars < 1) bcBars = 1;

    int barD = iBarShift(_Symbol, _Period, tC) - bcBars;
    if(barD < 0) barD = 0;

    tD = iTime(_Symbol, 0, barD);
    if(tD <= 0) tD = tC + (tC - tB);

    return true;
}

//+------------------------------------------------------------------+
//| Cleanup all objects belonging to a pattern                       |
//+------------------------------------------------------------------+
void DeletePatternObjects(const string baseName)
{
    string ptNames[3] = {"A", "B", "C"};
    for(int i = 0; i < 3; i++) {
        ObjectDelete(0, baseName + TH3_SUFFIX_POINT + ptNames[i]);
        ObjectDelete(0, baseName + TH3_SUFFIX_LABEL + ptNames[i]);
    }

    ObjectDelete(0, baseName + TH3_SUFFIX_LINE_AB);
    ObjectDelete(0, baseName + TH3_SUFFIX_LINE_BC);
    ObjectDelete(0, baseName + TH3_SUFFIX_INFO);

    for(int i = 1; i <= TH3_MAX_TARGETS; i++) {
        string idx = IntegerToString(i);
        ObjectDelete(0, baseName + TH3_SUFFIX_TARGET + idx);
        ObjectDelete(0, baseName + "_ZoneUpper_" + idx);
        ObjectDelete(0, baseName + "_ZoneLower_" + idx);
    }
}

//+------------------------------------------------------------------+
//| Draw ABCD point markers (A, B, C)                                |
//+------------------------------------------------------------------+
void DrawABCDPoints(const string mainObjName, datetime tA, double pA,
                    datetime tB, double pB, datetime tC, double pC)
{
    string names[3]     = {"A", "B", "C"};
    datetime times[3]   = {tA, tB, tC};
    double prices[3]    = {pA, pB, pC};

    // Smart positioning: detect peak/valley for each point
    bool isHigh[3];
    isHigh[0] = (pA > pB);  // A is peak if higher than B
    isHigh[1] = (pB > pA);  // B is peak if higher than A
    isHigh[2] = (pC > pB);  // C is peak if higher than B (mirrors A's role)

    // Calculate label offset proportional to pattern size
    double patternRange = MathAbs(pB - pA);
    double labelOffset = patternRange * inpABCDLabelOffsetPercent / 100.0;
    if(labelOffset < _Point * 5) labelOffset = _Point * 5;  // minimum offset

    for(int i = 0; i < 3; i++) {
        string pointName = mainObjName + TH3_SUFFIX_POINT + names[i];
        // Dot anchor: ANCHOR_BOTTOM for peaks (dot appears above price),
        //             ANCHOR_TOP for valleys (dot appears below price)
        ENUM_ARROW_ANCHOR dotAnchor = isHigh[i] ? ANCHOR_BOTTOM : ANCHOR_TOP;

        if(ObjectFind(0, pointName) < 0) {
            ObjectCreate(0, pointName, OBJ_ARROW, 0, times[i], prices[i]);
            ObjectSetInteger(0, pointName, OBJPROP_COLOR, inpABCDPointColor);
            ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, TH3_ARROW_CODE);
            ObjectSetInteger(0, pointName, OBJPROP_WIDTH, TH3_POINT_WIDTH);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, pointName, OBJPROP_BACK, false);
            ObjectSetInteger(0, pointName, OBJPROP_ZORDER, TH3_POINT_ZORDER);
            ObjectSetInteger(0, pointName, OBJPROP_ANCHOR, dotAnchor);
            ObjectSetString(0, pointName, OBJPROP_TOOLTIP,
                            "[PIN] Point " + names[i] + " | Drag to adjust");
        } else {
            ObjectMove(0, pointName, 0, times[i], prices[i]);
            ObjectSetInteger(0, pointName, OBJPROP_ANCHOR, dotAnchor);
        }

        if(inpABCDShowLabels) {
            // Smart label positioning: above peaks, below valleys
            string labelName = mainObjName + TH3_SUFFIX_LABEL + names[i];
            double labelPrice = isHigh[i] ? (prices[i] + labelOffset) : (prices[i] - labelOffset);
            ENUM_ANCHOR_POINT labelAnchor = isHigh[i] ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER;

            if(ObjectFind(0, labelName) < 0) {
                ObjectCreate(0, labelName, OBJ_TEXT, 0, times[i], labelPrice);
                ObjectSetString(0, labelName, OBJPROP_TEXT, "  " + names[i]);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, inpABCDPointColor);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, inpFontSize + 1);
                ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, labelAnchor);
            } else {
                ObjectMove(0, labelName, 0, times[i], labelPrice);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, labelAnchor);
            }
        } else {
            // Labels disabled — remove if they exist
            string labelName = mainObjName + TH3_SUFFIX_LABEL + names[i];
            if(ObjectFind(0, labelName) >= 0)
                ObjectDelete(0, labelName);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw target step levels with zones                               |
//+------------------------------------------------------------------+
void DrawABCDTargetLevels(const string mainObjName, double pC, double baseUnit,
                          bool isBullish, datetime startTime, double pipSize)
{
    string targetNames[TH3_TARGET_COUNT]  = {"Step1", "Step3", "Step5", "Step7"};
    double multipliers[TH3_TARGET_COUNT]  = {1.0, 3.0, 5.0, 7.0};

    int barShift = iBarShift(_Symbol, _Period, startTime);
    datetime endTime = iTime(_Symbol, 0, MathMax(0, barShift - TH3_BAR_EXTENSION));

    double zonePercent = MathMax(0.01, MathMin(1.0, inpTH3ZoneHeightPercent / 100.0));
    double zoneHalfWidth = baseUnit * zonePercent;

    for(int i = 0; i < TH3_TARGET_COUNT; i++) {
        double center = isBullish ? (pC + multipliers[i] * baseUnit)
                                  : (pC - multipliers[i] * baseUnit);
        double targetPips = MathAbs(baseUnit * multipliers[i]) / pipSize;

        string lineName = mainObjName + TH3_SUFFIX_TARGET + IntegerToString(i + 1);
        if(ObjectFind(0, lineName) < 0) {
            ObjectCreate(0, lineName, OBJ_FIBO, 0, startTime, center, endTime, center);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, inpABCDLineColor);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, inpABCDLineColor);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, TH3_TARGET_LINE_WIDTH);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELWIDTH, TH3_TARGET_LINE_WIDTH);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELS, 1);
            ObjectSetDouble(0, lineName, OBJPROP_LEVELVALUE, 0, 0.0);
        } else {
            ObjectMove(0, lineName, 0, startTime, center);
            ObjectMove(0, lineName, 1, endTime, center);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, clrDarkBlue);
        }

        if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
            double zonePips = (zoneHalfWidth * 2.0) / pipSize;
            string labelText = StringFormat("%s (%.1f) +/-%.1f",
                                            targetNames[i], targetPips, zonePips / 2.0);
            ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
        }

        if(inpTH3ZoneStyle == TH3_ZONE_LINES) {
            double upper = center + zoneHalfWidth;
            double lower = center - zoneHalfWidth;
            color zoneColor = (inpTH3ZoneColor == clrNONE) ? clrDarkBlue : inpTH3ZoneColor;
            string idx = IntegerToString(i + 1);

            CreateOrUpdateTrendLine(mainObjName + "_ZoneUpper_" + idx,
                                    startTime, upper, endTime, upper,
                                    zoneColor, inpTH3ZoneBorderWidth, inpTH3ZoneBorderStyle,
                                    inpABCDExtendCD, true);
            CreateOrUpdateTrendLine(mainObjName + "_ZoneLower_" + idx,
                                    startTime, lower, endTime, lower,
                                    zoneColor, inpTH3ZoneBorderWidth, inpTH3ZoneBorderStyle,
                                    inpABCDExtendCD, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Compute safe Y position for TH3 info label                       |
//| Accounts for ATR labels + all possible stacked mode labels       |
//+------------------------------------------------------------------+
int GetABCDInfoSafeYDistance()
{
    int y = inpABCDInfoYDistance;

    bool topCorner = (inpABCDInfoCorner == CORNER_LEFT_UPPER || inpABCDInfoCorner == CORNER_RIGHT_UPPER);
    if(!topCorner) return y;

    // ATR/TH label stack currently lives at top-left when label corner is LEFT_TOP.
    // If TH3 info is also in top-left, push it below that stack.
    if(inpLabelCornerPosition == LABEL_CORNER_LEFT_TOP && inpABCDInfoCorner == CORNER_LEFT_UPPER) {
        int stackedTopY = inpLabelsMarginTop + g_modeLabelYOffset + inpSectionGap;
        if(y < stackedTopY) y = stackedTopY;
    }

    // Push below ALL stacked mode labels + lock label
    if(inpModeLabelCorner == inpABCDInfoCorner) {
        int modeBlockHeight = GetModeLabelBlockHeight();
        int modeBottomY;
        if(modeBlockHeight > 0)
            modeBottomY = inpModeLabelYDistance + g_modeLabelYOffset + modeBlockHeight + 4;
        else
            modeBottomY = inpModeLabelYDistance + g_modeLabelYOffset + (inpModeLabelFontSize + 6) + 4;

        // If lock label is visible, add space for it too
        if(g_timeframeLocked) {
            modeBottomY += (inpModeLabelFontSize + 6);
        }
        if(y < modeBottomY) y = modeBottomY;
    }

    return y;
}

//+------------------------------------------------------------------+
//| Create or update info label for a pattern                        |
//+------------------------------------------------------------------+
void DrawABCDInfoLabel(const string mainObjName, double abDist, double pB,
                       double pC, double frequency, double pipSize)
{
    string infoText;
    if(g_lastFreqResult.isValid) {
        // Confidence stars: ★★★ (≥0.7), ★★ (≥0.4), ★ (<0.4)
        string stars = (g_lastFreqResult.confidence >= 0.7) ? "***" :
                       (g_lastFreqResult.confidence >= 0.4) ? "**" : "*";
        // Pattern type (if detected)
        string pat = (g_lastFreqResult.patternType != "") ?
                     (" " + g_lastFreqResult.patternType) : "";
        // √-score indicator: show if meaningful (> 0.3)
        string sqrtInd = (g_lastFreqResult.sqrtScore >= 0.3) ?
                         StringFormat(" V%.0f", g_lastFreqResult.sqrtScore * 100) : "";
        infoText = StringFormat("Freq:%.1f%% | %s %d/4 | Score:%.2f%s%s | %s | Err:%.1f",
                                frequency, stars, g_lastFreqResult.matchedSteps,
                                g_lastFreqResult.totalScore, pat, sqrtInd,
                                g_lastFreqResult.matchLabel, g_lastFreqResult.errorPips);
    } else {
        double pipsAB = abDist / pipSize;
        double pipsBC = MathAbs(pC - pB) / pipSize;
        infoText = StringFormat("AB=CD | AB:%.1f | BC:%.1f | Freq:%.1f%%",
                                pipsAB, pipsBC, frequency);
    }

    string infoLabel = mainObjName + TH3_SUFFIX_INFO;
    bool isActive = (g_activeABCDPattern == mainObjName);
    // Respect indicator hidden state
    long visibility = (isActive && !IsIndicatorHidden()) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;

    if(ObjectFind(0, infoLabel) < 0)
        ObjectCreate(0, infoLabel, OBJ_LABEL, 0, 0, 0);

    int safeY = GetABCDInfoSafeYDistance();

    ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
    ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
    ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, safeY);
    ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
    ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
    ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
    ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, infoLabel, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, infoLabel, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, visibility);
}

//+------------------------------------------------------------------+
//| Reposition all ABCD info labels (lightweight — Y update only)    |
//| Call after g_modeLabelYOffset changes to prevent overlap         |
//+------------------------------------------------------------------+
void RepositionABCDInfoLabels()
{
    if(!inpEnableTH3Tool) return;
    int safeY = GetABCDInfoSafeYDistance();
    int totalObjects = ObjectsTotal(0, 0, -1);
    for(int i = 0; i < totalObjects; i++) {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, TH3_PATTERN_PREFIX) == 0 &&
           StringFind(name, TH3_SUFFIX_INFO) > 0) {
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, safeY);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw complete AB=CD pattern with TH3 step targets                |
//+------------------------------------------------------------------+
void DrawABCDPattern(string mainObjName, datetime tA, double pA,
                     datetime tB, double pB, datetime tC, double pC)
{
    datetime tD;
    double pD;
    if(!CalculateABCDPointD(tA, pA, tB, pB, tC, pC, tD, pD)) {
        DeletePatternObjects(mainObjName);
        return;
    }

    double abDist    = MathAbs(pB - pA);
    bool isBullish   = (pB > pA);
    double frequency = (g_th3FreqOverride > 0) ? g_th3FreqOverride : inpTH3BaseStepPercent;
    double baseUnit  = abDist * (frequency / 100.0);
    double pipSize   = GetCachedPipSize();

    DrawABCDPoints(mainObjName, tA, pA, tB, pB, tC, pC);

    CreateOrUpdateTrendLine(mainObjName + TH3_SUFFIX_LINE_AB,
                            tA, pA, tB, pB, inpABCDLineColor, inpABCDWidth, STYLE_SOLID, false, false);
    CreateOrUpdateTrendLine(mainObjName + TH3_SUFFIX_LINE_BC,
                            tB, pB, tC, pC, clrGray, 1, STYLE_DOT, false, true);

    DrawABCDTargetLevels(mainObjName, pC, baseUnit, isBullish, tC, pipSize);
    DrawABCDInfoLabel(mainObjName, abDist, pB, pC, frequency, pipSize);

    // NOTE: ChartRedraw is caller's responsibility (avoids N+1 redraws in UpdateAllTH3Objects)
}

//+------------------------------------------------------------------+
//| Update all existing TH3 patterns (on frequency change)           |
//+------------------------------------------------------------------+
void UpdateAllTH3Objects()
{
    int totalObjects = ObjectsTotal(0, 0, -1);
    string patternNames[];
    int patternCount = 0;
    ArrayResize(patternNames, MathMin(totalObjects, 64));

    for(int i = 0; i < totalObjects; i++) {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, TH3_PATTERN_PREFIX) != 0) continue;

        int underscorePos = StringFind(name, "_", TH3_PATTERN_PREFIX_LEN);
        string baseName = (underscorePos > TH3_PATTERN_PREFIX_LEN)
                          ? StringSubstr(name, 0, underscorePos)
                          : name;

        bool exists = false;
        for(int j = 0; j < patternCount; j++) {
            if(patternNames[j] == baseName) { exists = true; break; }
        }

        if(!exists) {
            if(patternCount >= ArraySize(patternNames))
                ArrayResize(patternNames, patternCount * 2 + 1);
            patternNames[patternCount++] = baseName;
        }
    }

    for(int p = 0; p < patternCount; p++) {
        string baseName = patternNames[p];
        string lineAB = baseName + TH3_SUFFIX_LINE_AB;
        string lineBC = baseName + TH3_SUFFIX_LINE_BC;
        if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) continue;

        datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
        double   pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
        datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
        double   pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
        datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
        double   pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);

        if(tA > 0 && tB > 0 && tC > 0 && pA > 0 && pB > 0 && pC > 0)
            DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create temporary point marker during ABCD drawing                |
//+------------------------------------------------------------------+
void CreateABCDTempPoint(const string pointLabel, datetime clickTime, double clickPrice)
{
    // Smart positioning: detect if click is near candle high or low
    // to place the label above peaks and below valleys
    int barIndex = iBarShift(_Symbol, _Period, clickTime);
    double candleHigh = iHigh(_Symbol, _Period, barIndex);
    double candleLow  = iLow(_Symbol, _Period, barIndex);
    double candleMid  = (candleHigh + candleLow) / 2.0;
    bool isHigh = (clickPrice >= candleMid);

    // Offset from visible chart range for consistent visual spacing
    double chartHigh = ChartGetDouble(0, CHART_PRICE_MAX);
    double chartLow  = ChartGetDouble(0, CHART_PRICE_MIN);
    double offset = (chartHigh - chartLow) * 0.015;
    if(offset < _Point * 5) offset = _Point * 5;

    double labelPrice = isHigh ? (clickPrice + offset) : (clickPrice - offset);
    ENUM_ANCHOR_POINT anchor = isHigh ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER;

    string objName = TH3_TEMP_PREFIX + pointLabel;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_TEXT, 0, clickTime, labelPrice);
    } else {
        ObjectMove(0, objName, 0, clickTime, labelPrice);
    }
    ObjectSetString(0, objName, OBJPROP_TEXT, pointLabel);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrangeRed);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, inpFontSize + 2);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//+------------------------------------------------------------------+
//| Create temporary trend line during ABCD drawing                  |
//+------------------------------------------------------------------+
void CreateABCDTempLine(const string lineSuffix, datetime t1, double p1,
                        datetime t2, double p2)
{
    string objName = TH3_TEMP_LINE_PREFIX + lineSuffix;
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
    } else {
        ObjectMove(0, objName, 0, t1, p1);
        ObjectMove(0, objName, 1, t2, p2);
    }
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrangeRed);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//+------------------------------------------------------------------+
//| Cleanup temporary ABCD drawing objects                           |
//+------------------------------------------------------------------+
void CleanupABCDTempObjects()
{
    ObjectDelete(0, TH3_TEMP_PREFIX + "X");
    ObjectDelete(0, TH3_TEMP_PREFIX + "A");
    ObjectDelete(0, TH3_TEMP_PREFIX + "B");
    ObjectDelete(0, TH3_TEMP_PREFIX + "C");
    ObjectDelete(0, TH3_TEMP_LINE_PREFIX + "XA");
    ObjectDelete(0, TH3_TEMP_LINE_PREFIX + "AB");
    ObjectDelete(0, TH3_TEMP_LINE_PREFIX + "BC");
    ObjectDelete(0, TH3_TEMP_LINE_PREFIX + "Preview");
}

//+------------------------------------------------------------------+
//| Cancel ABCD drawing mode and cleanup                             |
//+------------------------------------------------------------------+
void CancelABCDDrawing()
{
    g_abcdDrawing = false;
    g_abcdPointCount = 0;
    CleanupABCDTempObjects();
    Comment("");
    // NOTE: Do NOT disable CHART_EVENT_MOUSE_MOVE here.
    // It is enabled globally at OnInit and other features (custom price drag)
    // depend on it remaining active.
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Handle sequential ABCD point clicks (X -> A -> B -> C)           |
//| Returns true when pattern is complete (C placed)                 |
//+------------------------------------------------------------------+
bool HandleABCDPointPlacement(datetime clickTime, double clickPrice)
{
    switch(g_abcdPointCount) {
        case 0:
            g_abcdTimeX  = clickTime;
            g_abcdPriceX = clickPrice;
            g_abcdPointCount = 1;
            CreateABCDTempPoint("X", clickTime, clickPrice);
            Comment("TH3: Click to place point A");
            ChartRedraw();
            return false;

        case 1:
            g_abcdTimeA  = clickTime;
            g_abcdPriceA = clickPrice;
            g_abcdPointCount = 2;
            CreateABCDTempPoint("A", clickTime, clickPrice);
            CreateABCDTempLine("XA", g_abcdTimeX, g_abcdPriceX, clickTime, clickPrice);
            Comment("TH3: Click to place point B");
            ChartRedraw();
            return false;

        case 2:
            g_abcdTimeB  = clickTime;
            g_abcdPriceB = clickPrice;
            g_abcdPointCount = 3;
            CreateABCDTempPoint("B", clickTime, clickPrice);
            CreateABCDTempLine("AB", g_abcdTimeA, g_abcdPriceA, clickTime, clickPrice);
            Comment("TH3: Click to place point C");
            ChartRedraw();
            return false;

        case 3:
            g_abcdTimeC  = clickTime;
            g_abcdPriceC = clickPrice;
            break;

        default:
            return false;
    }

    // C placed — auto-optimize frequency and draw pattern
    FrequencyResult freqResult;
    if(FindOptimalFrequency(g_abcdPriceX, g_abcdTimeX,
                            g_abcdPriceA, g_abcdTimeA,
                            g_abcdPriceB, g_abcdTimeB,
                            g_abcdPriceC, g_abcdTimeC, freqResult)) {
        ApplyOptimalFrequency(freqResult);
        UpdateTH3FreqLabel(g_th3FreqOverride);
        g_lastFreqResult = freqResult;
    }

    string patternName = TH3_PATTERN_PREFIX + IntegerToString((long)GetTickCount());
    DrawABCDPattern(patternName, g_abcdTimeA, g_abcdPriceA,
                    g_abcdTimeB, g_abcdPriceB, g_abcdTimeC, g_abcdPriceC);
    SetActiveABCDPattern(patternName);
    CancelABCDDrawing();
    return true;
}

//+------------------------------------------------------------------+
//| Snap price to nearest OHLC if within threshold                   |
//+------------------------------------------------------------------+
double SnapToOHLC(datetime barTime, double price, double pipSize)
{
    if(pipSize <= 0) return price;  // Guard against division by zero
    int barIndex = iBarShift(_Symbol, _Period, barTime);
    if(barIndex < 0) return price;

    double ohlc[4];
    ohlc[0] = iHigh(_Symbol, 0, barIndex);
    ohlc[1] = iLow(_Symbol, 0, barIndex);
    ohlc[2] = iClose(_Symbol, 0, barIndex);
    ohlc[3] = iOpen(_Symbol, 0, barIndex);

    double minDist = DBL_MAX;
    double snapped = price;

    for(int i = 0; i < 4; i++) {
        double dist = MathAbs(price - ohlc[i]) / pipSize;
        if(dist < minDist) {
            minDist = dist;
            snapped = ohlc[i];
        }
    }

    return (minDist <= TH3_SNAP_THRESHOLD_PIPS) ? snapped : price;
}

//+------------------------------------------------------------------+
//| Extract base pattern name from any child object name             |
//+------------------------------------------------------------------+
string ExtractPatternBaseName(const string objName)
{
    if(StringFind(objName, TH3_PATTERN_PREFIX) != 0) return "";

    string suffixes[] = {
        TH3_SUFFIX_LINE_AB, TH3_SUFFIX_LINE_BC, TH3_SUFFIX_TARGET,
        TH3_SUFFIX_POINT, TH3_SUFFIX_LABEL, TH3_SUFFIX_INFO, TH3_SUFFIX_ZONE
    };

    string baseName = objName;
    for(int s = 0; s < ArraySize(suffixes); s++) {
        int pos = StringFind(baseName, suffixes[s]);
        if(pos > 0) { baseName = StringSubstr(baseName, 0, pos); break; }
    }

    if(StringFind(baseName, TH3_PATTERN_PREFIX) != 0 || StringLen(baseName) < TH3_MIN_BASENAME_LEN)
        return "";

    return baseName;
}

//+------------------------------------------------------------------+
//| Process click during ABCD drawing mode (debounced)               |
//+------------------------------------------------------------------+
bool ProcessABCDClick(long xPixel, long yPixel)
{
    uint currentTime = GetTickCount();
    if(currentTime - g_abcdLastClickTime < ABCD_DEBOUNCE_MS) return false;
    g_abcdLastClickTime = currentTime;

    int subWindow;
    datetime clickTime;
    double clickPrice;
    if(!ChartXYToTimePrice(0, (int)xPixel, (int)yPixel, subWindow, clickTime, clickPrice))
        return false;

    return HandleABCDPointPlacement(clickTime, clickPrice);
}

//+------------------------------------------------------------------+
//| Handle mouse move events during ABCD drawing                     |
//+------------------------------------------------------------------+
void HandleABCDMouseMove(long lparam, double dparam, string sparam)
{
    int mouseState = (int)StringToInteger(sparam);
    bool rightButtonDown = (mouseState & 2) == 2;
    bool leftButtonDown  = (mouseState & 1) == 1;

    if(rightButtonDown && g_abcdDrawing) {
        CancelABCDDrawing();
        return;
    }

    static bool s_lastLeftButtonState = false;
    if(g_abcdDrawing && leftButtonDown && !s_lastLeftButtonState) {
        s_lastLeftButtonState = true;
        ProcessABCDClick(lparam, (long)dparam);
    }
    else if(!leftButtonDown && s_lastLeftButtonState) {
        s_lastLeftButtonState = false;
    }

    // Draw rubber-band preview line from last placed point to mouse cursor
    if(g_abcdDrawing && g_abcdPointCount > 0 && !leftButtonDown) {
        int subWindow;
        datetime mouseTime;
        double mousePrice;
        if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindow, mouseTime, mousePrice)) {
            datetime lastTime;
            double lastPrice;
            switch(g_abcdPointCount) {
                case 1: lastTime = g_abcdTimeX; lastPrice = g_abcdPriceX; break;
                case 2: lastTime = g_abcdTimeA; lastPrice = g_abcdPriceA; break;
                case 3: lastTime = g_abcdTimeB; lastPrice = g_abcdPriceB; break;
                default: return;
            }
            CreateABCDTempLine("Preview", lastTime, lastPrice, mouseTime, mousePrice);
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Handle point drag — update pattern when A, B, or C are moved     |
//+------------------------------------------------------------------+
void HandleABCDObjectDrag(const string sparam)
{
    if(StringFind(sparam, TH3_PATTERN_PREFIX) != 0) return;
    if(StringFind(sparam, TH3_SUFFIX_POINT) <= 0) return;

    int pointPos = StringFind(sparam, TH3_SUFFIX_POINT);
    string baseName  = StringSubstr(sparam, 0, pointPos);
    string pointName = StringSubstr(sparam, pointPos + 7);

    if(pointName != "A" && pointName != "B" && pointName != "C") return;

    SetActiveABCDPattern(baseName);

    string draggedObj = baseName + TH3_SUFFIX_POINT + pointName;
    datetime newTime  = (datetime)ObjectGetInteger(0, draggedObj, OBJPROP_TIME, 0);
    double newPrice   = ObjectGetDouble(0, draggedObj, OBJPROP_PRICE, 0);

    double pipSize    = GetCachedPipSize();
    double snapped    = SnapToOHLC(newTime, newPrice, pipSize);
    if(snapped != newPrice)
        ObjectSetDouble(0, draggedObj, OBJPROP_PRICE, snapped);
    newPrice = snapped;

    string lineAB = baseName + TH3_SUFFIX_LINE_AB;
    string lineBC = baseName + TH3_SUFFIX_LINE_BC;
    if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) return;

    datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
    double   pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
    datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
    double   pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
    datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
    double   pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);

    if(pointName == "A")      { tA = newTime; pA = newPrice; }
    else if(pointName == "B") { tB = newTime; pB = newPrice; }
    else if(pointName == "C") { tC = newTime; pC = newPrice; }

    // Re-optimize frequency after drag using stored X point
    if(g_abcdTimeX > 0 && g_abcdPriceX > 0) {
        // Update global ABCD state for history push
        g_abcdPriceA = pA; g_abcdTimeA = tA;
        g_abcdPriceB = pB; g_abcdTimeB = tB;
        g_abcdPriceC = pC; g_abcdTimeC = tC;

        FrequencyResult freqResult;
        if(FindOptimalFrequency(g_abcdPriceX, g_abcdTimeX,
                                pA, tA, pB, tB, pC, tC, freqResult)) {
            ApplyOptimalFrequency(freqResult);
            UpdateTH3FreqLabel(g_th3FreqOverride);
            g_lastFreqResult = freqResult;
        }
    }

    DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Handle object deletion — cleanup entire pattern                  |
//+------------------------------------------------------------------+
void HandleABCDObjectDelete(const string sparam)
{
    string baseName = ExtractPatternBaseName(sparam);
    if(baseName == "") return;

    DeletePatternObjects(baseName);
    CleanupABCDTempObjects();

    if(g_activeABCDPattern == baseName)
        SetActiveABCDPattern("");

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Main ABCD event dispatcher                                       |
//+------------------------------------------------------------------+
void OnABCDMouseEvent(int id, long lparam, double dparam, string sparam)
{
    if(id == CHARTEVENT_MOUSE_MOVE) {
        HandleABCDMouseMove(lparam, dparam, sparam);
        return;
    }

    if(id == CHARTEVENT_CLICK && g_abcdDrawing) {
        ProcessABCDClick(lparam, (long)dparam);
        return;
    }

    if(id == CHARTEVENT_OBJECT_DRAG) {
        HandleABCDObjectDrag(sparam);
        return;
    }

    if(id == CHARTEVENT_OBJECT_DELETE) {
        HandleABCDObjectDelete(sparam);
        return;
    }
}

//+------------------------------------------------------------------+
//| Toggle TH3 drawing mode (V key)                                  |
//+------------------------------------------------------------------+
void ToggleTH3Tool()
{
    if(!inpEnableTH3Tool) return;
    if(inpTH3DrawingMode != TH3_MODE_ABCD) return;

    if(!g_abcdDrawing) {
        CleanupABCDTempObjects();
        g_abcdDrawing = true;
        g_abcdPointCount = 0;
        g_abcdLastClickTime = 0;
        ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
        Comment("TH3: Click to place point X");
    } else {
        CancelABCDDrawing();
    }
}

#endif // TH3_TOOL_MQH
