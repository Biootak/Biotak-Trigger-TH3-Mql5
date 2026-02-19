#ifndef LABEL_FUNCTIONS_MQH
#define LABEL_FUNCTIONS_MQH

bool DrawMainLevels(const string prefix) {
    // Skip drawing High/Low lines when Custom Price mode is active
    // In Custom Price mode, user defines their own reference point
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        // Delete existing High/Low lines if they exist
        CacheRemoveObject(prefix + "High");
        ObjectDelete(0, prefix + "High");
    CacheRemoveObject(prefix + "High_PipsLabel");
    ObjectDelete(0, prefix + "High_PipsLabel");
    CacheRemoveObject(prefix + "Low");
    ObjectDelete(0, prefix + "Low");
    CacheRemoveObject(prefix + "Low_PipsLabel");
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
        _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid daily close price");
    return;
    }
    
    // OPTIMIZATION: Use centralized cached values from PerformanceOptimizations.mqh
    double s_cachedPointValue = GetCachedPoint();
    int s_cachedDigits = GetCachedDigits();
    string s_cachedSymbol = GetCachedSymbol();
    double s_cachedPipSize = GetCachedPipSize();
    if(IsZero(s_cachedPointValue, EPSILON_PRICE) || IsZero(s_cachedPipSize, EPSILON_PRICE)) {
        _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid point/pip size for symbol ", s_cachedSymbol);
        return;
    }
    const double pointsPerPip = s_cachedPointValue / s_cachedPipSize;
    string prefix=objectPrefix+"TH_Level_";
    // Note: ClearAllLevels is called in DrawLevelsBasedOnMode before this function
    double timeframePercentage=GetTimeframeTH();
    string structureTimeframe = GetStructureTimeframeForCurrent();
    
    // Use cached values instead of recalculating
    int digits = s_cachedDigits;
    if(digits < 0 || digits > 8) {
        _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid digits value: ", GetCachedDigits());
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
            _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid structure timeframe percentage");
            return;
        }
        double structureMultipliers[] = {1.0, 2.0, 4.0, 8.0, 16.0};
        int structureMultipliersCount = ArraySize(structureMultipliers);
        if(ArrayResize(structurePercentages, structureMultipliersCount) != structureMultipliersCount) {
            _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Failed to resize structurePercentages array");
            return;
        }
        for(int i=0; i<structureMultipliersCount; i++) {
            structurePercentages[i] = structureTFPercentage * structureMultipliers[i];
            if(structurePercentages[i] <= 0) {
                _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid structure percentage at index ", i);
                return;
            }
        }
        if(timeframePercentage<=0) {
            _LOG_GATE_E Print("[E][LBL] DrawTHLevels: Invalid timeframe percentage");
            return;
        }
        thStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,timeframePercentage);
        structureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[0]);
        doubleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[1]);
        tripleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[2]);
        quadrupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[3]);
        quintupleStructureTFTHStepSizePoints=CalculateTHPoints(dailyClosePrice,digits,structurePercentages[4]);
        
        // Apply ATR Adaptive Scaling to all step sizes uniformly
        // This preserves the fractal 2× ratio between structure levels
        thStepSizePoints = GetAdaptedStepSize(thStepSizePoints);
        structureTFTHStepSizePoints = GetAdaptedStepSize(structureTFTHStepSizePoints);
        doubleStructureTFTHStepSizePoints = GetAdaptedStepSize(doubleStructureTFTHStepSizePoints);
        tripleStructureTFTHStepSizePoints = GetAdaptedStepSize(tripleStructureTFTHStepSizePoints);
        quadrupleStructureTFTHStepSizePoints = GetAdaptedStepSize(quadrupleStructureTFTHStepSizePoints);
        quintupleStructureTFTHStepSizePoints = GetAdaptedStepSize(quintupleStructureTFTHStepSizePoints);
        
        basisLabel = "TH";
        // TH trigger tooltip multipliers
        cachedLongStepVal = timeframePercentage * LS_MULTIPLIER;
        cachedShortStepVal = timeframePercentage * SS_MULTIPLIER;
    
    // Validate step sizes to prevent infinite loops
    if(thStepSizePoints <= 0 || thStepSizePoints < s_cachedPointValue) {
        _LOG_GATE_E Print("[E][LBL] ? DrawTHLevels: Invalid thStepSizePoints=", thStepSizePoints, " (must be > Point=", s_cachedPointValue, ")");
    return;
    }
    if (thStepSizePoints <= 0 || structureTFTHStepSizePoints <= 0 || doubleStructureTFTHStepSizePoints <= 0) return;
    
    // -------------------------------------------------------------------
    // FIX: Use configurable Base Multiplier instead of hardcoded values
    // Matches Java implementation in LevelDrawer.java (getPathForStep)
    // -------------------------------------------------------------------
    int baseMultiplier = GetValidatedBaseMultiplier(); // Use central validation
    
    // Get cached intervals for the base multiplier (base^1, base^2, base^3, base^4, base^5)
    int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    
    // #11: Array bounds checking - get size for safe access
    int intervalSize = ArraySize(intervals);
    if(intervalSize == 0) {
        _LOG_GATE_D Print("[D][LBL] ? DrawTHLevels: Empty intervals array, cannot draw structure levels");
    return;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][LBL] ?? DrawTHLevels using Base Multiplier: ", baseMultiplier,
          " ? L1=", intervals[0], ", L2=", intervals[1], ", L3=", intervals[2],
          ", L4=", intervals[3], ", L5=", intervals[4]);
    #endif
    // -------------------------------------------------------------------
    
    // Get midpoint price using utility function
    double midpointPrice = GetMidpointPrice(g_thStartPointType);
    double pointValue = s_cachedPointValue;
    if(inpShowMidpointLine) {
        string lineNameMid=prefix+"Mid";
    string tooltipMid = "Trigger TH Midpoint Level (" + DoubleToString(midpointPrice,digits) + ")";
    double pipsToMid = CalculatePipsDistance(midpointPrice, g_currentPrice);
    tooltipMid = FormatTooltipWithDistanceFast(tooltipMid, pipsToMid);
    CreateTHLineObject(lineNameMid,midpointPrice,inpTriggerColor,inpTriggerStyle,inpTriggerWidth,tooltipMid, inpTHLineObjectType, false);
    string cachedTFForMid = GetFractalTimeframeForCurrent();
    string midLevelInfo = GetShortTimeframeName(cachedTFForMid) + " Mid";
    if(inpShowPipDistanceLabels) CreatePipDistanceLabel(prefix+"Mid_PipsLabel", midpointPrice, pipsToMid, inpTriggerLabelColor, midLevelInfo);
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
    
    // ZONE SUPPORT: Zone cleanup is already handled by ClearAllLevels before DrawLevelsBasedOnMode.
    // Removed redundant ObjectsDeleteAll(0, prefix + "Zone_", -1, -1) that was causing double deletion.
    
    // BASE PLAYER: Always draw levels — all steps are part of the subdivision grid
    if (true) {
        TH3_PROF_START(THLevelsLoops);
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
        
        // PERF: Pre-compute structure level timeframe names (L1-L5) before loops
        // Eliminates GetTimeframeForStructureLevel() + GetShortTimeframeName() + GetFractalTimeframeForCurrent() per level
        string cachedStructTF[5];
        cachedStructTF[0] = GetShortTimeframeName(GetTimeframeForStructureLevel(1));
        cachedStructTF[1] = GetShortTimeframeName(GetTimeframeForStructureLevel(2));
        cachedStructTF[2] = GetShortTimeframeName(GetTimeframeForStructureLevel(3));
        cachedStructTF[3] = GetShortTimeframeName(GetTimeframeForStructureLevel(4));
        cachedStructTF[4] = GetShortTimeframeName(GetTimeframeForStructureLevel(5));
        
        // ---------------------------------------------------------------
        // ZONE SUPPORT: Tracking variables for Structure/Trigger separation
        
        // ---------------------------------------------------------------
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
            
            // PERFORMANCE FIX: Early viewport culling - skip ALL string work for off-screen levels
            bool isAboveVisible = (priceLevelAbove >= vpBottom && priceLevelAbove <= vpTop);
            
            // Determine which level type this step is (needed for both counting and drawing)
            // We must still identify level type even for off-screen to maintain correct state
            int levelType = 0; // 0=skip, 1=structure, 2=trigger
            int structLevel = 0;
    if (intervalSize > 4 && intervals[4] > 0 && stepCountAbove % intervals[4] == 0 && inpShowStructure && inpShowStructureL5) {
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
            } else {
                // Trigger subdivisions hidden when triggers disabled
                levelType = 0;
            }
            
            // Skip trigger subdivisions when triggers disabled
            if(levelType == 0) {
                levelCountAbove++;
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
            // PERF: Inline overlap info using already-computed structLevel
            // Eliminates GetOverlapLevelsInfo + GetOverlapTimeframesInfo (each called GetHighestStructureLevel + string ops per level)
            string overlapLevels = (structLevel > 0) ? ("L" + IntegerToString(structLevel)) : "";
    string overlapTFs = (structLevel > 0) ? cachedStructTF[structLevel - 1] : shortCurrentTFCached;
    if(levelType == 1) {
                // Structure level
                switch(structLevel) {
                    case 5: {
    lineNameAbove = prefix + "StructureLevel5_Up_" + IntegerToString(stepCountAbove / intervals[4]);
    tooltipAbove = "[" + overlapTFs + "] " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[4]) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(quintupleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = overlapTFs + " " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[4]);
    lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
    break;
                    }
                    case 4: {
                        lineNameAbove = prefix + "StructureLevel4_Up_" + IntegerToString(stepCountAbove / intervals[3]);
    tooltipAbove = "[" + overlapTFs + "] " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[3]) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(quadrupleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = overlapTFs + " " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[3]);
    lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
    break;
                    }
                    case 3: {
                        lineNameAbove = prefix + "StructureLevel3_Up_" + IntegerToString(stepCountAbove / intervals[2]);
    tooltipAbove = "[" + overlapTFs + "] " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[2]) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(tripleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = overlapTFs + " " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[2]);
    lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
    break;
                    }
                    case 2: {
                        lineNameAbove = prefix + "StructureLevel2_Up_" + IntegerToString(stepCountAbove / intervals[1]);
    tooltipAbove = "[" + overlapTFs + "] " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[1]) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(doubleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = overlapTFs + " " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[1]);
    lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
    break;
                    }
                    default: { // case 1
                        lineNameAbove = prefix + "StructureLevel1_Up_" + IntegerToString(stepCountAbove / intervals[0]);
    tooltipAbove = "[" + overlapTFs + "] " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[0]) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(structureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = overlapTFs + " " + overlapLevels + " +" + IntegerToString(stepCountAbove / intervals[0]);
    lineColor = inpStructureL1Color; lineStyle = inpStructureL1Style; lineWidth = inpStructureL1Width;
    break;
                    }
                }
            } else {
                // Trigger level
                lineNameAbove = prefix + "TriggerTH_Up_" + IntegerToString(stepCountAbove);
    tooltipAbove = "[" + shortCurrentTFCached + "] +" + IntegerToString(stepCountAbove) + " | Price: " + DoubleToString(priceLevelAbove, GetCachedDigits()) + " | L: " + DoubleToString(cachedLongStep * thStepSizePoints * pointsPerPip, 1) + ", S: " + DoubleToString(cachedShortStep * thStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoAbove = shortCurrentTFCached + " +" + IntegerToString(stepCountAbove);
    lineColor = inpTriggerColor; lineStyle = inpTriggerStyle; lineWidth = inpTriggerWidth;
            }
    double pipsToLevelAbove = CalculatePipsDistance(priceLevelAbove, g_currentPrice);
    tooltipAbove = FormatTooltipWithDistanceFast(tooltipAbove, pipsToLevelAbove);
    CreateTHLineObject(lineNameAbove, priceLevelAbove, lineColor, lineStyle, lineWidth, tooltipAbove, inpTHLineObjectType, false);
    if(inpShowPipDistanceLabels) {
        color labelColorAbove = (levelType == 2) ? inpTriggerLabelColor : lineColor;
        CreatePipDistanceLabel(lineNameAbove+"_PipsLabel", priceLevelAbove, pipsToLevelAbove, labelColorAbove, levelInfoAbove);
    }
            
            // -----------------------------------------------------------
            // ZONE SUPPORT: Create zone between levels
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            
            // Uses GetHighestStructureLevel for clean logic
            // Pass fixed step size for consistent zone height
            // -----------------------------------------------------------
            if(inpShowMidZones) {
                // PERF: Reuse already-computed structLevel instead of calling GetHighestStructureLevel again
    bool isStructureLevel = (structLevel > 0 && inpShowStructure);
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
        
        // ---------------------------------------------------------------
        // ZONE SUPPORT: Tracking variables for levels below
        
        // ---------------------------------------------------------------
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
            
            // PERFORMANCE FIX: Early viewport culling - skip ALL string work for off-screen levels
            bool isBelowVisible = (priceLevelBelow >= vpBottom && priceLevelBelow <= vpTop);
            
            // Determine level type (needed for counting even off-screen)
            int levelType = 0; // 0=skip, 1=structure, 2=trigger
            int structLevel = 0;
    if (intervalSize > 4 && intervals[4] > 0 && stepCountBelow % intervals[4] == 0 && inpShowStructure && inpShowStructureL5) {
                levelType = 1; structLevel = 5;
            } else if (intervalSize > 3 && intervals[3] > 0 && stepCountBelow % intervals[3] == 0 && inpShowStructure && inpShowStructureL4) {
                levelType = 1; structLevel = 4;
            } else if (intervalSize > 2 && intervals[2] > 0 && stepCountBelow % intervals[2] == 0 && inpShowStructure && inpShowStructureL3) {
                levelType = 1; structLevel = 3;
            } else if (intervalSize > 1 && intervals[1] > 0 && stepCountBelow % intervals[1] == 0 && inpShowStructure && inpShowStructureL2) {
                levelType = 1; structLevel = 2;
            } else if (intervalSize > 0 && intervals[0] > 0 && stepCountBelow % intervals[0] == 0 && inpShowStructure && inpShowStructureL1) {
                levelType = 1; structLevel = 1;
            } else if (triggerEnabled) {
                levelType = 2;
            } else {
                // Non-structural steps are trigger subdivisions — skip when triggers disabled
                levelType = 0;
            }
            
            // Skip trigger subdivisions when triggers disabled
            if(levelType == 0) {
                levelCountBelow++;
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
            // PERF: Inline overlap info using already-computed structLevel (same as above loop)
            string overlapLevelsBelow = (structLevel > 0) ? ("L" + IntegerToString(structLevel)) : "";
    string overlapTFsBelow = (structLevel > 0) ? cachedStructTF[structLevel - 1] : shortCurrentTFCached;
    if(levelType == 1) {
                switch(structLevel) {
                    case 5: {
                        lineNameBelow = prefix + "StructureLevel5_Down_" + IntegerToString(stepCountBelow / intervals[4]);
    tooltipBelow = "[" + overlapTFsBelow + "] " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[4]) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(quintupleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = overlapTFsBelow + " " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[4]);
    lineColor = inpStructureL5Color; lineStyle = inpStructureL5Style; lineWidth = inpStructureL5Width;
    break;
                    }
                    case 4: {
                        lineNameBelow = prefix + "StructureLevel4_Down_" + IntegerToString(stepCountBelow / intervals[3]);
    tooltipBelow = "[" + overlapTFsBelow + "] " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[3]) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(quadrupleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = overlapTFsBelow + " " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[3]);
    lineColor = inpStructureL4Color; lineStyle = inpStructureL4Style; lineWidth = inpStructureL4Width;
    break;
                    }
                    case 3: {
                        lineNameBelow = prefix + "StructureLevel3_Down_" + IntegerToString(stepCountBelow / intervals[2]);
    tooltipBelow = "[" + overlapTFsBelow + "] " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[2]) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(tripleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = overlapTFsBelow + " " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[2]);
    lineColor = inpStructureL3Color; lineStyle = inpStructureL3Style; lineWidth = inpStructureL3Width;
    break;
                    }
                    case 2: {
                        lineNameBelow = prefix + "StructureLevel2_Down_" + IntegerToString(stepCountBelow / intervals[1]);
    tooltipBelow = "[" + overlapTFsBelow + "] " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[1]) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(doubleStructureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = overlapTFsBelow + " " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[1]);
    lineColor = inpStructureL2Color; lineStyle = inpStructureL2Style; lineWidth = inpStructureL2Width;
    break;
                    }
                    default: {
                        lineNameBelow = prefix + "StructureLevel1_Down_" + IntegerToString(stepCountBelow / intervals[0]);
    tooltipBelow = "[" + overlapTFsBelow + "] " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[0]) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | " + basisLabel + ": " + DoubleToString(structureTFTHStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = overlapTFsBelow + " " + overlapLevelsBelow + " -" + IntegerToString(stepCountBelow / intervals[0]);
    lineColor = inpStructureL1Color; lineStyle = inpStructureL1Style; lineWidth = inpStructureL1Width;
    break;
                    }
                }
            } else {
                lineNameBelow = prefix + "TriggerTH_Down_" + IntegerToString(stepCountBelow);
    tooltipBelow = "[" + shortCurrentTFCached + "] -" + IntegerToString(stepCountBelow) + " | Price: " + DoubleToString(priceLevelBelow, GetCachedDigits()) + " | L: " + DoubleToString(cachedLongStep * thStepSizePoints * pointsPerPip, 1) + ", S: " + DoubleToString(cachedShortStep * thStepSizePoints * pointsPerPip, 1) + " pips";
    levelInfoBelow = shortCurrentTFCached + " -" + IntegerToString(stepCountBelow);
    lineColor = inpTriggerColor; lineStyle = inpTriggerStyle; lineWidth = inpTriggerWidth;
            }
    double pipsToLevelBelow = CalculatePipsDistance(priceLevelBelow, g_currentPrice);
    tooltipBelow = FormatTooltipWithDistanceFast(tooltipBelow, pipsToLevelBelow);
    CreateTHLineObject(lineNameBelow, priceLevelBelow, lineColor, lineStyle, lineWidth, tooltipBelow, inpTHLineObjectType, false);
    if(inpShowPipDistanceLabels) {
        color labelColorBelow = (levelType == 2) ? inpTriggerLabelColor : lineColor;
        CreatePipDistanceLabel(lineNameBelow+"_PipsLabel", priceLevelBelow, pipsToLevelBelow, labelColorBelow, levelInfoBelow);
    }
            
            // -----------------------------------------------------------
            // ZONE SUPPORT: Create zone between levels
            // UNIFIED APPROACH: Use CreateZoneWithSmartFallback
            
            // Uses GetHighestStructureLevel for clean logic
            // Pass fixed step size for consistent zone height
            // -----------------------------------------------------------
            if(inpShowMidZones) {
                // PERF: Reuse already-computed structLevel instead of calling GetHighestStructureLevel again
    bool isStructureLevel = (structLevel > 0 && inpShowStructure);
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
            Print("[D][LBL] ? DrawTHLevels: Drew ", zoneCountAbove, " zones above, ",
                  zoneCountBelow, " zones below");
        }
    #endif

        TH3_PROF_END(THLevelsLoops);
    }
}
    void SetLabelFont(const string name) {
    ObjectSetString(0, name, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpFontSize);
}
// Helper: Initialize common properties for an ATR chart label
void InitATRChartLabel(const string name, ENUM_BASE_CORNER corner, ENUM_ANCHOR_POINT anchor) {
    ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
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
    double point = GetCachedPoint();
    double pipSize = GetCachedPipSize();
    if(IsZero(point, EPSILON_PRICE) || IsZero(pipSize, EPSILON_PRICE)) return false;
    double atrPips = NormalizeDouble((atrValuePoints * point) / pipSize, 1);
    double shortStepPips = NormalizeDouble(atrPips * SS_MULTIPLIER, 1);
    double longStepPips = NormalizeDouble(atrPips * LS_MULTIPLIER, 1);
    double target3x = MathFloor(atrPips * 3.0);
    double target5x = MathFloor(atrPips * 5.0);
    double target15x = MathFloor(atrPips * 15.0);
    string mainObjName = objectPrefix + "ATR_" + timeframeName;
    string stepsObjName = objectPrefix + "ATR_Steps_" + timeframeName;
    string targetsObjName = objectPrefix + "ATR_Targets_" + timeframeName;
    if(!inpShowATRTargets && ObjectFind(0, targetsObjName) >= 0) {
        ObjectDelete(0, targetsObjName);
    }
    
    string targetsText = DoubleToString(target3x, 0) + " - " + DoubleToString(target5x, 0) + " - " + DoubleToString(target15x, 0);
    string mainText = timeframeName + ": " + DoubleToString(atrPips, 1);
    string stepsText = "(" + DoubleToString(shortStepPips, 1) + " - " + DoubleToString(longStepPips, 1) + ")";

    // PERF: Check if objects already exist with correct text - skip redundant ObjectSet calls
    bool mainExists = (ObjectFind(0, mainObjName) >= 0);
    bool stepsExists = (ObjectFind(0, stepsObjName) >= 0);
    bool targetsExists = (inpShowATRTargets && ObjectFind(0, targetsObjName) >= 0);

    if(mainExists && stepsExists) {
        // Objects already configured - only update text/color if changed
        string curMainText = ObjectGetString(0, mainObjName, OBJPROP_TEXT);
        string curStepsText = ObjectGetString(0, stepsObjName, OBJPROP_TEXT);
        bool textChanged = (curMainText != mainText || curStepsText != stepsText);
        if(textChanged) {
            ObjectSetString(0, mainObjName, OBJPROP_TEXT, mainText);
            ObjectSetString(0, stepsObjName, OBJPROP_TEXT, stepsText);
        }
        color curColor = (color)ObjectGetInteger(0, mainObjName, OBJPROP_COLOR);
        if(curColor != textColor) {
            ObjectSetInteger(0, mainObjName, OBJPROP_COLOR, textColor);
            ObjectSetInteger(0, stepsObjName, OBJPROP_COLOR, textColor);
        }
        if(inpShowATRTargets) {
            if(targetsExists) {
                string curTargets = ObjectGetString(0, targetsObjName, OBJPROP_TEXT);
                if(curTargets != targetsText) ObjectSetString(0, targetsObjName, OBJPROP_TEXT, targetsText);
                color curTColor = (color)ObjectGetInteger(0, targetsObjName, OBJPROP_COLOR);
                if(curTColor != textColor) ObjectSetInteger(0, targetsObjName, OBJPROP_COLOR, textColor);
            } else {
                if(ObjectCreate(0, targetsObjName, OBJ_LABEL, 0, 0, 0)) {
                    ObjectSetString(0, targetsObjName, OBJPROP_TEXT, targetsText);
                    ObjectSetInteger(0, targetsObjName, OBJPROP_COLOR, textColor);
                    SetLabelFont(targetsObjName);
                }
            }
        }
        // Position update (Y may have changed due to layout shift)
        int baseY = MathAbs(yPos);
        int singleLineHeight_u = inpFontSize + inpLabelRowGap;
        ObjectSetInteger(0, mainObjName, OBJPROP_YDISTANCE, baseY);
        ObjectSetInteger(0, stepsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight_u);
        if(inpShowATRTargets && ObjectFind(0, targetsObjName) >= 0) {
            ObjectSetInteger(0, targetsObjName, OBJPROP_YDISTANCE, baseY + singleLineHeight_u * 2);
        }
        int labelXDistance = MathAbs(xPos);
        int mainTextWidth = (int)(StringLen(mainText) * inpFontSize * 0.6);
        int stepsTextWidth = (int)(StringLen(stepsText) * inpFontSize * 0.6);
        int mainOffset = (stepsTextWidth - mainTextWidth) / 2;
        if(mainOffset < 0) mainOffset = 0;
        ObjectSetInteger(0, mainObjName, OBJPROP_XDISTANCE, labelXDistance + mainOffset);
        ObjectSetInteger(0, stepsObjName, OBJPROP_XDISTANCE, labelXDistance);
        if(inpShowATRTargets && ObjectFind(0, targetsObjName) >= 0) {
            int targetsTextWidth = (int)(StringLen(targetsText) * inpFontSize * 0.6);
            int targetsOffset = (mainTextWidth - targetsTextWidth) / 2 + mainOffset;
            if(targetsOffset < 0) targetsOffset = 0;
            ObjectSetInteger(0, targetsObjName, OBJPROP_XDISTANCE, labelXDistance + targetsOffset);
        }
        return true;
    }

    // First-time creation: set all properties
    if (!mainExists) {
        if (!ObjectCreate(0, mainObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (!stepsExists) {
        if (!ObjectCreate(0, stepsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
    if (inpShowATRTargets && !targetsExists) {
        if (!ObjectCreate(0, targetsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    }
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
    InitATRChartLabel(mainObjName, corner, anchor);
    InitATRChartLabel(stepsObjName, corner, anchor);
    if(inpShowATRTargets) {
        InitATRChartLabel(targetsObjName, corner, anchor);
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
    double point = GetCachedPoint();
    double pipSize = GetCachedPipSize();
    int digits = GetCachedDigits();
    if(IsZero(point, EPSILON_PRICE) || IsZero(pipSize, EPSILON_PRICE) || digits == 0) return;

    TH3_PROF_START(ATRLabels);
    
    // Naming is timeframe-specific; update in-place to avoid expensive object churn
    string currentTFStr = IntegerToString(GetCachedPeriod());
    string uniquePrefix = objectPrefix + "TF" + currentTFStr + "_";
    
    // Standard MT5 timeframes with minutes for CalculateHybridATR
    string timeframes[] = {"M1", "M5", "M15", "H1", "H4", "D1", "W1", "MN1"};
    int tfMinutes[] = {1, 5, 15, 60, 240, 1440, 10080, 43200};

    // PERF: Decouple heavy ATR fetch from layout updates.
    // Recompute ATR values on timeframe change or short cadence; reuse cached values otherwise.
    static double s_lastATRPips[8] = {0,0,0,0,0,0,0,0};
    static double s_cachedATRValues[8] = {0,0,0,0,0,0,0,0};
    static int s_lastATRPeriod = -1;
    static int s_lastATROffsetContribution = 0;  // Track last Y offset for early-return path
    static uint s_lastATRFetchMs = 0;

    uint nowMs = GetTickCount();
    bool periodChanged = (s_lastATRPeriod != GetCachedPeriod());
    bool refreshATRValues = periodChanged || s_lastATRFetchMs == 0 || (nowMs - s_lastATRFetchMs >= 1500);

    double currentATRValues[8];
    double currentATRPips[8];
    bool anyChanged = periodChanged;
    for(int i = 0; i < 8; i++) {
        double atrVal = refreshATRValues ? GetATRForTimeframe(tfMinutes[i]) : s_cachedATRValues[i];
        currentATRValues[i] = atrVal;
        double pips = (atrVal > 0 && !IsZero(pipSize, EPSILON_PRICE))
                      ? NormalizeDouble(atrVal / pipSize, 1) : 0.0;
        currentATRPips[i] = pips;
        if(!anyChanged && MathAbs(pips - s_lastATRPips[i]) > 0.05) anyChanged = true;
    }

    if(refreshATRValues) {
        for(int i = 0; i < 8; i++) {
            s_cachedATRValues[i] = currentATRValues[i];
        }
        s_lastATRFetchMs = nowMs;
    }

    // PERF: Use integer hash instead of 9-part string concatenation
    // WHY: Building layoutSig string created 8 IntegerToString + 8 "+" allocations per tick.
    // Integer XOR-hash is ~50x faster and detects same changes.
    uint layoutHash = (uint)((int)inpLabelArrangement * 73856093) ^
                      (uint)(inpLabelsMarginLeft * 19349663) ^
                      (uint)(inpLabelsMarginTop * 83492791) ^
                      (uint)(inpFontSize * 48611383) ^
                      (uint)(inpLabelRowGap * 27644437) ^
                      (uint)(inpLabelColumnGap * 63197219) ^
                      (uint)(inpSectionGap * 91573241) ^
                      (uint)((inpShowATRTargets ? 1 : 0) * 37139213) ^
                      (uint)(GetCachedChartWidth() * 52429867);
    static uint s_lastATRLayoutHash = 0;
    bool layoutChanged = (layoutHash != s_lastATRLayoutHash);

    if(!anyChanged && !layoutChanged) {
        // ATR values unchanged - skip expensive object operations
        // but still update the Y offset so subsequent sections stack correctly
        g_currentLabelYOffset += s_lastATROffsetContribution;
        TH3_PROF_END(ATRLabels);
        return;
    }
    // Update stored values
    for(int i = 0; i < 8; i++) s_lastATRPips[i] = currentATRPips[i];
    s_lastATRPeriod = GetCachedPeriod();
    s_lastATRLayoutHash = layoutHash;

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
    
    // Layout setup - ATR renders FIRST (at the top)
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
    bool atrTitleCreated = false;
    if(ObjectFind(0, titleObjName) < 0) {
        ObjectCreate(0, titleObjName, OBJ_LABEL, 0, 0, 0);
        atrTitleCreated = true;
    }
    // PERF: Static properties only set on creation — saves ~9 ObjectSet* calls per refresh
    if(atrTitleCreated) {
        ObjectSetString(0, titleObjName, OBJPROP_TEXT, "ATR:");
        ObjectSetInteger(0, titleObjName, OBJPROP_COLOR, clrDarkBlue);
        ObjectSetString(0, titleObjName, OBJPROP_FONT, inpFontName);
        ObjectSetInteger(0, titleObjName, OBJPROP_FONTSIZE, inpFontSize);
        ObjectSetInteger(0, titleObjName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, titleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, titleObjName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, titleObjName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, titleObjName, OBJPROP_BACK, false);
    }
    // Dynamic properties: position + visibility (may change each refresh)
    ObjectSetInteger(0, titleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    ObjectSetInteger(0, titleObjName, OBJPROP_YDISTANCE, titleYPos);
    ObjectSetInteger(0, titleObjName, OBJPROP_TIMEFRAMES, IsIndicatorHidden() ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    
    int titleWidth = (int)CalculateTextWidth("ATR:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = GetCachedChartWidth() - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowATRTargets, rowSpacing);
    
    int renderedCount = 0;
    for(int i = 0; i < ArraySize(timeframes); i++) {
        string timeframeName = timeframes[i];
    int targetMinutes = tfMinutes[i];

    // PERF: Reuse pre-fetched ATR values from this same call (avoid duplicate heavy computation)
    double atrValue = currentATRValues[i];
    if(atrValue <= 0 || atrValue == EMPTY_VALUE) {
            ATR_PRINTF2("=== DisplayATRLabels: Invalid ATR for ", timeframeName, " ===");
    continue;
        }
    double atrPoints = atrValue / point;
    double atrPips = NormalizeDouble(atrValue / pipSize, 1);
    double shortStepPips = NormalizeDouble(atrPips * SS_MULTIPLIER, 1);
    double longStepPips = NormalizeDouble(atrPips * LS_MULTIPLIER, 1);
    double target3x = MathFloor(atrPips * 3.0);
    double target5x = MathFloor(atrPips * 5.0);
    double target15x = MathFloor(atrPips * 15.0);
    
    // Resolve label color: user override or auto per-timeframe
    color labelColor = colors[i];
    
    // Calculate label width for horizontal wrapping
        string mainText = inpShowTimeframeInLabels ?
            timeframeName + ": " + DoubleToString(atrPips, 1) :
            DoubleToString(atrPips, 1);
        string stepsText = "(" + DoubleToString(shortStepPips, 1) + " - " + DoubleToString(longStepPips, 1) + ")";
        string targetsText = DoubleToString(target3x, 0) + " - " + DoubleToString(target5x, 0) + " - " + DoubleToString(target15x, 0);
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
        int offsetContribution = consumedY + sectionGap;
        g_currentLabelYOffset += offsetContribution;
        s_lastATROffsetContribution = offsetContribution;  // Store for early-return path
    } else {
        s_lastATROffsetContribution = 0;
    }
    
    ATR_PRINT("=== DisplayATRLabels: Completed ===");

    TH3_PROF_END(ATRLabels);
}

// Fast ATR labels hide/show without deletion (O(1) object operations)
void SetATRLabelsVisibility(const string objectPrefix, const bool visible) {
    // Match DisplayATRLabels naming
    string currentTFStr = IntegerToString(GetCachedPeriod());
    string uniquePrefix = objectPrefix + "TF" + currentTFStr + "_";
    string allTimeframes[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};

    // F key (global hide) always wins
    bool shouldShow = (visible && !IsIndicatorHidden());
    long tf = shouldShow ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;

    // PERF: ObjectSetInteger is a no-op on non-existent objects — skip ObjectFind guards
    ObjectSetInteger(0, uniquePrefix + "ATR_Title", OBJPROP_TIMEFRAMES, tf);

    long targetsTF = (shouldShow && inpShowATRTargets) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < ArraySize(allTimeframes); i++) {
        string tfName = allTimeframes[i];
        ObjectSetInteger(0, uniquePrefix + "ATR_" + tfName, OBJPROP_TIMEFRAMES, tf);
        ObjectSetInteger(0, uniquePrefix + "ATR_Steps_" + tfName, OBJPROP_TIMEFRAMES, tf);
        ObjectSetInteger(0, uniquePrefix + "ATR_Targets_" + tfName, OBJPROP_TIMEFRAMES, targetsTF);
    }
}

// Fast TH labels hide/show without deletion (O(1) object operations)
// mode: 0=OFF, 1=FRACTAL
void SetTHLabelsVisibility(const string objectPrefix, const int mode) {
    // F key (global hide) always wins
    bool shouldShow = ((mode == 1) && !IsIndicatorHidden());
    long tf = shouldShow ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;

    // PERF: ObjectSetInteger is a no-op on non-existent objects — skip ObjectFind guards
    ObjectSetInteger(0, objectPrefix + "TH_Title", OBJPROP_TIMEFRAMES, tf);

    // Fractal timeframes
    long fractalTargetsTF = (shouldShow && inpShowTHTargets) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < ArraySize(FRACTAL_TIMEFRAMES); i++) {
        string timeframeName = FRACTAL_TIMEFRAMES[i];
        ObjectSetInteger(0, objectPrefix + "TH_" + timeframeName, OBJPROP_TIMEFRAMES, tf);
        ObjectSetInteger(0, objectPrefix + "TH_Steps_" + timeframeName, OBJPROP_TIMEFRAMES, tf);
        ObjectSetInteger(0, objectPrefix + "TH_Targets_" + timeframeName, OBJPROP_TIMEFRAMES, fractalTargetsTF);
    }
}
    bool CreateTHLabel(const string objectPrefix, const string timeframeName, const double thValuePoints, const int xPos, const int yPos, const color textColor, const int horizontalSpacing, const int verticalSpacing) {
    if (!inpShowTHLabels) return true;
    
    // Calculate TH, SS, LS values
    double point = GetCachedPoint();
    double pipSize = GetCachedPipSize();
    if(IsZero(point, EPSILON_PRICE) || IsZero(pipSize, EPSILON_PRICE)) return false;
    double thValuePips = NormalizeDouble((thValuePoints * point) / pipSize, 1);
    double shortStepPips = NormalizeDouble(thValuePips * SS_MULTIPLIER, 1);
    double longStepPips = NormalizeDouble(thValuePips * LS_MULTIPLIER, 1);
    double target3x = MathFloor(thValuePips * 3.0);
    double target5x = MathFloor(thValuePips * 5.0);
    double target15x = MathFloor(thValuePips * 15.0);
    string mainObjName = objectPrefix + "TH_" + timeframeName;
    string stepsObjName = objectPrefix + "TH_Steps_" + timeframeName;
    string targetsObjName = objectPrefix + "TH_Targets_" + timeframeName;
    if(!inpShowTHTargets && ObjectFind(0, targetsObjName) >= 0) {
        ObjectDelete(0, targetsObjName);
    }
    
    // PERF: Track which objects are newly created vs existing for fast-path updates
    bool mainCreated = false, stepsCreated = false, targetsCreated = false;
    if (ObjectFind(0, mainObjName) < 0) {
        if (!ObjectCreate(0, mainObjName, OBJ_LABEL, 0, 0, 0)) return false;
    mainCreated = true;
    }
    if (ObjectFind(0, stepsObjName) < 0) {
        if (!ObjectCreate(0, stepsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    stepsCreated = true;
    }
    if (inpShowTHTargets && ObjectFind(0, targetsObjName) < 0) {
        if (!ObjectCreate(0, targetsObjName, OBJ_LABEL, 0, 0, 0)) return false;
    targetsCreated = true;
    }
    // PERF: Only rebuild text strings + set text/color when TH value or color changed
    //       ObjectGetString is cheaper than StringFormat + ObjectSetString
    bool textChanged = mainCreated || stepsCreated;
    string mainText = GetBaseTimeframeName(timeframeName) + ": " + DoubleToString(thValuePips, 1);
    if(!textChanged) {
        string prevMain = ObjectGetString(0, mainObjName, OBJPROP_TEXT);
        textChanged = (prevMain != mainText);
    }
    bool colorChanged = mainCreated || ((color)ObjectGetInteger(0, mainObjName, OBJPROP_COLOR) != textColor);
    string stepsText = "(" + DoubleToString(shortStepPips, 1) + " - " + DoubleToString(longStepPips, 1) + ")";
    string targetsText = DoubleToString(target3x, 0) + " - " + DoubleToString(target5x, 0) + " - " + DoubleToString(target15x, 0);
    if(inpShowTHTargets && (textChanged || targetsCreated)) {
        ObjectSetString(0, targetsObjName, OBJPROP_TEXT, targetsText);
    if(colorChanged) ObjectSetInteger(0, targetsObjName, OBJPROP_COLOR, textColor);
    if(targetsCreated) SetLabelFont(targetsObjName);
    }
    if(textChanged) {
        ObjectSetString(0, mainObjName, OBJPROP_TEXT, mainText);
        ObjectSetString(0, stepsObjName, OBJPROP_TEXT, stepsText);
    }
    if(colorChanged) {
        ObjectSetInteger(0, mainObjName, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, stepsObjName, OBJPROP_COLOR, textColor);
    }
    if(mainCreated) SetLabelFont(mainObjName);
    if(stepsCreated) SetLabelFont(stepsObjName);
    // PERF: Static properties only on creation - corner, anchor, selectable, hidden never change
    ENUM_BASE_CORNER corner = CORNER_LEFT_LOWER;
    ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER;
    if(targetsCreated && inpShowTHTargets) {
        ObjectSetInteger(0, targetsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, targetsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, targetsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, targetsObjName, OBJPROP_HIDDEN, false);
    }
    if(mainCreated) {
    ObjectSetInteger(0, mainObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, mainObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, mainObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, mainObjName, OBJPROP_HIDDEN, false);
    }
    if(stepsCreated) {
    ObjectSetInteger(0, stepsObjName, OBJPROP_CORNER, corner);
    ObjectSetInteger(0, stepsObjName, OBJPROP_ANCHOR, anchor);
    ObjectSetInteger(0, stepsObjName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, stepsObjName, OBJPROP_HIDDEN, false);
    }
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
        double point = GetCachedPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    // PERF: Skip full TH label rebuild if base price and layout haven't changed
    // WHY: CalculateTHPoints() and CalculateStandardPercentage() were called for every 
    // fractal timeframe on every label refresh, even though TH values only change when
    // the base price changes. This guard skips ~8 recalculations per tick.
    static double s_lastFractalTHPrice = 0.0;
    static int s_lastFractalTHOffsetContribution = 0;
    static uint s_lastFractalLayoutHash = 0;
    uint fractalLayoutHash = (uint)((int)inpLabelArrangement * 73856093) ^
                             (uint)(inpLabelsMarginLeft * 19349663) ^
                             (uint)(inpFontSize * 48611383) ^
                             (uint)(inpLabelRowGap * 27644437) ^
                             (uint)(inpLabelColumnGap * 63197219) ^
                             (uint)(inpSectionGap * 91573241) ^
                             (uint)((inpShowTHTargets ? 1 : 0) * 37139213) ^
                             (uint)(GetCachedChartWidth() * 52429867);
    bool fractalPriceChanged = MathAbs(dailyPriceForTH - s_lastFractalTHPrice) > EPSILON_PRICE;
    bool fractalLayoutChanged = (fractalLayoutHash != s_lastFractalLayoutHash);
    if(!fractalPriceChanged && !fractalLayoutChanged) {
        g_currentLabelYOffsetBottom += s_lastFractalTHOffsetContribution;
        return;
    }
    s_lastFractalTHPrice = dailyPriceForTH;
    s_lastFractalLayoutHash = fractalLayoutHash;
    bool isVerticalLayout = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL);
    int rowSpacing = inpLabelRowGap;
    int horizontalPadding = inpLabelColumnGap;
    int startXPos = inpLabelsMarginLeft;
    int lineGap = rowSpacing;
    int singleLineHeight = inpFontSize + lineGap;
    int titleHeight = singleLineHeight;
    // Title on same row as first item (horizontal) or above it (vertical)
    int safeBottomPad = inpFontSize + 6;
    int titleYPos = inpTHLabelsMarginBottom + safeBottomPad + g_currentLabelYOffsetBottom;
    int titleAdjustment = inpShowTHTargets ? (singleLineHeight * 2) : singleLineHeight;
    int startYPos = isVerticalLayout ? (titleYPos + singleLineHeight) : titleYPos;
    int sectionGap = inpSectionGap;
    string thTitleObjName = objectPrefix + "TH_Title";
    bool thTitleCreated = false;
    if(ObjectFind(0, thTitleObjName) < 0) {
        ObjectCreate(0, thTitleObjName, OBJ_LABEL, 0, 0, 0);
        thTitleCreated = true;
    }
    // PERF: Static properties only set on creation
    if(thTitleCreated) {
        ObjectSetString(0, thTitleObjName, OBJPROP_TEXT, "TH:");
        ObjectSetInteger(0, thTitleObjName, OBJPROP_COLOR, clrDarkBlue);
        ObjectSetString(0, thTitleObjName, OBJPROP_FONT, inpFontName);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_FONTSIZE, inpFontSize);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_BACK, false);
    }
    // Dynamic properties: position + visibility
    ObjectSetInteger(0, thTitleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    int thTitleY = titleYPos + titleAdjustment;
    ObjectSetInteger(0, thTitleObjName, OBJPROP_YDISTANCE, thTitleY);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, IsIndicatorHidden() ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    int titleWidth = (int)CalculateTextWidth("TH:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = GetCachedChartWidth() - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowTHTargets, rowSpacing);
    // PERF: Pre-allocate to known fractal count instead of zero-then-grow
    int fractalCount = ArraySize(FRACTAL_TIMEFRAMES);
    ArrayResize(g_storedTHs, fractalCount);
    ArrayResize(g_labelPositions, fractalCount);
    int storedCount = 0;
    for(int i = 0; i < fractalCount; i++) {
        string timeframeName = FRACTAL_TIMEFRAMES[i];
    double percentage = MODIFIED_FRACTAL_PERCENTAGES[i];
    double thPoints = CalculateTHPoints(dailyPriceForTH, GetCachedDigits(), percentage);
    g_storedTHs[storedCount].timeframeName = timeframeName;
    g_storedTHs[storedCount].thValue = thPoints;
    storedCount++;
    StoreLabelPosition(timeframeName, currentXPos, currentYPos);
        double cachedPipSz = GetCachedPipSize();
        double thValuePips = IsZero(cachedPipSz, EPSILON_PRICE) ? 0.0 : NormalizeDouble((thPoints * GetCachedPoint()) / cachedPipSz, 1);
        double shortStepPips = NormalizeDouble(thValuePips * SS_MULTIPLIER, 1);
        double longStepPips = NormalizeDouble(thValuePips * LS_MULTIPLIER, 1);
        double target3x = MathFloor(thValuePips * 3.0);
        double target5x = MathFloor(thValuePips * 5.0);
        double target15x = MathFloor(thValuePips * 15.0);
        string mainText = inpShowTimeframeInLabels ?
            GetBaseTimeframeName(timeframeName) + ": " + DoubleToString(thValuePips, 1) :
            DoubleToString(thValuePips, 1);
        string stepsText = "(" + DoubleToString(shortStepPips, 1) + " - " + DoubleToString(longStepPips, 1) + ")";
        string targetsText = DoubleToString(target3x, 0) + " - " + DoubleToString(target5x, 0) + " - " + DoubleToString(target15x, 0);
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
    s_lastFractalTHOffsetContribution = fractalConsumedY + sectionGap;
    g_currentLabelYOffsetBottom += s_lastFractalTHOffsetContribution;
}
    void DisplayStandardTHs(const string objectPrefix, const double dailyPriceForTH, const datetime currentTime) {
        double point = GetCachedPoint();
    // OPTIMIZATION: Use cached Digits
    int digits = GetCachedDigits();
    // Use IsZero for float comparison instead of == 0
    if(IsZero(point, EPSILON_PRICE) || digits == 0) return;
    // PERF: Skip rebuild if base price and layout unchanged (same pattern as DisplayFractalTHs)
    static double s_lastStdTHPrice = 0.0;
    static int s_lastStdTHOffsetContribution = 0;
    static uint s_lastStdLayoutHash = 0;
    uint stdLayoutHash = (uint)((int)inpLabelArrangement * 73856093) ^
                         (uint)(inpLabelsMarginLeft * 19349663) ^
                         (uint)(inpFontSize * 48611383) ^
                         (uint)(inpLabelRowGap * 27644437) ^
                         (uint)(inpLabelColumnGap * 63197219) ^
                         (uint)(inpSectionGap * 91573241) ^
                         (uint)((inpShowTHTargets ? 1 : 0) * 37139213) ^
                         (uint)(GetCachedChartWidth() * 52429867);
    bool stdPriceChanged = MathAbs(dailyPriceForTH - s_lastStdTHPrice) > EPSILON_PRICE;
    bool stdLayoutChanged = (stdLayoutHash != s_lastStdLayoutHash);
    if(!stdPriceChanged && !stdLayoutChanged) {
        g_currentLabelYOffsetBottom += s_lastStdTHOffsetContribution;
        return;
    }
    s_lastStdTHPrice = dailyPriceForTH;
    s_lastStdLayoutHash = stdLayoutHash;
    bool isVerticalLayout = (inpLabelArrangement == LABEL_ARRANGEMENT_VERTICAL);
    int rowSpacing = inpLabelRowGap;
    int horizontalPadding = inpLabelColumnGap;
    int startXPos = inpLabelsMarginLeft;
    int lineGap = rowSpacing;
    int singleLineHeight = inpFontSize + lineGap;
    int titleHeight = singleLineHeight;
    // Title on same row as first item (horizontal) or above it (vertical)
    int safeBottomPad = inpFontSize + 6;
    int titleYPos = inpTHLabelsMarginBottom + safeBottomPad + g_currentLabelYOffsetBottom;
    int titleAdjustment = inpShowTHTargets ? (singleLineHeight * 2) : singleLineHeight;
    int startYPos = isVerticalLayout ? (titleYPos + singleLineHeight) : titleYPos;
    int titleWidth = (int)CalculateTextWidth("TH:");
    int labelStartX = GetLabelStartX(startXPos, titleWidth, horizontalPadding, isVerticalLayout);
    int currentXPos = labelStartX;
    int currentYPos = startYPos;
    int yStep = rowSpacing;
    int xStep = horizontalPadding;
    int maxWidth = GetCachedChartWidth() - startXPos * 2;
    int lineHeight = GetLabelLineHeight(inpShowTHTargets, rowSpacing);
    string thTitleObjName = objectPrefix + "TH_Title";
    bool thTitleCreated = false;
    if(ObjectFind(0, thTitleObjName) < 0) {
        ObjectCreate(0, thTitleObjName, OBJ_LABEL, 0, 0, 0);
        thTitleCreated = true;
    }
    // PERF: Static properties only set on creation
    if(thTitleCreated) {
        ObjectSetString(0, thTitleObjName, OBJPROP_TEXT, "TH:");
        ObjectSetInteger(0, thTitleObjName, OBJPROP_COLOR, clrDarkBlue);
        ObjectSetString(0, thTitleObjName, OBJPROP_FONT, inpFontName);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_FONTSIZE, inpFontSize);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_HIDDEN, false);
        ObjectSetInteger(0, thTitleObjName, OBJPROP_BACK, false);
    }
    // Dynamic properties: position + visibility
    ObjectSetInteger(0, thTitleObjName, OBJPROP_XDISTANCE, inpLabelsMarginLeft);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_YDISTANCE, titleYPos + titleAdjustment);
    ObjectSetInteger(0, thTitleObjName, OBJPROP_TIMEFRAMES, IsIndicatorHidden() ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    for(int i = 0; i < ArraySize(STANDARD_TIMEFRAMES); i++) {
        string timeframeName = STANDARD_TIMEFRAMES[i];
    double percentage = CalculateStandardPercentage(STANDARD_MINUTES[i]);
    double thPoints = CalculateTHPoints(dailyPriceForTH, GetCachedDigits(), percentage);
    // PERF: Pre-expand with reserve instead of grow-by-1
    int thIndex = ArraySize(g_storedTHs);
    ArrayResize(g_storedTHs, thIndex + 1, ArraySize(STANDARD_TIMEFRAMES));
        g_storedTHs[thIndex].timeframeName = timeframeName;
    g_storedTHs[thIndex].thValue = thPoints;
        double stdPipSz = GetCachedPipSize();
        double thValuePips = IsZero(stdPipSz, EPSILON_PRICE) ? 0.0 : NormalizeDouble((thPoints * GetCachedPoint()) / stdPipSz, 1);
        double shortStepPips = NormalizeDouble(thValuePips * SS_MULTIPLIER, 1);
        double longStepPips = NormalizeDouble(thValuePips * LS_MULTIPLIER, 1);
        double target3x = MathFloor(thValuePips * 3.0);
        double target5x = MathFloor(thValuePips * 5.0);
        double target15x = MathFloor(thValuePips * 15.0);
        string mainText = inpShowTimeframeInLabels ?
            GetBaseTimeframeName(timeframeName) + ": " + DoubleToString(thValuePips, 1) :
            DoubleToString(thValuePips, 1);
        string stepsText = "(" + DoubleToString(shortStepPips, 1) + " - " + DoubleToString(longStepPips, 1) + ")";
        string targetsText = DoubleToString(target3x, 0) + " - " + DoubleToString(target5x, 0) + " - " + DoubleToString(target15x, 0);
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
    s_lastStdTHOffsetContribution = standardConsumedY + inpSectionGap;
    g_currentLabelYOffsetBottom += s_lastStdTHOffsetContribution;
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
        _LOG_GATE_E Print("[E][LBL] StoreLabelPosition: Failed to resize array");
    }
}
    int GetStoredXPosition(const string name) {
    for(int i=0; i<ArraySize(g_labelPositions); i++) if(g_labelPositions[i].name==name) return g_labelPositions[i].xPos;
    return inpLabelsMarginLeft;
}
    double CalculateTextWidth(string text) {
        double averageCharWidth=inpFontSize*0.7;
    double plusFactor=StringFind(text,"+")>=0?inpFontSize*0.3:0;
    // PERF: Detect digits via char scan instead of destructive StringReplace
    bool hasDigit=false;
    int len=StringLen(text);
    for(int c=0;c<len;c++){ushort ch=StringGetCharacter(text,c);if(ch>='0'&&ch<='9'){hasDigit=true;break;}}
    double numberFactor=hasDigit?inpFontSize*0.2:0;
    return len*averageCharWidth+plusFactor+numberFactor;
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
    // Position: below all data labels AND mode labels, using same corner as mode labels
    int xDistance = inpModeLabelXDistance;
    // Base: below ATR labels
    int yDistance = inpLabelsMarginTop + g_modeLabelYOffset;
    // Add space for entire mode label block (all active rows)
    int modeBlockHeight = GetModeLabelBlockHeight();
    if(modeBlockHeight > 0)
        yDistance += inpModeLabelYDistance + modeBlockHeight + 4;
    else
        yDistance += (inpModeLabelFontSize + 8);
    if(g_timeframeLocked)
    {
        // Create or update label showing locked timeframe (no emoji - MT4 doesn't support)
        string lockText = "[LOCK:" + PeriodToString(g_lockedPeriod) + "]";
    if(ObjectFind(0, g_lockStatusLabelName) < 0)
        {
            if(!ObjectCreate(0, g_lockStatusLabelName, OBJ_LABEL, 0, 0, 0))
            {
                _LOG_GATE_E Print("[E][LBL] Failed to create lock status label. Error: ", GetLastError());
    return;
            }
        }
        
        ObjectSetString(0, g_lockStatusLabelName, OBJPROP_TEXT, lockText);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_COLOR, clrCrimson);
    ObjectSetString(0, g_lockStatusLabelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_FONTSIZE, inpModeLabelFontSize);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_CORNER, inpModeLabelCorner);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_XDISTANCE, xDistance);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_YDISTANCE, yDistance);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_HIDDEN, true);
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

#endif // LABEL_FUNCTIONS_MQH
