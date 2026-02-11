
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
        if(IsIndicatorHidden()) {
        return;
    }
    uint nowMs = GetTickCount();
    if(forceRedraw) {
        ChartRedraw();
    g_lastChartRedrawTime = nowMs;
    return;
    }
    if(nowMs - g_lastChartRedrawTime > CHART_REDRAW_THROTTLE_MS) {        ChartRedraw();
    g_lastChartRedrawTime = nowMs;
    }}
    double GetSymbolPoint() {
        static double point = 0;
    if(point == 0) {        point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(point == 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("GetSymbolPoint: Failed to get point value for symbol ", _Symbol);
    #endif
    return 0;
        }
    }
    return point;
}
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
        double cachedPoint = GetCachedPoint();
    if(IsZero(cachedPoint, EPSILON_PRICE)) return 0.0;
    return NormalizeDouble(MathAbs(price1 - price2) / cachedPoint / 10.0, 1);
}
    string FormatTooltipWithDistance(const string baseTooltip, const double priceLevel) {
        double pips = CalculatePipsDistance(priceLevel, g_currentPrice);
    return StringFormat("%s, Distance: +/- %.1f pips", baseTooltip, pips);
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
    double GetSharedComponentValue(ENUM_COMBO_COMPONENT_ITEM component, double structure, double pattern, double trigger) {
        #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ DEPRECATED: GetSharedComponentValue called - use CalculateComboStepSize instead");
    #endif
    switch(component) {        case COMP_SUB_TH:          return trigger * 0.25;
    case COMP_SUB_SS:          return trigger * 0.375;
    case COMP_SUB_LS:          return trigger * 0.5;
    case COMP_TRIGGER_TH:      return trigger;
    case COMP_TRIGGER_SS:      return trigger * 1.5;
    case COMP_TRIGGER_LS:      return trigger * 2.0;
    case COMP_PATTERN_TH:      return pattern;
    case COMP_PATTERN_SS:      return pattern * 1.5;
    case COMP_PATTERN_LS:      return pattern * 2.0;
    case COMP_STRUCTURE_TH:    return structure;
    case COMP_STRUCTURE_SS:    return structure * 1.5;
    case COMP_STRUCTURE_LS:    return structure * 2.0;
    case COMP_IGNORE:          return 0.0;
    default:                   return trigger;    }
}
    string GetSharedComponentName(ENUM_COMBO_COMPONENT_ITEM component) {
        #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ DEPRECATED: GetSharedComponentName called - use Preset system instead");
    #endif
    switch(component) {
        case COMP_SUB_TH:          return "Sub-TH";
    case COMP_SUB_SS:          return "Sub-SS";
    case COMP_SUB_LS:          return "Sub-LS";
    case COMP_TRIGGER_TH:      return "Trigger-TH";
    case COMP_TRIGGER_SS:      return "Trigger-SS";
    case COMP_TRIGGER_LS:      return "Trigger-LS";
    case COMP_PATTERN_TH:      return "Pattern-TH";
    case COMP_PATTERN_SS:      return "Pattern-SS";
    case COMP_PATTERN_LS:      return "Pattern-LS";
    case COMP_STRUCTURE_TH:    return "Structure-TH";
    case COMP_STRUCTURE_SS:    return "Structure-SS";
    case COMP_STRUCTURE_LS:    return "Structure-LS";
    case COMP_IGNORE:          return "Ignore";
    default:                   return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Clear all temporary mode labels (call before showing new one)   |

//+------------------------------------------------------------------+
void ClearAllModeLabels() {
        if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectDelete(0, g_stepModeLabelName);
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectDelete(0, g_factorLabelName);
    }

    Comment("");
}
    void ApplyModeLabelStyle(const string name, const color textColor, const int yOffsetExtra = 0) {
        ObjectSetInteger(0, name, OBJPROP_CORNER, inpModeLabelCorner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, inpModeLabelXDistance);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, inpModeLabelYDistance + yOffsetExtra);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetString(0, name, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpModeLabelFontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
    void UpdateStepModeLabel() {    if(!inpShowModeChangeLabel) return;
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    string modeName = GetStepModeName(currentMode);
    string basisName = "TH";
    if(currentMode == COMBO_STEP) {
        ENUM_COMBO_MODE currentComboMode = inpComboMode;
    if(currentComboMode == COMBO_MODE_PRESET) {            ENUM_COMBO_PRESET currentPreset = inpComboPreset;
    string presetName = GetComboPresetName(currentPreset);
    modeName = modeName + " [" + presetName + "]";
        } else {            modeName = modeName + " [Calculator]";
        }
    }
    ClearAllModeLabels();
    if(IsIndicatorHidden()) return;
    if(ObjectFind(0, g_stepModeLabelName) < 0) {
        ObjectCreate(0, g_stepModeLabelName, OBJ_LABEL, 0, 0, 0);
    }
    ObjectSetString(0, g_stepModeLabelName, OBJPROP_TEXT, "[ " + basisName + " | " + modeName + " ]");
    ApplyModeLabelStyle(g_stepModeLabelName, inpModeLabelColor);
    if(inpModeLabelDuration > 0) {
        EventSetTimer(inpModeLabelDuration);
    }
}

//+------------------------------------------------------------------+
//| Update Factor value label on chart (configurable duration)      |

//| Shows: "F: 2.50 | Step: 12.5 pips" with auto-hide               |
//+------------------------------------------------------------------+
void UpdateFactorLabel(double factorValue) {    if(!inpShowModeChangeLabel) return;
    ClearAllModeLabels();
    if(IsIndicatorHidden()) return;
    double stepSize = 0;
    string stepText = "";
    if(g_highestHigh > 0 && g_lowestLow > 0 && g_highestHigh > g_lowestLow) {
        stepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
    if(stepSize > 0) {
        double pipSize = GetCachedPipSize();
    double stepPips = stepSize / pipSize;
    stepText = " | Step: " + DoubleToString(stepPips, 1) + " pips";
        }
    }
    if(ObjectFind(0, g_factorLabelName) < 0) {
        ObjectCreate(0, g_factorLabelName, OBJ_LABEL, 0, 0, 0);
    }
    ObjectSetString(0, g_factorLabelName, OBJPROP_TEXT, 
        "[ F: " + DoubleToString(factorValue, 2) + stepText + " ]");
    ApplyModeLabelStyle(g_factorLabelName, inpFactorLevelColor);
    if(inpModeLabelDuration > 0) {
        EventSetTimer(inpModeLabelDuration);
    }
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
bool CreateGenericMidZone(const string zoneName, const double prevPrice, const double currentPrice,
                          const double zoneHeight, const color zoneColor, const int transparency)
{
        if(StringLen(zoneName) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Empty zone name");
    #endif
    return false;
    }
    if(prevPrice <= 0 || currentPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Invalid prices - Prev=", DoubleToString(prevPrice, Digits), 
              ", Current=", DoubleToString(currentPrice, Digits));
    #endif
    return false;
    }
    if(prevPrice == currentPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ CreateGenericMidZone: Prices are equal - no zone needed");
    #endif
    return false;
    }
    if(zoneHeight <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Invalid zone height: ", DoubleToString(zoneHeight, Digits));
    #endif
    return false;
    }
    double midPoint = (prevPrice + currentPrice) / 2.0;
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
    if(upperPrice <= lowerPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Invalid zone boundaries - Upper=", DoubleToString(upperPrice, Digits), 
              ", Lower=", DoubleToString(lowerPrice, Digits));
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Factory failed for '", zoneName, "' - ", result.errorMessage, 
              " (Code: ", result.errorCode, ")");
    #endif
    return false;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CreateGenericMidZone: Created/Updated '", zoneName, "' [", 
          DoubleToString(lowerPrice, Digits), " - ", DoubleToString(upperPrice, Digits), "]");
    #endif
    return true;
}
    #endif
