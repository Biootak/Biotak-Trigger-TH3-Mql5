  #property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"
#property strict

#ifndef LEVEL_PIPELINE_MQH
#define LEVEL_PIPELINE_MQH

//+------------------------------------------------------------------+
//| LEVEL PIPELINE   Zone-First Architecture                         |
//|                                                                  |
//| PHILOSOPHY: Zone is the PRIMARY entity. Lines (triggers) are     |
//| derived from zone boundaries. Zones define the structure;        |
//| lines are visual markers at the edges where zones meet.          |
//|                                                                  |
//| PIPELINE STAGES:                                                 |
//|   Stage 1: CalculateLevels    SCalculatedLevel[]                 |
//|   Stage 2: ClassifyLevels     update classification in-place     |
//|   Stage 3: BuildZones         SZoneDefinition[] (PRIMARY)        |
//|   Stage 4: DeriveTriggers     STriggerLine[] (from zone bounds)  |
//|   Stage 5: RenderAll          MT5 objects (zones first, lines)   |
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
    string labelText;
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
    color  clr;
    string labelText;
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
//| STEP MODE: How price is computed at each level                   |
//+------------------------------------------------------------------+
enum ENUM_LEVEL_STEP_MODE {
    LEVEL_STEP_UNIFORM = 0,       // price = center   stepSize   N (no drift)
    LEVEL_STEP_CUMULATIVE = 1     // price = center   cumulative(steps[N % count])
};

//+------------------------------------------------------------------+
//| CLASSIFY MODE: Which Stage-2 classifier to use                   |
//+------------------------------------------------------------------+
enum ENUM_CLASSIFY_MODE {
    CLASSIFY_STANDARD = 0,        // Standard structure/trigger classification
    CLASSIFY_ALTERNATING = 1      // SSLS: alternating SS/LS fallback colors
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
//| STAGE 1: Unified level price calculator                          |
//|                                                                  |
//| Handles ALL modes via stepMode enum:                             |
//|   LEVEL_STEP_UNIFORM:    price = center   step   N              |
//|   LEVEL_STEP_CUMULATIVE: price = center     steps[i % count]    |
//|                                                                  |
//| KEY PRINCIPLE: ALL levels are calculated. Every step is always   |
//| included   there is no filtering/skipping.                       |
//+------------------------------------------------------------------+
int CalculateLevels(
    const double centerPrice,
    const double &stepSizes[],
    const int stepSizeCount,
    const ENUM_LEVEL_STEP_MODE stepMode,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool boundByHistorical,
    const double maxPrice,
    const double minPrice,
    SCalculatedLevel &levels[],
    int &maxStepOut)
{
    maxStepOut = 0;
    if(centerPrice <= 0 || stepSizeCount < 1) return 0;
    for(int s = 0; s < stepSizeCount; s++) {
        if(stepSizes[s] <= 0) return 0;
    }
    
    int safeMaxAbove = MathMin(maxLevelsAbove, MAX_SAFE_LEVELS);
    int safeMaxBelow = MathMin(maxLevelsBelow, MAX_SAFE_LEVELS);
    if(safeMaxAbove < 1) safeMaxAbove = 1;
    if(safeMaxBelow < 1) safeMaxBelow = 1;
    
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal, 64);
    int count = 0;
    
    // Midpoint (always first)
    // GOLD FIX: Apply 0.5 step offset to centerPrice
    // This shifts all zones so that their BOUNDARIES (lines) fall exactly on the original levels.
    double offset = (stepSizes[0] * 0.5);
    double shiftedCenter = centerPrice + offset;
    
    levels[count].price = shiftedCenter;
    levels[count].logicalStep = 0;
    levels[count].isMidpoint = true;
    levels[count].direction = 0;
    count++;
    
    // --- Above levels ---
    int drawnAbove = 0;
    int logicalStep = 1;
    double cumAbove = 0;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;
    
