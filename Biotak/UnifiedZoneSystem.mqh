#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

// CRITICAL: Include guard to prevent duplicate symbols
#ifndef UNIFIED_ZONE_SYSTEM_MQH
#define UNIFIED_ZONE_SYSTEM_MQH

#include "ZoneFactory.mqh"

// CONSTANTS: Zone configuration defaults
#define DEFAULT_ZONE_HEIGHT_PERCENT 0.125  // 12.5% of step (6.25% each side)
#define MIN_ZONE_HEIGHT_PERCENT 0.01       // Minimum 1%
#define MAX_ZONE_HEIGHT_PERCENT 1.0        // Maximum 100%

//+------------------------------------------------------------------+
//| UNIFIED ZONE CONFIGURATION                                        |

//|                                                                  |

//+------------------------------------------------------------------+
struct SUnifiedZoneConfig {
        bool enabled;
    int transparency;
    double heightPercent;
    bool separateStructureTrigger;
    color defaultColor;
    ENUM_ZONE_STYLE style;    
};

//+------------------------------------------------------------------+
//| CREATE ZONE BETWEEN TWO LEVELS - UNIFIED METHOD                  |

//|                                                                  |

//| - M Mode, SS/LS Mode, Factor Mode, TP Mode, etc.                |
//|                                                                  |

//+------------------------------------------------------------------+
bool CreateUnifiedZone(const string zoneName,
                       const double prevLevelPrice,
                       const double currentLevelPrice,
                       const SUnifiedZoneConfig &config,
                       const color levelColor)
{
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: VALIDATION (Fail Fast)
    // ═══════════════════════════════════════════════════════════════
    
    // CRITICAL DIAGNOSTIC: Always print (not just in debug mode)
    static int callCount = 0;
    callCount++;
    #ifdef ENABLE_DEBUG_LOGS
    if(callCount <= 5) {  // Only first 5 calls to avoid spam
        Print("🔍 ZONE: '", zoneName, "' TF=", PeriodMinutes(), 
              "min, Enabled=", (config.enabled ? "YES" : "NO"), 
              ", Style=", (int)config.style);
    }
    #endif
    
    // Check if zones are enabled
    if(!config.enabled) {
        #ifdef ENABLE_DEBUG_LOGS
        if(callCount <= 5) {
            Print("⚠️ ZONE: DISABLED globally");
        }
    #endif
    return true; // Not an error, just disabled
    }
    
    // Check style: HIDDEN
    if(config.style == FACTOR_ZONE_HIDDEN) {
        #ifdef ENABLE_DEBUG_LOGS
        if(callCount <= 5) {
            Print("⚠️ ZONE: Style is HIDDEN");
        }
    #endif
        // Delete zone if exists
        if(ObjectFind(0, zoneName) >= 0) ObjectDelete(0, zoneName);
    return true; // Not an error, just hidden
    }
    
    // Validate zone name
    if(StringLen(zoneName) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Empty zone name");
    #endif
    return false;
    }
    
    // Validate prices
    if(prevLevelPrice <= 0 || currentLevelPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Invalid prices - Prev=", DoubleToString(prevLevelPrice, Digits),
              ", Current=", DoubleToString(currentLevelPrice, Digits));
    #endif
    return false;
    }
    
    // Check if prices are equal (no zone needed)
    // Use epsilon comparison instead of exact float ==
    if(AreEqual(prevLevelPrice, currentLevelPrice, EPSILON_PRICE)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CreateUnifiedZone: Prices are equal - no zone needed");
    #endif
    return true; // Not an error
    }
    
    // Validate height percent
    if(config.heightPercent < MIN_ZONE_HEIGHT_PERCENT || config.heightPercent > MAX_ZONE_HEIGHT_PERCENT) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Invalid height percent: ", config.heightPercent,
              " (must be between ", MIN_ZONE_HEIGHT_PERCENT, " and ", MAX_ZONE_HEIGHT_PERCENT, ")");
    #endif
    return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: CALCULATE ZONE GEOMETRY
    // ═══════════════════════════════════════════════════════════════
    
    // Calculate step size (distance between levels)
    double stepSize = MathAbs(currentLevelPrice - prevLevelPrice);
    
    // Validate step size
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Invalid step size: ", stepSize);
    #endif
    return false;
    }
    
    // Calculate zone height (percentage of step size)
    double zoneHeight = stepSize * config.heightPercent * 0.5; // 0.5 because ±height
    
    // Calculate midpoint between two levels
    double midPoint = (prevLevelPrice + currentLevelPrice) / 2.0;
    
    // Calculate zone boundaries
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
    
    // Validate zone boundaries
    if(upperPrice <= lowerPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Invalid zone boundaries - Upper=", DoubleToString(upperPrice, Digits),
              ", Lower=", DoubleToString(lowerPrice, Digits));
    #endif
    return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: HANDLE LINES STYLE (Special Case)
    // ═══════════════════════════════════════════════════════════════
    
    if(config.style == FACTOR_ZONE_LINES) {
        // Use special lines-only implementation
        return CreateFactorMidZone_LinesStyle(zoneName, upperPrice, lowerPrice,
                                              (levelColor == clrNONE) ? config.defaultColor : levelColor,
                                              config.transparency);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 4: DELEGATE TO ZONE FACTORY (Box Styles)
    // ═══════════════════════════════════════════════════════════════
    
    SZoneCreationRequest request;
    request.name = zoneName;
    request.topPrice = upperPrice;
    request.bottomPrice = lowerPrice;
    request.zoneColor = (levelColor == clrNONE) ? config.defaultColor : levelColor;
    request.transparency = config.transparency;
    request.filled = (config.style == FACTOR_ZONE_BOX_FILLED);
    request.startTime = 0;  // Auto-calculate
    request.endTime = 0;    // Auto-calculate
    
    SZoneCreationResult result = CreateZone(request);
    if(!result.success) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateUnifiedZone: Factory failed for '", zoneName, "' - ", result.errorMessage,
              " (Code: ", result.errorCode, ")");
    #endif
    return false;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CreateUnifiedZone: Created/Updated '", zoneName, "' [",
          DoubleToString(lowerPrice, Digits), " - ", DoubleToString(upperPrice, Digits), "]");
    #endif
    return true;
}

