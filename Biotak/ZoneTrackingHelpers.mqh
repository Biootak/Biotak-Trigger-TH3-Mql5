#ifndef ZONE_TRACKING_HELPERS_MQH
#define ZONE_TRACKING_HELPERS_MQH

#include "PerformanceOptimizations.mqh"

// Initialize zone tracking variables for structure/trigger separation
bool InitializeZoneTracking(const double centerPrice,
                            double &lastStructurePrice,
                            double &lastTriggerPrice,
                            double &lastFallbackPrice)
{
    if(centerPrice <= 0) {
        lastStructurePrice = 0;
        lastTriggerPrice = 0;
        lastFallbackPrice = 0;
        return false;
    }

    double normalizedCenter = NormalizeDouble(centerPrice, GetCachedDigits());
    if(normalizedCenter <= 0) {
        lastStructurePrice = 0;
        lastTriggerPrice = 0;
        lastFallbackPrice = 0;
        return false;
    }

    lastStructurePrice = normalizedCenter;
    lastTriggerPrice = 0; // Skip first zone from center
    lastFallbackPrice = normalizedCenter;
    return true;
}

// Validate zone tracking state
bool ValidateZoneTrackingState(const double lastStructurePrice,
                               const double lastTriggerPrice,
                               const double lastFallbackPrice,
                               const string contextName)
{
    bool isValid = true;
    if(lastStructurePrice < 0) isValid = false;
    if(lastFallbackPrice < 0) isValid = false;
    if(lastTriggerPrice < 0) isValid = false;
    return isValid;
}

#endif // ZONE_TRACKING_HELPERS_MQH