//+------------------------------------------------------------------+
//|                                           THCalculations.mqh     |
//+------------------------------------------------------------------+
#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"

//+------------------------------------------------------------------+
//| DEPRECATED: These functions are kept for backward compatibility  |
//| Use simple multipliers instead:                                  |
//| - Short Step (SS) = structureTH * 1.5                           |
//| - Long Step (LS) = structureTH * 2.0                            |
//|                                                                  |
//| Note: When Pattern = 0.5 * Structure, the structural formulas   |
//| simplify to the same result as simple multipliers:              |
//| - SS = (2*S) - P = (2*S) - (0.5*S) = 1.5*S                     |
//| - LS = (3*S) - (2*P) = (3*S) - (2*0.5*S) = 2.0*S              |
//+------------------------------------------------------------------+

// Deprecated functions removed - use simple multipliers instead:
// - Short Step (SS) = structureTH * 1.5
// - Long Step (LS) = structureTH * 2.0

// GOLD FIX #3: Enhanced epsilon-based validation with proper floating-point comparison
// Note: EPSILON constants are defined in FloatingPointHelper.mqh
#ifndef MAX_SAFE_PRICE
#define MAX_SAFE_PRICE 1000000.0
#endif
#ifndef MAX_SAFE_PERCENTAGE
#define MAX_SAFE_PERCENTAGE 1000.0
#endif

double CalculateTH(const double price, const int digits, const double percentage) {
    // CRITICAL FIX: Use epsilon for floating-point comparison
    if(price < EPSILON_PRICE || percentage < EPSILON_PERCENTAGE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTH: Invalid input - price=", DoubleToString(price, 10), 
              ", percentage=", DoubleToString(percentage, 10));
        #endif
        return 0;
    }
    
    // SECURITY: Prevent overflow with proper bounds
    if(price > MAX_SAFE_PRICE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTH: Price too large (", DoubleToString(price, 5), "), exceeds MAX_SAFE_PRICE");
        #endif
        return 0;
    }
    
    // VALIDATION: Digits range check
    if(digits < 0 || digits > 8) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTH: Invalid digits (", digits, "), must be 0-8");
        #endif
        return 0;
    }
    
    // VALIDATION: Percentage range with hard limit
    if(percentage > MAX_SAFE_PERCENTAGE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTH: Percentage too large (", DoubleToString(percentage, 3), 
              "%), exceeds MAX_SAFE_PERCENTAGE");
        #endif
        return 0;
    }
    
    // GOLD FIX: Enhanced cache with epsilon-based comparison
    static double s_lastPrice = 0.0;
    static int s_lastDigits = -1;
    static double s_lastPercentage = 0.0;
    static double s_lastResult = 0.0;
    
    // Normalize values for comparison
    double normalizedPrice = NormalizeDouble(price, digits);
    double normalizedPercentage = NormalizeDouble(percentage, 6);
    
    // CRITICAL: Use epsilon for floating-point comparison (not ==)
    bool priceMatch = MathAbs(normalizedPrice - s_lastPrice) < EPSILON_PRICE;
    bool percentageMatch = MathAbs(normalizedPercentage - s_lastPercentage) < EPSILON_PERCENTAGE;
    bool digitsMatch = (digits == s_lastDigits);
    
    if(priceMatch && percentageMatch && digitsMatch) {
        #ifdef ENABLE_DEBUG_LOGS
        static int s_cacheHits = 0;
        s_cacheHits++;
        if(s_cacheHits % 100 == 0) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CalculateTH: Cache hit #", s_cacheHits);
            #endif
        }
        #endif
        return s_lastResult;
    }
    
    // Cache miss - calculate and update
    s_lastPrice = normalizedPrice;
    s_lastDigits = digits;
    s_lastPercentage = normalizedPercentage;
    
    // Formula matching MotiveWave EXACTLY:
    // thStepPriceUnits = (basePrice * percentage) / 100.0
    s_lastResult = (normalizedPrice * normalizedPercentage) / 100.0;
    return s_lastResult;
}

double CalculateTHPoints(const double price, const int digits, const double percentage) {
    if(price <= 0 || percentage <= 0) return 0;
    
    // CRITICAL FIX: Use IsZero for float comparison instead of == 0.0
    static double s_pointValue = 0.0;
    if(IsZero(s_pointValue, EPSILON_PRICE)) s_pointValue = GetSymbolPoint();
    if(IsZero(s_pointValue, EPSILON_PRICE)) return 0;
    
    // محاسبه با دقت کامل (بدون NormalizeDouble برای تطابق با MotiveWave)
    double thStepPriceUnits = (price * percentage) / 100.0;
    return thStepPriceUnits <= 0 ? 0 : (thStepPriceUnits / s_pointValue);
}

// Cache timeframe TH calculations
static string s_lastTimeframe = "";
static double s_lastTimeframeTH = 0.0;

double GetTimeframeTH() {
    return CalculateTimeframeTH(GetFractalTimeframeForCurrent());
}

