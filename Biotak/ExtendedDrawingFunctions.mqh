#property copyright "© Formula by Professor Saeed Khakestar, Indicator by Biotak."
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
        if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
    if(!g_linesVisible) {
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    return true;
    } else {
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    return false;
    }
}

//+------------------------------------------------------------------+
//| HELPER: Get common viewport bounds for level drawing             |

//+------------------------------------------------------------------+
void GetViewportBounds(double &vpTop, double &vpBottom) {
        double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = (vpChartMax - vpChartMin) * 0.5;
    vpTop = vpChartMax + vpRange;
    vpBottom = vpChartMin - vpRange;
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
        if(ObjectFind(0, zoneName) >= 0) ObjectDelete(0, zoneName);
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
    if(result.success) {
        if(IsIndicatorHidden()) {
            ObjectSetInteger(0, zoneName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
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
    if(ObjectFind(0, lineTop) >= 0) ObjectDelete(0, lineTop);
    if(ObjectFind(0, lineBottom) >= 0) ObjectDelete(0, lineBottom);
    bool isHidden = IsIndicatorHidden();
    if(ObjectCreate(0, lineTop, OBJ_HLINE, 0, 0, upperPrice)) {
        ObjectSetInteger(0, lineTop, OBJPROP_COLOR, zoneColor);
    ObjectSetInteger(0, lineTop, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, lineTop, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, lineTop, OBJPROP_BACK, true);
    ObjectSetInteger(0, lineTop, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lineTop, OBJPROP_ZORDER, 0);
    if(isHidden) {
            ObjectSetInteger(0, lineTop, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
    if(ObjectCreate(0, lineBottom, OBJ_HLINE, 0, 0, lowerPrice)) {
        ObjectSetInteger(0, lineBottom, OBJPROP_COLOR, zoneColor);
    ObjectSetInteger(0, lineBottom, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, lineBottom, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, lineBottom, OBJPROP_BACK, true);
    ObjectSetInteger(0, lineBottom, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lineBottom, OBJPROP_ZORDER, 0);
    if(isHidden) {
            ObjectSetInteger(0, lineBottom, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Get default Factor value from Control step size                  |

//| Simple Formula: Step = Range / (Factor × 2)                      |
//| We want: Step = Control = (SS + LS) / 2 = TH × 1.75              |
//| So: TH × 1.75 = Range / (Factor × 2)                             |
//| Therefore: Factor = Range / (TH × 1.75 × 2)                      |
//|                                                                  |
//| NOW SUPPORTS MULTIPLE BASIS TYPES:                               |
//| - Control, SS, LS, TH, Trigger, Pattern, Structure, Combo       |
//+------------------------------------------------------------------+
double GetDefaultFactorValue(const double basePrice) {
        if(basePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Invalid base price (", basePrice, "), using fallback");
    #endif
    return 50.0;    }
    if(g_highestHigh <= 0 || g_lowestLow <= 0 || g_highestHigh <= g_lowestLow) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Invalid historical range, using fallback");
    #endif
    return 50.0;    }
    double range = g_highestHigh - g_lowestLow;
    if(range <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Invalid range (", range, "), using fallback");
    #endif
    return 50.0;
    }
    double stepSize = GetStepSizeForFactorBasis(basePrice, inpFactorAutoBasis);
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Invalid step size, using fallback");
    #endif
    return 50.0;
    }
    double denominator = stepSize * 2.0;
    if(denominator <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Invalid denominator, using fallback");
    #endif
    return 50.0;
    }
    double minDenominator = range / 10000.0;
    if(denominator < minDenominator) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Step size too small (", DoubleToString(stepSize, 8), 
              "), would produce factor > 10000, clamping to 1000");
    #endif
    return 1000.0;
    }
    double factor = range / denominator;
    if(factor > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Factor too large (", DoubleToString(factor, 2), 
              "), clamping to 1000 for usability");
    #endif
    factor = 1000.0;
    } else if(factor < 0.01) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("GetDefaultFactorValue: Factor too small (", DoubleToString(factor, 4), 
              "), clamping to 1.0 for usability");
    #endif
    factor = 1.0;
    }
    double result = NormalizeDouble(MathMax(0.01, MathMin(10000, factor)), 2);
    #ifdef ENABLE_DEBUG_LOGS
    Print("GetDefaultFactorValue: Basis=", EnumToString(inpFactorAutoBasis),
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForFactorBasis: Invalid basePrice=", basePrice);
    #endif
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
    case FACTOR_BASIS_TH:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_TRIGGER:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, PERIOD_CURRENT);
    break;
    case FACTOR_BASIS_PATTERN:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, GetPatternTimeframe());
    break;
    case FACTOR_BASIS_STRUCTURE:            stepSize = GetStepSizeForBasisType(basePrice, 1.0, GetStructureTimeframe());
    break;
    case FACTOR_BASIS_COMBO:            stepSize = GetComboStepSizeForFactor(basePrice);
    break;
    default:
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetStepSizeForFactorBasis: Unknown basis=", basis, ", using Control");
    #endif
    stepSize = GetStepSizeForBasisType(basePrice, 1.75, PERIOD_CURRENT);
    break;
    }
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForFactorBasis: Failed to calculate step for basis=", 
              EnumToString(basis));
    #endif
    return 0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ GetStepSizeForFactorBasis: Basis=", EnumToString(basis), 
          ", Step=", DoubleToString(stepSize, Digits));
    #endif
    return stepSize;
}

//+------------------------------------------------------------------+
//| Get step size for specific multiplier and timeframe              |

//| FIXED: Comprehensive error handling and validation               |
//+------------------------------------------------------------------+
double GetStepSizeForBasisType(const double basePrice, const double multiplier, 
                                const ENUM_TIMEFRAMES timeframe) {
        if(basePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForBasisType: Invalid basePrice=", basePrice);
    #endif
    return 0;
    }
    if(multiplier <= 0 || multiplier > 10.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForBasisType: Invalid multiplier=", multiplier);
    #endif
    return 0;
    }
    double thPercentage = GetTimeframeTHForPeriod(timeframe);
    if(thPercentage <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForBasisType: Invalid TH%=", thPercentage, " for TF=", timeframe);
    #endif
    return 0;
    }
    double thPriceUnits = (basePrice * thPercentage) / 100.0;
    if(thPriceUnits <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForBasisType: Invalid TH price units=", thPriceUnits);
    #endif
    return 0;
    }
    double stepSize = thPriceUnits * multiplier;
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForBasisType: Zero or negative stepSize=", stepSize);
    #endif
    return 0;
    }
    if(stepSize > basePrice * 0.5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetStepSizeForBasisType: Suspiciously large stepSize=", stepSize, 
              " (> 50% of basePrice=", basePrice, ")");
    Print("   TH%=", DoubleToString(thPercentage, 4), ", Mult=", multiplier);
    #endif
    }
    double minReasonableStep = basePrice * 0.000001;
    if(stepSize < minReasonableStep) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetStepSizeForBasisType: Suspiciously small stepSize=", stepSize, 
              " (< 0.0001% of basePrice=", basePrice, ")");
    #endif
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ GetStepSizeForBasisType: TF=", timeframe, ", Mult=", multiplier, 
          ", TH%=", DoubleToString(thPercentage, 4), ", Step=", DoubleToString(stepSize, Digits));
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid basePrice=", basePrice);
    #endif
    return 0;
    }
    if(tf1 < COMBO_TF_SUB || tf1 > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid tf1=", tf1);
    #endif
    return 0;
    }
    if(tf2 < COMBO_TF_SUB || tf2 > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid tf2=", tf2);
    #endif
    return 0;
    }
    if(tf3 < COMBO_TF_SUB || tf3 > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid tf3=", tf3);
    #endif
    return 0;
    }
    if(step1 < COMBO_STEP_TH || step1 > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid step1=", step1);
    #endif
    return 0;
    }
    if(step2 < COMBO_STEP_TH || step2 > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid step2=", step2);
    #endif
    return 0;
    }
    if(step3 < COMBO_STEP_TH || step3 > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid step3=", step3);
    #endif
    return 0;
    }
    if(operation < COMBO_OP_AVERAGE || operation > COMBO_OP_WEIGHTED) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid operation=", operation);
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid step values");
    #endif
    return 0;
    }
    double result = 0;
    switch(operation) {
        case COMBO_OP_AVERAGE:            result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    break;
    case COMBO_OP_ADD:            {
        double maxSafeValue = DBL_MAX / 3.0;
    if(stepValue1 > maxSafeValue || stepValue2 > maxSafeValue || stepValue3 > maxSafeValue) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ Overflow risk in COMBO_OP_ADD (triple), using safe fallback");
    #endif
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
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CalculateTripleComboStepSize: Unsupported operation=", operation, 
                  ", using Average");
    #endif
    result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    break;
    }
    if(result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateTripleComboStepSize: Invalid result=", result);
    #endif
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
        Print("⚠️ CalculateTripleComboStepSize: Suspicious result detected");
    Print("   Operation=", EnumToString(operation));
    Print("   Step1=", DoubleToString(stepValue1, Digits), 
              ", Step2=", DoubleToString(stepValue2, Digits), 
              ", Step3=", DoubleToString(stepValue3, Digits));
    Print("   Result=", DoubleToString(result, Digits), 
              " (min=", DoubleToString(minStep, Digits), 
              ", max=", DoubleToString(maxStep, Digits), ")");
    Print("   Using fallback: average");
    #endif
    result = (stepValue1 + stepValue2 + stepValue3) / 3.0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CalculateTripleComboStepSize: SUCCESS");
    Print("   TF1=", EnumToString(tf1), ", Step1=", DoubleToString(stepValue1, Digits));
    Print("   TF2=", EnumToString(tf2), ", Step2=", DoubleToString(stepValue2, Digits));
    Print("   TF3=", EnumToString(tf3), ", Step3=", DoubleToString(stepValue3, Digits));
    Print("   Operation=", EnumToString(operation), ", Result=", DoubleToString(result, Digits));
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
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ GetStepSizeFromComponent: All MEAN components invalid for ", EnumToString(comp));
    #endif
    return 0;
        }
    if(validCount < 3) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetStepSizeFromComponent: Only ", validCount, "/3 values valid for ", EnumToString(comp));
    Print("   TH: ", (th > 0 ? DoubleToString(th, Digits) : "INVALID"));
    Print("   SS: ", (ss > 0 ? DoubleToString(ss, Digits) : "INVALID"));
    #ifdef ENABLE_DEBUG_LOGS
            Print("   LS: ", (ls > 0 ? DoubleToString(ls, Digits) : "INVALID"));
    #endif
    #endif
    if(validCount == 1) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("️ MEAN COMPONENT INFO: ", EnumToString(comp), 
                      " - Only 1/3 values valid. Result equals the single valid value.");
    #endif
    } else if(validCount == 2) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("️ MEAN COMPONENT INFO: ", EnumToString(comp), 
                      " - Only 2/3 values valid. Mean calculated from 2 values.");
    #endif
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
        Print("✅ GetStepSizeFromComponent: MEAN component ", EnumToString(comp), 
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
//| Calculate Geometric Mean of N values: ⁿ√(v1 × v2 × ... × vn)    |

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
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CalculateGeometricMeanN: Non-positive value at index ", i, ": ", values[i]);
    #endif
    return 0;
        }
    logSum += MathLog(values[i]);
    }
    double result = MathExp(logSum / n);
    if(result <= 0 || result > DBL_MAX / 2.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateGeometricMeanN: Invalid result=", result);
    #endif
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
        if(MathAbs(values[i]) < 0.000001) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CalculateHarmonicMeanN: Zero/near-zero value at index ", i, ": ", values[i]);
    #endif
    return 0;
        }
        reciprocalSum += 1.0 / values[i];
    }
    if(MathAbs(reciprocalSum) < 0.000001) return 0;
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateMeanByType: Empty array");
    #endif
    return 0;
    }
    if(n == 1) return values[0];
    double result = 0;
    switch(meanType) {
        case MEAN_ARITHMETIC:
            result = CalculateArithmeticMeanN(values);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CalculateMeanByType: Arithmetic Mean of ", n, " values = ", 
                  DoubleToString(result, Digits));
    #endif
    break;
    case MEAN_GEOMETRIC:
            result = CalculateGeometricMeanN(values);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CalculateMeanByType: Geometric Mean of ", n, " values = ", 
                  DoubleToString(result, Digits));
    #endif
    break;
    case MEAN_HARMONIC:
            result = CalculateHarmonicMeanN(values);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ CalculateMeanByType: Harmonic Mean of ", n, " values = ", 
                  DoubleToString(result, Digits));
    #endif
    break;
    default:
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CalculateMeanByType: Unknown mean type ", meanType);
    #endif
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
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ CollectQuickTestComponents: Unknown preset=", inpQuickTestPreset);
    #endif
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
        Print("✅ CollectQuickTestComponents: Collected ", count, " components");
    for(int i = 0; i < count; i++) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("   [", i, "] = ", EnumToString(components[i]));
    #endif
    }
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CollectQuickTestComponents: No components collected!");
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateQuickTestStepSize: Invalid basePrice=", basePrice);
    #endif
    return 0;
    }
    ENUM_COMBO_COMPONENT_ITEM selectedComponents[];
    int componentCount = CollectQuickTestComponents(selectedComponents);
    if(componentCount == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Quick Test: No components selected");
    #endif
    Alert("⚠️ QUICK TEST MODE ERROR\n\nNo components selected!\nPlease select at least one timeframe in Quick Test settings.");
    return 0;
    }
    double componentValues[];
    ArrayResize(componentValues, componentCount);
    for(int i = 0; i < componentCount; i++) {
        double val = GetStepSizeFromComponent(basePrice, selectedComponents[i]);
    if(val <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Quick Test: Component ", selectedComponents[i], " returned invalid value");
    #endif
    return 0;
        }
        
        componentValues[i] = val;
    #ifdef ENABLE_DEBUG_LOGS
        Print("  Component[", i, "] = ", DoubleToString(val, Digits));
    #endif
    }
    double result = CalculateMeanByType(componentValues, inpQuickTestMeanType);
    if(result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Quick Test: Mean calculation failed");
    #endif
    return 0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    string meanTypeName = "";
    switch(inpQuickTestMeanType) {
        case MEAN_ARITHMETIC: meanTypeName = "Arithmetic"; break;
    case MEAN_GEOMETRIC: meanTypeName = "Geometric"; break;
    case MEAN_HARMONIC: meanTypeName = "Harmonic"; break;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Quick Test [", meanTypeName, " Mean of ", componentCount, " components]: Result=", 
    #endif
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
    case OP_DIVIDE:            if(MathAbs(value2) < 0.000001) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ApplyCalculatorOperator: Division by zero/near-zero detected! value2=", DoubleToString(value2, 8));
    #endif
    return 0;            }
    return value1 / value2;
    case OP_AVERAGE:            return (value1 + value2) / 2.0;
    case OP_GEOMETRIC_MEAN:            if(value1 <= 0 || value2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ApplyCalculatorOperator: Geometric mean requires positive values! value1=", value1, " value2=", value2);
    #endif
    return 0;
            }
    return MathSqrt(value1 * value2);
    case OP_HARMONIC_MEAN: {
        if(MathAbs(value1) < 0.000001 || MathAbs(value2) < 0.000001) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ApplyCalculatorOperator: Harmonic mean requires non-zero values! value1=", value1, " value2=", value2);
    #endif
    return 0;
            }
    double sum = value1 + value2;
    if(MathAbs(sum) < 0.000001) {
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Calculator Mode (Dual): Component 1 cannot be IGNORE");
    #endif
    Alert("⚠️ ADVANCED MODE ERROR (Dual Group Topology)\n\nComponent 1 cannot be IGNORE!\nDual Group topology requires at least Component 1.");
    return 0;
    }
    double valG1 = GetStepSizeFromComponent(basePrice, inpComboComp1);
    if(valG1 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Calculator Mode (Dual): Component 1 calculation failed");
    #endif
    Alert("⚠️ ADVANCED MODE ERROR\n\nFailed to calculate Component 1.\nPlease check your component selection.");
    return 0;
    }
    valG1 = ApplyOperationWithComponent(valG1, inpComboOp1, inpComboComp2, basePrice);
    if(inpComboOp2 == OP_NONE || inpComboComp3 == COMP_IGNORE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("️ Dual Group: Only Group 1 active (Op2=NONE or Comp3=IGNORE)");
    Print("   Group 1 Result: ", DoubleToString(valG1, Digits));
    #endif
    return valG1;
    }
    double valG2 = GetStepSizeFromComponent(basePrice, inpComboComp3);
    if(valG2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Dual Group: Component 3 invalid or failed");
    Print("   Component 3: ", EnumToString(inpComboComp3));
    Print("   Fallback: Using Group 1 result only");
    #ifdef ENABLE_DEBUG_LOGS
        Print("   Group 1 Result: ", DoubleToString(valG1, Digits));
    #endif
    #endif
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ DUAL GROUP TOPOLOGY WARNING: Component 3 (", EnumToString(inpComboComp3), 
              ") calculation failed. Using Group 1 result only.");
    #endif
    return valG1;
    }
    valG2 = ApplyOperationWithComponent(valG2, inpComboOp3, inpComboComp4, basePrice);
    if(valG2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Dual Group: Group 2 calculation failed after Op3");
    Print("   Op3: ", EnumToString(inpComboOp3));
    Print("   Component 4: ", EnumToString(inpComboComp4));
    Print("   Fallback: Using Group 1 result only");
    Print("   Group 1 Result: ", DoubleToString(valG1, Digits));
    Print("⚠️ DUAL GROUP TOPOLOGY WARNING: Group 2 calculation failed. Using Group 1 result only.");
    #endif
    return valG1;
    }
    double finalResult = ApplyCalculatorOperator(valG1, valG2, inpComboOp2);
    if(finalResult <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Dual Group: Final combination failed");
    Print("   Group 1: ", DoubleToString(valG1, Digits));
    Print("   Op2: ", EnumToString(inpComboOp2));
    Print("   Group 2: ", DoubleToString(valG2, Digits));
    Print("   Result: ", DoubleToString(finalResult, Digits));
    Print("   Fallback: Using Group 1 result only");
    Print("⚠️ DUAL GROUP TOPOLOGY WARNING: Final combination (", EnumToString(inpComboOp2), 
              ") produced invalid result. Using Group 1 result only.");
    #endif
    return valG1;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Dual Group: SUCCESS");
    Print("   Group 1: ", DoubleToString(valG1, Digits));
    Print("   Op2: ", EnumToString(inpComboOp2));
    Print("   Group 2: ", DoubleToString(valG2, Digits));
    Print("   Final Result: ", DoubleToString(finalResult, Digits));
    #endif
    return finalResult;
}
    double ApplyOperationWithComponent(const double currentVal, 
                                  const ENUM_COMBO_OPERATOR op, 
                                  const ENUM_COMBO_COMPONENT_ITEM nextComp, 
                                  const double basePrice) {    if (op == OP_NONE || nextComp == COMP_IGNORE) {
        #ifdef ENABLE_DEBUG_LOGS
        if(op == OP_NONE) {
            Print("️ ApplyOperationWithComponent: Operator is NONE, skipping");
        } else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("️ ApplyOperationWithComponent: Component is IGNORE, skipping");
    #endif
    }
    #endif
    return currentVal;
    }
    double nextVal = GetStepSizeFromComponent(basePrice, nextComp);
    if (nextVal <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ApplyOperationWithComponent: Next component invalid");
    Print("   Component: ", EnumToString(nextComp));
    Print("   Operator: ", EnumToString(op));
    Print("   Keeping current value: ", DoubleToString(currentVal, Digits));
    Print("⚠️ CALCULATOR WARNING: Component ", EnumToString(nextComp), 
              " calculation failed. Skipping operation ", EnumToString(op));
    #endif
    return currentVal;
    }
    double result = ApplyCalculatorOperator(currentVal, nextVal, op);
    if (result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ApplyOperationWithComponent: Operation produced invalid result");
    Print("   Current: ", DoubleToString(currentVal, Digits));
    Print("   Operator: ", EnumToString(op));
    Print("   Next: ", DoubleToString(nextVal, Digits));
    Print("   Result: ", DoubleToString(result, Digits));
    Print("   Fallback to current value");
    Print("⚠️ CALCULATOR WARNING: Operation ", EnumToString(op), 
              " produced invalid result. Keeping previous value.");
    #endif
    return currentVal;    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ApplyOperationWithComponent: ", DoubleToString(currentVal, Digits), 
          " ", EnumToString(op), " ", DoubleToString(nextVal, Digits), 
          " = ", DoubleToString(result, Digits));
    #endif
    return result;
}
    double CalculateLinearTopology(const double basePrice) {
        if(inpComboComp1 == COMP_IGNORE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Calculator Mode (Linear): Component 1 is IGNORE");
    #endif
    Alert("⚠️ ADVANCED MODE ERROR (Linear Topology)\n\nComponent 1 cannot be IGNORE!\nLinear topology requires at least Component 1.");
    return 0;
    }
    double result = GetStepSizeFromComponent(basePrice, inpComboComp1);
    if(result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Calculator Mode (Linear): Component 1 calculation failed");
    #endif
    Alert("⚠️ ADVANCED MODE ERROR\n\nFailed to calculate Component 1.\nPlease check your component selection.");
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateCalculatorModeStepSize: Invalid basePrice=", basePrice);
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ N-ARY Mode: No valid components found");
    #endif
    Alert("⚠️ ADVANCED MODE ERROR (N-ary Operator)\n\nAll components are set to IGNORE!\nPlease select at least one component.");
    return 0;
        }
    int expectedComponents = 0;
    if(inpComboComp1 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp2 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp3 != COMP_IGNORE) expectedComponents++;
    if(inpComboComp4 != COMP_IGNORE) expectedComponents++;
    if(componentCount < expectedComponents) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ N-ARY Mode: Only ", componentCount, "/", expectedComponents, " components valid");
    #endif
    Print("️ N-ARY OPERATOR INFO: Using ", componentCount, " valid components out of ", 
                  expectedComponents, " selected.");
        }
    #ifdef ENABLE_DEBUG_LOGS
        Print("️ N-ARY Mode: Collected ", componentCount, " valid components");
    for(int i = 0; i < componentCount; i++) {
            Print("   Component[", i, "] = ", DoubleToString(componentValues[i], Digits));
        }
    #endif
    double naryResult = 0;
    switch(inpComboOp1) {
            case OP_GEOMETRIC_MEAN_ALL:
                naryResult = CalculateGeometricMeanN(componentValues);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ N-ARY Mode: Geometric Mean of ", componentCount, " components = ", 
                      DoubleToString(naryResult, Digits));
    #endif
    break;
    case OP_ARITHMETIC_MEAN_ALL:
                naryResult = CalculateArithmeticMeanN(componentValues);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ N-ARY Mode: Arithmetic Mean of ", componentCount, " components = ", 
                      DoubleToString(naryResult, Digits));
    #endif
    break;
    case OP_HARMONIC_MEAN_ALL:
                naryResult = CalculateHarmonicMeanN(componentValues);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ N-ARY Mode: Harmonic Mean of ", componentCount, " components = ", 
                      DoubleToString(naryResult, Digits));
    #endif
    break;
    case OP_MIN_ALL:
                naryResult = CalculateMinN(componentValues);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ N-ARY Mode: Minimum of ", componentCount, " components = ", 
                      DoubleToString(naryResult, Digits));
    #endif
    break;
    case OP_MAX_ALL:
                naryResult = CalculateMaxN(componentValues);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ N-ARY Mode: Maximum of ", componentCount, " components = ", 
                      DoubleToString(naryResult, Digits));
    #endif
    break;
    default:
                #ifdef ENABLE_DEBUG_LOGS
                Print("❌ N-ARY Mode: Unknown operator ", inpComboOp1);
    #endif
    return 0;
        }
    if(naryResult <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ N-ARY Mode: Result is <= 0");
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Calculator Mode Result is <= 0");
    #endif
    return 0;
    }
    finalResult = NormalizeDouble(finalResult, GetCachedDigits());
    #ifdef ENABLE_DEBUG_LOGS
    string topoName = (inpComboTopology == TOPOLOGY_LINEAR) ? "LINEAR" : "DUAL_GROUP";
    Print("✅ Calculator Mode [", topoName, "]: Result=", DoubleToString(finalResult, Digits));
    #endif
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
//| - NOW SUPPORTS TRIPLE PRESETS! ✅                                |
//| - NOW SUPPORTS QUICK TEST MODE! ⚡                               |
//+------------------------------------------------------------------+
double CalculateComboStepSize(const double basePrice) {
        if(basePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid basePrice=", basePrice);
    #endif
    Alert("⚠️ COMBO MODE ERROR\n\nInvalid base price for calculation.\nPlease check your settings.");
    return 0;
    }
    if(inpComboMode == COMBO_MODE_QUICK_TEST) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ CalculateComboStepSize: QUICK TEST mode detected");
    #endif
    return CalculateQuickTestStepSize(basePrice);
    }
    if(inpComboMode == COMBO_MODE_ADVANCED) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ CalculateComboStepSize: ADVANCED (CALCULATOR) mode detected");
    #endif
    return CalculateCalculatorModeStepSize(basePrice);
    }
    if(inpComboMode != COMBO_MODE_PRESET) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid mode=", inpComboMode, " (expected PRESET)");
    #endif
    Alert("⚠️ COMBO MODE ERROR\n\nInvalid Combo Mode configuration!\nExpected: Preset Mode\nActual: ", EnumToString(inpComboMode));
    return 0;
    }
    if(inpComboPreset == COMBO_PRESET_BALANCED_TRIPLE) {
        return CalculateTripleComboStepSize(basePrice,
            COMBO_TF_TRIGGER, COMBO_STEP_TH,
            COMBO_TF_PATTERN, COMBO_STEP_TH,
            COMBO_TF_STRUCTURE, COMBO_STEP_TH,
            COMBO_OP_AVERAGE);
    }
    else if(inpComboPreset == COMBO_PRESET_TRIPLE_CONSERVATIVE) {
        return CalculateTripleComboStepSize(basePrice,
            COMBO_TF_TRIGGER, COMBO_STEP_TH,
            COMBO_TF_PATTERN, COMBO_STEP_TH,
            COMBO_TF_STRUCTURE, COMBO_STEP_TH,
            COMBO_OP_MAX);
    }
    else if(inpComboPreset == COMBO_PRESET_TRIPLE_AGGRESSIVE) {
        return CalculateTripleComboStepSize(basePrice,
            COMBO_TF_TRIGGER, COMBO_STEP_TH,
            COMBO_TF_PATTERN, COMBO_STEP_TH,
            COMBO_TF_STRUCTURE, COMBO_STEP_TH,
            COMBO_OP_MIN);
    }
    else if(inpComboPreset == COMBO_PRESET_MANUAL_TRIPLE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("️ MANUAL_TRIPLE preset detected → Redirecting to Advanced Mode");
    #endif
    return CalculateCalculatorModeStepSize(basePrice);
    }
    else if(inpComboPreset == COMBO_PRESET_MANUAL_DUAL) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("️ MANUAL_DUAL preset detected → Redirecting to Advanced Mode");
    #endif
    return CalculateCalculatorModeStepSize(basePrice);
    }    
    ENUM_COMBO_TIMEFRAME_TYPE tf1, tf2;
    ENUM_COMBO_STEP_TYPE step1Type, step2Type;
    ENUM_COMBO_OPERATION operation;
    GetPresetConfiguration(inpComboPreset, tf1, step1Type, tf2, step2Type, operation);
    if(tf1 < COMBO_TF_SUB || tf1 > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid tf1=", tf1);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid timeframe 1 configuration!\nPreset: ", EnumToString(inpComboPreset));
    return 0;
    }
    if(tf2 < COMBO_TF_SUB || tf2 > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid tf2=", tf2);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid timeframe 2 configuration!\nPreset: ", EnumToString(inpComboPreset));
    return 0;
    }
    if(step1Type < COMBO_STEP_TH || step1Type > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid step1Type=", step1Type);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid step type 1 configuration!\nPreset: ", EnumToString(inpComboPreset));
    return 0;
    }
    if(step2Type < COMBO_STEP_TH || step2Type > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid step2Type=", step2Type);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid step type 2 configuration!\nPreset: ", EnumToString(inpComboPreset));
    return 0;
    }
    if(operation < COMBO_OP_AVERAGE || operation > COMBO_OP_WEIGHTED) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid operation=", operation);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid operation configuration!\nPreset: ", EnumToString(inpComboPreset));
    return 0;
    }    
    ENUM_TIMEFRAMES timeframe1 = GetTimeframeByType(tf1);
    ENUM_TIMEFRAMES timeframe2 = GetTimeframeByType(tf2);
    if(timeframe1 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid timeframe1 from tf1=", tf1);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nFailed to calculate timeframe 1!\nTimeframe Type: ", EnumToString(tf1));
    return 0;
    }
    if(timeframe2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid timeframe2 from tf2=", tf2);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nFailed to calculate timeframe 2!\nTimeframe Type: ", EnumToString(tf2));
    return 0;
    }
    double multiplier1 = GetStepMultiplier(step1Type);
    double multiplier2 = GetStepMultiplier(step2Type);
    if(multiplier1 <= 0 || multiplier1 > 10.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid multiplier1=", multiplier1);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid step multiplier 1!\nStep Type: ", EnumToString(step1Type));
    return 0;
    }
    if(multiplier2 <= 0 || multiplier2 > 10.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid multiplier2=", multiplier2);
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid step multiplier 2!\nStep Type: ", EnumToString(step2Type));
    return 0;
    }
    double step1 = GetStepSizeForBasisType(basePrice, multiplier1, timeframe1);
    double step2 = GetStepSizeForBasisType(basePrice, multiplier2, timeframe2);
    if(step1 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid step1=", step1, 
              " for TF=", EnumToString(tf1), ", StepType=", EnumToString(step1Type));
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nFailed to calculate step size 1!\nTimeframe: ", EnumToString(tf1), 
              "\nStep Type: ", EnumToString(step1Type));
    return 0;
    }
    if(step2 <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid step2=", step2, 
              " for TF=", EnumToString(tf2), ", StepType=", EnumToString(step2Type));
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nFailed to calculate step size 2!\nTimeframe: ", EnumToString(tf2), 
              "\nStep Type: ", EnumToString(step2Type));
    return 0;
    }
    double comboStep = ApplyComboOperation(step1, step2, operation, 
                                           0.5, 0.5);
    if(comboStep <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CalculateComboStepSize: Invalid comboStep=", comboStep, 
              " after operation=", EnumToString(operation));
    #endif
    Alert("⚠️ PRESET MODE ERROR\n\nInvalid result after Combo operation!\nOperation: ", EnumToString(operation),
              "\nStep1: ", DoubleToString(step1, GetCachedDigits()), 
              "\nStep2: ", DoubleToString(step2, GetCachedDigits()));
    return 0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CalculateComboStepSize: SUCCESS");
    Print("   Preset=", EnumToString(inpComboPreset));
    Print("   TF1=", EnumToString(tf1), " (", timeframe1, "), Step1Type=", EnumToString(step1Type), 
          " (×", multiplier1, "), Value=", DoubleToString(step1, Digits));
    Print("   TF2=", EnumToString(tf2), " (", timeframe2, "), Step2Type=", EnumToString(step2Type), 
          " (×", multiplier2, "), Value=", DoubleToString(step2, Digits));
    Print("   Operation=", EnumToString(operation), ", Result=", DoubleToString(comboStep, Digits));
    #endif
    return comboStep;
}
    double GetComboStepSizeForFactor(const double basePrice) {
        return CalculateComboStepSize(basePrice);
}
    double GetStepSizeForSharedComponent(const double basePrice, 
                                      const ENUM_COMBO_COMPONENT_ITEM component) {
        if(basePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepSizeForSharedComponent: Invalid basePrice=", basePrice);
    #endif
    return 0;
    }
    
    ENUM_TIMEFRAMES timeframe;
    double multiplier;
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
    if(component == COMP_SUB_TH) multiplier = 1.0;
    else if(component == COMP_SUB_SS) multiplier = 1.5;
    else multiplier = 2.0;
    break;
        }
    case COMP_TRIGGER_TH:
            timeframe = GetSubTimeframe();
    multiplier = 1.0;
    break;
    case COMP_TRIGGER_SS:
            timeframe = GetSubTimeframe();
    multiplier = 1.5;
    break;
    case COMP_TRIGGER_LS:
            timeframe = GetSubTimeframe();
    multiplier = 2.0;
    break;
    case COMP_PATTERN_TH:
            timeframe = (ENUM_TIMEFRAMES)GetCachedPeriod();
    multiplier = 1.0;
    break;
    case COMP_PATTERN_SS:
            timeframe = (ENUM_TIMEFRAMES)GetCachedPeriod();
    multiplier = 1.5;
    break;
    case COMP_PATTERN_LS:
            timeframe = (ENUM_TIMEFRAMES)GetCachedPeriod();
    multiplier = 2.0;
    break;
    case COMP_STRUCTURE_TH:
            timeframe = GetPatternTimeframe();
    multiplier = 1.0;
    break;
    case COMP_STRUCTURE_SS:
            timeframe = GetPatternTimeframe();
    multiplier = 1.5;
    break;
    case COMP_STRUCTURE_LS:
            timeframe = GetPatternTimeframe();
    multiplier = 2.0;
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
    if(minutes == 1) return "M1";
    else if(minutes == 5) return "M4";
    else if(minutes == 15) return "M16";
    else if(minutes == 30) return "M16";
    else if(minutes == 60) return "H1+M4";
    else if(minutes == 240) return "H4+M16";
    else if(minutes == 1440) return "D2+H20+M16";
    else if(minutes == 10080) return "D11+H9+M4";
    else if(minutes == 43200) return "D45+H12+M16";
    else return "M1";}

