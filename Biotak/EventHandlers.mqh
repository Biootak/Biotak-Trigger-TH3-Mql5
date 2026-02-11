
int OnInitHandler() {    InitializeGlobalCache();
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    bool shouldBeHidden = false;
    if(GlobalVariableCheck(gvar_name)) {
        double gvarValue = GlobalVariableGet(gvar_name);
    bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
    bool isOne = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
    if(isZero || isOne) {
            shouldBeHidden = isOne;        } else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ OnInit: Corrupted hidden state detected!");
    Print("   Expected: 0.0 or 1.0");
    Print("   Actual: ", DoubleToString(gvarValue, 10));
    Print("   Action: Resetting to visible (0.0)");
    #endif
    GlobalVariableSet(gvar_name, 0.0);
    shouldBeHidden = false;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("🔧 OnInit: shouldBeHidden=", shouldBeHidden);
    #endif
    string chartIdStr = GetCachedChartIdStr();
    string triggerGvarName = "Biotak_TriggerLevels_" + chartIdStr;
    if(GlobalVariableCheck(triggerGvarName)) {
        double gvarValue = GlobalVariableGet(triggerGvarName);
    bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
    bool isOne = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
    if(isZero || isOne) {
            g_triggerLevelsEnabled = isOne;
        } else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ OnInit: Corrupted trigger state (", DoubleToString(gvarValue, 10), "), resetting to default");
    #endif
    GlobalVariableSet(triggerGvarName, inpShowTrigger ? 1.0 : 0.0);
    g_triggerLevelsEnabled = inpShowTrigger;
        }
    } else {        g_triggerLevelsEnabled = inpShowTrigger;
    }
    string linesGvarName = "Biotak_LinesVisible_" + chartIdStr;
    if(GlobalVariableCheck(linesGvarName)) {
        double gvarValue = GlobalVariableGet(linesGvarName);
    bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
    bool isOne = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
    if(isZero || isOne) {
            g_linesVisible = isOne;
        } else {
        #ifdef ENABLE_DEBUG_LOGS
            Print("❌ OnInit: Corrupted lines state (", DoubleToString(gvarValue, 10), "), resetting to default");
    #endif
    GlobalVariableSet(linesGvarName, inpShowLines ? 1.0 : 0.0);
    g_linesVisible = inpShowLines;
        }
    } else {        g_linesVisible = inpShowLines;
    }
    int validationResult = ValidateInputs();
    if(validationResult != INIT_SUCCEEDED) {
        return validationResult;
    }
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    CheckArraySizes();
    if(!UpdateHistoricalValues()) {Print("OnInit: UpdateHistoricalValues failed. Error: ", GetLastError()); return INIT_FAILED;}
    g_initialized=true;
    g_calculatedOnce=false;
    g_dailyClosePriceForTH=GetPriceForPreviousDay(inpTHPriceType);
    if(g_dailyClosePriceForTH==EMPTY_VALUE) {g_dailyClosePriceForTH=EMPTY_VALUE; Print("OnInit: GetPriceForPreviousDay failed, returning INIT_FAILED."); return INIT_FAILED;}
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    int digits = Digits;
    double validatedCustomPrice = inpCustomTHStartPrice;
    if(validatedCustomPrice < 0.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Invalid custom price (negative): ", validatedCustomPrice);
    #endif
    validatedCustomPrice = 0.0;
    }
    if(validatedCustomPrice > 1000000.0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ Invalid custom price (too large): ", validatedCustomPrice);
    #endif
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
    Print("=== Custom Price Debug (OnInit) ===");
    Print("inpCustomTHStartPrice: ", inpCustomTHStartPrice);
    Print("savedPrice: ", savedPrice);
    Print("override: ", g_customPriceKeyboardOverride);
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
    #ifdef ENABLE_DEBUG_LOGS
        Print("OnInit: Restored custom price from GlobalVariable: ", DoubleToString(g_customTHStartPrice, digits));
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ WARNING: Corrupted StepMode GlobalVariable (", tempMode, "), resetting to default");
    #endif
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ WARNING: Invalid Factor GlobalVariable (", val, "), resetting to default");
    #endif
    GlobalVariableDel(factorGvarName);
    g_factorValueOverride = 0.0;
            }
        } else {            g_factorValueOverride = 0.0;
        }
    }
    if(inpFactorMode == FACTOR_MODE_MANUAL) {
        if(inpFactorValue <= 0 || inpFactorValue > MAX_SAFE_FACTOR) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ ERROR: Invalid inpFactorValue (", inpFactorValue, "), clamping to safe range");
    #endif
    g_factorValueOverride = 50.0;
        }
    }
    // Restore TH3 Frequency override
    string th3FreqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    {
        double val = GlobalVariableGet(th3FreqGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            if(val > 0 && val <= 120.0) {
                g_th3FreqOverride = val;
            } else {
                GlobalVariableDel(th3FreqGvarName);
                g_th3FreqOverride = 0.0;
            }
        } else {
            g_th3FreqOverride = 0.0;
        }
    }
    InitializeATRCache();
    UpdateLockStatusLabel();
    PrintBuildInfo();
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStr;
    {
        double val = GlobalVariableGet(th3UpdateFlag);
    if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND && val > 0)
        {            UpdateAllTH3Objects();
    GlobalVariableDel(th3UpdateFlag);
    #ifdef ENABLE_DEBUG_LOGS
            Print("🔄 Updated all TH3 objects with new settings");
    #endif
    }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ AUDIT COMPLETE: All critical memory leaks fixed");
    Print("⚡ OPTIMIZED: API calls cached (Symbol, Digits, Point)");
    Print("🧹 MEMORY: BasePriceManager cleanup added");
    Print("🔧 BUILD: Debug/Production modes with compile-time optimization");
    Print("🔧 FEATURES: Multiple step modes (TH, SS/LS, M, TP, Combo)");
    Print("💾 PERSISTENT: Settings saved to GlobalVariables (survive terminal restart)");
    Print("To enable 'Chart Shift': Right-click chart > Chart Shift (or F11)");
    #endif
    if(shouldBeHidden) {        g_redrawTHLevelsNeeded = false;
    #ifdef ENABLE_DEBUG_LOGS
        Print("🔒 OnInit: Indicator in HIDDEN state - objects will be hidden when created");
    #endif
    } else {        g_redrawTHLevelsNeeded = true;
    #ifdef ENABLE_DEBUG_LOGS
        Print("👁️ OnInit: Indicator VISIBLE - objects will be created normally");
    #endif
    }
    return INIT_SUCCEEDED;
}bool CreateCustomPriceLine(double price, int digits, bool selected = false, 
                           string tooltipSuffix = "Drag to adjust")
{
        if(ObjectFind(0, g_customPriceHorizontalLineName) < 0) {
        if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, price)) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ Failed to create custom price line. Error: ", GetLastError());
    #endif
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
                  "📍 Custom Price: " + DoubleToString(price, digits) + " | " + tooltipSuffix);
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
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);
    if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix)
        {
        if(ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)) {
                hiddenCount++;
            }
        }    }
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    hiddenCount++;
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    hiddenCount++;
    }
    if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    hiddenCount++;
    }
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    hiddenCount++;
    }
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastHideLog = 0;
    datetime currentTime = TimeGMT();
    if(currentTime - s_lastHideLog > 5) {
        Print("🔒 HideAllTHObjects: Hidden ", hiddenCount, " objects (levels + labels + custom price)");
    s_lastHideLog = currentTime;
    }
    #endif
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
    void OnDeinitHandler(const int reason) {
        #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Starting cleanup - Reason: ", reason);
    #endif
    ReleaseATRHandle();
    EventKillTimer();
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectDelete(0, g_stepModeLabelName);
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectDelete(0, g_factorLabelName);
    }
    if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
        ObjectDelete(0, g_lockStatusLabelName);
    }
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
        ObjectDelete(0, g_customPriceHorizontalLineName);
    }
    if(reason == REASON_REMOVE)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("🗑️ Indicator removed - cleaning all GlobalVariables");
    #endif
    CleanupAllGlobalVariables();
    ObjectsDeleteAll(0, inpObjectPrefix);
    ObjectsDeleteAll(0, "TH3_Structure_");
    ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }
    else if(reason == REASON_PARAMETERS)
    {
        // پاک کردن تمام لیبل‌های ATR و TH برای اعمال تنظیمات جدید
        string currentTFStr = IntegerToString(Period());
        string uniquePrefix = inpObjectPrefix + "TF" + currentTFStr + "_";
        string allTimeframes[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
        
        // حذف لیبل‌های ATR
        ObjectDelete(0, uniquePrefix + "ATR_Title");
        for(int i = 0; i < ArraySize(allTimeframes); i++) {
            ObjectDelete(0, uniquePrefix + "ATR_" + allTimeframes[i]);
            ObjectDelete(0, uniquePrefix + "ATR_Steps_" + allTimeframes[i]);
            ObjectDelete(0, uniquePrefix + "ATR_Targets_" + allTimeframes[i]);
        }
        
        // حذف لیبل‌های TH
        ObjectDelete(0, inpObjectPrefix + "TH_Title");
        string fractalTFs[] = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"};
        for(int i = 0; i < ArraySize(fractalTFs); i++) {
            ObjectDelete(0, inpObjectPrefix + "TH_" + fractalTFs[i]);
            ObjectDelete(0, inpObjectPrefix + "TH_Steps_" + fractalTFs[i]);
            ObjectDelete(0, inpObjectPrefix + "TH_Targets_" + fractalTFs[i]);
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
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStrLocal;
    GlobalVariableSet(th3UpdateFlag, 1.0);
    GlobalVariableTemp(th3UpdateFlag);
    #ifdef ENABLE_DEBUG_LOGS
        Print("💾 OnDeinit (REASON_PARAMETERS) - reset overrides, settings will take priority");
    #endif
    ObjectsDeleteAll(0, inpObjectPrefix);
    ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }
    else
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("💾 OnDeinit (reason=", reason, ") - keeping persistent data for next session");
    #endif
    ObjectsDeleteAll(0, inpObjectPrefix);
    ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
    ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }
    CleanupCustomPriceObjects(false, true);
    Comment("");
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Freeing arrays...");
    #endif
    ArrayFree(g_storedTHs);
    ArrayFree(g_labelPositions);
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Cleaning up managers...");
    #endif
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
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Cleanup completed successfully - All resources freed");
    #endif
    }