double CalculateTimeframeTH(const string timeframe) {
    if(timeframe == s_lastTimeframe)
        return s_lastTimeframeTH;
        
    s_lastTimeframe = timeframe;
    int totalTimeframes = ArraySize(FRACTAL_TIMEFRAMES);
    
    // GOLD FIX: Use exact string comparison instead of StringFind
    // StringFind can cause false matches (e.g., "M1" matches "H1+M4")
    for(int i = 0; i < totalTimeframes; i++) {
        if(FRACTAL_TIMEFRAMES[i] == timeframe) {
            s_lastTimeframeTH = MODIFIED_FRACTAL_PERCENTAGES[i];
            return s_lastTimeframeTH;
        }
    }
    
    // Fallback: return 1.0% for unknown timeframes
    s_lastTimeframeTH = 1.0;
    return s_lastTimeframeTH;
}

//+------------------------------------------------------------------+
//| New calculation functions for extended step modes                |
//+------------------------------------------------------------------+

// Constants for calculations (matching MotiveWave implementation)
#define SS_MULTIPLIER 1.5      // Short Step = 1.5 * TH
#define LS_MULTIPLIER 2.0      // Long Step = 2.0 * TH
#define ATR_FACTOR 3.0         // ATR factor for M calculations

double CalculateShortStep(const double thValue) {
    return thValue * SS_MULTIPLIER;
}

double CalculateLongStep(const double thValue) {
    return thValue * LS_MULTIPLIER;
}

double CalculateEStep(const double thValue) {
    // Formula from EventHandlers.mqh: E = TH * 0.75
    return thValue * 0.75;
}

double CalculateTPStep(const double eValue) {
    // Formula from EventHandlers.mqh: TP = E * 3
    return eValue * 3.0;
}

double CalculateControlValue(const double shortStep, const double longStep) {
    // Logic deduced from typical Biotak patterns
    return shortStep;
}

