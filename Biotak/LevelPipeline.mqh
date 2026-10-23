// ============================================================================
// OWNED MT5 module - forked from the MetaTrader 4 source on 2026-10-12.
//   MT4 source : Biotak/Biotak/LevelPipeline.mqh
//
// MT4 remains the LOGIC reference and tools/parity/module-report.py flags
// any drift, but nothing regenerates this file: MT5-only changes live here
// directly, marked MT5-ONLY / P-MT5-* / P-PERF-*.
//
// MT5-only changes this file already carries:
//   * the census diagnostic is DEBUG, not production  (1 substitution)
//   * one lift per render pass, not three chart reads per level  (1 substitution)
// ============================================================================
  #property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"
#property strict

#ifndef LEVEL_PIPELINE_MQH
#define LEVEL_PIPELINE_MQH

// LevelPipe_A.mqh - LevelPipeline.mqh split 2026-09-29: exact lines 7-1438, byte-identical, zero renames.
#ifndef LEVEL_PIPE_A_MQH
#define LEVEL_PIPE_A_MQH


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
    // P-UI-62: the BAND and its EDGE are two halves of one picture, not one flag.
    //   FILLED   -> band, no edge      EMPTY -> edge, no band      OUTLINED -> both
    bool   filled;          // draw the band (filled rectangle)
    bool   outline;         // draw the edge (three border segments)
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
    bool   hideLineWhenTriggerOnly; // RETIRED (always false): lines are never
                                    // gated by the trigger switch — RenderZones
                                    // alone hides the trigger zones
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
    const bool sslsLongFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const bool boundByHistorical,
    const double maxPrice,
    const double minPrice,
    SCalculatedLevel &levels[],
    int &maxStepOut)
{
    maxStepOut = 0;
    // P-UI-57: `<= 0` IS NaN-BLIND — every comparison against NaN is false, so a
    // poisoned price/step passed straight through the guards that were supposed to
    // stop it and turned every derived level into NaN (NaN prices then reach
    // `ObjectSetDouble`, where MT4 stores a value no comparison can reason about:
    // invisible objects, labels reading `nan`, a level family that never matches
    // its own signature). `MathIsValidNumber` is the only test that catches it, and
    // it is here - at the ONE entry every calculating mode goes through - rather
    // than at the dozens of consumers.
    if(!MathIsValidNumber(centerPrice) || centerPrice <= 0 || stepSizeCount < 1) return 0;
    for(int s = 0; s < stepSizeCount; s++) {
        if(!MathIsValidNumber(stepSizes[s]) || stepSizes[s] <= 0) return 0;
    }
    
    int safeMaxAbove = MathMin(maxLevelsAbove, MAX_SAFE_LEVELS);
    int safeMaxBelow = MathMin(maxLevelsBelow, MAX_SAFE_LEVELS);
    if(safeMaxAbove < 1) safeMaxAbove = 1;
    if(safeMaxBelow < 1) safeMaxBelow = 1;
    
    int maxTotal = (safeMaxAbove + safeMaxBelow) * 2 + 1;
    ArrayResize(levels, maxTotal, 64);
    int count = 0;
    
    // Midpoint (always first). In SS/LS mode the short step is the zone
    // width, while the first center-to-center interval is user-selectable.
    double offset = (stepMode == LEVEL_STEP_CUMULATIVE && stepSizeCount > 1 && sslsLongFirst)
                    ? (stepSizes[1] * 0.5) : (stepSizes[0] * 0.5);
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
        // P-LEVEL-BOUND-03: the step THIS iteration advances by, so the historical
        // bound can be extended by whole rungs instead of a price guess.
        double iterStep = stepSizes[0];
        if(stepMode == LEVEL_STEP_UNIFORM) {
            price = shiftedCenter + (stepSizes[0] * logicalStep);
        } else {
            // CUMULATIVE: alternate SS/LS. The first interval is controlled
            // by sslsLongFirst; subsequent intervals alternate strictly.
            int sequenceIndex = (sslsLongFirst && stepSizeCount > 1) ? 1 : 0;
            int parity = (logicalStep - 1) % 2;
            int selectedIndex = (parity == 0) ? sequenceIndex : ((sequenceIndex + 1) % stepSizeCount);
            double dist = stepSizes[selectedIndex];
            iterStep = dist;
            cumAbove += dist;
            price = shiftedCenter + cumAbove;
        }
        
        // Price boundary check — P-LEVEL-BOUND-03: the bound is extended by
        // `P_LEVEL_BOUND_OVERDRAW` whole rungs so the chart shows where the next
        // levels WOULD be, without touching where the historical extreme is.
        if(boundByHistorical && maxPrice > 0 && price > maxPrice + P_LEVEL_BOUND_OVERDRAW * iterStep) break;
        
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
        double iterStep = stepSizes[0];
        if(stepMode == LEVEL_STEP_UNIFORM) {
            price = shiftedCenter - (stepSizes[0] * logicalStep);
        } else {
            int sequenceIndex = (sslsLongFirst && stepSizeCount > 1) ? 1 : 0;
            int parity = (logicalStep - 1) % 2;
            int selectedIndex = (parity == 0) ? sequenceIndex : ((sequenceIndex + 1) % stepSizeCount);
            double dist = stepSizes[selectedIndex];
            iterStep = dist;
            cumBelow += dist;
            price = shiftedCenter - cumBelow;
        }
        
        // Price boundary check — P-LEVEL-BOUND-03, same margin as the above side.
        if(boundByHistorical && minPrice > 0 && price < minPrice - P_LEVEL_BOUND_OVERDRAW * iterStep) break;
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

// P-LBL-12 (2026-10-17): GetLabelTextForLevel stood here. It derived the
// per-level text ("L1 +3" / "+3", "Midpoint") for the pip-distance labels
// only, and the labels themselves are retired — nothing reads the text now,
// so the whole derivation is gone rather than left computing into a dead
// field on every build.

//+------------------------------------------------------------------+
//| P-UI-131m: A BAND'S INK IS ONE PAIR, FADED EXACTLY ONCE.         |
//|                                                                  |
//| The trigger card's COLOR row could not reach the chart:           |
//| `GetTriggerRenderColor()` had already blended g_triggerColor with  |
//| g_triggerTransparency, and CreateZone blended that result AGAIN   |
//| with the MID ZONE transparency - two owners fading one band. At   |
//| the measured 43 % the band kept 8 % of the picked colour.        |
//|                                                                  |
//| So a band carries a BASE that is never pre-faded plus the opacity |
//| that owns it: card 0's TRANSPARENCY for a trigger band, the band  |
//| row on card 1 for a structure one. The EDGE derives from the same |
//| base, so the trigger card's colour reaches the surface that is    |
//| actually visible. No reader may hand CreateZone a self-faded      |
//| colour (P-UI-66's law, applied to the band).                     |
//+------------------------------------------------------------------+
color PipelineBandBaseColor(const int step, const bool triggerEnabled, const int baseMultiplier)
{
    color zc = GetZoneColorForLevel(step, triggerEnabled, baseMultiplier);
    if(zc != clrNONE) return zc;     // a structure tier owns this band's ink
    return g_triggerColor;           // the trigger family's own ink, RAW
}

int PipelineBandTransparency(const bool isTrigger, const int bandTransparency)
{
    if(!isTrigger) return bandTransparency;
    int t = (int)MathMax(0, MathMin(100, g_triggerTransparency));
    return t;
}

//+------------------------------------------------------------------+
//| STAGE 2: Classify all levels                                     |
//|                                                                  |
//| Structure/trigger identity drives ONLY the zones. ALL lines take |
//| the unified [08.4] appearance via GetLineRenderColor().          |
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
        
        // BASE PLAYER: Structure/Trigger classification.
        // The structure/trigger identity below drives ONLY the zones:
        // structure zones keep their L1-L5 colors, trigger zones keep the
        // trigger color. ALL LINES share ONE appearance (the [08.4] unified
        // line settings) regardless of family, and the trigger overlay
        // switch (inpShowTrigger / T) must NOT restyle lines here — it gates
        // only the trigger zones in RenderZones. Line visibility belongs to
        // the L switch / g_linesVisible alone, never to triggerEnabled.
        classified[i].structureLevel = GetHighestStructureLevel(step, g_cachedIntervals);
        classified[i].isStructure = (classified[i].structureLevel > 0);

        // UNIFIED LINES: every non-midpoint level draws its line with the
        // same [08.4] settings (GetLineRenderColor blends g_lineColor with
        // g_lineTransparency; style/width are inpLineStyle/inpLineWidth).
        classified[i].levelColor = GetLineRenderColor();
        classified[i].levelStyle = inpLineStyle;
        classified[i].levelWidth = inpLineWidth;
        if(!classified[i].isStructure) {
            classified[i].isTrigger = true;
        }

        // Zone color from level (zones keep their family identity). RAW - the
        // fade belongs to the row that owns it, and CreateZone does it once.
        classified[i].zoneColor = PipelineBandBaseColor(step, triggerEnabled, baseMultiplier);
    }
    
    return rawCount;
}

//+------------------------------------------------------------------+
//| STAGE 2 VARIANT: Classify with alternating fallback (SSLS)       |
//|                                                                  |
//| Lines are unified (see ClassifyLevels): every line — structure or|
//| trigger subdivision — shares the [08.4] line appearance, so there|
//| is no per-family line override here. This variant is kept for    |
//| signature compatibility and delegates to the standard classifier;|
//| the SS/LS order flag (lsFirst) still drives the step geometry in |
//| Stage 1 (CalculateLevels), and lsFirst is panel-editable.        |
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
    return ClassifyLevels(rawLevels, rawCount, config, triggerEnabled, baseMultiplier, classified);
}

//==============================================================================
// P-UI-58 — A ZONE BAND MAY NEVER REACH THE LINE FAMILY (minimum gap)
//
// The drawing architecture is: ZONES are centered ON the levels, and the visible
// LINES are drawn at the MIDPOINT between two neighbouring levels
// (`lineMidPrice = (prevPrice + currentPrice) / 2` below). That is what puts a
// line in the clear space between two bands — the "gap" — and the gap exists only
// while the band is SHORTER than half the interval: a band whose half-height
// reaches `interval / 2` touches exactly the line that belongs to it, and any
// rounding then puts the line INSIDE the band. `inpMidZoneHeightPercent` is allowed
// up to 100 (heightPercent 1.0 = the FULL step), which is that boundary case — so a
// control the user may legitimately push to its maximum silently swallows the lines
// it is supposed to sit beside.
//
// P-UI-59 — ONE INTERVAL IS NOT ENOUGH: A BAND HAS TWO NEIGHBOURS.
//
// P-UI-58 clamped a band with the interval it was BUILT from, which is only ever
// ONE of the two midpoint lines that bracket it. In SS/LS mode the two are not
// equal (the steps alternate short/long, so a level routinely has a SHORT interval
// on one side and a LONG one on the other), and a band clamped by the long side
// still reached the midpoint line of the short side. 100% height in SS/LS: the
// band half-height is `min(ss, ls) * 0.5 = ss/2` and the line in the ss interval
// sits at exactly `ss/2` — the line lands ON the band edge and renders inside it.
// That is the reported «خط میآید داخل زون». The invariant belongs to the LINE, not
// to the band: the line at `interval/2` needs the zones on BOTH of its ends to stay
// clear, so a band is clamped by the NEARER of its two intervals.
//
// The invariant is enforced where the band is BUILT, from the interval the band
// actually sits in (never from the "fixed" step, which in SS/LS mode is not the
// interval), and it keeps ZONE_MIN_GAP_RATIO of the half-interval clear. Every
// setting at or below `2 × (1 − ratio) = 80%` is pixel-identical (the factory
// default is 33%), so a chart changes only where it would otherwise violate the
// invariant. Cost: three compares, no work in the normal case.
//==============================================================================
#define ZONE_MIN_GAP_RATIO 0.20

double ClampZoneHalfHeight(const double wantedHalfHeight, const double neighbourInterval)
{
    if(!MathIsValidNumber(neighbourInterval) || neighbourInterval <= 0.0) return wantedHalfHeight;
    double ceiling = neighbourInterval * 0.5 * (1.0 - ZONE_MIN_GAP_RATIO);
    if(ceiling <= 0.0) return wantedHalfHeight;
    return (wantedHalfHeight > ceiling) ? ceiling : wantedHalfHeight;
}

