//+------------------------------------------------------------------+
//|                                                      TH3Tool.mqh |
//|                     TH3 Structure Tool (Proprietary Logic)       |
//|                     Supports: Steps Mode & AB=CD Pattern Mode    |
//+------------------------------------------------------------------+

// Constants for magic numbers
#define ABCD_MIN_DISTANCE_POINTS 10
#define ABCD_DEBOUNCE_MS 300
#define ABCD_LABEL_OFFSET_PIPS 15.0
#define ABCD_MAX_PRICE_MULTIPLIER 10.0
#define ABCD_COLLINEARITY_THRESHOLD 0.0001

// Global state for TH3 Tool Drawing Mode
bool g_th3ToolEnabled = false;
bool g_isDrawingTH3 = false;
bool g_isDraggingTH3 = false;
string g_currentDrawingObject = "";
int g_th3DraggingHandle = -1;
string g_th3DraggingObject = "";

//+------------------------------------------------------------------+
//| Get Cached Daily ATR (Performance Optimization)                 |
//| دریافت ATR روزانه با Cache (بهینه‌سازی عملکرد)                  |
//| Caches ATR for current bar to avoid repeated calculations       |
//+------------------------------------------------------------------+
double GetCachedDailyATR()
{
    static double cachedATR = 0;
    static int cachedBar = -1;
    
    int currentBar = iBars(_Symbol, PERIOD_D1);
    
    // اگر کندل عوض شده، ATR رو دوباره محاسبه کن
    if(currentBar != cachedBar || IsZero(cachedATR, EPSILON_PRICE)) {
        double atrValue = iATRMQL4(_Symbol, PERIOD_D1, 14, 0);
        cachedBar = currentBar;
        
        // CRITICAL FIX: Check for EMPTY_VALUE which iATR returns on error
        // Also check for invalid values using epsilon comparison
        if(atrValue == EMPTY_VALUE || IsZero(atrValue, EPSILON_PRICE) || atrValue < GetCachedPoint() * 10) {
            // Fallback: Calculate average range manually using batch copy
            double highArr[], lowArr[];
            int copied = CopyHigh(_Symbol, PERIOD_D1, 1, 20, highArr);
            int copiedL = CopyLow(_Symbol, PERIOD_D1, 1, 20, lowArr);
            double avgRange = 0;
            int validBars = 0;
            if(copied > 0 && copiedL > 0) {
                int cnt = MathMin(copied, copiedL);
                for(int i = 0; i < cnt; i++) {
                    if(highArr[i] != EMPTY_VALUE && lowArr[i] != EMPTY_VALUE && highArr[i] > lowArr[i]) {
                        avgRange += (highArr[i] - lowArr[i]);
                        validBars++;
                    }
                }
            }
            cachedATR = (validBars > 0) ? (avgRange / validBars) : GetCachedPoint() * 100;
        } else {
            cachedATR = atrValue;
        }
    }
    
    return cachedATR;
}

