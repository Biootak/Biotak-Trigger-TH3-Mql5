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
    bool   isMidpoint;      // true = this is the center/anchor level (step 0)
    int    direction;       // +1 = above midpoint, -1 = below, 0 = midpoint
};

//+------------------------------------------------------------------+
//| STAGE 2 OUTPUT: Classification result for a level                |
//+------------------------------------------------------------------+
struct SLevelClassified {
    double price;
    int    logicalStep;
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
};

//+------------------------------------------------------------------+
//| STAGE 3 OUTPUT: Zone definition (PRIMARY ENTITY)                 |
//|                                                                  |
//| Each zone is centered ON a level price.                          |
//| renderTop/renderBottom define actual visual extent.              |
//+------------------------------------------------------------------+
struct SZoneDefinition {
    string name;            // Object name for this zone
    double midPrice;        // Center price (= level price)
    double renderTop;       // Visual top (midPrice + zoneHeight)
    double renderBottom;    // Visual bottom (midPrice - zoneHeight)
    int    logicalStep;     // Step number of the level this zone sits on
    int    direction;       // +1 = above midpoint, -1 = below, 0 = midpoint
    int    zoneIndex;       // Sequential zone index in this direction
    bool   isStructure;     // Structural level zone
    bool   isTrigger;       // Trigger subdivision zone
    color  zoneColor;       // Zone color
    int    transparency;
    ENUM_ZONE_STYLE style;
    bool   filled;
    bool   inViewport;      // false = skip render, geometry is valid
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
//| KEY PRINCIPLE: ALL levels are calculated. Every step is always  |
//| included — there is no filtering/skipping.                      |
//+------------------------------------------------------------------+
int CalculateLevelsUniform(
    const double midpointPrice,
    const double stepSize,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool useStepFilter,
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
    
    // Worst case: all steps + midpoint
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal);
    int count = 0;
    
    // Midpoint (always first)
    levels[count].price = midpointPrice;
    levels[count].logicalStep = 0;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        drawnAbove++;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        drawnBelow++;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        drawnAbove++;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        drawnBelow++;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = 1;
        count++;
        
        drawnAbove++;
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
        
        levels[count].price = price;
        levels[count].logicalStep = logicalStep;
        levels[count].isMidpoint = false;
        levels[count].direction = -1;
        count++;
        
        drawnBelow++;
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
    
    // Override colors for non-structure, non-trigger levels with SS/LS alternating pattern
    for(int i = 0; i < result; i++) {
        if(classified[i].isMidpoint) continue;
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
        if(classified[i].isMidpoint) continue;
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
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| STAGE 3+4 (MERGED): Build zones AND derive midpoint lines        |
//|                                                                  |
//| Single pass over classified levels produces both zones and lines.|
//| Zone = centered ON each level price.                             |
//| Line = midpoint between consecutive zones (between-zone marker). |
//|                                                                  |
//| This eliminates the duplicate 2-pass iteration that existed      |
//| when BuildZones and DeriveTriggerLines were separate functions.  |
//|                                                                  |
//| With base multiplier N per structural interval:                  |
//|   Zones: N+1 (2 structure + N-1 trigger)                        |
//|   Lines: N (midpoint markers between zones)                     |
//|                                                                  |
//| EDGE CASE: If midpoint has no neighbors (aboveCount=0 AND       |
//| belowCount=0), we use a fallback zone height based on the       |
//| symbol's point value to prevent silent invisible midpoint.       |
//+------------------------------------------------------------------+
void BuildZonesAndLines(
    const SLevelClassified &classified[],
    const int classifiedCount,
    const SModeConfig &config,
    const double vpTop,
    const double vpBottom,
    SZoneDefinition &zones[],
    int &zoneCount,
    STriggerLine &lines[],
    int &lineCount)
{
    zoneCount = 0;
    lineCount = 0;
    
    // Separate levels by direction
    SLevelClassified aboveLevels[];
    SLevelClassified belowLevels[];
    SLevelClassified midLevel;
    midLevel.price = 0;
    midLevel.isMidpoint = false;
    bool hasMid = false;
    
    int aboveCount = 0, belowCount = 0;
    
    // First pass: count
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { hasMid = true; continue; }
        if(classified[i].direction > 0) aboveCount++;
        else if(classified[i].direction < 0) belowCount++;
    }
    
    ArrayResize(aboveLevels, aboveCount);
    ArrayResize(belowLevels, belowCount);
    
    // Second pass: collect
    int ai = 0, bi = 0;
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { midLevel = classified[i]; continue; }
        if(classified[i].direction > 0 && ai < aboveCount) { aboveLevels[ai] = classified[i]; ai++; }
        else if(classified[i].direction < 0 && bi < belowCount) { belowLevels[bi] = classified[i]; bi++; }
    }
    