// The two-sided form. `stepBelow` / `stepAbove` are the intervals on the two sides
// of the band; 0 means "no such neighbour" (the outermost level), which is not a
// constraint. Both are validated before the comparison because a NaN would make
// `stepAbove < bound` false and quietly drop the real constraint (P-UI-57).
double ClampZoneHalfHeightBoth(const double wantedHalfHeight,
                               const double stepBelow,
                               const double stepAbove)
{
    double bound = 0.0;
    if(MathIsValidNumber(stepBelow) && stepBelow > 0.0) bound = stepBelow;
    if(MathIsValidNumber(stepAbove) && stepAbove > 0.0 &&
       (bound <= 0.0 || stepAbove < bound)) bound = stepAbove;
    return ClampZoneHalfHeight(wantedHalfHeight, bound);
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
    const double fixedZoneStepSize,
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
    
    // Single pass: count AND collect simultaneously — and COMPACT.
    // P-UI-59: a level that does not ADVANCE the sequence (a duplicate price, or a
    // non-ordered one) used to be skipped by a `continue` INSIDE each build loop,
    // which left that loop's `prevPrice` pointing at the skipped level and made "the
    // level after this one" unknowable without a forward scan. Dropping it here
    // instead leaves s_aboveLevels strictly ascending and s_belowLevels strictly
    // descending, so i-1 / i+1 ARE the two neighbours of level i — which is exactly
    // what the two-sided gap clamp needs. Same arrays, still one pass, and the build
    // loops lose a branch each.
    int aboveCount = 0, belowCount = 0;
    for(int i = 0; i < classifiedCount; i++) {
        if(classified[i].isMidpoint) { hasMid = true; midLevel = classified[i]; continue; }
        double price = classified[i].price;
        if(!MathIsValidNumber(price) || price <= 0.0) continue;   // P-UI-57: never carry a non-finite price
        if(classified[i].direction > 0) {
            if(aboveCount > 0 && price <= s_aboveLevels[aboveCount - 1].price) continue;
            s_aboveLevels[aboveCount] = classified[i]; aboveCount++;
        } else if(classified[i].direction < 0) {
            if(belowCount > 0 && price >= s_belowLevels[belowCount - 1].price) continue;
            s_belowLevels[belowCount] = classified[i]; belowCount++;
        }
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
        if(neighborDist <= 0) {   // P-BE-02: the point size is 0 until the contract data loads
            double p = GetCachedPoint();
            neighborDist = p > 0 ? p * 100 : midLevel.price * 0.001;   // ...so the product was 0 -> an invisible zone
        }
        double zoneStepSize = (fixedZoneStepSize > 0) ? fixedZoneStepSize : neighborDist;
        // P-UI-58/59: `neighborDist` IS the nearer of the two neighbour intervals,
        // so this call already is the two-sided clamp the siblings below need — the
        // midpoint line above/below the centre zone is what must stay clear.
        double zoneHeight = ClampZoneHalfHeight(zoneStepSize * config.zoneHeightPercent * 0.5,
                                                neighborDist);
        
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
        zones[zIdx].filled  = (config.zoneStyle != ZONE_STYLE_BOX_EMPTY);     // P-UI-62
        zones[zIdx].outline = (config.zoneStyle != ZONE_STYLE_BOX_FILLED);    // P-UI-62
        zIdx++;
    }
    
    // --- ABOVE DIRECTION: zones on levels + lines between them ---
    double prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < aboveCount && prevPrice > 0; i++) {
        double currentPrice = s_aboveLevels[i].price;
        double stepSize = currentPrice - prevPrice;
        if(stepSize <= 0) { prevPrice = currentPrice; continue; }   // P-UI-59: cannot fire on a compacted array
        // P-UI-59: the interval ABOVE this level — the second line this band has to
        // stay clear of. 0 = this is the outermost level, so there is no line there.
        double stepAbove = (i + 1 < aboveCount) ? (s_aboveLevels[i + 1].price - currentPrice) : 0.0;
        // In SS/LS mode every zone uses the configured short-step width,
        // regardless of whether this interval is SS or LS.
        double zoneStepSize = (fixedZoneStepSize > 0) ? fixedZoneStepSize : stepSize;
        
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
        lines[lIdx].tooltip = "Midpoint +" + IntegerToString(s_aboveLevels[i].logicalStep) + 
            " (" + DoubleToString(lineMidPrice, GetCachedDigits()) + ")";
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lIdx++;
        
        // Zone centered on this level
        if(config.zonesEnabled) {
            // P-UI-58/59: the midpoint line below this level is `stepSize / 2` away and
            // the one ABOVE it is `stepAbove / 2` — the band must fit under the NEARER.
            double zoneHeight = ClampZoneHalfHeightBoth(zoneStepSize * config.zoneHeightPercent * 0.5,
                                                        stepSize, stepAbove);
            
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
            zones[zIdx].filled  = (config.zoneStyle != ZONE_STYLE_BOX_EMPTY);     // P-UI-62
            zones[zIdx].outline = (config.zoneStyle != ZONE_STYLE_BOX_FILLED);    // P-UI-62
            zIdx++;
        }
        
        prevPrice = currentPrice;
    }
    
    // --- BELOW DIRECTION: zones on levels + lines between them ---
    prevPrice = hasMid ? midLevel.price : 0;
    for(int i = 0; i < belowCount && prevPrice > 0; i++) {
        double currentPrice = s_belowLevels[i].price;
        double stepSize = prevPrice - currentPrice;
        if(stepSize <= 0) { prevPrice = currentPrice; continue; }   // P-UI-59: cannot fire on a compacted array
        // P-UI-59: the interval BELOW this level (0 = outermost level, no line there).
        double stepBelow = (i + 1 < belowCount) ? (currentPrice - s_belowLevels[i + 1].price) : 0.0;
        // In SS/LS mode every zone uses the configured short-step width.
        double zoneStepSize = (fixedZoneStepSize > 0) ? fixedZoneStepSize : stepSize;
        
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
        lines[lIdx].tooltip = "Midpoint -" + IntegerToString(s_belowLevels[i].logicalStep) + 
            " (" + DoubleToString(lineMidPrice, GetCachedDigits()) + ")";
        lines[lIdx].isMidpoint = false;
        lines[lIdx].setBack = config.useObjPropBack;
        lines[lIdx].zOrder = config.zOrder;
        lIdx++;
        
        // Zone centered on this level
        if(config.zonesEnabled) {
            // P-UI-58/59: same invariant as the Above branch, both neighbours
            // (`stepSize` is the interval above this level here, `stepBelow` the one below).
            double zoneHeight = ClampZoneHalfHeightBoth(zoneStepSize * config.zoneHeightPercent * 0.5,
                                                        stepBelow, stepSize);
            
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
            zones[zIdx].filled  = (config.zoneStyle != ZONE_STYLE_BOX_EMPTY);     // P-UI-62
            zones[zIdx].outline = (config.zoneStyle != ZONE_STYLE_BOX_FILLED);    // P-UI-62
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
// Returns true only when a real mask WRITE reached the chart (P-PERF-32b: the
// family walks report their cost as a number, and a guarded no-op is not a write).
bool SetPipelineObjectTimeframesIfExists(const string name, const long timeframes)
{
    // PERF FIX: Check object cache first to skip ObjectFind MT4 syscall when object is known absent.
    // ObjectFind is a slow kernel call; using CacheObjectExists avoids it for untracked names.
    // Fall back to ObjectFind only when cache has no info (returns false = not in cache).
    //
    // P-PERF-02: and the WRITE itself is guarded — this function is called for
    // every line, label and zone on EVERY heavy frame, so an unconditional
    // ObjectSetInteger here was the single largest write source on the chart
    // (hundreds of writes per frame for masks that had not changed).
    bool knownInCache = CacheObjectExists(name);
    if(knownInCache) {
        return ApplyTfMaskGuarded(name, timeframes);
    }
    // P-PERF-07: the ObjectFind fallback is a terminal call, and this function
    // is reached 7x per ZONE plus once per LINE and once per LABEL of every
    // level — including the CULLED ones, which were never created and so can
    // never enter the main cache. Without a negative cache that fallback ran
    // for every culled level on every heavy frame (~2.6k probes/frame at
    // inpMaxLevels=144), each scanning a chart holding thousands of objects.
    // A name already proven absent on this chart costs one hash instead.
    if(CacheIsAbsentKnown(name)) return false;
    // Not in cache — check chart directly (only for sub-objects like _Top, _Bottom, _B_*)
    if(ObjectFind(0, name) >= 0) {
        CacheForgetAbsent(name);
        return ApplyTfMaskGuarded(name, timeframes);
    }
    CacheMarkAbsent(name);
    return false;
}

// Returns the number of masks that actually reached the chart (0..7).
// P-PERF-32b: the trigger family's press-time walk (TriggerFamilyWalk) and the
// render share THIS writer, so the two can never disagree about which objects a
// zone is made of or which of them L owns.
int SetPipelineZoneVisibility(const string zoneName, const bool visible)
{
    // FIX: The L key controls only the zone boundary LINES (_Top/_Bottom).
    // The box object itself (rectangle or empty-box borders) is never
    // affected by L - only by F.
    // P-PERF-02: 7 guarded writes per zone per heavy frame — free when the
    // zone's visibility did not change (the common case by far).
    long tfAll = (visible && !IsIndicatorHidden()) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    long tfLine = (visible && !IsIndicatorHidden() && GetCachedLinesVisible()) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    int wrote = 0;
    if(SetPipelineObjectTimeframesIfExists(zoneName, tfAll)) wrote++;
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_Top", tfLine)) wrote++;
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_Bottom", tfLine)) wrote++;
    // Empty-box border segments follow the box itself (F key)
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_B_Top", tfAll)) wrote++;
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_B_Bottom", tfAll)) wrote++;
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_B_Left", tfAll)) wrote++;
    if(SetPipelineObjectTimeframesIfExists(zoneName + "_B_Right", tfAll)) wrote++;
    return wrote;
}

void RenderZones(
    const SZoneDefinition &zones[],
    const int zoneCount,
    const SModeConfig &config)
{
    // P-PERF-41: THE FAMILY SWITCH IS A MASK, NOT A DESTRUCTION.
    //
    // The mid-zone family used to be turned off by DELETING it (the cleanup walk
    // started at 0 when `zonesEnabled` was false) and turned back on by
    // RE-CREATING it: ~7 terminal calls per zone per direction for a switch that
    // moves no price and no geometry. That is why turning zones on/off was slow
    // and fragile next to F, which has always been a mask.
    //
    // A hidden object costs nothing to draw (MT4 culls it before rasterising)
    // and the guarded writer behind VisibilityZoneMask makes a repeat call free,
    // so OFF is now the SAME change L makes - one mask per object - over EVERY
    // zone object the cache knows, with zero index assumptions and zero
    // ObjectFind probes. The owner lives in VisibilityManager because the F show
    // path writes the same masks and the two must agree (P-PERF-41 there).
#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): the canvas family hides as ONE layer mask -
    // the object path's per-object walk has nothing to walk here. P-PERF-117:
    // the staging below is unreachable while the family is off, so the recs
    // age from this very pass on - the MID ZONES press must know before it
    // shows them again.
    if(!config.zonesEnabled && RBridgeActive()) { RBridgeZoneFamilyMask(false); RBridgeZonesMarkStale(); return; }
#endif
    if(!config.zonesEnabled) { HideAllZoneFamilyObjects(); return; }

    bool triggerEnabled = IsTriggerLevelsEnabled();

#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): the zone family stages onto the canvas's
    // BACK layer. The object path's own decisions are mirrored one for one:
    //   * the thin-zone pixel guard SKIPS the zone (the object path masks the
    //     whole family) - re-decided by the next render that sees the scale;
    //   * the trigger overlay is the rec's `visible` (never a stale masked
    //     object - the rec always carries the build's live geometry);
    //   * the `_B_Left` vertical edge is not drawn (documented divergence:
    //     it stands at the oldest bar, off-screen until the user scrolls to
    //     the start of history).
    // The ink (fill + edge tones) is computed by the bridge through the same
    // helpers CreateZone multiplies, so the two paths cannot bake two pictures.
    if(RBridgeActive())
    {
        static string s_znWit = "";
        string znWit = IntegerToString(config.zonesEnabled ? 1 : 0) + ":" +
                       IntegerToString(zoneCount) + ":" +
                       IntegerToString(RBridgeZonesStale() ? 1 : 0);
        if(znWit != s_znWit) {
            s_znWit = znWit;
            _LOG_GATE_W Print("[P-ZN] RenderZones en=", (config.zonesEnabled ? 1 : 0),
                  " zones=", zoneCount, " stale=", (RBridgeZonesStale() ? 1 : 0));
        }
        RBridgeZoneFamilyMask(true);
        RBridgeZonesBegin();

        double rbPxPerPrice = 0.0;
        {
            int    rbH    = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
            double rbPmax = ChartGetDouble(0, CHART_PRICE_MAX);
            double rbPmin = ChartGetDouble(0, CHART_PRICE_MIN);
            if(rbH > 0 && rbPmax > 0 && rbPmin > 0 && rbPmax > rbPmin)
                rbPxPerPrice = (double)rbH / (rbPmax - rbPmin);
        }

        for(int i = 0; i < zoneCount; i++)
        {
            if(rbPxPerPrice > 0.0 &&
               (zones[i].renderTop - zones[i].renderBottom) * rbPxPerPrice < P_P4_MIN_ZONE_PX)
                continue;
            if(zones[i].renderTop <= zones[i].renderBottom) continue;
            if(zones[i].renderTop <= 0 || zones[i].renderBottom <= 0) continue;
            bool triggerHidden = (zones[i].isTrigger && !triggerEnabled);
            RBridgeZone(zones[i].name, zones[i].renderTop, zones[i].renderBottom,
                        zones[i].zoneColor, zones[i].isTrigger, !triggerHidden,
                        zones[i].filled, zones[i].outline);
        }
        RBridgeZonesCommit();
        return;
    }
#endif

    // P-PERF-04 PIXEL AWARENESS: a zone is a full-chart-width FILL, the most
    // expensive thing this indicator paints and the reason a zoomed-out chart
    // crawls — MT4 must rasterise every one of them on every repaint even when
    // a zone is a hairline tall and shows nothing the level line does not
    // already show. Measure the price->pixel scale ONCE per render and hide
    // any zone thinner than P_P4_MIN_ZONE_PX (hiding is what this loop already
    // does for off-screen zones, so it is stateless: zooming back in redraws).
    double p4PxPerPrice = 0.0;
    {
        int    p4H    = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
        double p4Pmax = ChartGetDouble(0, CHART_PRICE_MAX);
        double p4Pmin = ChartGetDouble(0, CHART_PRICE_MIN);
        if(p4H > 0 && p4Pmax > 0 && p4Pmin > 0 && p4Pmax > p4Pmin)
            p4PxPerPrice = (double)p4H / (p4Pmax - p4Pmin);
    }

    for(int i = 0; i < zoneCount; i++) {
        // P-VIEW-01 (2026-09-29) — THE CULL DECIDES PAINT, THE VIEWPORT NEVER OWNS
        // VISIBILITY. It used to write `SetPipelineZoneVisibility(name,false)` here,
        // i.e. the window HID the band — and a hidden object is only shown again by
        // the frame that re-decides it. Measured: the cull window is allowed to lag
        // the chart by P_P4_VP_HYSTERESIS_PCT 0.20 of the visible range (the macro,
        // the function and the window-as-key-term were all retired by P-VIEW-05,
        // 2026-10-16), so a band the price walked up to stayed
        // HIDDEN until some other input forced a rebuild — the report «سطوح حذف
        // میشه ولی دیگه نمیاد تا یک تکونی به چارت بدم». Now the band is asserted with
        // the SAME mask the in-window path asserts (F/L alone own it, read-guarded by
        // ApplyTfMaskGuarded: zero writes in steady state) and simply not painted this
        // frame. MT4 draws an object it already holds at its own paint time, so the
        // band is there BEFORE the user scrolls to it — the only allocation this
        // costs is MT4's own clipping, not an indicator write.
        // P-VIEW-03 (2026-09-29): the window no longer skips a band here either —
        // see the same law and the same MEASURED band (EURUSD M15: 1.11520..1.15185
        // missing between two drawn groups) at RenderTriggerLines below. A band that
        // is only \"not painted this frame\" is a band that can stay unpainted forever,
        // because nothing else re-decides it. The thin-zone guard below stays: it is
        // re-decided by the same frame that sees the scale change.

        if(p4PxPerPrice > 0.0 &&
           (zones[i].renderTop - zones[i].renderBottom) * p4PxPerPrice < P_P4_MIN_ZONE_PX)
        {
            SetPipelineZoneVisibility(zones[i].name, false);
            continue;
        }

        // P-UI-62: there is deliberately NO `ZONE_STYLE_HIDDEN` branch here any more.
        // "Are zones drawn at all?" belongs to the MID ZONES master switch (the zone
        // family mask), and a second owner for it - a style value that DELETES the
        // family - is exactly what the card's third pill used to be: the user could
        // see two controls claiming to do the same thing, and they disagreed.
        
        // P-PERF-32b — THE TRIGGER OVERLAY IS A MASK, NOT A DESTRUCTION.
        //
        // This branch used to DELETE the band (and the F-show path's blanket
        // ALL_PERIODS was the reason it had to: a trigger band and a structure
        // band are the same `_Zone_` names, so a hidden trigger band would have
        // been re-shown by an F press - the flicker this delete existed to
        // prevent).
        //
        // What the delete could not survive is the LATENCY: the T toggle, the
        // ring's TRIGGER light and the card's SHOW row all flipped the switch
        // and then asked the RENDER for the pixels ("سطح تریگر دیر خاموش و روشن
        // میشه"), because a deleted band leaves the ON direction nothing to
        // show without a full family render. The structure switches (card 11,
        // P-PERF-32) have painted in their own event since they were fixed:
        // state + a walk over the objects + a discrete repaint.
        //
        // So the family is a MASK now, exactly like the mid-zone family
        // (P-PERF-41) and the unified lines (P-PERF-25): the band stays as a
        // hidden object and OFF/ON is one guarded mask per object, written by
        // the SAME `SetPipelineZoneVisibility` the press-time walk calls
        // (TriggerFamilyWalk, LevelPipe_B). A later render asserts the live
        // switch here and changes no pixel - and the F-show corner is closed at
        // the source: `ApplyHideAllState` re-asserts this family through its own
        // owner, in the same event.
        //
        // Cost: while the overlay is OFF the bands exist as masked objects
        // (MT4 culls a masked object before rasterising) - the same trade
        // P-PERF-41 made for the zone family, and what P-PERF-04's thin-zone
        // guard already does with a single band.
        //
        // AND HIDDEN, BUT NEVER STALE. The ON press paints from these very
        // objects (its walk writes masks, not geometry), so a band left at the
        // previous centre would flash at the old price for a frame - exactly the
        // class P-VIEW-01/03 refuse. The test is this list's own first guard, read
        // from the cache (the top price we last WROTE vs the top this geometry
        // gives): on a match the band is masked and skipped (seven guarded masks,
        // zero terminal calls); on a miss it falls through to the ONE creator
        // below, which updates it in place - still masked. That same fall-through
        // is what MATERIALISES the family while the overlay is off (the first
        // render after attach creates it), so the first ON press is a mask flip
        // too, exactly like a structure switch.
        bool triggerHidden = (zones[i].isTrigger && !triggerEnabled);
        if(triggerHidden) {
            SObjectCacheEntry trigEntry;
            if(CacheGetObject(zones[i].name, trigEntry) &&
               MathAbs(trigEntry.lastPrice - zones[i].renderTop) <= GetCachedPoint() * 0.1) {
                SetPipelineZoneVisibility(zones[i].name, false);
                // P-KEY-PROBE: only while a T press is outstanding (one int read per
                // band in the steady state would be the cost this project refuses).
                if(g_triggerPressMs != 0) g_triggerPressHidden++;
                continue;
            }
        }
        // P-KEY-PROBE: the bands this render reaches for the toggle (the show
        // direction pays these; the hide direction pays the masks above).
        if(zones[i].isTrigger && g_triggerPressMs != 0) g_triggerPressReached++;
        
        if(zones[i].renderTop <= zones[i].renderBottom) continue;
        
        {
            // P-UI-62: the two halves of the picture, transmitted as TWO flags.
            // `filled` = the band, `outline` = its edge (three segments), and each is
            // independent - so FILLED, EMPTY and OUTLINED are three real pictures and
            // the BORDER / BORDER WIDTH settings apply wherever an edge is drawn.
            SZoneCreationRequest request = ZoneRequestNew();   // P-UI-131h
            request.name = zones[i].name;
            request.topPrice = zones[i].renderTop;
            request.bottomPrice = zones[i].renderBottom;
            request.zoneColor = zones[i].zoneColor;
            // P-UI-131m: the band's OWN opacity, read live next to the border rows
            // below - a trigger band is faded by card 0's TRANSPARENCY, a structure
            // band by the band row on card 1. The BASE colour above is unfaded, so
            // this is the one fade (the double blend it replaces left a trigger band
            // at 8 % of the picked colour at 43 %).
            request.transparency = PipelineBandTransparency(zones[i].isTrigger, zones[i].transparency);
            request.filled = zones[i].filled;
            request.outline = zones[i].outline;
            request.borderStyle = inpMidZoneBorderStyle;
            request.borderWidth = inpMidZoneBorderWidth;
            // P-UI-63: the edge's OWN transparency - the two halves of the picture fade
            // independently, and both values are read here (next to the border style and
            // width they belong with) rather than threaded through the zone definition.
            request.borderTransparency = inpMidZoneBorderTransparency;
            // P-UI-131h: the two halves' own surfaces, read here with the three rows
            // above. AUTO (clrNONE / -1) is the factory state, so this changes nothing
            // until a row is touched.
            request.borderTopColor = inpZoneEdgeTopColor;
            request.borderBottomColor = inpZoneEdgeBottomColor;
            request.borderTopTransparency = inpZoneEdgeTopTransparency;
            request.borderBottomTransparency = inpZoneEdgeBottomTransparency;
            request.startTime = 0;
            request.endTime = 0;
            
            CreateZone(request);
            // P-PERF-32b: a band whose overlay is OFF is created/updated in place
            // and stays MASKED - the render never shows what the switch turned off.
            SetPipelineZoneVisibility(zones[i].name, !triggerHidden);
        }
    }
}

//+------------------------------------------------------------------+
//| P-PERF-32: STRUCTURE RECOLOUR WALK -- the toggle paints, nothing  |
//| recomputes.                                                      |
//|                                                                  |
//| A structure switch (master / L1-L5, card 11) changes NO geometry: |
//| the level SET is switch-invariant (ClassifyLevels always builds   |
//| every step; the switches only choose zone colours via              |
//| PipelineBandBaseColor, exactly as ClassifyLevels does).           |
//| Re-deriving the whole level                                        |
//| family to repaint a few hundred zone colours is what made the     |
//| switch feel dead on a weak PC. So the switch never reaches the    |
//| render: this walk rewrites the blended colour of every cached     |
//| zone object whose live colour moved, and nothing else. Lines are  |
//| unified (switch-free), Center zones wear the mode colour, HTF/BK/ |
//| labels carry no "_Zone_" -- none of them is visited. Filled/empty  |
//| shape is toggle-invariant, so entries that do not exist (culled   |
//| zones, migrated-away rects/borders) are skipped, never created: a |
//| zone scrolled back into view is created later with live switches. |
//| The geometry key keeps the switch terms, so any LATER real render |
//| recomputes with live switches -- the walk can never desync it.     |
//+------------------------------------------------------------------+
// Tail step of a pipeline zone object name: "<pfx><mode>_Zone_Above_12"
// (or _Below_), with one optional border/legacy sub-suffix. Returns the
// step, or <= 0 when the name carries none (Center, foreign, malformed).
int StructureZoneStepFromName(const string nm)
{
    string base = nm;
    int blen = StringLen(base);
    // Longer sub-suffixes first: "_B_Bottom" ends with "_Bottom".
    if(blen > 9 && StringSubstr(base, blen - 9, 9) == "_B_Bottom") base = StringSubstr(base, 0, blen - 9);
    else if(blen > 8 && StringSubstr(base, blen - 8, 8) == "_B_Right") base = StringSubstr(base, 0, blen - 8);
    else if(blen > 7 && StringSubstr(base, blen - 7, 7) == "_B_Left") base = StringSubstr(base, 0, blen - 7);
    else if(blen > 7 && StringSubstr(base, blen - 7, 7) == "_Bottom") base = StringSubstr(base, 0, blen - 7);
    else if(blen > 6 && StringSubstr(base, blen - 6, 6) == "_B_Top") base = StringSubstr(base, 0, blen - 6);
    else if(blen > 4 && StringSubstr(base, blen - 4, 4) == "_Top") base = StringSubstr(base, 0, blen - 4);
    int ulen = StringLen(base);
    int sep = ulen - 1;
    while(sep >= 0 && StringGetCharacter(base, (ushort)sep) != '_') sep--;
    if(sep < 0 || sep + 1 >= ulen) return 0;
    return (int)StringToInteger(StringSubstr(base, sep + 1));
}

// Returns the number of colour writes issued.
int StructureRecolourWalk()
{
#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): object-free recolour - the bridge reads the
    // same switches and re-bakes the recs' ink through the same helpers.
    if(RBridgeActive()) return RBridgeZoneRecolour();
#endif
    // Same inputs ClassifyLevels (lines 395-400) reads: the walk repaints
    // exactly what a recompute would have stored.
    bool trigOn = IsTriggerLevelsEnabled();
    int baseMult = GetValidatedBaseMultiplier();
    int tr = inpMidZoneTransparency;
    if(tr < 0) tr = 0;
    if(tr > 100) tr = 100;

    int touched = 0;
    int visited = 0;
    for(int i = 0; i < CACHE_HASH_BUCKETS && visited < g_objectCacheSize; i++)
    {
        if(!g_objectCacheHash[i].occupied) continue;
        visited++;
        // P-UI-62: a dead slot is not "nothing painted under this name" - it is a name
        // this chart does not carry at all, and the colour it holds belongs to a
        // PICTURE (the edge-only zone), not to an object. Repainting it would be a
        // terminal write the terminal drops on the floor.
        if(!CacheSlotIsLive(i)) continue;
        const string nm = g_objectCacheHash[i].name;
        if(StringFind(nm, "_Zone_") < 0) continue;         // lines/labels/HTF
        if(StringFind(nm, "_Zone_Center_") >= 0) continue; // mode colour, not structure
        if(StringFind(nm, "_BK_") >= 0) continue;          // independent layer
        int step = StructureZoneStepFromName(nm);
        if(step <= 0) continue;
        // P-UI-131m: the walk repaints through the SAME two owners the paint path
        // uses, or a structure switch would write a trigger band a colour the
        // render never produces (it used to blend the mid-zone transparency into a
        // base that was already faded).
        bool isTrig = (GetHighestStructureLevel(step, g_cachedIntervals) <= 0);
        color zc = PipelineBandBaseColor(step, trigOn, baseMult);
        color want = GetZoneRenderColor(zc, PipelineBandTransparency(isTrig, tr));
        color have = clrNONE;
        if(!CacheGetColor(nm, have)) continue;   // nothing painted under this name
        if(have == want) continue;
        if(!ObjectSetInteger(0, nm, OBJPROP_COLOR, want)) continue;
        CacheSetColor(nm, want);
        touched++;
    }
    return touched;
}

//+------------------------------------------------------------------+
//| STAGE 5b: Render trigger lines (SECOND   derived from zones)     |
//|                                                                  |
//| Creates/updates MT5 horizontal line objects.                     |
//| Uses CreateOrUpdateHLine for consistency.                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| P-UI-98: THE STEP-1 HANDLE'S FACE AND ITS MARKER.                 |
//|                                                                   |
//| In custom-price start-point mode the two rung-1 trigger lines are |
//| the user's step handle: while ARMED they are SELECTABLE (MT4's    |
//| own drag moves them), they sit at a z-order above the zone fills  |
//| (a zone rectangle under the cursor would otherwise eat the grab — |
//| the reported «الان step اول قابل درگ کردن نیستش»), and ONE small  |
//| red dot at the chart's right edge (time 0 — the anchoring the pip  |
//| labels used before their retirement, so it follows the market with |
//| no per-bar write) marks them. The user's marker order:             |
//| «خط کاستوم پرایس ... نشانه سبز و                                   |
//| step اول ... نشانه قرمز ... یک نشانه باشه که خیلی مزاحم هم نباشه» |
//| and «وقتی لاین ها رو خاموش میکنم نشان ها هم نباشه» — the dot      |
//| wears the line family's mask, so the L switch owns it with the    |
//| lines.                                                            |
//|                                                                   |
//| SET (the click-to-commit model, P-UI-98d): a set handle is not    |
//| selectable, its dot is gone, and the marker object is DELETED —   |
//| not masked — so no other mask writer can resurrect it. The       |
//| armed/set pair is owned HERE in the refresh path, so a state that |
//| changed under the chart is re-owned on the next render. Guarded:  |
//| one read per line per frame, a write only on drift (the perf law).|
//+------------------------------------------------------------------+
void Step1HandleOwnFace(const string name, const double price, const int direction,
                        const long lineTf, const string naturalTip)
{
    bool draggable = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) && g_s1LinesArmed;
    // P-UI-98e: WHILE OUR OWN CARRY OWNS THIS LINE, THE FLAG IS BORROWED.
    // P-LM-21 learned it on the leg metre: MT4 re-arms its own per-object drag on
    // every paint for as long as SELECTABLE sits on the object, so the line fights
    // the hand and the gesture «سریع قطع میشه». The face owner must not re-arm
    // what the gesture took, and the selection face it would otherwise drop
    // mid-drag stays (that is the separate property the borrow leaves alone).
    bool dragOwnsThis = (g_s1DragLive && g_s1DragName == name);
    if(!dragOwnsThis)
    {
        bool current = (bool)ObjectGetInteger(0, name, OBJPROP_SELECTABLE);
        if(current != draggable)
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, draggable);
        if(!draggable && (bool)ObjectGetInteger(0, name, OBJPROP_SELECTED))
            ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    }
    // P-UI-31's rule: the rung is NOT read back (the zorder audit bans
    // OBJPROP_ZORDER reads in product code - a diagnostic, not a product
    // question) and it is not re-decided either: the handle's one rung is
    // Z_CHART_LABEL, spelled here and nowhere else.
    ObjectSetInteger(0, name, OBJPROP_ZORDER, Z_CHART_LABEL);
    // P-UI-98g: an armed handle whose circle is not up yet asks for the click.
    string tip = draggable
        ? (g_s1HandleShown
           ? "[STEP 1] Drag the red handle to set the ladder step - click to commit, double-click re-arms"
           : "[STEP 1] Click it to bring up the red handle")
        : naturalTip;
    if(tip != "" && ObjectGetString(0, name, OBJPROP_TOOLTIP) != tip)
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);

    // the drag handle: ONE circular icon (S1_HANDLE_RES), centred on the line
    // at the screen's horizontal middle; a SET or hidden handle PARKS it
    // off-window (nothing can grab a set line, so nothing points at it either).
    // The name AND the price are stashed for the grab hit test and the ride
    // channels (P-UI-98e): the press edge must name the line it claims, and the
    // carry needs the object to move.
    // P-UI-98e: the rung-1 line's own NAME and PRICE are stashed whenever the
    // line is THERE — not only while it is draggable. A SET handle stays
    // CLICKABLE: the double-click that re-arms it has to find the row it names,
    // and the click's hit test reads this very stash. What a SET handle LOSES is
    // the icon (parked below), never the address — and the icon itself is placed
    // only while the pair is armed (HandsetMarkersRide obeys the same term).
    bool addressable = (price > 0.0) && MathIsValidNumber(price) && !IsIndicatorHidden();
    if(addressable) g_s1MarkPeriod = Period();   // P-UI-98e: the stash's own timeframe
    if(direction > 0) { g_s1MarkAbovePrice = addressable ? price : 0.0; g_s1MarkAboveName = addressable ? name : ""; }
    else              { g_s1MarkBelowPrice = addressable ? price : 0.0; g_s1MarkBelowName = addressable ? name : ""; }
    string mark = S1MarkName(direction);
    // P-UI-98g: the RED circle is painted on request too («فقط وقتی روش کلیک
    // کردیم دایره ها بیاد برای درگ کردن») — `g_s1HandleShown` is what the click
    // on the line sets, and a SET or unasked pair keeps the circle parked.
    if(!draggable || !g_s1HandleShown || !(price > 0.0) || !MathIsValidNumber(price) ||
       IsIndicatorHidden() || !g_linesVisible)
    {
        HandsetHandlePark(mark, S1_HANDLE_RES);
        return;
    }
    HandsetHandleAt(mark, price, S1_HANDLE_RES);
}

