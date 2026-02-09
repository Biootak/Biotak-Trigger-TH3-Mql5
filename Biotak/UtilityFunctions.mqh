//+------------------------------------------------------------------+
//|                                            UtilityFunctions.mqh |
//|                                  Copyright 2025, Biotak Project  |
//|                                      General Utility Functions   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

// CRITICAL: Include guard to prevent duplicate symbols
#ifndef UTILITY_FUNCTIONS_MQH
#define UTILITY_FUNCTIONS_MQH

// Include ZoneFactory for centralized zone creation
#include "ZoneFactory.mqh"

//+------------------------------------------------------------------+
//| Throttled ChartRedraw() to prevent excessive CPU usage           |
//| استفاده throttled از ChartRedraw برای جلوگیری از CPU بالا        |
//| GOLD FIX: Prevents 17 rapid ChartRedraw calls in OnChartEvent   |
//+------------------------------------------------------------------+
void ThrottledChartRedraw() {
    uint nowMs = GetTickCount();
    // Allow immediate redraw if > 100ms passed
    if(nowMs - g_lastChartRedrawTime > CHART_REDRAW_THROTTLE_MS) {
        ChartRedraw();
        g_lastChartRedrawTime = nowMs;
    }
    // Else skip - chart will redraw on next OnCalculate anyway
}

