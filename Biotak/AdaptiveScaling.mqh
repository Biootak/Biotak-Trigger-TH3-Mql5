  //+------------------------------------------------------------------+
//|                                            AdaptiveScaling.mqh   |
//|                                                                  |
//| ATR-Based Volatility Adaptive Scaling for Biotak Trigger TH3    |
//|                                                                  |
//| Normalizes TH-based level spacing to match real market           |
//| volatility using Weighted ATR, while preserving the fractal      |
//| 2  ratio between consecutive structure levels.                   |
//|                                                                  |
//| Three modes:                                                     |
//| FIXED: No adaptation (original behavior)                         |
//| ATR_ADAPTIVE: Full ATR normalization (scalingFactor = ATR/TH)   |
//| BLENDED: Weighted mix (    ATR + (1- )   TH)                   |
//|                                                                  |
//| Smoothing: EMA on scaling factor, updated on bar close only.    |
//+------------------------------------------------------------------+
#property copyright "  Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link      "@biotak"

#property strict

#ifndef ADAPTIVE_SCALING_MQH
#define ADAPTIVE_SCALING_MQH

//+------------------------------------------------------------------+
//| Adaptive Scaling State Variables                                  |
//+------------------------------------------------------------------+
static double g_atrScalingFactor = 1.0;         // Current raw ATR/TH ratio
static double g_smoothedScalingFactor = 1.0;     // EMA-smoothed scaling factor
static int    g_lastScalingBarCount = -1;         // Bar count at last update
static bool   g_scalingInitialized = false;       // First-time initialization flag
static double g_lastRawATR = 0.0;                 // Last ATR value (for debug)
static double g_lastTheoreticalTH = 0.0;          // Last theoretical TH (for debug)

//+------------------------------------------------------------------+
//| PERF (2026): Idempotent InitializeAdaptiveScaling                |
//|                                                                  |
//| Root cause of the "fractal jump on TF switch" instability:       |
//| the previous implementation reset the EMA scaling state to 1.0   |
//| on every OnInit, and reset g_scalingInitialized to false. The    |
//| first UpdateATRScalingFactor call after the reset then bypassed   |
//| the EMA (it sees "not initialized") and seeded the EMA with the  |
//| raw factor for the NEW timeframe - a value that can be wildly    |
//| different from the previous TF's smoothed value. The user saw   |
//| a hard "jump" instead of a smooth transition.                    |
//|                                                                  |
//| Fix: make the function idempotent. The state persists across     |
//| OnInit/OnDeinit cycles (static locals survive a chart's         |
//| OnDeinit -> OnInit pair in the same indicator process). We only  |
//| do a full reset on the very first call per indicator instance.  |
//| On a TF switch the EMA keeps smoothing across the transition,   |
//| and the user sees a gradual change - or no visible change at all |
//| if ATR for the new TF happens to be close to the EMA's value.   |
//|                                                                  |
//| The "first init" flag is per-process. If the user wants a true  |
//| reset (e.g. after changing inpAdaptiveMode to a wildly different|
//| value), they can remove+re-add the indicator or restart the     |
//| terminal - both clear the static and trigger the full reset.    |
//| Or they can call ForceResetAdaptiveScaling() explicitly.        |
//+------------------------------------------------------------------+
static bool g_scalingFirstInitDone = false;

void InitializeAdaptiveScaling() {
    if(g_scalingFirstInitDone) {
        // Subsequent init (TF switch, parameter change): keep the EMA state.
        // The next UpdateATRScalingFactor call will see g_scalingInitialized=true
        // and apply normal EMA smoothing, which absorbs the ATR change across
        // TFs gradually instead of jumping. This is the key fix for the
        // "wants to redraw from scratch on every TF switch" complaint.
        return;
    }
    g_atrScalingFactor = 1.0;
    g_smoothedScalingFactor = 1.0;
    g_lastScalingBarCount = -1;
    g_scalingInitialized = false;
    g_lastRawATR = 0.0;
    g_lastTheoreticalTH = 0.0;
    g_scalingFirstInitDone = true;
}

//+------------------------------------------------------------------+
//| PERF (2026): Force-reset the adaptive scaling state.            |
//|                                                                  |
//| Use cases:                                                       |
//|  - User changed inpAdaptiveMode to a wildly different value     |
//|    (e.g. ADAPTIVE_FIXED -> ADAPTIVE_ATR with smoothing=2)       |
//|  - Symbol change: the previous scaling was for the old symbol   |
//|  - User pressed the reset hotkey and wants a clean slate        |
//|                                                                  |
//| After this call, the next UpdateATRScalingFactor will seed the  |
//| EMA with the new raw factor (one-frame jump), which is what the  |
//| user explicitly asked for.                                      |
//+------------------------------------------------------------------+
void ForceResetAdaptiveScaling() {
    g_scalingFirstInitDone = false;
    InitializeAdaptiveScaling();
}