//+------------------------------------------------------------------+
//| P-UI-98f: WHICH LINE WEARS THE STEP-1 HANDLE (2026-09-22).        |
//|                                                                   |
//| Reported: «استپ اول که کلیک میکنم دوتا فعال میشه ... اون قرمز    |
//| خیلی نزدیک کاستوم پرایس نباید باشه». The old rule was             |
//| `logicalStep == 1` — the LADDER's rung 1, which is not the line    |
//| one STEP away from the custom price. Trigger lines are drawn at    |
//| the MIDPOINT of each pair of neighbouring levels, and the custom   |
//| price line is a zone EDGE (the ladder's centre sits half a step    |
//| above it, P-UI-98's `shiftedCenter`), so the drawn family is:      |
//|                                                                   |
//|     above:  start + 1*step, + 2*step, + 3*step ...  (= _Above_1)   |
//|     below:  start + 0*step, - 1*step, - 2*step ...  (= _Below_2)   |
//|                                                                   |
//| `_Below_1` is the boundary between the centre zone and the first   |
//| below zone: it is drawn ON the custom price line, so its red icon  |
//| landed exactly under the custom price line's green one - the two   |
//| reds the user saw, one of them «خیلی نزدیک». And the drag math     |
//| (`newFirst = |dragged - start| / natural`, the ONE owner in        |
//| EventHandlers) only reads correctly for a line that IS one step    |
//| from the start: on the coincident line it read 0 at rest and any   |
//| hair of a downward move collapsed the whole ladder to a fraction   |
//| of a step - «step اول سریع قطع میشه».                             |
//|                                                                   |
//| So the handle is picked by GEOMETRY, never by rung number: on each |
//| side, the drawn trigger line nearest ONE STEP from the custom      |
//| price line, and never a line closer than half a step to it (the    |
//| coincident boundary can never carry a handle - nothing may be      |
//| grabbed on top of the custom price line's own handle). The step is |
//| the project's ONE owner of "the current step", F x the F-free       |
//| natural first step the mode factory noted, so the pick is          |
//| invariant under the override: F scales every line and the step     |
//| together, and the same two lines stay the handle (a drag can       |
//| never hand the gesture to a different line mid-flight).            |
//+------------------------------------------------------------------+
void Step1HandlePick(const STriggerLine &lines[], const int lineCount,
                     const double anchor, const double stepNow,
                     string &aboveName, string &belowName)
{
    aboveName = "";
    belowName = "";
    if(!(anchor > 0.0) || !(stepNow > 0.0)) return;   // no step known = no handle
    double bestAbove = 0.0, bestBelow = 0.0;
    for(int i = 0; i < lineCount; i++)
    {
        if(lines[i].isMidpoint) continue;
        if(!(lines[i].price > 0.0) || !MathIsValidNumber(lines[i].price)) continue;
        double dist = MathAbs(lines[i].price - anchor);
        if(dist < stepNow * 0.5) continue;             // on the anchor: never a handle
        double err = MathAbs(dist - stepNow);          // how far from ONE step
        if(lines[i].direction > 0)
        {
            if(aboveName == "" || err < bestAbove)
            { bestAbove = err; aboveName = lines[i].name; }
        }
        else
        {
            if(belowName == "" || err < bestBelow)
            { bestBelow = err; belowName = lines[i].name; }
        }
    }
}

