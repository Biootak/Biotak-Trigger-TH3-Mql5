
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"
#ifndef UTILITY_FUNCTIONS_MQH
#define UTILITY_FUNCTIONS_MQH
#include "ZoneFactory.mqh"

//+------------------------------------------------------------------+
//| Throttled ChartRedraw() to prevent excessive CPU usage           |

//| GOLD FIX: Prevents 17 rapid ChartRedraw calls in OnChartEvent   |
//| Task 13 - Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7|
//|                                                                  |
//| Parameters:                                                      |
//|   forceRedraw - true to bypass throttling for critical updates  |
//|                                                                  |
//| Requirements:                                                    |
//|   14.1: Check if minimum interval has elapsed                   |
//|   14.2: Skip ChartRedraw if interval not elapsed                |
//|   14.3: Call ChartRedraw once when interval elapsed             |
//|   14.4: Batch rapid redraw requests                             |
//|   14.5: Force immediate redraw for critical updates             |
//|   14.6: Skip all ChartRedraw when indicator hidden              |
//|   14.7: Use configurable throttle interval                      |
//+------------------------------------------------------------------+
void ThrottledChartRedraw(bool forceRedraw = false) {
    uint nowMs = GetTickCount();
    // FIX: Force redraws always execute regardless of hidden state
    if(forceRedraw) {
        ChartRedraw();
    g_lastChartRedrawTime = nowMs;
    return;
    }
    if(IsIndicatorHidden()) return;
    if(nowMs - g_lastChartRedrawTime > CHART_REDRAW_THROTTLE_MS) {        ChartRedraw();
    g_lastChartRedrawTime = nowMs;
    }}
    double GetArrayMax(const double &array[]) {
        int size=ArraySize(array);
    if(size<=0) return EMPTY_VALUE;
    int maxIdx = ArrayMaximum(array);
    if(maxIdx < 0) return EMPTY_VALUE;
    return array[maxIdx];
}
    double GetArrayMin(const double &array[]) {
        int size=ArraySize(array);
    if(size<=0) return EMPTY_VALUE;
    int minIdx = ArrayMinimum(array);
    if(minIdx < 0) return EMPTY_VALUE;
    return array[minIdx];
}
    void CheckArraySizes() {
        int optimalCacheSize = ArraySize(FRACTAL_TIMEFRAMES) + ArraySize(STANDARD_TIMEFRAMES) + 5;
    if(ArraySize(g_storedTHs) <= 0) {
        ArrayResize(g_storedTHs, optimalCacheSize);
    }
    if(ArraySize(g_labelPositions) <= 0) {
        ArrayResize(g_labelPositions, optimalCacheSize);
    }
}
    double CalculatePipsDistance(const double price1, const double price2) {
        double pipSize = GetCachedPipSize();
    if(IsZero(pipSize, EPSILON_PRICE)) return 0.0;
    return NormalizeDouble(MathAbs(price1 - price2) / pipSize, 1);
}
    string FormatTooltipWithDistance(const string baseTooltip, const double priceLevel) {
        double pips = CalculatePipsDistance(priceLevel, g_currentPrice);
    return baseTooltip + ", Distance: +/- " + DoubleToString(pips, 1) + " pips";
}
    // PERF: Overload accepting pre-computed pips to avoid redundant CalculatePipsDistance
    string FormatTooltipWithDistanceFast(const string baseTooltip, const double precomputedPips) {
    return baseTooltip + ", Distance: +/- " + DoubleToString(precomputedPips, 1) + " pips";
}
    double GetMidpointPrice(ENUM_TH_START_POINT_TYPE startPointType) {
    switch(startPointType) {
        case TH_START_POINT_HISTORICAL_HIGH:
            return g_highestHigh;
    case TH_START_POINT_HISTORICAL_LOW:
            return g_lowestLow;
    case TH_START_POINT_CUSTOM_PRICE:
        {
        double customPrice = (g_customTHStartPrice > 0.0) ? g_customTHStartPrice : inpCustomTHStartPrice;
    return (customPrice > 0.0) ? customPrice : (g_highestHigh + g_lowestLow) / 2.0;
        }
        case TH_START_POINT_MIDPOINT:
        default:
            return (g_highestHigh + g_lowestLow) / 2.0;
    }
}