//+------------------------------------------------------------------+
//| Set active AB=CD pattern (for info label display)               |
//| تنظیم پترن فعال AB=CD (برای نمایش info label)                    |
//+------------------------------------------------------------------+
void SetActiveABCDPattern(string patternName)
{
    if(g_activeABCDPattern == patternName) return; // Already active
    
    // Hide old pattern's info label
    if(g_activeABCDPattern != "") {
        string oldInfoLabel = g_activeABCDPattern + "_Info";
        if(ObjectFind(0, oldInfoLabel) >= 0) {
            ObjectSetInteger(0, oldInfoLabel, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
    
    // Set new active pattern
    g_activeABCDPattern = patternName;
    
    // Show new pattern's info label
    if(patternName != "") {
        string newInfoLabel = patternName + "_Info";
        if(ObjectFind(0, newInfoLabel) >= 0) {
            ObjectSetInteger(0, newInfoLabel, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }
    }
    
    ChartRedraw();
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("📌 Active AB=CD pattern: ", patternName);
    #endif
}

//+------------------------------------------------------------------+
//| Calculate Optimal Default Frequency                             |
//| محاسبه بهترین فرکانس پیش‌فرض                                    |
//| Analyzes all frequencies to find best default for Steps 3,5,7   |
//+------------------------------------------------------------------+
double CalculateOptimalDefaultFrequency()
{
    // تحلیل ریاضی:
    // برای اینکه D روی Step N قرار بگیرد:
    // frequency = 100 / N
    // 
    // Step 3: 100/3 = 33.333%
    // Step 5: 100/5 = 20.0%
    // Step 7: 100/7 = 14.286%
    
    // جستجو در آرایه فرکانس‌ها برای نزدیک‌ترین مقادیر
    double idealFrequencies[3];
    idealFrequencies[0] = 100.0 / 3.0;  // 33.333% for Step 3
    idealFrequencies[1] = 100.0 / 5.0;  // 20.0% for Step 5
    idealFrequencies[2] = 100.0 / 7.0;  // 14.286% for Step 7
    
    int bestIndices[3] = {-1, -1, -1};
    double minErrors[3] = {1000000.0, 1000000.0, 1000000.0};
    
    // پیدا کردن نزدیک‌ترین فرکانس برای هر گام
    for(int i = 0; i < 3; i++)
    {
        double minError = 1000000.0;
        int bestIdx = -1;
        
        for(int j = 0; j < TH3_FREQUENCY_COUNT; j++)
        {
            double error = MathAbs(TH3_TEST_FREQUENCIES[j] - idealFrequencies[i]);
            if(error < minError)
            {
                minError = error;
                bestIdx = j;
            }
        }
        
        bestIndices[i] = bestIdx;
        minErrors[i] = minError;
    }
    
    // نمایش نتایج تحلیل
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("📊 OPTIMAL DEFAULT FREQUENCY ANALYSIS");
    Print("========================================");
    Print("Step 3 (Ideal: 33.333%):");
    Print("  → Closest: ", DoubleToString(TH3_TEST_FREQUENCIES[bestIndices[0]], 3), 
          "% (Index: ", bestIndices[0], ", Error: ", DoubleToString(minErrors[0], 3), "%)");
    Print("Step 5 (Ideal: 20.0%):");
    Print("  → Closest: ", DoubleToString(TH3_TEST_FREQUENCIES[bestIndices[1]], 3), 
          "% (Index: ", bestIndices[1], ", Error: ", DoubleToString(minErrors[1], 3), "%)");
    Print("Step 7 (Ideal: 14.286%):");
    Print("  → Closest: ", DoubleToString(TH3_TEST_FREQUENCIES[bestIndices[2]], 3), 
          "% (Index: ", bestIndices[2], ", Error: ", DoubleToString(minErrors[2], 3), "%)");
    Print("========================================");
    #endif
    
    // انتخاب بهترین فرکانس: میانگین وزن‌دار بر اساس اهمیت هر گام
    // Step 5 مهم‌ترین است (وزن 50%)
    // Step 3 و 7 هر کدام 25% وزن دارند
    double weightedFreq = (TH3_TEST_FREQUENCIES[bestIndices[0]] * 0.25) +
                          (TH3_TEST_FREQUENCIES[bestIndices[1]] * 0.50) +
                          (TH3_TEST_FREQUENCIES[bestIndices[2]] * 0.25);
    
    // پیدا کردن نزدیک‌ترین فرکانس در آرایه به میانگین وزن‌دار
    double minError = 1000000.0;
    int bestDefaultIdx = -1;
    
    for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
    {
        double error = MathAbs(TH3_TEST_FREQUENCIES[i] - weightedFreq);
        if(error < minError)
        {
            minError = error;
            bestDefaultIdx = i;
        }
    }
    
    double bestDefault = TH3_TEST_FREQUENCIES[bestDefaultIdx];
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🎯 RECOMMENDED DEFAULT FREQUENCY:");
    Print("  Weighted Average: ", DoubleToString(weightedFreq, 3), "%");
    Print("  Best Match: ", DoubleToString(bestDefault, 3), "% (Index: ", bestDefaultIdx, ")");
    Print("========================================");
    #endif
    
    return bestDefault;
}

//+------------------------------------------------------------------+
//| Get Current TH3 Frequency (with override support)               |
//+------------------------------------------------------------------+
double GetCurrentTH3Frequency() {
    if(g_th3FrequencyOverride > 0.0) return g_th3FrequencyOverride;
    
    // Validate input parameter (extended to 120%)
    if(inpTH3BaseStepPercent > 0.0 && inpTH3BaseStepPercent <= 120.0) {
        return inpTH3BaseStepPercent;
    }
    
    // Fallback to safe default
    return 28.125;
}

//+------------------------------------------------------------------+
//| Analyze Three-Wave Pattern (XA, AB, BC)                         |
//| تحلیل الگوی سه موجی (XA، AB، BC)                                 |
//| Returns comprehensive wave analysis for frequency selection     |
//+------------------------------------------------------------------+
struct WaveAnalysis {
    // Wave lengths (price)
    double XA_Distance;
    double AB_Distance;
    double BC_Distance;
    
    // Wave durations (time)
    int XA_Minutes;
    int AB_Minutes;
    int BC_Minutes;
    
    // Wave speeds (pips per minute)
    double XA_Speed;
    double AB_Speed;
    double BC_Speed;
    
    // Wave angles (Gann angles in degrees)
    double XA_Angle;
    double AB_Angle;
    double BC_Angle;
    
    // Wave ratios
    double AB_XA_Ratio;      // AB/XA (Fibonacci: 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618)
    double BC_AB_Ratio;      // BC/AB
    
    // Time ratios
    double AB_XA_TimeRatio;  // زمان AB / زمان XA
    double BC_AB_TimeRatio;  // زمان BC / زمان AB
    
    // Speed ratios
    double AB_XA_SpeedRatio; // سرعت AB / سرعت XA
    double BC_AB_SpeedRatio; // سرعت BC / سرعت AB
    
    // Acceleration (تغییر سرعت در طول زمان)
    double XA_to_AB_Acceleration;  // شتاب از XA به AB (pips/min²)
    double AB_to_BC_Acceleration;  // شتاب از AB به BC (pips/min²)
    
    // Strength levels (قدرت هر leg)
    double XA_RawStrength;       // قدرت خام XA (pips/min)
    double AB_RawStrength;       // قدرت خام AB
    double BC_RawStrength;       // قدرت خام BC
    double XA_WeightedStrength;  // قدرت وزن‌دار XA (با زاویه)
    double AB_WeightedStrength;  // قدرت وزن‌دار AB
    double BC_WeightedStrength;  // قدرت وزن‌دار BC
    double XA_RelativeStrength;  // قدرت نسبی XA (نسبت به ATR)
    double AB_RelativeStrength;  // قدرت نسبی AB
    double BC_RelativeStrength;  // قدرت نسبی BC
    
    // Pattern characteristics
    bool isImpulsive;        // آیا الگو impulsive است (موج‌های قوی)
    bool isCorrectional;     // آیا الگو correctional است (اصلاح)
    double avgSpeed;         // میانگین سرعت سه موج
    double speedConsistency; // ثبات سرعت (0-1، 1 = ثبات کامل)
    double timeSymmetry;     // تقارن زمانی BC با AB (0-1، 1 = تقارن کامل)
};

WaveAnalysis AnalyzeThreeWaves(datetime tX, double pX, datetime tA, double pA,
                                datetime tB, double pB, datetime tC, double pC)
{
    WaveAnalysis analysis;
    double pipSize = GetCachedPipSize();
    
    // SECURITY: Validate time ordering (X < A < B < C)
    if(!(tX < tA && tA < tB && tB < tC)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AnalyzeThreeWaves: Invalid time ordering (X < A < B < C required)");
        Print("   tX=", TimeToString(tX), ", tA=", TimeToString(tA), ", tB=", TimeToString(tB), ", tC=", TimeToString(tC));
        #endif
        // Return default values
        analysis.XA_Distance = 0;
        analysis.AB_Distance = 0;
        analysis.BC_Distance = 0;
        analysis.XA_Minutes = 1;
        analysis.AB_Minutes = 1;
        analysis.BC_Minutes = 1;
        analysis.XA_Speed = 0;
        analysis.AB_Speed = 0;
        analysis.BC_Speed = 0;
        analysis.XA_Angle = 0;
        analysis.AB_Angle = 0;
        analysis.BC_Angle = 0;
        analysis.AB_XA_Ratio = 1;
        analysis.BC_AB_Ratio = 1;
        analysis.AB_XA_TimeRatio = 1;
        analysis.BC_AB_TimeRatio = 1;
        analysis.AB_XA_SpeedRatio = 1;
        analysis.BC_AB_SpeedRatio = 1;
        analysis.isImpulsive = false;
        analysis.isCorrectional = false;
        analysis.avgSpeed = 0;
        analysis.speedConsistency = 0;
        analysis.timeSymmetry = 0;
        return analysis;
    }
    
    // محاسبه طول موج‌ها (قیمت)
    analysis.XA_Distance = MathAbs(pA - pX);
    analysis.AB_Distance = MathAbs(pB - pA);
    analysis.BC_Distance = MathAbs(pC - pB);
    
    // محاسبه مدت زمان موج‌ها (دقیقه)
    analysis.XA_Minutes = (int)((tA - tX) / 60);
    analysis.AB_Minutes = (int)((tB - tA) / 60);
    analysis.BC_Minutes = (int)((tC - tB) / 60);
    
    // جلوگیری از تقسیم بر صفر
    if(analysis.XA_Minutes <= 0) analysis.XA_Minutes = 1;
    if(analysis.AB_Minutes <= 0) analysis.AB_Minutes = 1;
    if(analysis.BC_Minutes <= 0) analysis.BC_Minutes = 1;
    
    // CRITICAL FIX: Validate division operands with epsilon check
    if(MathAbs(analysis.AB_Minutes) < 0.001) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateWaveAnalysis: AB_Minutes too small (", analysis.AB_Minutes, "), cannot calculate speed");
        #endif
        analysis.AB_Speed = 0;
    } else {
        analysis.AB_Speed = (analysis.AB_Distance / pipSize) / analysis.AB_Minutes;
    }
    
    if(MathAbs(analysis.XA_Minutes) < 0.001) {
        analysis.XA_Speed = 0;
    } else {
        analysis.XA_Speed = (analysis.XA_Distance / pipSize) / analysis.XA_Minutes;
    }
    
    if(MathAbs(analysis.BC_Minutes) < 0.001) {
        analysis.BC_Speed = 0;
    } else {
        analysis.BC_Speed = (analysis.BC_Distance / pipSize) / analysis.BC_Minutes;
    }
    
    // محاسبه زاویه‌های Gann (یکبار برای همیشه)
    analysis.XA_Angle = CalculateWaveAngle(tX, pX, tA, pA);
    analysis.AB_Angle = CalculateWaveAngle(tA, pA, tB, pB);
    analysis.BC_Angle = CalculateWaveAngle(tB, pB, tC, pC);
    
    // محاسبه نسبت‌های قیمت
    analysis.AB_XA_Ratio = (analysis.XA_Distance > 0) ? (analysis.AB_Distance / analysis.XA_Distance) : 1.0;
    analysis.BC_AB_Ratio = (analysis.AB_Distance > 0) ? (analysis.BC_Distance / analysis.AB_Distance) : 1.0;
    
    // محاسبه نسبت‌های زمان
    analysis.AB_XA_TimeRatio = (double)analysis.AB_Minutes / analysis.XA_Minutes;
    analysis.BC_AB_TimeRatio = (double)analysis.BC_Minutes / analysis.AB_Minutes;
    
    // محاسبه نسبت‌های سرعت
    analysis.AB_XA_SpeedRatio = (analysis.XA_Speed > 0) ? (analysis.AB_Speed / analysis.XA_Speed) : 1.0;
    analysis.BC_AB_SpeedRatio = (analysis.AB_Speed > 0) ? (analysis.BC_Speed / analysis.AB_Speed) : 1.0;
    
    // ========================================
    // 🚀 ACCELERATION ANALYSIS (شتاب - تغییر سرعت)
    // ========================================
    // فرمول: Acceleration = ΔVelocity ÷ ΔTime
    // منبع: فیزیک استاندارد (a = Δv / Δt)
    
    // شتاب از XA به AB
    double velocityChange_XA_AB = analysis.AB_Speed - analysis.XA_Speed;
    analysis.XA_to_AB_Acceleration = velocityChange_XA_AB / MathMax(analysis.AB_Minutes, 1);
    
    // شتاب از AB به BC
    double velocityChange_AB_BC = analysis.BC_Speed - analysis.AB_Speed;
    analysis.AB_to_BC_Acceleration = velocityChange_AB_BC / MathMax(analysis.BC_Minutes, 1);
    
    // SECURITY: بررسی NaN
    if(analysis.XA_to_AB_Acceleration != analysis.XA_to_AB_Acceleration) analysis.XA_to_AB_Acceleration = 0;
    if(analysis.AB_to_BC_Acceleration != analysis.AB_to_BC_Acceleration) analysis.AB_to_BC_Acceleration = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🚀 ACCELERATION ANALYSIS:");
    Print("   XA→AB: ", DoubleToString(analysis.XA_to_AB_Acceleration, 4), " pips/min²");
    if(analysis.XA_to_AB_Acceleration > 0.001) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ⬆️ ACCELERATING: Speed increasing (getting stronger)");
        #endif
    } else if(analysis.XA_to_AB_Acceleration < -0.001) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ⬇️ DECELERATING: Speed decreasing (getting weaker)");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ➡️ CONSTANT: Speed stable");
        #endif
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("   AB→BC: ", DoubleToString(analysis.AB_to_BC_Acceleration, 4), " pips/min²");
    #endif
    if(analysis.AB_to_BC_Acceleration > 0.001) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ⬆️ ACCELERATING: Correction speeding up");
        #endif
    } else if(analysis.AB_to_BC_Acceleration < -0.001) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ⬇️ DECELERATING: Correction slowing down");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("      ➡️ CONSTANT: Correction speed stable");
        #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    #endif
    
    // ========================================
    // 💪 LEG STRENGTH ANALYSIS (تحلیل قدرت هر leg)
    // ========================================
    // فرمول: Velocity = Distance ÷ Time (pips/min)
    // منبع: فیزیک نیوتن، TradingView Time-Price Velocity
    
    // محاسبه قدرت خام (Raw Strength) = Velocity
    analysis.XA_RawStrength = (analysis.XA_Distance / pipSize) / MathMax(analysis.XA_Minutes, 1);
    analysis.AB_RawStrength = (analysis.AB_Distance / pipSize) / MathMax(analysis.AB_Minutes, 1);
    analysis.BC_RawStrength = (analysis.BC_Distance / pipSize) / MathMax(analysis.BC_Minutes, 1);
    
    // SECURITY: بررسی NaN
    if(analysis.XA_RawStrength != analysis.XA_RawStrength) analysis.XA_RawStrength = 0;
    if(analysis.AB_RawStrength != analysis.AB_RawStrength) analysis.AB_RawStrength = 0;
    if(analysis.BC_RawStrength != analysis.BC_RawStrength) analysis.BC_RawStrength = 0;
    
    // محاسبه قدرت وزن‌دار (Weighted Strength)
    // وزن بر اساس زاویه: زاویه بالاتر = قدرت بیشتر
    // فرمول: Weighted = Raw × sin(angle)
    double angleWeight_XA = MathSin(analysis.XA_Angle * M_PI / 180.0);  // 0-1
    double angleWeight_AB = MathSin(analysis.AB_Angle * M_PI / 180.0);
    double angleWeight_BC = MathSin(analysis.BC_Angle * M_PI / 180.0);
    
    analysis.XA_WeightedStrength = analysis.XA_RawStrength * angleWeight_XA;
    analysis.AB_WeightedStrength = analysis.AB_RawStrength * angleWeight_AB;
    analysis.BC_WeightedStrength = analysis.BC_RawStrength * angleWeight_BC;
    
    // SECURITY: بررسی NaN
    if(analysis.XA_WeightedStrength != analysis.XA_WeightedStrength) analysis.XA_WeightedStrength = 0;
    if(analysis.AB_WeightedStrength != analysis.AB_WeightedStrength) analysis.AB_WeightedStrength = 0;
    if(analysis.BC_WeightedStrength != analysis.BC_WeightedStrength) analysis.BC_WeightedStrength = 0;
    
    // ========================================
    // OPTIMIZATION: محاسبه یکبار ATR برای استفاده مجدد
    // ========================================
    double dailyATR = GetCachedDailyATR();
    double dailyATRInPips = dailyATR / pipSize;
    double referenceSpeed = dailyATRInPips / 1440.0;  // ATR per minute
    
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    
    // محاسبه قدرت نسبی (Relative Strength)
    // مقایسه با ATR روزانه برای نرمال‌سازی
    // فرمول: Relative = Weighted ÷ (ATR per minute)
    // منبع: TradingView ATR Normalization
    analysis.XA_RelativeStrength = analysis.XA_WeightedStrength / referenceSpeed;
    analysis.AB_RelativeStrength = analysis.AB_WeightedStrength / referenceSpeed;
    analysis.BC_RelativeStrength = analysis.BC_WeightedStrength / referenceSpeed;
    
    // SECURITY: بررسی NaN
    if(analysis.XA_RelativeStrength != analysis.XA_RelativeStrength) analysis.XA_RelativeStrength = 0;
    if(analysis.AB_RelativeStrength != analysis.AB_RelativeStrength) analysis.AB_RelativeStrength = 0;
    if(analysis.BC_RelativeStrength != analysis.BC_RelativeStrength) analysis.BC_RelativeStrength = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("💪 LEG STRENGTH ANALYSIS:");
    Print("   XA: Raw=", DoubleToString(analysis.XA_RawStrength, 2), 
          " | Weighted=", DoubleToString(analysis.XA_WeightedStrength, 2),
          " | Relative=", DoubleToString(analysis.XA_RelativeStrength, 2), "x ATR");
    #ifdef ENABLE_DEBUG_LOGS
    Print("   AB: Raw=", DoubleToString(analysis.AB_RawStrength, 2), 
          " | Weighted=", DoubleToString(analysis.AB_WeightedStrength, 2),
          " | Relative=", DoubleToString(analysis.AB_RelativeStrength, 2), "x ATR");
    Print("   BC: Raw=", DoubleToString(analysis.BC_RawStrength, 2), 
          " | Weighted=", DoubleToString(analysis.BC_WeightedStrength, 2),
          " | Relative=", DoubleToString(analysis.BC_RelativeStrength, 2), "x ATR");
    #endif
    
    // تشخیص قوی‌ترین leg
    string strongestLeg = "XA";
    double maxStrength = analysis.XA_RelativeStrength;
    if(analysis.AB_RelativeStrength > maxStrength) {
        strongestLeg = "AB";
        maxStrength = analysis.AB_RelativeStrength;
    }
    if(analysis.BC_RelativeStrength > maxStrength) {
        strongestLeg = "BC";
        maxStrength = analysis.BC_RelativeStrength;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("   🏆 Strongest Leg: ", strongestLeg, " (", DoubleToString(maxStrength, 2), "x ATR)");
    #endif
    
    // تشخیص نوع قدرت
    if(maxStrength > 3.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚡ VERY STRONG: Explosive movement detected");
        #endif
    } else if(maxStrength > 2.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   💪 STRONG: Powerful movement");
        #endif
    } else if(maxStrength > 1.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ✓ MODERATE: Normal strength");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚠️ WEAK: Low momentum");
        #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    #endif
    
    // ========================================
    // تشخیص نوع الگو (استفاده مجدد از referenceSpeed)
    // ========================================
    // Impulsive: موج‌ها قوی و سریع (سرعت بالا)
    // Correctional: موج‌ها ضعیف و کند (سرعت پایین)
    analysis.avgSpeed = (analysis.XA_Speed + analysis.AB_Speed + analysis.BC_Speed) / 3.0;
    
    // محاسبه ثبات سرعت (انحراف معیار نرمال شده)
    // فرمول: StdDev = √(Σ(x - mean)² / n)
    double speedVariance = MathPow(analysis.XA_Speed - analysis.avgSpeed, 2) +
                          MathPow(analysis.AB_Speed - analysis.avgSpeed, 2) +
                          MathPow(analysis.BC_Speed - analysis.avgSpeed, 2);
    double speedStdDev = MathSqrt(speedVariance / 3.0);
    analysis.speedConsistency = (analysis.avgSpeed > 0) ? (1.0 - MathMin(speedStdDev / analysis.avgSpeed, 1.0)) : 0.5;
    
    // SECURITY: بررسی NaN
    if(analysis.speedConsistency != analysis.speedConsistency) analysis.speedConsistency = 0.5;
    
    // تشخیص impulsive vs correctional (استفاده مجدد از referenceSpeed)
    double avgSpeedRatio = analysis.avgSpeed / referenceSpeed;
    analysis.isImpulsive = (avgSpeedRatio > 1.2);      // سرعت بیش از 120% میانگین
    analysis.isCorrectional = (avgSpeedRatio < 0.8);   // سرعت کمتر از 80% میانگین
    
    // محاسبه تقارن زمانی (یکبار برای همیشه)
    analysis.timeSymmetry = CalculateTimeSymmetry(tA, tB, tC);
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Calculate Wave Angle (Gann Angle)                               |
//| محاسبه زاویه موج (زاویه Gann)                                    |
//| Returns: Angle in degrees (0-90)                                |
//| Logic: angle = atan(price_change / time_change)                 |
//+------------------------------------------------------------------+
double CalculateWaveAngle(datetime tStart, double pStart, datetime tEnd, double pEnd)
{
    // SECURITY: Validate inputs
    if(tEnd <= tStart) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateWaveAngle: Invalid time range");
        #endif
        return 0;
    }
    if(pStart <= 0 || pEnd <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateWaveAngle: Invalid prices");
        #endif
        return 0;
    }
    
    // محاسبه تغییرات قیمت و زمان
    double priceChange = MathAbs(pEnd - pStart);
    int timeChangeMinutes = (int)((tEnd - tStart) / 60);
    if(timeChangeMinutes <= 0) timeChangeMinutes = 1;
    
    // نرمال‌سازی: قیمت به پیپ
    double pipSize = GetCachedPipSize();
    double priceInPips = priceChange / pipSize;
    
    // محاسبه زاویه (degrees)
    // نرمال‌سازی: 1 pip per minute = 45 degrees (Gann 1×1)
    // OPTIMIZATION: Use cached ATR instead of repeated iATR() calls
    double dailyATR = GetCachedDailyATR();
    if(dailyATR <= 0 || dailyATR < GetCachedPoint() * 10) {
        double highArr[], lowArr[];
        int copied = CopyHigh(_Symbol, PERIOD_D1, 1, 20, highArr);
        int copiedL = CopyLow(_Symbol, PERIOD_D1, 1, 20, lowArr);
        double avgRange = 0;
        if(copied > 0 && copiedL > 0) {
            int cnt = MathMin(copied, copiedL);
            for(int i = 0; i < cnt; i++) {
                avgRange += (highArr[i] - lowArr[i]);
            }
            dailyATR = avgRange / cnt;
        } else {
            dailyATR = GetCachedPoint() * 100;
        }
    }
    
    double dailyATRInPips = dailyATR / pipSize;
    double referenceSpeed = dailyATRInPips / 1440.0; // pips per minute
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    
    // سرعت واقعی
    double actualSpeed = priceInPips / timeChangeMinutes;
    
    // نسبت سرعت (1.0 = 45 degrees)
    double speedRatio = actualSpeed / referenceSpeed;
    
    // تبدیل به زاویه
    // speedRatio = 0 → 0°
    // speedRatio = 1 → 45° (Gann 1×1)
    // speedRatio = 2 → 63.43° (Gann 2×1)
    // speedRatio = 3 → 71.57° (Gann 3×1)
    // speedRatio → ∞ → 90°
    double angle = MathArctan(speedRatio) * 180.0 / M_PI;
    
    // SECURITY: بررسی NaN
    if(angle != angle) angle = 0;  // NaN check
    
    // محدود کردن به بازه 0-90
    if(angle < 0) angle = 0;
    if(angle > 90) angle = 90;
    
    return angle;
}

//+------------------------------------------------------------------+
//| Calculate Required Rest Candles Based on Angle                  |
//| محاسبه تعداد کندل‌های استراحت مورد نیاز بر اساس زاویه            |
//| Returns: Number of candles needed for rest/correction           |
//| CRITICAL FIX: Complete integer overflow protection               |
//+------------------------------------------------------------------+

// Constants for angle thresholds (no magic numbers)
#define ANGLE_SPIKE_THRESHOLD 80.0
#define ANGLE_STRONG_THRESHOLD 55.0
#define ANGLE_BALANCED_THRESHOLD 40.0
#define ANGLE_SLOW_THRESHOLD 25.0

#define REST_SPIKE_BASE 3
#define REST_SPIKE_MAX 4
#define REST_STRONG_BASE 7
#define REST_STRONG_MAX 9
#define REST_BALANCED_BASE 15
#define REST_BALANCED_MAX 17
#define REST_SLOW_BASE 26
#define REST_SLOW_MAX 33
#define REST_VERY_SLOW_BASE 33
#define REST_VERY_SLOW_MAX 50

#define MAX_MOVEMENT_CANDLES 10000
#define MAX_REST_CANDLES 1000

int CalculateRequiredRestCandles(double angle, int movementCandles)
{
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #1: Validate movementCandles to prevent overflow
    // ═══════════════════════════════════════════════════════════════
    if(movementCandles < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateRequiredRestCandles: Negative movementCandles (", 
              movementCandles, "), setting to 0");
        #endif
        movementCandles = 0;
    }
    if(movementCandles > MAX_MOVEMENT_CANDLES) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateRequiredRestCandles: movementCandles too large (", 
              movementCandles, "), clamping to ", MAX_MOVEMENT_CANDLES);
        #endif
        movementCandles = MAX_MOVEMENT_CANDLES;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #2: Validate angle
    // ═══════════════════════════════════════════════════════════════
    if(angle < 0) angle = 0;
    if(angle > 90) angle = 90;
    
    int restCandles = 0;
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #3: Safe calculation with overflow checks
    // ═══════════════════════════════════════════════════════════════
    if(angle >= ANGLE_SPIKE_THRESHOLD) {
        // Spike (80-90°): خیلی تند
        double temp = movementCandles * 0.1;
        if(temp > INT_MAX - REST_SPIKE_BASE) {
            restCandles = REST_SPIKE_MAX;
        } else {
            restCandles = REST_SPIKE_BASE + (int)temp;
            if(restCandles > REST_SPIKE_MAX) restCandles = REST_SPIKE_MAX;
        }
    }
    else if(angle >= ANGLE_STRONG_THRESHOLD) {
        // Strong (55-80°): تند
        double temp = movementCandles * 0.15;
        if(temp > INT_MAX - REST_STRONG_BASE) {
            restCandles = REST_STRONG_MAX;
        } else {
            restCandles = REST_STRONG_BASE + (int)temp;
            if(restCandles > REST_STRONG_MAX) restCandles = REST_STRONG_MAX;
        }
    }
    else if(angle >= ANGLE_BALANCED_THRESHOLD) {
        // Balanced (40-55°): متعادل (نزدیک Gann 1×1)
        double temp = movementCandles * 0.2;
        if(temp > INT_MAX - REST_BALANCED_BASE) {
            restCandles = REST_BALANCED_MAX;
        } else {
            restCandles = REST_BALANCED_BASE + (int)temp;
            if(restCandles > REST_BALANCED_MAX) restCandles = REST_BALANCED_MAX;
        }
    }
    else if(angle >= ANGLE_SLOW_THRESHOLD) {
        // Slow (25-40°): کند
        double temp = movementCandles * 0.25;
        if(temp > INT_MAX - REST_SLOW_BASE) {
            restCandles = REST_SLOW_MAX;
        } else {
            restCandles = REST_SLOW_BASE + (int)temp;
            if(restCandles > REST_SLOW_MAX) restCandles = REST_SLOW_MAX;
        }
    }
    else {
        // Very Slow (< 25°): خیلی کند
        double temp = movementCandles * 0.3;
        if(temp > INT_MAX - REST_VERY_SLOW_BASE) {
            restCandles = REST_VERY_SLOW_MAX;
        } else {
            restCandles = REST_VERY_SLOW_BASE + (int)temp;
            if(restCandles > REST_VERY_SLOW_MAX) restCandles = REST_VERY_SLOW_MAX;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #4: Final validation
    // ═══════════════════════════════════════════════════════════════
    if(restCandles < 0) restCandles = 0;
    if(restCandles > MAX_REST_CANDLES) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateRequiredRestCandles: Result too large (", restCandles, 
              "), clamping to ", MAX_REST_CANDLES);
        #endif
        restCandles = MAX_REST_CANDLES;
    }
    
    return restCandles;
}

//+------------------------------------------------------------------+
//| Determine Reference Timeframe Based on Wave Size                |
//| تعیین تایم‌فریم مرجع بر اساس اندازه موج                          |
//| Returns: TH percentage for reference timeframe                  |
//| Logic: Wave size (in TH units) determines structure timeframe   |
//+------------------------------------------------------------------+
double DetermineReferenceTimeframe(double waveDistance, double currentTH)
{
    // محاسبه اندازه موج به واحد TH
    double waveSizeInTH = (currentTH > 0) ? (waveDistance / currentTH) : 0;
    
    // قانون: هر موج باید 3 برابر TH یک تایم‌فریم باشه
    // پس تایم‌فریم مرجع = waveSizeInTH / 3
    
    // پیدا کردن نزدیک‌ترین تایم‌فریم در آرایه فراکتال
    double targetTHMultiplier = waveSizeInTH / 3.0;
    
    // جستجو در آرایه MODIFIED_FRACTAL_PERCENTAGES
    int arraySize = ArraySize(MODIFIED_FRACTAL_PERCENTAGES);
    double closestTH = MODIFIED_FRACTAL_PERCENTAGES[0];
    double minDiff = 1000000.0;
    
    for(int i = 0; i < arraySize; i++) {
        double testTH = MODIFIED_FRACTAL_PERCENTAGES[i];
        double diff = MathAbs(testTH - (currentTH * targetTHMultiplier));
        
        if(diff < minDiff) {
            minDiff = diff;
            closestTH = testTH;
        }
    }
    
    return closestTH;
}

//+------------------------------------------------------------------+
//| Calculate Consolidation Factor - ADVANCED (Gann-based)          |
//| محاسبه ضریب Consolidation - پیشرفته (بر اساس Gann)             |
//| Considers: angle, rest candles, energy buildup                  |
//| OPTIMIZED: Uses pre-calculated wave analysis                    |
//+------------------------------------------------------------------+
double CalculateConsolidationFactor(datetime tA, datetime tB, datetime tC, 
                                     WaveAnalysis &waves)
{
    // ========================================
    // مرحله 1: استفاده از زاویه محاسبه شده
    // ========================================
    double angleAB = waves.AB_Angle;  // از struct استفاده می‌کنیم
    
    // ========================================
    // مرحله 2: محاسبه تعداد کندل‌های AB و BC
    // ========================================
    int barA = iBarShift(_Symbol, _Period, tA);
    int barB = iBarShift(_Symbol, _Period, tB);
    int barC = iBarShift(_Symbol, _Period, tC);
    
    int AB_Candles = MathAbs(barA - barB);
    int BC_Candles = MathAbs(barB - barC);
    
    if(AB_Candles < 1) AB_Candles = 1;
    if(BC_Candles < 1) BC_Candles = 1;
    
    // ========================================
    // مرحله 3: محاسبه کندل‌های استراحت مورد نیاز
    // ========================================
    int requiredRestCandles = CalculateRequiredRestCandles(angleAB, AB_Candles);
    
    // ========================================
    // مرحله 4: محاسبه نسبت استراحت واقعی به مورد نیاز
    // ========================================
    double restRatio = (double)BC_Candles / requiredRestCandles;
    
    // ========================================
    // مرحله 5: محاسبه ضریب consolidation
    // ========================================
    double consolidationFactor = 0.0;
    
    if(restRatio < 0.3) {
        // استراحت خیلی کم (< 30% مورد نیاز)
        // انرژی زیاد جمع شده → breakout قوی
        consolidationFactor = 0.9;
    }
    else if(restRatio < 0.6) {
        // استراحت کم (30-60% مورد نیاز)
        // انرژی متوسط جمع شده
        consolidationFactor = 0.7;
    }
    else if(restRatio < 1.0) {
        // استراحت نزدیک به کافی (60-100% مورد نیاز)
        // انرژی کم جمع شده
        consolidationFactor = 0.4;
    }
    else if(restRatio < 1.5) {
        // استراحت کافی (100-150% مورد نیاز)
        // حرکت عادی
        consolidationFactor = 0.1;
    }
    else {
        // استراحت زیاد (> 150% مورد نیاز)
        // انرژی تخلیه شده
        consolidationFactor = 0.0;
    }
    
    // ========================================
    // مرحله 6: تنظیم بر اساس زاویه
    // ========================================
    // زاویه تندتر → نیاز به استراحت بیشتر → consolidation بالاتر
    if(angleAB >= 80) {
        consolidationFactor *= 1.3; // Spike: +30%
    }
    else if(angleAB >= 55) {
        consolidationFactor *= 1.15; // Strong: +15%
    }
    // else: Normal
    
    // محدود کردن به بازه 0-1
    if(consolidationFactor > 1.0) consolidationFactor = 1.0;
    if(consolidationFactor < 0.0) consolidationFactor = 0.0;
    
    return consolidationFactor;
}

//+------------------------------------------------------------------+
//| Calculate Optimal Frequency from Wave Analysis                  |
//| محاسبه فرکانس بهینه از تحلیل موج                                |
//| Integrates: speed, consolidation, consistency, Fibonacci        |
//+------------------------------------------------------------------+
double CalculateFrequencyFromWaves(WaveAnalysis &waves)
{
    // استراتژی انتخاب فرکانس بر اساس تحلیل موج:
    // 1. شروع با فرکانس پایه (Step 5 = 20%)
    // 2. تنظیم بر اساس نوع الگو (Impulsive/Correctional)
    // 3. تنظیم بر اساس سرعت دقیق (Gann-inspired)
    // 4. تنظیم بر اساس ثبات سرعت
    // 5. تنظیم بر اساس نسبت‌های Fibonacci
    
    double baseFrequency = 20.0; // پیش‌فرض برای Step 5
    
    // ========================================
    // مرحله 1: تنظیم بر اساس نوع الگو
    // ========================================
    if(waves.isImpulsive) {
        baseFrequency *= 1.3; // افزایش 30% برای موج‌های قوی
    }
    else if(waves.isCorrectional) {
        baseFrequency *= 0.7; // کاهش 30% برای موج‌های ضعیف
    }
    
    // ========================================
    // مرحله 2: تنظیم دقیق بر اساس سرعت (Gann-inspired)
    // ========================================
    // محاسبه نسبت سرعت نسبت به ATR
    // OPTIMIZATION: Use cached ATR instead of repeated iATR() calls
    double dailyATR = GetCachedDailyATR();
    double pipSize = GetCachedPipSize();
    
    if(dailyATR <= 0 || dailyATR < GetCachedPoint() * 10) {
        double highArr[], lowArr[];
        int copied = CopyHigh(_Symbol, PERIOD_D1, 1, 20, highArr);
        int copiedL = CopyLow(_Symbol, PERIOD_D1, 1, 20, lowArr);
        double avgRange = 0;
        if(copied > 0 && copiedL > 0) {
            int cnt = MathMin(copied, copiedL);
            for(int i = 0; i < cnt; i++) {
                avgRange += (highArr[i] - lowArr[i]);
            }
            dailyATR = avgRange / cnt;
        } else {
            dailyATR = GetCachedPoint() * 100;
        }
    }
    
    double dailyATRInPips = dailyATR / pipSize;
    double referenceSpeed = dailyATRInPips / 1440.0;
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    
    double avgSpeedRatio = waves.avgSpeed / referenceSpeed;
    
    // تنظیم دقیق بر اساس سرعت (منطق Gann)
    double speedWeight = 1.0;
    if(avgSpeedRatio >= 3.0) {
        speedWeight = 1.5; // خیلی سریع
    }
    else if(avgSpeedRatio >= 2.0) {
        speedWeight = 1.3; // سریع (Gann 2×1)
    }
    else if(avgSpeedRatio >= 1.5) {
        speedWeight = 1.15; // نسبتاً سریع
    }
    else if(avgSpeedRatio >= 0.8 && avgSpeedRatio <= 1.2) {
        speedWeight = 1.0; // متعادل (Gann 1×1)
    }
    else if(avgSpeedRatio >= 0.5) {
        speedWeight = 0.85; // نسبتاً کند (Gann 1×2)
    }
    else if(avgSpeedRatio >= 0.33) {
        speedWeight = 0.7; // کند
    }
    else {
        speedWeight = 0.6; // خیلی کند
    }
    
    baseFrequency *= speedWeight;
    
    // ========================================
    // مرحله 3: تنظیم بر اساس ثبات سرعت
    // ========================================
    // اگر سرعت ثابت است، به محاسبات اعتماد بیشتری داریم
    double consistencyFactor = 0.8 + (waves.speedConsistency * 0.4); // 0.8 تا 1.2
    baseFrequency *= consistencyFactor;
    
    // ========================================
    // مرحله 4: تنظیم بر اساس نسبت AB/XA (Fibonacci)
    // ========================================
    // اگر نزدیک به نسبت‌های Fibonacci باشد، الگو قوی‌تر است
    double fibRatios[7] = {0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618};
    double minFibDiff = 1000.0;
    
    for(int i = 0; i < 7; i++) {
        double diff = MathAbs(waves.AB_XA_Ratio - fibRatios[i]);
        if(diff < minFibDiff) minFibDiff = diff;
    }
    
    // اگر نزدیک به Fibonacci باشد (< 0.1)، اعتماد بیشتر
    if(minFibDiff < 0.1) {
        baseFrequency *= 1.1; // افزایش 10%
    }
    
    // ========================================
    // مرحله 5: محدود کردن به بازه معتبر
    // ========================================
    if(baseFrequency < 3.125) baseFrequency = 3.125;
    if(baseFrequency > 120.0) baseFrequency = 120.0; // Extended to 120%
    
    return baseFrequency;
}
//| محاسبه نسبت سرعت حرکت (الهام از Gann) - اصلاح شده              |
//| Returns: Speed ratio relative to reference (1.0 = balanced)     |
//| > 1.0 = Fast move, < 1.0 = Slow move                           |
//+------------------------------------------------------------------+
double CalculateMovementSpeed(datetime tA, double pA, datetime tB, double pB)
{
    // محاسبه تغییرات قیمت و زمان
    double priceChange = MathAbs(pB - pA);
    int timeChangeMinutes = (int)((tB - tA) / 60); // تبدیل به دقیقه
    
    if(timeChangeMinutes <= 0) return 1.0; // Default to balanced
    
    // نرمال‌سازی: قیمت به پیپ
    double pipSize = GetCachedPipSize();
    double priceInPips = priceChange / pipSize;
    
    // محاسبه سرعت: پیپ در دقیقه
    double speed = priceInPips / timeChangeMinutes;
    
    // محاسبه سرعت مرجع (benchmark) بر اساس ATR
    double dailyATR = GetCachedDailyATR();  // استفاده از cache
    
    double dailyATRInPips = dailyATR / pipSize;
    
    // سرعت مرجع: ATR روزانه تقسیم بر 1440 دقیقه (یک روز)
    double referenceSpeed = dailyATRInPips / 1440.0;
    
    // FIX: اگر هنوز هم صفر است، از مقدار پیش‌فرض استفاده کن
    if(referenceSpeed <= 0) referenceSpeed = 0.1; // حداقل سرعت مرجع
    
    // نسبت سرعت: سرعت واقعی / سرعت مرجع
    double speedRatio = speed / referenceSpeed;
    
    // محدود کردن نسبت به بازه معقول (0.1 تا 10)
    if(speedRatio < 0.1) speedRatio = 0.1;
    if(speedRatio > 10.0) speedRatio = 10.0;
    
    return speedRatio;
}

//+------------------------------------------------------------------+
//| Calculate Time Symmetry Factor                                  |
//| محاسبه ضریب تقارن زمانی بین AB و BC                             |
//| Perfect symmetry (AB time = BC time) = 1.0                      |
//+------------------------------------------------------------------+
double CalculateTimeSymmetry(datetime tA, datetime tB, datetime tC)
{
    int timeAB = (int)((tB - tA) / 60); // دقیقه
    int timeBC = (int)((tC - tB) / 60); // دقیقه
    
    if(timeAB <= 0 || timeBC <= 0) return 1.0;
    
    // نسبت تقارن: هر چه نزدیک‌تر به 1، تقارن بیشتر
    // CRITICAL FIX: Validate division operands
    double ratio = 0;
    if(timeAB > 0 && timeBC > 0) {
        ratio = (timeAB > timeBC) ? ((double)timeBC / timeAB) : ((double)timeAB / timeBC);
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateTimeSymmetry: Invalid time values - AB=", timeAB, ", BC=", timeBC);
        #endif
    }
    
    return ratio;
}

//+------------------------------------------------------------------+
//| Frequency Search Result Structure                               |
//| ساختار نتیجه جستجوی فرکانس                                      |
//+------------------------------------------------------------------+
struct FrequencySearchResult {
    double frequency;        // فرکانس
    int frequencyIndex;      // ایندکس در آرایه
    int targetStep;          // گام هدف (3، 5، یا 7)
    double errorPercent;     // درصد خطا
    double calculatedD;      // قیمت محاسبه شده D
    double targetPrice;      // قیمت هدف (Step N)
    double errorPips;        // خطا به پیپ
    double gannAngle;        // زاویه Gann موج AB
    double angleWeight;      // ضریب وزنی زاویه
    double timeSymmetry;     // تقارن زمانی AB/BC
    double totalScore;       // امتیاز کل (کم‌تر = بهتر)
};

//+------------------------------------------------------------------+
//| Analyze Harmonic Properties (Scientific Analysis)               |
//| تحلیل ویژگی‌های هارمونیک (تحلیل علمی)                           |
//| Returns: Detailed analysis of harmonic ratios                   |
//+------------------------------------------------------------------+
void AnalyzeHarmonicProperties(WaveAnalysis &waves)
{
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🎵 HARMONIC ANALYSIS (SCIENTIFIC)");
    Print("========================================");
    
    // ========================================
    // 1. HARMONIC MEAN ANALYSIS
    // ========================================
    if(waves.XA_Speed > 0 && waves.AB_Speed > 0 && waves.BC_Speed > 0) {
        double recipSum = (1.0/waves.XA_Speed) + (1.0/waves.AB_Speed) + (1.0/waves.BC_Speed);
        double harmonicMean = 3.0 / recipSum;
        double arithmeticMean = (waves.XA_Speed + waves.AB_Speed + waves.BC_Speed) / 3.0;
        double geometricMean = MathPow(waves.XA_Speed * waves.AB_Speed * waves.BC_Speed, 1.0/3.0);
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("📊 PYTHAGOREAN MEANS:");
        Print("   Harmonic Mean:   ", DoubleToString(harmonicMean, 2), " pips/min");
        Print("   Geometric Mean:  ", DoubleToString(geometricMean, 2), " pips/min");
        Print("   Arithmetic Mean: ", DoubleToString(arithmeticMean, 2), " pips/min");
        Print("   Relationship: HM ≤ GM ≤ AM ", 
        #endif
              (harmonicMean <= geometricMean && geometricMean <= arithmeticMean) ? "✅" : "❌");
        
        double meanRatio = harmonicMean / arithmeticMean;
        #ifdef ENABLE_DEBUG_LOGS
        Print("   HM/AM Ratio: ", DoubleToString(meanRatio, 3));
        #endif
        if(meanRatio > 0.9) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → ✅ EXCELLENT: Very consistent speeds");
            #endif
        } else if(meanRatio > 0.8) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → ✓ GOOD: Moderately consistent speeds");
            #endif
        } else if(meanRatio > 0.7) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → ⚠️ FAIR: Some speed variation");
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → ❌ POOR: High speed variation");
            #endif
        }
    }
    
    // ========================================
    // 2. GOLDEN RATIO ANALYSIS (PHI)
    // ========================================
    double phi = 1.618033988749;
    double phiInverse = 0.618033988749;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("📐 GOLDEN RATIO (φ = 1.618):");
    #endif
    
    // AB/XA ratio
    double phiDev_AB_XA = MathAbs(waves.AB_XA_Ratio - phiInverse);
    #ifdef ENABLE_DEBUG_LOGS
    Print("   AB/XA = ", DoubleToString(waves.AB_XA_Ratio, 3));
    #endif
    if(phiDev_AB_XA < 0.05) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   → ✨ GOLDEN RATIO (0.618) detected! Deviation: ", 
        #endif
              DoubleToString(phiDev_AB_XA * 100, 1), "%");
    } else {
        double phiDev_ext = MathAbs(waves.AB_XA_Ratio - phi);
        if(phiDev_ext < 0.08) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → ✨ PHI EXTENSION (1.618) detected! Deviation: ", 
            #endif
                  DoubleToString(phiDev_ext * 100, 1), "%");
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   → No Golden Ratio (deviation: ", DoubleToString(phiDev_AB_XA * 100, 1), "%)");
            #endif
        }
    }
    
    // BC/AB ratio
    double phiDev_BC_AB = MathAbs(waves.BC_AB_Ratio - phiInverse);
    #ifdef ENABLE_DEBUG_LOGS
    Print("   BC/AB = ", DoubleToString(waves.BC_AB_Ratio, 3));
    #endif
    if(phiDev_BC_AB < 0.05) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   → ✨ GOLDEN RATIO (0.618) detected! Deviation: ", 
        #endif
              DoubleToString(phiDev_BC_AB * 100, 1), "%");
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   → No Golden Ratio (deviation: ", DoubleToString(phiDev_BC_AB * 100, 1), "%)");
        #endif
    }
    
    // ========================================
    // 3. SUMMARY
    // ========================================
    int harmonicScore = 0;
    if(waves.XA_Speed > 0 && waves.AB_Speed > 0 && waves.BC_Speed > 0) {
        double recipSum = (1.0/waves.XA_Speed) + (1.0/waves.AB_Speed) + (1.0/waves.BC_Speed);
        double harmonicMean = 3.0 / recipSum;
        double arithmeticMean = (waves.XA_Speed + waves.AB_Speed + waves.BC_Speed) / 3.0;
        double meanRatio = harmonicMean / arithmeticMean;
        if(meanRatio > 0.9) harmonicScore++;
    }
    
    if(phiDev_AB_XA < 0.05 || phiDev_BC_AB < 0.05) harmonicScore++;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🎯 HARMONIC QUALITY: ", harmonicScore, "/2");
    #endif
    if(harmonicScore == 2) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⭐⭐ EXCELLENT: Strong harmonic properties");
        #endif
    } else if(harmonicScore == 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⭐ GOOD: Some harmonic properties");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ➡️ NORMAL: No special harmonic properties");
        #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    #endif
}

