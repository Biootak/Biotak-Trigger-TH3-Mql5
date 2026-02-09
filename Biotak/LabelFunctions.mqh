
bool DrawMainLevels(const string prefix) {
    // Skip drawing High/Low lines when Custom Price mode is active
    // In Custom Price mode, user defines their own reference point
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        // Delete existing High/Low lines if they exist
        ObjectDelete(0, prefix + "High");
        ObjectDelete(0, prefix + "High_PipsLabel");
        ObjectDelete(0, prefix + "Low");
        ObjectDelete(0, prefix + "Low_PipsLabel");
        return true;
    }
    
    // OPTIMIZATION: Cache tooltip strings and only recalculate if prices changed
    static double s_lastHighPrice = 0;
    static double s_lastLowPrice = 0;
    static string s_cachedHighTooltip = "";
    static string s_cachedLowTooltip = "";
    
    // High line
    string highTooltip;
    if(s_lastHighPrice != g_highestHigh) {
        highTooltip = inpHighLineTooltip + ": " + DoubleToString(g_highestHigh, GetCachedDigits());
        double pipsToHigh = CalculatePipsDistance(g_highestHigh, g_currentPrice);
        highTooltip = highTooltip + ", Distance: +/- " + DoubleToString(pipsToHigh, 1) + " pips";
        s_cachedHighTooltip = highTooltip;
        s_lastHighPrice = g_highestHigh;
    } else {
        highTooltip = s_cachedHighTooltip;
    }
    if(!CreateTHLineObject(prefix+"High",g_highestHigh,inpHighColor,inpHighStyle,inpHighWidth,highTooltip, inpTHLineObjectType, false)) return false;
    if(inpShowPipDistanceLabels) {
        double pipsToHigh = CalculatePipsDistance(g_highestHigh, g_currentPrice);
        CreatePipDistanceLabel(prefix+"High_PipsLabel", g_highestHigh, pipsToHigh, inpHighColor);
    }
    
    // Low line
    string lowTooltip;
    if(s_lastLowPrice != g_lowestLow) {
        lowTooltip = inpLowLineTooltip + ": " + DoubleToString(g_lowestLow, GetCachedDigits());
        double pipsToLow = CalculatePipsDistance(g_lowestLow, g_currentPrice);
        lowTooltip = lowTooltip + ", Distance: +/- " + DoubleToString(pipsToLow, 1) + " pips";
        s_cachedLowTooltip = lowTooltip;
        s_lastLowPrice = g_lowestLow;
    } else {
        lowTooltip = s_cachedLowTooltip;
    }
    if(!CreateTHLineObject(prefix+"Low",g_lowestLow,inpLowColor,inpLowStyle,inpLowWidth,lowTooltip, inpTHLineObjectType, false)) return false;
    if(inpShowPipDistanceLabels) {
        double pipsToLow = CalculatePipsDistance(g_lowestLow, g_currentPrice);
        CreatePipDistanceLabel(prefix+"Low_PipsLabel", g_lowestLow, pipsToLow, inpLowColor);
    }
    return true;
}

