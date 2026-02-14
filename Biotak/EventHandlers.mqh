#ifndef EVENT_HANDLERS_MQH
#define EVENT_HANDLERS_MQH

int OnInitHandler() {    InitializeGlobalCache();
    // Initialize logger with user's configured log level
    LoggerSetLevel(inpLogLevel);
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    bool shouldBeHidden = RestoreBoolGlobalVar(gvar_name, false);
    DEBUG_PRINTF("OnInit: shouldBeHidden=", shouldBeHidden);
    string chartIdStr = GetCachedChartIdStr();
    g_triggerLevelsEnabled = RestoreBoolGlobalVar("Biotak_TriggerLevels_" + chartIdStr, inpShowTrigger);
    g_linesVisible = RestoreBoolGlobalVar("Biotak_LinesVisible_" + chartIdStr, inpShowLines);
    g_atrLabelsVisible = RestoreBoolGlobalVar("Biotak_ATRLabels_" + chartIdStr, inpShowATRLabels);
    // Input setting is the master switch: if disabled in Inputs, force runtime state off
    if(!inpShowATRLabels) {
        g_atrLabelsVisible = false;
    }
    string thLabelsGvarName = "Biotak_THLabels_" + chartIdStr;
    if(GlobalVariableCheck(thLabelsGvarName)) {
        double gvarValue = GlobalVariableGet(thLabelsGvarName);
    bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
    bool isOne = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
    bool isTwo = MathAbs(gvarValue - 2.0) < EPSILON_GENERAL;
    bool isThree = MathAbs(gvarValue - 3.0) < EPSILON_GENERAL;
    if(isZero || isOne || isTwo || isThree) {
            g_thLabelsMode = (int)gvarValue;
            g_thLabelsVisible = (g_thLabelsMode != 0);
        } else {
            _LOG_GATE_E Print("[E][GEN] OnInit: Corrupted TH labels state (", DoubleToString(gvarValue, 10), "), resetting to default");
    int defaultMode = 0;
    if(inpShowTHLabels) {
        if(inpShowFractalTHs && inpShowStandardTHs) defaultMode = 3;
        else if(inpShowFractalTHs) defaultMode = 1;
        else if(inpShowStandardTHs) defaultMode = 2;
        else defaultMode = 0;
    }
    GlobalVariableSet(thLabelsGvarName, (double)defaultMode);
    g_thLabelsMode = defaultMode;
    g_thLabelsVisible = (g_thLabelsMode != 0);
        }
    } else {
        int defaultMode = 0;
        if(inpShowTHLabels) {
            if(inpShowFractalTHs && inpShowStandardTHs) defaultMode = 3;
            else if(inpShowFractalTHs) defaultMode = 1;
            else if(inpShowStandardTHs) defaultMode = 2;
            else defaultMode = 0;
        }
        g_thLabelsMode = defaultMode;
        g_thLabelsVisible = (g_thLabelsMode != 0);
    }
    // Input setting is the master switch: if disabled in Inputs, force runtime state off
    if(!inpShowTHLabels) {
        g_thLabelsMode = 0;
        g_thLabelsVisible = false;
    }
    int validationResult = ValidateInputs();
    if(validationResult != INIT_SUCCEEDED) {
        return validationResult;
    }

    // Backward-friendly: if user didn't customize TH bottom margin, keep it aligned with generic bottom margin
    // (MQL inputs are compile-time defaults; this only affects internal layout usage)
    // Note: inpTHLabelsMarginBottom is an input; we won't overwrite user customization.
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    CheckArraySizes();
    if(!UpdateHistoricalValues()) {Print("OnInit: UpdateHistoricalValues failed. Error: ", GetLastError()); return INIT_FAILED;}
    g_initialized=true;
    g_calculatedOnce=false;
    
    // Initialize ATR Adaptive Scaling system
    InitializeAdaptiveScaling();
    
    g_dailyClosePriceForTH=GetPriceForPreviousDay(inpTHPriceType);
    if(g_dailyClosePriceForTH==EMPTY_VALUE) {g_dailyClosePriceForTH=EMPTY_VALUE; Print("OnInit: GetPriceForPreviousDay failed, returning INIT_FAILED."); return INIT_FAILED;}
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    int digits = Digits;
    double validatedCustomPrice = inpCustomTHStartPrice;
    if(validatedCustomPrice < 0.0) {
        _LOG_GATE_E Print("[E][GEN] Invalid custom price (negative): ", validatedCustomPrice);
    validatedCustomPrice = 0.0;
    }
    if(validatedCustomPrice > 1000000.0) {
        _LOG_GATE_E Print("[E][GEN] Invalid custom price (too large): ", validatedCustomPrice);
    validatedCustomPrice = 0.0;
    }
    {
        double val = GlobalVariableGet(overrideFlagName);
    g_customPriceKeyboardOverride = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) ? (bool)val : false;
    }
    double savedPrice;
    {
        double val = GlobalVariableGet(gvarName);
    savedPrice = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) ? val : 0.0;
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][GEN] === Custom Price Debug (OnInit) ===");
    Print("[D][GEN] inpCustomTHStartPrice: ", inpCustomTHStartPrice);
    Print("[D][GEN] savedPrice: ", savedPrice);
    Print("[D][GEN] override: ", g_customPriceKeyboardOverride);
    #endif
    if(g_customPriceKeyboardOverride && savedPrice > 0.0) {        g_customTHStartPrice = savedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    DEBUG_PRINTF("OnInit: Using keyboard/drag price (override): ", DoubleToString(g_customTHStartPrice, digits));
    CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else if(validatedCustomPrice > 0.0) {        g_customTHStartPrice = validatedCustomPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    g_customPriceKeyboardOverride = false;
    GlobalVariableSet(gvarName, g_customTHStartPrice);
    GlobalVariableSet(overrideFlagName, 0.0);
    DEBUG_PRINTF("OnInit: Using custom price from settings: ", DoubleToString(g_customTHStartPrice, digits));
    CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else if(savedPrice > 0.0) {        g_customTHStartPrice = savedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        _LOG_GATE_D Print("[D][GEN] OnInit: Restored custom price from GlobalVariable: ", DoubleToString(g_customTHStartPrice, digits));
    CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else {        g_customTHStartPrice = 0.0;
    g_thStartPointType = inpTHStartPointType;
    g_customPriceKeyboardOverride = false;
    GlobalVariableDel(gvarName);
    GlobalVariableDel(overrideFlagName);
    DEBUG_PRINT("OnInit: Using default mode (no custom price)");
    }
    
    g_redrawTHLevelsNeeded = true;
    InitializeBasePriceSystem();
    string lockFlagName = "Biotak_LockTF_" + chartIdStr;
    {
        double val = GlobalVariableGet(lockFlagName);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            g_timeframeLocked = (bool)val;
        }
    }
    string lockPeriodName = "Biotak_LockTFPeriod_" + chartIdStr;
    {
        double val = GlobalVariableGet(lockPeriodName);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            g_lockedPeriod = (int)val;
        }
    }
    string stepModeGvarName = "Biotak_StepMode_" + chartIdStr;
    {
        double val = GlobalVariableGet(stepModeGvarName);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
        int tempMode = (int)val;
    if(tempMode >= 0 && tempMode <= 5) {
                g_stepModeOverride = tempMode;
            } else {
                _LOG_GATE_W Print("[W][GEN] WARNING: Corrupted StepMode GlobalVariable (", tempMode, "), resetting to default");
    GlobalVariableDel(stepModeGvarName);
    g_stepModeOverride = -1;
            }
        }
    }
    string factorGvarName = "Biotak_Factor_" + chartIdStr;
    {
        double val = GlobalVariableGet(factorGvarName);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
        if(val > 0 && val <= MAX_SAFE_FACTOR) {
                g_factorValueOverride = val;
            } else {
                _LOG_GATE_E Print("[E][GEN] WARNING: Invalid Factor GlobalVariable (", val, "), resetting to default");
    GlobalVariableDel(factorGvarName);
    g_factorValueOverride = 0.0;
            }
        } else {            g_factorValueOverride = 0.0;
        }
    }
    if(inpFactorMode == FACTOR_MODE_MANUAL) {
        if(inpFactorValue <= 0 || inpFactorValue > MAX_SAFE_FACTOR) {
            _LOG_GATE_E Print("[E][GEN] ERROR: Invalid inpFactorValue (", inpFactorValue, "), clamping to safe range");
    g_factorValueOverride = 50.0;
        }
    }
    // Restore TH3 Frequency override + index
    string th3FreqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    string th3FreqIdxGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
    {
        double val = GlobalVariableGet(th3FreqGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            double maxFreq = GetFrequencyByIndex(MAX_TH3_FREQ_INDEX);
            if(val > 0 && val <= maxFreq) {
                g_th3FreqOverride = val;
            } else {
                GlobalVariableDel(th3FreqGvarName);
                g_th3FreqOverride = 0.0;
            }
        } else {
            g_th3FreqOverride = 0.0;
        }
        // Restore frequency index
        double idxVal = GlobalVariableGet(th3FreqIdxGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            int idx = (int)idxVal;
            if(idx >= MIN_TH3_FREQ_INDEX && idx <= MAX_TH3_FREQ_INDEX) {
                g_th3FreqIndex = idx;
            } else {
                g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
                GlobalVariableDel(th3FreqIdxGvarName);
            }
        } else {
            g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
        }
        // Migration: sync index with saved frequency value (old GM array → new binary subdivision)
        if(g_th3FreqOverride > 0) {
            double expectedFreq = GetFrequencyByIndex(g_th3FreqIndex);
            if(MathAbs(expectedFreq - g_th3FreqOverride) > 0.01) {
                g_th3FreqIndex = FindNearestFreqIndex(g_th3FreqOverride);
                g_th3FreqOverride = GetFrequencyByIndex(g_th3FreqIndex);
                // Persist corrected values
                GlobalVariableSet(th3FreqGvarName, g_th3FreqOverride);
                GlobalVariableSet(th3FreqIdxGvarName, (double)g_th3FreqIndex);
                Print("[Init] TH3 Freq migrated to binary subdivision: ", DoubleToString(g_th3FreqOverride, 4), "% [#", g_th3FreqIndex, "]");
            }
        }
    }
    InitializeATRCache();
    WarmupATRMultiTFCache();
    UpdateLockStatusLabel();
    PrintBuildInfo();
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStr;
    {
        double val = GlobalVariableGet(th3UpdateFlag);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND && val > 0)
        {            UpdateAllTH3Objects();
    GlobalVariableDel(th3UpdateFlag);
            _LOG_GATE_I Print("[I][GEN] Updated all TH3 objects with new settings");
    }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("[E][GEN] AUDIT COMPLETE: All critical memory leaks fixed");
    Print("[D][GEN] [FAST] OPTIMIZED: API calls cached (Symbol, Digits, Point)");
    Print("[D][GEN] [CLEAN] MEMORY: BasePriceManager cleanup added");
    Print("[D][GEN] [CFG] BUILD: Debug/Production modes with compile-time optimization");
    Print("[D][GEN] [CFG] FEATURES: Multiple step modes (TH, SS/LS, M, TP, Combo)");
    Print("[I][GEN] PERSISTENT: Settings saved to GlobalVariables (survive terminal restart)");
    Print("[D][GEN] To enable 'Chart Shift': Right-click chart > Chart Shift (or F11)");
    #endif
    if(shouldBeHidden) {        g_redrawTHLevelsNeeded = false;
        _LOG_GATE_D Print("[D][GEN] [LOCK] OnInit: Indicator in HIDDEN state - objects will be hidden when created");
    } else {        g_redrawTHLevelsNeeded = true;
        _LOG_GATE_D Print("[D][GEN] [SHOW] OnInit: Indicator VISIBLE - objects will be created normally");
    }
    return INIT_SUCCEEDED;
}bool CreateCustomPriceLine(double price, int digits, bool selected = false, 
                           string tooltipSuffix = "Drag to adjust")
{
        if(ObjectFind(0, g_customPriceHorizontalLineName) < 0) {
        if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, price)) {
            _LOG_GATE_E Print("[E][GEN] Failed to create custom price line. Error: ", GetLastError());
    g_customPriceLineCreated = false;
    return false;
        }
    } else {
        ObjectSetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, price);
    }
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, selected);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                  "[PIN] Custom Price: " + DoubleToString(price, digits) + " | " + tooltipSuffix);
    g_customPriceLineCreated = true;
    return true;
}

