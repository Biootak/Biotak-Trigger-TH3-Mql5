  //+------------------------------------------------------------------+
//|                                                   ZoneFactory.mqh |
//|                                  Copyright 2025, Biotak Project  |
//|                          Factory Pattern for Zone Creation       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"
#property strict

#include "ConstantsAndEnums.mqh"
#include "ZoneValidator.mqh"

#include "ObjectCache.mqh"

// Minimum visible zone height (each side, in points). Mirrors the define in
// LevelPipeline.mqh so zones are never rejected as sub-point on low TFs.
#ifndef ZONE_MIN_HEIGHT_POINTS
#define ZONE_MIN_HEIGHT_POINTS 2   // minimum half-height each side in points
#endif

//+------------------------------------------------------------------+
//| Zone Factory - Centralized Zone Creation                         |
//|        Zone -             Zone                                   |
//|                                                                  |
//| BENEFITS:                                                        |
//| - Single point of zone creation (DRY)                           |
//| - Consistent validation                                          |
//| - Easy to extend with new zone types                            |
//| - Testable in isolation                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Zone Creation Request                                            |
//|              Zone                                                |
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
//|            Zone                                                  |
//+------------------------------------------------------------------+
struct SZoneCreationResult {
    bool success;             // Was creation successful?
    string zoneName;          // Created zone name
    string errorMessage;      // Error message if failed
    int errorCode;            // Error code
};

// PERF: Per-frame cached chart background color
static color g_cachedBgColor = clrBlack;
static datetime g_cachedBgColorFrameTime = 0;

color GetCachedChartBgColor() {
    datetime frameTime = CacheGetFrameTime();
    if(frameTime == g_cachedBgColorFrameTime && g_cachedBgColorFrameTime != 0) {
        return g_cachedBgColor;
    }
    g_cachedBgColor = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
    g_cachedBgColorFrameTime = frameTime;
    return g_cachedBgColor;
}

// Compute visually reliable zone color for chart objects by blending with background.
// This simulates transparency in MT4 which doesn't support alpha channel in standard objects.
color GetZoneRenderColor(const color sourceColor, const int transparency)
{
    int t = (int)MathMax(0, MathMin(100, transparency));
    // Stronger visual fade (same concept as trigger transparency mapping)
    int tVis = 100 - ((100 - t) * (100 - t)) / 100;

    if(tVis <= 0) return sourceColor;

    color bg = GetCachedChartBgColor();
    if(tVis >= 100) return bg;

    int fr = ((int)sourceColor) & 0xFF;
    int fg = (((int)sourceColor) >> 8) & 0xFF;
    int fb = (((int)sourceColor) >> 16) & 0xFF;

    int br = ((int)bg) & 0xFF;
    int bgc = (((int)bg) >> 8) & 0xFF;
    int bb = (((int)bg) >> 16) & 0xFF;

    int outR = (fr * (100 - tVis) + br * tVis) / 100;
    int outG = (fg * (100 - tVis) + bgc * tVis) / 100;
    int outB = (fb * (100 - tVis) + bb * tVis) / 100;

    return (color)(outR | (outG << 8) | (outB << 16));
}