//+------------------------------------------------------------------+
//| Get TH percentage for specific timeframe period                  |

//| FIXED: No recursion, proper error handling                       |
//+------------------------------------------------------------------+
double GetTimeframeTHForPeriod(const ENUM_TIMEFRAMES period) {
        if(period == PERIOD_CURRENT || period == 0) {
        string currentFractal = GetCurrentFractalTimeframe();
    double th = CalculateTimeframeTH(currentFractal);
    #ifdef ENABLE_DEBUG_LOGS
        Print("GetTimeframeTHForPeriod: CURRENT (", Period(), "min) -> ", 
              currentFractal, " = ", DoubleToString(th, 4), "%");
    #endif
    return th;
    }
    string timeframeStr = "";
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ GetTimeframeTHForPeriod: Unknown period=", period, ", using D45+H12+M16");
    #endif
    return CalculateTimeframeTH("D45+H12+M16");
            }
            break;
        }
    }
    if(minutes == 1) timeframeStr = "M1";
    else if(minutes <= 5) timeframeStr = "M4";
    else if(minutes <= 15) timeframeStr = "M16";
    else if(minutes <= 30) timeframeStr = "M16";
    else if(minutes <= 60) timeframeStr = "H1+M4";
    else if(minutes <= 240) timeframeStr = "H4+M16";
    else if(minutes <= 1440) timeframeStr = "D2+H20+M16";
    else if(minutes <= 10080) timeframeStr = "D11+H9+M4";
    else timeframeStr = "D45+H12+M16";
    double th = CalculateTimeframeTH(timeframeStr);
    #ifdef ENABLE_DEBUG_LOGS
    Print("GetTimeframeTHForPeriod: ", period, " (", minutes, "min) -> ", 
          timeframeStr, " = ", DoubleToString(th, 4), "%");
    #endif
    return th;
}