//+------------------------------------------------------------------+
//| Calculate Frequency Error for AB=CD Pattern                     |
//| محاسبه خطای فرکانس برای پترن AB=CD                              |
//| Returns: Error percentage (0 = perfect match)                   |
//| CRITICAL FIX: Added division by zero protection                 |
//+------------------------------------------------------------------+
double CalculateFrequencyError(double pA, double pB, double pC, 
                               double frequency, int targetStep,
                               double &calculatedD, double &targetPrice)
{
    // SECURITY: Validate AB distance to prevent division by zero
    double AB_Distance = MathAbs(pB - pA);
    double minDistance = GetCachedPoint() * 10; // Minimum 10 pips
    
    if(AB_Distance < minDistance) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFrequencyError: AB distance too small (", 
              DoubleToString(AB_Distance, Digits), ") - minimum ", 
              DoubleToString(minDistance, Digits), " required");
        #endif
        calculatedD = 0.0;
        targetPrice = 0.0;
        return 999.99; // Invalid error
    }
    
    // محاسبه مقادیر پایه
    // baseUnit = AB × (frequency / 100) معادل TH است
    bool isBullish = (pB > pA);
    double baseUnit = AB_Distance * (frequency / 100.0);
    
    // محاسبه D بر اساس قانون AB=CD
    // در پترن AB=CD: فاصله CD باید برابر فاصله AB باشه
    double pD;
    if(isBullish) {
        pD = pC + AB_Distance;
    } else {
        pD = pC - AB_Distance;
    }
    calculatedD = pD;
    
    // محاسبه قیمت هدف (Step N از C)
    // Step N = C + (N × baseUnit)
    double stepPrice;
    if(isBullish) {
        stepPrice = pC + (targetStep * baseUnit);
    } else {
        stepPrice = pC - (targetStep * baseUnit);
    }
    targetPrice = stepPrice;
    
    // محاسبه خطا: فاصله بین D و Step N
    // خطا به صورت درصد از AB نمایش داده میشه
    double error = MathAbs(pD - stepPrice);
    
    // CRITICAL FIX: Validate division operand
    double errorPercent = 0;
    if(MathAbs(AB_Distance) > 0.000001) {
        errorPercent = (error / AB_Distance) * 100.0;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CalculateFrequencyError: AB_Distance too small (", AB_Distance, ")");
        #endif
    }
    
    return errorPercent;
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci Deviation                                   |
//| محاسبه انحراف از نسبت‌های Fibonacci                             |
//| Returns: Minimum deviation from standard Fibonacci ratios       |
//+------------------------------------------------------------------+
double CalculateFibonacciDeviation(double ratio)
{
    // نسبت‌های استاندارد Fibonacci
    double fibRatios[9] = {0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618, 2.618};
    
    double minDeviation = 1000.0;
    for(int i = 0; i < 9; i++) {
        double deviation = MathAbs(ratio - fibRatios[i]);
        if(deviation < minDeviation) {
            minDeviation = deviation;
        }
    }
    
    return minDeviation;
}

