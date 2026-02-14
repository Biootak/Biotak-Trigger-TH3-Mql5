//+------------------------------------------------------------------+
//| WaveAnalysis.mqh - Wave Data Structures & Analysis               |
//| Core theory: Every reversal is a reaction to 50% midpoint of     |
//| a reference wave. Combines arithmetic + Gann (sqrt) midpoints.   |
//+------------------------------------------------------------------+
#ifndef WAVE_ANALYSIS_MQH
#define WAVE_ANALYSIS_MQH

// Maximum number of reference midpoints to evaluate
#define MAX_REFERENCE_MIDPOINTS 28
// Number of primary + compound waves from XABC pattern
#define WAVE_COUNT 6

//+------------------------------------------------------------------+
//| Single wave data                                                 |
//+------------------------------------------------------------------+
struct WaveData {
    double    startPrice;
    double    endPrice;
    datetime  startTime;
    datetime  endTime;
    double    distance;         // |endPrice - startPrice|
    double    midArithmetic;    // (start + end) / 2
    double    midGann;          // (sqrt(start) + sqrt(end))^2 / 4
    double    quarter25;        // start + 0.25 * (end - start)
    double    quarter75;        // start + 0.75 * (end - start)
    int       barDuration;      // bars between start and end
    double    speed;            // distance / barDuration (Gann angle proxy)
    bool      isBullish;        // endPrice > startPrice
    bool      isValid;

    void Reset() {
        startPrice = 0; endPrice = 0;
        startTime = 0;  endTime = 0;
        distance = 0;   midArithmetic = 0; midGann = 0;
        quarter25 = 0;  quarter75 = 0;
        barDuration = 0; speed = 0;
        isBullish = false; isValid = false;
    }
};

//+------------------------------------------------------------------+
//| Reference midpoint for matching against Step3                    |
//+------------------------------------------------------------------+
struct ReferenceMidpoint {
    double    price;           // The midpoint price level
    int       waveIndex;       // Which wave (0-5) it belongs to
    string    label;           // e.g. "XA-50%", "AB-Gann", "BC-25%"
    int       type;            // 0=arithmetic50, 1=gann50, 2=quarter25, 3=quarter75
};

//+------------------------------------------------------------------+
//| Full XABC wave analysis result                                   |
//+------------------------------------------------------------------+
struct WaveAnalysisResult {
    // Primary waves
    WaveData  waveXA;          // X → A
    WaveData  waveAB;          // A → B
    WaveData  waveBC;          // B → C

    // Compound waves
    WaveData  waveXB;          // X → B
    WaveData  waveAC;          // A → C
    WaveData  waveXC;          // X → C

    // Input points
    double    priceX, priceA, priceB, priceC;
    datetime  timeX, timeA, timeB, timeC;

    // Overall pattern
    bool      isBullish;       // pB > pA (AB wave direction)
    bool      isValid;

    // Wave ratios (for harmonic scoring)
    double    ratioAB_XA;      // AB.distance / XA.distance
    double    ratioBC_AB;      // BC.distance / AB.distance
    double    timeRatioAB_XA;  // AB.barDuration / XA.barDuration
    double    timeRatioBC_AB;  // BC.barDuration / XA.barDuration

    // Collected reference midpoints
    ReferenceMidpoint midpoints[];
    int       midpointCount;

    void Reset() {
        waveXA.Reset(); waveAB.Reset(); waveBC.Reset();
        waveXB.Reset(); waveAC.Reset(); waveXC.Reset();
        priceX = 0; priceA = 0; priceB = 0; priceC = 0;
        timeX = 0;  timeA = 0;  timeB = 0;  timeC = 0;
        isBullish = false; isValid = false;
        ratioAB_XA = 0; ratioBC_AB = 0;
        timeRatioAB_XA = 0; timeRatioBC_AB = 0;
        midpointCount = 0;
        ArrayResize(midpoints, 0);
    }
};

//+------------------------------------------------------------------+
//| Calculate Gann geometric midpoint: (√H + √L)² / 4              |
//| Gann's "square root" mean — the true geometric center            |
//+------------------------------------------------------------------+
double CalculateGannMidpoint(double price1, double price2) {
    if(price1 <= 0 || price2 <= 0) return 0;
    double sqrtSum = MathSqrt(price1) + MathSqrt(price2);
    return (sqrtSum * sqrtSum) / 4.0;
}

//+------------------------------------------------------------------+
//| Build a single WaveData from two price/time endpoints            |
//+------------------------------------------------------------------+
void BuildWaveData(WaveData &wave, double p1, datetime t1, double p2, datetime t2) {
    wave.Reset();
    if(p1 <= 0 || p2 <= 0 || t1 <= 0 || t2 <= 0) return;

    wave.startPrice = p1;
    wave.endPrice   = p2;
    wave.startTime  = t1;
    wave.endTime    = t2;
    wave.distance   = MathAbs(p2 - p1);
    wave.isBullish  = (p2 > p1);

    // Arithmetic midpoint
    wave.midArithmetic = (p1 + p2) / 2.0;

    // Gann sqrt midpoint
    wave.midGann = CalculateGannMidpoint(p1, p2);

    // Fractal quarters
    double dir = p2 - p1;  // signed direction
    wave.quarter25 = p1 + 0.25 * dir;
    wave.quarter75 = p1 + 0.75 * dir;

    // Time/speed
    wave.barDuration = iBarShift(_Symbol, _Period, t1) - iBarShift(_Symbol, _Period, t2);
    if(wave.barDuration < 0) wave.barDuration = -wave.barDuration;
    if(wave.barDuration < 1) wave.barDuration = 1;
    wave.speed = wave.distance / (double)wave.barDuration;

    wave.isValid = (wave.distance > GetCachedPoint() * ABCD_MIN_DISTANCE_POINTS);
}