ENUM_STEP_CALCULATION_MODE GetCurrentStepMode() {
        if(g_stepModeOverride >= 0 && g_stepModeOverride <= 5) {
        return (ENUM_STEP_CALCULATION_MODE)g_stepModeOverride;
    }
    return inpStepCalculationMode;
}
    string GetStepModeName(ENUM_STEP_CALCULATION_MODE mode) {
    switch(mode) {
        case TH_STEP:           return "S";
    case SS_LS_STEP:        return "SS/LS";
    case M_STEP:            return "M";
    case TP_STEP:           return "TP";
    case COMBO_STEP:        return "Combo";
    case FACTOR_STEP:       return "F";
    default:                return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get Preset name for display (user-friendly)                     |

//+------------------------------------------------------------------+
string GetComboPresetName(const ENUM_COMBO_PRESET preset) {
    switch(preset) {
        case COMBO_PRESET_LEGACY_ADD:           return "Legacy (Trigger SS + Pattern SS)";
    case COMBO_PRESET_BALANCED_MEDIUM:      return "Balanced Medium";
    case COMBO_PRESET_BALANCED_LONG:        return "Balanced Long";
    case COMBO_PRESET_BALANCED_TRIPLE:      return "Triple Balanced";
    case COMBO_PRESET_BALANCED_MIN:         return "Balanced Min";
    case COMBO_PRESET_CONSERVATIVE:         return "Conservative";
    case COMBO_PRESET_ULTRA_CONSERVATIVE:   return "Ultra Conservative";
    case COMBO_PRESET_TRIPLE_CONSERVATIVE:  return "Triple Conservative";
    case COMBO_PRESET_AGGRESSIVE:           return "Aggressive";
    case COMBO_PRESET_ULTRA_AGGRESSIVE:     return "Ultra Aggressive";
    case COMBO_PRESET_TRIPLE_AGGRESSIVE:    return "Triple Aggressive";
    case COMBO_PRESET_TREND_FILTER:         return "Trend Filter";
    case COMBO_PRESET_VOLATILITY_ADAPTIVE:  return "Volatility Adaptive";
    case COMBO_PRESET_MANUAL_DUAL:          return "Manual Dual";
    case COMBO_PRESET_MANUAL_TRIPLE:        return "Manual Triple";
    default:                                return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Clear a single temporary label by name and reset its timestamp  |
//+------------------------------------------------------------------+
void ClearSingleModeLabel(const string labelName, uint &createTime) {
    if(ObjectFind(0, labelName) >= 0)
        ObjectDelete(0, labelName);
    createTime = 0;
}

//+------------------------------------------------------------------+
//| Clear all temporary mode labels (used by OnTimer / reset)       |
//+------------------------------------------------------------------+
void ClearAllModeLabels() {
    ClearSingleModeLabel(g_stepModeLabelName, g_stepModeLabelCreateTime);
    ClearSingleModeLabel(g_factorLabelName, g_factorLabelCreateTime);
    ClearSingleModeLabel(g_th3FreqLabelName, g_th3FreqLabelCreateTime);
    Comment("");
    g_resetCommentCreateTime = 0;
}

double GetCurrentModePrimaryStepPrice(ENUM_STEP_CALCULATION_MODE mode)
{
    int digits = GetCachedDigits();
    if(digits <= 0) digits = Digits;

    double basePrice = g_dailyClosePriceForTH;
    if(basePrice <= 0 || basePrice == EMPTY_VALUE) {
        if(g_currentPrice > 0) basePrice = g_currentPrice;
        else if(g_highestHigh > 0 && g_lowestLow > 0) basePrice = (g_highestHigh + g_lowestLow) * 0.5;
    }
    if(basePrice <= 0) return 0.0;

    double timeframePercentage = GetTimeframeTH();
    double thValue = CalculateTH(basePrice, digits, timeframePercentage);
    if(thValue <= 0) return 0.0;
    thValue = GetAdaptedStepSize(thValue);

    switch(mode)
    {
        case TH_STEP:
            return thValue;

        case FACTOR_STEP:
        {
            double factorValue = g_factorValueOverride;
            if(factorValue <= 0) {
                if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0)
                    factorValue = inpFactorValue;
                else
                    factorValue = GetDefaultFactorValue(basePrice);
            }
            return CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
        }

        case SS_LS_STEP:
        case M_STEP:
        {
            double structureValue = 0, patternValue = 0, triggerValue = 0;
            CalculateFractalValues(thValue, structureValue, patternValue, triggerValue);
            double shortStep = structureValue * 1.5;
            if(mode == M_STEP && inpMStepBasisType == MSTEP_BASIS_M_EQUAL)
                return CalculateMDistance(shortStep);
            return shortStep;
        }

        case TP_STEP:
        {
            double eValue = CalculateEStep(thValue);
            return CalculateTPStep(eValue);
        }

        case COMBO_STEP:
            return CalculateComboStepSize(basePrice);

        default:
            return thValue;
    }
}

string BuildUnifiedModeLabelText()
{
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    string modeName = GetStepModeName(currentMode);

    double pipSize = GetCachedPipSize();
    if(IsZero(pipSize, EPSILON_PRICE) || pipSize <= 0)
        return "[ " + modeName + " ]";

    double stepPrice = GetCurrentModePrimaryStepPrice(currentMode);
    if(stepPrice <= 0)
        return "[ " + modeName + " ]";

    double stepPips = stepPrice / pipSize;
    return "[ " + modeName + " | Step: " + DoubleToString(stepPips, 1) + " pips ]";
}

//+------------------------------------------------------------------+
//| Check and clear expired labels (called from OnTimer)            |
//| Returns true if any labels remain (timer should continue)       |
//+------------------------------------------------------------------+
bool CheckAndClearExpiredLabels() {
    uint now = GetTickCount();
    uint durationMs = (uint)inpModeLabelDuration * 1000;
    bool anyRemaining = false;
    bool anyCleared = false;

    // FIX: durationMs==0 means permanent labels — never auto-clear
    if(durationMs > 0) {
        if(g_stepModeLabelCreateTime > 0) {
            if((now - g_stepModeLabelCreateTime) >= durationMs) {
                ClearSingleModeLabel(g_stepModeLabelName, g_stepModeLabelCreateTime);
                anyCleared = true;
            } else {
                anyRemaining = true;
            }
        }
        if(g_factorLabelCreateTime > 0) {
            if((now - g_factorLabelCreateTime) >= durationMs) {
                ClearSingleModeLabel(g_factorLabelName, g_factorLabelCreateTime);
                anyCleared = true;
            } else {
                anyRemaining = true;
            }
        }
        if(g_th3FreqLabelCreateTime > 0) {
            if((now - g_th3FreqLabelCreateTime) >= durationMs) {
                ClearSingleModeLabel(g_th3FreqLabelName, g_th3FreqLabelCreateTime);
                anyCleared = true;
            } else {
                anyRemaining = true;
            }
        }
    } else {
        // Duration is 0 (permanent) — labels live forever, nothing to expire
        if(g_stepModeLabelCreateTime > 0 || g_factorLabelCreateTime > 0 || g_th3FreqLabelCreateTime > 0)
            anyRemaining = false; // No timer needed for permanent labels
    }

    if(g_resetCommentCreateTime > 0) {
        if((now - g_resetCommentCreateTime) >= 2000) {
            Comment("");
            g_resetCommentCreateTime = 0;
            anyCleared = true;
        } else {
            anyRemaining = true;
        }
    }

    // Reposition remaining labels when some are cleared (stack changes)
    if(anyCleared)
        RepositionAllOverlayLabels();

    return anyRemaining;
}

//+------------------------------------------------------------------+
//| Get Y row offset for a specific label type (stacked vertically) |
//+------------------------------------------------------------------+
int GetModeLabelRowOffset(const string labelName) {
    int rowHeight = inpModeLabelFontSize + 6;
    // Step mode: row 0 (top)
    if(labelName == g_stepModeLabelName)  return 0;
    // Factor: row 1 (below step mode if visible, else row 0)
    if(labelName == g_factorLabelName) {
        int row = 0;
        if(g_stepModeLabelCreateTime > 0) row++;
        return row * rowHeight;
    }
    // TH3 Freq: row 2 (below visible labels)
    if(labelName == g_th3FreqLabelName) {
        int row = 0;
        if(g_stepModeLabelCreateTime > 0) row++;
        if(g_factorLabelCreateTime > 0) row++;
        return row * rowHeight;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Get total height of ALL active mode labels (for stacking below) |
//+------------------------------------------------------------------+
int GetModeLabelBlockHeight() {
    int activeCount = 0;
    if(g_stepModeLabelCreateTime > 0) activeCount++;
    if(g_factorLabelCreateTime > 0) activeCount++;
    if(g_th3FreqLabelCreateTime > 0) activeCount++;
    int rowHeight = inpModeLabelFontSize + 6;
    return activeCount * rowHeight;
}

    void ApplyModeLabelStyle(const string name, const color textColor, const int yOffsetExtra = 0) {
        ObjectSetInteger(0, name, OBJPROP_CORNER, inpModeLabelCorner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, inpModeLabelXDistance);
    // Compute proper Y position: below ATR labels + stacked row for this label type
    int rowOffset = GetModeLabelRowOffset(name);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, inpModeLabelYDistance + yOffsetExtra + g_modeLabelYOffset + rowOffset);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetString(0, name, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpModeLabelFontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
    void UpdateStepModeLabel() {    if(!inpShowModeChangeLabel) return;
    if(IsIndicatorHidden()) return;
        // Keep only one mode label on chart (mode + step). Remove old secondary labels.
        ClearSingleModeLabel(g_factorLabelName, g_factorLabelCreateTime);
        ClearSingleModeLabel(g_th3FreqLabelName, g_th3FreqLabelCreateTime);

    if(ObjectFind(0, g_stepModeLabelName) < 0) {
        ObjectCreate(0, g_stepModeLabelName, OBJ_LABEL, 0, 0, 0);
    }
        ObjectSetString(0, g_stepModeLabelName, OBJPROP_TEXT, BuildUnifiedModeLabelText());
    g_stepModeLabelCreateTime = GetTickCount();
    ApplyModeLabelStyle(g_stepModeLabelName, inpModeLabelColor);
    if(inpModeLabelDuration > 0) {
        EventSetTimer(1);  // Check every second for expired labels
    }
}

//+------------------------------------------------------------------+
//| Update Factor value label on chart (configurable duration)      |

//| Shows: "F: 2.50 | Step: 12.5 pips" with auto-hide               |
//+------------------------------------------------------------------+
void UpdateFactorLabel(double factorValue) {    if(!inpShowModeChangeLabel) return;
    // Unified label policy: only StepMode label is shown.
    // Keep this function as a compatibility hook and refresh the main mode label.
    ClearSingleModeLabel(g_factorLabelName, g_factorLabelCreateTime);
    UpdateStepModeLabel();
}

//+------------------------------------------------------------------+
//| Update TH3 Frequency label on chart                             |
//+------------------------------------------------------------------+
void UpdateTH3FreqLabel(double freqValue) {
    // Unified label policy: hide legacy TH3 frequency label to avoid clutter.
    ClearSingleModeLabel(g_th3FreqLabelName, g_th3FreqLabelCreateTime);
}

//+------------------------------------------------------------------+
//| Create Mid-Range Zone (Generic function for all modes)          |

//| Logic: Draw zone with specified height around midpoint          |
//| Compatible with CreateFactorMidZone logic                        |
//| @param zoneName - Unique name for zone object                   |
//| @param prevPrice - Previous level price                         |
//| @param currentPrice - Current level price                       |
//| @param zoneHeight - Height of zone (±from midpoint)             |
//| @param zoneColor - Color of zone                                |
//| @param transparency - Transparency (0-100)                      |
//+------------------------------------------------------------------+
//| Create Generic Mid Zone - GOLD VERSION v2                        |

//|                                                                  |
//| ARCHITECTURE: Delegates to ZoneFactory with comprehensive        |
//| validation, error handling, and NO unnecessary deletion          |
//|                                                                  |
//| IMPROVEMENTS v2:                                                 |
//| - REMOVED unnecessary object deletion (let factory handle it)   |
//| - Factory will UPDATE existing objects (more efficient)         |
//| - Better error messages with context                            |
//| - Consistent error handling                                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Unified repositioning for ALL overlay labels                     |
//| Call after g_modeLabelYOffset changes to keep layout consistent  |
//+------------------------------------------------------------------+
void RepositionAllOverlayLabels() {
    // 1. Reposition existing mode labels in-place
    if(ObjectFind(0, g_stepModeLabelName) >= 0)
        ApplyModeLabelStyle(g_stepModeLabelName, (color)ObjectGetInteger(0, g_stepModeLabelName, OBJPROP_COLOR));
    if(ObjectFind(0, g_factorLabelName) >= 0)
        ApplyModeLabelStyle(g_factorLabelName, (color)ObjectGetInteger(0, g_factorLabelName, OBJPROP_COLOR));
    if(ObjectFind(0, g_th3FreqLabelName) >= 0)
        ApplyModeLabelStyle(g_th3FreqLabelName, (color)ObjectGetInteger(0, g_th3FreqLabelName, OBJPROP_COLOR));

    // 2. Reposition lock status label
    UpdateLockStatusLabel();

    // 3. Reposition ABCD info labels
    RepositionABCDInfoLabels();
}

bool CreateGenericMidZone(const string zoneName, const double prevPrice, const double currentPrice,
                          const double zoneHeight, const color zoneColor, const int transparency)
{
        if(StringLen(zoneName) == 0) {
        _LOG_GATE_E Print("[E][ZONE] CreateGenericMidZone: Empty zone name");
    return false;
    }
    if(prevPrice <= 0 || currentPrice <= 0) {
        _LOG_GATE_E Print("[E][ZONE] CreateGenericMidZone: Invalid prices - Prev=", DoubleToString(prevPrice, Digits));
    return false;
    }
    if(prevPrice == currentPrice) {
        _LOG_GATE_W Print("[W][ZONE] CreateGenericMidZone: Prices are equal - no zone needed");
    return false;
    }
    if(zoneHeight <= 0) {
        _LOG_GATE_E Print("[E][ZONE] CreateGenericMidZone: Invalid zone height: ", DoubleToString(zoneHeight, Digits));
    return false;
    }
    double midPoint = (prevPrice + currentPrice) / 2.0;
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
    if(upperPrice <= lowerPrice) {
        _LOG_GATE_E Print("[E][ZONE] CreateGenericMidZone: Invalid zone boundaries - Upper=", DoubleToString(upperPrice, Digits));
    return false;
    }    
    SZoneCreationRequest request;
    request.name = zoneName;
    request.topPrice = upperPrice;
    request.bottomPrice = lowerPrice;
    request.zoneColor = zoneColor;
    request.transparency = transparency;
    request.filled = true;
    request.startTime = 0;
    request.endTime = 0;
    SZoneCreationResult result = CreateZone(request);
    if(!result.success) {
        _LOG_GATE_E Print("[E][ZONE] CreateGenericMidZone: Factory failed for '", zoneName, "' - ", result.errorMessage);
    return false;
    }
    _LOG_GATE_I Print("[I][ZONE] CreateGenericMidZone: Created/Updated '", zoneName, "' [");
    return true;
}
    #endif
