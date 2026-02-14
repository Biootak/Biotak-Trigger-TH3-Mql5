#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#ifndef LEVEL_PIPELINE_MQH
#define LEVEL_PIPELINE_MQH

//+------------------------------------------------------------------+
//| LEVEL PIPELINE — Zone-First Architecture                         |
//|                                                                  |
//| PHILOSOPHY: Zone is the PRIMARY entity. Lines (triggers) are     |
//| derived from zone boundaries. Zones define the structure;        |
//| lines are visual markers at the edges where zones meet.          |
//|                                                                  |
//| PIPELINE STAGES:                                                 |
//|   Stage 1: CalculateLevels  → SCalculatedLevel[]                 |
//|   Stage 2: ClassifyLevels   → update classification in-place     |
//|   Stage 3: BuildZones       → SZoneDefinition[] (PRIMARY)        |
//|   Stage 4: DeriveTriggers   → STriggerLine[] (from zone bounds)  |
//|   Stage 5: RenderAll        → MT5 objects (zones first, lines)   |
//|                                                                  |
//| BENEFITS:                                                        |
//|   - Zones are always geometrically correct (no state mutation)   |
//|   - Render order is independent of calculation order             |
//|   - Viewport culling only affects rendering, not geometry        |
//|   - New modes only need to implement Stage 1 (price calc)        |
//|   - Testable without MT5 (stages 1-4 are pure data)             |
//+------------------------------------------------------------------+

#include "ConstantsAndEnums.mqh"

//+------------------------------------------------------------------+
//| STAGE 1 OUTPUT: Raw calculated level                             |
//+------------------------------------------------------------------+
struct SCalculatedLevel {
    double price;           // Level price
    int    logicalStep;     // Original step number (1, 2, 3, ...)
    bool   included;        // true = passes filter (structure/trigger/baseMultiplier)
    bool   isMidpoint;      // true = this is the center/anchor level (step 0)
    int    direction;       // +1 = above midpoint, -1 = below, 0 = midpoint
};

//+------------------------------------------------------------------+
//| STAGE 2 OUTPUT: Classification result for a level                |
//+------------------------------------------------------------------+
struct SLevelClassified {
    double price;
    int    logicalStep;
    bool   included;
    bool   isMidpoint;
    int    direction;
    
    // Classification results
    int    structureLevel;  // 0 = not structure, 1-5 = L1-L5
    bool   isTrigger;       // true = trigger level (not structure)
    bool   isStructure;     // true = any structure level (L1-L5)
    color  levelColor;
    ENUM_LINE_STYLE levelStyle;
    int    levelWidth;
    color  zoneColor;       // Color for zone touching this level
    string tooltip;         // Pre-built tooltip text
};

//+------------------------------------------------------------------+
//| STAGE 3 OUTPUT: Zone definition (PRIMARY ENTITY)                 |
//|                                                                  |
//| A zone is defined by TWO adjacent included levels.               |
//| The zone occupies the space between them.                        |
//+------------------------------------------------------------------+
struct SZoneDefinition {
    string name;            // Object name for this zone
    double upperBoundary;   // Upper level price
    double lowerBoundary;   // Lower level price
    double midPrice;        // Midpoint of zone
    double height;          // Zone visual height (based on heightPercent)
    double renderTop;       // Actual render top (midPrice + height/2)
    double renderBottom;    // Actual render bottom (midPrice - height/2)
    int    upperStep;       // Logical step of upper boundary
    int    lowerStep;       // Logical step of lower boundary
    int    direction;       // +1 = above midpoint, -1 = below
    int    zoneIndex;       // Sequential zone index in this direction
    bool   isStructure;     // Zone between structure levels
    bool   isTrigger;       // Zone between trigger levels
    color  zoneColor;       // Determined by dominant boundary
    int    transparency;
    ENUM_ZONE_STYLE style;
    bool   filled;
    bool   inViewport;      // false = skip render, but geometry is valid
};

//+------------------------------------------------------------------+
//| STAGE 4 OUTPUT: Trigger line (DERIVED from zone boundaries)      |
//|                                                                  |
//| A trigger line sits at the boundary between two adjacent zones.  |
//| Its properties come from the dominant zone it borders.           |
//+------------------------------------------------------------------+
struct STriggerLine {
    string name;            // Object name for this line
    double price;           // = zone boundary price
    int    logicalStep;
    int    direction;       // +1 = above, -1 = below, 0 = midpoint
    color  lineColor;
    ENUM_LINE_STYLE lineStyle;
    int    lineWidth;
    string tooltip;
    int    zoneAboveIdx;    // Index of zone above this line (-1 = none)
    int    zoneBelowIdx;    // Index of zone below this line (-1 = none)
    bool   inViewport;      // false = skip render
    bool   isMidpoint;
    bool   setBack;         // OBJPROP_BACK value (mode-specific)
    int    zOrder;          // OBJPROP_ZORDER value (mode-specific)
};

//+------------------------------------------------------------------+
//| MODE CONFIGURATION: All mode-specific settings in one place      |
//+------------------------------------------------------------------+
struct SModeConfig {
    string modeName;        // "SSLS", "M", "TP", "Combo", "Factor", "MEq", "TH"
    string objectPrefix;    // Full prefix including inpObjectPrefix
    
    // Fallback colors (when not structure/trigger)
    color  fallbackColor;
    ENUM_LINE_STYLE fallbackStyle;
    int    fallbackWidth;
    
    // Secondary fallback (for alternating modes like SSLS)
    color  fallbackColor2;
    ENUM_LINE_STYLE fallbackStyle2;
    int    fallbackWidth2;
    bool   hasAlternatingFallback; // true for SSLS mode
    
    // Midpoint styling
    color  midpointColor;
    ENUM_LINE_STYLE midpointStyle;
    int    midpointWidth;
    
    // Zone configuration
    bool   zonesEnabled;
    int    zoneTransparency;
    double zoneHeightPercent;
    color  zoneDefaultColor;
    ENUM_ZONE_STYLE zoneStyle;
    
    // Rendering flags
    bool   useObjPropBack;  // Set OBJPROP_BACK on lines (Factor modes)
    int    zOrder;          // OBJPROP_ZORDER value (Factor = 1, others = 0)
    bool   hideLineWhenTriggerOnly; // Factor: hide lines when trigger enabled
    bool   useSimpleZones;  // MEq: use CreateSimpleZone instead of SmartFallback
    bool   useStepFilter;   // false for MEq (draws every step)
    