// P-LBL-12 (2026-10-17): P-UI-131j's `GetTriggerLabelRenderColor` stood here
// - the AUTO-aware blend feeding the trigger lines' pip labels. The labels
// are retired, so the getter had no reader; `g_triggerLabelColor` and
// `g_triggerLabelTransparency` stay persisted and inert, exactly like the
// MIDPOINT setting before them (P-UI-47), and their card rows are off the
// display (see BiotakPanels PnlSpec).

void RenderTriggerLines(
    const STriggerLine &lines[],
    const int lineCount,
    const SModeConfig &config,
    const bool makeLines)
{
    // P-UI-98f: the step-1 handle is picked by GEOMETRY once per render (the
    // line one step from the custom price on each side - see Step1HandlePick),
    // so the face owner below is reached by the same pair the click and drag
    // channels will answer, in every start-point mode (the owner itself makes
    // the handle grabbable in the custom-price mode only).
    string s1AboveName = "", s1BelowName = "";
    Step1HandlePick(lines, lineCount, GetMidpointPrice(g_thStartPointType),
                    StepOverrideFactor() * NaturalFirstStep(),
                    s1AboveName, s1BelowName);

    // P-UI-66: THE LOOK IS A PAINT PROPERTY. `lines[].clr/lineStyle/lineWidth`
    // are the BUILD's copy of the unified [08.4] look, and they are only correct
    // in the frame that rebuilt the geometry (see PipelineGeometryKey). Painting
    // from them is what made the Lines card's WIDTH and STYLE rows dead: the
    // panel wrote the global, the key stayed equal, the cache served the old
    // array, and the old array painted the old look.
    //
    // Read once per pass - `GetLineRenderColor()` is change-cached internally,
    // and every writer below is already change-guarded against the object cache
    // (`CreateOrUpdateHLine` compares colour/style/width before it writes), so a
    // steady frame still costs zero terminal calls for an unchanged look.
    color           lineClr   = GetLineRenderColor();
    ENUM_LINE_STYLE lineStyle = inpLineStyle;
    int             lineWidth = inpLineWidth;

#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): the canvas staging prelude. When the engine
    // owns the ladder, this pass is diff-committed to the scene instead of the
    // terminal; pins (the step-1 handle pair + a live drag) stay object-owned.
    // See Engine\RenderBridge.mqh. P-LBL-12 (2026-10-17): the second flag is a
    // fixed false — the product stages no label texts since the pip-distance
    // labels retired, so the bridge's text family stays empty by construction.
    if(RBridgeActive())
    {
        RBridgePinsBegin(s1AboveName, s1BelowName, g_s1DragLive ? g_s1DragName : "");
        RBridgeBegin(makeLines, false);
    }
#endif

    // P-PERF-03: record the level prices in the pass that already has them in
    // hand. CheckAlerts() then scans this array instead of walking the chart
    // with 2 x inpMaxLevels ObjectFind/ObjectGetDouble calls per heavy frame.
    // NOTE: recorded BEFORE the viewport cull, so an off-screen level can
    // still alert (the chart holds it; we simply do not paint it).
    AlertCacheReset(g_drawGeneration);

    for(int i = 0; i < lineCount; i++)
    {
        AlertCacheAdd(lines[i].name, lines[i].price, lines[i].logicalStep,
                      lines[i].direction > 0);

        // P-UI-98: the step-1 handle. While ITS gesture is live the line is
        // MT4's to move: nothing on the object (P-BK-15), and the recomputed
        // line price equals the dragged price anyway (it is where F came
        // from) — the settle frame re-asserts it. Keyed on the NAME alone
        // (P-UI-98f): the handle is not always the ladder's rung 1, so a rung
        // number here let the render write the line the hand was holding.
        if(g_s1DragLive && lines[i].name == g_s1DragName)
            continue;

        // ALL pipeline lines (trigger-subdivision AND structure-interval)
        // share the unified [08.4] appearance set in ClassifyLevels. They are
        // drawn whenever the Lines switch (L / g_linesVisible) shows them and
        // are NEVER hidden or restyled by the trigger switch. RenderZones is
        // the ONLY place the trigger overlay hides things — the trigger ZONES.
        // (The old Factor hideLineWhenTriggerOnly inversion is retired: every
        //  mode config leaves it false, and line visibility belongs to L alone.)
        // P-VIEW-01 (2026-09-29) — THE CULL DECIDES PAINT, THE VIEWPORT NEVER OWNS
        // VISIBILITY. This branch used to write OBJ_NO_PERIODS on the line AND its
        // label, i.e. the window HID them, and only the frame that re-evaluated
        // `inViewport` could bring them back. Measured on this machine: the cull
        // window was deliberately allowed to lag P_P4_VP_HYSTERESIS_PCT = 0.20 of the
        // visible range while the geometry signature that decided whether a render
        // runs AT ALL carried that same window (both retired by P-VIEW-05,
        // 2026-10-16). So a level the price walked to could sit
        // hidden through any number of frames — exactly the report «سطوح حذف میشه
        // ولی دیگه نمیاد تا یک تکونی به چارت بدم» — and every window re-derivation
        // flipped the mask on hundreds of objects in ONE frame, which is the flicker
        // that carried the whole chart with it (the card and the countdown are
        // re-created by the same rebuild).
        //
        // The mask is now the OWNER's (F / L / IsIndicatorHidden), asserted exactly as
        // the in-window path asserts it and read-guarded in ApplyTfMaskGuarded — zero
        // writes in steady state, one cache read per object — and this branch only
        // skips the PAINT. The object keeps its price, so when the user scrolls to it
        // MT4 draws it from its own state at its own paint time: nothing to wait for,
        // nothing to flip, no cost on this side (that is the "قبل از کاربر" order).
        long lineTf  = (IsIndicatorHidden() || !g_linesVisible) ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
        // P-VIEW-03 (2026-09-29) — THE WINDOW IS NOT AN OWNER OF THE OBJECT, AND A
        // FRAME THAT SKIPS A PAINT IS A LEVEL THAT CAN STAY MISSING.
        //
        // This is where an `if(!inView) { assert mask; continue; }` fence stood (and,
        // before that, an `if(!inView) SetPipelineObjectTimeframesIfExists(...,
        // OBJ_NO_PERIODS)`). Both shapes are the same defect with different clothes:
        // they make the object's EXISTENCE depend on the moment the render happened
        // to run, and nothing guarantees a later frame re-decides it. MEASURED in the
        // user's own chart (2026-09-29, EURUSD M15, this build): the family above the
        // live price was drawn from 1.15185 up to 1.17630 and two rungs at the bottom
        // (1.11520 / 1.11250) were drawn, while the whole band around the price —
        // 1.11520..1.15185, nine rungs on the same 41-pip pitch — was simply ABSENT.
        // A hole in the MIDDLE cannot come from the level list (the ladder is built
        // outward from the centre and is contiguous, and BuildZonesAndLines culls
        // nothing — it only FLAGS `inViewport`), so the band existed in `lines[]` and
        // was skipped here, with no later frame to bring it back after a scale change.
        //
        // The law this restores, and it is the same one the class already follows for
        // zones and labels: THE WINDOW DECIDES NOTHING. Every level the build produced
        // is asserted with the OWNER's mask (F / L / IsIndicatorHidden, read-guarded in
        // ApplyTfMaskGuarded) and painted; MT4 clips what is off the chart itself, and
        // that clipping costs this indicator nothing. "Painted but off-screen" is free;
        // "not painted and back in view" is a hole.
        //
        // Cost, stated: the loop no longer skips, so a level outside the window now
        // runs the same change-guarded `CreateOrUpdateHLine` the in-window ones run —
        // a handful of property reads that write NOTHING when the object already holds
        // those values (P-PERF-51's law), against a full level family (bounded by the
        // ladder's own count, the same number the level list already carries). And it
        // removes the reason for a pan to rebuild anything: with no window term in the
        // frame signature (P-VIEW-02) a scroll now costs zero indicator work AND the
        // picture is complete, which is the "قبل از کاربر" order the user asked for.
        //

        // Use the individual line color instead of config.triggerColor
        if(makeLines) {
            // MT5-ONLY (R-RENDER-ENGINE): a canvas-owned line stages instead of
            // creating/updating its object. A pinned line (step-1 handle pair,
            // live drag) keeps the untouched object path below.
            bool rbCanvasStage = false;
#ifdef BIOTAK_RENDER_ENGINE
            if(RBridgeActive() && !RBridgePinned(lines[i].name))
            {
                rbCanvasStage = true;
                RBridgeLevelLine(lines[i].name, lines[i].price, lineClr,
                                 (int)lineStyle, lineWidth);
            }
#endif
            if(!rbCanvasStage) {
            bool isNew = CreateOrUpdateHLine(lines[i].name, lines[i].price,
                                              lineClr, lineStyle, lineWidth,
                                              lines[i].tooltip);
            SetPipelineObjectTimeframesIfExists(lines[i].name, lineTf);   // P-VIEW-01: hoisted, one owner

            // Set mode-specific properties on new objects
            if(isNew) {
                if(config.useObjPropBack) {
                    ObjectSetInteger(0, lines[i].name, OBJPROP_BACK, false);
                }
                if(config.zOrder > 0) {
                    ObjectSetInteger(0, lines[i].name, OBJPROP_ZORDER, config.zOrder);
                }
            }
            // P-UI-98: the face is owned AFTER the creator — CreateOrUpdateHLine
            // writes SELECTABLE=false on every fresh object, so a face write
            // before it landed on nothing and a just-created handle stayed
            // un-grabbable until a topology change re-rendered the family.
            if(lines[i].name == s1AboveName || lines[i].name == s1BelowName)
                Step1HandleOwnFace(lines[i].name, lines[i].price, lines[i].direction,
                                   lineTf, lines[i].tooltip);
            }
        }

        // P-LBL-12 (2026-10-17): THE PIP-DISTANCE LABEL BLOCK STOOD HERE.
        //
        // The user's screenshot pointed at the "+7 | 4161.4" texts and the
        // order was to remove them («این پیپ لیبل ها رو کامل حذف کن») - they
        // were an extra surface per level, and the feature cost one object
        // per rung plus its own row-lift machinery. Both feeders are gone:
        // this level-family block (CreatePipDistanceLabel, deleted from
        // ObjectFunctions) and the High/Low pair's blocks (Labels_A).
        // The build no longer derives per-level label text either (see
        // GetLabelTextForLevel's seat). And the names are out of the ladder
        // sweep's produced set, so the ONE handoff sweep
        // (P-LEVEL-FOREIGN-02) deletes every legacy `<line>_Label` object a
        // previous build left on the chart - the upgrade cleans itself, once.
    }
#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): close the pass - sweep the staged families,
    // diff-commit the changed ones, paint if anything moved.
    if(RBridgeActive()) RBridgeEnd();
#endif
}