    while(drawnAbove < safeMaxAbove && iterations < maxIterations) {
        iterations++;
        double price;
        if(stepMode == LEVEL_STEP_UNIFORM) {
            price = shiftedCenter + (stepSizes[0] * logicalStep);
        } else {
            // CUMULATIVE: alternate through stepSizes array
            double dist = stepSizes[(logicalStep - 1) % stepSizeCount];
            cumAbove += dist;
            price = shiftedCenter + cumAbove;
        }
        
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
    
    // --- Below levels ---
    int drawnBelow = 0;
    logicalStep = 1;
    double cumBelow = 0;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;
    
    while(drawnBelow < safeMaxBelow && iterations < maxIterations) {
        iterations++;
        double price;
        if(stepMode == LEVEL_STEP_UNIFORM) {
            price = shiftedCenter - (stepSizes[0] * logicalStep);
        } else {
            double dist = stepSizes[(logicalStep - 1) % stepSizeCount];
            cumBelow += dist;
            price = shiftedCenter - cumBelow;
        }
        
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
    
    // PERF: maxStep is known   drawnAbove and drawnBelow track the actual max logicalStep
    maxStepOut = (drawnAbove > drawnBelow) ? drawnAbove : drawnBelow;
    ArrayResize(levels, count);
    return count;
}

//+------------------------------------------------------------------+
//| HELPER: Get descriptive label text for a level                   |
//+------------------------------------------------------------------+
string GetLabelTextForLevel(const SLevelClassified &level, const int baseMultiplier) {
    if(level.isMidpoint) return "Midpoint";
    
    string direction = (level.direction > 0) ? "+" : "-";
    
    if(level.structureLevel > 0) {
        return StringFormat("L%d %s%d", level.structureLevel, direction, level.logicalStep);
    }
    
    // For trigger subdivisions, show distance in base multiplier units if possible
    return StringFormat("%s%d", direction, level.logicalStep);
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
    ArrayResize(classified, rawCount, 64);
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
        classified[i].labelText = "";
        
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
            classified[i].labelText = GetLabelTextForLevel(classified[i], baseMultiplier);
            continue;
        }
        
        // BASE PLAYER: Structure/Trigger classification
        classified[i].structureLevel = GetHighestStructureLevel(step, g_cachedIntervals);
        classified[i].isStructure = (classified[i].structureLevel > 0);
        
        if(classified[i].isStructure) {
            // Structural level   get styling from GetPathForLevelOptimized
            color outColor; ENUM_LINE_STYLE outStyle; int outWidth;
            if(GetPathForLevelOptimized(step, outColor, outStyle, outWidth, triggerEnabled)) {
                classified[i].levelColor = outColor;
                classified[i].levelStyle = outStyle;
                classified[i].levelWidth = outWidth;
            }
        } else {
            // Trigger subdivision   between structural levels
            classified[i].isTrigger = true;
            if(triggerEnabled) {
                // User has trigger styling enabled   use trigger colors
                classified[i].levelColor = GetTriggerRenderColor();
                classified[i].levelStyle = inpTriggerStyle;
                classified[i].levelWidth = inpTriggerWidth;
            } else {
                // Trigger styling disabled   use mode fallback colors
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
        
        // Populate label text
        classified[i].labelText = GetLabelTextForLevel(classified[i], baseMultiplier);
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
    
    // PERF: Single-pass separation using pre-allocated static arrays
    // Avoids two full iterations over classifiedCount and repeated ArrayResize
    static SLevelClassified s_aboveLevels[];
    static SLevelClassified s_belowLevels[];
    static int s_aboveCapacity = 0;
    static int s_belowCapacity = 0;
    SLevelClassified midLevel;
    midLevel.price = 0;
    midLevel.isMidpoint = false;
    bool hasMid = false;
    
    // Ensure capacity (only grows, never shrinks   eliminates per-frame allocation)
    if(s_aboveCapacity < classifiedCount) {
        ArrayResize(s_aboveLevels, classifiedCount, 64);
        s_aboveCapacity = classifiedCount;
    }
    if(s_belowCapacity < classifiedCount) {
        ArrayResize(s_belowLevels, classifiedCount, 64);
        s_belowCapacity = classifiedCount;
    }
    
    // Single pass: count AND collect simultaneously
    int aboveCount = 0, belowCount = 0;
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { hasMid = true; midLevel = classified[i]; continue; }
        if(classified[i].direction > 0) { s_aboveLevels[aboveCount] = classified[i]; aboveCount++; }
        else if(classified[i].direction < 0) { s_belowLevels[belowCount] = classified[i]; belowCount++; }
    }
    
    // Pre-allocate output arrays (max possible sizes)
    int maxZones = (hasMid ? 1 : 0) + aboveCount + belowCount;
    int maxLines = aboveCount + belowCount;
    if(config.zonesEnabled) ArrayResize(zones, maxZones, 64);
    ArrayResize(lines, maxLines, 64);
    
    int zIdx = 0, lIdx = 0;
    
    // --- MIDPOINT ZONE (step 0) ---
    if(hasMid && config.zonesEnabled) {
        double neighborDist = 0;
        if(aboveCount > 0) {
            neighborDist = s_aboveLevels[0].price - midLevel.price;
        } else if(belowCount > 0) {
            neighborDist = midLevel.price - s_belowLevels[0].price;
        }
        // Edge case fix: no neighbors - use 100 points as fallback height
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
        double currentPrice = s_aboveLevels[i].price;
        if(currentPrice <= prevPrice) { prevPrice = currentPrice; continue; }
        
        double stepSize = currentPrice - prevPrice;
        
        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = config.objectPrefix + config.modeName + "_Above_" + 
                           IntegerToString(s_aboveLevels[i].logicalStep);
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = s_aboveLevels[i].logicalStep;
        lines[lIdx].direction = 1;
        lines[lIdx].lineColor = s_aboveLevels[i].levelColor;
        lines[lIdx].lineStyle = s_aboveLevels[i].levelStyle;
        lines[lIdx].lineWidth = s_aboveLevels[i].levelWidth;
        lines[lIdx].clr = s_aboveLevels[i].levelColor;
        lines[lIdx].labelText = s_aboveLevels[i].labelText;
        lines[lIdx].tooltip = "Midpoint +" + IntegerToString(s_aboveLevels[i].logicalStep) + 
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
                               IntegerToString(s_aboveLevels[i].logicalStep);
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, GetCachedDigits());
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, GetCachedDigits());
            zones[zIdx].logicalStep = s_aboveLevels[i].logicalStep;
            zones[zIdx].direction = 1;
            zones[zIdx].zoneIndex = i;
            zones[zIdx].isStructure = s_aboveLevels[i].isStructure;
            zones[zIdx].isTrigger = s_aboveLevels[i].isTrigger;
            zones[zIdx].zoneColor = (s_aboveLevels[i].zoneColor != clrNONE) ? 
                                     s_aboveLevels[i].zoneColor : config.zoneDefaultColor;
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
        double currentPrice = s_belowLevels[i].price;
        if(currentPrice >= prevPrice || currentPrice <= 0) { prevPrice = currentPrice; continue; }
        
        double stepSize = prevPrice - currentPrice;
        
        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = config.objectPrefix + config.modeName + "_Below_" + 
                           IntegerToString(s_belowLevels[i].logicalStep);
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = s_belowLevels[i].logicalStep;
        lines[lIdx].direction = -1;
        lines[lIdx].lineColor = s_belowLevels[i].levelColor;
        lines[lIdx].lineStyle = s_belowLevels[i].levelStyle;
        lines[lIdx].lineWidth = s_belowLevels[i].levelWidth;
        lines[lIdx].clr = s_belowLevels[i].levelColor;
        lines[lIdx].labelText = s_belowLevels[i].labelText;
        lines[lIdx].tooltip = "Midpoint -" + IntegerToString(s_belowLevels[i].logicalStep) + 
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
                               IntegerToString(s_belowLevels[i].logicalStep);
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, GetCachedDigits());
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, GetCachedDigits());
            zones[zIdx].logicalStep = s_belowLevels[i].logicalStep;
            zones[zIdx].direction = -1;
            zones[zIdx].zoneIndex = i;
            zones[zIdx].isStructure = s_belowLevels[i].isStructure;
            zones[zIdx].isTrigger = s_belowLevels[i].isTrigger;
            zones[zIdx].zoneColor = (s_belowLevels[i].zoneColor != clrNONE) ? 
                                     s_belowLevels[i].zoneColor : config.zoneDefaultColor;
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
//| STAGE 5a: Render zones (FIRST   zones are primary)               |
//|                                                                  |
//| Creates/updates MT5 rectangle objects for each zone.             |
//| Handles all zone styles: Lines, Filled Box, Empty Box, Hidden.   |
//+------------------------------------------------------------------+
void SetPipelineObjectTimeframesIfExists(const string name, const long timeframes)
{
    // PERF: CacheFindIndex is the hot path here. It avoids synchronous
    // ObjectFind calls for objects created by this indicator and applies the
    // terminal property only when the desired state actually changed.
    SetManagedObjectTimeframes(name, timeframes);
}