    // Price boundaries
    bool   boundByHistorical; // true = stop at g_highestHigh/g_lowestLow
    double maxPrice;        // Upper price boundary (0 = no limit)
    double minPrice;        // Lower price boundary (0 = no limit)
};

//+------------------------------------------------------------------+
//| PIPELINE RESULT: Complete output ready for rendering             |
//+------------------------------------------------------------------+
struct SPipelineResult {
    int    zoneCount;
    int    lineCount;
    int    zonesRendered;
    int    linesRendered;
    bool   success;
    string errorMessage;
};

//+------------------------------------------------------------------+
//| STAGE 1: Calculate all level prices                              |
//|                                                                  |
//| Mode-specific: each mode provides its own price calculator.      |
//| This function handles uniform step (TH, TP, Combo, M, MEq, Factor) |
//| For SSLS, use CalculateLevelsAlternating.                       |
//| For Harmonic, use CalculateLevelsHarmonic.                      |
//|                                                                  |
//| KEY PRINCIPLE: ALL levels are calculated, even filtered ones.    |
//| Filtering is marked via `included` flag, NOT by skipping.       |
//+------------------------------------------------------------------+
int CalculateLevelsUniform(
    const double midpointPrice,
    const double stepSize,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool useStepFilter,
    const bool triggerEnabled,
    const bool structureEnabled,
    const int baseMultiplier,
    const bool boundByHistorical,
    const double maxPrice,
    const double minPrice,
    SCalculatedLevel &levels[])
{
    if(midpointPrice <= 0 || stepSize <= 0) return 0;
    
    int safeMaxAbove = MathMin(maxLevelsAbove, MAX_SAFE_LEVELS);
    int safeMaxBelow = MathMin(maxLevelsBelow, MAX_SAFE_LEVELS);
    if(safeMaxAbove < 1) safeMaxAbove = 1;
    if(safeMaxBelow < 1) safeMaxBelow = 1;
    
    // Worst case: all steps included + midpoint
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal);
    int count = 0;
    
    // Midpoint (always included, always first)
    levels[count].price = midpointPrice;
    levels[count].logicalStep = 0;
    levels[count].included = true;
    levels[count].isMidpoint = true;
    levels[count].direction = 0;
    count++;
    
    // Above levels
    int drawnAbove = 0;
    int logicalStep = 1;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;
    
    while(drawnAbove < safeMaxAbove && iterations < maxIterations) {
        iterations++;
        double price = midpointPrice + (stepSize * logicalStep);
        
        // Price boundary check
        if(boundByHistorical && maxPrice > 0 && price > maxPrice) break;
        
        // BASE PLAYER: All steps are always included.
        // Base Player = base multiplier defines N equal divisions between structural levels.
        // Every step contributes to the subdivision grid.
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        if(included) drawnAbove++;
        logicalStep++;
    }
    
    // Below levels
    int drawnBelow = 0;
    logicalStep = 1;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;
    
    while(drawnBelow < safeMaxBelow && iterations < maxIterations) {
        iterations++;
        double price = midpointPrice - (stepSize * logicalStep);
        
        // Price boundary check
        if(boundByHistorical && minPrice > 0 && price < minPrice) break;
        if(price <= 0) break;
        
        // BASE PLAYER: All steps always included (same as above direction)
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        if(included) drawnBelow++;
        logicalStep++;
    }
    
    ArrayResize(levels, count);
    return count;
}

//+------------------------------------------------------------------+
//| STAGE 1 VARIANT: Alternating step sizes (SSLS mode)              |
//+------------------------------------------------------------------+
int CalculateLevelsAlternating(
    const double midpointPrice,
    const double step1,        // First step size (SS or LS depending on lsFirst)
    const double step2,        // Second step size
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool triggerEnabled,
    const bool structureEnabled,
    const int baseMultiplier,
    const bool boundByHistorical,
    const double maxPrice,
    const double minPrice,
    SCalculatedLevel &levels[])
{
    if(midpointPrice <= 0 || step1 <= 0 || step2 <= 0) return 0;
    
    int safeMaxAbove = MathMin(maxLevelsAbove, MAX_SAFE_LEVELS);
    int safeMaxBelow = MathMin(maxLevelsBelow, MAX_SAFE_LEVELS);
    if(safeMaxAbove < 1) safeMaxAbove = 1;
    if(safeMaxBelow < 1) safeMaxBelow = 1;
    
    double stepDistances[2];
    stepDistances[0] = step1;
    stepDistances[1] = step2;
    
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal);
    int count = 0;
    
    // Midpoint
    levels[count].price = midpointPrice;
    levels[count].logicalStep = 0;
    levels[count].included = true;
    levels[count].isMidpoint = true;
    levels[count].direction = 0;
    count++;
    
    // Above
    int drawnAbove = 0;
    int logicalStep = 0;
    double cumulative = 0;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;
    
    while(drawnAbove < safeMaxAbove && iterations < maxIterations) {
        iterations++;
        double dist = stepDistances[logicalStep % 2];
        cumulative += dist;
        logicalStep++;
        double price = midpointPrice + cumulative;
        
        if(boundByHistorical && maxPrice > 0 && price > maxPrice) break;
        
        // BASE PLAYER: All steps always included
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        if(included) drawnAbove++;
    }
    
    // Below
    int drawnBelow = 0;
    logicalStep = 0;
    cumulative = 0;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;
    
    while(drawnBelow < safeMaxBelow && iterations < maxIterations) {
        iterations++;
        double dist = stepDistances[logicalStep % 2];
        cumulative += dist;
        logicalStep++;
        double price = midpointPrice - cumulative;
        
        if(boundByHistorical && minPrice > 0 && price < minPrice) break;
        if(price <= 0) break;
        
        // BASE PLAYER: All steps always included
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        if(included) drawnBelow++;
    }
    
    ArrayResize(levels, count);
    return count;
}

