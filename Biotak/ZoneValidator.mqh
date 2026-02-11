#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

#include "ConstantsAndEnums.mqh"
#include "ZoneConstants.mqh"
#include "PerformanceOptimizations.mqh"

//+------------------------------------------------------------------+
//| Validate Input Arrays                                            |

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

//+------------------------------------------------------------------+
bool ValidateCompleteConfig(
    const SLevelRawData &levels[],
    double stepSize,
    const SStyleConfig &config,
    int &outCount,
    double &outZoneHeight)
{
    // Use existing validation functions (DRY principle)
    
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

//+------------------------------------------------------------------+
//| ENHANCED VALIDATION SYSTEM (Task 2)                              |

//| Requirements: 1.6, 2.1-2.7, 13.1-13.7, 17.1-17.7                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Enhanced Validation Result Structure                             |

//| Requirements: 2.5, 17.1-17.5                                     |
//+------------------------------------------------------------------+
struct SZoneValidationResultEnhanced {
        bool valid;                 // Overall validation result
    string errorMessage;        // Human-readable error message
    int errorCode;              // Error code for programmatic handling
    
    // Diagnostic information
    int barsCount;              // Number of bars available
    int periodSeconds;          // Period in seconds
    datetime startTime;         // Calculated start time
    datetime endTime;           // Calculated end time
    double topPrice;            // Top price boundary
    double bottomPrice;         // Bottom price boundary
    string timeframeName;       // Timeframe name for logging
};

//+------------------------------------------------------------------+
//| Validate Zone Creation Preconditions                             |

//| Requirements: 1.6, 2.1, 2.2, 13.1                               |
//|                                                                  |
//| Fast-fail validation: checks name first, then Bars, then Period  |
//+------------------------------------------------------------------+
SZoneValidationResultEnhanced ValidateZoneCreationPreconditions(
    int period,
    string zoneName)
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
    
    // FAST FAILURE 1: Validate object name (cheapest check)
    if(!ValidateObjectName(zoneName)) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = "Invalid zone name: empty or too long";
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneCreationPreconditions: ", result.errorMessage);
    #endif
    return result;
    }
    
    // FAST FAILURE 2: Validate Bars count
    // Requirements 1.6, 2.1: Bars must be > 0
    result.barsCount = Bars(GetCachedSymbol(), (ENUM_TIMEFRAMES)period);
    if(result.barsCount <= 0) {
        result.errorCode = ERR_ZONE_NO_DATA;
    result.errorMessage = StringFormat("No bars available (Bars=%d)", result.barsCount);
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneCreationPreconditions: ", result.errorMessage, 
              " for zone '", zoneName, "'");
    #endif
    return result;
    }
    
    // FAST FAILURE 3: Validate PeriodSeconds
    result.periodSeconds = PeriodSeconds((ENUM_TIMEFRAMES)period);
    if(result.periodSeconds <= 0) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid PeriodSeconds=%d (must be positive)", 
                                          result.periodSeconds);
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneCreationPreconditions: ", result.errorMessage);
    #endif
    return result;
    }
    
    // Check for unreasonably large period (> 30 days = 2,592,000 seconds)
    const int MAX_REASONABLE_PERIOD_SECONDS = 2592000;
    if(result.periodSeconds > MAX_REASONABLE_PERIOD_SECONDS) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("PeriodSeconds=%d exceeds reasonable bounds (max=%d)", 
                                          result.periodSeconds, MAX_REASONABLE_PERIOD_SECONDS);
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneCreationPreconditions: ", result.errorMessage);
    #endif
    return result;
    }
    
    // Store timeframe name for diagnostic logging
    result.timeframeName = EnumToString((ENUM_TIMEFRAMES)period);
    
    // All preconditions passed
    result.valid = true;
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ValidateZoneCreationPreconditions: Passed for zone '", zoneName, 
          "' (Bars=", result.barsCount, ", PeriodSeconds=", result.periodSeconds, 
          ", Timeframe=", result.timeframeName, ")");
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Validate Zone Geometry Parameters                                |

//| Requirements: 2.3, 2.4, 13.2, 13.3                              |
//|                                                                  |
//| Validates price range and time range for zone creation           |
//+------------------------------------------------------------------+
SZoneValidationResultEnhanced ValidateZoneGeometryEnhanced(
    double topPrice,
    double bottomPrice,
    datetime startTime,
    datetime endTime)
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
    int cachedDigits = GetCachedDigits();
    
    // FAST FAILURE 1: Validate prices (before time calculations)
    if(!ValidatePrice(topPrice)) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid top price: %s", 
                                          DoubleToString(topPrice, cachedDigits));
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneGeometryEnhanced: ", result.errorMessage);
    #endif
    return result;
    }
    
    if(!ValidatePrice(bottomPrice)) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid bottom price: %s", 
                                          DoubleToString(bottomPrice, cachedDigits));
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneGeometryEnhanced: ", result.errorMessage);
    #endif
    return result;
    }
    
    // FAST FAILURE 2: Validate price range
    if(topPrice <= bottomPrice) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid price range: top=%s must be > bottom=%s",
                                          DoubleToString(topPrice, cachedDigits),
                                          DoubleToString(bottomPrice, cachedDigits));
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneGeometryEnhanced: ", result.errorMessage);
    #endif
    return result;
    }
    
    // FAST FAILURE 3: Validate time range
    if(startTime >= endTime) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid time range: start=%s must be < end=%s",
                                          TimeToString(startTime, TIME_DATE|TIME_MINUTES),
                                          TimeToString(endTime, TIME_DATE|TIME_MINUTES));
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneGeometryEnhanced: ", result.errorMessage);
    #endif
    return result;
    }
    
    // All geometry validations passed
    result.valid = true;
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ValidateZoneGeometryEnhanced: Passed (top=", DoubleToString(topPrice, cachedDigits),
          ", bottom=", DoubleToString(bottomPrice, cachedDigits),
          ", start=", TimeToString(startTime, TIME_DATE|TIME_MINUTES),
          ", end=", TimeToString(endTime, TIME_DATE|TIME_MINUTES), ")");
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Validate Zone Extension Parameters                               |