void SetPipelineZoneVisibility(const string zoneName, const bool visible,
                               const ENUM_ZONE_STYLE zoneStyle,
                               const bool indicatorHidden)
{
    // FIX: The L key controls only zone boundary lines. The box/empty-box
    // outline is controlled by F. More importantly, do not probe six object
    // names that cannot exist for the selected zone style on every frame.
    long tfAll = (visible && !indicatorHidden) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    if(zoneStyle == ZONE_STYLE_BOX_FILLED) {
        // Only the rectangle exists for a filled box.
        SetPipelineObjectTimeframesIfExists(zoneName, tfAll);
        return;
    }

    // BOX_EMPTY is represented by three ray/border segments (there is no
    // rectangle and the right edge is intentionally omitted because the top
    // and bottom borders use RAY_RIGHT).
    if(zoneStyle == ZONE_STYLE_BOX_EMPTY) {
        SetPipelineObjectTimeframesIfExists(zoneName + "_B_Top", tfAll);
        SetPipelineObjectTimeframesIfExists(zoneName + "_B_Bottom", tfAll);
        SetPipelineObjectTimeframesIfExists(zoneName + "_B_Left", tfAll);
    }
}

void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config)
{
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool indicatorHidden = IsIndicatorHidden();
    
    for(int i = 0; i < zoneCount; i++) {
        if(!zones[i].inViewport) {
            SetPipelineZoneVisibility(zones[i].name, false, config.zoneStyle, indicatorHidden);
            continue;
        }

        if(config.zoneStyle == ZONE_STYLE_HIDDEN) {
            DeleteManagedZoneObjects(zones[i].name);
            continue;
        }
        
        // Skip trigger zones when triggers are disabled
        if(zones[i].isTrigger && !triggerEnabled) {
            DeleteManagedZoneObjects(zones[i].name);
            continue;
        }
        
        if(zones[i].renderTop <= zones[i].renderBottom) continue;
        
        {
            // Box style (filled or empty) with configurable border style/width
            SZoneCreationRequest request;
            request.name = zones[i].name;
            request.topPrice = zones[i].renderTop;
            request.bottomPrice = zones[i].renderBottom;
            request.zoneColor = zones[i].zoneColor;
            request.transparency = zones[i].transparency;
            request.filled = zones[i].filled;
            request.borderStyle = inpMidZoneBorderStyle;
            request.borderWidth = inpMidZoneBorderWidth;
            request.startTime = 0;
            request.endTime = 0;
            
            CreateZone(request);
            SetPipelineZoneVisibility(zones[i].name, true, config.zoneStyle, indicatorHidden);
        }
    }
}