//+------------------------------------------------------------------+
//| GET UNIFIED ZONE CONFIG FROM GLOBAL SETTINGS                     |

//|                                                                  |

//| Added validation for global variables               |
//| Added style support for all modes                  |
//+------------------------------------------------------------------+
SUnifiedZoneConfig GetUnifiedZoneConfig()
{
    SUnifiedZoneConfig config;
    
    // Validate global variables exist and have valid values
    // Read from global input parameters with safe defaults
    config.enabled = inpShowMidZones;
    
    // Validate and clamp transparency
    config.transparency = inpMidZoneTransparency;
    if(config.transparency < 0) config.transparency = 0;
    if(config.transparency > 100) config.transparency = 100;
    
    // Use configurable zone height from input parameter
    // Convert from percentage (1-100) to decimal (0.01-1.0)
    double heightPercentInput = inpMidZoneHeightPercent / 100.0;
    
    // Validate and clamp height percent
    if(heightPercentInput < MIN_ZONE_HEIGHT_PERCENT) {
        heightPercentInput = MIN_ZONE_HEIGHT_PERCENT;
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetUnifiedZoneConfig: Zone height too small, clamped to ", 
              MIN_ZONE_HEIGHT_PERCENT * 100, "%");
    #endif
    }
    if(heightPercentInput > MAX_ZONE_HEIGHT_PERCENT) {
        heightPercentInput = MAX_ZONE_HEIGHT_PERCENT;
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetUnifiedZoneConfig: Zone height too large, clamped to ", 
              MAX_ZONE_HEIGHT_PERCENT * 100, "%");
    #endif
    }
    
    config.heightPercent = heightPercentInput;
    config.separateStructureTrigger = true;
    config.defaultColor = clrDarkGray;
    
    // Add style support
    config.style = inpMidZoneStyle;
    return config;
}

//+------------------------------------------------------------------+
//| CREATE ZONE WITH TRACKING - FOR STRUCTURE/TRIGGER SEPARATION    |

//|                                                                  |

//|                                                                  |
//| Removed unused prevPrice parameter                  |
//|                                                                  |

