#property copyright "Â© Formula by Professor Saeed Khakestar, Indicator by Biotak."
#property link "@biotak"
#include "UnifiedZoneSystem.mqh"
#include "ZoneTrackingHelpers.mqh"
//+------------------------------------------------------------------+
//| PERF: Delete surplus zone/line objects beyond what was just drawn |

//| Uses consecutive-miss strategy: stops after 3 misses in a row    |
//| ANTI-FLICKER: Skips cleanup if custom price is being dragged    |
//+------------------------------------------------------------------+
void CleanupSurplusObjects(const string prefix, int startIdx, int maxConsecutiveMiss = 6) {
        if(g_customPriceLineDragging && StringFind(prefix, "_Zone_") >= 0) {
        return;    }
    int misses = 0;
    for(int idx = startIdx; misses < maxConsecutiveMiss; idx++) {
        string name = prefix + IntegerToString(idx);
    if(ObjectFind(0, name) >= 0) {
            CacheRemoveObject(name);
            ObjectDelete(0, name);
    misses = 0;        } else {
            misses++;
        }
    }
}

//+------------------------------------------------------------------+
//| HELPER: Create or Update a horizontal level line                 |

//| Returns true if a NEW object was created (for zone tracking)    |
//| PERF: Only sets visual properties on new objects                |
//+------------------------------------------------------------------+
bool CreateOrUpdateHLine(const string name, double price, 
                          color clr, ENUM_LINE_STYLE style, int width,
                          const string tooltip) {
    bool objectExists = CacheObjectExists(name);
    if(!objectExists) objectExists = (ObjectFind(0, name) >= 0);
    
    if(!objectExists) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
        CacheAddObject(name, price, clr, style, width);
        // FIX: Use unified visibility system instead of raw g_linesVisible check
        ApplyVisibilityState(name, true);
        return true;
    } else {
        // FIX: Only update price if changed (use cache for comparison)
        SObjectCacheEntry cachedEntry;
        bool hasCached = CacheGetObject(name, cachedEntry);
        double normPrice = NormalizeDouble(price, _Digits);
        if(!hasCached || MathAbs(hasCached ? cachedEntry.lastPrice - normPrice : 1.0) > GetCachedPoint() * 0.1) {
            ObjectSetDouble(0, name, OBJPROP_PRICE, normPrice);
        }
        if(!hasCached || cachedEntry.lastColor != clr) {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
        }
        CacheUpdateObject(name, normPrice, clr, style, width);
        // FIX: Use unified visibility system for existing objects too
        ApplyVisibilityStateIfUnchangedSkip(name, true);
        return false;
    }
}

//+------------------------------------------------------------------+
//| HELPER: Get common viewport bounds for level drawing             |
//| PERF: Cached per-frame via g_cacheFrameTime — eliminates ~8      |
//|       redundant ChartGetDouble syscalls across 4 pipelines       |
//+------------------------------------------------------------------+
void GetViewportBounds(double &vpTop, double &vpBottom) {
    static double s_vpTop = 0;
    static double s_vpBottom = 0;
    static datetime s_vpFrameTime = 0;
    datetime frameTime = CacheGetFrameTime();
    if(frameTime == s_vpFrameTime && s_vpTop > 0) {
        vpTop = s_vpTop;
        vpBottom = s_vpBottom;
        return;
    }
    double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = (vpChartMax - vpChartMin) * 0.5;
    vpTop = vpChartMax + vpRange;
    vpBottom = vpChartMin - vpRange;
    s_vpTop = vpTop;
    s_vpBottom = vpBottom;
    s_vpFrameTime = frameTime;
}

//+------------------------------------------------------------------+
//| Create Factor Mid Zone - REFACTORED to use Unified System        |

//|                                                                  |
//| ARCHITECTURE: Now uses UnifiedZoneSystem for consistency         |

//| FIXED: Respects Hide state when creating zones                  |
//|                                                                  |
//| @param zoneName Unique name for the zone object                 |
//| @param upperPrice Top boundary of the zone                      |
//| @param lowerPrice Bottom boundary of the zone                   |
//| @param zoneColor Color of the zone                              |
//| @param zoneStyle Style (Lines/Filled/Empty/Hidden)              |
//| @param transparency Transparency (0-100, 0=opaque, 100=invisible)|
//| @return true if zone created successfully, false otherwise      |
//+------------------------------------------------------------------+
bool CreateFactorMidZone(const string zoneName, 
                         const double upperPrice,
                         const double lowerPrice,
                         const color zoneColor,
                         const ENUM_ZONE_STYLE zoneStyle,
                         const int transparency)
{
        if(zoneStyle == FACTOR_ZONE_HIDDEN) {
        if(ObjectFind(0, zoneName) >= 0) {
            CacheRemoveObject(zoneName);
            ObjectDelete(0, zoneName);
        }
    return true;
    }
    if(zoneStyle == FACTOR_ZONE_LINES) {
        return CreateFactorMidZone_LinesStyle(zoneName, upperPrice, lowerPrice, 
                                              zoneColor, transparency);
    }
    double midPoint = (upperPrice + lowerPrice) / 2.0;
    double halfHeight = (upperPrice - lowerPrice) / 2.0;
    SZoneCreationRequest request;
    request.name = zoneName;
    request.topPrice = upperPrice;
    request.bottomPrice = lowerPrice;
    request.zoneColor = zoneColor;
    request.transparency = transparency;
    request.filled = (zoneStyle == FACTOR_ZONE_BOX_FILLED);
    request.startTime = 0;
    request.endTime = 0;
    SZoneCreationResult result = CreateZone(request);
    return result.success;
}

//+------------------------------------------------------------------+
//| Create Factor Mid Zone - LINES STYLE (Legacy)                    |

//|                                                                  |

//| FIXED: Respects Hide state when creating line zones             |
//+------------------------------------------------------------------+
bool CreateFactorMidZone_LinesStyle(const string zoneName,
                                    const double upperPrice,
                                    const double lowerPrice,
                                    const color zoneColor,
                                    const int transparency)
{
        if(StringLen(zoneName) == 0) return false;
    if(upperPrice <= 0 || lowerPrice <= 0) return false;
    if(upperPrice <= lowerPrice) return false;
    string lineTop = zoneName + "_Top";
    string lineBottom = zoneName + "_Bottom";

    bool topExists = (ObjectFind(0, lineTop) >= 0);
    if(!topExists) {
        if(!ObjectCreate(0, lineTop, OBJ_HLINE, 0, 0, upperPrice)) return false;
        ObjectSetInteger(0, lineTop, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lineTop, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lineTop, OBJPROP_BACK, true);
        ObjectSetInteger(0, lineTop, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineTop, OBJPROP_ZORDER, 0);
    }
    ObjectSetDouble(0, lineTop, OBJPROP_PRICE, upperPrice);
    ObjectSetInteger(0, lineTop, OBJPROP_COLOR, zoneColor);
    ApplyVisibilityState(lineTop, true);

    bool bottomExists = (ObjectFind(0, lineBottom) >= 0);
    if(!bottomExists) {
        if(!ObjectCreate(0, lineBottom, OBJ_HLINE, 0, 0, lowerPrice)) return false;
        ObjectSetInteger(0, lineBottom, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lineBottom, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lineBottom, OBJPROP_BACK, true);
        ObjectSetInteger(0, lineBottom, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lineBottom, OBJPROP_ZORDER, 0);
    }
    ObjectSetDouble(0, lineBottom, OBJPROP_PRICE, lowerPrice);
    ObjectSetInteger(0, lineBottom, OBJPROP_COLOR, zoneColor);
    ApplyVisibilityState(lineBottom, true);

    return true;
}

//+------------------------------------------------------------------+
//| Get default Factor value from Control step size                  |

//| Simple Formula: Step = Range / (Factor Ã— 2)                      |
//| We want: Step = Control = (SS + LS) / 2 = TH Ã— 1.75              |
//| So: TH Ã— 1.75 = Range / (Factor Ã— 2)                             |
//| Therefore: Factor = Range / (TH Ã— 1.75 Ã— 2)                      |
//|                                                                  |
//| NOW SUPPORTS MULTIPLE BASIS TYPES:                               |
//| - Control, SS, LS, TH, Trigger, Pattern, Structure, Combo       |
//+------------------------------------------------------------------+
double GetDefaultFactorValue(const double basePrice) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetDefaultFactorValue: Invalid base price (", basePrice, "), using fallback");
    return 50.0;    }
    if(g_highestHigh <= 0 || g_lowestLow <= 0 || g_highestHigh <= g_lowestLow) {
        _LOG_GATE_E Print("[E][DRAW] GetDefaultFactorValue: Invalid historical range, using fallback");
    return 50.0;    }
    double range = g_highestHigh - g_lowestLow;
    if(range <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetDefaultFactorValue: Invalid range (", range, "), using fallback");
    return 50.0;
    }
    double stepSize = GetStepSizeForFactorBasis(basePrice, inpFactorAutoBasis);
    if(stepSize <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetDefaultFactorValue: Invalid step size, using fallback");
    return 50.0;
    }
    double denominator = stepSize * 2.0;
    if(denominator <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetDefaultFactorValue: Invalid denominator, using fallback");
    return 50.0;
    }
    double minDenominator = range / 10000.0;
    if(denominator < minDenominator) {
        _LOG_GATE_D Print("[D][DRAW] GetDefaultFactorValue: Step size too small (", DoubleToString(stepSize, 8));
    return 1000.0;
    }
    double factor = range / denominator;
    if(factor > 10000) {
        _LOG_GATE_D Print("[D][DRAW] GetDefaultFactorValue: Factor too large (", DoubleToString(factor, 2));
    factor = 1000.0;
    } else if(factor < 0.01) {
        _LOG_GATE_D Print("[D][DRAW] GetDefaultFactorValue: Factor too small (", DoubleToString(factor, 4));
    factor = 1.0;
    }
    double result = NormalizeDouble(MathMax(0.01, MathMin(10000, factor)), 2);
    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][DRAW] GetDefaultFactorValue: Basis=", EnumToString(inpFactorAutoBasis),
          ", basePrice=", DoubleToString(basePrice, Digits), 
          ", Range=", DoubleToString(range, Digits),
          ", StepSize=", DoubleToString(stepSize, Digits),
          ", Factor=", DoubleToString(result, 2));
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Get step size based on Factor Auto Basis selection               |

//| Complete validation and error handling             |
//+------------------------------------------------------------------+
double GetStepSizeForFactorBasis(const double basePrice, const ENUM_FACTOR_AUTO_BASIS basis) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForFactorBasis: Invalid basePrice=", basePrice);
    return 0;
    }
    double stepSize = 0;
    switch(basis) {
        case FACTOR_BASIS_CONTROL:            stepSize = GetStepSizeForBasisType(basePrice, 1.75, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_SS:            stepSize = GetStepSizeForBasisType(basePrice, 1.5, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_LS:            stepSize = GetStepSizeForBasisType(basePrice, 2.0, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_TH:
    case FACTOR_BASIS_TRIGGER:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_PATTERN:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, GetPatternTimeframe());
    break;
    case FACTOR_BASIS_STRUCTURE:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, GetStructureTimeframe());
    break;
    case FACTOR_BASIS_COMBO:            stepSize = GetComboStepSizeForFactor(basePrice);
    break;
    default:
            _LOG_GATE_W Print("[W][DRAW] GetStepSizeForFactorBasis: Unknown basis=", basis, ", using Control");
    stepSize = GetStepSizeForBasisType(basePrice, 1.75, PERIOD_CURRENT);
    break;
    }
    if(stepSize <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForFactorBasis: Failed to calculate step for basis=");
    return 0;
    }
    _LOG_GATE_I Print("[I][DRAW] GetStepSizeForFactorBasis: Basis=", EnumToString(basis));
    return stepSize;
}

