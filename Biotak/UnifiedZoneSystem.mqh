#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#ifndef UNIFIED_ZONE_SYSTEM_MQH
#define UNIFIED_ZONE_SYSTEM_MQH

#include "ZoneFactory.mqh"

#define DEFAULT_ZONE_HEIGHT_PERCENT 0.125
#define MIN_ZONE_HEIGHT_PERCENT 0.01
#define MAX_ZONE_HEIGHT_PERCENT 1.0

struct SUnifiedZoneConfig {
    bool enabled;
    int transparency;
    double heightPercent;
    color defaultColor;
    ENUM_ZONE_STYLE style;
};

// Core zone creation between two levels
bool CreateUnifiedZone(const string zoneName,
                       const double prevLevelPrice,
                       const double currentLevelPrice,
                       const SUnifiedZoneConfig &config,
                       const color levelColor)
{
    if(!config.enabled) return true;

    if(config.style == FACTOR_ZONE_HIDDEN) {
        if(ObjectFind(0, zoneName) >= 0) ObjectDelete(0, zoneName);
        return true;
    }

    if(StringLen(zoneName) == 0) return false;
    if(prevLevelPrice <= 0 || currentLevelPrice <= 0) return false;
    if(AreEqual(prevLevelPrice, currentLevelPrice, EPSILON_PRICE)) return true;
    if(config.heightPercent < MIN_ZONE_HEIGHT_PERCENT || config.heightPercent > MAX_ZONE_HEIGHT_PERCENT) return false;

    double stepSize = MathAbs(currentLevelPrice - prevLevelPrice);
    if(stepSize <= 0) return false;

    double zoneHeight = stepSize * config.heightPercent * 0.5;
    double midPoint = (prevLevelPrice + currentLevelPrice) / 2.0;
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
    if(upperPrice <= lowerPrice) return false;

    if(config.style == FACTOR_ZONE_LINES) {
        return CreateFactorMidZone_LinesStyle(zoneName, upperPrice, lowerPrice,
                                              (levelColor == clrNONE) ? config.defaultColor : levelColor,
                                              config.transparency);
    }

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
    return result.success;
}

// Read zone config from global input parameters
SUnifiedZoneConfig GetUnifiedZoneConfig()
{
    SUnifiedZoneConfig config;
    config.enabled = inpShowMidZones;
    config.transparency = MathMax(0, MathMin(100, inpMidZoneTransparency));

    double hp = inpMidZoneHeightPercent / 100.0;
    if(hp < MIN_ZONE_HEIGHT_PERCENT) hp = MIN_ZONE_HEIGHT_PERCENT;
    if(hp > MAX_ZONE_HEIGHT_PERCENT) hp = MAX_ZONE_HEIGHT_PERCENT;
    config.heightPercent = hp;

    config.defaultColor = clrDarkGray;
    config.style = inpMidZoneStyle;
    return config;
}

// Simple zone for modes without structure/trigger separation
bool CreateSimpleZone(const string zoneName,
                      const double prevPrice,
                      const double currentPrice,
                      const color levelColor)
{
    SUnifiedZoneConfig config = GetUnifiedZoneConfig();
    return CreateUnifiedZone(zoneName, prevPrice, currentPrice, config, levelColor);
}

// Zone with smart fallback for all modes
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

    if(!config.enabled) {
        if(isStructure && structureEnabled) lastStructurePrice = currentPrice;
        else if(!isStructure && triggerEnabled) lastTriggerPrice = currentPrice;
        else lastFallbackPrice = currentPrice;
        return true;
    }

    double effectivePrevPrice = 0;
    bool shouldDraw = false;

    if(isStructure && structureEnabled) {
        effectivePrevPrice = lastStructurePrice;
        shouldDraw = (lastStructurePrice > 0);
        lastStructurePrice = currentPrice;
    }
    else if(!isStructure && triggerEnabled) {
        effectivePrevPrice = lastTriggerPrice;
        shouldDraw = (lastTriggerPrice > 0);
        lastTriggerPrice = currentPrice;
    }
    else {
        effectivePrevPrice = lastFallbackPrice;
        shouldDraw = (lastFallbackPrice > 0);
        lastFallbackPrice = currentPrice;
    }

    if(!shouldDraw || effectivePrevPrice <= 0) return true;

    if(fixedStepSize > 0) {
        double actualDistance = MathAbs(currentPrice - effectivePrevPrice);
        double zoneHeight = actualDistance * config.heightPercent * 0.5;
        double midPoint = (effectivePrevPrice + currentPrice) / 2.0;
        double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
        double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());

        if(config.style == FACTOR_ZONE_LINES) {
            return CreateFactorMidZone_LinesStyle(zoneName, upperPrice, lowerPrice,
                                                  (levelColor == clrNONE) ? config.defaultColor : levelColor,
                                                  config.transparency);
        }
        if(config.style == FACTOR_ZONE_HIDDEN) {
            if(ObjectFind(0, zoneName) >= 0) ObjectDelete(0, zoneName);
            return true;
        }

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
        return result.success;
    }

    return CreateUnifiedZone(zoneName, effectivePrevPrice, currentPrice, config, levelColor);
}

// Batch create zones
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

#endif // UNIFIED_ZONE_SYSTEM_MQH