//+------------------------------------------------------------------+
//| Get Sub timeframe (1/4 current - faster than current)            |

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetSubTimeframe() {
        int currentMinutes = PeriodMinutes();
    int subMinutes = currentMinutes / 4;
    if(subMinutes < 1) subMinutes = 1;
    ENUM_TIMEFRAMES result;
    if(subMinutes <= 1) result = PERIOD_M1;
    else if(subMinutes <= 5) result = PERIOD_M5;
    else if(subMinutes <= 15) result = PERIOD_M15;
    else if(subMinutes <= 30) result = PERIOD_M30;
    else if(subMinutes <= 60) result = PERIOD_H1;
    else if(subMinutes <= 360) result = PERIOD_H4;
    else if(subMinutes <= 1440) result = PERIOD_D1;
    else if(subMinutes <= 4320) result = PERIOD_D1;
    else if(subMinutes <= 10080) result = PERIOD_W1;
    else if(subMinutes <= 20000) result = PERIOD_W1;
    else result = PERIOD_MN1;
    #ifdef ENABLE_DEBUG_LOGS
    Print("GetSubTimeframe: Current=", currentMinutes, "min, Sub=", 
          subMinutes, "min (÷4) -> ", result);
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Get timeframe based on type                                       |

//| Added validation and error logging                     |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetTimeframeByType(const ENUM_COMBO_TIMEFRAME_TYPE tfType) {
        if(tfType < COMBO_TF_SUB || tfType > COMBO_TF_STRUCTURE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetTimeframeByType: Invalid tfType=", tfType, ", using current period");
    #endif
    return (ENUM_TIMEFRAMES)GetCachedPeriod();    }
    
    ENUM_TIMEFRAMES result;
    switch(tfType) {
        case COMBO_TF_SUB:            {
        int currentMinutes = PeriodMinutes();
    int subMinutes = currentMinutes / 16;
    if(subMinutes < 1) subMinutes = 1;
    if(subMinutes <= 1) result = PERIOD_M1;
    else if(subMinutes <= 5) result = PERIOD_M5;
    else if(subMinutes <= 15) result = PERIOD_M15;
    else if(subMinutes <= 30) result = PERIOD_M30;
    else if(subMinutes <= 60) result = PERIOD_H1;
    else if(subMinutes <= 360) result = PERIOD_H4;
    else if(subMinutes <= 1440) result = PERIOD_D1;
    else if(subMinutes <= 10080) result = PERIOD_W1;
    else result = PERIOD_MN1;
            }
            break;
    case COMBO_TF_TRIGGER:            result = GetSubTimeframe();
    break;
    case COMBO_TF_PATTERN:            result = (ENUM_TIMEFRAMES)GetCachedPeriod();
    break;
    case COMBO_TF_STRUCTURE:            result = GetPatternTimeframe();
    break;
    default:
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetTimeframeByType: Unexpected tfType=", tfType, ", using current period");
    #endif
    result = (ENUM_TIMEFRAMES)GetCachedPeriod();
    break;
    }
    if(result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetTimeframeByType: Invalid result=", result, " for tfType=", tfType);
    #endif
    return (ENUM_TIMEFRAMES)GetCachedPeriod();    }
    return result;
}

//+------------------------------------------------------------------+
//| Get step multiplier based on step type                           |

//| Added validation and error logging                     |
//+------------------------------------------------------------------+
double GetStepMultiplier(const ENUM_COMBO_STEP_TYPE stepType) {
        if(stepType < COMBO_STEP_TH || stepType > COMBO_STEP_LS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepMultiplier: Invalid stepType=", stepType, ", using 1.0 (TH)");
    #endif
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
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetStepMultiplier: Unexpected stepType=", stepType, ", using 1.0 (TH)");
    #endif
    multiplier = 1.0;
    break;
    }
    if(multiplier <= 0 || multiplier > 10.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetStepMultiplier: Invalid multiplier=", multiplier, " for stepType=", stepType);
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ApplyComboOperation: Invalid values - v1=", value1, ", v2=", value2);
    #endif
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
                Print("⚠️ ApplyComboOperation: Subtract result too small (", 
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
                Print("⚠️ ApplyComboOperation: Multiply overflow detected");
    Print("   v1=", DoubleToString(value1, Digits), 
                      ", v2=", DoubleToString(value2, Digits), 
                      ", result=", DoubleToString(result, Digits), 
                      " > threshold=", DoubleToString(overflowThreshold, Digits));
    #ifdef ENABLE_DEBUG_LOGS
                Print("   Clamping to max input=", DoubleToString(maxInput, Digits));
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ApplyComboOperation: Negative weights - w1=", weight1, ", w2=", weight2);
    #endif
    result = (value1 + value2) / 2.0;
    break;
            }
    double weightSum = weight1 + weight2;
    if(weightSum <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ ApplyComboOperation: Zero weight sum - w1=", weight1, ", w2=", weight2);
    #endif
    result = (value1 + value2) / 2.0;
    break;
            }
    result = (value1 * weight1 + value2 * weight2) / weightSum;
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ ApplyComboOperation: Weighted - w1=", weight1, ", w2=", weight2, 
                  ", sum=", weightSum, ", normalized result=", result);
    #endif
    break;
        }
            
        default:
            #ifdef ENABLE_DEBUG_LOGS
            Print("❌ ApplyComboOperation: Unknown operation=", operation);
    #endif
    result = (value1 + value2) / 2.0;
    break;
    }
    if(result <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ApplyComboOperation: Invalid result=", result, 
              " for op=", EnumToString(operation));
    #endif
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
        Print("⚠️ ApplyComboOperation: Suspicious result detected");
    Print("   Operation=", EnumToString(operation));
    Print("   v1=", DoubleToString(value1, Digits), 
              ", v2=", DoubleToString(value2, Digits));
    Print("   Result=", DoubleToString(result, Digits), 
              " (min=", DoubleToString(minInput, Digits), 
              ", max=", DoubleToString(maxInput, Digits), ")");
    Print("   Using fallback: average");
    #endif
    result = (value1 + value2) / 2.0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ ApplyComboOperation: v1=", DoubleToString(value1, Digits), 
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
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ GetPresetConfiguration: Unknown preset=", preset, ", using Legacy");
    #endif
    tf1 = COMBO_TF_TRIGGER;
    step1 = COMBO_STEP_SS;
    tf2 = COMBO_TF_PATTERN;
    step2 = COMBO_STEP_SS;
    operation = COMBO_OP_ADD;
    break;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ GetPresetConfiguration: PRESET MODE - Preset=", EnumToString(preset));
    Print("   TF1=", EnumToString(tf1), ", Step1=", EnumToString(step1));
    Print("   TF2=", EnumToString(tf2), ", Step2=", EnumToString(step2));
    #ifdef ENABLE_DEBUG_LOGS
    Print("   Operation=", EnumToString(operation));
    #endif
    #endif
}
ENUM_TIMEFRAMES GetPatternTimeframe() {
        int currentMinutes = PeriodMinutes();
    int patternMinutes = currentMinutes * 4;
    if(patternMinutes > 43200) patternMinutes = 43200;
    ENUM_TIMEFRAMES result;
    if(patternMinutes <= 1) result = PERIOD_M1;
    else if(patternMinutes <= 5) result = PERIOD_M5;
    else if(patternMinutes <= 15) result = PERIOD_M15;
    else if(patternMinutes <= 30) result = PERIOD_M30;
    else if(patternMinutes <= 60) result = PERIOD_H1;
    else if(patternMinutes <= 240) result = PERIOD_H4;
    else if(patternMinutes <= 1440) result = PERIOD_D1;
    else if(patternMinutes <= 10080) result = PERIOD_W1;
    else result = PERIOD_MN1;
    #ifdef ENABLE_DEBUG_LOGS
    Print("GetPatternTimeframe: Current=", currentMinutes, "min, Pattern=", 
          patternMinutes, "min (4x) -> ", result);
    #endif
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
    ENUM_TIMEFRAMES result;
    if(structureMinutes <= 1) result = PERIOD_M1;
    else if(structureMinutes <= 5) result = PERIOD_M5;
    else if(structureMinutes <= 15) result = PERIOD_M15;
    else if(structureMinutes <= 30) result = PERIOD_M30;
    else if(structureMinutes <= 60) result = PERIOD_H1;
    else if(structureMinutes <= 240) result = PERIOD_H4;
    else if(structureMinutes <= 1440) result = PERIOD_D1;
    else if(structureMinutes <= 10080) result = PERIOD_W1;
    else result = PERIOD_MN1;
    #ifdef ENABLE_DEBUG_LOGS
    Print("GetStructureTimeframe: Current=", currentMinutes, "min, Structure=", 
          structureMinutes, "min (16x) -> ", result);
    #endif
    return result;
}

//+------------------------------------------------------------------+
//| Calculate Structure level interval based on base multiplier     |

//|                                                                  |
//| EXAMPLES:                                                        |
//| Base=2: L1=2, L2=4, L3=8, L4=16, L5=32                          |
//| Base=3: L1=3, L2=9, L3=27, L4=81, L5=243                        |
//| Base=4: L1=4, L2=16, L3=64, L4=256, L5=1024                     |
//|                                                                  |
//| USAGE:                                                           |
//| Check from HIGHEST to LOWEST level for proper hierarchy:        |
//| if(step % L5 == 0) → Level 5                                    |
//| else if(step % L4 == 0) → Level 4                               |
//| else if(step % L3 == 0) → Level 3                               |
//| else if(step % L2 == 0) → Level 2                               |
//| else if(step % L1 == 0) → Level 1                               |
//| else → Trigger                                                   |
//+------------------------------------------------------------------+
int CalculateStructureInterval(const int baseMultiplier, const int level) {
        if(baseMultiplier < 2 || baseMultiplier > 9) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Invalid base multiplier: ", baseMultiplier, " (must be 2-9)");
    #endif
    return 0;
    }
    if(level < 1 || level > 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Invalid level: ", level, " (must be 1-5)");
    #endif
    return 0;
    }
    return (int)MathPow(baseMultiplier, level);
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetValidatedBaseMultiplier: Invalid value ", baseMultiplier, 
              " detected, auto-correcting to default: 3");
    #endif
    return 3;    }
    return baseMultiplier;
}
    bool ShouldDrawStepOptimized(const int step, const bool triggerEnabled, const int baseMultiplier) {
        if(triggerEnabled) return true;
    int validatedMultiplier = baseMultiplier;
    if(validatedMultiplier < 2 || validatedMultiplier > 9) {
        validatedMultiplier = 3;    }
    
    return (step % validatedMultiplier == 0);
}
    bool ShouldDrawStep(const int step) {
        if(IsTriggerLevelsEnabled()) return true;
    int baseMultiplier = GetValidatedBaseMultiplier();
    return (step % baseMultiplier == 0);
}