//+------------------------------------------------------------------+
//| Helper function to hide all TH objects (DRY)                     |

//|                                                                  |
//| Centralized hide logic to avoid code duplication      |
//| Used by: OnInit, RedrawAllObjects, F key handler                |
//| COVERS: TH levels, labels, zones, mode labels, custom price     |
//+------------------------------------------------------------------+
void HideAllTHObjects()
{
        int total = ObjectsTotal(0, -1, -1);
    int hiddenCount = 0;
    string cachedPrefix = inpObjectPrefix;
    int prefixLen = StringLen(cachedPrefix);
    // PERF: Pre-compute long constant for visibility outside loop
    long noPeriodsVal = OBJ_NO_PERIODS;
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);
    // PERF: Use StringLen + StringSubstr instead of StringFind for prefix check
    if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix)
        {
        ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, noPeriodsVal);
        hiddenCount++;
        }    }
    // PERF: Batch special label hide with single constant
    if(ObjectFind(0, g_stepModeLabelName) >= 0)
        ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    if(ObjectFind(0, g_factorLabelName) >= 0)
        ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    if(ObjectFind(0, g_th3FreqLabelName) >= 0)
        ObjectSetInteger(0, g_th3FreqLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    if(ObjectFind(0, g_lockStatusLabelName) >= 0)
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0)
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    // NOTE: ABCD pattern objects are NOT hidden by F key — they are independent of TH levels
    }void CleanupCustomPriceObjects(bool resetGlobalVars = false, bool forceDelete = false)
{    if (g_waitingForCustomPriceClick || forceDelete) {
        ObjectDelete(0, g_customPriceHorizontalLineName);
    g_customPriceLineCreated = false;
    }
    
    g_waitingForCustomPriceClick = false;
    if (resetGlobalVars) {
        string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    GlobalVariableDel(gvarName);
    GlobalVariableDel(overrideFlagName);
    g_customTHStartPrice = 0.0;
    g_thStartPointType = inpTHStartPointType;
    g_customPriceKeyboardOverride = false;    }
}

//+------------------------------------------------------------------+
//| Delete all indicator objects (DRY helper for OnDeinit)           |
//+------------------------------------------------------------------+
void DeleteAllIndicatorObjects() {
    ObjectsDeleteAll(0, inpObjectPrefix);
    ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
}

    void OnDeinitHandler(const int reason) {
        DEBUG_PRINT("Starting cleanup");
    ReleaseATRHandle();
    EventKillTimer();
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectDelete(0, g_stepModeLabelName);
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectDelete(0, g_factorLabelName);
    }
    if(ObjectFind(0, g_th3FreqLabelName) >= 0) {
        ObjectDelete(0, g_th3FreqLabelName);
    }
    if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
        ObjectDelete(0, g_lockStatusLabelName);
    }
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
        ObjectDelete(0, g_customPriceHorizontalLineName);
    }
    if(reason == REASON_REMOVE)
    {
        DEBUG_PRINT("Indicator removed - cleaning all GlobalVariables");
    CleanupAllGlobalVariables();
    DeleteAllIndicatorObjects();
    ObjectsDeleteAll(0, "TH3_Structure_");
    ObjectsDeleteAll(0, TH3_PATTERN_PREFIX);  // Clean up AB=CD pattern objects
    ObjectsDeleteAll(0, TH3_TEMP_PREFIX);     // Clean up any temp drawing objects
    }
    else if(reason == REASON_PARAMETERS)
    {
        // Clear all ATR and TH labels to apply new settings
        string currentTFStr = IntegerToString(Period());
        string uniquePrefix = inpObjectPrefix + "TF" + currentTFStr + "_";
        string tfLabels[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
        
        // Delete ATR labels
        ObjectDelete(0, uniquePrefix + "ATR_Title");
        for(int i = 0; i < ArraySize(tfLabels); i++) {
            ObjectDelete(0, uniquePrefix + "ATR_" + tfLabels[i]);
            ObjectDelete(0, uniquePrefix + "ATR_Steps_" + tfLabels[i]);
            ObjectDelete(0, uniquePrefix + "ATR_Targets_" + tfLabels[i]);
        }
        
        // Delete TH labels
        ObjectDelete(0, inpObjectPrefix + "TH_Title");
        for(int i = 0; i < ArraySize(tfLabels); i++) {
            ObjectDelete(0, inpObjectPrefix + "TH_" + tfLabels[i]);
            ObjectDelete(0, inpObjectPrefix + "TH_Steps_" + tfLabels[i]);
            ObjectDelete(0, inpObjectPrefix + "TH_Targets_" + tfLabels[i]);
        }
        
        string symbolName = GetCachedSymbol();
    string chartIdStrLocal = GetCachedChartIdStr();
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    GlobalVariableSet(overrideFlagName, 0.0);
    string factorGvarName = "Biotak_Factor_" + chartIdStrLocal;
    GlobalVariableDel(factorGvarName);
    g_factorValueOverride = 0.0;
    string linesGvarName = "Biotak_LinesVisible_" + chartIdStrLocal;
    GlobalVariableDel(linesGvarName);
    // ATR labels hotkey override should not survive parameter changes
    string atrLabelsGvarName = "Biotak_ATRLabels_" + chartIdStrLocal;
    GlobalVariableDel(atrLabelsGvarName);
    // TH labels hotkey override should not survive parameter changes
    string thLabelsGvarNameLocal = "Biotak_THLabels_" + chartIdStrLocal;
    GlobalVariableDel(thLabelsGvarNameLocal);
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStrLocal;
    GlobalVariableSet(th3UpdateFlag, 1.0);
    GlobalVariableTemp(th3UpdateFlag);
    DEBUG_PRINT("OnDeinit (REASON_PARAMETERS) - reset overrides");
    DeleteAllIndicatorObjects();
    }
    else
    {
        DEBUG_PRINTF("OnDeinit (reason=", reason);
    DeleteAllIndicatorObjects();
    }
    CleanupCustomPriceObjects(false, true);
    // FIX: Force ChartRedraw after cleanup so deleted objects disappear immediately
    if(reason != REASON_REMOVE) ChartRedraw();
    Comment("");
    DEBUG_PRINT("Freeing arrays...");
    ArrayFree(g_storedTHs);
    ArrayFree(g_labelPositions);
    DEBUG_PRINT("Cleaning up managers...");
    CleanupBasePriceManager();
    CleanupATRCache();
    CleanupObjectCountManager();
    g_initialized = false;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    g_highestHigh = EMPTY_VALUE;
    g_lowestLow = EMPTY_VALUE;
    g_currentPrice = 0.0;
    g_lastCalculation = 0;
    g_lastHistoricalUpdate = 0;
    g_dailyClosePriceForTH = EMPTY_VALUE;
    g_objectCountLast = 0;
    g_lastObjectCleanup = 0;
    DEBUG_PRINT("Cleanup completed successfully");
    }

//+------------------------------------------------------------------+
//| Clear all level objects from all modes (OPTIMIZED + SAFE)       |