//+------------------------------------------------------------------+
bool CreateZoneWithTracking(const string zoneName,
                            const double currentPrice,
                            const bool isStructure,
                            const color levelColor,
                            double &lastStructurePrice,
                            double &lastTriggerPrice)
{
    SUnifiedZoneConfig config = GetUnifiedZoneConfig();
    
    // Determine which "last price" to use based on structure/trigger
    double effectivePrevPrice = 0;
    if(isStructure) {
        effectivePrevPrice = lastStructurePrice;
    lastStructurePrice = currentPrice; // Update tracker
    }
    else {
        effectivePrevPrice = lastTriggerPrice;
    lastTriggerPrice = currentPrice; // Update tracker
    }
    
    // Only create zone if we have a previous price
    if(effectivePrevPrice <= 0) {
        return true; // Not an error, just first level
    }
    
    // Create zone using unified method
    return CreateUnifiedZone(zoneName, effectivePrevPrice, currentPrice, config, levelColor);
}

//+------------------------------------------------------------------+
//| CREATE SIMPLE ZONE - FOR MODES WITHOUT STRUCTURE/TRIGGER        |

//|                                                                  |

//|                                                                  |

//+------------------------------------------------------------------+
bool CreateSimpleZone(const string zoneName,
                      const double prevPrice,
                      const double currentPrice,
                      const color levelColor)
{
    SUnifiedZoneConfig config = GetUnifiedZoneConfig();
    return CreateUnifiedZone(zoneName, prevPrice, currentPrice, config, levelColor);
}

//+------------------------------------------------------------------+
//| CREATE ZONE WITH SMART FALLBACK - UNIFIED FOR ALL MODES         |

//|                                                                  |

//|                                                                  |
//| LOGIC:                                                           |

//|                                                                  |
//| Added fixedStepSize parameter for consistent zones|
//|                                                                  |