// Reconstructed CalculateSharedPatternStep
double CalculateSharedPatternStep(const double currentStructure, const double currentPattern,
                                 const double higherPatternStructure, const double higherPatternPattern) {
    #ifdef ENABLE_DEBUG_LOGS
    Print("CalculateSharedPatternStep: currentS=", currentStructure, 
          ", currentP=", currentPattern, ", higherS=", higherPatternStructure, 
          ", higherP=", higherPatternPattern);
    #endif
    
    // Return current SS only as fallback
    if(currentStructure > 0 && currentPattern > 0) {
        return (2 * currentStructure) - currentPattern;  // SS formula
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Factor Step Size                                        |
//| محاسبه اندازه گام فاکتور                                          |
//| Simple Formula: Step = (High - Low) / (Factor × 2)               |
//| CRITICAL FIX: Complete overflow and division-by-zero protection  |
//+------------------------------------------------------------------+

// Cache for Factor calculations to avoid recalculation on every tick
static double s_cachedFactorHigh = 0;
static double s_cachedFactorLow = 0;
static double s_cachedFactorValue = 0;
static double s_cachedFactorStepSize = 0;
static int s_cachedFactorPeriod = 0;  // Track timeframe for cache invalidation
static int s_cachedHistoricalPeriods = -1;  // GOLD FIX v3: Track historical periods

// Tolerance for cache comparison (relative to price)
// Note: EPSILON is defined in FloatingPointHelper.mqh as EPSILON_GENERAL
#ifndef FACTOR_CACHE_TOLERANCE
#define FACTOR_CACHE_TOLERANCE 1e-9
#endif
#ifndef MAX_FACTOR_VALUE
#define MAX_FACTOR_VALUE 10000.0
#endif
#ifndef MIN_FACTOR_VALUE
#define MIN_FACTOR_VALUE 0.01
#endif

//+------------------------------------------------------------------+
//| Invalidate Factor cache (call on timeframe/range change)         |
//+------------------------------------------------------------------+
void InvalidateFactorCache() {
    s_cachedFactorHigh = 0;
    s_cachedFactorLow = 0;
    s_cachedFactorValue = 0;
    s_cachedFactorStepSize = 0;
    s_cachedFactorPeriod = 0;
}

double CalculateFactorStepSize(const double highPrice, const double lowPrice, const double factor) {
    // GOLD FIX v3: Enhanced cache invalidation with all conditions
    bool periodChanged = (s_cachedFactorPeriod != Period());
    bool historicalPeriodsChanged = (s_cachedHistoricalPeriods != inpHistoricalPeriods);
    
    if(periodChanged || historicalPeriodsChanged) {
        InvalidateFactorCache();
        s_cachedFactorPeriod = Period();
        s_cachedHistoricalPeriods = inpHistoricalPeriods;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #1: Validate prices with epsilon
    // ═══════════════════════════════════════════════════════════════
    if(highPrice < EPSILON_PRICE || lowPrice < EPSILON_PRICE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Invalid prices - High=", DoubleToString(highPrice, Digits), 
              ", Low=", DoubleToString(lowPrice, Digits));
        #endif
        return 0;
    }
    
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Invalid range - High (", DoubleToString(highPrice, Digits), 
              ") must be greater than Low (", DoubleToString(lowPrice, Digits), ")");
        #endif
        return 0;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #2: Validate range (prevent precision loss)
    // ═══════════════════════════════════════════════════════════════
    double range = highPrice - lowPrice;
    double minRange = Point * 10; // At least 10 pips
    if(range < minRange) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Range too small (", DoubleToString(range, Digits), 
              ") - minimum ", DoubleToString(minRange, Digits), " required");
        #endif
        return 0;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #3: Validate factor BEFORE any calculation
    // ═══════════════════════════════════════════════════════════════
    if(factor < MIN_FACTOR_VALUE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Factor too small (", DoubleToString(factor, 2), 
              ") - minimum ", DoubleToString(MIN_FACTOR_VALUE, 2), " required");
        #endif
        return 0;
    }
    if(factor > MAX_FACTOR_VALUE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Factor too large (", DoubleToString(factor, 2), 
              ") - maximum ", DoubleToString(MAX_FACTOR_VALUE, 2), " allowed");
        #endif
        return 0;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #4: Check for potential overflow BEFORE multiplication
    // ═══════════════════════════════════════════════════════════════
    if(factor > 1000000000.0 / 2.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Factor would cause overflow in multiplication");
        #endif
        return 0;
    }
    
    // Calculate relative tolerance based on price magnitude
    double priceTolerance = highPrice * FACTOR_CACHE_TOLERANCE;
    
    // Check cache with tolerance AND validate historical range hasn't changed
    bool rangeChanged = (MathAbs(highPrice - s_cachedFactorHigh) >= priceTolerance) || 
                        (MathAbs(lowPrice - s_cachedFactorLow) >= priceTolerance);
    
    if(!rangeChanged && 
       MathAbs(factor - s_cachedFactorValue) < 0.001 &&
       s_cachedFactorStepSize > 0) {
        return s_cachedFactorStepSize;
    }

    // ═══════════════════════════════════════════════════════════════
    // GOLD FIX v3: Enhanced safe division with proper threshold
    // ═══════════════════════════════════════════════════════════════
    double divisions = factor * 2.0;
    
    // CRITICAL: Use MIN_SAFE_DIVISIONS instead of EPSILON_GENERAL
    // EPSILON_GENERAL (1e-9) is too small and can cause precision loss
    if(divisions < MIN_SAFE_DIVISIONS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Divisions too small (", DoubleToString(divisions, 10), 
              ") - minimum required: ", DoubleToString(MIN_SAFE_DIVISIONS, 10));
        #endif
        return 0;
    }
    
    // Validate divisions result for overflow
    if(divisions > 1000000.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Invalid divisions calculated (too large): ", divisions);
        #endif
        return 0;
    }
    
    // Use SafeDivide from FloatingPointHelper for additional safety
    double stepSize = SafeDivide(range, divisions, 0.0, MIN_SAFE_DIVISIONS);
    
    // Validate SafeDivide result
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: SafeDivide returned invalid result");
        #endif
        return 0;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #6: Validate result is reasonable
    // ═══════════════════════════════════════════════════════════════
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Invalid step size result: ", stepSize);
        #endif
        return 0;
    }
    if(stepSize < Point * 0.1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Step size too small (", stepSize, ") - would create too many levels");
        #endif
        return 0;
    }
    if(stepSize > range) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFactorStepSize: Step size (", stepSize, ") exceeds range (", range, ")");
        #endif
        return 0;
    }
    
    // Cache validated values
    s_cachedFactorHigh = highPrice;
    s_cachedFactorLow = lowPrice;
    s_cachedFactorValue = factor;
    s_cachedFactorStepSize = stepSize;
    
    return s_cachedFactorStepSize;
}

//+------------------------------------------------------------------+
//| Calculate Fractal Values (Structure, Pattern, Trigger) from TH  |
//| محاسبه مقادیر فراکتال (ساختار، الگو، تریگر) از TH               |
//+------------------------------------------------------------------+
void CalculateFractalValues(const double thValue, double &structureValue, double &patternValue, double &triggerValue) {
    // In TH Basis, Structure = TH
    structureValue = thValue;
    
    // Pattern = 0.5 * Structure
    patternValue = structureValue * 0.5;
    
    // Trigger = 0.25 * Structure (half of Pattern)
    triggerValue = structureValue * 0.25;
}

//+------------------------------------------------------------------+
//| Calculate M Distance based on Control Value                      |
//| محاسبه فاصله M بر اساس مقدار کنترل                               |
//+------------------------------------------------------------------+
double CalculateMDistance(const double controlValue) {
    // M Distance is Control Value divided by ATR_FACTOR (3.0)
    // If Control Value is SS (1.5 * Structure), then M Distance = 0.5 * Structure (Pattern)
    return controlValue / ATR_FACTOR;
}