//+------------------------------------------------------------------+
//| Clear all level objects from all modes (OPTIMIZED + SAFE)       |

//| Added error handling and retry logic              |
//+------------------------------------------------------------------+
void ClearAllLevels(const string objectPrefix, bool clearZones = true)
{
        int totalDeleted = 0;
    int totalFailed = 0;
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastClearLog = 0;
    if(TimeCurrent() - s_lastClearLog > 5) {
        Print("[MT4] 🧹 CLEARING ALL LEVELS with prefix: ", objectPrefix);
    s_lastClearLog = TimeCurrent();
    }
    #endif
    string prefixes[];
    ArrayResize(prefixes, 24);
    prefixes[0] = objectPrefix + "SSLS_";
    prefixes[1] = objectPrefix + "M_";
    prefixes[2] = objectPrefix + "MLabel_";
    prefixes[3] = objectPrefix + "MEq_";
    prefixes[4] = objectPrefix + "MEqLabel_";
    prefixes[5] = objectPrefix + "TP_";
    prefixes[6] = objectPrefix + "Combo_";
    prefixes[7] = objectPrefix + "SharedPattern_";
    prefixes[8] = objectPrefix + "TH_Level_";
    prefixes[9] = objectPrefix + "S_";
    prefixes[10] = objectPrefix + "TriggerTH_Up_";
    prefixes[11] = objectPrefix + "TriggerTH_Down_";
    prefixes[12] = objectPrefix + "StructureLevel1_Up_";
    prefixes[13] = objectPrefix + "StructureLevel1_Down_";
    prefixes[14] = objectPrefix + "StructureLevel2_Up_";
    prefixes[15] = objectPrefix + "StructureLevel2_Down_";
    prefixes[16] = objectPrefix + "StructureLevel3_Up_";
    prefixes[17] = objectPrefix + "StructureLevel3_Down_";
    prefixes[18] = objectPrefix + "StructureLevel4_Up_";
    prefixes[19] = objectPrefix + "StructureLevel4_Down_";
    prefixes[20] = objectPrefix + "StructureLevel5_Up_";
    prefixes[21] = objectPrefix + "StructureLevel5_Down_";
    prefixes[22] = objectPrefix + "Mid";
    prefixes[23] = objectPrefix + "Factor_";
    int prefixCount = ArraySize(prefixes);
    if(prefixCount > MAX_PREFIX_COUNT) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CRITICAL: Prefix count (", prefixCount, ") exceeds MAX_PREFIX_COUNT (", MAX_PREFIX_COUNT, ")");
    #endif
    prefixCount = MAX_PREFIX_COUNT;
    }
    for(int i = 0; i < prefixCount; i++) {
        int result = ObjectsDeleteAll(0, prefixes[i], -1, -1);
    if(result >= 0) {
            totalDeleted += result;
        } else {
            totalFailed++;
    int error = GetLastError();
    #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ ClearAllLevels: Failed to delete prefix '", prefixes[i], "' - Error: ", error);
    #endif
    ResetLastError();
    result = ObjectsDeleteAll(0, prefixes[i], -1, -1);
    if(result >= 0) {
                totalDeleted += result;
    totalFailed--;            }
        }
    }
    if(clearZones) {
        string zonePrefixes[];
    ArrayResize(zonePrefixes, 5);
    zonePrefixes[0] = objectPrefix + "SSLS_Zone_";
    zonePrefixes[1] = objectPrefix + "M_Zone_";
    zonePrefixes[2] = objectPrefix + "TP_Zone_";
    zonePrefixes[3] = objectPrefix + "Combo_Zone_";
    zonePrefixes[4] = objectPrefix + "Factor_Zone_";
    int zonePrefixCount = ArraySize(zonePrefixes);
    for(int i = 0; i < zonePrefixCount; i++) {
        int result = ObjectsDeleteAll(0, zonePrefixes[i], -1, -1);
    if(result >= 0) {
                totalDeleted += result;
            } else {
                totalFailed++;
            }
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    if(totalDeleted > 0 || totalFailed > 0) {
        Print("✅ ClearAllLevels: Deleted=", totalDeleted, ", Failed=", totalFailed);
    }
    #endif
    if(totalFailed > 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ WARNING: Multiple deletion failures (", totalFailed, ") - forcing manual cleanup");
    #endif
    int total = ObjectsTotal(0, -1, -1);
    int prefixLen = StringLen(objectPrefix);
    for(int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, -1, -1);
    if(StringLen(name) >= prefixLen && StringSubstr(name, 0, prefixLen) == objectPrefix) {
                ObjectDelete(0, name);
            }
        }
    }
    // FIX: Clear ObjectCache after deleting objects to prevent stale cache entries.
    // Without this, rapid mode cycling (E key) causes CacheObjectExists to return true
    // for deleted zones, making CreateZone skip creation and zones stop rendering.
    CacheClear();
}
    void GetAdaptiveLevelCounts(int &maxAbove, int &maxBelow)
{
        if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {        maxAbove = inpCustomPriceMaxLevels;
    maxBelow = inpCustomPriceMaxLevels;
    if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
    if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
    if(maxAbove < 1) maxAbove = 1;
    if(maxBelow < 1) maxBelow = 1;
    } else {        maxAbove = inpMaxLevels;
    maxBelow = inpMaxLevels;
    if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
    if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
    if(maxAbove < 1) maxAbove = 1;
    if(maxBelow < 1) maxBelow = 1;
    }
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
        #ifdef ENABLE_DEBUG_LOGS
        Print("CalculateCommonStepData: Invalid daily close price");
    #endif
    return false;
    }
    static StepCalculationData s_cachedData;
    static double s_lastDailyClose = 0;
    static string s_lastTF = "";
    static int s_lastStartPointType = -1;
    static double s_lastCustomPrice = 0;
    static int s_lastMaxAbove = 0;
    static int s_lastMaxBelow = 0;
    string currentTF = GetFractalTimeframeForCurrent();
    
    if(dailyClosePrice == s_lastDailyClose && 
       currentTF == s_lastTF &&
       g_thStartPointType == s_lastStartPointType &&
       (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE || g_customTHStartPrice == s_lastCustomPrice) &&
       inpMaxLevels == s_lastMaxAbove &&
       inpMaxLevels == s_lastMaxBelow &&
       s_lastDailyClose != 0) {
        data = s_cachedData;
    return true;
    }
    
    int digits = Digits;
    
    // TH-based step calculations
    double timeframePercentage = GetTimeframeTH();
    data.thValue = CalculateTH(dailyClosePrice, digits, timeframePercentage);
    CalculateFractalValues(data.thValue, data.structureValue, data.patternValue, data.triggerValue);
    
    #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastTHDebugLogTime = 0;
    datetime currentDebugTime = TimeCurrent();
    if(currentDebugTime - s_lastTHDebugLogTime > 300) {
            Print("========== MT4 TH_BASIS CALCULATION ==========");
    Print("Calculation Basis: TH (Theoretical)");
    Print("Base Price (dailyClosePrice): ", DoubleToString(dailyClosePrice, 10));
    Print("Timeframe Percentage: ", DoubleToString(timeframePercentage, 10));
    Print("TH Value (price units): ", DoubleToString(data.thValue, 10));
    Print("Structure Value: ", DoubleToString(data.structureValue, 10));
    Print("Pattern Value: ", DoubleToString(data.patternValue, 10));
    Print("Trigger Value: ", DoubleToString(data.triggerValue, 10));
    Print("SS (1.5 × Structure): ", DoubleToString(data.structureValue * 1.5, 10));
    Print("LS (2.0 × Structure): ", DoubleToString(data.structureValue * 2.0, 10));
    Print("==============================================");
    s_lastTHDebugLogTime = currentDebugTime;
        }
    #endif
    
    data.shortStep = data.structureValue * 1.5;
    data.longStep = data.structureValue * 2.0;
    data.pointSize = 1.0;
    data.midpointPrice = GetMidpointPrice(g_thStartPointType);
    if(data.midpointPrice <= 0 || data.midpointPrice == EMPTY_VALUE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ERROR: Invalid midpoint price! g_highestHigh=", g_highestHigh, ", g_lowestLow=", g_lowestLow);
    #endif
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
    return true;
}
    void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice)
{
        static ENUM_STEP_CALCULATION_MODE s_lastDrawnMode = (ENUM_STEP_CALCULATION_MODE)-1;
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    bool modeChanged = (currentMode != s_lastDrawnMode);
    if(modeChanged || g_forceClearOnNextDraw) {
        bool clearZones = !g_customPriceLineDragging;
    ClearAllLevels(objectPrefix, clearZones);
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
    double controlValue = CalculateControlValue(data.shortStep, data.longStep);
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
                Print("❌ COMBO_STEP: Failed to calculate combo step");
    Print("   Base Price: ", dailyClosePrice);
    Print("   Preset: ", EnumToString(inpComboPreset));
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
                Print("========== COMBO STEP (UNIFIED) ==========");
    Print("TF: ", GetCurrentTimeframe(), " | TH: ", DoubleToString(data.thValue, Digits));
    Print("Preset: ", EnumToString(inpComboPreset));
    Print("Combo Step = ", DoubleToString(comboStep, Digits));
    Print("Structure: ", DoubleToString(data.structureValue, Digits), 
                      " | Pattern: ", DoubleToString(data.patternValue, Digits),
                      " | Trigger: ", DoubleToString(data.triggerValue, Digits));
    Print("==========================================");
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("❌ FACTOR_STEP: Failed to calculate common step data");
    #endif
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
    Print("FACTOR_STEP: Mode=", modeStr, ", Factor=", DoubleToString(factorValue, 2));
    Print("   Center=", DoubleToString(data.midpointPrice, Digits),
                  " (", (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE ? "Custom" : "Midpoint"), ")");
    Print("   MaxLevels: Above=", data.maxLevelsAbove, ", Below=", data.maxLevelsBelow);
    #endif
    UpdateFactorLabel(factorValue);
    if(inpEnableHarmonicPattern) {
        double harmonicRatio = inpHarmonicRatio;
    if(harmonicRatio < MIN_HARMONIC_RATIO) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("⚠️ FACTOR_STEP: Harmonic ratio too small (", harmonicRatio, 
                          "), clamping to ", MIN_HARMONIC_RATIO);
    #endif
    harmonicRatio = MIN_HARMONIC_RATIO;
                } else if(harmonicRatio > MAX_HARMONIC_RATIO) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("⚠️ FACTOR_STEP: Harmonic ratio too large (", harmonicRatio, 
                          "), clamping to ", MAX_HARMONIC_RATIO);
    #endif
    harmonicRatio = MAX_HARMONIC_RATIO;
                }
    harmonicRatio = NormalizeDouble(harmonicRatio, 3);
    double baseStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
    if(baseStepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ FACTOR_STEP: Invalid base step size calculated");
    #endif
    return;
                }
    if(baseStepSize < Point * 2) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ FACTOR_STEP: Base step too small (", baseStepSize, 
                          ") - Factor too large or range too small");
    #endif
    return;
                }
    #ifdef ENABLE_DEBUG_LOGS
                Print("🎵 FACTOR_STEP: Harmonic Mode");
    Print("   BaseStep=", DoubleToString(baseStepSize, Digits), 
                      " (", DoubleToString(baseStepSize / Point, 1), " pips)");
    Print("   Ratio=", harmonicRatio, 
                      " (", DoubleToString((harmonicRatio - 1.0) * 100, 1), "% larger)");
    Print("   LargeStep=", DoubleToString(baseStepSize * harmonicRatio, Digits),
                      " (", DoubleToString(baseStepSize * harmonicRatio / Point, 1), " pips)");
    #endif
    DrawFactorLevelsHarmonicFromCenter(objectPrefix, data.midpointPrice, 
                                                   g_highestHigh, g_lowestLow,
                                                   factorValue, baseStepSize, harmonicRatio,
                                                   data.maxLevelsAbove, data.maxLevelsBelow);
                
            } else {
        double factorStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
    if(factorStepSize <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ FACTOR_STEP: Invalid step size calculated");
    #endif
    return;
                }
    #ifdef ENABLE_DEBUG_LOGS
                Print("📏 FACTOR_STEP: Standard Mode");
    Print("   StepSize=", DoubleToString(factorStepSize, Digits),
                      " (", DoubleToString(factorStepSize / Point, 1), " pips)");
    #endif
    DrawFactorLevelsFromCenter(objectPrefix, data.midpointPrice, 
                                          g_highestHigh, g_lowestLow, 
                                          factorValue, factorStepSize,
                                          data.maxLevelsAbove, data.maxLevelsBelow);
            }
    double referenceStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
    DrawFactorBoundaryLines(objectPrefix, g_highestHigh, g_lowestLow, factorValue, referenceStepSize);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ FACTOR_STEP: Completed successfully");
    #endif
    break;
        }
        
        case TH_STEP:
        default:
        {
            DrawTHLevels(objectPrefix, dailyClosePrice);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ TH_STEP: Completed successfully");
    #endif
            break;
        }
    }
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawLevelsBasedOnMode: All operations completed");
    #endif
    }
    void RedrawAllObjects(bool force_redraw=false)
{
        datetime currentTime = TimeGMT();
    string s_cachedSymbol = GetCachedSymbol();
    int s_cachedDigits = GetCachedDigits();
    double s_cachedPoint = GetCachedPoint();
    g_currentPrice = Bid;
    if(g_currentPrice <= 0) return;
    UpdateBasePrice();
    double thBasePrice = GetBasePriceForTH();
    if(thBasePrice <= 0 || thBasePrice == EMPTY_VALUE) {        thBasePrice = g_dailyClosePriceForTH;
    }
    static double s_lastDrawnBasePrice = 0.0;
    bool basePriceChanged = (MathAbs(thBasePrice - s_lastDrawnBasePrice) > s_cachedPoint);
    if(basePriceChanged) {
        s_lastDrawnBasePrice = thBasePrice;
    g_redrawTHLevelsNeeded = true;
    }
    bool customPriceLineExists = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
    if(!force_redraw && !customPriceLineExists && !basePriceChanged && !g_redrawTHLevelsNeeded && currentTime - g_lastCalculation < REDRAW_THROTTLE_SECONDS && g_initialized) return;
    g_lastCalculation = currentTime;
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    if(currentTime - g_lastObjectCleanup > CLEANUP_INTERVAL_SECONDS) {
        int currentObjectCount = ObjectsTotal(0, -1, -1);
    if(currentObjectCount > g_objectCountLast + OBJECT_COUNT_INCREASE_THRESHOLD) {
        datetime cutoffTime = currentTime - 3600;
    int maxCleanupItems = MathMin(currentObjectCount, 2000);
    for(int i = maxCleanupItems - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, -1, -1);
    if(objName == "") continue;
    if(StringFind(objName, "TH3_Structure_") >= 0) continue;
    if(StringFind(objName, objectPrefix) >= 0) continue;
    datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
    if(objTime > 0 && objTime < cutoffTime) {
                    ObjectDelete(0, objName);
                }
            }
        }
        g_objectCountLast = currentObjectCount;
    g_lastObjectCleanup = currentTime;
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
        Print("[MT4 DEBUG] RedrawAllObjects executing - Bid: ", DoubleToString(Bid, Digits));
    s_lastDebugLog = TimeGMT();
    }
    #endif
    g_dailyClosePriceForTH = thBasePrice;
    if(currentTime - g_lastHistoricalUpdate >= 3600 || !g_initialized)
    {
        if(!UpdateHistoricalValues()) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("RedrawAllObjects: UpdateHistoricalValues failed.");
    #endif
    return; 
        }
        g_initialized = true;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    }

    DrawMainLevels(objectPrefix);
    if(!g_calculatedOnce)
    {        if (g_dailyClosePriceForTH == EMPTY_VALUE)
        {
            g_dailyClosePriceForTH = thBasePrice;        }
    g_currentLabelYOffset = 0;  // Reset top label stacking offset
    g_currentLabelYOffsetBottom = 0;  // Reset bottom label stacking offset
    DisplayATRLabels(objectPrefix);
    if(inpShowTHLabels && inpShowFractalTHs) DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    if(inpShowTHLabels && inpShowStandardTHs) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    if(inpShowTHLevels) g_redrawTHLevelsNeeded = true;
    g_calculatedOnce = true;
    }
    {
        static bool s_isHiddenCached = false;
    static datetime s_lastHiddenCheckTime = 0;
    if(currentTime - s_lastHiddenCheckTime >= 2) {
        string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    double val = GlobalVariableGet(gvar_name);
    s_isHiddenCached = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND && (bool)val);
    s_lastHiddenCheckTime = currentTime;
        }
    if(s_isHiddenCached) {
            HideAllTHObjects();
        }
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
        if(ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, g_customTHStartPrice)) {
                    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                  "📍 Custom Price: " + DoubleToString(g_customTHStartPrice, s_cachedDigits) + " | Drag to adjust (live update)");
    g_customPriceLineCreated = true;
                }
            }
        } else if(inpCustomTHStartPrice > 0.0) {
        if(MathAbs(g_customTHStartPrice - inpCustomTHStartPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = inpCustomTHStartPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    GlobalVariableSet(gvarName, g_customTHStartPrice);
    if(!lineExists) {
        if(ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, g_customTHStartPrice)) {
                        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                      "📍 Custom Price: " + DoubleToString(g_customTHStartPrice, s_cachedDigits) + " | Drag to adjust (live update)");
    g_customPriceLineCreated = true;
                    }
                } else {
                    ObjectSetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, g_customTHStartPrice);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                  "📍 Custom Price: " + DoubleToString(g_customTHStartPrice, s_cachedDigits) + " | Drag to adjust (live update)");
                }
                
                g_redrawTHLevelsNeeded = true;
            }
        } else if(hasGlobalVar && savedPrice > 0.0) {
        if(MathAbs(g_customTHStartPrice - savedPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = savedPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            }
    if(!lineExists) {
        if(ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, g_customTHStartPrice)) {
                    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                                  "📍 Custom Price: " + DoubleToString(g_customTHStartPrice, s_cachedDigits) + " | Drag to adjust (live update)");
    g_customPriceLineCreated = true;
    #ifdef ENABLE_DEBUG_LOGS
                    Print("🔄 Custom price line restored at: ", DoubleToString(g_customTHStartPrice, s_cachedDigits));
    #endif
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
            Print("[MT4] 🎨 REDRAWING LEVELS | Base Price: ", DoubleToString(g_dailyClosePriceForTH, Digits), 
                  " | Mode: ", GetStepModeName(GetCurrentStepMode()));
    s_lastLevelRedrawLog = TimeCurrent();
        }
    #endif
    bool skipZones = g_customPriceLineDragging;
    ClearAllLevels(objectPrefix, !skipZones);
    DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH);
    g_redrawTHLevelsNeeded = false;
    }
    else if (!inpShowTHLevels && g_redrawTHLevelsNeeded)
    {        ClearAllLevels(objectPrefix);
    g_redrawTHLevelsNeeded = false;
    }    
    if(!g_linesVisible) {
        int total = ObjectsTotal(0, -1, -1);
    string cachedPrefix = objectPrefix;
    int prefixLen = StringLen(cachedPrefix);
    for(int i = 0; i < total; i++) {
        string objName = ObjectName(0, i, -1, -1);
    if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix) {
        int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
    if(objType == OBJ_HLINE || objType == OBJ_TREND) {
                    ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
                }
            }
        }
    }

    CheckAlerts(objectPrefix, g_currentPrice);
}
    int OnCalculateHandler(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
        static uint s_lastCPUTime = 0;
    static int s_cpuWarningCount = 0;
    uint startTime = GetTickCount();
    if(IsIndicatorHidden())
    {
        return(rates_total);
    }
    static uint s_lastTickMs = 0;
    static double s_lastPrice = 0;
    static int s_lastBars = 0;
    static int s_lastPeriod = -1;
    static double s_lastCustomPrice = 0;
    uint nowMs = GetTickCount();
    double currentPrice = (rates_total > 0) ? close[rates_total-1] : 0;
    int currentBars = Bars(_Symbol, _Period);
    int currentPeriod = _Period;
    double currentCustomPrice = g_customTHStartPrice;
    double priceChangePercent = 0;
    if(s_lastPrice > 0 && currentPrice > 0) {
        priceChangePercent = MathAbs((currentPrice - s_lastPrice) / s_lastPrice) * 100.0;
    }
    bool significantPriceChange = (priceChangePercent > 0.1);
    bool barsChanged = (currentBars != s_lastBars && s_lastBars != 0);
    bool isNewBar = barsChanged;
    bool timeframeChanged = (currentPeriod != s_lastPeriod && s_lastPeriod != -1);
    bool customPriceChanged = false;
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        customPriceChanged = (MathAbs(currentCustomPrice - s_lastCustomPrice) > EPSILON_PRICE);
    }
    bool tickThrottled = (nowMs - s_lastTickMs < 100 && s_lastTickMs != 0);
    if(timeframeChanged) {        InvalidateTimeframeDependentCaches();
    InvalidateATRCache();
    #ifdef ENABLE_DEBUG_LOGS
        Print("🔄 Timeframe changed: ", s_lastPeriod, " -> ", currentPeriod);
    #endif
    }
    if(barsChanged) {        InvalidateFactorCache();
    }
    if(customPriceChanged) {        InvalidateTHCache();
    #ifdef ENABLE_DEBUG_LOGS
        Print("🔄 Custom price changed: ", DoubleToString(s_lastCustomPrice, Digits), 
              " -> ", DoubleToString(currentCustomPrice, Digits));
    #endif
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
    s_lastBars = currentBars;
    s_lastPeriod = currentPeriod;
    s_lastCustomPrice = currentCustomPrice;
    RedrawAllObjects(g_redrawTHLevelsNeeded || g_forceClearOnNextDraw);
    if(barsChanged || s_lastBars == 0) {
        int totalObjects = ObjectsTotal(0, -1, -1);
    if(totalObjects > MAX_SAFE_OBJECTS && totalObjects < CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
                if(s_cpuWarningCount % 10 == 0) {                    Print("⚠️ Performance Warning: ", totalObjects, " objects on chart (recommended max: ", MAX_SAFE_OBJECTS, ")");
    Print("🧹 Consider reducing inpMaxLevels for better performance");
                }
    #endif
    s_cpuWarningCount++;
            }
            else if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("🔴 CRITICAL: ", totalObjects, " objects approaching MT4 limit (64000)!");
    Print("🧹 EMERGENCY: Using ObjectsDeleteAll for cleanup...");
    #endif
    int deleted = 0;
    deleted += ObjectsDeleteAll(0, "Zone_", -1, -1);
    deleted += ObjectsDeleteAll(0, "Mid_", -1, -1);
    #ifdef ENABLE_DEBUG_LOGS
                int afterCleanup = ObjectsTotal(0, -1, -1);
    Print("✅ Emergency cleanup completed. Objects: ", totalObjects, " -> ", afterCleanup, " (deleted=", deleted, ")");
    #endif
    }
        }
    }
    uint elapsed = GetTickCount() - startTime;
    if(elapsed > CPU_WARNING_MS) {
        if(elapsed > CPU_CRITICAL_MS) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("🔴 CRITICAL CPU: OnCalculate took ", elapsed, "ms! Reduce inpMaxTHLevels!");
    #endif
    }
        else if(s_lastCPUTime == 0 || GetTickCount() - s_lastCPUTime > 60000) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CPU Warning: OnCalculate took ", elapsed, "ms (threshold: ", CPU_WARNING_MS, "ms)");
    #endif
    s_lastCPUTime = GetTickCount();
        }
    }
    return rates_total;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Apply Lines Visibility State to All Line Objects                 |