//+------------------------------------------------------------------+
//| STAGE 1 VARIANT: Harmonic alternating steps (Factor Harmonic)    |
//+------------------------------------------------------------------+
int CalculateLevelsHarmonic(
    const double centerPrice,
    const double baseStepSize,
    const double harmonicRatio,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool triggerEnabled,
    const bool structureEnabled,
    const int baseMultiplier,
    SCalculatedLevel &levels[])
{
    if(centerPrice <= 0 || baseStepSize <= 0 || harmonicRatio <= 0) return 0;
    
    double largeStepSize = baseStepSize * harmonicRatio;
    int safeMaxAbove = MathMin(maxLevelsAbove, MAX_SAFE_LEVELS);
    int safeMaxBelow = MathMin(maxLevelsBelow, MAX_SAFE_LEVELS);
    
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal);
    int count = 0;
    
    // Center
    levels[count].price = centerPrice;
    levels[count].logicalStep = 0;
    levels[count].included = true;
    levels[count].isMidpoint = true;
    levels[count].direction = 0;
    count++;
    
    // Above — alternating base/large steps, cumulative
    int drawnAbove = 0;
    double cumAbove = 0;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;
    int logicalStep = 1;
    
    while(drawnAbove < safeMaxAbove && iterations < maxIterations) {
        iterations++;
        double step = ((logicalStep - 1) % 2 == 0) ? baseStepSize : largeStepSize;
        cumAbove += step;
        double price = centerPrice + cumAbove;
        
        // BASE PLAYER: All steps always included
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        if(included) drawnAbove++;
        logicalStep++;
    }
    
    // Below
    int drawnBelow = 0;
    double cumBelow = 0;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;
    logicalStep = 1;
    
    while(drawnBelow < safeMaxBelow && iterations < maxIterations) {
        iterations++;
        double step = ((logicalStep - 1) % 2 == 0) ? baseStepSize : largeStepSize;
        cumBelow += step;
        double price = centerPrice - cumBelow;
        
        if(price <= 0) break;
        
        // BASE PLAYER: All steps always included
        bool included = true;
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].included = included;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        if(included) drawnBelow++;
        logicalStep++;
    }
    
    ArrayResize(levels, count);
    return count;
}

//+------------------------------------------------------------------+
//| STAGE 2: Classify all levels                                     |
//|                                                                  |
//| Assigns color/style/width based on structure/trigger priority.   |
//| Uses GetPathForLevelOptimized for consistency.                   |
//| Only classifies INCLUDED levels (others stay default).           |
//+------------------------------------------------------------------+
int ClassifyLevels(
    const SCalculatedLevel &rawLevels[],
    const int rawCount,
    const SModeConfig &config,
    const bool triggerEnabled,
    const int baseMultiplier,
    SLevelClassified &classified[])
{
    ArrayResize(classified, rawCount);
    EnsureIntervalsCache(baseMultiplier);
    
    for(int i = 0; i < rawCount; i++) {
        // Copy base data
        classified[i].price = rawLevels[i].price;
        classified[i].logicalStep = rawLevels[i].logicalStep;
        classified[i].included = rawLevels[i].included;
        classified[i].isMidpoint = rawLevels[i].isMidpoint;
        classified[i].direction = rawLevels[i].direction;
        
        // Default classification
        classified[i].structureLevel = 0;
        classified[i].isTrigger = false;
        classified[i].isStructure = false;
        classified[i].levelColor = config.fallbackColor;
        classified[i].levelStyle = config.fallbackStyle;
        classified[i].levelWidth = config.fallbackWidth;
        classified[i].zoneColor = clrNONE;
        classified[i].tooltip = "";
        
        if(!rawLevels[i].included && !rawLevels[i].isMidpoint) continue;
        
        int step = rawLevels[i].logicalStep;
        
        // Midpoint classification
        if(rawLevels[i].isMidpoint) {
            color mc; ENUM_LINE_STYLE ms; int mw;
            if(GetPathForLevelOptimized(0, mc, ms, mw, triggerEnabled)) {
                classified[i].levelColor = mc;
                classified[i].levelStyle = ms;
                classified[i].levelWidth = mw;
            } else {
                classified[i].levelColor = config.midpointColor;
                classified[i].levelStyle = config.midpointStyle;
                classified[i].levelWidth = config.midpointWidth;
            }
            classified[i].tooltip = "Midpoint (Start) - " + 
                DoubleToString(rawLevels[i].price, GetCachedDigits());
            continue;
        }
        
        // BASE PLAYER: Structure/Trigger classification
        // Every step is classified as either structural or trigger subdivision.
        // Structural: step divisible by L1..L5 intervals → structure color/style
        // Trigger subdivision: steps between structural levels → trigger or fallback color/style
        // With base=4: steps 4,8,12.. = structural L1, steps between = trigger subdivisions
        // This ensures exactly (base) equal zones between each pair of structural levels.
        
        classified[i].structureLevel = GetHighestStructureLevel(step, g_cachedIntervals);
        classified[i].isStructure = (classified[i].structureLevel > 0);
        
        if(classified[i].isStructure) {
            // Structural level — get styling from GetPathForLevelOptimized
            color outColor; ENUM_LINE_STYLE outStyle; int outWidth;
            if(GetPathForLevelOptimized(step, outColor, outStyle, outWidth, triggerEnabled)) {
                classified[i].levelColor = outColor;
                classified[i].levelStyle = outStyle;
                classified[i].levelWidth = outWidth;
            }
        } else {
            // Trigger subdivision — between structural levels
            classified[i].isTrigger = true;
            if(triggerEnabled) {
                // User has trigger styling enabled — use trigger colors
                classified[i].levelColor = inpTriggerColor;
                classified[i].levelStyle = inpTriggerStyle;
                classified[i].levelWidth = inpTriggerWidth;
            } else {
                // Trigger styling disabled — use mode fallback colors
                classified[i].levelColor = config.fallbackColor;
                classified[i].levelStyle = config.fallbackStyle;
                classified[i].levelWidth = config.fallbackWidth;
            }
        }
        
        // Zone color from level
        classified[i].zoneColor = GetZoneColorForLevel(step, triggerEnabled, baseMultiplier);
        if(classified[i].zoneColor == clrNONE) {
            classified[i].zoneColor = classified[i].levelColor;
        }
        
        // Default tooltip
        string dirStr = (rawLevels[i].direction > 0) ? "+" : "-";
        classified[i].tooltip = "Level " + dirStr + IntegerToString(step) + 
            " (" + DoubleToString(rawLevels[i].price, GetCachedDigits()) + ")";
    }
    
    return rawCount;
}

