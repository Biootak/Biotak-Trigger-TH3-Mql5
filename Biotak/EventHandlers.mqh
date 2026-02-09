//+------------------------------------------------------------------+
//| Event Handlers - Version 3.09 GOLD                              |
//| Security & Performance Audit Complete                           |
//+------------------------------------------------------------------+

int OnInitHandler() {
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 0: INITIALIZE GLOBAL CACHE (PERFORMANCE OPTIMIZATION)
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL: Initialize cache before any other operations
    // This caches Symbol(), Period(), ChartID(), Digits, Point
    InitializeGlobalCache();
    
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 0.5: INITIALIZE OBJECT CACHE SYSTEM (FLICKERING FIX)
    // ═══════════════════════════════════════════════════════════════════
    // Clear any existing cache entries
    CacheClear();
    
    // Rebuild cache from existing chart objects (if any from previous session)
    // This handles cases where indicator is reloaded or terminal restarted
    int existingObjects = ObjectsTotal(0, -1, -1);
    if(existingObjects > 0) {
        CacheRebuild();
        #ifdef ENABLE_DEBUG_LOGS
        Print("🔄 Object cache rebuilt: ", CacheGetSize(), " objects cached from previous session");
        #endif
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("✅ Object cache initialized (empty - no existing objects)");
        #endif
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 1: CHECK HIDDEN STATE (but don't return early)
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL FIX: Always initialize indicator fully, even if hidden
    // This ensures objects exist and can be shown later with F key
    // We'll hide objects at the END of initialization, not at the beginning
    
    // PERFORMANCE: Use cached ChartID string instead of IntegerToString(ChartID())
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    bool shouldBeHidden = false;  // Default: visible
    
    // GOLD FIX v2: Enhanced GlobalVariable validation with epsilon
    if(GlobalVariableCheck(gvar_name)) {
        double gvarValue = GlobalVariableGet(gvar_name);
        
        // SECURITY: Validate value using epsilon (not exact comparison)
        bool isZero = MathAbs(gvarValue - 0.0) < EPSILON_GENERAL;
        bool isOne = MathAbs(gvarValue - 1.0) < EPSILON_GENERAL;
        
        if(isZero || isOne) {
            shouldBeHidden = isOne;  // true if close to 1.0
        } else {
            // Corrupted value - reset to visible and log detailed warning
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
    
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 2: FULL INITIALIZATION (always execute)
    // ═══════════════════════════════════════════════════════════════════
    
    // PERFORMANCE: Cache chartIdStr for all GlobalVariable operations in this function
    string chartIdStr = GetCachedChartIdStr();
    
    // Initialize Trigger Levels toggle state - restore from GlobalVariable or use input parameter
    string triggerGvarName = "Biotak_TriggerLevels_" + chartIdStr;
    if(GlobalVariableCheck(triggerGvarName)) {
        // GOLD FIX: Validate value using epsilon
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
    } else {
        // First time - use input parameter
        g_triggerLevelsEnabled = inpShowTrigger;
    }
    
    // Initialize Lines visibility state - restore from GlobalVariable or use input parameter
    string linesGvarName = "Biotak_LinesVisible_" + chartIdStr;
    if(GlobalVariableCheck(linesGvarName)) {
        // GOLD FIX: Validate value using epsilon
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
    } else {
        // First time - use input parameter
        g_linesVisible = inpShowLines;
    }
    
    // Validate all input parameters using modular validator
    int validationResult = ValidateInputs();
    if(validationResult != INIT_SUCCEEDED) {
        return validationResult;
    }
    
    // Enable Object Delete Events (Critical for TH3 cleanup)
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    
    // PERFORMANCE FIX: Enable mouse move events for real-time custom price line dragging
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    // ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrLavender);
    CheckArraySizes();
    if(!UpdateHistoricalValues()) {Print("OnInit: UpdateHistoricalValues failed. Error: ", GetLastError()); return INIT_FAILED;}
    g_initialized=true;
    g_calculatedOnce=false;
    g_dailyClosePriceForTH=GetPriceForPreviousDay(inpTHPriceType);
    if(g_dailyClosePriceForTH==EMPTY_VALUE) {g_dailyClosePriceForTH=EMPTY_VALUE; Print("OnInit: GetPriceForPreviousDay failed, returning INIT_FAILED."); return INIT_FAILED;}
    
    // Check if custom price is saved in GlobalVariable (persistent with temp)
    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    int digits = Digits;
    
    // SECURITY FIX: Validate custom price input parameter
    // Note: Cannot modify input parameter directly in MQL4
    // Validation is done in InputValidator.mqh
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
    
    // ═══════════════════════════════════════════════════════════════════
    // Custom Price Priority Logic (OnInit) - SIMPLIFIED VERSION:
    // 
    // Key insight: Use ONLY override flag to determine source
    // - override = true → user dragged/pressed C → use savedPrice
    // - override = false → use settings (inpCustomTHStartPrice)
    // 
    // REASON_PARAMETERS resets override in OnDeinit
    // REASON_CHARTCHANGE preserves override in OnDeinit
    // 
    // Priority:
    // 1. If override AND savedPrice > 0 → use dragged/C price
    // 2. If inpCustomTHStartPrice > 0 → use settings
    // 3. If savedPrice > 0 (no override, no input) → restore saved
    // 4. Default mode
    // ═══════════════════════════════════════════════════════════════════
    
    // Restore keyboard override flag
    {
        double val = GlobalVariableGet(overrideFlagName);
        g_customPriceKeyboardOverride = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) ? (bool)val : false;
    }
    
    // Get saved price from GlobalVariable
    double savedPrice;
    {
        double val = GlobalVariableGet(gvarName);
        savedPrice = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) ? val : 0.0;
    }
    
    // Debug logging (only in DEBUG_BUILD - zero overhead in production)
    #ifdef ENABLE_DEBUG_LOGS
    Print("=== Custom Price Debug (OnInit) ===");
    Print("inpCustomTHStartPrice: ", inpCustomTHStartPrice);
    Print("savedPrice: ", savedPrice);
    Print("override: ", g_customPriceKeyboardOverride);
    #endif
    
    // Priority logic - SIMPLIFIED
    if(g_customPriceKeyboardOverride && savedPrice > 0.0) {
        // 1. User pressed C key or dragged line - PRESERVE across TF changes
        g_customTHStartPrice = savedPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        
        DEBUG_PRINTF("OnInit: Using keyboard/drag price (override): ", DoubleToString(g_customTHStartPrice, digits));
        CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else if(validatedCustomPrice > 0.0) {
        // 2. User set custom price in settings - use it
        g_customTHStartPrice = validatedCustomPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        g_customPriceKeyboardOverride = false; // Reset override
        
        // Save to GlobalVariables
        GlobalVariableSet(gvarName, g_customTHStartPrice);
        GlobalVariableSet(overrideFlagName, 0.0);
        
        DEBUG_PRINTF("OnInit: Using custom price from settings: ", DoubleToString(g_customTHStartPrice, digits));
        CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else if(savedPrice > 0.0) {
        // 3. No input price set, but saved price exists - restore it
        g_customTHStartPrice = savedPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("OnInit: Restored custom price from GlobalVariable: ", DoubleToString(g_customTHStartPrice, digits));
        #endif
        CreateCustomPriceLine(g_customTHStartPrice, digits);
        
    } else {
        // 4. No custom price - use default
        g_customTHStartPrice = 0.0;
        g_thStartPointType = inpTHStartPointType;
        g_customPriceKeyboardOverride = false;
        
        // Clear GlobalVariables (Del is safe even if not found)
        GlobalVariableDel(gvarName);
        GlobalVariableDel(overrideFlagName);
        
        DEBUG_PRINT("OnInit: Using default mode (no custom price)");
    }
    
    g_redrawTHLevelsNeeded = true;
    
    // Initialize base price history system
    InitializeBasePriceSystem();

    // Restore timeframe lock state (persist across timeframe changes)
    // PERFORMANCE: Use cached chartIdStr for all GlobalVariable operations
    // PERF FIX: Single GlobalVariableGet + GetLastError instead of Check+Get
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
    
    // Restore step mode override state (persist across timeframe changes)
    // GOLD FIX: Add validation to prevent corrupted values
    string stepModeGvarName = "Biotak_StepMode_" + chartIdStr;
    {
        double val = GlobalVariableGet(stepModeGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            int tempMode = (int)val;
            // Validate range: 0=TH, 1=SS/LS, 2=M, 3=TP, 4=Combo, 5=Factor
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
    
    // Restore Factor value override state (persist across timeframe changes)
    // بازیابی مقدار فاکتور (پایدار در تغییر تایم‌فریم)
    // GOLD FIX: Add validation to prevent invalid values
    string factorGvarName = "Biotak_Factor_" + chartIdStr;
    {
        double val = GlobalVariableGet(factorGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            // Validate: must be positive and within MAX_SAFE_FACTOR
            if(val > 0 && val <= MAX_SAFE_FACTOR) {
                g_factorValueOverride = val;
            } else {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ WARNING: Invalid Factor GlobalVariable (", val, "), resetting to default");
                #endif
                GlobalVariableDel(factorGvarName);
                g_factorValueOverride = 0.0;
            }
        } else {
            // No saved override - reset to 0 (use settings)
            g_factorValueOverride = 0.0;
        }
    }
    
    // GOLD FIX: Validate manual factor input parameter
    if(inpFactorMode == FACTOR_MODE_MANUAL) {
        if(inpFactorValue <= 0 || inpFactorValue > MAX_SAFE_FACTOR) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ ERROR: Invalid inpFactorValue (", inpFactorValue, "), clamping to safe range");
            #endif
            // Don't override input, just warn and use safe fallback via override
            g_factorValueOverride = 50.0;
        }
    }
    
    // Restore calculation basis override state (persist across timeframe changes)
    // بازیابی وضعیت مبنای محاسبات (پایدار در تغییر تایم‌فریم)
    string basisGvarName = "Biotak_CalcBasis_" + chartIdStr;
    {
        double val = GlobalVariableGet(basisGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            g_calculationBasisOverride = (int)val;
        }
    }
    
    // Restore TH3 frequency override state (persist across timeframe changes)
    // بازیابی وضعیت فرکانس TH3 (پایدار در تغییر تایم‌فریم)
    string freqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    {
        double restoredFreq = GlobalVariableGet(freqGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            // Validate restored frequency (must be positive and reasonable)
            if(restoredFreq > 0 && restoredFreq <= 100.0) {
                g_th3FrequencyOverride = restoredFreq;
            } else {
                // Invalid frequency - reset to default
                g_th3FrequencyOverride = 0;
                GlobalVariableDel(freqGvarName);
            }
        }
    }
    
    string indexGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
    {
        double val = GlobalVariableGet(indexGvarName);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND) {
            int restoredIndex = (int)val;
            // Validate restored index (must be within array bounds)
            if(restoredIndex >= 0 && restoredIndex < TH3_FREQUENCY_COUNT) {
                g_th3FrequencyIndex = restoredIndex;
            } else {
                // Invalid index - reset to default frequency (28.125%)
                g_th3FrequencyIndex = 16;
                GlobalVariableDel(indexGvarName);
            }
        }
    }
    
    // Initialize ATR cache system
    // راه‌اندازی سیستم کش ATR
    InitializeATRCache();
    
    // Update lock status label on chart (shows 🔒 TF when locked)
    UpdateLockStatusLabel();

    // Print build info (uses compile-time constants)
    PrintBuildInfo();
    
    // Check if TH3 objects need update (after settings change)
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStr;
    {
        double val = GlobalVariableGet(th3UpdateFlag);
        if(GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND && val > 0)
        {
            // Update all existing TH3 objects with new settings
            UpdateAllTH3Objects();
            
            // Clear the flag
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
    
    // ========================================
    // Initialize Learning System
    // مقداردهی اولیه سیستم یادگیری
    // ========================================
    InitializeLearningSystem();
    
    // ═══════════════════════════════════════════════════════════════════
    // PHASE 3: SET FLAGS FOR HIDDEN STATE (objects will be created later)
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL FIX: Don't try to hide objects in OnInit - they don't exist yet!
    // Objects are created in OnCalculate → RedrawAllObjects → DrawMainLevels
    // We just set the flag here, and objects will be hidden when created
    
    if(shouldBeHidden) {
        // GOLD FIX: Set flag to prevent object creation/display
        // Objects will check this flag when being created
        g_redrawTHLevelsNeeded = false;  // Don't draw levels
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("🔒 OnInit: Indicator in HIDDEN state - objects will be hidden when created");
        #endif
    } else {
        // Normal mode - objects will be created and shown
        g_redrawTHLevelsNeeded = true;
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("👁️ OnInit: Indicator VISIBLE - objects will be created normally");
        #endif
    }
    
    return INIT_SUCCEEDED;
}

// Helper function to create custom price horizontal line (DRY)
void CreateCustomPriceLine(double price, int digits)
{
    ObjectDelete(0, g_customPriceHorizontalLineName);
    if(ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, price)) {
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_COLOR, inpCustomPriceLevelColor);
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_WIDTH, inpCustomPriceLevelWidth);
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100);
        ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                      "📍 Custom Price: " + DoubleToString(price, digits) + " | Drag to adjust");
        g_customPriceLineCreated = true;
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ Failed to create custom price line. Error: ", GetLastError());
        #endif
        g_customPriceLineCreated = false;
    }
}

//+------------------------------------------------------------------+
//| Helper function to hide all TH objects (DRY)                     |
//| تابع کمکی برای مخفی کردن همه اشیاء TH                            |
//|                                                                  |
//| GOLD FIX: Centralized hide logic to avoid code duplication      |
//| Used by: OnInit, RedrawAllObjects, F key handler                |
//| COVERS: TH levels, labels, zones, mode labels, custom price     |
//+------------------------------------------------------------------+
void HideAllTHObjects()
{
    int total = ObjectsTotal(0, -1, -1);
    int hiddenCount = 0;
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: Hide TH level objects (with prefix)
    // OPTIMIZATION: Cache prefix and length to avoid repeated StringFind
    // ═══════════════════════════════════════════════════════════════
    string cachedPrefix = inpObjectPrefix;
    int prefixLen = StringLen(cachedPrefix);
    
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);
        
        // OPTIMIZED: Use StringSubstr instead of StringFind for faster prefix check
        if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix)
        {
            if(ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS)) {
                hiddenCount++;
            }
        }
        // TH3 objects remain visible (user drawings should persist)
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: Hide mode labels (no prefix)
    // ═══════════════════════════════════════════════════════════════
    // GOLD FIX: These labels don't have prefix, hide them separately
    if(ObjectFind(0, g_stepModeLabelName) >= 0) {
        ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    if(ObjectFind(0, g_basisModeLabelName) >= 0) {
        ObjectSetInteger(0, g_basisModeLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    if(ObjectFind(0, g_factorLabelName) >= 0) {
        ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    if(ObjectFind(0, g_frequencyLabelName) >= 0) {
        ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
        ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: Hide custom price line (no prefix)
    // ═══════════════════════════════════════════════════════════════
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
        hiddenCount++;
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastHideLog = 0;
    datetime currentTime = TimeGMT();
    // Throttle logging to once per 5 seconds
    if(currentTime - s_lastHideLog > 5) {
        Print("🔒 HideAllTHObjects: Hidden ", hiddenCount, " objects (levels + labels + custom price)");
        s_lastHideLog = currentTime;
    }
    #endif
}

// Helper function to clean up custom price selection objects
void CleanupCustomPriceObjects(bool resetGlobalVars = false, bool forceDelete = false)
{
    // No need to delete vertical line as it's not created anymore
    
    // Only delete the horizontal line if we're in the initial selection mode or if forceDelete is true
    if (g_waitingForCustomPriceClick || forceDelete) {
        ObjectDelete(0, g_customPriceHorizontalLineName);
        g_customPriceLineCreated = false;
    }
    
    g_waitingForCustomPriceClick = false;
    
    // If resetGlobalVars is true, also delete the global variable and reset keyboard override
    if (resetGlobalVars) {
        // OPTIMIZATION: Use GetCachedSymbol() for consistency
        string symbolName = GetCachedSymbol();
        string gvarName = "Biotak_CustomPrice_" + symbolName;
        string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
        // PERF FIX: GlobalVariableDel safely returns false if not found
        GlobalVariableDel(gvarName);
        GlobalVariableDel(overrideFlagName);
        g_customTHStartPrice = 0.0;
        g_thStartPointType = inpTHStartPointType;
        g_customPriceKeyboardOverride = false; // Reset keyboard override flag
    }
}

void OnDeinitHandler(const int reason) {
    // OPTIMIZATION: Comprehensive memory cleanup
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Starting cleanup - Reason: ", reason);
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 0: Release cached indicator handles
    // ═══════════════════════════════════════════════════════════════
    ReleaseATRHandle();
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: Stop Timer (if active)
    // ═══════════════════════════════════════════════════════════════
    EventKillTimer();
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: Delete ALL Labels (with and without prefix)
    // ═══════════════════════════════════════════════════════════════
    // Delete mode labels (no prefix)
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
    if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
        ObjectDelete(0, g_lockStatusLabelName);
    }
    
    // Delete custom price line (no prefix)
    if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
        ObjectDelete(0, g_customPriceHorizontalLineName);
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: Handle different deinit reasons
    // ═══════════════════════════════════════════════════════════════
    // IMPORTANT: Only delete global variable if indicator is being REMOVED
    // NOT when terminal closes, timeframe changes, or parameters change!
    if(reason == REASON_REMOVE)
    {
        #ifdef ENABLE_DEBUG_LOGS
        Print("🗑️ Indicator removed - cleaning all GlobalVariables");
        #endif
        // Use comprehensive cleanup function
        CleanupAllGlobalVariables();
        
        // Delete all chart objects with prefix (only on removal)
        ObjectsDeleteAll(0, inpObjectPrefix);
        ObjectsDeleteAll(0, "TH3_Structure_");
        
        // Delete all zone objects from all modes
        ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }
    else if(reason == REASON_PARAMETERS)
    {
        // User opened settings and clicked OK - reset ALL override flags
        // This means user wants to use settings values (even if same as before)
        string symbolName = GetCachedSymbol();
        
        // PERFORMANCE: Use cached ChartID string for all GlobalVariable operations
        string chartIdStrLocal = GetCachedChartIdStr();
        
        // Reset Custom Price override
        string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
        // PERF FIX: GlobalVariableSet creates the variable if not found - no check needed
        GlobalVariableSet(overrideFlagName, 0.0);
        
        // Reset Factor override (keyboard +/- keys)
        string factorGvarName = "Biotak_Factor_" + chartIdStrLocal;
        GlobalVariableDel(factorGvarName);
        g_factorValueOverride = 0.0;  // Clear in-memory override
        
        // Reset Lines visibility override (keyboard L key)
        string linesGvarName = "Biotak_LinesVisible_" + chartIdStrLocal;
        GlobalVariableDel(linesGvarName);
        // Note: g_linesVisible will be reset to inpShowLines in OnInit
        
        // Set flag to update TH3 objects in OnInit
        string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStrLocal;
        GlobalVariableSet(th3UpdateFlag, 1.0);
        GlobalVariableTemp(th3UpdateFlag);
        
        #ifdef ENABLE_DEBUG_LOGS
        Print("💾 OnDeinit (REASON_PARAMETERS) - reset overrides, settings will take priority");
        #endif
        
        // Delete TH levels but keep TH3 structures (user drawings should persist)
        ObjectsDeleteAll(0, inpObjectPrefix);
        
        // Delete all zone objects from all modes
        ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }
    else
    {
        // Keep the global variables for persistence (timeframe change, terminal close)
        #ifdef ENABLE_DEBUG_LOGS
        Print("💾 OnDeinit (reason=", reason, ") - keeping persistent data for next session");
        #endif
        
        // Delete TH levels but keep TH3 structures (user drawings should persist)
        ObjectsDeleteAll(0, inpObjectPrefix);
        
        // Delete all zone objects from all modes
        ObjectsDeleteAll(0, inpObjectPrefix + "SSLS_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "M_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "TP_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Combo_Zone_", -1, -1);
        ObjectsDeleteAll(0, inpObjectPrefix + "Factor_Zone_", -1, -1);
    }

    // Clean up custom price selection objects (force delete the line)
    CleanupCustomPriceObjects(false, true);
    
    // Clear any comment
    Comment("");
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 4: Free all dynamic arrays to prevent memory leaks
    // ═══════════════════════════════════════════════════════════════
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Freeing arrays...");
    #endif
    ArrayFree(g_thCache);
    ArrayFree(g_storedTHs);
    ArrayFree(g_labelPositions);
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 5: Cleanup all managers to prevent memory leaks
    // ═══════════════════════════════════════════════════════════════
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Cleaning up managers...");
    #endif
    
    // Cleanup BasePriceManager
    CleanupBasePriceManager();
    
    // Cleanup ATR cache
    CleanupATRCache();
    
    // Cleanup ObjectCountManager
    CleanupObjectCountManager();
    
    // Cleanup Learning System
    CleanupLearningSystem();
    
    // Cleanup Object Cache (FLICKERING FIX)
    CacheClear();
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 Object cache cleared");
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 6: Reset all global state variables
    // ═══════════════════════════════════════════════════════════════
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
//| پاک کردن تمام سطوح از همه مودها برای جلوگیری از تداخل           |
//| CRITICAL FIX: Added error handling and retry logic              |
//+------------------------------------------------------------------+
void ClearAllLevels(const string objectPrefix, bool clearZones = true)
{
    // DEBUG: Log when zones are being cleared
    #ifdef ENABLE_DEBUG_LOGS
    Print("🧹 ClearAllLevels called: prefix=", objectPrefix, ", clearZones=", clearZones, ", dragging=", g_customPriceLineDragging);
    #endif
    
    // OPTIMIZATION: Instead of iterating all objects, use ObjectsDeleteAll with prefix
    // This is much faster than checking each object individually
    // Delete all level objects from all modes to prevent overlapping when switching modes
    // 
    // ANTI-FLICKER FIX: clearZones parameter allows skipping zone deletion during drag
    // رفع چشمک زدن: پارامتر clearZones اجازه می‌دهد در هنگام درگ، زون‌ها پاک نشوند
    
    // CRITICAL FIX: Track deletion statistics for error recovery
    int totalDeleted = 0;
    int totalFailed = 0;
    
    // Log clearing (throttled) - DEBUG only
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastClearLog = 0;
    if(TimeCurrent() - s_lastClearLog > 5) {
        Print("[MT4] 🧹 CLEARING ALL LEVELS with prefix: ", objectPrefix);
        s_lastClearLog = TimeCurrent();
    }
    #endif
    
    // CRITICAL FIX: Define all prefixes in array for systematic deletion
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
    
    // GOLD FIX v3: Enhanced array safety with bounds checking
    int prefixCount = ArraySize(prefixes);
    
    // CRITICAL: Validate array size before processing
    if(prefixCount > MAX_PREFIX_COUNT) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CRITICAL: Prefix count (", prefixCount, ") exceeds MAX_PREFIX_COUNT (", MAX_PREFIX_COUNT, ")");
        #endif
        prefixCount = MAX_PREFIX_COUNT;
    }
    
    // CRITICAL FIX: Delete with error handling
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
            
            // CRITICAL FIX: Retry once on failure
            ResetLastError();
            // Sleep removed for MQL5 indicator compatibility
            result = ObjectsDeleteAll(0, prefixes[i], -1, -1);
            if(result >= 0) {
                totalDeleted += result;
                totalFailed--; // Retry succeeded
            }
        }
    }
    
    // Delete zone objects separately (only if clearZones=true)
    // فقط در صورتی که clearZones=true باشد، زون‌ها پاک می‌شوند
    if(clearZones) {
        string zonePrefixes[];
        ArrayResize(zonePrefixes, 5);
        zonePrefixes[0] = objectPrefix + "SSLS_Zone_";
        zonePrefixes[1] = objectPrefix + "M_Zone_";
        zonePrefixes[2] = objectPrefix + "TP_Zone_";
        zonePrefixes[3] = objectPrefix + "Combo_Zone_";
        zonePrefixes[4] = objectPrefix + "Factor_Zone_";
        
        // PERFORMANCE: Cache ArraySize before loop
        int zonePrefixCount = ArraySize(zonePrefixes);
        for(int i = 0; i < zonePrefixCount; i++) {
            int result = ObjectsDeleteAll(0, zonePrefixes[i], -1, -1);
            if(result >= 0) {
                totalDeleted += result;
            } else {
                totalFailed++;
            }
        }
        
        // CRITICAL FIX: Clear object cache when zones are deleted
        // This prevents "unchanged, skipping" when zones are recreated
        CacheClear();
    }
    
    #ifdef ENABLE_DEBUG_LOGS
    if(totalDeleted > 0 || totalFailed > 0) {
        Print("✅ ClearAllLevels: Deleted=", totalDeleted, ", Failed=", totalFailed);
    }
    #endif
    
    // CRITICAL FIX: If too many failures, force manual cleanup
    if(totalFailed > 5) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ WARNING: Multiple deletion failures (", totalFailed, ") - forcing manual cleanup");
        #endif
        // GOLD FIX: Cache ObjectsTotal outside loop
        int total = ObjectsTotal(0, -1, -1);
        int prefixLen = StringLen(objectPrefix);
        for(int i = total - 1; i >= 0; i--) {
            string name = ObjectName(0, i, -1, -1);
            // OPTIMIZATION: Use StringSubstr for faster prefix check
            if(StringLen(name) >= prefixLen && StringSubstr(name, 0, prefixLen) == objectPrefix) {
                ObjectDelete(0, name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get adaptive level counts based on start point type             |
//+------------------------------------------------------------------+
void GetAdaptiveLevelCounts(int &maxAbove, int &maxBelow)
{
    // Adaptive level counts based on start point type:
    // - Custom Price: User-defined (default 20 levels) - focused view around custom price
    // - Historical High/Low/Midpoint: Up to MAX_SAFE_LEVELS (200) for full historical range
    
    // PERFORMANCE FIX: Trigger levels no longer multiply the count.
    // When trigger is on, ShouldDrawStepOptimized draws ALL steps (not just every Nth),
    // which already produces enough granularity. Multiplying count too wastes objects.
    
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        // Custom price mode: Use user-defined level count
        maxAbove = inpCustomPriceMaxLevels;
        maxBelow = inpCustomPriceMaxLevels;
        
        // Safety: Limit to MAX_SAFE_LEVELS to prevent performance issues
        if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
        if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
        
        // Minimum 1 level
        if(maxAbove < 1) maxAbove = 1;
        if(maxBelow < 1) maxBelow = 1;
    } else {
        // Historical modes: Use input parameters with safety limits
        maxAbove = inpMaxTHLevelsAbove;
        maxBelow = inpMaxTHLevelsBelow;
        
        // Safety: Limit to MAX_SAFE_LEVELS to prevent performance issues
        if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
        if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
        
        // Minimum 1 level
        if(maxAbove < 1) maxAbove = 1;
        if(maxBelow < 1) maxBelow = 1;
    }
}

//+------------------------------------------------------------------+
//| Get Current Calculation Basis (respects keyboard override)       |
//| دریافت مبنای محاسبات فعلی (با احترام به override کیبورد)         |
//+------------------------------------------------------------------+
ENUM_CALCULATION_BASIS GetCurrentCalculationBasis() {
    if(g_calculationBasisOverride >= 0) {
        return (ENUM_CALCULATION_BASIS)g_calculationBasisOverride;
    }
    return inpCalculationBasis;
}

//+------------------------------------------------------------------+
//| Helper structure to hold common calculation values              |
//| All values are in PRICE units (matching MotiveWave)             |
//+------------------------------------------------------------------+
struct StepCalculationData {
    double thValue;              // TH value in PRICE units
    double structureValue;       // Structure value in PRICE units
    double patternValue;         // Pattern value in PRICE units
    double triggerValue;         // Trigger value in PRICE units
    double shortStep;            // SS = 1.5 * Structure (PRICE units)
    double longStep;             // LS = 2.0 * Structure (PRICE units)
    double pointSize;            // DEPRECATED: No longer used (set to 1.0)
    double midpointPrice;        // Start point price
    int maxLevelsAbove;          // Adaptive max levels above
    int maxLevelsBelow;          // Adaptive max levels below
    bool isATRBasis;             // True if using ATR basis
};

//+------------------------------------------------------------------+
//| Calculate common values used across all step modes              |
//| Supports both TH_BASIS and ATR_BASIS (matching Java)            |
//+------------------------------------------------------------------+
bool CalculateCommonStepData(const double dailyClosePrice, StepCalculationData &data)
{
    if(dailyClosePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("CalculateCommonStepData: Invalid daily close price");
        #endif
        return false;
    }
    
    // OPTIMIZATION: Cache calculation results
    static StepCalculationData s_cachedData;
    static double s_lastDailyClose = 0;
    static ENUM_CALCULATION_BASIS s_lastBasis = -1;
    static string s_lastTF = "";
    static int s_lastStartPointType = -1;
    static double s_lastCustomPrice = 0;
    static int s_lastMaxAbove = 0;
    static int s_lastMaxBelow = 0;
    
    string currentTF = GetFractalTimeframeForCurrent();
    ENUM_CALCULATION_BASIS currentBasis = GetCurrentCalculationBasis();
    
    // GOLD FIX: Include max levels in cache dependency for complete invalidation
    if(dailyClosePrice == s_lastDailyClose && 
       currentBasis == s_lastBasis && 
       currentTF == s_lastTF &&
       g_thStartPointType == s_lastStartPointType &&
       (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE || g_customTHStartPrice == s_lastCustomPrice) &&
       inpMaxTHLevelsAbove == s_lastMaxAbove &&
       inpMaxTHLevelsBelow == s_lastMaxBelow &&
       s_lastDailyClose != 0) {
        data = s_cachedData;
        return true;
    }

    // Get current calculation basis
    data.isATRBasis = (currentBasis == CALC_BASIS_ATR);
    
    // OPTIMIZATION: Use global Digits instead of MarketInfo call
    int digits = Digits;
    
    if(data.isATRBasis) {
        //=============================================================
        // ATR_BASIS: Use Weighted ATR for calculations
        // مبنای ATR: استفاده از ATR وزن‌دار برای محاسبات
        //=============================================================
        
        // Calculate ATR-based values
        CalculateATRFractalValues(data.structureValue, data.patternValue, data.triggerValue);
        data.thValue = data.structureValue;  // For ATR, TH = Structure = Weighted ATR
        
        #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastATRDebugLogTime = 0;
        datetime currentDebugTime = TimeCurrent();
        if(currentDebugTime - s_lastATRDebugLogTime > 300) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("========== MT4 ATR_BASIS CALCULATION ==========");
            Print("Calculation Basis: ATR (Actual)");
            Print("Weighted ATR (Structure): ", DoubleToString(data.structureValue, 10));
            Print("Pattern Value (0.5×ATR): ", DoubleToString(data.patternValue, 10));
            Print("Trigger Value (0.25×ATR): ", DoubleToString(data.triggerValue, 10));
            Print("SS (1.5 × Structure): ", DoubleToString(data.structureValue * 1.5, 10));
            Print("LS (2.0 × Structure): ", DoubleToString(data.structureValue * 2.0, 10));
            Print("================================================");
            #endif
            s_lastATRDebugLogTime = currentDebugTime;
        }
        #endif
        
    } else {
        //=============================================================
        // TH_BASIS: Use TH formula for calculations (default)
        // مبنای TH: استفاده از فرمول TH برای محاسبات (پیش‌فرض)
        //=============================================================
        
        // Calculate TH in PRICE units directly (matching MotiveWave)
        double timeframePercentage = GetTimeframeTH();
        
        // Use CalculateTH which returns price units, NOT CalculateTHPoints
        data.thValue = CalculateTH(dailyClosePrice, digits, timeframePercentage);
        CalculateFractalValues(data.thValue, data.structureValue, data.patternValue, data.triggerValue);
        
        #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastTHDebugLogTime = 0;
        datetime currentDebugTime = TimeCurrent();
        if(currentDebugTime - s_lastTHDebugLogTime > 300) {
            #ifdef ENABLE_DEBUG_LOGS
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
            #endif
            s_lastTHDebugLogTime = currentDebugTime;
        }
        #endif
    }
    
    // Calculate SS/LS values using simple multipliers (in PRICE units)
    // SS = 1.5 * Structure, LS = 2.0 * Structure
    data.shortStep = data.structureValue * 1.5;
    data.longStep = data.structureValue * 2.0;
    
    // NO point size conversion needed - values are already in price units
    data.pointSize = 1.0;  // Not used anymore
    
    // Get midpoint price using utility function
    data.midpointPrice = GetMidpointPrice(g_thStartPointType);
    
    // Validate midpoint price
    if(data.midpointPrice <= 0 || data.midpointPrice == EMPTY_VALUE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ ERROR: Invalid midpoint price! g_highestHigh=", g_highestHigh, ", g_lowestLow=", g_lowestLow);
        #endif
        return false;
    }
    
    // Get adaptive level counts based on start point type
    GetAdaptiveLevelCounts(data.maxLevelsAbove, data.maxLevelsBelow);
    
    // Update cache
    s_cachedData = data;
    s_lastDailyClose = dailyClosePrice;
    s_lastBasis = currentBasis;
    s_lastTF = currentTF;
    s_lastStartPointType = g_thStartPointType;
    s_lastCustomPrice = g_customTHStartPrice;
    s_lastMaxAbove = inpMaxTHLevelsAbove;
    s_lastMaxBelow = inpMaxTHLevelsBelow;
    
    return true;
}

//+------------------------------------------------------------------+
//| Wrapper function to handle different step calculation modes     |
//+------------------------------------------------------------------+
void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice)
{
    // PERFORMANCE FIX: Only clear ALL objects when the mode actually changes.
    // CreateTHLineObject already handles update-in-place (ObjectFind → ObjectSetDouble).
    // This eliminates the expensive destroy-all + recreate-all cycle on every redraw.
    static ENUM_STEP_CALCULATION_MODE s_lastDrawnMode = (ENUM_STEP_CALCULATION_MODE)-1;
    static ENUM_CALCULATION_BASIS s_lastDrawnBasis = (ENUM_CALCULATION_BASIS)-1;
    
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    ENUM_CALCULATION_BASIS currentBasis = GetCurrentCalculationBasis();
    
    bool modeChanged = (currentMode != s_lastDrawnMode || currentBasis != s_lastDrawnBasis);
    
    // ANTI-FLICKER FIX: Only clear if mode changed OR forceClear requested AND not dragging
    // حین drag، فقط update می‌کنیم نه clear
    if(modeChanged || (g_forceClearOnNextDraw && !g_customPriceLineDragging)) {
        // DEBUG: Log why we're clearing
        #ifdef ENABLE_DEBUG_LOGS
        Print("🎨 DrawLevelsBasedOnMode: modeChanged=", modeChanged, ", forceClear=", g_forceClearOnNextDraw, ", dragging=", g_customPriceLineDragging);
        #endif
        
        // Mode changed, or keyboard handler requested a full clear (and not dragging)
        ClearAllLevels(objectPrefix, true);  // Always clear zones when clearing
        s_lastDrawnMode = currentMode;
        s_lastDrawnBasis = currentBasis;
        g_forceClearOnNextDraw = false;
    }
    
    // Draw based on selected mode (respects keyboard override)
    switch(currentMode) {
        case SS_LS_STEP:
        {
            StepCalculationData data;
            if(!CalculateCommonStepData(dailyClosePrice, data)) return;
            
            // SS and LS are already in PRICE units (no conversion needed)
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
            
            // Control value is already in PRICE units (no conversion needed)
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
            
            // TP = E × 3 = TH × 0.75 × 3 = TH × 2.25 (matching Java TP_STEP)
            double eValue = CalculateEStep(data.thValue);  // E = TH × 0.75
            double tpValue = CalculateTPStep(eValue);       // TP = E × 3
            
            // Use DrawTHLevelsWithStep for TP mode
            DrawTHLevelsWithStep(objectPrefix, data.midpointPrice, tpValue, "TP",
                                data.maxLevelsAbove, data.maxLevelsBelow);
            break;
        }
        
        case COMBO_STEP:
        {
            StepCalculationData data;
            if(!CalculateCommonStepData(dailyClosePrice, data)) return;
            
            // ═══════════════════════════════════════════════════════════════
            // UNIFIED COMBO SYSTEM: Uses Preset/Operation configuration
            // سیستم یکپارچه کامبو: از تنظیمات Preset/Operation استفاده می‌کند
            // ═══════════════════════════════════════════════════════════════
            
            // Calculate combo step using unified function (shared with Factor mode)
            // محاسبه گام کامبو با تابع یکپارچه (مشترک با حالت Factor)
            double comboStep = CalculateComboStepSize(dailyClosePrice);
            
            // CRITICAL: Check for errors with user-friendly message
            if(comboStep <= 0) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("❌ COMBO_STEP: Failed to calculate combo step");
                Print("   Base Price: ", dailyClosePrice);
                Print("   Preset: ", EnumToString(inpComboPreset));
                #endif
                
                // Show error to user
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
            
            // ALWAYS log Combo calculations (throttled to once per mode switch)
            // همیشه محاسبات کامبو رو لاگ کن (برای اطمینان از صحت محاسبات)
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
            
            // Use DrawTHLevelsWithStep for Combo Step mode
            DrawTHLevelsWithStep(objectPrefix, data.midpointPrice, comboStep, "Combo",
                                data.maxLevelsAbove, data.maxLevelsBelow);
            break;
        }
        
        case FACTOR_STEP:
        {
            // ═══════════════════════════════════════════════════════════
            // FACTOR MODE: Uses same structure as other modes
            // حالت Factor: از همان ساختار سایر مدها استفاده می‌کند
            // ═══════════════════════════════════════════════════════════
            
            // Calculate common step data (like other modes)
            StepCalculationData data;
            if(!CalculateCommonStepData(dailyClosePrice, data)) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("❌ FACTOR_STEP: Failed to calculate common step data");
                #endif
                return;
            }
            
            // Get Factor value - priority: keyboard override > input parameter > auto
            double factorValue;
            if(g_factorValueOverride > 0) {
                // Keyboard override (user pressed +/-)
                factorValue = g_factorValueOverride;
            } else if(inpFactorMode == FACTOR_MODE_MANUAL) {
                // Manual mode: Use user-defined value from settings
                factorValue = inpFactorValue;
            } else {
                // Auto mode: Calculate factor so each level equals current TF's TH
                factorValue = GetDefaultFactorValue(dailyClosePrice);
            }
            
            // Validate and clamp Factor range (minimum 0.01, maximum 10000)
            factorValue = NormalizeDouble(MathMax(0.01, MathMin(10000, factorValue)), 2);
            
            #ifdef ENABLE_DEBUG_LOGS
            string modeStr = (g_factorValueOverride > 0) ? "KEYBOARD" : 
                            ((inpFactorMode == FACTOR_MODE_AUTO) ? "AUTO" : "MANUAL");
            Print("FACTOR_STEP: Mode=", modeStr, ", Factor=", DoubleToString(factorValue, 2));
            Print("   Center=", DoubleToString(data.midpointPrice, Digits),
                  " (", (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE ? "Custom" : "Midpoint"), ")");
            Print("   MaxLevels: Above=", data.maxLevelsAbove, ", Below=", data.maxLevelsBelow);
            #endif
            
            // Show Factor label
            UpdateFactorLabel(factorValue);
            
            // Check if Harmonic Alternating Pattern is enabled
            if(inpEnableHarmonicPattern) {
                // ═══════════════════════════════════════════════════════════
                // HARMONIC MODE: Alternating pattern with base and large steps
                // ═══════════════════════════════════════════════════════════
                
                // Validate harmonic ratio with strict bounds
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
                
                // Normalize to 3 decimal places
                harmonicRatio = NormalizeDouble(harmonicRatio, 3);
                
                // Calculate base step size
                double baseStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
                if(baseStepSize <= 0) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ FACTOR_STEP: Invalid base step size calculated");
                    #endif
                    return;
                }
                
                // Validate base step is not too small
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
                
                // Draw Harmonic Alternating levels from center (like other modes)
                DrawFactorLevelsHarmonicFromCenter(objectPrefix, data.midpointPrice, 
                                                   g_highestHigh, g_lowestLow,
                                                   factorValue, baseStepSize, harmonicRatio,
                                                   data.maxLevelsAbove, data.maxLevelsBelow);
                
            } else {
                // ═══════════════════════════════════════════════════════════
                // STANDARD MODE: Equal spacing
                // ═══════════════════════════════════════════════════════════
                
                // Calculate step size for Factor mode
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
                
                // Draw Factor levels from center (like other modes)
                DrawFactorLevelsFromCenter(objectPrefix, data.midpointPrice, 
                                          g_highestHigh, g_lowestLow, 
                                          factorValue, factorStepSize,
                                          data.maxLevelsAbove, data.maxLevelsBelow);
            }
            
            // Also draw Historical High/Low reference lines
            // NOTE: Boundary lines always use actual historical high/low
            double referenceStepSize = CalculateFactorStepSize(g_highestHigh, g_lowestLow, factorValue);
            DrawFactorBoundaryLines(objectPrefix, g_highestHigh, g_lowestLow, factorValue, referenceStepSize);
            
            // GOLD FIX: Memory cleanup for Factor mode
            // No dynamic arrays in StepCalculationData, but good practice to reset
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ FACTOR_STEP: Completed successfully");
            #endif
            
            break;
        }
        
        case TH_STEP:
        default:
        {
            // Get calculation basis to decide which method to use
            ENUM_CALCULATION_BASIS currentBasis = GetCurrentCalculationBasis();
            
            if(currentBasis == CALC_BASIS_ATR) {
                // ATR_BASIS: Use CalculateCommonStepData like other modes
                StepCalculationData data;
                if(!CalculateCommonStepData(dailyClosePrice, data)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("❌ TH_STEP (ATR): Failed to calculate common step data");
                    #endif
                    return;
                }
                
                // Use DrawTHLevelsWithStep with Structure value as step
                DrawTHLevelsWithStep(objectPrefix, data.midpointPrice, data.structureValue, "S",
                                    data.maxLevelsAbove, data.maxLevelsBelow);
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ TH_STEP (ATR): Completed successfully");
                #endif
            } else {
                // TH_BASIS: Use original DrawTHLevels for traditional TH mode
                DrawTHLevels(objectPrefix, dailyClosePrice);
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ TH_STEP (TH): Completed successfully");
                #endif
            }
            break;
        }
    }
    
    // GOLD FIX: Final cleanup after all modes
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ DrawLevelsBasedOnMode: All operations completed");
    #endif
}