//+------------------------------------------------------------------+
//| Cache for structure intervals to avoid repeated MathPow() calls |

//+------------------------------------------------------------------+
static int g_cachedBaseMultiplier = -1;
    static int g_cachedIntervals[5];
    void GetCachedIntervals(const int baseMultiplier, int &intervals[]) {
        int validatedMultiplier = baseMultiplier;
    if(validatedMultiplier < 2 || validatedMultiplier > 9) {
        validatedMultiplier = 3;
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetCachedIntervals: Invalid base ", baseMultiplier, 
              " auto-corrected to ", validatedMultiplier);
    #endif
    }
    if(g_cachedBaseMultiplier != validatedMultiplier) {        for(int i = 0; i < 5; i++) {
            g_cachedIntervals[i] = CalculateStructureInterval(validatedMultiplier, i + 1);
        }
        g_cachedBaseMultiplier = validatedMultiplier;
    #ifdef ENABLE_DEBUG_LOGS
        Print("📊 Structure intervals calculated for base ", validatedMultiplier, 
              ": L1=", g_cachedIntervals[0], ", L2=", g_cachedIntervals[1], 
              ", L3=", g_cachedIntervals[2], ", L4=", g_cachedIntervals[3], 
              ", L5=", g_cachedIntervals[4]);
    #endif
    }
    ArrayResize(intervals, 5);
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
//| EXAMPLES with Base=4:                                            |
//| Step 4:  Returns 1 (L1 only)                                    |
//| Step 8:  Returns 1 (L1 only)                                    |
//| Step 16: Returns 2 (L2, not L1)                                 |
//| Step 64: Returns 3 (L3, not L2 or L1)                           |
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ GetHighestStructureLevel: Invalid step=", step);
    #endif
    return 0;
    }
    int arraySize = ArraySize(intervals);
    if(arraySize != 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ GetHighestStructureLevel: Invalid intervals array size=", arraySize, " (expected 5)");
    #endif
    return 0;
    }
    for(int i = 0; i < 5; i++) {
        if(intervals[i] <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ GetHighestStructureLevel: Invalid interval[", i, "]=", intervals[i]);
    #endif
    return 0;
        }
    if(i > 0 && intervals[i] <= intervals[i-1]) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ GetHighestStructureLevel: Intervals not in ascending order at index ", i);
    #endif
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
        if(inpShowStructure) {
        int baseMultiplier = GetValidatedBaseMultiplier();
    int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    if(intervals[4] > 0 && stepCount % intervals[4] == 0 && inpShowStructureL5) {
            outColor = inpStructureL5Color;
    outStyle = inpStructureL5Style;
    outWidth = inpStructureL5Width;
    return true;
        }
    if(intervals[3] > 0 && stepCount % intervals[3] == 0 && inpShowStructureL4) {
            outColor = inpStructureL4Color;
    outStyle = inpStructureL4Style;
    outWidth = inpStructureL4Width;
    return true;
        }
    if(intervals[2] > 0 && stepCount % intervals[2] == 0 && inpShowStructureL3) {
            outColor = inpStructureL3Color;
    outStyle = inpStructureL3Style;
    outWidth = inpStructureL3Width;
    return true;
        }
    if(intervals[1] > 0 && stepCount % intervals[1] == 0 && inpShowStructureL2) {
            outColor = inpStructureL2Color;
    outStyle = inpStructureL2Style;
    outWidth = inpStructureL2Width;
    return true;
        }
    if(intervals[0] > 0 && stepCount % intervals[0] == 0 && inpShowStructureL1) {
            outColor = inpStructureL1Color;
    outStyle = inpStructureL1Style;
    outWidth = inpStructureL1Width;
    return true;
        }
    }
    if(triggerEnabled) {
        bool isStructureLevel = false;
    if(inpShowStructure) {
        int baseMultiplier = GetValidatedBaseMultiplier();
    int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    if((intervals[4] > 0 && stepCount % intervals[4] == 0 && inpShowStructureL5) ||
               (intervals[3] > 0 && stepCount % intervals[3] == 0 && inpShowStructureL4) ||
               (intervals[2] > 0 && stepCount % intervals[2] == 0 && inpShowStructureL3) ||
               (intervals[1] > 0 && stepCount % intervals[1] == 0 && inpShowStructureL2) ||
               (intervals[0] > 0 && stepCount % intervals[0] == 0 && inpShowStructureL1)) {
                isStructureLevel = true;
            }
        }
    if(!isStructureLevel) {
            outColor = inpTriggerColor;
    outStyle = inpTriggerStyle;
    outWidth = inpTriggerWidth;
    return true;
        }
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
        int validatedMultiplier = baseMultiplier;
    if(validatedMultiplier < 2 || validatedMultiplier > 9) {
            validatedMultiplier = GetValidatedBaseMultiplier();        }
    int intervals[];
    GetCachedIntervals(validatedMultiplier, intervals);
    if(intervals[4] > 0 && currentStep % intervals[4] == 0 && inpShowStructureL5) {
        return inpStructureL5Color;
        }
    if(intervals[3] > 0 && currentStep % intervals[3] == 0 && inpShowStructureL4) {
        return inpStructureL4Color;
        }
    if(intervals[2] > 0 && currentStep % intervals[2] == 0 && inpShowStructureL3) {
        return inpStructureL3Color;
        }
    if(intervals[1] > 0 && currentStep % intervals[1] == 0 && inpShowStructureL2) {
        return inpStructureL2Color;
        }
    if(intervals[0] > 0 && currentStep % intervals[0] == 0 && inpShowStructureL1) {
        return inpStructureL1Color;
        }
    }
    return clrNONE;}
    void DrawSSLSLevels(const string objectPrefix, const double midpointPrice, 
                    const double ssValue, const double lsValue, const bool lsFirst,
                    const int maxLevelsAbove = 0, const int maxLevelsBelow = 0)
{
        if(ssValue <= 0 || lsValue <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawSSLSLevels: Invalid SS/LS values");
    #endif
    return;
    }
    double stepDistances[2];
    stepDistances[0] = lsFirst ? lsValue : ssValue;
    stepDistances[1] = lsFirst ? ssValue : lsValue;
    double avgStepSize = (ssValue + lsValue) / 2.0;
    int effectiveMaxAbove = (maxLevelsAbove > 0) ? maxLevelsAbove : inpMaxTHLevelsAbove;
    int effectiveMaxBelow = (maxLevelsBelow > 0) ? maxLevelsBelow : inpMaxTHLevelsBelow;
    if(effectiveMaxAbove > MAX_SAFE_LEVELS) effectiveMaxAbove = MAX_SAFE_LEVELS;
    if(effectiveMaxBelow > MAX_SAFE_LEVELS) effectiveMaxBelow = MAX_SAFE_LEVELS;
    double chartPriceMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double chartPriceMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double viewportRange = chartPriceMax - chartPriceMin;
    double vpTop = chartPriceMax + viewportRange;
    double vpBottom = chartPriceMin - viewportRange;
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    bool checkCustomPrice = (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE);
    color midpointColor = clrNONE;
    ENUM_LINE_STYLE midpointStyle = STYLE_SOLID;
    int midpointWidth = 1;
    if(GetPathForLevelOptimized(0, midpointColor, midpointStyle, midpointWidth, triggerEnabled)) {    } else {        midpointColor = inpLSLevelColor;
    midpointStyle = inpLSLevelStyle;
    midpointWidth = inpLSLevelWidth;
    }
    string midpointName = objectPrefix + "SSLS_Midpoint_0";
    if(ObjectFind(0, midpointName) < 0) {
        ObjectCreate(0, midpointName, OBJ_HLINE, 0, 0, midpointPrice);
    ObjectSetInteger(0, midpointName, OBJPROP_COLOR, midpointColor);
    ObjectSetInteger(0, midpointName, OBJPROP_STYLE, midpointStyle);
    ObjectSetInteger(0, midpointName, OBJPROP_WIDTH, midpointWidth);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTED, false);
    if(!g_linesVisible) {
            ObjectSetInteger(0, midpointName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
        
        ObjectSetString(0, midpointName, OBJPROP_TOOLTIP, 
                       "Midpoint (Start) - " + DoubleToString(midpointPrice, GetCachedDigits()));
    } else {
        ObjectSetDouble(0, midpointName, OBJPROP_PRICE, midpointPrice);
    }
    int drawnAbove = 0;
    int logicalStep = 0;
    double cumulative = 0;
    int zoneCountAbove = 0;
    double lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceAbove, 
                               lastTriggerPriceAbove, lastFallbackPriceAbove)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawSSLSLevels: Failed to initialize zone tracking (Above)");
    #endif
    return;    }
    int maxIterations = effectiveMaxAbove * 2;
    int iterations = 0;
    while(drawnAbove < effectiveMaxAbove && iterations < maxIterations) {
        iterations++;
    double dist = stepDistances[logicalStep % 2];
    cumulative += dist;
    logicalStep++;
    double priceLevel = midpointPrice + cumulative;
    #ifdef ENABLE_DEBUG_LOGS
        if(logicalStep == 1) {
            Print("========== MT4 FIRST LEVEL DEBUG ==========");
    Print("Anchor (midpoint): ", DoubleToString(midpointPrice, 10));
    #ifdef ENABLE_DEBUG_LOGS
            Print("Step distance (LS): ", DoubleToString(dist, 10));
    Print("First level price: ", DoubleToString(priceLevel, 10));
    Print("Formula: ", DoubleToString(midpointPrice, 10), " + ", DoubleToString(dist, 10), " = ", DoubleToString(priceLevel, 10));
    Print("===========================================");
    Print("🔵 MT4 FIRST LEVEL: ", DoubleToString(priceLevel, 10), " (LS=", DoubleToString(dist, 10), ")");
    #endif
    }
    #endif
    if(checkCustomPrice) {
        if(priceLevel > g_highestHigh) break;
        }
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    bool isSS = ((logicalStep % 2 == 0) == lsFirst);
    if(!GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {            levelColor = isSS ? inpSSLevelColor : inpLSLevelColor;
    levelStyle = isSS ? inpSSLevelStyle : inpLSLevelStyle;
    levelWidth = isSS ? inpSSLevelWidth : inpLSLevelWidth;
        }
    string levelName = objectPrefix + "SSLS_Above_" + IntegerToString(logicalStep);
    if(priceLevel < vpBottom || priceLevel > vpTop) {
            drawnAbove++;
    continue;
        }
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceLevel);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           (isSS ? "SS " : "LS ") + IntegerToString(logicalStep) + 
                           " (" + DoubleToString(priceLevel, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceLevel);
        }
        
        drawnAbove++;
    if(inpShowMidZones) {
        bool isStructureLevel = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isStructureLevel = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "SSLS_Zone_Above_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceLevel, isStructureLevel, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove,
                                          avgStepSize)) {                zoneCountAbove++;
            }
        }    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "SSLS_Zone_Above_", logicalStep + 1);
    }
    int drawnBelow = 0;
    logicalStep = 0;
    cumulative = 0;
    int zoneCountBelow = 0;
    double lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceBelow, 
                               lastTriggerPriceBelow, lastFallbackPriceBelow)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawSSLSLevels: Failed to initialize zone tracking (Below)");
    #endif
    return;    }
    maxIterations = effectiveMaxBelow * 2;
    iterations = 0;
    while(drawnBelow < effectiveMaxBelow && iterations < maxIterations) {
        iterations++;
    double dist = stepDistances[logicalStep % 2];
    cumulative += dist;
    logicalStep++;
    double priceLevel = midpointPrice - cumulative;
    if(checkCustomPrice) {
        if(priceLevel < g_lowestLow) break;
        }
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    bool isSS = ((logicalStep % 2 == 0) == lsFirst);
    if(!GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {            levelColor = isSS ? inpSSLevelColor : inpLSLevelColor;
    levelStyle = isSS ? inpSSLevelStyle : inpLSLevelStyle;
    levelWidth = isSS ? inpSSLevelWidth : inpLSLevelWidth;
        }
    string levelName = objectPrefix + "SSLS_Below_" + IntegerToString(logicalStep);
    if(priceLevel < vpBottom || priceLevel > vpTop) {
            drawnBelow++;
    continue;
        }
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceLevel);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           (isSS ? "SS " : "LS ") + IntegerToString(logicalStep) + 
                           " (" + DoubleToString(priceLevel, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceLevel);
        }
        
        drawnBelow++;
    if(inpShowMidZones) {
        bool isStructureLevel = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isStructureLevel = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "SSLS_Zone_Below_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceLevel, isStructureLevel, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow,
                                          avgStepSize)) {                zoneCountBelow++;
            }
        }    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "SSLS_Zone_Below_", logicalStep + 1);
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(inpShowMidZones) {
        Print("✅ DrawSSLSLevels: Drew ", zoneCountAbove, " zones above, ", 
              zoneCountBelow, " zones below");
    }
    #endif
    }

//| UNIFIED HELPER: Draw Single Level with Unified Logic             |

//|                                                                  |
//| This function encapsulates the common logic used by all modes   |

//+------------------------------------------------------------------+
bool DrawUnifiedLevel(
    const string levelName,
    const double price,
    const int logicalStep,
    const bool triggerEnabled,
    const bool structureEnabled,
    const int baseMultiplier,
    const color fallbackColor,
    const ENUM_LINE_STYLE fallbackStyle,
    const int fallbackWidth,
    const string tooltip)
{
        color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {    } else if(triggerEnabled) {        levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
    } else {        levelColor = fallbackColor;
    levelStyle = fallbackStyle;
    levelWidth = fallbackWidth;
    }
    if(ObjectFind(0, levelName) < 0) {
        if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, price)) {
        return false;
        }
    }
    
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetDouble(0, levelName, OBJPROP_PRICE, price);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, tooltip);
    return true;
}

//+------------------------------------------------------------------+
//| UNIFIED HELPER: Draw Single Zone with Unified Logic              |

//+------------------------------------------------------------------+
bool DrawUnifiedZone(
    const string zoneName,
    const double currentPrice,
    const int logicalStep,
    const bool triggerEnabled,
    const bool structureEnabled,
    const int baseMultiplier,
    const color levelColor,
    double &lastDrawnPrice,
    double &lastTriggerPrice)
{
    if(!inpShowMidZones) return false;
    bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                isCurrentStructure = true;
    break;
            }
        }
    }
    return CreateZoneWithSmartFallback(zoneName, currentPrice, isCurrentStructure, levelColor,
                                      structureEnabled, triggerEnabled,
                                      lastDrawnPrice, lastTriggerPrice, lastDrawnPrice);
}