//| Added error handling and retry logic              |
//+------------------------------------------------------------------+
void ClearAllLevels(const string objectPrefix, bool clearZones = true)
{
    int totalDeleted = 0;
    int totalFailed = 0;
    if(StringLen(objectPrefix) == 0) return;

    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastClearLog = 0;
    if(TimeCurrent() - s_lastClearLog > 5) {
        Print("[D][GEN] [MT4] [CLEAN] CLEARING ALL LEVELS with prefix: ", objectPrefix);
        s_lastClearLog = TimeCurrent();
    }
    #endif

    // FIX: Zone suffixes are checked FIRST and separately from level suffixes.
    // Previously, zones like "SSLS_Zone_" matched "SSLS_" in LEVEL_SUFFIXES,
    // causing clearZones=false to be ineffective (zones always deleted).
    static const string ZONE_SUFFIXES[] = {
        "SSLS_Zone_", "M_Zone_", "TP_Zone_", "Combo_Zone_", "Factor_Zone_",
        "MEq_Zone_", "Factor_Harmonic_Zone_", "TH_Level_Zone_"
    };
    static const string LEVEL_SUFFIXES[] = {
        "SSLS_", "M_", "MLabel_", "MEq_", "MEqLabel_", "TP_", "Combo_",
        "SharedPattern_", "TH_Level_", "S_",
        "TriggerTH_Up_", "TriggerTH_Down_",
        "StructureLevel1_Up_", "StructureLevel1_Down_",
        "StructureLevel2_Up_", "StructureLevel2_Down_",
        "StructureLevel3_Up_", "StructureLevel3_Down_",
        "StructureLevel4_Up_", "StructureLevel4_Down_",
        "StructureLevel5_Up_", "StructureLevel5_Down_",
        "Mid", "Factor_"
    };
    // PERF: Pre-compute suffix lengths once (static locals compile to one-time init)
    static int LEVEL_SUFFIX_LENS[];
    static int ZONE_SUFFIX_LENS[];
    static bool s_suffixLensInit = false;
    if(!s_suffixLensInit) {
        ArrayResize(LEVEL_SUFFIX_LENS, ArraySize(LEVEL_SUFFIXES));
        for(int s = 0; s < ArraySize(LEVEL_SUFFIXES); s++)
            LEVEL_SUFFIX_LENS[s] = StringLen(LEVEL_SUFFIXES[s]);
        ArrayResize(ZONE_SUFFIX_LENS, ArraySize(ZONE_SUFFIXES));
        for(int z = 0; z < ArraySize(ZONE_SUFFIXES); z++)
            ZONE_SUFFIX_LENS[z] = StringLen(ZONE_SUFFIXES[z]);
        s_suffixLensInit = true;
    }

    int total = ObjectsTotal(0, -1, -1);
    int prefixLen = StringLen(objectPrefix);
    for(int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, -1, -1);
        if(name == "") continue;
        int nameLen = StringLen(name);
        if(nameLen < prefixLen) continue;
        if(StringSubstr(name, 0, prefixLen) != objectPrefix) continue;

        string tail = StringSubstr(name, prefixLen);
        int tailLen = nameLen - prefixLen;
        bool shouldDelete = false;
        bool isZoneObject = false;

        // PERF: Use first char of tail to skip most suffix comparisons
        ushort firstChar = (tailLen > 0) ? StringGetCharacter(tail, 0) : 0;

        // FIX: Check zone suffixes FIRST (longer, more specific match)
        // This prevents "SSLS_Zone_" from matching "SSLS_" in level suffixes
        for(int z = 0; z < ArraySize(ZONE_SUFFIXES); z++) {
            int zl = ZONE_SUFFIX_LENS[z];
            if(tailLen < zl) continue;
            if(StringGetCharacter(ZONE_SUFFIXES[z], 0) != firstChar) continue;
            if(StringSubstr(tail, 0, zl) == ZONE_SUFFIXES[z]) {
                isZoneObject = true;
                break;
            }
        }

        if(isZoneObject) {
            // Zone object: only delete if clearZones is true
            if(clearZones) shouldDelete = true;
        } else {
            // Non-zone: check level suffixes
            for(int s = 0; s < ArraySize(LEVEL_SUFFIXES); s++) {
                int sl = LEVEL_SUFFIX_LENS[s];
                if(tailLen < sl) continue;
                if(StringGetCharacter(LEVEL_SUFFIXES[s], 0) != firstChar) continue;
                if(StringSubstr(tail, 0, sl) == LEVEL_SUFFIXES[s]) {
                    shouldDelete = true;
                    break;
                }
            }
        }

        if(!shouldDelete) continue;

        // FIX: Remove from cache individually instead of clearing entire cache
        CacheRemoveObject(name);
        g_suppressDeleteEvents = true;  // Prevent cascade deletion of ABCD patterns
        if(ObjectDelete(0, name)) totalDeleted++;
        else totalFailed++;
        g_suppressDeleteEvents = false;
    }

    #ifdef ENABLE_DEBUG_LOGS
    if(totalDeleted > 0 || totalFailed > 0) {
        Print("[E][GEN] ClearAllLevels: Deleted=", totalDeleted, ", Failed=", totalFailed);
    }
    #endif

    // FIX: Invalidate object count cache so CanCreateObject doesn't block creation after cleanup
    // Note: Individual cache entries removed during deletion loop above (no CacheClear needed)
    InvalidateObjectCountCache();
}
    void GetAdaptiveLevelCounts(int &maxAbove, int &maxBelow)
{
            maxAbove = inpMaxLevels;
        maxBelow = inpMaxLevels;
        if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
        if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
        if(maxAbove < 1) maxAbove = 1;
        if(maxBelow < 1) maxBelow = 1;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
    struct StepCalculationData {
        double thValue;
    double structureValue;
    double patternValue;
    double triggerValue;
    double shortStep;
    double longStep;
    double pointSize;
    double midpointPrice;
    int maxLevelsAbove;
    int maxLevelsBelow;
};

    bool CalculateCommonStepData(const double dailyClosePrice, StepCalculationData &data)
{
        if(dailyClosePrice <= 0) {
        _LOG_GATE_E Print("[E][GEN] CalculateCommonStepData: Invalid daily close price");
    return false;
    }
    static StepCalculationData s_cachedData;
    static double s_lastDailyClose = 0;
    static string s_lastTF = "";
    static int s_lastStartPointType = -1;
    static double s_lastCustomPrice = 0;
    static int s_lastMaxAbove = 0;
    static int s_lastMaxBelow = 0;
    static double s_lastScalingFactor = 1.0;
    string currentTF = GetFractalTimeframeForCurrent();
    double currentScalingFactor = GetCurrentScalingFactor();
    
    if(dailyClosePrice == s_lastDailyClose && 
       currentTF == s_lastTF &&
       g_thStartPointType == s_lastStartPointType &&
       (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE || g_customTHStartPrice == s_lastCustomPrice) &&
       inpMaxLevels == s_lastMaxAbove &&
       inpMaxLevels == s_lastMaxBelow &&
       MathAbs(currentScalingFactor - s_lastScalingFactor) < EPSILON_GENERAL &&
       s_lastDailyClose != 0) {
        data = s_cachedData;
    return true;
    }
    
    int digits = Digits;
    
    // TH-based step calculations
    double timeframePercentage = GetTimeframeTH();
    data.thValue = CalculateTH(dailyClosePrice, digits, timeframePercentage);
    
    // Apply ATR Adaptive Scaling to TH value
    // This preserves the fractal 2× ratio since the same factor scales all levels uniformly
    data.thValue = GetAdaptedStepSize(data.thValue);
    
    CalculateFractalValues(data.thValue, data.structureValue, data.patternValue, data.triggerValue);
    
    #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastTHDebugLogTime = 0;
    datetime currentDebugTime = TimeCurrent();
    if(currentDebugTime - s_lastTHDebugLogTime > 300) {
            Print("[D][GEN] ========== MT4 TH_BASIS CALCULATION ==========");
    Print("[D][GEN] Calculation Basis: TH (Theoretical)");
    Print("[D][GEN] Base Price (dailyClosePrice): ", DoubleToString(dailyClosePrice, 10));
    Print("[D][GEN] Timeframe Percentage: ", DoubleToString(timeframePercentage, 10));
    Print("[D][GEN] TH Value (price units): ", DoubleToString(data.thValue, 10));
    Print("[D][GEN] Structure Value: ", DoubleToString(data.structureValue, 10));
    Print("[D][GEN] Pattern Value: ", DoubleToString(data.patternValue, 10));
    Print("[D][GEN] Trigger Value: ", DoubleToString(data.triggerValue, 10));
    Print("[D][GEN] SS (1.5 × Structure): ", DoubleToString(data.structureValue * 1.5, 10));
    Print("[D][GEN] LS (2.0 × Structure): ", DoubleToString(data.structureValue * 2.0, 10));
    Print("[D][GEN] ==============================================");
    s_lastTHDebugLogTime = currentDebugTime;
        }
    #endif
    
    data.shortStep = data.structureValue * 1.5;
    data.longStep = data.structureValue * 2.0;
    data.pointSize = 1.0;
    data.midpointPrice = GetMidpointPrice(g_thStartPointType);
    if(data.midpointPrice <= 0 || data.midpointPrice == EMPTY_VALUE) {
        _LOG_GATE_E Print("[E][GEN] ERROR: Invalid midpoint price! g_highestHigh=", g_highestHigh, ", g_lowestLow=", g_lowestLow);
    return false;
    }
    GetAdaptiveLevelCounts(data.maxLevelsAbove, data.maxLevelsBelow);
    s_cachedData = data;
    s_lastDailyClose = dailyClosePrice;
    s_lastTF = currentTF;
    s_lastStartPointType = g_thStartPointType;
    s_lastCustomPrice = g_customTHStartPrice;
    s_lastMaxAbove = inpMaxLevels;
    s_lastMaxBelow = inpMaxLevels;
    s_lastScalingFactor = currentScalingFactor;
    return true;
}
    void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice)
{
        static ENUM_STEP_CALCULATION_MODE s_lastDrawnMode = (ENUM_STEP_CALCULATION_MODE)-1;
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    bool modeChanged = (currentMode != s_lastDrawnMode);
    // PERF: ClearAllLevels is already called by RedrawAllObjects before this function.
    // Only update mode tracking here; skip the redundant second clear.
    if(modeChanged || g_forceClearOnNextDraw) {
        s_lastDrawnMode = currentMode;
    g_forceClearOnNextDraw = false;
    }
    switch(currentMode) {
        case SS_LS_STEP:
        {
            StepCalculationData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) return;
    double ssValuePrice = data.shortStep;
    double lsValuePrice = data.longStep;
    DrawSSLSLevels(objectPrefix, data.midpointPrice, ssValuePrice, lsValuePrice, inpLSFirst,
                          data.maxLevelsAbove, data.maxLevelsBelow);
    break;
        }
        
        case M_STEP:
        {
            StepCalculationData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) return;
    double controlValue = data.shortStep;
    double controlValuePrice = controlValue;
    if(inpMStepBasisType == MSTEP_BASIS_C_BASED) {
                DrawMLevels(objectPrefix, data.midpointPrice, controlValuePrice,
                           data.maxLevelsAbove, data.maxLevelsBelow);
            } else {
        double mDistance = CalculateMDistance(controlValue);
    double mDistancePrice = mDistance;
    DrawMEqualLevels(objectPrefix, data.midpointPrice, mDistancePrice,
                                data.maxLevelsAbove, data.maxLevelsBelow);
            }
            break;
        }
        
        case TP_STEP:
        {
            StepCalculationData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) return;
    double eValue = CalculateEStep(data.thValue);
    double tpValue = CalculateTPStep(eValue);
    DrawTHLevelsWithStep(objectPrefix, data.midpointPrice, tpValue, "TP",
                                data.maxLevelsAbove, data.maxLevelsBelow);
    break;
        }
        
        case COMBO_STEP:
        {
            StepCalculationData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) return;
    double comboStep = CalculateComboStepSize(dailyClosePrice);
    if(comboStep <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("[E][GEN] COMBO_STEP: Failed to calculate combo step");
    Print("[D][GEN]    Base Price: ", dailyClosePrice);
    Print("[D][GEN]    Preset: ", EnumToString(inpComboPreset));
    #endif
    string errorMsg = "Failed to calculate Combo Step!\n\n";
    errorMsg += "Preset: " + EnumToString(inpComboPreset) + "\n";
    errorMsg += "Base Price: " + DoubleToString(dailyClosePrice, Digits) + "\n\n";
    errorMsg += "Please check:\n";
    errorMsg += "1. Preset configuration is valid\n";
    errorMsg += "2. Base price is positive\n";
    errorMsg += "3. Timeframe settings are correct";
    Alert(errorMsg);
    return;
            }
    static double s_lastLoggedComboStep = 0;
    if(MathAbs(comboStep - s_lastLoggedComboStep) > 0.0000001) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("[D][GEN] ========== COMBO STEP (UNIFIED) ==========");
    Print("[D][GEN] TF: ", GetCurrentTimeframe(), " | TH: ", DoubleToString(data.thValue, Digits));
    Print("[D][GEN] Preset: ", EnumToString(inpComboPreset));
    Print("[D][GEN] Combo Step = ", DoubleToString(comboStep, Digits));
    Print("[D][GEN] Structure: ", DoubleToString(data.structureValue, Digits),
                      " | Pattern: ", DoubleToString(data.patternValue, Digits),
                      " | Trigger: ", DoubleToString(data.triggerValue, Digits));
    Print("[D][GEN] ==========================================");
    #endif
    s_lastLoggedComboStep = comboStep;
            }
    DrawTHLevelsWithStep(objectPrefix, data.midpointPrice, comboStep, "Combo",
                                data.maxLevelsAbove, data.maxLevelsBelow);
    break;
        }
        
        case FACTOR_STEP:
        {            StepCalculationData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) {
                _LOG_GATE_E Print("[E][GEN] FACTOR_STEP: Failed to calculate common step data");
    return;
            }
    double factorValue;
    if(g_factorValueOverride > 0) {                factorValue = g_factorValueOverride;
            } else if(inpFactorMode == FACTOR_MODE_MANUAL) {                factorValue = inpFactorValue;
            } else {                factorValue = GetDefaultFactorValue(dailyClosePrice);
            }
    factorValue = NormalizeDouble(MathMax(0.01, MathMin(10000, factorValue)), 2);
    #ifdef ENABLE_DEBUG_LOGS
            string modeStr = (g_factorValueOverride > 0) ? "KEYBOARD" : 
                            ((inpFactorMode == FACTOR_MODE_AUTO) ? "AUTO" : "MANUAL");
    Print("[D][GEN] FACTOR_STEP: Mode=", modeStr, ", Factor=", DoubleToString(factorValue, 2));
    Print("[D][GEN]    Center=", DoubleToString(data.midpointPrice, Digits),
                  " (", (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE ? "Custom" : "Midpoint"), ")");
    Print("[D][GEN]    MaxLevels: Above=", data.maxLevelsAbove, ", Below=", data.maxLevelsBelow);
    #endif
    UpdateFactorLabel(factorValue);
    // PERF: Compute factor step size ONCE — was being computed 2-3 times with identical params
    double factorStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
    if(factorStepSize <= 0) {
                _LOG_GATE_E Print("[E][GEN] FACTOR_STEP: Invalid step size calculated");
    return;
            }
    if(factorStepSize < Point * 2) {
                _LOG_GATE_E Print("[E][GEN] FACTOR_STEP: Base step too small (", factorStepSize);
    return;
            }
    if(inpEnableHarmonicPattern) {
        double harmonicRatio = inpHarmonicRatio;
    if(harmonicRatio < MIN_HARMONIC_RATIO) {
                    _LOG_GATE_W Print("[W][GEN] FACTOR_STEP: Harmonic ratio too small (", harmonicRatio);
    harmonicRatio = MIN_HARMONIC_RATIO;
                } else if(harmonicRatio > MAX_HARMONIC_RATIO) {
                    _LOG_GATE_W Print("[W][GEN] FACTOR_STEP: Harmonic ratio too large (", harmonicRatio);
    harmonicRatio = MAX_HARMONIC_RATIO;
                }
    harmonicRatio = NormalizeDouble(harmonicRatio, 3);
    #ifdef ENABLE_DEBUG_LOGS
                double pipSizeDbg = GetCachedPipSize();
    if(IsZero(pipSizeDbg, EPSILON_PRICE)) pipSizeDbg = Point;
                Print("[D][GEN] [HARM] FACTOR_STEP: Harmonic Mode");
    Print("[D][GEN]    BaseStep=", DoubleToString(factorStepSize, Digits),
                      " (", DoubleToString(factorStepSize / pipSizeDbg, 1), " pips)");
    Print("[D][GEN]    Ratio=", harmonicRatio,
                      " (", DoubleToString((harmonicRatio - 1.0) * 100, 1), "% larger)");
    Print("[D][GEN]    LargeStep=", DoubleToString(factorStepSize * harmonicRatio, Digits),
                      " (", DoubleToString(factorStepSize * harmonicRatio / pipSizeDbg, 1), " pips)");
    #endif
    DrawFactorLevelsHarmonicFromCenter(objectPrefix, data.midpointPrice, 
                                                   g_highestHigh, g_lowestLow,
                                                   factorValue, factorStepSize, harmonicRatio,
                                                   data.maxLevelsAbove, data.maxLevelsBelow);
                
            } else {
    #ifdef ENABLE_DEBUG_LOGS
                Print("[D][GEN] [STD] FACTOR_STEP: Standard Mode");
    double pipSizeDbg = GetCachedPipSize();
    if(IsZero(pipSizeDbg, EPSILON_PRICE)) pipSizeDbg = Point;
    Print("[D][GEN]    StepSize=", DoubleToString(factorStepSize, Digits),
                      " (", DoubleToString(factorStepSize / pipSizeDbg, 1), " pips)");
    #endif
    DrawFactorLevelsFromCenter(objectPrefix, data.midpointPrice, 
                                          g_highestHigh, g_lowestLow, 
                                          factorValue, factorStepSize,
                                          data.maxLevelsAbove, data.maxLevelsBelow);
            }
    DrawFactorBoundaryLines(objectPrefix, g_highestHigh, g_lowestLow, factorValue, factorStepSize);
            _LOG_GATE_I Print("[I][GEN] FACTOR_STEP: Completed successfully");
    break;
        }
        
        case TH_STEP:
        default:
        {
            DrawTHLevels(objectPrefix, dailyClosePrice);
            _LOG_GATE_I Print("[I][GEN] TH_STEP: Completed successfully");
            break;
        }
    }
    _LOG_GATE_I Print("[I][GEN] DrawLevelsBasedOnMode: All operations completed");
    }
    void RedrawAllObjects(bool force_redraw=false)
{
        // PERF: Refresh cached frame time once — eliminates ~2000+ TimeCurrent() syscalls in cache ops
        CacheRefreshFrameTime();
        // PERF: Cache visibility state once per frame — skips ~800 ObjectSetInteger calls when unchanged
        CacheRefreshVisibilityState();
        datetime currentTime = TimeGMT();
    string s_cachedSymbol = GetCachedSymbol();
    int s_cachedDigits = GetCachedDigits();
    double s_cachedPoint = GetCachedPoint();
    // PERF: Cache Bid/Ask once per redraw frame instead of ~10 SymbolInfoDouble syscalls
    CacheTickPrices();
    g_currentPrice = GetCachedBid();
    if(g_currentPrice <= 0) return;

    TH3_PROF_START(BasePrice);
    UpdateBasePrice();
    double thBasePrice = GetBasePriceForTH();
    TH3_PROF_END(BasePrice);
    if(thBasePrice <= 0 || thBasePrice == EMPTY_VALUE) {        thBasePrice = g_dailyClosePriceForTH;
    }
    
    // Update ATR Adaptive Scaling factor (only recalculates on new bar close)
    UpdateATRScalingFactor(thBasePrice, s_cachedDigits);
    
    static double s_lastDrawnBasePrice = 0.0;
    bool basePriceChanged = (MathAbs(thBasePrice - s_lastDrawnBasePrice) > s_cachedPoint);
    if(basePriceChanged) {
        s_lastDrawnBasePrice = thBasePrice;
    g_redrawTHLevelsNeeded = true;
    }
    bool customPriceLineExists = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
    if(!force_redraw && !g_labelsRelayoutNeeded && !customPriceLineExists && !basePriceChanged && !g_redrawTHLevelsNeeded && currentTime - g_lastCalculation < REDRAW_THROTTLE_SECONDS && g_initialized) return;
    g_lastCalculation = currentTime;
    // PERF: Cache objectPrefix - only rebuild when timeframe actually changes
    static string s_cachedObjectPrefix = "";
    static string s_cachedTimeframeStr = "";
    string currentTFStr = GetCurrentTimeframe();
    if(currentTFStr != s_cachedTimeframeStr) {
        s_cachedTimeframeStr = currentTFStr;
        s_cachedObjectPrefix = inpObjectPrefix + "_" + currentTFStr + "_";
    }
    string objectPrefix = s_cachedObjectPrefix;
    if(currentTime - g_lastObjectCleanup > CLEANUP_INTERVAL_SECONDS) {
        TH3_PROF_START(ObjectCleanup);
        int currentObjectCount = ObjectsTotal(0, -1, -1);
    if(currentObjectCount > g_objectCountLast + OBJECT_COUNT_INCREASE_THRESHOLD) {
        datetime cutoffTime = currentTime - 3600;
    int currentPrefixLen = StringLen(objectPrefix);
    string indicatorPrefix = inpObjectPrefix;
    int indicatorPrefixLen = StringLen(indicatorPrefix);
    int maxCleanupItems = MathMin(currentObjectCount, 2000);
    for(int i = maxCleanupItems - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, -1, -1);
    if(objName == "") continue;
    // FIX: Only consider objects that belong to THIS indicator (known prefixes)
    bool isOurs = false;
    if(StringLen(objName) >= indicatorPrefixLen && StringSubstr(objName, 0, indicatorPrefixLen) == indicatorPrefix) isOurs = true;
    if(!isOurs && StringFind(objName, TH3_PATTERN_PREFIX) == 0) isOurs = true;
    if(!isOurs && StringFind(objName, TH3_TEMP_PREFIX) == 0) isOurs = true;
    if(!isOurs && StringFind(objName, "TH3_Structure_") == 0) isOurs = true;
    if(!isOurs) continue; // Skip foreign objects entirely
    // Keep current-timeframe objects, TH3 structure, and ABCD patterns
    if(StringFind(objName, "TH3_Structure_") >= 0) continue;
    if(StringFind(objName, TH3_PATTERN_PREFIX) == 0) continue;  // Never age-delete ABCD patterns
    if(StringLen(objName) >= currentPrefixLen && StringSubstr(objName, 0, currentPrefixLen) == objectPrefix) continue;
    datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
    if(objTime > 0 && objTime < cutoffTime) {
                    CacheRemoveObject(objName);
                    g_suppressDeleteEvents = true;
                    ObjectDelete(0, objName);
                    g_suppressDeleteEvents = false;
                }
            }
        }
        g_objectCountLast = currentObjectCount;
    g_lastObjectCleanup = currentTime;
    TH3_PROF_END(ObjectCleanup);
    }
    static string s_lastPrefix = "";
    if(s_lastPrefix != "" && s_lastPrefix != objectPrefix) {        ClearAllLevels(s_lastPrefix);
    InvalidateTimeframeDependentCaches();
    InvalidateATRCache();
    }
    s_lastPrefix = objectPrefix;
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastDebugLog = 0;
    if(TimeGMT() - s_lastDebugLog > 60) {
        Print("[D][GEN] [MT4 DEBUG] RedrawAllObjects executing - Bid: ", DoubleToString(Bid, Digits));
    s_lastDebugLog = TimeGMT();
    }
    #endif
    g_dailyClosePriceForTH = thBasePrice;
    if(currentTime - g_lastHistoricalUpdate >= 3600 || !g_initialized)
    {
        if(!UpdateHistoricalValues()) {
            _LOG_GATE_E Print("[E][GEN] RedrawAllObjects: UpdateHistoricalValues failed.");
    return; 
        }
        g_initialized = true;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    }

    // Early exit when hidden - skip all drawing
    if(IsIndicatorHidden()) {
        HideAllTHObjects();
        return;
    }

    DrawMainLevels(objectPrefix);
    bool needLabels = (!g_calculatedOnce) || g_labelsRelayoutNeeded;
    if(needLabels)
    {        if (g_dailyClosePriceForTH == EMPTY_VALUE)
        {
            g_dailyClosePriceForTH = thBasePrice;        }
    g_currentLabelYOffset = 0;  // Reset top label stacking offset
    g_currentLabelYOffsetBottom = 0;  // Reset bottom label stacking offset

    TH3_PROF_START(Labels);
    if(g_atrLabelsVisible && inpShowATRLabels) DisplayATRLabels(objectPrefix);
    bool showFractal = (g_thLabelsMode == 1 || g_thLabelsMode == 3);
    bool showStandard = (g_thLabelsMode == 2 || g_thLabelsMode == 3);
    if(inpShowTHLabels && g_thLabelsMode != 0 && showFractal)  DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    if(inpShowTHLabels && g_thLabelsMode != 0 && showStandard) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    TH3_PROF_END(Labels);
    // FIX: Snapshot final Y offset so mode/lock/factor labels always appear below all data labels
    g_modeLabelYOffset = g_currentLabelYOffset;
    // FIX: Reposition ALL overlay labels (mode, lock, ABCD info) to match new layout offset
    RepositionAllOverlayLabels();
    if(!g_calculatedOnce && inpShowTHLevels) g_redrawTHLevelsNeeded = true;
    g_calculatedOnce = true;
    g_labelsRelayoutNeeded = false;
    }
    g_dailyClosePriceForTH = thBasePrice;
    string gvarName = "Biotak_CustomPrice_" + s_cachedSymbol;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + s_cachedSymbol;
    bool lineExists = customPriceLineExists;
    double currentLinePrice = lineExists ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0.0;
    if(!g_customPriceLineDragging) {
        bool hasGlobalVar = GlobalVariableCheck(gvarName);
    double savedPrice = hasGlobalVar ? GlobalVariableGet(gvarName) : 0.0;
    if(g_customPriceKeyboardOverride && savedPrice > 0.0) {
        if(MathAbs(g_customTHStartPrice - savedPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = savedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            }
    if(!lineExists) {
        CreateCustomPriceLine(g_customTHStartPrice, s_cachedDigits, false, "Drag to adjust (live update)");
            }
        } else if(inpCustomTHStartPrice > 0.0) {
        if(MathAbs(g_customTHStartPrice - inpCustomTHStartPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = inpCustomTHStartPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    GlobalVariableSet(gvarName, g_customTHStartPrice);
    if(!lineExists) {
        CreateCustomPriceLine(g_customTHStartPrice, s_cachedDigits, false, "Drag to adjust (live update)");
                } else {
                    ObjectSetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, g_customTHStartPrice);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                  "[PIN] Custom Price: " + DoubleToString(g_customTHStartPrice, s_cachedDigits) + " | Drag to adjust (live update)");
                }
                
                g_redrawTHLevelsNeeded = true;
            }
        } else if(hasGlobalVar && savedPrice > 0.0) {
        if(MathAbs(g_customTHStartPrice - savedPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = savedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            }
    if(!lineExists) {
        if(CreateCustomPriceLine(g_customTHStartPrice, s_cachedDigits, false, "Drag to adjust (live update)")) {
                    _LOG_GATE_I Print("[I][GEN] Custom price line restored at: ", DoubleToString(g_customTHStartPrice, s_cachedDigits));
        }
            }
        } else {            g_thStartPointType = inpTHStartPointType;
    g_customTHStartPrice = 0.0;
        }
    }
    
    if (inpShowTHLevels && g_redrawTHLevelsNeeded)
    {
        #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastLevelRedrawLog = 0;
    if(TimeCurrent() - s_lastLevelRedrawLog > 5) {
            Print("[D][GEN] [MT4] [DRAW] REDRAWING LEVELS | Base Price: ", DoubleToString(g_dailyClosePriceForTH, Digits),
                  " | Mode: ", GetStepModeName(GetCurrentStepMode()));
    s_lastLevelRedrawLog = TimeCurrent();
        }
    #endif
    bool skipZones = g_customPriceLineDragging;
    TH3_PROF_START(Levels);
    ClearAllLevels(objectPrefix, !skipZones);
    DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH);
    TH3_PROF_END(Levels);
    g_redrawTHLevelsNeeded = false;
    }
    else if (!inpShowTHLevels && g_redrawTHLevelsNeeded)
    {        ClearAllLevels(objectPrefix);
    g_redrawTHLevelsNeeded = false;
    }    
    CheckAlerts(objectPrefix, g_currentPrice);
}
    int OnCalculateHandler(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
        static uint s_lastCPUTime = 0;
    static int s_cpuWarningCount = 0;
    uint startTime = GetTickCount();
    // PERF: Cache Bid/Ask once per tick
    CacheTickPrices();
    if(IsIndicatorHidden())
    {
        return(rates_total);
    }
    static uint s_lastTickMs = 0;
    static double s_lastPrice = 0;
    static datetime s_lastBarTime = 0;
    static int s_lastPeriod = -1;
    static double s_lastCustomPrice = 0;
    uint nowMs = GetTickCount();
    double currentPrice = (rates_total > 0) ? close[rates_total-1] : 0;
    datetime currentBarTime = (rates_total > 0) ? time[rates_total-1] : (datetime)0;
    int currentPeriod = _Period;
    double currentCustomPrice = g_customTHStartPrice;
    double priceChangePercent = 0;
    if(s_lastPrice > 0 && currentPrice > 0) {
        priceChangePercent = MathAbs((currentPrice - s_lastPrice) / s_lastPrice) * 100.0;
    }
    bool significantPriceChange = (priceChangePercent > 0.1);
    bool barsChanged = (currentBarTime != s_lastBarTime && s_lastBarTime != 0);
    bool isNewBar = barsChanged;
    bool timeframeChanged = (currentPeriod != s_lastPeriod && s_lastPeriod != -1);
    bool customPriceChanged = false;
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        customPriceChanged = (MathAbs(currentCustomPrice - s_lastCustomPrice) > EPSILON_PRICE);
    }
    bool tickThrottled = (nowMs - s_lastTickMs < 50 && s_lastTickMs != 0);
    if(timeframeChanged) {        InvalidateTimeframeDependentCaches();
    InvalidateATRCache();
        _LOG_GATE_I Print("[I][GEN] Timeframe changed: ", s_lastPeriod, " -> ", currentPeriod);
    }
    if(barsChanged) {        InvalidateFactorCache();
    }
    if(customPriceChanged) {        InvalidateTHCache();
        _LOG_GATE_I Print("[I][GEN] Custom price changed: ", DoubleToString(s_lastCustomPrice, Digits));
    }
    if(rates_total > 0)
    {
        if(tickThrottled && !isNewBar && !g_redrawTHLevelsNeeded && 
           !g_forceClearOnNextDraw && !significantPriceChange && 
           !timeframeChanged && !customPriceChanged) {
        return rates_total;
        }
    s_lastTickMs = nowMs;
    s_lastPrice = currentPrice;
    s_lastBarTime = currentBarTime;
    s_lastPeriod = currentPeriod;
    s_lastCustomPrice = currentCustomPrice;
    TH3_PROF_START(RedrawCall);
    RedrawAllObjects(g_redrawTHLevelsNeeded || g_forceClearOnNextDraw);
    TH3_PROF_END(RedrawCall);
    // FIX: ChartRedraw after RedrawAllObjects — ensures object changes are immediately visible
    ThrottledChartRedraw();
    if(barsChanged || s_lastBarTime == 0) {
        int totalObjects = ObjectsTotal(0, -1, -1);
    if(totalObjects > MAX_SAFE_OBJECTS && totalObjects < CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
                if(s_cpuWarningCount % 10 == 0) {                    Print("[WARN] Performance Warning: ", totalObjects, " objects on chart (recommended max: ", MAX_SAFE_OBJECTS, ")");
    Print("[D][GEN] [CLEAN] Consider reducing inpMaxLevels for better performance");
                }
    #endif
    s_cpuWarningCount++;
            }
            else if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("[E][GEN] [CRIT] CRITICAL: ", totalObjects, " objects approaching MT4 limit (64000)!");
    Print("[D][GEN] [CLEAN] EMERGENCY: Using ObjectsDeleteAll for cleanup...");
    #endif
    int deleted = 0;
    deleted += ObjectsDeleteAll(0, "Zone_", -1, -1);
    deleted += ObjectsDeleteAll(0, "Mid_", -1, -1);
    _LOG_GATE_I Print("[I][GEN] Emergency cleanup completed. Objects: ", totalObjects, " -> ", ObjectsTotal(0), " (deleted=", deleted, ")");
    InvalidateObjectCountCache();
    }
        }
    }
    uint elapsed = GetTickCount() - startTime;
    if(elapsed > CPU_WARNING_MS) {
        if(elapsed > CPU_CRITICAL_MS) {
            _LOG_GATE_E Print("[E][GEN] [CRIT] CRITICAL CPU: OnCalculate took ", elapsed, "ms! Reduce inpMaxTHLevels!");
    }
        else if(s_lastCPUTime == 0 || GetTickCount() - s_lastCPUTime > 60000) {
            _LOG_GATE_W Print("[W][GEN] CPU Warning: OnCalculate took ", elapsed, "ms (threshold: ", CPU_WARNING_MS, "ms)");
    s_lastCPUTime = GetTickCount();
        }
    }
    return rates_total;
}

