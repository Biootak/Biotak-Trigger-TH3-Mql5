//+------------------------------------------------------------------+
//|                                                ZoneValidator.mqh |
//|                                  Copyright 2025, Biotak Project  |
//|                                    Zone Validation & Safety      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneConstants.mqh"

//+------------------------------------------------------------------+
//| Validate Input Arrays                                            |
//| اعتبارسنجی آرایه‌های ورودی                                        |
//+------------------------------------------------------------------+
bool ValidateInputArrays(const SLevelRawData &levels[], int &outCount)
{
    outCount = ArraySize(levels);
    
    if(outCount <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateInputArrays: Empty levels array");
        #endif
        return false;
    }
    
    // Check for NULL prices
    for(int i = 0; i < outCount; i++) {
        if(levels[i].price <= 0) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ ValidateInputArrays: Invalid price at index ", i, ": ", levels[i].price);
            #endif
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Step Size                                               |
//| اعتبارسنجی اندازه گام                                             |
//+------------------------------------------------------------------+
bool ValidateStepSize(double stepSize)
{
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateStepSize: Invalid stepSize=", stepSize);
        #endif
        return false;
    }
    
    // Check for unreasonably large step (> 50% of typical price)
    double typicalPrice = (Bid + Ask) / 2.0;
    if(typicalPrice > 0 && stepSize > typicalPrice * 0.5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ValidateStepSize: Suspiciously large stepSize=", stepSize, 
              " (> 50% of price=", typicalPrice, ")");
        #endif
        // Don't fail, just warn
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Style Config                                            |
//| اعتبارسنجی تنظیمات استایل                                         |
//+------------------------------------------------------------------+
bool ValidateStyleConfig(const SStyleConfig &config)
{
    // Validate zone height percent
    if(config.zoneHeightPercent < 0 || config.zoneHeightPercent > 1.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateStyleConfig: Invalid zoneHeightPercent=", config.zoneHeightPercent,
              " (must be 0.0-1.0)");
        #endif
        return false;
    }
    
    // Validate transparency
    if(config.zoneTransparency < 0 || config.zoneTransparency > 100) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateStyleConfig: Invalid zoneTransparency=", config.zoneTransparency,
              " (must be 0-100)");
        #endif
        return false;
    }
    
    // Validate base multiplier (CRITICAL: prevent division by zero)
    if(config.baseMultiplier < 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateStyleConfig: Invalid baseMultiplier=", config.baseMultiplier,
              " (must be >= 1)");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Zone Height                                             |
