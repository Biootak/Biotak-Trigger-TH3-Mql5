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

// TH3 Frequency Array (76 discrete frequencies: base n/32 + geometric means)
const int TH3_FREQUENCY_COUNT = 76;
const int DEFAULT_TH3_FREQ_INDEX = 16; // 28.125% (index 16)
const double TH3_TEST_FREQUENCIES[] = {
    // Original range: 3.125% to 100% (63 frequencies)
    3.125,   // 1/32
    4.419,   // √(3.125 × 6.25)
    6.25,    // 2/32
    7.629,   // √(6.25 × 9.375)
    9.375,   // 3/32
    10.825,  // √(9.375 × 12.5)
    12.5,    // 4/32
    13.975,  // √(12.5 × 15.625)
    15.625,  // 5/32
    17.089,  // √(15.625 × 18.75)
    18.75,   // 6/32
    20.176,  // √(18.75 × 21.875)
    21.875,  // 7/32
    23.242,  // √(21.875 × 25)
    25.0,    // 8/32 - Quarter 1
    26.491,  // √(25 × 28.125)
    28.125,  // 9/32 - DEFAULT (index 16)
    29.619,  // √(28.125 × 31.25)
    31.25,   // 10/32
    32.795,  // √(31.25 × 34.375)
    34.375,  // 11/32
    35.951,  // √(34.375 × 37.5)
    37.5,    // 12/32
    39.063,  // √(37.5 × 40.625)
    40.625,  // 13/32
    42.157,  // √(40.625 × 43.75)
    43.75,   // 14/32
    45.234,  // √(43.75 × 46.875)
    46.875,  // 15/32
    48.295,  // √(46.875 × 50)
    50.0,    // 16/32 - MIDPOINT
    51.705,  // √(50 × 53.125)
    53.125,  // 17/32
    54.766,  // √(53.125 × 56.25)
    56.25,   // 18/32
    57.843,  // √(56.25 × 59.375)
    59.375,  // 19/32
    60.937,  // √(59.375 × 62.5)
    62.5,    // 20/32
    64.049,  // √(62.5 × 65.625)
    65.625,  // 21/32
    67.187,  // √(65.625 × 68.75)
    68.75,   // 22/32
    70.205,  // √(68.75 × 71.875)
    71.875,  // 23/32
    73.381,  // √(71.875 × 75)
    75.0,    // 24/32 - Quarter 3
    76.509,  // √(75 × 78.125)
    78.125,  // 25/32
    79.658,  // √(78.125 × 81.25)
    81.25,   // 26/32
    82.795,  // √(81.25 × 84.375)
    84.375,  // 27/32
    85.911,  // √(84.375 × 87.5)
    87.5,    // 28/32
    89.024,  // √(87.5 × 90.625)
    90.625,  // 29/32
    92.157,  // √(90.625 × 93.75)
    93.75,   // 30/32
    95.299,  // √(93.75 × 96.875)
    96.875,  // 31/32
    98.425,  // √(96.875 × 100)
    100.0,   // 32/32 - Full range
    // Extended range: 100% to 120% (13 additional frequencies)
    101.491, // √(100 × 103.125)
    103.125, // 33/32
    105.176, // √(103.125 × 106.25)
    106.25,  // 34/32
    107.795, // √(106.25 × 109.375)
    109.375, // 35/32
    110.825, // √(109.375 × 112.5)
    112.5,   // 36/32
    114.024, // √(112.5 × 115.625)
    115.625, // 37/32
    117.176, // √(115.625 × 118.75)
    118.75,  // 38/32
    120.0    // Extended maximum
};

// UI Timing (milliseconds)
const uint DOUBLE_CLICK_THRESHOLD_MS = 300;
const uint CHART_CHANGE_THROTTLE_MS = 250;

// Hotkey Defaults
const double DEFAULT_FACTOR_ADJUST_STEP = 0.1;
const double DEFAULT_TH3_FREQ_ADJUST_STEP = 1.0; // Legacy (kept for compatibility)

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