//+------------------------------------------------------------------+
//| Get Symbol Point (Cached)                                        |
//+------------------------------------------------------------------+
double GetSymbolPoint() {
    static double point = 0;
    if(point == 0) {
        // MQL5: Use SymbolInfoDouble instead of MarketInfo
        point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        // For most forex pairs, SYMBOL_POINT and SYMBOL_TRADE_TICK_SIZE are the same
        // But to be absolutely sure, we use SYMBOL_POINT which matches Java's tickSize
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
    // PERF FIX: Use MQL5 built-in ArrayMaximum (potentially faster/optimized)
    int maxIdx = ArrayMaximum(array);
    if(maxIdx < 0) return EMPTY_VALUE;
    return array[maxIdx];
}

double GetArrayMin(const double &array[]) {
    int size=ArraySize(array);
    if(size<=0) return EMPTY_VALUE;
    // PERF FIX: Use MQL5 built-in ArrayMinimum (potentially faster/optimized)
    int minIdx = ArrayMinimum(array);
    if(minIdx < 0) return EMPTY_VALUE;
    return array[minIdx];
}

void CheckArraySizes() {
    // OPTIMIZATION: Use smarter initial sizing based on actual needs
    // Cache arrays: size based on number of fractal timeframes + buffer
    int optimalCacheSize = ArraySize(FRACTAL_TIMEFRAMES) + ArraySize(STANDARD_TIMEFRAMES) + 5;
    
    if(ArraySize(g_thCache) <= 0) {
        ArrayResize(g_thCache, optimalCacheSize);
        for(int i = 0; i < optimalCacheSize; i++) {
            g_thCache[i].valid = false;
            g_thCache[i].value = EMPTY_VALUE;
            g_thCache[i].lastUpdate = 0;
        }
    }

    // Stored THs: size based on actual timeframe count
    if(ArraySize(g_storedTHs) <= 0) {
        ArrayResize(g_storedTHs, optimalCacheSize);
    }

    // Label positions: size based on actual timeframe count
    if(ArraySize(g_labelPositions) <= 0) {
        ArrayResize(g_labelPositions, optimalCacheSize);
    }
}

//+------------------------------------------------------------------+
//| Calculate pips distance between two prices                       |
//| Note: Uses g_currentPrice which is Close of last completed bar  |
//| OPTIMIZED: Uses cached Point value via GetSymbolPoint()         |
//+------------------------------------------------------------------+
double CalculatePipsDistance(const double price1, const double price2) {
    // OPTIMIZATION: Use centralized cached Point from PerformanceOptimizations.mqh
    double cachedPoint = GetCachedPoint();
    if(IsZero(cachedPoint, EPSILON_PRICE)) return 0.0;  // Prevent division by zero
    return NormalizeDouble(MathAbs(price1 - price2) / cachedPoint / 10.0, 1);
}

//+------------------------------------------------------------------+
//| Format tooltip with distance in pips                            |
//+------------------------------------------------------------------+
string FormatTooltipWithDistance(const string baseTooltip, const double priceLevel) {
    double pips = CalculatePipsDistance(priceLevel, g_currentPrice);
    return StringFormat("%s, Distance: +/- %.1f pips", baseTooltip, pips);
}

//+------------------------------------------------------------------+
//| Get midpoint price based on start point type                    |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Get current step calculation mode (respects keyboard override)  |
//| Supports modes 0-5: TH, SS/LS, M, TP, Combo, Factor             |
//+------------------------------------------------------------------+
ENUM_STEP_CALCULATION_MODE GetCurrentStepMode() {
    // If user has overridden via keyboard, use that
    // Range 0-5 includes FACTOR_STEP (mode 5)
    if(g_stepModeOverride >= 0 && g_stepModeOverride <= 5) {
        return (ENUM_STEP_CALCULATION_MODE)g_stepModeOverride;
    }
    // Otherwise use input parameter
    return inpStepCalculationMode;
}

//+------------------------------------------------------------------+
//| Get step mode display name for UI                               |
//+------------------------------------------------------------------+
string GetStepModeName(ENUM_STEP_CALCULATION_MODE mode) {
    switch(mode) {
        case TH_STEP:           return "S";      // Structure step (was TH - renamed to avoid confusion with TH/ATR basis)
        case SS_LS_STEP:        return "SS/LS";
        case M_STEP:            return "M";
        case TP_STEP:           return "TP";
        case COMBO_STEP:        return "Combo";
        case FACTOR_STEP:       return "F";      // Factor step mode
        default:                return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get Preset name for display (user-friendly)                     |
//| دریافت نام Preset برای نمایش (کاربرپسند)                        |
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
//| DEPRECATED: Old Combo Step component system                     |
//| Use CalculateComboStepSize() with Preset system instead         |
//|                                                                  |
//| This function is kept for backward compatibility only           |
//+------------------------------------------------------------------+
double GetSharedComponentValue(ENUM_COMBO_COMPONENT_ITEM component, double structure, double pattern, double trigger) {
    #ifdef ENABLE_DEBUG_LOGS
    Print("⚠️ DEPRECATED: GetSharedComponentValue called - use CalculateComboStepSize instead");
    #endif
    
    switch(component) {
        // Sub components (1/4x - using trigger/4 approximation for legacy)
        case COMP_SUB_TH:          return trigger * 0.25;             // Sub TH
        case COMP_SUB_SS:          return trigger * 0.375;            // Sub SS (1.5/4)
        case COMP_SUB_LS:          return trigger * 0.5;              // Sub LS (2.0/4)
        
        // Trigger components
        case COMP_TRIGGER_TH:      return trigger;                    // Trigger TH
        case COMP_TRIGGER_SS:      return trigger * 1.5;              // Trigger SS
        case COMP_TRIGGER_LS:      return trigger * 2.0;              // Trigger LS
        
        // Pattern components
        case COMP_PATTERN_TH:      return pattern;                    // Pattern TH
        case COMP_PATTERN_SS:      return pattern * 1.5;              // Pattern SS
        case COMP_PATTERN_LS:      return pattern * 2.0;              // Pattern LS
        
        // Structure components
        case COMP_STRUCTURE_TH:    return structure;                  // Structure TH
        case COMP_STRUCTURE_SS:    return structure * 1.5;            // Structure SS
        case COMP_STRUCTURE_LS:    return structure * 2.0;            // Structure LS
        
        case COMP_IGNORE:          return 0.0;                        // Ignore
        
        default:                   return trigger;                    // Default to Trigger TH
    }
}

//+------------------------------------------------------------------+
//| DEPRECATED: Get component name for display                      |
//| Use Preset names instead                                        |
//+------------------------------------------------------------------+
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
//| پاک کردن همه label های موقت (قبل از نمایش جدید صدا بزن)         |
//+------------------------------------------------------------------+
void ClearAllModeLabels() {
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectDelete(0, g_stepModeLabelName);
    }
    if(ObjectFind(0, g_basisModeLabelName) >= 0) {
        ObjectDelete(0, g_basisModeLabelName);
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectDelete(0, g_factorLabelName);
    }
    if(ObjectFind(0, g_frequencyLabelName) >= 0) {
        ObjectDelete(0, g_frequencyLabelName);
    }
    Comment("");
}

//+------------------------------------------------------------------+
//| Update step mode label on chart (configurable duration)         |
//| Uses Label object for larger font and better positioning        |
//| Shows both basis and step mode: "TH | SS/LS"                    |
//| Duration: inpModeLabelDuration (0=permanent, >0=seconds)        |
//+------------------------------------------------------------------+
void UpdateStepModeLabel() {
    // Check if mode label display is enabled
    if(!inpShowModeChangeLabel) return;
    
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    string modeName = GetStepModeName(currentMode);
    ENUM_CALCULATION_BASIS currentBasis = GetCurrentCalculationBasis();
    string basisName = (currentBasis == CALC_BASIS_TH) ? "TH" : "ATR";
    
    // For Combo mode, add Mode and Preset/Operation info
    // THREAD-SAFE: Read values once to avoid race conditions
    if(currentMode == COMBO_STEP) {
        ENUM_COMBO_MODE currentComboMode = inpComboMode;  // Atomic read
        
        if(currentComboMode == COMBO_MODE_PRESET) {
            // Preset Mode: Show preset name
            ENUM_COMBO_PRESET currentPreset = inpComboPreset;  // Atomic read
            string presetName = GetComboPresetName(currentPreset);
            modeName = modeName + " [" + presetName + "]";
        } else {
            // Manual Mode: Calculator Mode
            modeName = modeName + " [Calculator]";
        }
    }
    
    // Clear ALL temporary labels first (prevents overlap)
    // CRITICAL: Must be done BEFORE creating new label
    ClearAllModeLabels();
    
    // CRITICAL FIX: Don't show label if indicator is hidden
    // PERFORMANCE: Use cached IsIndicatorHidden()
    if(IsIndicatorHidden()) return; // Don't show mode labels when hidden
    
    // GOLD FIX: Check if object exists before creating
    if(ObjectFind(0, g_stepModeLabelName) < 0) {
        ObjectCreate(0, g_stepModeLabelName, OBJ_LABEL, 0, 0, 0);
    }
    
    // Set text with basis AND mode name: "TH | SS/LS"
    ObjectSetString(0, g_stepModeLabelName, OBJPROP_TEXT, "[ " + basisName + " | " + modeName + " ]");
    
    // Position: top-left corner with minimal space usage
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_XDISTANCE, 15);
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_YDISTANCE, 25); // First line
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    
    // Font: bold for better visibility
    ObjectSetString(0, g_stepModeLabelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_FONTSIZE, 11);
    
    // Color: use dark color for better visibility on light backgrounds (lavender)
    // رنگ: استفاده از رنگ تیره برای دیده شدن بهتر روی پس‌زمینه روشن (لاوندر)
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_COLOR, clrDarkBlue);
    
    // Make sure it's visible
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_HIDDEN, true);
    
    // Set timer based on user setting (0=permanent, >0=auto-hide after N seconds)
    if(inpModeLabelDuration > 0) {
        EventSetTimer(inpModeLabelDuration);
    }
}