//+------------------------------------------------------------------+
//| Get step size for specific multiplier and timeframe              |

//| FIXED: Comprehensive error handling and validation               |
//+------------------------------------------------------------------+
double GetStepSizeForBasisType(const double basePrice, const double multiplier, 
                                const ENUM_TIMEFRAMES timeframe) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForBasisType: Invalid basePrice=", basePrice);
    return 0;
    }
    if(multiplier <= 0 || multiplier > 10.0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForBasisType: Invalid multiplier=", multiplier);
    return 0;
    }
    double thPercentage = GetTimeframeTHForPeriod(timeframe);
    if(thPercentage <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForBasisType: Invalid TH%=", thPercentage, " for TF=", timeframe);
    return 0;
    }
    double thPriceUnits = (basePrice * thPercentage) / 100.0;
    if(thPriceUnits <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForBasisType: Invalid TH price units=", thPriceUnits);
    return 0;
    }
    double stepSize = thPriceUnits * multiplier;
    if(stepSize <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForBasisType: Zero or negative stepSize=", stepSize);
    return 0;
    }
    if(stepSize > basePrice * 0.5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[W][DRAW] GetStepSizeForBasisType: Suspiciously large stepSize=", stepSize,
              " (> 50% of basePrice=", basePrice, ")");
    Print("[D][DRAW]    TH%=", DoubleToString(thPercentage, 4), ", Mult=", multiplier);
    #endif
    }
    double minReasonableStep = basePrice * EPSILON_ANGLE;
    if(stepSize < minReasonableStep) {
        _LOG_GATE_W Print("[W][DRAW] GetStepSizeForBasisType: Suspiciously small stepSize=", stepSize);
    }
    _LOG_GATE_I Print("[I][DRAW] GetStepSizeForBasisType: TF=", timeframe, ", Mult=", multiplier);
    return stepSize;
}

//+------------------------------------------------------------------+
//| Calculate Triple Combo Step Size (3 components)                  |

//|                                                                  |
//| Used for Triple presets: Balanced, Conservative, Aggressive     |
//|                                                                  |
//| @param basePrice Base price for TH calculation (must be > 0)    |
//| @param tf1 First timeframe type                                 |
//| @param step1 First step type                                    |
//| @param tf2 Second timeframe type                                |
//| @param step2 Second step type                                   |
//| @param tf3 Third timeframe type                                 |
//| @param step3 Third step type                                    |
//| @param operation Operation to apply (Average, Min, Max only)   |
//| @return Calculated triple combo step size (> 0), or 0 on error |
//+------------------------------------------------------------------+
double CalculateTripleComboStepSize(const double basePrice,
                                    const ENUM_COMBO_TIMEFRAME_TYPE tf1,
                                    const ENUM_COMBO_STEP_TYPE step1,
                                    const ENUM_COMBO_TIMEFRAME_TYPE tf2,
                                    const ENUM_COMBO_STEP_TYPE step2,
                                    const ENUM_COMBO_TIMEFRAME_TYPE tf3,
                                    const ENUM_COMBO_STEP_TYPE step3,
                                    const ENUM_COMBO_OPERATION operation) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid basePrice=", basePrice);
    return 0;
    }
    if(tf1 < COMBO_TF_SUB || tf1 > COMBO_TF_STRUCTURE) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid tf1=", tf1);
    return 0;
    }
    if(tf2 < COMBO_TF_SUB || tf2 > COMBO_TF_STRUCTURE) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid tf2=", tf2);
    return 0;
    }
    if(tf3 < COMBO_TF_SUB || tf3 > COMBO_TF_STRUCTURE) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid tf3=", tf3);
    return 0;
    }
    if(step1 < COMBO_STEP_TH || step1 > COMBO_STEP_LS) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid step1=", step1);
    return 0;
    }
    if(step2 < COMBO_STEP_TH || step2 > COMBO_STEP_LS) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid step2=", step2);
    return 0;
    }
    if(step3 < COMBO_STEP_TH || step3 > COMBO_STEP_LS) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid step3=", step3);
    return 0;
    }
    if(operation < COMBO_OP_AVERAGE || operation > COMBO_OP_WEIGHTED) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid operation=", operation);
    return 0;
    }    
    ENUM_TIMEFRAMES timeframe1 = GetTimeframeByType(tf1);
    ENUM_TIMEFRAMES timeframe2 = GetTimeframeByType(tf2);
    ENUM_TIMEFRAMES timeframe3 = GetTimeframeByType(tf3);
    double multiplier1 = GetStepMultiplier(step1);
    double multiplier2 = GetStepMultiplier(step2);
    double multiplier3 = GetStepMultiplier(step3);
    double stepValue1 = GetStepSizeForBasisType(basePrice, multiplier1, timeframe1);
    double stepValue2 = GetStepSizeForBasisType(basePrice, multiplier2, timeframe2);
    double stepValue3 = GetStepSizeForBasisType(basePrice, multiplier3, timeframe3);
    if(stepValue1 <= 0 || stepValue2 <= 0 || stepValue3 <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid step values");
    return 0;
    }
    double result = 0;
    switch(operation) {
        case COMBO_OP_AVERAGE:            result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    break;
    case COMBO_OP_ADD:            {
        double maxSafeValue = DBL_MAX / 3.0;
    if(stepValue1 > maxSafeValue || stepValue2 > maxSafeValue || stepValue3 > maxSafeValue) {
                    _LOG_GATE_E Print("[E][DRAW] Overflow risk in COMBO_OP_ADD (triple), using safe fallback");
    result = MathMax(stepValue1, MathMax(stepValue2, stepValue3));
                } else {
                    result = stepValue1 + stepValue2 + stepValue3;
                }
            }
            break;
    case COMBO_OP_MIN:            result = MathMin(stepValue1, MathMin(stepValue2, stepValue3));
    break;
    case COMBO_OP_MAX:            result = MathMax(stepValue1, MathMax(stepValue2, stepValue3));
    break;
    default:
            _LOG_GATE_W Print("[W][DRAW] CalculateTripleComboStepSize: Unsupported operation=", operation);
    result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    break;
    }
    if(result <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateTripleComboStepSize: Invalid result=", result);
    return 0;
    }
    double maxStep = MathMax(stepValue1, MathMax(stepValue2, stepValue3));
    double minStep = MathMin(stepValue1, MathMin(stepValue2, stepValue3));
    bool isSuspicious = false;
    switch(operation) {
        case COMBO_OP_AVERAGE:            if(result < minStep * 0.9 || result > maxStep * 1.1) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_ADD:            if(result < maxStep) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_MIN:            if(MathAbs(result - minStep) > minStep * 0.001) {                isSuspicious = true;
            }
            break;
    case COMBO_OP_MAX:            if(MathAbs(result - maxStep) > maxStep * 0.001) {                isSuspicious = true;
            }
            break;
    }
    if(isSuspicious) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[W][DRAW] CalculateTripleComboStepSize: Suspicious result detected");
    Print("[D][DRAW]    Operation=", EnumToString(operation));
    Print("[D][DRAW]    Step1=", DoubleToString(stepValue1, Digits),
              ", Step2=", DoubleToString(stepValue2, Digits), 
              ", Step3=", DoubleToString(stepValue3, Digits));
    Print("[D][DRAW]    Result=", DoubleToString(result, Digits),
              " (min=", DoubleToString(minStep, Digits), 
              ", max=", DoubleToString(maxStep, Digits), ")");
    Print("[D][DRAW]    Using fallback: average");
    #endif
    result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] CalculateTripleComboStepSize: SUCCESS");
    Print("[D][DRAW]    TF1=", EnumToString(tf1), ", Step1=", DoubleToString(stepValue1, Digits));
    Print("[D][DRAW]    TF2=", EnumToString(tf2), ", Step2=", DoubleToString(stepValue2, Digits));
    Print("[D][DRAW]    TF3=", EnumToString(tf3), ", Step3=", DoubleToString(stepValue3, Digits));
    Print("[D][DRAW]    Operation=", EnumToString(operation), ", Result=", DoubleToString(result, Digits));
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Helper to decode Smart Combo Component Item to TF and Step       |

//+------------------------------------------------------------------+
bool GetComboComponentParams(const ENUM_COMBO_COMPONENT_ITEM item, 
                             ENUM_COMBO_TIMEFRAME_TYPE &outTF, 
                             ENUM_COMBO_STEP_TYPE &outStep) {
    if (item == COMP_IGNORE) return false;
    switch(item) {        case COMP_SUB_TH: outTF = COMBO_TF_SUB; outStep = COMBO_STEP_TH; return true;
    case COMP_SUB_SS: outTF = COMBO_TF_SUB; outStep = COMBO_STEP_SS; return true;
    case COMP_SUB_LS: outTF = COMBO_TF_SUB; outStep = COMBO_STEP_LS; return true;
    case COMP_TRIGGER_TH: outTF = COMBO_TF_TRIGGER; outStep = COMBO_STEP_TH; return true;
    case COMP_TRIGGER_SS: outTF = COMBO_TF_TRIGGER; outStep = COMBO_STEP_SS; return true;
    case COMP_TRIGGER_LS: outTF = COMBO_TF_TRIGGER; outStep = COMBO_STEP_LS; return true;
    case COMP_PATTERN_TH: outTF = COMBO_TF_PATTERN; outStep = COMBO_STEP_TH; return true;
    case COMP_PATTERN_SS: outTF = COMBO_TF_PATTERN; outStep = COMBO_STEP_SS; return true;
    case COMP_PATTERN_LS: outTF = COMBO_TF_PATTERN; outStep = COMBO_STEP_LS; return true;
    case COMP_STRUCTURE_TH: outTF = COMBO_TF_STRUCTURE; outStep = COMBO_STEP_TH; return true;
    case COMP_STRUCTURE_SS: outTF = COMBO_TF_STRUCTURE; outStep = COMBO_STEP_SS; return true;
    case COMP_STRUCTURE_LS: outTF = COMBO_TF_STRUCTURE; outStep = COMBO_STEP_LS; return true;
    default: return false;
    }
}
    double GetStepSizeFromComponent(const double basePrice, const ENUM_COMBO_COMPONENT_ITEM comp) {
    if (comp == COMP_IGNORE) return 0;
    if(comp >= COMP_SUB_MEAN && comp <= COMP_STRUCTURE_MEAN) {
        ENUM_COMBO_TIMEFRAME_TYPE tfType;
    switch(comp) {
            case COMP_SUB_MEAN:       tfType = COMBO_TF_SUB; break;
    case COMP_TRIGGER_MEAN:   tfType = COMBO_TF_TRIGGER; break;
    case COMP_PATTERN_MEAN:   tfType = COMBO_TF_PATTERN; break;
    case COMP_STRUCTURE_MEAN: tfType = COMBO_TF_STRUCTURE; break;
    default: return 0;
        }
        
        ENUM_TIMEFRAMES tf = GetTimeframeByType(tfType);
    if(tf <= 0) return 0;
    double th = GetStepSizeForBasisType(basePrice, 1.0, tf);
    double ss = GetStepSizeForBasisType(basePrice, 1.5, tf);
    double ls = GetStepSizeForBasisType(basePrice, 2.0, tf);
    int validCount = 0;
    if(th > 0) validCount++;
    if(ss > 0) validCount++;
    if(ls > 0) validCount++;
    if(validCount == 0) {
            _LOG_GATE_E Print("[E][DRAW] GetStepSizeFromComponent: All MEAN components invalid for ", EnumToString(comp));
    return 0;
        }
    if(validCount < 3) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[W][DRAW] GetStepSizeFromComponent: Only ", validCount, "/3 values valid for ", EnumToString(comp));
    Print("[E][DRAW]    TH: ", (th > 0 ? DoubleToString(th, Digits) : "INVALID"));
    Print("[E][DRAW]    SS: ", (ss > 0 ? DoubleToString(ss, Digits) : "INVALID"));
            Print("[E][DRAW]    LS: ", (ls > 0 ? DoubleToString(ls, Digits) : "INVALID"));
    #endif
    if(validCount == 1) {
                _LOG_GATE_D Print("[D][DRAW]  MEAN COMPONENT INFO: ", EnumToString(comp));
    } else if(validCount == 2) {
                _LOG_GATE_D Print("[D][DRAW]  MEAN COMPONENT INFO: ", EnumToString(comp));
    }
        }
    double validValues[];
    ArrayResize(validValues, validCount);
    int idx = 0;
    if(th > 0) validValues[idx++] = th;
    if(ss > 0) validValues[idx++] = ss;
    if(ls > 0) validValues[idx++] = ls;
    double result = CalculateMeanByType(validValues, inpAggregateMeanType);
    #ifdef ENABLE_DEBUG_LOGS
        Print("[I][DRAW] GetStepSizeFromComponent: MEAN component ", EnumToString(comp),
              " = ", DoubleToString(result, Digits), " (", validCount, "/3 valid values, ",
              EnumToString(inpAggregateMeanType), " mean)");
    #endif
    return result;
    }
    ENUM_COMBO_TIMEFRAME_TYPE tfType;
    ENUM_COMBO_STEP_TYPE stepType;
    if(!GetComboComponentParams(comp, tfType, stepType)) {
        return 0;
    }
    
    ENUM_TIMEFRAMES tf = GetTimeframeByType(tfType);
    if(tf <= 0) return 0;
    double mult = GetStepMultiplier(stepType);
    if(mult <= 0) return 0;
    return GetStepSizeForBasisType(basePrice, mult, tf);
}