    // Pre-allocate output arrays (max possible sizes)
    int maxZones = (hasMid ? 1 : 0) + aboveCount + belowCount;
    int maxLines = aboveCount + belowCount;
    if(config.zonesEnabled) ArrayResize(zones, maxZones);
    ArrayResize(lines, maxLines);
    
    int zIdx = 0, lIdx = 0;
    
    // --- MIDPOINT ZONE (step 0) ---
    if(hasMid && config.zonesEnabled) {
        double neighborDist = 0;
        if(aboveCount > 0) {
            neighborDist = aboveLevels[0].price - midLevel.price;
        } else if(belowCount > 0) {
            neighborDist = midLevel.price - belowLevels[0].price;
        }
        // Edge case fix: no neighbors → use 100 points as fallback height
        if(neighborDist <= 0) {
            neighborDist = GetCachedPoint() * 100;
        }
        double zoneHeight = neighborDist * config.zoneHeightPercent * 0.5;
        
        zones[zIdx].name = config.objectPrefix + config.modeName + "_Zone_Center_0";
        zones[zIdx].midPrice = midLevel.price;
        zones[zIdx].renderTop = NormalizeDouble(midLevel.price + zoneHeight, GetCachedDigits());
        zones[zIdx].renderBottom = NormalizeDouble(midLevel.price - zoneHeight, GetCachedDigits());
        zones[zIdx].logicalStep = 0;
        zones[zIdx].direction = 0;
        zones[zIdx].zoneIndex = 0;
        zones[zIdx].isStructure = true;
        zones[zIdx].isTrigger = false;
        zones[zIdx].zoneColor = config.zoneDefaultColor;
        zones[zIdx].transparency = config.zoneTransparency;
        zones[zIdx].style = config.zoneStyle;
        zones[zIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
        zones[zIdx].inViewport = (zones[zIdx].renderTop >= vpBottom && 
                                   zones[zIdx].renderBottom <= vpTop);
        zIdx++;
    }
    
    // --- ABOVE DIRECTION: zones on levels + lines between them ---
    double prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < aboveCount && prevPrice > 0; i++) {
        double currentPrice = aboveLevels[i].price;
        if(currentPrice <= prevPrice) { prevPrice = currentPrice; continue; }
        
        double stepSize = currentPrice - prevPrice;
        
        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = config.objectPrefix + config.modeName + "_Above_" + 
                           IntegerToString(aboveLevels[i].logicalStep);
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = aboveLevels[i].logicalStep;
        lines[lIdx].direction = 1;
        lines[lIdx].lineColor = aboveLevels[i].levelColor;
        lines[lIdx].lineStyle = aboveLevels[i].levelStyle;
        lines[lIdx].lineWidth = aboveLevels[i].levelWidth;
        lines[lIdx].tooltip = "Midpoint +" + IntegerToString(aboveLevels[i].logicalStep) + 
            " (" + DoubleToString(lineMidPrice, GetCachedDigits()) + ")";
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lines[lIdx].inViewport = (lineMidPrice >= vpBottom && lineMidPrice <= vpTop);
        lIdx++;
        
        // Zone centered on this level
        if(config.zonesEnabled) {
            double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
            
            zones[zIdx].name = config.objectPrefix + config.modeName + "_Zone_Above_" + 
                               IntegerToString(aboveLevels[i].logicalStep);
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, GetCachedDigits());
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, GetCachedDigits());
            zones[zIdx].logicalStep = aboveLevels[i].logicalStep;
            zones[zIdx].direction = 1;
            zones[zIdx].zoneIndex = i;
            zones[zIdx].isStructure = aboveLevels[i].isStructure;
            zones[zIdx].isTrigger = aboveLevels[i].isTrigger;
            zones[zIdx].zoneColor = (aboveLevels[i].zoneColor != clrNONE) ? 
                                     aboveLevels[i].zoneColor : config.zoneDefaultColor;
            zones[zIdx].transparency = config.zoneTransparency;
            zones[zIdx].style = config.zoneStyle;
            zones[zIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
            zones[zIdx].inViewport = (zones[zIdx].renderTop >= vpBottom && 
                                      zones[zIdx].renderBottom <= vpTop);
            zIdx++;
        }
        