//+------------------------------------------------------------------+
//| Update calculation basis label on chart (configurable duration) |
//| Uses Label object matching step mode label style                |
//| Shows both basis and current step mode: "ATR | SS/LS"           |
//| Duration: inpModeLabelDuration (0=permanent, >0=seconds)        |
//+------------------------------------------------------------------+
void UpdateBasisModeLabel(ENUM_CALCULATION_BASIS basis) {
    // Check if mode label display is enabled
    if(!inpShowModeChangeLabel) return;
    
    string basisName = (basis == CALC_BASIS_TH) ? "TH" : "ATR";
    string modeName = GetStepModeName(GetCurrentStepMode());
    
    // Clear ALL temporary labels first (prevents overlap)
    ClearAllModeLabels();
    
    // CRITICAL FIX: Don't show label if indicator is hidden
    if(IsIndicatorHidden()) return; // Don't show mode labels when hidden
    
    // GOLD FIX: Check if object exists before creating
    if(ObjectFind(0, g_basisModeLabelName) < 0) {
        ObjectCreate(0, g_basisModeLabelName, OBJ_LABEL, 0, 0, 0);
    }
    
    // Set text with basis name AND step mode: "ATR | SS/LS"
    ObjectSetString(0, g_basisModeLabelName, OBJPROP_TEXT, "[ " + basisName + " | " + modeName + " ]");
    
    // Position: top-left corner with minimal space usage (same as step mode)
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_XDISTANCE, 15);
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_YDISTANCE, 25); // First line (temporary display)
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    
    // Font: bold for better visibility (same as step mode)
    ObjectSetString(0, g_basisModeLabelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_FONTSIZE, 11);
    
    // Color: use dark color for better visibility on light backgrounds (lavender)
    // رنگ: استفاده از رنگ تیره برای دیده شدن بهتر روی پس‌زمینه روشن (لاوندر)
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_COLOR, clrDarkBlue);
    
    // Make sure it's visible
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_HIDDEN, true);
    
    // Set timer based on user setting (0=permanent, >0=auto-hide after N seconds)
    if(inpModeLabelDuration > 0) {
        EventSetTimer(inpModeLabelDuration);
    }
}