// P-LBL-12 (2026-10-17): GetCurrentPriceForLabels stood here — it priced the
// pip-distance labels' distance to the live price. With the labels retired
// it had no reader.

//+------------------------------------------------------------------+
//| STAGE 5c: Cleanup surplus objects from previous render           |
//+------------------------------------------------------------------+
void CleanupSurplusPipeline(
    const SModeConfig &config,
    const int maxLogicalStep)
{
    // ══════════════════════════════════════════════════════════════════════
    // P-PERF-108 (2026-10-16) — NO SURPLUS DELETE AGAINST A TRANSIENT BUILD.
    //
    // `maxLogicalStep` arrives from the build that just ran, and on the first
    // frame after a timeframe switch that build can be SYNTHETIC: history has
    // not landed yet, so RedrawAllObjects stands in a ±1% band around the base
    // price (EventHandlers, the `!g_initialized` fallback) and the ladder that
    // comes out is a fraction of the real one. This walk then deleted every
    // adopted object above that fraction — names the REAL build produces and
    // the very next frame re-creates — which is the delete-and-reappear blink
    // the user reported («حذف و ظاهر میشه مثل چشم زدن»), on EVERY switch.
    //
    // `!g_initialized` is the exact name of "history is not trustworthy yet":
    // it is false from attach/switch until UpdateHistoricalValues succeeds,
    // and RedrawAllObjects retries it every heavy frame (the pump owes one
    // every 250 ms on a tick-less chart), so the moment it flips, the next
    // frame's cleanup runs against the real ladder. Nothing accumulates: the
    // real build's own frame deletes the true surplus in one pass.
    // ══════════════════════════════════════════════════════════════════════
    if(!g_initialized) return;

    // During a hand-set drag (custom-price or step-1), do lightweight throttled
    // cleanup instead of skipping entirely. P-UI-98i: the step-1 drag re-steps
    // the ladder live like the line's drag, so it owns the same throttle - a
    // full surplus sweep mid-gesture deletes under the hand.
    if(g_customPriceLineDragging || g_s1DragLive) {
        static uint s_lastDragCleanupMs = 0;
        uint nowMs = GetTickCount();
        if(s_lastDragCleanupMs != 0 && (nowMs - s_lastDragCleanupMs) < 250)
            return;
        s_lastDragCleanupMs = nowMs;
    }
    
    //======================================================================
    // P-PERF-36 - A FAMILY'S CLEANUP MUST NOT BE GUARDED BY THE FLAG THAT
    //             TURNS THE FAMILY OFF
    //
    // Cleanup has exactly one job: remove what THIS render no longer produces.
    // "Mid zones off" is precisely the state in which every zone must go, so
    // guarding the zone cleanup on `zonesEnabled` skipped the delete in the ONE
    // state that needed it. The chain is complete and provable:
    //
    //   ring CIR_ZONES -> g_showMidZones (== inpShowMidZones macro)
    //     -> GetUnifiedZoneConfig().enabled -> cfg.zonesEnabled
    //     -> zone BUILDING is gated on it (lines above: ArrayResize/hasMid/zIdx)
    //     -> so `zones[]` arrives EMPTY at RenderZones, which only walks the list
    //        it is handed and has NO delete-stale path of its own
    //     -> and this cleanup - the only remover of zone objects - was skipped
    //
    // Result: the switch stopped the zones being RE-CREATED while every zone
    // object already on the chart stayed put, which is the reported symptom:
    // "levels don't turn on/off with this button". Turning it back ON also did
    // nothing visible, because the objects had never left.
    //
    // P-PERF-41 supersedes the P-PERF-36 window: "zones off" is no longer an
    // ABSENCE at all. RenderZones hides the whole family with one mask walk the
    // moment the switch goes off, so cleanup is once more exactly what its name
    // says - "remove what THIS render no longer produces" - and it walks past the
    // newest logical step in BOTH states. Deleting the family on the way out was
    // the expensive half of the old toggle (7 deletes per zone, then 7 writes
    // per zone to come back) and the reason a hidden object could never be
    // brought back for free.
    //
    // The invariant P-PERF-36 was protecting is kept and strengthened: cleanup
    // may never be guarded by the flag that turns the family off, and the OFF
    // state is handled explicitly, one branch above.
    //======================================================================
    const int zoneCleanupFrom = maxLogicalStep + 1;
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Above_", zoneCleanupFrom);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Below_", zoneCleanupFrom);
    CleanupSurplusObjects(config.objectPrefix + config.modeName + "_Zone_Center_", 1);
    
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

#endif // LEVEL_PIPE_A_MQH// LevelPipe_B.mqh - LevelPipeline.mqh split 2026-09-29: exact lines 1439-2181, byte-identical, zero renames.
#ifndef LEVEL_PIPE_B_MQH
#define LEVEL_PIPE_B_MQH

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
    cfg.zOrder = Z_CHART_ZONE;   // P-UI-31: mode configs override (Factor -> Z_CHART_LINE)
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
//| ASYMMETRIC REACH: split the budget toward the live price. Centred /  |
//| invalid live reads an even split; total never exceeds the budget.    |
//+------------------------------------------------------------------+
void LevelSplitCounts(const int Nin, int &above, int &below)
{
    int N = Nin;
    if(N > MAX_SAFE_LEVELS) N = MAX_SAFE_LEVELS;
    if(N < 1) N = 1;
    int total = MathMin(N * 2, LVL_TOTAL_BUDGET);
    above = N; below = N;
    if(total < N * 2) { above = total / 2; below = total - above; }
    double center = GetMidpointPrice(g_thStartPointType);
    double step = NaturalFirstStep() * StepOverrideFactor();
    double bid = MarketInfo(GetCachedSymbol(), MODE_BID);
    double ask = MarketInfo(GetCachedSymbol(), MODE_ASK);
    double live = (bid > 0.0 && ask > 0.0) ? (bid + ask) * 0.5 : bid;
    if(!(MathIsValidNumber(center) && center > 0.0 && MathIsValidNumber(step) && step > 0.0 && live > 0.0)) return;
    int offLvls = (int)MathCeil(MathAbs(live - center) / step);
    if(offLvls <= LVL_SPLIT_MARGIN) return;
    int minCtx = MathMax(1, total / LVL_SPLIT_CTXDIV);
    if(total < minCtx * 2) return;
    int toward = MathMin(N + offLvls, total - minCtx);
    if(live >= center) { above = toward; below = total - toward; }
    else               { below = toward; above = total - toward; }
    if(above < 1) above = 1;
    if(below < 1) below = 1;
    static int s_wA = -1, s_wB = -1;
    if(above != s_wA || below != s_wB) { s_wA = above; s_wB = below; _LOG_GATE_D Print("[LVL] split N=", N, " above=", above, " below=", below); }
}

//+------------------------------------------------------------------+
//| P-PERF-18: the identity of a built geometry.                     |
//|                                                                  |
//| Every input the three pure stages read is folded in, so a change  |
//| in ANY of them misses the cache and rebuilds for real:           |
//|   - center price + step sizes   (a tick that moved the base price)|
//|   - the cull window             (a scroll or a zoom)             |
//|   - mode / classify / lsFirst / max levels / trigger switch      |
//|   - every zone and fallback colour/style field of SModeConfig    |
//|   - the custom-price drag flag  (the drag path re-culls)         |
//| Doubles are quantised with DoubleToString(...,8) so a sub-point  |
//| wobble cannot masquerade as a new geometry, and the string is     |
//| built once per frame - microseconds against the thousands of      |
//| level computations it can save.                                  |
//+------------------------------------------------------------------+
string PipelineGeometryKey(const SModeConfig &config,
                           const double centerPrice,
                           const double &stepSizes[],
                           const int stepSizeCount,
                           const ENUM_LEVEL_STEP_MODE stepMode,
                           const ENUM_CLASSIFY_MODE classifyMode,
                           const bool lsFirst,
                           const int maxLevelsAbove,
                           const int maxLevelsBelow,
                           const int baseMultiplier)
{
    string key = config.modeName + "|" + config.objectPrefix;
    key += "|" + DoubleToString(centerPrice, 8);
    key += "|" + IntegerToString(stepSizeCount) + "," + IntegerToString((int)stepMode);
    for(int s = 0; s < stepSizeCount; s++) key += "," + DoubleToString(stepSizes[s], 8);
    key += "|" + IntegerToString((int)classifyMode) + IntegerToString(lsFirst ? 1 : 0);
    key += "|" + IntegerToString(maxLevelsAbove) + "," + IntegerToString(maxLevelsBelow);
    // P-VIEW-05 (2026-10-16): `vpTop|vpBottom` stood here and they were the
    // last live term of the cull window inside the engine. The window never
    // decided what is built or painted (the P-VIEW-01 law: the render takes
    // the window and never lets it write a mask; the build's `inViewport`
    // flags are written and read by no one), so a pan past the hysteresis
    // could only change this key and throw away a valid geometry — a full
    // re-derive and re-assert for pixels that had not changed. The key is
    // the REAL geometry now: centre, steps, classification, counts, colours,
    // bounds. A pan changes none of them.
    // P-PERF-21: `triggerEnabled` used to sit here, and it was a FALSE
    // dependency. The trigger overlay owns exactly ONE family - the trigger
    // zones - and that decision lives in RenderZones (`zones[i].isTrigger &&
    // !triggerEnabled`), which reads the LIVE flag at paint time. Nothing that
    // BUILDS this geometry reads it: CalculateLevels does not touch it,
    // BuildZonesAndLines does not touch it, and the two classify-time helpers
    // that take it as a parameter (`GetPathForLevelOptimized`,
    // `GetZoneColorForLevel`) never look at it. So a T press threw away the
    // whole geometry and recomputed byte-identical lists - the recompute half
    // of "the trigger toggle redraws all my levels".
    key += "|" + IntegerToString(baseMultiplier);
    key += "|" + IntegerToString(config.zonesEnabled ? 1 : 0) + "," + IntegerToString((int)config.zoneStyle);
    key += "," + IntegerToString(config.zoneTransparency) + "," + DoubleToString(config.zoneHeightPercent, 6);
    key += "," + IntegerToString((int)config.zoneDefaultColor);
    key += "|" + IntegerToString(config.useObjPropBack ? 1 : 0) + "," + IntegerToString(config.zOrder);
    key += "," + IntegerToString(config.useStepFilter ? 1 : 0);
    key += "," + IntegerToString(config.boundByHistorical ? 1 : 0);
    key += "," + DoubleToString(config.maxPrice, 8) + "," + DoubleToString(config.minPrice, 8);
    key += "|" + IntegerToString((int)config.fallbackColor) + "," + IntegerToString((int)config.fallbackStyle);
    key += "," + IntegerToString(config.fallbackWidth);
    key += "," + IntegerToString((int)config.fallbackColor2) + "," + IntegerToString((int)config.fallbackStyle2);
    key += "," + IntegerToString(config.fallbackWidth2);
    key += "," + IntegerToString((int)config.midpointColor) + "," + IntegerToString((int)config.midpointStyle);
    key += "," + IntegerToString(config.midpointWidth);
    // P-PERF-21b: the ZONE COLOURS are part of what this geometry carries
    // (ClassifyLevels stores zoneColor per level, read from PipelineBandBaseColor),
    // yet none of THOSE inputs were in the key: a structure-tier colour, a tier's
    // show flag, the zones switch or the trigger colour could change while the key
    // stayed equal and the cached zones would keep painting the old colour. The
    // staleness was invisible because every one of those edits also changes
    // levelSig and therefore wipes - but the cache must not RELY on a different
    // guard to be correct.
    // P-UI-131m: the trigger term is the RAW `g_triggerColor` the geometry stores.
    // It used to be `GetTriggerRenderColor()`, which put the trigger TRANSPARENCY
    // in the key and so made every step of that slider a full family recompute -
    // a PAINT input read as geometry, the mistake P-UI-66 removed from the lines.
    key += "|zc" + IntegerToString(inpShowMidZones ? 1 : 0)
              + IntegerToString(inpShowStructure ? 1 : 0)
              + IntegerToString(inpShowStructureL1 ? 1 : 0) + IntegerToString(inpShowStructureL2 ? 1 : 0)
              + IntegerToString(inpShowStructureL3 ? 1 : 0) + IntegerToString(inpShowStructureL4 ? 1 : 0)
              + IntegerToString(inpShowStructureL5 ? 1 : 0)
              + "," + IntegerToString((int)inpStructureL1Color) + IntegerToString((int)inpStructureL2Color)
              + IntegerToString((int)inpStructureL3Color) + IntegerToString((int)inpStructureL4Color)
              + IntegerToString((int)inpStructureL5Color)
              + "," + IntegerToString((int)g_triggerColor);
    key += "|" + IntegerToString(g_customPriceLineDragging ? 1 : 0);
    // P-UI-66 - THE LINE LOOK IS NOT GEOMETRY, SO IT IS NOT A KEY TERM.
    //
    // This slot used to carry `g_lineColor` and `g_lineTransparency` as a
    // workaround for a stale read: ClassifyLevels() copies the live look into
    // `classified[]`, BuildZonesAndLines() copies it on into `lines[]`, and the
    // PAINT read it back out of that array. A look edit therefore only reached
    // the chart when this key MISSED - and only the two inputs that happened to
    // be listed here could ever miss it. WIDTH and STYLE were not listed, so on
    // the Lines card ("ONE STYLE FOR ALL LINES") the colour row and the
    // transparency slider moved the chart while the width slider and the style
    // dropdown did NOTHING until an unrelated edit rebuilt the geometry.
    //
    // Naming all four inputs here would have been the wrong repair: every width
    // drag would then throw the whole level family away (CalculateLevels +
    // Classify + Build) on the weak PC this project is written for. The owner is
    // fixed instead - RenderTriggerLines reads the live look, exactly as
    // RenderZones already reads the BAND/EDGE border live - so **no look input
    // belongs in this key at all**, and leaving one out can no longer make a
    // control dead. The gate that holds this: probe-budget-audit `look-live`.
    // P-PERF-23b: `g_linesVisible` used to sit here, described as "ClassifyLevels()
    // reads the LIVE line appearance and the L toggle". That was FALSE: no stage
    // of this pipeline reads it. grep says it has exactly two consumers in the
    // whole file - the RenderTriggerLines paint line (`long lineTf = ...
    // !g_linesVisible ...`, plus ObjectFunctions) and this key. The L switch and
    // the panels' SHOW LINES row are a MASK decision taken at paint time, so the
    // term turned every visibility flip into a full recompute of
    // CalculateLevels/Classify/Build that produced byte-identical lists, and
    // then the paint re-read the live flag anyway. Removed: the picture still
    // follows the switch (the mask writer owns it), the math no longer restarts.
    // ClassifyLevels() -> GetHighestStructureLevel() reads the structure-interval
    // table (g_cachedIntervals). That table is a pure function of the VALIDATED
    // base multiplier (already in the key), but the key names its five values
    // directly, so a future change to how the table is derived cannot silently
    // serve structure levels computed against the old table. (The term here used
    // to be ArraySize(g_cachedIntervals), the constant 5 - it asserted a
    // property instead of proving it.)
    key += "|iv";
    for(int iv = 0; iv < 5; iv++) key += "," + IntegerToString(g_cachedIntervals[iv]);
    return key;
}