//+------------------------------------------------------------------+
//| STAGE 5b: Render trigger lines (SECOND   derived from zones)     |
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
    double currentPrice = GetCurrentPriceForLabels();
    
    for(int i = 0; i < lineCount; i++) {
        string labelName = lines[i].name + "_Label";
        if(!lines[i].inViewport) {
            SetPipelineObjectTimeframesIfExists(lines[i].name, OBJ_NO_PERIODS);
            SetPipelineObjectTimeframesIfExists(labelName, OBJ_NO_PERIODS);
            continue;
        }

        // Factor mode: hide lines when trigger-only enabled
        if(config.hideLineWhenTriggerOnly && !lines[i].isMidpoint) {
            bool shouldShow = !triggerEnabled;
            if(!shouldShow) {
                SetManagedObjectTimeframes(lines[i].name, OBJ_NO_PERIODS);
                SetManagedObjectTimeframes(labelName, OBJ_NO_PERIODS);
                continue;
            }
        }
        
        // Use the individual line color instead of config.triggerColor
        bool isNew = CreateOrUpdateHLine(lines[i].name, lines[i].price,
                                          lines[i].clr, lines[i].lineStyle, lines[i].lineWidth,
                                          lines[i].tooltip);
        // CreateOrUpdateHLine already applies lineTf through the visibility
        // cache; avoid a second hash lookup for the same object.
        
        // Set mode-specific properties on new objects
        if(isNew) {
            if(config.useObjPropBack) {
                ObjectSetInteger(0, lines[i].name, OBJPROP_BACK, false);
            }
            if(config.zOrder > 0) {
                ObjectSetInteger(0, lines[i].name, OBJPROP_ZORDER, config.zOrder);
            }
        }

        // Render Pip Distance Label
        if(inpShowPipDistanceLabels) {
            double pips = MathAbs(lines[i].price - currentPrice) / GetCachedPoint() / 10.0;
            CreatePipDistanceLabel(labelName, lines[i].price, pips, lines[i].clr, lines[i].labelText);
            // CreatePipDistanceLabel applies the non-line visibility state;
            // no second TIMEFRAMES/cache pass is needed here.
        }
    }
}