//+------------------------------------------------------------------+
//| Update Factor value label on chart (configurable duration)      |
//| نمایش مقدار فاکتور و استپ روی چارت (با مدت زمان قابل تنظیم)      |
//| Shows: "F: 2.50 | Step: 12.5 pips" with auto-hide               |
//+------------------------------------------------------------------+
void UpdateFactorLabel(double factorValue) {
    // Check if mode label display is enabled
    if(!inpShowModeChangeLabel) return;
    
    // Clear ALL temporary labels first (prevents overlap)
    ClearAllModeLabels();
    
    // CRITICAL FIX: Don't show label if indicator is hidden
    if(IsIndicatorHidden()) return; // Don't show mode labels when hidden
    
    // Calculate step size for display
    double stepSize = 0;
    string stepText = "";
    
    if(g_highestHigh > 0 && g_lowestLow > 0 && g_highestHigh > g_lowestLow) {
        stepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
        
        if(stepSize > 0) {
            // Calculate pip size based on Digits
            double pipSize = GetCachedPipSize();
            double stepPips = stepSize / pipSize;
            stepText = " | Step: " + DoubleToString(stepPips, 1) + " pips";
        }
    }
    
    // GOLD FIX: Check if object exists before creating
    if(ObjectFind(0, g_factorLabelName) < 0) {
        ObjectCreate(0, g_factorLabelName, OBJ_LABEL, 0, 0, 0);
    }
    
    // Set text with Factor value and Step: "F: 2.50 | Step: 12.5 pips"
    ObjectSetString(0, g_factorLabelName, OBJPROP_TEXT, 
        "[ F: " + DoubleToString(factorValue, 2) + stepText + " ]");
    
    // Position: top-left corner with minimal space usage (same as step mode)
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_XDISTANCE, LABEL_X_OFFSET);
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_YDISTANCE, LABEL_Y_OFFSET); // First line (temporary display)
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    
    // Font: bold for better visibility (same as step mode)
    ObjectSetString(0, g_factorLabelName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_FONTSIZE, 11);
    
    // Color: Use Factor level color from settings (same as Factor lines)
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_COLOR, inpFactorLevelColor);
    
    // Make sure it's visible
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_HIDDEN, true);
    
    // Set timer based on user setting (0=permanent, >0=auto-hide after N seconds)
    if(inpModeLabelDuration > 0) {
        EventSetTimer(inpModeLabelDuration);
    }
}