//+------------------------------------------------------------------+
//| UNIFIED PIPELINE EXECUTOR                                        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| P-LEVEL-FOREIGN-01 — A NAME IS NOT A PLACE                       |
//|                                                                  |
//| THE DEFECT THIS CLOSES                                           |
//|                                                                  |
//| A level object is named by its LOGICAL STEP INDEX (`_Above_7`),   |
//| but its PRICE is a function of the geometry: the anchor, the step |
//| sizes and the mode. The index therefore survives a change that    |
//| moves every price, and NOTHING in the project could tell the two  |
//| apart:                                                           |
//|                                                                  |
//|   * RenderTriggerLines() creates or updates a line only when it   |
//|     is inside the viewport; every other object merely gets a mask |
//|     (OBJ_NO_PERIODS). Out of view, a price is never corrected.    |
//|   * CleanupSurplusPipeline() sweeps by STEP INDEX, from           |
//|     `maxStep + 1` upward - and the previous geometry's `_Above_7` |
//|     and this one's `_Above_7` are the same index. The sweep sees  |
//|     a name it expects and stops. It cannot see a foreign object.  |
//|                                                                  |
//| So an object written by a previous geometry keeps its name, keeps |
//| its index, keeps its price, and is never removed. The live chart  |
//| showed the result: `_Above_1..9` at 2.41 pips (M1) interleaved    |
//| with `_Above_10..43` at 9.65 pips (H1), including near-duplicate  |
//| PAIRS 0.06-0.16 pips apart - one member from each geometry, which |
//| a single build can never emit (BuildZonesAndLines drops a level   |
//| that fails to advance, so a duplicate proves two builds).         |
//|                                                                  |
//| WHAT THIS DOES                                                    |
//|                                                                  |
//| When the LADDER ITSELF changes (the step signature: mode, count,  |
//| the sizes - i.e. a timeframe switch, a mode change, an ATR-scaling |
//| regime change), walk the freshly built lists and delete any object |
//| whose CACHED price disagrees with the price this geometry gives   |
//| its step index. The cache stores the price we last wrote, so the  |
//| comparison costs one hash probe and no terminal read; only a      |
//| genuine mismatch costs a delete. The render that follows re-creates |
//| whatever is inside the viewport, so the family ends up exactly the |
//| current geometry - and the objects that are gone are the ones the |
//| current geometry never owned.                                     |
//|                                                                  |
//| WHY ONLY ON A LADDER CHANGE                                       |
//|                                                                  |
//| A centre-only move (a price-anchored start point ticking) shifts  |
//| the whole ladder coherently: anything that enters the viewport is |
//| corrected by the render, and anything else is masked, not visible. |
//| The corruption that reaches the SCREEN comes from a change of     |
//| PITCH - two different step sizes coexisting - so that is the gate. |
//| It makes the pass rare (a switch, not a tick) and keeps the cost  |
//| bounded on the weak PC this project is written for.               |
//|                                                                  |
//| THE COLD-CACHE CORNER, STATED HONESTLY                            |
//|                                                                  |
//| On a timeframe switch the teardown clears the object cache, so a  |
//| fresh instance's cache holds nothing to compare and this pass     |
//| finds nothing. That corner is NOT covered here - it is covered by |
//| AdoptionFingerprint(), which now folds in the timeframe and the   |
//| anchor so the kept family is never ADOPTED when its prices are    |
//| stale (see P-LEVEL-FOREIGN-01 there). This function is the net    |
//| for the WARM-cache case: a ladder change inside one instance.     |
//+------------------------------------------------------------------+
int SweepForeignLevelObjects(const SModeConfig &config,
                             const STriggerLine &lines[],
                             const int lineCount,
                             const SZoneDefinition &zones[],
                             const int zoneCount)
{
   const double tol = GetCachedPoint() * 0.1;
   int removed = 0;

    for(int i = 0; i < lineCount; i++)
    {
       // P-UI-98k: the render skips the live-dragged handle (it must never
       // rewrite a line the hand is holding, P-BK-15) - so this sweep must
       // not delete it either. Every step-1 drag changes the pitch (F), so
       // this pass runs on the drag's own frames and the cache still holds
       // the pre-drag price: without this term the sweep deletes the very
       // line being dragged, the render refuses to re-create it while the
       // gesture is live, the factor math reads 0 and freezes (no write, no
       // redraw flag), and the settle's forced frame is gated off - the
       // handle stays missing until an unrelated rebuild. The above handle
       // never blinks because it is deleted AND re-created in the same
       // frame; only the dragged one (here: the below handle) vanishes.
       bool s1SkipSweep = (g_s1DragLive && g_s1DragName != "" &&
                           lines[i].name == g_s1DragName);
        // P-LBL-12 (2026-10-17): this pass used to probe the line's
        // pip-distance label too (pass 0/1 over `<name>` and `<name>_Label`).
        // The labels are retired and nothing produces the name, so the second
        // probe could only ever miss; the sweep is line-only now.
        {
           if(s1SkipSweep) continue;
           string nm = lines[i].name;
          SObjectCacheEntry e;
          if(!CacheGetObject(nm, e)) continue;   // cold cache: nothing to compare
          if(!e.exists) continue;                // dead slot: no object under this name
          if(MathAbs(e.lastPrice - lines[i].price) <= tol) continue;   // ours
          if(DeleteIndicatorObjectManaged(nm, true)) removed++;
       }
   }

   for(int i = 0; i < zoneCount; i++)
   {
      SObjectCacheEntry e;
      if(!CacheGetObject(zones[i].name, e)) continue;
      if(!e.exists) continue;
      if(MathAbs(e.lastPrice - zones[i].midPrice) <= tol) continue;
      if(DeleteManagedZoneObjects(zones[i].name, true)) removed++;
   }

   return removed;
}

//| A zone exists as ONE band plus up to six NAMED sub-objects — `_Top`,
//| `_Bottom` (the boundary lines) and `_B_Top`/`_B_Bottom`/`_B_Left`/
//| `_B_Right` (the empty-box border segments) — and `DeleteManaged- |
//| ZoneObjects()` removes the whole set from the BAND's name. So the   |
//| walk has to act on the band only, or one foreign zone would be     |
//| deleted six times over.
bool ZoneNameIsBand(const string nm)
{
    int n = StringLen(nm);
    if(n > 4 && StringSubstr(nm, n - 4, 4) == "_Top")    return false;   // also _B_Top
    if(n > 7 && StringSubstr(nm, n - 7, 7) == "_Bottom") return false;   // also _B_Bottom
    if(n > 5 && StringSubstr(nm, n - 5, 5) == "_Left")   return false;   // also _B_Left
    if(n > 6 && StringSubstr(nm, n - 6, 6) == "_Right")  return false;   // also _B_Right
    return true;
}

//+------------------------------------------------------------------+
//| P-LEVEL-FOREIGN-02 — THE OTHER HALF OF THE FOREIGN-OBJECT SWEEP.  |
//|                                                                  |
//| `SweepForeignLevelObjects()` above can only judge the names the    |
//| new ladder PRODUCES: it walks the built lists and asks the cache   |
//| whether the object under each name is still at the built price.    |
//| An object whose STEP INDEX the new ladder does not produce at all  |
//| is never in those lists, so nothing ever asked about it - and that |
//| is exactly why the family could carry a foreign pitch (the        |
//| reported `_Above_1..9` at 2.41 pips beside `_Above_10..43` at     |
//| 9.65). THAT hole is what put `Period()` into the adoption          |
//| fingerprint, and the fingerprint is what made every timeframe      |
//| switch wipe and rebuild the level family.                          |
//|                                                                  |
//| This walks the CHART instead - once, on the frame the ladder PITCH |
//| changed, which is the only moment the two pitches can be told      |
//| apart - and deletes every family object whose tail step is above   |
//| the newest one. Names carry the step and the ladder produces a     |
//| CONTIGUOUS 1..maxStep range (the same range `CleanupSurplus-        |
//| Pipeline` walks from maxStep + 1), so "step > maxStep" is exact:   |
//|                                                                  |
//|   * an index <= maxStep is produced by this ladder, so the render  |
//|     owns it and re-asserts its price IN PLACE;                    |
//|   * an index >  maxStep cannot be produced by this ladder at any   |
//|     price, so it can only be a survivor of another pitch.          |
//|                                                                  |
//| Called only when the family was HANDED OVER (`g_adoptPrevious-     |
//| Topology`), never after a wipe: a wiped chart has nothing foreign  |
//| on it, and this is a whole-chart walk.                             |
//|                                                                  |
//| The names are COLLECTED first and deleted afterwards, because a     |
//| delete renumbers the terminal's object-list indices - deleting     |
//| inside the walk would step over the next object.                   |
//+------------------------------------------------------------------+
// Is this chart name one of the names the build JUST produced?  The produced
// list is small (the culled ladder: tens of entries) and the walk only asks
// about names the family test already accepted, so a linear scan is the right
// shape here - and it is EXACT, which is the whole point (see below).
bool ProducedLadderName(const string nm, const string &produced[], const int producedCount)
{
    for(int p = 0; p < producedCount; p++)
        if(produced[p] == nm) return true;
    return false;
}

//+------------------------------------------------------------------+
//| P-PERF-55 (2026-10-13) — THE SWEEP'S MEMBERSHIP TEST IS A SET.    |
//|                                                                   |
//| The note above calls `produced[]` "small (tens of entries)". That |
//| is the assumption, and the LIVE CHART contradicts it: `produced`  |
//| is sized `lineCount * 2 + zoneCount` (the caller below), and the  |
//| same session measured lineCount=450 / zoneCount=289 — i.e. ~1,189 |
//| names — while the walk visits every chart object (~1,200). So the |
//| frame paid ~1.4M string compares, all of it inside ONE sweep:     |
//|                                                                   |
//|   [P-LEVEL-FOREIGN-02: deleted 450 ladder object(s)]              |
//|   [W][PERF] coop job=heavy-frame ran=125ms                        |
//|   [E][GEN] [CRIT] CRITICAL CPU: OnCalculate took 453ms!           |
//|            [base=0 atr=0 hist=0 levels=453 ...]                   |
//|                                                                   |
//| The fix is the SHAPE of the question, not its answer: build the   |
//| set once (O(pc)) and answer each name with one FNV-1a probe. The  |
//| predicate is unchanged — a name is doomed iff it is NOT one this  |
//| build produced — so the output is byte-identical and the caller   |
//| set is untouched (`ProducedLadderName` above stays, as the exact  |
//| fallback for a table that cannot hold the list).                  |
//|                                                                   |
//| COST, stated: was one linear scan per family name, up to          |
//| pc × familyObjects ≈ 1.4M compares on the measured chart; now     |
//| pc inserts + one probe per family name (≈ 1,189 + 1,200 probes)   |
//| plus one 4096-slot clear. A list too big for the table (pc × 2 >  |
//| LADDER_SET_SIZE) falls back to the old scan rather than growing.  |
//+------------------------------------------------------------------+
#define LADDER_SET_SIZE 4096
static string s_ladderSetNm[LADDER_SET_SIZE];
static bool   s_ladderSetOn[LADDER_SET_SIZE];

uint LadderSetHash(const string s)
{
    uint h = 2166136261;                     // FNV-1a, 32-bit, uint only (no ULL: the build rejects it)
    const int n = StringLen(s);
    for(int i = 0; i < n; i++)
        h = (h ^ (uint)StringGetCharacter(s, i)) * 16777619;
    return h;
}

// Returns false when the list does not fit the table — the caller then keeps the
// exact linear scan, so a very deep ladder is slower, never wrong.
bool LadderSetBuild(const string &produced[], const int pc)
{
    for(int i = 0; i < LADDER_SET_SIZE; i++) { s_ladderSetOn[i] = false; s_ladderSetNm[i] = ""; }
    if(pc <= 0 || pc * 2 > LADDER_SET_SIZE) return false;
    for(int i = 0; i < pc; i++)
    {
        const uint h = LadderSetHash(produced[i]);
        for(int probe = 0; probe < LADDER_SET_SIZE; probe++)
        {
            const int at = (int)((h + (uint)probe) % (uint)LADDER_SET_SIZE);
            if(!s_ladderSetOn[at]) { s_ladderSetOn[at] = true; s_ladderSetNm[at] = produced[i]; break; }
        }
    }
    return true;
}

bool LadderSetHas(const string nm)
{
    const uint h = LadderSetHash(nm);
    for(int probe = 0; probe < LADDER_SET_SIZE; probe++)
    {
        const int at = (int)((h + (uint)probe) % (uint)LADDER_SET_SIZE);
        if(!s_ladderSetOn[at]) return false;   // an empty slot ends the probe chain
        if(s_ladderSetNm[at] == nm) return true;
    }
    return false;
}

// Only a name that looks like OUR family is judged. `_BK_` is the user's
// Base/Knot layer (P-BK-01: it has no expiry whichever build made it).
bool LadderFamilyName(const string nm, const string fam)
{
    if(StringLen(nm) <= StringLen(fam)) return false;
    if(StringSubstr(nm, 0, StringLen(fam)) != fam) return false;
    if(StringFind(nm, "_BK_") >= 0) return false;
    return true;
}

// Zone sub-objects are paid for by their band's name, so a band that survives
// carries its borders with it and a band that goes takes them with it.
bool LadderNameIsZoneBand(const string nm)
{
    return (StringFind(nm, "_Zone_") >= 0) && ZoneNameIsBand(nm);
}