//+------------------------------------------------------------------+
//| N-ARY MEAN CALCULATORS - For Multi-Component Operations          |

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Geometric Mean of N values: â¿âˆš(v1 Ã— v2 Ã— ... Ã— vn)    |

//|                                                                  |
//| Uses logarithmic approach to prevent overflow          |
//| Formula: exp((ln(v1) + ln(v2) + ... + ln(vn)) / n)              |
//+------------------------------------------------------------------+
double CalculateGeometricMeanN(const double &values[]) {
        int n = ArraySize(values);
    if(n == 0) return 0;
    if(n == 1) return values[0];
    double logSum = 0;
    for(int i = 0; i < n; i++) {
        if(values[i] <= 0) {
            _LOG_GATE_E Print("[E][DRAW] CalculateGeometricMeanN: Non-positive value at index ", i, ": ", values[i]);
    return 0;
        }
    logSum += MathLog(values[i]);
    }
    double result = MathExp(logSum / n);
    if(result <= 0 || result > DBL_MAX / 2.0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateGeometricMeanN: Invalid result=", result);
    return 0;
    }
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Arithmetic Mean of N values: (v1 + v2 + ... + vn) / n |

//+------------------------------------------------------------------+
double CalculateArithmeticMeanN(const double &values[]) {
        int n = ArraySize(values);
    if(n == 0) return 0;
    if(n == 1) return values[0];
    double sum = 0;
    for(int i = 0; i < n; i++) {
        sum += values[i];
    }
    return sum / n;
}

//+------------------------------------------------------------------+
//| Calculate Harmonic Mean of N values: n / (1/v1 + 1/v2 + ... + 1/vn) |

//+------------------------------------------------------------------+
double CalculateHarmonicMeanN(const double &values[]) {
        int n = ArraySize(values);
    if(n == 0) return 0;
    if(n == 1) return values[0];
    double reciprocalSum = 0;
    for(int i = 0; i < n; i++) {
        if(MathAbs(values[i]) < EPSILON_ANGLE) {
            _LOG_GATE_E Print("[E][DRAW] CalculateHarmonicMeanN: Zero/near-zero value at index ", i, ": ", values[i]);
    return 0;
        }
        reciprocalSum += 1.0 / values[i];
    }
    if(MathAbs(reciprocalSum) < EPSILON_ANGLE) return 0;
    return n / reciprocalSum;
}

//+------------------------------------------------------------------+
//| Calculate Minimum of N values: min(v1, v2, ..., vn)             |

//+------------------------------------------------------------------+
double CalculateMinN(const double &values[]) {
        int n = ArraySize(values);
    if(n == 0) return 0;
    if(n == 1) return values[0];
    double minVal = values[0];
    for(int i = 1; i < n; i++) {
        if(values[i] < minVal) minVal = values[i];
    }
    return minVal;
}

//+------------------------------------------------------------------+
//| Calculate Maximum of N values: max(v1, v2, ..., vn)             |

//+------------------------------------------------------------------+
double CalculateMaxN(const double &values[]) {
        int n = ArraySize(values);
    if(n == 0) return 0;
    if(n == 1) return values[0];
    double maxVal = values[0];
    for(int i = 1; i < n; i++) {
        if(values[i] > maxVal) maxVal = values[i];
    }
    return maxVal;
}

//+------------------------------------------------------------------+
//| Calculate mean based on type (Unified Interface)                 |

//|                                                                  |
//| This is the MAIN interface for all mean calculations             |
//| Used by: Quick Test, Aggregate Components, N-ary Operators      |
//+------------------------------------------------------------------+
double CalculateMeanByType(const double &values[], const ENUM_MEAN_TYPE meanType) {
        int n = ArraySize(values);
    if(n == 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateMeanByType: Empty array");
    return 0;
    }
    if(n == 1) return values[0];
    double result = 0;
    switch(meanType) {
        case MEAN_ARITHMETIC:
            result = CalculateArithmeticMeanN(values);
            _LOG_GATE_I Print("[I][DRAW] CalculateMeanByType: Arithmetic Mean of ", n, " values = ");
    break;
    case MEAN_GEOMETRIC:
            result = CalculateGeometricMeanN(values);
            _LOG_GATE_I Print("[I][DRAW] CalculateMeanByType: Geometric Mean of ", n, " values = ");
    break;
    case MEAN_HARMONIC:
            result = CalculateHarmonicMeanN(values);
            _LOG_GATE_I Print("[I][DRAW] CalculateMeanByType: Harmonic Mean of ", n, " values = ");
    break;
    default:
            _LOG_GATE_E Print("[E][DRAW] CalculateMeanByType: Unknown mean type ", meanType);
    return 0;
    }
    return result;
}

//+------------------------------------------------------------------+
//| QUICK TEST MODE FUNCTIONS                                        |

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Collect components from Quick Test preset or checkboxes          |

//|                                                                  |
//| Returns: Number of selected components                           |
//+------------------------------------------------------------------+
int CollectQuickTestComponents(ENUM_COMBO_COMPONENT_ITEM &components[]) {
    ArrayResize(components, 0);
    bool useSub = false, useTrigger = false, usePattern = false, useStructure = false;
    switch(inpQuickTestPreset) {
        case QUICK_PRESET_TRIGGER_PATTERN:
            useTrigger = true;
    usePattern = true;
    break;
    case QUICK_PRESET_ALL_4TF:
            useSub = true;
    useTrigger = true;
    usePattern = true;
    useStructure = true;
    break;
    case QUICK_PRESET_TRIGGER_PATTERN_STRUCTURE:
            useTrigger = true;
    usePattern = true;
    useStructure = true;
    break;
    case QUICK_PRESET_PATTERN_STRUCTURE:
            usePattern = true;
    useStructure = true;
    break;
    case QUICK_PRESET_TRIGGER_ONLY:
            useTrigger = true;
    break;
    default:
            _LOG_GATE_E Print("[E][DRAW] CollectQuickTestComponents: Unknown preset=", inpQuickTestPreset);
    return 0;
    }
    int maxComponents = 4;
    ArrayResize(components, maxComponents);
    int count = 0;
    if(useSub) {
        if(inpQuickTestStepType == COMBO_STEP_TH) components[count++] = COMP_SUB_TH;
    else if(inpQuickTestStepType == COMBO_STEP_SS) components[count++] = COMP_SUB_SS;
    else components[count++] = COMP_SUB_LS;
    }
    if(useTrigger) {
        if(inpQuickTestStepType == COMBO_STEP_TH) components[count++] = COMP_TRIGGER_TH;
    else if(inpQuickTestStepType == COMBO_STEP_SS) components[count++] = COMP_TRIGGER_SS;
    else components[count++] = COMP_TRIGGER_LS;
    }
    if(usePattern) {
        if(inpQuickTestStepType == COMBO_STEP_TH) components[count++] = COMP_PATTERN_TH;
    else if(inpQuickTestStepType == COMBO_STEP_SS) components[count++] = COMP_PATTERN_SS;
    else components[count++] = COMP_PATTERN_LS;
    }
    if(useStructure) {
        if(inpQuickTestStepType == COMBO_STEP_TH) components[count++] = COMP_STRUCTURE_TH;
    else if(inpQuickTestStepType == COMBO_STEP_SS) components[count++] = COMP_STRUCTURE_SS;
    else components[count++] = COMP_STRUCTURE_LS;
    }
    ArrayResize(components, count);
    #ifdef ENABLE_DEBUG_LOGS
    if(count > 0) {
        Print("[I][DRAW] CollectQuickTestComponents: Collected ", count, " components");
    for(int i = 0; i < count; i++) {
            Print("[D][DRAW]    [", i, "] = ", EnumToString(components[i]));
    }
    } else {
        Print("[E][DRAW] CollectQuickTestComponents: No components collected!");
    }
    #endif
    return count;
}

//+------------------------------------------------------------------+
//| Quick Test Mode Calculator                                       |

//|                                                                  |
//| Calculates step size based on selected checkboxes and mean type |
//+------------------------------------------------------------------+
double CalculateQuickTestStepSize(const double basePrice) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateQuickTestStepSize: Invalid basePrice=", basePrice);
    return 0;
    }
    ENUM_COMBO_COMPONENT_ITEM selectedComponents[];
    int componentCount = CollectQuickTestComponents(selectedComponents);
    if(componentCount == 0) {
        _LOG_GATE_E Print("[E][DRAW] Quick Test: No components selected");
    Alert("[WARN] QUICK TEST MODE ERROR\n\nNo components selected!\nPlease select at least one timeframe in Quick Test settings.");
    return 0;
    }
    double componentValues[];
    ArrayResize(componentValues, componentCount);
    for(int i = 0; i < componentCount; i++) {
        double val = GetStepSizeFromComponent(basePrice, selectedComponents[i]);
    if(val <= 0) {
            _LOG_GATE_E Print("[E][DRAW] Quick Test: Component ", selectedComponents[i], " returned invalid value");
    return 0;
        }
        
        componentValues[i] = val;
        _LOG_GATE_D Print("[D][DRAW]   Component[", i, "] = ", DoubleToString(val, Digits));
    }
    double result = CalculateMeanByType(componentValues, inpQuickTestMeanType);
    if(result <= 0) {
        _LOG_GATE_E Print("[E][DRAW] Quick Test: Mean calculation failed");
    return 0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    string meanTypeName = "";
    switch(inpQuickTestMeanType) {
        case MEAN_ARITHMETIC: meanTypeName = "Arithmetic"; break;
    case MEAN_GEOMETRIC: meanTypeName = "Geometric"; break;
    case MEAN_HARMONIC: meanTypeName = "Harmonic"; break;
    }
    Print("[I][DRAW] Quick Test [", meanTypeName, " Mean of ", componentCount, " components]: Result=",
    DoubleToString(result, Digits));
    #endif
    return NormalizeDouble(result, GetCachedDigits());
}