//+------------------------------------------------------------------+
//| Find Optimal Frequency for XABCD Pattern - COMPLETE ANALYSIS    |
//| پیدا کردن بهترین فرکانس برای پترن XABCD - تحلیل کامل            |
//| Multi-factor scoring: error, wave analysis, Fibonacci, symmetry |
//+------------------------------------------------------------------+
int FindOptimalFrequencyForABCD(datetime tX, double pX, datetime tA, double pA, 
                                datetime tB, double pB, datetime tC, double pC,
                                FrequencySearchResult &results[],
                                double maxErrorPercent = 5.0)
{
    // پاکسازی آرایه نتایج
    ArrayResize(results, 0);
    
    double AB_Distance = MathAbs(pB - pA);
    if(AB_Distance <= 0) return 0;
    
    double pipSize = GetCachedPipSize();
    
    // ========================================
    // مرحله 1: تحلیل کامل موج (Wave Analysis)
    // ========================================
    WaveAnalysis waves = AnalyzeThreeWaves(tX, pX, tA, pA, tB, pB, tC, pC);
    
    // تحلیل ویژگی‌های هارمونیک (علمی)
    AnalyzeHarmonicProperties(waves);
    
    // محاسبه فرکانس پیشنهادی بر اساس تحلیل موج
    double suggestedFreq = CalculateFrequencyFromWaves(waves);
    
    // محاسبه سرعت و تقارن زمانی
    double speedRatio = CalculateMovementSpeed(tA, pA, tB, pB);
    double timeSymmetry = waves.timeSymmetry;  // استفاده از مقدار محاسبه شده در struct
    
    // محاسبه انحراف از Fibonacci
    double fibDeviation = CalculateFibonacciDeviation(waves.AB_XA_Ratio);
    
    // محاسبه ضریب Consolidation (انرژی جمع شده برای breakout)
    double consolidationFactor = CalculateConsolidationFactor(tA, tB, tC, waves);
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🔍 COMPLETE WAVE ANALYSIS (X-A-B-C):");
    Print("   Wave Distances: XA=", DoubleToString(waves.XA_Distance/pipSize, 1), 
          " | AB=", DoubleToString(waves.AB_Distance/pipSize, 1),
          " | BC=", DoubleToString(waves.BC_Distance/pipSize, 1), " pips");
    #ifdef ENABLE_DEBUG_LOGS
    Print("   Wave Speeds: XA=", DoubleToString(waves.XA_Speed, 2), 
          " | AB=", DoubleToString(waves.AB_Speed, 2),
          " | BC=", DoubleToString(waves.BC_Speed, 2), " pips/min");
    Print("   AB/XA Ratio: ", DoubleToString(waves.AB_XA_Ratio, 3), 
          " (Fib Dev: ", DoubleToString(fibDeviation, 3), ")");
    Print("   Speed Consistency: ", DoubleToString(waves.speedConsistency * 100, 1), "%");
    Print("   Time Symmetry: ", DoubleToString(timeSymmetry * 100, 1), "%");
    Print("   Consolidation Factor: ", DoubleToString(consolidationFactor * 100, 1), "% (Energy buildup)");
    Print("   Pattern Type: ", waves.isImpulsive ? "Impulsive" : (waves.isCorrectional ? "Correctional" : "Balanced"));
    Print("   Suggested Frequency: ", DoubleToString(suggestedFreq, 3), "%");
    Print("   Speed Ratio: ", DoubleToString(speedRatio, 2), "x");
    #endif
    
    // هشدار برای کیفیت پایین
    if(waves.speedConsistency < 0.5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚠️ WARNING: Low speed consistency - results may be unreliable");
        #endif
    } else if(waves.speedConsistency < 0.7) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚠️ CAUTION: Moderate speed consistency");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ✅ Good speed consistency");
        #endif
    }
    
    // هشدار برای consolidation بالا
    if(consolidationFactor > 0.7) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   🔥 HIGH CONSOLIDATION: Expect strong breakout - using larger steps");
        #endif
    } else if(consolidationFactor > 0.4) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚡ MODERATE CONSOLIDATION: Some energy buildup detected");
        #endif
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    #endif
    
    // ========================================
    // مرحله 2: تحلیل پیشرفته هارمونیک (Advanced Harmonic Analysis)
    // ========================================
    // استفاده از زاویه Gann که قبلاً محاسبه شده (از struct)
    double gannAngle = waves.AB_Angle;
    
    // محاسبه نسبت BC/AB برای تشخیص عمق اصلاح
    double bcToAbRatio = 0.0;
    if(waves.AB_Distance > 0) {
        bcToAbRatio = waves.BC_Distance / waves.AB_Distance;
    }
    
    // ========================================
    // 🎯 HARMONIC PATTERN RECOGNITION (Gartley, Bat, Butterfly, Crab)
    // ========================================
    // بر اساس نسبت‌های Fibonacci استاندارد
    string harmonicPattern = "NONE";
    double harmonicConfidence = 0.0;
    double prz_Frequency = 0.0;  // Potential Reversal Zone frequency
    
    // Gartley Pattern: AB/XA = 0.618, BC/AB = 0.382-0.886, CD = 1.272 extension of BC
    if(waves.AB_XA_Ratio >= 0.580 && waves.AB_XA_Ratio <= 0.660) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "GARTLEY";
            harmonicConfidence = 0.786;  // 78.6% retracement point
            prz_Frequency = 28.0 + (bcToAbRatio * 30.0);  // 28-58% range
        }
    }
    // Bat Pattern: AB/XA = 0.382-0.500, BC/AB = 0.382-0.886, CD = 1.618-2.618 extension
    else if(waves.AB_XA_Ratio >= 0.382 && waves.AB_XA_Ratio <= 0.500) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "BAT";
            harmonicConfidence = 0.886;  // 88.6% retracement point
            prz_Frequency = 35.0 + (bcToAbRatio * 25.0);  // 35-60% range
        }
    }
    // Butterfly Pattern: AB/XA = 0.786, BC/AB = 0.382-0.886, CD = 1.618-2.24 extension
    else if(waves.AB_XA_Ratio >= 0.750 && waves.AB_XA_Ratio <= 0.820) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "BUTTERFLY";
            harmonicConfidence = 1.272;  // 127.2% extension
            prz_Frequency = 45.0 + (bcToAbRatio * 35.0);  // 45-80% range
        }
    }
    // Crab Pattern: AB/XA = 0.382-0.618, BC/AB = 0.382-0.886, CD = 2.24-3.618 extension
    else if(waves.AB_XA_Ratio >= 0.382 && waves.AB_XA_Ratio <= 0.618) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "CRAB";
            harmonicConfidence = 1.618;  // 161.8% extension
            prz_Frequency = 50.0 + (bcToAbRatio * 40.0);  // 50-90% range
        }
    }
    
    // ========================================
    // 📐 ANDREWS PITCHFORK MEDIAN LINE ANALYSIS
    // ========================================
    // قانون 80%: قیمت 80% مواقع به خط میانی (Median Line) برمیگرده
    // محاسبه فاصله از Median Line برای تعیین احتمال بازگشت
    double medianPrice = (pX + pA + pB) / 3.0;  // Median of X, A, B
    double currentDistanceFromMedian = MathAbs(pC - medianPrice);
    double maxDistanceFromMedian = MathMax(MathAbs(pA - medianPrice), MathAbs(pB - medianPrice));
    
    double medianLineDeviation = 0.0;
    if(maxDistanceFromMedian > 0) {
        medianLineDeviation = currentDistanceFromMedian / maxDistanceFromMedian;
    }
    
    // اگر قیمت خیلی دور از Median باشه (>80%)، احتمال بازگشت قوی بالاست
    bool strongMedianLinePull = (medianLineDeviation > 0.8);
    bool moderateMedianLinePull = (medianLineDeviation > 0.5 && medianLineDeviation <= 0.8);
    
    // تنظیم فرکانس بر اساس فاصله از Median Line
    double medianLineFrequency = 0.0;
    if(strongMedianLinePull) {
        // قیمت خیلی دور از Median → انتظار بازگشت قوی → فرکانس بالاتر
        medianLineFrequency = 55.0 + (medianLineDeviation * 30.0);  // 55-85% range
    } else if(moderateMedianLinePull) {
        // قیمت متوسط دور از Median → بازگشت متوسط → فرکانس متوسط
        medianLineFrequency = 35.0 + (medianLineDeviation * 30.0);  // 35-65% range
    }
    
    // ========================================
    // 🔄 AB=CD PATTERN VALIDATION
    // ========================================
    // قانون AB=CD: BC باید 61.8% retracement از AB باشه
    //              CD باید 127.2% extension از BC باشه
    bool isValidABCD = false;
    double abcdScore = 0.0;
    
    // بررسی BC retracement (باید نزدیک 0.618 باشه)
    double bcRetracementError = MathAbs(bcToAbRatio - 0.618);
    if(bcRetracementError < 0.15) {  // تلرانس ±15%
        isValidABCD = true;
        abcdScore = 1.0 - (bcRetracementError / 0.15);  // 0-1 score
    }
    
    // شناسایی الگوی Impulsive قوی و متوسط
    bool isStrongImpulsive = (gannAngle > 75.0 && consolidationFactor < 0.1);
    bool isMediumImpulsive = (gannAngle >= 50.0 && gannAngle <= 75.0 && consolidationFactor < 0.1);
    bool hasDeepRetracement = (bcToAbRatio > 0.7);
    bool hasGoodTimeSymmetry = (timeSymmetry > 0.8);
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🎯 ADVANCED HARMONIC & PITCHFORK ANALYSIS:");
    Print("========================================");
    
    // Harmonic Pattern Detection
    if(harmonicPattern != "NONE") {
        #ifdef ENABLE_DEBUG_LOGS
        Print("📊 HARMONIC PATTERN: ", harmonicPattern);
        Print("   AB/XA Ratio: ", DoubleToString(waves.AB_XA_Ratio, 3));
        Print("   BC/AB Ratio: ", DoubleToString(bcToAbRatio, 3));
        Print("   Confidence Level: ", DoubleToString(harmonicConfidence, 3));
        Print("   PRZ Frequency: ", DoubleToString(prz_Frequency, 1), "%");
        Print("   → Using harmonic-based frequency selection");
        #endif
    }
    
    // Median Line Analysis
    #ifdef ENABLE_DEBUG_LOGS
    Print("📐 ANDREWS PITCHFORK (Median Line):");
    Print("   Median Price: ", DoubleToString(medianPrice, Digits));
    Print("   Distance from Median: ", DoubleToString(medianLineDeviation * 100, 1), "%");
    #endif
    if(strongMedianLinePull) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   🎯 STRONG PULL: Price far from median (>80%)");
        Print("   → Expect strong reversal to median");
        Print("   → Median Frequency: ", DoubleToString(medianLineFrequency, 1), "%");
        #endif
    } else if(moderateMedianLinePull) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚡ MODERATE PULL: Price moderately far (50-80%)");
        Print("   → Median Frequency: ", DoubleToString(medianLineFrequency, 1), "%");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ✓ Near Median: Price close to equilibrium");
        #endif
    }
    
    // AB=CD Validation
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 AB=CD PATTERN VALIDATION:");
    Print("   BC Retracement: ", DoubleToString(bcToAbRatio, 3), " (Target: 0.618)");
    Print("   Error: ", DoubleToString(bcRetracementError, 3));
    #endif
    if(isValidABCD) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ✅ VALID AB=CD: Score ", DoubleToString(abcdScore * 100, 1), "%");
        Print("   → Using AB=CD frequency rules");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("   ⚠️ Not a classic AB=CD pattern");
        #endif
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    
    // Original Impulsive Pattern Detection
    if(isStrongImpulsive) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("🚀 STRONG IMPULSIVE PATTERN DETECTED:");
        Print("   Gann Angle: ", DoubleToString(gannAngle, 2), "° (>75°)");
        Print("   Consolidation: ", DoubleToString(consolidationFactor * 100, 1), "% (<10%)");
        Print("   BC/AB Ratio: ", DoubleToString(bcToAbRatio, 3));
        #endif
        if(hasDeepRetracement) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   Deep Retracement: YES - Expect strong continuation");
            #endif
        }
        #ifdef ENABLE_DEBUG_LOGS
        Print("   → Adjusting scoring: Prefer higher frequencies (50-70% range)");
        Print("   → Reducing penalties for low consistency and time symmetry");
        #endif
    }
    else if(isMediumImpulsive) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚡ MEDIUM IMPULSIVE PATTERN DETECTED:");
        Print("   Gann Angle: ", DoubleToString(gannAngle, 2), "° (50-75°)");
        Print("   Consolidation: ", DoubleToString(consolidationFactor * 100, 1), "% (<10%)");
        Print("   BC/AB Ratio: ", DoubleToString(bcToAbRatio, 3));
        Print("   Time Symmetry: ", DoubleToString(timeSymmetry * 100, 1), "%");
        #endif
        if(hasGoodTimeSymmetry) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   Good Time Symmetry: Pattern is reliable");
            #endif
        }
        #ifdef ENABLE_DEBUG_LOGS
        Print("   → Adjusting scoring: Prefer frequencies (35-50% range)");
        Print("   → Reducing penalties for low consistency");
        #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    #endif
    
    // ========================================
    // مرحله 3: تعیین گام‌های هدف با اولویت‌بندی
    // ========================================
    int targetSteps[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    int primarySteps[3] = {3, 5, 7}; // مهم‌ترین گام‌ها
    
    // برای الگوی Impulsive قوی، اولویت به گام‌های 2-3-4 داده میشه
    if(isStrongImpulsive) {
        primarySteps[0] = 2;
        primarySteps[1] = 3;
        primarySteps[2] = 4;
    }
    // برای الگوی Impulsive متوسط، اولویت به گام‌های 2-3-5 داده میشه
    else if(isMediumImpulsive) {
        primarySteps[0] = 2;
        primarySteps[1] = 3;
        primarySteps[2] = 5;
    }
    
    // ========================================
    // مرحله 4: جمع‌آوری فرکانس‌های candidate
    // ========================================
    bool candidateFreqs[76]; // TH3_FREQUENCY_COUNT = 76 (extended to 120%)
    ArrayInitialize(candidateFreqs, false);
    
    // روش 1: بر اساس فرمول ریاضی (100/N)
    for(int stepIdx = 0; stepIdx < 3; stepIdx++)
    {
        int targetStep = primarySteps[stepIdx];
        double idealFreq = 100.0 / targetStep;
        
        int closestIdx = 0;
        double minDiff = 1000.0;
        
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
            double diff = MathAbs(TH3_TEST_FREQUENCIES[i] - idealFreq);
            if(diff < minDiff)
            {
                minDiff = diff;
                closestIdx = i;
            }
        }
        
        // Mark ±5 فرکانس اطراف
        int startIdx = MathMax(0, closestIdx - 5);
        int endIdx = MathMin(TH3_FREQUENCY_COUNT - 1, closestIdx + 5);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            candidateFreqs[i] = true;
        }
    }
    
    // روش 2: بر اساس تحلیل موج (suggested frequency)
    if(suggestedFreq > 0 && suggestedFreq <= 100.0)
    {
        int closestIdx = 0;
        double minDiff = 1000.0;
        
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
            double diff = MathAbs(TH3_TEST_FREQUENCIES[i] - suggestedFreq);
            if(diff < minDiff)
            {
                minDiff = diff;
                closestIdx = i;
            }
        }
        
        // Mark ±3 فرکانس اطراف suggested frequency
        int startIdx = MathMax(0, closestIdx - 3);
        int endIdx = MathMin(TH3_FREQUENCY_COUNT - 1, closestIdx + 3);
        
        for(int i = startIdx; i <= endIdx; i++)
        {
            candidateFreqs[i] = true;
        }
    }
    
    // روش 3: برای الگوی Impulsive قوی، محدوده 50-70% رو هم اضافه کن
    if(isStrongImpulsive) {
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
            if(TH3_TEST_FREQUENCIES[i] >= 50.0 && TH3_TEST_FREQUENCIES[i] <= 70.0)
            {
                candidateFreqs[i] = true;
            }
        }
    }
    // روش 4: برای الگوی Impulsive متوسط، محدوده 35-50% رو هم اضافه کن
    else if(isMediumImpulsive) {
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
            if(TH3_TEST_FREQUENCIES[i] >= 35.0 && TH3_TEST_FREQUENCIES[i] <= 50.0)
            {
                candidateFreqs[i] = true;
            }
        }
    }
    
    // ========================================
    // مرحله 5: تست و امتیازدهی چندبعدی
    // ========================================
    for(int freqIdx = 0; freqIdx < TH3_FREQUENCY_COUNT; freqIdx++)
    {
        if(!candidateFreqs[freqIdx]) continue;
        
        double testFreq = TH3_TEST_FREQUENCIES[freqIdx];
        
        for(int stepIdx = 0; stepIdx < 10; stepIdx++)
        {
            int testStep = targetSteps[stepIdx];
            double calcD, targetPrice;
            
            double errorPercent = CalculateFrequencyError(pA, pB, pC, testFreq, 
                                                          testStep, calcD, targetPrice);
            
            // ========================================
            // امتیازدهی چندبعدی (Multi-factor Scoring)
            // با استفاده از وزن‌های یادگیری شده
            // ========================================
            
            // دریافت وزن‌های یادگیری شده
            LearnedWeights learnedWeights = GetLearnedWeights();
            
            // 1. اولویت Step (با وزن یادگیری شده)
            double stepPriority = 1.0;
            if(testStep == 5) {
                stepPriority = learnedWeights.step5Priority;  // یادگیری شده
            } else if(testStep == 3 || testStep == 7) {
                stepPriority = learnedWeights.step3_7Priority;  // یادگیری شده
            } else if(testStep == 1) {
                stepPriority = learnedWeights.step1Priority;  // یادگیری شده
            }
            
            // 2. خطای ریاضی (با وزن یادگیری شده)
            double errorScore = errorPercent * learnedWeights.errorWeight;
            
            // 3. ثبات سرعت (با وزن یادگیری شده)
            // کم‌تر = بهتر، پس (1 - consistency) × 20
            // برای الگوی Impulsive قوی و متوسط، penalty کمتری بده
            double speedConsistencyWeight = learnedWeights.speedConsistencyWeight;
            if(isStrongImpulsive) {
                speedConsistencyWeight *= 0.3;  // کاهش 70% penalty
            }
            else if(isMediumImpulsive) {
                speedConsistencyWeight *= 0.5;  // کاهش 50% penalty
            }
            double speedScore = (1.0 - waves.speedConsistency) * 20.0 * speedConsistencyWeight;
            
            // 4. تقارن زمانی (با وزن یادگیری شده)
            // کم‌تر = بهتر، پس (1 - symmetry) × 100
            // برای الگوی Impulsive با اصلاح عمیق، penalty کمتری بده
            // برای الگوی متوسط با تقارن خوب، بونوس بده
            double timeSymmetryWeight = learnedWeights.timeSymmetryWeight;
            if(isStrongImpulsive && hasDeepRetracement) {
                timeSymmetryWeight *= 0.2;  // کاهش 80% penalty
            }
            else if(isMediumImpulsive && hasGoodTimeSymmetry) {
                timeSymmetryWeight *= 0.5;  // کاهش 50% penalty (تقارن خوب = الگو قابل اعتماد)
            }
            double timeScore = (1.0 - timeSymmetry) * 100.0 * timeSymmetryWeight;
            
            // 5. انحراف از Fibonacci (با وزن یادگیری شده)
            // کم‌تر = بهتر
            double fibScore = fibDeviation * 100.0 * learnedWeights.fibonacciWeight;
            
            // 6. تطابق با suggested frequency (با وزن یادگیری شده)
            double freqDeviation = 0.0;
            if(suggestedFreq > 0) {
                freqDeviation = MathAbs(testFreq - suggestedFreq) / suggestedFreq;
            }
            double freqScore = freqDeviation * 100.0 * learnedWeights.freqDeviationWeight;
            
            // 7. Consolidation factor (با وزن یادگیری شده)
            // اگر consolidation بالا باشه، فرکانس بالاتر (گام بزرگتر) ترجیح داده میشه
            // پس فرکانس‌های پایین‌تر penalty می‌گیرن
            double consolidationPenalty = 0.0;
            if(consolidationFactor > 0.3) {
                // اگر فرکانس کمتر از suggested باشه، penalty بده
                if(testFreq < suggestedFreq) {
                    double freqRatio = testFreq / suggestedFreq;
                    consolidationPenalty = (1.0 - freqRatio) * consolidationFactor * 100.0 * learnedWeights.consolidationWeight;
                }
            }
            
            // 8. اولویت Step Priority (با وزن یادگیری شده)
            // این وزن کل امتیاز رو ضرب میکنه
            double stepPriorityScore = stepPriority * learnedWeights.stepPriorityWeight;
            
            // 9. بونوس برای فرکانس‌های بالاتر در الگوی Impulsive
            double impulsiveBonus = 0.0;
            if(isStrongImpulsive) {
                // اگر فرکانس در محدوده 50-70% باشه، بونوس بده (امتیاز کمتر = بهتر)
                if(testFreq >= 50.0 && testFreq <= 70.0) {
                    impulsiveBonus = -50.0;  // بونوس منفی = امتیاز بهتر
                }
                // اگر فرکانس خیلی پایین باشه، penalty بده
                else if(testFreq < 30.0) {
                    impulsiveBonus = 100.0;  // penalty برای فرکانس‌های پایین
                }
            }
            else if(isMediumImpulsive) {
                // اگر فرکانس در محدوده 35-50% باشه، بونوس بده
                if(testFreq >= 35.0 && testFreq <= 50.0) {
                    impulsiveBonus = -30.0;  // بونوس متوسط
                }
                // اگر فرکانس خیلی پایین باشه، penalty بده
                else if(testFreq < 25.0) {
                    impulsiveBonus = 80.0;  // penalty برای فرکانس‌های پایین
                }
                // اگر تقارن زمانی خوب باشه، بونوس اضافی بده
                if(hasGoodTimeSymmetry && testFreq >= 40.0 && testFreq <= 45.0) {
                    impulsiveBonus -= 20.0;  // بونوس اضافی برای تقارن خوب
                }
            }
            
            // ========================================
            // 10. 🎯 HARMONIC PATTERN BONUS (NEW)
            // ========================================
            double harmonicBonus = 0.0;
            if(harmonicPattern != "NONE" && prz_Frequency > 0) {
                // اگر فرکانس نزدیک PRZ باشه، بونوس بده
                double przDeviation = MathAbs(testFreq - prz_Frequency) / prz_Frequency;
                if(przDeviation < 0.15) {  // ±15% tolerance
                    harmonicBonus = -40.0 * (1.0 - przDeviation / 0.15);  // Max -40 bonus
                    
                    // بونوس اضافی برای الگوهای قوی‌تر
                    if(harmonicPattern == "CRAB") harmonicBonus *= 1.3;  // Crab = قوی‌ترین
                    else if(harmonicPattern == "BUTTERFLY") harmonicBonus *= 1.2;
                    else if(harmonicPattern == "BAT") harmonicBonus *= 1.1;
                }
            }
            
            // ========================================
            // 11. 📐 MEDIAN LINE BONUS (NEW)
            // ========================================
            double medianLineBonus = 0.0;
            if(medianLineFrequency > 0) {
                // اگر فرکانس نزدیک Median Line Frequency باشه، بونوس بده
                double medianDeviation = MathAbs(testFreq - medianLineFrequency) / medianLineFrequency;
                if(medianDeviation < 0.20) {  // ±20% tolerance
                    if(strongMedianLinePull) {
                        // قیمت خیلی دور از Median → بونوس قوی
                        medianLineBonus = -35.0 * (1.0 - medianDeviation / 0.20);  // Max -35 bonus
                    } else if(moderateMedianLinePull) {
                        // قیمت متوسط دور از Median → بونوس متوسط
                        medianLineBonus = -20.0 * (1.0 - medianDeviation / 0.20);  // Max -20 bonus
                    }
                }
            }
            
            // ========================================
            // 12. 🔄 AB=CD VALIDATION BONUS (NEW)
            // ========================================
            double abcdBonus = 0.0;
            if(isValidABCD) {
                // الگوی AB=CD معتبر → بونوس بر اساس score
                // فرکانس باید در محدوده 25-45% باشه (کلاسیک AB=CD)
                if(testFreq >= 25.0 && testFreq <= 45.0) {
                    abcdBonus = -30.0 * abcdScore;  // Max -30 bonus
                    
                    // بونوس اضافی اگر نزدیک 38.2% باشه (Fibonacci 0.382)
                    if(testFreq >= 36.0 && testFreq <= 40.0) {
                        abcdBonus -= 15.0;  // Extra -15 bonus
                    }
                }
            }
            
            // ========================================
            // 13. 🚀 ACCELERATION FACTOR (NEW - HIGH PRIORITY)
            // ========================================
            double accelerationScore = 0.0;
            
            // شتاب مثبت = اصلاح در حال تند شدن → انتظار breakout قوی‌تر
            if(waves.AB_to_BC_Acceleration > 0.001) {
                // هر چه شتاب بیشتر، فرکانس بالاتر
                double accelRatio = MathMin(waves.AB_to_BC_Acceleration / 0.01, 1.0);
                accelerationScore = -20.0 * accelRatio;  // Max -20 bonus
            }
            // شتاب منفی = اصلاح در حال کند شدن → انتظار breakout ضعیف‌تر
            else if(waves.AB_to_BC_Acceleration < -0.001) {
                double accelRatio = MathMin(MathAbs(waves.AB_to_BC_Acceleration) / 0.01, 1.0);
                accelerationScore = 20.0 * accelRatio;  // Max +20 penalty
            }
            
            // ========================================
            // 14. 💪 RELATIVE STRENGTH FACTOR (NEW - HIGH PRIORITY)
            // ========================================
            double strengthScore = 0.0;
            
            // قدرت مطلق BC
            if(waves.BC_RelativeStrength > 2.0) {
                // BC خیلی قوی → انتظار D قوی‌تر
                strengthScore = -25.0;
            } else if(waves.BC_RelativeStrength < 1.0) {
                // BC ضعیف → انتظار D ضعیف‌تر
                strengthScore = 25.0;
            }
            
            // نسبت قدرت BC به AB (momentum change)
            double strengthRatio = waves.BC_RelativeStrength / MathMax(waves.AB_RelativeStrength, 0.1);
            if(strengthRatio > 1.2) {
                // BC قوی‌تر از AB → momentum در حال افزایش
                strengthScore -= 15.0;
            } else if(strengthRatio < 0.8) {
                // BC ضعیف‌تر از AB → momentum در حال کاهش
                strengthScore += 15.0;
            }
            
            // ========================================
            // 15. 🎯 CONFIDENCE SCORE SYSTEM (NEW - CRITICAL)
            // ========================================
            double confidence = 100.0;
            
            // کاهش confidence بر اساس عوامل ضعف
            if(waves.speedConsistency < 0.5) confidence -= 30.0;  // ثبات پایین
            if(timeSymmetry < 0.6) confidence -= 20.0;  // تقارن پایین
            if(fibDeviation > 0.15) confidence -= 15.0;  // دور از Fibonacci
            if(errorPercent > 3.0) confidence -= 25.0;  // خطای بالا
            
            // افزایش confidence بر اساس تاییدها
            if(harmonicPattern != "NONE") confidence += 15.0;  // الگوی هارمونیک
            if(isValidABCD) confidence += 10.0;  // AB=CD معتبر
            if(waves.BC_RelativeStrength > 2.0) confidence += 10.0;  // قدرت بالا
            if(MathAbs(waves.AB_to_BC_Acceleration) < 0.001) confidence += 5.0;  // شتاب ثابت
            
            // محدود کردن به 0-100
            if(confidence < 0) confidence = 0;
            if(confidence > 100) confidence = 100;
            
            // penalty برای confidence پایین
            double confidencePenalty = 0.0;
            if(confidence < 50.0) {
                confidencePenalty = 50.0 * (1.0 - confidence / 50.0);  // Max +50 penalty
            }
            
            // ========================================
            // 16. 🎵 HARMONIC MEAN CONSISTENCY (SCIENTIFIC - PYTHAGOREAN)
            // ========================================
            // اصل علمی: Harmonic Mean برای سرعت‌ها درست است
            // منبع: ریاضیات فیثاغورث، فیزیک نیوتن
            double harmonicMeanScore = 0.0;
            
            if(waves.XA_Speed > 0 && waves.AB_Speed > 0 && waves.BC_Speed > 0) {
                // محاسبه Harmonic Mean
                double recipSum = (1.0/waves.XA_Speed) + (1.0/waves.AB_Speed) + (1.0/waves.BC_Speed);
                double harmonicMean = 3.0 / recipSum;
                
                // محاسبه Arithmetic Mean
                double arithmeticMean = (waves.XA_Speed + waves.AB_Speed + waves.BC_Speed) / 3.0;
                
                // نسبت Harmonic به Arithmetic
                // اگر نزدیک 1.0 باشد → سرعت‌ها ثابت → الگوی قابل اعتماد
                double meanRatio = harmonicMean / arithmeticMean;
                
                // بونوس برای ثبات بالا (meanRatio > 0.9)
                if(meanRatio > 0.9) {
                    harmonicMeanScore = -15.0 * ((meanRatio - 0.9) / 0.1);  // Max -15 bonus
                }
                // penalty برای ثبات پایین (meanRatio < 0.7)
                else if(meanRatio < 0.7) {
                    harmonicMeanScore = 15.0 * ((0.7 - meanRatio) / 0.3);  // Max +15 penalty
                }
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("   Harmonic Mean: ", DoubleToString(harmonicMean, 2), " pips/min");
                Print("   Arithmetic Mean: ", DoubleToString(arithmeticMean, 2), " pips/min");
                Print("   Ratio: ", DoubleToString(meanRatio, 3), 
                      " (", meanRatio > 0.9 ? "✅ Consistent" : (meanRatio < 0.7 ? "⚠️ Inconsistent" : "➡️ Moderate"), ")");
                #endif
            }
            
            // ========================================
            // 17. 📐 PHI RATIO BONUS (SCIENTIFIC - GOLDEN RATIO)
            // ========================================
            // اصل علمی: نسبت طلایی (φ = 0.618) در بازار کار می‌کند
            // دلیل: Self-Fulfilling Prophecy (میلیون‌ها تریدر از آن استفاده می‌کنند)
            // منبع: اقلیدس (300 قبل از میلاد)، تحلیل آماری بازارهای واقعی
            double phiRatioScore = 0.0;
            
            double phi = 1.618033988749;
            double phiInverse = 0.618033988749;
            
            // بررسی AB/XA نزدیک به 0.618
            double phiDeviation_AB_XA = MathAbs(waves.AB_XA_Ratio - phiInverse);
            if(phiDeviation_AB_XA < 0.05) {  // ±5% tolerance
                // هر چه نزدیک‌تر، بونوس بیشتر
                phiRatioScore -= 20.0 * (1.0 - phiDeviation_AB_XA / 0.05);  // Max -20 bonus
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Golden Ratio detected in AB/XA: ", DoubleToString(waves.AB_XA_Ratio, 3));
                #endif
            }
            
            // بررسی BC/AB نزدیک به 0.618
            double phiDeviation_BC_AB = MathAbs(waves.BC_AB_Ratio - phiInverse);
            if(phiDeviation_BC_AB < 0.05) {  // ±5% tolerance
                phiRatioScore -= 15.0 * (1.0 - phiDeviation_BC_AB / 0.05);  // Max -15 bonus
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Golden Ratio detected in BC/AB: ", DoubleToString(waves.BC_AB_Ratio, 3));
                #endif
            }
            
            // بررسی AB/XA نزدیک به 1.618 (φ)
            double phiDeviation_AB_XA_ext = MathAbs(waves.AB_XA_Ratio - phi);
            if(phiDeviation_AB_XA_ext < 0.08) {  // ±8% tolerance (کمی بیشتر برای extension)
                phiRatioScore -= 12.0 * (1.0 - phiDeviation_AB_XA_ext / 0.08);  // Max -12 bonus
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Phi Extension detected in AB/XA: ", DoubleToString(waves.AB_XA_Ratio, 3));
                #endif
            }
            
            // امتیاز کل (کمتر = بهتر)
            // فرمول نهایی با 2 فاکتور علمی جدید
            double totalScore = (errorScore + speedScore + timeScore + fibScore + freqScore + consolidationPenalty) 
                              * stepPriority * (1.0 + stepPriorityScore) 
                              + impulsiveBonus + harmonicBonus + medianLineBonus + abcdBonus
                              + accelerationScore + strengthScore + confidencePenalty
                              + harmonicMeanScore + phiRatioScore;  // ← 2 فاکتور علمی جدید
            
            // ذخیره نتیجه - PERF FIX: Reserve extra slots
            int size = ArraySize(results);
            ArrayResize(results, size + 1, 128);
            
            results[size].frequency = testFreq;
            results[size].frequencyIndex = freqIdx;
            results[size].targetStep = testStep;
            results[size].errorPercent = errorPercent;
            results[size].calculatedD = calcD;
            results[size].targetPrice = targetPrice;
            results[size].errorPips = MathAbs(calcD - targetPrice) / pipSize;
            results[size].gannAngle = speedRatio;
            results[size].angleWeight = waves.speedConsistency;
            results[size].timeSymmetry = timeSymmetry;
            results[size].totalScore = totalScore;
        }
    }
    
    // ========================================
    // مرحله 6: مرتب‌سازی بر اساس امتیاز کل
    // ========================================
    int resultCount = ArraySize(results);
    for(int i = 0; i < resultCount - 1; i++)
    {
        int minIdx = i;
        for(int j = i + 1; j < resultCount; j++)
        {
            if(results[j].totalScore < results[minIdx].totalScore)
            {
                minIdx = j;
            }
        }
        
        if(minIdx != i)
        {
            FrequencySearchResult temp = results[i];
            results[i] = results[minIdx];
            results[minIdx] = temp;
        }
    }
    
    // ========================================
    // مرحله 7: فیلتر کردن نتایج
    // ========================================
    int goodResults = 0;
    for(int i = 0; i < resultCount; i++)
    {
        if(results[i].errorPercent <= maxErrorPercent)
        {
            goodResults++;
        }
        else
        {
            break;
        }
    }
    
    if(goodResults > 0)
    {
        ArrayResize(results, goodResults);
        return goodResults;
    }
    else
    {
        // هیچ نتیجه با خطای کمتر از threshold نبود
        // بهترین 10 نتیجه رو نگه دار
        int keepCount = MathMin(10, resultCount);
        ArrayResize(results, keepCount);
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ No results with error < ", maxErrorPercent, "%, keeping best ", keepCount, " results");
        #endif
        
        return keepCount;
    }
}

