#ifndef PROJECT_CONSTANTS_MQH
#define PROJECT_CONSTANTS_MQH

#property copyright " Biotak"

// Transparency
const int MIN_TRANSPARENCY_PERCENT = 0;
const int MAX_TRANSPARENCY_PERCENT = 100;
const int DEFAULT_TRANSPARENCY_PERCENT = 50;

// Zone Height
const double MIN_ZONE_HEIGHT_PERCENT = 0.01;
const double MAX_ZONE_HEIGHT_PERCENT = 1.0;
const double DEFAULT_ZONE_HEIGHT_PERCENT = 0.125;

// Multipliers
const int ZONE_EXTENSION_MULTIPLIER = 100;
const int ALPHA_SCALE_FACTOR = 255;
const int PERCENTAGE_TO_DECIMAL = 100;

// Performance
const int CACHE_LOG_INTERVAL = 100;
const int ZONE_EXTENSION_PERIODS = 100;
const int MAX_ZONES_PER_CHART = 500;
const int OBJECT_CACHE_SIZE = 1000;

// Limits
const int MAX_MOVEMENT_CANDLES = 10000;
const int MAX_REST_CANDLES = 1000;
const int MAX_LEARNING_DATA_SIZE = 10000;
const double MAX_PRICE_DEVIATION = 2.0;
const double MAX_ZONE_HEIGHT_PERCENT_LIMIT = 1.0;

// Frequency
const int FREQUENCY_BASE = 100;
const double FREQUENCY_STEP_3 = 33.333;
const double FREQUENCY_STEP_5 = 20.0;
const double FREQUENCY_STEP_7 = 14.286;

// Consolidation Thresholds
const double CONSOLIDATION_VERY_LOW = 0.6;
const double CONSOLIDATION_LOW = 1.0;
const double CONSOLIDATION_MEDIUM = 1.5;

// Pattern Detection
const double GANN_ANGLE_STRONG_IMPULSIVE = 75.0;
const double GANN_ANGLE_MEDIUM_IMPULSIVE = 50.0;
const double CONSOLIDATION_IMPULSIVE_MAX = 0.1;
const double TIME_SYMMETRY_GOOD = 0.8;

// Sizing
const int TEST_ARRAY_SIZE = 100;
const int TEST_OVERFLOW_COUNT = 100;
const int LABEL_OFFSET_MAX_PIPS = 100;
const int PATTERN_BARS_PADDING = 100;

// Time
const int SECONDS_PER_MINUTE = 60;
const int SECONDS_PER_HOUR = 3600;
const int SECONDS_PER_DAY = 86400;
const int SECONDS_PER_MONTH = 2592000;
const int MUTEX_STALE_TIMEOUT_SECONDS = 2;
const int MUTEX_RETRY_ATTEMPTS = 10;
const int MUTEX_RETRY_DELAY_MS = 10;

// Array Sizes
const int DEFAULT_ARRAY_SIZE = 10;
const int SMALL_ARRAY_SIZE = 50;
const int MEDIUM_ARRAY_SIZE = 100;
const int LARGE_ARRAY_SIZE = 500;

// Validation
const double MIN_PRICE_VALUE = 0.00001;
const double MAX_PRICE_MULTIPLIER = 1000000.0;
const int MIN_BARS_REQUIRED = 1;
const int MAX_BARS_LOOKBACK = 10000;

// Error Codes (simple)
const int ERROR_CODE_SUCCESS = 0;
const int ERROR_CODE_INVALID_INPUT = -1;
const int ERROR_CODE_MEMORY_LIMIT = -2;
const int ERROR_CODE_FILE_OPERATION = -3;
const int ERROR_CODE_STATE_CONFLICT = -4;
const int ERROR_CODE_OVERFLOW = -5;

// Helper Functions
double PercentToDecimal(double percent) {
        return percent / PERCENTAGE_TO_DECIMAL;
}
    double DecimalToPercent(double decimal) {
        return decimal * PERCENTAGE_TO_DECIMAL;
}
    int TransparencyToAlpha(int transparency) {
        if(transparency < MIN_TRANSPARENCY_PERCENT) transparency = MIN_TRANSPARENCY_PERCENT;
    if(transparency > MAX_TRANSPARENCY_PERCENT) transparency = MAX_TRANSPARENCY_PERCENT;
    return (int)((MAX_TRANSPARENCY_PERCENT - transparency) * ALPHA_SCALE_FACTOR / PERCENTAGE_TO_DECIMAL);
}
    bool IsValidTransparency(int transparency) {
    return (transparency >= MIN_TRANSPARENCY_PERCENT && transparency <= MAX_TRANSPARENCY_PERCENT);
}
    bool IsValidZoneHeightPercent(double heightPercent) {
    return (heightPercent >= MIN_ZONE_HEIGHT_PERCENT && heightPercent <= MAX_ZONE_HEIGHT_PERCENT);
}
    double GetFrequencyForStep(int step) {
        if(step <= 0) return 0.0;
    return (double)FREQUENCY_BASE / step;
}
    bool IsValidPriceSimple(double price) {
    return (price >= MIN_PRICE_VALUE && price < MAX_PRICE_MULTIPLIER);
}
    void PrintConstantsSummary() {
        #ifdef ENABLE_DEBUG_LOGS
    Print("=== PROJECT CONSTANTS ===");
    Print("Transparency: ", MIN_TRANSPARENCY_PERCENT, "-", MAX_TRANSPARENCY_PERCENT, "%");
    Print("Zone Height: ", DoubleToString(MIN_ZONE_HEIGHT_PERCENT * 100, 2), "-",
          DoubleToString(MAX_ZONE_HEIGHT_PERCENT * 100, 2), "%");
    Print("Max Zones: ", MAX_ZONES_PER_CHART);
    #endif
    }
    #endif
    // PROJECT_CONSTANTS_MQH