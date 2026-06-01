#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#ifndef ZONE_FACTORY_MQH
#define ZONE_FACTORY_MQH

#include "ConstantsAndEnums.mqh"
// ZoneValidator.mqh removed - was empty (no validation functions)
#include "ObjectCache.mqh"
#include "PropertyChangeDetector.mqh"
#include "VisibilityManager.mqh"
#include "CalculationCache.mqh"

struct SZoneCreationRequest {
    string name;
    double topPrice;
    double bottomPrice;
    color zoneColor;
    int transparency;
    bool filled;
    datetime startTime;
    datetime endTime;
};

struct SZoneCreationResult {
    bool success;
    string zoneName;
    string errorMessage;
    int errorCode;
};

// PERF: Per-frame cached chart background color — eliminates ~50 ChartGetInteger
//       syscalls per redraw frame (one per zone object)
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

// Compute visually reliable zone color for chart objects.
// MT5 chart objects may ignore ARGB alpha, so we blend with chart background.
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

// Adaptive extension multiplier based on timeframe
int CalculateAdaptiveExtensionMultiplier(int periodSeconds)
{
    int currentPeriod = GetCachedPeriod();
    double cached = GetCachedExtensionMultiplier(currentPeriod, periodSeconds);
    if(cached > 0) return (int)cached;

    int multiplier;
    if(periodSeconds <= 300)           multiplier = 50;
    else if(periodSeconds <= 1800)     multiplier = (int)(50 + (periodSeconds - 300) * 10.0 / 1500.0);
    else if(periodSeconds <= 3600)     multiplier = (int)(60 + (periodSeconds - 1800) * 40.0 / 1800.0);
    else                               multiplier = 100;

    StoreExtensionMultiplier(currentPeriod, periodSeconds, (double)multiplier);
    return multiplier;
}

// PERF: Per-frame static cache for zone times — avoids repeated Bars/iTime/PeriodSeconds calls
// All zones in the same redraw cycle share identical start/end times
bool CalculateZoneTimes(datetime &startTime, datetime &endTime)
{
    static datetime s_cachedStart = 0;
    static datetime s_cachedEnd = 0;
    static int s_cachedPeriod = -1;
    static datetime s_cachedBarTime = 0;

    int currentPeriod = GetCachedPeriod();
    datetime bar0Time = iTime(_Symbol, _Period, 0);

    // Return cached result if same period and same bar
    if(s_cachedPeriod == currentPeriod && bar0Time > 0 && bar0Time == s_cachedBarTime &&
       s_cachedStart > 0 && s_cachedEnd > s_cachedStart) {
        startTime = s_cachedStart;
        endTime = s_cachedEnd;
        return true;
    }

    int safeBars = Bars(_Symbol, _Period);
    datetime currentTime = (safeBars > 0) ? bar0Time : 0;

    if(safeBars > 0) {
        int recheck = Bars(_Symbol, _Period);
        if(recheck != safeBars) {
            safeBars = recheck;
            currentTime = (safeBars > 0) ? iTime(_Symbol, _Period, 0) : 0;
        }
    }
    if(currentTime <= 0) currentTime = TimeCurrent();
    if(currentTime <= 0 || safeBars <= 0) return false;

    int periodMinutes = PeriodMinutes();
    int lookback = (periodMinutes < 60)
        ? MathMin(safeBars - 1, 20000)
        : MathMin(safeBars - 1, 5000);
    if(lookback < 0) lookback = 0;

    startTime = iTime(_Symbol, _Period, lookback);
    if(startTime <= 0) startTime = iTime(_Symbol, _Period, 0);
    if(startTime <= 0) return false;

    int periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    if(periodSeconds <= 0) return false;

    int multiplier = CalculateAdaptiveExtensionMultiplier(periodSeconds);
    endTime = currentTime + (periodSeconds * multiplier);

    // Store in static cache for next call in same frame
    if(endTime > startTime) {
        s_cachedStart = startTime;
        s_cachedEnd = endTime;
        s_cachedPeriod = currentPeriod;
        s_cachedBarTime = bar0Time;
    }
    return (endTime > startTime);
}

// PERF: Compute zone time range at most once per redraw frame.
// Uses CacheGetFrameTime() (refreshed in RedrawAllObjects) as frame key.
bool GetZoneTimesForCurrentFrame(datetime &startTime, datetime &endTime)
{
    static datetime s_frameKey = 0;
    static int s_cachedPeriod = -1;
    static datetime s_start = 0;
    static datetime s_end = 0;

    datetime frameKey = CacheGetFrameTime();
    int period = GetCachedPeriod();
    if(frameKey > 0 && frameKey == s_frameKey && period == s_cachedPeriod && s_start > 0 && s_end > s_start) {
        startTime = s_start;
        endTime = s_end;
        return true;
    }

    datetime calcStart = 0, calcEnd = 0;
    if(!CalculateZoneTimes(calcStart, calcEnd)) return false;

    s_frameKey = frameKey;
    s_cachedPeriod = period;
    s_start = calcStart;
    s_end = calcEnd;

    startTime = calcStart;
    endTime = calcEnd;
    return true;
}