//+------------------------------------------------------------------+
void DrawMLevels(const string objectPrefix, const double midpointPrice, const double controlDistance,
                 const int maxLevelsAbove = 0, const int maxLevelsBelow = 0)
{
        if(controlDistance <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawMLevels: Invalid control distance");
    #endif
    return;
    }
    int effectiveMaxAbove = (maxLevelsAbove > 0) ? maxLevelsAbove : inpMaxTHLevelsAbove;
    int effectiveMaxBelow = (maxLevelsBelow > 0) ? maxLevelsBelow : inpMaxTHLevelsBelow;
    if(effectiveMaxAbove > MAX_SAFE_LEVELS) effectiveMaxAbove = MAX_SAFE_LEVELS;
    if(effectiveMaxBelow > MAX_SAFE_LEVELS) effectiveMaxBelow = MAX_SAFE_LEVELS;
    double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = vpChartMax - vpChartMin;
    double vpTop = vpChartMax + vpRange;
    double vpBottom = vpChartMin - vpRange;
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    bool isCustomPriceMode = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE);
    color midpointColor = clrNONE;
    ENUM_LINE_STYLE midpointStyle = STYLE_SOLID;
    int midpointWidth = 1;
    if(GetPathForLevelOptimized(0, midpointColor, midpointStyle, midpointWidth, triggerEnabled)) {    } else {        midpointColor = inpCLevelColor;
    midpointStyle = inpCLevelStyle;
    midpointWidth = inpCLevelWidth;
    }
    string midpointName = objectPrefix + "M_Midpoint_0";
    if(ObjectFind(0, midpointName) < 0) {
        ObjectCreate(0, midpointName, OBJ_HLINE, 0, 0, midpointPrice);
    ObjectSetInteger(0, midpointName, OBJPROP_COLOR, midpointColor);
    ObjectSetInteger(0, midpointName, OBJPROP_STYLE, midpointStyle);
    ObjectSetInteger(0, midpointName, OBJPROP_WIDTH, midpointWidth);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTED, false);
    if(!g_linesVisible) {
            ObjectSetInteger(0, midpointName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
        
        ObjectSetString(0, midpointName, OBJPROP_TOOLTIP, 
                       "Midpoint (Start) - " + DoubleToString(midpointPrice, GetCachedDigits()));
    } else {
        ObjectSetDouble(0, midpointName, OBJPROP_PRICE, midpointPrice);
    }
    int logicalStep = 1;
    int drawnAbove = 0;
    int zoneCountAbove = 0;
    double priceAbove = midpointPrice + controlDistance;
    double lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceAbove, 
                               lastTriggerPriceAbove, lastFallbackPriceAbove)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawMLevels: Failed to initialize zone tracking (Above)");
    #endif
    return;    }
    int maxIterations = effectiveMaxAbove * 2;
    int iterations = 0;
    while(drawnAbove < effectiveMaxAbove && (isCustomPriceMode || priceAbove <= g_highestHigh) && iterations < maxIterations) {
        iterations++;
    bool isM = (logicalStep % 3 == 0);
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    priceAbove += controlDistance;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    priceAbove += controlDistance;
    continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = isM ? inpMLevelColor : inpCLevelColor;
    levelStyle = isM ? inpMLevelStyle : inpCLevelStyle;
    levelWidth = isM ? inpMLevelWidth : inpCLevelWidth;
        }
    if(priceAbove < vpBottom || priceAbove > vpTop) {
            drawnAbove++;
    logicalStep++;
    priceAbove += controlDistance;
    continue;
        }
    {
        string levelName = objectPrefix + "M_Above_" + IntegerToString(logicalStep);
    if(ObjectFind(0, levelName) < 0) {
                ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceAbove);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                               "Level " + IntegerToString(logicalStep) + 
                               " (" + DoubleToString(priceAbove, GetCachedDigits()) + ")");
            } else {
                ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceAbove);
            };
    drawnAbove++;
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(inpShowStructure) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                            isCurrentStructure = true;
    break;
                        }
                    }
                }
    string zoneName = objectPrefix + "M_Zone_Above_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceAbove, isCurrentStructure, levelColor,
                                              structureEnabled, triggerEnabled,
                                              lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove,
                                              controlDistance)) {                    zoneCountAbove++;
                }
            }
        }
    logicalStep++;
    priceAbove += controlDistance;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "M_Zone_Above_", logicalStep);
    }
    logicalStep = 1;
    int drawnBelow = 0;
    int zoneCountBelow = 0;
    double priceBelow = midpointPrice - controlDistance;
    double lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceBelow, 
                               lastTriggerPriceBelow, lastFallbackPriceBelow)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawMLevels: Failed to initialize zone tracking (Below)");
    #endif
    return;    }
    maxIterations = effectiveMaxBelow * 2;
    iterations = 0;
    while(drawnBelow < effectiveMaxBelow && (isCustomPriceMode || priceBelow >= g_lowestLow) && iterations < maxIterations) {
        iterations++;
    bool isM2 = (logicalStep % 3 == 0);
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    priceBelow -= controlDistance;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    priceBelow -= controlDistance;
    continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = isM2 ? inpMLevelColor : inpCLevelColor;
    levelStyle = isM2 ? inpMLevelStyle : inpCLevelStyle;
    levelWidth = isM2 ? inpMLevelWidth : inpCLevelWidth;
        }
    if(priceBelow < vpBottom || priceBelow > vpTop) {
            drawnBelow++;
    logicalStep++;
    priceBelow -= controlDistance;
    continue;
        }
    {
        string levelName = objectPrefix + "M_Below_" + IntegerToString(logicalStep);
    if(ObjectFind(0, levelName) < 0) {
                ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceBelow);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                               "Level " + IntegerToString(logicalStep) + 
                               " (" + DoubleToString(priceBelow, GetCachedDigits()) + ")");
            } else {
                ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceBelow);
            };
    drawnBelow++;
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(inpShowStructure) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                            isCurrentStructure = true;
    break;
                        }
                    }
                }
    string zoneName = objectPrefix + "M_Zone_Below_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceBelow, isCurrentStructure, levelColor,
                                              structureEnabled, triggerEnabled,
                                              lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow,
                                              controlDistance)) {                    zoneCountBelow++;
                }
            }
        }
    logicalStep++;
    priceBelow -= controlDistance;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "M_Zone_Below_", logicalStep);
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(inpShowMidZones) {
        Print("✅ DrawMLevels: Drew ", zoneCountAbove, " zones above, ", 
              zoneCountBelow, " zones below");
    }
    #endif
    }

#include "DrawingPipeline.mqh"
void DrawTHLevelsWithStep(const string objectPrefix, const double midpointPrice, 
                          const double stepSizePrice, const string modeName,
                          const int maxLevelsAbove = 0, const int maxLevelsBelow = 0)
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("DrawTHLevelsWithStep: Mode=", modeName, " Mid=", DoubleToString(midpointPrice, Digits),
          " Step=", DoubleToString(stepSizePrice, Digits), " MaxAbove=", maxLevelsAbove, " MaxBelow=", maxLevelsBelow);
    #endif
    if(stepSizePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawTHLevelsWithStep: Invalid step size - ABORTING");
    #endif
    return;
    }
    int effectiveMaxAbove = (maxLevelsAbove > 0) ? maxLevelsAbove : inpMaxTHLevelsAbove;
    int effectiveMaxBelow = (maxLevelsBelow > 0) ? maxLevelsBelow : inpMaxTHLevelsBelow;
    if(effectiveMaxAbove > MAX_SAFE_LEVELS) effectiveMaxAbove = MAX_SAFE_LEVELS;
    if(effectiveMaxBelow > MAX_SAFE_LEVELS) effectiveMaxBelow = MAX_SAFE_LEVELS;
    double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = vpChartMax - vpChartMin;
    double vpTop = vpChartMax + vpRange;
    double vpBottom = vpChartMin - vpRange;
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    bool isCustomPriceMode = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE);
    color midpointColor = clrNONE;
    ENUM_LINE_STYLE midpointStyle = STYLE_SOLID;
    int midpointWidth = 1;
    if(GetPathForLevelOptimized(0, midpointColor, midpointStyle, midpointWidth, triggerEnabled)) {    } else {        midpointColor = inpCLevelColor;
    midpointStyle = inpCLevelStyle;
    midpointWidth = inpCLevelWidth;
    }
    string midpointName = objectPrefix + modeName + "_Midpoint_0";
    if(ObjectFind(0, midpointName) < 0) {
        ObjectCreate(0, midpointName, OBJ_HLINE, 0, 0, midpointPrice);
    ObjectSetInteger(0, midpointName, OBJPROP_COLOR, midpointColor);
    ObjectSetInteger(0, midpointName, OBJPROP_STYLE, midpointStyle);
    ObjectSetInteger(0, midpointName, OBJPROP_WIDTH, midpointWidth);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTED, false);
    ObjectSetString(0, midpointName, OBJPROP_TOOLTIP, 
                       "Midpoint (Start) - " + DoubleToString(midpointPrice, GetCachedDigits()));
    } else {
        ObjectSetDouble(0, midpointName, OBJPROP_PRICE, midpointPrice);
    }
    int logicalStep = 1;
    int drawnAbove = 0;
    int zoneCountAbove = 0;
    double priceAbove = midpointPrice + stepSizePrice;
    double lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceAbove, 
                               lastTriggerPriceAbove, lastFallbackPriceAbove)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawTHLevelsWithStep: Failed to initialize zone tracking (Above)");
    #endif
    return;    }
    double maxPriceLimit = (isCustomPriceMode) ? 0 : g_highestHigh;
    double minPriceLimit = (isCustomPriceMode) ? 0 : g_lowestLow;
    int maxIterations = effectiveMaxAbove * 2;
    int iterations = 0;
    while(drawnAbove < effectiveMaxAbove && (isCustomPriceMode || priceAbove <= maxPriceLimit) && iterations < maxIterations) {
        iterations++;
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    priceAbove += stepSizePrice;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    priceAbove += stepSizePrice;
    continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = inpCLevelColor;
    levelStyle = inpCLevelStyle;
    levelWidth = inpCLevelWidth;
        }
    if(priceAbove < vpBottom || priceAbove > vpTop) {
            drawnAbove++;
    logicalStep++;
    priceAbove += stepSizePrice;
    continue;
        }
    string levelName = objectPrefix + modeName + "_Above_" + IntegerToString(logicalStep);
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceAbove);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           "Level " + IntegerToString(logicalStep) + 
                           " (" + DoubleToString(priceAbove, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceAbove);
        };
    drawnAbove++;
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + modeName + "_Zone_Above_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceAbove, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove,
                                          stepSizePrice)) {                zoneCountAbove++;
            }
        }
        
        logicalStep++;
    priceAbove += stepSizePrice;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + modeName + "_Zone_Above_", logicalStep);
    }
    logicalStep = 1;
    int drawnBelow = 0;
    int zoneCountBelow = 0;
    double priceBelow = midpointPrice - stepSizePrice;
    double lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow;
    if(!InitializeZoneTracking(midpointPrice, lastStructurePriceBelow, 
                               lastTriggerPriceBelow, lastFallbackPriceBelow)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawTHLevelsWithStep: Failed to initialize zone tracking (Below)");
    #endif
    return;    }
    maxIterations = effectiveMaxBelow * 2;
    iterations = 0;
    while(drawnBelow < effectiveMaxBelow && (isCustomPriceMode || priceBelow >= minPriceLimit) && priceBelow > 0 && iterations < maxIterations) {
        iterations++;
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    priceBelow -= stepSizePrice;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    priceBelow -= stepSizePrice;
    continue;
            }
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = inpCLevelColor;
    levelStyle = inpCLevelStyle;
    levelWidth = inpCLevelWidth;
        }
    if(priceBelow < vpBottom || priceBelow > vpTop) {
            drawnBelow++;
    logicalStep++;
    priceBelow -= stepSizePrice;
    continue;
        }
    string levelName = objectPrefix + modeName + "_Below_" + IntegerToString(logicalStep);
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceBelow);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           "Level " + IntegerToString(logicalStep) + 
                           " (" + DoubleToString(priceBelow, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceBelow);
        };
    drawnBelow++;
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + modeName + "_Zone_Below_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, priceBelow, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow,
                                          stepSizePrice)) {                zoneCountBelow++;
            }
        }
        
        logicalStep++;
    priceBelow -= stepSizePrice;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + modeName + "_Zone_Below_", logicalStep);
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawTHLevelsWithStep COMPLETED for mode: ", modeName);
    Print("   Levels drawn: Above=", drawnAbove, ", Below=", drawnBelow);
    Print("   Zones drawn: Above=", zoneCountAbove, ", Below=", zoneCountBelow);
    Print("═══════════════════════════════════════════════════════════");
    #endif
    }
    void DrawMEqualLevels(const string objectPrefix, const double midpointPrice, const double mDistance,
                      const int maxLevelsAbove = 0, const int maxLevelsBelow = 0)
{
        if(mDistance <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawMEqualLevels: Invalid M distance");
    #endif
    return;
    }
    int effectiveMaxAbove = (maxLevelsAbove > 0) ? maxLevelsAbove : inpMaxTHLevelsAbove;
    int effectiveMaxBelow = (maxLevelsBelow > 0) ? maxLevelsBelow : inpMaxTHLevelsBelow;
    if(effectiveMaxAbove > MAX_SAFE_LEVELS) effectiveMaxAbove = MAX_SAFE_LEVELS;
    if(effectiveMaxBelow > MAX_SAFE_LEVELS) effectiveMaxBelow = MAX_SAFE_LEVELS;
    double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = vpChartMax - vpChartMin;
    double vpTop = vpChartMax + vpRange;
    double vpBottom = vpChartMin - vpRange;
    bool triggerEnabled = IsTriggerLevelsEnabled();
    color midpointColor;
    ENUM_LINE_STYLE midpointStyle;
    int midpointWidth;
    if(GetPathForLevelOptimized(0, midpointColor, midpointStyle, midpointWidth, triggerEnabled)) {    } else {        midpointColor = inpMLevelColor;
    midpointStyle = inpMLevelStyle;
    midpointWidth = inpMLevelWidth;
    }
    string midpointName = objectPrefix + "MEq_Midpoint_0";
    if(ObjectFind(0, midpointName) < 0) {
        ObjectCreate(0, midpointName, OBJ_HLINE, 0, 0, midpointPrice);
    ObjectSetInteger(0, midpointName, OBJPROP_COLOR, midpointColor);
    ObjectSetInteger(0, midpointName, OBJPROP_STYLE, midpointStyle);
    ObjectSetInteger(0, midpointName, OBJPROP_WIDTH, midpointWidth);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, midpointName, OBJPROP_SELECTED, false);
    ObjectSetString(0, midpointName, OBJPROP_TOOLTIP, 
                       "M-Equal Midpoint (Start) - " + DoubleToString(midpointPrice, GetCachedDigits()));
    } else {
        ObjectSetDouble(0, midpointName, OBJPROP_PRICE, midpointPrice);
    }
    int step = 1;
    double price = midpointPrice + mDistance;
    double lastDrawnPriceAbove = midpointPrice;
    int zoneCountAbove = 0;
    int maxIterations = effectiveMaxAbove * 2;
    int iterations = 0;
    while(step <= effectiveMaxAbove && (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE || price <= g_highestHigh) && iterations < maxIterations) {
        iterations++;
    if(price < vpBottom || price > vpTop) {
            step++;
    price += mDistance;
    continue;
        }
    string levelName = objectPrefix + "MEq_Above_" + IntegerToString(step);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(!GetPathForLevelOptimized(step, levelColor, levelStyle, levelWidth, triggerEnabled)) {
        if(triggerEnabled) {
                levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
            } else {
                levelColor = inpStructureL1Color;
    levelStyle = inpStructureL1Style;
    levelWidth = inpStructureL1Width;
            }
        }
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           "Level " + IntegerToString(step) + 
                           " (" + DoubleToString(price, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, price);
        };
    if(inpShowMidZones) {
        string zoneName = objectPrefix + "MEq_Zone_Above_" + IntegerToString(step);
    if(CreateSimpleZone(zoneName, lastDrawnPriceAbove, price, levelColor)) {
                zoneCountAbove++;
            }
        }
        
        lastDrawnPriceAbove = price;
    step++;
    price += mDistance;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "MEq_Zone_Above_", step);
    }
    step = 1;
    price = midpointPrice - mDistance;
    double lastDrawnPriceBelow = midpointPrice;
    int zoneCountBelow = 0;
    maxIterations = effectiveMaxBelow * 2;
    iterations = 0;
    while(step <= effectiveMaxBelow && (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE || price >= g_lowestLow) && iterations < maxIterations) {
        iterations++;
    if(price < vpBottom || price > vpTop) {
            step++;
    price -= mDistance;
    continue;
        }
    string levelName = objectPrefix + "MEq_Below_" + IntegerToString(step);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(!GetPathForLevelOptimized(step, levelColor, levelStyle, levelWidth, triggerEnabled)) {
        if(triggerEnabled) {
                levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
            } else {
                levelColor = inpStructureL1Color;
    levelStyle = inpStructureL1Style;
    levelWidth = inpStructureL1Width;
            }
        }
    if(ObjectFind(0, levelName) < 0) {
            ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                           "Level " + IntegerToString(step) + 
                           " (" + DoubleToString(price, GetCachedDigits()) + ")");
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, price);
        };
    if(inpShowMidZones) {
        string zoneName = objectPrefix + "MEq_Zone_Below_" + IntegerToString(step);
    if(CreateSimpleZone(zoneName, lastDrawnPriceBelow, price, levelColor)) {
                zoneCountBelow++;
            }
        }
        
        lastDrawnPriceBelow = price;
    step++;
    price -= mDistance;
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "MEq_Zone_Below_", step);
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(inpShowMidZones) {
        Print("✅ DrawMEqualLevels: Drew ", zoneCountAbove, " zones above, ", 
              zoneCountBelow, " zones below");
    }
    #endif
    }

