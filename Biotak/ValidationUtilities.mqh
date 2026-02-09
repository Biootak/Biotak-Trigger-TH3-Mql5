//+------------------------------------------------------------------+
//|                                        ValidationUtilities.mqh   |
//|                     Centralized Validation Functions             |
//|                     توابع متمرکز اعتبارسنجی                      |
//|                     DRY Principle Implementation                 |
//+------------------------------------------------------------------+

#include "FloatingPointHelper.mqh"
#include "ErrorCodes.mqh"

//+------------------------------------------------------------------+
//| Validation Result Structure                                      |
//+------------------------------------------------------------------+
struct ValidationResult {
    bool isValid;
    int errorCode;
    string errorMessage;
    double correctedValue;
};

//+------------------------------------------------------------------+
//| Validate Array Index                                             |
//| اعتبارسنجی ایندکس آرایه                                          |
//+------------------------------------------------------------------+
bool ValidateArrayIndex(int index, int arraySize, const string context = "") {
    if(index < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        string ctxMsg1 = (StringLen(context) > 0) ? " in " + context : "";
        Print("❌ ValidateArrayIndex: Negative index (", index, ")", ctxMsg1);
        #endif
        return false;
    }
    
    if(index >= arraySize) {
        #ifdef ENABLE_DEBUG_LOGS
        string ctxMsg2 = (StringLen(context) > 0) ? " in " + context : "";
        Print("❌ ValidateArrayIndex: Index out of bounds (", index, " >= ", arraySize, ")", ctxMsg2);
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Array Sizes Match                                       |
//| اعتبارسنجی تطابق اندازه آرایه‌ها                                 |
//+------------------------------------------------------------------+
bool ValidateArraySizesMatch(int size1, int size2, const string name1, const string name2) {
    if(size1 != size2) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Array size mismatch: ", name1, "=", size1, ", ", name2, "=", size2);
        #endif
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Validate Price Value                                             |
//| اعتبارسنجی مقدار قیمت                                            |
//+------------------------------------------------------------------+
ValidationResult ValidatePrice(double price, const string paramName = "price") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = price;
    
    // Check for negative
    if(price < 0) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_PRICE;
        result.errorMessage = paramName + " cannot be negative: " + DoubleToString(price, 5);
        result.correctedValue = 0;
        return result;
    }
    
    // Check for zero (warning, not error)
    if(IsZero(price, EPSILON_PRICE)) {
        result.errorMessage = paramName + " is zero";
        result.correctedValue = 0;
        return result;
    }
    
    // Check for unreasonably large values
    double maxReasonablePrice = 1000000.0;
    if(price > maxReasonablePrice) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = paramName + " too large: " + DoubleToString(price, 2);
        result.correctedValue = maxReasonablePrice;
        return result;
    }
    
    // Check for unreasonably small values
    double minReasonablePrice = 0.00001;
    if(price > 0 && price < minReasonablePrice) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = paramName + " too small: " + DoubleToString(price, 8);
        result.correctedValue = minReasonablePrice;
        return result;
    }
    
    // Check for NaN or Infinity
    if(price != price || price == EMPTY_VALUE) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_PRICE;
        result.errorMessage = paramName + " is NaN or EMPTY_VALUE";
        result.correctedValue = 0;
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Percentage Value                                        |
//| اعتبارسنجی مقدار درصد                                            |
//+------------------------------------------------------------------+
ValidationResult ValidatePercentage(double percentage, double minValue = 0.001, 
                                    double maxValue = 100.0, const string paramName = "percentage") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = percentage;
    
    // Check range
    if(percentage < minValue) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = paramName + " too small: " + DoubleToString(percentage, 3) + 
                            " (min: " + DoubleToString(minValue, 3) + ")";
        result.correctedValue = minValue;
        return result;
    }
    
    if(percentage > maxValue) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = paramName + " too large: " + DoubleToString(percentage, 3) + 
                            " (max: " + DoubleToString(maxValue, 3) + ")";
        result.correctedValue = maxValue;
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Integer Range                                           |
//| اعتبارسنجی محدوده عدد صحیح                                       |
//+------------------------------------------------------------------+
bool ValidateIntRange(int value, int minValue, int maxValue, const string paramName = "value") {
    if(value < minValue || value > maxValue) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ", paramName, " out of range: ", value, " (valid: ", minValue, "-", maxValue, ")");
        #endif
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Validate String Not Empty                                        |
//| اعتبارسنجی رشته غیرخالی                                          |
//+------------------------------------------------------------------+
bool ValidateStringNotEmpty(const string str, const string paramName = "string") {
    if(StringLen(str) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ", paramName, " is empty");
        #endif
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Validate Timeframe                                               |
//| اعتبارسنجی تایم‌فریم                                             |
//+------------------------------------------------------------------+
bool ValidateTimeframe(int timeframe) {
    // Valid MT4 timeframes
    switch(timeframe) {
        case PERIOD_M1:
        case PERIOD_M5:
        case PERIOD_M15:
        case PERIOD_M30:
        case PERIOD_H1:
        case PERIOD_H4:
        case PERIOD_D1:
        case PERIOD_W1:
        case PERIOD_MN1:
            return true;
        default:
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Invalid timeframe: ", timeframe);
            #endif
            return false;
    }
}

//+------------------------------------------------------------------+
//| Validate Color Value                                             |
//| اعتبارسنجی مقدار رنگ                                             |
//+------------------------------------------------------------------+
bool ValidateColor(color clr, const string paramName = "color") {
    // In MQL4, color is uint, so always >= 0
    // Check for clrNONE (special value)
    if(clr == clrNONE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ", paramName, " is clrNONE");
        #endif
        return true; // Not an error, just a warning
    }
    
    // Check for valid RGB range (0x00RRGGBB)
    if(clr > 0x00FFFFFF) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ", paramName, " invalid: ", ColorToString(clr));
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Batch Validation Helper                                          |
//| کمک‌کننده اعتبارسنجی دسته‌ای                                     |
//+------------------------------------------------------------------+
bool ValidatePriceRange(double price1, double price2, const string name1, const string name2) {
    ValidationResult result1 = ValidatePrice(price1, name1);
    ValidationResult result2 = ValidatePrice(price2, name2);
    
    if(!result1.isValid) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ", result1.errorMessage);
        #endif
        return false;
    }
    
    if(!result2.isValid) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ", result2.errorMessage);
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Division Operands                                       |
//| اعتبارسنجی عملوندهای تقسیم                                       |
//+------------------------------------------------------------------+
bool ValidateDivisionOperands(double numerator, double denominator, const string context = "") {
    if(IsZero(denominator, EPSILON_GENERAL)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Division by zero", (StringLen(context) > 0) ? " in " + context : "",
              " (denominator=", DoubleToString(denominator, 10), ")");
        #endif
        return false;
    }
    
    // Check for potential overflow
    if(MathAbs(numerator) > DBL_MAX / 2.0 && MathAbs(denominator) < 1.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Potential overflow in division", (StringLen(context) > 0) ? " in " + context : "");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| TASK 15.1: VALIDATION ERROR HANDLING                             |
//| Requirements: 13.1, 13.2, 13.3, 13.4, 13.5                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Validate Object Name                                             |
//| اعتبارسنجی نام شیء                                               |
//| Requirement 13.1: Handle empty object names                      |
//+------------------------------------------------------------------+
bool ValidateObjectName(const string name, const string context = "") {
    // Check for empty name
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateObjectName: Empty object name", 
              (StringLen(context) > 0) ? " in " + context : "");
        #endif
        return false;
    }
    
    // Check for maximum length (MT4 limit is 63 characters)
    if(StringLen(name) > 63) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateObjectName: Name too long (", StringLen(name), " > 63) in ", context);
        Print("   Name: ", StringSubstr(name, 0, 50), "...");
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Validate Price for Object Creation                               |
//| اعتبارسنجی قیمت برای ساخت شیء                                    |
//| Requirement 13.2: Handle invalid prices                          |
//+------------------------------------------------------------------+
ValidationResult ValidatePriceForObject(double price, const string context = "") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = price;
    
    // Check for negative price
    if(price < 0) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_PRICE;
        result.errorMessage = "Negative price: " + DoubleToString(price, 5);
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = 0;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePriceForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    // Check for zero price
    if(IsZero(price, EPSILON_PRICE)) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_PRICE;
        result.errorMessage = "Zero price";
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = 0;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePriceForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    // Check for out of range (too large)
    double maxPrice = 1000000.0;
    if(price > maxPrice) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = "Price too large: " + DoubleToString(price, 2) + " > " + DoubleToString(maxPrice, 0);
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = maxPrice;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePriceForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    // Check for out of range (too small)
    double minPrice = 0.00001;
    if(price < minPrice) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = "Price too small: " + DoubleToString(price, 8) + " < " + DoubleToString(minPrice, 8);
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = minPrice;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePriceForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    // Check for NaN or EMPTY_VALUE
    if(price != price || price == EMPTY_VALUE) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_PRICE;
        result.errorMessage = "Price is NaN or EMPTY_VALUE";
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = 0;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidatePriceForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Color for Object                                        |
//| اعتبارسنجی رنگ برای شیء                                          |
//| Requirement 13.3: Handle invalid colors                          |
//+------------------------------------------------------------------+
ValidationResult ValidateColorForObject(color clr, const string context = "") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = clr;
    
    // clrNONE is valid (means no color)
    if(clr == clrNONE) {
        return result;
    }
    
    // Check for valid RGB range (0x00RRGGBB)
    // In MQL4, color is uint, so always >= 0
    if(clr > 0x00FFFFFF) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_COLOR;
        result.errorMessage = "Invalid color value: " + IntegerToString(clr);
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = clrGray; // Default fallback
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateColorForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Line Style for Object                                   |
//| اعتبارسنجی استایل خط برای شیء                                    |
//| Requirement 13.4: Handle invalid styles                          |
//+------------------------------------------------------------------+
ValidationResult ValidateLineStyleForObject(int style, const string context = "") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = style;
    
    // Valid ENUM_LINE_STYLE values in MT4
    // STYLE_SOLID = 0, STYLE_DASH = 1, STYLE_DOT = 2, STYLE_DASHDOT = 3, STYLE_DASHDOTDOT = 4
    if(style < 0 || style > 4) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_STYLE;
        result.errorMessage = "Invalid line style: " + IntegerToString(style) + " (valid: 0-4)";
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        result.correctedValue = STYLE_SOLID; // Default fallback
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateLineStyleForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Line Width for Object                                   |
//| اعتبارسنجی عرض خط برای شیء                                       |
//| Requirement 13.5: Handle invalid widths                          |
//+------------------------------------------------------------------+
ValidationResult ValidateLineWidthForObject(int width, const string context = "") {
    ValidationResult result;
    result.isValid = true;
    result.errorCode = 0;
    result.errorMessage = "";
    result.correctedValue = width;
    
    // Valid width range in MT4 is 1-5
    if(width < 1 || width > 5) {
        result.isValid = false;
        result.errorCode = ERR_OUT_OF_RANGE;
        result.errorMessage = "Invalid line width: " + IntegerToString(width) + " (valid: 1-5)";
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        
        // Clamp to valid range
        if(width < 1) result.correctedValue = 1;
        else if(width > 5) result.correctedValue = 5;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateLineWidthForObject: ", result.errorMessage);
        #endif
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Comprehensive Object Creation Validation                         |
//| اعتبارسنجی جامع ساخت شیء                                         |
//| Requirements: 13.1, 13.2, 13.3, 13.4, 13.5                       |
//+------------------------------------------------------------------+
struct ObjectValidationResult {
    bool isValid;
    string errorMessage;
    int errorCode;
    
    // Corrected values (if validation failed but can be corrected)
    string correctedName;
    double correctedPrice;
    color correctedColor;
    int correctedStyle;
    int correctedWidth;
};

ObjectValidationResult ValidateObjectCreationParams(const string name, const double price,
                                                     const color clr, const int style,
                                                     const int width, const string context = "") {
    ObjectValidationResult result;
    result.isValid = true;
    result.errorMessage = "";
    result.errorCode = 0;
    result.correctedName = name;
    result.correctedPrice = price;
    result.correctedColor = clr;
    result.correctedStyle = style;
    result.correctedWidth = width;
    
    // Validate name
    if(!ValidateObjectName(name, context)) {
        result.isValid = false;
        result.errorCode = ERR_INVALID_NAME;
        result.errorMessage = "Invalid object name";
        if(StringLen(context) > 0) result.errorMessage += " in " + context;
        return result;
    }
    
    // Validate price
    ValidationResult priceResult = ValidatePriceForObject(price, context);
    if(!priceResult.isValid) {
        result.isValid = false;
        result.errorCode = priceResult.errorCode;
        result.errorMessage = priceResult.errorMessage;
        result.correctedPrice = priceResult.correctedValue;
        return result;
    }
    
    // Validate color
    ValidationResult colorResult = ValidateColorForObject(clr, context);
    if(!colorResult.isValid) {
        result.isValid = false;
        result.errorCode = colorResult.errorCode;
        result.errorMessage = colorResult.errorMessage;
        result.correctedColor = (color)colorResult.correctedValue;
        return result;
    }
    
    // Validate style
    ValidationResult styleResult = ValidateLineStyleForObject(style, context);
    if(!styleResult.isValid) {
        result.isValid = false;
        result.errorCode = styleResult.errorCode;
        result.errorMessage = styleResult.errorMessage;
        result.correctedStyle = (int)styleResult.correctedValue;
        return result;
    }
    
    // Validate width
    ValidationResult widthResult = ValidateLineWidthForObject(width, context);
    if(!widthResult.isValid) {
        result.isValid = false;
        result.errorCode = widthResult.errorCode;
        result.errorMessage = widthResult.errorMessage;
        result.correctedWidth = (int)widthResult.correctedValue;
        return result;
    }
    
    return result;
}


//+------------------------------------------------------------------+
//| TASK 15.2: MT4/MT5 API ERROR HANDLING                            |
//| Requirements: 6.5                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Handle ObjectCreate Error                                        |
//| مدیریت خطای ObjectCreate                                         |
//| Requirement 6.5: Handle ObjectCreate failures                    |
//+------------------------------------------------------------------+
struct ObjectCreateErrorResult {
    bool shouldRetry;
    bool shouldRemoveFromCache;
    string errorMessage;
    int errorCode;
};

ObjectCreateErrorResult HandleObjectCreateError(const string objectName, const string context = "") {
    ObjectCreateErrorResult result;
    result.shouldRetry = false;
    result.shouldRemoveFromCache = false;
    result.errorMessage = "";
    result.errorCode = GetLastError();
    
    switch(result.errorCode) {
        case 0:
            // No error
            result.errorMessage = "Success";
            break;
            
        case 4200:
            // ERR_OBJECT_ALREADY_EXISTS - Object already exists
            result.errorMessage = "Object already exists: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = false;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ HandleObjectCreateError: ", result.errorMessage, 
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   This is not a critical error - will update existing object");
            #endif
            break;
            
        case 4014:
            // ERR_UNKNOWN_COMMAND - Unknown command
            result.errorMessage = "Unknown command (4014) for object: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectCreateError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   This indicates an API compatibility issue");
            #endif
            break;
            
        case 4051:
            // ERR_INVALID_FUNCTION_PARAMVALUE - Invalid function parameter value
            result.errorMessage = "Invalid parameter (4051) for object: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectCreateError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   Check object type, coordinates, and parameters");
            #endif
            break;
            
        case 4202:
            // ERR_OBJECT_COORDINATES_ERROR - Object coordinates error
            result.errorMessage = "Invalid coordinates (4202) for object: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectCreateError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            #endif
            break;
            
        case 4203:
            // ERR_NO_SPECIFIED_SUBWINDOW - No specified subwindow
            result.errorMessage = "No subwindow (4203) for object: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectCreateError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            #endif
            break;
            
        default:
            result.errorMessage = "Unknown error (" + IntegerToString(result.errorCode) + ") for object: " + objectName;
            result.shouldRetry = false;
            result.shouldRemoveFromCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectCreateError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            #endif
            break;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle ObjectFind Error                                          |
//| مدیریت خطای ObjectFind                                           |
//+------------------------------------------------------------------+
struct ObjectFindErrorResult {
    bool objectExists;
    bool shouldRebuildCache;
    string errorMessage;
    int errorCode;
};

ObjectFindErrorResult HandleObjectFindError(const string objectName, const string context = "") {
    ObjectFindErrorResult result;
    result.objectExists = false;
    result.shouldRebuildCache = false;
    result.errorMessage = "";
    result.errorCode = GetLastError();
    
    switch(result.errorCode) {
        case 0:
            // No error - object not found (normal case)
            result.errorMessage = "Object not found: " + objectName;
            result.objectExists = false;
            result.shouldRebuildCache = false;
            break;
            
        case 4014:
            // ERR_UNKNOWN_COMMAND - Unknown command
            result.errorMessage = "Unknown command (4014) in ObjectFind";
            result.objectExists = false;
            result.shouldRebuildCache = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectFindError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            #endif
            break;
            
        default:
            result.errorMessage = "Unknown error (" + IntegerToString(result.errorCode) + ") in ObjectFind";
            result.objectExists = false;
            result.shouldRebuildCache = false;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ HandleObjectFindError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            #endif
            break;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle ObjectSet Error                                           |
//| مدیریت خطای ObjectSet                                            |
//+------------------------------------------------------------------+
struct ObjectSetErrorResult {
    bool shouldRemoveFromCache;
    bool shouldSkipUpdate;
    string errorMessage;
    int errorCode;
};

ObjectSetErrorResult HandleObjectSetError(const string objectName, const string propertyName, const string context = "") {
    ObjectSetErrorResult result;
    result.shouldRemoveFromCache = false;
    result.shouldSkipUpdate = false;
    result.errorMessage = "";
    result.errorCode = GetLastError();
    
    switch(result.errorCode) {
        case 0:
            // No error
            result.errorMessage = "Success";
            break;
            
        case 4200:
            // ERR_OBJECT_DOES_NOT_EXIST - Object was deleted externally
            result.errorMessage = "Object deleted externally: " + objectName;
            result.shouldRemoveFromCache = true;
            result.shouldSkipUpdate = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ HandleObjectSetError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   Property: ", propertyName);
            Print("   Object will be removed from cache");
            #endif
            break;
            
        case 4014:
            // ERR_UNKNOWN_COMMAND - Unknown command
            result.errorMessage = "Unknown command (4014) in ObjectSet";
            result.shouldRemoveFromCache = false;
            result.shouldSkipUpdate = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectSetError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   Property: ", propertyName);
            #endif
            break;
            
        case 4051:
            // ERR_INVALID_FUNCTION_PARAMVALUE - Invalid parameter
            result.errorMessage = "Invalid parameter (4051) for property: " + propertyName;
            result.shouldRemoveFromCache = false;
            result.shouldSkipUpdate = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ HandleObjectSetError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   Object: ", objectName);
            #endif
            break;
            
        default:
            result.errorMessage = "Unknown error (" + IntegerToString(result.errorCode) + ") in ObjectSet";
            result.shouldRemoveFromCache = false;
            result.shouldSkipUpdate = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ HandleObjectSetError: ", result.errorMessage,
                  (StringLen(context) > 0) ? " in " + context : "");
            Print("   Object: ", objectName, ", Property: ", propertyName);
            #endif
            break;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| TASK 15.3: CACHE ERROR HANDLING                                  |
//| Requirements: 11.5                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Cache Error Types                                                |
//+------------------------------------------------------------------+
enum ENUM_CACHE_ERROR {
    CACHE_ERROR_NONE = 0,
    CACHE_ERROR_OVERFLOW = 1,
    CACHE_ERROR_CORRUPTION = 2,
    CACHE_ERROR_INVALIDATION = 3,
    CACHE_ERROR_ENTRY_NOT_FOUND = 4,
    CACHE_ERROR_DUPLICATE_ENTRY = 5
};

//+------------------------------------------------------------------+
//| Cache Error Result Structure                                     |
//+------------------------------------------------------------------+
struct CacheErrorResult {
    ENUM_CACHE_ERROR errorType;
    bool shouldRebuild;
    bool shouldRemoveEntry;
    string errorMessage;
    string objectName;
};

//+------------------------------------------------------------------+
//| Handle Cache Overflow                                            |
//| مدیریت سرریز کش                                                  |
//| Requirement 11.5: Handle cache overflow                          |
//+------------------------------------------------------------------+
CacheErrorResult HandleCacheOverflow(int currentSize, int maxSize) {
    CacheErrorResult result;
    result.errorType = CACHE_ERROR_OVERFLOW;
    result.shouldRebuild = true;
    result.shouldRemoveEntry = false;
    result.errorMessage = "Cache overflow: " + IntegerToString(currentSize) + " >= " + IntegerToString(maxSize);
    result.objectName = "";
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ HandleCacheOverflow: ", result.errorMessage);
    Print("   Triggering cache rebuild to clean up stale entries");
    #endif
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle Cache Corruption                                          |
//| مدیریت خرابی کش                                                  |
//| Requirement 11.5: Handle cache corruption                        |
//+------------------------------------------------------------------+
CacheErrorResult HandleCacheCorruption(const string objectName, const string reason) {
    CacheErrorResult result;
    result.errorType = CACHE_ERROR_CORRUPTION;
    result.shouldRebuild = false;
    result.shouldRemoveEntry = true;
    result.errorMessage = "Cache corruption for object: " + objectName + " - " + reason;
    result.objectName = objectName;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ HandleCacheCorruption: ", result.errorMessage);
    Print("   Removing corrupted entry from cache");
    #endif
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle Cache Invalidation                                        |
//| مدیریت بی‌اعتبارسازی کش                                          |
//| Requirement 11.5: Handle cache invalidation                      |
//+------------------------------------------------------------------+
CacheErrorResult HandleCacheInvalidation(const string reason) {
    CacheErrorResult result;
    result.errorType = CACHE_ERROR_INVALIDATION;
    result.shouldRebuild = true;
    result.shouldRemoveEntry = false;
    result.errorMessage = "Cache invalidation: " + reason;
    result.objectName = "";
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("ℹ️ HandleCacheInvalidation: ", result.errorMessage);
    Print("   Rebuilding cache from chart objects");
    #endif
    
    return result;
}

//+------------------------------------------------------------------+
//| Validate Cache Entry                                             |
//| اعتبارسنجی ورودی کش                                              |
//+------------------------------------------------------------------+
bool ValidateCacheEntry(const string name, const double price, const color clr) {
    // Validate name
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCacheEntry: Empty name");
        #endif
        return false;
    }
    
    // Validate price (allow zero for labels)
    if(price < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCacheEntry: Negative price for ", name);
        #endif
        return false;
    }
    
    // Validate color (clrNONE is valid)
    if(clr != clrNONE && clr > 0x00FFFFFF) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ValidateCacheEntry: Invalid color for ", name);
        #endif
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| TASK 15.4: STATE MANAGEMENT ERROR HANDLING                       |
//| Requirements: 7.4                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Handle Corrupted GlobalVariable                                  |
//| مدیریت متغیر سراسری خراب                                         |
//| Requirement 7.4: Handle corrupted GlobalVariable values          |
//+------------------------------------------------------------------+
struct GlobalVariableErrorResult {
    bool isValid;
    double correctedValue;
    bool shouldReset;
    string errorMessage;
};

GlobalVariableErrorResult HandleGlobalVariableError(const string varName, double value, 
                                                     double minValue, double maxValue,
                                                     double defaultValue) {
    GlobalVariableErrorResult result;
    result.isValid = true;
    result.correctedValue = value;
    result.shouldReset = false;
    result.errorMessage = "";
    
    // Check for NaN or invalid value
    if(value != value || value == EMPTY_VALUE) {
        result.isValid = false;
        result.correctedValue = defaultValue;
        result.shouldReset = true;
        result.errorMessage = "GlobalVariable '" + varName + "' is NaN or EMPTY_VALUE";
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ HandleGlobalVariableError: ", result.errorMessage);
        Print("   Resetting to default: ", defaultValue);
        #endif
        
        return result;
    }
    
    // Check for out of range
    if(value < minValue || value > maxValue) {
        result.isValid = false;
        result.correctedValue = defaultValue;
        result.shouldReset = true;
        result.errorMessage = "GlobalVariable '" + varName + "' out of range: " + 
                             DoubleToString(value, 2) + " (valid: " + 
                             DoubleToString(minValue, 2) + "-" + DoubleToString(maxValue, 2) + ")";
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ HandleGlobalVariableError: ", result.errorMessage);
        Print("   Resetting to default: ", defaultValue);
        #endif
        
        return result;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle Missing GlobalVariable                                    |
//| مدیریت متغیر سراسری گمشده                                        |
//| Requirement 7.4: Handle missing GlobalVariables                  |
//+------------------------------------------------------------------+
GlobalVariableErrorResult HandleMissingGlobalVariable(const string varName, double defaultValue) {
    GlobalVariableErrorResult result;
    result.isValid = false;
    result.correctedValue = defaultValue;
    result.shouldReset = true;
    result.errorMessage = "GlobalVariable '" + varName + "' not found";
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ HandleMissingGlobalVariable: ", result.errorMessage);
    Print("   Initializing with default: ", defaultValue);
    #endif
    
    return result;
}

//+------------------------------------------------------------------+
//| Handle Drag Flag Stuck                                           |
//| مدیریت پرچم درگ گیر کرده                                         |
//| Requirement 7.4: Handle drag flag stuck true                     |
//+------------------------------------------------------------------+
struct DragFlagErrorResult {
    bool shouldReset;
    bool shouldTriggerCleanup;
    string errorMessage;
    datetime stuckSince;
};

DragFlagErrorResult HandleDragFlagStuck(bool dragFlag, datetime lastDragTime, 
                                        datetime currentTime, int timeoutSeconds = 5) {
    DragFlagErrorResult result;
    result.shouldReset = false;
    result.shouldTriggerCleanup = false;
    result.errorMessage = "";
    result.stuckSince = lastDragTime;
    
    // Only check if flag is true
    if(!dragFlag) {
        return result;
    }
    
    // Check if stuck (flag true for more than timeout)
    int elapsedSeconds = (int)(currentTime - lastDragTime);
    
    if(elapsedSeconds > timeoutSeconds) {
        result.shouldReset = true;
        result.shouldTriggerCleanup = true;
        result.errorMessage = "Drag flag stuck true for " + IntegerToString(elapsedSeconds) + " seconds";
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ HandleDragFlagStuck: ", result.errorMessage);
        Print("   Auto-resetting flag and triggering cleanup");
        Print("   Last drag time: ", TimeToString(lastDragTime));
        Print("   Current time: ", TimeToString(currentTime));
        #endif
    }
    
    return result;
}
