#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneValidator.mqh"

//+------------------------------------------------------------------+
//| Helper: Check if Structure Level (FIXED: Proper hierarchy)      |

//|                                                                  |
//| OLD LOGIC (WRONG):                                               |
//| Step 16 with Base=4 → 16%4=0 → L1 ✅ AND 16%16=0 → L2 ✅        |
//| This causes overlaps!                                            |
//|                                                                  |
//| NEW LOGIC (CORRECT):                                             |
//| Step 16 with Base=4 → Highest level only = L2                   |
//| A step is Structure if it's divisible by base BUT NOT by base²  |
//| unless it's also divisible by base², then it's higher level     |
//|                                                                  |
//| EXAMPLES with Base=4:                                            |
//| Step 4:  4%4=0, 4%16≠0 → Structure L1 ✅                         |
//| Step 8:  8%4=0, 8%16≠0 → Structure L1 ✅                         |
//| Step 12: 12%4=0, 12%16≠0 → Structure L1 ✅                       |
//| Step 16: 16%4=0, 16%16=0 → Structure L2 (not L1) ✅             |
//|                                                                  |
//| @param step The step number to check                            |
//| @param baseMult The power base multiplier (2-9)                 |
//| @return true if this step is ANY structure level                |
//+------------------------------------------------------------------+
bool IsStructureLevel(int step, int baseMult)
{
        if(baseMult <= 1) return true;
    
    // A step is Structure if it's divisible by the base
    // (The specific level L1-L5 is determined elsewhere)
    return (step % baseMult == 0);
}

//+------------------------------------------------------------------+
//| Classify Levels (Active/Inactive, Structure/Trigger)            |