//+------------------------------------------------------------------+
//| Helper: Apply Combo Operator (Calculator Mode) - GOLDEN VERSION  |

//+------------------------------------------------------------------+
double ApplyCalculatorOperator(const double value1, const double value2, 
                          const ENUM_COMBO_OPERATOR op) {
        if(op == OP_NONE) return value1;
    switch(op) {
        case OP_PLUS: 
            return value1 + value2;
    case OP_MINUS: 
            return value1 - value2;
    case OP_MULTIPLY: 
            return value1 * value2;
    case OP_DIVIDE:            if(MathAbs(value2) < EPSILON_ANGLE) {
                _LOG_GATE_E Print("[E][DRAW] ApplyCalculatorOperator: Division by zero/near-zero detected! value2=", DoubleToString(value2, 8));
    return 0;            }
    return value1 / value2;
    case OP_AVERAGE:            return (value1 + value2) / 2.0;
    case OP_GEOMETRIC_MEAN:            if(value1 <= 0 || value2 <= 0) {
                _LOG_GATE_E Print("[E][DRAW] ApplyCalculatorOperator: Geometric mean requires positive values! value1=", value1, " value2=", value2);
    return 0;
            }
    return MathSqrt(value1 * value2);
    case OP_HARMONIC_MEAN: {
        if(MathAbs(value1) < EPSILON_ANGLE || MathAbs(value2) < EPSILON_ANGLE) {
                _LOG_GATE_E Print("[E][DRAW] ApplyCalculatorOperator: Harmonic mean requires non-zero values! value1=", value1, " value2=", value2);
    return 0;
            }
    double sum = value1 + value2;
    if(MathAbs(sum) < EPSILON_ANGLE) {
        return 0;
            }
            return (2.0 * value1 * value2) / sum;
        }
            
        default: 
            return value1;
    }
}
    double CalculateDualGroupTopology(const double basePrice) {
        if(inpComboComp1 == COMP_IGNORE) {
        _LOG_GATE_E Print("[E][DRAW] Calculator Mode (Dual): Component 1 cannot be IGNORE");
    Alert("[WARN] ADVANCED MODE ERROR (Dual Group Topology)\n\nComponent 1 cannot be IGNORE!\nDual Group topology requires at least Component 1.");
    return 0;
    }
    double valG1 = GetStepSizeFromComponent(basePrice, inpComboComp1);
    if(valG1 <= 0) {
        _LOG_GATE_E Print("[E][DRAW] Calculator Mode (Dual): Component 1 calculation failed");
    Alert("[WARN] ADVANCED MODE ERROR\n\nFailed to calculate Component 1.\nPlease check your component selection.");
    return 0;
    }
    valG1 = ApplyOperationWithComponent(valG1, inpComboOp1, inpComboComp2, basePrice);
    if(inpComboOp2 == OP_NONE || inpComboComp3 == COMP_IGNORE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[D][DRAW]  Dual Group: Only Group 1 active (Op2=NONE or Comp3=IGNORE)");
    Print("[D][DRAW]    Group 1 Result: ", DoubleToString(valG1, Digits));
    #endif
    return valG1;
    }
    double valG2 = GetStepSizeFromComponent(basePrice, inpComboComp3);
    if(valG2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] Dual Group: Component 3 invalid or failed");
    Print("[D][DRAW]    Component 3: ", EnumToString(inpComboComp3));
    Print("[D][DRAW]    Fallback: Using Group 1 result only");
        Print("[D][DRAW]    Group 1 Result: ", DoubleToString(valG1, Digits));
    #endif
        _LOG_GATE_W Print("[W][DRAW] DUAL GROUP TOPOLOGY WARNING: Component 3 (", EnumToString(inpComboComp3));
    return valG1;
    }
    valG2 = ApplyOperationWithComponent(valG2, inpComboOp3, inpComboComp4, basePrice);
    if(valG2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] Dual Group: Group 2 calculation failed after Op3");
    Print("[D][DRAW]    Op3: ", EnumToString(inpComboOp3));
    Print("[D][DRAW]    Component 4: ", EnumToString(inpComboComp4));
    Print("[D][DRAW]    Fallback: Using Group 1 result only");
    Print("[D][DRAW]    Group 1 Result: ", DoubleToString(valG1, Digits));
    Print("[E][DRAW] DUAL GROUP TOPOLOGY WARNING: Group 2 calculation failed. Using Group 1 result only.");
    #endif
    return valG1;
    }
    double finalResult = ApplyCalculatorOperator(valG1, valG2, inpComboOp2);
    if(finalResult <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] Dual Group: Final combination failed");
    Print("[D][DRAW]    Group 1: ", DoubleToString(valG1, Digits));
    Print("[D][DRAW]    Op2: ", EnumToString(inpComboOp2));
    Print("[D][DRAW]    Group 2: ", DoubleToString(valG2, Digits));
    Print("[D][DRAW]    Result: ", DoubleToString(finalResult, Digits));
    Print("[D][DRAW]    Fallback: Using Group 1 result only");
    Print("[W][DRAW] DUAL GROUP TOPOLOGY WARNING: Final combination (", EnumToString(inpComboOp2),
              ") produced invalid result. Using Group 1 result only.");
    #endif
    return valG1;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] Dual Group: SUCCESS");
    Print("[D][DRAW]    Group 1: ", DoubleToString(valG1, Digits));
    Print("[D][DRAW]    Op2: ", EnumToString(inpComboOp2));
    Print("[D][DRAW]    Group 2: ", DoubleToString(valG2, Digits));
    Print("[D][DRAW]    Final Result: ", DoubleToString(finalResult, Digits));
    #endif
    return finalResult;
}
    double ApplyOperationWithComponent(const double currentVal, 
                                  const ENUM_COMBO_OPERATOR op, 
                                  const ENUM_COMBO_COMPONENT_ITEM nextComp, 
                                  const double basePrice) {    if (op == OP_NONE || nextComp == COMP_IGNORE) {
        #ifdef ENABLE_DEBUG_LOGS
        if(op == OP_NONE) {
            Print("[W][DRAW]  ApplyOperationWithComponent: Operator is NONE, skipping");
        } else {
            Print("[W][DRAW]  ApplyOperationWithComponent: Component is IGNORE, skipping");
    }
    #endif
    return currentVal;
    }
    double nextVal = GetStepSizeFromComponent(basePrice, nextComp);
    if (nextVal <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] ApplyOperationWithComponent: Next component invalid");
    Print("[D][DRAW]    Component: ", EnumToString(nextComp));
    Print("[D][DRAW]    Operator: ", EnumToString(op));
    Print("[D][DRAW]    Keeping current value: ", DoubleToString(currentVal, Digits));
    Print("[W][DRAW] CALCULATOR WARNING: Component ", EnumToString(nextComp),
              " calculation failed. Skipping operation ", EnumToString(op));
    #endif
    return currentVal;
    }
    double result = ApplyCalculatorOperator(currentVal, nextVal, op);
    if (result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] ApplyOperationWithComponent: Operation produced invalid result");
    Print("[D][DRAW]    Current: ", DoubleToString(currentVal, Digits));
    Print("[D][DRAW]    Operator: ", EnumToString(op));
    Print("[D][DRAW]    Next: ", DoubleToString(nextVal, Digits));
    Print("[D][DRAW]    Result: ", DoubleToString(result, Digits));
    Print("[D][DRAW]    Fallback to current value");
    Print("[W][DRAW] CALCULATOR WARNING: Operation ", EnumToString(op),
              " produced invalid result. Keeping previous value.");
    #endif
    return currentVal;    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] ApplyOperationWithComponent: ", DoubleToString(currentVal, Digits),
          " ", EnumToString(op), " ", DoubleToString(nextVal, Digits), 
          " = ", DoubleToString(result, Digits));
    #endif
    return result;
}
    double CalculateLinearTopology(const double basePrice) {
        if(inpComboComp1 == COMP_IGNORE) {
        _LOG_GATE_E Print("[E][DRAW] Calculator Mode (Linear): Component 1 is IGNORE");
    Alert("[WARN] ADVANCED MODE ERROR (Linear Topology)\n\nComponent 1 cannot be IGNORE!\nLinear topology requires at least Component 1.");
    return 0;
    }
    double result = GetStepSizeFromComponent(basePrice, inpComboComp1);
    if(result <= 0) {
        _LOG_GATE_E Print("[E][DRAW] Calculator Mode (Linear): Component 1 calculation failed");
    Alert("[WARN] ADVANCED MODE ERROR\n\nFailed to calculate Component 1.\nPlease check your component selection.");
    return 0;
    }
    result = ApplyOperationWithComponent(result, inpComboOp1, inpComboComp2, basePrice);
    result = ApplyOperationWithComponent(result, inpComboOp2, inpComboComp3, basePrice);
    result = ApplyOperationWithComponent(result, inpComboOp3, inpComboComp4, basePrice);
    return result;
}

//+------------------------------------------------------------------+
//| Calculator Mode Logic (Unified Entry Point) - GOLDEN VERSION     |