//+------------------------------------------------------------------+
//| Draw Factor boundary lines (Historical High/Low reference)       |

//+------------------------------------------------------------------+
void DrawFactorBoundaryLines(const string objectPrefix, const double highPrice, 
                              const double lowPrice, const double factor, const double stepSize)
{
        if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {        ObjectDelete(0, objectPrefix + "Factor_High");
    ObjectDelete(0, objectPrefix + "Factor_Low");
    ObjectDelete(0, objectPrefix + "Factor_High_Label");
    ObjectDelete(0, objectPrefix + "Factor_Low_Label");
    return;
    }
    double pipSize = (GetCachedDigits() <= 3) ? 0.01 : 0.0001;
    double rangePips = (highPrice - lowPrice) / pipSize;
    double stepPips = stepSize / pipSize;
    string highLineName = objectPrefix + "Factor_High";
    if(ObjectFind(0, highLineName) < 0) {
        ObjectCreate(0, highLineName, OBJ_HLINE, 0, 0, highPrice);
    }
    ObjectSetDouble(0, highLineName, OBJPROP_PRICE, highPrice);
    ObjectSetInteger(0, highLineName, OBJPROP_COLOR, inpHighColor);
    ObjectSetInteger(0, highLineName, OBJPROP_STYLE, inpHighStyle);
    ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, inpHighWidth);
    ObjectSetInteger(0, highLineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, highLineName, OBJPROP_SELECTED, false);
    ObjectSetString(0, highLineName, OBJPROP_TOOLTIP, 
        StringFormat("Historical HIGH | %s | Range: %.0f pips", 
            DoubleToString(highPrice, GetCachedDigits()), rangePips));
    string lowLineName = objectPrefix + "Factor_Low";
    if(ObjectFind(0, lowLineName) < 0) {
        ObjectCreate(0, lowLineName, OBJ_HLINE, 0, 0, lowPrice);
    }
    ObjectSetDouble(0, lowLineName, OBJPROP_PRICE, lowPrice);
    ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, inpLowColor);
    ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, inpLowStyle);
    ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, inpLowWidth);
    ObjectSetInteger(0, lowLineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lowLineName, OBJPROP_SELECTED, false);
    ObjectSetString(0, lowLineName, OBJPROP_TOOLTIP, 
        StringFormat("Historical LOW | %s | Range: %.0f pips", 
            DoubleToString(lowPrice, GetCachedDigits()), rangePips));
    string highLabelName = objectPrefix + "Factor_High_Label";
    if(ObjectFind(0, highLabelName) < 0) {
        ObjectCreate(0, highLabelName, OBJ_TEXT, 0, TimeCurrent(), highPrice);
    }
    ObjectSetDouble(0, highLabelName, OBJPROP_PRICE, highPrice);
    ObjectSetInteger(0, highLabelName, OBJPROP_TIME, TimeCurrent());
    ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, inpHighColor);
    ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, highLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetString(0, highLabelName, OBJPROP_FONT, "Arial");
    ObjectSetString(0, highLabelName, OBJPROP_TEXT, 
        StringFormat("  HIGH %s | Range: %.0f pips | F=%.2f | Step: %.1f pips", 
            DoubleToString(highPrice, GetCachedDigits()), rangePips, factor, stepPips));
    ObjectSetInteger(0, highLabelName, OBJPROP_SELECTABLE, false);
    string lowLabelName = objectPrefix + "Factor_Low_Label";
    if(ObjectFind(0, lowLabelName) < 0) {
        ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, TimeCurrent(), lowPrice);
    }
    ObjectSetDouble(0, lowLabelName, OBJPROP_PRICE, lowPrice);
    ObjectSetInteger(0, lowLabelName, OBJPROP_TIME, TimeCurrent());
    ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, inpLowColor);
    ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, lowLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetString(0, lowLabelName, OBJPROP_FONT, "Arial");
    ObjectSetString(0, lowLabelName, OBJPROP_TEXT, 
        StringFormat("  LOW %s | Range: %.0f pips | F=%.2f | Step: %.1f pips", 
            DoubleToString(lowPrice, GetCachedDigits()), rangePips, factor, stepPips));
    ObjectSetInteger(0, lowLabelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw Factor levels with perfect equal spacing (aligned)          |

//| Ensures all spacing is equal including at chart boundaries       |
//+------------------------------------------------------------------+
//| Draw Factor Levels with Harmonic Alternating Pattern             |

//| Alternates between Base Step (÷2) and Large Step (÷ratio)        |
//| Creates macro symmetry with micro variation                       |
//+------------------------------------------------------------------+
void DrawFactorLevelsHarmonic(const string objectPrefix, const double highPrice, 
                              const double lowPrice, const double factor, 
                              const double baseStepSize, const double harmonicRatio)
{
        if(StringLen(objectPrefix) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Empty object prefix");
    #endif
    return;
    }
    if(highPrice <= 0 || lowPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Invalid prices - High=", highPrice, ", Low=", lowPrice);
    #endif
    return;
    }
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Invalid range - High must be > Low");
    #endif
    return;
    }
    if(baseStepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Invalid base step size: ", baseStepSize);
    #endif
    return;
    }
    if(harmonicRatio < MIN_HARMONIC_RATIO) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Ratio too small (", harmonicRatio, 
              ") - must be >= ", MIN_HARMONIC_RATIO, " for meaningful alternation");
    #endif
    return;
    }
    if(harmonicRatio > MAX_HARMONIC_RATIO) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Ratio too large (", harmonicRatio, 
              ") - must be <= ", MAX_HARMONIC_RATIO);
    #endif
    return;
    }
    double largeStepSize = baseStepSize * harmonicRatio;
    double range = highPrice - lowPrice;
    if(largeStepSize > range) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ DrawFactorLevelsHarmonic: Large step (", largeStepSize, 
              ") exceeds range (", range, ") - adjusting");
    #endif
    largeStepSize = range * 0.5;    }
    double midpoint = NormalizeDouble((highPrice + lowPrice) / 2.0, GetCachedDigits());
    #ifdef ENABLE_DEBUG_LOGS
    Print("═══ DrawFactorLevelsHarmonic ═══");
    Print("High=", highPrice, ", Low=", lowPrice, ", Range=", range);
    Print("Midpoint=", midpoint, ", Factor=", factor);
    Print("BaseStep=", baseStepSize, ", LargeStep=", largeStepSize);
    Print("Ratio=", harmonicRatio, " (", DoubleToString((harmonicRatio - 1.0) * 100, 1), "% larger)");
    #endif
    string midName = objectPrefix + "Factor_Mid_0";
    if(ObjectFind(0, midName) < 0) {
        if(!ObjectCreate(0, midName, OBJ_HLINE, 0, 0, midpoint)) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ Failed to create midpoint level. Error: ", GetLastError());
    #endif
    return;
        }
    ObjectSetInteger(0, midName, OBJPROP_COLOR, C'255,140,0');
    ObjectSetInteger(0, midName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, midName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, midName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, midName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, midName, OBJPROP_BACK, false);
    ObjectSetString(0, midName, OBJPROP_TOOLTIP, 
            StringFormat("🎯 Harmonic Center | %s | F=%.2f | R=%.3f", 
                DoubleToString(midpoint, GetCachedDigits()), factor, harmonicRatio));
    } else {
        ObjectSetDouble(0, midName, OBJPROP_PRICE, midpoint);
    }
    double stepPattern[2];
    stepPattern[0] = baseStepSize;
    stepPattern[1] = largeStepSize;
    double halfRange = range / 2.0;
    double avgStep = (baseStepSize + largeStepSize) / 2.0;
    int maxLevelsPerSide = (int)MathCeil(halfRange / avgStep);
    const int MAX_HARMONIC_LEVELS = 2500;
    if(maxLevelsPerSide > MAX_HARMONIC_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Clamping levels from ", maxLevelsPerSide, " to ", MAX_HARMONIC_LEVELS);
    #endif
    maxLevelsPerSide = MAX_HARMONIC_LEVELS;
    }
    if(baseStepSize < GetCachedPoint() * 2) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonic: Base step too small (", baseStepSize, 
              ") - must be >= ", Point * 2);
    #endif
    return;
    }
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double cumulative = 0;
    int levelsAbove = 0;
    int iterationCount = 0;
    for(int i = 0; i < maxLevelsPerSide && iterationCount < MAX_HARMONIC_LEVELS * 2; i++, iterationCount++) {
        double step = stepPattern[i % 2];
    cumulative += step;
    double priceLevel = midpoint + cumulative;
    if(priceLevel > highPrice) {
        #ifdef ENABLE_DEBUG_LOGS
            if(i == 0) Print("⚠️ First level above midpoint exceeds high - step too large");
    #endif
    break;
        }
    priceLevel = NormalizeDouble(priceLevel, GetCachedDigits());
    bool isBase = (i % 2 == 0);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    bool shouldDraw = true;
    int logicalStep = i + 1;
    levelColor = isBase ? inpHarmonicBaseColor : inpHarmonicLargeColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = isBase ? inpHarmonicBaseWidth : inpHarmonicLargeWidth;
    string levelName = objectPrefix + "Factor_Up_" + IntegerToString(i + 1);
    if(ObjectFind(0, levelName) < 0) {
            if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceLevel)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ Failed to create level above ", i + 1, ". Error: ", GetLastError());
    #endif
    continue;
            }
            ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                StringFormat("%s Step %d | %s | F=%.2f | Δ=%.1f", 
                    (isBase ? "📏 Base" : "📐 Large"), i + 1, 
                    DoubleToString(priceLevel, GetCachedDigits()), factor, step / GetCachedPoint()));
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceLevel);
        }
        
        levelsAbove++;
    }    
    cumulative = 0;
    int levelsBelow = 0;
    iterationCount = 0;
    for(int i = 0; i < maxLevelsPerSide && iterationCount < MAX_HARMONIC_LEVELS * 2; i++, iterationCount++) {
        double step = stepPattern[i % 2];
    cumulative += step;
    double priceLevel = midpoint - cumulative;
    if(priceLevel < lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
            if(i == 0) Print("⚠️ First level below midpoint goes below low - step too large");
    #endif
    break;
        }
    priceLevel = NormalizeDouble(priceLevel, GetCachedDigits());
    bool isBase = (i % 2 == 0);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    int logicalStep = i + 1;
    levelColor = isBase ? inpHarmonicBaseColor : inpHarmonicLargeColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = isBase ? inpHarmonicBaseWidth : inpHarmonicLargeWidth;
    string levelName = objectPrefix + "Factor_Down_" + IntegerToString(i + 1);
    if(ObjectFind(0, levelName) < 0) {
            if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, priceLevel)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ Failed to create level below ", i + 1, ". Error: ", GetLastError());
    #endif
    continue;
            }
            ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                StringFormat("%s Step %d | %s | F=%.2f | Δ=%.1f", 
                    (isBase ? "📏 Base" : "📐 Large"), i + 1, 
                    DoubleToString(priceLevel, GetCachedDigits()), factor, step / GetCachedPoint()));
        } else {
            ObjectSetDouble(0, levelName, OBJPROP_PRICE, priceLevel);
        }
        
        levelsBelow++;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawFactorLevelsHarmonic: Drew ", levelsAbove, " levels above, ", 
          levelsBelow, " levels below midpoint");
    Print("Total: ", (levelsAbove + levelsBelow + 1), " levels (including midpoint)");
    #endif
    }