//+------------------------------------------------------------------+
//| Update TH3 Frequency Label (auto-hide after 5 seconds)          |
//| نمایش فرکانس TH3 روی چارت (با حذف خودکار بعد از 5 ثانیه)         |
//+------------------------------------------------------------------+
void UpdateTH3FrequencyLabel(double frequency) {
    // Check if mode label display is enabled
    if(!inpShowModeChangeLabel) return;
    
    // Clear ALL temporary labels first (prevents overlap)
    ClearAllModeLabels();
    
    // CRITICAL FIX: Don't show label if indicator is hidden
    // PERFORMANCE: Use cached IsIndicatorHidden()
    if(IsIndicatorHidden()) return; // Don't show mode labels when hidden
    
    // Calculate step information based on current TH3 structure range
    string stepInfo = "";
    
    // Try to find an active TH3 structure to calculate step info
    int total = ObjectsTotal(0, -1, OBJ_FIBO);
    for(int i = 0; i < total; i++) {
        string name = ObjectName(0, i, -1, OBJ_FIBO);
        
        if(StringFind(name, "TH3_Structure_") == 0 && 
           StringFind(name, "_Text") < 0 && 
           StringFind(name, "_Target") < 0) {
            
            // Get structure range
            datetime t1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
            double p1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
            datetime t2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
            double p2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
            
            // CRITICAL FIX: Validate ObjectGet results
            if(t1 <= 0 || t2 <= 0 || p1 <= 0 || p2 <= 0) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ GetStructureRangeFromTH3: Invalid object data for ", name);
                #endif
                continue;
            }
            
            if(t1 > 0 && t2 > 0 && p1 > 0 && p2 > 0) {
                double range = MathAbs(p2 - p1);
                
                // Use existing CalculatePipsDistance function for accurate pip calculation
                double rangePips = CalculatePipsDistance(p1, p2);
                
                // Calculate step size and count
                double stepPips = rangePips * (frequency / 100.0);
                double stepCount = rangePips / stepPips;
                int fullSteps = (int)MathFloor(stepCount);
                double remainder = stepCount - fullSteps;
                
                stepInfo = StringFormat(" | Step: %.1f pips | Steps: %d + %.2f", 
                    stepPips, fullSteps, remainder);
                break; // Use first found structure
            }
        }
    }
    
    // GOLD FIX: Check if object exists before creating
    if(ObjectFind(0, g_frequencyLabelName) < 0) {
        ObjectCreate(0, g_frequencyLabelName, OBJ_LABEL, 0, 0, 0);
    }
    
    // Set text with frequency value and step info
    ObjectSetString(0, g_frequencyLabelName, OBJPROP_TEXT, 
        "[ TH3 Freq: " + DoubleToString(frequency, 3) + "%" + stepInfo + " ]");
    
    // Position: offset below step mode label to prevent overlap
    // موقعیت: زیر لیبل step mode برای جلوگیری از همپوشانی
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_CORNER, inpModeLabelCorner);
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_XDISTANCE, inpModeLabelXDistance);
    // Add FREQUENCY_LABEL_Y_EXTRA pixels offset to Y position to place below step mode label
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_YDISTANCE, inpModeLabelYDistance + FREQUENCY_LABEL_Y_EXTRA);
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    
    // Font: use input parameters for customization
    ObjectSetString(0, g_frequencyLabelName, OBJPROP_FONT, inpFontName);
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_FONTSIZE, inpModeLabelFontSize);
    
    // Color: use input parameter for customization
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_COLOR, inpModeLabelColor);
    
    // Make visible
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_HIDDEN, true);
    
    // Set timer for auto-hide (frequency labels stay longer for readability)
    EventSetTimer(FREQUENCY_LABEL_TIMER_SEC);
}


//+------------------------------------------------------------------+
//| Create Mid-Range Zone (Generic function for all modes)          |
//| رسم محدوده میانی (تابع عمومی برای همه مودها)                     |
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
//| ایجاد Zone میانی عمومی - نسخه طلایی v2                           |
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
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: QUICK VALIDATION (Fail Fast)
    // ═══════════════════════════════════════════════════════════════
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
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: CALCULATE ZONE BOUNDARIES (Optimized)
    // ═══════════════════════════════════════════════════════════════
    
    // Calculate midpoint between previous and current
    double midPoint = (prevPrice + currentPrice) / 2.0;
    
    // Calculate zone boundaries (±zoneHeight from midpoint)
    // OPTIMIZATION: Single NormalizeDouble call per value
    double upperPrice = NormalizeDouble(midPoint + zoneHeight, GetCachedDigits());
    double lowerPrice = NormalizeDouble(midPoint - zoneHeight, GetCachedDigits());
    
    // Validate zone boundaries
    if(upperPrice <= lowerPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateGenericMidZone: Invalid zone boundaries - Upper=", DoubleToString(upperPrice, Digits), 
              ", Lower=", DoubleToString(lowerPrice, Digits));
        #endif
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: DELEGATE TO ZONE FACTORY (Centralized Creation)
    // OPTIMIZATION: Let factory handle update vs create decision
    // ═══════════════════════════════════════════════════════════════
    
    SZoneCreationRequest request;
    request.name = zoneName;
    request.topPrice = upperPrice;
    request.bottomPrice = lowerPrice;
    request.zoneColor = zoneColor;
    request.transparency = transparency;
    request.filled = true;
    request.startTime = 0;  // Auto-calculate
    request.endTime = 0;    // Auto-calculate
    
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

#endif // UTILITY_FUNCTIONS_MQH