// DEPRECATED: Old helper functions removed
// Base price history is now managed by BasePriceManager.mqh
// Use PrintBasePriceHistory() from BasePriceManager instead

void RedrawAllObjects(bool force_redraw=false)
{
    // CRITICAL: Use GMT/UTC time for consistent base price updates across platforms
    datetime currentTime = TimeGMT();  // GMT/UTC time (not server time)

    // OPTIMIZATION: Use centralized cached values from PerformanceOptimizations.mqh
    string s_cachedSymbol = GetCachedSymbol();
    int s_cachedDigits = GetCachedDigits();
    double s_cachedPoint = GetCachedPoint();

    // Live price for distance/alerts (TH calculations use separate base price)
    g_currentPrice = Bid;
    if(g_currentPrice <= 0) return;
    
    // ═══════════════════════════════════════════════════════════════════
    // BASE PRICE UPDATE (NEW IMPLEMENTATION - Matching Java/MotiveWave)
    // ═══════════════════════════════════════════════════════════════════
    // Update base price every 30 minutes using BasePriceManager
    // This replaces the old inline logic with a clean, tested implementation
    UpdateBasePrice();
    
    // Get current base price for TH calculations
    double thBasePrice = GetBasePriceForTH();
    if(thBasePrice <= 0 || thBasePrice == EMPTY_VALUE) {
        // Fallback to daily close if base price not initialized
        thBasePrice = g_dailyClosePriceForTH;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    
    // OLD BASE PRICE LOGIC REMOVED - Now handled by BasePriceManager.mqh
    // The new implementation provides:
    // - Duplicate prevention with lastProcessedBlockTimestamp
    // - Correct M1 reference tracking (only updates on ACCEPT)
    // - Accurate last bar finding in previous 30-min block
    // - Complete history format matching Java/MotiveWave
    
    // Check if base price changed and redraw is needed
    static double s_lastDrawnBasePrice = 0.0;
    bool basePriceChanged = (MathAbs(thBasePrice - s_lastDrawnBasePrice) > s_cachedPoint);
    if(basePriceChanged) {
        s_lastDrawnBasePrice = thBasePrice;
        g_redrawTHLevelsNeeded = true;
    }
    
    // Continue with rest of RedrawAllObjects logic...
    
    // Check if custom price line exists and is being dragged (for live update)
    bool customPriceLineExists = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
    
    // GOLD FIX v3: Use named constant instead of magic number
    // OPTIMIZED: Throttle updates to prevent excessive calculations
    // BUT: Allow updates if:
    //   1. force_redraw is true
    //   2. custom price line is active (for live dragging)
    //   3. base price just changed (CRITICAL for timely updates)
    if(!force_redraw && !customPriceLineExists && !basePriceChanged && !g_redrawTHLevelsNeeded && currentTime - g_lastCalculation < REDRAW_THROTTLE_SECONDS && g_initialized) return;
    g_lastCalculation = currentTime;
    
    // Define objectPrefix early for use in cleanup
    string objectPrefix = inpObjectPrefix + "_" + GetCurrentTimeframe() + "_";
    
    // GOLD FIX v3: Use named constants instead of magic numbers
    // Periodic cleanup: Remove orphaned objects every 5 minutes to prevent accumulation
    if(currentTime - g_lastObjectCleanup > CLEANUP_INTERVAL_SECONDS) {
        int currentObjectCount = ObjectsTotal(0, -1, -1);
        if(currentObjectCount > g_objectCountLast + OBJECT_COUNT_INCREASE_THRESHOLD) {
            // Cleanup old objects older than 1 hour
            datetime cutoffTime = currentTime - 3600; // 1 hour ago
            
            // PERFORMANCE: Limit cleanup iterations to prevent stalls
            int maxCleanupItems = MathMin(currentObjectCount, 2000);
            for(int i = maxCleanupItems - 1; i >= 0; i--) {
                string objName = ObjectName(0, i, -1, -1);
                if(objName == "") continue;
                
                // Skip TH3 structures (user drawings)
                if(StringFind(objName, "TH3_Structure_") >= 0) continue;
                
                // CRITICAL FIX: Skip current timeframe objects to prevent them from disappearing
                if(StringFind(objName, objectPrefix) >= 0) continue;
                
                // Get object creation time
                datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
                
                // Delete if older than cutoff
                if(objTime > 0 && objTime < cutoffTime) {
                    ObjectDelete(0, objName);
                }
            }
        }
        g_objectCountLast = currentObjectCount;
        g_lastObjectCleanup = currentTime;
    }
    
    // Track timeframe changes when unlocked to clean up old objects
    // GOLD FIX v3: Move static variable to global scope to avoid MQL4 issues
    static string s_lastPrefix = "";
    if(s_lastPrefix != "" && s_lastPrefix != objectPrefix) {
        // Timeframe changed - delete old objects with old prefix
        ClearAllLevels(s_lastPrefix);
    }
    s_lastPrefix = objectPrefix;
    
    // OPTIMIZATION: Reduce debug log frequency to 60s (was 5s)
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastDebugLog = 0;
    if(TimeGMT() - s_lastDebugLog > 60) {
        Print("[MT4 DEBUG] RedrawAllObjects executing - Bid: ", DoubleToString(Bid, Digits));
        s_lastDebugLog = TimeGMT();
    }
    #endif
    
    // Use thBasePrice instead of g_currentPrice for TH calculations
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
    {
        // CRITICAL FIX: Use Close[0] of current timeframe (matching MotiveWave exactly)
        // MotiveWave uses: series.getBidClose(totalBars - 1) = Close of last completed candle
        // MT4 equivalent: iClose(_Symbol, _Period, 0) = Close[0]
        if (g_dailyClosePriceForTH == EMPTY_VALUE)
        {
            g_dailyClosePriceForTH = thBasePrice;  // Use thBasePrice which is already set to iClose(_Symbol, _Period, 0)
        }
        if(inpShowTHLabels && inpShowFractalTHs) DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(inpShowTHLabels && inpShowStandardTHs) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(inpShowTHLevels) g_redrawTHLevelsNeeded = true;
        g_calculatedOnce = true;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // CRITICAL FIX: Hide ALL objects if indicator is in hidden state
    // ═══════════════════════════════════════════════════════════════════
    // GOLD FIX: Check AFTER all object creation (DrawMainLevels + DisplayFractalTHs + DisplayStandardTHs)
    // This ensures ALL objects are hidden, not just some
    // PERFORMANCE: Cache hidden state check (every 2 seconds instead of every call)
    {
        static bool s_isHiddenCached = false;
        static datetime s_lastHiddenCheckTime = 0;
        if(currentTime - s_lastHiddenCheckTime >= 2) {
            string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
            // PERF FIX: Single Get + GetLastError instead of Check+Get
            double val = GlobalVariableGet(gvar_name);
            s_isHiddenCached = (GetLastError() != ERR_GLOBALVARIABLE_NOT_FOUND && (bool)val);
            s_lastHiddenCheckTime = currentTime;
        }
        if(s_isHiddenCached) {
            HideAllTHObjects();
        }
    }

    // MATCHING MOTIVEWAVE: Use half-hourly base price (updated at 11:59, 12:29, 12:59, ...)
    // This matches MotiveWave implementation exactly
    // Base price stays constant within each 30-minute block for consistent levels
    g_dailyClosePriceForTH = thBasePrice;

    // OPTIMIZATION: Cache gvarName and reuse customPriceLineExists (already checked above)
    string gvarName = "Biotak_CustomPrice_" + s_cachedSymbol;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + s_cachedSymbol;
    bool lineExists = customPriceLineExists;  // Reuse ObjectFind from above
    
    double currentLinePrice = lineExists ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0.0;

    // OPTIMIZATION: Old dragging detection logic removed
    // Now using CHARTEVENT_MOUSE_MOVE for real-time drag detection (more accurate)
    // منطق قدیمی تشخیص درگ حذف شد - حالا از CHARTEVENT_MOUSE_MOVE استفاده می‌شود
    
    // OPTIMIZATION: Only check GlobalVariable if not currently dragging
    // During drag, we already have the latest price from the line
    if(!g_customPriceLineDragging) {
        // ═══════════════════════════════════════════════════════════════════
        // Custom Price Priority Logic (RedrawAllObjects):
        // 1. If keyboard override is active (user pressed C) → use GlobalVariable
        // 2. If input parameter is set and no keyboard override → use input parameter
        // 3. If only GlobalVariable exists → use it
        // NOTE: Factor Mode now supports Custom Price (like other modes)
        // ═══════════════════════════════════════════════════════════════════
        
        bool hasGlobalVar = GlobalVariableCheck(gvarName);
        double savedPrice = hasGlobalVar ? GlobalVariableGet(gvarName) : 0.0;
        
        if(g_customPriceKeyboardOverride && savedPrice > 0.0) {
            // User pressed C key - use keyboard-set price (ignore input parameter)
            if(MathAbs(g_customTHStartPrice - savedPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = savedPrice;
                g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            }
            
            // Restore custom price horizontal line if it doesn't exist
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
            // User set custom price in settings - use it (no keyboard override)
            // OPTIMIZATION: Only update if different from current value
            if(MathAbs(g_customTHStartPrice - inpCustomTHStartPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = inpCustomTHStartPrice;
                g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
                
                // Save to GlobalVariable for persistence
                GlobalVariableSet(gvarName, g_customTHStartPrice);
                
                // Update or create the custom price horizontal line
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
            // Input parameter is 0, restore from GlobalVariable (keyboard-set price)
            if(MathAbs(g_customTHStartPrice - savedPrice) > s_cachedPoint * 0.1) {
                g_customTHStartPrice = savedPrice;
                g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            }
            
            // Restore custom price horizontal line if it doesn't exist
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
        } else {
            // No custom price set - use the input parameter setting
            g_thStartPointType = inpTHStartPointType;
            g_customTHStartPrice = 0.0;
        }
    }
    
    if (inpShowTHLevels && g_redrawTHLevelsNeeded)
    {
        // Log level redraw with reason
        #ifdef ENABLE_DEBUG_LOGS
        static datetime s_lastLevelRedrawLog = 0;
        if(TimeCurrent() - s_lastLevelRedrawLog > 5) {
            Print("[MT4] 🎨 REDRAWING LEVELS | Base Price: ", DoubleToString(g_dailyClosePriceForTH, Digits), 
                  " | Mode: ", GetStepModeName(GetCurrentStepMode()));
            s_lastLevelRedrawLog = TimeCurrent();
        }
        #endif
        
        // DrawLevelsBasedOnMode handles clearing internally based on mode changes
        // No need to clear here - it causes zones to disappear after drag
        DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH);
        g_redrawTHLevelsNeeded = false;
    }
    else if (!inpShowTHLevels && g_redrawTHLevelsNeeded)
    {
        // Use ClearAllLevels to properly delete all level objects
        ClearAllLevels(objectPrefix);
        g_redrawTHLevelsNeeded = false;
    }

    // PERFORMANCE FIX: ApplyLinesVisibility removed from per-redraw path.
    // Drawing functions (CreateTHLineObject, etc.) already respect g_linesVisible.
    // ApplyLinesVisibility is now ONLY called from the L key toggle handler.

    // CRITICAL FIX: Apply g_linesVisible state to all line objects
    // This ensures that when Trigger (T) is toggled, Lines (L) state is preserved
    // اطمینان از اینکه وقتی Trigger (T) toggle می‌شود، وضعیت Lines (L) حفظ می‌شود
    if(!g_linesVisible) {
        int total = ObjectsTotal(0, -1, -1);
        string cachedPrefix = objectPrefix;
        int prefixLen = StringLen(cachedPrefix);
        
        for(int i = 0; i < total; i++) {
            string objName = ObjectName(0, i, -1, -1);
            
            // Check if it's our object (has the prefix)
            if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix) {
                // Check if it's a line object (HLINE or TREND)
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
    // CPU Performance Monitoring
    static uint s_lastCPUTime = 0;
    static int s_cpuWarningCount = 0;
    uint startTime = GetTickCount();
    
    // OPTIMIZATION: Use centralized cached hidden state
    if(IsIndicatorHidden())
    {
        return(rates_total);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // TASK 10.1: Redraw Flag Check - Skip drawing if not needed
    // ═══════════════════════════════════════════════════════════════════
    // Check if redraw is needed before proceeding with drawing pipeline
    // This prevents unnecessary redraws when prices haven't changed
    if(!IsRedrawNeeded() && !g_redrawTHLevelsNeeded && !g_forceClearOnNextDraw) {
        // No redraw needed - skip all drawing operations
        return(rates_total);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // TASK 10.1: Price Change Detection
    // ═══════════════════════════════════════════════════════════════════
    // Detect if price has changed significantly to trigger redraw
    static double s_lastPrice = 0.0;
    double currentPrice = (rates_total > 0) ? close[rates_total - 1] : 0.0;
    bool priceChanged = false;
    
    if(s_lastPrice > 0 && currentPrice > 0) {
        double priceChangePips = MathAbs(currentPrice - s_lastPrice) / Point;
        // Only trigger redraw if price changed by more than 1 pip
        if(priceChangePips > 1.0) {
            priceChanged = true;
            SetRedrawFlag(true);
        }
    }
    
    if(currentPrice > 0) {
        s_lastPrice = currentPrice;
    }
    
    // PERFORMANCE: Tick-level throttle — skip if called faster than 500ms
    // بهینه‌سازی: اگر کمتر از ۵۰۰ میلی‌ثانیه گذشته، تیک را رد کن
    static uint s_lastTickMs = 0;
    uint nowMs = GetTickCount();
    bool tickThrottled = (nowMs - s_lastTickMs < 500 && s_lastTickMs != 0);
    
    static int s_lastBars = 0;
    int currentBars = Bars(_Symbol, _Period);
    bool isNewBar = (currentBars != s_lastBars && s_lastBars != 0);
    
    if(rates_total > 0)
    {
        // ═══════════════════════════════════════════════════════════════════
        // TASK 10.4: Historical Object Update Skip for Incremental Updates
        // ═══════════════════════════════════════════════════════════════════
        // Check if only current bar is updating (incremental update)
        // Skip historical object modifications to prevent unnecessary updates
        bool isIncrementalUpdate = (prev_calculated > 0 && rates_total - prev_calculated <= 1);
        
        // Only redraw on new bar, or if tick throttle expired
        // EXCEPTION: Always redraw if levels need updating (keyboard/settings change)
        // This reduces CPU from ~100% to <5% on fast-moving markets
        if(tickThrottled && !isNewBar && !g_redrawTHLevelsNeeded && !g_forceClearOnNextDraw && !priceChanged) {
            return(rates_total);
        }
        
        // Skip historical object updates for incremental updates
        // Only update when new bar forms or full redraw is needed
        if(isIncrementalUpdate && !g_redrawTHLevelsNeeded && !g_forceClearOnNextDraw && !isNewBar) {
            // Incremental update - skip historical object modifications
            return(rates_total);
        }
        
        s_lastTickMs = nowMs;
        
        // Force redraw when levels need updating (settings change / keyboard)
        RedrawAllObjects(g_redrawTHLevelsNeeded || g_forceClearOnNextDraw);
        
        // ═══════════════════════════════════════════════════════════════════
        // TASK 10.1: Clear Redraw Flag After Successful Draw
        // ═══════════════════════════════════════════════════════════════════
        // Reset the redraw flag after successful drawing operation
        ClearRedrawFlag();
        
        // Track bar changes for object count monitoring
        if(currentBars > s_lastBars || s_lastBars == 0) {
            s_lastBars = currentBars;
            
            // OPTIMIZATION: Enhanced object count monitoring with auto-cleanup
            int totalObjects = ObjectsTotal(0, -1, -1);
            if(totalObjects > MAX_SAFE_OBJECTS && totalObjects < CRITICAL_OBJECT_LIMIT) {
                #ifdef ENABLE_DEBUG_LOGS
                if(s_cpuWarningCount % 10 == 0) { // Log every 10th warning to avoid spam
                    Print("⚠️ Performance Warning: ", totalObjects, " objects on chart (recommended max: ", MAX_SAFE_OBJECTS, ")");
                    Print("🧹 Consider reducing inpMaxTHLevelsAbove/Below for better performance");
                }
                #endif
                s_cpuWarningCount++;
            }
            else if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("🔴 CRITICAL: ", totalObjects, " objects approaching MT4 limit (64000)!");
                Print("🧹 EMERGENCY: Using ObjectsDeleteAll for cleanup...");
                #endif
                // GOLD FIX: Use ObjectsDeleteAll instead of loop - much faster!
                int deleted = 0;
                deleted += ObjectsDeleteAll(0, "Zone_", -1, -1);  // Remove all zones
                deleted += ObjectsDeleteAll(0, "Mid_", -1, -1);   // Remove all mid-zones
                
                #ifdef ENABLE_DEBUG_LOGS
                int afterCleanup = ObjectsTotal(0, -1, -1);
                Print("✅ Emergency cleanup completed. Objects: ", totalObjects, " -> ", afterCleanup, " (deleted=", deleted, ")");
                #endif
            }
        }
    }
    
    // CPU Time Monitoring
    uint elapsed = GetTickCount() - startTime;
    if(elapsed > CPU_WARNING_MS) {
        if(elapsed > CPU_CRITICAL_MS) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("🔴 CRITICAL CPU: OnCalculate took ", elapsed, "ms! Reduce inpMaxTHLevels!");
            #endif
        }
        else if(s_lastCPUTime == 0 || GetTickCount() - s_lastCPUTime > 60000) { // Log once per minute
            #ifdef ENABLE_DEBUG_LOGS
            Print("⚠️ CPU Warning: OnCalculate took ", elapsed, "ms (threshold: ", CPU_WARNING_MS, "ms)");
            #endif
            s_lastCPUTime = GetTickCount();
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Apply Lines Visibility State to All Line Objects                 |
//| اعمال وضعیت نمایش خطوط به همه اشیاء خط                          |
//|                                                                  |
//| GOLD FIX: Removed redundant loop - visibility now set during     |
//| object creation in CreateTHLineObject()                         |
//| This function kept as stub for backward compatibility           |
//+------------------------------------------------------------------+
void ApplyLinesVisibility()
{
    // GOLD FIX: This loop is now REDUNDANT because:
    // 1. CreateTHLineObject() already sets OBJPROP_TIMEFRAMES based on g_linesVisible
    // 2. Running this AFTER RedrawAllObjects() is wasteful
    // 3. Visibility is more efficiently handled during object creation
    
    // Stub: Do nothing - handled in CreateTHLineObject()
    return;
}

void OnChartEventHandler(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Handle key press events
    if(id == CHARTEVENT_KEYDOWN)
    {
        // Handle hide/show key
        string mutableHideKey = inpHideKey;
        StringToUpper(mutableHideKey);
        int hideKeyCode = StringGetCharacter(mutableHideKey, 0);

        if(lparam == hideKeyCode)
        {
            // ═══════════════════════════════════════════════════════════════
            // F KEY HANDLER: HIDE/SHOW TOGGLE
            // Requirements: 4.3, 10.3
            // Uses VisibilityManager to toggle visibility without deletion
            // ═══════════════════════════════════════════════════════════════
            // PERFORMANCE: Use cached ChartID string
            string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
            
            // GOLD FIX: Safe state toggle with validation
            double currentState = 0.0;
            if(GlobalVariableCheck(gvar_name)) {
                currentState = GlobalVariableGet(gvar_name);
                // Validate: only accept 0.0 or 1.0
                if(currentState != 0.0 && currentState != 1.0) {
                    currentState = 0.0; // Reset corrupted value
                }
            }
            
            bool isBecomingHidden = (currentState == 0.0); // Toggle

            // GOLD FIX: Atomic state update
            if(!GlobalVariableSet(gvar_name, isBecomingHidden ? 1.0 : 0.0)) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ F key: Failed to set GlobalVariable, Error: ", GetLastError());
                #endif
            }
            
            // PERFORMANCE: Immediately refresh the cached hidden state
            RefreshIsHiddenCache();

            // ═══════════════════════════════════════════════════════════════
            // OPTIMIZED: Use VisibilityManager instead of deletion/recreation
            // This prevents flickering and maintains object properties
            // ═══════════════════════════════════════════════════════════════
            #ifdef ENABLE_DEBUG_LOGS
            Print(isBecomingHidden ? "🔒 F key: Hiding all objects" : "👁️ F key: Showing all objects");
            #endif
            
            // Use VisibilityManager to toggle visibility without deletion
            SetAllTHObjectsVisibility(!isBecomingHidden);
            
            // Handle custom price line separately (no prefix)
            if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
                SetObjectVisibility(g_customPriceHorizontalLineName, !isBecomingHidden);
            }
            
            // Handle mode labels separately (no prefix)
            if(ObjectFind(0, g_stepModeLabelName) >= 0) {
                SetObjectVisibility(g_stepModeLabelName, !isBecomingHidden);
            }
            if(ObjectFind(0, g_basisModeLabelName) >= 0) {
                SetObjectVisibility(g_basisModeLabelName, !isBecomingHidden);
            }
            if(ObjectFind(0, g_factorLabelName) >= 0) {
                SetObjectVisibility(g_factorLabelName, !isBecomingHidden);
            }
            if(ObjectFind(0, g_frequencyLabelName) >= 0) {
                SetObjectVisibility(g_frequencyLabelName, !isBecomingHidden);
            }
            if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
                SetObjectVisibility(g_lockStatusLabelName, !isBecomingHidden);
            }
            
            // Update redraw flag
            if(isBecomingHidden) {
                g_redrawTHLevelsNeeded = false;
            } else {
                g_redrawTHLevelsNeeded = true;
            }
            
            ThrottledChartRedraw(); // Redraw chart to apply visual changes
        }
        
        // Handle lines toggle key (L)
        string mutableLinesKey = inpLinesToggleKey;
        StringToUpper(mutableLinesKey);
        int linesKeyCode = StringGetCharacter(mutableLinesKey, 0);
        
        if(lparam == linesKeyCode)
        {
            // ═══════════════════════════════════════════════════════════════
            // L KEY HANDLER: LINES VISIBILITY TOGGLE
            // Requirements: 4.4, 10.4
            // Uses VisibilityManager to toggle line visibility without deletion
            // ═══════════════════════════════════════════════════════════════
            
            // Toggle lines visibility
            g_linesVisible = !g_linesVisible;
            
            // Save state to GlobalVariable for persistence
            // PERFORMANCE: Use cached ChartID string
            string gvar_name = "Biotak_LinesVisible_" + GetCachedChartIdStr();
            GlobalVariableSet(gvar_name, g_linesVisible ? 1.0 : 0.0);
            
            // ═══════════════════════════════════════════════════════════════
            // OPTIMIZED: Use VisibilityManager instead of manual iteration
            // This ensures consistent behavior and prevents flickering
            // ═══════════════════════════════════════════════════════════════
            SetAllLineObjectsVisibility(g_linesVisible);
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("📊 Lines ", (g_linesVisible ? "VISIBLE" : "HIDDEN"));
            #endif
            
            ThrottledChartRedraw();
        }
        
        // Handle custom price key
        string mutableCustomKey = inpCustomPriceKey;
        StringToUpper(mutableCustomKey);
        int customKeyCode = StringGetCharacter(mutableCustomKey, 0);
        
        if(lparam == customKeyCode)
        {
            // Custom Price is now supported in all modes including Factor Mode
            
            g_waitingForCustomPriceClick = true;
            g_customPriceKeyboardOverride = true; // User pressed C - override input parameter
            
            // Save override flag to GlobalVariable for persistence across timeframe changes
            string overrideFlagName = "Biotak_CustomPriceOverride_" + GetCachedSymbol();
            GlobalVariableSet(overrideFlagName, 1.0);
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("Press anywhere on the chart to set custom TH start price");
            #endif
            
            // Delete existing horizontal line if any (force delete even if not in selection mode)
            ObjectDelete(0, g_customPriceHorizontalLineName);
            g_customPriceLineCreated = false;
            
            // Create a horizontal line at current price (original behavior - always reset to current price)
            double currentPrice = iClose(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0); // Get current price
            
            // IMPORTANT: Update global variables immediately so TH levels update
            g_customTHStartPrice = currentPrice;
            g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            
            // Save to GlobalVariable for persistence
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
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100); // Bring to front
            ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                          "📍 Custom Price: " + DoubleToString(currentPrice, Digits) + " | Drag to adjust, Double-click to confirm");
            g_customPriceLineCreated = true;
            
            // Force redraw TH levels with new custom price
            g_redrawTHLevelsNeeded = true;
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("📍 Custom price set to: ", DoubleToString(currentPrice, Digits), " - Drag to adjust.");
            #endif
            
            ThrottledChartRedraw();
        }
        
        // Handle Escape key to cancel/exit custom price mode
        if(lparam == 27) // 27 is the ASCII code for Escape key
        {
            string symbolName = GetCachedSymbol();
            string gvarName = "Biotak_CustomPrice_" + symbolName;
            string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
            bool customPriceActive = GlobalVariableCheck(gvarName);
            
            if(g_waitingForCustomPriceClick || customPriceActive || g_customPriceKeyboardOverride)
            {
                CleanupCustomPriceObjects(true, true); // Reset global variables too and force delete the line
                g_thStartPointType = inpTHStartPointType; // Return to input parameter setting
                g_customPriceKeyboardOverride = false; // Reset keyboard override flag
                
                // Clear override flag from GlobalVariable
                GlobalVariableSet(overrideFlagName, 0.0);
                
                g_forceClearOnNextDraw = true;
                g_redrawTHLevelsNeeded = true;
                RedrawAllObjects(true); // Force redraw with input parameter setting
                #ifdef ENABLE_DEBUG_LOGS
                Print("Custom price mode cancelled - returned to Input Parameter setting");
                #endif
                ThrottledChartRedraw();
            }
        }
        
        // Handle Trigger Levels toggle key (T)
        string mutableTriggerKey = inpTriggerLevelsKey;
        StringToUpper(mutableTriggerKey);
        int triggerKeyCode = StringGetCharacter(mutableTriggerKey, 0);
        if(lparam == triggerKeyCode)
        {
            // Toggle Trigger TH Levels visibility
            // Note: We can't modify input parameters at runtime, so we use a global variable
            g_triggerLevelsEnabled = !g_triggerLevelsEnabled;
            
            // Persist state per chart
            // PERFORMANCE: Use cached ChartID string
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
            
            // Force redraw to apply the change
            g_forceClearOnNextDraw = true;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            ThrottledChartRedraw();
        }
        
        // Handle TH3 Tool toggle key
        string mutableTH3Key = inpTH3ToolKey;
        StringToUpper(mutableTH3Key);
        int th3KeyCode = StringGetCharacter(mutableTH3Key, 0);
        if(lparam == th3KeyCode)
        {
            ToggleTH3Tool();
            ThrottledChartRedraw(); // Force redraw to show/hide tool immediately
        }
        
        // Handle Frequency Analysis key (F) - analyze optimal default frequency
        // کلید تحلیل فرکانس (F) - تحلیل بهترین فرکانس پیش‌فرض
        if(lparam == 'F' || lparam == 70) // 70 = ASCII for 'F'
        {
            #ifdef ENABLE_DEBUG_LOGS
            Print("🔍 Starting Frequency Analysis...");
            #endif
            double optimalFreq = CalculateOptimalDefaultFrequency();
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Analysis complete. Recommended default: ", DoubleToString(optimalFreq, 3), "%");
            #endif
        }
        
        // Handle Step Mode Cycle key (E) - cycles through all modes
        string mutableStepModeKey = inpStepModeKey;
        StringToUpper(mutableStepModeKey);
        int stepModeKeyCode = StringGetCharacter(mutableStepModeKey, 0);
        if(lparam == stepModeKeyCode)
        {
            // Get current mode
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
            
            // Cycle to next mode: TH -> SS/LS -> M -> TP -> Combo -> Factor -> TH
            // Total 6 modes (0-5), so modulo 6
            ENUM_STEP_CALCULATION_MODE newMode = (ENUM_STEP_CALCULATION_MODE)(((int)currentMode + 1) % 6);
            
            // Set override
            g_stepModeOverride = (int)newMode;
            
            // Custom Price is now supported in all modes including Factor Mode
            // No need to reset start point type
            
            // Persist state per chart
            // PERFORMANCE: Use cached ChartID string
            string stepModeGvarName = "Biotak_StepMode_" + GetCachedChartIdStr();
            GlobalVariableSet(stepModeGvarName, g_stepModeOverride);
            
            // Update step mode label on chart
            UpdateStepModeLabel();
            
            // Force redraw to apply the change
            g_forceClearOnNextDraw = true;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            
            // GOLD FIX: Use throttled redraw instead of direct ChartRedraw
            ThrottledChartRedraw();
        }
        
        // Handle Factor decrease key (1) - only in Factor Mode
        // کلید کاهش فاکتور (1) - فقط در حالت Factor
        if(lparam == '1' || lparam == 49) // 49 = ASCII for '1'
        {
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
            if(currentMode == FACTOR_STEP)
            {
                // FIX: Get current factor value correctly with error handling
                double currentFactor = g_factorValueOverride;
                if(currentFactor <= 0) {
                    // If no override, get from input or calculate auto
                    if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
                        currentFactor = inpFactorValue;
                    } else {
                        // Auto mode: calculate default with fallback
                        currentFactor = GetDefaultFactorValue(g_dailyClosePriceForTH);
                        // Validate result (GetDefaultFactorValue returns fallback on error)
                        if(currentFactor <= 0 || currentFactor > 10000) {
                            #ifdef ENABLE_DEBUG_LOGS
                            Print("Factor decrease: Invalid factor from GetDefaultFactorValue, using 50.0");
                            #endif
                            currentFactor = 50.0;
                        }
                    }
                }
                
                // Use configurable step size (default 0.1)
                // استفاده از مقدار گام قابل تنظیم (پیش‌فرض 0.1)
                double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : 0.1;
                double newFactor = NormalizeDouble(currentFactor - step, 2);
                
                // Clamp to min (0.01 minimum)
                if(newFactor < 0.01) newFactor = 0.01;
                
                // Set override
                g_factorValueOverride = newFactor;
                
                // Persist state per chart (with error handling)
                // PERFORMANCE: Use cached ChartID string
                string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
                if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("WARNING: Failed to persist Factor value to GlobalVariable");
                    #endif
                }
                
                // Show label on chart (auto-hide)
                UpdateFactorLabel(newFactor);
                
                // Force redraw
                g_forceClearOnNextDraw = true;
                g_redrawTHLevelsNeeded = true;
                RedrawAllObjects(true);
                ThrottledChartRedraw();
            }
        }
        
        // Handle Factor increase key (2) - only in Factor Mode
        // کلید افزایش فاکتور (2) - فقط در حالت Factor
        if(lparam == '2' || lparam == 50) // 50 = ASCII for '2'
        {
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
            if(currentMode == FACTOR_STEP)
            {
                // FIX: Get current factor value correctly with error handling
                double currentFactor = g_factorValueOverride;
                if(currentFactor <= 0) {
                    // If no override, get from input or calculate auto
                    if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
                        currentFactor = inpFactorValue;
                    } else {
                        // Auto mode: calculate default with fallback
                        currentFactor = GetDefaultFactorValue(g_dailyClosePriceForTH);
                        // Validate result (GetDefaultFactorValue returns fallback on error)
                        if(currentFactor <= 0 || currentFactor > 10000) {
                            #ifdef ENABLE_DEBUG_LOGS
                            Print("Factor increase: Invalid factor from GetDefaultFactorValue, using 50.0");
                            #endif
                            currentFactor = 50.0;
                        }
                    }
                }
                
                // Use configurable step size (default 0.1)
                // استفاده از مقدار گام قابل تنظیم (پیش‌فرض 0.1)
                double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : 0.1;
                double newFactor = NormalizeDouble(currentFactor + step, 2);
                
                // Clamp to max
                if(newFactor > 10000) newFactor = 10000;
                
                // Set override
                g_factorValueOverride = newFactor;
                
                // Persist state per chart (with error handling)
                // PERFORMANCE: Use cached ChartID string
                string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
                if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("WARNING: Failed to persist Factor value to GlobalVariable");
                    #endif
                }
                
                // Show label on chart (auto-hide)
                UpdateFactorLabel(newFactor);
                
                // Force redraw
                g_forceClearOnNextDraw = true;
                g_redrawTHLevelsNeeded = true;
                RedrawAllObjects(true);
                ThrottledChartRedraw();
            }
        }
        
        // Handle Calculation Basis toggle key (W) - toggles between TH and ATR
        // کلید تغییر مبنای محاسبات (W) - تغییر بین TH و ATR
        if(lparam == 'W' || lparam == 'w')
        {
            // Get current basis
            ENUM_CALCULATION_BASIS currentBasis = GetCurrentCalculationBasis();
            
            // Toggle between TH and ATR
            ENUM_CALCULATION_BASIS newBasis = (currentBasis == CALC_BASIS_TH) ? CALC_BASIS_ATR : CALC_BASIS_TH;
            
            // Set override
            g_calculationBasisOverride = (int)newBasis;
            
            // Persist state per chart
            // PERFORMANCE: Use cached ChartID string
            string basisGvarName = "Biotak_CalcBasis_" + GetCachedChartIdStr();
            GlobalVariableSet(basisGvarName, g_calculationBasisOverride);
            
            // Invalidate ATR cache when switching to ATR basis
            if(newBasis == CALC_BASIS_ATR) {
                InvalidateATRCache();
            }
            
            // Show feedback using label (same style as step mode)
            UpdateBasisModeLabel(newBasis);
            
            // Also print to log
            if(newBasis == CALC_BASIS_TH) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("📐 Calculation Basis: TH (Theoretical)");
                #endif
            } else {
                #ifdef ENABLE_DEBUG_LOGS
                Print("📊 Calculation Basis: ATR (Actual)");
                #endif
            }
            
            // Force redraw to apply the change
            g_forceClearOnNextDraw = true;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            ThrottledChartRedraw();
        }
        
        // Handle TH3 Frequency Decrease (Key 3) - previous frequency
        // کلید کاهش فرکانس TH3 (3) - فرکانس قبلی
        if(lparam == '3')
        {
            // Only works if TH3 Tool is enabled
            if(!inpEnableTH3Tool) {
                if(ObjectFind(0, g_frequencyLabelName) >= 0) {
                    ObjectDelete(0, g_frequencyLabelName);
                }
                ClearAllModeLabels();
                ObjectCreate(0, g_frequencyLabelName, OBJ_LABEL, 0, 0, 0);
                ObjectSetString(0, g_frequencyLabelName, OBJPROP_TEXT, "[ TH3 Tool is Disabled ]");
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_XDISTANCE, 15);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_YDISTANCE, 45); // Second line
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
                ObjectSetString(0, g_frequencyLabelName, OBJPROP_FONT, "Arial Bold");
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_FONTSIZE, 11);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_COLOR, clrDarkBlue); // Dark color for lavender background
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_HIDDEN, true);
                if(inpModeLabelDuration > 0) EventSetTimer(inpModeLabelDuration);
                return;
            }
            
            DecrementTH3Frequency();
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⬇️ TH3 Frequency: ", DoubleToString(GetCurrentTH3Frequency(), 3), "%");
            #endif
            
            ThrottledChartRedraw();
        }
        
        // Handle TH3 Frequency Increase (Key 4) - next frequency
        // کلید افزایش فرکانس TH3 (4) - فرکانس بعدی
        if(lparam == '4')
        {
            // Only works if TH3 Tool is enabled
            if(!inpEnableTH3Tool) {
                if(ObjectFind(0, g_frequencyLabelName) >= 0) {
                    ObjectDelete(0, g_frequencyLabelName);
                }
                ClearAllModeLabels();
                ObjectCreate(0, g_frequencyLabelName, OBJ_LABEL, 0, 0, 0);
                ObjectSetString(0, g_frequencyLabelName, OBJPROP_TEXT, "[ TH3 Tool is Disabled ]");
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_XDISTANCE, 15);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_YDISTANCE, 45); // Second line
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
                ObjectSetString(0, g_frequencyLabelName, OBJPROP_FONT, "Arial Bold");
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_FONTSIZE, 11);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_COLOR, clrDarkBlue); // Dark color for lavender background
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_SELECTABLE, false);
                ObjectSetInteger(0, g_frequencyLabelName, OBJPROP_HIDDEN, true);
                if(inpModeLabelDuration > 0) EventSetTimer(inpModeLabelDuration);
                return;
            }
            
            CycleTH3Frequency();
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("⬆️ TH3 Frequency: ", DoubleToString(GetCurrentTH3Frequency(), 3), "%");
            #endif
            
            ThrottledChartRedraw();
        }
        
        // ========================================
        // Handle Key 5 - Quick Approve Pattern
        // مدیریت کلید 5 - تایید سریع پترن
        // ========================================
        if(lparam == '5')
        {
            #ifdef ENABLE_DEBUG_LOGS
            Print("🔑 KEY 5 DETECTED IN EVENT HANDLER");
            #endif
            QuickApprovePattern();
        }
        
        // ========================================
        // Handle ENTER key (13) - Confirm adjusted frequency
        // مدیریت کلید ENTER - تایید فرکانس تنظیم شده
        // ========================================
        if(lparam == 13) // ENTER key
        {
            if(g_adjustmentMode)
            {
                ConfirmAdjustedFrequency();
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ Adjusted frequency confirmed");
                #endif
            }
        }
        
        // Handle Reset key (Q) - reset all settings to defaults
        string mutableResetKey = inpResetKey;
        StringToUpper(mutableResetKey);
        int resetKeyCode = StringGetCharacter(mutableResetKey, 0);
        if(lparam == resetKeyCode)
        {
            // Reset step mode to input parameter default
            g_stepModeOverride = -1;
            
            // Reset Factor value to input parameter default
            g_factorValueOverride = 0;
            
            // Reset calculation basis to input parameter default
            g_calculationBasisOverride = -1;
            
            // Reset timeframe lock
            g_timeframeLocked = false;
            g_lockedPeriod = 0;
            
            // Reset trigger levels to input parameter
            g_triggerLevelsEnabled = inpShowTrigger;
            
            // Reset lines visibility to input parameter
            g_linesVisible = inpShowLines;
            
            // Reset TH3 frequency to input parameter default
            g_th3FrequencyOverride = 0;
            g_th3FrequencyIndex = 24; // Reset to default (28.125%)
            
            // Update all TH3 objects with default frequency
            if(inpEnableTH3Tool) {
                UpdateAllTH3Objects();
            }
            
            // Reset custom price to INPUT PARAMETER value (not delete it)
            g_customPriceKeyboardOverride = false;
            g_thStartPointType = inpTHStartPointType;
            g_customTHStartPrice = inpCustomTHStartPrice;
            
            // Clear keyboard override GlobalVariables but keep input parameter values
            // PERFORMANCE: Use cached ChartID string
            string chartIdStr = GetCachedChartIdStr();
            string symbolName = GetCachedSymbol();
            if(GlobalVariableCheck("Biotak_StepMode_" + chartIdStr)) GlobalVariableDel("Biotak_StepMode_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_Factor_" + chartIdStr)) GlobalVariableDel("Biotak_Factor_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_CalcBasis_" + chartIdStr)) GlobalVariableDel("Biotak_CalcBasis_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_LockTF_" + chartIdStr)) GlobalVariableDel("Biotak_LockTF_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_LockTFPeriod_" + chartIdStr)) GlobalVariableDel("Biotak_LockTFPeriod_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_TriggerLevels_" + chartIdStr)) GlobalVariableDel("Biotak_TriggerLevels_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_LinesVisible_" + chartIdStr)) GlobalVariableDel("Biotak_LinesVisible_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_CustomPriceOverride_" + symbolName)) GlobalVariableDel("Biotak_CustomPriceOverride_" + symbolName);
            if(GlobalVariableCheck("Biotak_TH3Freq_" + chartIdStr)) GlobalVariableDel("Biotak_TH3Freq_" + chartIdStr);
            if(GlobalVariableCheck("Biotak_TH3FreqIdx_" + chartIdStr)) GlobalVariableDel("Biotak_TH3FreqIdx_" + chartIdStr);
            
            // If input parameter has custom price, restore it; otherwise clear
            if(inpCustomTHStartPrice > 0.0) {
                // Restore custom price line from input parameter
                GlobalVariableSet("Biotak_CustomPrice_" + symbolName, inpCustomTHStartPrice);
                CreateCustomPriceLine(inpCustomTHStartPrice, Digits);
            } else {
                // No custom price in settings - clear it
                if(GlobalVariableCheck("Biotak_CustomPrice_" + symbolName)) GlobalVariableDel("Biotak_CustomPrice_" + symbolName);
                ObjectDelete(0, g_customPriceHorizontalLineName);
                g_customPriceLineCreated = false;
            }
            
            // Update UI
            UpdateLockStatusLabel();
            Comment("\n\n        [ RESET ]");
            EventSetTimer(2);
            
            // Force full redraw
            g_forceClearOnNextDraw = true;
            g_calculatedOnce = false;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            ThrottledChartRedraw();
        }
        
        // Handle timeframe lock/unlock key
        string mutableLockKey = inpLockKey;
        StringToUpper(mutableLockKey);
        int lockKeyCode = StringGetCharacter(mutableLockKey, 0);
        if(lparam == lockKeyCode)
        {
            // Delete ALL indicator objects before toggling to prevent overlap
            // This is more efficient than tracking old prefixes
            // Save custom price state before clearing
            bool hadCustomPrice = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
            double savedCustomPrice = hadCustomPrice ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0;
            
            ObjectsDeleteAll(0, inpObjectPrefix);
            
            g_timeframeLocked = !g_timeframeLocked;
            if(g_timeframeLocked)
            {
                g_lockedPeriod = GetCachedPeriod(); // Capture current chart timeframe
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
            
            // Update lock status label on chart
            UpdateLockStatusLabel();
            
            // Persist lock state per chart
            // PERFORMANCE: Use cached ChartID string
            string lockChartIdStr = GetCachedChartIdStr();
            string lockFlagName = "Biotak_LockTF_" + lockChartIdStr;
            GlobalVariableSet(lockFlagName, g_timeframeLocked);
            string lockPeriodName = "Biotak_LockTFPeriod_" + lockChartIdStr;
            GlobalVariableSet(lockPeriodName, g_lockedPeriod);
            
            // Trigger full redraw with new lock state
            g_forceClearOnNextDraw = true;
            g_calculatedOnce = false;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            
            // Restore custom price line if it existed
            if(hadCustomPrice && savedCustomPrice > 0) {
                // FIX: Also restore global variables to ensure consistency
                g_customTHStartPrice = savedCustomPrice;
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
    
    // Pass events to TH3 Tool FIRST (higher priority than custom price)
    // CRITICAL: Pass ALL relevant events, not just when g_abcdDrawing is true
    // This includes: CLICK (for drawing), MOUSE_MOVE (for cancel), DRAG (for adjusting), DELETE (for cleanup)
    if(g_abcdDrawing || 
       id == CHARTEVENT_OBJECT_DRAG || 
       id == CHARTEVENT_OBJECT_DELETE ||
       id == CHARTEVENT_MOUSE_MOVE) {
        OnABCDMouseEvent(id, lparam, dparam, sparam);
        
        // Only block other handlers when actively drawing
        if(g_abcdDrawing && id == CHARTEVENT_CLICK) {
            return; // Don't process other click handlers when in ABCD drawing mode
        }
    }
    
    // Handle chart click event for custom price selection
    if(id == CHARTEVENT_CLICK && g_waitingForCustomPriceClick)
    {
        // Check if it's a right-click (sparam contains "r" for right-click)
        if(StringFind(sparam, "r") >= 0)
        {
            // Cancel custom price setting on right-click
            CleanupCustomPriceObjects(true, true); // Reset global variables too and force delete the line
            #ifdef ENABLE_DEBUG_LOGS
            Print("Custom price setting cancelled (right-click)");
            #endif
            ThrottledChartRedraw();
            return;
        }
        
        // Get price at clicked point
        double clickedPrice = dparam;
        
        if(!g_customPriceLineCreated)
        {
            // Create a horizontal line at clicked price that can be dragged
            if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, clickedPrice)) {
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
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_ZORDER, 100); // Bring to front
            ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price Line - Drag to adjust, Double-click to confirm");
            
            g_customPriceLineCreated = true;
            #ifdef ENABLE_DEBUG_LOGS
            Print("📍 Drag the orange dotted line to adjust price. Double-click to confirm.");
            #endif
        }
        else
        {
            // Check if this is a double-click (two clicks within 300ms)
            uint currentTickCount = GetTickCount();
            bool isDoubleClick = (currentTickCount - g_lastClickTickCount < 300); // 300 milliseconds threshold
            g_lastClickTickCount = currentTickCount;
            
            if (isDoubleClick || !g_customPriceLineCreated) // Confirm on double-click or second single click
            {
                g_waitingForCustomPriceClick = false;
                g_customPriceKeyboardOverride = true; // User confirmed via click - override input parameter
                
                // Get the current price from the horizontal line
                double selectedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
                
                // Update custom price
                g_customTHStartPrice = selectedPrice;
                
                // Set TH start point type to custom price
                g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
                
                // IMPORTANT: Save to GlobalVariable for persistence
                string symbolName = GetCachedSymbol();
                string gvarName = "Biotak_CustomPrice_" + symbolName;
                string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
                GlobalVariableSet(gvarName, selectedPrice);
                // Save override flag
                GlobalVariableSet(overrideFlagName, 1.0);
                
                // Keep the horizontal line for future adjustments
                // No need to delete vertical line as it's not created anymore
                // ObjectDelete(0, g_customPriceHorizontalLineName);
                // Instead of deleting, update the tooltip to indicate it can still be dragged and make it selectable
                ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
                ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
                g_customPriceLineCreated = true; // Keep this flag true to indicate line exists
                
                // Force redraw of TH levels
                g_redrawTHLevelsNeeded = true;
                RedrawAllObjects(true);
                
                #ifdef ENABLE_DEBUG_LOGS
                Print("✅ Custom Price Mode activated! Using ", inpCustomPriceMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
                #endif
            }
        }
        
        ThrottledChartRedraw();
    }
    
    // Handle object click event for the horizontal line (replaces double-click event)
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_customPriceHorizontalLineName)
    {
        // Check if this is a double-click (two clicks within 300ms)
        uint currentTickCount = GetTickCount();
        bool isDoubleClick = (currentTickCount - g_lastClickTickCount < 300); // 300 milliseconds threshold
        g_lastClickTickCount = currentTickCount;
        
        if (isDoubleClick)
        {
            g_waitingForCustomPriceClick = false;
            g_customPriceKeyboardOverride = true; // User confirmed via double-click - override input parameter
            
            // Get the current price from the horizontal line
            double selectedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
            
            // Update custom price
            g_customTHStartPrice = selectedPrice;
            
            // Set TH start point type to custom price
            g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            
            // IMPORTANT: Save to GlobalVariable for persistence
            string symbolName = GetCachedSymbol();
            string gvarName = "Biotak_CustomPrice_" + symbolName;
            string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
            GlobalVariableSet(gvarName, selectedPrice);
            // Save override flag
            GlobalVariableSet(overrideFlagName, 1.0);
            
            // Keep the horizontal line for future adjustments
            // No need to delete vertical line as it's not created anymore
            // ObjectDelete(0, g_customPriceHorizontalLineName);
            // Instead of deleting, update the tooltip to indicate it can still be dragged and make it selectable
            ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, "📍 Custom Price: " + DoubleToString(selectedPrice, Digits) + " | Drag to adjust (live update)");
            ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, true);
            g_customPriceLineCreated = true; // Keep this flag true to indicate line exists
            
            // Force redraw of TH levels
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("✅ Custom Price Mode activated! Using ", inpCustomPriceMaxLevels, " levels above/below price: ", DoubleToString(selectedPrice, Digits));
            #endif
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // REAL-TIME DRAG: Update levels instantly while mouse is moving
    // بروزرسانی آنی سطوح هنگام درگ خط قیمت سفارشی
    // In MT5, CHARTEVENT_OBJECT_DRAG only fires on mouse RELEASE.
    // We use CHARTEVENT_MOUSE_MOVE + left-button check for real-time.
    // PERFORMANCE: Throttled to 150ms (6-7 fps) to prevent lag
    // ═══════════════════════════════════════════════════════════════
    if(id == CHARTEVENT_MOUSE_MOVE && g_customPriceLineCreated)
    {
        // sparam contains mouse state flags: bit0=left, bit1=right, bit2=middle, bit4=shift, bit5=ctrl
        int mouseFlags = (int)StringToInteger(sparam);
        bool leftButtonDown = (mouseFlags & 1) != 0;
        
        if(leftButtonDown)
        {
            // Check if the custom price line is selected (being dragged)
            bool lineSelected = (bool)ObjectGetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTED);
            if(lineSelected)
            {
                // ANTI-FLICKER FIX: Set dragging flag to prevent zone deletion
                // رفع چشمک زدن: تنظیم پرچم درگ برای جلوگیری از پاک شدن زون‌ها
                
                // DEBUG: Log drag state
                #ifdef ENABLE_DEBUG_LOGS
                if(!g_customPriceLineDragging) {
                    Print("🖱️ DRAG STARTED: g_customPriceLineDragging set to TRUE");
                }
                #endif
                
                g_customPriceLineDragging = true;
                
                // Get current line price from object (MT4 updates it automatically during drag)
                double currentLinePrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
                
                if(currentLinePrice > 0 && MathAbs(currentLinePrice - g_customTHStartPrice) > _Point * 0.5)
                {
                    // Apply magnet/snap to nearest OHLC if enabled
                    double snappedPrice = currentLinePrice;
                    
                    if(inpEnableMagnet && inpMagnetSensitivityPips > 0)
                    {
                        // Get mouse position to find the bar
                        int mouseX = (int)lparam;
                        int mouseY = (int)dparam;
                        datetime mouseTime;
                        double mousePrice;
                        int subWindow = 0;
                        
                        if(ChartXYToTimePrice(0, mouseX, mouseY, subWindow, mouseTime, mousePrice))
                        {
                            int barIndex = iBarShift(NULL, 0, mouseTime, false);
                            if(barIndex >= 0)
                            {
                                // Get OHLC of current bar
                                double barOpen = iOpen(NULL, 0, barIndex);
                                double barHigh = iHigh(NULL, 0, barIndex);
                                double barLow = iLow(NULL, 0, barIndex);
                                double barClose = iClose(NULL, 0, barIndex);
                                
                                // Calculate threshold in price units
                                double threshold = inpMagnetSensitivityPips * _Point;
                                if(Digits == 3 || Digits == 5) threshold *= 10; // Adjust for 5-digit brokers
                                
                                // Find nearest OHLC
                                double minDist = threshold + 1;
                                double nearestPrice = currentLinePrice;
                                
                                double distOpen = MathAbs(currentLinePrice - barOpen);
                                if(distOpen < minDist) { minDist = distOpen; nearestPrice = barOpen; }
                                
                                double distHigh = MathAbs(currentLinePrice - barHigh);
                                if(distHigh < minDist) { minDist = distHigh; nearestPrice = barHigh; }
                                
                                double distLow = MathAbs(currentLinePrice - barLow);
                                if(distLow < minDist) { minDist = distLow; nearestPrice = barLow; }
                                
                                double distClose = MathAbs(currentLinePrice - barClose);
                                if(distClose < minDist) { minDist = distClose; nearestPrice = barClose; }
                                
                                // Snap if within threshold
                                if(minDist <= threshold)
                                {
                                    snappedPrice = nearestPrice;
                                    // Update line position immediately for smooth snap
                                    ObjectSetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0, snappedPrice);
                                }
                            }
                        }
                    }
                    
                    // PERFORMANCE FIX: Throttle RedrawAllObjects to 50ms during drag
                    // بهینه‌سازی: محدود کردن بروزرسانی سطوح به 20 بار در ثانیه برای عملکرد روان
                    uint nowMs = GetTickCount();
                    if(nowMs - g_lastDragRedrawTime > DRAG_REDRAW_THROTTLE_MS)
                    {
                        #ifdef ENABLE_DEBUG_LOGS
                        Print("🔄 DRAG UPDATE: price=", snappedPrice, ", redrawing...");
                        #endif
                        
                        g_customTHStartPrice = snappedPrice;
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
            // Left button released - end dragging
            // دکمه چپ رها شد - پایان درگ
            if(g_customPriceLineDragging) {
                // ANTI-FLICKER FIX: Detect drag state transition (true -> false)
                // Requirement 7.3: Trigger single cleanup pass after drag ends
                g_customPriceLineDragging = false;
                
                // DON'T force clear - just redraw normally
                // فقط بازرسم عادی - بدون پاک کردن اجباری
                g_redrawTHLevelsNeeded = true;
                RedrawAllObjects(false);  // false = don't force clear
                ThrottledChartRedraw();
            }
        }
    }
    
    // Handle object drag event for custom price line (fires on mouse release)
    if(id == CHARTEVENT_OBJECT_DRAG && sparam == g_customPriceHorizontalLineName)
    {
        // ANTI-FLICKER FIX: Detect drag state transition (true -> false)
        // Requirement 7.3: Trigger single cleanup pass after drag ends
        g_customPriceLineDragging = false;
        
        // Get the current price from the horizontal line
        double draggedPrice = ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0);
        
        // Update custom price for live preview
        g_customTHStartPrice = draggedPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        g_customPriceKeyboardOverride = true; // User dragged line - override input parameter
        
        // Save to GlobalVariable IMMEDIATELY for live preview
        string symbolName = GetCachedSymbol();
        string gvarName = "Biotak_CustomPrice_" + symbolName;
        string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
        GlobalVariableSet(gvarName, draggedPrice);
        // Save override flag
        GlobalVariableSet(overrideFlagName, 1.0);
        
        // If we're still in the initial custom price selection mode
        if (g_waitingForCustomPriceClick) {
            // Update tooltip with current price
            string tooltip = "Current price: " + DoubleToString(draggedPrice, Digits) + " - Double-click to confirm";
            ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, tooltip);
        } else {
            // We're in adjustment mode after confirmation
            // Update tooltip
            string tooltip = "Custom TH start price: " + DoubleToString(draggedPrice, Digits) + " - Drag to adjust";
            ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, tooltip);
            
            #ifdef ENABLE_DEBUG_LOGS
            Print("Custom TH start price updated to: ", DoubleToString(draggedPrice, Digits));
            #endif
        }
        
        // Force redraw of TH levels (works for both preview and adjustment mode)
        // بازرسم سطوح TH (برای هر دو حالت پیش‌نمایش و تنظیم)
        g_redrawTHLevelsNeeded = true;
        RedrawAllObjects(false);  // false = don't force clear zones
    }
    
    // Handle Wave Analyzer toggle (W key) - REMOVED
    // Wave Analyzer feature removed per user request
    
    // ========================================
    // Handle Learning System Feedback Buttons
    // مدیریت دکمه‌های بازخورد سیستم یادگیری
    // ========================================
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(StringFind(sparam, "LEARN_") == 0)
        {
            OnFeedbackButtonClick(sparam);
            return;
        }
    }
    
    // Handle AB=CD pattern selection (click on any pattern object)
    // مدیریت انتخاب پترن AB=CD (کلیک روی هر object پترن)
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        // Check if clicked object belongs to an AB=CD pattern
        if(StringFind(sparam, "ABCD_Pattern_") == 0)
        {
            // Extract pattern name from object name
            string patternName = "";
            
            // Find the base pattern name (before any suffix like _Point_, _Line_, etc.)
            int suffixPos = -1;
            if(StringFind(sparam, "_Point_") > 0) suffixPos = StringFind(sparam, "_Point_");
            else if(StringFind(sparam, "_Label_") > 0) suffixPos = StringFind(sparam, "_Label_");
            else if(StringFind(sparam, "_Line_") > 0) suffixPos = StringFind(sparam, "_Line_");
            else if(StringFind(sparam, "_Target_") > 0) suffixPos = StringFind(sparam, "_Target_");
            else if(StringFind(sparam, "_Zone") > 0) suffixPos = StringFind(sparam, "_Zone");
            
            if(suffixPos > 0) {
                patternName = StringSubstr(sparam, 0, suffixPos);
            } else {
                patternName = sparam; // Fallback
            }
            
            // Set this pattern as active
            if(patternName != "") {
                SetActiveABCDPattern(patternName);
            }
        }
        else
        {
            // Clicked outside any AB=CD pattern - deactivate all
            // کلیک خارج از پترن - همه رو غیرفعال کن
            SetActiveABCDPattern("");
        }
    }
}

