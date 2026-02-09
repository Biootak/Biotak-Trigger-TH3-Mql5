//+------------------------------------------------------------------+
//|                                        FloatingPointHelper.mqh   |
//|                     Floating-Point Precision & Comparison Helpers|
//|                     کمک‌کننده‌های دقت و مقایسه اعشاری             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| EPSILON CONSTANTS - For Different Data Types                     |
//| ✅ FIXED: Dynamic epsilon scaling based on magnitude             |
//+------------------------------------------------------------------+
#define EPSILON_BASE 1e-10              // Base epsilon for small numbers
#define EPSILON_PERCENTAGE 1e-10        // For percentage comparisons
#define EPSILON_RATIO 1e-8              // For ratio comparisons
#define EPSILON_ANGLE 1e-6              // For angle comparisons
#define EPSILON_GENERAL 1e-9            // General purpose

// Dynamic epsilon for price (scales with magnitude)
#define EPSILON_PRICE_SCALE 1e-8        // 0.01 pips for typical forex

double GetDynamicEpsilonForPrice(double price) {
    // Scale epsilon based on price magnitude
    // For XAUUSD (2600): epsilon = 2600 * 1e-8 = 0.000026 (0.26 pips)
    // For EURUSD (1.08): epsilon = 1.08 * 1e-8 = 0.0000000108 (0.00011 pips)
    double epsilon = MathAbs(price) * EPSILON_PRICE_SCALE;
    
    // Minimum epsilon to avoid zero
    if(epsilon < EPSILON_BASE) epsilon = EPSILON_BASE;
    
    return epsilon;
}

// Backward compatibility
#define EPSILON_PRICE EPSILON_BASE

//+------------------------------------------------------------------+
//| Safe Floating-Point Comparison Functions                         |
//| توابع مقایسه امن اعشاری                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if value is effectively zero                               |
//| بررسی صفر بودن مقدار                                             |
//+------------------------------------------------------------------+
bool IsZero(double value, double epsilon = EPSILON_GENERAL)
{
    return MathAbs(value) < epsilon;
}

//+------------------------------------------------------------------+
//| Check if two values are effectively equal                        |
//| بررسی برابری دو مقدار                                            |
//+------------------------------------------------------------------+
bool AreEqual(double value1, double value2, double epsilon = EPSILON_GENERAL)
{
    return MathAbs(value1 - value2) < epsilon;
}

//+------------------------------------------------------------------+
//| Check if value1 > value2 (with epsilon tolerance)               |
//| بررسی بزرگتر بودن                                                |
//+------------------------------------------------------------------+
bool IsGreater(double value1, double value2, double epsilon = EPSILON_GENERAL)
{
    return (value1 - value2) > epsilon;
}

//+------------------------------------------------------------------+
//| Check if value1 < value2 (with epsilon tolerance)               |
//| بررسی کوچکتر بودن                                                |
//+------------------------------------------------------------------+
bool IsLess(double value1, double value2, double epsilon = EPSILON_GENERAL)
{
    return (value2 - value1) > epsilon;
}

//+------------------------------------------------------------------+
//| Check if value1 >= value2 (with epsilon tolerance)              |
//| بررسی بزرگتر یا مساوی بودن                                       |
//+------------------------------------------------------------------+
bool IsGreaterOrEqual(double value1, double value2, double epsilon = EPSILON_GENERAL)
{
    return (value1 - value2) > -epsilon;
}

//+------------------------------------------------------------------+
//| Check if value1 <= value2 (with epsilon tolerance)              |
//| بررسی کوچکتر یا مساوی بودن                                       |
//+------------------------------------------------------------------+
bool IsLessOrEqual(double value1, double value2, double epsilon = EPSILON_GENERAL)
{
    return (value2 - value1) > -epsilon;
}

//+------------------------------------------------------------------+
//| Safe Division with Zero Check                                    |
//| تقسیم امن با بررسی صفر                                           |
//+------------------------------------------------------------------+
double SafeDivide(double numerator, double denominator, double defaultValue = 0.0, double epsilon = EPSILON_GENERAL)
{
    if(IsZero(denominator, epsilon)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ SafeDivide: Division by zero avoided (denominator=", 
              DoubleToString(denominator, 10), ")");
        #endif
        return defaultValue;
    }
    
    return numerator / denominator;
}

//+------------------------------------------------------------------+
//| Safe Square Root with Negative Check                             |
//| جذر امن با بررسی منفی                                            |
//+------------------------------------------------------------------+
double SafeSqrt(double value, double defaultValue = 0.0, double epsilon = EPSILON_GENERAL)
{
    if(value < -epsilon) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ SafeSqrt: Negative value (", DoubleToString(value, 10), 
              "), returning default: ", defaultValue);
        #endif
        return defaultValue;
    }
    
    // Treat small negative values as zero (floating-point errors)
    if(value < 0 && value > -epsilon) {
        value = 0;
    }
    
    return MathSqrt(value);
}

//+------------------------------------------------------------------+
//| Clamp Value to Range                                             |
//| محدود کردن مقدار به بازه                                         |
//+------------------------------------------------------------------+
double ClampValue(double value, double minVal, double maxVal)
{
    if(value < minVal) return minVal;
    if(value > maxVal) return maxVal;
    return value;
}

//+------------------------------------------------------------------+
//| Normalize Price to Symbol Digits                                 |
//| نرمال‌سازی قیمت به تعداد ارقام سیمبل                             |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
    return NormalizeDouble(price, Digits);
}