//| Requirements: 2.2, 13.4                                          |
//|                                                                  |
//| Validates extension calculation parameters                       |
//+------------------------------------------------------------------+
SZoneValidationResultEnhanced ValidateZoneExtension(
    int periodSeconds,
    datetime startTime,
    datetime endTime)
{
    SZoneValidationResultEnhanced result;
    result.valid = false;
    result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = "";
    result.barsCount = 0;
    result.periodSeconds = periodSeconds;
    result.startTime = startTime;
    result.endTime = endTime;
    result.topPrice = 0;
    result.bottomPrice = 0;
    result.timeframeName = "";
    
    // FAST FAILURE 1: Validate PeriodSeconds
    if(periodSeconds <= 0) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid PeriodSeconds=%d (must be positive)", 
                                          periodSeconds);
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneExtension: ", result.errorMessage);
    #endif
    return result;
    }
    
    // FAST FAILURE 2: Validate time range consistency
    if(startTime >= endTime) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Invalid extension time range: start=%s >= end=%s",
                                          TimeToString(startTime, TIME_DATE|TIME_MINUTES),
                                          TimeToString(endTime, TIME_DATE|TIME_MINUTES));
    #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateZoneExtension: ", result.errorMessage);
    #endif
    return result;
    }
    
    // Calculate extension duration
    int extensionDuration = (int)(endTime - startTime);
    
    // Validate extension is reasonable (not too short or too long)
    if(extensionDuration < periodSeconds) {
        result.errorCode = ERR_ZONE_INVALID_CONFIG;
    result.errorMessage = StringFormat("Extension duration (%d sec) < PeriodSeconds (%d sec)",
                                          extensionDuration, periodSeconds);
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ValidateZoneExtension: ", result.errorMessage, " (warning only)");
    #endif
        // Don't fail, just warn
    }
    
    // All extension validations passed
    result.valid = true;
    result.errorCode = ERR_ZONE_NONE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ValidateZoneExtension: Passed (PeriodSeconds=", periodSeconds,
          ", duration=", extensionDuration, " sec)");
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Log Zone Creation Failure with Full Diagnostic Context           |

//| Requirements: 1.7, 17.1-17.6                                     |
//|                                                                  |
//| Comprehensive logging for debugging zone display issues          |
//+------------------------------------------------------------------+
void LogZoneCreationFailure(const SZoneValidationResultEnhanced &validation,
                           const string zoneName = "")
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("═══════════════════════════════════════════════════════════");
    Print("❌ ZONE CREATION FAILURE DIAGNOSTIC");
    Print("═══════════════════════════════════════════════════════════");
    if(StringLen(zoneName) > 0) {
        Print("Zone Name: ", zoneName);
    }
    
    Print("Error Code: ", validation.errorCode);
    Print("Error Message: ", validation.errorMessage);
    if(StringLen(validation.timeframeName) > 0) {
        Print("Timeframe: ", validation.timeframeName);
    }
    if(validation.barsCount > 0) {
        Print("Bars Count: ", validation.barsCount);
    } else if(validation.errorCode == ERR_ZONE_NO_DATA) {
        Print("Bars Count: 0 (NO DATA AVAILABLE)");
    }
    if(validation.periodSeconds > 0) {
        Print("PeriodSeconds: ", validation.periodSeconds);
    }
    if(validation.topPrice > 0 || validation.bottomPrice > 0) {
        int cachedDigits = GetCachedDigits();
    Print("Price Range: top=", DoubleToString(validation.topPrice, cachedDigits),
              ", bottom=", DoubleToString(validation.bottomPrice, cachedDigits));
    }
    if(validation.startTime > 0 || validation.endTime > 0) {
        Print("Time Range: start=", TimeToString(validation.startTime, TIME_DATE|TIME_MINUTES),
              ", end=", TimeToString(validation.endTime, TIME_DATE|TIME_MINUTES));
    }
    
    Print("═══════════════════════════════════════════════════════════");
    #endif
    }

//+------------------------------------------------------------------+
//| Log Zone Creation Success                                        |

//| Requirement: 17.6                                                |
//+------------------------------------------------------------------+
void LogZoneCreationSuccess(const string zoneName)
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Zone created successfully: '", zoneName, "'");
    #endif
    }