//+------------------------------------------------------------------+
//| Add a reference midpoint to the analysis result                  |
//+------------------------------------------------------------------+
void AddReferenceMidpoint(WaveAnalysisResult &result, double price, int waveIdx, 
                          const string lbl, int type) {
    if(price <= 0) return;
    int idx = result.midpointCount;
    if(idx >= MAX_REFERENCE_MIDPOINTS) return;

    ArrayResize(result.midpoints, idx + 1);
    result.midpoints[idx].price     = price;
    result.midpoints[idx].waveIndex = waveIdx;
    result.midpoints[idx].label     = lbl;
    result.midpoints[idx].type      = type;
    result.midpointCount = idx + 1;
}

//+------------------------------------------------------------------+
//| Collect all reference midpoints from 6 waves × 4 levels         |
//| = up to 24 midpoints                                             |
//+------------------------------------------------------------------+
void CollectReferenceMidpoints(WaveAnalysisResult &result) {
    // Wave names for labels
    string waveNames[6];
    waveNames[0] = "XA"; waveNames[1] = "AB"; waveNames[2] = "BC";
    waveNames[3] = "XB"; waveNames[4] = "AC"; waveNames[5] = "XC";

    // Type suffixes
    string typeSuffix[4];
    typeSuffix[0] = "50%"; typeSuffix[1] = "Gann"; typeSuffix[2] = "25%"; typeSuffix[3] = "75%";

    // All 6 waves as array of pointers (MQL5 doesn't support, so access directly)
    WaveData waves[6];
    waves[0] = result.waveXA;
    waves[1] = result.waveAB;
    waves[2] = result.waveBC;
    waves[3] = result.waveXB;
    waves[4] = result.waveAC;
    waves[5] = result.waveXC;

    for(int w = 0; w < WAVE_COUNT; w++) {
        if(!waves[w].isValid) continue;

        // Arithmetic 50%
        AddReferenceMidpoint(result, waves[w].midArithmetic, w,
                             waveNames[w] + "-" + typeSuffix[0], 0);
        // Gann 50%
        AddReferenceMidpoint(result, waves[w].midGann, w,
                             waveNames[w] + "-" + typeSuffix[1], 1);
        // 25%
        AddReferenceMidpoint(result, waves[w].quarter25, w,
                             waveNames[w] + "-" + typeSuffix[2], 2);
        // 75%
        AddReferenceMidpoint(result, waves[w].quarter75, w,
                             waveNames[w] + "-" + typeSuffix[3], 3);
    }
}

//+------------------------------------------------------------------+
//| Main analysis: build all waves from XABC points and collect      |
//| all reference midpoints                                          |
//+------------------------------------------------------------------+
bool AnalyzeWaves(double pX, datetime tX, double pA, datetime tA,
                  double pB, datetime tB, double pC, datetime tC,
                  WaveAnalysisResult &result) {
    result.Reset();

    // Validate inputs
    if(pX <= 0 || pA <= 0 || pB <= 0 || pC <= 0) return false;
    if(tX <= 0 || tA <= 0 || tB <= 0 || tC <= 0) return false;

    // Store input points
    result.priceX = pX; result.priceA = pA;
    result.priceB = pB; result.priceC = pC;
    result.timeX  = tX; result.timeA  = tA;
    result.timeB  = tB; result.timeC  = tC;

    // Build primary waves
    BuildWaveData(result.waveXA, pX, tX, pA, tA);
    BuildWaveData(result.waveAB, pA, tA, pB, tB);
    BuildWaveData(result.waveBC, pB, tB, pC, tC);

    // Build compound waves
    BuildWaveData(result.waveXB, pX, tX, pB, tB);
    BuildWaveData(result.waveAC, pA, tA, pC, tC);
    BuildWaveData(result.waveXC, pX, tX, pC, tC);

    // Validate critical waves
    if(!result.waveAB.isValid) return false;

    result.isBullish = result.waveAB.isBullish;

    // Calculate ratios
    if(result.waveXA.isValid && result.waveXA.distance > 0) {
        result.ratioAB_XA     = result.waveAB.distance / result.waveXA.distance;
        result.timeRatioAB_XA = (double)result.waveAB.barDuration / (double)result.waveXA.barDuration;
    }
    if(result.waveAB.distance > 0) {
        result.ratioBC_AB     = result.waveBC.distance / result.waveAB.distance;
        result.timeRatioBC_AB = (double)result.waveBC.barDuration / (double)result.waveAB.barDuration;
    }

    // Collect ALL reference midpoints (24 potential)
    CollectReferenceMidpoints(result);

    result.isValid = true;
    return true;
}

#endif // WAVE_ANALYSIS_MQH