//+------------------------------------------------------------------+
bool CreateZoneWithSmartFallback(const string zoneName,
                                 const double currentPrice,
                                 const bool isStructure,
                                 const color levelColor,
                                 const bool structureEnabled,
                                 const bool triggerEnabled,
                                 double &lastStructurePrice,
                                 double &lastTriggerPrice,
                                 double &lastFallbackPrice,
                                 const double fixedStepSize = 0)
{
    SUnifiedZoneConfig config = GetUnifiedZoneConfig();
    
    // CRITICAL DIAGNOSTIC - Track per timeframe
    static int m15Count = 0, m30Count = 0;
    int currentTF = PeriodMinutes();
    #ifdef ENABLE_DEBUG_LOGS
    if(currentTF == 15 && m15Count < 5) {
        m15Count++;
    Print("🔍 M15-FALLBACK #", m15Count, ": Enabled=", (config.enabled ? "YES" : "NO"));
    }
    else if(currentTF == 30 && m30Count < 5) {
        m30Count++;
    Print("🔍 M30-FALLBACK #", m30Count, ": Enabled=", (config.enabled ? "YES" : "NO"));
    }
    #endif
    
    // Check if zones are enabled globally
    if(!config.enabled) {
        // Zones disabled - still update tracking variables but don't draw
        #ifdef ENABLE_DEBUG_LOGS
        if(currentTF == 15 && m15Count <= 5) {
            Print("🔍 M15-DISABLED: Returning early");
        }
        else if(currentTF == 30 && m30Count <= 5) {
            Print("🔍 M30-DISABLED: Returning early");
        }
    #endif
    if(isStructure && structureEnabled) {
            lastStructurePrice = currentPrice;
        }
        else if(!isStructure && triggerEnabled) {
            lastTriggerPrice = currentPrice;
        }
        else {
            lastFallbackPrice = currentPrice;
        }
    return true; // Not an error, just disabled
    }
    
    // Determine which tracking path to use
    double effectivePrevPrice = 0;
    bool shouldDraw = false;
    if(isStructure && structureEnabled) {
        // Structure zone path
        effectivePrevPrice = lastStructurePrice;
    shouldDraw = (lastStructurePrice > 0);
    lastStructurePrice = currentPrice;
    }
    else if(!isStructure && triggerEnabled) {
        // Trigger zone path
        effectivePrevPrice = lastTriggerPrice;
    shouldDraw = (lastTriggerPrice > 0);
    lastTriggerPrice = currentPrice;
    }
    else {
        // FALLBACK: Neither Structure nor Trigger enabled
        // Draw zone using level's own color
        effectivePrevPrice = lastFallbackPrice;
    shouldDraw = (lastFallbackPrice > 0);
    lastFallbackPrice = currentPrice;
    }
    
    // CRITICAL DIAGNOSTIC
    #ifdef ENABLE_DEBUG_LOGS
    if((currentTF == 15 && m15Count <= 5) || (currentTF == 30 && m30Count <= 5)) {
        Print("🔍 TF", currentTF, "-TRACK: shouldDraw=", (shouldDraw ? "YES" : "NO"), 
              ", prevPrice=", DoubleToString(effectivePrevPrice, 5));
    }
    #endif
    
    // Only create zone if we have a previous price
    if(!shouldDraw || effectivePrevPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        if((currentTF == 15 && m15Count <= 5) || (currentTF == 30 && m30Count <= 5)) {
            Print("🔍 TF", currentTF, "-SKIP: First level or no prev price");
        }
    #endif
    return true; // Not an error, just first level
    }
    
    // CRITICAL DIAGNOSTIC
    #ifdef ENABLE_DEBUG_LOGS
    if((currentTF == 15 && m15Count <= 5) || (currentTF == 30 && m30Count <= 5)) {
        Print("🔍 TF", currentTF, "-STEP: fixedStepSize=", DoubleToString(fixedStepSize, 5));
    }
    #endif
    
    // Use fixed step size if provided
    if(fixedStepSize > 0) {
        // fixedStepSize is the STEP SIZE, not the distance
        // We need to calculate zone height based on the ACTUAL distance between levels
        double actualDistance = MathAbs(currentPrice - effectivePrevPrice);
    double zoneHeight = actualDistance * config.heightPercent * 0.5;
    double midPoint = (effectivePrevPrice + currentPrice) / 2.0;
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
        
        // CRITICAL DIAGNOSTIC
        #ifdef ENABLE_DEBUG_LOGS
        if((currentTF == 15 && m15Count <= 5) || (currentTF == 30 && m30Count <= 5)) {
            Print("🔍 TF", currentTF, "-ZONE: upper=", DoubleToString(upperPrice, 5), 
                  ", lower=", DoubleToString(lowerPrice, 5), ", dist=", DoubleToString(actualDistance, 5));
        }
    #endif
        
        // Handle LINES style (special case)
        if(config.style == FACTOR_ZONE_LINES) {
        return CreateFactorMidZone_LinesStyle(zoneName, upperPrice, lowerPrice,
                                                  (levelColor == clrNONE) ? config.defaultColor : levelColor,
                                                  config.transparency);
        }
        
        // Handle HIDDEN style
        if(config.style == FACTOR_ZONE_HIDDEN) {
        if(ObjectFind(0, zoneName) >= 0) ObjectDelete(0, zoneName);
    return true;
        }
        
        // Handle BOX styles (Filled/Empty)
        SZoneCreationRequest request;
    request.name = zoneName;
    request.topPrice = upperPrice;
    request.bottomPrice = lowerPrice;
    request.zoneColor = (levelColor == clrNONE) ? config.defaultColor : levelColor;
    request.transparency = config.transparency;
    request.filled = (config.style == FACTOR_ZONE_BOX_FILLED);
    request.startTime = 0;
    request.endTime = 0;
    SZoneCreationResult result = CreateZone(request);
        
        // CRITICAL DIAGNOSTIC
        if((currentTF == 15 && m15Count <= 5) || (currentTF == 30 && m30Count <= 5)) {
            Print("🔍 TF", currentTF, "-RESULT: success=", (result.success ? "YES" : "NO"), 
                  ", error=", result.errorMessage);
        }
    return result.success;
    }
    
    // Original method: use distance between levels
    return CreateUnifiedZone(zoneName, effectivePrevPrice, currentPrice, config, levelColor);
}

//+------------------------------------------------------------------+
//| BATCH CREATE ZONES - FOR PERFORMANCE                             |

//|                                                                  |

//+------------------------------------------------------------------+
struct SZonePair {
        string name;
    double prevPrice;
    double currentPrice;
    color levelColor;
};

    int CreateZonesBatch(const SZonePair &zones[], const SUnifiedZoneConfig &config)
{
        int count = ArraySize(zones);
    int successCount = 0;
    for(int i = 0; i < count; i++) {
        if(CreateUnifiedZone(zones[i].name, zones[i].prevPrice, zones[i].currentPrice,
                            config, zones[i].levelColor)) {
            successCount++;
        }
    }
    return successCount;
}
    #endif
    // UNIFIED_ZONE_SYSTEM_MQH
