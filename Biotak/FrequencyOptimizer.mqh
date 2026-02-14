//+------------------------------------------------------------------+
//| FrequencyOptimizer.mqh - Optimal Frequency Detection Engine      |
//| Theory: Step3 must land on 50% midpoint of a reference wave.     |
//| The correct frequency aligns Step3 with this reversal point.     |
//| Scoring: 60% midpoint + 25% time(Gann) + 15% harmonic           |
//+------------------------------------------------------------------+
#ifndef FREQUENCY_OPTIMIZER_MQH
#define FREQUENCY_OPTIMIZER_MQH

// FrequencyResult struct is defined in ProjectConstants.mqh
// (included before GlobalVariables.mqh so it can be used as global state)

// Scoring weights (sum = 1.0)
#define WEIGHT_MIDPOINT  0.60
#define WEIGHT_TIME      0.25
#define WEIGHT_HARMONIC  0.15

// Minimum score to accept a frequency as valid
#define MIN_ACCEPTABLE_SCORE 0.10

//+------------------------------------------------------------------+
//| Calculate Step3 price for a given frequency and ABCD pattern     |
//| Step3 = C ± 3 × baseUnit, where baseUnit = AB × (freq/100)     |
//+------------------------------------------------------------------+
double CalculateStep3Price(double pA, double pB, double pC, double frequency) {
    double abDistance = MathAbs(pB - pA);
    if(abDistance <= 0 || frequency <= 0) return 0;

    double baseUnit = abDistance * (frequency / 100.0);
    bool isBullish = (pB > pA);

    // Step3 = C + 3*baseUnit (bullish) or C - 3*baseUnit (bearish)
    return isBullish ? (pC + 3.0 * baseUnit) : (pC - 3.0 * baseUnit);
}

//+------------------------------------------------------------------+
//| MIDPOINT SCORE (60% weight)                                      |
//| How close is Step3 to the nearest reference midpoint?            |
//| Uses inverse-distance scoring: score = 1/(1 + k*normalized_err) |
//+------------------------------------------------------------------+
double ScoreMidpointMatch(double step3Price, const WaveAnalysisResult &analysis,
                          double abDistance, int &bestMidpointIdx) {
    bestMidpointIdx = -1;
    if(analysis.midpointCount <= 0 || abDistance <= 0) return 0;

    double bestScore = 0;

    for(int i = 0; i < analysis.midpointCount; i++) {
        double midPrice = analysis.midpoints[i].price;
        if(midPrice <= 0) continue;

        double error = MathAbs(step3Price - midPrice);
        // Normalize error relative to AB distance
        double normalizedError = error / abDistance;

        // Inverse scoring: perfect match = 1.0, error=AB → ~0.09
        // k=10 gives steep falloff — rewards precision
        double score = 1.0 / (1.0 + normalizedError * 10.0);

        // Bonus for arithmetic 50% and Gann 50% (types 0 and 1)
        // These are the most important according to the theory
        if(analysis.midpoints[i].type <= 1) {
            score *= 1.2;  // 20% bonus for 50% midpoints
            if(score > 1.0) score = 1.0;
        }

        if(score > bestScore) {
            bestScore = score;
            bestMidpointIdx = i;
        }
    }

    return bestScore;
}