// Core zone creation
SZoneCreationResult CreateZone(const SZoneCreationRequest &request)
{
    SZoneCreationResult result;
    result.success = false;
    result.zoneName = request.name;
    result.errorMessage = "";
    result.errorCode = ERR_ZONE_NONE;

    // Validate
    if(StringLen(request.name) == 0) {
        result.errorMessage = "Empty name";
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        return result;
    }
    if(request.topPrice <= 0 || request.bottomPrice <= 0 || request.topPrice <= request.bottomPrice) {
        result.errorMessage = "Invalid prices";
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
        return result;
    }

    int clampedTransparency = (int)MathMax(0, MathMin(100, request.transparency));

    // Time calculation
    datetime startTime = request.startTime;
    datetime endTime = request.endTime;

    if(startTime == 0 || endTime == 0) {
        if(!GetZoneTimesForCurrentFrame(startTime, endTime)) {
            result.errorMessage = "Time calculation failed";
            result.errorCode = ERR_ZONE_NO_DATA;
            return result;
        }
    }

    if(startTime <= 0 || endTime <= startTime) {
        result.errorMessage = "Invalid time range";
        result.errorCode = ERR_ZONE_RENDER_FAILED;
        return result;
    }

    // Calculate effective zone color (filled rectangle zones only)
    long finalColor = (long)GetZoneRenderColor(request.zoneColor, clampedTransparency);

    // Create or update object
    bool objectExists = CacheObjectExists(request.name);
    if(objectExists) {
        // FIX: Verify cache accuracy - cache can be stale after ObjectsDeleteAll in ClearAllLevels
        if(ObjectFind(0, request.name) < 0) {
            CacheRemoveObject(request.name);
            objectExists = false;
        }
    } else {
        objectExists = (ObjectFind(0, request.name) >= 0);
    }

    if(!objectExists) {
        long chartId = ChartID();
        if(!ObjectCreate(chartId, request.name, OBJ_RECTANGLE, 0,
                         startTime, request.topPrice, endTime, request.bottomPrice)) {
            int error = GetLastError();
            result.errorMessage = StringFormat("Create failed: error %d", error);
            result.errorCode = error;
            if(ObjectFind(chartId, request.name) >= 0)
                ObjectDelete(chartId, request.name);
            return result;
        }
        CacheAddObject(request.name, request.topPrice, request.zoneColor, 0, 0);

        ObjectSetInteger(0, request.name, OBJPROP_COLOR, finalColor);
        ObjectSetInteger(0, request.name, OBJPROP_BACK, true);
        ObjectSetInteger(0, request.name, OBJPROP_FILL, request.filled);
        ObjectSetInteger(0, request.name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, request.name, OBJPROP_RAY_RIGHT, true);
        ObjectSetInteger(0, request.name, OBJPROP_ZORDER, 0);
        ApplyVisibilityState(request.name, false);
    }
    else {
        SObjectCacheEntry cachedEntry;
        bool hasCached = CacheGetObject(request.name, cachedEntry);

        if(hasCached) {
            bool priceChanged = HasPriceChanged(cachedEntry.lastPrice, request.topPrice);
            bool colorChanged = HasColorChanged(cachedEntry.lastColor, request.zoneColor);
            bool renderColorChanged = ((color)ObjectGetInteger(0, request.name, OBJPROP_COLOR) != (color)finalColor);

            if(!priceChanged && !colorChanged && !renderColorChanged) {
                // FIX: Always apply visibility even when price/color unchanged
                // This ensures F-key toggle and periodic re-sync work for static zones
                ApplyVisibilityStateIfUnchangedSkip(request.name, false);
                result.success = true;
                return result;
            }

            if(priceChanged) {
                ObjectSetDouble(0, request.name, OBJPROP_PRICE, 0, request.topPrice);
                ObjectSetDouble(0, request.name, OBJPROP_PRICE, 1, request.bottomPrice);
                ObjectSetInteger(0, request.name, OBJPROP_TIME, 0, startTime);
                ObjectSetInteger(0, request.name, OBJPROP_TIME, 1, endTime);
            }
            if(colorChanged || renderColorChanged) {
                ObjectSetInteger(0, request.name, OBJPROP_COLOR, finalColor);
            }
        }
        else {
            ObjectSetDouble(0, request.name, OBJPROP_PRICE, 0, request.topPrice);
            ObjectSetDouble(0, request.name, OBJPROP_PRICE, 1, request.bottomPrice);
            ObjectSetInteger(0, request.name, OBJPROP_TIME, 0, startTime);
            ObjectSetInteger(0, request.name, OBJPROP_TIME, 1, endTime);
            ObjectSetInteger(0, request.name, OBJPROP_COLOR, finalColor);
        }
        CacheUpdateObject(request.name, request.topPrice, request.zoneColor, 0, 0);
        // PERF: Skip visibility for existing zones if state unchanged since last frame
        ApplyVisibilityStateIfUnchangedSkip(request.name, false);
    }

    result.success = true;
    return result;
}

bool DeleteZone(const string &zoneName)
{
    if(StringLen(zoneName) == 0) return false;
    if(ObjectFind(0, zoneName) >= 0) {
        if(ObjectDelete(0, zoneName))
            CacheRemoveObject(zoneName);
        else return false;
    }
    else {
        CacheRemoveObject(zoneName);
    }
    return true;
}

int DeleteZonesByPrefix(const string &prefix)
{
    if(StringLen(prefix) == 0) return 0;
    int deleted = 0;
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, prefix) == 0) {
            if(ObjectDelete(0, name)) {
                CacheRemoveObject(name);
                deleted++;
            }
        }
    }
    return deleted;
}

#endif // ZONE_FACTORY_MQH