//+------------------------------------------------------------------+
//| STAGE 2 VARIANT: Classify with alternating fallback (SSLS)       |
//|                                                                  |
//| Same as ClassifyLevels but uses alternating SS/LS fallback       |
//| based on odd/even step and lsFirst flag.                         |
//+------------------------------------------------------------------+
int ClassifyLevelsAlternating(
    const SCalculatedLevel &rawLevels[],
    const int rawCount,
    const SModeConfig &config,
    const bool triggerEnabled,
    const int baseMultiplier,
    const bool lsFirst,
    SLevelClassified &classified[])
{
    // Start with standard classification
    int result = ClassifyLevels(rawLevels, rawCount, config, triggerEnabled, baseMultiplier, classified);
    
    // Override fallback colors for non-structure, non-trigger levels
    for(int i = 0; i < result; i++) {
        if(classified[i].isMidpoint || !classified[i].included) continue;
        if(classified[i].isStructure || classified[i].isTrigger) continue;
        
        // SSLS alternating: determine if this step is SS or LS
        bool isSS = ((classified[i].logicalStep % 2 == 0) == lsFirst);
        if(isSS) {
            classified[i].levelColor = config.fallbackColor;
            classified[i].levelStyle = config.fallbackStyle;
            classified[i].levelWidth = config.fallbackWidth;
        } else {
            classified[i].levelColor = config.fallbackColor2;
            classified[i].levelStyle = config.fallbackStyle2;
            classified[i].levelWidth = config.fallbackWidth2;
        }
        
        // Update tooltip
        string typeStr = isSS ? "SS " : "LS ";
        classified[i].tooltip = typeStr + IntegerToString(classified[i].logicalStep) + 
            " (" + DoubleToString(classified[i].price, GetCachedDigits()) + ")";
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| STAGE 2 VARIANT: Classify for M mode (C vs M distinction)       |
//+------------------------------------------------------------------+
int ClassifyLevelsMMode(
    const SCalculatedLevel &rawLevels[],
    const int rawCount,
    const SModeConfig &config,
    const bool triggerEnabled,
    const int baseMultiplier,
    SLevelClassified &classified[])
{
    int result = ClassifyLevels(rawLevels, rawCount, config, triggerEnabled, baseMultiplier, classified);
    
    for(int i = 0; i < result; i++) {
        if(classified[i].isMidpoint || !classified[i].included) continue;
        if(classified[i].isStructure || classified[i].isTrigger) continue;
        
        // M mode: every 3rd step is M level, others are C levels
        bool isM = (classified[i].logicalStep % 3 == 0);
        if(isM) {
            classified[i].levelColor = inpMLevelColor;
            classified[i].levelStyle = inpMLevelStyle;
            classified[i].levelWidth = inpMLevelWidth;
        } else {
            classified[i].levelColor = inpCLevelColor;
            classified[i].levelStyle = inpCLevelStyle;
            classified[i].levelWidth = inpCLevelWidth;
        }
        
        classified[i].tooltip = (isM ? "M " : "C ") + IntegerToString(classified[i].logicalStep) + 
            " (" + DoubleToString(classified[i].price, GetCachedDigits()) + ")";
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| STAGE 3: Build zones from classified levels (ZONE-FIRST)         |
//|                                                                  |
//| KEY ALGORITHM:                                                   |
//| 1. Collect all INCLUDED levels sorted by direction               |
//| 2. For each direction (above/below), pair consecutive levels     |
//| 3. Each pair defines one zone                                    |
//| 4. Zone color = color of the level that forms the boundary       |
//|    farther from midpoint (the "outer" boundary)                  |
//|                                                                  |
//| VIEWPORT INDEPENDENCE:                                           |
//| Viewport is checked here but only sets `inViewport` flag.        |
//| Zone GEOMETRY is always correct regardless of viewport.          |
//+------------------------------------------------------------------+
int BuildZones(
    const SLevelClassified &classified[],
    const int classifiedCount,
    const SModeConfig &config,
    const double vpTop,
    const double vpBottom,
    SZoneDefinition &zones[])
{
    if(!config.zonesEnabled) return 0;
    
    // Separate included levels by direction
    // Above: sorted by step ascending (closest to midpoint first)
    // Below: sorted by step ascending (closest to midpoint first)
    SLevelClassified aboveLevels[];
    SLevelClassified belowLevels[];
    SLevelClassified midLevel;
    bool hasMid = false;
    
    int aboveCount = 0, belowCount = 0;
    
    // First pass: count
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { hasMid = true; continue; }
        if(!classified[i].included) continue;
        if(classified[i].direction > 0) aboveCount++;
        else if(classified[i].direction < 0) belowCount++;
    }
    
    ArrayResize(aboveLevels, aboveCount);
    ArrayResize(belowLevels, belowCount);
    
    // Second pass: collect
    int ai = 0, bi = 0;
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { midLevel = classified[i]; continue; }
        if(!classified[i].included) continue;
        if(classified[i].direction > 0 && ai < aboveCount) { aboveLevels[ai] = classified[i]; ai++; }
        else if(classified[i].direction < 0 && bi < belowCount) { belowLevels[bi] = classified[i]; bi++; }
    }
    
    // Sort by logicalStep ascending (they should already be, but ensure)
    // Above: step 3, 6, 9, ... → zone between (mid,3), (3,6), (6,9)
    // Below: step 3, 6, 9, ... → zone between (mid,3), (3,6), (6,9) 
    
    int maxZones = aboveCount + belowCount;
    ArrayResize(zones, maxZones);
    int zoneIdx = 0;
    
    // Build zones ABOVE midpoint
    double prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < aboveCount && prevPrice > 0; i++) {
        double currentPrice = aboveLevels[i].price;
        if(currentPrice <= prevPrice) { prevPrice = currentPrice; continue; }
        
        double stepSize = currentPrice - prevPrice;
        double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
        double mid = (prevPrice + currentPrice) / 2.0;
        
        zones[zoneIdx].name = config.objectPrefix + config.modeName + "_Zone_Above_" + 
                              IntegerToString(aboveLevels[i].logicalStep);
        zones[zoneIdx].upperBoundary = currentPrice;
        zones[zoneIdx].lowerBoundary = prevPrice;
        zones[zoneIdx].midPrice = mid;
        zones[zoneIdx].height = zoneHeight * 2;
        zones[zoneIdx].renderTop = NormalizeDouble(mid + zoneHeight, GetCachedDigits());
        zones[zoneIdx].renderBottom = NormalizeDouble(mid - zoneHeight, GetCachedDigits());
        zones[zoneIdx].upperStep = aboveLevels[i].logicalStep;
        zones[zoneIdx].lowerStep = (i == 0) ? 0 : aboveLevels[i-1].logicalStep;
        zones[zoneIdx].direction = 1;
        zones[zoneIdx].zoneIndex = i;
        zones[zoneIdx].isStructure = aboveLevels[i].isStructure;
        zones[zoneIdx].isTrigger = aboveLevels[i].isTrigger;
        zones[zoneIdx].zoneColor = (aboveLevels[i].zoneColor != clrNONE) ? 
                                    aboveLevels[i].zoneColor : config.zoneDefaultColor;
        zones[zoneIdx].transparency = config.zoneTransparency;
        zones[zoneIdx].style = config.zoneStyle;
        zones[zoneIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
        zones[zoneIdx].inViewport = (zones[zoneIdx].renderTop >= vpBottom && 
                                     zones[zoneIdx].renderBottom <= vpTop);
        zoneIdx++;
        
        prevPrice = currentPrice;
    }
    
    // Build zones BELOW midpoint
    prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < belowCount && prevPrice > 0; i++) {
        double currentPrice = belowLevels[i].price;
        if(currentPrice >= prevPrice || currentPrice <= 0) { prevPrice = currentPrice; continue; }
        
        double stepSize = prevPrice - currentPrice;
        double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
        double mid = (prevPrice + currentPrice) / 2.0;
        
        zones[zoneIdx].name = config.objectPrefix + config.modeName + "_Zone_Below_" + 
                              IntegerToString(belowLevels[i].logicalStep);
        zones[zoneIdx].upperBoundary = prevPrice;
        zones[zoneIdx].lowerBoundary = currentPrice;
        zones[zoneIdx].midPrice = mid;
        zones[zoneIdx].height = zoneHeight * 2;
        zones[zoneIdx].renderTop = NormalizeDouble(mid + zoneHeight, GetCachedDigits());
        zones[zoneIdx].renderBottom = NormalizeDouble(mid - zoneHeight, GetCachedDigits());
        zones[zoneIdx].upperStep = (i == 0) ? 0 : belowLevels[i-1].logicalStep;
        zones[zoneIdx].lowerStep = belowLevels[i].logicalStep;
        zones[zoneIdx].direction = -1;
        zones[zoneIdx].zoneIndex = i;
        zones[zoneIdx].isStructure = belowLevels[i].isStructure;
        zones[zoneIdx].isTrigger = belowLevels[i].isTrigger;
        zones[zoneIdx].zoneColor = (belowLevels[i].zoneColor != clrNONE) ? 
                                    belowLevels[i].zoneColor : config.zoneDefaultColor;
        zones[zoneIdx].transparency = config.zoneTransparency;
        zones[zoneIdx].style = config.zoneStyle;
        zones[zoneIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
        zones[zoneIdx].inViewport = (zones[zoneIdx].renderTop >= vpBottom && 
                                     zones[zoneIdx].renderBottom <= vpTop);
        zoneIdx++;
        
        prevPrice = currentPrice;
    }
    
    ArrayResize(zones, zoneIdx);
    return zoneIdx;
}

//+------------------------------------------------------------------+
//| STAGE 4: Derive trigger lines from zone boundaries               |
//|                                                                  |
//| Each line sits at a zone boundary. Adjacent zones share the      |
//| boundary — the line appears once with the dominant zone's style. |
//|                                                                  |
//| PRINCIPLE: Line = edge of zone. No zone = no line.               |
//| Exception: midpoint line is always drawn.                        |
//+------------------------------------------------------------------+
int DeriveTriggerLines(
    const SLevelClassified &classified[],
    const int classifiedCount,
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config,
    const double vpTop,
    const double vpBottom,
    STriggerLine &lines[])
{
    // Lines come from classified levels that are included
    // Each included level is a zone boundary
    
    // Count included levels
    int includedCount = 0;
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].included) includedCount++;
    }
    
    ArrayResize(lines, includedCount);
    int lineIdx = 0;
    
    for(int i = 0; i < classifiedCount; i++) {
        if(!classified[i].included) continue;
        
        string suffix;
        if(classified[i].isMidpoint) {
            suffix = config.modeName + "_Midpoint_0";
        } else if(classified[i].direction > 0) {
            suffix = config.modeName + "_Above_" + IntegerToString(classified[i].logicalStep);
        } else {
            suffix = config.modeName + "_Below_" + IntegerToString(classified[i].logicalStep);
        }
        
        lines[lineIdx].name = config.objectPrefix + suffix;
        lines[lineIdx].price = classified[i].price;
        lines[lineIdx].logicalStep = classified[i].logicalStep;
        lines[lineIdx].direction = classified[i].direction;
        lines[lineIdx].lineColor = classified[i].levelColor;
        lines[lineIdx].lineStyle = classified[i].levelStyle;
        lines[lineIdx].lineWidth = classified[i].levelWidth;
        lines[lineIdx].tooltip = classified[i].tooltip;
        lines[lineIdx].isMidpoint = classified[i].isMidpoint;
        lines[lineIdx].setBack = config.useObjPropBack;
        lines[lineIdx].zOrder = config.zOrder;
        
        // Find adjacent zones
        lines[lineIdx].zoneAboveIdx = -1;
        lines[lineIdx].zoneBelowIdx = -1;
        for(int z = 0; z < zoneCount; z++) {
            if(MathAbs(zones[z].lowerBoundary - classified[i].price) < GetCachedPoint() * 0.5) {
                lines[lineIdx].zoneAboveIdx = z;
            }
            if(MathAbs(zones[z].upperBoundary - classified[i].price) < GetCachedPoint() * 0.5) {
                lines[lineIdx].zoneBelowIdx = z;
            }
        }
        
        // Viewport check
        lines[lineIdx].inViewport = (classified[i].price >= vpBottom && classified[i].price <= vpTop);
        
        lineIdx++;
    }
    
    ArrayResize(lines, lineIdx);
    return lineIdx;
}

