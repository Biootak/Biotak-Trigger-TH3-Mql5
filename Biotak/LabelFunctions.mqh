
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
    
    // Use cached values instead of recalculating
    int digits = s_cachedDigits;
    if(digits < 0 || digits > 8) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawTHLevels: Invalid digits value: ", digits);
    #endif
    return;
    }
    
    // Step size and structure level values (computed differently for TH vs ATR)
    double thStepSizePoints;
    double structureTFTHStepSizePoints;
    double doubleStructureTFTHStepSizePoints;
    double tripleStructureTFTHStepSizePoints;
    double quadrupleStructureTFTHStepSizePoints;
    double quintupleStructureTFTHStepSizePoints;
    string basisLabel;
    double structurePercentages[];
    // Cached LS/SS multipliers for trigger tooltips
    double cachedLongStepVal;
    double cachedShortStepVal;
    
    // TH-based step calculations
    double structureTFPercentage=CalculateTimeframeTH(structureTimeframe);
        if(structureTFPercentage <= 0) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("DrawTHLevels: Invalid structure timeframe percentage");
            #endif
            return;
        }
        double structureMultipliers[] = {1.0, 2.0, 4.0, 8.0, 16.0};
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
        thStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,timeframePercentage);
        structureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[0]);
        doubleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[1]);
        tripleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[2]);
        quadrupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[3]);
        quintupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[4]);
        basisLabel = "TH";
        // TH trigger tooltip multipliers
        cachedLongStepVal = timeframePercentage * 2.0;
        cachedShortStepVal = timeframePercentage * 1.5;
    
    // Validate step sizes to prevent infinite loops
    if(thStepSizePoints <= 0 || thStepSizePoints < s_cachedPointValue) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawTHLevels: Invalid thStepSizePoints=", thStepSizePoints, " (must be > Point=", s_cachedPointValue, ")");
    #endif
    return;
    }
    if (thStepSizePoints <= 0 || structureTFTHStepSizePoints <= 0 || doubleStructureTFTHStepSizePoints <= 0) return;
    
    // ═══════════════════════════════════════════════════════════════════
    // FIX: Use configurable Base Multiplier instead of hardcoded values
    // Matches Java implementation in LevelDrawer.java (getPathForStep)
    // ═══════════════════════════════════════════════════════════════════
    int baseMultiplier = GetValidatedBaseMultiplier(); // Use central validation
    
    // Get cached intervals for the base multiplier (base^1, base^2, base^3, base^4, base^5)
    int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    
    // #11: Array bounds checking - get size for safe access
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
    double cachedLongStep = cachedLongStepVal;
    double cachedShortStep = cachedShortStepVal;
        // PERFORMANCE: Cache shortCurrentTF once instead of calling per iteration
        string shortCurrentTFCached = GetShortTimeframeName(cachedCurrentTF);
        
        // ═══════════════════════════════════════════════════════════════
        // ZONE SUPPORT: Tracking variables for Structure/Trigger separation
        
        // ═══════════════════════════════════════════════════════════════
        double lastDrawnPriceAbove = midpointPrice;  // Track last structure level
        double lastTriggerPriceAbove = 0;            // Track last trigger level
        int zoneCountAbove = 0;
    double priceLevelAbove = midpointPrice + (thStepSizePoints * pointValue);
        // NO NormalizeDouble - keep full precision to match MotiveWave
        int stepCountAbove = 1;
    int levelCountAbove = 0;
        
        // Loop condition: Custom Price = only count, Historical = count AND bounds
        // Add safety counter to prevent infinite loops
        int safetyCounterAbove = 0;
    const int MAX_ITERATIONS_ABOVE = 1000; // Safety limit
        
        while ((checkHistoricalBounds ? (priceLevelAbove <= g_highestHigh) : true) && 
               levelCountAbove < maxLevelsAbove && 
               safetyCounterAbove < MAX_ITERATIONS_ABOVE) {
            
            safetyCounterAbove++; // Increment safety counter
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
    tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | %s: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[4], DoubleToString(priceLevelAbove, digits), basisLabel, quintupleStructureTFTHStepSizePoints / 10.0);
    levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[4]);
    lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
    percentageTooltip = structurePercentages[4];
    break;
                    }
                    case 4: {
                        lineNameAbove = prefix + "StructureLevel4_Up_" + IntegerToString(stepCountAbove / intervals[3]);
    tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | %s: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[3], DoubleToString(priceLevelAbove, digits), basisLabel, quadrupleStructureTFTHStepSizePoints / 10.0);
    levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[3]);
    lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
    percentageTooltip = structurePercentages[3];
    break;
                    }
                    case 3: {
                        lineNameAbove = prefix + "StructureLevel3_Up_" + IntegerToString(stepCountAbove / intervals[2]);
    tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | %s: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[2], DoubleToString(priceLevelAbove, digits), basisLabel, tripleStructureTFTHStepSizePoints / 10.0);
    levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[2]);
    lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
    percentageTooltip = structurePercentages[2];
    break;
                    }
                    case 2: {
                        lineNameAbove = prefix + "StructureLevel2_Up_" + IntegerToString(stepCountAbove / intervals[1]);
    tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | %s: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[1], DoubleToString(priceLevelAbove, digits), basisLabel, doubleStructureTFTHStepSizePoints / 10.0);
    levelInfoAbove = StringFormat("%s %s +%d", overlapTFs, overlapLevels, stepCountAbove / intervals[1]);
    lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
    percentageTooltip = structurePercentages[1];
    break;
                    }
                    default: { // case 1
                        lineNameAbove = prefix + "StructureLevel1_Up_" + IntegerToString(stepCountAbove / intervals[0]);
    tooltipAbove = StringFormat("[%s] %s +%d | Price: %s | %s: %.1f pips", overlapTFs, overlapLevels, stepCountAbove / intervals[0], DoubleToString(priceLevelAbove, digits), basisLabel, structureTFTHStepSizePoints / 10.0);
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
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            
            // Uses GetHighestStructureLevel for clean logic
            // Pass fixed step size for consistent zone height
            // ═══════════════════════════════════════════════════════════
            if(inpShowMidZones) {
                // Use centralized function instead of repeated else-if
                int highestLevel = GetHighestStructureLevel(stepCountAbove, intervals);
    bool isStructureLevel = (highestLevel > 0 && inpShowStructure);
    string zoneName = prefix + "Zone_Above_" + IntegerToString(stepCountAbove);
                
                // Calculate fixed step size (matching M/SS/LS/Factor modes)
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
        
        // ═══════════════════════════════════════════════════════════════
        double lastDrawnPriceBelow = midpointPrice;  // Track last structure level
        double lastTriggerPriceBelow = 0;            // Track last trigger level
        int zoneCountBelow = 0;
    double priceLevelBelow = midpointPrice - (thStepSizePoints * pointValue);
        // NO NormalizeDouble - keep full precision to match MotiveWave
        int stepCountBelow = 1;
    int levelCountBelow = 0;
        
        // Loop condition: Custom Price = only count, Historical = count AND bounds
        // Add safety counter to prevent infinite loops
        int safetyCounterBelow = 0;
    const int MAX_ITERATIONS_BELOW = 1000; // Safety limit
        
        while ((checkHistoricalBounds ? (priceLevelBelow >= g_lowestLow) : true) && 
               levelCountBelow < maxLevelsBelow && 
               safetyCounterBelow < MAX_ITERATIONS_BELOW) {
            
            safetyCounterBelow++; // Increment safety counter
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
    tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | %s: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[4], DoubleToString(priceLevelBelow, digits), basisLabel, quintupleStructureTFTHStepSizePoints / 10.0);
    levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[4]);
    lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
    percentageTooltip = structurePercentages[4];
    break;
                    }
                    case 4: {
                        lineNameBelow = prefix + "StructureLevel4_Down_" + IntegerToString(stepCountBelow / intervals[3]);
    tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | %s: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[3], DoubleToString(priceLevelBelow, digits), basisLabel, quadrupleStructureTFTHStepSizePoints / 10.0);
    levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[3]);
    lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
    percentageTooltip = structurePercentages[3];
    break;
                    }
                    case 3: {
                        lineNameBelow = prefix + "StructureLevel3_Down_" + IntegerToString(stepCountBelow / intervals[2]);
    tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | %s: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[2], DoubleToString(priceLevelBelow, digits), basisLabel, tripleStructureTFTHStepSizePoints / 10.0);
    levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[2]);
    lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
    percentageTooltip = structurePercentages[2];
    break;
                    }
                    case 2: {
                        lineNameBelow = prefix + "StructureLevel2_Down_" + IntegerToString(stepCountBelow / intervals[1]);
    tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | %s: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[1], DoubleToString(priceLevelBelow, digits), basisLabel, doubleStructureTFTHStepSizePoints / 10.0);
    levelInfoBelow = StringFormat("%s %s -%d", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[1]);
    lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
    percentageTooltip = structurePercentages[1];
    break;
                    }
                    default: {
                        lineNameBelow = prefix + "StructureLevel1_Down_" + IntegerToString(stepCountBelow / intervals[0]);
    tooltipBelow = StringFormat("[%s] %s -%d | Price: %s | %s: %.1f pips", overlapTFsBelow, overlapLevelsBelow, stepCountBelow / intervals[0], DoubleToString(priceLevelBelow, digits), basisLabel, structureTFTHStepSizePoints / 10.0);
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
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            
            // Uses GetHighestStructureLevel for clean logic
            // Pass fixed step size for consistent zone height
            // ═══════════════════════════════════════════════════════════
            if(inpShowMidZones) {
                // Use centralized function instead of repeated else-if
                int highestLevel = GetHighestStructureLevel(stepCountBelow, intervals);
    bool isStructureLevel = (highestLevel > 0 && inpShowStructure);
    string zoneName = prefix + "Zone_Below_" + IntegerToString(stepCountBelow);
                
                // Calculate fixed step size (matching M/SS/LS/Factor modes)
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
    string GetBaseTimeframeName(const string fullName) {
        int plusPos = StringFind(fullName, "+");
    if(plusPos > 0) {
        return StringSubstr(fullName, 0, plusPos);
    }
    return fullName;
}
    bool CreateATRLabelSimple(const string objectPrefix, const string timeframeName, const double atrValuePoints, const int xPos, const int yPos, const color textColor, const int horizontalSpacing, const int verticalSpacing) {
    
    // Calculate ATR, SS, LS values (same ratios as TH)
    double atrPips = NormalizeDouble(atrValuePoints / 10.0, 1);
    double shortStepPips = NormalizeDouble(atrPips * 1.5, 1);
    double longStepPips = NormalizeDouble(atrPips * 2.0, 1);
    double target3x = MathFloor(atrPips * 3.0);
    double target5x = MathFloor(atrPips * 5.0);
    double target15x = MathFloor(atrPips * 15.0);
    string mainObjName = objectPrefix + "ATR_" + timeframeName;
    string stepsObjName = objectPrefix + "ATR_Steps_" + timeframeName;
    string targetsObjName = objectPrefix + "ATR_Targets_" + timeframeName;
    if(!inpShowATRTargets && ObjectFind(0, targetsObjName) >= 0) {
        ObjectDelete(0, targetsObjName);
    }
    
    if (ObjectFind(0, mainObjName) < 0) {
        if (!ObjectCreate(0, mainObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (ObjectFind(0, stepsObjName) < 0) {
        if (!ObjectCreate(0, stepsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (inpShowATRTargets && ObjectFind(0, targetsObjName) < 0) {
        if (!ObjectCreate(0, targetsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    string targetsText = StringFormat("%.0f - %.0f - %.0f", target3x, target5x, target15x);
    string mainText = StringFormat("%s: %.1f", timeframeName, atrPips);
    string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
    if(inpShowATRTargets) {
        ObjectSetString(0, targetsObjName, OBJPROP_TEXT, targetsText);
    ObjectSetInteger(0, targetsObjName, OBJPROP_COLOR, textColor);
    SetLabelFont(targetsObjName);
    }
    ObjectSetString(0, mainObjName, OBJPROP_TEXT, mainText);
    ObjectSetString(0, stepsObjName, OBJPROP_TEXT, stepsText);
    ObjectSetInteger(0, mainObjName, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_COLOR, textColor);
    SetLabelFont(mainObjName);
    SetLabelFont(stepsObjName);
    
    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER;
    ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER;
    ObjectSetInteger(0, mainObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, mainObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, stepsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, mainObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, mainObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_HIDDEN, false);
    if(inpShowATRTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, targetsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, targetsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, targetsObjName, OBJPROP_HIDDEN, false);
    }
    int labelXDistance = MathAbs(xPos);
    int bottomPadding = 20;
    int lineGap = inpLabelRowGap;
    int singleLineHeight = inpFontSize + lineGap;
    int mainTextWidth = (int)(StringLen(mainText) * inpFontSize * 0.6);
    int stepsTextWidth = (int)(StringLen(stepsText) * inpFontSize * 0.6);
    int mainOffset = (stepsTextWidth - mainTextWidth) / 2;
    if(mainOffset < 0) mainOffset = 0;
    int targetsOffset = 0;
    if(inpShowATRTargets) {
        int targetsTextWidth = (int)(StringLen(targetsText) * inpFontSize * 0.6);
    targetsOffset = (mainTextWidth - targetsTextWidth) / 2 + mainOffset;
    if(targetsOffset < 0) targetsOffset = 0;
    }
    
    int baseY = MathAbs(yPos);
    ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, baseY);
    ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight);
    if(inpShowATRTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight * 2);
    }
    if(inpShowATRTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_XDISTANCE, labelXDistance + targetsOffset);
    }
    ObjectSetInteger(0, mainObjName, OBJPROP_XDISTANCE, labelXDistance + mainOffset);
    ObjectSetInteger(0, stepsObjName, OBJPROP_XDISTANCE, labelXDistance);
    
    if(IsIndicatorHidden()) {
        if(inpShowATRTargets) ObjectSetInteger(0, targetsObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        if(inpShowATRTargets) ObjectSetInteger(0, targetsObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    return true;
}
    void DisplayATRLabels(const string objectPrefix) {
    if(!g_atrLabelsVisible) return;
    
    ATR_PRINT("=== DisplayATRLabels: Starting ===");
    double point = GetSymbolPoint();
    int digits = GetCachedDigits();
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    
    // Clean up old ATR label objects
    string currentTFStr = IntegerToString(Period());
    string uniquePrefix = objectPrefix + "TF" + currentTFStr + "_";
    string allTimeframes[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
    ObjectDelete(0, uniquePrefix + "ATR_Title");
    for(int i = 0; i < ArraySize(allTimeframes); i++) {
        ObjectDelete(0, uniquePrefix + "ATR_" + allTimeframes[i]);
    ObjectDelete(0, uniquePrefix + "ATR_Steps_" + allTimeframes[i]);
    ObjectDelete(0, uniquePrefix + "ATR_Targets_" + allTimeframes[i]);
    }
    
    // Standard MT5 timeframes with minutes for CalculateHybridATR
    string timeframes[] = {"M1", "M5", "M15", "H1", "H4", "D1", "W1", "MN1"};
    int tfMinutes[] = {1, 5, 15, 60, 240, 1440, 10080, 43200};
    // Original color scheme per timeframe
    color colors[] = {
        clrBlack,        // M1
        clrBlack,        // M5
        clrBlack,        // M15
        clrBlue,         // H1
        clrRed,          // H4
        clrGreen,        // D1
        clrBlack,        // W1
        clrBlack         // MN1
    };
    
    // Layout setup — ATR renders FIRST (at the top)
    bool isVerticalLayout = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL);
    int rowSpacing = inpLabelRowGap;
    int horizontalPadding = inpLabelColumnGap;
    int startXPos = inpLabelsMarginLeft;
    int lineGap = rowSpacing;
    int singleLineHeight = inpFontSize + lineGap;
    int titleHeight = singleLineHeight;
    // Title on same row as first item (horizontal) or above it (vertical)
    int titleYPos = inpLabelsMarginTop + g_currentLabelYOffset;
    int startYPos = isVerticalLayout ? (titleYPos + singleLineHeight) : titleYPos;
    int sectionGap = inpSectionGap;
    
    // Create "ATR:" title label
    string titleObjName = uniquePrefix + "ATR_Title";
    ObjectDelete(0, titleObjName);
    ObjectCreate(0, titleObjName, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, titleObjName, OBJPROP_TEXT, "ATR:");
    ObjectSetInteger(0, titleObjName, OBJPROP_COLOR, clrDarkBlue);
    ObjectSetString(0, titleObjName, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, titleObjName, OBJPROP_FONTSIZE, inpFontSize);
    ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER;
    ObjectSetInteger(0, titleObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, titleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, titleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    int titleY = titleYPos;
    ObjectSetInteger(0, titleObjName, OBJPROP_YDISTANCE, titleY);
    ObjectSetInteger(0, titleObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, titleObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, titleObjName, OBJPROP_BACK, false);
    if(IsIndicatorHidden()) {
        ObjectSetInteger(0, titleObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, titleObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    
    int titleWidth = (int)CalculateTextWidth("ATR:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowATRTargets, rowSpacing);
    
    int renderedCount = 0;
    for(int i = 0; i < ArraySize(timeframes); i++) {
        string timeframeName = timeframes[i];
    int targetMinutes = tfMinutes[i];
    
    // BUGFIX: Use GetATRForTimeframe for direct calculation (not scaled!)
    // This ensures ATR values are consistent across all chart timeframes
    double atrValue = GetATRForTimeframe(targetMinutes);
    if(atrValue <= 0 || atrValue == EMPTY_VALUE) {
            ATR_PRINTF2("=== DisplayATRLabels: Invalid ATR for ", timeframeName, " ===");
    continue;
        }
    double atrPoints = atrValue / point;
    double atrPips = NormalizeDouble(atrPoints / 10.0, 1);
    double shortStepPips = NormalizeDouble(atrPips * 1.5, 1);
    double longStepPips = NormalizeDouble(atrPips * 2.0, 1);
    double target3x = MathFloor(atrPips * 3.0);
    double target5x = MathFloor(atrPips * 5.0);
    double target15x = MathFloor(atrPips * 15.0);
    
    // Resolve label color: user override or auto per-timeframe
    color labelColor = colors[i];
    
    // Calculate label width for horizontal wrapping
        string mainText = inpShowTimeframeInLabels ?
            StringFormat("%s: %.1f", timeframeName, atrPips) :
            StringFormat("%.1f", atrPips);
        string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
        string targetsText = StringFormat("%.0f - %.0f - %.0f", target3x, target5x, target15x);
        int labelWidth = GetLabelBlockWidth(mainText, stepsText, targetsText, inpShowATRTargets);
    
    if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            if(!CreateATRLabelSimple(uniquePrefix, timeframeName, atrPoints, currentXPos, currentYPos, labelColor, xStep, yStep)) continue;
    currentYPos += lineHeight;
        } else {
        if(currentXPos + labelWidth + xStep > maxWidth) {
            currentXPos = labelStartX;
    currentYPos += lineHeight;
            }
                if(!CreateATRLabelSimple(uniquePrefix, timeframeName, atrPoints, currentXPos, currentYPos, labelColor, xStep, yStep)) continue;
            currentXPos += labelWidth + xStep;
        }
    renderedCount++;
    }
    
    // Update global Y offset so subsequent sections (TH) stack below ATR
    if(renderedCount > 0) {
        int consumedY = (currentYPos - startYPos) + lineHeight;
        g_currentLabelYOffset += consumedY + sectionGap;
    }
    
    ATR_PRINT("=== DisplayATRLabels: Completed ===");
}
    bool CreateTHLabel(const string objectPrefix, const string timeframeName, const double thValuePoints, const int xPos, const int yPos, const color textColor, const int horizontalSpacing, const int verticalSpacing) {
    if (!inpShowTHLabels) return true;
    
    // Calculate TH, SS, LS values
    double thValuePips = NormalizeDouble(thValuePoints / 10.0, 1);
    double shortStepPips = NormalizeDouble(thValuePips * 1.5, 1);
    double longStepPips = NormalizeDouble(thValuePips * 2.0, 1);
    double target3x = MathFloor(thValuePips * 3.0);
    double target5x = MathFloor(thValuePips * 5.0);
    double target15x = MathFloor(thValuePips * 15.0);
    string mainObjName = objectPrefix + "TH_" + timeframeName;
    string stepsObjName = objectPrefix + "TH_Steps_" + timeframeName;
    string targetsObjName = objectPrefix + "TH_Targets_" + timeframeName;
    if(!inpShowTHTargets && ObjectFind(0, targetsObjName) >= 0) {
        ObjectDelete(0, targetsObjName);
    }
    
    if (ObjectFind(0, mainObjName) < 0) {
        if (!ObjectCreate(0, mainObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (ObjectFind(0, stepsObjName) < 0) {
        if (!ObjectCreate(0, stepsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (inpShowTHTargets && ObjectFind(0, targetsObjName) < 0) {
        if (!ObjectCreate(0, targetsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    string targetsText = StringFormat("%.0f - %.0f - %.0f", target3x, target5x, target15x);
    string mainText = StringFormat("%s: %.1f", GetBaseTimeframeName(timeframeName), thValuePips);
    string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
    if(inpShowTHTargets) {
        ObjectSetString(0, targetsObjName, OBJPROP_TEXT, targetsText);
    ObjectSetInteger(0, targetsObjName, OBJPROP_COLOR, textColor);
    SetLabelFont(targetsObjName);
    }
    ObjectSetString(0, mainObjName, OBJPROP_TEXT, mainText);
    ObjectSetString(0, stepsObjName, OBJPROP_TEXT, stepsText);
    ObjectSetInteger(0, mainObjName, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_COLOR, textColor);
    SetLabelFont(mainObjName);
    SetLabelFont(stepsObjName);
    ENUM_BASE_CORNER corner = CORNER_LEFT_LOWER;
    ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER;
    if(inpShowTHTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, targetsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, targetsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, targetsObjName, OBJPROP_HIDDEN, false);
    }
    ObjectSetInteger(0, mainObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, mainObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, stepsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, mainObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, mainObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_HIDDEN, false);
    int labelXDistance = MathAbs(xPos);
    int bottomPadding = 0;
    int lineGap = inpLabelRowGap;
    int singleLineHeight = inpFontSize + lineGap;
    int mainTextWidth = (int)(StringLen(mainText) * inpFontSize * 0.6);
    int stepsTextWidth = (int)(StringLen(stepsText) * inpFontSize * 0.6);
    int mainOffset = (stepsTextWidth - mainTextWidth) / 2;
    if(mainOffset < 0) mainOffset = 0;
    int targetsOffset = 0;
    if(inpShowTHTargets) {
        int targetsTextWidth = (int)(StringLen(targetsText) * inpFontSize * 0.6);
    targetsOffset = (mainTextWidth - targetsTextWidth) / 2 + mainOffset;
    if(targetsOffset < 0) targetsOffset = 0;
    }
    
    if (corner == CORNER_LEFT_LOWER) {
        int baseY = MathAbs(yPos) + bottomPadding;
    if(inpShowTHTargets) {
            
            ObjectSetInteger(0, targetsObjName, OBJPROP_YDISTANCE, baseY);
    ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight);
    ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight * 2);
        } else {
            
            ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, baseY);
    ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight);
        }
    } else {
        int baseY = MathAbs(yPos);
    ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, baseY);
    ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight);
    if(inpShowTHTargets) {
            ObjectSetInteger(0, targetsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight * 2);
        }
    }
    if(inpShowTHTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_XDISTANCE, labelXDistance + targetsOffset);
    }
    ObjectSetInteger(0, mainObjName, OBJPROP_XDISTANCE, labelXDistance + mainOffset);
    ObjectSetInteger(0, stepsObjName, OBJPROP_XDISTANCE, labelXDistance); 
    
    // Respect Hide state (F key)
    if(IsIndicatorHidden()) {
        if(inpShowTHTargets) ObjectSetInteger(0, targetsObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        if(inpShowTHTargets) ObjectSetInteger(0, targetsObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, mainObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, stepsObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    return true;
}
    void DisplayFractalTHs(const string objectPrefix, const double dailyPriceForTH, const datetime currentTime) {
        double point = GetSymbolPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    bool isVerticalLayout = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL);
    int rowSpacing = inpLabelRowGap;
    int horizontalPadding = inpLabelColumnGap;
    int startXPos = inpLabelsMarginLeft;
    int lineGap = rowSpacing;
    int singleLineHeight = inpFontSize + lineGap;
    int titleHeight = singleLineHeight;
    // Title on same row as first item (horizontal) or above it (vertical)
    int titleYPos = inpLabelsMarginTop + inpLabelsMarginBottom + g_currentLabelYOffsetBottom;
    int titleAdjustment = inpShowTHTargets ? (singleLineHeight * 2) : singleLineHeight;
    int startYPos = isVerticalLayout ? (titleYPos + singleLineHeight) : titleYPos;
    int sectionGap = inpSectionGap;
    string thTitleObjName = objectPrefix + "TH_Title";
    ObjectDelete(0, thTitleObjName);
    ObjectCreate(0, thTitleObjName, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, thTitleObjName, OBJPROP_TEXT, "TH:");
    ObjectSetInteger(0, thTitleObjName, OBJPROP_COLOR, clrDarkBlue);
    ObjectSetString(0, thTitleObjName, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_FONTSIZE, inpFontSize);
    ENUM_BASE_CORNER corner = CORNER_LEFT_LOWER;
    ObjectSetInteger(0, thTitleObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    int thTitleY = titleYPos + titleAdjustment;
    
    ObjectSetInteger(0, thTitleObjName, OBJPROP_YDISTANCE, thTitleY);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_BACK, false);
    if(IsIndicatorHidden()) {
        ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    int titleWidth = (int)CalculateTextWidth("TH:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowTHTargets, rowSpacing);
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
    ArrayResize(g_storedTHs, thIndex + 1, 16);  // Reserve extra
        g_storedTHs[thIndex].timeframeName = timeframeName;
    g_storedTHs[thIndex].thValue = thPoints;
    StoreLabelPosition(timeframeName, currentXPos, currentYPos);
        double thValuePips = NormalizeDouble(thPoints / 10.0, 1);
        double shortStepPips = NormalizeDouble(thValuePips * 1.5, 1);
        double longStepPips = NormalizeDouble(thValuePips * 2.0, 1);
        double target3x = MathFloor(thValuePips * 3.0);
        double target5x = MathFloor(thValuePips * 5.0);
        double target15x = MathFloor(thValuePips * 15.0);
        string mainText = inpShowTimeframeInLabels ?
            StringFormat("%s: %.1f", GetBaseTimeframeName(timeframeName), thValuePips) :
            StringFormat("%.1f", thValuePips);
        string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
        string targetsText = StringFormat("%.0f - %.0f - %.0f", target3x, target5x, target15x);
        int labelWidth = GetLabelBlockWidth(mainText, stepsText, targetsText, inpShowTHTargets);
    if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, FRACTAL_COLORS[i], xStep, yStep)) continue;
    currentYPos += lineHeight;
        } else {
        if(currentXPos + labelWidth + xStep > maxWidth) {
            currentXPos = labelStartX;
    currentYPos += lineHeight;
            }
                if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, FRACTAL_COLORS[i], xStep, yStep)) continue;
            currentXPos += labelWidth + xStep;
        }
    }
    // Update global Y offset for next section (StandardTHs)
    int fractalConsumedY = (currentYPos - startYPos) + lineHeight;
    g_currentLabelYOffsetBottom += fractalConsumedY + sectionGap;
}
    void DisplayStandardTHs(const string objectPrefix, const double dailyPriceForTH, const datetime currentTime) {
        double point = GetSymbolPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    bool isVerticalLayout = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL);
    int rowSpacing = inpLabelRowGap;
    int horizontalPadding = inpLabelColumnGap;
    int startXPos = inpLabelsMarginLeft;
    int lineGap = rowSpacing;
    int singleLineHeight = inpFontSize + lineGap;
    int titleHeight = singleLineHeight;
    // Title on same row as first item (horizontal) or above it (vertical)
    int titleYPos = inpLabelsMarginTop + inpLabelsMarginBottom + g_currentLabelYOffsetBottom;
    int titleAdjustment = inpShowTHTargets ? (singleLineHeight * 2) : singleLineHeight;
    int startYPos = isVerticalLayout ? (titleYPos + singleLineHeight) : titleYPos;
    int titleWidth = (int)CalculateTextWidth("TH:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowTHTargets, rowSpacing);
    string thTitleObjName = objectPrefix + "TH_Title";
    ObjectDelete(0, thTitleObjName);
    ObjectCreate(0, thTitleObjName, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, thTitleObjName, OBJPROP_TEXT, "TH:");
    ObjectSetInteger(0, thTitleObjName, OBJPROP_COLOR, clrDarkBlue);
    ObjectSetString(0, thTitleObjName, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_FONTSIZE, inpFontSize);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_YDISTANCE, titleYPos + titleAdjustment);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_BACK, false);
    if(IsIndicatorHidden()) {
        ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
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
    ArrayResize(g_storedTHs, thIndex + 1, 16);  // Reserve extra
        g_storedTHs[thIndex].timeframeName = timeframeName;
    g_storedTHs[thIndex].thValue = thPoints;
        double thValuePips = NormalizeDouble(thPoints / 10.0, 1);
        double shortStepPips = NormalizeDouble(thValuePips * 1.5, 1);
        double longStepPips = NormalizeDouble(thValuePips * 2.0, 1);
        double target3x = MathFloor(thValuePips * 3.0);
        double target5x = MathFloor(thValuePips * 5.0);
        double target15x = MathFloor(thValuePips * 15.0);
        string mainText = inpShowTimeframeInLabels ?
            StringFormat("%s: %.1f", GetBaseTimeframeName(timeframeName), thValuePips) :
            StringFormat("%.1f", thValuePips);
        string stepsText = StringFormat("(%.1f - %.1f)", shortStepPips, longStepPips);
        string targetsText = StringFormat("%.0f - %.0f - %.0f", target3x, target5x, target15x);
        int labelWidth = GetLabelBlockWidth(mainText, stepsText, targetsText, inpShowTHTargets);
    if(inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL) {
            if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, STANDARD_COLORS[0], xStep, yStep)) continue;
    currentYPos += lineHeight;
        } else {
        if(currentXPos + labelWidth + xStep > maxWidth) {
            currentXPos = labelStartX;
    currentYPos += lineHeight;
            }
                if(!CreateTHLabel(objectPrefix, timeframeName, thPoints, currentXPos, currentYPos, STANDARD_COLORS[0], xStep, yStep)) continue;
            currentXPos += labelWidth + xStep;
        }
    }
    int standardConsumedY = (currentYPos - startYPos) + lineHeight;
    g_currentLabelYOffsetBottom += standardConsumedY + inpSectionGap;
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
    if(ArrayResize(g_labelPositions,size+1,16)) {  // Reserve extra
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
    return inpLabelsMarginLeft;
}
    double CalculateTextWidth(string text) {
        double averageCharWidth=inpFontSize*0.7;
    double plusFactor=StringFind(text,"+")>=0?inpFontSize*0.3:0;
    double numberFactor=StringLen(text)-StringReplace(text,"0123456789","")>0?inpFontSize*0.2:0;
    return StringLen(text)*averageCharWidth+plusFactor+numberFactor;
}
    int GetLabelLineHeight(const bool showTargets, const int rowSpacing) {
        int lines = showTargets ? 3 : 2;
    return (inpFontSize + rowSpacing) * lines;
}
    int GetLabelBlockWidth(const string mainText, const string stepsText, const string targetsText, const bool showTargets) {
        int maxWidth = (int)CalculateTextWidth(mainText);
    int stepsWidth = (int)CalculateTextWidth(stepsText);
    if(stepsWidth > maxWidth) maxWidth = stepsWidth;
    if(showTargets) {
        int targetsWidth = (int)CalculateTextWidth(targetsText);
        if(targetsWidth > maxWidth) maxWidth = targetsWidth;
    }
    return maxWidth;
}
    int GetLabelStartX(const int baseX, const int titleWidth, const int padding, const bool isVertical) {
        int titleGap = MathMin(padding, 6);
    return isVertical ? baseX : baseX + titleWidth + titleGap;
}
    int GetBottomTitleYOffset(const bool showTargets, const int rowSpacing) {
        int singleLineHeight = inpFontSize + rowSpacing;
    return showTargets ? singleLineHeight * 2 : singleLineHeight;
}
    string StringRepeat(string str, int count) {
        string result = "";
    for(int i=0; i<count; i++) {
        result = result + str;
    }
    return result;
}
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