// Robust hotkey matcher: compares both key code (lparam) and key text (sparam)
bool IsHotkeyPressed(const long lparam, const string sparam, const string hotkey) {
    if(StringLen(hotkey) <= 0) return false;
    string k = hotkey;
    StringToUpper(k);
    int code = (int)StringGetCharacter(k, 0);
    if((int)lparam == code) return true;

    // Some keyboard layouts deliver different lparam; sparam can contain the key text
    if(StringLen(sparam) > 0) {
        string sp = sparam;
        StringToUpper(sp);
        if((int)StringGetCharacter(sp, 0) == code) return true;
    }
    return false;
}

// Lightweight label-only redraw (no level recalculation). Safe to call from hotkeys.
void RedrawLabelsOnly() {
    if(IsIndicatorHidden()) return;
    datetime currentTime = TimeGMT();
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";

    g_currentLabelYOffset = 0;
    g_currentLabelYOffsetBottom = 0;

    if(g_atrLabelsVisible && inpShowATRLabels) {
        DisplayATRLabels(objectPrefix);
    }

    bool showFractal = (g_thLabelsMode == 1 || g_thLabelsMode == 3);
    bool showStandard = (g_thLabelsMode == 2 || g_thLabelsMode == 3);
    // TH labels need a valid base price; if not ready yet, skip TH to avoid broken output.
    if(inpShowTHLabels && g_thLabelsMode != 0 && g_dailyClosePriceForTH != EMPTY_VALUE && g_dailyClosePriceForTH > 0.0) {
        if(showFractal)  DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(showStandard) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    }
    // FIX: Snapshot final offset for mode/lock/factor labels
    g_modeLabelYOffset = g_currentLabelYOffset;
    // FIX: Reposition ALL overlay labels (mode, lock, ABCD info) to match new layout offset
    RepositionAllOverlayLabels();
}

