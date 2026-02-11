#define ABCD_MIN_DISTANCE_POINTS 10
#define ABCD_DEBOUNCE_MS 300
#define ABCD_LABEL_OFFSET_PIPS 15.0
#define ABCD_MAX_PRICE_MULTIPLIER 10.0
#define ABCD_COLLINEARITY_THRESHOLD 0.0001
bool g_th3ToolEnabled = false;
    bool g_isDrawingTH3 = false;
    bool g_isDraggingTH3 = false;
    string g_currentDrawingObject = "";
    int g_th3DraggingHandle = -1;
    string g_th3DraggingObject = "";

//+------------------------------------------------------------------+
//| Get Cached Daily ATR (Performance Optimization)                 |

//| Caches ATR for current bar to avoid repeated calculations       |
//+------------------------------------------------------------------+
double GetCachedDailyATR()
{
        static double cachedATR = 0;
    static int cachedBar = -1;
    int currentBar = iBars(_Symbol, PERIOD_D1);
    if(currentBar != cachedBar || IsZero(cachedATR, EPSILON_PRICE)) {
        double atrValue = iATRMQL4(_Symbol, PERIOD_D1, 14, 0);
    cachedBar = currentBar;
    if(atrValue == EMPTY_VALUE || IsZero(atrValue, EPSILON_PRICE) || atrValue < GetCachedPoint() * 10) {
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

//+------------------------------------------------------------------+
void SetActiveABCDPattern(string patternName)
{
        if(g_activeABCDPattern == patternName) return;
    if(g_activeABCDPattern != "") {
        string oldInfoLabel = g_activeABCDPattern + "_Info";
    if(ObjectFind(0, oldInfoLabel) >= 0) {
            ObjectSetInteger(0, oldInfoLabel, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
    g_activeABCDPattern = patternName;
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

//| Analyzes all frequencies to find best default for Steps 3,5,7   |
//+------------------------------------------------------------------+
double CalculateOptimalDefaultFrequency()
{
        double idealFrequencies[3];
    idealFrequencies[0] = 100.0 / 3.0;
    idealFrequencies[1] = 100.0 / 5.0;
    idealFrequencies[2] = 100.0 / 7.0;
    int bestIndices[3] = {-1, -1, -1};

    double minErrors[3] = {1000000.0, 1000000.0, 1000000.0};
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
    double weightedFreq = (TH3_TEST_FREQUENCIES[bestIndices[0]] * 0.25) +
                          (TH3_TEST_FREQUENCIES[bestIndices[1]] * 0.50) +
                          (TH3_TEST_FREQUENCIES[bestIndices[2]] * 0.25);
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
    double GetCurrentTH3Frequency() {
        if(g_th3FrequencyOverride > 0.0) return g_th3FrequencyOverride;
    if(inpTH3BaseStepPercent > 0.0 && inpTH3BaseStepPercent <= 120.0) {
        return inpTH3BaseStepPercent;
    }
    return 28.125;
}

//+------------------------------------------------------------------+
//| Analyze Three-Wave Pattern (XA, AB, BC)                         |

//| Returns comprehensive wave analysis for frequency selection     |
//+------------------------------------------------------------------+
struct WaveAnalysis {
        double XA_Distance;
    double AB_Distance;
    double BC_Distance;
    int XA_Minutes;
    int AB_Minutes;
    int BC_Minutes;
    double XA_Speed;
    double AB_Speed;
    double BC_Speed;
    double XA_Angle;
    double AB_Angle;
    double BC_Angle;
    double AB_XA_Ratio;
    double BC_AB_Ratio;
    double AB_XA_TimeRatio;
    double BC_AB_TimeRatio;
    double AB_XA_SpeedRatio;
    double BC_AB_SpeedRatio;
    double XA_to_AB_Acceleration;
    double AB_to_BC_Acceleration;
    double XA_RawStrength;
    double AB_RawStrength;
    double BC_RawStrength;
    double XA_WeightedStrength;
    double AB_WeightedStrength;
    double BC_WeightedStrength;
    double XA_RelativeStrength;
    double AB_RelativeStrength;
    double BC_RelativeStrength;
    bool isImpulsive;
    bool isCorrectional;
    double avgSpeed;
    double speedConsistency;
    double timeSymmetry;     
};
    WaveAnalysis AnalyzeThreeWaves(datetime tX, double pX, datetime tA, double pA,
                                datetime tB, double pB, datetime tC, double pC)
{
    WaveAnalysis analysis;
    double pipSize = GetCachedPipSize();
    if(!(tX < tA && tA < tB && tB < tC)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AnalyzeThreeWaves: Invalid time ordering (X < A < B < C required)");
    Print("   tX=", TimeToString(tX), ", tA=", TimeToString(tA), ", tB=", TimeToString(tB), ", tC=", TimeToString(tC));
    #endif
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
    
    
    analysis.XA_Distance = MathAbs(pA - pX);
    analysis.AB_Distance = MathAbs(pB - pA);
    analysis.BC_Distance = MathAbs(pC - pB);
    analysis.XA_Minutes = (int)((tA - tX) / 60);
    analysis.AB_Minutes = (int)((tB - tA) / 60);
    analysis.BC_Minutes = (int)((tC - tB) / 60);
    if(analysis.XA_Minutes <= 0) analysis.XA_Minutes = 1;
    if(analysis.AB_Minutes <= 0) analysis.AB_Minutes = 1;
    if(analysis.BC_Minutes <= 0) analysis.BC_Minutes = 1;
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
    
    
    analysis.XA_Angle = CalculateWaveAngle(tX, pX, tA, pA);
    analysis.AB_Angle = CalculateWaveAngle(tA, pA, tB, pB);
    analysis.BC_Angle = CalculateWaveAngle(tB, pB, tC, pC);
    analysis.AB_XA_Ratio = (analysis.XA_Distance > 0) ? (analysis.AB_Distance / analysis.XA_Distance) : 1.0;
    analysis.BC_AB_Ratio = (analysis.AB_Distance > 0) ? (analysis.BC_Distance / analysis.AB_Distance) : 1.0;
    analysis.AB_XA_TimeRatio = (double)analysis.AB_Minutes / analysis.XA_Minutes;
    analysis.BC_AB_TimeRatio = (double)analysis.BC_Minutes / analysis.AB_Minutes;
    analysis.AB_XA_SpeedRatio = (analysis.XA_Speed > 0) ? (analysis.AB_Speed / analysis.XA_Speed) : 1.0;
    analysis.BC_AB_SpeedRatio = (analysis.AB_Speed > 0) ? (analysis.BC_Speed / analysis.AB_Speed) : 1.0;
    double velocityChange_XA_AB = analysis.AB_Speed - analysis.XA_Speed;
    analysis.XA_to_AB_Acceleration = velocityChange_XA_AB / MathMax(analysis.AB_Minutes, 1);
    double velocityChange_AB_BC = analysis.BC_Speed - analysis.AB_Speed;
    analysis.AB_to_BC_Acceleration = velocityChange_AB_BC / MathMax(analysis.BC_Minutes, 1);
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
    
    
    
    analysis.XA_RawStrength = (analysis.XA_Distance / pipSize) / MathMax(analysis.XA_Minutes, 1);
    analysis.AB_RawStrength = (analysis.AB_Distance / pipSize) / MathMax(analysis.AB_Minutes, 1);
    analysis.BC_RawStrength = (analysis.BC_Distance / pipSize) / MathMax(analysis.BC_Minutes, 1);
    if(analysis.XA_RawStrength != analysis.XA_RawStrength) analysis.XA_RawStrength = 0;
    if(analysis.AB_RawStrength != analysis.AB_RawStrength) analysis.AB_RawStrength = 0;
    if(analysis.BC_RawStrength != analysis.BC_RawStrength) analysis.BC_RawStrength = 0;
    double angleWeight_XA = MathSin(analysis.XA_Angle * M_PI / 180.0);
    double angleWeight_AB = MathSin(analysis.AB_Angle * M_PI / 180.0);
    double angleWeight_BC = MathSin(analysis.BC_Angle * M_PI / 180.0);
    analysis.XA_WeightedStrength = analysis.XA_RawStrength * angleWeight_XA;
    analysis.AB_WeightedStrength = analysis.AB_RawStrength * angleWeight_AB;
    analysis.BC_WeightedStrength = analysis.BC_RawStrength * angleWeight_BC;
    if(analysis.XA_WeightedStrength != analysis.XA_WeightedStrength) analysis.XA_WeightedStrength = 0;
    if(analysis.AB_WeightedStrength != analysis.AB_WeightedStrength) analysis.AB_WeightedStrength = 0;
    if(analysis.BC_WeightedStrength != analysis.BC_WeightedStrength) analysis.BC_WeightedStrength = 0;
    double dailyATR = GetCachedDailyATR();
    double dailyATRInPips = dailyATR / pipSize;
    double referenceSpeed = dailyATRInPips / 1440.0;
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    analysis.XA_RelativeStrength = analysis.XA_WeightedStrength / referenceSpeed;
    analysis.AB_RelativeStrength = analysis.AB_WeightedStrength / referenceSpeed;
    analysis.BC_RelativeStrength = analysis.BC_WeightedStrength / referenceSpeed;
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
    
    analysis.avgSpeed = (analysis.XA_Speed + analysis.AB_Speed + analysis.BC_Speed) / 3.0;
    double speedVariance = MathPow(analysis.XA_Speed - analysis.avgSpeed, 2) +
                          MathPow(analysis.AB_Speed - analysis.avgSpeed, 2) +
                          MathPow(analysis.BC_Speed - analysis.avgSpeed, 2);
    double speedStdDev = MathSqrt(speedVariance / 3.0);
    analysis.speedConsistency = (analysis.avgSpeed > 0) ? (1.0 - MathMin(speedStdDev / analysis.avgSpeed, 1.0)) : 0.5;
    if(analysis.speedConsistency != analysis.speedConsistency) analysis.speedConsistency = 0.5;
    double avgSpeedRatio = analysis.avgSpeed / referenceSpeed;
    analysis.isImpulsive = (avgSpeedRatio > 1.2);
    analysis.isCorrectional = (avgSpeedRatio < 0.8);
    analysis.timeSymmetry = CalculateTimeSymmetry(tA, tB, tC);
    return analysis;
}

//+------------------------------------------------------------------+
//| Calculate Wave Angle (Gann Angle)                               |

//| Returns: Angle in degrees (0-90)                                |
//| Logic: angle = atan(price_change / time_change)                 |
//+------------------------------------------------------------------+
double CalculateWaveAngle(datetime tStart, double pStart, datetime tEnd, double pEnd)
{
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
    double priceChange = MathAbs(pEnd - pStart);
    int timeChangeMinutes = (int)((tEnd - tStart) / 60);
    if(timeChangeMinutes <= 0) timeChangeMinutes = 1;
    double pipSize = GetCachedPipSize();
    double priceInPips = priceChange / pipSize;
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
    double referenceSpeed = dailyATRInPips / 1440.0;
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    double actualSpeed = priceInPips / timeChangeMinutes;
    double speedRatio = actualSpeed / referenceSpeed;
    double angle = MathArctan(speedRatio) * 180.0 / M_PI;
    if(angle != angle) angle = 0;
    if(angle < 0) angle = 0;
    if(angle > 90) angle = 90;
    return angle;
}

//+------------------------------------------------------------------+
//| Calculate Required Rest Candles Based on Angle                  |

//| Returns: Number of candles needed for rest/correction           |
//| Complete integer overflow protection               |
//+------------------------------------------------------------------+
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
    if(angle < 0) angle = 0;
    if(angle > 90) angle = 90;
    int restCandles = 0;
    if(angle >= ANGLE_SPIKE_THRESHOLD) {
        double temp = movementCandles * 0.1;
    if(temp > INT_MAX - REST_SPIKE_BASE) {
            restCandles = REST_SPIKE_MAX;
        } else {
            restCandles = REST_SPIKE_BASE + (int)temp;
    if(restCandles > REST_SPIKE_MAX) restCandles = REST_SPIKE_MAX;
        }
    }
    else if(angle >= ANGLE_STRONG_THRESHOLD) {
        double temp = movementCandles * 0.15;
    if(temp > INT_MAX - REST_STRONG_BASE) {
            restCandles = REST_STRONG_MAX;
        } else {
            restCandles = REST_STRONG_BASE + (int)temp;
    if(restCandles > REST_STRONG_MAX) restCandles = REST_STRONG_MAX;
        }
    }
    else if(angle >= ANGLE_BALANCED_THRESHOLD) {
        double temp = movementCandles * 0.2;
    if(temp > INT_MAX - REST_BALANCED_BASE) {
            restCandles = REST_BALANCED_MAX;
        } else {
            restCandles = REST_BALANCED_BASE + (int)temp;
    if(restCandles > REST_BALANCED_MAX) restCandles = REST_BALANCED_MAX;
        }
    }
    else if(angle >= ANGLE_SLOW_THRESHOLD) {
        double temp = movementCandles * 0.25;
    if(temp > INT_MAX - REST_SLOW_BASE) {
            restCandles = REST_SLOW_MAX;
        } else {
            restCandles = REST_SLOW_BASE + (int)temp;
    if(restCandles > REST_SLOW_MAX) restCandles = REST_SLOW_MAX;
        }
    }
    else {
        double temp = movementCandles * 0.3;
    if(temp > INT_MAX - REST_VERY_SLOW_BASE) {
            restCandles = REST_VERY_SLOW_MAX;
        } else {
            restCandles = REST_VERY_SLOW_BASE + (int)temp;
    if(restCandles > REST_VERY_SLOW_MAX) restCandles = REST_VERY_SLOW_MAX;
        }
    }
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

//| Returns: TH percentage for reference timeframe                  |
//| Logic: Wave size (in TH units) determines structure timeframe   |
//+------------------------------------------------------------------+
double DetermineReferenceTimeframe(double waveDistance, double currentTH)
{
        double waveSizeInTH = (currentTH > 0) ? (waveDistance / currentTH) : 0;
    double targetTHMultiplier = waveSizeInTH / 3.0;
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

//| Considers: angle, rest candles, energy buildup                  |
//| OPTIMIZED: Uses pre-calculated wave analysis                    |
//+------------------------------------------------------------------+
double CalculateConsolidationFactor(datetime tA, datetime tB, datetime tC, 
                                     WaveAnalysis &waves)
{
        double angleAB = waves.AB_Angle;
    int barA = iBarShift(_Symbol, _Period, tA);
    int barB = iBarShift(_Symbol, _Period, tB);
    int barC = iBarShift(_Symbol, _Period, tC);
    int AB_Candles = MathAbs(barA - barB);
    int BC_Candles = MathAbs(barB - barC);
    if(AB_Candles < 1) AB_Candles = 1;
    if(BC_Candles < 1) BC_Candles = 1;
    int requiredRestCandles = CalculateRequiredRestCandles(angleAB, AB_Candles);
    double restRatio = (double)BC_Candles / requiredRestCandles;
    double consolidationFactor = 0.0;
    if(restRatio < 0.3) {
        
        
        consolidationFactor = 0.9;
    }
    else if(restRatio < 0.6) {
        
        
        consolidationFactor = 0.7;
    }
    else if(restRatio < 1.0) {
        
        
        consolidationFactor = 0.4;
    }
    else if(restRatio < 1.5) {
        
        
        consolidationFactor = 0.1;
    }
    else {
        
        
        consolidationFactor = 0.0;
    }
    if(angleAB >= 80) {
        consolidationFactor *= 1.3;    }
    else if(angleAB >= 55) {
        consolidationFactor *= 1.15;    }
    if(consolidationFactor > 1.0) consolidationFactor = 1.0;
    if(consolidationFactor < 0.0) consolidationFactor = 0.0;
    return consolidationFactor;
}

//+------------------------------------------------------------------+
//| Calculate Optimal Frequency from Wave Analysis                  |

//| Integrates: speed, consolidation, consistency, Fibonacci        |
//+------------------------------------------------------------------+
double CalculateFrequencyFromWaves(WaveAnalysis &waves)
{
        double baseFrequency = 20.0;
    if(waves.isImpulsive) {
        baseFrequency *= 1.3; 
    }
    else if(waves.isCorrectional) {
        baseFrequency *= 0.7; 
    }
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
    double speedWeight = 1.0;
    if(avgSpeedRatio >= 3.0) {
        speedWeight = 1.5; 
    }
    else if(avgSpeedRatio >= 2.0) {
        speedWeight = 1.3; 
    }
    else if(avgSpeedRatio >= 1.5) {
        speedWeight = 1.15; 
    }
    else if(avgSpeedRatio >= 0.8 && avgSpeedRatio <= 1.2) {
        speedWeight = 1.0; 
    }
    else if(avgSpeedRatio >= 0.5) {
        speedWeight = 0.85; 
    }
    else if(avgSpeedRatio >= 0.33) {
        speedWeight = 0.7; 
    }
    else {
        speedWeight = 0.6; 
    }
    
    baseFrequency *= speedWeight;
    double consistencyFactor = 0.8 + (waves.speedConsistency * 0.4);
    baseFrequency *= consistencyFactor;
    double fibRatios[7] = {0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618};

    double minFibDiff = 1000.0;
    for(int i = 0; i < 7; i++) {
        double diff = MathAbs(waves.AB_XA_Ratio - fibRatios[i]);
    if(diff < minFibDiff) minFibDiff = diff;
    }
    if(minFibDiff < 0.1) {
        baseFrequency *= 1.1; 
    }
    if(baseFrequency < 3.125) baseFrequency = 3.125;
    if(baseFrequency > 120.0) baseFrequency = 120.0;
    return baseFrequency;
}

//| Returns: Speed ratio relative to reference (1.0 = balanced)     |
//| > 1.0 = Fast move, < 1.0 = Slow move                           |
//+------------------------------------------------------------------+
double CalculateMovementSpeed(datetime tA, double pA, datetime tB, double pB)
{
        double priceChange = MathAbs(pB - pA);
    int timeChangeMinutes = (int)((tB - tA) / 60);
    if(timeChangeMinutes <= 0) return 1.0;
    double pipSize = GetCachedPipSize();
    double priceInPips = priceChange / pipSize;
    double speed = priceInPips / timeChangeMinutes;
    double dailyATR = GetCachedDailyATR();
    double dailyATRInPips = dailyATR / pipSize;
    double referenceSpeed = dailyATRInPips / 1440.0;
    if(referenceSpeed <= 0) referenceSpeed = 0.1;
    double speedRatio = speed / referenceSpeed;
    if(speedRatio < 0.1) speedRatio = 0.1;
    if(speedRatio > 10.0) speedRatio = 10.0;
    return speedRatio;
}

//+------------------------------------------------------------------+
//| Calculate Time Symmetry Factor                                  |

//| Perfect symmetry (AB time = BC time) = 1.0                      |
//+------------------------------------------------------------------+
double CalculateTimeSymmetry(datetime tA, datetime tB, datetime tC)
{
        int timeAB = (int)((tB - tA) / 60);
    int timeBC = (int)((tC - tB) / 60);
    if(timeAB <= 0 || timeBC <= 0) return 1.0;
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

//+------------------------------------------------------------------+
struct FrequencySearchResult {
        double frequency;
    int frequencyIndex;
    int targetStep;
    double errorPercent;
    double calculatedD;
    double targetPrice;
    double errorPips;
    double gannAngle;
    double angleWeight;
    double timeSymmetry;
    double totalScore;       
};

//+------------------------------------------------------------------+
//| Analyze Harmonic Properties (Scientific Analysis)               |

//| Returns: Detailed analysis of harmonic ratios                   |
//+------------------------------------------------------------------+
void AnalyzeHarmonicProperties(WaveAnalysis &waves)
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🎵 HARMONIC ANALYSIS (SCIENTIFIC)");
    Print("========================================");
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
    double phi = 1.618033988749;
    double phiInverse = 0.618033988749;
    #ifdef ENABLE_DEBUG_LOGS
    Print("📐 GOLDEN RATIO (φ = 1.618):");
    #endif
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

//| Returns: Error percentage (0 = perfect match)                   |
//| Added division by zero protection                 |
//+------------------------------------------------------------------+
double CalculateFrequencyError(double pA, double pB, double pC, 
                               double frequency, int targetStep,
                               double &calculatedD, double &targetPrice)
{
        double AB_Distance = MathAbs(pB - pA);
    double minDistance = GetCachedPoint() * 10;
    if(AB_Distance < minDistance) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateFrequencyError: AB distance too small (", 
              DoubleToString(AB_Distance, Digits), ") - minimum ", 
              DoubleToString(minDistance, Digits), " required");
    #endif
    calculatedD = 0.0;
    targetPrice = 0.0;
    return 999.99;    }
    bool isBullish = (pB > pA);
    double baseUnit = AB_Distance * (frequency / 100.0);
    double pD;
    if(isBullish) {
        pD = pC + AB_Distance;
    } else {
        pD = pC - AB_Distance;
    }
    calculatedD = pD;
    double stepPrice;
    if(isBullish) {
        stepPrice = pC + (targetStep * baseUnit);
    } else {
        stepPrice = pC - (targetStep * baseUnit);
    }
    targetPrice = stepPrice;
    double error = MathAbs(pD - stepPrice);
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

//| Returns: Minimum deviation from standard Fibonacci ratios       |
//+------------------------------------------------------------------+
double CalculateFibonacciDeviation(double ratio)
{
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

//| Multi-factor scoring: error, wave analysis, Fibonacci, symmetry |
//+------------------------------------------------------------------+
int FindOptimalFrequencyForABCD(datetime tX, double pX, datetime tA, double pA, 
                                datetime tB, double pB, datetime tC, double pC,
                                FrequencySearchResult &results[],
                                double maxErrorPercent = 5.0)
{
    
    ArrayResize(results, 0);
    double AB_Distance = MathAbs(pB - pA);
    if(AB_Distance <= 0) return 0;
    double pipSize = GetCachedPipSize();
    WaveAnalysis waves = AnalyzeThreeWaves(tX, pX, tA, pA, tB, pB, tC, pC);
    AnalyzeHarmonicProperties(waves);
    double suggestedFreq = CalculateFrequencyFromWaves(waves);
    double speedRatio = CalculateMovementSpeed(tA, pA, tB, pB);
    double timeSymmetry = waves.timeSymmetry;
    double fibDeviation = CalculateFibonacciDeviation(waves.AB_XA_Ratio);
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
    double gannAngle = waves.AB_Angle;
    double bcToAbRatio = 0.0;
    if(waves.AB_Distance > 0) {
        bcToAbRatio = waves.BC_Distance / waves.AB_Distance;
    }
    string harmonicPattern = "NONE";
    double harmonicConfidence = 0.0;
    double prz_Frequency = 0.0;
    if(waves.AB_XA_Ratio >= 0.580 && waves.AB_XA_Ratio <= 0.660) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "GARTLEY";
    harmonicConfidence = 0.786;
    prz_Frequency = 28.0 + (bcToAbRatio * 30.0);        }
    }
    else if(waves.AB_XA_Ratio >= 0.382 && waves.AB_XA_Ratio <= 0.500) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "BAT";
    harmonicConfidence = 0.886;
    prz_Frequency = 35.0 + (bcToAbRatio * 25.0);        }
    }
    else if(waves.AB_XA_Ratio >= 0.750 && waves.AB_XA_Ratio <= 0.820) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "BUTTERFLY";
    harmonicConfidence = 1.272;
    prz_Frequency = 45.0 + (bcToAbRatio * 35.0);        }
    }
    else if(waves.AB_XA_Ratio >= 0.382 && waves.AB_XA_Ratio <= 0.618) {
        if(bcToAbRatio >= 0.382 && bcToAbRatio <= 0.886) {
            harmonicPattern = "CRAB";
    harmonicConfidence = 1.618;
    prz_Frequency = 50.0 + (bcToAbRatio * 40.0);        }
    }
    double medianPrice = (pX + pA + pB) / 3.0;
    double currentDistanceFromMedian = MathAbs(pC - medianPrice);
    double maxDistanceFromMedian = MathMax(MathAbs(pA - medianPrice), MathAbs(pB - medianPrice));
    double medianLineDeviation = 0.0;
    if(maxDistanceFromMedian > 0) {
        medianLineDeviation = currentDistanceFromMedian / maxDistanceFromMedian;
    }
    bool strongMedianLinePull = (medianLineDeviation > 0.8);
    bool moderateMedianLinePull = (medianLineDeviation > 0.5 && medianLineDeviation <= 0.8);
    double medianLineFrequency = 0.0;
    if(strongMedianLinePull) {
        
        medianLineFrequency = 55.0 + (medianLineDeviation * 30.0);    } else if(moderateMedianLinePull) {
        
        medianLineFrequency = 35.0 + (medianLineDeviation * 30.0);    }
    bool isValidABCD = false;
    double abcdScore = 0.0;
    double bcRetracementError = MathAbs(bcToAbRatio - 0.618);
    if(bcRetracementError < 0.15) {  
        isValidABCD = true;
    abcdScore = 1.0 - (bcRetracementError / 0.15);    }
    bool isStrongImpulsive = (gannAngle > 75.0 && consolidationFactor < 0.1);
    bool isMediumImpulsive = (gannAngle >= 50.0 && gannAngle <= 75.0 && consolidationFactor < 0.1);
    bool hasDeepRetracement = (bcToAbRatio > 0.7);
    bool hasGoodTimeSymmetry = (timeSymmetry > 0.8);
    #ifdef ENABLE_DEBUG_LOGS
    Print("========================================");
    Print("🎯 ADVANCED HARMONIC & PITCHFORK ANALYSIS:");
    Print("========================================");
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
    int targetSteps[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

    int primarySteps[3] = {3, 5, 7};
    if(isStrongImpulsive) {
        primarySteps[0] = 2;
    primarySteps[1] = 3;
    primarySteps[2] = 4;
    }
    
    else if(isMediumImpulsive) {
        primarySteps[0] = 2;
    primarySteps[1] = 3;
    primarySteps[2] = 5;
    }
    bool candidateFreqs[77];
    ArrayInitialize(candidateFreqs, false);
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
    int startIdx = MathMax(0, closestIdx - 5);
    int endIdx = MathMin(TH3_FREQUENCY_COUNT - 1, closestIdx + 5);
    for(int i = startIdx; i <= endIdx; i++)
        {
            candidateFreqs[i] = true;
        }
    }
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
    int startIdx = MathMax(0, closestIdx - 3);
    int endIdx = MathMin(TH3_FREQUENCY_COUNT - 1, closestIdx + 3);
    for(int i = startIdx; i <= endIdx; i++)
        {
            candidateFreqs[i] = true;
        }
    }
    if(isStrongImpulsive) {
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
        if(TH3_TEST_FREQUENCIES[i] >= 50.0 && TH3_TEST_FREQUENCIES[i] <= 70.0)
            {
                candidateFreqs[i] = true;
            }
        }
    }
    
    else if(isMediumImpulsive) {
        for(int i = 0; i < TH3_FREQUENCY_COUNT; i++)
        {
        if(TH3_TEST_FREQUENCIES[i] >= 35.0 && TH3_TEST_FREQUENCIES[i] <= 50.0)
            {
                candidateFreqs[i] = true;
            }
        }
    }
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
    LearnedWeights learnedWeights = GetLearnedWeights();
    double stepPriority = 1.0;
    if(testStep == 5) {
                stepPriority = learnedWeights.step5Priority;  
            } else if(testStep == 3 || testStep == 7) {
                stepPriority = learnedWeights.step3_7Priority;  
            } else if(testStep == 1) {
                stepPriority = learnedWeights.step1Priority;  
            }
    double errorScore = errorPercent * learnedWeights.errorWeight;
    double speedConsistencyWeight = learnedWeights.speedConsistencyWeight;
    if(isStrongImpulsive) {
                speedConsistencyWeight *= 0.3;  
            }
            else if(isMediumImpulsive) {
                speedConsistencyWeight *= 0.5;  
            }
    double speedScore = (1.0 - waves.speedConsistency) * 20.0 * speedConsistencyWeight;
    double timeSymmetryWeight = learnedWeights.timeSymmetryWeight;
    if(isStrongImpulsive && hasDeepRetracement) {
                timeSymmetryWeight *= 0.2;  
            }
            else if(isMediumImpulsive && hasGoodTimeSymmetry) {
                timeSymmetryWeight *= 0.5;  
            }
    double timeScore = (1.0 - timeSymmetry) * 100.0 * timeSymmetryWeight;
    double fibScore = fibDeviation * 100.0 * learnedWeights.fibonacciWeight;
    double freqDeviation = 0.0;
    if(suggestedFreq > 0) {
                freqDeviation = MathAbs(testFreq - suggestedFreq) / suggestedFreq;
            }
    double freqScore = freqDeviation * 100.0 * learnedWeights.freqDeviationWeight;
    double consolidationPenalty = 0.0;
    if(consolidationFactor > 0.3) {
        if(testFreq < suggestedFreq) {
        double freqRatio = testFreq / suggestedFreq;
    consolidationPenalty = (1.0 - freqRatio) * consolidationFactor * 100.0 * learnedWeights.consolidationWeight;
                }
            }
    double stepPriorityScore = stepPriority * learnedWeights.stepPriorityWeight;
    double impulsiveBonus = 0.0;
    if(isStrongImpulsive) {
        if(testFreq >= 50.0 && testFreq <= 70.0) {
                    impulsiveBonus = -50.0;  
                }
                
                else if(testFreq < 30.0) {
                    impulsiveBonus = 100.0;  
                }
            }
            else if(isMediumImpulsive) {
        if(testFreq >= 35.0 && testFreq <= 50.0) {
                    impulsiveBonus = -30.0;  
                }
                
                else if(testFreq < 25.0) {
                    impulsiveBonus = 80.0;  
                }
    if(hasGoodTimeSymmetry && testFreq >= 40.0 && testFreq <= 45.0) {
                    impulsiveBonus -= 20.0;  
                }
            }
    double harmonicBonus = 0.0;
    if(harmonicPattern != "NONE" && prz_Frequency > 0) {
        double przDeviation = MathAbs(testFreq - prz_Frequency) / prz_Frequency;
    if(przDeviation < 0.15) {                    harmonicBonus = -40.0 * (1.0 - przDeviation / 0.15);
    if(harmonicPattern == "CRAB") harmonicBonus *= 1.3;
    else if(harmonicPattern == "BUTTERFLY") harmonicBonus *= 1.2;
    else if(harmonicPattern == "BAT") harmonicBonus *= 1.1;
                }
            }
    double medianLineBonus = 0.0;
    if(medianLineFrequency > 0) {
        double medianDeviation = MathAbs(testFreq - medianLineFrequency) / medianLineFrequency;
    if(medianDeviation < 0.20) {
        if(strongMedianLinePull) {
                        
                        medianLineBonus = -35.0 * (1.0 - medianDeviation / 0.20);                    } else if(moderateMedianLinePull) {
                        
                        medianLineBonus = -20.0 * (1.0 - medianDeviation / 0.20);                    }
                }
            }
    double abcdBonus = 0.0;
    if(isValidABCD) {
        if(testFreq >= 25.0 && testFreq <= 45.0) {
                    abcdBonus = -30.0 * abcdScore;
    if(testFreq >= 36.0 && testFreq <= 40.0) {
                        abcdBonus -= 15.0;                    }
                }
            }
    double accelerationScore = 0.0;
    if(waves.AB_to_BC_Acceleration > 0.001) {
        double accelRatio = MathMin(waves.AB_to_BC_Acceleration / 0.01, 1.0);
    accelerationScore = -20.0 * accelRatio;            }
            
            else if(waves.AB_to_BC_Acceleration < -0.001) {
        double accelRatio = MathMin(MathAbs(waves.AB_to_BC_Acceleration) / 0.01, 1.0);
    accelerationScore = 20.0 * accelRatio;            }
    double strengthScore = 0.0;
    if(waves.BC_RelativeStrength > 2.0) {
                
                strengthScore = -25.0;
            } else if(waves.BC_RelativeStrength < 1.0) {
                
                strengthScore = 25.0;
            }
    double strengthRatio = waves.BC_RelativeStrength / MathMax(waves.AB_RelativeStrength, 0.1);
    if(strengthRatio > 1.2) {
                
                strengthScore -= 15.0;
            } else if(strengthRatio < 0.8) {
                
                strengthScore += 15.0;
            }
    double confidence = 100.0;
    if(waves.speedConsistency < 0.5) confidence -= 30.0;
    if(timeSymmetry < 0.6) confidence -= 20.0;
    if(fibDeviation > 0.15) confidence -= 15.0;
    if(errorPercent > 3.0) confidence -= 25.0;
    if(harmonicPattern != "NONE") confidence += 15.0;
    if(isValidABCD) confidence += 10.0;
    if(waves.BC_RelativeStrength > 2.0) confidence += 10.0;
    if(MathAbs(waves.AB_to_BC_Acceleration) < 0.001) confidence += 5.0;
    if(confidence < 0) confidence = 0;
    if(confidence > 100) confidence = 100;
    double confidencePenalty = 0.0;
    if(confidence < 50.0) {
                confidencePenalty = 50.0 * (1.0 - confidence / 50.0);            }
    double harmonicMeanScore = 0.0;
    if(waves.XA_Speed > 0 && waves.AB_Speed > 0 && waves.BC_Speed > 0) {
        double recipSum = (1.0/waves.XA_Speed) + (1.0/waves.AB_Speed) + (1.0/waves.BC_Speed);
    double harmonicMean = 3.0 / recipSum;
    double arithmeticMean = (waves.XA_Speed + waves.AB_Speed + waves.BC_Speed) / 3.0;
    double meanRatio = harmonicMean / arithmeticMean;
    if(meanRatio > 0.9) {
                    harmonicMeanScore = -15.0 * ((meanRatio - 0.9) / 0.1);                }
                
                else if(meanRatio < 0.7) {
                    harmonicMeanScore = 15.0 * ((0.7 - meanRatio) / 0.3);                }
    #ifdef ENABLE_DEBUG_LOGS
                Print("   Harmonic Mean: ", DoubleToString(harmonicMean, 2), " pips/min");
    Print("   Arithmetic Mean: ", DoubleToString(arithmeticMean, 2), " pips/min");
    Print("   Ratio: ", DoubleToString(meanRatio, 3), 
                      " (", meanRatio > 0.9 ? "✅ Consistent" : (meanRatio < 0.7 ? "⚠️ Inconsistent" : "➡️ Moderate"), ")");
    #endif
    }
    double phiRatioScore = 0.0;
    double phi = 1.618033988749;
    double phiInverse = 0.618033988749;
    double phiDeviation_AB_XA = MathAbs(waves.AB_XA_Ratio - phiInverse);
    if(phiDeviation_AB_XA < 0.05) {                
                phiRatioScore -= 20.0 * (1.0 - phiDeviation_AB_XA / 0.05);
    #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Golden Ratio detected in AB/XA: ", DoubleToString(waves.AB_XA_Ratio, 3));
    #endif
    }
    double phiDeviation_BC_AB = MathAbs(waves.BC_AB_Ratio - phiInverse);
    if(phiDeviation_BC_AB < 0.05) {                phiRatioScore -= 15.0 * (1.0 - phiDeviation_BC_AB / 0.05);
    #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Golden Ratio detected in BC/AB: ", DoubleToString(waves.BC_AB_Ratio, 3));
    #endif
    }
    double phiDeviation_AB_XA_ext = MathAbs(waves.AB_XA_Ratio - phi);
    if(phiDeviation_AB_XA_ext < 0.08) {  
                phiRatioScore -= 12.0 * (1.0 - phiDeviation_AB_XA_ext / 0.08);
    #ifdef ENABLE_DEBUG_LOGS
                Print("   ✨ Phi Extension detected in AB/XA: ", DoubleToString(waves.AB_XA_Ratio, 3));
    #endif
    }
    double totalScore = (errorScore + speedScore + timeScore + fibScore + freqScore + consolidationPenalty) 
                              * stepPriority * (1.0 + stepPriorityScore) 
                              + impulsiveBonus + harmonicBonus + medianLineBonus + abcdBonus
                              + accelerationScore + strengthScore + confidencePenalty
                              + harmonicMeanScore + phiRatioScore;
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

//+------------------------------------------------------------------+
bool AutoSelectBestFrequency(string patternName)
{
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
    if(tA <= 0 || tB <= 0 || tC <= 0 || pA <= 0 || pB <= 0 || pC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Invalid pattern data");
    #endif
    return false;
    }
    int barA = iBarShift(_Symbol, _Period, tA);
    int barB = iBarShift(_Symbol, _Period, tB);
    int AB_Bars = barA - barB;
    if(AB_Bars < 1) AB_Bars = 1;
    int barX = barA + AB_Bars;
    datetime tX = iTime(_Symbol, 0, barX);
    if(tX <= 0 || tX >= tA) {
        
        tX = tA - (tB - tA);
    if(tX <= 0) tX = tA - 3600; 
    }
    bool isABBullish = (pB > pA);
    double AB_Distance = MathAbs(pB - pA);
    double pX;
    if(isABBullish) {
        
        
        
        pX = pA + (AB_Distance * 0.618); 
    } else {
        
        
        
        pX = pA - (AB_Distance * 0.618); 
    }
    if(pX <= 0) {
        if(isABBullish) {
            pX = pA + (AB_Distance * 0.5); 
        } else {
            pX = pA - (AB_Distance * 0.5);
        }
    }
    if(pX <= 0) pX = pA;
    FrequencySearchResult results[];
    ArrayResize(results, 0);
    bool hasValidX = (MathAbs(pX - pA) > MathAbs(pB - pA) * 0.1);
    int resultCount;
    if(hasValidX) {
        
        resultCount = FindOptimalFrequencyForABCD(tX, pX, tA, pA, tB, pB, tC, pC, results, 5.0);
    } else {
        
        
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
    double bestFreq = results[0].frequency;
    int bestIndex = results[0].frequencyIndex;
    g_th3FrequencyOverride = bestFreq;
    g_th3FrequencyIndex = bestIndex;
    string chartIdStr = GetCachedChartIdStr();
    string freqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    string indexGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
    GlobalVariableSet(freqGvarName, bestFreq);
    GlobalVariableSet(indexGvarName, bestIndex);
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Frequency applied successfully");
    #endif
    UpdateTH3FrequencyLabel(bestFreq);
    return true;
}

//+------------------------------------------------------------------+
//| Calculate AB=CD Point D (with 9-level validation)               |

//| Rule: AB distance = CD distance (equal price movement)          |
//+------------------------------------------------------------------+
bool CalculateABCDPointD(datetime tA, double pA, datetime tB, double pB,
                         datetime tC, double pC, datetime &tD, double &pD)
{
        if(tA <= 0 || tB <= 0 || tC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Invalid time inputs");
    #endif
    return false;
    }
    if(pA <= 0 || pB <= 0 || pC <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Invalid price inputs");
    #endif
    return false;
    }    
    if(!(tA < tB && tB < tC)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ AB=CD Warning: Time ordering violated (A < B < C) - allowing during drag");
    #endif
    }
    double AB_Distance = MathAbs(pB - pA);
    double BC_Distance = MathAbs(pC - pB);
    double minDistance = GetCachedPoint() * ABCD_MIN_DISTANCE_POINTS;
    if(AB_Distance < minDistance) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: AB distance too small (min: ", minDistance, ")");
    #endif
    return false;
    }
    bool isBullish = (pB > pA);
    double CD_Distance = AB_Distance;
    if(isBullish) {
        pD = pC + CD_Distance;    } else {
        pD = pC - CD_Distance;    }
    int BC_Bars = iBarShift(_Symbol, _Period, tB) - iBarShift(_Symbol, _Period, tC);
    if(BC_Bars < 1) BC_Bars = 1;
    int CD_Bars = BC_Bars;
    int barD = iBarShift(_Symbol, _Period, tC) - CD_Bars;
    if(barD < 0) barD = 0;
    tD = iTime(_Symbol, 0, barD);
    if(tD <= 0) tD = tC + (tC - tB);
    if(pD <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ AB=CD Error: Calculated D price is zero or negative");
    #endif
    return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Draw AB=CD Pattern with TH3-style Steps                         |

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
    double labelOffset;
    if(inpABCDLabelOffsetPercent > 0) {
        double avgCandleSize = 0;
    int lookback = 20;
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
            avgCandleSize = GetCachedPipSize() * 10;
        }
        
        labelOffset = avgCandleSize * (inpABCDLabelOffsetPercent / 100.0);
    double minOffset = 2.0 * pipSize;
    double maxOffset = 15.0 * pipSize;
    if(labelOffset < minOffset) labelOffset = minOffset;
    if(labelOffset > maxOffset) labelOffset = maxOffset;
    } else {
        double avgCandleSize = 0;
    int lookback = 10;
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
            avgCandleSize = GetCachedPipSize() * 50;
        }
    labelOffset = avgCandleSize * 0.10;
    double minOffset = 2.0 * pipSize;
    double maxOffset = 10.0 * pipSize;
    if(labelOffset < minOffset) labelOffset = minOffset;
    if(labelOffset > maxOffset) labelOffset = maxOffset;
    }
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
    for(int i = 0; i < 3; i++) {
        string pointName = mainObjName + "_Point_" + pointNames[i];
    double pointPrice = pointPrices[i];
    if(ObjectFind(0, pointName) < 0) {
            if(!ObjectCreate(0, pointName, OBJ_ARROW, 0, pointTimes[i], pointPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ Failed to create point ", pointNames[i], " | Error: ", GetLastError());
    #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
                Print("✅ Created point ", pointNames[i], " at ", TimeToString(pointTimes[i]), " @ ", DoubleToString(pointPrices[i], Digits));
    #endif
    }
    ObjectSetInteger(0, pointName, OBJPROP_COLOR, inpABCDPointColor);
    ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159);
    ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, pointName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, pointName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, pointName, OBJPROP_BACK, false);
    ObjectSetInteger(0, pointName, OBJPROP_ZORDER, 10);
    ObjectSetString(0, pointName, OBJPROP_TOOLTIP, "📍 Point " + pointNames[i] + " | Drag to adjust");
        } else {            ObjectMove(0, pointName, 0, pointTimes[i], pointPrice);
    #ifdef ENABLE_DEBUG_LOGS
            Print("🔄 Updated existing point ", pointNames[i]);
    #endif
    }
    if(inpABCDShowLabels) {
        string labelName = mainObjName + "_Label_" + pointNames[i];
    if(ObjectFind(0, labelName) >= 0) {
                ObjectDelete(0, labelName);
            }
        }
    }
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
    double zoneHeightPercent = inpTH3ZoneHeightPercent / 100.0;
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
        } else {            ObjectMove(0, lineName, 0, startTime, centerPrice);
    ObjectMove(0, lineName, 1, endTime, centerPrice);
    if(inpTH3LabelPosition != TH3_LABEL_HIDDEN) {
        double zonePips = (zoneHalfWidth * 2.0) / pipSize;
    string labelText = StringFormat("%s (%.1f) ±%.1f", targetNames[i], targetPips[i], zonePips/2.0);
    ObjectSetString(0, lineName, OBJPROP_LEVELTEXT, 0, labelText);
            }
        }
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
    double pips_AB = AB_Distance / pipSize;
    double pips_BC = MathAbs(pC - pB) / pipSize;
    string infoText = StringFormat("AB=CD | AB:%.1f | BC:%.1f | Freq:%.1f%%", 
                                   pips_AB, pips_BC, frequency);
    string infoLabel = mainObjName + "_Info";
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
    ObjectSetInteger(0, infoLabel, OBJPROP_TIMEFRAMES, isActive ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
    } else {        ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
    ObjectSetInteger(0, infoLabel, OBJPROP_CORNER, inpABCDInfoCorner);
    ObjectSetInteger(0, infoLabel, OBJPROP_XDISTANCE, inpABCDInfoXDistance);
    ObjectSetInteger(0, infoLabel, OBJPROP_YDISTANCE, inpABCDInfoYDistance);
    ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, inpABCDInfoColor);
    ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, inpABCDInfoFontSize);
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

//+------------------------------------------------------------------+
void UpdateAllTH3Objects() {
        int updatedCount = 0;
    int totalObjects = ObjectsTotal(0, 0, -1);
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔍 UpdateAllTH3Objects: Searching ", totalObjects, " objects for AB=CD patterns...");
    #endif
    string patternNames[];
    int patternCount = 0;
    ArrayResize(patternNames, 0);
    for(int i = 0; i < totalObjects; i++) {
        string name = ObjectName(0, i, 0, -1);
    if(StringFind(name, "ABCD_Pattern_") == 0) {
        string baseName = "";
    int searchStart = 13;
    int underscorePos = StringFind(name, "_", searchStart);
    if(underscorePos > searchStart) {
                baseName = StringSubstr(name, 0, underscorePos);
            } else {                baseName = name;
            }
    bool exists = false;
    for(int j = 0; j < patternCount; j++) {
        if(patternNames[j] == baseName) {
                    exists = true;
    break;
                }
            }
            
            if(!exists) {
                ArrayResize(patternNames, patternCount + 1);
    patternNames[patternCount] = baseName;
    patternCount++;
            }
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("📊 Found ", patternCount, " unique AB=CD patterns");
    #endif
    for(int p = 0; p < patternCount; p++) {
        string baseName = patternNames[p];
    string lineAB = baseName + "_Line_AB";
    string lineBC = baseName + "_Line_BC";
    if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ Pattern ", baseName, " missing lines - skipping");
    #endif
    continue;
        }
    datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
    double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
    datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
    double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
    datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
    double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
    if(tA > 0 && tB > 0 && tC > 0 && pA > 0 && pB > 0 && pC > 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("🔄 Updating pattern: ", baseName, " with frequency: ", DoubleToString(GetCurrentTH3Frequency(), 3), "%");
    #endif
    DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
    updatedCount++;
        } else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ Pattern ", baseName, " has invalid data - skipping");
    #endif
    }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Updated ", updatedCount, " AB=CD patterns with frequency: ", 
          DoubleToString(GetCurrentTH3Frequency(), 3), "%");
    #endif
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Helper: Create ABCD temporary point marker on chart             |

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

//+------------------------------------------------------------------+
void OnABCDMouseEvent(int id, long lparam, double dparam, string sparam) {
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
    static bool s_lastLeftButtonState = false;
    if(g_abcdDrawing && leftButtonDown && !s_lastLeftButtonState) {            s_lastLeftButtonState = true;
    #ifdef ENABLE_DEBUG_LOGS
            Print("🖱️ Left button pressed via MOUSE_MOVE | lparam=", lparam, " dparam=", dparam);
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
            Print("✅ Click detected | time=", TimeToString(clickTime), " price=", DoubleToString(clickPrice, Digits), " | pointCount=", g_abcdPointCount);
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
                    
                    g_th3FrequencyOverride = searchResults[0].frequency;
    g_th3FrequencyIndex = searchResults[0].frequencyIndex;
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
    SetActiveABCDPattern(patternName);
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
    UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
    ChartRedraw();
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ AB=CD pattern created: ", patternName);
    #endif
    }
        }
        else if(!leftButtonDown && s_lastLeftButtonState) {            s_lastLeftButtonState = false;
        }
        
        return;
    }
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
    if(id == CHARTEVENT_OBJECT_DRAG) {
        if(StringFind(sparam, "ABCD_Pattern_") == 0 && StringFind(sparam, "_Point_") > 0) {
        int pointPos = StringFind(sparam, "_Point_");
    string baseName = StringSubstr(sparam, 0, pointPos);
    string pointName = StringSubstr(sparam, pointPos + 7);
    if(pointName != "A" && pointName != "B" && pointName != "C") return;
    SetActiveABCDPattern(baseName);
    string draggedPoint = baseName + "_Point_" + pointName;
    datetime newTime = (datetime)ObjectGetInteger(0, draggedPoint, OBJPROP_TIME, 0);
    double newPrice = ObjectGetDouble(0, draggedPoint, OBJPROP_PRICE, 0);
    int barIndex = iBarShift(_Symbol, _Period, newTime);
    if(barIndex >= 0) {
        double high = iHigh(_Symbol, 0, barIndex);
    double low = iLow(_Symbol, 0, barIndex);
    double open = iOpen(_Symbol, 0, barIndex);
    double close = iClose(_Symbol, 0, barIndex);
    double pipSize = GetCachedPipSize();
    double distToHigh = MathAbs(newPrice - high) / pipSize;
    double distToLow = MathAbs(newPrice - low) / pipSize;
    double distToOpen = MathAbs(newPrice - open) / pipSize;
    double distToClose = MathAbs(newPrice - close) / pipSize;
    double snapThreshold = 5.0;
    double minDist = MathMin(MathMin(distToHigh, distToLow), MathMin(distToOpen, distToClose));
    if(minDist <= snapThreshold) {
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
    ObjectSetDouble(0, draggedPoint, OBJPROP_PRICE, newPrice);
                }            }
    string lineAB = baseName + "_Line_AB";
    string lineBC = baseName + "_Line_BC";
    if(ObjectFind(0, lineAB) < 0 || ObjectFind(0, lineBC) < 0) return;
    datetime tA = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 0);
    double pA = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 0);
    if(ObjectFind(0, lineAB) < 0) return;
    datetime tB = (datetime)ObjectGetInteger(0, lineAB, OBJPROP_TIME, 1);
    double pB = ObjectGetDouble(0, lineAB, OBJPROP_PRICE, 1);
    if(ObjectFind(0, lineBC) < 0) return;
    datetime tC = (datetime)ObjectGetInteger(0, lineBC, OBJPROP_TIME, 1);
    double pC = ObjectGetDouble(0, lineBC, OBJPROP_PRICE, 1);
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
    DrawABCDPattern(baseName, tA, pA, tB, pB, tC, pC);
        }
    }
    if(id == CHARTEVENT_OBJECT_DELETE) {
        if(StringFind(sparam, "ABCD_Pattern_") == 0) {
        string baseName = sparam;
    int underscorePos = -1;
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
    if(StringFind(baseName, "ABCD_Pattern_") != 0 || StringLen(baseName) < 20) {                return;
            }
    #ifdef ENABLE_DEBUG_LOGS
            Print("🗑️ Deleting AB=CD pattern: ", baseName);
    Print("   Triggered by object: ", sparam);
    #endif
    string pointNames[3] = {"A", "B", "C"};
    for(int i = 0; i < 3; i++) {
                ObjectDelete(0, baseName + "_Point_" + pointNames[i]);
    ObjectDelete(0, baseName + "_Label_" + pointNames[i]);
            }
    ObjectDelete(0, baseName + "_Line_AB");
    ObjectDelete(0, baseName + "_Line_BC");
    ObjectDelete(0, baseName + "_Info");
    for(int i = 1; i <= 7; i++) {
                ObjectDelete(0, baseName + "_Target_" + IntegerToString(i));
    ObjectDelete(0, baseName + "_ZoneUpper_" + IntegerToString(i));
    ObjectDelete(0, baseName + "_ZoneLower_" + IntegerToString(i));
            }            
            ObjectDelete(0, baseName + "_Temp_X");
    ObjectDelete(0, baseName + "_Temp_A");
    ObjectDelete(0, baseName + "_Temp_B");
    ObjectDelete(0, baseName + "_Temp_C");
    ObjectDelete(0, baseName + "_Temp_Line_XA");
    ObjectDelete(0, baseName + "_Temp_Line_AB");
    ObjectDelete(0, baseName + "_Temp_Line_BC");
    if(g_activeABCDPattern == baseName) {
                SetActiveABCDPattern("");
            }
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

//+------------------------------------------------------------------+
void ToggleTH3Tool() {
    if(!inpEnableTH3Tool) return;
    if(inpTH3DrawingMode == TH3_MODE_ABCD) {        if(!g_abcdDrawing) {
            g_abcdDrawing = true;
    g_abcdPointCount = 0;
    g_abcdLastClickTime = 0;
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    #ifdef ENABLE_DEBUG_LOGS
            Print("🎯 AB=CD Mode: Click 4 points (X, A, B, C). Right-click to cancel.");
    #endif
    } else {            g_abcdDrawing = false;
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

//+------------------------------------------------------------------+
void CycleTH3Frequency() {
        if(g_th3FrequencyIndex < 0 || g_th3FrequencyIndex >= TH3_FREQUENCY_COUNT) {
        g_th3FrequencyIndex = 16;    }
    
    g_th3FrequencyIndex = (g_th3FrequencyIndex + 1) % TH3_FREQUENCY_COUNT;
    g_th3FrequencyOverride = TH3_TEST_FREQUENCIES[g_th3FrequencyIndex];
    CheckSmartFeedback();
    UpdateAllTH3Objects();
    UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
    ChartRedraw(0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 TH3 Frequency: ", DoubleToString(g_th3FrequencyOverride, 3), "%");
    #endif
    }
    void DecrementTH3Frequency() {
        if(g_th3FrequencyIndex < 0 || g_th3FrequencyIndex >= TH3_FREQUENCY_COUNT) {
        g_th3FrequencyIndex = 16;    }
    
    g_th3FrequencyIndex = (g_th3FrequencyIndex - 1 + TH3_FREQUENCY_COUNT) % TH3_FREQUENCY_COUNT;
    g_th3FrequencyOverride = TH3_TEST_FREQUENCIES[g_th3FrequencyIndex];
    CheckSmartFeedback();
    UpdateAllTH3Objects();
    UpdateTH3FrequencyLabel(g_th3FrequencyOverride);
    ChartRedraw(0);
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔄 TH3 Frequency: ", DoubleToString(g_th3FrequencyOverride, 3), "%");
    #endif
    }

//+------------------------------------------------------------------+
//| Find Optimal Frequency with Learning Data                        |

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
    
    ArrayResize(results, 0);
    double AB_Distance = MathAbs(pB - pA);
    if(AB_Distance <= 0) return 0;
    waves_out = AnalyzeThreeWaves(tX, pX, tA, pA, tB, pB, tC, pC);
    consolidationFactor_out = CalculateConsolidationFactor(tA, tB, tC, waves_out);
    int resultCount = FindOptimalFrequencyForABCD(tX, pX, tA, pA, tB, pB, tC, pC, results, maxErrorPercent);
    return resultCount;
}

