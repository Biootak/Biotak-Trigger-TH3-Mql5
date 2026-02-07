//+------------------------------------------------------------------+
//|                                                   ZoneFactory.mqh |
//|                                  Copyright 2025, Biotak Project  |
//|                          Factory Pattern for Zone Creation       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneValidator.mqh"

//+------------------------------------------------------------------+
//| Zone Factory - Centralized Zone Creation                         |
//| فکتوری Zone - ساخت متمرکز Zone‌ها                                |
//|                                                                  |
//| BENEFITS:                                                        |
//| - Single point of zone creation (DRY)                           |
//| - Consistent validation                                          |
//| - Easy to extend with new zone types                            |
//| - Testable in isolation                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Zone Creation Request                                            |
//| درخواست ساخت Zone                                                |
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
//| نتیجه ساخت Zone                                                  |
//+------------------------------------------------------------------+
struct SZoneCreationResult {
    bool success;             // Was creation successful?
    string zoneName;          // Created zone name
    string errorMessage;      // Error message if failed
    int errorCode;            // Error code
};

//+------------------------------------------------------------------+
//| Create Zone with Full Validation - GOLD VERSION v3 FINAL         |
//| ساخت Zone با اعتبارسنجی کامل - نسخه طلایی v3 نهایی               |
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
                                          DoubleToString(request.topPrice, Digits),
                                          DoubleToString(request.bottomPrice, Digits));
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        return result;
    }
    
    if(request.topPrice <= request.bottomPrice) {
        result.errorMessage = StringFormat("Top price (%s) must be greater than bottom price (%s)",
                                          DoubleToString(request.topPrice, Digits),
                                          DoubleToString(request.bottomPrice, Digits));
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
    // PHASE 2: TIME CALCULATION
    // PERFORMANCE: Mutex removed — MQL5 indicators are single-threaded
    // بهینه‌سازی: Mutex حذف شد — اندیکاتورها تک‌نخی هستند
    // ═══════════════════════════════════════════════════════════════
    
    int safeBars = Bars(_Symbol, _Period);
    datetime currentTime = (safeBars > 0) ? iTime(_Symbol, _Period, 0) : 0;
    
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
    
    // Auto-calculate times if not provided
    if(startTime == 0) {
        if(safeBars <= 0) {
            result.errorMessage = StringFormat("Invalid Bars count: %d", safeBars);
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
        
        // FIX BUG #12: Correct validation logic
        // startIndex will be safeBars-1, which is always < safeBars
        // So we need to check if safeBars is at least 1
        if(safeBars < 1) {
            result.errorMessage = "Not enough bars for zone creation";
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
        
        int startIndex = safeBars - 1;
        startTime = iTime(_Symbol, _Period, startIndex);
        
        // Validate retrieved time
        if(startTime <= 0) {
            result.errorMessage = StringFormat("Invalid Time[%d]", startIndex);
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
    }
    else {
        // Validate user-provided startTime
        if(startTime <= 0) {
            result.errorMessage = StringFormat("Invalid user-provided startTime: %s", TimeToString(startTime));
            result.errorCode = ERR_ZONE_INVALID_CONFIG;
            return result;
        }
    }
    
    if(endTime == 0) {
        if(currentTime <= 0) {
            result.errorMessage = "Invalid Time[0]";
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
        
        // CRITICAL FIX: Validate PeriodSeconds before use
        int periodSeconds = PeriodSeconds(Period());
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
        if(periodSeconds > 2592000) {  // 30 days in seconds
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CreateZone: Suspiciously large PeriodSeconds=", periodSeconds);
            #endif
        }
        
        // Now safe to use periodSeconds
        datetime calculatedEndTime = startTime + (periodSeconds * 10000);
        
        // Validate endTime is reasonable
        if(calculatedEndTime <= startTime) {
            result.errorMessage = StringFormat("Invalid PeriodSeconds: %d", periodSeconds);
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
        
        endTime = currentTime + periodSeconds * ZONE_EXTENSION_PERIODS;
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
    // PHASE 4: ZONE CREATION/UPDATE (Atomic Operation)
    // FIX BUG #10: Set properties ONCE, not twice
    // FIX BUG #11: Check all ObjectSet return values
    // ═══════════════════════════════════════════════════════════════
    
    bool objectExists = (ObjectFind(0, request.name) >= 0);
    bool needsPropertyUpdate = true;
    
    if(!objectExists) {
        // GOLD FIX #4: Enhanced atomic zone creation with rollback
        bool createSuccess = ObjectCreate(0, request.name, OBJ_RECTANGLE, 0, 
                                         startTime, request.topPrice, 
                                         endTime, request.bottomPrice);
        
        if(!createSuccess) {
            int error = GetLastError();
            result.errorMessage = StringFormat("Failed to create zone '%s': MT4 Error %d", 
                                              request.name, error);
            result.errorCode = error;
            
            // CRITICAL: Atomic cleanup - ensure no partial objects remain
            int cleanupAttempts = 0;
            while(ObjectFind(0, request.name) >= 0 && cleanupAttempts < 3) {
                ObjectDelete(0, request.name);
                cleanupAttempts++;
                if(cleanupAttempts > 1) {
                    // Sleep removed for MQL5 indicator compatibility
                }
            }
            
            if(ObjectFind(0, request.name) >= 0) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ Failed to cleanup partial zone object after ", cleanupAttempts, " attempts");
                #endif
            }
            
            return result;
        }
        needsPropertyUpdate = true;
    }
    else {
        // Update existing zone - geometry only
        // FIX BUG #11: Check return values
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
        needsPropertyUpdate = true;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 5: APPLY VISUAL PROPERTIES (Once, with error checking)
    // FIX BUG #10: Properties set ONCE here for both create and update
    // FIX BUG #11: Check all return values
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
    }
    
    // ═══════════════════════════════════════════════════════════════
    // SUCCESS
    // ═══════════════════════════════════════════════════════════════
    
    result.success = true;
    result.zoneName = request.name;
    
    return result;
}

//+------------------------------------------------------------------+
//| Batch Create Zones                                               |
//| ساخت دسته‌ای Zone‌ها                                             |
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
//| حذف امن Zone                                                      |
//+------------------------------------------------------------------+
bool DeleteZone(const string &zoneName)
{
    if(StringLen(zoneName) == 0) return false;
    
    if(ObjectFind(0, zoneName) >= 0) {
        return ObjectDelete(0, zoneName);
    }
    
    return true; // Already deleted
}

//+------------------------------------------------------------------+
//| Delete Zones by Prefix                                           |
//| حذف Zone‌ها با پیشوند                                             |
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
                deletedCount++;
            }
        }
    }
    
    return deletedCount;
}
