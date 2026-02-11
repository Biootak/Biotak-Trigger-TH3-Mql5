#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneValidator.mqh"
#include "ObjectCache.mqh"
#include "PropertyChangeDetector.mqh"
#include "VisibilityManager.mqh"
#include "CalculationCache.mqh"

//+------------------------------------------------------------------+
//| Zone Factory - Centralized Zone Creation                         |

//|                                                                  |
//| BENEFITS:                                                        |
//| - Single point of zone creation (DRY)                           |
//| - Consistent validation                                          |
//| - Easy to extend with new zone types                            |
//| - Testable in isolation                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Adaptive Extension Multiplier with Caching             |

//| Task 7 - Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7 |
//|                                                                  |
//| ADAPTIVE EXTENSION LOGIC:                                        |
//| - M1 (60s): 50 bars × 60s = 50min extension                     |
//| - M5 (300s): 50 bars × 300s = 250min (~4h)                      |
//| - M15 (900s): ~55 bars × 900s = ~13.75h                         |
//| - M30 (1800s): 60 bars × 1800s = 30h                            |
//| - H1 (3600s): 100 bars × 3600s = 100h (~4 days)                 |
//| - H4 (14400s): 100 bars × 14400s = 400h (~16 days)              |
//| - D1 (86400s): 100 bars × 86400s = 100 days                     |
//|                                                                  |
//| CACHING BENEFITS:                                                |
//| - Requirement 19.1: Check cache first before calculation        |
//| - Requirement 19.2: Use cached multiplier when TF unchanged     |
//| - Requirement 19.5: Skip interpolation arithmetic on cache hit  |
//| - Requirement 19.6: Reuse across multiple zone creations        |
//+------------------------------------------------------------------+
int CalculateAdaptiveExtensionMultiplier(int periodSeconds)
{
        int currentPeriod = GetCachedPeriod();
    double cachedMultiplier = GetCachedExtensionMultiplier(currentPeriod, periodSeconds);
    if(cachedMultiplier > 0) {
        #ifdef ENABLE_DEBUG_LOGS
        static int s_extensionMultiplierCacheHits = 0;
    s_extensionMultiplierCacheHits++;
    if(s_extensionMultiplierCacheHits % 100 == 0) {
            Print("✅ Extension Multiplier Cache Hit #", s_extensionMultiplierCacheHits);
        }
    #endif
    return (int)cachedMultiplier;
    }
    
    // Cache miss - calculate multiplier
    int extensionMultiplier = ZONE_EXTENSION_MULTIPLIER; // Default from constants
    
    // Adaptive multiplier: Scale smoothly based on timeframe duration
    // Lower timeframes (seconds) → Shorter extension
    // Higher timeframes (hours/days) → Longer extension
    
    if(periodSeconds <= 60) {                          // M1 (60s)
        extensionMultiplier = 50;
    }
    else if(periodSeconds <= 300) {                    // M1-M5 (60-300s)
        extensionMultiplier = 50;
    }
    else if(periodSeconds <= 1800) {                   // M5-M30 (300-1800s)
        // Smooth interpolation: 50 at M5 → 60 at M30        extensionMultiplier = (int)(50 + (periodSeconds - 300) * 10.0 / 1500.0);
    }
    else if(periodSeconds <= 3600) {                   // M30-H1 (1800-3600s)
        // Smooth transition: 60 at M30 → 100 at H1        extensionMultiplier = (int)(60 + (periodSeconds - 1800) * 40.0 / 1800.0);
    }
    else if(periodSeconds <= 86400) {                  // H1-D1 (3600-86400s)
        // All hourly timeframes get 100
        extensionMultiplier = 100;
    }
    else {                                             // D1+ (W1, MN1)
        extensionMultiplier = 100;
    }
    StoreExtensionMultiplier(currentPeriod, periodSeconds, (double)extensionMultiplier);
    #ifdef ENABLE_DEBUG_LOGS
    Print("💾 Extension Multiplier Calculated and Cached: period=", currentPeriod, 
          ", periodSeconds=", periodSeconds, ", multiplier=", extensionMultiplier);
    #endif
    return extensionMultiplier;
}

//+------------------------------------------------------------------+
//| Zone Creation Request                                            |

