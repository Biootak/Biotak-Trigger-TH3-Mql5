#ifndef INPUT_VALIDATOR_MQH
#define INPUT_VALIDATOR_MQH

bool ValidateWidth(int width, const string name) {
        if(width <= 0 || width > 10) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ERROR: ", name, " (", width, ") out of range [1-10]");
    #endif
    return false;
    }
    return true;
}
    bool ValidateRange(double value, double minVal, double maxVal, const string name) {
        if(value < minVal || value > maxVal) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ERROR: ", name, " (", DoubleToString(value, 3), ") out of range [",
              DoubleToString(minVal, 3), "-", DoubleToString(maxVal, 3), "]");
    #endif
    return false;
    }
    return true;
}
    bool ValidatePositive(int value, const string name) {
        if(value <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ERROR: ", name, " (", value, ") must be positive");
    #endif
    return false;
    }
    return true;
}
    bool ValidateNonNegative(int value, const string name) {
        if(value < 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ERROR: ", name, " (", value, ") must be non-negative");
    #endif
    return false;
    }
    return true;
}
    bool ValidateTransparency(int value, const string name) {
        if(value < 0 || value > 100) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ERROR: ", name, " (", value, ") out of range [0-100]");
    #endif
    return false;
    }
    return true;
}
    int ValidateInputs() {
    // Base Price Threshold
    if(!ValidateRange(inpBasePriceThresholdPercent, 0.0001, 10.0, "BasePriceThreshold"))
        return INIT_PARAMETERS_INCORRECT;

    // Harmonic Ratio
    if(inpEnableHarmonicPattern) {
        if(!ValidateRange(inpHarmonicRatio, 1.01, 2.0, "HarmonicRatio"))
            return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpHarmonicBaseWidth, "HarmonicBaseWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpHarmonicLargeWidth, "HarmonicLargeWidth")) return INIT_PARAMETERS_INCORRECT;
    }

    // Font
    if(!ValidatePositive(inpFontSize, "FontSize")) return INIT_PARAMETERS_INCORRECT;
    if(inpFontSize > 100) return INIT_PARAMETERS_INCORRECT;

    // Widths
    if(!ValidateWidth(inpCustomPriceLevelWidth, "CustomPriceLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpHighWidth, "HighWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpLowWidth, "LowWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpTriggerWidth, "TriggerWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpCLevelWidth, "CLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpMLevelWidth, "MLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpSSLevelWidth, "SSLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpLSLevelWidth, "LSLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpComboLevelWidth, "ComboLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpTPLevelWidth, "TPLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpFactorLevelWidth, "FactorLevelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpTH3Width, "TH3Width")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpABCDWidth, "ABCDWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpTH3ZoneBorderWidth, "TH3ZoneBorderWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpStructureL1Width, "StructureL1Width")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpStructureL2Width, "StructureL2Width")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpStructureL3Width, "StructureL3Width")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpStructureL4Width, "StructureL4Width")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateWidth(inpStructureL5Width, "StructureL5Width")) return INIT_PARAMETERS_INCORRECT;

    // Label Position & Spacing
    if(!ValidateNonNegative(inpLabelsMarginTop, "LabelsMarginTop")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpLabelsMarginLeft, "LabelsMarginLeft")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpLabelsMarginBottom, "LabelsMarginBottom")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpLabelRowGap, "LabelRowGap")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpLabelColumnGap, "LabelColumnGap")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpSectionGap, "SectionGap")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidatePositive(inpMaxLabelWidth, "MaxLabelWidth")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpABCDInfoXDistance, "ABCDInfoX")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpABCDInfoYDistance, "ABCDInfoY")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpModeLabelXDistance, "ModeLabelX")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateNonNegative(inpModeLabelYDistance, "ModeLabelY")) return INIT_PARAMETERS_INCORRECT;

    // Levels
    if(!ValidatePositive(inpMaxLevels, "MaxLevels")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidatePositive(inpCustomPriceMaxLevels, "CustomPriceMaxLevels")) return INIT_PARAMETERS_INCORRECT;

    // Performance warnings
    if(inpMaxLevels > MAX_SAFE_LEVELS) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("WARNING: TH Levels exceed MAX_SAFE_LEVELS (", MAX_SAFE_LEVELS, ")");
    #endif
    }

    // Transparency
    if(!ValidateTransparency(inpTH3ZoneTransparency, "TH3ZoneTransparency")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateTransparency(inpMidZoneTransparency, "MidZoneTransparency")) return INIT_PARAMETERS_INCORRECT;

    // Zone Heights
    if(!ValidateRange(inpTH3ZoneHeightPercent, 1.0, 100.0, "TH3ZoneHeight")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateRange(inpMidZoneHeightPercent, 1.0, 100.0, "MidZoneHeight")) return INIT_PARAMETERS_INCORRECT;

    // Historical
    if(!ValidateNonNegative(inpHistoricalPeriods, "HistoricalPeriods")) return INIT_PARAMETERS_INCORRECT;

    // Factor
    if(!ValidateRange(inpFactorValue, 0.01, 10000.0, "FactorValue")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidateRange(inpFactorAdjustStep, 0.01, 100.0, "FactorAdjustStep")) return INIT_PARAMETERS_INCORRECT;

    // TH3
    if(!ValidateRange(inpTH3BaseStepPercent, 0.1, 1000.0, "TH3BaseStepPercent")) return INIT_PARAMETERS_INCORRECT;

    // Font Sizes
    if(!ValidatePositive(inpABCDInfoFontSize, "ABCDInfoFontSize")) return INIT_PARAMETERS_INCORRECT;
    if(!ValidatePositive(inpModeLabelFontSize, "ModeLabelFontSize")) return INIT_PARAMETERS_INCORRECT;

    // Combo validation
    ValidateComboModeConfiguration();
    #ifdef ENABLE_DEBUG_LOGS
    Print("All input validations passed");
    #endif
    return INIT_SUCCEEDED;
}
    void ValidateComboModeConfiguration() {
        #ifdef ENABLE_DEBUG_LOGS
    string modeName;
    switch(inpComboMode) {
        case COMBO_MODE_QUICK_TEST: modeName = "Quick Test"; break;
    case COMBO_MODE_PRESET:     modeName = "Preset"; break;
    case COMBO_MODE_ADVANCED:   modeName = "Advanced"; break;
    default:                    modeName = "Unknown"; break;
    }
    Print("Combo Mode: ", modeName);
    if(inpComboMode == COMBO_MODE_ADVANCED) {
        int activeComponents = 0;
    if(inpComboComp1 != COMP_IGNORE) activeComponents++;
    if(inpComboComp2 != COMP_IGNORE) activeComponents++;
    if(inpComboComp3 != COMP_IGNORE) activeComponents++;
    if(inpComboComp4 != COMP_IGNORE) activeComponents++;
    if(activeComponents == 0) {
            Print("WARNING: All combo components set to IGNORE");
        }
    if(inpComboOp1 >= OP_GEOMETRIC_MEAN_ALL && inpComboOp1 <= OP_MAX_ALL) {
            Print("N-ARY operator detected: topology will be ignored");
        }
    }
    #endif
    }
    #endif
    // INPUT_VALIDATOR_MQH