//+------------------------------------------------------------------+
//| TIME SCORE (25% weight) — Gann: Price = Time                    |
//| Checks if the implied CD duration forms harmonic ratio with      |
//| AB and BC durations. Gann believed perfect reversals occur       |
//| when price distance equals time distance (1:1 angle = 45°)      |
//+------------------------------------------------------------------+
double ScoreTimeAlignment(double step3Price, double pC, double frequency,
                          const WaveAnalysisResult &analysis) {
    if(!analysis.waveAB.isValid || !analysis.waveBC.isValid) return 0;
    if(analysis.waveBC.speed <= 0) return 0;

    // Estimate how many bars from C to reach Step3
    double step3Distance = MathAbs(step3Price - pC);
    if(step3Distance <= 0) return 0;

    // Use BC wave speed as reference for CD projection
    double estimatedBars = step3Distance / analysis.waveBC.speed;
    if(estimatedBars <= 0) return 0;

    // Check how close estimatedBars is to harmonic multiples of AB/BC duration
    // Harmonic ratios: 0.5, 1.0, 1.5, 2.0, 2.5, 3.0
    double bestTimeScore = 0;

    double refDurations[2];
    refDurations[0] = (double)analysis.waveAB.barDuration;
    refDurations[1] = (double)analysis.waveBC.barDuration;

    for(int d = 0; d < 2; d++) {
        if(refDurations[d] <= 0) continue;

        double ratio = estimatedBars / refDurations[d];

        // Find nearest harmonic multiple (0.5, 1.0, 1.5, 2.0, 2.5, 3.0)
        double nearestHarmonic = MathRound(ratio * 2.0) / 2.0;
        if(nearestHarmonic < 0.5) nearestHarmonic = 0.5;
        if(nearestHarmonic > 3.0) nearestHarmonic = 3.0;

        double deviation = MathAbs(ratio - nearestHarmonic);
        // Score: 1.0 at exact harmonic, 0.0 at deviation >= 0.5
        double score = MathMax(0, 1.0 - deviation * 2.0);

        // Bonus for 1:1 (Gann's ideal 45° angle)
        if(MathAbs(nearestHarmonic - 1.0) < 0.01) score *= 1.15;
        if(score > 1.0) score = 1.0;

        if(score > bestTimeScore) bestTimeScore = score;
    }

    // Additional: Gann angle check — price movement / time movement ratio
    // Ideal Gann angle is 45° (1:1 price/time)
    // But we need to normalize since price and time have different units
    // Use AB wave as the "unit of measure"
    if(analysis.waveAB.barDuration > 0 && analysis.waveAB.distance > 0) {
        double pricePerBar = analysis.waveAB.distance / (double)analysis.waveAB.barDuration;
        if(pricePerBar > 0) {
            double cdAngleRatio = (step3Distance / estimatedBars) / pricePerBar;
            // 1.0 = same angle as AB, which is ideal
            double angleDeviation = MathAbs(cdAngleRatio - 1.0);
            double angleScore = MathMax(0, 1.0 - angleDeviation);
            // Blend: 70% harmonic + 30% angle consistency
            bestTimeScore = bestTimeScore * 0.7 + angleScore * 0.3;
        }
    }

    return bestTimeScore;
}

//+------------------------------------------------------------------+
//| HARMONIC SCORE (15% weight)                                      |
//| Checks if the frequency itself has harmonic relationship with    |
//| wave ratios. Powers of 2 and n/32 divisions score higher.       |
//+------------------------------------------------------------------+
double ScoreHarmonicPhase(double frequency, const WaveAnalysisResult &analysis) {
    double score = 0;

    // 1. Check if frequency is a clean n/32 division (no geometric mean)
    //    Clean divisions: 3.125, 6.25, 9.375, ..., 100
    //    These have exact binary subdivision properties
    double n32 = frequency / 3.125;
    double n32Rounded = MathRound(n32);
    double n32Error = MathAbs(n32 - n32Rounded);
    if(n32Error < 0.01) {
        score += 0.4;  // Clean binary subdivision
    }

    // 2. Check if freq is power-of-2 percentage: 3.125, 6.25, 12.5, 25, 50, 100
    double log2Freq = MathLog(frequency) / MathLog(2.0);
    double log2Rounded = MathRound(log2Freq);
    double log2Error = MathAbs(log2Freq - log2Rounded);
    if(log2Error < 0.05) {
        score += 0.3;  // Power of 2 — very harmonic
    }

    // 3. Check if frequency relates to wave ratio AB/XA
    if(analysis.ratioAB_XA > 0) {
        // If freq/100 ≈ ratioAB_XA or freq/100 ≈ 2×ratioAB_XA etc.
        double freqRatio = frequency / 100.0;
        double nearestMult = MathRound(freqRatio / analysis.ratioAB_XA);
        if(nearestMult >= 1 && nearestMult <= 4) {
            double expected = nearestMult * analysis.ratioAB_XA;
            double ratioDeviation = MathAbs(freqRatio - expected);
            if(ratioDeviation < 0.05) {
                score += 0.3;
            }
        }
    }

    // Clamp to [0, 1]
    if(score > 1.0) score = 1.0;
    return score;
}