//+------------------------------------------------------------------+
void ClassifyLevels(
    const SLevelRawData &levels[],
    const SStyleConfig &config,
    SLevelClassification &outClassifications[])
{
        int count = ArraySize(levels);
    ArrayResize(outClassifications, count);
    
    // OPTIMIZATION: Use centralized cached Digits from PerformanceOptimizations.mqh
    int s_cachedDigits = GetCachedDigits();
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔍 ZONE CLASSIFICATION: struct=", config.showStructure, " trigger=", config.showTrigger, " mult=", config.baseMultiplier);
    #endif
    for(int i = 0; i < count; i++) {
        // Determine if Structure Level
        bool isStructure = (levels[i].logicalStep == 0) || 
                          IsStructureLevel(levels[i].logicalStep, config.baseMultiplier);
    outClassifications[i].isStructure = isStructure;
        
        // Determine if Active (should be included in calculations)
        bool isActive = false;
    color levelColor = clrNONE;
    int style = STYLE_SOLID;
    int width = 1;
        
        // For modes like TP/Combo where baseMultiplier=1,
        // ALL levels should be active (showStructure=true, all are structure)
        if(config.showStructure && isStructure) {
            isActive = true;
    levelColor = config.structColorL1;
    style = config.structStyleL1;
    width = config.structWidthL1;
        }
        else if(config.showTrigger && !isStructure) {
            isActive = true;
    levelColor = config.triggerColor;
    style = config.triggerStyle;
    width = config.triggerWidth;
        }
        
        // FALLBACK: If neither condition met but we have valid config,
        // use structure settings (for TP/Combo modes)
        if(!isActive && config.showStructure) {
            isActive = true;
    levelColor = config.structColorL1;
    style = config.structStyleL1;
    width = config.structWidthL1;
        }
        
        outClassifications[i].isActive = isActive;
    outClassifications[i].levelColor = levelColor;
    outClassifications[i].style = style;
    outClassifications[i].width = width;
        
        // Per-level classification logging removed for performance
    }
    #ifdef ENABLE_DEBUG_LOGS
    int activeCount = 0;
    int structureCount = 0;
    int triggerCount = 0;
    for(int i = 0; i < count; i++) {
        if(outClassifications[i].isActive) {
            activeCount++;
    if(outClassifications[i].isStructure) structureCount++;
    else triggerCount++;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("───────────────────────────────────────────────────────────");
    Print("✅ ClassifyLevels Summary:");
    Print("   Total Levels: ", count);
    Print("   Active Levels: ", activeCount);
    Print("   Structure Levels: ", structureCount);
    Print("   Trigger Levels: ", triggerCount);
    Print("═══════════════════════════════════════════════════════════");
    #endif
    #endif
}

//+------------------------------------------------------------------+
//| Geometry Calculation Cache - NOW MANAGED BY CalculationCache.mqh |

//| Requirements: 9.4                                                 |
//| NOTE: All geometry cache functions removed - use CalculationCache|
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Zone Geometries (with Caching)                         |

//| Array bounds validation                            |
//| OPTIMIZATION: Geometry calculation caching (Requirement 9.4)     |
//+------------------------------------------------------------------+
void CalculateZoneGeometries(
    const SLevelRawData &levels[],
    const SLevelClassification &classifications[],
    double zoneHeight,
    SZoneGeometry &outGeometries[])
{
        int count = ArraySize(levels);
    int classCount = ArraySize(classifications);
    
    // OPTIMIZATION: Use centralized cached Digits from PerformanceOptimizations.mqh
    int s_cachedDigits = GetCachedDigits();
    
    // ═══════════════════════════════════════════════════════════════
    // Array size validation
    // ═══════════════════════════════════════════════════════════════
    if(classCount != count) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateZoneGeometries: Array size mismatch - levels=", count, 
              ", classifications=", classCount);
    #endif
    ArrayResize(outGeometries, 0);
    return;
    }
    
    // SECURITY: Validate count is within safe limits
    if(count <= 0 || count > MAX_SAFE_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateZoneGeometries: Invalid level count=", count);
    #endif
    ArrayResize(outGeometries, 0);
    return;
    }
    
    // ═══════════════════════════════════════════════════════════════    // ═══════════════════════════════════════════════════════════════
    // NOTE: Geometry caching is now handled by CalculationCache.mqh
    // This function no longer uses local cache - all caching centralized
    
    // Cache miss - calculate geometries
    ArrayResize(outGeometries, count);
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔍 ZONE GEOMETRY: levels=", count, " height=", DoubleToString(zoneHeight, s_cachedDigits));
    #endif
    
    // Initialize ALL trackers (structure + trigger) with midpoint
    double lastStructurePriceAbove = -1;
    double lastStructurePriceBelow = -1;
    double lastTriggerPriceAbove = -1;
    double lastTriggerPriceBelow = -1;
    bool midpointFound = false;
    
    // Find and initialize with midpoint
    for(int i = 0; i < count; i++) {
        // Bounds check before access
        if(i >= count || i >= classCount) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Index out of bounds: i=", i, ", count=", count, ", classCount=", classCount);
    #endif
    break;
        }
    if(levels[i].logicalStep == 0) {
            lastStructurePriceAbove = levels[i].price;
    lastStructurePriceBelow = levels[i].price;
    lastTriggerPriceAbove = levels[i].price;
    lastTriggerPriceBelow = levels[i].price;
    midpointFound = true;
    #ifdef ENABLE_DEBUG_LOGS
            Print("📍 Midpoint Found at Index ", i, ": ", DoubleToString(levels[i].price, s_cachedDigits));
    #endif
    break;
        }
    }
    
    
    if(!midpointFound) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateZoneGeometries: Midpoint not found in levels array");
    #endif
    ArrayResize(outGeometries, 0);
    return;
    }
    
    // Calculate Zone Geometries
    int validZoneCount = 0;
    #ifdef ENABLE_DEBUG_LOGS
    Print("Zone Calculation: ", count, " levels");
    #endif
    for(int i = 0; i < count; i++) {
        // Bounds check
        if(i >= count || i >= classCount) {
            break;
        }
        
        outGeometries[i].isValid = false;
    outGeometries[i].linkedLevelIndex = i;
        
        // Skip if level is not active
        if(!classifications[i].isActive) {
            continue;
        }
        
        // Skip midpoint (no zone for midpoint itself)
        if(levels[i].logicalStep == 0) {
            continue;
        }
        
        // Determine Previous Price based on Structure/Trigger type
        double prevPrice = 0;
    bool canCalculate = false;
    bool isStructure = classifications[i].isStructure;
    if(levels[i].logicalStep > 0) {
            // Above midpoint
            if(isStructure) {
        if(lastStructurePriceAbove > 0) {
                    prevPrice = lastStructurePriceAbove;
    canCalculate = true;
                }
                lastStructurePriceAbove = levels[i].price;
            }
            else {
        if(lastTriggerPriceAbove > 0) {
                    prevPrice = lastTriggerPriceAbove;
    canCalculate = true;
                }
                lastTriggerPriceAbove = levels[i].price;
            }
        }
        else {
            // Below midpoint
            if(isStructure) {
        if(lastStructurePriceBelow > 0) {
                    prevPrice = lastStructurePriceBelow;
    canCalculate = true;
                }
                lastStructurePriceBelow = levels[i].price;
            }
            else {
        if(lastTriggerPriceBelow > 0) {
                    prevPrice = lastTriggerPriceBelow;
    canCalculate = true;
                }
                lastTriggerPriceBelow = levels[i].price;
            }
        }
        
        // Calculate Zone Boundaries
        if(canCalculate) {
            // Validate geometry before calculating
            SZoneValidationResult validation = 
                ValidateZoneGeometry(prevPrice, levels[i].price, zoneHeight);
    if(validation.isValid) {
        double midPoint = (prevPrice + levels[i].price) / 2.0;
    double topPrice = midPoint + zoneHeight;
    double bottomPrice = midPoint - zoneHeight;
    outGeometries[i].isValid = true;
    outGeometries[i].topPrice = NormalizeDouble(topPrice, s_cachedDigits);
    outGeometries[i].bottomPrice = NormalizeDouble(bottomPrice, s_cachedDigits);
    outGeometries[i].midPoint = NormalizeDouble(midPoint, s_cachedDigits);
    validZoneCount++;
            }
            else {
        #ifdef ENABLE_DEBUG_LOGS
                Print("Zone geometry invalid for step ", levels[i].logicalStep, ": ", validation.errorMessage);
    #endif
    }
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("CalculateZoneGeometries: ", validZoneCount, " valid zones");
    #endif
    
    // NOTE: Geometry caching is now handled by CalculationCache.mqh
}