//+------------------------------------------------------------------+
//| STAGE 5a: Render zones (FIRST — zones are primary)               |
//|                                                                  |
//| Creates/updates MT5 rectangle objects for each zone.             |
//| Handles all zone styles: Lines, Filled Box, Empty Box, Hidden.   |
//+------------------------------------------------------------------+
int RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config)
{
    int rendered = 0;
    
    for(int i = 0; i < zoneCount; i++) {
        if(config.zoneStyle == ZONE_STYLE_HIDDEN) {
            // Hidden: delete existing zone objects
            if(ObjectFind(0, zones[i].name) >= 0) {
                CacheRemoveObject(zones[i].name);
                ObjectDelete(0, zones[i].name);
            }
            continue;
        }
        
        if(!zones[i].inViewport) continue;
        
        if(zones[i].renderTop <= zones[i].renderBottom) continue;
        
        if(config.zoneStyle == ZONE_STYLE_LINES) {
            // Lines style: two horizontal lines for zone boundaries
            if(CreateFactorMidZone_LinesStyle(zones[i].name, 
                                               zones[i].renderTop, zones[i].renderBottom,
                                               zones[i].zoneColor, zones[i].transparency)) {
                rendered++;
            }
        } else {
            // Box style (filled or empty)
            SZoneCreationRequest request;
            request.name = zones[i].name;
            request.topPrice = zones[i].renderTop;
            request.bottomPrice = zones[i].renderBottom;
            request.zoneColor = zones[i].zoneColor;
            request.transparency = zones[i].transparency;
            request.filled = zones[i].filled;
            request.startTime = 0;
            request.endTime = 0;
            
            SZoneCreationResult result = CreateZone(request);
            if(result.success) rendered++;
        }
    }
    
    return rendered;
}