//|                                                                  |
//| SUPPORTS:                                                        |
//| 1. N-ARY OPERATORS: If Op1 is N-ary, collects all components    |
//| 2. BINARY OPERATORS: Normal topology-based calculation          |
//+------------------------------------------------------------------+
double CalculateCalculatorModeStepSize(const double basePrice) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateCalculatorModeStepSize: Invalid basePrice=", basePrice);
    return 0;
    }
    if(inpComboOp1 >= OP_GEOMETRIC_MEAN_ALL && inpComboOp1 <= OP_MAX_ALL) {
        double componentValues[];
    ArrayResize(componentValues, 0);
    if(inpComboComp1 != COMP_IGNORE) {
        double val1 = GetStepSizeFromComponent(basePrice, inpComboComp1);
    if(val1 > 0) {
                ArrayResize(componentValues, ArraySize(componentValues) + 1);
    componentValues[ArraySize(componentValues) - 1] = val1;
            }
        }
    if(inpComboComp2 != COMP_IGNORE) {
        double val2 = GetStepSizeFromComponent(basePrice, inpComboComp2);
    if(val2 > 0) {
                ArrayResize(componentValues, ArraySize(componentValues) + 1);
    componentValues[ArraySize(componentValues) - 1] = val2;
            }
        }
    if(inpComboComp3 != COMP_IGNORE) {
        double val3 = GetStepSizeFromComponent(basePrice, inpComboComp3);
    if(val3 > 0) {
                ArrayResize(componentValues, ArraySize(componentValues) + 1);
    componentValues[ArraySize(componentValues) - 1] = val3;
            }
        }
    if(inpComboComp4 != COMP_IGNORE) {
        double val4 = GetStepSizeFromComponent(basePrice, inpComboComp4);
    if(val4 > 0) {
                ArrayResize(componentValues, ArraySize(componentValues) + 1);
    componentValues[ArraySize(componentValues) - 1] = val4;
            }
        }
    int componentCount = ArraySize(componentValues);
    if(componentCount == 0) {
            _LOG_GATE_E Print("[E][DRAW] N-ARY Mode: No valid components found");
    Alert("[WARN] ADVANCED MODE ERROR (N-ary Operator)\n\nAll components are set to IGNORE!\nPlease select at least one component.");
    return 0;
        }
    int expectedComponents = 0;
    if(inpComboComp1 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp2 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp3 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp4 != COMP_IGNORE) expectedComponents++;
    if(componentCount < expectedComponents) {
            _LOG_GATE_W Print("[W][DRAW] N-ARY Mode: Only ", componentCount, "/", expectedComponents, " components valid");
    Print(" N-ARY OPERATOR INFO: Using ", componentCount, " valid components out of ", 
                  expectedComponents, " selected.");
        }
    #ifdef ENABLE_DEBUG_LOGS
        Print("[D][DRAW]  N-ARY Mode: Collected ", componentCount, " valid components");
    for(int i = 0; i < componentCount; i++) {
            Print("[D][DRAW]    Component[", i, "] = ", DoubleToString(componentValues[i], Digits));
        }
    #endif
    double naryResult = 0;
    switch(inpComboOp1) {
            case OP_GEOMETRIC_MEAN_ALL:
                naryResult = CalculateGeometricMeanN(componentValues);
                _LOG_GATE_I Print("[I][DRAW] N-ARY Mode: Geometric Mean of ", componentCount, " components = ");
    break;
    case OP_ARITHMETIC_MEAN_ALL:
                naryResult = CalculateArithmeticMeanN(componentValues);
                _LOG_GATE_I Print("[I][DRAW] N-ARY Mode: Arithmetic Mean of ", componentCount, " components = ");
    break;
    case OP_HARMONIC_MEAN_ALL:
                naryResult = CalculateHarmonicMeanN(componentValues);
                _LOG_GATE_I Print("[I][DRAW] N-ARY Mode: Harmonic Mean of ", componentCount, " components = ");
    break;
    case OP_MIN_ALL:
                naryResult = CalculateMinN(componentValues);
                _LOG_GATE_I Print("[I][DRAW] N-ARY Mode: Minimum of ", componentCount, " components = ");
    break;
    case OP_MAX_ALL:
                naryResult = CalculateMaxN(componentValues);
                _LOG_GATE_I Print("[I][DRAW] N-ARY Mode: Maximum of ", componentCount, " components = ");
    break;
    default:
                _LOG_GATE_E Print("[E][DRAW] N-ARY Mode: Unknown operator ", inpComboOp1);
    return 0;
        }
    if(naryResult <= 0) {
            _LOG_GATE_E Print("[E][DRAW] N-ARY Mode: Result is <= 0");
    return 0;
        }
    return NormalizeDouble(naryResult, GetCachedDigits());
    }
    double finalResult = 0;
    if(inpComboTopology == TOPOLOGY_LINEAR) {
        finalResult = CalculateLinearTopology(basePrice);
    }
    else {
        finalResult = CalculateDualGroupTopology(basePrice);
    }
    if(finalResult <= 0) {
        _LOG_GATE_E Print("[E][DRAW] Calculator Mode Result is <= 0");
    return 0;
    }
    finalResult = NormalizeDouble(finalResult, GetCachedDigits());
    _LOG_GATE_I Print("[I][DRAW] Calculator Mode [", EnumToString(inpComboTopology), "]: Result=", DoubleToString(finalResult, GetCachedDigits()));
    return finalResult;
}

//+------------------------------------------------------------------+
//| UNIFIED Combo Step Calculation (used by both modes)              |

//|                                                                  |
//| Used by:                                                         |
//| 1. Combo Step Mode (COMBO_STEP) - for drawing TH levels         |
//| 2. Factor Auto Basis = COMBO - for calculating Factor           |
//|                                                                  |
//| @param basePrice Base price for TH calculation (must be > 0)    |
//| @return Calculated combo step size (> 0), or 0 on error         |
//|                                                                  |
//| Single source of truth, no code duplication       |
//| - Full input validation                                         |
//| - Comprehensive error handling                                  |
//| - Thread-safe (no global state modification)                    |
//| - Performance optimized with early returns                      |
//| - NOW SUPPORTS TRIPLE PRESETS! [OK]                                |
//| - NOW SUPPORTS QUICK TEST MODE! [FAST]                               |
//+------------------------------------------------------------------+

// Validate a combo parameter, logging and alerting on failure. Returns false if invalid.
bool ValidateComboParam(bool isInvalid, const string paramName, const string paramValue, const string context = "PRESET MODE") {
    if(!isInvalid) return true;
    _LOG_GATE_E Print("[E][DRAW] CalculateComboStepSize: Invalid ", paramName, "=", paramValue);
    Alert("[WARN] ", context, " ERROR\n\nInvalid ", paramName, " configuration!\nPreset: ", EnumToString(inpComboPreset));
    return false;
}

double CalculateComboStepSize(const double basePrice) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] CalculateComboStepSize: Invalid basePrice=", basePrice);
    Alert("[WARN] COMBO MODE ERROR\n\nInvalid base price for calculation.\nPlease check your settings.");
    return 0;
    }
    if(inpComboMode == COMBO_MODE_QUICK_TEST) {
        _LOG_GATE_I Print("[I][DRAW] CalculateComboStepSize: QUICK TEST mode detected");
    return CalculateQuickTestStepSize(basePrice);
    }
    if(inpComboMode == COMBO_MODE_ADVANCED) {
        _LOG_GATE_I Print("[I][DRAW] CalculateComboStepSize: ADVANCED (CALCULATOR) mode detected");
    return CalculateCalculatorModeStepSize(basePrice);
    }
    if(inpComboMode != COMBO_MODE_PRESET) {
        _LOG_GATE_E Print("[E][DRAW] CalculateComboStepSize: Invalid mode=", inpComboMode, " (expected PRESET)");
    Alert("[WARN] COMBO MODE ERROR\n\nInvalid Combo Mode configuration!\nExpected: Preset Mode\nActual: ", EnumToString(inpComboMode));
    return 0;
    }
    // Triple presets: all share same TF/step params, differ only in operation
    if(inpComboPreset == COMBO_PRESET_BALANCED_TRIPLE ||
       inpComboPreset == COMBO_PRESET_TRIPLE_CONSERVATIVE ||
       inpComboPreset == COMBO_PRESET_TRIPLE_AGGRESSIVE) {
        ENUM_COMBO_OPERATION tripleOp = (inpComboPreset == COMBO_PRESET_BALANCED_TRIPLE)   ? COMBO_OP_AVERAGE :
                                        (inpComboPreset == COMBO_PRESET_TRIPLE_CONSERVATIVE) ? COMBO_OP_MAX     :
                                                                                               COMBO_OP_MIN;
        return CalculateTripleComboStepSize(basePrice,
            COMBO_TF_TRIGGER, COMBO_STEP_TH,
            COMBO_TF_PATTERN, COMBO_STEP_TH,
            COMBO_TF_STRUCTURE, COMBO_STEP_TH,
            tripleOp);
    }
    else if(inpComboPreset == COMBO_PRESET_MANUAL_TRIPLE) {
        _LOG_GATE_D Print("[D][DRAW]  MANUAL_TRIPLE preset detected -> Redirecting to Advanced Mode");
    return CalculateCalculatorModeStepSize(basePrice);
    }
    else if(inpComboPreset == COMBO_PRESET_MANUAL_DUAL) {
        _LOG_GATE_D Print("[D][DRAW]  MANUAL_DUAL preset detected -> Redirecting to Advanced Mode");
    return CalculateCalculatorModeStepSize(basePrice);
    }    
    ENUM_COMBO_TIMEFRAME_TYPE tf1, tf2;
    ENUM_COMBO_STEP_TYPE step1Type, step2Type;
    ENUM_COMBO_OPERATION operation;
    GetPresetConfiguration(inpComboPreset, tf1, step1Type, tf2, step2Type, operation);
    if(!ValidateComboParam(tf1 < COMBO_TF_SUB || tf1 > COMBO_TF_STRUCTURE, "tf1", IntegerToString(tf1))) return 0;
    if(!ValidateComboParam(tf2 < COMBO_TF_SUB || tf2 > COMBO_TF_STRUCTURE, "tf2", IntegerToString(tf2))) return 0;
    if(!ValidateComboParam(step1Type < COMBO_STEP_TH || step1Type > COMBO_STEP_LS, "step1Type", IntegerToString(step1Type))) return 0;
    if(!ValidateComboParam(step2Type < COMBO_STEP_TH || step2Type > COMBO_STEP_LS, "step2Type", IntegerToString(step2Type))) return 0;
    if(!ValidateComboParam(operation < COMBO_OP_AVERAGE || operation > COMBO_OP_WEIGHTED, "operation", IntegerToString(operation))) return 0;
    ENUM_TIMEFRAMES timeframe1 = GetTimeframeByType(tf1);
    ENUM_TIMEFRAMES timeframe2 = GetTimeframeByType(tf2);
    if(!ValidateComboParam(timeframe1 <= 0, "timeframe1", EnumToString(tf1))) return 0;
    if(!ValidateComboParam(timeframe2 <= 0, "timeframe2", EnumToString(tf2))) return 0;
    double multiplier1 = GetStepMultiplier(step1Type);
    double multiplier2 = GetStepMultiplier(step2Type);
    if(!ValidateComboParam(multiplier1 <= 0 || multiplier1 > 10.0, "multiplier1", DoubleToString(multiplier1, 2))) return 0;
    if(!ValidateComboParam(multiplier2 <= 0 || multiplier2 > 10.0, "multiplier2", DoubleToString(multiplier2, 2))) return 0;
    double step1 = GetStepSizeForBasisType(basePrice, multiplier1, timeframe1);
    double step2 = GetStepSizeForBasisType(basePrice, multiplier2, timeframe2);
    if(!ValidateComboParam(step1 <= 0, "step1", DoubleToString(step1, GetCachedDigits()))) return 0;
    if(!ValidateComboParam(step2 <= 0, "step2", DoubleToString(step2, GetCachedDigits()))) return 0;
    double comboStep = ApplyComboOperation(step1, step2, operation, 
                                           0.5, 0.5);
    if(!ValidateComboParam(comboStep <= 0, "comboStep", DoubleToString(comboStep, GetCachedDigits()))) return 0;
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] CalculateComboStepSize: SUCCESS");
    Print("[D][DRAW]    Preset=", EnumToString(inpComboPreset));
    Print("[D][DRAW]    TF1=", EnumToString(tf1), " (", timeframe1, "), Step1Type=", EnumToString(step1Type),
          " (Ã—", multiplier1, "), Value=", DoubleToString(step1, Digits));
    Print("[D][DRAW]    TF2=", EnumToString(tf2), " (", timeframe2, "), Step2Type=", EnumToString(step2Type),
          " (Ã—", multiplier2, "), Value=", DoubleToString(step2, Digits));
    Print("[D][DRAW]    Operation=", EnumToString(operation), ", Result=", DoubleToString(comboStep, Digits));
    #endif
    return comboStep;
}
    double GetComboStepSizeForFactor(const double basePrice) {
        return CalculateComboStepSize(basePrice);
}
    double GetStepSizeForSharedComponent(const double basePrice, 
                                      const ENUM_COMBO_COMPONENT_ITEM component) {
        if(basePrice <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepSizeForSharedComponent: Invalid basePrice=", basePrice);
    return 0;
    }
    
    ENUM_TIMEFRAMES timeframe;
    double multiplier;
    // Step type suffix determines multiplier: TH=1.0, SS=1.5, LS=2.0
    static const double stepMultipliers[3] = {1.0, 1.5, 2.0};
    switch(component) {        case COMP_SUB_TH:
        case COMP_SUB_SS:
        case COMP_SUB_LS:
        {
        int currentMinutes = PeriodMinutes();
    int subMinutes = currentMinutes / 16;
    if(subMinutes < 1) subMinutes = 1;
    if(subMinutes <= 1) timeframe = PERIOD_M1;
    else if(subMinutes <= 5) timeframe = PERIOD_M5;
    else if(subMinutes <= 15) timeframe = PERIOD_M15;
    else if(subMinutes <= 30) timeframe = PERIOD_M30;
    else if(subMinutes <= 60) timeframe = PERIOD_H1;
    else if(subMinutes <= 360) timeframe = PERIOD_H4;
    else if(subMinutes <= 1440) timeframe = PERIOD_D1;
    else if(subMinutes <= 10080) timeframe = PERIOD_W1;
    else timeframe = PERIOD_MN1;
    multiplier = stepMultipliers[component - COMP_SUB_TH];
    break;
        }
    case COMP_TRIGGER_TH:
    case COMP_TRIGGER_SS:
    case COMP_TRIGGER_LS:
            timeframe = GetSubTimeframe();
    multiplier = stepMultipliers[component - COMP_TRIGGER_TH];
    break;
    case COMP_PATTERN_TH:
    case COMP_PATTERN_SS:
    case COMP_PATTERN_LS:
            timeframe = (ENUM_TIMEFRAMES)GetCachedPeriod();
    multiplier = stepMultipliers[component - COMP_PATTERN_TH];
    break;
    case COMP_STRUCTURE_TH:
    case COMP_STRUCTURE_SS:
    case COMP_STRUCTURE_LS:
            timeframe = GetPatternTimeframe();
    multiplier = stepMultipliers[component - COMP_STRUCTURE_TH];
    break;
    default:
            return 0;
    }
    return GetStepSizeForBasisType(basePrice, multiplier, timeframe);
}
    bool IsTriggerLevelsEnabled() {
        return g_triggerLevelsEnabled;
}

