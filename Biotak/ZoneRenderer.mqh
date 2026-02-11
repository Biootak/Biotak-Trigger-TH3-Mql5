#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneConstants.mqh"
#include "GlobalVariables.mqh"  
#include "ZoneFactory.mqh"      

//+------------------------------------------------------------------+
//| Resolve Line Styles                                              |

//+------------------------------------------------------------------+
void ResolveLineStyles(
    const SLevelRawData &levels[],
    const SLevelClassification &classifications[],
    const SStyleConfig &config,
    const string objectPrefix,
    SLineRenderInfo &outLines[])
{
        int count = ArraySize(levels);
    
    // Validate array size before resize
    if(count <= 0 || count > MAX_SAFE_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ResolveLineStyles: Invalid level count=", count);
    #endif
    ArrayResize(outLines, 0);
    return;
    }
    
    ArrayResize(outLines, count);
    string safePrefix = (StringLen(objectPrefix) > 0) ? objectPrefix : "Zone_";
    
    // Use centralized cached Digits from PerformanceOptimizations.mqh
    int cachedDigits = GetCachedDigits();
    for(int i = 0; i < count; i++) {
        outLines[i].isVisible = false;
    if(classifications[i].isActive) {
            // Line visibility controlled by config (which uses g_linesVisible)
            
            outLines[i].isVisible = config.globalShowLines;
    outLines[i].clr = classifications[i].levelColor;
    outLines[i].style = (ENUM_LINE_STYLE)classifications[i].style;
    outLines[i].width = classifications[i].width;
            
            // Generate name using StringFormat (3x faster than concatenation)
            string suffix = (levels[i].logicalStep >= 0) ? "Above_" : "Below_";
    if(levels[i].logicalStep == 0) suffix = "Midpoint_";
    int absStep = MathAbs(levels[i].logicalStep);
    outLines[i].name = StringFormat("%sLevel_%s%d", safePrefix, suffix, absStep);
    outLines[i].price = NormalizeDouble(levels[i].price, cachedDigits);
    outLines[i].tooltip = StringFormat("Level %d", levels[i].logicalStep);
    outLines[i].selectable = false;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    int visibleCount = 0;
    for(int i = 0; i < count; i++) {
        if(outLines[i].isVisible) visibleCount++;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ResolveLineStyles: ", visibleCount, " visible lines");
    #endif
    #endif
}

//+------------------------------------------------------------------+
//| Resolve Zone Styles                                              |

//+------------------------------------------------------------------+
void ResolveZoneStyles(
    const SLevelRawData &levels[],
    const SLevelClassification &classifications[],
    const SZoneGeometry &geometries[],
    const SStyleConfig &config,
    const string objectPrefix,
    SZoneRenderInfo &outZones[])
{
        int count = ArraySize(levels);
    int zoneCount = 0;
    ArrayResize(outZones, count); // Max possible
    
    
    string safePrefix = (StringLen(objectPrefix) > 0) ? objectPrefix : "Zone_";
    if(config.showZones) {
        for(int i = 0; i < count; i++) {
        if(geometries[i].isValid && classifications[i].isActive) {
        string suffix = (levels[i].logicalStep >= 0) ? "Above_" : "Below_";
    int absStep = MathAbs(levels[i].logicalStep);
    outZones[zoneCount].isVisible = true;
    outZones[zoneCount].name = StringFormat("%sZone_%s%d", safePrefix, suffix, absStep);
    outZones[zoneCount].clr = classifications[i].levelColor;
    outZones[zoneCount].transparency = config.zoneTransparency;
    outZones[zoneCount].filled = true;
    outZones[zoneCount].topPrice = geometries[i].topPrice;
    outZones[zoneCount].bottomPrice = geometries[i].bottomPrice;
    zoneCount++;
            }
        }
    }
    
    ArrayResize(outZones, zoneCount);
}

//+------------------------------------------------------------------+
//| Render Zones (Optimized - Using ZoneFactory)                     |

//|                                                                  |
//| REFACTORED: Now uses ZoneFactory for consistency and DRY        |

//| FIXED: Respects Hide state when rendering zones                 |
//+------------------------------------------------------------------+
void RenderZones(const SZoneRenderInfo &zones[])
{
        int count = ArraySize(zones);
    
    // CRITICAL: Enforce zone limit
    if(count > MAX_ZONES_PER_CHART) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ RenderZones: Zone count (", count, ") exceeds limit (", MAX_ZONES_PER_CHART, ")");
    #endif
    count = MAX_ZONES_PER_CHART;
    }
    
    // Check if indicator is hidden
    
    // PERFORMANCE: Use cached IsIndicatorHidden()
    bool isHidden = IsIndicatorHidden();
    
    // Performance tracking
    int zonesCreated = 0;
    int zonesFailed = 0;
    
    // ═══════════════════════════════════════════════════════════════
    // BATCH RENDERING USING ZONE FACTORY
    
    // ═══════════════════════════════════════════════════════════════
    
    for(int i = 0; i < count; i++) {
        if(!zones[i].isVisible) continue;
        
        // ═══════════════════════════════════════════════════════════
        // DELEGATE TO ZONE FACTORY (DRY Principle)
        
        // ═══════════════════════════════════════════════════════════
        
        SZoneCreationRequest request;
    request.name = zones[i].name;
    request.topPrice = zones[i].topPrice;
    request.bottomPrice = zones[i].bottomPrice;
    request.zoneColor = zones[i].clr;
    request.transparency = zones[i].transparency;
    request.filled = zones[i].filled;
    request.startTime = 0;  // Auto-calculate by Factory
        request.endTime = 0;    // Auto-calculate by Factory
        
        SZoneCreationResult result = CreateZone(request);
    if(result.success) {
            zonesCreated++;
            
            // If indicator is hidden, hide the zone immediately
            
            if(isHidden) {
                ObjectSetInteger(0, zones[i].name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }
        else {
            zonesFailed++;
    #ifdef ENABLE_DEBUG_LOGS
            Print("❌ RenderZones: Factory failed for '", zones[i].name, "' - ", 
                  result.errorMessage, " (Code: ", result.errorCode, ")");
    #endif
    }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // UPDATE METRICS
    
    // Note: Factory handles both create and update internally
    
    // ═══════════════════════════════════════════════════════════════
    g_zoneMetrics.totalZonesCreated += zonesCreated;
    g_zoneMetrics.totalZonesFailed += zonesFailed;
    g_zoneMetrics.totalRenderCalls++;
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ RenderZones (Factory): Processed=", zonesCreated, ", Failed=", zonesFailed, 
          ", Hidden=", (isHidden ? "YES" : "NO"));
    #endif
    }

//+------------------------------------------------------------------+
//| Render Lines                                                      |

//| FIXED: Respects Hide state and Lines visibility toggle          |
//+------------------------------------------------------------------+
void RenderLines(const SLineRenderInfo &lines[])
{
        int count = ArraySize(lines);
    int visibleCount = 0;
    
    // Check if indicator is hidden
    
    // PERFORMANCE: Use cached IsIndicatorHidden()
    bool isHidden = IsIndicatorHidden();
    
    // Batch property updates to reduce API calls
    for(int i = 0; i < count; i++) {
        // Create or update line object
        bool objectExists = (ObjectFind(0, lines[i].name) >= 0);
    if(!objectExists) {
            if(!ObjectCreate(0, lines[i].name, OBJ_HLINE, 0, 0, lines[i].price)) {
        int error = GetLastError();
    #ifdef ENABLE_DEBUG_LOGS
                Print("❌ RenderLines: Failed to create line: ", lines[i].name,
                      ", Error: ", error);
    #endif
                
                // CRITICAL: Cleanup partial object before continue
                if(ObjectFind(0, lines[i].name) >= 0) {
                    ObjectDelete(0, lines[i].name);
                }
                continue;
            }
            
            // Set visual properties only on creation (not every update)
            ObjectSetInteger(0, lines[i].name, OBJPROP_COLOR, lines[i].clr);
    ObjectSetInteger(0, lines[i].name, OBJPROP_STYLE, lines[i].style);
    ObjectSetInteger(0, lines[i].name, OBJPROP_WIDTH, lines[i].width);
    ObjectSetInteger(0, lines[i].name, OBJPROP_SELECTABLE, lines[i].selectable);
    ObjectSetInteger(0, lines[i].name, OBJPROP_BACK, false);
    ObjectSetString(0, lines[i].name, OBJPROP_TOOLTIP, lines[i].tooltip);
        }
        else {
            // Existing object: only update price (the only value that changes per tick)
            ObjectSetDouble(0, lines[i].name, OBJPROP_PRICE, lines[i].price);
        }
        
        // Control visibility via TIMEFRAMES property (hide/show without deleting)
        
        // Respect both Hide state AND Lines visibility toggle
        if(isHidden || !lines[i].isVisible) {
            // Hidden by F key OR hidden by L key
            ObjectSetInteger(0, lines[i].name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
        else {
            ObjectSetInteger(0, lines[i].name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    visibleCount++;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ RenderLines: Rendered ", visibleCount, " visible lines out of ", count,
          ", Hidden=", (isHidden ? "YES" : "NO"));
    #endif
    }

//+------------------------------------------------------------------+
//| Batch Render (Zones First, Then Lines)                           |

//|                                                                  |
//| CRITICAL RENDERING ORDER (Requirement 9.5):                      |
//| 1. Zones are rendered FIRST (background layer)                   |
//| 2. Lines are rendered SECOND (foreground layer)                  |
//|                                                                  |
//| This ensures zones appear behind lines for proper visualization  |

//|                                                                  |
//| TASK 12.5: Rendering order verified and documented              |
//+------------------------------------------------------------------+
void RenderBatch(const SLineRenderInfo &lines[], const SZoneRenderInfo &zones[])
{
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: Render zones first (background layer)
    
    // ═══════════════════════════════════════════════════════════════
    RenderZones(zones);
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: Render lines second (foreground layer)
    
    // ═══════════════════════════════════════════════════════════════
    RenderLines(lines);
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ RenderBatch: Rendering order verified - Zones (", ArraySize(zones), 
          ") rendered before Lines (", ArraySize(lines), ")");
    #endif
    }

//+------------------------------------------------------------------+
//| Cleanup Objects by Prefix                                        |

//+------------------------------------------------------------------+
void CleanupZoneObjects(const string &prefix)
{
    ObjectsDeleteAll(0, prefix, -1, -1);
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CleanupZoneObjects: Deleted all objects with prefix: ", prefix);
    #endif
    }