//+------------------------------------------------------------------+
struct SZoneCreationRequest {
        string name;              // Zone name
    double topPrice;          // Top boundary
    double bottomPrice;       // Bottom boundary
    color zoneColor;          // Zone color
    int transparency;         // Transparency (0-100)
    bool filled;              // Fill zone?
    datetime startTime;       // Start time (optional, 0 = auto)
    datetime endTime;         // End time (optional, 0 = auto)
};

//+------------------------------------------------------------------+
//| Zone Creation Result                                             |

//+------------------------------------------------------------------+
struct SZoneCreationResult {
        bool success;             // Was creation successful?
    string zoneName;          // Created zone name
    string errorMessage;      // Error message if failed
    int errorCode;            // Error code
};

//+------------------------------------------------------------------+
//| Create Zone with Full Validation - |

//|                                                                  |
//| IMPROVEMENTS v3 (FINAL):                                         |
//| - Fixed: Removed duplicate property setting (performance)       |
//| - Fixed: Added error checking for all ObjectSet calls           |
//| - Fixed: Corrected startIndex validation logic                  |
//| - Fixed: Added PeriodSeconds validation                         |
//| - Race condition prevention (cached Bars/Time)                  |
//| - Better transparency validation with warning                   |
//| - Atomic object creation (cleanup on failure)                   |
//| - Comprehensive error context                                   |
//+------------------------------------------------------------------+
SZoneCreationResult CreateZone(const SZoneCreationRequest &request)
{
    SZoneCreationResult result;
    result.success = false;
    result.zoneName = request.name;
    result.errorMessage = "";
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔧 CreateZone START: '", request.name, "' Top=", request.topPrice, " Bottom=", request.bottomPrice);
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: VALIDATION (Fail Fast)
    // ═══════════════════════════════════════════════════════════════
    
    // Validate name
    if(StringLen(request.name) == 0) {
        result.errorMessage = "Zone name cannot be empty";
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    return result;
    }
    
    // Validate prices
    if(request.topPrice <= 0 || request.bottomPrice <= 0) {
        result.errorMessage = StringFormat("Invalid zone prices: Top=%s, Bottom=%s",
                                          DoubleToString(request.topPrice, GetCachedDigits()),
                                          DoubleToString(request.bottomPrice, GetCachedDigits()));
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    return result;
    }
    if(request.topPrice <= request.bottomPrice) {
        result.errorMessage = StringFormat("Top price (%s) must be greater than bottom price (%s)",
                                          DoubleToString(request.topPrice, GetCachedDigits()),
                                          DoubleToString(request.bottomPrice, GetCachedDigits()));
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    return result;
    }
    
    // Validate transparency with warning for clamping
    int originalTransparency = request.transparency;
    int clampedTransparency = request.transparency;
    if(clampedTransparency < 0) {
        clampedTransparency = 0;
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CreateZone: Transparency clamped from ", originalTransparency, " to 0");
    #endif
    }
    if(clampedTransparency > 100) {
        clampedTransparency = 100;
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CreateZone: Transparency clamped from ", originalTransparency, " to 100");
    #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: TIME CALCULATION - ATOMIC READ PATTERN
    // ✅ FIXED: Read all time-dependent values atomically
    // ═══════════════════════════════════════════════════════════════
    
    // CRITICAL: Read all values in one atomic block to prevent race conditions
    int safeBars = Bars(_Symbol, _Period);
    datetime currentTime = 0;
    if(safeBars > 0) {
        // Read time IMMEDIATELY after bars check (minimize race window)
        currentTime = iTime(_Symbol, _Period, 0);
        
        // Validate: bars count should still match
        int barsRecheck = Bars(_Symbol, _Period);
    if(barsRecheck != safeBars) {
            // Bars changed during read - retry once
            safeBars = barsRecheck;
    currentTime = (safeBars > 0) ? iTime(_Symbol, _Period, 0) : 0;
        }
    }
    
    // Fallback to server time if chart time unavailable
    if(currentTime <= 0) {
        currentTime = TimeCurrent();
    }
    
    // Final validation
    if(currentTime <= 0) {
        result.errorMessage = StringFormat("Invalid time (Bars=%d)", safeBars);
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
    }
    datetime startTime = request.startTime;
    datetime endTime = request.endTime;
    
    // ═══════════════════════════════════════════════════════════════
    // GEOMETRY CACHE CHECK (Task 5 - Requirements 4.1, 4.2, 4.4, 4.5)
    // ═══════════════════════════════════════════════════════════════
    // Check if we need to calculate times (both are 0 or auto-calculate)
    bool needsTimeCalculation = (startTime == 0 || endTime == 0);
    if(needsTimeCalculation) {
        // Calculate extension multiplier parameters for cache key
        int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    int extensionMultiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);
        
        // Try to get cached geometry
        datetime cachedStartTime = 0;
    datetime cachedEndTime = 0;
        
        // Note: We don't have historicalPeriods in request, using 0 as placeholder
        // The cache will still work for same prices and extension multiplier
        bool cacheHit = GetCachedZoneGeometry(
            request.topPrice,
            request.bottomPrice,
            extensionMultiplier,
            0,  // historicalPeriods placeholder
            cachedStartTime,
            cachedEndTime
        );
    if(cacheHit && cachedStartTime > 0 && cachedEndTime > 0) {            startTime = cachedStartTime;
    endTime = cachedEndTime;
    needsTimeCalculation = false;
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CreateZone: Geometry cache HIT for '", request.name, 
                  "' - skipping time calculations");
    #endif
    }
        else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("🔍 CreateZone: Geometry cache MISS for '", request.name, 
                  "' - will calculate times");
    #endif
    }
    }
    
    // Auto-calculate times if not provided and not cached
    if(startTime == 0 && needsTimeCalculation) {
        // ✅ EDGE CASE FIX: Handle zero bars scenario
        if(safeBars <= 0) {
            // LOW TIMEFRAME OPTIMIZATION: Wait for first bar data
            #ifdef ENABLE_DEBUG_LOGS
            Print("⏱️ CreateZone: Waiting for bar data on TF=", GetCachedPeriod());
    #endif
    result.errorMessage = "No bars available - waiting for first tick";
    result.errorCode = ERR_ZONE_NO_DATA;
    return result;
        }
        
        // Correct validation logic
        // startIndex will be safeBars-1, which is always < safeBars
        // So we need to check if safeBars is at least 1
        if(safeBars < 1) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CreateZone: Not enough bars (", safeBars, ") on TF=", GetCachedPeriod());
    #endif
    result.errorMessage = "Not enough bars for zone creation";
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
        }
        
        // ZONE START TIME: Use time from far enough back to cover visible chart history
        
        // For ALL timeframes below H1, use extended lookback
        
        int lookbackBars;
    int periodMinutes = PeriodMinutes();
        
        // Extended lookback for ALL sub-hourly timeframes
        // This ensures zones are visible on M1, M2, M3, M4, M5, M6, M10, M12, M15, M20, M30
        if(periodMinutes < 60) {
            // Sub-hourly timeframes: Use maximum lookback for visibility
            
            lookbackBars = MathMin(safeBars - 1, 20000);  // Increased from 10000 to 20000
        }
        else {
            // Hourly and above: Standard lookback
            lookbackBars = MathMin(safeBars - 1, 5000);
        }
        
        // Ensure we have at least 1 bar
        if(lookbackBars < 0) lookbackBars = 0;
    startTime = iTime(_Symbol, _Period, lookbackBars);
        
        // Validate retrieved time
        if(startTime <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CreateZone: Invalid iTime(", lookbackBars, "), trying Time[0]...");
    #endif
            // Fallback: try current time
            startTime = iTime(_Symbol, _Period, 0);
    if(startTime <= 0) {
                result.errorMessage = StringFormat("Cannot retrieve chart time (Bars=%d)", safeBars);
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
            }
        }
    #ifdef ENABLE_DEBUG_LOGS
        Print("✅ CreateZone: StartTime=", TimeToString(startTime), " (Lookback=", lookbackBars, 
              " bars, TF=", periodMinutes, "min, Bars=", safeBars, ")");
    #endif
    }
    else {
        // Validate user-provided startTime
        if(startTime <= 0) {
            result.errorMessage = StringFormat("Invalid user-provided startTime: %s", TimeToString(startTime));
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    return result;
        }
    }
    if(endTime == 0 && needsTimeCalculation) {
        if(currentTime <= 0) {
            result.errorMessage = "Invalid Time[0]";
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
        }
        
        // Validate PeriodSeconds before use
        int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    if(periodSeconds <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CreateZone: Invalid PeriodSeconds=", periodSeconds, " for Period=", Period());
    #endif
    result.success = false;
    result.errorCode = ZONE_ERROR_INVALID_PRICES;
    result.errorMessage = "Invalid timeframe period";
    return result;
        }
        
        // Additional validation: Check for reasonable period
        // Additional validation: Check for reasonable period
        if(periodSeconds > 2592000) {  // 30 days in seconds
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CreateZone: Suspiciously large PeriodSeconds=", periodSeconds);
    #endif
    }
        
        // ZONE EXTENSION: Zones extend from past (startTime) to future (currentTime + extension)
        
        
        // ═══════════════════════════════════════════════════════════════
        // 🔧 ADAPTIVE ZONE EXTENSION FOR ALL TIMEFRAMES
        // ═══════════════════════════════════════════════════════════════
        // OLD BUG: Hard-coded if-else only worked on M1/M5/M15/H1/H4/D1
        // PROBLEM: Zones disappeared on M2,M3,M4,M6,M10,M12,M20,M30,H2,H3,H6,H8,W1,MN1
        // SOLUTION: Use adaptive calculation based on periodSeconds        // ═══════════════════════════════════════════════════════════════
        
        int extensionMultiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);
        
        // ═══════════════════════════════════════════════════════════════
        // 📊 EXTENSION CALCULATION BREAKDOWN:
        // ═══════════════════════════════════════════════════════════════
        // M1:  50 bars × 60s = 50min extension
        // M5:  50 bars × 300s = 250min extension (~4h)
        // M15: ~55 bars × 900s = ~13.75h extension
        // M30: 60 bars × 1800s = 30h extension
        // H1:  100 bars × 3600s = 100h extension (~4 days)
        // H4:  100 bars × 14400s = 400h extension (~16 days)
        // D1:  100 bars × 86400s = 100 days extension
        // ═══════════════════════════════════════════════════════════════
        
        // Calculate endTime: currentTime (now) + extension into future
        
        endTime = currentTime + (periodSeconds * extensionMultiplier);
    #ifdef ENABLE_DEBUG_LOGS
        Print("🔧 CreateZone: Extension multiplier=", extensionMultiplier, 
              " period=", periodSeconds, "s → extension=", (periodSeconds * extensionMultiplier), "s");
    #endif
        
        // Validate endTime is in the future
        if(endTime <= currentTime) {
            result.errorMessage = StringFormat("Invalid endTime calculation: %s", TimeToString(endTime));
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
        }
    }
    else {
        // Validate user-provided endTime
        if(endTime <= 0) {
            result.errorMessage = StringFormat("Invalid user-provided endTime: %s", TimeToString(endTime));
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    return result;
        }
    }
    
    // Validate time range
    if(startTime <= 0 || endTime <= startTime) {
        result.errorMessage = StringFormat("Invalid time range: Start=%s, End=%s",
                                          TimeToString(startTime),
                                          TimeToString(endTime));
    result.errorCode = ERR_ZONE_RENDER_FAILED;
    return result;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STORE GEOMETRY IN CACHE (Task 5 - Requirements 4.1, 4.2, 4.4)
    // ═══════════════════════════════════════════════════════════════
    // Store calculated geometry for future reuse
    // Only store if we actually calculated it (not from user-provided values)
    if(needsTimeCalculation && request.startTime == 0 && request.endTime == 0) {
        // Calculate extension multiplier for cache key
        int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    int extensionMultiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);
        
        // Store in cache for next time
        StoreZoneGeometry(
            request.topPrice,
            request.bottomPrice,
            extensionMultiplier,
            0,  // historicalPeriods placeholder
            startTime,
            endTime
        );
    #ifdef ENABLE_DEBUG_LOGS
        Print("💾 CreateZone: Stored geometry in cache for '", request.name, "'");
    #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: CALCULATE FINAL COLOR (Before Object Creation)
    // ═══════════════════════════════════════════════════════════════
    
    // FIX: Use MQL5 ColorToARGB() for correct transparency instead of manual bit-packing.
    // Old code had wrong byte order (AABBGGRR vs AARRGGBB) and (color) cast truncated alpha.
    long finalColorARGB = (long)request.zoneColor;  // Default: fully opaque
    if(clampedTransparency > 0) {
        // transparency 0%=fully opaque (alpha=255), 100%=fully transparent (alpha=0)
        uchar alpha = (uchar)((100 - clampedTransparency) * 255 / 100);
        
        // CRITICAL: clamp alpha bounds (defense in depth)
        if(alpha < (uchar)MIN_ALPHA_VALUE) alpha = (uchar)MIN_ALPHA_VALUE;
    if(alpha > (uchar)MAX_ALPHA_VALUE) alpha = (uchar)MAX_ALPHA_VALUE;
    finalColorARGB = (long)ColorToARGB(request.zoneColor, alpha);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 4: ZONE CREATION/UPDATE (Atomic Operation with Cache)
    // Set properties ONCE, not twice
    // Check all ObjectSet return values
    // Use cache and change detection (Requirements 6.1, 6.2, 6.3, 6.4)
    // ═══════════════════════════════════════════════════════════════
    
    // Check cache first before ObjectFind (Requirement 6.2)
    bool objectExists = CacheObjectExists(request.name);
    
    // If not in cache, verify with ObjectFind
    if(!objectExists) {
        objectExists = (ObjectFind(0, request.name) >= 0);
        
        // If object exists but not in cache, add it to cache
        if(objectExists) {
            // Get current properties and add to cache
            double currentTopPrice = ObjectGetDouble(0, request.name, OBJPROP_PRICE, 0);
    color currentColor = (color)ObjectGetInteger(0, request.name, OBJPROP_COLOR);
    CacheAddObject(request.name, currentTopPrice, currentColor, 0, 0);
        }
    }
    bool needsPropertyUpdate = true;
    if(!objectExists) {
        // #4: Enhanced atomic zone creation with rollback
        // Use ChartID() instead of 0 for current chart
        long chartId = ChartID();
    bool createSuccess = ObjectCreate(chartId, request.name, OBJ_RECTANGLE, 0, 
                                         startTime, request.topPrice, 
                                         endTime, request.bottomPrice);
    if(!createSuccess) {
        int error = GetLastError();
    result.errorMessage = StringFormat("Failed to create zone '%s': MT4 Error %d (ChartID=%d)", 
                                              request.name, error, chartId);
    result.errorCode = error;
            
            // CRITICAL: Atomic cleanup - ensure no partial objects remain
            int cleanupAttempts = 0;
    while(ObjectFind(chartId, request.name) >= 0 && cleanupAttempts < 3) {
                ObjectDelete(chartId, request.name);
    cleanupAttempts++;
    if(cleanupAttempts > 1) {
                    // Sleep removed for MQL5 indicator compatibility
                }
            }
    if(ObjectFind(chartId, request.name) >= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ Failed to cleanup partial zone object after ", cleanupAttempts, " attempts");
    #endif
    }
    return result;
        }
        
        // Add to cache after successful creation (Requirement 6.2)
        CacheAddObject(request.name, request.topPrice, request.zoneColor, 0, 0);
    needsPropertyUpdate = true;
    #ifdef ENABLE_DEBUG_LOGS
        Print("✅ CreateZone: Created new zone '", request.name, "' and added to cache");
    #endif
    }
    else {
        // Object exists - use PropertyChangeDetector (Requirement 6.3)
        SObjectCacheEntry cachedEntry;
    bool hasCachedData = CacheGetObject(request.name, cachedEntry);
    if(hasCachedData) {
            // Check if properties have changed
            // For zones, we track: topPrice, color (transparency affects color)
            bool priceChanged = HasPriceChanged(cachedEntry.lastPrice, request.topPrice);
    bool colorChanged = HasColorChanged(cachedEntry.lastColor, request.zoneColor);
    if(!priceChanged && !colorChanged) {
                // No changes needed - skip all updates (Requirement 6.3)
                #ifdef ENABLE_DEBUG_LOGS
                Print("⏭️ CreateZone: Zone '", request.name, "' unchanged, skipping update");
    #endif
    result.success = true;
    result.zoneName = request.name;
    return result;
            }
            
            // Update only changed properties (Requirement 6.4)
            bool updateSuccess = true;
    if(priceChanged) {
                // Batch update all geometry properties together
                updateSuccess = updateSuccess && ObjectSetDouble(0, request.name, OBJPROP_PRICE, 0, request.topPrice);
    updateSuccess = updateSuccess && ObjectSetDouble(0, request.name, OBJPROP_PRICE, 1, request.bottomPrice);
    updateSuccess = updateSuccess && ObjectSetInteger(0, request.name, OBJPROP_TIME, 0, startTime);
    updateSuccess = updateSuccess && ObjectSetInteger(0, request.name, OBJPROP_TIME, 1, endTime);
    #ifdef ENABLE_DEBUG_LOGS
                Print("🔄 CreateZone: Updated zone '", request.name, "' geometry (price changed)");
    #endif
    }
            
            if(!updateSuccess) {
        int error = GetLastError();
    result.errorMessage = StringFormat("Failed to update zone geometry '%s': MT4 Error %d", 
                                                  request.name, error);
    result.errorCode = error;
    return result;
            }
    CacheUpdateObject(request.name, request.topPrice, request.zoneColor, 0, 0);
            
            // needsPropertyUpdate will be set based on color change
            needsPropertyUpdate = colorChanged;
        }
        else {
            // No cached data - update all properties
            bool updateSuccess = true;
    updateSuccess = updateSuccess && ObjectSetDouble(0, request.name, OBJPROP_PRICE, 0, request.topPrice);
    updateSuccess = updateSuccess && ObjectSetDouble(0, request.name, OBJPROP_PRICE, 1, request.bottomPrice);
    updateSuccess = updateSuccess && ObjectSetInteger(0, request.name, OBJPROP_TIME, 0, startTime);
    updateSuccess = updateSuccess && ObjectSetInteger(0, request.name, OBJPROP_TIME, 1, endTime);
    if(!updateSuccess) {
        int error = GetLastError();
    result.errorMessage = StringFormat("Failed to update zone geometry '%s': MT4 Error %d", 
                                                  request.name, error);
    result.errorCode = error;
    return result;
            }
            
            // Add to cache (Requirement 8.5: avoid redundant operations)
            CacheAddObject(request.name, request.topPrice, request.zoneColor, 0, 0);
    needsPropertyUpdate = true;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 5: APPLY VISUAL PROPERTIES (Once, with error checking)
    // Properties set ONCE here for both create and update
    // Check all return values
    // Apply visibility state immediately (Requirement 10.1)
    // BATCH OPTIMIZATION: Requirements 8.1, 8.3 - Set all properties in sequence
    // ═══════════════════════════════════════════════════════════════
    
    if(needsPropertyUpdate) {
        bool propsSuccess = true;
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_COLOR, finalColorARGB);
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_BACK, true);
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_FILL, request.filled);
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_SELECTABLE, false);
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_RAY_RIGHT, true);
    propsSuccess = propsSuccess && ObjectSetInteger(0, request.name, OBJPROP_ZORDER, 0);
    if(!propsSuccess) {
        int error = GetLastError();
    #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CreateZone: Failed to set some properties for '", request.name, "': MT4 Error ", error);
    #endif
            // Don't fail completely - zone is created, just properties might be incomplete
        }
        
        // Update cache with final color (Requirement 8.5: avoid redundant updates)
        CacheUpdateObject(request.name, request.topPrice, request.zoneColor, 0, 0);
    }
    
    // Apply visibility state immediately (Requirement 10.1)
    // Zones are not lines, so pass false for isLine parameter
    ApplyVisibilityState(request.name, false);
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CreateZone: Applied visibility state to '", request.name, "'");
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // SUCCESS
    // ═══════════════════════════════════════════════════════════════
    
    result.success = true;
    result.zoneName = request.name;
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CreateZone SUCCESS: '", request.name, "' [", 
          TimeToString(startTime), " - ", TimeToString(endTime), "] [",
          DoubleToString(request.bottomPrice, Digits), " - ", 
          DoubleToString(request.topPrice, Digits), "]");
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Batch Create Zones                                               |