//+------------------------------------------------------------------+
//| STAGE 5b: Render trigger lines (SECOND — derived from zones)     |
//|                                                                  |
//| Creates/updates MT5 horizontal line objects.                     |
//| Uses CreateOrUpdateHLine for consistency.                        |
//+------------------------------------------------------------------+
int RenderTriggerLines(
    const STriggerLine &lines[],
    const int lineCount,
    const SModeConfig &config)
{
    int rendered = 0;
    
    for(int i = 0; i < lineCount; i++) {
        // Factor mode: hide lines when trigger-only enabled
        if(config.hideLineWhenTriggerOnly && !lines[i].isMidpoint) {
            bool shouldShow = !IsTriggerLevelsEnabled();
            if(!shouldShow) {
                if(ObjectFind(0, lines[i].name) >= 0) {
                    ObjectSetInteger(0, lines[i].name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                }
                continue;
            }
        }
        
        if(!lines[i].inViewport) continue;
        
        // Use the unified create-or-update pattern
        bool isNew = CreateOrUpdateHLine(lines[i].name, lines[i].price,
                                          lines[i].lineColor, lines[i].lineStyle, lines[i].lineWidth,
                                          lines[i].tooltip);
        
        // Set mode-specific properties on new objects
        if(isNew) {
            if(config.useObjPropBack) {
                ObjectSetInteger(0, lines[i].name, OBJPROP_BACK, false);
            }
            if(config.zOrder > 0) {
                ObjectSetInteger(0, lines[i].name, OBJPROP_ZORDER, config.zOrder);
            }
        }
        
        rendered++;
    }
    
    return rendered;
}

//+------------------------------------------------------------------+
//| STAGE 5c: Cleanup surplus objects from previous render           |
//|                                                                  |
//| Removes zone and line objects that no longer exist in current    |
//| pipeline output. Uses the mode name for prefix matching.         |
//+------------------------------------------------------------------+
void CleanupSurplusPipeline(
    const SModeConfig &config,
    const SZoneDefinition &zones[],
    const int zoneCount,
    const STriggerLine &lines[],
    const int lineCount,
    const int maxLogicalStep)
{
    if(g_customPriceLineDragging) return;
    
    // Cleanup surplus zones
    if(config.zonesEnabled) {
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Above_", maxLogicalStep + 1);
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Below_", maxLogicalStep + 1);
    }
    
    // Cleanup surplus lines (above and below direction)
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Above_", maxLogicalStep + 1);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Below_", maxLogicalStep + 1);
}

//+------------------------------------------------------------------+
//| BUILD MODE CONFIG: Create config from current input parameters   |
//+------------------------------------------------------------------+
SModeConfig BuildModeConfig(const string objectPrefix, const string modeName)
{
    SModeConfig cfg;
    cfg.modeName = modeName;
    cfg.objectPrefix = objectPrefix;
    
    // Read zone settings from unified zone config
    SUnifiedZoneConfig zoneConfig = GetUnifiedZoneConfig();
    cfg.zonesEnabled = zoneConfig.enabled;
    cfg.zoneTransparency = zoneConfig.transparency;
    cfg.zoneHeightPercent = zoneConfig.heightPercent;
    cfg.zoneDefaultColor = zoneConfig.defaultColor;
    cfg.zoneStyle = zoneConfig.style;
    
    // Default rendering flags
    cfg.useObjPropBack = false;
    cfg.zOrder = 0;
    cfg.hideLineWhenTriggerOnly = false;
    cfg.useSimpleZones = false;
    cfg.useStepFilter = true;
    cfg.hasAlternatingFallback = false;
    
    // Defaults for fallback colors (overridden per mode)
    cfg.fallbackColor = inpCLevelColor;
    cfg.fallbackStyle = inpCLevelStyle;
    cfg.fallbackWidth = inpCLevelWidth;
    cfg.fallbackColor2 = inpCLevelColor;
    cfg.fallbackStyle2 = inpCLevelStyle;
    cfg.fallbackWidth2 = inpCLevelWidth;
    cfg.midpointColor = inpCLevelColor;
    cfg.midpointStyle = inpCLevelStyle;
    cfg.midpointWidth = inpCLevelWidth;
    
    // Price boundaries
    bool isCustomPrice = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE);
    cfg.boundByHistorical = !isCustomPrice;
    cfg.maxPrice = isCustomPrice ? 0 : g_highestHigh;
    cfg.minPrice = isCustomPrice ? 0 : g_lowestLow;
    
    return cfg;
}

SModeConfig BuildSSLSConfig(const string objectPrefix)
{
    SModeConfig cfg = BuildModeConfig(objectPrefix, "SSLS");
    cfg.hasAlternatingFallback = true;
    cfg.fallbackColor = inpSSLevelColor;
    cfg.fallbackStyle = inpSSLevelStyle;
    cfg.fallbackWidth = inpSSLevelWidth;
    cfg.fallbackColor2 = inpLSLevelColor;
    cfg.fallbackStyle2 = inpLSLevelStyle;
    cfg.fallbackWidth2 = inpLSLevelWidth;
    cfg.midpointColor = inpLSLevelColor;
    cfg.midpointStyle = inpLSLevelStyle;
    cfg.midpointWidth = inpLSLevelWidth;
    return cfg;
}

SModeConfig BuildMConfig(const string objectPrefix)
{
    SModeConfig cfg = BuildModeConfig(objectPrefix, "M");
    cfg.midpointColor = inpMLevelColor;
    cfg.midpointStyle = inpMLevelStyle;
    cfg.midpointWidth = inpMLevelWidth;
    return cfg;
}

SModeConfig BuildMEqualConfig(const string objectPrefix)
{
    SModeConfig cfg = BuildModeConfig(objectPrefix, "MEq");
    cfg.useStepFilter = false;
    cfg.useSimpleZones = true;
    cfg.midpointColor = inpMLevelColor;
    cfg.midpointStyle = inpMLevelStyle;
    cfg.midpointWidth = inpMLevelWidth;
    cfg.fallbackColor = inpStructureL1Color;
    cfg.fallbackStyle = inpStructureL1Style;
    cfg.fallbackWidth = inpStructureL1Width;
    return cfg;
}

