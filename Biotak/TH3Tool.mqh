//+------------------------------------------------------------------+
//| TH3Tool.mqh - AB=CD Pattern Drawing System                      |
//+------------------------------------------------------------------+
#define ABCD_MIN_DISTANCE_POINTS 10
#define ABCD_DEBOUNCE_MS 300

//+------------------------------------------------------------------+
//| Set active AB=CD pattern (for info label display)                |
//+------------------------------------------------------------------+
void SetActiveABCDPattern(string patternName)
{
    if(g_activeABCDPattern == patternName) return;

    if(g_activeABCDPattern != "") {
        string oldInfoLabel = g_activeABCDPattern + "_Info";
        if(ObjectFind(0, oldInfoLabel) >= 0)
            ObjectSetInteger(0, oldInfoLabel, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    }

    g_activeABCDPattern = patternName;

    if(patternName != "") {
        string newInfoLabel = patternName + "_Info";
        if(ObjectFind(0, newInfoLabel) >= 0)
            ObjectSetInteger(0, newInfoLabel, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calculate AB=CD Point D                                          |
//| Rule: AB distance = CD distance (equal price movement)           |
//+------------------------------------------------------------------+
bool CalculateABCDPointD(datetime tA, double pA, datetime tB, double pB,
                         datetime tC, double pC, datetime &tD, double &pD)
{
    if(tA <= 0 || tB <= 0 || tC <= 0) return false;
    if(pA <= 0 || pB <= 0 || pC <= 0) return false;

    double AB_Distance = MathAbs(pB - pA);
    double minDistance = GetCachedPoint() * ABCD_MIN_DISTANCE_POINTS;
    if(AB_Distance < minDistance) return false;

    bool isBullish = (pB > pA);
    pD = isBullish ? (pC + AB_Distance) : (pC - AB_Distance);

    int BC_Bars = iBarShift(_Symbol, _Period, tB) - iBarShift(_Symbol, _Period, tC);
    if(BC_Bars < 1) BC_Bars = 1;

    int barD = iBarShift(_Symbol, _Period, tC) - BC_Bars;
    if(barD < 0) barD = 0;

    tD = iTime(_Symbol, 0, barD);
    if(tD <= 0) tD = tC + (tC - tB);
    if(pD <= 0) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Draw AB=CD Pattern with TH3-style Steps                          |
//| User provides A, B, C -> System calculates D                     |
//| Targets (Step1/3/5/7) start from C (not D)                      |
//+------------------------------------------------------------------+
void DrawABCDPattern(string mainObjName, datetime tA, double pA, datetime tB, double pB,
                     datetime tC, double pC)
{
    datetime tD;
    double pD;
    if(!CalculateABCDPointD(tA, pA, tB, pB, tC, pC, tD, pD)) {
        string pointNames[4] = {"A", "B", "C", "D"};
        for(int i = 0; i < 4; i++) {
            ObjectDelete(0, mainObjName + "_Point_" + pointNames[i]);
            ObjectDelete(0, mainObjName + "_Label_" + pointNames[i]);
        }
        ObjectDelete(0, mainObjName + "_Line_AB");
        ObjectDelete(0, mainObjName + "_Line_BC");
        ObjectDelete(0, mainObjName + "_Info");
        return;
    }

    double AB_Distance = MathAbs(pB - pA);
    bool isBullish = (pB > pA);
    double frequency = (g_th3FreqOverride > 0) ? g_th3FreqOverride : inpTH3BaseStepPercent;
    double baseUnit = AB_Distance * (frequency / 100.0);
    double pipSize = GetCachedPipSize();

    // Create/update points A, B, C
    string pointNames[4];
    pointNames[0] = "A";
    pointNames[1] = "B";
    pointNames[2] = "C";
    pointNames[3] = "D";

    datetime pointTimes[4];
    pointTimes[0] = tA;
    pointTimes[1] = tB;
    pointTimes[2] = tC;
    pointTimes[3] = tD;

    double pointPrices[4];
    pointPrices[0] = pA;
    pointPrices[1] = pB;
    pointPrices[2] = pC;
    pointPrices[3] = pD;

    for(int i = 0; i < 3; i++) {
        string pointName = mainObjName + "_Point_" + pointNames[i];
        double pointPrice = pointPrices[i];

        if(ObjectFind(0, pointName) < 0) {
            ObjectCreate(0, pointName, OBJ_ARROW, 0, pointTimes[i], pointPrice);
            ObjectSetInteger(0, pointName, OBJPROP_COLOR, inpABCDPointColor);
            ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, pointName, OBJPROP_BACK, false);
            ObjectSetInteger(0, pointName, OBJPROP_ZORDER, 10);
            ObjectSetString(0, pointName, OBJPROP_TOOLTIP,
                            "📍 Point " + pointNames[i] + " | Drag to adjust");
        } else {
            ObjectMove(0, pointName, 0, pointTimes[i], pointPrice);
        }

        if(inpABCDShowLabels) {
            string labelName = mainObjName + "_Label_" + pointNames[i];
            if(ObjectFind(0, labelName) >= 0)
                ObjectDelete(0, labelName);
        }
    }

    // Line AB
    string lineAB = mainObjName + "_Line_AB";
    if(ObjectFind(0, lineAB) < 0) {
        ObjectCreate(0, lineAB, OBJ_TREND, 0, tA, pA, tB, pB);
        ObjectSetInteger(0, lineAB, OBJPROP_COLOR, inpABCDLineColor);
        ObjectSetInteger(0, lineAB, OBJPROP_WIDTH, inpABCDWidth);
        ObjectSetInteger(0, lineAB, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, lineAB, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineAB, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineAB, OBJPROP_BACK, false);
    } else {
        ObjectMove(0, lineAB, 0, tA, pA);
        ObjectMove(0, lineAB, 1, tB, pB);
    }

    // Line BC
    string lineBC = mainObjName + "_Line_BC";
    if(ObjectFind(0, lineBC) < 0) {
        ObjectCreate(0, lineBC, OBJ_TREND, 0, tB, pB, tC, pC);
        ObjectSetInteger(0, lineBC, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, lineBC, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lineBC, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lineBC, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineBC, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineBC, OBJPROP_BACK, true);
    } else {
        ObjectMove(0, lineBC, 0, tB, pB);
        ObjectMove(0, lineBC, 1, tC, pC);
    }

    // Target levels (Step1, Step3, Step5, Step7) from C
    string targetNames[4] = {"Step1", "Step3", "Step5", "Step7"};
    color targetColors[4] = {clrNavy, clrNavy, clrNavy, clrNavy};
    double multipliers[4] = {1.0, 3.0, 5.0, 7.0};

    double targetLevels[4];
    double targetPips[4];
    for(int i = 0; i < 4; i++) {
        targetLevels[i] = isBullish ? (pC + multipliers[i] * baseUnit)
                                    : (pC - multipliers[i] * baseUnit);
        targetPips[i] = MathAbs(baseUnit * multipliers[i]) / pipSize;
    }

    datetime startTime = tC;
    int barShift = iBarShift(_Symbol, _Period, startTime);
    datetime endTime = iTime(_Symbol, 0, MathMax(0, barShift - 100));

    double zoneHeightPercent = inpTH3ZoneHeightPercent / 100.0;
    if(zoneHeightPercent < 0.01) zoneHeightPercent = 0.01;
    if(zoneHeightPercent > 1.0) zoneHeightPercent = 1.0;
    double zoneHalfWidth = baseUnit * zoneHeightPercent;

    for(int i = 0; i < 4; i++) {
        string lineName = mainObjName + "_Target_" + IntegerToString(i + 1);
        double centerPrice = targetLevels[i];
        double upperZone = centerPrice + zoneHalfWidth;
        double lowerZone = centerPrice - zoneHalfWidth;
        color zoneColor = (inpTH3ZoneColor == clrNONE) ? targetColors[i] : inpTH3ZoneColor;

        if(ObjectFind(0, lineName) < 0) {
            ObjectCreate(0, lineName, OBJ_FIBO, 0, startTime, centerPrice, endTime, centerPrice);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetColors[i]);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, targetColors[i]);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELWIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELS, 1);
            ObjectSetDouble(0, lineName, OBJPROP_LEVELVALUE, 0, 0.0);
        } else {
            ObjectMove(0, lineName, 0, startTime, centerPrice);
            ObjectMove(0, lineName, 1, endTime, centerPrice);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, targetColors[i]);
        }

        if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
            double zonePips = (zoneHalfWidth * 2.0) / pipSize;
            string labelText = StringFormat("%s (%.1f) ±%.1f",
                                            targetNames[i], targetPips[i], zonePips / 2.0);
            ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
        }

        // Zone border lines
        string zoneUpperName = mainObjName + "_ZoneUpper_" + IntegerToString(i + 1);
        string zoneLowerName = mainObjName + "_ZoneLower_" + IntegerToString(i + 1);

        if(inpTH3ZoneStyle == TH3_ZONE_LINES) {
            if(ObjectFind(0, zoneUpperName) < 0) {
                ObjectCreate(0, zoneUpperName, OBJ_TREND, 0, startTime, upperZone, endTime, upperZone);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_COLOR, zoneColor);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_BACK, true);
            } else {
                ObjectMove(0, zoneUpperName, 0, startTime, upperZone);
                ObjectMove(0, zoneUpperName, 1, endTime, upperZone);
            }

            if(ObjectFind(0, zoneLowerName) < 0) {
                ObjectCreate(0, zoneLowerName, OBJ_TREND, 0, startTime, lowerZone, endTime, lowerZone);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_COLOR, zoneColor);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_BACK, true);
            } else {
                ObjectMove(0, zoneLowerName, 0, startTime, lowerZone);
                ObjectMove(0, zoneLowerName, 1, endTime, lowerZone);
            }
        }
    }

    // Info label
    double pips_AB = AB_Distance / pipSize;
    double pips_BC = MathAbs(pC - pB) / pipSize;
    string infoText = StringFormat("AB=CD | AB:%.1f | BC:%.1f | Freq:%.1f%%",
                                   pips_AB, pips_BC, frequency);
    string infoLabel = mainObjName + "_Info";
    bool isActive = (g_activeABCDPattern == mainObjName);

    if(ObjectFind(0, infoLabel) < 0) {
        ObjectCreate(0, infoLabel, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
        ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, inpABCDInfoYDistance);
        ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
        ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
        ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
        ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, infoLabel, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, infoLabel, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    } else {
        ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
        ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
        ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, inpABCDInfoYDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
        ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
        ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update All TH3 Objects (when frequency changes)                  |
//+------------------------------------------------------------------+
void UpdateAllTH3Objects()
{
    int totalObjects = ObjectsTotal(0, 0, -1);
    string patternNames[];
    int patternCount = 0;
    // PERF: Pre-allocate with reserve to avoid repeated ArrayResize(+1)
    int reserveSize = MathMin(totalObjects, 64);
    ArrayResize(patternNames, reserveSize);

    for(int i = 0; i < totalObjects; i++) {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "ABCD_Pattern_") != 0) continue;

        int searchStart = 13;
        int underscorePos = StringFind(name, "_", searchStart);
        string baseName = (underscorePos > searchStart)
                          ? StringSubstr(name, 0, underscorePos)
                          : name;

        bool exists = false;
        for(int j = 0; j < patternCount; j++) {
            if(patternNames[j] == baseName) { exists = true; break; }
        }

        if(!exists) {
            if(patternCount >= ArraySize(patternNames))
                ArrayResize(patternNames, patternCount * 2 + 1);
            patternNames[patternCount] = baseName;
            patternCount++;
        }
    }

    for(int p = 0; p < patternCount; p++) {
        string baseName = patternNames[p];
        string lineAB = baseName + "_Line_AB";
        string lineBC = baseName + "_Line_BC";
        if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) continue;

        datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
        double pA   = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
        datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
        double pB   = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
        datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
        double pC   = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);

        if(tA > 0 && tB > 0 && tC > 0 && pA > 0 && pB > 0 && pC > 0)
            DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Helper: Create ABCD temporary point marker on chart              |