        prevPrice = currentPrice;
    }
    
    // --- BELOW DIRECTION: zones on levels + lines between them ---
    prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < belowCount && prevPrice > 0; i++) {
        double currentPrice = belowLevels[i].price;
        if(currentPrice >= prevPrice || currentPrice <= 0) { prevPrice = currentPrice; continue; }
        
        double stepSize = prevPrice - currentPrice;
        
        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = config.objectPrefix + config.modeName + "_Below_" + 
                           IntegerToString(belowLevels[i].logicalStep);
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = belowLevels[i].logicalStep;
        lines[lIdx].direction = -1;
        lines[lIdx].lineColor = belowLevels[i].levelColor;
        lines[lIdx].lineStyle = belowLevels[i].levelStyle;
        lines[lIdx].lineWidth = belowLevels[i].levelWidth;
        lines[lIdx].tooltip = "Midpoint -" + IntegerToString(belowLevels[i].logicalStep) + 
            " (" + DoubleToString(lineMidPrice, GetCachedDigits()) + ")";
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lines[lIdx].inViewport = (lineMidPrice >= vpBottom && lineMidPrice <= vpTop);
        lIdx++;
        
        // Zone centered on this level
        if(config.zonesEnabled) {
            double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
            
            zones[zIdx].name = config.objectPrefix + config.modeName + "_Zone_Below_" + 
                               IntegerToString(belowLevels[i].logicalStep);
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, GetCachedDigits());
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, GetCachedDigits());
            zones[zIdx].logicalStep = belowLevels[i].logicalStep;
            zones[zIdx].direction = -1;
            zones[zIdx].zoneIndex = i;
            zones[zIdx].isStructure = belowLevels[i].isStructure;
            zones[zIdx].isTrigger = belowLevels[i].isTrigger;
            zones[zIdx].zoneColor = (belowLevels[i].zoneColor != clrNONE) ? 
                                     belowLevels[i].zoneColor : config.zoneDefaultColor;
            zones[zIdx].transparency = config.zoneTransparency;
            zones[zIdx].style = config.zoneStyle;
            zones[zIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
            zones[zIdx].inViewport = (zones[zIdx].renderTop >= vpBottom && 
                                      zones[zIdx].renderBottom <= vpTop);
            zIdx++;
        }
        
        prevPrice = currentPrice;
    }
    
    // Trim output arrays
    if(config.zonesEnabled) ArrayResize(zones, zIdx);
    ArrayResize(lines, lIdx);
    zoneCount = zIdx;
    lineCount = lIdx;
}

//+------------------------------------------------------------------+
//| STAGE 5a: Render zones (FIRST — zones are primary)               |
//|                                                                  |
//| Creates/updates MT5 rectangle objects for each zone.             |
//| Handles all zone styles: Lines, Filled Box, Empty Box, Hidden.   |
//+------------------------------------------------------------------+
void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config)
{
    bool triggerEnabled = IsTriggerLevelsEnabled();
    
    for(int i = 0; i < zoneCount; i++) {
        if(config.zoneStyle == ZONE_STYLE_HIDDEN) {
            // Hidden: delete existing zone objects
            if(ObjectFind(0, zones[i].name) >= 0) {
                CacheRemoveObject(zones[i].name);
                ObjectDelete(0, zones[i].name);
            }
            continue;
        }
        
        // Skip trigger zones when triggers are disabled
        if(zones[i].isTrigger && !triggerEnabled) {
            if(ObjectFind(0, zones[i].name) >= 0) {
                CacheRemoveObject(zones[i].name);
                ObjectDelete(0, zones[i].name);
            }
            continue;
        }
        
        if(!zones[i].inViewport) continue;
        
        if(zones[i].renderTop <= zones[i].renderBottom) continue;
        
        if(config.zoneStyle == ZONE_STYLE_LINES) {
            CreateFactorMidZone_LinesStyle(zones[i].name, 
                                           zones[i].renderTop, zones[i].renderBottom,
                                           zones[i].zoneColor, zones[i].transparency);
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
            
            CreateZone(request);
        }
    }
}

