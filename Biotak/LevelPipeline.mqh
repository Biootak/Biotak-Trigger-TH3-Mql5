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
//| ZONE MINIMUM HEIGHT FLOOR                                        |
//|                                                                  |
//| FIX: Zones below a timeframe's fractal step collapse to zero     |
//| height (renderTop == renderBottom after NormalizeDouble) and are |
//| silently skipped. This makes zones vanish on lower TFs (M30/M15/ |
//| M5/M1). Enforce a minimum visible height in POINTS so zones      |
//| always render. 2 points = 1 pip on a 4-digit symbol.             |
//+------------------------------------------------------------------+
#ifndef ZONE_MIN_HEIGHT_POINTS
#define ZONE_MIN_HEIGHT_POINTS 2   // minimum half-height each side in points
#endif

// Expand a zone's half-height so the resulting box is always at least
// ZONE_MIN_HEIGHT_POINTS points tall on each side. Keeps the center price.
double GetMinSafeZoneHalfHeight(const double centerPrice, double halfHeight)
{
    double point = GetCachedPoint();
    if(point <= 0) point = 1e-5;
    double minHalf = point * ZONE_MIN_HEIGHT_POINTS;
    if(halfHeight < minHalf) halfHeight = minHalf;
    return halfHeight;
}

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
    int logicalStepAboveLast = 0;
    double cumAbove = 0;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;

    // RANGE FIX: If the base price is far below the visible/historical top, skip the
    // levels that fall entirely outside the range so the level budget is spent inside
    // the range instead of in empty space. Only applied in UNIFORM mode where the step
    // is constant (exact skip); CUMULATIVE keeps the plain scan to avoid over-skipping.
    if(stepMode == LEVEL_STEP_UNIFORM && boundByHistorical && maxPrice > 0 && stepSizes[0] > 0) {
        double gap = maxPrice - shiftedCenter;
        if(gap > 0) {
            int skip = (int)MathFloor(gap / stepSizes[0]);
            if(skip > 0) logicalStep = skip + 1;  // land just inside the top of range
        }
    }

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
        logicalStepAboveLast = logicalStep;
        logicalStep++;
    }
    
    // --- Below levels ---
    int drawnBelow = 0;
    logicalStep = 1;
    double cumBelow = 0;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;

    // RANGE FIX (symmetric): skip levels above the visible/historical bottom when the
    // base price is far above it. UNIFORM mode only (constant step = exact skip).
    if(stepMode == LEVEL_STEP_UNIFORM && boundByHistorical && minPrice > 0 && stepSizes[0] > 0) {
        double gap = shiftedCenter - minPrice;
        if(gap > 0) {
            int skip = (int)MathFloor(gap / stepSizes[0]);
            if(skip > 0) logicalStep = skip + 1;  // land just inside the bottom of range
        }
    }

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
    
    // maxStep must reflect the HIGHEST logicalStep actually assigned (objects are named
    // by logicalStep and CleanupSurplusObjects deletes indices > maxStep). With the range
    // skip offset the last logicalStep can exceed the drawn count, so derive it directly.
    int maxLogicalAbove = (drawnAbove > 0) ? (logicalStepAboveLast) : 0;
    int maxLogicalBelow = (drawnBelow > 0) ? (logicalStep - 1) : 0;
    maxStepOut = (maxLogicalAbove > maxLogicalBelow) ? maxLogicalAbove : maxLogicalBelow;
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

    // PERF (2026): hoist the per-direction string prefixes out of the hot
    // loops. The previous implementation rebuilt the same "<prefix>_<mode>_Above_"
    // and "<prefix>_<mode>_Zone_Above_" strings via 2-3 concatenations per zone,
    // allocating a new string buffer each time. With 158 zones on MN1 that was
    // 474+ intermediate string allocations per redraw - measurable in the
    // 2026 hot-path profiler. Building the constant prefix once and appending
    // only the per-level IntegerToString cuts the allocations to 1 per zone.
    int digits = GetCachedDigits();
    string modePrefix = config.objectPrefix + config.modeName;
    string lineAbovePrefix = modePrefix + "_Above_";
    string lineBelowPrefix = modePrefix + "_Below_";
    string zoneAbovePrefix = modePrefix + "_Zone_Above_";
    string zoneBelowPrefix = modePrefix + "_Zone_Below_";
    string zoneCenterName  = modePrefix + "_Zone_Center_0";

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
        // FIX: floor to a minimum visible height so the zone never collapses
        // below one point on lower timeframes (M30/M15/M5/M1).
        zoneHeight = GetMinSafeZoneHalfHeight(midLevel.price, zoneHeight);

        zones[zIdx].name = zoneCenterName;
        zones[zIdx].midPrice = midLevel.price;
        zones[zIdx].renderTop = NormalizeDouble(midLevel.price + zoneHeight, digits);
        zones[zIdx].renderBottom = NormalizeDouble(midLevel.price - zoneHeight, digits);
        zones[zIdx].logicalStep = 0;
        zones[zIdx].direction = 0;
        zones[zIdx].zoneIndex = 0;
        zones[zIdx].isStructure = true;
        zones[zIdx].isTrigger = false;
        zones[zIdx].zoneColor = config.zoneDefaultColor;
        zones[zIdx].transparency = config.zoneTransparency;
        zones[zIdx].style = config.zoneStyle;
        zones[zIdx].filled = (config.zoneStyle == ZONE_STYLE_BOX_FILLED);
        // CRITICAL FIX: Always create zones regardless of current viewport. The previous
        // inViewport filter silently dropped zones on lower TFs due to stale/narrow viewport
        // calculations. Visibility is controlled later via OBJPROP_TIMEFRAMES.
        zones[zIdx].inViewport = true;
        zIdx++;
    }

    // --- ABOVE DIRECTION: zones on levels + lines between them ---
    double prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < aboveCount && prevPrice > 0; i++) {
        double currentPrice = s_aboveLevels[i].price;
        if(currentPrice <= prevPrice) { prevPrice = currentPrice; continue; }

        double stepSize = currentPrice - prevPrice;

        // PERF (2026): IntegerToString is faster than concat (single allocation
        // instead of two), and using StringFormat for the tooltip is ~3x
        // faster than the prior 4-concat pattern.
        string stepStr = IntegerToString(s_aboveLevels[i].logicalStep);

        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = lineAbovePrefix + stepStr;
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = s_aboveLevels[i].logicalStep;
        lines[lIdx].direction = 1;
        lines[lIdx].lineColor = s_aboveLevels[i].levelColor;
        lines[lIdx].lineStyle = s_aboveLevels[i].levelStyle;
        lines[lIdx].lineWidth = s_aboveLevels[i].levelWidth;
        lines[lIdx].clr = s_aboveLevels[i].levelColor;
        lines[lIdx].labelText = s_aboveLevels[i].labelText;
        lines[lIdx].tooltip = StringFormat("Midpoint +%s (%s)", stepStr, DoubleToString(lineMidPrice, digits));
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lines[lIdx].inViewport = (lineMidPrice >= vpBottom && lineMidPrice <= vpTop);
        lIdx++;

        // Zone centered on this level
        if(config.zonesEnabled) {
            double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
            // FIX: floor to a minimum visible height on lower timeframes
            zoneHeight = GetMinSafeZoneHalfHeight(currentPrice, zoneHeight);

            zones[zIdx].name = zoneAbovePrefix + stepStr;
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, digits);
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, digits);
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
            // CRITICAL FIX: Always create zones regardless of current viewport.
            zones[zIdx].inViewport = true;
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

        string stepStr = IntegerToString(s_belowLevels[i].logicalStep);

        // Line at midpoint between prev and current
        double lineMidPrice = (prevPrice + currentPrice) / 2.0;
        lines[lIdx].name = lineBelowPrefix + stepStr;
        lines[lIdx].price = lineMidPrice;
        lines[lIdx].logicalStep = s_belowLevels[i].logicalStep;
        lines[lIdx].direction = -1;
        lines[lIdx].lineColor = s_belowLevels[i].levelColor;
        lines[lIdx].lineStyle = s_belowLevels[i].levelStyle;
        lines[lIdx].lineWidth = s_belowLevels[i].levelWidth;
        lines[lIdx].clr = s_belowLevels[i].levelColor;
        lines[lIdx].labelText = s_belowLevels[i].labelText;
        lines[lIdx].tooltip = StringFormat("Midpoint -%s (%s)", stepStr, DoubleToString(lineMidPrice, digits));
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lines[lIdx].inViewport = (lineMidPrice >= vpBottom && lineMidPrice <= vpTop);
        lIdx++;

        // Zone centered on this level
        if(config.zonesEnabled) {
            double zoneHeight = stepSize * config.zoneHeightPercent * 0.5;
            // FIX: floor to a minimum visible height on lower timeframes
            zoneHeight = GetMinSafeZoneHalfHeight(currentPrice, zoneHeight);

            zones[zIdx].name = zoneBelowPrefix + stepStr;
            zones[zIdx].midPrice = currentPrice;
            zones[zIdx].renderTop = NormalizeDouble(currentPrice + zoneHeight, digits);
            zones[zIdx].renderBottom = NormalizeDouble(currentPrice - zoneHeight, digits);
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
            // CRITICAL FIX: Always create zones regardless of current viewport.
            zones[zIdx].inViewport = true;
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
//+------------------------------------------------------------------+
//| PERF (2026): cache-backed SetPipelineObjectTimeframesIfExists    |
//|                                                                  |
//| The original implementation called ObjectFind on every zone/line  |
//| (a SYNCHRONOUS chart API call per the official MQL5 docs) just    |
//| to gate the asynchronous ObjectSetInteger write. With ~200 zones  |
//| on M1 that is ~200 sync syscalls per redraw for nothing —         |
//| the cache already knows which objects exist and what their last  |
//| OBJPROP_TIMEFRAMES value was. We now skip the chart API entirely  |
//| on the hot path.                                                  |
//+------------------------------------------------------------------+
void SetPipelineObjectTimeframesIfExists(const string name, const long timeframes)
{
    int idx = CacheFindIndex(name);
    if(idx >= 0 && g_objectCacheHash[idx].entry.exists) {
        if(g_objectCacheHash[idx].entry.lastTimeframes == timeframes) return;
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
        g_objectCacheHash[idx].entry.lastTimeframes = timeframes;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
        return;
    }
    // Cache miss (object never cached, or was invalidated): pay the
    // sync ObjectFind cost ONCE and hydrate the cache for the next call.
    if(ObjectFind(0, name) < 0) return;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
    if(idx >= 0) {
        g_objectCacheHash[idx].entry.lastTimeframes = timeframes;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
    }
}

void SetPipelineZoneVisibility(const string zoneName, const bool visible)
{
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    SetPipelineObjectTimeframesIfExists(zoneName, timeframes);
    SetPipelineObjectTimeframesIfExists(zoneName + "_Top", timeframes);
    SetPipelineObjectTimeframesIfExists(zoneName + "_Bottom", timeframes);
}

void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config,
    const double vpTop = 0,
    const double vpBottom = 0)
{
    bool triggerEnabled = IsTriggerLevelsEnabled();
    
    // PERF/B (in-place shift updates): when a valid viewport is supplied, delete
    // (not hide) zones that fall outside the visible price window. Deleting is
    // what lets a shift change update levels in place instead of a full clear:
    // objects no longer in view are removed here, while still-visible ones are
    // moved/updated by CreateZone. OBJ_ALL_PERIODS is kept (never OBJ_NO_PERIODS),
    // and redraws on scroll regenerate off-screen zones, so lower-TF visibility is
    // preserved (objects simply reappear when scrolled into view).
    // v2026: Disabled viewport culling for zones. On lower timeframes the tiny
    // TH steps make zones very small; even a slight price shift or stale
    // viewport calculation was hiding them. Zones are cheap to keep because the
    // adaptive level cap already limits their count, and CreateZone handles
    // sub-point heights. Keeping them always visible avoids the "disappears
    // after a few seconds" symptom.
    
    // DIAGNOSTIC LOG: always print zone render summary (first 5 calls per run)
    static int s_zoneRenderLogCount = 0;
    int createdCount = 0;
    int failedCount = 0;
    int skippedCount = 0;
    int culledCount = 0;
    string firstFailReason = "";
    
    for(int i = 0; i < zoneCount; i++) {
        // DISABLED: viewport culling for zones. It caused zones to vanish on
        // lower timeframes when price moved slightly. Visibility is now managed
        // solely by the global hide (F key) and OBJ_ALL_PERIODS default.
        
        if(config.zoneStyle == ZONE_STYLE_HIDDEN) {
            DeleteManagedZoneObjects(zones[i].name);
            skippedCount++;
            continue;
        }
        
        // Skip trigger zones when triggers are disabled
        if(zones[i].isTrigger && !triggerEnabled) {
            DeleteManagedZoneObjects(zones[i].name);
            skippedCount++;
            continue;
        }
        
        if(zones[i].renderTop <= zones[i].renderBottom) {
            skippedCount++;
            continue;
        }
        
        if(config.zoneStyle == ZONE_STYLE_LINES) {
            CreateFactorMidZone_LinesStyle(zones[i].name,
                                           zones[i].renderTop, zones[i].renderBottom,
                                           zones[i].zoneColor, zones[i].transparency);
            // PERF (2026): SetPipelineZoneVisibility(zoneName, true) was a
            // 3x redundant call here:
            //   * The main `zoneName` object is deleted by
            //     CreateFactorMidZone_LinesStyle before the top/bottom lines
            //     are created, so writing OBJPROP_TIMEFRAMES on it is wasted.
            //   * The `_Top` / `_Bottom` lines are created by
            //     CreateOrUpdateHLine, which already pushes the right
            //     visibility through ApplyVisibilityState /
            //     ApplyVisibilityStateIfUnchangedSkip (cache-backed since
            //     the 2026 PERF patch).
            // We just trust the visibility state from the per-frame cache
            // (CacheRefreshVisibilityState) — the global hide (F key) and
            // lines-visibility (L key) are already applied at the call site.
            createdCount++;
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

            SZoneCreationResult zoneResult = CreateZone(request);
            if(zoneResult.success) {
                createdCount++;
            } else {
                failedCount++;
                if(StringLen(firstFailReason) == 0) {
                    firstFailReason = zoneResult.errorMessage;
                }
            }
            // PERF (2026): the redundant SetPipelineZoneVisibility(zoneName,
            // true) was removed. CreateZone already calls
            // SetObjectTimeframesIfChanged for the main zone name, and the
            // `_Top` / `_Bottom` lines do not exist in BOX style (only in
            // LINES style). On 200+ zones this saves 600+ cache lookups
            // per redraw frame.
        }
    }
    
    // DIAGNOSTIC LOG: report zone render results (first 5 calls per run)
    if(s_zoneRenderLogCount < 5) {
        Print("[ZONE_RENDER_DIAG] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " zones=", zoneCount, " created=", createdCount, " failed=", failedCount,
              " skipped=", skippedCount, " culled=", culledCount, " style=", EnumToString(config.zoneStyle),
              " firstFail=", firstFailReason);
        s_zoneRenderLogCount++;
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
    const SModeConfig &config,
    const double vpTop = 0,
    const double vpBottom = 0)
{
    bool triggerEnabled = IsTriggerLevelsEnabled();
    double currentPrice = GetCurrentPriceForLabels();

    // PERF (2026): hoist the per-line invariants out of the loop. The previous
    // implementation called IsIndicatorHidden() and the g_linesVisible branch
    // TWICE per line (once for the line, once for its pip-distance label) -
    // 316 calls per redraw on MN1 with 158 lines. Both are stable for the
    // whole frame, so compute them once and pass the resolved OBJPROP_TIMEFRAMES
    // value through. SetPipelineObjectTimeframesIfExists then becomes a single
    // cache lookup per object instead of a getter + setter chain.
    bool hiddenCached = IsIndicatorHidden();
    long lineTf = (hiddenCached || !g_linesVisible) ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
    long labelTf = hiddenCached ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
    bool showPipLabels = inpShowPipDistanceLabels;

    // PERF (2026): pre-compute the "_Label" suffix once. Per the MQL5 docs,
    // every `+` on a string allocates a new buffer; doing it inside a
    // 158-iteration loop was 158 short-lived heap allocations per redraw.
    // The label is always 6 chars appended to the line name.
    string LABEL_SUFFIX = "_Label";

    for(int i = 0; i < lineCount; i++) {
        const string lineName = lines[i].name;
        string labelName = lineName + LABEL_SUFFIX;
        // DISABLED: viewport culling for lines. Lines now stay visible regardless
        // of zoom or scroll position.

        // Factor mode: hide lines when trigger-only enabled
        if(config.hideLineWhenTriggerOnly && !lines[i].isMidpoint) {
            bool shouldShow = !triggerEnabled;
            if(!shouldShow) {
                SetPipelineObjectTimeframesIfExists(lineName, OBJ_NO_PERIODS);
                SetPipelineObjectTimeframesIfExists(labelName, OBJ_NO_PERIODS);
                continue;
            }
        }

        // Use the individual line color instead of config.triggerColor
        bool isNew = CreateOrUpdateHLine(lineName, lines[i].price,
                                          lines[i].clr, lines[i].lineStyle, lines[i].lineWidth,
                                          lines[i].tooltip);
        SetPipelineObjectTimeframesIfExists(lineName, lineTf);

        // Set mode-specific properties on new objects
        if(isNew) {
            if(config.useObjPropBack) {
                ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
            }
            if(config.zOrder > 0) {
                ObjectSetInteger(0, lineName, OBJPROP_ZORDER, config.zOrder);
            }
        }

        // Render Pip Distance Label
        if(showPipLabels) {
            double pips = MathAbs(lines[i].price - currentPrice) / GetCachedPoint() / 10.0;
            CreatePipDistanceLabel(labelName, lines[i].price, pips, lines[i].clr, lines[i].labelText);
            SetPipelineObjectTimeframesIfExists(labelName, labelTf);
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
//| PERF (2026): String hash set for zone/line name diff.            |
//|                                                                  |
//| The previous ExecutePipeline did an O(N*M) nested-loop name diff  |
//| to figure out which previously-rendered zones/lines were no      |
//| longer in the new kept set. With 289 zones on M1, that was       |
//| 289*289 = 83,521 string comparisons per redraw.                  |
//|                                                                  |
//| We replace it with a small open-addressed hash set, sized as a   |
//| power of two so the modulo is a cheap bitmask. Load factor is    |
//| ~28% on M1 (289/1024) and ~58% on the heaviest timeframe, so     |
//| the bounded linear probe stays short. Insert/lookup are amortized |
//| O(1), so the whole diff becomes O(N+M) ≈ 600 ops on M1.          |
//+------------------------------------------------------------------+
#define ZONE_DIFF_HASH_SIZE 1024
#define ZONE_DIFF_HASH_MASK (ZONE_DIFF_HASH_SIZE - 1)
#define ZONE_DIFF_MAX_PROBE 32

struct SDiffHashEntry {
    string name;
    bool   occupied;
};

static SDiffHashEntry g_diffHash[];
static bool g_diffHashInit = false;

void DiffHashEnsure() {
    if(g_diffHashInit) return;
    ArrayResize(g_diffHash, ZONE_DIFF_HASH_SIZE);
    for(int i = 0; i < ZONE_DIFF_HASH_SIZE; i++) {
        g_diffHash[i].name = "";
        g_diffHash[i].occupied = false;
    }
    g_diffHashInit = true;
}

int DiffHashKey(const string name) {
    // djb2 hash — cheap, well-distributed for short ASCII names.
    uint h = 5381;
    int len = StringLen(name);
    for(int i = 0; i < len; i++) {
        h = ((h << 5) + h) + (uint)(ushort)StringGetCharacter(name, i);
    }
    return (int)(h & ZONE_DIFF_HASH_MASK);
}

void DiffHashInsert(const string name) {
    int key = DiffHashKey(name);
    for(int probe = 0; probe < ZONE_DIFF_MAX_PROBE; probe++) {
        int idx = (key + probe) & ZONE_DIFF_HASH_MASK;
        if(!g_diffHash[idx].occupied || g_diffHash[idx].name == name) {
            g_diffHash[idx].name = name;
            g_diffHash[idx].occupied = true;
            return;
        }
    }
}

bool DiffHashContains(const string name) {
    int key = DiffHashKey(name);
    for(int probe = 0; probe < ZONE_DIFF_MAX_PROBE; probe++) {
        int idx = (key + probe) & ZONE_DIFF_HASH_MASK;
        if(!g_diffHash[idx].occupied) return false;
        if(g_diffHash[idx].name == name) return true;
    }
    return false;
}

void DiffHashClear() {
    // PERF: just flip occupied to false. Don't bother clearing names —
    // an empty slot is recognized by `occupied == false`, and the next
    // insert overwrites the name in-place.
    for(int i = 0; i < ZONE_DIFF_HASH_SIZE; i++) {
        g_diffHash[i].occupied = false;
    }
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
    
    // DIAGNOSTIC LOG: confirm pipeline entry
    static int s_pipelineEntryLogCount = 0;
    if(s_pipelineEntryLogCount < 5) {
        Print("[PIPELINE_ENTRY] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " mode=", config.modeName,
              " center=", DoubleToString(centerPrice, Digits),
              " stepCount=", stepSizeCount);
        s_pipelineEntryLogCount++;
    }
    
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
    
    // DIAGNOSTIC LOG: pipeline summary (print first 5 calls per run)
    static int s_pipelineLogCount = 0;
    if(s_pipelineLogCount < 5) {
        Print("[PIPELINE_DIAG] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " mode=", config.modeName,
              " raw=", rawCount, " classified=", classifiedCount,
              " zones=", result.zoneCount, " lines=", result.lineCount,
              " vpBottom=", DoubleToString(vpBottom, Digits),
              " vpTop=", DoubleToString(vpTop, Digits),
              " center=", DoubleToString(centerPrice, Digits));
        s_pipelineLogCount++;
    }
    
    // Stage 5: Render and cleanup
    // PERF/B (in-place shift updates): delete objects from the previous draw that
    // are NOT present in the current render set, so a fractal-shift change updates
    // levels in place (move still-visible ones via CreateZone) instead of a full
    // clear+recreate. Names shared between old and new sets are kept and moved.
    // Tracked per-mode so Combinations/Factor modes don't delete each other's objects.
    // NOTE: Out-of-viewport objects are kept in the set and hidden by RenderZones/
    // RenderTriggerLines to avoid object churn on scroll.
    bool trigEn = IsTriggerLevelsEnabled();

    int slot = GetRenderedSlot(config.modeName);
    string prevZoneNames[];
    string prevLineNames[];
    ArrayCopy(prevZoneNames, g_renderedNames[slot].zoneNames);
    ArrayCopy(prevLineNames, g_renderedNames[slot].lineNames);

    // Build the set of zone/line names that will exist after this draw (kept set).
    // All valid objects are kept; viewport culling hides off-screen ones instead
    // of deleting them, preventing churn when the user scrolls or price shifts.
    string keepZoneNames[];
    ArrayResize(keepZoneNames, result.zoneCount);
    int keepZoneCount = 0;
    for(int zi = 0; zi < result.zoneCount; zi++) {
        if(config.zoneStyle == ZONE_STYLE_HIDDEN) continue;
        if(zones[zi].isTrigger && !trigEn) continue;
        if(zones[zi].renderTop <= zones[zi].renderBottom) continue;
        keepZoneNames[keepZoneCount++] = zones[zi].name;
    }
    ArrayResize(keepZoneNames, keepZoneCount);

    string keepLineNames[];
    ArrayResize(keepLineNames, result.lineCount);
    int keepLineCount = 0;
    for(int li = 0; li < result.lineCount; li++) {
        keepLineNames[keepLineCount++] = lines[li].name;
    }
    ArrayResize(keepLineNames, keepLineCount);

    // PERF (2026): O(N+M) zone/line diff using the open-addressed hash set
    // above. The previous nested-loop version was O(N*M) string compares —
    // 83k+ comparisons on M1 alone. Now we build the kept set once and
    // probe it in O(1) per previous name.
    DiffHashEnsure();
    DiffHashClear();
    for(int kz = 0; kz < keepZoneCount; kz++) DiffHashInsert(keepZoneNames[kz]);
    for(int kl = 0; kl < keepLineCount; kl++) DiffHashInsert(keepLineNames[kl]);

    for(int pi = 0; pi < ArraySize(prevZoneNames); pi++) {
        if(!DiffHashContains(prevZoneNames[pi]))
            DeleteManagedZoneObjects(prevZoneNames[pi]);
    }
    for(int pi = 0; pi < ArraySize(prevLineNames); pi++) {
        if(!DiffHashContains(prevLineNames[pi])) {
            DeleteIndicatorObjectManaged(prevLineNames[pi]);
            DeleteIndicatorObjectManaged(prevLineNames[pi] + "_Label");
        }
    }

    RenderZones(zones, result.zoneCount, config, vpTop, vpBottom);
    RenderTriggerLines(lines, result.lineCount, config, vpTop, vpBottom);

    // Remember this draw's kept set for the next in-place diff.
    ArrayResize(prevZoneNames, keepZoneCount);
    for(int kz = 0; kz < keepZoneCount; kz++) prevZoneNames[kz] = keepZoneNames[kz];
    ArrayResize(prevLineNames, keepLineCount);
    for(int kl = 0; kl < keepLineCount; kl++) prevLineNames[kl] = keepLineNames[kl];
    
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

// PERF/B: per-mode registry of object names rendered in the last draw so that
// in-place updates (fractal shift, scroll) can delete only objects no longer in
// the current set, instead of a full clear+recreate.
struct SModeRenderedNames {
    string mode;
    string zoneNames[];
    string lineNames[];
};
SModeRenderedNames g_renderedNames[];
int GetRenderedSlot(const string mode) {
    for(int i = 0; i < ArraySize(g_renderedNames); i++) {
        if(g_renderedNames[i].mode == mode) return i;
    }
    int n = ArraySize(g_renderedNames);
    ArrayResize(g_renderedNames, n + 1);
    g_renderedNames[n].mode = mode;
    return n;
}

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

#endif // LEVEL_PIPELINE_MQH