void DrawTHLevels(const string objectPrefix, const double dailyClosePrice) {
    if(dailyClosePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Invalid daily close price");
        #endif
        return;
    }
    
    // OPTIMIZATION: Use centralized cached values from PerformanceOptimizations.mqh
    double s_cachedPointValue = GetCachedPoint();
    int s_cachedDigits = GetCachedDigits();
    string s_cachedSymbol = GetCachedSymbol();
    
    string prefix=objectPrefix+"TH_Level_";
    // Note: ClearAllLevels is called in DrawLevelsBasedOnMode before this function
    double timeframePercentage=GetTimeframeTH();
    string structureTimeframe = GetStructureTimeframeForCurrent();
    double structureTFPercentage=CalculateTimeframeTH(structureTimeframe);
    if(structureTFPercentage <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Invalid structure timeframe percentage");
        #endif
        return;
    }
    double structureMultipliers[] = {1.0, 2.0, 4.0, 8.0, 16.0};
    double structurePercentages[];
    // PERFORMANCE: Cache ArraySize before loop
    int structureMultipliersCount = ArraySize(structureMultipliers);
    if(ArrayResize(structurePercentages, structureMultipliersCount) != structureMultipliersCount) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Failed to resize structurePercentages array");
        #endif
        return;
    }
    for(int i=0; i<structureMultipliersCount; i++) {
        structurePercentages[i] = structureTFPercentage * structureMultipliers[i];
        if(structurePercentages[i] <= 0) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("DrawTHLevels: Invalid structure percentage at index ", i);
            #endif
            return;
        }
    }
    if(timeframePercentage<=0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Invalid timeframe percentage");
        #endif
        return;
    }
    
    // Use cached values instead of recalculating
    int digits = s_cachedDigits;
    if(digits < 0 || digits > 8) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Invalid digits value: ", digits);
        #endif
        return;
    }
    double thStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,timeframePercentage);
    double structureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[0]);
    double doubleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[1]);
    double tripleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[2]);
    double quadrupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[3]);
    double quintupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[4]);
    if (thStepSizePoints <= 0 || structureTFTHStepSizePoints <= 0 || doubleStructureTFTHStepSizePoints <= 0) return;
    
    // ═══════════════════════════════════════════════════════════════════
    // FIX: Use configurable Base Multiplier instead of hardcoded values
    // Matches Java implementation in LevelDrawer.java (getPathForStep)
    // ═══════════════════════════════════════════════════════════════════
    int baseMultiplier = GetValidatedBaseMultiplier(); // Use central validation
    
    // Get cached intervals for the base multiplier (base^1, base^2, base^3, base^4, base^5)
    int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    
    // GOLD FIX #11: Array bounds checking - get size for safe access
    int intervalSize = ArraySize(intervals);
    if(intervalSize == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawTHLevels: Empty intervals array, cannot draw structure levels");
        #endif
        return;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("📊 DrawTHLevels using Base Multiplier: ", baseMultiplier,
          " → L1=", intervals[0], ", L2=", intervals[1], ", L3=", intervals[2],
          ", L4=", intervals[3], ", L5=", intervals[4]);
    #endif
    // ═══════════════════════════════════════════════════════════════════
    
    // Get midpoint price using utility function
    double midpointPrice = GetMidpointPrice(g_thStartPointType);
    double pointValue = s_cachedPointValue;
    
    if(inpShowMidpointLine) {
        string lineNameMid=prefix+"Mid";
        string tooltipMid=StringFormat("Trigger TH Midpoint Level (%s)",DoubleToString(midpointPrice,digits));
        double pipsToMid = CalculatePipsDistance(midpointPrice, g_currentPrice);
        tooltipMid = FormatTooltipWithDistance(tooltipMid, midpointPrice);
        CreateTHLineObject(lineNameMid,midpointPrice,inpTriggerColor,inpTriggerStyle,inpTriggerWidth,tooltipMid, inpTHLineObjectType, false);
        string cachedTFForMid = GetFractalTimeframeForCurrent();
        string midLevelInfo = StringFormat("%s Mid", GetShortTimeframeName(cachedTFForMid));
        if(inpShowPipDistanceLabels) CreatePipDistanceLabel(prefix+"Mid_PipsLabel", midpointPrice, pipsToMid, inpTriggerColor, midLevelInfo);
    }
    // OPTIMIZATION: Cache IsTriggerLevelsEnabled() result BEFORE the loops
    bool triggerEnabled = IsTriggerLevelsEnabled();
    
    // PERFORMANCE: Get chart viewport range to skip off-screen levels
    double chartPriceMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double chartPriceMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double viewportRange = chartPriceMax - chartPriceMin;
    // Add 100% margin around viewport so levels appear smoothly when scrolling
    double vpTop = chartPriceMax + viewportRange;
    double vpBottom = chartPriceMin - viewportRange;
    
    // ═══════════════════════════════════════════════════════════════
    // ZONE SUPPORT: Cleanup old zones
    // پشتیبانی Zone: پاکسازی zone های قدیمی
    // ═══════════════════════════════════════════════════════════════
    if(inpShowMidZones) {
        ObjectsDeleteAll(0, prefix + "Zone_", -1, -1);
    }
    
    if (triggerEnabled || inpShowStructure) {
        // Get adaptive level counts based on start point type
        int maxLevelsAbove = 0;
        int maxLevelsBelow = 0;
        GetAdaptiveLevelCounts(maxLevelsAbove, maxLevelsBelow);
        
        // Determine if we should check historical high/low bounds
        // Custom Price mode: Only respect level count, ignore historical bounds
        // Historical modes (High/Low/Midpoint): Respect both level count AND historical bounds
        bool checkHistoricalBounds = (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE);
        
        // OPTIMIZATION: Cache GetFractalTimeframeForCurrent() and related values BEFORE the loops
        string cachedCurrentTF = GetFractalTimeframeForCurrent();
        double cachedPatternTH = GetLowerTimeframeTH(cachedCurrentTF, 1);
        double cachedTriggerTH = GetLowerTimeframeTH(cachedCurrentTF, 2);
        double cachedLongStep = timeframePercentage * 2.0;
        double cachedShortStep = timeframePercentage * 1.5;
        // PERFORMANCE: Cache shortCurrentTF once instead of calling per iteration
        string shortCurrentTFCached = GetShortTimeframeName(cachedCurrentTF);
        
        // ═══════════════════════════════════════════════════════════════
        // ZONE SUPPORT: Tracking variables for Structure/Trigger separation
        // پشتیبانی Zone: متغیرهای ردیابی برای جداسازی Structure/Trigger
        // ═══════════════════════════════════════════════════════════════
        double lastDrawnPriceAbove = midpointPrice;  // Track last structure level
        double lastTriggerPriceAbove = 0;            // Track last trigger level
        int zoneCountAbove = 0;
        
        double priceLevelAbove = midpointPrice + (thStepSizePoints * pointValue);
        // NO NormalizeDouble - keep full precision to match MotiveWave
        int stepCountAbove = 1;
        int levelCountAbove = 0;
        
        // Loop condition: Custom Price = only count, Historical = count AND bounds
        while ((checkHistoricalBounds ? (priceLevelAbove <= g_highestHigh) : true) && levelCountAbove < maxLevelsAbove) {
            string lineNameAbove, tooltipAbove, levelInfoAbove;
            color lineColor;
            ENUM_LINE_STYLE lineStyle = inpTHLineStyle;
            int lineWidth;
            double percentageTooltip = 0.0;
            
            // PERFORMANCE FIX: Early viewport culling — skip ALL string work for off-screen levels
            bool isAboveVisible = (priceLevelAbove >= vpBottom && priceLevelAbove <= vpTop);
            
            // Determine which level type this step is (needed for both counting and drawing)
            // We must still identify level type even for off-screen to maintain correct state
            int levelType = 0; // 0=skip, 1=structure, 2=trigger
            int structLevel = 0;
            
            if (intervals[4] > 0 && stepCountAbove % intervals[4] == 0 && inpShowStructure && inpShowStructureL5) {
                levelType = 1; structLevel = 5;
            } else if (intervalSize > 3 && intervals[3] > 0 && stepCountAbove % intervals[3] == 0 && inpShowStructure && inpShowStructureL4) {
                levelType = 1; structLevel = 4;
            } else if (intervalSize > 2 && intervals[2] > 0 && stepCountAbove % intervals[2] == 0 && inpShowStructure && inpShowStructureL3) {
                levelType = 1; structLevel = 3;
            } else if (intervalSize > 1 && intervals[1] > 0 && stepCountAbove % intervals[1] == 0 && inpShowStructure && inpShowStructureL2) {
                levelType = 1; structLevel = 2;
            } else if (intervalSize > 0 && intervals[0] > 0 && stepCountAbove % intervals[0] == 0 && inpShowStructure && inpShowStructureL1) {
                levelType = 1; structLevel = 1;
            } else if (triggerEnabled) {
                levelType = 2;
            }
            
            // If this step is not a level at all, skip entirely
            if(levelType == 0) {
                priceLevelAbove += (thStepSizePoints * pointValue);
                stepCountAbove++;
                continue;
            }
            
            // If off-screen, skip string building and object creation but count the level
            if(!isAboveVisible) {
                levelCountAbove++;
                priceLevelAbove += (thStepSizePoints * pointValue);
                stepCountAbove++;
                continue;
            }
            
            // === ON-SCREEN: build strings and create objects ===
            string overlapLevels = GetOverlapLevelsInfo(stepCountAbove, intervals);
            string overlapTFs = GetOverlapTimeframesInfo(stepCountAbove, intervals);
            
            if(levelType == 1) {
                // Structure level
                switch(structLevel) {
                    case 5: {
                        string tfL5 = GetShortTimeframeName(GetTimeframeForStructureLevel(5));
                        lineNameAbove = prefix + "StructureLevel5_Up_" + IntegerToString(stepCountAbove / intervals[4]);
                        tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | TH: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[4], DoubleToString(priceLevelAbove, digits), quintupleStructureTFTHStepSizePoints / 10.0);
                        levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[4]);
                        lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
                        percentageTooltip = structurePercentages[4];
                        break;
                    }
                    case 4: {
                        lineNameAbove = prefix + "StructureLevel4_Up_" + IntegerToString(stepCountAbove / intervals[3]);
                        tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | TH: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[3], DoubleToString(priceLevelAbove, digits), quadrupleStructureTFTHStepSizePoints / 10.0);
                        levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[3]);
                        lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
                        percentageTooltip = structurePercentages[3];
                        break;
                    }
                    case 3: {
                        lineNameAbove = prefix + "StructureLevel3_Up_" + IntegerToString(stepCountAbove / intervals[2]);
                        tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | TH: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[2], DoubleToString(priceLevelAbove, digits), tripleStructureTFTHStepSizePoints / 10.0);
                        levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[2]);
                        lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
                        percentageTooltip = structurePercentages[2];
                        break;
                    }
                    case 2: {
                        lineNameAbove = prefix + "StructureLevel2_Up_" + IntegerToString(stepCountAbove / intervals[1]);
                        tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | TH: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[1], DoubleToString(priceLevelAbove, digits), doubleStructureTFTHStepSizePoints / 10.0);
                        levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[1]);
                        lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
                        percentageTooltip = structurePercentages[1];
                        break;
                    }
                    default: { // case 1
                        lineNameAbove = prefix + "StructureLevel1_Up_" + IntegerToString(stepCountAbove / intervals[0]);
                        tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | TH: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[0], DoubleToString(priceLevelAbove, digits), structureTFTHStepSizePoints / 10.0);
                        levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[0]);
                        lineColor = inpStructureL1Color; lineStyle = inpStructureL1Style; lineWidth = inpStructureL1Width;
                        percentageTooltip = structurePercentages[0];
                        break;
                    }
                }
            } else {
                // Trigger level
                lineNameAbove = prefix + "TriggerTH_Up_" + IntegerToString(stepCountAbove);
                tooltipAbove = StringFormat("[%s] +%d | Price: %s | L: %.1f, S: %.1f pips",
                    shortCurrentTFCached, stepCountAbove, DoubleToString(priceLevelAbove, digits),
                    cachedLongStep * thStepSizePoints / 10.0,
                    cachedShortStep * thStepSizePoints / 10.0);
                levelInfoAbove = StringFormat("%s +%d", shortCurrentTFCached, stepCountAbove);
                lineColor = inpTriggerColor; lineStyle = inpTriggerStyle; lineWidth = inpTriggerWidth;
                percentageTooltip = timeframePercentage;
            }
            
            double pipsToLevelAbove = CalculatePipsDistance(priceLevelAbove, g_currentPrice);
            tooltipAbove = FormatTooltipWithDistance(tooltipAbove, priceLevelAbove);
            
            CreateTHLineObject(lineNameAbove, priceLevelAbove, lineColor, lineStyle, lineWidth, tooltipAbove, inpTHLineObjectType, false);
            if(inpShowPipDistanceLabels) CreatePipDistanceLabel(lineNameAbove+"_PipsLabel", priceLevelAbove, pipsToLevelAbove, lineColor, levelInfoAbove);
            
            // ═══════════════════════════════════════════════════════════
            // ZONE SUPPORT: Create zone between levels
            // پشتیبانی Zone: ساخت zone بین سطوح
            // 
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            // رویکرد یکپارچه: از CreateZoneWithSmartFallback استفاده کن
            // GOLD VERSION: Uses GetHighestStructureLevel for clean logic
            // CRITICAL FIX: Pass fixed step size for consistent zone height
            // ═══════════════════════════════════════════════════════════
            if(inpShowMidZones) {
                // GOLD FIX: Use centralized function instead of repeated else-if
                int highestLevel = GetHighestStructureLevel(stepCountAbove, intervals);
                bool isStructureLevel = (highestLevel > 0 && inpShowStructure);
                
                string zoneName = prefix + "Zone_Above_" + IntegerToString(stepCountAbove);
                
                // CRITICAL FIX: Calculate fixed step size (matching M/SS/LS/Factor modes)
                double fixedStepSize = thStepSizePoints * pointValue;
                
                // Use unified smart fallback function
                // Note: We pass lastDrawnPriceAbove as both structure and fallback tracker
                // because in TH mode, when neither is enabled, we still want to track the last drawn price
                if(CreateZoneWithSmartFallback(zoneName, priceLevelAbove, isStructureLevel, lineColor,
                                              inpShowStructure, triggerEnabled,
                                              lastDrawnPriceAbove, lastTriggerPriceAbove, lastDrawnPriceAbove,
                                              fixedStepSize)) {  // Pass fixed step size
                    zoneCountAbove++;
                }
            }
            
            priceLevelAbove += (thStepSizePoints * pointValue);
            // NO NormalizeDouble - keep full precision to match MotiveWave
            stepCountAbove++;
            levelCountAbove++;
        }
        
        // ═══════════════════════════════════════════════════════════════
        // ZONE SUPPORT: Tracking variables for levels below
        // پشتیبانی Zone: متغیرهای ردیابی برای سطوح پایین
        // ═══════════════════════════════════════════════════════════════
        double lastDrawnPriceBelow = midpointPrice;  // Track last structure level
        double lastTriggerPriceBelow = 0;            // Track last trigger level
        int zoneCountBelow = 0;
        
        double priceLevelBelow = midpointPrice - (thStepSizePoints * pointValue);
        // NO NormalizeDouble - keep full precision to match MotiveWave
        int stepCountBelow = 1;
        int levelCountBelow = 0;
        
        // Loop condition: Custom Price = only count, Historical = count AND bounds
        while ((checkHistoricalBounds ? (priceLevelBelow >= g_lowestLow) : true) && levelCountBelow < maxLevelsBelow) {
            string lineNameBelow, tooltipBelow, levelInfoBelow;
            color lineColor;
            ENUM_LINE_STYLE lineStyle = inpTHLineStyle;
            int lineWidth;
            double percentageTooltip = 0.0;
            
            // PERFORMANCE FIX: Early viewport culling — skip ALL string work for off-screen levels
            bool isBelowVisible = (priceLevelBelow >= vpBottom && priceLevelBelow <= vpTop);
            
            // Determine level type (needed for counting even off-screen)
            int levelType = 0; // 0=skip, 1=structure, 2=trigger
            int structLevel = 0;
            
            if (intervals[4] > 0 && stepCountBelow % intervals[4] == 0 && inpShowStructure && inpShowStructureL5) {
                levelType = 1; structLevel = 5;
            } else if (intervals[3] > 0 && stepCountBelow % intervals[3] == 0 && inpShowStructure && inpShowStructureL4) {
                levelType = 1; structLevel = 4;
            } else if (intervals[2] > 0 && stepCountBelow % intervals[2] == 0 && inpShowStructure && inpShowStructureL3) {
                levelType = 1; structLevel = 3;
            } else if (intervals[1] > 0 && stepCountBelow % intervals[1] == 0 && inpShowStructure && inpShowStructureL2) {
                levelType = 1; structLevel = 2;
            } else if (intervals[0] > 0 && stepCountBelow % intervals[0] == 0 && inpShowStructure && inpShowStructureL1) {
                levelType = 1; structLevel = 1;
            } else if (triggerEnabled) {
                levelType = 2;
            }
            
            if(levelType == 0) {
                priceLevelBelow -= (thStepSizePoints * pointValue);
                stepCountBelow++;
                continue;
            }
            
            if(!isBelowVisible) {
                levelCountBelow++;
                priceLevelBelow -= (thStepSizePoints * pointValue);
                stepCountBelow++;
                continue;
            }
            
            // === ON-SCREEN: build strings and create objects ===
            string overlapLevelsBelow = GetOverlapLevelsInfo(stepCountBelow, intervals);
            string overlapTFsBelow = GetOverlapTimeframesInfo(stepCountBelow, intervals);
            
            if(levelType == 1) {
                switch(structLevel) {
                    case 5: {
                        lineNameBelow = prefix + "StructureLevel5_Down_" + IntegerToString(stepCountBelow / intervals[4]);
                        tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | TH: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[4], DoubleToString(priceLevelBelow, digits), quintupleStructureTFTHStepSizePoints / 10.0);
                        levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[4]);
                        lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
                        percentageTooltip = structurePercentages[4];
                        break;
                    }
                    case 4: {
                        lineNameBelow = prefix + "StructureLevel4_Down_" + IntegerToString(stepCountBelow / intervals[3]);
                        tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | TH: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[3], DoubleToString(priceLevelBelow, digits), quadrupleStructureTFTHStepSizePoints / 10.0);
                        levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[3]);
                        lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
                        percentageTooltip = structurePercentages[3];
                        break;
                    }
                    case 3: {
                        lineNameBelow = prefix + "StructureLevel3_Down_" + IntegerToString(stepCountBelow / intervals[2]);
                        tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | TH: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[2], DoubleToString(priceLevelBelow, digits), tripleStructureTFTHStepSizePoints / 10.0);
                        levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[2]);
                        lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
                        percentageTooltip = structurePercentages[2];
                        break;
                    }
                    case 2: {
                        lineNameBelow = prefix + "StructureLevel2_Down_" + IntegerToString(stepCountBelow / intervals[1]);
                        tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | TH: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[1], DoubleToString(priceLevelBelow, digits), doubleStructureTFTHStepSizePoints / 10.0);
                        levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[1]);
                        lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
                        percentageTooltip = structurePercentages[1];
                        break;
                    }
                    default: {
                        lineNameBelow = prefix + "StructureLevel1_Down_" + IntegerToString(stepCountBelow / intervals[0]);
                        tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | TH: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[0], DoubleToString(priceLevelBelow, digits), structureTFTHStepSizePoints / 10.0);
                        levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[0]);
                        lineColor = inpStructureL1Color; lineStyle = inpStructureL1Style; lineWidth = inpStructureL1Width;
                        percentageTooltip = structurePercentages[0];
                        break;
                    }
                }
            } else {
                lineNameBelow = prefix + "TriggerTH_Down_" + IntegerToString(stepCountBelow);
                tooltipBelow = StringFormat("[%s] -%d | Price: %s | L: %.1f, S: %.1f pips",
                    shortCurrentTFCached, stepCountBelow, DoubleToString(priceLevelBelow, digits),
                    cachedLongStep * thStepSizePoints / 10.0,
                    cachedShortStep * thStepSizePoints / 10.0);
                levelInfoBelow = StringFormat("%s -%d", shortCurrentTFCached, stepCountBelow);
                lineColor = inpTriggerColor; lineStyle = inpTriggerStyle; lineWidth = inpTriggerWidth;
                percentageTooltip = timeframePercentage;
            }
            
            double pipsToLevelBelow = NormalizeDouble(MathAbs(priceLevelBelow - g_currentPrice) / pointValue / 10.0, 1);
            tooltipBelow = StringFormat("%s | Dist: %.1f pips", tooltipBelow, pipsToLevelBelow);
            
            CreateTHLineObject(lineNameBelow, priceLevelBelow, lineColor, lineStyle, lineWidth, tooltipBelow, inpTHLineObjectType, false);
            if(inpShowPipDistanceLabels) CreatePipDistanceLabel(lineNameBelow+"_PipsLabel", priceLevelBelow, pipsToLevelBelow, lineColor, levelInfoBelow);
            
            // ═══════════════════════════════════════════════════════════
            // ZONE SUPPORT: Create zone between levels
            // پشتیبانی Zone: ساخت zone بین سطوح
            // 
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            // رویکرد یکپارچه: از CreateZoneWithSmartFallback استفاده کن
            // GOLD VERSION: Uses GetHighestStructureLevel for clean logic
            // CRITICAL FIX: Pass fixed step size for consistent zone height
            // ═══════════════════════════════════════════════════════════
            if(inpShowMidZones) {
                // GOLD FIX: Use centralized function instead of repeated else-if
                int highestLevel = GetHighestStructureLevel(stepCountBelow, intervals);
                bool isStructureLevel = (highestLevel > 0 && inpShowStructure);
                
                string zoneName = prefix + "Zone_Below_" + IntegerToString(stepCountBelow);
                
                // CRITICAL FIX: Calculate fixed step size (matching M/SS/LS/Factor modes)
                double fixedStepSize = thStepSizePoints * pointValue;
                
                // Use unified smart fallback function
                if(CreateZoneWithSmartFallback(zoneName, priceLevelBelow, isStructureLevel, lineColor,
                                              inpShowStructure, triggerEnabled,
                                              lastDrawnPriceBelow, lastTriggerPriceBelow, lastDrawnPriceBelow,
                                              fixedStepSize)) {  // Pass fixed step size
                    zoneCountBelow++;
                }
            }
            
            priceLevelBelow -= (thStepSizePoints * pointValue);
            // NO NormalizeDouble - keep full precision to match MotiveWave
            stepCountBelow++;
            levelCountBelow++;
        }
        
        #ifdef ENABLE_DEBUG_LOGS
        if(inpShowMidZones) {
            Print("✅ DrawTHLevels: Drew ", zoneCountAbove, " zones above, ", 
                  zoneCountBelow, " zones below");
        }
        #endif
    }
}