//+------------------------------------------------------------------+
void CreateABCDTempPoint(const string pointLabel, datetime clickTime, double clickPrice)
{
    string objName = "ABCD_Temp_" + pointLabel;
    ObjectCreate(0, objName, OBJ_TEXT, 0, clickTime, clickPrice);
    ObjectSetString(0, objName, OBJPROP_TEXT, pointLabel);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Helper: Create ABCD temporary trend line between two points      |
//+------------------------------------------------------------------+
void CreateABCDTempLine(const string lineSuffix, datetime t1, double p1, datetime t2, double p2)
{
    string objName = "ABCD_Temp_Line_" + lineSuffix;
    ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Helper: Cleanup temporary ABCD drawing objects                   |
//+------------------------------------------------------------------+
void CleanupABCDTempObjects()
{
    ObjectDelete(0, "ABCD_Temp_X");
    ObjectDelete(0, "ABCD_Temp_A");
    ObjectDelete(0, "ABCD_Temp_B");
    ObjectDelete(0, "ABCD_Temp_C");
    ObjectDelete(0, "ABCD_Temp_Line_XA");
    ObjectDelete(0, "ABCD_Temp_Line_AB");
    ObjectDelete(0, "ABCD_Temp_Line_BC");
}

//+------------------------------------------------------------------+
//| Helper: Cancel AB=CD drawing mode and cleanup                    |
//+------------------------------------------------------------------+
void CancelABCDDrawing()
{
    g_abcdDrawing = false;
    g_abcdPointCount = 0;
    CleanupABCDTempObjects();
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Handle ABCD point placement (X, A, B, C clicks)         |
//| Returns true when pattern is complete (4th point placed)         |
//+------------------------------------------------------------------+
bool HandleABCDPointPlacement(datetime clickTime, double clickPrice)
{
    if(g_abcdPointCount == 0) {
        g_abcdTimeX = clickTime;
        g_abcdPriceX = clickPrice;
        g_abcdPointCount = 1;
        CreateABCDTempPoint("X", clickTime, clickPrice);
        ChartRedraw();
    }
    else if(g_abcdPointCount == 1) {
        g_abcdTimeA = clickTime;
        g_abcdPriceA = clickPrice;
        g_abcdPointCount = 2;
        CreateABCDTempPoint("A", clickTime, clickPrice);
        CreateABCDTempLine("XA", g_abcdTimeX, g_abcdPriceX, g_abcdTimeA, g_abcdPriceA);
        ChartRedraw();
    }
    else if(g_abcdPointCount == 2) {
        g_abcdTimeB = clickTime;
        g_abcdPriceB = clickPrice;
        g_abcdPointCount = 3;
        CreateABCDTempPoint("B", clickTime, clickPrice);
        CreateABCDTempLine("AB", g_abcdTimeA, g_abcdPriceA, g_abcdTimeB, g_abcdPriceB);
        ChartRedraw();
    }
    else if(g_abcdPointCount == 3) {
        g_abcdTimeC = clickTime;
        g_abcdPriceC = clickPrice;

        string patternName = "ABCD_Pattern_" + IntegerToString((long)GetTickCount());
        DrawABCDPattern(patternName, g_abcdTimeA, g_abcdPriceA,
                        g_abcdTimeB, g_abcdPriceB, g_abcdTimeC, g_abcdPriceC);
        SetActiveABCDPattern(patternName);
        CancelABCDDrawing();
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Handle AB=CD Mouse Events (3-point click workflow)               |
//+------------------------------------------------------------------+
void OnABCDMouseEvent(int id, long lparam, double dparam, string sparam)
{
    // Mouse move events - track button state for click detection
    if(id == CHARTEVENT_MOUSE_MOVE) {
        int mouseState = (int)StringToInteger(sparam);
        bool rightButtonDown = (mouseState & 2) == 2;
        bool leftButtonDown  = (mouseState & 1) == 1;

        // Right-click cancels drawing
        if(rightButtonDown && g_abcdDrawing) {
            CancelABCDDrawing();
            return;
        }

        static bool s_lastLeftButtonState = false;
        if(g_abcdDrawing && leftButtonDown && !s_lastLeftButtonState) {
            s_lastLeftButtonState = true;

            uint currentTime = GetTickCount();
            if(currentTime - g_abcdLastClickTime < ABCD_DEBOUNCE_MS) return;
            g_abcdLastClickTime = currentTime;

            int subWindow;
            datetime clickTime;
            double clickPrice;
            if(!ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindow, clickTime, clickPrice))
                return;

            HandleABCDPointPlacement(clickTime, clickPrice);
        }
        else if(!leftButtonDown && s_lastLeftButtonState) {
            s_lastLeftButtonState = false;
        }

        return;
    }

    // Standard click events
    if(id == CHARTEVENT_CLICK && g_abcdDrawing) {
        uint currentTime = GetTickCount();
        if(currentTime - g_abcdLastClickTime < ABCD_DEBOUNCE_MS) return;
        g_abcdLastClickTime = currentTime;

        int subWindow;
        datetime clickTime;
        double clickPrice;
        if(!ChartXYToTimePrice(0, (int)lparam, (int)dparam, subWindow, clickTime, clickPrice))
            return;

        HandleABCDPointPlacement(clickTime, clickPrice);
    }

    // Object drag - update pattern when dragging A, B, or C
    if(id == CHARTEVENT_OBJECT_DRAG) {
        if(StringFind(sparam, "ABCD_Pattern_") != 0 || StringFind(sparam, "_Point_") <= 0)
            return;

        int pointPos = StringFind(sparam, "_Point_");
        string baseName  = StringSubstr(sparam, 0, pointPos);
        string pointName = StringSubstr(sparam, pointPos + 7);
        if(pointName != "A" && pointName != "B" && pointName != "C") return;

        SetActiveABCDPattern(baseName);

        string draggedPoint = baseName + "_Point_" + pointName;
        datetime newTime  = (datetime)ObjectGetInteger(0, draggedPoint, OBJPROP_TIME, 0);
        double newPrice   = ObjectGetDouble(0, draggedPoint, OBJPROP_PRICE, 0);

        // Snap to OHLC if within threshold
        int barIndex = iBarShift(_Symbol, _Period, newTime);
        if(barIndex >= 0) {
            double high  = iHigh(_Symbol, 0, barIndex);
            double low   = iLow(_Symbol, 0, barIndex);
            double open  = iOpen(_Symbol, 0, barIndex);
            double close = iClose(_Symbol, 0, barIndex);
            double pipSz = GetCachedPipSize();
            double snapThreshold = 5.0;

            double distToHigh  = MathAbs(newPrice - high)  / pipSz;
            double distToLow   = MathAbs(newPrice - low)   / pipSz;
            double distToOpen  = MathAbs(newPrice - open)  / pipSz;
            double distToClose = MathAbs(newPrice - close) / pipSz;
            double minDist = MathMin(MathMin(distToHigh, distToLow),
                                     MathMin(distToOpen, distToClose));

            if(minDist <= snapThreshold) {
                if(minDist == distToHigh)       newPrice = high;
                else if(minDist == distToLow)   newPrice = low;
                else if(minDist == distToClose) newPrice = close;
                else if(minDist == distToOpen)  newPrice = open;
                ObjectSetDouble(0, draggedPoint, OBJPROP_PRICE, newPrice);
            }
        }

        // Read current coordinates from lines
        string lineAB = baseName + "_Line_AB";
        string lineBC = baseName + "_Line_BC";
        if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) return;

        datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
        double pA   = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
        datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
        double pB   = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
        datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
        double pC   = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);

        if(pointName == "A")      { tA = newTime; pA = newPrice; }
        else if(pointName == "B") { tB = newTime; pB = newPrice; }
        else if(pointName == "C") { tC = newTime; pC = newPrice; }

        DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
    }

    // Object delete - cleanup entire pattern when any part is deleted
    if(id == CHARTEVENT_OBJECT_DELETE) {
        if(StringFind(sparam, "ABCD_Pattern_") != 0) return;

        string baseName = sparam;
        string suffixes[7];
        suffixes[0] = TH3_SUFFIX_LINE_AB;
        suffixes[1] = TH3_SUFFIX_LINE_BC;
        suffixes[2] = TH3_SUFFIX_TARGET;
        suffixes[3] = TH3_SUFFIX_POINT;
        suffixes[4] = TH3_SUFFIX_LABEL;
        suffixes[5] = TH3_SUFFIX_INFO;
        suffixes[6] = TH3_SUFFIX_ZONE;

        for(int s = 0; s < ArraySize(suffixes); s++) {
            int pos = StringFind(baseName, suffixes[s]);
            if(pos > 0) { baseName = StringSubstr(baseName, 0, pos); break; }
        }

        if(StringFind(baseName, "ABCD_Pattern_") != 0 || StringLen(baseName) < 20) return;

        string ptNames[3] = {"A", "B", "C"};
        for(int i = 0; i < 3; i++) {
            ObjectDelete(0, baseName + "_Point_" + ptNames[i]);
            ObjectDelete(0, baseName + "_Label_" + ptNames[i]);
        }

        ObjectDelete(0, baseName + "_Line_AB");
        ObjectDelete(0, baseName + "_Line_BC");
        ObjectDelete(0, baseName + "_Info");

        for(int i = 1; i <= 7; i++) {
            ObjectDelete(0, baseName + "_Target_" + IntegerToString(i));
            ObjectDelete(0, baseName + "_ZoneUpper_" + IntegerToString(i));
            ObjectDelete(0, baseName + "_ZoneLower_" + IntegerToString(i));
        }

        CleanupABCDTempObjects();

        if(g_activeABCDPattern == baseName)
            SetActiveABCDPattern("");

        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| Toggle TH3 Tool (V key)                                          |
//+------------------------------------------------------------------+
void ToggleTH3Tool()
{
    if(!inpEnableTH3Tool) return;

    if(inpTH3DrawingMode == TH3_MODE_ABCD) {
        if(!g_abcdDrawing) {
            g_abcdDrawing = true;
            g_abcdPointCount = 0;
            g_abcdLastClickTime = 0;
            ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
        } else {
            CancelABCDDrawing();
        }
    }
}