//| اعتبارسنجی ارتفاع زون                                            |
//+------------------------------------------------------------------+
bool ValidateZoneHeight(double zoneHeight, double stepSize)
{
    if(zoneHeight <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneHeight: Invalid zoneHeight=", zoneHeight);
        #endif
        return false;
    }
    
    // Zone height should not exceed step size
    if(zoneHeight > stepSize) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ValidateZoneHeight: Zone height (", zoneHeight, 
              ") exceeds step size (", stepSize, ")");
        #endif
        // Don't fail, just warn
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Zone Geometry                                           |
//| اعتبارسنجی هندسه زون                                             |
//+------------------------------------------------------------------+
SZoneValidationResult ValidateZoneGeometry(
    double prevPrice, 
    double currentPrice,
    double zoneHeight)
{
    SZoneValidationResult result;
    result.isValid = false;
    result.errorCode = ZONE_ERROR_NONE;
    result.errorMessage = "";
    
    // OPTIMIZATION: Use centralized cached values from PerformanceOptimizations.mqh
    int s_cachedDigits = GetCachedDigits();
    double s_cachedPoint = GetCachedPoint();
    
    // Check for invalid prices
    if(prevPrice <= 0 || currentPrice <= 0) {
        result.errorCode = ZONE_ERROR_INVALID_PRICES;
        result.errorMessage = "Invalid prices: prev=" + DoubleToString(prevPrice, s_cachedDigits) +
                            ", current=" + DoubleToString(currentPrice, s_cachedDigits);
        return result;
    }
    
    // Check for equal prices (use cached Point)
    if(MathAbs(prevPrice - currentPrice) < s_cachedPoint) {
        result.errorCode = ZONE_ERROR_EQUAL_PRICES;
        result.errorMessage = "Prices are equal (no zone needed)";
        return result;
    }
    
    // Check zone height
    if(zoneHeight <= 0) {
        result.errorCode = ZONE_ERROR_INVALID_HEIGHT;
        result.errorMessage = "Invalid zone height: " + DoubleToString(zoneHeight, s_cachedDigits);
        return result;
    }
    
    // Calculate midpoint and boundaries
    double midPoint = (prevPrice + currentPrice) / 2.0;
    double topPrice = midPoint + zoneHeight;
    double bottomPrice = midPoint - zoneHeight;
    
    // Check for inverted bounds
    if(topPrice <= bottomPrice) {
        result.errorCode = ZONE_ERROR_INVERTED_BOUNDS;
        result.errorMessage = "Inverted bounds: top=" + DoubleToString(topPrice, s_cachedDigits) +
                            ", bottom=" + DoubleToString(bottomPrice, s_cachedDigits);
        return result;
    }
    
    // Check for reasonable range (not too far from current price)
    // استفاده از cached market price برای بهینه‌سازی
    double currentMarketPrice = GetCachedMarketPrice();
    if(currentMarketPrice > 0) {
        double maxReasonableDistance = currentMarketPrice * 2.0; // 200% of current price
        
        if(MathAbs(topPrice - currentMarketPrice) > maxReasonableDistance ||
           MathAbs(bottomPrice - currentMarketPrice) > maxReasonableDistance) {
            result.errorCode = ZONE_ERROR_OUT_OF_RANGE;
            result.errorMessage = "Zone too far from current price";
            // Don't fail, just warn
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ ValidateZoneGeometry: ", result.errorMessage);
            #endif
        }
    }
    
    // All checks passed
    result.isValid = true;
    return result;
}

//+------------------------------------------------------------------+
//| Validate Object Name (Fast Failure)                              |
//| اعتبارسنجی نام شیء (شکست سریع)                                   |
//| Requirements: 13.1                                                |
//+------------------------------------------------------------------+
bool ValidateObjectName(const string name)
{
    // Fast failure: empty name
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateObjectName: Empty object name");
        #endif
        return false;
    }
    
    // Fast failure: name too long (MT4 limit is 63 characters)
    if(StringLen(name) > 63) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateObjectName: Name too long (", StringLen(name), " chars, max 63)");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Price (Fast Failure)                                    |
//| اعتبارسنجی قیمت (شکست سریع)                                      |
//| Requirements: 13.2                                                |
//+------------------------------------------------------------------+
bool ValidatePrice(double price)
{
    // Fast failure: negative or zero price
    if(price <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePrice: Invalid price (", DoubleToString(price, 8), "), must be positive");
        #endif
        return false;
    }
    
    // Fast failure: price out of reasonable range
    // Use cached market price for comparison
    double marketPrice = GetCachedMarketPrice();
    if(marketPrice > 0) {
        // Price should be within 1000x of current market price
        double maxReasonablePrice = marketPrice * 1000.0;
        double minReasonablePrice = marketPrice / 1000.0;
        
        if(price > maxReasonablePrice || price < minReasonablePrice) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ ValidatePrice: Price (", DoubleToString(price, 8), 
                  ") out of reasonable range (", DoubleToString(minReasonablePrice, 8),
                  " - ", DoubleToString(maxReasonablePrice, 8), ")");
            #endif
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Color (Fast Failure)                                    |
//| اعتبارسنجی رنگ (شکست سریع)                                       |
//| Requirements: 13.3                                                |
//+------------------------------------------------------------------+
bool ValidateColor(color clr)
{
    // Fast failure: clrNONE is invalid for visible objects
    if(clr == clrNONE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateColor: clrNONE is not a valid color for visible objects");
        #endif
        return false;
    }
    
    // MT4/MT5 colors are stored as integers (0xBBGGRR format)
    // Valid range: 0x000000 to 0xFFFFFF (16777215)
    int colorValue = (int)clr;
    if(colorValue < 0 || colorValue > 16777215) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateColor: Invalid color value (", colorValue, "), must be 0-16777215");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Line Style (Fast Failure)                               |
//| اعتبارسنجی استایل خط (شکست سریع)                                 |
//| Requirements: 13.4                                                |
//+------------------------------------------------------------------+
bool ValidateLineStyle(int style)
{
    // Fast failure: invalid ENUM_LINE_STYLE
    // Valid values: STYLE_SOLID (0), STYLE_DASH (1), STYLE_DOT (2), 
    //               STYLE_DASHDOT (3), STYLE_DASHDOTDOT (4)
    if(style < STYLE_SOLID || style > STYLE_DASHDOTDOT) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateLineStyle: Invalid style (", style, "), must be 0-4 (ENUM_LINE_STYLE)");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Line Width (Fast Failure)                               |
//| اعتبارسنجی عرض خط (شکست سریع)                                    |
//| Requirements: 13.5                                                |
//+------------------------------------------------------------------+
bool ValidateLineWidth(int width)
{
    // Fast failure: invalid width
    // Valid range: 1-5 for MT4/MT5
    if(width < 1 || width > 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateLineWidth: Invalid width (", width, "), must be 1-5");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Drawing Parameters (Fast Failure - All at Once)         |
//| اعتبارسنجی پارامترهای رسم (شکست سریع - همه با هم)                |
//| Requirements: 9.2, 13.1, 13.2, 13.3, 13.4, 13.5                  |
//|                                                                  |
//| Returns false immediately on first validation failure            |
//| This is the main validation entry point for drawing operations   |
//+------------------------------------------------------------------+
bool ValidateDrawingParameters(
    const string objectName,
    double price,
    color clr,
    int style,
    int width)
{
    // Fast failure chain - return immediately on first failure
    
    // 1. Validate object name (non-empty)
    if(!ValidateObjectName(objectName)) {
        return false;
    }
    
    // 2. Validate price (positive, within range)
    if(!ValidatePrice(price)) {
        return false;
    }
    
    // 3. Validate color (valid MT4/MT5 color)
    if(!ValidateColor(clr)) {
        return false;
    }
    
    // 4. Validate style (valid ENUM_LINE_STYLE)
    if(!ValidateLineStyle(style)) {
        return false;
    }
    
    // 5. Validate width (1-5)
    if(!ValidateLineWidth(width)) {
        return false;
    }
    
    // All validations passed
    return true;
}

//+------------------------------------------------------------------+
//| Validate Zone Drawing Parameters (Fast Failure)                  |
//| اعتبارسنجی پارامترهای رسم زون (شکست سریع)                        |
//| Requirements: 9.2, 13.1, 13.2, 13.3                              |
//+------------------------------------------------------------------+
bool ValidateZoneDrawingParameters(
    const string objectName,
    double topPrice,
    double bottomPrice,
    color clr,
    int transparency)
{
    // Fast failure chain
    
    // 1. Validate object name
    if(!ValidateObjectName(objectName)) {
        return false;
    }
    
    // 2. Validate top price
    if(!ValidatePrice(topPrice)) {
        return false;
    }
    
    // 3. Validate bottom price
    if(!ValidatePrice(bottomPrice)) {
        return false;
    }
    
    // 4. Validate price order (top must be > bottom)
    if(topPrice <= bottomPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneDrawingParameters: Top price (", DoubleToString(topPrice, 8),
              ") must be greater than bottom price (", DoubleToString(bottomPrice, 8), ")");
        #endif
        return false;
    }
    
    // 5. Validate color
    if(!ValidateColor(clr)) {
        return false;
    }
    
    // 6. Validate transparency (0-100)
    if(transparency < 0 || transparency > 100) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneDrawingParameters: Invalid transparency (", transparency, "), must be 0-100");
        #endif
        return false;
    }
    
    // All validations passed
    return true;
}

//+------------------------------------------------------------------+
//| Validate Complete Configuration                                  |
//| اعتبارسنجی کامل تنظیمات                                          |
//+------------------------------------------------------------------+
bool ValidateCompleteConfig(
    const SLevelRawData &levels[],
    double stepSize,
    const SStyleConfig &config,
    int &outCount,
    double &outZoneHeight)
{
    // GOLD FIX v3: Use existing validation functions (DRY principle)
    
    // Validate input arrays
    if(!ValidateInputArrays(levels, outCount)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCompleteConfig: Input array validation failed");
        #endif
        return false;
    }
    
    // Validate step size
    if(!ValidateStepSize(stepSize)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCompleteConfig: Step size validation failed");
        #endif
        return false;
    }
    
    // Validate style config
    if(!ValidateStyleConfig(config)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCompleteConfig: Style config validation failed");
        #endif
        return false;
    }
    
    // Calculate and validate zone height (unique to this function)
    outZoneHeight = stepSize * config.zoneHeightPercent * 0.5;
    if(outZoneHeight <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCompleteConfig: Invalid zoneHeight=", outZoneHeight);
        #endif
        return false;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    // OPTIMIZATION: Use centralized cached Digits value
    int s_cachedDigitsConfig = GetCachedDigits();
    
    Print("✅ ValidateCompleteConfig: All validations passed");
    Print("   Count=", outCount, ", StepSize=", DoubleToString(stepSize, s_cachedDigitsConfig),
          ", ZoneHeight=", DoubleToString(outZoneHeight, s_cachedDigitsConfig));
    #endif
    
    return true;
}