//+------------------------------------------------------------------+
//| Auto-Select Best Frequency for Current AB=CD Pattern            |
//| انتخاب خودکار بهترین فرکانس برای پترن AB=CD فعلی                |
//+------------------------------------------------------------------+
bool AutoSelectBestFrequency(string patternName)
{
    // پیدا کردن نقاط A، B، C از پترن
    string lineAB = patternName + "_Line_AB";
    string lineBC = patternName + "_Line_BC";
    
    if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Pattern not found: ", patternName);
        #endif
        return false;
    }
    
    datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
    double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
    datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
    double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
    datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
    double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
    
    // CRITICAL FIX: Validate all retrieved values
    if(tA <= 0 || tB <= 0 || tC <= 0 || pA <= 0 || pB <= 0 || pC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Invalid pattern data");
        #endif
        return false;
    }
    
    // For auto-select, we don't have X point stored in pattern
    // Estimate X based on typical wave pattern structure
    // برای انتخاب خودکار، نقطه X در پترن ذخیره نشده
    // تخمین X بر اساس ساختار معمول الگوی موجی
    
    // محاسبه تعداد کندل‌های موج AB
    int barA = iBarShift(_Symbol, _Period, tA);
    int barB = iBarShift(_Symbol, _Period, tB);
    int AB_Bars = barA - barB; // A قدیمی‌تر از B است
    if(AB_Bars < 1) AB_Bars = 1;
    
    // تخمین زمان X: یک موج قبل از A (با فرض تقارن زمانی)
    int barX = barA + AB_Bars; // X قدیمی‌تر از A
    datetime tX = iTime(_Symbol, 0, barX);
    
    // اعتبارسنجی زمان
    if(tX <= 0 || tX >= tA) {
        // fallback: استفاده از فاصله زمانی AB
        tX = tA - (tB - tA);
        if(tX <= 0) tX = tA - 3600; // حداقل 1 ساعت قبل
    }
    
    // تخمین قیمت X بر اساس ساختار موجی
    // در الگوی AB=CD معمولی: X و A در یک طرف، B و D در طرف دیگر
    bool isABBullish = (pB > pA);
    double AB_Distance = MathAbs(pB - pA);
    double pX;
    
    if(isABBullish) {
        // اگر AB صعودی است (A→B رو به بالا)
        // پس XA باید نزولی باشه (X→A رو به پایین)
        // یعنی X بالاتر از A است
        pX = pA + (AB_Distance * 0.618); // فرض: XA حدود 61.8% از AB (Fibonacci)
    } else {
        // اگر AB نزولی است (A→B رو به پایین)
        // پس XA باید صعودی باشه (X→A رو به بالا)
        // یعنی X پایین‌تر از A است
        pX = pA - (AB_Distance * 0.618); // فرض: XA حدود 61.8% از AB
    }
    
    // اعتبارسنجی قیمت: X نباید خیلی دور یا منفی باشه
    if(pX <= 0) {
        if(isABBullish) {
            pX = pA + (AB_Distance * 0.5); // fallback: 50% از AB
        } else {
            pX = pA - (AB_Distance * 0.5);
        }
    }
    
    // اگر هنوز مشکل داره، از قیمت A استفاده کن (بدترین حالت)
    if(pX <= 0) pX = pA;
    
    // جستجوی بهترین فرکانس (با 4 نقطه)
    // اگر X تخمینی خیلی نزدیک به A باشه، تحلیل 3 موجی معتبر نیست
    FrequencySearchResult results[];
    ArrayResize(results, 0); // Initialize array
    
    bool hasValidX = (MathAbs(pX - pA) > MathAbs(pB - pA) * 0.1); // X باید حداقل 10% AB از A فاصله داشته باشه
    
    int resultCount;
    if(hasValidX) {
        // تحلیل کامل با 4 نقطه
        resultCount = FindOptimalFrequencyForABCD(tX, pX, tA, pA, tB, pB, tC, pC, results, 5.0);
    } else {
        // تحلیل ساده بدون X (فقط بر اساس AB و BC)
        // در این حالت، X = A قرار میدیم و pattern quality کمتر اهمیت داره
        resultCount = FindOptimalFrequencyForABCD(tA, pA, tA, pA, tB, pB, tC, pC, results, 5.0);
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ X point estimation not reliable, using simplified analysis");
        #endif
    }
    
    if(resultCount == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ No suitable frequency found (error > 5%)");
        #endif
        return false;
    }
    
    // نمایش نتایج با جزئیات کامل
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🔍 FREQUENCY SEARCH RESULTS");
    Print("Pattern: ", patternName);
    Print("AB Distance: ", DoubleToString(MathAbs(pB - pA), Digits), " (", 
          DoubleToString(MathAbs(pB - pA) / ((Digits == 3 || Digits == 5) ? Point * 10 : Point), 1), " pips)");
    Print("========================================");
    Print("🎯 BEST MATCH:");
    Print("   Frequency: ", DoubleToString(results[0].frequency, 3), "% (Index: ", results[0].frequencyIndex, ")");
    Print("   Target: Step ", results[0].targetStep, " | Error: ", DoubleToString(results[0].errorPercent, 3), "% (", DoubleToString(results[0].errorPips, 1), " pips)");
    Print("   Speed: ", DoubleToString(results[0].gannAngle, 2), "x | Consistency: ", DoubleToString(results[0].angleWeight * 100, 1), "%");
    Print("   Time Symmetry: ", DoubleToString(results[0].timeSymmetry * 100, 1), "% | Total Score: ", DoubleToString(results[0].totalScore, 2));
    Print("========================================");
    Print("📊 TOP 10 ALTERNATIVES:");
    #endif
    
    int displayCount = MathMin(10, resultCount);
    for(int i = 0; i < displayCount; i++)
    {
        Print(StringFormat("%d. %.3f%% → Step %d | Err: %.2f%% (%.1f pips) | Speed: %.2fx | Score: %.2f",
              i + 1,
              results[i].frequency,
              results[i].targetStep,
              results[i].errorPercent,
              results[i].errorPips,
              results[i].gannAngle,
              results[i].totalScore));
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    #endif
    
    // انتخاب بهترین فرکانس
    double bestFreq = results[0].frequency;
    int bestIndex = results[0].frequencyIndex;
    
    // اعمال فرکانس
    g_th3FrequencyOverride = bestFreq;
    g_th3FrequencyIndex = bestIndex;
    
    // ذخیره در GlobalVariable
    // PERFORMANCE: Use cached ChartID string
    string chartIdStr = GetCachedChartIdStr();
    string freqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    string indexGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
    GlobalVariableSet(freqGvarName, bestFreq);
    GlobalVariableSet(indexGvarName, bestIndex);
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Frequency applied successfully");
    #endif
    
    // Update frequency label
    UpdateTH3FrequencyLabel(bestFreq);
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate AB=CD Point D (with 9-level validation)               |
//| محاسبه نقطه D با اعتبارسنجی 9 سطحی                              |
//| Rule: AB distance = CD distance (equal price movement)          |
//+------------------------------------------------------------------+
bool CalculateABCDPointD(datetime tA, double pA, datetime tB, double pB,
                         datetime tC, double pC, datetime &tD, double &pD)
{
    // 1. Validate input times
    if(tA <= 0 || tB <= 0 || tC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Invalid time inputs");
        #endif
        return false;
    }
    
    // 2. Validate input prices
    if(pA <= 0 || pB <= 0 || pC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Invalid price inputs");
        #endif
        return false;
    }
    
    // 3. Time ordering: A < B < C
    if(!(tA < tB && tB < tC)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Time ordering violated (A < B < C required)");
        #endif
        return false;
    }
    
    // 4. Minimum distance check (prevent micro-patterns)
    double AB_Distance = MathAbs(pB - pA);
    double BC_Distance = MathAbs(pC - pB);
    double minDistance = GetCachedPoint() * ABCD_MIN_DISTANCE_POINTS;
    
    if(AB_Distance < minDistance) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: AB distance too small (min: ", minDistance, ")");
        #endif
        return false;
    }
    
    // RELAXED: BC can be any size (user might be adjusting)
    // BC میتونه هر اندازه‌ای باشه (کاربر ممکنه داره تنظیم میکنه)
    
    // 5. Pattern direction validation (RELAXED - allow any C position)
    // اعتبارسنجی جهت پترن (آزاد - C میتونه هر جایی باشه)
    bool isBullish = (pB > pA); // A to B is upward
    
    // REMOVED: Retracement check - C can be anywhere
    // حذف شد: چک retracement - C میتونه هر جایی باشه
    // This allows user to freely adjust C without pattern deletion
    // این به کاربر اجازه میده C رو آزادانه تنظیم کنه بدون حذف پترن
    
    // 6. Calculate D using AB=CD rule
    double CD_Distance = AB_Distance; // Equal distance
    
    if(isBullish) {
        pD = pC + CD_Distance; // Bullish: D above C
    } else {
        pD = pC - CD_Distance; // Bearish: D below C
    }
    
    // 7. Calculate D time (proportional to BC time)
    int BC_Bars = iBarShift(_Symbol, _Period, tB) - iBarShift(_Symbol, _Period, tC);
    if(BC_Bars < 1) BC_Bars = 1;
    
    int CD_Bars = BC_Bars; // Same time proportion
    int barD = iBarShift(_Symbol, _Period, tC) - CD_Bars;
    if(barD < 0) barD = 0;
    
    tD = iTime(_Symbol, 0, barD);
    if(tD <= 0) tD = tC + (tC - tB); // Fallback
    
    // 8. Collinearity check (REMOVED - too restrictive)
    // چک collinearity حذف شد - خیلی محدود کننده بود
    // User should be free to place points anywhere
    // کاربر باید آزادانه بتونه نقاط رو جابجا کنه
    
    // 9. Final validation: D price must be reasonable (RELAXED)
    // اعتبارسنجی نهایی: قیمت D باید منطقی باشه (آزاد شده)
    if(pD <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Calculated D price is zero or negative");
        #endif
        return false;
    }
    
    // RELAXED: Allow any D price (even if far from current price)
    // آزاد شده: D میتونه هر قیمتی باشه (حتی اگر از قیمت فعلی دور باشه)
    
    return true;
}