//+------------------------------------------------------------------+
//| HELPER: Get current price for distance labels                    |
//+------------------------------------------------------------------+
double GetCurrentPriceForLabels() {
    return (g_currentPrice > 0) ? g_currentPrice : Bid;
}

//+------------------------------------------------------------------+
//| STAGE 5c: Cleanup surplus objects from previous render           |
//+------------------------------------------------------------------+
void CleanupSurplusPipeline(
    const SModeConfig &config,
    const int maxLogicalStep)
{
    // During custom-price drag, do lightweight throttled cleanup instead of skipping entirely.
    if(g_customPriceLineDragging) {
        static uint s_lastDragCleanupMs = 0;
        uint nowMs = GetTickCount();
        if(s_lastDragCleanupMs != 0 && (nowMs - s_lastDragCleanupMs) < 250)
            return;
        s_lastDragCleanupMs = nowMs;
    }
    
    // Cleanup surplus zones
    if(config.zonesEnabled) {
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Above_", maxLogicalStep + 1);
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Below_", maxLogicalStep + 1);
        CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Center_", 1);
    }
    
    // Cleanup surplus lines and their labels
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Above_", maxLogicalStep + 1);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Below_", maxLogicalStep + 1);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Above_", maxLogicalStep + 1, 6, "_Label");
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Below_", maxLogicalStep + 1, 6, "_Label");
    
    // Legacy cleanup
    string midpointName = config.objectPrefix + config.modeName + "_Midpoint_0";
    if(ObjectFind(0, midpointName) >= 0) {
        CacheRemoveObject(midpointName);
        ObjectDelete(0, midpointName);
    }
}