//+------------------------------------------------------------------+
//| Check if Price is Valid                                          |
//| بررسی معتبر بودن قیمت                                            |
//+------------------------------------------------------------------+
bool IsValidPrice(double price, double epsilon = EPSILON_PRICE)
{
    // Price must be positive and not too large
    if(price < epsilon) return false;
    if(price > 1000000000.0) return false; // 1 billion
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if Percentage is Valid                                     |
//| بررسی معتبر بودن درصد                                            |
//+------------------------------------------------------------------+
bool IsValidPercentage(double percentage, double minPercent = 0.0, double maxPercent = 100.0)
{
    if(percentage < minPercent - EPSILON_PERCENTAGE) return false;
    if(percentage > maxPercent + EPSILON_PERCENTAGE) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if Ratio is Valid                                          |
//| بررسی معتبر بودن نسبت                                            |
//+------------------------------------------------------------------+
bool IsValidRatio(double ratio, double minRatio = 0.0, double maxRatio = 10.0)
{
    if(ratio < minRatio - EPSILON_RATIO) return false;
    if(ratio > maxRatio + EPSILON_RATIO) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Safe Percentage Calculation                                      |
//| محاسبه امن درصد                                                  |
//+------------------------------------------------------------------+
double CalculatePercentage(double part, double whole, double defaultValue = 0.0)
{
    if(IsZero(whole, EPSILON_GENERAL)) {
        return defaultValue;
    }
    
    return (part / whole) * 100.0;
}

//+------------------------------------------------------------------+
//| Safe Ratio Calculation                                           |
//| محاسبه امن نسبت                                                  |
//+------------------------------------------------------------------+
double CalculateRatio(double numerator, double denominator, double defaultValue = 1.0)
{
    if(IsZero(denominator, EPSILON_GENERAL)) {
        return defaultValue;
    }
    
    return numerator / denominator;
}

//+------------------------------------------------------------------+
//| Round to Nearest Pip                                             |
//| گرد کردن به نزدیک‌ترین پیپ                                       |
//+------------------------------------------------------------------+
double RoundToPip(double value)
{
    double pipSize = (Digits == 3 || Digits == 5) ? Point * 10 : Point;
    
    if(IsZero(pipSize, EPSILON_GENERAL)) {
        return value; // Cannot round
    }
    
    return MathRound(value / pipSize) * pipSize;
}

//+------------------------------------------------------------------+
//| Check if value is within range (inclusive)                       |
//| بررسی قرار گرفتن مقدار در بازه                                   |
//+------------------------------------------------------------------+
bool IsInRange(double value, double minVal, double maxVal, double epsilon = EPSILON_GENERAL)
{
    return IsGreaterOrEqual(value, minVal, epsilon) && 
           IsLessOrEqual(value, maxVal, epsilon);
}

//+------------------------------------------------------------------+
//| Linear Interpolation (Lerp)                                      |
//| درون‌یابی خطی                                                     |
//+------------------------------------------------------------------+
double Lerp(double start, double end, double t)
{
    // Clamp t to [0, 1]
    t = ClampValue(t, 0.0, 1.0);
    
    return start + (end - start) * t;
}

//+------------------------------------------------------------------+
//| Inverse Linear Interpolation                                     |
//| درون‌یابی خطی معکوس                                              |
//+------------------------------------------------------------------+
double InverseLerp(double start, double end, double value)
{
    if(IsZero(end - start, EPSILON_GENERAL)) {
        return 0.0;
    }
    
    return ClampValue((value - start) / (end - start), 0.0, 1.0);
}

//+------------------------------------------------------------------+
//| Map value from one range to another                              |
//| نگاشت مقدار از یک بازه به بازه دیگر                              |
//+------------------------------------------------------------------+
double MapRange(double value, double fromMin, double fromMax, double toMin, double toMax)
{
    // Get normalized position in source range
    double t = InverseLerp(fromMin, fromMax, value);
    
    // Map to target range
    return Lerp(toMin, toMax, t);
}

//+------------------------------------------------------------------+
//| Test Floating-Point Helper Functions                             |
//| تست توابع کمکی اعشاری                                            |
//+------------------------------------------------------------------+
void TestFloatingPointHelper()
{
    #ifdef ENABLE_DEBUG_LOGS
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║  FLOATING-POINT HELPER TESTS                                  ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
    
    // Test 1: IsZero
    bool test1 = IsZero(0.0000000001, EPSILON_GENERAL);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 1 (IsZero): ", test1 ? "PASS" : "FAIL");
    #endif
    
    // Test 2: AreEqual
    bool test2 = AreEqual(1.0000000001, 1.0, EPSILON_GENERAL);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 2 (AreEqual): ", test2 ? "PASS" : "FAIL");
    #endif
    
    // Test 3: SafeDivide
    double test3 = SafeDivide(10.0, 0.0, 999.0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 3 (SafeDivide): ", (test3 == 999.0) ? "PASS" : "FAIL");
    #endif
    
    // Test 4: SafeSqrt
    double test4 = SafeSqrt(-1.0, 0.0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 4 (SafeSqrt): ", (test4 == 0.0) ? "PASS" : "FAIL");
    #endif
    
    // Test 5: ClampValue
    double test5 = ClampValue(150.0, 0.0, 100.0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 5 (ClampValue): ", (test5 == 100.0) ? "PASS" : "FAIL");
    #endif
    
    // Test 6: MapRange
    double test6 = MapRange(50.0, 0.0, 100.0, 0.0, 1.0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Test 6 (MapRange): ", AreEqual(test6, 0.5, EPSILON_GENERAL) ? "PASS" : "FAIL");
    #endif
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("╚═══════════════════════════════════════════════════════════════╝");
    #endif
}