//+------------------------------------------------------------------+
void DrawFactorLevelsAligned(const string objectPrefix, const double highPrice, 
                             const double lowPrice, const double factor, const double stepSize)
{
        if(StringLen(objectPrefix) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: Empty object prefix");
    #endif
    return;
    }
    if(highPrice <= 0 || lowPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: Invalid prices - High=", highPrice, ", Low=", lowPrice);
    #endif
    return;
    }
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: Invalid range - High (", highPrice, ") must be greater than Low (", lowPrice, ")");
    #endif
    return;
    }
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: Invalid step size: ", stepSize);
    #endif
    return;
    }
    double currentPrice = Bid;
    double distToHigh = MathAbs(currentPrice - highPrice);
    double distToLow = MathAbs(currentPrice - lowPrice);
    bool startFromHigh = (distToHigh > distToLow);
    #ifdef ENABLE_DEBUG_LOGS
    Print("Factor Direction: Price=", DoubleToString(currentPrice, Digits),
          ", DistHigh=", DoubleToString(distToHigh, Digits),
          ", DistLow=", DoubleToString(distToLow, Digits),
          ", Start=", (startFromHigh ? "HIGH" : "LOW"));
    #endif
    double range = highPrice - lowPrice;
    int totalLevels = (int)MathFloor(range / stepSize);
    if(totalLevels <= 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: Not enough space (totalLevels=", totalLevels, 
              ", range=", DoubleToString(range, Digits), 
              ", stepSize=", DoubleToString(stepSize, Digits), ")");
    #endif
    return;
    }
    const int MAX_FACTOR_LEVELS = 5000;
    if(totalLevels > MAX_FACTOR_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevelsAligned: WARNING - Too many levels (", totalLevels, 
              "), clamping to ", MAX_FACTOR_LEVELS);
    #endif
    totalLevels = MAX_FACTOR_LEVELS;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("DrawFactorLevelsAligned: High=", highPrice, ", Low=", lowPrice, 
          ", Factor=", factor, ", StepSize=", stepSize, ", TotalLevels=", totalLevels,
          ", StartFrom=", (startFromHigh ? "HIGH" : "LOW"));
    #endif
    double startPrice = startFromHigh ? highPrice : lowPrice;
    double direction = startFromHigh ? -1.0 : 1.0;
    int levelsDrawn = 0;
    int zoneCount = 0;
    double halfStep = stepSize / 2.0;
    double zoneHeight = halfStep * 0.25;
    for(int i = 1; i <= totalLevels; i++) {
        double levelPrice = startPrice + (direction * stepSize * i);
    if(levelPrice < lowPrice || levelPrice > highPrice) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ Level ", i, " outside range: ", DoubleToString(levelPrice, Digits));
    #endif
    continue;        }
    double normalizedPrice = NormalizeDouble(levelPrice, GetCachedDigits());
    if(inpShowMidZones) {
        double prevPrice = (i == 1) ? startPrice : (startPrice + (direction * stepSize * (i-1)));
    prevPrice = NormalizeDouble(prevPrice, GetCachedDigits());
    double midPoint = (normalizedPrice + prevPrice) / 2.0;
    double zoneTop = midPoint + zoneHeight;
    double zoneBottom = midPoint - zoneHeight;
    zoneTop = NormalizeDouble(zoneTop, GetCachedDigits());
    zoneBottom = NormalizeDouble(zoneBottom, GetCachedDigits());
    if(zoneTop <= highPrice && zoneBottom >= lowPrice) {
        string zoneName = objectPrefix + "Factor_Zone_" + IntegerToString(i);
    if(CreateFactorMidZone(zoneName, zoneTop, zoneBottom, 
                                      inpFactorLevelColor,                                      inpMidZoneStyle,                                      inpMidZoneTransparency)) {
                    zoneCount++;
    #ifdef ENABLE_DEBUG_LOGS
                    Print("✅ Zone ", i, ": Between ", DoubleToString(prevPrice, Digits),
                          " and ", DoubleToString(normalizedPrice, Digits),
                          " | Mid=", DoubleToString(midPoint, Digits),
                          " | Height=", DoubleToString(zoneHeight, Digits),
                          " | Style=", EnumToString(inpMidZoneStyle));
    #endif
    }
            }
        }
    string levelName = objectPrefix + "Factor_" + IntegerToString(i);
    bool shouldShowLine = !IsTriggerLevelsEnabled();
    bool objectExists = (ObjectFind(0, levelName) >= 0);
    if(shouldShowLine) {            if(!objectExists) {
                if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("DrawFactorLevelsAligned: Failed to create level ", i, ", Error: ", GetLastError());
    #endif
    continue;
                }
            }
    ObjectSetDouble(0, levelName, OBJPROP_PRICE, normalizedPrice);
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, inpFactorLevelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, inpFactorLevelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, inpFactorLevelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, levelName, OBJPROP_ZORDER, 1);
    if(!g_linesVisible) {
                ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            } else {
                ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            }
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, 
                StringFormat("Factor Level %d | %s | F=%.2f", 
                    i, DoubleToString(normalizedPrice, GetCachedDigits()), factor));
    levelsDrawn++;
        } else {
        if(objectExists) {
                ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);            }
        }
    }
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "Factor_Zone_", totalLevels + 1);
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawFactorLevelsAligned: Drew ", levelsDrawn, " levels and ", zoneCount, " zones");
    Print("   halfStep=", DoubleToString(halfStep, Digits), 
          ", zoneHeight=", DoubleToString(zoneHeight, Digits), " (25% of halfStep = 12.5% each side)");
    #endif
    }

//+------------------------------------------------------------------+
//| Draw Harmonic Factor levels FROM CENTER (supports Custom Price) |

//| Alternates between base and large steps from center              |
//+------------------------------------------------------------------+
void DrawFactorLevelsHarmonicFromCenter(const string objectPrefix, const double centerPrice,
                                        const double highPrice, const double lowPrice,
                                        const double factor, const double baseStepSize,
                                        const double harmonicRatio,
                                        const int maxLevelsAbove, const int maxLevelsBelow)
{
        if(StringLen(objectPrefix) == 0 || centerPrice <= 0 || highPrice <= 0 || lowPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Invalid inputs");
    #endif
    return;
    }
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Invalid range - High must be > Low");
    #endif
    return;
    }
    if(baseStepSize <= 0 || harmonicRatio < MIN_HARMONIC_RATIO || harmonicRatio > MAX_HARMONIC_RATIO) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Invalid step or ratio");
    #endif
    return;
    }
    if(maxLevelsAbove < 1 || maxLevelsBelow < 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Invalid level counts");
    #endif
    return;
    }
    double historicalRange = highPrice - lowPrice;
    double currentPrice = iClose(_Symbol, _Period, 0);
    double viewportTop = currentPrice + (historicalRange * 10.0);
    double viewportBottom = currentPrice - (historicalRange * 10.0);
    int safeMaxAbove = maxLevelsAbove;
    int safeMaxBelow = maxLevelsBelow;
    if(centerPrice > viewportTop || centerPrice < viewportBottom) {
        safeMaxAbove = (int)MathMin(maxLevelsAbove, 100);
    safeMaxBelow = (int)MathMin(maxLevelsBelow, 100);
    #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Harmonic: Center outside viewport - limiting to ", safeMaxAbove, "/", safeMaxBelow);
    #endif
    }
    double largeStepSize = baseStepSize * harmonicRatio;
    double avgStepSize = (baseStepSize + largeStepSize) / 2.0;
    bool shouldShowLine = !IsTriggerLevelsEnabled();
    int levelsDrawn = 0;
    int zoneCount = 0;
    #ifdef ENABLE_DEBUG_LOGS
    Print("DrawFactorLevelsHarmonicFromCenter: Center=", DoubleToString(centerPrice, Digits),
          ", BaseStep=", DoubleToString(baseStepSize, Digits),
          ", LargeStep=", DoubleToString(largeStepSize, Digits),
          ", MaxAbove=", maxLevelsAbove, ", MaxBelow=", maxLevelsBelow);
    #endif
    string centerName = objectPrefix + "Factor_Harmonic_Center";
    double normalizedCenter = NormalizeDouble(centerPrice, GetCachedDigits());
    if(shouldShowLine && ObjectFind(0, centerName) < 0) {
        if(ObjectCreate(0, centerName, OBJ_HLINE, 0, 0, normalizedCenter)) {
            ObjectSetInteger(0, centerName, OBJPROP_COLOR, C'255,140,0');
    ObjectSetInteger(0, centerName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, centerName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, centerName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, centerName, OBJPROP_BACK, false);
    if(!g_linesVisible) {
                ObjectSetInteger(0, centerName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            } else {
                ObjectSetInteger(0, centerName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            }
            ObjectSetString(0, centerName, OBJPROP_TOOLTIP,
                StringFormat("Harmonic Center | %s | F=%.2f | R=%.3f",
                    DoubleToString(normalizedCenter, GetCachedDigits()), factor, harmonicRatio));
    levelsDrawn++;
        }
    }
    double cumulative = 0;
    int levelsAboveCount = 0;
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove;
    if(!InitializeZoneTracking(normalizedCenter, lastStructurePriceAbove, 
                               lastTriggerPriceAbove, lastFallbackPriceAbove)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Failed to initialize zone tracking (Above)");
    #endif
    return;    }
    int logicalStepAbove = 0;
    for(int i = 0; i < safeMaxAbove; i++) {
        double step = (i % 2 == 0) ? baseStepSize : largeStepSize;
    cumulative += step;
    double priceLevel = centerPrice + cumulative;
    logicalStepAbove = i + 1;
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStepAbove, triggerEnabled, baseMultiplier)) {
                continue;            }
        } else {
        if(logicalStepAbove % baseMultiplier != 0) {
                continue;
            }
        }
    double normalizedPrice = NormalizeDouble(priceLevel, GetCachedDigits());
    bool isBase = (i % 2 == 0);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStepAbove, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = isBase ? inpHarmonicBaseColor : inpHarmonicLargeColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = isBase ? inpHarmonicBaseWidth : inpHarmonicLargeWidth;
        }
    string levelName = objectPrefix + "Factor_Harmonic_Above_" + IntegerToString(logicalStepAbove);
    if(shouldShowLine && ObjectFind(0, levelName) < 0) {
        if(ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
                ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    if(!g_linesVisible) {
                    ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                } else {
                    ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                }
                ObjectSetString(0, levelName, OBJPROP_TOOLTIP,
                    StringFormat("Harmonic +%d (%s) | %s | F=%.2f",
                        logicalStepAbove, (isBase ? "Base" : "Large"), DoubleToString(normalizedPrice, GetCachedDigits()), factor));
    levelsDrawn++;
    levelsAboveCount++;
            }
        }
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStepAbove % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "Factor_Harmonic_Zone_Above_" + IntegerToString(logicalStepAbove);
    if(CreateZoneWithSmartFallback(zoneName, normalizedPrice, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove,
                                          avgStepSize)) {                zoneCount++;
            }
        }
    }
    CleanupSurplusObjects(objectPrefix + "Factor_Harmonic_Above_", logicalStepAbove + 1);
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "Factor_Harmonic_Zone_Above_", logicalStepAbove + 1);
    }
    cumulative = 0;
    int levelsBelowCount = 0;
    double lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow;
    if(!InitializeZoneTracking(normalizedCenter, lastStructurePriceBelow, 
                               lastTriggerPriceBelow, lastFallbackPriceBelow)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsHarmonicFromCenter: Failed to initialize zone tracking (Below)");
    #endif
    return;    }
    int logicalStepBelow = 0;
    for(int i = 0; i < safeMaxBelow; i++) {
        double step = (i % 2 == 0) ? baseStepSize : largeStepSize;
    cumulative += step;
    double priceLevel = centerPrice - cumulative;
    logicalStepBelow = i + 1;
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStepBelow, triggerEnabled, baseMultiplier)) {
                continue;            }
        } else {
        if(logicalStepBelow % baseMultiplier != 0) {
                continue;
            }
        }
    double normalizedPrice = NormalizeDouble(priceLevel, GetCachedDigits());
    bool isBase = (i % 2 == 0);
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStepBelow, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = isBase ? inpHarmonicBaseColor : inpHarmonicLargeColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = isBase ? inpHarmonicBaseWidth : inpHarmonicLargeWidth;
        }
    string levelName = objectPrefix + "Factor_Harmonic_Below_" + IntegerToString(logicalStepBelow);
    if(shouldShowLine && ObjectFind(0, levelName) < 0) {
        if(ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
                ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    if(!g_linesVisible) {
                    ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                } else {
                    ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                }
                ObjectSetString(0, levelName, OBJPROP_TOOLTIP,
                    StringFormat("Harmonic -%d (%s) | %s | F=%.2f",
                        logicalStepBelow, (isBase ? "Base" : "Large"), DoubleToString(normalizedPrice, GetCachedDigits()), factor));
    levelsDrawn++;
    levelsBelowCount++;
            }
        }
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStepBelow % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "Factor_Harmonic_Zone_Below_" + IntegerToString(logicalStepBelow);
    if(CreateZoneWithSmartFallback(zoneName, normalizedPrice, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow,
                                          avgStepSize)) {                zoneCount++;
            }
        }
    }
    CleanupSurplusObjects(objectPrefix + "Factor_Harmonic_Below_", logicalStepBelow + 1);
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "Factor_Harmonic_Zone_Below_", logicalStepBelow + 1);
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawFactorLevelsHarmonicFromCenter: Drew ", levelsDrawn, " levels and ", zoneCount, " zones");
    Print("   Above=", levelsAboveCount, "/", maxLevelsAbove,
          ", Below=", levelsBelowCount, "/", maxLevelsBelow);
    #endif
    }

//+------------------------------------------------------------------+
//| Draw Factor levels FROM CENTER (supports Custom Price)          |