//+------------------------------------------------------------------+
//| Viewport-only refresh cache                                      |
//|                                                                  |
//| Caches the last rendered zone/line geometry plus mode config so  |
//| CHARTEVENT_CHART_CHANGE (scroll/zoom) can re-render ONLY the     |
//| visibility of existing objects against the new viewport instead  |
//| of running the full calculation pipeline on every scroll event.  |
//+------------------------------------------------------------------+
static SZoneDefinition s_cachedZones[];
static STriggerLine   s_cachedLines[];
static int   s_cachedZoneCount = 0;
static int   s_cachedLineCount = 0;
static SModeConfig s_cachedModeConfig;
static bool  s_pipelineCacheValid = false;

void InvalidatePipelineViewportCache()
{
    s_pipelineCacheValid = false;
    s_cachedZoneCount = 0;
    s_cachedLineCount = 0;
    ArrayFree(s_cachedZones);
    ArrayFree(s_cachedLines);
}

//+------------------------------------------------------------------+
//| Re-render cached zones/lines against the CURRENT viewport.       |
//|                                                                  |
//| Skips CalculateLevels/ClassifyLevels/BuildZonesAndLines entirely  |
//| (geometry does not change on scroll/zoom) and only recomputes the |
//| inViewport flags + runs the two render stages. Objects whose      |
//| visibility state is unchanged are cheap no-ops thanks to the      |
//| timeframes cache; only objects entering/leaving the viewport      |
//| touch the terminal API.                                          |
//|                                                                  |
//| @return true if a refresh was performed, false if the cache is   |
//|         empty (caller should fall back to a full redraw).        |
//+------------------------------------------------------------------+
bool RefreshPipelineViewportOnly()
{
    // Native chart objects are already anchored to time/price. Let MT5
    // re-project them during scroll/zoom instead of touching visibility or
    // geometry on every CHARTEVENT_CHART_CHANGE event.
    if(inpRenderEngine == RENDER_ENGINE_OBJECTS) return true;
    if(!s_pipelineCacheValid) return false;
    if(s_cachedZoneCount <= 0 && s_cachedLineCount <= 0) return false;
    
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);
    
    // Recompute inViewport flags against the CURRENT viewport bounds
    for(int i = 0; i < s_cachedZoneCount; i++) {
        s_cachedZones[i].inViewport = (s_cachedZones[i].renderTop >= vpBottom &&
                                       s_cachedZones[i].renderBottom <= vpTop);
    }
    for(int i = 0; i < s_cachedLineCount; i++) {
        s_cachedLines[i].inViewport = (s_cachedLines[i].price >= vpBottom &&
                                       s_cachedLines[i].price <= vpTop);
    }
    
    // Render stages only (no calculation stages)
    RenderZones(s_cachedZones, s_cachedZoneCount, s_cachedModeConfig);
    RenderTriggerLines(s_cachedLines, s_cachedLineCount, s_cachedModeConfig);
    return true;
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
    
    // GOLD FIX: Factor mode steps are defined differently in user's mind (or original logic)
    // If it looks double, we apply a 0.5 scaling factor specifically for Factor modes.
    if(modeName == "Factor" || modeName == "Factor_Harmonic") {
        cfg.zoneHeightPercent *= 0.5;
    }
    
    cfg.zoneDefaultColor = zoneConfig.defaultColor;
    cfg.zoneStyle = zoneConfig.style;
    
    // Default rendering flags
    cfg.useObjPropBack = false;
    cfg.zOrder = 0;
    cfg.hideLineWhenTriggerOnly = false;
    cfg.useStepFilter = true;
    
    // Defaults for fallback colors (overridden per mode)
    cfg.fallbackColor = clrDodgerBlue;
    cfg.fallbackStyle = STYLE_DOT;
    cfg.fallbackWidth = 1;
    cfg.fallbackColor2 = clrDodgerBlue;
    cfg.fallbackStyle2 = STYLE_DOT;
    cfg.fallbackWidth2 = 1;
    cfg.midpointColor = clrDodgerBlue;
    cfg.midpointStyle = STYLE_DOT;
    cfg.midpointWidth = 1;
    
    // Price boundaries
    bool isCustomPrice = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE);
    cfg.boundByHistorical = !isCustomPrice;
    cfg.maxPrice = isCustomPrice ? 0 : g_highestHigh;
    cfg.minPrice = isCustomPrice ? 0 : g_lowestLow;
    
    return cfg;
}