//+------------------------------------------------------------------+
//| P-PERF-32b — THE TRIGGER FAMILY'S OWN MASK WALK.                  |
//|                                                                   |
//| THE DEFECT IT CLOSES: «سطوح تریگر دیر خاموش و روشن میشه» — the     |
//| T hotkey, the ring's TRIGGER light and the card's SHOW row all     |
//| flipped `g_triggerLevelsEnabled` and then asked the RENDER for     |
//| the pixels, so the picture waited for a whole heavy frame (and the |
//| render had to rebuild a family the OFF press had deleted). The     |
//| structure switches (card 11, P-PERF-32) have painted in their own  |
//| event since they were fixed — state, a walk over the objects that  |
//| own the property, one discrete repaint — and the frame is never    |
//| the owner of the feedback. This is that technique for the family   |
//| whose property IS its mask.                                        |
//|                                                                   |
//| ONE OWNER FOR THE PROPERTY: the walk writes through                |
//| `SetPipelineZoneVisibility` — the render's own writer — so which   |
//| objects a zone is made of, and which of them L owns, is spelled    |
//| once. This walk only decides WHICH cached `_Zone_` names are       |
//| trigger bands: the ladder's own classification                     |
//| (`GetHighestStructureLevel(step, g_cachedIntervals) <= 0`, the     |
//| same test ClassifyLevels and StructureRecolourWalk use), read      |
//| from the name's step (sub-objects included: their band decides).   |
//|                                                                   |
//| BOUNDED BY THE CACHE, like every sibling walk: one hash probe per  |
//| occupied slot, zero ObjectName calls, zero type probes, and a      |
//| guarded mask write that is FREE when that object is already right. |
//| `seen` = the trigger bands the walk found (0 says the chart does   |
//| not carry the family yet, which is the one case that still needs a |
//| render to build it), return = the masks that really reached the    |
//| chart. Both numbers are printed by the press that paid for them.   |
//+------------------------------------------------------------------+
int TriggerFamilyWalk(const bool on, int &seen)
{
#ifdef BIOTAK_RENDER_ENGINE
    // MT5-ONLY (R-RENDER-ENGINE): the canvas overlay is per-zone visibility
    // inside one layer - a rec flip, counted with the same `seen` contract.
    if(RBridgeActive()) return RBridgeTriggerWalk(on, seen);
#endif
    seen = 0;
    int written = 0;
    int visited = 0;
    for(int i = 0; i < CACHE_HASH_BUCKETS && visited < g_objectCacheSize; i++)
    {
        if(!g_objectCacheHash[i].occupied) continue;
        visited++;
        if(!CacheSlotIsLive(i)) continue;         // P-UI-62: liveness is the permission to touch
        const string nm = g_objectCacheHash[i].name;
        if(StringFind(nm, "_Zone_") < 0) continue;         // lines/labels/HTF
        if(StringFind(nm, "_Zone_Center_") >= 0) continue; // mode colour, not a ladder band
        if(StringFind(nm, "_BK_") >= 0) continue;          // independent layer (P-BK-01)
        if(!ZoneNameIsBand(nm)) continue;                   // a sub-object: its band decides
        int step = StructureZoneStepFromName(nm);
        if(step <= 0) continue;
        if(GetHighestStructureLevel(step, g_cachedIntervals) > 0) continue;   // a structure tier
        seen++;
        written += SetPipelineZoneVisibility(nm, on);
    }
    return written;
}

//+------------------------------------------------------------------+
//| P-LEVEL-FOREIGN-02 — EXACTLY THE PRODUCED SET, OR NOTHING.        |
//|                                                                  |
//| Reported (after the P-PERF-38d handoff landed): «سطوح که باید   |
//| نمایش بده نمایش نمیده، و سطوحی که توی دید نیست رو نمایش میده   |
//| — برعکس» — the family near the price is not drawn while objects  |
//| far outside the window are.                                       |
//|                                                                  |
//| That is ONE structural defect with two faces. The family on the   |
//| chart must be EXACTLY the set the current build produces; nothing |
//| enforced it, so the kept objects of a former geometry (a wider    |
//| window, another pitch, another timeframe) could stay VISIBLE       |
//| outside the window while the produced set could be attacked from   |
//| the other side. The previous attempt at this walked the indices    |
//| from `maxStep + 1` upward, which is only right when the numbering  |
//| is contiguous AND `${fam}` ... `maxStep` is a window/geometry     |
//| quantity, not a name-space bound.                                 |
//|                                                                  |
//| So the question this pass asks is the only exact one: "is this     |
//| chart name one of the names the build just produced?" - and the    |
//| answer is available for free, because the build is standing in     |
//| this very call with `lines[]` and `zones[]` in hand.               |
//|                                                                  |
//| Two faces it closes, in one pass:                                  |
//|   * a survivor the build does not produce is DELETED (whatever its |
//|     index, pitch or price) - the far visible objects go;           |
//|   * a name the build DOES produce is left alone, so the render     |
//|     re-asserts it in place (the cache-first creator updates an      |
//|     existing object) - which is what makes the handoff cheaper      |
//|     than the wipe it replaced.                                     |
//|                                                                  |
//| NOTHING is deleted when the build is not trustworthy — either it |
//| produced nothing, or history has not landed yet (`!g_initialized` |
//| means the ladder standing here is the synthetic transient, so the |
//| produced set must not be used to judge survivors — P-PERF-108).   |
//| The next real pass re-derives it and re-creates what is missing.  |
//| A delete-everything-then-rebuild flash on an attach is exactly the |
//| class of bug this project refuses to trade a flicker for.          |
//+------------------------------------------------------------------+
// P-PERF-107 (2026-10-16) — THE HANDOFF SWEEP IS RESUMABLE.
//
// MEASURED (2026-10-16 tour): the whole-chart walk below cost 1016-1062 ms
// (H1 rest=1016, D1 rest=1062) and ran BEFORE the first render of the
// handoff frame — the chart the user switched to stayed EMPTY for a full
// second on top of the ~1 s OnInit walk. The walk is ~1200 ObjectName
// calls at ~0.85 ms each; the object count is the terminal's, not ours.
//
// So the walk is CHUNKED: each call examines at most SWEEP_FOREIGN_CHUNK
// objects and returns -1 ("still running"); the caller latches the handoff
// only when it returns >= 0. The first render waits ONE chunk (~200 ms),
// and the deletions are chunked the same way afterwards.
//
// State carried between calls (statics, per instance): the produced
// snapshot, the family prefix, the doomed list, and a DESCENDING chart
// cursor. Descending is what makes a cursor legal across frames: the
// render only APPENDS objects (above the cursor — not visited), and a
// deletion below the cursor costs at most one re-examined neighbour. A
// stale object missed this way is swept by the next handoff.
//
// SWEEP_FOREIGN_CHUNK = objects examined/deleted per frame (P-PERF-107).
// The sweep's statics carry the state between calls; their comments live on
// their own lines (the parity chunker keys file-scope declarations by their
// own line, and a trailing comment makes the line read as an anonymous block).
const int SWEEP_FOREIGN_CHUNK = 250;
static bool   s_fsActive  = false;
static int    s_fsPhase   = 0;
static int    s_fsCursor  = 0;
static string s_fsFam     = "";
static string s_fsProduced[];
static int    s_fsPc      = 0;
static bool   s_fsSet     = false;
static string s_fsDoomed[];
static int    s_fsNd      = 0;
static int    s_fsRemoved = 0;

int SweepForeignLadderObjects(const SModeConfig &config,
                              const STriggerLine &lines[],
                              const int lineCount,
                              const SZoneDefinition &zones[],
                              const int zoneCount)
{
    if(!s_fsActive)
    {
        // P-PERF-107b (2026-10-16): "cannot judge yet" is NOT a verdict. The
        // hoisted caller runs on EVERY frame - including the first frames
        // after a handoff, where there is no base price yet (centerPrice<=0
        // above leaves lineCount at 0). Returning 0 there made the caller
        // latch `s_foreignSweepDone` before the real build ever landed, so
        // the previous timeframe's ladder was never swept (no FOREIGN print
        // in the whole 15:20-15:28 tour). -1 = "retry next frame".
        // P-VIEW-05 (2026-10-16): the old gate here asked whether the CULL
        // WINDOW was usable — a proxy for "the build is real". It is the
        // readiness flag itself now: the window never decided what this
        // sweep may delete, and `g_initialized` names the fact the proxy
        // was standing in for (history landed, the ladder is final).
        if(!g_initialized) return -1;                        // transient ladder: not judged
        if(lineCount <= 0) return -1;                        // nothing produced yet: not judged

        // What this build owns, by NAME. P-LBL-12 (2026-10-17): the pip-distance
        // labels used to be part of this set ("a line and its label are one
        // decision"). They are retired, so the `<line>_Label` names are NOT
        // produced - which is exactly what arms this sweep as the upgrade net:
        // the one handoff walk deletes every legacy label object a previous
        // build left on the chart, alongside the ladder names it always swept.
        s_fsPc = lineCount + zoneCount;
        ArrayResize(s_fsProduced, s_fsPc);
        int pc = 0;
        for(int l = 0; l < lineCount; l++)
            s_fsProduced[pc++] = lines[l].name;
        for(int z = 0; z < zoneCount; z++)
            s_fsProduced[pc++] = zones[z].name;

        s_fsFam = config.objectPrefix + config.modeName + "_";
        // P-PERF-55: the membership question is asked once per family name, so
        // the list is turned into a SET here — one O(pc) build, one probe per
        // name. `false` = the list is too big for the table: every test below
        // then uses the original exact scan, so the verdict cannot change.
        // The set is NOT rebuilt per chunk: nothing else calls LadderSetBuild
        // while a sweep is active.
        s_fsSet = LadderSetBuild(s_fsProduced, s_fsPc);

        // P-PERF-97 (BUG-10, 2026-10-13): ONE ALLOCATION FOR THE WHOLE WALK —
        // `total` is the exact upper bound on the names the walk can collect.
        const int total = ObjectsTotal(0, -1, -1);
        s_fsNd = 0;
        if(total > 0) ArrayResize(s_fsDoomed, total);
        s_fsCursor = total - 1;
        s_fsRemoved = 0;
        s_fsPhase = 0;
        s_fsActive = true;
    }

    if(s_fsPhase == 0)
    {
        // Phase 0: walk, SWEEP_FOREIGN_CHUNK objects this frame.
        int examined = 0;
        while(s_fsCursor >= 0 && examined < SWEEP_FOREIGN_CHUNK)
        {
            const string nm = ObjectName(0, s_fsCursor, -1, -1);
            s_fsCursor--;
            examined++;
            if(!LadderFamilyName(nm, s_fsFam)) continue;

            if(LadderNameIsZoneBand(nm))
            {
                if(s_fsSet ? LadderSetHas(nm) : ProducedLadderName(nm, s_fsProduced, s_fsPc)) continue;
                if(s_fsNd >= ArraySize(s_fsDoomed)) ArrayResize(s_fsDoomed, s_fsNd + 1);
                s_fsDoomed[s_fsNd++] = nm;
                continue;
            }
            if(StringFind(nm, "_Zone_") >= 0) continue;   // a border sub-object: its band decides

            if(s_fsSet ? LadderSetHas(nm) : ProducedLadderName(nm, s_fsProduced, s_fsPc)) continue;
            if(s_fsNd >= ArraySize(s_fsDoomed)) ArrayResize(s_fsDoomed, s_fsNd + 1);
            s_fsDoomed[s_fsNd++] = nm;
        }
        if(s_fsCursor >= 0) return -1;   // more to walk — the caller must not latch
        if(s_fsNd == 0) { s_fsActive = false; return 0; }
        s_fsPhase = 1;
    }

    // Phase 1: delete, SWEEP_FOREIGN_CHUNK names this frame (popped from the
    // end of the doomed list — the order never mattered).
    g_suppressDeleteEvents = true;
    int deleted = 0;
    while(s_fsNd > 0 && deleted < SWEEP_FOREIGN_CHUNK)
    {
        const string nm = s_fsDoomed[s_fsNd - 1];
        s_fsNd--;
        deleted++;
        if(StringFind(nm, "_Zone_") >= 0)
        {
            if(DeleteManagedZoneObjects(nm, true)) s_fsRemoved++;
        }
        else if(DeleteIndicatorObjectManaged(nm, true)) s_fsRemoved++;
    }
    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
    g_suppressDeleteEvents = false;
    if(s_fsNd > 0) return -1;   // more to delete — the caller must not latch
    const int removed = s_fsRemoved;
    s_fsActive = false;
    return removed;
}