void SetLabelFont(const string name) {
    ObjectSetString(0, name, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpFontSize);
}

// استخراج نام اصلی تایم‌فریم (قبل از +)
string GetBaseTimeframeName(const string fullName) {
    int plusPos = StringFind(fullName, "+");
    if(plusPos > 0) {
        return StringSubstr(fullName, 0, plusPos);
    }
    return fullName;
}

bool CreateTHLabel(const string objectPrefix, const string timeframeName, const double thValuePoints, const int xPos, const int yPos, const color textColor, const int horizontalSpacing, const int verticalSpacing) {
    if (!inpShowTHLabels) return true;
    
    // Calculate TH, SS, LS values
    double thValuePips = NormalizeDouble(thValuePoints / 10.0, 1);
    double shortStepPips = NormalizeDouble(thValuePips * 1.5, 1);
    double longStepPips = NormalizeDouble(thValuePips * 2.0, 1);
    
    string mainObjName = objectPrefix + "TH_" + timeframeName;
    string stepsObjName = objectPrefix + "TH_Steps_" + timeframeName;
    
    if (ObjectFind(0, mainObjName) < 0) {
        if (!ObjectCreate(0, mainObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (ObjectFind(0, stepsObjName) < 0) {
        if (!ObjectCreate(0, stepsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    
    // فرمت دو خطی: M1: 21
    //              (10 - 12)
    string mainText = StringFormat("%s: %.1f", GetBaseTimeframeName(timeframeName), thValuePips);
    string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
    
    ObjectSetString(0, mainObjName, OBJPROP_TEXT, mainText);
    ObjectSetString(0, stepsObjName, OBJPROP_TEXT, stepsText);
    ObjectSetInteger(0, mainObjName, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_COLOR, textColor);
    SetLabelFont(mainObjName);
    SetLabelFont(stepsObjName);
    
    ENUM_BASE_CORNER corner = (inpLabelCornerPosition == LABEL_CORNER_LEFT_TOP) ? CORNER_LEFT_UPPER : CORNER_LEFT_LOWER;
    ENUM_ANCHOR_POINT anchor = (inpLabelCornerPosition == LABEL_CORNER_LEFT_TOP) ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER;
    
    ObjectSetInteger(0, mainObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, mainObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, stepsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, mainObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, mainObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_HIDDEN, false);
    
    int labelXDistance = MathAbs(xPos) + 5;
    int labelYDistance;
    int bottomPadding = 20;
    int lineSpacing = inpFontSize + 16; // فاصله عمودی بین دو خط
    
    // محاسبه عرض تقریبی برای مرکز کردن سطر اول روی سطر دوم
    int mainTextWidth = (int)(StringLen(mainText) * inpFontSize * 0.6);
    int stepsTextWidth = (int)(StringLen(stepsText) * inpFontSize * 0.6);
    int centerOffset = (stepsTextWidth - mainTextWidth) / 2;
    if(centerOffset < 0) centerOffset = 0;
    
    if (inpLabelCornerPosition == LABEL_CORNER_LEFT_BOTTOM) {
        // از پایین به بالا
        labelYDistance = MathAbs(yPos) + inpFontSize + verticalSpacing + bottomPadding;
        ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, labelYDistance);
        ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, labelYDistance - lineSpacing);
    } else {
        // از بالا به پایین
        labelYDistance = MathAbs(yPos) + verticalSpacing;
        ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, labelYDistance);
        ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, labelYDistance + lineSpacing);
    }
    
    ObjectSetInteger(0, mainObjName, OBJPROP_XDISTANCE, labelXDistance + centerOffset); // مرکز کردن سطر اول
    ObjectSetInteger(0, stepsObjName, OBJPROP_XDISTANCE, labelXDistance); // سطر دوم ثابت
    
    // CRITICAL FIX: Respect Hide state (F key)
    if(IsIndicatorHidden()) {
        ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    
    return true;
}

void DisplayFractalTHs(const string objectPrefix, const double dailyPriceForTH, const datetime currentTime) {
    double point = GetSymbolPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // CRITICAL FIX: Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    int startXPos = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) ? 5 : inpInitialX;
    int startYPos = inpInitialY;
    int currentXPos = startXPos;
    int currentYPos = startYPos;
    int yStep = inpLabelSpacing + 5;
    // فاصله افقی بین لیبل‌ها
    int xStep = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) ? 8 : inpLabelSpacing * 2;
    int maxWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - startXPos * 2;
    // دو خطی: نام و TH در خط اول، SS و LS در خط دوم
    int lineHeight = (inpFontSize + inpLabelSpacing) * 2;
    ArrayResize(g_storedTHs, 0); // Clear existing stored THs before displaying fractal THs
    ArrayResize(g_labelPositions, 0); // Clear label positions
    string thLabelPrefix = objectPrefix + "TH_";
    for(int i = 0; i < ArraySize(FRACTAL_TIMEFRAMES); i++) {
        ObjectDelete(0, thLabelPrefix + FRACTAL_TIMEFRAMES[i]);
    }
    for(int i = 0; i < ArraySize(FRACTAL_TIMEFRAMES); i++) {
        string timeframeName = FRACTAL_TIMEFRAMES[i];
        double percentage = MODIFIED_FRACTAL_PERCENTAGES[i];
        double thPoints = CalculateTHPoints(dailyPriceForTH, digits, percentage);
        int thIndex = ArraySize(g_storedTHs);
        ArrayResize(g_storedTHs, thIndex + 1, 16);  // PERF FIX: Reserve extra
        g_storedTHs[thIndex].timeframeName = timeframeName;
        g_storedTHs[thIndex].thValue = thPoints;
        StoreLabelPosition(timeframeName, currentXPos, currentYPos);
        string displayTimeframeName = inpLabelArrangement == LABEL_ARRANGEMENT_HORIZONTAL ? 
            GetShortTimeframeName(timeframeName) : timeframeName;
        string labelText = inpShowTimeframeInLabels ?
            StringFormat("%s: %.1f pips", displayTimeframeName, NormalizeDouble(thPoints / 10.0, 1)) :
            StringFormat("%.1f pips", NormalizeDouble(thPoints / 10.0, 1));
        int labelWidth = (int)CalculateTextWidth(labelText);
        if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, FRACTAL_COLORS[i], xStep, yStep)) continue;
            currentYPos += lineHeight;
        } else {
            if(currentXPos + labelWidth + xStep > maxWidth) {
                currentXPos = startXPos;
                currentYPos += lineHeight;
            }
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, FRACTAL_COLORS[i], xStep, yStep)) continue;
            // فاصله افقی بین لیبل‌ها
            currentXPos += labelWidth + xStep + 20;
        }
    }
}