//| Draws levels upward and downward from center point               |
//| Like other modes (TH, SS/LS, M, TP), respects Custom Price      |
//| With safety checks and performance optimization    |
//+------------------------------------------------------------------+
void DrawFactorLevelsFromCenter(const string objectPrefix, const double centerPrice,
                                const double highPrice, const double lowPrice,
                                const double factor, const double stepSize,
                                const int maxLevelsAbove, const int maxLevelsBelow)
{
        if(StringLen(objectPrefix) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Empty object prefix");
    #endif
    return;
    }
    if(centerPrice <= 0 || highPrice <= 0 || lowPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Invalid prices - Center=", centerPrice, 
              ", High=", highPrice, ", Low=", lowPrice);
    #endif
    return;
    }
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Invalid range - High must be > Low");
    #endif
    return;
    }
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Invalid step size: ", stepSize);
    #endif
    return;
    }
    if(maxLevelsAbove < 1 || maxLevelsBelow < 1) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Invalid level counts");
    #endif
    return;
    }
    int safeMaxAbove = (maxLevelsAbove > MAX_SAFE_LEVELS) ? MAX_SAFE_LEVELS : maxLevelsAbove;
    int safeMaxBelow = (maxLevelsBelow > MAX_SAFE_LEVELS) ? MAX_SAFE_LEVELS : maxLevelsBelow;
    double vpChartMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double vpChartMin = ChartGetDouble(0, CHART_PRICE_MIN);
    double vpRange = vpChartMax - vpChartMin;
    double vpTop = vpChartMax + vpRange;
    double vpBottom = vpChartMin - vpRange;
    #ifdef ENABLE_DEBUG_LOGS
    Print("DrawFactorLevelsFromCenter: Center=", DoubleToString(centerPrice, Digits),
          ", High=", DoubleToString(highPrice, Digits), 
          ", Low=", DoubleToString(lowPrice, Digits),
          ", StepSize=", DoubleToString(stepSize, Digits),
          ", MaxAbove=", safeMaxAbove, ", MaxBelow=", safeMaxBelow);
    #endif
    const double ZONE_HEIGHT_PERCENT = 0.25;
    double zoneHeight = stepSize * ZONE_HEIGHT_PERCENT * 0.5;
    int levelsDrawn = 0;
    int zoneCount = 0;
    bool shouldShowLine = !IsTriggerLevelsEnabled();
    string centerLevelName = objectPrefix + "Factor_Center";
    double normalizedCenter = NormalizeDouble(centerPrice, GetCachedDigits());
    if(shouldShowLine) {
        if(ObjectFind(0, centerLevelName) < 0) {
        if(ObjectCreate(0, centerLevelName, OBJ_HLINE, 0, 0, normalizedCenter)) {
                ObjectSetInteger(0, centerLevelName, OBJPROP_COLOR, inpFactorLevelColor);
    ObjectSetInteger(0, centerLevelName, OBJPROP_STYLE, inpFactorLevelStyle);
    ObjectSetInteger(0, centerLevelName, OBJPROP_WIDTH, inpFactorLevelWidth);
    ObjectSetInteger(0, centerLevelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, centerLevelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, centerLevelName, OBJPROP_ZORDER, 1);
    if(!g_linesVisible) {
                    ObjectSetInteger(0, centerLevelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                } else {
                    ObjectSetInteger(0, centerLevelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                }
                ObjectSetString(0, centerLevelName, OBJPROP_TOOLTIP, 
                    StringFormat("Factor Center | %s | F=%.2f", 
                        DoubleToString(normalizedCenter, GetCachedDigits()), factor));
    levelsDrawn++;
            }
        }
    } else {
        if(ObjectFind(0, centerLevelName) >= 0) {
            ObjectSetInteger(0, centerLevelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        }
    }
    bool triggerEnabled = IsTriggerLevelsEnabled();
    bool structureEnabled = inpShowStructure;
    int baseMultiplier = GetValidatedBaseMultiplier();
    double lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove;
    if(!InitializeZoneTracking(normalizedCenter, lastStructurePriceAbove, 
                               lastTriggerPriceAbove, lastFallbackPriceAbove)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Failed to initialize zone tracking (Above)");
    #endif
    return;    }
    int logicalStep = 1;
    int levelsAboveCount = 0;
    double prevPrice = normalizedCenter;
    int maxIterations = safeMaxAbove * 2;
    int iterations = 0;
    while(levelsAboveCount < safeMaxAbove && iterations < maxIterations) {
        iterations++;
    double levelPrice = centerPrice + (stepSize * logicalStep);
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    continue;
            }
        }
    double normalizedPrice = NormalizeDouble(levelPrice, GetCachedDigits());
    if(normalizedPrice < vpBottom || normalizedPrice > vpTop) {
            logicalStep++;
    levelsAboveCount++;
    continue;
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = inpFactorLevelColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = inpFactorLevelWidth;
        }
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "Factor_Zone_Above_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, normalizedPrice, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceAbove, lastTriggerPriceAbove, lastFallbackPriceAbove,
                                          stepSize)) {                zoneCount++;
            }
        }
    string levelName = objectPrefix + "Factor_Above_" + IntegerToString(logicalStep);
    if(shouldShowLine) {
        if(ObjectFind(0, levelName) < 0) {
        if(ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
                    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, levelName, OBJPROP_ZORDER, 1);
    if(!g_linesVisible) {
                        ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                    } else {
                        ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                    }
                    ObjectSetString(0, levelName, OBJPROP_TOOLTIP,
                        StringFormat("Factor +%d | %s | F=%.2f",
                            logicalStep, DoubleToString(normalizedPrice, GetCachedDigits()), factor));
    levelsDrawn++;
                }
            }
        } else {
        if(ObjectFind(0, levelName) >= 0) {
                ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }
        
        prevPrice = normalizedPrice;
    logicalStep++;
    levelsAboveCount++;
    }
    CleanupSurplusObjects(objectPrefix + "Factor_Above_", logicalStep);
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "Factor_Zone_Above_", logicalStep);
    }
    double lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow;
    if(!InitializeZoneTracking(normalizedCenter, lastStructurePriceBelow, 
                               lastTriggerPriceBelow, lastFallbackPriceBelow)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ DrawFactorLevelsFromCenter: Failed to initialize zone tracking (Below)");
    #endif
    return;    }
    
    logicalStep = 1;
    int levelsBelowCount = 0;
    prevPrice = normalizedCenter;
    maxIterations = safeMaxBelow * 2;
    iterations = 0;
    while(levelsBelowCount < safeMaxBelow && iterations < maxIterations) {
        iterations++;
    double levelPrice = centerPrice - (stepSize * logicalStep);
    if(structureEnabled || triggerEnabled) {
            if(!ShouldDrawStepOptimized(logicalStep, triggerEnabled, baseMultiplier)) {
                logicalStep++;
    continue;
            }
        } else {
        if(logicalStep % baseMultiplier != 0) {
                logicalStep++;
    continue;
            }
        }
    double normalizedPrice = NormalizeDouble(levelPrice, GetCachedDigits());
    if(normalizedPrice < vpBottom || normalizedPrice > vpTop) {
            logicalStep++;
    levelsBelowCount++;
    continue;
        }
    color levelColor;
    ENUM_LINE_STYLE levelStyle;
    int levelWidth;
    if(GetPathForLevelOptimized(logicalStep, levelColor, levelStyle, levelWidth, triggerEnabled)) {        } else if(triggerEnabled) {            levelColor = inpTriggerColor;
    levelStyle = inpTriggerStyle;
    levelWidth = inpTriggerWidth;
        } else {            levelColor = inpFactorLevelColor;
    levelStyle = inpFactorLevelStyle;
    levelWidth = inpFactorLevelWidth;
        }
    if(inpShowMidZones) {
        bool isCurrentStructure = false;
    if(structureEnabled) {
        int intervals[];
    GetCachedIntervals(baseMultiplier, intervals);
    for(int j = 0; j < 5; j++) {
        if(intervals[j] > 0 && logicalStep % intervals[j] == 0) {
                        isCurrentStructure = true;
    break;
                    }
                }
            }
    string zoneName = objectPrefix + "Factor_Zone_Below_" + IntegerToString(logicalStep);
    if(CreateZoneWithSmartFallback(zoneName, normalizedPrice, isCurrentStructure, levelColor,
                                          structureEnabled, triggerEnabled,
                                          lastStructurePriceBelow, lastTriggerPriceBelow, lastFallbackPriceBelow,
                                          stepSize)) {                zoneCount++;
            }
        }
    string levelName = objectPrefix + "Factor_Below_" + IntegerToString(logicalStep);
    if(shouldShowLine) {
        if(ObjectFind(0, levelName) < 0) {
        if(ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
                    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, levelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, levelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, levelName, OBJPROP_ZORDER, 1);
    if(!g_linesVisible) {
                        ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                    } else {
                        ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                    }
                    ObjectSetString(0, levelName, OBJPROP_TOOLTIP,
                        StringFormat("Factor -%d | %s | F=%.2f",
                            logicalStep, DoubleToString(normalizedPrice, GetCachedDigits()), factor));
    levelsDrawn++;
                }
            }
        } else {
        if(ObjectFind(0, levelName) >= 0) {
                ObjectSetInteger(0, levelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            }
        }
        
        prevPrice = normalizedPrice;
    logicalStep++;
    levelsBelowCount++;
    }
    CleanupSurplusObjects(objectPrefix + "Factor_Below_", logicalStep);
    if(inpShowMidZones) {
        CleanupSurplusObjects(objectPrefix + "Factor_Zone_Below_", logicalStep);
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawFactorLevelsFromCenter: Drew ", levelsDrawn, " levels and ", zoneCount, " zones");
    Print("   Center=", DoubleToString(normalizedCenter, Digits),
          ", Above=", levelsAboveCount, "/", maxLevelsAbove, 
          ", Below=", levelsBelowCount, "/", maxLevelsBelow);
    #endif
    }

//+------------------------------------------------------------------+
//| DEPRECATED: Use DrawFactorLevelsAligned instead                 |
//| Draw Factor levels between Historical High and Low               |

//| Divides the range into (Factor × 2) equal parts                  |
//| NOTE: This function is kept for backward compatibility only      |
//+------------------------------------------------------------------+
static int s_lastFactorLevelCount = 0;
void DrawFactorLevels(const string objectPrefix, const double highPrice, 
                      const double lowPrice, const double factor)
{
        if(StringLen(objectPrefix) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: Empty object prefix");
    #endif
    return;
    }
    if(highPrice <= 0 || lowPrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: Invalid prices - High=", highPrice, ", Low=", lowPrice);
    #endif
    return;
    }
    if(highPrice <= lowPrice) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: Invalid range - High (", highPrice, ") must be greater than Low (", lowPrice, ")");
    #endif
    return;
    }
    if(factor < 0.01 || factor > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: Invalid factor (", DoubleToString(factor, 2), ") - must be 0.01-10000");
    #endif
    return;
    }
    double stepSize = CalculateFactorStepSize(highPrice, lowPrice, factor);
    if(stepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: Invalid step size calculated");
    #endif
    return;
    }
    double range = highPrice - lowPrice;
    int totalLevels = (int)MathFloor(range / stepSize) - 1;
    if(totalLevels <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: No levels to draw (totalLevels=", totalLevels, 
              ", factor=", DoubleToString(factor, 2), ", stepSize=", stepSize, ")");
    #endif
    return;
    }
    const int MAX_FACTOR_LEVELS = 5000;
    if(totalLevels > MAX_FACTOR_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("DrawFactorLevels: WARNING - Too many levels (", totalLevels, 
              "), clamping to ", MAX_FACTOR_LEVELS, " for safety");
    #endif
    totalLevels = MAX_FACTOR_LEVELS;
    }
    double pipSize;
    if(GetCachedDigits() <= 3) {
        pipSize = 0.01;    } else {
        pipSize = 0.0001;    }
    double rangePips = (highPrice - lowPrice) / pipSize;
    double stepPips = stepSize / pipSize;
    if(s_lastFactorLevelCount > totalLevels) {
        for(int i = totalLevels + 1; i <= s_lastFactorLevelCount; i++) {
        string staleName = objectPrefix + "Factor_" + IntegerToString(i);
    if(ObjectFind(0, staleName) >= 0) {
                ObjectDelete(0, staleName);
            }
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("DrawFactorLevels: High=", highPrice, ", Low=", lowPrice, ", Factor=", factor,
          ", StepSize=", stepSize, ", TotalLevels=", totalLevels);
    #endif
    string highLineName = objectPrefix + "Factor_High";
    if(ObjectFind(0, highLineName) < 0) {
        ObjectCreate(0, highLineName, OBJ_HLINE, 0, 0, highPrice);
    }
    ObjectSetDouble(0, highLineName, OBJPROP_PRICE, highPrice);
    ObjectSetInteger(0, highLineName, OBJPROP_COLOR, inpHighColor);
    ObjectSetInteger(0, highLineName, OBJPROP_STYLE, inpHighStyle);
    ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, inpHighWidth);
    ObjectSetInteger(0, highLineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, highLineName, OBJPROP_SELECTED, false);
    ObjectSetString(0, highLineName, OBJPROP_TOOLTIP, 
        StringFormat("Historical HIGH | %s | Range: %.0f pips", 
            DoubleToString(highPrice, GetCachedDigits()), rangePips));
    string lowLineName = objectPrefix + "Factor_Low";
    if(ObjectFind(0, lowLineName) < 0) {
        ObjectCreate(0, lowLineName, OBJ_HLINE, 0, 0, lowPrice);
    }
    ObjectSetDouble(0, lowLineName, OBJPROP_PRICE, lowPrice);
    ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, inpLowColor);
    ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, inpLowStyle);
    ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, inpLowWidth);
    ObjectSetInteger(0, lowLineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lowLineName, OBJPROP_SELECTED, false);
    ObjectSetString(0, lowLineName, OBJPROP_TOOLTIP, 
        StringFormat("Historical LOW | %s | Range: %.0f pips", 
            DoubleToString(lowPrice, GetCachedDigits()), rangePips));
    string highLabelName = objectPrefix + "Factor_High_Label";
    if(ObjectFind(0, highLabelName) < 0) {
        ObjectCreate(0, highLabelName, OBJ_TEXT, 0, TimeCurrent(), highPrice);
    }
    ObjectSetDouble(0, highLabelName, OBJPROP_PRICE, highPrice);
    ObjectSetInteger(0, highLabelName, OBJPROP_TIME, TimeCurrent());
    ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, inpHighColor);
    ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, highLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetString(0, highLabelName, OBJPROP_FONT, "Arial");
    ObjectSetString(0, highLabelName, OBJPROP_TEXT, 
        StringFormat("  HIGH %s | Range: %.0f pips | F=%.2f | Step: %.1f pips", 
            DoubleToString(highPrice, GetCachedDigits()), rangePips, factor, stepPips));
    ObjectSetInteger(0, highLabelName, OBJPROP_SELECTABLE, false);
    string lowLabelName = objectPrefix + "Factor_Low_Label";
    if(ObjectFind(0, lowLabelName) < 0) {
        ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, TimeCurrent(), lowPrice);
    }
    ObjectSetDouble(0, lowLabelName, OBJPROP_PRICE, lowPrice);
    ObjectSetInteger(0, lowLabelName, OBJPROP_TIME, TimeCurrent());
    ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, inpLowColor);
    ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, lowLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetString(0, lowLabelName, OBJPROP_FONT, "Arial");
    ObjectSetString(0, lowLabelName, OBJPROP_TEXT, 
        StringFormat("  LOW %s | Range: %.0f pips | F=%.2f | Step: %.1f pips", 
            DoubleToString(lowPrice, GetCachedDigits()), rangePips, factor, stepPips));
    ObjectSetInteger(0, lowLabelName, OBJPROP_SELECTABLE, false);
    double currentPrice = Bid;
    double distanceToHigh = MathAbs(currentPrice - highPrice);
    double distanceToLow = MathAbs(currentPrice - lowPrice);
    bool startFromLow = (distanceToLow <= distanceToHigh);
    double startPrice = startFromLow ? lowPrice : highPrice;
    double endPrice = startFromLow ? highPrice : lowPrice;
    int direction = startFromLow ? 1 : -1;
    int levelNumber = 0;
    double epsilon = stepSize * 0.001;
    int maxIterations = totalLevels * 2;
    int iterations = 0;
    while(levelNumber < totalLevels && iterations < maxIterations) {
        iterations++;
    levelNumber++;
    double levelPrice = startPrice + (stepSize * levelNumber * direction);
    if(startFromLow) {
        if(levelPrice >= (highPrice - epsilon)) break;
        } else {
        if(levelPrice <= (lowPrice + epsilon)) break;
        }
    string levelName = objectPrefix + "Factor_" + IntegerToString(levelNumber);
    double normalizedPrice = NormalizeDouble(levelPrice, GetCachedDigits());
    bool objectExists = (ObjectFind(0, levelName) >= 0);
    if(!objectExists) {
            if(!ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, normalizedPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("DrawFactorLevels: Failed to create level ", levelNumber, ", Error: ", GetLastError());
    #endif
    levelNumber++;
    continue;
            }
    color levelColor = (g_factorColorOverride >= 0) ? (color)g_factorColorOverride : inpFactorLevelColor;
    ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
    ObjectSetInteger(0, levelName, OBJPROP_STYLE, inpFactorLevelStyle);
    ObjectSetInteger(0, levelName, OBJPROP_WIDTH, inpFactorLevelWidth);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, levelName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, levelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, levelName, OBJPROP_HIDDEN, false);
        } else {
        double oldPrice = ObjectGetDouble(0, levelName, OBJPROP_PRICE);
    if(MathAbs(oldPrice - normalizedPrice) > GetCachedPoint() * 0.1) {
                ObjectSetDouble(0, levelName, OBJPROP_PRICE, normalizedPrice);
            }
        }
    string tooltip = StringFormat("Factor %d/%d | Price: %s | Step: %.1f pips", 
            levelNumber, totalLevels, 
            DoubleToString(normalizedPrice, GetCachedDigits()),
            stepPips);
    ObjectSetString(0, levelName, OBJPROP_TOOLTIP, tooltip);
    levelNumber++;
    }
    s_lastFactorLevelCount = levelNumber - 1;
    #ifdef ENABLE_DEBUG_LOGS
    Print("DrawFactorLevels: Drew ", s_lastFactorLevelCount, " levels");
    #endif
    }

//+------------------------------------------------------------------+
//| Clear all Factor level objects                                    |

//+------------------------------------------------------------------+
void ClearFactorLevels(const string objectPrefix)
{
        string highLineName = objectPrefix + "Factor_High";
    string lowLineName = objectPrefix + "Factor_Low";
    string highLabelName = objectPrefix + "Factor_High_Label";
    string lowLabelName = objectPrefix + "Factor_Low_Label";
    if(ObjectFind(0, highLineName) >= 0) ObjectDelete(0, highLineName);
    if(ObjectFind(0, lowLineName) >= 0) ObjectDelete(0, lowLineName);
    if(ObjectFind(0, highLabelName) >= 0) ObjectDelete(0, highLabelName);
    if(ObjectFind(0, lowLabelName) >= 0) ObjectDelete(0, lowLabelName);
    int totalObjects = ObjectsTotal(0, -1, -1);
    string factorPrefix = objectPrefix + "Factor_";
    for(int i = totalObjects - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
    if(StringFind(objName, factorPrefix) == 0) {
            ObjectDelete(0, objName);
        }
    }
}