//+------------------------------------------------------------------+
//| UNIFIED PIPELINE EXECUTOR                                        |
//+------------------------------------------------------------------+
SPipelineResult ExecutePipeline(
    const SModeConfig &config,
    const double centerPrice,
    const double &stepSizes[],
    const int stepSizeCount,
    const ENUM_LEVEL_STEP_MODE stepMode,
    const ENUM_CLASSIFY_MODE classifyMode,
    const bool lsFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow)
{
    SPipelineResult result;
    result.zoneCount = 0;
    result.lineCount = 0;
    result.success = false;
    result.errorMessage = "";
    
    if(centerPrice <= 0) {
        result.errorMessage = "Invalid center price";
        return result;
    }
    for(int s = 0; s < stepSizeCount; s++) {
        if(stepSizes[s] <= 0) {
            result.errorMessage = "Invalid step size";
            return result;
        }
    }
    
    bool triggerEnabled = IsTriggerLevelsEnabled();
    int baseMultiplier = GetValidatedBaseMultiplier();
    double vpTop, vpBottom;
    GetViewportBounds(vpTop, vpBottom);

    // The retained-object renderer must keep every calculated object alive.
    // OBJ_HLINE/OBJ_RECTANGLE are chart-space objects and the terminal clips
    // them natively; viewport culling here would hide levels until a scroll
    // event re-renders them and causes the MT5 flicker/jump being avoided.
    if(inpRenderEngine == RENDER_ENGINE_OBJECTS) {
        vpTop = 1.0e100;
        vpBottom = -1.0e100;
    }
    
    // Stage 1: Calculate (unified)
    SCalculatedLevel rawLevels[];
    int maxStep = 0;
    int rawCount = CalculateLevels(centerPrice, stepSizes, stepSizeCount, stepMode,
                                    maxLevelsAbove, maxLevelsBelow,
                                    config.boundByHistorical, config.maxPrice, config.minPrice,
                                    rawLevels, maxStep);
    if(rawCount == 0) {
        result.errorMessage = "No levels calculated";
        return result;
    }
    
    // Stage 2: Classify (mode-specific variant)
    SLevelClassified classified[];
    int classifiedCount = 0;
    switch(classifyMode) {
        case CLASSIFY_ALTERNATING:
            classifiedCount = ClassifyLevelsAlternating(rawLevels, rawCount, config,
                                                        triggerEnabled, baseMultiplier, lsFirst,
                                                        classified);
            break;
        default: // CLASSIFY_STANDARD
            classifiedCount = ClassifyLevels(rawLevels, rawCount, config,
                                              triggerEnabled, baseMultiplier, classified);
            break;
    }
    
    // Stages 3+4: Build zones and lines (merged   single pass)
    SZoneDefinition zones[];
    STriggerLine lines[];
    BuildZonesAndLines(classified, classifiedCount, config, vpTop, vpBottom,
                       zones, result.zoneCount, lines, result.lineCount);
    
    // Stage 5: Render and cleanup
    RenderZones(zones, result.zoneCount, config);
    RenderTriggerLines(lines, result.lineCount, config);
    
    // PERF: Cache the geometry used for rendering so a later scroll/zoom
    // (CHARTEVENT_CHART_CHANGE) can refresh visibility without rebuilding
    // levels, classifications and zones from scratch.
    // NOTE: ArrayCopy is not allowed on struct arrays containing strings
    // (error 368), so copy element-by-element into pre-sized static arrays.
    if(ArraySize(s_cachedZones) < result.zoneCount)
        ArrayResize(s_cachedZones, result.zoneCount);
    for(int i = 0; i < result.zoneCount; i++) s_cachedZones[i] = zones[i];
    if(ArraySize(s_cachedLines) < result.lineCount)
        ArrayResize(s_cachedLines, result.lineCount);
    for(int i = 0; i < result.lineCount; i++) s_cachedLines[i] = lines[i];
    s_cachedZoneCount = result.zoneCount;
    s_cachedLineCount = result.lineCount;
    s_cachedModeConfig = config;
    s_pipelineCacheValid = true;
    
    // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
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
    string zoneCenter;      // e.g., "SSLS_Zone_Center_"   zone on midpoint/anchor level
};