SModeConfig BuildTPConfig(const string objectPrefix)
{
    return BuildModeConfig(objectPrefix, "TP");
}

SModeConfig BuildComboConfig(const string objectPrefix)
{
    return BuildModeConfig(objectPrefix, "Combo");
}

SModeConfig BuildFactorConfig(const string objectPrefix)
{
    SModeConfig cfg = BuildModeConfig(objectPrefix, "Factor");
    cfg.useObjPropBack = true;
    cfg.zOrder = 1;
    cfg.hideLineWhenTriggerOnly = true;
    cfg.fallbackColor = inpFactorLevelColor;
    cfg.fallbackStyle = inpFactorLevelStyle;
    cfg.fallbackWidth = inpFactorLevelWidth;
    cfg.midpointColor = inpFactorLevelColor;
    cfg.midpointStyle = inpFactorLevelStyle;
    cfg.midpointWidth = inpFactorLevelWidth;
    return cfg;
}

SModeConfig BuildFactorHarmonicConfig(const string objectPrefix)
{
    SModeConfig cfg = BuildModeConfig(objectPrefix, "Factor_Harmonic");
    cfg.useObjPropBack = true;
    cfg.hideLineWhenTriggerOnly = true;
    cfg.fallbackColor = inpFactorLevelColor;
    cfg.fallbackStyle = inpFactorLevelStyle;
    cfg.fallbackWidth = inpFactorLevelWidth;
    cfg.midpointColor = inpFactorLevelColor;
    cfg.midpointStyle = inpFactorLevelStyle;
    cfg.midpointWidth = inpFactorLevelWidth;
    return cfg;
}

//+------------------------------------------------------------------+
//| UNIFIED PIPELINE EXECUTOR                                        |
//|                                                                  |
//| Runs all 5 stages in order:                                      |
//|   1. Calculate → 2. Classify → 3. BuildZones → 4. DeriveTriggers |
//|   5a. RenderZones (FIRST) → 5b. RenderLines → 5c. Cleanup       |
//|                                                                  |
//| This replaces ALL individual Draw*Levels functions.              |
//+------------------------------------------------------------------+

// Execute pipeline for uniform step modes (TH, TP, Combo, M, MEq, Factor)
SPipelineResult ExecuteUniformPipeline(
    const SModeConfig &config,
    const double midpointPrice,
    const double stepSize,
    const int maxLevelsAbove,
    const int maxLevelsBelow)
{
    SPipelineResult result;
    result.zoneCount = 0;
    result.lineCount = 0;
    result.zonesRendered = 0;
    result.linesRendered = 0;
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || stepSize <= 0) {
        result.errorMessage = "Invalid midpoint or step size";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    
    // Viewport
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1: Calculate
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsUniform(midpointPrice, stepSize,
                                           maxLevelsAbove, maxLevelsBelow,
                                           config.useStepFilter,
                                           triggerEnabled, structureEnabled, baseMultiplier,
                                           config.boundByHistorical, config.maxPrice, config.minPrice,
                                           rawLevels);
    if(rawCount == 0) {
        result.errorMessage = "No levels calculated";
        return result;
    }
    
    // Stage 2: Classify
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevels(rawLevels, rawCount, config, 
                                          triggerEnabled, baseMultiplier, classified);
    
    // Stage 3: Build zones (FIRST — primary entity)
    SZoneDefinition zones[];
    result.zoneCount = BuildZones(classified, classifiedCount, config, vpTop, vpBottom, zones);
    
    // Stage 4: Derive trigger lines (from zone boundaries)
    STriggerLine lines[];
    result.lineCount = DeriveTriggerLines(classified, classifiedCount, zones, result.zoneCount,
                                           config, vpTop, vpBottom, lines);
    
    // Stage 5a: Render ZONES first
    result.zonesRendered = RenderZones(zones, result.zoneCount, config);
    
    // Stage 5b: Render LINES second (derived from zones)
    result.linesRendered = RenderTriggerLines(lines, result.lineCount, config);
    
    // Stage 5c: Cleanup surplus
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, zones, result.zoneCount, lines, result.lineCount, maxStep);
    
    result.success = true;
    return result;
}

// Execute pipeline for SSLS mode (alternating steps)
SPipelineResult ExecuteSSLSPipeline(
    const SModeConfig &config,
    const double midpointPrice,
    const double ssValue,
    const double lsValue,
    const bool lsFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow)
{
    SPipelineResult result;
    result.zoneCount = 0;
    result.lineCount = 0;
    result.zonesRendered = 0;
    result.linesRendered = 0;
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || ssValue <= 0 || lsValue <= 0) {
        result.errorMessage = "Invalid SSLS parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Determine step order
    double step1 = lsFirst ? lsValue : ssValue;
    double step2 = lsFirst ? ssValue : lsValue;
    
    // Stage 1
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsAlternating(midpointPrice, step1, step2,
                                               maxLevelsAbove, maxLevelsBelow,
                                               triggerEnabled, structureEnabled, baseMultiplier,
                                               config.boundByHistorical, config.maxPrice, config.minPrice,
                                               rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2: Classify with alternating fallback
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevelsAlternating(rawLevels, rawCount, config,
                                                     triggerEnabled, baseMultiplier, lsFirst,
                                                     classified);
    
    // Stage 3
    SZoneDefinition zones[];
    result.zoneCount = BuildZones(classified, classifiedCount, config, vpTop, vpBottom, zones);
    
    // Stage 4
    STriggerLine lines[];
    result.lineCount = DeriveTriggerLines(classified, classifiedCount, zones, result.zoneCount,
                                           config, vpTop, vpBottom, lines);
    
    // Stage 5
    result.zonesRendered = RenderZones(zones, result.zoneCount, config);
    result.linesRendered = RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, zones, result.zoneCount, lines, result.lineCount, maxStep);
    
    result.success = true;
    return result;
}