//+------------------------------------------------------------------+
//| HELPER: Adjust factor value by step (+1 = increase, -1 = decrease)|
//+------------------------------------------------------------------+
void AdjustFactorValue(int direction)
{
    double currentFactor = g_factorValueOverride;
    if(currentFactor <= 0) {
        if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
            currentFactor = inpFactorValue;
        } else {
            currentFactor = GetDefaultFactorValue(g_dailyClosePriceForTH);
            if(currentFactor <= 0 || currentFactor > MAX_FACTOR_VALUE) {
                _LOG_GATE_E Print("[E][GEN] Factor adjust: Invalid factor from GetDefaultFactorValue, using ", DEFAULT_FACTOR_FALLBACK);
                currentFactor = DEFAULT_FACTOR_FALLBACK;
            }
        }
    }
    double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : DEFAULT_FACTOR_ADJUST_STEP;
    double newFactor = NormalizeDouble(currentFactor + step * direction, 2);
    if(newFactor < MIN_FACTOR_VALUE) newFactor = MIN_FACTOR_VALUE;
    if(newFactor > MAX_FACTOR_VALUE) newFactor = MAX_FACTOR_VALUE;
    g_factorValueOverride = newFactor;
    string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
    if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
        _LOG_GATE_E Print("[E][GEN] WARNING: Failed to persist Factor value to GlobalVariable");
    }
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    // FIX: Move UpdateFactorLabel AFTER RedrawAllObjects so g_modeLabelYOffset is finalized
    UpdateFactorLabel(newFactor);
    ThrottledChartRedraw();
}