void DisplayStandardTHs(const string objectPrefix, const double dailyPriceForTH, const datetime currentTime) {
    double point = GetSymbolPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // CRITICAL FIX: Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    int startXPos = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) ? 5 : inpInitialX;
    int startYPos = inpInitialY;
    int currentXPos = startXPos;
    int currentYPos = startYPos;
    int yStep = inpLabelSpacing + inpFontSize + 5;
    // فاصله افقی بین لیبل‌ها
    int xStep = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) ? 8 : inpLabelSpacing * 2;
    int maxWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - startXPos * 2;
    // دو خطی: نام و TH در خط اول، SS و LS در خط دوم
    int lineHeight = (inpFontSize + inpLabelSpacing) * 2;
    if(inpShowFractalTHs) {
        if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            currentYPos += ArraySize(FRACTAL_TIMEFRAMES) * lineHeight;
        } else {
            int fractalLabelsWidth = 0;
            int fractalRows = 1;
            for(int i = 0; i < ArraySize(FRACTAL_TIMEFRAMES); i++) {
                string displayTimeframeName = inpLabelArrangement == LABEL_ARRANGEMENT_HORIZONTAL ? 
                    GetShortTimeframeName(FRACTAL_TIMEFRAMES[i]) : FRACTAL_TIMEFRAMES[i];
                string labelText = inpShowTimeframeInLabels ?
                    StringFormat("%s: %.1f pips", displayTimeframeName, 0.0) :
                    StringFormat("%.1f pips", 0.0);
                int labelWidth = (int)CalculateTextWidth(labelText) + xStep;
                if(fractalLabelsWidth + labelWidth > maxWidth) {
                    fractalRows++;
                    fractalLabelsWidth = labelWidth;
                } else {
                    fractalLabelsWidth += labelWidth;
                }
            }
            currentYPos += (fractalRows * lineHeight) + inpLabelSpacing;
        }
    }
    string thLabelPrefix = objectPrefix + "TH_";
    for(int i = 0; i < ArraySize(STANDARD_TIMEFRAMES); i++) {
        ObjectDelete(0, thLabelPrefix + STANDARD_TIMEFRAMES[i]);
    }
    for(int i = 0; i < ArraySize(STANDARD_TIMEFRAMES); i++) {
        string timeframeName = STANDARD_TIMEFRAMES[i];
        double percentage = CalculatePercentage(STANDARD_MINUTES[i]);
        double thPoints = CalculateTHPoints(dailyPriceForTH, digits, percentage);
        int thIndex = ArraySize(g_storedTHs);
        ArrayResize(g_storedTHs, thIndex + 1, 16);  // PERF FIX: Reserve extra
        g_storedTHs[thIndex].timeframeName = timeframeName;
        g_storedTHs[thIndex].thValue = thPoints;
        string displayTimeframeName = inpLabelArrangement == LABEL_ARRANGEMENT_HORIZONTAL ? 
            GetShortTimeframeName(timeframeName) : timeframeName;
        string labelText = inpShowTimeframeInLabels ?
            StringFormat("%s: %.1f pips", displayTimeframeName, NormalizeDouble(thPoints / 10.0, 1)) :
            StringFormat("%.1f pips", NormalizeDouble(thPoints / 10.0, 1));
        int labelWidth = (int)CalculateTextWidth(labelText);
        if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, STANDARD_COLORS[0], xStep, yStep)) continue;
            currentYPos += lineHeight;
        } else {
            if(currentXPos + labelWidth + xStep > maxWidth) {
                currentXPos = startXPos;
                currentYPos += lineHeight;
            }
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, STANDARD_COLORS[0], xStep, yStep)) continue;
            // فاصله افقی بین لیبل‌ها
            currentXPos += labelWidth + xStep + 25;
        }
    }
}