//+------------------------------------------------------------------+
//| Calculate EMA Alpha from period                                  |
//|   = 2 / (period + 1)                                            |
//+------------------------------------------------------------------+
double GetEMAAlpha(const int period) {
    int safePeriod = MathMax(1, period);
    return 2.0 / (safePeriod + 1.0);
}

//+------------------------------------------------------------------+
//| Update ATR Scaling Factor                                        |
//|                                                                  |
//| Called on each tick, but only recalculates when a new bar closes  |
//| (bar count changes). This prevents level jitter while            |
//| maintaining responsiveness.                                      |
//|                                                                  |
//| @param basePrice    Daily close price used for TH calculation   |
//| @param digits       Symbol digits (precision)                   |
//| @return true if scaling factor was updated                       |
//+------------------------------------------------------------------+
bool UpdateATRScalingFactor(const double basePrice, const int digits) {
    // FIXED mode: no scaling needed
    if(inpAdaptiveMode == ADAPTIVE_FIXED) {
        g_smoothedScalingFactor = 1.0;
        g_atrScalingFactor = 1.0;
        g_fractalDetermined = true;
        g_fractalDeterminedTF = GetCurrentTimeframe();
        return false;
    }
    
    // Update frequency gate: allow updates every 5 seconds instead of every bar
    // This makes the indicator much more responsive to intraday volatility spikes.
    // While the jump has not yet been determined for THIS timeframe, bypass the gate
    // so we converge on the very next tick that ATR becomes available (no
    // narrow-then-wide first draw after a timeframe switch).
    string curTF = GetCurrentTimeframe();
    bool determinedForThisTF = (g_fractalDetermined && g_fractalDeterminedTF == curTF);
    static datetime s_lastScalingUpdate = 0;
    datetime now = TimeCurrent();
    if(g_scalingInitialized && determinedForThisTF && (now - s_lastScalingUpdate) < 5) {
        return false; 
    }
    s_lastScalingUpdate = now;
    
    // Validate base price
    if(basePrice < EPSILON_PRICE) {
        _LOG_GATE_E Print("[E][ADAPT] UpdateATRScalingFactor: Invalid base price=", DoubleToString(basePrice, 10));
        return false;
    }
    
    // Get theoretical TH for current timeframe (un-adapted base TH)
    double timeframePercentage = GetBaseTimeframeTH();
    if(timeframePercentage <= 0) {
        _LOG_GATE_E Print("[E][ADAPT] UpdateATRScalingFactor: Invalid timeframe percentage=", DoubleToString(timeframePercentage, 10));
        return false;
    }
    
    double theoreticalTH = CalculateTH(basePrice, digits, timeframePercentage);
    if(theoreticalTH <= 0) {
        _LOG_GATE_E Print("[E][ADAPT] UpdateATRScalingFactor: Invalid theoretical TH=", DoubleToString(theoreticalTH, 10));
        return false;
    }
    
    // Use the core Weighted ATR system for calculation (consistent with labels)
    double weightedATR = CalculateWeightedATR_Locked();
    
    if(weightedATR <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[W][ADAPT] UpdateATRScalingFactor: ATR=0, keeping previous scaling factor");
        #endif
        return false;
    }
    
    // ATR is valid: the jump can now be determined, so the first level draw is safe.
    g_fractalDetermined = true;
    g_fractalDeterminedTF = curTF;
    
    // Calculate raw scaling factor: ATR / TH
    double rawFactor = SafeDivide(weightedATR, theoreticalTH, 1.0, EPSILON_PRICE);
    
    // Clamp to safe range to prevent extreme values
    rawFactor = MathMax(MIN_SCALING_FACTOR, MathMin(MAX_SCALING_FACTOR, rawFactor));
    
    // Store for debug
    g_lastRawATR = weightedATR;
    g_lastTheoreticalTH = theoreticalTH;
    g_atrScalingFactor = rawFactor;
    
    // Apply EMA smoothing
    int smoothingPeriod = MathMax(1, inpAdaptiveSmoothingPeriod);
    double alpha = GetEMAAlpha(smoothingPeriod);
    
    if(!g_scalingInitialized) {
        // First time: seed EMA with current raw value
        g_smoothedScalingFactor = rawFactor;
        g_scalingInitialized = true;
    } else {
        // Fast-track for large changes in Aggressive mode (v3.11)
        if(inpFractalJumpStrategy == JUMP_AGGRESSIVE && MathAbs(rawFactor - g_smoothedScalingFactor) > 1.0) {
            alpha = MathMin(1.0, alpha * 2.0); 
        }
        // EMA: smoothed = prev * (1 - alpha) + raw * alpha
        g_smoothedScalingFactor = g_smoothedScalingFactor * (1.0 - alpha) + rawFactor * alpha;
    }
    
    // Clamp smoothed result too
    g_smoothedScalingFactor = MathMax(MIN_SCALING_FACTOR, MathMin(MAX_SCALING_FACTOR, g_smoothedScalingFactor));
    
    int oldShift = g_fractalShift;
    
    // UPDATE FRACTAL SHIFT (Global State)
    if(inpAdaptiveMode == ADAPTIVE_FRACTAL) {
        // Find base index for current timeframe
        int baseIdx = -1;
        string baseTF = GetBaseFractalTimeframeForCurrent();
        int tfArraySize = ArraySize(FRACTAL_TIMEFRAMES);
        
        for(int i = 0; i < tfArraySize; i++) {
            if(FRACTAL_TIMEFRAMES[i] == baseTF) {
                baseIdx = i;
                break;
            }
        }
        
        if(baseIdx != -1) {
            if(inpFractalJumpStrategy == JUMP_AGGRESSIVE) {
                // DIRECT THRESHOLD STRATEGY (v3.11):
                // Find the first fractal level whose TH is greater than or equal to current ATR.
                
                int targetIdx = baseIdx;
                double pipSize = GetCachedPipSize();
                double atrPips = (pipSize > 0) ? weightedATR / pipSize : 0;
                
                for(int i = baseIdx; i < tfArraySize; i++) {
                    double p = MODIFIED_FRACTAL_PERCENTAGES[i];
                    double th = CalculateTH(basePrice, digits, p);
                    
                    if(th >= weightedATR) {
                        targetIdx = i;
                        break;
                    }
                    targetIdx = i;
                }
                int newShift = targetIdx - baseIdx;
                // HYSTERESIS: Don't jump immediately. Require the new shift to be
                // proposed at least 2 consecutive times, OR a large ATR change.
                static int s_proposedShift = -1;
                static int s_proposalCount = 0;
                static double s_lastConfirmedATR = 0;
                // PERF (2026): also track the TF of the last confirmed shift. The
                // large-ATR-move bypass (25% threshold) was designed for same-TF
                // volatility spikes, but on a TF switch the ATR change is STRUCTURAL
                // (M5 ATR vs M15 ATR is typically 2-10x), not a volatility spike. If
                // we let the bypass fire on every TF switch, the shift is applied
                // immediately and the user sees a hard "jump" - the very thing the
                // hysteresis was designed to prevent. With TF tracking we treat a TF
                // change as a normal proposal: it still has to clear 2 consecutive
                // confirmations. The first call after a TF switch resets the
                // proposal count to 1, and the shift is held for ~5-15s while ATR
                // settles into its new regime. The user sees the OLD shift's
                // spacing for those few seconds - which is exactly the stability
                // they want.
                static string s_lastConfirmedTF = "";
                bool tfChangedSinceLastConfirm = (s_lastConfirmedTF != "" && s_lastConfirmedTF != curTF);
                if(newShift == s_proposedShift) {
                    s_proposalCount++;
                } else {
                    s_proposedShift = newShift;
                    s_proposalCount = 1;
                }
                bool largeATRMove = (s_lastConfirmedATR > 0 && MathAbs(weightedATR - s_lastConfirmedATR) / s_lastConfirmedATR > 0.25);
                // Apply the shift immediately on the very first determination so levels are
                // drawn ONCE with the correct spacing (no narrow-then-wide double draw).
                // Subsequent changes keep the 2-proposal hysteresis to avoid flicker.
                // On a TF switch, the large-ATR-move bypass is DISABLED - the ATR delta
                // is structural (different period), not a volatility spike, so the
                // hysteresis must take its normal course.
                bool firstDetermination = (s_lastConfirmedATR <= 0);
                if(firstDetermination || s_proposalCount >= 2 || (largeATRMove && !tfChangedSinceLastConfirm)) {
                    g_fractalShift = newShift;
                    s_lastConfirmedATR = weightedATR;
                    s_lastConfirmedTF = curTF;
                    s_proposalCount = 0;
                }
                // else: keep current g_fractalShift
                
                #ifdef ENABLE_DEBUG_LOGS
                // CRITICAL LOG: Now showing Pips instead of Points for clarity
                static datetime s_lastLogTime = 0;
                if(now - s_lastLogTime > 10) { // Log every 10 seconds
                    string currentFractal = FRACTAL_TIMEFRAMES[baseIdx + g_fractalShift];
                    Print("[FRACTAL_LOG] Stable ATR: ", DoubleToString(atrPips, 1), " Pips",
                          " | Target Fractal: ", currentFractal, 
                          " | Shift: ", g_fractalShift, 
                          " | Ratio: ", DoubleToString(g_smoothedScalingFactor, 2));
                    s_lastLogTime = now;
                }
                #endif
            } else {
                // CONSERVATIVE STRATEGY: Original log2-based jumping
                if(g_smoothedScalingFactor <= 1.2) {
                    g_fractalShift = 0;
                } else {
                    g_fractalShift = (int)MathRound((MathLog(g_smoothedScalingFactor) / MathLog(2.0)) + 0.1);
                }
            }
        } else {
            g_fractalShift = 0;
        }
        
        // Clamp shift to valid range [0, 5]
        if(g_fractalShift < 0) g_fractalShift = 0;
        if(g_fractalShift > 5) g_fractalShift = 5;
        
        if(g_fractalShift != oldShift) {
             _LOG_GATE_I Print("[I][ADAPT] Fractal Shift changed: ", oldShift, " -> ", g_fractalShift, " (ATR: ", DoubleToString(weightedATR / GetCachedPoint(), 1), " pips)");
             return true; // Shift changed, need redraw
        }
    } else {
        g_fractalShift = 0;
        if(g_fractalShift != oldShift) return true;
    }
    
    return false; // No significant change needing redraw
}