//+------------------------------------------------------------------+
//| MAIN: Find optimal frequency for an ABCD pattern                 |
//| Tests all 76 frequencies, scores each, returns the best          |
//+------------------------------------------------------------------+
bool FindOptimalFrequency(double pX, datetime tX, double pA, datetime tA,
                          double pB, datetime tB, double pC, datetime tC,
                          FrequencyResult &result) {
    result.Reset();

    // Step 1: Analyze all waves
    WaveAnalysisResult analysis;
    if(!AnalyzeWaves(pX, tX, pA, tA, pB, tB, pC, tC, analysis)) {
        _LOG_GATE_E Print("[E][FreqOpt] AnalyzeWaves failed — invalid XABC points");
        return false;
    }

    double abDistance = analysis.waveAB.distance;
    if(abDistance <= 0) return false;

    double pipSize = GetCachedPipSize();
    if(pipSize <= 0) pipSize = GetCachedPoint();

    // Step 2: Test every frequency in the array
    double bestTotal = -1;
    int    bestIdx   = -1;

    for(int i = 0; i < TH3_FREQUENCY_COUNT; i++) {
        double freq = TH3_TEST_FREQUENCIES[i];

        // Calculate Step3 price for this frequency
        double step3 = CalculateStep3Price(pA, pB, pC, freq);
        if(step3 <= 0) continue;

        // Score components
        int bestMidIdx = -1;
        double sMidpoint = ScoreMidpointMatch(step3, analysis, abDistance, bestMidIdx);
        double sTime     = ScoreTimeAlignment(step3, pC, freq, analysis);
        double sHarmonic = ScoreHarmonicPhase(freq, analysis);

        // Weighted total
        double total = WEIGHT_MIDPOINT * sMidpoint
                     + WEIGHT_TIME     * sTime
                     + WEIGHT_HARMONIC * sHarmonic;

        if(total > bestTotal) {
            bestTotal = total;
            bestIdx   = i;
            result.midpointScore = sMidpoint;
            result.timeScore     = sTime;
            result.harmonicScore = sHarmonic;
            result.step3Price    = step3;
            result.matchWaveIndex = (bestMidIdx >= 0) ? analysis.midpoints[bestMidIdx].waveIndex : -1;
            result.matchLabel     = (bestMidIdx >= 0) ? analysis.midpoints[bestMidIdx].label : "";
            if(bestMidIdx >= 0 && pipSize > 0) {
                result.errorPips = MathAbs(step3 - analysis.midpoints[bestMidIdx].price) / pipSize;
            }
        }
    }

    if(bestIdx < 0 || bestTotal < MIN_ACCEPTABLE_SCORE) {
        _LOG_GATE_W Print("[W][FreqOpt] No acceptable frequency found. Best score: ",
                          DoubleToString(bestTotal, 4));
        return false;
    }

    result.bestIndex     = bestIdx;
    result.bestFrequency = TH3_TEST_FREQUENCIES[bestIdx];
    result.totalScore    = bestTotal;
    result.isValid       = true;

    Print("[FreqOpt] Optimal: ", DoubleToString(result.bestFrequency, 3), "% [#", bestIdx, "]",
          " | Score: ", DoubleToString(result.totalScore, 3),
          " (M:", DoubleToString(result.midpointScore, 2),
          " T:", DoubleToString(result.timeScore, 2),
          " H:", DoubleToString(result.harmonicScore, 2), ")",
          " | Match: ", result.matchLabel,
          " | Error: ", DoubleToString(result.errorPips, 1), " pips",
          " | Step3: ", DoubleToString(result.step3Price, (int)Digits));

    return true;
}

//+------------------------------------------------------------------+
//| Apply optimal frequency to the global state                      |
//+------------------------------------------------------------------+
void ApplyOptimalFrequency(const FrequencyResult &result) {
    if(!result.isValid) return;

    g_th3FreqIndex    = result.bestIndex;
    g_th3FreqOverride = result.bestFrequency;

    // Persist
    string chartIdStr = GetCachedChartIdStr();
    GlobalVariableSet("Biotak_TH3Freq_" + chartIdStr, g_th3FreqOverride);
    GlobalVariableSet("Biotak_TH3FreqIdx_" + chartIdStr, (double)g_th3FreqIndex);
}

#endif // FREQUENCY_OPTIMIZER_MQH
