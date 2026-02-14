#ifndef PROJECT_CONSTANTS_MQH
#define PROJECT_CONSTANTS_MQH

#property copyright " Biotak"

// Factor Limits
const double MIN_FACTOR_VALUE = 0.01;
const double MAX_FACTOR_VALUE = 10000.0;
const double DEFAULT_FACTOR_FALLBACK = 50.0;

//+------------------------------------------------------------------+
//| TH3 Binary Subdivision Frequency System                          |
//| Theory: Every real number in [0,100] has exact representation    |
//| as n/2^k × 100%. At depth=6: freq = index × (100/64) = i×1.5625 |
//| This replaces the old GM-interpolated array (22 incorrect values)|
//+------------------------------------------------------------------+
const int    BINARY_SUBDIVISION_DEPTH = 6;              // 2^6 = 64 subdivisions per 100%
const double BINARY_SUBDIVISION_STEP  = 1.5625;         // 100.0 / 64 = 1.5625% per index
const int    MIN_TH3_FREQ_INDEX       = 1;              // 1.5625% (minimum meaningful frequency)
const int    MAX_TH3_FREQ_INDEX       = 256;            // 400.0% (extended range)
const int    DEFAULT_TH3_FREQ_INDEX   = 18;             // 28.125% (18 × 1.5625 = 28.125, was index 16 in old array)

//+------------------------------------------------------------------+
//| Get frequency percentage by index — pure runtime calculation      |
//| No static array needed. freq(i) = i × 1.5625%                    |
//| Key levels: 16=25% (1/4), 32=50% (1/2), 48=75% (3/4), 64=100%  |
//+------------------------------------------------------------------+
double GetFrequencyByIndex(int index) {
    return index * BINARY_SUBDIVISION_STEP;
}

//+------------------------------------------------------------------+
//| Find nearest valid frequency index for a given percentage         |
//| Used for: migrating old saved values, syncing after manual input  |
//+------------------------------------------------------------------+
int FindNearestFreqIndex(double freqPercent) {
    if(freqPercent <= 0) return MIN_TH3_FREQ_INDEX;
    int idx = (int)MathRound(freqPercent / BINARY_SUBDIVISION_STEP);
    if(idx < MIN_TH3_FREQ_INDEX) idx = MIN_TH3_FREQ_INDEX;
    if(idx > MAX_TH3_FREQ_INDEX) idx = MAX_TH3_FREQ_INDEX;
    return idx;
}

//+------------------------------------------------------------------+
//| Get binary depth level of an index (2-adic valuation)             |
//| Returns how many times index is divisible by 2:                   |
//|   v₂(64)=6, v₂(32)=5, v₂(16)=4, v₂(8)=3, v₂(4)=2, v₂(2)=1    |
//| Higher depth = more fundamental frequency level ("louder note")  |
//+------------------------------------------------------------------+
int GetBinaryDepthLevel(int index) {
    if(index <= 0) return 0;
    int depth = 0;
    while((index & 1) == 0) {
        depth++;
        index >>= 1;
    }
    return depth;
}

//+------------------------------------------------------------------+
//| Check if index is a "clean" binary level at given depth           |
//| depth=0: all indices (64ths)                                     |
//| depth=1: even indices (32nds) — divisible by 2                   |
//| depth=2: divisible by 4 (16ths)                                  |
//| depth=3: divisible by 8 (8ths)                                   |
//| depth=4: divisible by 16 (quarters)                              |
//| depth=5: divisible by 32 (halves: 50%, 100%, ...)               |
//| depth=6: divisible by 64 (wholes: 100%, 200%)                   |
//+------------------------------------------------------------------+
bool IsCleanBinaryLevel(int index, int minDepth) {
    return GetBinaryDepthLevel(index) >= minDepth;
}

// ABCD Pattern Constants
#define ABCD_MIN_DISTANCE_POINTS 10
#define ABCD_DEBOUNCE_MS 300

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

// Frequency History — remember past pattern frequencies for coherence scoring
#define FREQ_HISTORY_SIZE 8    // Ring buffer: last 8 pattern results
#define MIN_STEP1_PIPS   2.0   // Minimum Step1 distance in pips to be meaningful

//+------------------------------------------------------------------+
//| FrequencyResult - Result of frequency optimization               |
//| Defined here (before GlobalVariables.mqh) so it can be used      |
//| as a global variable for info label display                      |
//+------------------------------------------------------------------+
struct FrequencyResult {
    int       bestIndex;          // Binary subdivision index (freq = index × 1.5625%)
    double    bestFrequency;      // The optimal frequency percentage
    double    totalScore;         // Combined score (0..1)
    double    multiStepScore;     // Multi-step resonance score (was midpointScore)
    double    patternScore;       // Harmonic pattern projection score (Gartley/Bat/etc.)
    double    timeScore;          // Gann price=time alignment score
    double    sqrtScore;          // Gann square root price harmony score
    double    harmonicScore;      // Harmonic/phase relationship score
    double    historyScore;       // Coherence with previous pattern frequencies
    double    confidence;         // Confidence level (0..1): how consistent components are
    double    step1Price;         // Step1 = C ± 1×baseUnit
    double    step3Price;         // Step3 = C ± 3×baseUnit (primary target)
    double    step5Price;         // Step5 = C ± 5×baseUnit
    double    step7Price;         // Step7 = C ± 7×baseUnit
    int       matchedSteps;       // How many steps (0-4) matched reference levels
    string    matchLabel;         // Which reference midpoint matched Step3
    string    patternType;        // Detected harmonic pattern type (e.g. "Gartley")
    int       matchWaveIndex;     // Which wave the best match belongs to
    double    errorPips;          // Distance in pips between Step3 and matched midpoint
    bool      isValid;

    void Reset() {
        bestIndex = -1; bestFrequency = 0; totalScore = 0;
        multiStepScore = 0; patternScore = 0; timeScore = 0;
        sqrtScore = 0; harmonicScore = 0; historyScore = 0; confidence = 0;
        step1Price = 0; step3Price = 0; step5Price = 0; step7Price = 0;
        matchedSteps = 0; matchLabel = ""; patternType = "";
        matchWaveIndex = -1; errorPips = 0; isValid = false;
    }
};

//+------------------------------------------------------------------+
//| FrequencyHistoryEntry — one entry in the ring buffer              |
//| Stores result + XABC context for coherence analysis               |
//+------------------------------------------------------------------+
struct FrequencyHistoryEntry {
    FrequencyResult result;     // What the optimizer found
    double    abDistance;       // |AB| distance for scale comparison
    double    ratioBC_AB;       // BC/AB ratio for pattern similarity
    int       freqIndex;        // Best frequency index (binary subdivision)
    datetime  timestamp;        // When this pattern was recorded
    bool      isUsed;           // Whether this slot has data

    void Reset() {
        result.Reset();
        abDistance = 0; ratioBC_AB = 0; freqIndex = 0;
        timestamp = 0; isUsed = false;
    }
};

// Multipliers
const int ZONE_EXTENSION_MULTIPLIER = 100;
const int PERCENTAGE_TO_DECIMAL = 100;

// Time
const int SECONDS_PER_MINUTE = 60;
const int SECONDS_PER_HOUR = 3600;
const int SECONDS_PER_DAY = 86400;

#endif
    // PROJECT_CONSTANTS_MQH