//+------------------------------------------------------------------+
//| HELPER: Cycle TH3 frequency forward (binary subdivision)         |
//| Each step = 1.5625% (100/64). Index range: 1..128 (200%)         |
//+------------------------------------------------------------------+
void CycleTH3Frequency()
{
    if(!inpEnableTH3Tool) return;
    if(g_th3FreqIndex < MIN_TH3_FREQ_INDEX || g_th3FreqIndex > MAX_TH3_FREQ_INDEX)
        g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
    int newIndex = g_th3FreqIndex + 1;
    if(newIndex > MAX_TH3_FREQ_INDEX) return;  // Clamp at 400% — don't wrap
    g_th3FreqIndex = newIndex;
    g_th3FreqOverride = GetFrequencyByIndex(g_th3FreqIndex);
    string chartIdStr = GetCachedChartIdStr();
    GlobalVariableSet("Biotak_TH3Freq_" + chartIdStr, g_th3FreqOverride);
    GlobalVariableSet("Biotak_TH3FreqIdx_" + chartIdStr, (double)g_th3FreqIndex);
    UpdateAllTH3Objects();
    UpdateTH3FreqLabel(g_th3FreqOverride);
    ThrottledChartRedraw();
    Print("TH3 Frequency: ", DoubleToString(g_th3FreqOverride, 4), "% [#", g_th3FreqIndex, "] depth=", GetBinaryDepthLevel(g_th3FreqIndex));
}