//+------------------------------------------------------------------+
//| Draw AB=CD Pattern with TH3-style Steps                         |
//| رسم پترن AB=CD با گام‌های TH3                                    |
//| User provides A, B, C → System calculates D                      |
//| Targets (Step1/3/5/7) start from C (not D)                       |
//+------------------------------------------------------------------+
void DrawABCDPattern(string mainObjName, datetime tA, double pA, datetime tB, double pB,
                     datetime tC, double pC)
{
    #ifdef ENABLE_DEBUG_LOGS
    Print("🎨 DrawABCDPattern called | Name: ", mainObjName);
    Print("   A: ", TimeToString(tA), " @ ", DoubleToString(pA, Digits));
    Print("   B: ", TimeToString(tB), " @ ", DoubleToString(pB, Digits));
    #ifdef ENABLE_DEBUG_LOGS
    Print("   C: ", TimeToString(tC), " @ ", DoubleToString(pC, Digits));
    #endif
    #endif
    
    datetime tD;
    double pD;
    
    if(!CalculateABCDPointD(tA, pA, tB, pB, tC, pC, tD, pD)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateABCDPointD failed - cleaning up temp objects");
        #endif
        
        // Cleanup partial objects
        string pointNames[4] = {"A", "B", "C", "D"};
        for(int i = 0; i < 4; i++) {
            ObjectDelete(0, mainObjName + "_Point_" + pointNames[i]);
            ObjectDelete(0, mainObjName + "_Label_" + pointNames[i]);
        }
        ObjectDelete(0, mainObjName + "_Line_AB");
        ObjectDelete(0, mainObjName + "_Line_BC");
        ObjectDelete(0, mainObjName + "_Info");
        return;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Point D calculated: ", TimeToString(tD), " @ ", DoubleToString(pD, Digits));
    #endif
    
    double AB_Distance = MathAbs(pB - pA);
    bool isBullish = (pB > pA);
    double frequency = GetCurrentTH3Frequency();
    double baseUnit = AB_Distance * (frequency / 100.0);
    
    double pipSize = GetCachedPipSize();
    
    // DYNAMIC OFFSET: Calculate based on candle size for better positioning
    // Offset داینامیک: محاسبه بر اساس اندازه کندل برای موقعیت بهتر
    double labelOffset;
    
    if(inpABCDLabelOffsetPercent > 0) {
        // User-defined offset percentage
        double avgCandleSize = 0;
        int lookback = 20; // میانگین 20 کندل اخیر
        double highArr[], lowArr[];
        int copied = CopyHigh(_Symbol, 0, 0, lookback, highArr);
        int copiedL = CopyLow(_Symbol, 0, 0, lookback, lowArr);
        if(copied > 0 && copiedL > 0) {
            int cnt = MathMin(copied, copiedL);
            for(int k = 0; k < cnt; k++) {
                avgCandleSize += (highArr[k] - lowArr[k]);
            }
            avgCandleSize /= cnt;
        } else {
            avgCandleSize = GetCachedPipSize() * 10; // fallback
        }
        
        // Use user-defined percentage of average candle size
        labelOffset = avgCandleSize * (inpABCDLabelOffsetPercent / 100.0);
        
        // Minimum offset: 3 pips (prevent labels too close)
        double minOffset = 3.0 * pipSize;
        if(labelOffset < minOffset) labelOffset = minOffset;
        
        // Maximum offset: 100 pips (prevent labels too far)
        double maxOffset = 100.0 * pipSize;
        if(labelOffset > maxOffset) labelOffset = maxOffset;
    } else {
        // Auto mode: Use fixed 15 pips (legacy behavior)
        labelOffset = 15.0 * pipSize;
    }
    
    // Draw points A, B, C, D with smart label positioning
    string pointNames[4];
    pointNames[0] = "A";
    pointNames[1] = "B";
    pointNames[2] = "C";
    pointNames[3] = "D";
    
    datetime pointTimes[4];
    pointTimes[0] = tA;
    pointTimes[1] = tB;
    pointTimes[2] = tC;
    pointTimes[3] = tD;
    
    double pointPrices[4];
    pointPrices[0] = pA;
    pointPrices[1] = pB;
    pointPrices[2] = pC;
    pointPrices[3] = pD;
    
    // Draw visible drag points for A, B, C (small circles with smart positioning)
    // نقاط قابل کشیدن برای A، B، C (دایره‌های کوچک با موقعیت هوشمند)
    for(int i = 0; i < 3; i++) {
        string pointName = mainObjName + "_Point_" + pointNames[i];
        
        // SMART POSITIONING: Place point above/below candle based on price level
        // موقعیت‌یابی هوشمند: قرار دادن نقطه بالا/پایین کندل بر اساس سطح قیمت
        int barIndex = iBarShift(_Symbol, _Period, pointTimes[i]);
        double pointPrice = pointPrices[i];
        
        if(barIndex >= 0) {
            double high = iHigh(_Symbol, 0, barIndex);
            double low = iLow(_Symbol, 0, barIndex);
            double mid = (high + low) / 2.0;
            
            // Determine if point is at top or bottom of candle
            // تشخیص اینکه نقطه در بالا یا پایین کندل هست
            bool isAtTop = (pointPrice >= mid);
            
            // Offset point slightly outside candle for visibility
            // جابجایی نقطه کمی خارج از کندل برای قابل مشاهده بودن
            double offset = (high - low) * 0.15; // 15% of candle range
            if(offset < GetCachedPoint() * 10) offset = GetCachedPoint() * 10; // Minimum offset
            
            if(isAtTop) {
                // Point at top - place above high
                pointPrice = high + offset;
            } else {
                // Point at bottom - place below low
                pointPrice = low - offset;
            }
        }
        
        // OPTIMIZED: Use small circle (ARROWCODE 159) - visible and draggable
        // استفاده از دایره کوچک - قابل مشاهده و کشیدن
        if(ObjectFind(0, pointName) < 0) {
            if(!ObjectCreate(0, pointName, OBJ_ARROW, 0, pointTimes[i], pointPrices[i])) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("❌ Failed to create point ", pointNames[i], " | Error: ", GetLastError());
                #endif
            } else {
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ Created point ", pointNames[i], " at ", TimeToString(pointTimes[i]), " @ ", DoubleToString(pointPrices[i], Digits));
                #endif
            }
            
            // CRITICAL: Visible circle with smart positioning
            ObjectSetInteger(0, pointName, OBJPROP_COLOR, inpABCDPointColor);
            ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Small filled circle
            ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 3); // Medium size for easy clicking
            ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, pointName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, pointName, OBJPROP_BACK, false); // Draw on top
            ObjectSetInteger(0, pointName, OBJPROP_ZORDER, 10); // High priority
            ObjectSetString(0, pointName, OBJPROP_TOOLTIP, "📍 Point " + pointNames[i] + " | Drag to adjust");
        } else {
            // Update existing point position
            ObjectMove(0, pointName, 0, pointTimes[i], pointPrices[i]);
            #ifdef ENABLE_DEBUG_LOGS
            Print("🔄 Updated existing point ", pointNames[i]);
            #endif
        }
        
        // Smart label positioning relative to candle High/Low
        // موقعیت‌یابی هوشمند لیبل نسبت به High/Low کندل
        if(inpABCDShowLabels) {
            string labelName = mainObjName + "_Label_" + pointNames[i];
            double labelPrice = pointPrices[i];
            ENUM_ANCHOR_POINT anchor = ANCHOR_CENTER;
            
            // Get candle High/Low for this point
            int labelBarIndex = iBarShift(_Symbol, _Period, pointTimes[i]);
            double candleHigh = (labelBarIndex >= 0) ? iHigh(_Symbol, 0, labelBarIndex) : pointPrices[i];
            double candleLow = (labelBarIndex >= 0) ? iLow(_Symbol, 0, labelBarIndex) : pointPrices[i];
            
            // Position label relative to candle High/Low (not point price)
            // قرار دادن لیبل نسبت به High/Low کندل (نه قیمت نقطه)
            if(i == 0 || i == 2) { // A or C (swing lows in bullish, swing highs in bearish)
                if(isBullish) {
                    // A/C are lows - place label below candle low
                    labelPrice = candleLow - labelOffset;
                    anchor = ANCHOR_UPPER;
                } else {
                    // A/C are highs - place label above candle high
                    labelPrice = candleHigh + labelOffset;
                    anchor = ANCHOR_LOWER;
                }
            } else { // B or D (swing highs in bullish, swing lows in bearish)
                if(isBullish) {
                    // B/D are highs - place label above candle high
                    labelPrice = candleHigh + labelOffset;
                    anchor = ANCHOR_LOWER;
                } else {
                    // B/D are lows - place label below candle low
                    labelPrice = candleLow - labelOffset;
                    anchor = ANCHOR_UPPER;
                }
            }
            
            if(ObjectFind(0, labelName) < 0) {
                if(!ObjectCreate(0, labelName, OBJ_TEXT, 0, pointTimes[i], labelPrice)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ Failed to create label ", pointNames[i], " | Error: ", GetLastError());
                    #endif
                } else {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("✅ Created label ", pointNames[i]);
                    #endif
                }
                ObjectSetString(0, labelName, OBJPROP_TEXT, pointNames[i]);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, inpABCDPointColor);
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
                ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            } else {
                ObjectMove(0, labelName, 0, pointTimes[i], labelPrice);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
                #ifdef ENABLE_DEBUG_LOGS
                Print("🔄 Updated existing label ", pointNames[i]);
                #endif
            }
        }
    }
    
    // Draw line AB (solid)
    string lineAB = mainObjName + "_Line_AB";
    if(ObjectFind(0, lineAB) < 0) {
        if(!ObjectCreate(0, lineAB, OBJ_TREND, 0, tA, pA, tB, pB)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Failed to create Line AB | Error: ", GetLastError());
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Created Line AB");
            #endif
        }
        ObjectSetInteger(0, lineAB, OBJPROP_COLOR, inpABCDLineColor);
        ObjectSetInteger(0, lineAB, OBJPROP_WIDTH, inpABCDWidth);
        ObjectSetInteger(0, lineAB, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, lineAB, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineAB, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineAB, OBJPROP_BACK, false);
    } else {
        ObjectMove(0, lineAB, 0, tA, pA);
        ObjectMove(0, lineAB, 1, tB, pB);
    }
    
    // Draw line BC (dotted)
    string lineBC = mainObjName + "_Line_BC";
    if(ObjectFind(0, lineBC) < 0) {
        if(!ObjectCreate(0, lineBC, OBJ_TREND, 0, tB, pB, tC, pC)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Failed to create Line BC | Error: ", GetLastError());
            #endif
        } else {
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Created Line BC");
            #endif
        }
        ObjectSetInteger(0, lineBC, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, lineBC, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lineBC, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lineBC, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lineBC, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineBC, OBJPROP_BACK, true);
    } else {
        ObjectMove(0, lineBC, 0, tB, pB);
        ObjectMove(0, lineBC, 1, tC, pC);
    }
    
    // Draw TH3-style targets (Step1, Step3, Step5, Step7) from C
    string targetNames[4] = {"Step1", "Step3", "Step5", "Step7"};
    color targetColors[4] = {clrDodgerBlue, clrOrangeRed, clrLimeGreen, clrGold};
    double targetLevels[4];
    
    if(isBullish) {
        targetLevels[0] = pC + (1.0 * baseUnit);
        targetLevels[1] = pC + (3.0 * baseUnit);
        targetLevels[2] = pC + (5.0 * baseUnit);
        targetLevels[3] = pC + (7.0 * baseUnit);
    } else {
        targetLevels[0] = pC - (1.0 * baseUnit);
        targetLevels[1] = pC - (3.0 * baseUnit);
        targetLevels[2] = pC - (5.0 * baseUnit);
        targetLevels[3] = pC - (7.0 * baseUnit);
    }
    
    double targetPips[4];
    for(int i = 0; i < 4; i++) {
        targetPips[i] = MathAbs(baseUnit * (i*2 + 1)) / pipSize;
    }
    
    datetime startTime = tC;
    int barShift = iBarShift(_Symbol, _Period, startTime);
    datetime endTime = iTime(_Symbol, 0, MathMax(0, barShift - 100));
    
    // GOLD VERSION: Use configurable zone height from input parameter
    // Convert from percentage (1-100) to decimal (0.01-1.0)
    double zoneHeightPercent = inpTH3ZoneHeightPercent / 100.0;
    
    // Validate and clamp
    if(zoneHeightPercent < 0.01) zoneHeightPercent = 0.01;
    if(zoneHeightPercent > 1.0) zoneHeightPercent = 1.0;
    
    double zoneHalfWidth = baseUnit * zoneHeightPercent;
    
    for(int i = 0; i < 4; i++) {
        string lineName = mainObjName + "_Target_" + IntegerToString(i+1);
        double centerPrice = targetLevels[i];
        double upperZone = centerPrice + zoneHalfWidth;
        double lowerZone = centerPrice - zoneHalfWidth;
        color zoneColor = (inpTH3ZoneColor == clrNONE) ? targetColors[i] : inpTH3ZoneColor;
        
        if(ObjectFind(0, lineName) < 0) {
            ObjectCreate(0, lineName, OBJ_FIBO, 0, startTime, centerPrice, endTime, centerPrice);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, targetColors[i]);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELCOLOR, targetColors[i]);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELWIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lineName, OBJPROP_LEVELS, 1);
            ObjectSetDouble(0, lineName, OBJPROP_LEVELVALUE, 0, 0.0);
            
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
                double zonePips = (zoneHalfWidth * 2.0) / pipSize;
                string labelText = StringFormat("%s (%.1f) ±%.1f", targetNames[i], targetPips[i], zonePips/2.0);
                ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
            }
        } else {
            // CRITICAL FIX: Update position AND label text when frequency changes
            ObjectMove(0, lineName, 0, startTime, centerPrice);
            ObjectMove(0, lineName, 1, endTime, centerPrice);
            
            // Update label text with new pip values
            if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
                double zonePips = (zoneHalfWidth * 2.0) / pipSize;
                string labelText = StringFormat("%s (%.1f) ±%.1f", targetNames[i], targetPips[i], zonePips/2.0);
                ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
            }
        }
        
        // Zone lines
        string zoneUpperName = mainObjName + "_ZoneUpper_" + IntegerToString(i+1);
        string zoneLowerName = mainObjName + "_ZoneLower_" + IntegerToString(i+1);
        
        if(inpTH3ZoneStyle == TH3_ZONE_LINES) {
            if(ObjectFind(0, zoneUpperName) < 0) {
                ObjectCreate(0, zoneUpperName, OBJ_TREND, 0, startTime, upperZone, endTime, upperZone);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_COLOR, zoneColor);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, zoneUpperName, OBJPROP_BACK, true);
            } else {
                ObjectMove(0, zoneUpperName, 0, startTime, upperZone);
                ObjectMove(0, zoneUpperName, 1, endTime, upperZone);
            }
            
            if(ObjectFind(0, zoneLowerName) < 0) {
                ObjectCreate(0, zoneLowerName, OBJ_TREND, 0, startTime, lowerZone, endTime, lowerZone);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_COLOR, zoneColor);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_WIDTH, inpTH3ZoneBorderWidth);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_STYLE, inpTH3ZoneBorderStyle);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_RAY_RIGHT, inpABCDExtendCD);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, zoneLowerName, OBJPROP_BACK, true);
            } else {
                ObjectMove(0, zoneLowerName, 0, startTime, lowerZone);
                ObjectMove(0, zoneLowerName, 1, endTime, lowerZone);
            }
        }
    }
    
    // Info label (corner-based positioning - configurable)
    // لیبل اطلاعات (موقعیت گوشه‌ای - قابل تنظیم)
    // VISIBILITY: Only shown for active pattern
    // قابل مشاهده بودن: فقط برای پترن فعال نمایش داده میشه
    double pips_AB = AB_Distance / pipSize;
    double pips_BC = MathAbs(pC - pB) / pipSize;
    
    string infoText = StringFormat("AB=CD | AB:%.1f | BC:%.1f | Freq:%.1f%%", 
                                   pips_AB, pips_BC, frequency);
    
    string infoLabel = mainObjName + "_Info";
    
    // Determine visibility based on active pattern
    // تعیین قابل مشاهده بودن بر اساس پترن فعال
    bool isActive = (g_activeABCDPattern == mainObjName);
    
    if(ObjectFind(0, infoLabel) < 0) {
        ObjectCreate(0, infoLabel, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
        ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, inpABCDInfoYDistance);
        ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
        ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
        ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
        ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, infoLabel, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, infoLabel, OBJPROP_HIDDEN, true);
        
        // Set visibility based on active state
        ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    } else {
        // Update text and visibility
        ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
        ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
        ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, inpABCDInfoYDistance);
        ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
        ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
        
        // Update visibility based on active state
        ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🎨 DrawABCDPattern completed | Pattern: ", mainObjName);
    Print("   Objects: Points(3:A,B,C) + Labels(3) + Lines(2) + Targets(4) + Zones(8) + Info(1)");
    Print("   Note: Point D not shown - target levels indicate D zone");
    #endif
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update All TH3 Objects (when frequency changes)                 |
//| آپدیت تمام اشیاء TH3 (وقتی فرکانس تغییر میکنه)                  |
//+------------------------------------------------------------------+
void UpdateAllTH3Objects() {
    int updatedCount = 0;
    
    // Update AB=CD patterns
    int totalTrend = ObjectsTotal(0, -1, OBJ_TREND);
    for(int i = 0; i < totalTrend; i++) {
        string name = ObjectName(0, i, -1, OBJ_TREND);
        
        // Find AB=CD pattern main line (Line_AB)
        if(StringFind(name, "ABCD_Pattern_") == 0 && StringFind(name, "_Line_AB") > 0) {
            string baseName = StringSubstr(name, 0, StringFind(name, "_Line_AB"));
            
            // Get points A, B, C from line endpoints
            string lineAB = baseName + "_Line_AB";
            string lineBC = baseName + "_Line_BC";
            
            if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) continue;
            
            datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
            double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
            datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
            double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
            datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
            double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
            
            int lastError = GetLastError();
            if(lastError != 0) {
                ResetLastError(); // CRITICAL FIX: Clear error for next iteration
                continue;
            }
            
            if(tA > 0 && tB > 0 && tC > 0 && pA > 0 && pB > 0 && pC > 0) {
                // Redraw entire AB=CD pattern with new frequency
                DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
                updatedCount++;
            }
        }
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    if(updatedCount > 0) {
        Print("🔄 Updated ", updatedCount, " AB=CD patterns with frequency: ", 
              DoubleToString(GetCurrentTH3Frequency(), 3), "%");
    }
    #endif
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Create ABCD temporary point marker on chart             |
//| کمکی: ساخت نشانگر نقطه موقت ABCD روی چارت                        |
//+------------------------------------------------------------------+
void CreateABCDTempPoint(const string pointLabel, datetime clickTime, double clickPrice) {
    string objName = "ABCD_Temp_" + pointLabel;
    ObjectCreate(0, objName, OBJ_TEXT, 0, clickTime, clickPrice);
    ObjectSetString(0, objName, OBJPROP_TEXT, pointLabel);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Helper: Create ABCD temporary trend line between two points     |
//| کمکی: ساخت خط روند موقت ABCD بین دو نقطه                         |
//+------------------------------------------------------------------+
void CreateABCDTempLine(const string lineSuffix, datetime t1, double p1, datetime t2, double p2) {
    string objName = "ABCD_Temp_Line_" + lineSuffix;
    ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Handle AB=CD Mouse Events (3-point click workflow)              |
//| مدیریت رویدادهای موس برای AB=CD (کلیک 3 نقطه)                   |
//+------------------------------------------------------------------+
void OnABCDMouseEvent(int id, long lparam, double dparam, string sparam) {
    // Handle right-click cancel
    if(id == CHARTEVENT_MOUSE_MOVE) {
        int mouseState = (int)StringToInteger(sparam);
        bool rightButtonDown = (mouseState & 2) == 2;
        bool leftButtonDown = (mouseState & 1) == 1;
        
        if(rightButtonDown && g_abcdDrawing) {
            g_abcdDrawing = false;
            g_abcdPointCount = 0;
            
            ObjectDelete(0, "ABCD_Temp_X");
            ObjectDelete(0, "ABCD_Temp_A");
            ObjectDelete(0, "ABCD_Temp_B");
            ObjectDelete(0, "ABCD_Temp_C");
            ObjectDelete(0, "ABCD_Temp_Line_XA");
            ObjectDelete(0, "ABCD_Temp_Line_AB");
            ObjectDelete(0, "ABCD_Temp_Line_BC");
            
            ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✖️ AB=CD creation cancelled");
            #endif
            return;
        }
        
        // ALTERNATIVE CLICK DETECTION: Use mouse button state change
        // This is more reliable than CHARTEVENT_CLICK in MT4
        static bool s_lastLeftButtonState = false;
        
        if(g_abcdDrawing && leftButtonDown && !s_lastLeftButtonState) {
            // Left button just pressed (rising edge detection)
            s_lastLeftButtonState = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("🖱️ Left button pressed via MOUSE_MOVE | lparam=", lparam, " dparam=", dparam);
            #endif
            
            // Debounce check
            uint currentTime = GetTickCount();
            if(currentTime - g_abcdLastClickTime < ABCD_DEBOUNCE_MS) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⏱️ Click debounced (too fast)");
                #endif
                return;
            }
            g_abcdLastClickTime = currentTime;
            
            // Get click coordinates
            double mx = (double)lparam;
            double my = (double)dparam;
            
            int subWindow;
            datetime clickTime;
            double clickPrice;
            if(!ChartXYToTimePrice(0, (int)mx, (int)my, subWindow, clickTime, clickPrice)) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ChartXYToTimePrice failed | mx=", mx, " my=", my);
                #endif
                return;
            }
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Click detected | time=", TimeToString(clickTime), " price=", DoubleToString(clickPrice, Digits), " | pointCount=", g_abcdPointCount);
            #endif
            
            // Place point based on current count (4 points: X, A, B, C)
            if(g_abcdPointCount == 0) {
                g_abcdTimeX = clickTime;
                g_abcdPriceX = clickPrice;
                g_abcdPointCount = 1;
                
                CreateABCDTempPoint("X", clickTime, clickPrice);
                ChartRedraw();
                #ifdef ENABLE_DEBUG_LOGS
                Print("✓ Point X placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
                #endif
            }
            else if(g_abcdPointCount == 1) {
                g_abcdTimeA = clickTime;
                g_abcdPriceA = clickPrice;
                g_abcdPointCount = 2;
                
                CreateABCDTempPoint("A", clickTime, clickPrice);
                CreateABCDTempLine("XA", g_abcdTimeX, g_abcdPriceX, g_abcdTimeA, g_abcdPriceA);
                ChartRedraw();
                #ifdef ENABLE_DEBUG_LOGS
                Print("✓ Point A placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
                #endif
            }
            else if(g_abcdPointCount == 2) {
                g_abcdTimeB = clickTime;
                g_abcdPriceB = clickPrice;
                g_abcdPointCount = 3;
                
                CreateABCDTempPoint("B", clickTime, clickPrice);
                CreateABCDTempLine("AB", g_abcdTimeA, g_abcdPriceA, g_abcdTimeB, g_abcdPriceB);
                ChartRedraw();
                #ifdef ENABLE_DEBUG_LOGS
                Print("✓ Point B placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
                #endif
            }
            else if(g_abcdPointCount == 3) {
                g_abcdTimeC = clickTime;
                g_abcdPriceC = clickPrice;
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("✓ Point C placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
                #endif
                
                // 🔍 AUTO-SEARCH: Find optimal frequency for this pattern (with 3-wave analysis)
                // جستجوی خودکار: پیدا کردن بهترین فرکانس برای این پترن (با تحلیل 3 موج)
                FrequencySearchResult searchResults[];
                WaveAnalysis waves;
                double consolidationFactor;
                
                int resultCount = FindOptimalFrequencyForABCD_WithLearningData(
                    g_abcdTimeX, g_abcdPriceX,
                    g_abcdTimeA, g_abcdPriceA, 
                    g_abcdTimeB, g_abcdPriceB,
                    g_abcdTimeC, g_abcdPriceC,
                    searchResults,
                    waves,
                    consolidationFactor,
                    5.0);
                
                if(resultCount > 0) {
                    // اعمال بهترین فرکانس
                    g_th3FrequencyOverride = searchResults[0].frequency;
                    g_th3FrequencyIndex = searchResults[0].frequencyIndex;
                    
                    // ذخیره در GlobalVariable
                    // PERFORMANCE: Use cached ChartID string
                    string chartIdStr = GetCachedChartIdStr();
                    string freqGvarName = "Biotak_TH3Freq_" + chartIdStr;
                    string indexGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
                    GlobalVariableSet(freqGvarName, g_th3FrequencyOverride);
                    GlobalVariableSet(indexGvarName, g_th3FrequencyIndex);
                    
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("========================================");
                    Print("🎯 AUTO-SELECTED FREQUENCY");
                    Print("========================================");
                    Print("Best: ", DoubleToString(searchResults[0].frequency, 3), "% → Step ", searchResults[0].targetStep);
                    Print("Error: ", DoubleToString(searchResults[0].errorPercent, 3), "% (", DoubleToString(searchResults[0].errorPips, 1), " pips)");
                    Print("Speed: ", DoubleToString(searchResults[0].gannAngle, 2), "x | Consistency: ", DoubleToString(searchResults[0].angleWeight * 100, 1), "%");
                    Print("Time Sym: ", DoubleToString(searchResults[0].timeSymmetry * 100, 1), "% | Score: ", DoubleToString(searchResults[0].totalScore, 2));
                    Print("========================================");
                    Print("📊 TOP 5 ALTERNATIVES:");
                    #endif
                    for(int i = 0; i < MathMin(5, resultCount); i++) {
                        Print(StringFormat("%d. %.3f%% → Step %d | Err: %.2f%% | Speed: %.2fx | Score: %.2f",
                              i + 1,
                              searchResults[i].frequency,
                              searchResults[i].targetStep,
                              searchResults[i].errorPercent,
                              searchResults[i].gannAngle,
                              searchResults[i].totalScore));
                    }
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("========================================");
                    #endif
                }
                
                string patternName = "ABCD_Pattern_" + IntegerToString((long)GetTickCount());
                DrawABCDPattern(patternName, g_abcdTimeA, g_abcdPriceA, g_abcdTimeB, g_abcdPriceB, g_abcdTimeC, g_abcdPriceC);
                
                // Set as active pattern
                SetActiveABCDPattern(patternName);
                
                // ========================================
                // 💾 SAVE FOR LEARNING (بعد از رسم کامل پترن)
                // SAVE FOR LEARNING (after pattern is fully drawn)
                // ========================================
                SavePatternForLearning(
                    patternName,
                    g_abcdTimeX, g_abcdPriceX,
                    g_abcdTimeA, g_abcdPriceA,
                    g_abcdTimeB, g_abcdPriceB,
                    g_abcdTimeC, g_abcdPriceC,
                    searchResults[0].frequency,
                    searchResults[0].frequencyIndex,
                    searchResults[0].targetStep,
                    searchResults[0].errorPercent,
                    searchResults[0].totalScore,
                    waves,
                    consolidationFactor
                );
                
                ObjectDelete(0, "ABCD_Temp_X");
                ObjectDelete(0, "ABCD_Temp_A");
                ObjectDelete(0, "ABCD_Temp_B");
                ObjectDelete(0, "ABCD_Temp_C");
                ObjectDelete(0, "ABCD_Temp_Line_XA");
                ObjectDelete(0, "ABCD_Temp_Line_AB");
                ObjectDelete(0, "ABCD_Temp_Line_BC");
                
                g_abcdDrawing = false;
                g_abcdPointCount = 0;
                ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
                
                // Update frequency label
                UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
                
                ChartRedraw();
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ AB=CD pattern created: ", patternName);
                #endif
            }
        }
        else if(!leftButtonDown && s_lastLeftButtonState) {
            // Left button released
            s_lastLeftButtonState = false;
        }
        
        return;
    }
    
    // Handle left-click to place points (fallback for CHARTEVENT_CLICK)
    if(id == CHARTEVENT_CLICK && g_abcdDrawing) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("🔍 CHARTEVENT_CLICK received | lparam=", lparam, " dparam=", dparam, " sparam=", sparam, " | g_abcdPointCount=", g_abcdPointCount);
        #endif
        
        uint currentTime = GetTickCount();
        if(currentTime - g_abcdLastClickTime < ABCD_DEBOUNCE_MS) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("⏱️ Click debounced (too fast)");
            #endif
            return;
        }
        g_abcdLastClickTime = currentTime;
        
        double mx = (double)lparam;
        double my = (double)dparam;
        
        int subWindow;
        datetime clickTime;
        double clickPrice;
        if(!ChartXYToTimePrice(0, (int)mx, (int)my, subWindow, clickTime, clickPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ ChartXYToTimePrice failed | mx=", mx, " my=", my);
            #endif
            return;
        }
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ ChartXYToTimePrice success | time=", TimeToString(clickTime), " price=", DoubleToString(clickPrice, Digits));
        #endif
        
        if(g_abcdPointCount == 0) {
            g_abcdTimeX = clickTime;
            g_abcdPriceX = clickPrice;
            g_abcdPointCount = 1;
            
            CreateABCDTempPoint("X", clickTime, clickPrice);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✓ Point X placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
            #endif
        }
        else if(g_abcdPointCount == 1) {
            g_abcdTimeA = clickTime;
            g_abcdPriceA = clickPrice;
            g_abcdPointCount = 2;
            
            CreateABCDTempPoint("A", clickTime, clickPrice);
            CreateABCDTempLine("XA", g_abcdTimeX, g_abcdPriceX, g_abcdTimeA, g_abcdPriceA);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✓ Point A placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
            #endif
        }
        else if(g_abcdPointCount == 2) {
            g_abcdTimeB = clickTime;
            g_abcdPriceB = clickPrice;
            g_abcdPointCount = 3;
            
            CreateABCDTempPoint("B", clickTime, clickPrice);
            CreateABCDTempLine("AB", g_abcdTimeA, g_abcdPriceA, g_abcdTimeB, g_abcdPriceB);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✓ Point B placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
            #endif
        }
        else if(g_abcdPointCount == 3) {
            g_abcdTimeC = clickTime;
            g_abcdPriceC = clickPrice;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("✓ Point C placed at ", TimeToString(clickTime), " price ", DoubleToString(clickPrice, Digits));
            #endif
            
            string patternName = "ABCD_Pattern_" + IntegerToString((long)GetTickCount());
            DrawABCDPattern(patternName, g_abcdTimeA, g_abcdPriceA, g_abcdTimeB, g_abcdPriceB, g_abcdTimeC, g_abcdPriceC);
            
            // Set as active pattern
            SetActiveABCDPattern(patternName);
            
            ObjectDelete(0, "ABCD_Temp_X");
            ObjectDelete(0, "ABCD_Temp_A");
            ObjectDelete(0, "ABCD_Temp_B");
            ObjectDelete(0, "ABCD_Temp_C");
            ObjectDelete(0, "ABCD_Temp_Line_XA");
            ObjectDelete(0, "ABCD_Temp_Line_AB");
            ObjectDelete(0, "ABCD_Temp_Line_BC");
            
            g_abcdDrawing = false;
            g_abcdPointCount = 0;
            ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ AB=CD pattern created: ", patternName);
            #endif
        }
    }
    
    // Handle drag events for A, B, C points with smart magnet effect
    // مدیریت کشیدن نقاط A، B، C با افکت مگنت هوشمند
    if(id == CHARTEVENT_OBJECT_DRAG) {
        if(StringFind(sparam, "ABCD_Pattern_") == 0 && StringFind(sparam, "_Point_") > 0) {
            // Extract pattern name and point
            int pointPos = StringFind(sparam, "_Point_");
            string baseName = StringSubstr(sparam, 0, pointPos);
            string pointName = StringSubstr(sparam, pointPos + 7);
            
            // Only A, B, C are draggable
            if(pointName != "A" && pointName != "B" && pointName != "C") return;
            
            // CRITICAL: Set this pattern as active when user drags it
            // وقتی کاربر drag میکنه، این پترن رو فعال کن
            SetActiveABCDPattern(baseName);
            
            // SMART MAGNET: Snap to nearest candle high/low with threshold
            // مگنت هوشمند: چسبیدن به high/low نزدیک با آستانه
            string draggedPoint = baseName + "_Point_" + pointName;
            datetime newTime = (datetime)ObjectGetInteger(0, draggedPoint, OBJPROP_TIME, 0);
            double newPrice = ObjectGetDouble(0, draggedPoint, OBJPROP_PRICE, 0);
            
            int barIndex = iBarShift(_Symbol, _Period, newTime);
            if(barIndex >= 0) {
                double high = iHigh(_Symbol, 0, barIndex);
                double low = iLow(_Symbol, 0, barIndex);
                double open = iOpen(_Symbol, 0, barIndex);
                double close = iClose(_Symbol, 0, barIndex);
                
                // Calculate distances in pips
                double pipSize = GetCachedPipSize();
                double distToHigh = MathAbs(newPrice - high) / pipSize;
                double distToLow = MathAbs(newPrice - low) / pipSize;
                double distToOpen = MathAbs(newPrice - open) / pipSize;
                double distToClose = MathAbs(newPrice - close) / pipSize;
                
                // THRESHOLD: Only snap if within 5 pips (industry standard)
                // آستانه: فقط اگر فاصله کمتر از 5 پیپ باشه snap میشه
                double snapThreshold = 5.0;
                
                // Find closest level within threshold
                double minDist = MathMin(MathMin(distToHigh, distToLow), MathMin(distToOpen, distToClose));
                
                if(minDist <= snapThreshold) {
                    // PRIORITY: High/Low > Open/Close (more significant levels)
                    // اولویت: High/Low > Open/Close (سطوح مهم‌تر)
                    if(minDist == distToHigh) {
                        newPrice = high;
                        #ifdef ENABLE_DEBUG_LOGS
                        Print("🧲 Snapped to HIGH (", DoubleToString(minDist, 1), " pips)");
                        #endif
                    } else if(minDist == distToLow) {
                        newPrice = low;
                        #ifdef ENABLE_DEBUG_LOGS
                        Print("🧲 Snapped to LOW (", DoubleToString(minDist, 1), " pips)");
                        #endif
                    } else if(minDist == distToClose) {
                        newPrice = close;
                        #ifdef ENABLE_DEBUG_LOGS
                        Print("🧲 Snapped to CLOSE (", DoubleToString(minDist, 1), " pips)");
                        #endif
                    } else if(minDist == distToOpen) {
                        newPrice = open;
                        #ifdef ENABLE_DEBUG_LOGS
                        Print("🧲 Snapped to OPEN (", DoubleToString(minDist, 1), " pips)");
                        #endif
                    }
                    
                    // Update point with snapped price
                    ObjectSetDouble(0, draggedPoint, OBJPROP_PRICE, newPrice);
                }
                // else: No snap - user has precise control beyond threshold
            }
            
            // Get updated positions
            string lineAB = baseName + "_Line_AB";
            string lineBC = baseName + "_Line_BC";
            
            if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) return;
            
            datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
            double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
            
            // Validate after each ObjectGet (CRITICAL FIX: prevent crash)
            if(ObjectFind(0, lineAB) < 0) return;
            
            datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
            double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
            
            if(ObjectFind(0, lineBC) < 0) return;
            
            datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
            double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
            
            // Update point position from drag
            if(pointName == "A") {
                tA = newTime;
                pA = newPrice;
            } else if(pointName == "B") {
                tB = newTime;
                pB = newPrice;
            } else if(pointName == "C") {
                tC = newTime;
                pC = newPrice;
            }
            
            // Redraw pattern with updated points (includes wave analysis)
            DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
        }
    }
    
    // Handle pattern deletion (only when main objects are deleted, not drag points)
    // مدیریت حذف پترن (فقط وقتی اشیاء اصلی حذف شدن، نه نقاط قابل کشیدن)
    if(id == CHARTEVENT_OBJECT_DELETE) {
        // Check if any ABCD pattern object is deleted
        // بررسی اینکه آیا هر شیء مربوط به پترن ABCD حذف شده
        if(StringFind(sparam, "ABCD_Pattern_") == 0) {
            
            // Extract base name from deleted object
            string baseName = sparam;
            
            // CRITICAL FIX: Safe string parsing - find pattern base name
            // پیدا کردن نام پایه پترن
            int underscorePos = -1;
            
            // Try different suffixes to extract base name (using constants)
            string suffixes[7];
            suffixes[0] = TH3_SUFFIX_LINE_AB;
            suffixes[1] = TH3_SUFFIX_LINE_BC;
            suffixes[2] = TH3_SUFFIX_TARGET;
            suffixes[3] = TH3_SUFFIX_POINT;
            suffixes[4] = TH3_SUFFIX_LABEL;
            suffixes[5] = TH3_SUFFIX_INFO;
            suffixes[6] = TH3_SUFFIX_ZONE;
            
            for(int s = 0; s < ArraySize(suffixes); s++) {
                int pos = StringFind(baseName, suffixes[s]);
                if(pos > 0) {
                    baseName = StringSubstr(baseName, 0, pos);
                    break;
                }
            }
            
            // Verify this is a valid pattern base name (should be ABCD_Pattern_XXXXXXXX)
            if(StringFind(baseName, "ABCD_Pattern_") != 0 || StringLen(baseName) < 20) {
                // Not a valid pattern base name, ignore
                return;
            }
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("🗑️ Deleting AB=CD pattern: ", baseName);
            Print("   Triggered by object: ", sparam);
            #endif
            
            // ========================================
            // COMPREHENSIVE CLEANUP: Delete ALL related objects
            // پاکسازی جامع: حذف همه اشیاء وابسته
            // ========================================
            
            // 1. Delete drag points (A, B, C) and labels
            string pointNames[3] = {"A", "B", "C"};
            for(int i = 0; i < 3; i++) {
                ObjectDelete(0, baseName + "_Point_" + pointNames[i]);
                ObjectDelete(0, baseName + "_Label_" + pointNames[i]);
            }
            
            // 2. Delete lines
            ObjectDelete(0, baseName + "_Line_AB");
            ObjectDelete(0, baseName + "_Line_BC");
            
            // 3. Delete info label
            ObjectDelete(0, baseName + "_Info");
            
            // 4. Delete all target levels (Step1-7) and zones
            // حذف تمام سطوح هدف و زون‌ها
            for(int i = 1; i <= 7; i++) {
                ObjectDelete(0, baseName + "_Target_" + IntegerToString(i));
                ObjectDelete(0, baseName + "_ZoneUpper_" + IntegerToString(i));
                ObjectDelete(0, baseName + "_ZoneLower_" + IntegerToString(i));
            }
            
            // 5. Delete any temporary objects
            // حذف اشیاء موقت
            ObjectDelete(0, baseName + "_Temp_X");
            ObjectDelete(0, baseName + "_Temp_A");
            ObjectDelete(0, baseName + "_Temp_B");
            ObjectDelete(0, baseName + "_Temp_C");
            ObjectDelete(0, baseName + "_Temp_Line_XA");
            ObjectDelete(0, baseName + "_Temp_Line_AB");
            ObjectDelete(0, baseName + "_Temp_Line_BC");
            
            // 6. Clear active pattern if this was the active one
            // پاکسازی پترن فعال اگر این پترن فعال بود
            if(g_activeABCDPattern == baseName) {
                SetActiveABCDPattern("");
            }
            
            // ========================================
            // 🤖 SMART LEARNING: Pattern deleted
            // یادگیری هوشمند: پترن حذف شد
            // ========================================
            OnPatternDeleted(baseName);
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Pattern cleanup complete: ", baseName);
            #endif
            
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Toggle TH3 Tool (V key)                                         |
//| فعال/غیرفعال کردن ابزار TH3 (کلید V)                            |
//+------------------------------------------------------------------+
void ToggleTH3Tool() {
    if(!inpEnableTH3Tool) return;
    
    if(inpTH3DrawingMode == TH3_MODE_ABCD) {
        // AB=CD mode: Start 3-point input
        if(!g_abcdDrawing) {
            g_abcdDrawing = true;
            g_abcdPointCount = 0;
            g_abcdLastClickTime = 0;
            ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
            #ifdef ENABLE_DEBUG_LOGS
            Print("🎯 AB=CD Mode: Click 4 points (X, A, B, C). Right-click to cancel.");
            #endif
        } else {
            // Cancel current drawing
            g_abcdDrawing = false;
            g_abcdPointCount = 0;
            ObjectDelete(0, "ABCD_Temp_X");
            ObjectDelete(0, "ABCD_Temp_A");
            ObjectDelete(0, "ABCD_Temp_B");
            ObjectDelete(0, "ABCD_Temp_C");
            ObjectDelete(0, "ABCD_Temp_Line_XA");
            ObjectDelete(0, "ABCD_Temp_Line_AB");
            ObjectDelete(0, "ABCD_Temp_Line_BC");
            ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
            ChartRedraw();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✖️ AB=CD creation cancelled");
            #endif
        }
    }
}

//+------------------------------------------------------------------+
//| Cycle TH3 Frequency (Keys 3 and 4)                              |
//| چرخش فرکانس TH3 (کلیدهای 3 و 4)                                 |
//+------------------------------------------------------------------+
void CycleTH3Frequency() {
    if(g_th3FrequencyIndex < 0 || g_th3FrequencyIndex >= TH3_FREQUENCY_COUNT) {
        g_th3FrequencyIndex = 16; // Reset to default (28.125% at index 16)
    }
    
    g_th3FrequencyIndex = (g_th3FrequencyIndex + 1) % TH3_FREQUENCY_COUNT;
    g_th3FrequencyOverride = TH3_TEST_FREQUENCIES[g_th3FrequencyIndex];
    
    // ========================================
    // 🤖 SMART LEARNING: Frequency changed
    // یادگیری هوشمند: فرکانس تغییر کرد
    // ========================================
    CheckSmartFeedback();
    
    // Update all AB=CD patterns with new frequency
    UpdateAllTH3Objects();
    
    // Update frequency label
    UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 TH3 Frequency: ", DoubleToString(g_th3FrequencyOverride, 3), "%");
    #endif
}

void DecrementTH3Frequency() {
    if(g_th3FrequencyIndex < 0 || g_th3FrequencyIndex >= TH3_FREQUENCY_COUNT) {
        g_th3FrequencyIndex = 16; // Reset to default (28.125% at index 16)
    }
    
    g_th3FrequencyIndex = (g_th3FrequencyIndex - 1 + TH3_FREQUENCY_COUNT) % TH3_FREQUENCY_COUNT;
    g_th3FrequencyOverride = TH3_TEST_FREQUENCIES[g_th3FrequencyIndex];
    
    // ========================================
    // 🤖 SMART LEARNING: Frequency changed
    // یادگیری هوشمند: فرکانس تغییر کرد
    // ========================================
    CheckSmartFeedback();
    
    // Update all AB=CD patterns with new frequency
    UpdateAllTH3Objects();
    
    // Update frequency label
    UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 TH3 Frequency: ", DoubleToString(g_th3FrequencyOverride, 3), "%");
    #endif
}


//+------------------------------------------------------------------+
//| Find Optimal Frequency with Learning Data                        |
//| پیدا کردن بهترین فرکانس با داده‌های یادگیری                      |
//| Returns: result count + fills waves and consolidation params    |
//+------------------------------------------------------------------+
int FindOptimalFrequencyForABCD_WithLearningData(
    datetime tX, double pX, datetime tA, double pA,
    datetime tB, double pB, datetime tC, double pC,
    FrequencySearchResult &results[],
    WaveAnalysis &waves_out,
    double &consolidationFactor_out,
    double maxErrorPercent = 5.0)
{
    // پاکسازی آرایه نتایج
    ArrayResize(results, 0);
    
    double AB_Distance = MathAbs(pB - pA);
    if(AB_Distance <= 0) return 0;
    
    // تحلیل موج
    waves_out = AnalyzeThreeWaves(tX, pX, tA, pA, tB, pB, tC, pC);
    
    // محاسبه consolidation (استفاده از waves محاسبه شده)
    consolidationFactor_out = CalculateConsolidationFactor(tA, tB, tC, waves_out);
    
    // فراخوانی تابع اصلی
    int resultCount = FindOptimalFrequencyForABCD(tX, pX, tA, pA, tB, pB, tC, pC, results, maxErrorPercent);
    
    return resultCount;
}

