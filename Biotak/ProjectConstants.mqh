#ifndef PROJECT_CONSTANTS_MQH
#define PROJECT_CONSTANTS_MQH

#property copyright " Biotak"

// Factor Limits
const double MIN_FACTOR_VALUE = 0.01;
const double MAX_FACTOR_VALUE = 10000.0;
const double DEFAULT_FACTOR_FALLBACK = 50.0;

// TH3 Frequency Limits
const double MIN_TH3_FREQUENCY = 0.1;
const double MAX_TH3_FREQUENCY = 1000.0;

// UI Timing (milliseconds)
const uint DOUBLE_CLICK_THRESHOLD_MS = 300;
const uint CHART_CHANGE_THROTTLE_MS = 250;

// Hotkey Defaults
const double DEFAULT_FACTOR_ADJUST_STEP = 0.1;
const double DEFAULT_TH3_FREQ_ADJUST_STEP = 1.0;

// Zone Height
const double MIN_ZONE_HEIGHT_PERCENT = 0.01;
const double MAX_ZONE_HEIGHT_PERCENT = 1.0;
const double DEFAULT_ZONE_HEIGHT_PERCENT = 0.125;

// Multipliers
const int ZONE_EXTENSION_MULTIPLIER = 100;
const int PERCENTAGE_TO_DECIMAL = 100;

// Time
const int SECONDS_PER_MINUTE = 60;
const int SECONDS_PER_HOUR = 3600;
const int SECONDS_PER_DAY = 86400;

#endif
    // PROJECT_CONSTANTS_MQH