//+------------------------------------------------------------------+
//| STAGE 5b: Render trigger lines (SECOND — derived from zones)     |
//|                                                                  |
//| Creates/updates MT5 horizontal line objects.                     |
//| Uses CreateOrUpdateHLine for consistency.                        |
//+------------------------------------------------------------------+
void RenderTriggerLines(
    const STriggerLine &lines[],
    const int lineCount,
    const SModeConfig &config)
{
    bool triggerEnabled = IsTriggerLevelsEnabled();
    
    for(int i = 0; i < lineCount; i++) {
        // Factor mode: hide lines when trigger-only enabled
        if(config.hideLineWhenTriggerOnly && !lines[i].isMidpoint) {
            bool shouldShow = !triggerEnabled;
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
    }
}

//+------------------------------------------------------------------+
//| STAGE 5c: Cleanup surplus objects from previous render           |
//|                                                                  |
//| Removes zone and line objects that no longer exist in current    |
//| pipeline output. Uses the mode name for prefix matching.         |
//+------------------------------------------------------------------+
void CleanupSurplusPipeline(
    const SModeConfig &config,
    const int maxLogicalStep)
{
    if(g_customPriceLineDragging) return;
    
    // Cleanup surplus zones (above, below, and center)
    if(config.zonesEnabled) {
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Above_", maxLogicalStep + 1);
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Below_", maxLogicalStep + 1);
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Center_", 1); // Only index 0 exists
    }
    
    // Cleanup surplus lines (above and below direction)
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Above_", maxLogicalStep + 1);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Below_", maxLogicalStep + 1);
    
    // Legacy cleanup: remove old midpoint line (step 0 now gets a zone, not a line)
    string midpointName = config.objectPrefix + config.modeName + "_Midpoint_0";
    if(ObjectFind(0, midpointName) >= 0) {
        CacheRemoveObject(midpointName);
        ObjectDelete(0, midpointName);
    }
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
    cfg.useStepFilter = true;
    
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

SModeConfig BuildTHConfig(const string objectPrefix)
{
    // Keep legacy-compatible TH family naming for cleanup/prefix matching
    SModeConfig cfg = BuildModeConfig(objectPrefix, "TH_Level");

    // TH mode: non-structure levels use C-level styling as fallback when triggers off
    // When triggers are on, ClassifyLevels applies trigger render color directly
    cfg.fallbackColor = inpCLevelColor;
    cfg.fallbackStyle = inpCLevelStyle;
    cfg.fallbackWidth = inpCLevelWidth;
    cfg.midpointColor = inpTriggerColor;
    cfg.midpointStyle = inpTriggerStyle;
    cfg.midpointWidth = inpTriggerWidth;
    return cfg;
}

//+------------------------------------------------------------------+
//| UNIFIED PIPELINE EXECUTOR                                        |
//|                                                                  |
//| Runs stages in order:                                            |
//|   1. Calculate → 2. Classify → 3+4. BuildZonesAndLines           |
//|   5a. RenderZones → 5b. RenderLines → 5c. Cleanup                |
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
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || stepSize <= 0) {
        result.errorMessage = "Invalid midpoint or step size";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    int baseMultiplier = GetValidatedBaseMultiplier();
    
    // Viewport
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1: Calculate
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsUniform(midpointPrice, stepSize,
                                           maxLevelsAbove, maxLevelsBelow,
                                           config.useStepFilter,
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
    
    // Stage 3+4: Build zones and lines (merged — single pass)
    SZoneDefinition zones[];
    STriggerLine lines[];
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, result.zoneCount, lines, result.lineCount);
    
    // Stage 5: Render and cleanup
    RenderZones(zones, result.zoneCount, config);
    RenderTriggerLines(lines, result.lineCount, config);
    
    // Cleanup surplus
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, maxStep);
    
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
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || ssValue <= 0 || lsValue <= 0) {
        result.errorMessage = "Invalid SSLS parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
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
                                               config.boundByHistorical, config.maxPrice, config.minPrice,
                                               rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2: Classify with alternating fallback
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevelsAlternating(rawLevels, rawCount, config,
                                                     triggerEnabled, baseMultiplier, lsFirst,
                                                     classified);
    
    // Stage 3+4: Merged zones and lines
    SZoneDefinition zones[];
    STriggerLine lines[];
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, result.zoneCount, lines, result.lineCount);
    
    // Stage 5: Render
    RenderZones(zones, result.zoneCount, config);
    RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, maxStep);
    
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
    result.success = false;
    result.errorMessage = "";
    
    if(midpointPrice <= 0 || controlDistance <= 0) {
        result.errorMessage = "Invalid M mode parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsUniform(midpointPrice, controlDistance,
                                           maxLevelsAbove, maxLevelsBelow,
                                           config.useStepFilter,
                                           config.boundByHistorical, config.maxPrice, config.minPrice,
                                           rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2: M mode classification
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevelsMMode(rawLevels, rawCount, config,
                                              triggerEnabled, baseMultiplier, classified);
    
    // Stage 3+4: Merged zones and lines
    SZoneDefinition zones[];
    STriggerLine lines[];
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, result.zoneCount, lines, result.lineCount);
    
    RenderZones(zones, result.zoneCount, config);
    RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, maxStep);
    
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
    result.success = false;
    result.errorMessage = "";
    
    if(centerPrice <= 0 || baseStepSize <= 0 || harmonicRatio <= 0) {
        result.errorMessage = "Invalid harmonic parameters";
        return result;
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Stage 1
    SCalculatedLevel rawLevels[];
    int rawCount = CalculateLevelsHarmonic(centerPrice, baseStepSize, harmonicRatio,
                                            maxLevelsAbove, maxLevelsBelow,
                                            rawLevels);
    if(rawCount == 0) { result.errorMessage = "No levels calculated"; return result; }
    
    // Stage 2
    SLevelClassified classified[];
    int classifiedCount = ClassifyLevels(rawLevels, rawCount, config,
                                          triggerEnabled, baseMultiplier, classified);
    
    // Stages 3+4+5: Merged zones and lines, then render
    SZoneDefinition zones[];
    STriggerLine lines[];
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, result.zoneCount, lines, result.lineCount);
    
    RenderZones(zones, result.zoneCount, config);
    RenderTriggerLines(lines, result.lineCount, config);
    
    int maxStep = 0;
    for(int i = 0; i < rawCount; i++) {
        if(rawLevels[i].logicalStep > maxStep) maxStep = rawLevels[i].logicalStep;
    }
    CleanupSurplusPipeline(config, maxStep);
    
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
    string zoneCenter;      // e.g., "SSLS_Zone_Center_" — zone on midpoint/anchor level
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
    entries[0].zoneCenter = "SSLS_Zone_Center_";
    
    // M (Control-based)
    entries[1].zoneSuffix = "M_Zone_";
    entries[1].levelAbove = "M_Above_";
    entries[1].levelBelow = "M_Below_";
    entries[1].midpoint = "M_Midpoint_";
    entries[1].zoneCenter = "M_Zone_Center_";
    
    // MEq (Equal spacing)
    entries[2].zoneSuffix = "MEq_Zone_";
    entries[2].levelAbove = "MEq_Above_";
    entries[2].levelBelow = "MEq_Below_";
    entries[2].midpoint = "MEq_Midpoint_";
    entries[2].zoneCenter = "MEq_Zone_Center_";
    
    // TP
    entries[3].zoneSuffix = "TP_Zone_";
    entries[3].levelAbove = "TP_Above_";
    entries[3].levelBelow = "TP_Below_";
    entries[3].midpoint = "TP_Midpoint_";
    entries[3].zoneCenter = "TP_Zone_Center_";
    
    // Combo
    entries[4].zoneSuffix = "Combo_Zone_";
    entries[4].levelAbove = "Combo_Above_";
    entries[4].levelBelow = "Combo_Below_";
    entries[4].midpoint = "Combo_Midpoint_";
    entries[4].zoneCenter = "Combo_Zone_Center_";
    
    // Factor (Standard)
    entries[5].zoneSuffix = "Factor_Zone_";
    entries[5].levelAbove = "Factor_Above_";
    entries[5].levelBelow = "Factor_Below_";
    entries[5].midpoint = "Factor_Center_";
    entries[5].zoneCenter = "Factor_Zone_Center_";
    
    // Factor (Harmonic)
    entries[6].zoneSuffix = "Factor_Harmonic_Zone_";
    entries[6].levelAbove = "Factor_Harmonic_Above_";
    entries[6].levelBelow = "Factor_Harmonic_Below_";
    entries[6].midpoint = "Factor_Harmonic_Center_";
    entries[6].zoneCenter = "Factor_Harmonic_Zone_Center_";
    
    // TH (Traditional)
    entries[7].zoneSuffix = "TH_Level_Zone_";
    entries[7].levelAbove = "TH_Level_Above_";
    entries[7].levelBelow = "TH_Level_Below_";
    entries[7].midpoint = "TH_Level_Midpoint_";
    entries[7].zoneCenter = "TH_Level_Zone_Center_";
}

// Get all zone suffixes as a flat array (for ClearAllLevels compatibility)
void GetAllZoneSuffixes(string &suffixes[], int &count)
{
    SModeSuffixEntry entries[];
    int entryCount = 0;
    GetAllModeSuffixes(entries, entryCount);
    
    // Each mode has 2 zone suffix families: zoneSuffix (Above/Below) + zoneCenter
    count = entryCount * 2;
    ArrayResize(suffixes, count);
    int idx = 0;
    for(int i = 0; i < entryCount; i++) {
        suffixes[idx++] = entries[i].zoneSuffix;
        suffixes[idx++] = entries[i].zoneCenter;
    }
    count = idx;
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
