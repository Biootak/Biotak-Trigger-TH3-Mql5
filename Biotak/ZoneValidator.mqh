#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#ifndef ZONE_VALIDATOR_MQH
#define ZONE_VALIDATOR_MQH

#include "ConstantsAndEnums.mqh"
#include "ZoneConstants.mqh"
#include "PerformanceOptimizations.mqh"

// Validation result for zone geometry
SZoneValidationResult ValidateZoneGeometry(
    double prevPrice,
    double currentPrice,
    double zoneHeight)
{
    SZoneValidationResult result;
    result.isValid = false;
    result.errorCode = ZONE_ERROR_NONE;
    result.errorMessage = "";

    int digits = GetCachedDigits();
    double point = GetCachedPoint();

    if(prevPrice <= 0 || currentPrice <= 0) {
        result.errorCode = ZONE_ERROR_INVALID_PRICES;
        result.errorMessage = "Invalid prices";
        return result;
    }

    if(MathAbs(prevPrice - currentPrice) < point) {
        result.errorCode = ZONE_ERROR_EQUAL_PRICES;
        result.errorMessage = "Prices are equal";
        return result;
    }

    if(zoneHeight <= 0) {
        result.errorCode = ZONE_ERROR_INVALID_HEIGHT;
        result.errorMessage = "Invalid zone height";
        return result;
    }

    double midPoint = (prevPrice + currentPrice) / 2.0;
    if(midPoint + zoneHeight <= midPoint - zoneHeight) {
        result.errorCode = ZONE_ERROR_INVERTED_BOUNDS;
        result.errorMessage = "Inverted bounds";
        return result;
    }

    result.isValid = true;
    return result;
}

// Validate step size
bool ValidateStepSize(double stepSize)
{
    if(stepSize <= 0) return false;

    double price = GetCachedMarketPrice();
    if(price > 0 && stepSize > price * 0.5) {
        _LOG_GATE_D Print("[D][ZONE] ValidateStepSize: large stepSize=", stepSize, " vs price=", price);
    }
    return true;
}

// Validate style config
bool ValidateStyleConfig(const SStyleConfig &config)
{
    if(config.zoneHeightPercent < 0 || config.zoneHeightPercent > 1.0) return false;
    if(config.zoneTransparency < 0 || config.zoneTransparency > 100) return false;
    if(config.baseMultiplier < 1) return false;
    return true;
}

// Validate input arrays
bool ValidateInputArrays(const SLevelRawData &levels[], int &outCount)
{
    outCount = ArraySize(levels);
    if(outCount <= 0) return false;
    for(int i = 0; i < outCount; i++) {
        if(levels[i].price <= 0) return false;
    }
    return true;
}

// Validate object name
bool ValidateObjectName(const string name)
{
    return (StringLen(name) > 0 && StringLen(name) <= 63);
}

// Validate price
bool ValidatePrice(double price)
{
    if(price <= 0) return false;
    double marketPrice = GetCachedMarketPrice();
    if(marketPrice > 0) {
        if(price > marketPrice * 1000.0 || price < marketPrice / 1000.0)
            return false;
    }
    return true;
}

// Enhanced validation result
struct SZoneValidationResultEnhanced {
    bool valid;
    string errorMessage;
    int errorCode;
    int barsCount;
    int periodSeconds;
    datetime startTime;
    datetime endTime;
    double topPrice;
    double bottomPrice;
    string timeframeName;
};

// Validate zone creation preconditions
SZoneValidationResultEnhanced ValidateZoneCreationPreconditions(int period, string zoneName)
{
    SZoneValidationResultEnhanced result;
    result.valid = false;
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = "";
    result.barsCount = 0;
    result.periodSeconds = 0;
    result.startTime = 0;
    result.endTime = 0;
    result.topPrice = 0;
    result.bottomPrice = 0;
    result.timeframeName = "";

    if(!ValidateObjectName(zoneName)) {
        result.errorMessage = "Invalid zone name";
        return result;
    }

    result.barsCount = Bars(GetCachedSymbol(), (ENUM_TIMEFRAMES)period);
    if(result.barsCount <= 0) {
        result.errorCode = ERR_ZONE_NO_DATA;
        result.errorMessage = StringFormat("No bars (Bars=%d)", result.barsCount);
        return result;
    }

    result.periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)period);
    if(result.periodSeconds <= 0 || result.periodSeconds > 2592000) {
        result.errorMessage = StringFormat("Invalid PeriodSeconds=%d", result.periodSeconds);
        return result;
    }

    result.timeframeName = EnumToString((ENUM_TIMEFRAMES)period);
    result.valid = true;
    result.errorCode = ERR_ZONE_NONE;
    return result;
}

// Validate zone geometry (enhanced)
SZoneValidationResultEnhanced ValidateZoneGeometryEnhanced(
    double topPrice, double bottomPrice,
    datetime startTime, datetime endTime)
{
    SZoneValidationResultEnhanced result;
    result.valid = false;
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = "";
    result.barsCount = 0;
    result.periodSeconds = 0;
    result.startTime = startTime;
    result.endTime = endTime;
    result.topPrice = topPrice;
    result.bottomPrice = bottomPrice;
    result.timeframeName = "";

    if(!ValidatePrice(topPrice) || !ValidatePrice(bottomPrice)) {
        result.errorMessage = "Invalid prices";
        return result;
    }
    if(topPrice <= bottomPrice) {
        result.errorMessage = "top must be > bottom";
        return result;
    }
    if(startTime >= endTime) {
        result.errorMessage = "start must be < end";
        return result;
    }

    result.valid = true;
    result.errorCode = ERR_ZONE_NONE;
    return result;
}

// Log zone creation failure
void LogZoneCreationFailure(const SZoneValidationResultEnhanced &v, const string zoneName = "")
{
    _LOG_GATE_E Print("[E][ZONE] ZONE FAIL: ", zoneName, " code=", v.errorCode, " ", v.errorMessage);
}

// Log zone creation success
void LogZoneCreationSuccess(const string zoneName)
{
    _LOG_GATE_D Print("[D][ZONE] ZONE OK: ", zoneName);
}

#endif // ZONE_VALIDATOR_MQH