void StoreLabelPosition(const string name, const int xPos, const int yPos) {
    for(int i=0; i<ArraySize(g_labelPositions); i++) {
        if(g_labelPositions[i].name == name) {
            g_labelPositions[i].xPos = xPos;
            g_labelPositions[i].yPos = yPos;
            return;
        }
    }
    int size=ArraySize(g_labelPositions);
    if(ArrayResize(g_labelPositions,size+1,16)) {  // PERF FIX: Reserve extra
        g_labelPositions[size].name=name;
        g_labelPositions[size].xPos=xPos;
        g_labelPositions[size].yPos=yPos;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("StoreLabelPosition: Failed to resize array");
        #endif
    }
}

int GetStoredXPosition(const string name) {
    for(int i=0; i<ArraySize(g_labelPositions); i++) if(g_labelPositions[i].name==name) return g_labelPositions[i].xPos;
    return inpInitialX;
}

double CalculateTextWidth(string text) {
    double averageCharWidth=inpFontSize*0.7;
    double plusFactor=StringFind(text,"+")>=0?inpFontSize*0.3:0;
    double numberFactor=StringLen(text)-StringReplace(text,"0123456789","")>0?inpFontSize*0.2:0;
    return StringLen(text)*averageCharWidth+plusFactor+numberFactor;
}