//+------------------------------------------------------------------+
//| HELPER: Decrease TH3 frequency (binary subdivision, clamp at min)|
//+------------------------------------------------------------------+
void DecrementTH3Frequency()
{
    if(!inpEnableTH3Tool) return;
    if(g_th3FreqIndex < MIN_TH3_FREQ_INDEX || g_th3FreqIndex > MAX_TH3_FREQ_INDEX)
        g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
    int newIndex = g_th3FreqIndex - 1;
    if(newIndex < MIN_TH3_FREQ_INDEX) return;  // Clamp at 1.5625% — don't wrap
    g_th3FreqIndex = newIndex;
    g_th3FreqOverride = GetFrequencyByIndex(g_th3FreqIndex);
    string chartIdStr = GetCachedChartIdStr();
    GlobalVariableSet("Biotak_TH3Freq_" + chartIdStr, g_th3FreqOverride);
    GlobalVariableSet("Biotak_TH3FreqIdx_" + chartIdStr, (double)g_th3FreqIndex);
    UpdateAllTH3Objects();
    UpdateTH3FreqLabel(g_th3FreqOverride);
    ThrottledChartRedraw();
    Print("TH3 Frequency: ", DoubleToString(g_th3FreqOverride, 4), "% [#", g_th3FreqIndex, "] depth=", GetBinaryDepthLevel(g_th3FreqIndex));
}

    void OnChartEventHandler(const int id, const long &lparam, const double &dparam, const string &sparam)
{
        if(id == CHARTEVENT_KEYDOWN)
    {
        string mutableHideKey = inpHideKey;
    StringToUpper(mutableHideKey);
    int hideKeyCode = StringGetCharacter(mutableHideKey, 0);
    if(IsHotkeyPressed(lparam, sparam, inpHideKey))
        {
        string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    double currentState = 0.0;
    if(GlobalVariableCheck(gvar_name)) {
                currentState = GlobalVariableGet(gvar_name);
    if(currentState != 0.0 && currentState != 1.0) {
                    currentState = 0.0;                }
            }
    bool isBecomingHidden = (currentState == 0.0);
    if(!GlobalVariableSet(gvar_name, isBecomingHidden ? 1.0 : 0.0)) {
        LOG_W(LOG_CAT_KEYS, "F key: Failed to set GlobalVariable, Error: " + IntegerToString(GetLastError()));
    }
    RefreshIsHiddenCache();
    if(isBecomingHidden)
            {
        LOG_I(LOG_CAT_KEYS, "F key: Hiding all objects");
    // Cancel ABCD drawing mode if active (prevent stale drawing state)
    if(g_abcdDrawing) {
        g_abcdDrawing = false;
        g_abcdPointCount = 0;
        g_suppressDeleteEvents = true;
        ObjectsDeleteAll(0, TH3_TEMP_PREFIX);
        ObjectsDeleteAll(0, TH3_TEMP_LINE_PREFIX);
        g_suppressDeleteEvents = false;
        ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
        Comment("");
    }
    HideAllTHObjects();
    CleanupCustomPriceObjects(false, true);
    g_redrawTHLevelsNeeded = false;
            }
            else
            {
        LOG_I(LOG_CAT_KEYS, "F key: Showing all objects");
    // Fast show: toggle visibility instead of delete+recreate
    int total = ObjectsTotal(0, -1, -1);
    string cachedPrefixF = inpObjectPrefix;
    int prefixLenF = StringLen(cachedPrefixF);
    for(int i = total - 1; i >= 0; i--)
                {
        string objName = ObjectName(0, i, -1, -1);
    if(StringLen(objName) >= prefixLenF && StringSubstr(objName, 0, prefixLenF) == cachedPrefixF)
                    {
        // Keep ATR objects hidden if ATR labels are disabled (A key / Inputs)
        bool isATRObject = (StringFind(objName, "ATR_") >= 0);
        if(isATRObject) {
            bool atrShouldShow = (g_atrLabelsVisible && inpShowATRLabels);
            if(!atrShouldShow) {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            } else {
                // Targets obey inpShowATRTargets
                if(StringFind(objName, "ATR_Targets_") >= 0 && !inpShowATRTargets)
                    ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                else
                    ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            }
            continue;
        }
        // Keep trigger objects hidden if triggers are disabled
        bool isTriggerObject = (StringFind(objName, "TriggerTH_Up_") >= 0 || 
                                               StringFind(objName, "TriggerTH_Down_") >= 0);
    if(isTriggerObject && !g_triggerLevelsEnabled)
                        {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                        }
        // Keep line objects hidden if lines are disabled
        else if(!g_linesVisible)
                        {
            int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
    if(objType == OBJ_HLINE || objType == OBJ_TREND)
                            {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                            }
                            else
                            {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                            }
                        }
                        else
                        {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                        }
                    }
                }
    // NOTE: ABCD pattern objects are NOT affected by F key — they remain always visible
    // Restore labels visibility
    if(ObjectFind(0, g_stepModeLabelName) >= 0)
        ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    if(ObjectFind(0, g_factorLabelName) >= 0)
        ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    if(ObjectFind(0, g_th3FreqLabelName) >= 0)
        ObjectSetInteger(0, g_th3FreqLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    if(ObjectFind(0, g_lockStatusLabelName) >= 0)
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    // Restore custom price line if active
    if(g_customPriceKeyboardOverride && ObjectFind(0, g_customPriceHorizontalLineName) >= 0)
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

    // Defer recalculation to next OnCalculate tick
    g_redrawTHLevelsNeeded = true;

    // Re-apply label visibility consistently (ATR + TH mode split)
    string objectPrefixLocal = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    SetATRLabelsVisibility(objectPrefixLocal, (g_atrLabelsVisible && inpShowATRLabels));
    SetTHLabelsVisibility(objectPrefixLocal, (inpShowTHLabels ? g_thLabelsMode : 0));
    }
    // Direct ChartRedraw for F key (ThrottledChartRedraw skips when hidden)
            ChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpLinesToggleKey))
        {            g_linesVisible = !g_linesVisible;
    // FIX: Immediately update cache so subsequent RedrawAllObjects/mode switches use correct state
    UpdateLinesVisibleCache(g_linesVisible);
    string gvar_name = "Biotak_LinesVisible_" + GetCachedChartIdStr();
    GlobalVariableSet(gvar_name, g_linesVisible ? 1.0 : 0.0);
    int total = ObjectsTotal(0, -1, -1);
    string cachedPrefixL = inpObjectPrefix;
    int prefixLenL = StringLen(cachedPrefixL);
    for(int i = 0; i < total; i++)
            {
        string objName = ObjectName(0, i, -1, -1);
    if(StringLen(objName) >= prefixLenL && StringSubstr(objName, 0, prefixLenL) == cachedPrefixL)
                {
        int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
    if(objType == OBJ_HLINE || objType == OBJ_TREND)
                    {
        if(g_linesVisible)
                        {
                            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                        }
                        else
                        {
                            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                        }
                    }
                }
            }
    LOG_I(LOG_CAT_LINES, "Lines " + (g_linesVisible ? "VISIBLE" : "HIDDEN"));
    ThrottledChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpCustomPriceKey))
        {            
            g_waitingForCustomPriceClick = true;
    g_customPriceKeyboardOverride = true;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + GetCachedSymbol();
    GlobalVariableSet(overrideFlagName, 1.0);
            _LOG_GATE_D Print("[D][GEN] Press anywhere on the chart to set custom TH start price");
    ObjectDelete(0, g_customPriceHorizontalLineName);
    g_customPriceLineCreated = false;
    double currentPrice = iClose(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0);
    g_customTHStartPrice = currentPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    string gvarName = "Biotak_CustomPrice_" + GetCachedSymbol();
    GlobalVariableSet(gvarName, currentPrice);
    if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, currentPrice)) {
                _LOG_GATE_E Print("[E][GEN] Failed to create custom price horizontal line. Error: ", GetLastError());
    return;
            }
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                          "[PIN] Custom Price: " + DoubleToString(currentPrice, Digits) + " | Drag to adjust, Double-click to confirm");
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
            _LOG_GATE_D Print("[D][GEN] [PIN] Custom price set to: ", DoubleToString(currentPrice, Digits), " - Drag to adjust.");
    ThrottledChartRedraw();
    return;
        }
    if(lparam == 27)        {
        string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    bool customPriceActive = GlobalVariableCheck(gvarName);
    if(g_waitingForCustomPriceClick || customPriceActive || g_customPriceKeyboardOverride)
            {
                CleanupCustomPriceObjects(true, true);
    g_thStartPointType = inpTHStartPointType;
    g_customPriceKeyboardOverride = false;
    GlobalVariableSet(overrideFlagName, 0.0);
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
                _LOG_GATE_D Print("[D][GEN] Custom price mode cancelled - returned to Input Parameter setting");
    ThrottledChartRedraw();
    return;
            }
        }
    if(IsHotkeyPressed(lparam, sparam, inpTriggerLevelsKey))
        {            g_triggerLevelsEnabled = !g_triggerLevelsEnabled;
    // FIX: Immediately update cache to prevent stale state during subsequent redraws
    UpdateTriggerEnabledCache(g_triggerLevelsEnabled);
    string triggerGvarName = "Biotak_TriggerLevels_" + GetCachedChartIdStr();
    GlobalVariableSet(triggerGvarName, g_triggerLevelsEnabled);
    if(g_triggerLevelsEnabled) {
                LOG_I(LOG_CAT_KEYS, "Trigger Levels: ON");
    } else {
                LOG_I(LOG_CAT_KEYS, "Trigger Levels: OFF");
    }
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpATRLabelsKey))
        {
        // If user disabled ATR in Inputs, keep it off (and persist off)
    string atrGvarNameKey = "Biotak_ATRLabels_" + GetCachedChartIdStr();
    if(!inpShowATRLabels) {
        g_atrLabelsVisible = false;
        GlobalVariableSet(atrGvarNameKey, 0.0);
    } else {
        g_atrLabelsVisible = !g_atrLabelsVisible;
        GlobalVariableSet(atrGvarNameKey, g_atrLabelsVisible ? 1.0 : 0.0);
    }

    // O(1) visibility toggle (no delete, no chart-wide scan)
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    SetATRLabelsVisibility(objectPrefix, g_atrLabelsVisible && inpShowATRLabels);

    // Schedule lightweight relayout so TH labels move up/down on next tick (no lag on keydown)
    g_labelsRelayoutNeeded = true;
    // FIX: Immediate relayout so labels reposition without waiting for next tick
    RedrawLabelsOnly();
        LOG_I(LOG_CAT_LABELS, "ATR Labels " + (g_atrLabelsVisible ? "VISIBLE" : "HIDDEN"));
    ChartRedraw();
    return;
        }

    // TH labels toggle
    if(IsHotkeyPressed(lparam, sparam, inpTHLabelsKey))
        {
        string thGvar = "Biotak_THLabels_" + GetCachedChartIdStr();
    if(!inpShowTHLabels) {
        g_thLabelsMode = 0;
        g_thLabelsVisible = false;
        GlobalVariableSet(thGvar, 0.0);
    } else {
        if(g_thLabelsMode < 0 || g_thLabelsMode > 3) g_thLabelsMode = 0;
        g_thLabelsMode = (g_thLabelsMode + 1) % 4; // OFF->FRACTAL->STANDARD->BOTH->OFF
        g_thLabelsVisible = (g_thLabelsMode != 0);
        GlobalVariableSet(thGvar, (double)g_thLabelsMode);
    }
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    SetTHLabelsVisibility(objectPrefix, (inpShowTHLabels ? g_thLabelsMode : 0));
    g_labelsRelayoutNeeded = true;
    RedrawLabelsOnly();
        LOG_IP1(LOG_CAT_LABELS, "TH Labels mode=", IntegerToString(g_thLabelsMode) + " (0=OFF,1=FRACTAL,2=STANDARD,3=BOTH)");
    ChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpTH3ToolKey))
        {
            ToggleTH3Tool();
    ThrottledChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpStepModeKey))
        {            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    ENUM_STEP_CALCULATION_MODE newMode = (ENUM_STEP_CALCULATION_MODE)(((int)currentMode + 1) % 6);
    g_stepModeOverride = (int)newMode;
    string stepModeGvarName = "Biotak_StepMode_" + GetCachedChartIdStr();
    GlobalVariableSet(stepModeGvarName, g_stepModeOverride);
    LOG_IP1(LOG_CAT_KEYS, "Step Mode changed to: ", IntegerToString(g_stepModeOverride));
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    g_calculatedOnce = false;  // FIX: Force label refresh on mode change
    RedrawAllObjects(true);
    // FIX: Move UpdateStepModeLabel AFTER RedrawAllObjects so g_modeLabelYOffset is finalized
    UpdateStepModeLabel();
    ThrottledChartRedraw();
    return;
        }
    // KEY '1' — Decrease Factor
    if(lparam == '1') { AdjustFactorValue(-1); return; }

    // KEY '2' — Increase Factor
    else if(lparam == '2') { AdjustFactorValue(+1); return; }

    // KEY '3' — Decrease TH3 Frequency (cycle backward through array)
    else if(lparam == '3') { DecrementTH3Frequency(); return; }

    // KEY '4' — Increase TH3 Frequency (cycle forward through array)
    else if(lparam == '4') { CycleTH3Frequency(); return; }

    if(IsHotkeyPressed(lparam, sparam, inpResetKey))
        {            g_stepModeOverride = -1;
    g_factorValueOverride = 0;
    g_th3FreqOverride = 0;
    g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
    g_timeframeLocked = false;
    g_lockedPeriod = 0;
    g_triggerLevelsEnabled = inpShowTrigger;
    g_linesVisible = inpShowLines;
    // FIX: Invalidate all visibility caches after resetting toggle states
    InvalidateAllVisibilityCaches();
    g_atrLabelsVisible = inpShowATRLabels;
    if(inpShowTHLabels) {
        if(inpShowFractalTHs && inpShowStandardTHs) g_thLabelsMode = 3;
        else if(inpShowFractalTHs) g_thLabelsMode = 1;
        else if(inpShowStandardTHs) g_thLabelsMode = 2;
        else g_thLabelsMode = 0;
    } else {
        g_thLabelsMode = 0;
    }
    g_thLabelsVisible = (g_thLabelsMode != 0);
    if(inpEnableTH3Tool) {
                UpdateAllTH3Objects();
            }
    // FIX: Cancel any active ABCD drawing to prevent stale prompts
    if(g_abcdDrawing) {
        g_abcdDrawing = false;
        g_abcdPointCount = 0;
        g_suppressDeleteEvents = true;  // Prevent cascade from temp object cleanup
        ObjectsDeleteAll(0, TH3_TEMP_PREFIX);
        ObjectsDeleteAll(0, TH3_TEMP_LINE_PREFIX);
        g_suppressDeleteEvents = false;
    }
    g_customPriceKeyboardOverride = false;
    g_thStartPointType = inpTHStartPointType;
    g_customTHStartPrice = inpCustomTHStartPrice;
    string chartIdStr = GetCachedChartIdStr();
    string symbolName = GetCachedSymbol();
    GlobalVariableDel("Biotak_StepMode_" + chartIdStr);
    GlobalVariableDel("Biotak_Factor_" + chartIdStr);
    GlobalVariableDel("Biotak_LockTF_" + chartIdStr);
    GlobalVariableDel("Biotak_LockTFPeriod_" + chartIdStr);
    GlobalVariableDel("Biotak_TriggerLevels_" + chartIdStr);
    GlobalVariableDel("Biotak_LinesVisible_" + chartIdStr);
    GlobalVariableDel("Biotak_ATRLabels_" + chartIdStr);
    GlobalVariableDel("Biotak_THLabels_" + chartIdStr);
    GlobalVariableDel("Biotak_CustomPriceOverride_" + symbolName);
    GlobalVariableDel("Biotak_TH3Freq_" + chartIdStr);
    GlobalVariableDel("Biotak_TH3FreqIdx_" + chartIdStr);
    if(inpCustomTHStartPrice > 0.0) {                GlobalVariableSet("Biotak_CustomPrice_" + symbolName, inpCustomTHStartPrice);
    CreateCustomPriceLine(inpCustomTHStartPrice, Digits);
            } else {
        if(GlobalVariableCheck("Biotak_CustomPrice_" + symbolName)) GlobalVariableDel("Biotak_CustomPrice_" + symbolName);
    ObjectDelete(0, g_customPriceHorizontalLineName);
    g_customPriceLineCreated = false;
            }
    UpdateLockStatusLabel();
    Comment("\n\n        [ RESET ]");
    g_resetCommentCreateTime = GetTickCount();
    LOG_I(LOG_CAT_KEYS, "Reset: All overrides cleared");
    ClearAllModeLabels();
    EventSetTimer(1);  // Check every second for expired labels
    g_forceClearOnNextDraw = true;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
    return;
        }
    if(IsHotkeyPressed(lparam, sparam, inpLockKey))
        {
        bool hadCustomPrice = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
    double savedCustomPrice = hadCustomPrice ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0;
    g_suppressDeleteEvents = true;  // Prevent cascade deletion of ABCD patterns
    ObjectsDeleteAll(0, inpObjectPrefix);
    g_suppressDeleteEvents = false;
    g_timeframeLocked = !g_timeframeLocked;
    if(g_timeframeLocked)
            {
                g_lockedPeriod = GetCachedPeriod();
    LOG_I(LOG_CAT_KEYS, "Timeframe LOCKED to: " + GetCurrentTimeframe());
                _LOG_GATE_D Print("[D][GEN] [LOCK] Timeframe locked to: ", GetCurrentTimeframe());
    }
            else
            {
        LOG_I(LOG_CAT_KEYS, "Timeframe UNLOCKED - following chart: " + GetCurrentTimeframe());
                _LOG_GATE_D Print("[D][GEN] [UNLOCK] Timeframe unlocked - now following chart timeframe: ", GetCurrentTimeframe());
    }
    UpdateLockStatusLabel();
    string lockChartIdStr = GetCachedChartIdStr();
    string lockFlagName = "Biotak_LockTF_" + lockChartIdStr;
    GlobalVariableSet(lockFlagName, g_timeframeLocked);
    string lockPeriodName = "Biotak_LockTFPeriod_" + lockChartIdStr;
    GlobalVariableSet(lockPeriodName, g_lockedPeriod);
    g_forceClearOnNextDraw = true;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    if(hadCustomPrice && savedCustomPrice > 0) {                g_customTHStartPrice = savedCustomPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    if(ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, savedCustomPrice)) {
                    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                  "[PIN] Custom Price: " + DoubleToString(savedCustomPrice, Digits) + " | Drag to adjust (live update)");
    g_customPriceLineCreated = true;
                }
            }
            
            ThrottledChartRedraw();
    return;
        }
    }
    if(g_abcdDrawing || 
       id == CHARTEVENT_OBJECT_DRAG || 
       id == CHARTEVENT_OBJECT_DELETE ||
       id == CHARTEVENT_MOUSE_MOVE) {
        OnABCDMouseEvent(id, lparam, dparam, sparam);
    if(g_abcdDrawing && id == CHARTEVENT_CLICK) {
            return;        }
    }

    // Chart layout/size changes (Navigator/Terminal toggles, window resize, scroll, zoom, etc.)
    // Re-layout labels immediately so they don't "lag" until next tick.
    // FIX: Also handle scroll/zoom to ensure viewport-culled levels are drawn
    if(id == CHARTEVENT_CHART_CHANGE) {
        if(IsIndicatorHidden()) return;
        static uint s_lastLayoutMs = 0;
        static int s_lastW = -1;
        static int s_lastH = -1;
        static double s_lastVisibleMin = 0;
        static double s_lastVisibleMax = 0;
        uint nowMs = GetTickCount();
        if(nowMs - s_lastLayoutMs < CHART_CHANGE_THROTTLE_MS) return; // throttle bursts

        int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        bool sizeChanged = (w != s_lastW || h != s_lastH);
        
        // Detect scroll/zoom by checking visible price range change
        double visibleMin = ChartGetDouble(0, CHART_PRICE_MIN);
        double visibleMax = ChartGetDouble(0, CHART_PRICE_MAX);
        bool viewportChanged = (MathAbs(visibleMin - s_lastVisibleMin) > GetCachedPoint() ||
                                MathAbs(visibleMax - s_lastVisibleMax) > GetCachedPoint());
        
        if(!sizeChanged && !viewportChanged) return;
        
        s_lastW = w;
        s_lastH = h;
        s_lastVisibleMin = visibleMin;
        s_lastVisibleMax = visibleMax;
        s_lastLayoutMs = nowMs;

        if(sizeChanged) g_labelsRelayoutNeeded = true;
        // FIX: Trigger full level redraw on scroll/zoom so viewport-culled levels appear
        if(viewportChanged) g_redrawTHLevelsNeeded = true;
        
        if(sizeChanged) RedrawLabelsOnly();
        ChartRedraw();
        return;
    }
    if(id == CHARTEVENT_CLICK && g_waitingForCustomPriceClick)
    {
        if(StringFind(sparam, "r") >= 0)
        {            CleanupCustomPriceObjects(true, true);
            _LOG_GATE_D Print("[D][GEN] Custom price setting cancelled (right-click)");
    ThrottledChartRedraw();
    return;
        }
    double clickedPrice = dparam;
    if(!g_customPriceLineCreated)
        {            if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, clickedPrice)) {
                _LOG_GATE_E Print("[E][GEN] Failed to create custom price horizontal line. Error: ", GetLastError());
    return;
            }
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "[PIN] Custom Price Line - Drag to adjust, Double-click to confirm");
    g_customPriceLineCreated = true;
            _LOG_GATE_D Print("[D][GEN] [PIN] Drag the orange dotted line to adjust price. Double-click to confirm.");
    }
        else
        {
        uint currentTickCount = GetTickCount();
    bool isDoubleClick = (currentTickCount - g_lastClickTickCount < DOUBLE_CLICK_THRESHOLD_MS);
    g_lastClickTickCount = currentTickCount;
    if (isDoubleClick || !g_customPriceLineCreated)            {
                g_waitingForCustomPriceClick = false;
    g_customPriceKeyboardOverride = true;
    double selectedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
    g_customTHStartPrice = selectedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    GlobalVariableSet(gvarName, selectedPrice);
    GlobalVariableSet(overrideFlagName, 1.0);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "[PIN] Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
                _LOG_GATE_I Print("[I][GEN] Custom Price Mode activated! Using ", inpMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
    }
        }
        
        ThrottledChartRedraw();
    }
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_customPriceHorizontalLineName)
    {
        uint currentTickCount = GetTickCount();
    bool isDoubleClick = (currentTickCount - g_lastClickTickCount < DOUBLE_CLICK_THRESHOLD_MS);
    g_lastClickTickCount = currentTickCount;
    if (isDoubleClick)
        {
            g_waitingForCustomPriceClick = false;
    g_customPriceKeyboardOverride = true;
    double selectedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
    g_customTHStartPrice = selectedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    GlobalVariableSet(gvarName, selectedPrice);
    GlobalVariableSet(overrideFlagName, 1.0);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "[PIN] Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
            _LOG_GATE_I Print("[I][GEN] Custom Price Mode activated! Using ", inpMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
    }
    }
    if(id == CHARTEVENT_MOUSE_MOVE && g_customPriceLineCreated)
    {
        int mouseFlags = (int)StringToInteger(sparam);
    bool leftButtonDown = (mouseFlags & 1) != 0;
    if(leftButtonDown)
        {
        bool lineSelected = (bool)ObjectGetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED);
    if(lineSelected)
            {                
                g_customPriceLineDragging = true;
    double currentLinePrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
    if(currentLinePrice > 0 && MathAbs(currentLinePrice - g_customTHStartPrice) > _Point * 0.5)
                {
        uint nowMs = GetTickCount();
    if(nowMs - g_lastDragRedrawTime > DRAG_REDRAW_THROTTLE_MS)
                    {
                        g_customTHStartPrice = currentLinePrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
    g_lastDragRedrawTime = nowMs;
                    }
                }
            }
        }
        else
        {
        if(g_customPriceLineDragging) {
                g_customPriceLineDragging = false;
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
            }
        }
    }
    if(id == CHARTEVENT_OBJECT_DRAG && sparam == g_customPriceHorizontalLineName)
    {        g_customPriceLineDragging = false;
    double draggedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
    g_customTHStartPrice = draggedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    g_customPriceKeyboardOverride = true;
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    GlobalVariableSet(gvarName, draggedPrice);
    GlobalVariableSet(overrideFlagName, 1.0);
    if (g_waitingForCustomPriceClick) {
        string tooltip = "Current price: " + DoubleToString(draggedPrice, Digits) + " - Double-click to confirm";
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, tooltip);
        } else {
        string tooltip = "Custom TH start price: " + DoubleToString(draggedPrice, Digits) + " - Drag to adjust";
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, tooltip);
            _LOG_GATE_D Print("[D][GEN] Custom TH start price updated to: ", DoubleToString(draggedPrice, Digits));
    }        
        g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    }
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "ABCD_Pattern_") == 0)
        {
        string patternName = "";
    int suffixPos = -1;
    if(StringFind(sparam, "_Point_") > 0) suffixPos = StringFind(sparam, "_Point_");
    else if(StringFind(sparam, "_Label_") > 0) suffixPos = StringFind(sparam, "_Label_");
    else if(StringFind(sparam, "_Line_") > 0) suffixPos = StringFind(sparam, "_Line_");
    else if(StringFind(sparam, "_Target_") > 0) suffixPos = StringFind(sparam, "_Target_");
    else if(StringFind(sparam, "_Zone") > 0) suffixPos = StringFind(sparam, "_Zone");
    if(suffixPos > 0) {
                patternName = StringSubstr(sparam, 0, suffixPos);
            } else {
                patternName = sparam;            }
    if(patternName != "") {
                SetActiveABCDPattern(patternName);
            }
        }
        else
        {            
            SetActiveABCDPattern("");
        }
    }
}

#endif // EVENT_HANDLERS_MQH