// GetAll registered mode suffixes   used by ClearAllLevels and DeleteAllIndicatorObjects
void GetAllModeSuffixes(SModeSuffixEntry &entries[], int &count)
{
    static string modeNames[] = {"SSLS", "Combo", "Factor", "Factor_Harmonic", "TH_Level"};
    count = ArraySize(modeNames);
    ArrayResize(entries, count);
    
    for(int i = 0; i < count; i++) {
        entries[i].zoneSuffix = modeNames[i] + "_Zone_";
        entries[i].levelAbove = modeNames[i] + "_Above_";
        entries[i].levelBelow = modeNames[i] + "_Below_";
        entries[i].midpoint = modeNames[i] + "_Midpoint_";
        entries[i].zoneCenter = modeNames[i] + "_Zone_Center_";
        
        // Manual overrides for non-standard legacy suffixes
        if(modeNames[i] == "Factor") entries[i].midpoint = "Factor_Center_";
        if(modeNames[i] == "Factor_Harmonic") entries[i].midpoint = "Factor_Harmonic_Center_";
    }
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

// Get compact mode-family prefixes for one-call bulk deletion.
//
// Every object a mode creates is named objectPrefix + "<ModeName>_..."
// (e.g. "SSLS_Zone_Above_1", "Factor_Above_5", "Combo_Midpoint_0"), so a
// single ObjectsDeleteAll per family prefix replaces the per-suffix sweeps
// above (25 calls -> 4). A family whose prefix starts with an earlier one
// (Factor_Harmonic_ under Factor_) is already covered and is deduped.
// Future modes only need to add their name to GetAllModeSuffixes' list and
// they are automatically covered here - no ClearAllLevels change required.
void GetAllModeFamilyPrefixes(string &prefixes[], int &count)
{
    SModeSuffixEntry entries[];
    int entryCount = 0;
    GetAllModeSuffixes(entries, entryCount);

    const string ZONE_MARKER = "Zone_"; // zoneSuffix == "<ModeName>_Zone_"
    int markerLen = StringLen(ZONE_MARKER);

    ArrayResize(prefixes, entryCount);
    count = 0;
    for(int i = 0; i < entryCount; i++) {
        string fam = entries[i].zoneSuffix;
        int famLen = StringLen(fam) - markerLen; // length of "<ModeName>_"
        if(famLen < 1) continue;
        string famPrefix = StringSubstr(fam, 0, famLen);
        bool covered = false;
        for(int j = 0; j < count; j++) {
            if(StringFind(famPrefix, prefixes[j], 0) == 0) {
                covered = true;
                break;
            }
        }
        if(!covered) prefixes[count++] = famPrefix;
    }
    ArrayResize(prefixes, count);
}

#endif // LEVEL_PIPELINE_MQH