string StringRepeat(string str, int count) {
    string result = "";
    for(int i=0; i<count; i++) {
        result = result + str;
    }
    return result;
}


//+------------------------------------------------------------------+
//| Create/Update Timeframe Lock Status Label                        |
//| Shows lock status and timeframe when locked (small, left corner) |
//+------------------------------------------------------------------+
void UpdateLockStatusLabel()
{
    // Position: Top-left corner, small and unobtrusive
    int xDistance = 5;
    int yDistance = 15;
    
    if(g_timeframeLocked)
    {
        // Create or update label showing locked timeframe (no emoji - MT4 doesn't support)
        string lockText = "[LOCK:" + PeriodToString(g_lockedPeriod) + "]";
        
        if(ObjectFind(0, g_lockStatusLabelName) < 0)
        {
            if(!ObjectCreate(0, g_lockStatusLabelName, OBJ_LABEL, 0, 0, 0))
            {
                #ifdef ENABLE_DEBUG_LOGS
                Print("Failed to create lock status label. Error: ", GetLastError());
                #endif
                return;
            }
        }
        
        ObjectSetString(0, g_lockStatusLabelName, OBJPROP_TEXT, lockText);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_COLOR, clrYellow);
        ObjectSetString(0, g_lockStatusLabelName, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_XDISTANCE, xDistance);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_YDISTANCE, yDistance);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_HIDDEN, false);
        ObjectSetString(0, g_lockStatusLabelName, OBJPROP_TOOLTIP, "TF locked to " + PeriodToString(g_lockedPeriod) + " - Press " + inpLockKey + " to unlock");
    }
    else
    {
        // Delete label when unlocked
        if(ObjectFind(0, g_lockStatusLabelName) >= 0)
        {
            ObjectDelete(0, g_lockStatusLabelName);
        }
    }
}

//+------------------------------------------------------------------+
//| Convert period to readable string                                |
//+------------------------------------------------------------------+
string PeriodToString(int period)
{
    switch(period)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN";
        default:         return "TF" + IntegerToString(period);
    }
}