SPipelineResult ExecutePipeline(
    const SModeConfig &config,
    const double centerPrice,
    const double &stepSizes[],
    const int stepSizeCount,
    const ENUM_LEVEL_STEP_MODE stepMode,
    const ENUM_CLASSIFY_MODE classifyMode,
    const bool lsFirst,
    const int maxLevelsAbove,
    const int maxLevelsBelow,
    const int buildStage)
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
    // P-PERF-06: the cull window arrives from the caller (RedrawAllObjects owns
    // the hysteretic window AND the staging snapshot — deriving it here a
    // second time could split staged families across two viewports).

    double fixedZoneStepSize = 0.0;
    if(config.modeName == "SSLS" && stepSizeCount > 1)
        fixedZoneStepSize = MathMin(stepSizes[0], stepSizes[1]);

    SZoneDefinition zones[];
    STriggerLine lines[];
    int maxStep = 0;

    //                                                                
    // P-PERF-18: THE STAGED REBUILD WAS RE-COMPUTING THE SAME MATH    
    //                                                                
    // P-PERF-06 splits a post-wipe rebuild (attach / TF switch /       
    // topology toggle) into four frames - lines, zones, labels, block  
    // - and every one of those frames called this function again, so   
    // CalculateLevels -> ClassifyLevels/Alternating -> BuildZonesAnd-  
    // Lines ran FOUR times with IDENTICAL inputs: on the weakest        
    // machine that is four times the level arithmetic and four times   
    // four times the label strings, for one switch. This is the         
    // "compute it once, at the right moment" rule (LEARNING §16): the   
    // staged frames are by construction "same geometry, another          
    // family", so the built lists are remembered under a key made of    
    // every input the three stages read. A tick that moves the base     
    // price, an input edit, or a mode switch changes the key and the    
    // math runs again - the cache can only ever answer for an unchanged
    // geometry. P-VIEW-05 (2026-10-16): the cull window used to be one
    // of those terms; it is gone from the key because nothing that is
    // BUILT or PAINTED ever read it (the build's `inViewport` flags had
    // no consumer), so a pan could only throw away a valid cache.
    //                                                                
    string geoKey = PipelineGeometryKey(config, centerPrice, stepSizes, stepSizeCount,
                                       stepMode, classifyMode, lsFirst, maxLevelsAbove,
                                       maxLevelsBelow,
                                       baseMultiplier);
    static string s_geoKey = "";
    static bool   s_geoValid = false;
    static SZoneDefinition s_geoZones[];
    static STriggerLine    s_geoLines[];
    static int    s_geoZoneCount = 0;
    static int    s_geoLineCount = 0;
    static int    s_geoMaxStep = 0;
    // P-LEVEL-FOREIGN-01: the ladder signature the foreign-object sweep last ran
    // against. "" means "never run" - the first real build always sweeps, which
    // is what cleans a chart that a previous instance left a foreign pitch on.
    static string s_lastStepSig = "";
    // P-LEVEL-FOREIGN-02: the chart walk below runs at most ONCE per instance.
    // The handoff is a per-instance event (the first real build of the new
    // instance is the frame after the switch), while a later intraday pitch
    // drift is not - and a whole-chart walk is ~26 ms on a chart carrying 800
    // objects, so it may not become a tax on every step-size refresh. Nothing
    // regresses by stopping there: before this sweep existed NO index was ever
    // swept on a drift either, and the price sweep plus the 6-miss index walk
    // still run on every pitch change.
    static bool s_foreignSweepDone = false;

    if(s_geoValid && geoKey == s_geoKey) {
        // Same geometry, another family: copy the built lists, skip the math.
        ArrayResize(zones, s_geoZoneCount);
        for(int z = 0; z < s_geoZoneCount; z++) zones[z] = s_geoZones[z];
        ArrayResize(lines, s_geoLineCount);
        for(int l = 0; l < s_geoLineCount; l++) lines[l] = s_geoLines[l];
        result.zoneCount = s_geoZoneCount;
        result.lineCount = s_geoLineCount;
        maxStep = s_geoMaxStep;
    }
    else {
        // Stage 1: Calculate (unified)
        SCalculatedLevel rawLevels[];
        int rawCount = CalculateLevels(centerPrice, stepSizes, stepSizeCount, stepMode,
                                        lsFirst, maxLevelsAbove, maxLevelsBelow,
                                        config.boundByHistorical, config.maxPrice, config.minPrice,
                                        rawLevels, maxStep);
        if(rawCount == 0) {
            result.errorMessage = "No levels calculated";
            s_geoValid = false;   // never serve a geometry for a config that produced none
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
        BuildZonesAndLines(classified, classifiedCount, config,
                           fixedZoneStepSize, zones, result.zoneCount, lines, result.lineCount);

        // Remember the result for the other families of this same rebuild.
        ArrayResize(s_geoZones, result.zoneCount);
        for(int zc = 0; zc < result.zoneCount; zc++) s_geoZones[zc] = zones[zc];
        ArrayResize(s_geoLines, result.lineCount);
        for(int lc = 0; lc < result.lineCount; lc++) s_geoLines[lc] = lines[lc];
        s_geoZoneCount = result.zoneCount;
        s_geoLineCount = result.lineCount;
        s_geoMaxStep = maxStep;
        s_geoKey = geoKey;
        s_geoValid = true;

        // P-LEVEL-FOREIGN-01: the ladder itself moved (a timeframe switch, a mode
        // change, an ATR-scaling regime change), so objects written by the
        // previous pitch are still on the chart with valid names and valid step
        // indices - and no sweep in the project could recognise them. This is the
        // one moment they can be identified: against the lists just built. Runs
        // BEFORE the render below, which re-creates whatever is in the viewport.
        {
            string stepSig = IntegerToString((int)stepMode) + "," + IntegerToString(stepSizeCount);
            for(int ss = 0; ss < stepSizeCount; ss++) stepSig += "," + DoubleToString(stepSizes[ss], 8);
            // P-UI-153 (2026-10-02) — A HAND MID-DRAG DOES NOT SWEEP THE PITCH.
            //
            // User order: «هنوز هم مثل خود خط کاستوم پرایس ریل تایم واقعی نشده ...
            // برای اون نقاط قرمز معماری شئ کپی کن». MEASURED FIRST, on the flushed
            // channel, by pricing the ONE frame owner both hand-set gestures share
            // (P-UI-152's `[drag]` witness):
            //   the custom price LINE drag  ->  ms=0..16,  lv=0..16
            //   the step-1 handle drag      ->  ms=172..203, lv == ms, on EVERY step
            // So the whole cost of a step-1 step is the LEVELS phase, and this pass
            // is why: the handle's drag changes the STEP SIZES, `stepSig` therefore
            // changes on every held event, and this block runs on every one of them.
            // It then finds the cache's `lastPrice` for the SAME name disagreeing
            // with the new pitch (the family has just moved) and DELETES those
            // objects - so the render that follows re-CREATES a whole family per
            // step (ObjectDelete + ObjectCreate + every property) instead of
            // re-pricing it in place. The custom price line's drag never trips this
            // pass: it moves the CENTRE, the step sizes and `stepSig` are untouched,
            // and its frames are the render alone (16 ms). THAT is the architecture
            // the user asked to copy, and this is the half of it the handle lacked.
            //
            // The pass's own reason to exist is "the ladder ITSELF moved": a
            // timeframe switch, a mode change, an ATR-scaling regime change - the
            // moments in which nothing else can name the objects a previous pitch
            // left behind. A hand on the handle is none of those: the same names are
            // about to be re-asserted at the new pitch by the render line below, and
            // whatever the new ladder no longer produces is removed by
            // `CleanupSurplusPipeline`, which already throttles itself to 250 ms for
            // a live gesture for exactly this reason.
            //
            // So the pass is DEFERRED, never dropped: `s_lastStepSig` is left stale
            // on purpose while a gesture is live, and the release's own forced frame
            // (both drag flags are down by then) sweeps ONCE against the final pitch
            // - the frame that can afford it. This also retires the P-UI-98k hazard
            // at its source: the pass that could delete the very line under the hand
            // no longer runs under the hand at all.
            // P-PERF-108 (2026-10-16): the SAME deferral covers the transient
            // history window — a sweep against the synthetic ±1% ladder would
            // delete names the real build is about to re-assert. The latch is
            // taken only when `g_initialized` (the real ladder), so the sweep
            // runs once, against the pitch that actually stays.
            if(stepSig != s_lastStepSig && g_initialized
               && !g_s1DragLive && !g_customPriceLineDragging)
            {
                s_lastStepSig = stepSig;
                int swept = SweepForeignLevelObjects(config, lines, result.lineCount,
                                                     zones, result.zoneCount);
                if(swept > 0)
                    _LOG_GATE_I Print("[I][GEN] P-LEVEL-FOREIGN-01: swept ", swept,
                                      " level object(s) left by a previous step geometry");
                // P-PERF-107 (2026-10-16): the P-LEVEL-FOREIGN-02 sweep that
                // stood here MOVED OUT of this block — it is resumable now and
                // must advance on every frame, not only on the frame the pitch
                // changed. See the hoisted caller before Stage 5 below.
            }
        }
    }
    
    // P-PERF-107 (2026-10-16) — THE HANDOFF SWEEP IS RESUMABLE, SO IT RUNS
    // OUTSIDE THE stepSig BLOCK.
    //
    // The sweep's walk is ~1 s of ObjectName calls on the user's chart and it
    // used to block the FIRST RENDER of the handoff frame (measured 2026-10-16:
    // H1 rest=1016 ms / D1 rest=1062 ms, with the chart empty until it ended).
    // It is chunked now (SweepForeignLadderObjects returns -1 while it is still
    // walking), so it has to advance on EVERY frame — not only on the frame the
    // ladder pitch changed — and s_foreignSweepDone is latched only when the
    // sweep RETURNS (>= 0).
    //
    // The semantics are unchanged from P-LEVEL-FOREIGN-02: only after a HANDOFF
    // (g_adoptPreviousTopology), only once per instance, and the names it can
    // reach are the ones the new ladder does not produce AT ALL — which is what
    // lets a timeframe switch UPDATE the family in place (the render re-asserts
    // every produced name, this deletes the rest) instead of wiping it.
    // P-PERF-107b: the drag guards the old stepSig block carried are kept here
    // - the sweep must not delete the level under the hand (P-UI-98k); it
    // simply pauses and resumes, the statics carry the chunk state across.
    // P-PERF-108 (2026-10-16): and it does not START against a transient
    // build — the produced set it walks against must be the REAL ladder, or
    // its deletes land on names the next frame re-creates (the same blink the
    // cleanup gate above kills; this is the ladder-sweep half of it).
    if(g_adoptPreviousTopology && g_initialized && !s_foreignSweepDone
       && !g_s1DragLive && !g_customPriceLineDragging)
    {
        int stale = SweepForeignLadderObjects(config, lines, result.lineCount,
                                              zones, result.zoneCount);
        if(stale >= 0)
        {
            s_foreignSweepDone = true;   // the handoff's sweep has finished
            if(stale > 0)
                _LOG_GATE_W Print("[W][GEN] P-LEVEL-FOREIGN-02: deleted ", stale,
                                  " ladder object(s) this build does not produce ",
                                  "(handoff, family=", config.modeName, ")");
        }
    }

    // Stage 5: Render and cleanup.
    // P-PERF-06 STAGED RENDER: the math above (Calculate/Classify/Build) is
    // pure CPU (~ms) and re-runs every stage; only ONE object family is
    // materialised per frame, so a post-wipe build lands as a few ~2k-call
    // frames instead of one ~8k-call freeze. buildStage 0 (or anything
    // unexpected) is the full legacy render — steady frames always take it.
    // P-LBL-12 (2026-10-17): there were FOUR rungs (1=lines, 2=zones, 3=pip
    // labels, 4=labels block). The pip labels are retired, so stage 3 is gone;
    // the surplus cleanup it used to carry (a full family re-assert had just
    // run in that frame) now rides the ZONES rung, which is the last family
    // frame before the labels block seals the rebuild.
    if(buildStage == BUILD_STAGE_LINES) {
        RenderTriggerLines(lines, result.lineCount, config, true);
    } else if(buildStage == BUILD_STAGE_ZONES) {
        RenderZones(zones, result.zoneCount, config);

        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    } else {
        RenderZones(zones, result.zoneCount, config);
        RenderTriggerLines(lines, result.lineCount, config, true);

        // PERF: maxStep already known from CalculateLevels output (no extra O(n) scan needed)
        CleanupSurplusPipeline(config, maxStep);
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // P-VIEW-04 (2026-09-29) — THE "MIDDLE BAND IS EMPTY" CENSUS, ONE LINE,
    // ONE NUMBER PER STAGE. Reported by the user with a screenshot (EURUSD M15,
    // price 1.139): the family was drawn from 1.15185 up to 1.17630 and two rungs
    // at the bottom (1.11520 / 1.11250), while the whole band between them — nine
    // rungs on the SAME pitch — was absent. A hole in the MIDDLE cannot be explained
    // by a count limit at either end, so the loss is somewhere in the chain
    //   ladder -> classified -> BuildZonesAndLines -> RenderTriggerLines -> object
    // and this line says WHERE, once, with numbers:
    //   lines=<built>  nearAbove/nearBelow = the closest built line to the centre on
    //   each side (a build whose nearest above is 3 pitches away IS the hole, said
    //   numerically), pitch=maxStep, span=[lo..hi] of the built list, then the two
    //   object-level answers that separate the two remaining causes:
    //     absent=<n>  the name is in `lines[]` but NO object holds it   -> deleted/
    //                 name collision (a sweep, a duplicate logicalStep);
    //     hidden=<n>  the object exists but its mask is not ALL_PERIODS -> a mask
    //                 writer owns it (F / L / a per-TF rule).
    // A still picture prints nothing: the guard is the shape itself, so this costs
    // one string compare per rebuild and one line of log per SHAPE change.
    // P-VIEW-05 (2026-10-16): the window is out of the shape too — a pan is not
    // a change of the built family and must not make the census speak.
    {
        static string s_lastViewCensus = "";
        string shape = IntegerToString(result.lineCount) + ":" + IntegerToString(result.zoneCount);
        if(shape != s_lastViewCensus)
        {
            s_lastViewCensus = shape;
            double lo = 0.0, hi = 0.0;
            double nearAbove = 0.0, nearBelow = 0.0;
            int absent = 0;
            long rawMask = 0, maskMin = 0, maskMax = 0;
            for(int ci = 0; ci < result.lineCount; ci++)
            {
                double p = lines[ci].price;
                if(lo == 0.0 || p < lo) lo = p;
                if(p > hi) hi = p;
                if(p > centerPrice && (nearAbove == 0.0 || p < nearAbove)) nearAbove = p;
                if(p < centerPrice && (nearBelow == 0.0 || p > nearBelow)) nearBelow = p;
                if(ObjectFind(0, lines[ci].name) < 0) absent++;
                else
                {
                    // P-VIEW-04b: the mask is compared against OBJ_NO_PERIODS and the
                    // RAW value is carried out with it. `!= OBJ_ALL_PERIODS` was a
                    // WRONG test and it said `hidden=288` of 288 lines on a chart that
                    // visibly paints its levels: MT4 stores "every timeframe" as a
                    // 32-bit -1, while the constant's own value can be read as
                    // 0xFFFFFFFF, so a signed-long compare calls every VISIBLE object
                    // hidden. OBJ_NO_PERIODS is 0 on both sides of that edge.
                    // P-VIEW-04c: NOT `hidden++`. The census must not depend on
                    // OBJ_NO_PERIODS vs OBJ_ALL_PERIODS being distinct numbers in this
                    // compiler: measured `rawMask=-1` on every level of a chart that
                    // paints them, while the counter built on `== OBJ_NO_PERIODS`
                    // called all of them hidden — i.e. the two constants share the
                    // value -1 here and the comparison proves nothing. The FACT is the
                    // range of the raw masks across the family: `maskMin=maskMax=-1`
                    // means every level carries the same mask the painter wrote.
                    long m = (long)ObjectGetInteger(0, lines[ci].name, OBJPROP_TIMEFRAMES);
                    if(ci == 0) { rawMask = m; maskMin = m; maskMax = m; }
                    if(m < maskMin) maskMin = m;
                    if(m > maskMax) maskMax = m;
                }
            }
            _LOG_GATE_D Print("[P-VIEW] stage=census lines=", result.lineCount, " zones=", result.zoneCount,
                  " pitch=", DoubleToString(maxStep, GetCachedDigits()),
                  " centre=", DoubleToString(centerPrice, GetCachedDigits()),
                  " nearAbove=", DoubleToString(nearAbove, GetCachedDigits()),
                  " nearBelow=", DoubleToString(nearBelow, GetCachedDigits()),
                  " span=", DoubleToString(lo, GetCachedDigits()), "..", DoubleToString(hi, GetCachedDigits()),
                  " absent=", absent, " mask=", (int)maskMin, "..", (int)maskMax,
                  " stage=", buildStage);
        }
    }

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

#endif // LEVEL_PIPE_B_MQH

#endif // LEVEL_PIPELINE_MQH