//+------------------------------------------------------------------+
//| Get current timeframe as fractal string                          |

//+------------------------------------------------------------------+
string GetCurrentFractalTimeframe() {
        int minutes = PeriodMinutes();
    return MinutesToFractalString(minutes);
}

//+------------------------------------------------------------------+
//| Get TH percentage for specific timeframe period                  |

//| FIXED: No recursion, proper error handling                       |
//+------------------------------------------------------------------+
double GetTimeframeTHForPeriod(const ENUM_TIMEFRAMES period) {
        if(period == PERIOD_CURRENT || period == 0) {
        string currentFractal = GetCurrentFractalTimeframe();
    double th = CalculateTimeframeTH(currentFractal);
        _LOG_GATE_D Print("[D][DRAW] GetTimeframeTHForPeriod: CURRENT (", Period(), "min) -> ");
    return th;
    }
    int minutes = 0;
    switch(period) {
        case PERIOD_M1:  minutes = 1; break;
    case PERIOD_M5:  minutes = 5; break;
    case PERIOD_M15: minutes = 15; break;
    case PERIOD_M30: minutes = 30; break;
    case PERIOD_H1:  minutes = 60; break;
    case PERIOD_H4:  minutes = 240; break;
    case PERIOD_D1:  minutes = 1440; break;
    case PERIOD_W1:  minutes = 10080; break;
    case PERIOD_MN1: minutes = 43200; break;
    default: {
        int seconds = PeriodSeconds(period);
    if(seconds > 0) {
                minutes = seconds / 60;
            } else {
                _LOG_GATE_W Print("[W][DRAW] GetTimeframeTHForPeriod: Unknown period=", period, ", using D45+H12+M16");
    return CalculateTimeframeTH("D45+H12+M16");
            }
            break;
        }
    }
    string timeframeStr = MinutesToFractalString(minutes);
    double th = CalculateTimeframeTH(timeframeStr);
    _LOG_GATE_D Print("[D][DRAW] GetTimeframeTHForPeriod: ", period, " (", minutes, "min) -> ");
    return th;
}

//+------------------------------------------------------------------+
//| Get Sub timeframe (1/4 current - faster than current)            |

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetSubTimeframe() {
        int currentMinutes = PeriodMinutes();
    int subMinutes = currentMinutes / 4;
    if(subMinutes < 1) subMinutes = 1;
    ENUM_TIMEFRAMES result = MinutesToTimeframe(subMinutes);
    DEBUG_PRINTF3("GetSubTimeframe: Current=", currentMinutes, "min, Sub=", subMinutes);
    return result;
}

//+------------------------------------------------------------------+
//| Get timeframe based on type                                       |

//| Added validation and error logging                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframeByType(const ENUM_COMBO_TIMEFRAME_TYPE tfType) {
        if(tfType < COMBO_TF_SUB || tfType > COMBO_TF_STRUCTURE) {
        _LOG_GATE_E Print("[E][DRAW] GetTimeframeByType: Invalid tfType=", tfType, ", using current period");
    return (ENUM_TIMEFRAMES)GetCachedPeriod();    }
    
    ENUM_TIMEFRAMES result;
    switch(tfType) {
        case COMBO_TF_SUB:            {
        int currentMinutes = PeriodMinutes();
    int subMinutes = currentMinutes / 16;
    if(subMinutes < 1) subMinutes = 1;
    result = MinutesToTimeframe(subMinutes);
            }
            break;
    case COMBO_TF_TRIGGER:            result = GetSubTimeframe();
    break;
    case COMBO_TF_PATTERN:            result = (ENUM_TIMEFRAMES)GetCachedPeriod();
    break;
    case COMBO_TF_STRUCTURE:            result = GetPatternTimeframe();
    break;
    default:
            _LOG_GATE_W Print("[W][DRAW] GetTimeframeByType: Unexpected tfType=", tfType, ", using current period");
    result = (ENUM_TIMEFRAMES)GetCachedPeriod();
    break;
    }
    if(result <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetTimeframeByType: Invalid result=", result, " for tfType=", tfType);
    return (ENUM_TIMEFRAMES)GetCachedPeriod();    }
    return result;
}

//+------------------------------------------------------------------+
//| Get step multiplier based on step type                           |

//| Added validation and error logging                     |
//+------------------------------------------------------------------+
double GetStepMultiplier(const ENUM_COMBO_STEP_TYPE stepType) {
        if(stepType < COMBO_STEP_TH || stepType > COMBO_STEP_LS) {
        _LOG_GATE_E Print("[E][DRAW] GetStepMultiplier: Invalid stepType=", stepType, ", using 1.0 (TH)");
    return 1.0;
    }
    double multiplier;
    switch(stepType) {
        case COMBO_STEP_TH:
            multiplier = 1.0;
    break;
    case COMBO_STEP_SS:
            multiplier = 1.5;
    break;
    case COMBO_STEP_LS:
            multiplier = 2.0;
    break;
    default:
            _LOG_GATE_W Print("[W][DRAW] GetStepMultiplier: Unexpected stepType=", stepType, ", using 1.0 (TH)");
    multiplier = 1.0;
    break;
    }
    if(multiplier <= 0 || multiplier > 10.0) {
        _LOG_GATE_E Print("[E][DRAW] GetStepMultiplier: Invalid multiplier=", multiplier, " for stepType=", stepType);
    return 1.0;
    }
    return multiplier;
}

//+------------------------------------------------------------------+
//| Apply operation on two values ()                     |

//|                                                                  |
//| @param value1 First value (must be > 0)                         |
//| @param value2 Second value (must be > 0)                        |
//| @param operation Operation type to apply                        |
//| @param weight1 Weight for value1 (0.0-1.0, for WEIGHTED only)   |
//| @param weight2 Weight for value2 (0.0-1.0, for WEIGHTED only)   |
//| @return Result of operation (> 0), or 0 on error                |
//|                                                                  |
//| FIXES:                                                           |
//| - Normalized weighted operation (handles any weight sum)        |
//| - Comprehensive validation                                      |
//| - Better error messages                                         |
//+------------------------------------------------------------------+
double ApplyComboOperation(const double value1, const double value2, 
                           const ENUM_COMBO_OPERATION operation,
                           const double weight1 = 0.5, const double weight2 = 0.5) {
        if(value1 <= 0 || value2 <= 0) {
        _LOG_GATE_E Print("[E][DRAW] ApplyComboOperation: Invalid values - v1=", value1, ", v2=", value2);
    return 0;
    }
    double result = 0;
    switch(operation) {
        case COMBO_OP_AVERAGE:            result = (value1 + value2) / 2.0;
    break;
    case COMBO_OP_ADD:            result = value1 + value2;
    break;
    case COMBO_OP_SUBTRACT: {            result = MathAbs(value1 - value2);
    double avgValue = (value1 + value2) / 2.0;
    double minThreshold = avgValue * 0.01;
    if(result < minThreshold) {
                result = avgValue;
    #ifdef ENABLE_DEBUG_LOGS
                Print("[W][DRAW] ApplyComboOperation: Subtract result too small (",
                      DoubleToString(result, Digits), " < ", DoubleToString(minThreshold, Digits), 
                      "), using average=", DoubleToString(avgValue, Digits));
    #endif
    }
            break;
        }
            
        case COMBO_OP_MULTIPLY: {            result = value1 * value2;
    double maxInput = MathMax(value1, value2);
    double overflowThreshold = maxInput * 100.0;
    if(result > overflowThreshold) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("[W][DRAW] ApplyComboOperation: Multiply overflow detected");
    Print("[D][DRAW]    v1=", DoubleToString(value1, Digits),
                      ", v2=", DoubleToString(value2, Digits), 
                      ", result=", DoubleToString(result, Digits), 
                      " > threshold=", DoubleToString(overflowThreshold, Digits));
                Print("[D][DRAW]    Clamping to max input=", DoubleToString(maxInput, Digits));
    #endif
                result = maxInput;
            }
            break;
        }
            
        case COMBO_OP_MIN:            result = MathMin(value1, value2);
    break;
    case COMBO_OP_MAX:            result = MathMax(value1, value2);
    break;
    case COMBO_OP_WEIGHTED: {
        if(weight1 < 0 || weight2 < 0) {
                _LOG_GATE_E Print("[E][DRAW] ApplyComboOperation: Negative weights - w1=", weight1, ", w2=", weight2);
    result = (value1 + value2) / 2.0;
    break;
            }
    double weightSum = weight1 + weight2;
    if(weightSum <= 0) {
                _LOG_GATE_E Print("[E][DRAW] ApplyComboOperation: Zero weight sum - w1=", weight1, ", w2=", weight2);
    result = (value1 + value2) / 2.0;
    break;
            }
    result = (value1 * weight1 + value2 * weight2) / weightSum;
            _LOG_GATE_I Print("[I][DRAW] ApplyComboOperation: Weighted - w1=", weight1, ", w2=", weight2);
    break;
        }
            
        default:
            _LOG_GATE_E Print("[E][DRAW] ApplyComboOperation: Unknown operation=", operation);
    result = (value1 + value2) / 2.0;
    break;
    }
    if(result <= 0) {
        _LOG_GATE_E Print("[E][DRAW] ApplyComboOperation: Invalid result=", result);
    return 0;
    }
    double maxInput = MathMax(value1, value2);
    double minInput = MathMin(value1, value2);
    bool isSuspicious = false;
    switch(operation) {
        case COMBO_OP_ADD:            if(result > maxInput * 2.5) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_MULTIPLY:            if(result > maxInput * 100) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_AVERAGE:
        case COMBO_OP_WEIGHTED:            if(result < minInput * 0.5 || result > maxInput * 1.5) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_SUBTRACT:            if(result > maxInput) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_MIN:            if(result != minInput) {
                isSuspicious = true;
            }
            break;
    case COMBO_OP_MAX:            if(result != maxInput) {
                isSuspicious = true;
            }
            break;
    }
    if(isSuspicious) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[W][DRAW] ApplyComboOperation: Suspicious result detected");
    Print("[D][DRAW]    Operation=", EnumToString(operation));
    Print("[D][DRAW]    v1=", DoubleToString(value1, Digits),
              ", v2=", DoubleToString(value2, Digits));
    Print("[D][DRAW]    Result=", DoubleToString(result, Digits),
              " (min=", DoubleToString(minInput, Digits), 
              ", max=", DoubleToString(maxInput, Digits), ")");
    Print("[D][DRAW]    Using fallback: average");
    #endif
    result = (value1 + value2) / 2.0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] ApplyComboOperation: v1=", DoubleToString(value1, Digits),
          ", v2=", DoubleToString(value2, Digits), 
          ", op=", EnumToString(operation), 
          ", result=", DoubleToString(result, Digits));
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Get preset configuration (OPTIMIZED VERSION with all presets)    |

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get preset configuration (UNIFIED VERSION with Mode support)    |

