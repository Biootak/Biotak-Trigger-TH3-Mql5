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
    
    // Auto-calculate times if not provided
    if(startTime == 0) {
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
        
        // FIX BUG #12: Correct validation logic
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
        // زمان شروع Zone: از زمان کافی عقب برای پوشش تاریخچه قابل مشاهده چارت
        // Calculate a reasonable lookback (max 5000 bars or available bars)
        int lookbackBars = MathMin(safeBars - 1, 5000);
        
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
        Print("✅ CreateZone: StartTime=", TimeToString(startTime), " (Lookback=", lookbackBars, " bars)");
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
    
    if(endTime == 0) {
        if(currentTime <= 0) {
            result.errorMessage = "Invalid Time[0]";
            result.errorCode = ERR_ZONE_RENDER_FAILED;
            return result;
        }
        
        // CRITICAL FIX: Validate PeriodSeconds before use
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
        // زون‌ها از گذشته (startTime) تا آینده (currentTime + extension) امتداد دارند
        
        // ADAPTIVE ZONE EXTENSION: Scale based on timeframe
        // Lower timeframes need shorter extensions, higher timeframes need longer ones
        int extensionMultiplier = ZONE_EXTENSION_MULTIPLIER;
        
        // Adjust multiplier based on timeframe (more conservative)
        if(periodSeconds <= 60) {           // M1
            extensionMultiplier = 50;
        }
        else if(periodSeconds <= 300) {     // M5
            extensionMultiplier = 50;
        }
        else if(periodSeconds <= 900) {     // M15
            extensionMultiplier = 60;
        }
        else if(periodSeconds <= 3600) {    // H1
            extensionMultiplier = 100;
        }
        else if(periodSeconds <= 14400) {   // H4
            extensionMultiplier = 100;
        }
        else {                               // D1+
            extensionMultiplier = 100;
        }
        
        // Calculate endTime: currentTime (now) + extension into future
        // محاسبه endTime: زمان فعلی + گسترش به آینده
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