// Execute pipeline for M mode (C-based with C/M distinction)
SPipelineResult ExecuteMLevelPipeline(
    const SModeConfig &config,
    const double midpointPrice,
    const double controlDistance,
    const int maxLevelsAbove,
    const int maxLevelsBelow)
{
    SPipelineResult result;
    result.zoneCount = 0;
    result.lineCount = 0;
    result.zonesRendered = 0;
    result.linesRendered = 0;
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || controlDistance <= 0) {
        result.errorMessage = "Invalid M mode parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsUniform(midpointPrice, controlDistance,
                                           maxLevelsAbove, maxLevelsBelow,
                                           config.useStepFilter,
                                           triggerEnabled, structureEnabled, baseMultiplier,
                                           config.boundByHistorical, config.maxPrice, config.minPrice,
                                           rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2: M mode classification
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevelsMMode(rawLevels, rawCount, config,
                                              triggerEnabled, baseMultiplier, classified);
    
    // Stage 3-5
    SZoneDefinition zones[];
    result.zoneCount = BuildZones(classified, classifiedCount, config, vpTop, vpBottom, zones);
    
    STriggerLine lines[];
    result.lineCount = DeriveTriggerLines(classified, classifiedCount, zones, result.zoneCount,
                                           config, vpTop, vpBottom, lines);
    
    result.zonesRendered = RenderZones(zones, result.zoneCount, config);
    result.linesRendered = RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, zones, result.zoneCount, lines, result.lineCount, maxStep);
    
    result.success = true;
    return result;
}

// Execute pipeline for Harmonic Factor mode
SPipelineResult ExecuteHarmonicPipeline(
    const SModeConfig &config,
    const double centerPrice,
    const double baseStepSize,
    const double harmonicRatio,
    const int maxLevelsAbove,
    const int maxLevelsBelow)
{
    SPipelineResult result;
    result.zoneCount = 0;
    result.lineCount = 0;
    result.zonesRendered = 0;
    result.linesRendered = 0;
    result.success = false;
    result.errorMessage = "";
    
    if(centerPrice <= 0 || baseStepSize <= 0 || harmonicRatio <= 0) {
        result.errorMessage = "Invalid harmonic parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsHarmonic(centerPrice, baseStepSize, harmonicRatio,
                                            maxLevelsAbove, maxLevelsBelow,
                                            triggerEnabled, structureEnabled, baseMultiplier,
                                            rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevels(rawLevels, rawCount, config,
                                          triggerEnabled, baseMultiplier, classified);
    
    // Stages 3-5
    SZoneDefinition zones[];
    result.zoneCount = BuildZones(classified, classifiedCount, config, vpTop, vpBottom, zones);
    
    STriggerLine lines[];
    result.lineCount = DeriveTriggerLines(classified, classifiedCount, zones, result.zoneCount,
                                           config, vpTop, vpBottom, lines);
    
    result.zonesRendered = RenderZones(zones, result.zoneCount, config);
    result.linesRendered = RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, zones, result.zoneCount, lines, result.lineCount, maxStep);
    
    result.success = true;
    return result;
}

//+------------------------------------------------------------------+
//| SUFFIX REGISTRY: Centralized suffix tracking                     |
//|                                                                  |
//| All mode suffixes registered in one place.                       |
//| Adding a new mode = add one entry here.                          |
//+------------------------------------------------------------------+
struct SModeSuffixEntry {
    string zoneSuffix;      // e.g., "SSLS_Zone_"
    string levelAbove;      // e.g., "SSLS_Above_"
    string levelBelow;      // e.g., "SSLS_Below_"
    string midpoint;        // e.g., "SSLS_Midpoint_"
};

// All registered mode suffixes — used by ClearAllLevels and DeleteAllIndicatorObjects
void GetAllModeSuffixes(SModeSuffixEntry &entries[], int &count)
{
    count = 8;
    ArrayResize(entries, count);
    
    // SSLS
    entries[0].zoneSuffix = "SSLS_Zone_";
    entries[0].levelAbove = "SSLS_Above_";
    entries[0].levelBelow = "SSLS_Below_";
    entries[0].midpoint = "SSLS_Midpoint_";
    
    // M (Control-based)
    entries[1].zoneSuffix = "M_Zone_";
    entries[1].levelAbove = "M_Above_";
    entries[1].levelBelow = "M_Below_";
    entries[1].midpoint = "M_Midpoint_";
    
    // MEq (Equal spacing)
    entries[2].zoneSuffix = "MEq_Zone_";
    entries[2].levelAbove = "MEq_Above_";
    entries[2].levelBelow = "MEq_Below_";
    entries[2].midpoint = "MEq_Midpoint_";
    
    // TP
    entries[3].zoneSuffix = "TP_Zone_";
    entries[3].levelAbove = "TP_Above_";
    entries[3].levelBelow = "TP_Below_";
    entries[3].midpoint = "TP_Midpoint_";
    
    // Combo
    entries[4].zoneSuffix = "Combo_Zone_";
    entries[4].levelAbove = "Combo_Above_";
    entries[4].levelBelow = "Combo_Below_";
    entries[4].midpoint = "Combo_Midpoint_";
    
    // Factor (Standard)
    entries[5].zoneSuffix = "Factor_Zone_";
    entries[5].levelAbove = "Factor_Above_";
    entries[5].levelBelow = "Factor_Below_";
    entries[5].midpoint = "Factor_Center";
    
    // Factor (Harmonic)
    entries[6].zoneSuffix = "Factor_Harmonic_Zone_";
    entries[6].levelAbove = "Factor_Harmonic_Above_";
    entries[6].levelBelow = "Factor_Harmonic_Below_";
    entries[6].midpoint = "Factor_Harmonic_Center";
    
    // TH (Traditional)
    entries[7].zoneSuffix = "TH_Level_Zone_";
    entries[7].levelAbove = "TH_Level_Above_";
    entries[7].levelBelow = "TH_Level_Below_";
    entries[7].midpoint = "TH_Level_Midpoint_";
}

// Get all zone suffixes as a flat array (for ClearAllLevels compatibility)
void GetAllZoneSuffixes(string &suffixes[], int &count)
{
    SModeSuffixEntry entries[];
    int entryCount = 0;
    GetAllModeSuffixes(entries, entryCount);
    
    count = entryCount;
    ArrayResize(suffixes, count);
    for(int i = 0; i < count; i++) {
        suffixes[i] = entries[i].zoneSuffix;
    }
}

// Get all level suffixes as a flat array (for ClearAllLevels compatibility)
void GetAllLevelSuffixes(string &suffixes[], int &count)
{
    SModeSuffixEntry entries[];
    int entryCount = 0;
    GetAllModeSuffixes(entries, entryCount);
    
    // Each mode has 3 level suffixes (above, below, midpoint)
    // Plus legacy suffixes for backward compatibility
    count = entryCount * 3;
    ArrayResize(suffixes, count);
    int idx = 0;
    for(int i = 0; i < entryCount; i++) {
        suffixes[idx++] = entries[i].levelAbove;
        suffixes[idx++] = entries[i].levelBelow;
        suffixes[idx++] = entries[i].midpoint;
    }
    count = idx;
}

#endif // LEVEL_PIPELINE_MQH