//|                                                                  |
//| Removed redundant loop - visibility now set during     |
//| object creation in CreateTHLineObject()                         |
//| This function kept as stub for backward compatibility           |
//+------------------------------------------------------------------+
void ApplyLinesVisibility()
{    return;
}
    void OnChartEventHandler(const int id, const long &lparam, const double &dparam, const string &sparam)
{
        if(id == CHARTEVENT_KEYDOWN)
    {
        string mutableHideKey = inpHideKey;
    StringToUpper(mutableHideKey);
    int hideKeyCode = StringGetCharacter(mutableHideKey, 0);
    if(lparam == hideKeyCode)
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
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ F key: Failed to set GlobalVariable, Error: ", GetLastError());
    #endif
    }
    RefreshIsHiddenCache();
    if(isBecomingHidden)
            {
        #ifdef ENABLE_DEBUG_LOGS
                Print("🔒 F key: Hiding all objects");
    #endif
    HideAllTHObjects();
    CleanupCustomPriceObjects(false, true);
    g_redrawTHLevelsNeeded = false;
            }
            else
            {
        #ifdef ENABLE_DEBUG_LOGS
                Print("👁️ F key: Showing all objects");
    #endif
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    ClearAllLevels(objectPrefix);
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    g_initialized = true;
    RedrawAllObjects(true);
    int total = ObjectsTotal(0, -1, -1);
    int shownCount = 0;
    int hiddenCount = 0;
    int failedCount = 0;
    string cachedPrefixF = inpObjectPrefix;
    int prefixLenF = StringLen(cachedPrefixF);
    for(int i = total - 1; i >= 0; i--)
                {
        string objName = ObjectName(0, i, -1, -1);
    if(StringLen(objName) >= prefixLenF && StringSubstr(objName, 0, prefixLenF) == cachedPrefixF)
                    {
        bool isTriggerObject = (StringFind(objName, "TriggerTH_Up_") >= 0 || 
                                               StringFind(objName, "TriggerTH_Down_") >= 0);
    if(isTriggerObject && !g_triggerLevelsEnabled)
                        {
        if(ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)) {
                                hiddenCount++;
                            } else {
                                failedCount++;
                            }
                        } else {
                            shownCount++;
                        }
                    }
                }
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ F key: Shown ", shownCount, " objects, hidden ", hiddenCount, 
                      " Trigger objects (", failedCount, " failed)");
    #endif
    }
            ThrottledChartRedraw();        }
    string mutableLinesKey = inpLinesToggleKey;
    StringToUpper(mutableLinesKey);
    int linesKeyCode = StringGetCharacter(mutableLinesKey, 0);
    if(lparam == linesKeyCode)
        {            g_linesVisible = !g_linesVisible;
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
    #ifdef ENABLE_DEBUG_LOGS
            Print("📊 Lines ", (g_linesVisible ? "VISIBLE" : "HIDDEN"));
    #endif
    ThrottledChartRedraw();
        }
    string mutableCustomKey = inpCustomPriceKey;
    StringToUpper(mutableCustomKey);
    int customKeyCode = StringGetCharacter(mutableCustomKey, 0);
    if(lparam == customKeyCode)
        {            
            g_waitingForCustomPriceClick = true;
    g_customPriceKeyboardOverride = true;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + GetCachedSymbol();
    GlobalVariableSet(overrideFlagName, 1.0);
    #ifdef ENABLE_DEBUG_LOGS
            Print("Press anywhere on the chart to set custom TH start price");
    #endif
    ObjectDelete(0, g_customPriceHorizontalLineName);
    g_customPriceLineCreated = false;
    double currentPrice = iClose(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0);
    g_customTHStartPrice = currentPrice;
    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
    string gvarName = "Biotak_CustomPrice_" + GetCachedSymbol();
    GlobalVariableSet(gvarName, currentPrice);
    if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, currentPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("Failed to create custom price horizontal line. Error: ", GetLastError());
    #endif
    return;
            }
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                          "📍 Custom Price: " + DoubleToString(currentPrice, Digits) + " | Drag to adjust, Double-click to confirm");
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
    #ifdef ENABLE_DEBUG_LOGS
            Print("📍 Custom price set to: ", DoubleToString(currentPrice, Digits), " - Drag to adjust.");
    #endif
    ThrottledChartRedraw();
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
    #ifdef ENABLE_DEBUG_LOGS
                Print("Custom price mode cancelled - returned to Input Parameter setting");
    #endif
    ThrottledChartRedraw();
            }
        }
    string mutableTriggerKey = inpTriggerLevelsKey;
    StringToUpper(mutableTriggerKey);
    int triggerKeyCode = StringGetCharacter(mutableTriggerKey, 0);
    if(lparam == triggerKeyCode)
        {            g_triggerLevelsEnabled = !g_triggerLevelsEnabled;
    string triggerGvarName = "Biotak_TriggerLevels_" + GetCachedChartIdStr();
    GlobalVariableSet(triggerGvarName, g_triggerLevelsEnabled);
    if(g_triggerLevelsEnabled) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("🔵 Trigger Levels: ON");
    #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
                Print("⚪ Trigger Levels: OFF");
    #endif
    }
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
        }
    string mutableTH3Key = inpTH3ToolKey;
    StringToUpper(mutableTH3Key);
    int th3KeyCode = StringGetCharacter(mutableTH3Key, 0);
    if(lparam == th3KeyCode)
        {
            ToggleTH3Tool();
    ThrottledChartRedraw();        }
    string mutableStepModeKey = inpStepModeKey;
    StringToUpper(mutableStepModeKey);
    int stepModeKeyCode = StringGetCharacter(mutableStepModeKey, 0);
    if(lparam == stepModeKeyCode)
        {            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    ENUM_STEP_CALCULATION_MODE newMode = (ENUM_STEP_CALCULATION_MODE)(((int)currentMode + 1) % 6);
    g_stepModeOverride = (int)newMode;
    string stepModeGvarName = "Biotak_StepMode_" + GetCachedChartIdStr();
    GlobalVariableSet(stepModeGvarName, g_stepModeOverride);
    UpdateStepModeLabel();
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    g_calculatedOnce = false;  // FIX: Force label refresh on mode change
    RedrawAllObjects(true);
    ThrottledChartRedraw();
        }
    if(lparam == '1' || lparam == 49)        {
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    if(currentMode == FACTOR_STEP)
            {
        double currentFactor = g_factorValueOverride;
    if(currentFactor <= 0) {
        if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
                        currentFactor = inpFactorValue;
                    } else {                        currentFactor = GetDefaultFactorValue(g_dailyClosePriceForTH);
    if(currentFactor <= 0 || currentFactor > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
                            Print("Factor decrease: Invalid factor from GetDefaultFactorValue, using 50.0");
    #endif
    currentFactor = 50.0;
                        }
                    }
                }
    double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : 0.1;
    double newFactor = NormalizeDouble(currentFactor - step, 2);
    if(newFactor < 0.01) newFactor = 0.01;
    g_factorValueOverride = newFactor;
    string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
    if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("WARNING: Failed to persist Factor value to GlobalVariable");
    #endif
    }
    UpdateFactorLabel(newFactor);
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
            }
        }
    if(lparam == '2' || lparam == 50)        {
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    if(currentMode == FACTOR_STEP)
            {
        double currentFactor = g_factorValueOverride;
    if(currentFactor <= 0) {
        if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
                        currentFactor = inpFactorValue;
                    } else {                        currentFactor = GetDefaultFactorValue(g_dailyClosePriceForTH);
    if(currentFactor <= 0 || currentFactor > 10000) {
        #ifdef ENABLE_DEBUG_LOGS
                            Print("Factor increase: Invalid factor from GetDefaultFactorValue, using 50.0");
    #endif
    currentFactor = 50.0;
                        }
                    }
                }
    double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : 0.1;
    double newFactor = NormalizeDouble(currentFactor + step, 2);
    if(newFactor > 10000) newFactor = 10000;
    g_factorValueOverride = newFactor;
    string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
    if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("WARNING: Failed to persist Factor value to GlobalVariable");
    #endif
    }
    UpdateFactorLabel(newFactor);
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
            }
        }
        // KEY '3' — Decrease TH3 Frequency
        if(lparam == '3' || lparam == 51) {
            if(inpEnableTH3Tool) {
                double currentFreq = g_th3FreqOverride;
                if(currentFreq <= 0) currentFreq = inpTH3BaseStepPercent;
                double step = (inpTH3FreqAdjustStep > 0) ? inpTH3FreqAdjustStep : 1.0;
                double newFreq = NormalizeDouble(currentFreq - step, 2);
                if(newFreq < 0.1) newFreq = 0.1;
                g_th3FreqOverride = newFreq;
                GlobalVariableSet("Biotak_TH3Freq_" + GetCachedChartIdStr(), g_th3FreqOverride);
                UpdateTH3FreqLabel(newFreq);
                UpdateAllTH3Objects();
                ThrottledChartRedraw();
            }
        }

        // KEY '4' — Increase TH3 Frequency
        if(lparam == '4' || lparam == 52) {
            if(inpEnableTH3Tool) {
                double currentFreq = g_th3FreqOverride;
                if(currentFreq <= 0) currentFreq = inpTH3BaseStepPercent;
                double step = (inpTH3FreqAdjustStep > 0) ? inpTH3FreqAdjustStep : 1.0;
                double newFreq = NormalizeDouble(currentFreq + step, 2);
                if(newFreq > 120.0) newFreq = 120.0;
                g_th3FreqOverride = newFreq;
                GlobalVariableSet("Biotak_TH3Freq_" + GetCachedChartIdStr(), g_th3FreqOverride);
                UpdateTH3FreqLabel(newFreq);
                UpdateAllTH3Objects();
                ThrottledChartRedraw();
            }
        }

    string mutableResetKey = inpResetKey;
    StringToUpper(mutableResetKey);
    int resetKeyCode = StringGetCharacter(mutableResetKey, 0);
    if(lparam == resetKeyCode)
        {            g_stepModeOverride = -1;
    g_factorValueOverride = 0;
    g_th3FreqOverride = 0;
    g_timeframeLocked = false;
    g_lockedPeriod = 0;
    g_triggerLevelsEnabled = inpShowTrigger;
    g_linesVisible = inpShowLines;
    if(inpEnableTH3Tool) {
                UpdateAllTH3Objects();
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
    EventSetTimer(2);
    g_forceClearOnNextDraw = true;
    g_calculatedOnce = false;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    ThrottledChartRedraw();
        }
    string mutableLockKey = inpLockKey;
    StringToUpper(mutableLockKey);
    int lockKeyCode = StringGetCharacter(mutableLockKey, 0);
    if(lparam == lockKeyCode)
        {
        bool hadCustomPrice = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
    double savedCustomPrice = hadCustomPrice ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0;
    ObjectsDeleteAll(0, inpObjectPrefix);
    g_timeframeLocked = !g_timeframeLocked;
    if(g_timeframeLocked)
            {
                g_lockedPeriod = GetCachedPeriod();
    #ifdef ENABLE_DEBUG_LOGS
                Print("🔒 Timeframe locked to: ", GetCurrentTimeframe());
    #endif
    }
            else
            {
        #ifdef ENABLE_DEBUG_LOGS
                Print("🔓 Timeframe unlocked - now following chart timeframe: ", GetCurrentTimeframe());
    #endif
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
                                  "📍 Custom Price: " + DoubleToString(savedCustomPrice, Digits) + " | Drag to adjust (live update)");
    g_customPriceLineCreated = true;
                }
            }
            
            ThrottledChartRedraw();
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
    if(id == CHARTEVENT_CLICK && g_waitingForCustomPriceClick)
    {
        if(StringFind(sparam, "r") >= 0)
        {            CleanupCustomPriceObjects(true, true);
    #ifdef ENABLE_DEBUG_LOGS
            Print("Custom price setting cancelled (right-click)");
    #endif
    ThrottledChartRedraw();
    return;
        }
    double clickedPrice = dparam;
    if(!g_customPriceLineCreated)
        {            if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, clickedPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                Print("Failed to create custom price horizontal line. Error: ", GetLastError());
    #endif
    return;
            }
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, true);
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price Line - Drag to adjust, Double-click to confirm");
    g_customPriceLineCreated = true;
    #ifdef ENABLE_DEBUG_LOGS
            Print("📍 Drag the orange dotted line to adjust price. Double-click to confirm.");
    #endif
    }
        else
        {
        uint currentTickCount = GetTickCount();
    bool isDoubleClick = (currentTickCount - g_lastClickTickCount < 300);
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
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    #ifdef ENABLE_DEBUG_LOGS
                Print("✅ Custom Price Mode activated! Using ", inpCustomPriceMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
    #endif
    }
        }
        
        ThrottledChartRedraw();
    }
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_customPriceHorizontalLineName)
    {
        uint currentTickCount = GetTickCount();
    bool isDoubleClick = (currentTickCount - g_lastClickTickCount < 300);
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
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
    g_customPriceLineCreated = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Custom Price Mode activated! Using ", inpCustomPriceMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
    #endif
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
    #ifdef ENABLE_DEBUG_LOGS
            Print("Custom TH start price updated to: ", DoubleToString(draggedPrice, Digits));
    #endif
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