//|                                                                  |
//| Supports two modes:                                             |
//| 1. PRESET Mode: Quick select from 9 ready-to-use presets       |
//| 2. MANUAL Mode: Full control over all parameters               |
//|                                                                  |
//| @param preset Preset selection (used in PRESET mode)           |
//| @param tf1 Output: Timeframe 1                                 |
//| @param step1 Output: Step type 1                               |
//| @param tf2 Output: Timeframe 2                                 |
//| @param step2 Output: Step type 2                               |
//| @param operation Output: Operation type                        |
//+------------------------------------------------------------------+
void GetPresetConfiguration(const ENUM_COMBO_PRESET preset,
                            ENUM_COMBO_TIMEFRAME_TYPE &tf1,
                            ENUM_COMBO_STEP_TYPE &step1,
                            ENUM_COMBO_TIMEFRAME_TYPE &tf2,
                            ENUM_COMBO_STEP_TYPE &step2,
                            ENUM_COMBO_OPERATION &operation) {    tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_AVERAGE;
    switch(preset) {        
        case COMBO_PRESET_LEGACY_ADD:            tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_SS;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_SS;
    operation = COMBO_OP_ADD;
    break;
    case COMBO_PRESET_BALANCED_MEDIUM:            
            tf1 = COMBO_TF_PATTERN;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_TRIGGER;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_AVERAGE;
    break;
    case COMBO_PRESET_BALANCED_LONG:            
            tf1 = COMBO_TF_STRUCTURE;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_AVERAGE;
    break;
    case COMBO_PRESET_BALANCED_TRIPLE:            tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_AVERAGE;
    break;
    case COMBO_PRESET_BALANCED_MIN:            tf1 = COMBO_TF_PATTERN;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_TRIGGER;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MIN;
    break;
    case COMBO_PRESET_CONSERVATIVE:            
            tf1 = COMBO_TF_STRUCTURE;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MAX;
    break;
    case COMBO_PRESET_ULTRA_CONSERVATIVE:            
            
            
            tf1 = COMBO_TF_STRUCTURE;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_STRUCTURE;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MAX;
    break;
    case COMBO_PRESET_TRIPLE_CONSERVATIVE:            tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MAX;
    break;
    case COMBO_PRESET_AGGRESSIVE:            
            tf1 = COMBO_TF_PATTERN;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_TRIGGER;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MIN;
    break;
    case COMBO_PRESET_ULTRA_AGGRESSIVE:            
            tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_SUB;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MIN;
    break;
    case COMBO_PRESET_TRIPLE_AGGRESSIVE:            tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_MIN;
    break;
    case COMBO_PRESET_TREND_FILTER:            
            tf1 = COMBO_TF_STRUCTURE;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_SUB;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_SUBTRACT;
    break;
    case COMBO_PRESET_VOLATILITY_ADAPTIVE:            
            tf1 = COMBO_TF_STRUCTURE;
    step1 = COMBO_STEP_TH;
    tf2 = COMBO_TF_SUB;
    step2 = COMBO_STEP_TH;
    operation = COMBO_OP_AVERAGE;
    break;
    case COMBO_PRESET_MANUAL_DUAL:
        case COMBO_PRESET_MANUAL_TRIPLE:            {
                ENUM_COMBO_TIMEFRAME_TYPE t1, t2;
    ENUM_COMBO_STEP_TYPE s1, s2;
    bool valid = GetComboComponentParams(inpComboComp1, t1, s1) && 
                             GetComboComponentParams(inpComboComp2, t2, s2);
    if (valid) {
                    tf1 = t1; step1 = s1;
    tf2 = t2; step2 = s2;
                } else {                    tf1 = COMBO_TF_TRIGGER; step1 = COMBO_STEP_SS;
    tf2 = COMBO_TF_PATTERN; step2 = COMBO_STEP_SS;
                }
    operation = COMBO_OP_ADD; 
            }
            break;
    default:
            _LOG_GATE_W Print("[W][DRAW] GetPresetConfiguration: Unknown preset=", preset, ", using Legacy");
    tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_SS;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_SS;
    operation = COMBO_OP_ADD;
    break;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[I][DRAW] GetPresetConfiguration: PRESET MODE - Preset=", EnumToString(preset));
    Print("[D][DRAW]    TF1=", EnumToString(tf1), ", Step1=", EnumToString(step1));
    Print("[D][DRAW]    TF2=", EnumToString(tf2), ", Step2=", EnumToString(step2));
    Print("[D][DRAW]    Operation=", EnumToString(operation));
    #endif
}
ENUM_TIMEFRAMES GetPatternTimeframe() {
        int currentMinutes = PeriodMinutes();
    int patternMinutes = currentMinutes * 4;
    if(patternMinutes > 43200) patternMinutes = 43200;
    ENUM_TIMEFRAMES result = MinutesToTimeframe(patternMinutes);
    DEBUG_PRINTF3("GetPatternTimeframe: Current=", currentMinutes, "min -> ", patternMinutes);
    return result;
}

//+------------------------------------------------------------------+
//| Get Structure timeframe (16x current)                            |

//| FIXED: Proper bounds checking and logging                        |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetStructureTimeframe() {
        int currentMinutes = PeriodMinutes();
    int structureMinutes = currentMinutes * 16;
    if(structureMinutes > 43200) structureMinutes = 43200;
    ENUM_TIMEFRAMES result = MinutesToTimeframe(structureMinutes);
    DEBUG_PRINTF3("GetStructureTimeframe: Current=", currentMinutes, "min -> ", structureMinutes);
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Structure level interval based on base multiplier     |

//|                                                                  |
//| EXAMPLES:                                                        |
//| NEW FORMULA: L(n) = base Ã— 2^(n-1)  [Fractal 2Ã— ratio]         |
//| Base=2: L1=2, L2=4, L3=8, L4=16, L5=32                          |
//| Base=3: L1=3, L2=6, L3=12, L4=24, L5=48                         |
//| Base=4: L1=4, L2=8, L3=16, L4=32, L5=64                         |
//| Base=9: L1=9, L2=18, L3=36, L4=72, L5=144                       |
//|                                                                  |
//| This ensures:                                                    |
//| 1. L(n+1)/L(n) = 2 always (fractal ratio preserved)            |
//| 2. All L1-L5 are reachable within maxLevels=144                 |
//| 3. base sets the L1 starting point, not exponential growth      |
//|                                                                  |
//| USAGE:                                                           |
//| Check from HIGHEST to LOWEST level for proper hierarchy:        |
//| if(step % L5 == 0) -> Level 5                                    |
//| else if(step % L4 == 0) -> Level 4                               |
//| else if(step % L3 == 0) -> Level 3                               |
//| else if(step % L2 == 0) -> Level 2                               |
//| else if(step % L1 == 0) -> Level 1                               |
//| else -> Trigger                                                   |
//+------------------------------------------------------------------+
int CalculateStructureInterval(const int baseMultiplier, const int level) {
        if(baseMultiplier < 2 || baseMultiplier > 9) {
        _LOG_GATE_E Print("[E][DRAW] Invalid base multiplier: ", baseMultiplier, " (must be 2-9)");
    return 0;
    }
    if(level < 1 || level > 5) {
        _LOG_GATE_E Print("[E][DRAW] Invalid level: ", level, " (must be 1-5)");
    return 0;
    }
    // NEW: base Ã— 2^(level-1) instead of base^level
    // This preserves the fractal 2Ã— ratio: L(n+1)/L(n) = 2
    // And ensures all L1-L5 are always reachable within maxLevels
    return baseMultiplier * (int)MathPow(2, level - 1);
}

//+------------------------------------------------------------------+
//| Get validated base multiplier with auto-correction               |

//|                                                                  |
//| This function ensures baseMultiplier is always in valid range    |
//| If invalid value is detected, auto-corrects to default (3)      |
//|                                                                  |
//| @return Valid base multiplier (2-9, default: 3)                 |
//+------------------------------------------------------------------+
int GetValidatedBaseMultiplier() {
        int baseMultiplier = (int)inpStructureBase;
    if(baseMultiplier < 2 || baseMultiplier > 9) {
        _LOG_GATE_E Print("[E][DRAW] GetValidatedBaseMultiplier: Invalid value ", baseMultiplier);
    return 3;    }
    return baseMultiplier;
}


//+------------------------------------------------------------------+
//| Cache for structure intervals to avoid repeated MathPow() calls |

//+------------------------------------------------------------------+
static int g_cachedBaseMultiplier = -1;
    static int g_cachedIntervals[5];
    
    // PERF: Ensure intervals cache is valid without copying to a local array
    void EnsureIntervalsCache(const int baseMultiplier) {
        int validatedMultiplier = baseMultiplier;
        if(validatedMultiplier < 2 || validatedMultiplier > 9)
            validatedMultiplier = 3;
        if(g_cachedBaseMultiplier != validatedMultiplier) {
            for(int i = 0; i < 5; i++)
                g_cachedIntervals[i] = CalculateStructureInterval(validatedMultiplier, i + 1);
            g_cachedBaseMultiplier = validatedMultiplier;
        }
    }
    
    void GetCachedIntervals(const int baseMultiplier, int &intervals[]) {
        EnsureIntervalsCache(baseMultiplier);
    // PERF: Skip ArrayResize when caller's array is already correct size
    if(ArraySize(intervals) != 5) {
        ArrayResize(intervals, 5);
    }
    for(int i = 0; i < 5; i++) {
        intervals[i] = g_cachedIntervals[i];
    }
}

//+------------------------------------------------------------------+
//| Get highest structure level for a given step                     |

//|                                                                  |
//| Returns the highest level (1-5) that this step belongs to       |
//| Returns 0 if step is not a structure level (i.e., trigger)      |
//|                                                                  |
//| EXAMPLES with Base=4 (L1=4, L2=8, L3=16, L4=32, L5=64):       |
//| Step 4:  Returns 1 (L1 only)                                    |
//| Step 8:  Returns 2 (L2, not L1)                                 |
//| Step 16: Returns 3 (L3, not L2 or L1)                           |
//| Step 64: Returns 5 (L5)                                         |
//| Step 5:  Returns 0 (Trigger, not Structure)                     |
//|                                                                  |
//| SECURITY: Full input validation with safe defaults              |
//|                                                                  |
//| @param step The step number to check                            |
//| @param intervals Array of structure intervals [L1, L2, L3, L4, L5] |
//| @return Highest level (1-5) or 0 if trigger/invalid             |
//+------------------------------------------------------------------+
int GetHighestStructureLevel(const int step, const int &intervals[]) {
        if(step == 0) return 0;
    int absStep = MathAbs(step);
    if(absStep <= 0) {
        _LOG_GATE_E Print("[E][DRAW] GetHighestStructureLevel: Invalid step=", step);
    return 0;
    }
    int arraySize = ArraySize(intervals);
    if(arraySize != 5) {
        _LOG_GATE_E Print("[E][DRAW] GetHighestStructureLevel: Invalid intervals array size=", arraySize, " (expected 5)");
    return 0;
    }
    for(int i = 0; i < 5; i++) {
        if(intervals[i] <= 0) {
            _LOG_GATE_E Print("[E][DRAW] GetHighestStructureLevel: Invalid interval[", i, "]=", intervals[i]);
    return 0;
        }
    if(i > 0 && intervals[i] <= intervals[i-1]) {
            _LOG_GATE_E Print("[E][DRAW] GetHighestStructureLevel: Intervals not in ascending order at index ", i);
    return 0;
        }
    }
    if(absStep % intervals[4] == 0) return 5;
    if(absStep % intervals[3] == 0) return 4;
    if(absStep % intervals[2] == 0) return 3;
    if(absStep % intervals[1] == 0) return 2;
    if(absStep % intervals[0] == 0) return 1;
    return 0;}
    bool GetPathForLevelOptimized(const int stepCount, color &outColor, ENUM_LINE_STYLE &outStyle, int &outWidth, const bool triggerEnabled) {
        // PERF: Compute intervals once and reuse for both structure and trigger checks
        bool isStructureLevel = false;
        if(inpShowStructure) {
        // PERF: Use g_cachedIntervals directly â€” no local array alloc or copy
        int baseMultiplier = GetValidatedBaseMultiplier();
    EnsureIntervalsCache(baseMultiplier);
    if(g_cachedIntervals[4] > 0 && stepCount % g_cachedIntervals[4] == 0 && inpShowStructureL5) {
            outColor = inpStructureL5Color;
    outStyle = inpStructureL5Style;
    outWidth = inpStructureL5Width;
    return true;
        }
    if(g_cachedIntervals[3] > 0 && stepCount % g_cachedIntervals[3] == 0 && inpShowStructureL4) {
            outColor = inpStructureL4Color;
    outStyle = inpStructureL4Style;
    outWidth = inpStructureL4Width;
    return true;
        }
    if(g_cachedIntervals[2] > 0 && stepCount % g_cachedIntervals[2] == 0 && inpShowStructureL3) {
            outColor = inpStructureL3Color;
    outStyle = inpStructureL3Style;
    outWidth = inpStructureL3Width;
    return true;
        }
    if(g_cachedIntervals[1] > 0 && stepCount % g_cachedIntervals[1] == 0 && inpShowStructureL2) {
            outColor = inpStructureL2Color;
    outStyle = inpStructureL2Style;
    outWidth = inpStructureL2Width;
    return true;
        }
    if(g_cachedIntervals[0] > 0 && stepCount % g_cachedIntervals[0] == 0 && inpShowStructureL1) {
            outColor = inpStructureL1Color;
    outStyle = inpStructureL1Style;
    outWidth = inpStructureL1Width;
    return true;
        }
    }
    // PERF: If structure block above didn't return, this step is NOT a structure level.
    // No need to recompute intervals â€” just check triggerEnabled directly.
    if(triggerEnabled) {
            outColor = inpTriggerColor;
    outStyle = inpTriggerStyle;
    outWidth = inpTriggerWidth;
    return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get Zone Color for level (uses CURRENT level's color)           |

//|                                                                  |
//| Logic: Zone uses SAME logic as level drawing                    |

//|                                                                  |
//| Priority: Structure (L5>L4>L3>L2>L1) > Trigger > Mode Color     |

//|                                                                  |
//| @param currentStep Current step number (must be > 0)            |
//| @param triggerEnabled Whether trigger levels are enabled        |
//| @param baseMultiplier Base multiplier for structure levels      |
//| @return Zone color (clrNONE = use mode's default color)         |
//+------------------------------------------------------------------+
color GetZoneColorForLevel(const int currentStep, const bool triggerEnabled, const int baseMultiplier) {    if(!inpShowMidZones) return clrNONE;
    if(currentStep <= 0) return clrNONE;
    if(inpShowStructure) {
        // PERF: Use g_cachedIntervals directly â€” no local array alloc or copy
        int validatedMultiplier = baseMultiplier;
    if(validatedMultiplier < 2 || validatedMultiplier > 9) {
            validatedMultiplier = GetValidatedBaseMultiplier();        }
    EnsureIntervalsCache(validatedMultiplier);
    if(g_cachedIntervals[4] > 0 && currentStep % g_cachedIntervals[4] == 0 && inpShowStructureL5) {
        return inpStructureL5Color;
        }
    if(g_cachedIntervals[3] > 0 && currentStep % g_cachedIntervals[3] == 0 && inpShowStructureL4) {
        return inpStructureL4Color;
        }
    if(g_cachedIntervals[2] > 0 && currentStep % g_cachedIntervals[2] == 0 && inpShowStructureL3) {
        return inpStructureL3Color;
        }
    if(g_cachedIntervals[1] > 0 && currentStep % g_cachedIntervals[1] == 0 && inpShowStructureL2) {
        return inpStructureL2Color;
        }
    if(g_cachedIntervals[0] > 0 && currentStep % g_cachedIntervals[0] == 0 && inpShowStructureL1) {
        return inpStructureL1Color;
        }
    }
    // Non-structure step: return trigger color if enabled
    if(triggerEnabled) {
        return inpTriggerColor;
    }
    return clrNONE;
}

//+------------------------------------------------------------------+
//| Draw Factor boundary lines (High/Low)                            |
//+------------------------------------------------------------------+
void DrawFactorBoundaryLines(const string objectPrefix, const double highPrice, 
                              const double lowPrice, const double factor, const double stepSize)
{
    // PERF: Static change detection — skip redundant ObjectSet + StringFormat when inputs unchanged
    static double s_prevHigh = 0, s_prevLow = 0, s_prevFactor = 0, s_prevStep = 0;
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        CacheRemoveObject(objectPrefix + "Factor_High");
        ObjectDelete(0, objectPrefix + "Factor_High");
        CacheRemoveObject(objectPrefix + "Factor_Low");
        ObjectDelete(0, objectPrefix + "Factor_Low");
        CacheRemoveObject(objectPrefix + "Factor_High_Label");
        ObjectDelete(0, objectPrefix + "Factor_High_Label");
        CacheRemoveObject(objectPrefix + "Factor_Low_Label");
        ObjectDelete(0, objectPrefix + "Factor_Low_Label");
        // Reset cached state so next non-custom call triggers full update
        s_prevHigh = 0; s_prevLow = 0; s_prevFactor = 0; s_prevStep = 0;
        return;
    }
    bool paramsChanged = HasPriceChanged(s_prevHigh, highPrice) ||
                         HasPriceChanged(s_prevLow, lowPrice) ||
                         HasPriceChanged(s_prevFactor, factor) ||
                         HasPriceChanged(s_prevStep, stepSize);
    double pipSize = (GetCachedDigits() <= 3) ? 0.01 : 0.0001;
    double rangePips = (highPrice - lowPrice) / pipSize;
    double stepPips = stepSize / pipSize;
    string highLineName = objectPrefix + "Factor_High";
    bool highLineCreated = false;
    if(ObjectFind(0, highLineName) < 0) {
        ObjectCreate(0, highLineName, OBJ_HLINE, 0, 0, highPrice);
        highLineCreated = true;
    }
    if(paramsChanged || highLineCreated) {
        ObjectSetDouble(0, highLineName, OBJPROP_PRICE, highPrice);
        ObjectSetInteger(0, highLineName, OBJPROP_COLOR, inpHighColor);
        ObjectSetInteger(0, highLineName, OBJPROP_STYLE, inpHighStyle);
        ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, inpHighWidth);
        ObjectSetInteger(0, highLineName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, highLineName, OBJPROP_SELECTED, false);
        ObjectSetString(0, highLineName, OBJPROP_TOOLTIP,
            StringFormat("Historical HIGH | %s | Range: %.0f pips",
                DoubleToString(highPrice, GetCachedDigits()), rangePips));
    }
    ApplyVisibilityState(highLineName, true);
    string lowLineName = objectPrefix + "Factor_Low";
    bool lowLineCreated = false;
    if(ObjectFind(0, lowLineName) < 0) {
        ObjectCreate(0, lowLineName, OBJ_HLINE, 0, 0, lowPrice);
        lowLineCreated = true;
    }
    if(paramsChanged || lowLineCreated) {
        ObjectSetDouble(0, lowLineName, OBJPROP_PRICE, lowPrice);
        ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, inpLowColor);
        ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, inpLowStyle);
        ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, inpLowWidth);
        ObjectSetInteger(0, lowLineName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lowLineName, OBJPROP_SELECTED, false);
        ObjectSetString(0, lowLineName, OBJPROP_TOOLTIP,
            StringFormat("Historical LOW | %s | Range: %.0f pips",
                DoubleToString(lowPrice, GetCachedDigits()), rangePips));
    }
    ApplyVisibilityState(lowLineName, true);
    // PERF: Cache frame time — avoids 4 TimeCurrent() syscalls per boundary redraw
    datetime frameTime = CacheGetFrameTime();
    string highLabelName = objectPrefix + "Factor_High_Label";
    bool highLabelCreated = false;
    if(ObjectFind(0, highLabelName) < 0) {
        ObjectCreate(0, highLabelName, OBJ_TEXT, 0, frameTime, highPrice);
        highLabelCreated = true;
    }
    if(paramsChanged || highLabelCreated) {
        ObjectSetDouble(0, highLabelName, OBJPROP_PRICE, highPrice);
        ObjectSetInteger(0, highLabelName, OBJPROP_TIME, frameTime);
        ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, inpHighColor);
        ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, highLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        ObjectSetString(0, highLabelName, OBJPROP_FONT, "Arial");
        ObjectSetString(0, highLabelName, OBJPROP_TEXT,
            StringFormat("  HIGH %s | Range: %.0f pips | F=%.2f | Step: %.1f pips",
                DoubleToString(highPrice, GetCachedDigits()), rangePips, factor, stepPips));
        ObjectSetInteger(0, highLabelName, OBJPROP_SELECTABLE, false);
    } else {
        // Only update time anchor (scrolling moves the label)
        ObjectSetInteger(0, highLabelName, OBJPROP_TIME, frameTime);
    }
    ApplyVisibilityState(highLabelName, false);
    string lowLabelName = objectPrefix + "Factor_Low_Label";
    bool lowLabelCreated = false;
    if(ObjectFind(0, lowLabelName) < 0) {
        ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, frameTime, lowPrice);
        lowLabelCreated = true;
    }
    if(paramsChanged || lowLabelCreated) {
        ObjectSetDouble(0, lowLabelName, OBJPROP_PRICE, lowPrice);
        ObjectSetInteger(0, lowLabelName, OBJPROP_TIME, frameTime);
        ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, inpLowColor);
        ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, lowLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetString(0, lowLabelName, OBJPROP_FONT, "Arial");
        ObjectSetString(0, lowLabelName, OBJPROP_TEXT,
            StringFormat("  LOW %s | Range: %.0f pips | F=%.2f | Step: %.1f pips",
                DoubleToString(lowPrice, GetCachedDigits()), rangePips, factor, stepPips));
        ObjectSetInteger(0, lowLabelName, OBJPROP_SELECTABLE, false);
    } else {
        // Only update time anchor (scrolling moves the label)
        ObjectSetInteger(0, lowLabelName, OBJPROP_TIME, frameTime);
    }
    ApplyVisibilityState(lowLabelName, false);
    // PERF: Update cached state after successful render
    s_prevHigh = highPrice;
    s_prevLow = lowPrice;
    s_prevFactor = factor;
    s_prevStep = stepSize;
}