//+------------------------------------------------------------------+
int CreateZonesBatch(const SZoneCreationRequest &requests[], 
                     SZoneCreationResult &results[])
{
        int count = ArraySize(requests);
    ArrayResize(results, count);
    int successCount = 0;
    for(int i = 0; i < count; i++) {
        results[i] = CreateZone(requests[i]);
    if(results[i].success) successCount++;
    }
    return successCount;
}

//+------------------------------------------------------------------+
//| Delete Zone Safely                                               |

//| Remove from cache when deleted                   |
//+------------------------------------------------------------------+
bool DeleteZone(const string &zoneName)
{
        if(StringLen(zoneName) == 0) return false;
    if(ObjectFind(0, zoneName) >= 0) {
        bool deleted = ObjectDelete(0, zoneName);
        
        // Remove from cache after successful deletion
        if(deleted) {
            CacheRemoveObject(zoneName);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ DeleteZone: Deleted '", zoneName, "' and removed from cache");
    #endif
    }
    return deleted;
    }
    
    // Object doesn't exist, but ensure it's not in cache
    CacheRemoveObject(zoneName);
    return true; // Already deleted
}

//+------------------------------------------------------------------+
//| Delete Zones by Prefix                                           |

//| Remove from cache when deleted                   |
//+------------------------------------------------------------------+
int DeleteZonesByPrefix(const string &prefix)
{
        if(StringLen(prefix) == 0) return 0;
    int deletedCount = 0;
    int totalObjects = ObjectsTotal(0, -1, -1);
    for(int i = totalObjects - 1; i >= 0; i--) {
        string name = ObjectName(0, i, -1, -1);
    if(StringFind(name, prefix) == 0) {
        if(ObjectDelete(0, name)) {
                // Remove from cache after successful deletion
                CacheRemoveObject(name);
    deletedCount++;
            }
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(deletedCount > 0) {
        Print("✅ DeleteZonesByPrefix: Deleted ", deletedCount, " zones with prefix '", prefix, "' and removed from cache");
    }
    #endif
    return deletedCount;
}

//+------------------------------------------------------------------+
//| ENHANCED ZONE CREATION WITH VALIDATION AND RETRY (Task 4)        |

//| Requirements: 1.7, 2.5, 2.6, 2.7, 17.1-17.7                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Zone with Enhanced Validation                             |

//| Requirements: 1.7, 2.5, 2.6, 17.1-17.6                          |
//|                                                                  |
//| Performs comprehensive validation before zone creation           |
//| Returns detailed diagnostic information on failure               |
//+------------------------------------------------------------------+
SZoneCreationResult CreateZoneWithValidation(const SZoneCreationRequest &request)
{
    SZoneCreationResult result;
    result.success = false;
    result.zoneName = request.name;
    result.errorMessage = "";
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔍 CreateZoneWithValidation START: '", request.name, "'");
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: PRE-CREATION VALIDATION
    // ═══════════════════════════════════════════════════════════════
    
    SZoneValidationResultEnhanced validation = ValidateZoneCreationPreconditions(
        GetCachedPeriod(),
        request.name
    );
    if(!validation.valid) {        LogZoneCreationFailure(validation, request.name);
        
        // Convert validation result to creation result
        result.errorCode = validation.errorCode;
    result.errorMessage = validation.errorMessage;
    return result;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: GEOMETRY VALIDATION
    // ═══════════════════════════════════════════════════════════════
    
    // Calculate times if not provided (same logic as CreateZone)
    datetime startTime = request.startTime;
    datetime endTime = request.endTime;
    if(startTime == 0 || endTime == 0) {
        // Need to calculate times - use same logic as CreateZone
        int safeBars = Bars(_Symbol, _Period);
    datetime currentTime = 0;
    if(safeBars > 0) {
            currentTime = iTime(_Symbol, _Period, 0);
            
            // Validate: bars count should still match
            int barsRecheck = Bars(_Symbol, _Period);
    if(barsRecheck != safeBars) {
                safeBars = barsRecheck;
    currentTime = (safeBars > 0) ? iTime(_Symbol, _Period, 0) : 0;
            }
        }
    if(currentTime <= 0) {
            currentTime = TimeCurrent();
        }
    if(startTime == 0) {
        if(safeBars <= 0) {
                result.errorMessage = "No bars available - waiting for first tick";
    result.errorCode = ERR_ZONE_NO_DATA;
                
                // Log failure with diagnostic context
                SZoneValidationResultEnhanced noBarsValidation;
    noBarsValidation.valid = false;
    noBarsValidation.errorCode = ERR_ZONE_NO_DATA;
    noBarsValidation.errorMessage = result.errorMessage;
    noBarsValidation.barsCount = safeBars;
    noBarsValidation.periodSeconds = validation.periodSeconds;
    noBarsValidation.timeframeName = validation.timeframeName;
    LogZoneCreationFailure(noBarsValidation, request.name);
    return result;
            }
    int lookbackBars = MathMin(safeBars - 1, 5000);
    if(lookbackBars < 0) lookbackBars = 0;
    startTime = iTime(_Symbol, _Period, lookbackBars);
    if(startTime <= 0) {
                startTime = iTime(_Symbol, _Period, 0);
    if(startTime <= 0) {
                    result.errorMessage = StringFormat("Cannot retrieve chart time (Bars=%d)", safeBars);
    result.errorCode = ERR_ZONE_RENDER_FAILED;
                    
                    // Log failure
                    SZoneValidationResultEnhanced timeValidation;
    timeValidation.valid = false;
    timeValidation.errorCode = ERR_ZONE_RENDER_FAILED;
    timeValidation.errorMessage = result.errorMessage;
    timeValidation.barsCount = safeBars;
    timeValidation.periodSeconds = validation.periodSeconds;
    timeValidation.timeframeName = validation.timeframeName;
    LogZoneCreationFailure(timeValidation, request.name);
    return result;
                }
            }
        }
    if(endTime == 0) {
        int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    if(periodSeconds <= 0) {
                result.errorMessage = "Invalid timeframe period";
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
                
                // Log failure
                SZoneValidationResultEnhanced periodValidation;
    periodValidation.valid = false;
    periodValidation.errorCode = ERR_ZONE_INVALID_CONFIG;
    periodValidation.errorMessage = result.errorMessage;
    periodValidation.barsCount = safeBars;
    periodValidation.periodSeconds = periodSeconds;
    periodValidation.timeframeName = validation.timeframeName;
    LogZoneCreationFailure(periodValidation, request.name);
    return result;
            }
            
            // Calculate extension multiplier
            int extensionMultiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);
    endTime = currentTime + (periodSeconds * extensionMultiplier);
        }
    }
    
    // Now validate geometry with calculated times
    validation = ValidateZoneGeometryEnhanced(
        request.topPrice,
        request.bottomPrice,
        startTime,
        endTime
    );
    if(!validation.valid) {        LogZoneCreationFailure(validation, request.name);
        
        // Convert validation result to creation result
        result.errorCode = validation.errorCode;
    result.errorMessage = validation.errorMessage;
    return result;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: CREATE ZONE (Existing Logic)
    // ═══════════════════════════════════════════════════════════════
    
    // Update request with calculated times
    SZoneCreationRequest updatedRequest = request;
    updatedRequest.startTime = startTime;
    updatedRequest.endTime = endTime;
    result = CreateZone(updatedRequest);
    if(result.success) {
        LogZoneCreationSuccess(request.name);
    }
    return result;
}

//+------------------------------------------------------------------+
//| Create Zone with Retry Logic                                     |

//| Requirements: 2.7, 17.1-17.7                                     |
//|                                                                  |
//| Retries zone creation on ERR_ZONE_NO_DATA errors                 |
//| Other errors are not retryable and fail immediately              |
//+------------------------------------------------------------------+
SZoneCreationResult CreateZoneWithRetry(
    const SZoneCreationRequest &request,
    int maxRetries = 3)
{
    SZoneCreationResult result;
    result.success = false;
    result.zoneName = request.name;
    result.errorMessage = "";
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 CreateZoneWithRetry START: '", request.name, "' (maxRetries=", maxRetries, ")");
    #endif
    for(int attempt = 0; attempt < maxRetries; attempt++) {
        #ifdef ENABLE_DEBUG_LOGS
        if(attempt > 0) {
            Print("🔄 CreateZoneWithRetry: Attempt ", attempt + 1, " of ", maxRetries, 
                  " for zone '", request.name, "'");
        }
    #endif
        
        // Try to create zone with validation
        result = CreateZoneWithValidation(request);
        
        // Success - return immediately
        if(result.success) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CreateZoneWithRetry: Success on attempt ", attempt + 1, 
                  " for zone '", request.name, "'");
    #endif
    return result;
        }        // If failure is due to missing bars, wait and retry
        if(result.errorCode == ERR_ZONE_NO_DATA) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⏱️ CreateZoneWithRetry: ERR_ZONE_NO_DATA on attempt ", attempt + 1,
                  " - will retry on next tick");
    #endif
            
            // Return error to allow retry on next tick
            // Don't continue loop - let OnCalculate call us again
            return result;
        }
        
        // Other errors are not retryable - fail immediately
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateZoneWithRetry: Non-retryable error (code=", result.errorCode,
              ") on attempt ", attempt + 1, " for zone '", request.name, "'");
    #endif
    break;
    }
    
    // All retries exhausted or non-retryable error
    if(!result.success && result.errorCode == ERR_ZONE_NO_DATA) {
        result.errorMessage = StringFormat("Zone creation failed after %d retries: %s", 
                                          maxRetries, result.errorMessage);
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateZoneWithRetry: Failed after ", maxRetries, " retries for zone '", 
              request.name, "'");
    #endif
    }
    return result;
}