//+------------------------------------------------------------------+
//| Get fractal level shift based on ATR/TH ratio                    |
//| Only used in ADAPTIVE_FRACTAL mode                               |
//+------------------------------------------------------------------+
int GetFractalShift() {
    return g_fractalShift;
}

//+------------------------------------------------------------------+
//| Get Adapted Step Size                                            |
//|                                                                  |
//| Applies the appropriate scaling to a step size based on the     |
//| selected adaptive mode. Preserves fractal 2  ratio because     |
//| the same scaling factor is applied to ALL levels uniformly.     |
//|                                                                  |
//| @param originalStepSize  The raw TH-based step size             |
//| @return Adapted step size matching real market volatility        |
//+------------------------------------------------------------------+
double GetAdaptedStepSize(const double originalStepSize) {
    // FIXED mode: return unchanged
    if(inpAdaptiveMode == ADAPTIVE_FIXED) {
        return originalStepSize;
    }
    
    // Validate input
    if(originalStepSize <= 0) return 0.0;
    
    // Use smoothed scaling factor
    double factor = g_smoothedScalingFactor;
    
    switch(inpAdaptiveMode) {
        case ADAPTIVE_ATR:
        {
            // Full ATR adaptation: stepSize   scalingFactor
            return originalStepSize * factor;
        }
        
        case ADAPTIVE_BLENDED:
        {
            // Blended: interpolate between original and ATR-adapted
            // result = original * (1 - blendRatio) + (original * scalingFactor) * blendRatio
            // Simplified: result = original * ((1 - blendRatio) + scalingFactor * blendRatio)
            double blendRatio = MathMax(0.0, MathMin(1.0, inpAdaptiveBlendRatio));
            double blendedFactor = (1.0 - blendRatio) + factor * blendRatio;
            return originalStepSize * blendedFactor;
        }
        
        case ADAPTIVE_FRACTAL:
        {
            // Fractal Jump is handled at the timeframe selection level
            // so we don't apply another multiplier here.
            return originalStepSize;
        }
        
        default:
            return originalStepSize;
    }
}

//+------------------------------------------------------------------+
//| Get current scaling factor for info display                      |
//+------------------------------------------------------------------+
double GetCurrentScalingFactor() {
    return g_smoothedScalingFactor;
}

//+------------------------------------------------------------------+
//| Get raw (unsmoothed) scaling factor for info display              |
//+------------------------------------------------------------------+
double GetRawScalingFactor() {
    return g_atrScalingFactor;
}

//+------------------------------------------------------------------+
//| Check if adaptive scaling is active                              |
//+------------------------------------------------------------------+
bool IsAdaptiveScalingActive() {
    return (inpAdaptiveMode != ADAPTIVE_FIXED);
}

#endif
// ADAPTIVE_SCALING_MQH