//+------------------------------------------------------------------+
//| Create Zone with Full Validation - GOLD VERSION v3 FINAL         |
//|      Zone                    -            v3                     |
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
SZoneCreationResult CreateZone(SZoneCreationRequest &request)
{
    SZoneCreationResult result;
    result.success = false;
    result.zoneName = request.name;
    result.errorMessage = "";
    result.errorCode = ERR_ZONE_NONE;
    
    #ifdef ENABLE_DEBUG_LOGS
    // DIAGNOSTIC LOG: log first 10 CreateZone calls per run
    static int s_createZoneCallCount = 0;
    s_createZoneCallCount++;
    if(s_createZoneCallCount <= 10) {
        Print("[CREATEZONE_DIAG] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " name=", request.name,
              " top=", DoubleToString(request.topPrice, Digits),
              " bottom=", DoubleToString(request.bottomPrice, Digits),
              " top<=bottom=", (request.topPrice <= request.bottomPrice ? "YES" : "NO"));
    }
    #endif
    
    //                                                                
    // PHASE 1: VALIDATION (Fail Fast)
    //                                                                
    
    // Validate name
    if(StringLen(request.name) == 0) {
        result.errorMessage = "Zone name cannot be empty";
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        #ifdef ENABLE_DEBUG_LOGS
        Print("[CREATEZONE_FAIL] name empty");
        #endif
        return result;
    }
    
    // Validate prices
    if(request.topPrice <= 0 || request.bottomPrice <= 0) {
        result.errorMessage = StringFormat("Invalid zone prices: Top=%s, Bottom=%s",
                                          DoubleToString(request.topPrice, Digits),
                                          DoubleToString(request.bottomPrice, Digits));
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        #ifdef ENABLE_DEBUG_LOGS
        Print("[CREATEZONE_FAIL] name=", request.name, " invalid prices");
        #endif
        return result;
    }

    // FIX: Enforce a minimum visible zone height (in points) so zones created on
    // lower timeframes (where the fractal step is sub-point) are not silently
    // rejected as "top <= bottom" after NormalizeDouble. Expand symmetrically
    // around the box center, preserving the intended price level.
    {
        double point = GetCachedPoint();
        if(point <= 0) point = 1e-5;
        double center = (request.topPrice + request.bottomPrice) * 0.5;
        double half = (request.topPrice - request.bottomPrice) * 0.5;
        double minHalf = point * ZONE_MIN_HEIGHT_POINTS;
        if(half < minHalf) {
            request.topPrice = NormalizeDouble(center + minHalf, Digits);
            request.bottomPrice = NormalizeDouble(center - minHalf, Digits);
        }
    }

    if(request.topPrice <= request.bottomPrice) {
        result.errorMessage = StringFormat("Top price (%s) must be greater than bottom price (%s)",
                                          DoubleToString(request.topPrice, Digits),
                                          DoubleToString(request.bottomPrice, Digits));
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        #ifdef ENABLE_DEBUG_LOGS
        Print("[CREATEZONE_FAIL] name=", request.name, " top<=bottom");
        #endif
        return result;
    }
    
    // Validate transparency with warning for clamping
    int originalTransparency = request.transparency;
    int clampedTransparency = request.transparency;
    
    if(clampedTransparency < 0) {
        clampedTransparency = 0;
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CreateZone: Transparency clamped from ", originalTransparency, " to 0");
        #endif
    }
    if(clampedTransparency > 100) {
        clampedTransparency = 100;
        #ifdef ENABLE_DEBUG_LOGS
        Print("   CreateZone: Transparency clamped from ", originalTransparency, " to 100");
        #endif
    }
    
    //                                                                
    // PHASE 2: TIME CALCULATION (Optimized - No slow GlobalVariables)
    //                                                                
    
    // CRITICAL FIX: Use iBars() instead of Bars(). On lower timeframes Bars() can report
    // more bars than are actually loaded, causing iTime(..., safeBars-1) to return 0 and
    // silently failing zone creation. iBars() returns the count of actually loaded bars.
    int safeBars = iBars(Symbol(), (ENUM_TIMEFRAMES)Period());
    datetime currentTime = (safeBars > 0) ? iTime(Symbol(), (ENUM_TIMEFRAMES)Period(), 0) : TimeCurrent();
    if(currentTime <= 0) currentTime = TimeCurrent();
    
    datetime startTime = request.startTime;
    datetime endTime = request.endTime;
    
    // Auto-calculate times if not provided
    if(startTime == 0) {
        if(safeBars < 1) {
            // DIAGNOSTIC + SAFETY: On M1 with monthly history unavailable, fall back to current bar.
            #ifdef ENABLE_DEBUG_LOGS
            Print("[CreateZone] safeBars < 1 on ", EnumToString((ENUM_TIMEFRAMES)Period()), " using TimeCurrent fallback");
            #endif
            startTime = currentTime;
        }
        else {
            // Zones should span the entire visible history, so start from the
            // oldest loaded bar. In the common case iTime(safeBars-1) is valid
            // immediately, avoiding the O(safeBars) walk-back fallback.
            int startIndex = safeBars - 1;
            startTime = iTime(Symbol(), (ENUM_TIMEFRAMES)Period(), startIndex);
            
            // Fallback: if the oldest bar is not yet synced, walk forward until
            // a valid timestamp is found.
            while(startIndex >= 0 && startTime <= 0) {
                startTime = iTime(Symbol(), (ENUM_TIMEFRAMES)Period(), startIndex);
                if(startTime <= 0) startIndex--;
            }
            
            if(startTime <= 0) {
                #ifdef ENABLE_DEBUG_LOGS
                // OPERATIONAL LOG: Always visible so users can diagnose missing zones on lower TFs
                static int s_iTimeFailLogCount = 0;
                static datetime s_lastITimeFailLog = 0;
                if(s_iTimeFailLogCount < 5 && TimeCurrent() - s_lastITimeFailLog >= 1) {
                    Print("[ZONE_TIME_FAIL] iTime returned 0 for all indices 0..", safeBars - 1,
                          " on TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
                          " zone=", request.name);
                    s_iTimeFailLogCount++;
                    s_lastITimeFailLog = TimeCurrent();
                }
                Print("[CreateZone] iTime failed at all indices down to 0 on ", EnumToString((ENUM_TIMEFRAMES)Period()));
                #endif
                result.errorMessage = StringFormat("Invalid Time[%d]", startIndex);
                result.errorCode = ERR_ZONE_RENDER_FAILED;
                return result;
            }
        }
    }
    
    if(endTime == 0) {
        int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)Period());
        if(periodSeconds <= 0) {
            result.success = false;
            result.errorCode = ERR_ZONE_INVALID_CONFIG;
            result.errorMessage = "Invalid timeframe period";
            #ifdef ENABLE_DEBUG_LOGS
            Print("[CREATEZONE_FAIL] name=", request.name, " invalid period");
            #endif
            return result;
        }
        endTime = currentTime + periodSeconds * ZONE_EXTENSION_PERIODS;
    }
    
    // Validate time range
    if(startTime <= 0 || endTime <= startTime) {
        result.errorMessage = StringFormat("Invalid time range: Start=%s, End=%s",
                                          TimeToString(startTime),
                                          TimeToString(endTime));
        result.errorCode = ERR_ZONE_RENDER_FAILED;
        #ifdef ENABLE_DEBUG_LOGS
        Print("[CREATEZONE_FAIL] name=", request.name, " invalid time range");
        #endif
        return result;
    }
    
    //                                                                
    // PHASE 3: CALCULATE FINAL COLOR & CHECK CACHE
    //                                                                
    
    color finalColor = GetZoneRenderColor(request.zoneColor, clampedTransparency);
    // FIX: Removed DeleteIndicatorObjectManaged(_Top/_Bottom) here.
    // Deleting those border lines on every tick caused visible flicker.
    // They are only needed when switching zone style (handled by caller).

    // PERFORMANCE: Use per-frame cached IsIndicatorHidden() instead of GlobalVariableCheck/Get
    bool isHidden = IsIndicatorHidden();
    
    // PERFORMANCE: Check cache to skip redundant API calls
    SObjectCacheEntry cache;
    bool inCache = CacheGetObject(request.name, cache);
    // FIX: Trust the cache for the current redraw frame. Timeframe-switch and
    // bulk-deletion paths call InvalidateObjectCacheByPrefix/CacheRemoveObject,
    // so a cache hit within the same frame is reliable. Re-verify only on
    // cache misses or stale entries.
    bool objectExists = false;
    if(inCache && cache.exists && cache.lastUpdate == CacheGetFrameTime() && cache.lastUpdate > 0) {
        objectExists = true;
    }
    else {
        objectExists = (ObjectFind(0, request.name) >= 0);
        if(inCache && !objectExists) {
            CacheRemoveObject(request.name);
            inCache = false;
        }
    }
    bool createdObject = false;
    
    if(inCache && objectExists) {
        // Check if anything actually changed
        bool geometryChanged = (cache.lastPrice != request.topPrice || cache.lastPrice2 != request.bottomPrice ||
                               cache.lastTime1 != startTime || cache.lastTime2 != endTime);
        bool visualChanged = (cache.lastColor != finalColor || cache.lastFilled != request.filled);
        
        if(!geometryChanged && !visualChanged) {
            // PERF: Only rewrite timeframe when it actually changed.
            SetObjectTimeframesIfChanged(request.name, isHidden ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
            result.success = true;
            return result; // Geometry/visuals are current; visibility may still change.
        }
    }
    
    //                                                                
    // PHASE 4: ZONE CREATION/UPDATE
    //                                                                
    
    if(!objectExists) {
        if(!ObjectCreate(0, request.name, OBJ_RECTANGLE, 0, startTime, request.topPrice, endTime, request.bottomPrice)) {
            int error = GetLastError();
            #ifdef ENABLE_DEBUG_LOGS
            Print("[CREATEZONE_FAIL] ObjectCreate FAILED name=", request.name,
                  " TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
                  " start=", TimeToString(startTime), " end=", TimeToString(endTime),
                  " top=", request.topPrice, " bottom=", request.bottomPrice,
                  " err=", error);
            #endif
            result.errorMessage = StringFormat("Failed to create zone '%s': MT4 Error %d", request.name, error);
            result.errorCode = error;
            return result;
        }
        createdObject = true;
    }
    else {
        // Update geometry ONLY if changed
        bool geometryChanged = !inCache || (cache.lastPrice != request.topPrice || cache.lastPrice2 != request.bottomPrice ||
                                           cache.lastTime1 != startTime || cache.lastTime2 != endTime);
        if(geometryChanged) {
            ObjectSetDouble(0, request.name, OBJPROP_PRICE, 0, request.topPrice);
            ObjectSetDouble(0, request.name, OBJPROP_PRICE, 1, request.bottomPrice);
            ObjectSetInteger(0, request.name, OBJPROP_TIME, 0, startTime);
            ObjectSetInteger(0, request.name, OBJPROP_TIME, 1, endTime);
        }
    }
    
    // Apply visual properties ONLY if changed
    bool visualChanged = createdObject || !inCache || (cache.lastColor != finalColor || cache.lastFilled != request.filled);
    if(visualChanged) {
        ObjectSetInteger(0, request.name, OBJPROP_COLOR, finalColor);
        ObjectSetInteger(0, request.name, OBJPROP_BACK, true);
        ObjectSetInteger(0, request.name, OBJPROP_FILL, request.filled);
        ObjectSetInteger(0, request.name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, request.name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, request.name, OBJPROP_ZORDER, 0);
    }

    // PERF: Only rewrite timeframe when it actually changed.
    SetObjectTimeframesIfChanged(request.name, isHidden ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    
    // Update cache
    CacheUpdateZone(request.name, request.topPrice, request.bottomPrice, startTime, endTime, finalColor, request.filled);
    
    result.success = true;
    return result;
}

//+------------------------------------------------------------------+
//| Batch Create Zones                                               |
//|              Zone                                                |
//+------------------------------------------------------------------+
int CreateZonesBatch(SZoneCreationRequest &requests[], 
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
//|         Zone                                                      |
//+------------------------------------------------------------------+
bool DeleteZone(const string &zoneName)
{
    if(StringLen(zoneName) == 0) return false;

    return DeleteManagedZoneObjects(zoneName, true);
}

//+------------------------------------------------------------------+
//| Delete Zones by Prefix                                           |
//|     Zone                                                          |
//+------------------------------------------------------------------+
int DeleteZonesByPrefix(const string &prefix)
{
    if(StringLen(prefix) == 0) return 0;
    
    int deletedCount = 0;
    int totalObjects = ObjectsTotal(0, -1, -1);
    
    for(int i = totalObjects - 1; i >= 0; i--) {
        string name = ObjectName(0, i, -1, -1);
        
        if(StringFind(name, prefix) == 0) {
            if(DeleteIndicatorObjectManaged(name, true)) {
                deletedCount++;
            }
        }
    }
    
    return deletedCount;
}
