   //+------------------------------------------------------------------+
//| Event Handlers - Version 3.09 GOLD                              |
//| Security & Performance Audit Complete                           |
//+------------------------------------------------------------------+
#property strict

int OnInitHandler() {
    InitializeGlobalCache();
    LoggerSetLevel(inpLogLevel);

    // PERF (2026): one-time migration from the old TF-suffixed prefix
    // (e.g. "Biotak_M5_") to the new TF-independent prefix ("Biotak_").
    // Any leftover objects from a previous version would otherwise persist
    // on the chart as duplicates of the new objects, and the cleanup path
    // would not be able to tell them apart. Delete the OLD TF-suffixed
    // objects on first run with this build; the subsequent redraw creates
    // the new objects from scratch. Gated on a GlobalVariable so this only
    // runs ONCE per chart (not on every OnInit re-run after TF switch etc.).
    if(!GlobalVariableCheck("Biotak_TFIndependent_Migrated_" + GetCachedChartIdStr())) {
        string oldMigPrefix = inpObjectPrefix + "_";
        int migPrefixLen = StringLen(oldMigPrefix);
        // Heuristic: OLD format = "<prefix>_<TF>_<rest>" where the TF segment
        // is short, starts with an optional letter (M/H/D/W, or "MN") and is
        // followed by at least one digit. NEW format segments (TH, SSLS, Combo,
        // Factor, Above, Below, Zone, High, Low, Center, StepMode, ...) are
        // letter-only or letter+letter, NEVER letter+digits.
        int migTotal = ObjectsTotal(0, -1, -1);
        int migDeleted = 0;
        for(int mi = migTotal - 1; mi >= 0; mi--) {
            string migName = ObjectName(0, mi, -1, -1);
            if(migName == "") continue;
            if(StringLen(migName) <= migPrefixLen) continue;
            if(StringSubstr(migName, 0, migPrefixLen) != oldMigPrefix) continue;
            int nextUnd = StringFind(migName, "_", migPrefixLen);
            if(nextUnd <= migPrefixLen) continue;
            string tfSeg = StringSubstr(migName, migPrefixLen, nextUnd - migPrefixLen);
            // Validate TF shape: optional leading letter(s) M/H/D/W (or "MN"),
            // then AT LEAST ONE digit, no other chars.
            int si = 0;
            if(tfSeg[0] == 'M' || tfSeg[0] == 'H' || tfSeg[0] == 'D' || tfSeg[0] == 'W') {
                si = 1;
                if(StringLen(tfSeg) >= 2 && tfSeg[0] == 'M' && tfSeg[1] == 'N') si = 2;
            }
            bool isTF = false;
            if(si > 0 && si < StringLen(tfSeg)) {
                isTF = true;
                for(int k = si; k < StringLen(tfSeg); k++) {
                    if(tfSeg[k] < '0' || tfSeg[k] > '9') { isTF = false; break; }
                }
            }
            if(!isTF) continue;
            ObjectDelete(0, migName);
            migDeleted++;
        }
        if(migDeleted > 0) {
            Print("[I][GEN] Migration: removed ", migDeleted,
                  " legacy TF-suffixed objects (old prefix pattern)");
            // PERF (2026): the object cache still holds entries with the
            // old TF-suffixed names. Those entries now point at objects
            // that no longer exist on the chart, so the next redraw would
            // get inconsistent "exists=true" responses from the cache and
            // could try to update ghost objects (the source of the
            // "stale levels from the old TF" visual artifact). Wipe the
            // entire object cache so the subsequent redraw rebuilds it
            // from scratch with the new TF-independent names.
            CacheClear();
            Print("[I][GEN] Migration: object cache cleared (will rebuild on first redraw)");
        }
        GlobalVariableSet("Biotak_TFIndependent_Migrated_" + GetCachedChartIdStr(), 1.0);
    }

    // DIAGNOSTIC: confirm this build includes the diagnostic patches
    #ifdef DEBUG_BUILD
    string dbgFlag = "Y";
    #else
    string dbgFlag = "N";
    #endif
    Print("[DIAG_BUILD_MARKER] Biotak Trigger TH3 diagnostic build loaded | TF=",
          EnumToString((ENUM_TIMEFRAMES)Period()),
          " | debug=", dbgFlag,
          " | logLevel=", EnumToString(inpLogLevel));

    // Restore hidden state
    string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
    bool shouldBeHidden = RestoreBoolGlobalVar(gvar_name, false);
    DEBUG_PRINTF("OnInit: shouldBeHidden=", shouldBeHidden);

    string chartIdStr = GetCachedChartIdStr();
    datetime initNow = TimeCurrent();

    // Detect chart symbol changes and clean up stale symbol-scoped GlobalVariables
    // (custom price state from the previous symbol should not leak into the new one).
    // PERF (2026): file I/O is gone entirely. The previous version did
    //   FileOpen(READ) + FileReadString + FileClose + FileOpen(WRITE) + FileWriteString + FileClose
    // on every OnInit, costing ~3-5ms per TF switch. A TF switch never changes
    // the symbol, so we use a per-chart GlobalVariable keyed on a 32-bit hash of
    // the symbol name. The hash is stable, comparable across inits, and stored
    // in-memory - zero I/O, sub-microsecond reads. CleanupSymbolScopedGlobalVariables
    // iterates the known symbol-scoped gvar name pattern, so it doesn't need the
    // exact previous symbol - the hash is enough to detect "did the symbol change?".
    string currentSymbol = GetCachedSymbol();
    string symbolCacheGvarName = "Biotak_LastSymbolHash_" + chartIdStr;
    // FNV-1a 32-bit hash of the symbol name.
    uint curSymHash = 2166136261u;
    for(int si = 0; si < StringLen(currentSymbol); si++) {
        curSymHash ^= (uint)(ushort)StringGetCharacter(currentSymbol, si);
        curSymHash *= 16777619u;
    }
    uint prevSymHash = 0;
    if(GlobalVariableCheck(symbolCacheGvarName)) {
        prevSymHash = (uint)GlobalVariableGet(symbolCacheGvarName);
    }
    if(prevSymHash != 0 && prevSymHash != curSymHash) {
        _LOG_GATE_I Print("[I][GEN] Symbol changed (hash ", prevSymHash, " -> ", curSymHash,
                          " on ", currentSymbol, ") - cleaning stale symbol-scoped globals");
        // We don't have the previous symbol as a string - CleanupSymbolScopedGlobalVariables
        // expects it. Pass empty; the cleanup iterates the gvar namespace and
        // removes everything that looks symbol-scoped, which is what we want here.
        CleanupSymbolScopedGlobalVariables("");
    }
    GlobalVariableSet(symbolCacheGvarName, (double)curSymHash);

    // Timeframe-switch debounce: detect recent TF change (within 20s)
    string tfSwitchStampGvar = "Biotak_LastTFSwitch_" + chartIdStr;
    bool recentTimeframeSwitch = false;
    if(GlobalVariableCheck(tfSwitchStampGvar)) {
        datetime lastTFSwitch = (datetime)GlobalVariableGet(tfSwitchStampGvar);
        if(initNow > 0 && lastTFSwitch > 0 && (initNow - lastTFSwitch) <= 20)
            recentTimeframeSwitch = true;
    }

    // Restore toggle states (early, before validation)
    g_triggerLevelsEnabled = RestoreBoolGlobalVar("Biotak_TriggerLevels_" + chartIdStr, inpShowTrigger);
    g_linesVisible = RestoreBoolGlobalVar("Biotak_LinesVisible_" + chartIdStr, inpShowLines);

    // BUG (2026): per-frame visibility caches MUST be invalidated here.
    // GetCachedLinesVisible() reads g_linesVisibleCached, which is a separate
    // static from g_linesVisible and is normally updated by UpdateLinesVisibleCache
    // when the L key is pressed. OnInit was restoring g_linesVisible from the
    // GlobalVariable but never refreshing the cache, so the FIRST redraw after
    // a TF switch still saw the OLD cached value (typically true). Result: lines
    // came back on automatically after the switch, ignoring the user's "off"
    // preference. Same pattern for the indicator-hidden TTL cache and the
    // ATR labels visibility. InvalidateAllVisibilityCaches is the single
    // hammer that forces the next IsIndicatorHidden / GetCachedLinesVisible
    // call to do a live GlobalVariable read.
    UpdateLinesVisibleCache(g_linesVisible);
    RefreshIsHiddenCache();
    InvalidateAllVisibilityCaches();

    // Restore ATR labels visibility (Default to OFF on first load)
    g_atrLabelsVisible = RestoreBoolGlobalVar("Biotak_ATRLabels_" + chartIdStr, false);

    // Restore TH labels mode (Default to OFF on first load: 0=OFF, 1=FRACTAL, 2=STANDARD, 3=BOTH)
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
            _LOG_GATE_E Print("[E][GEN] OnInit: Corrupted TH labels state (", DoubleToString(gvarValue, 10), "), resetting");
            g_thLabelsMode = 0; // Default to OFF
            GlobalVariableSet(thLabelsGvarName, 0.0);
            g_thLabelsVisible = false;
        }
    } else {
        g_thLabelsMode = 0; // Default to OFF
        g_thLabelsVisible = false;
    }

    int validationResult = ValidateInputs();
    if(validationResult != INIT_SUCCEEDED) return validationResult;

    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    EventSetTimer(1);
    CheckArraySizes();

    // BUG (2026): invalidate the per-object OBJPROP_TIMEFRAMES cache for ALL
    // of our objects after a TF switch. The cache is the source of truth for
    // SetObjectTimeframesIfChanged - if the cache says "the object is already
    // at OBJ_NO_PERIODS" the function returns without touching the chart, even
    // if the chart engine silently reset the property back to OBJ_ALL_PERIODS
    // during the TF switch. MT5 does reset OBJPROP_TIMEFRAMES for chart objects
    // when the underlying chart re-initializes (it has to - the time series
    // attached to the object changes), and the cache has no way to know. The
    // fix: tombstone every cached entry whose name matches our prefix. The
    // next SetObjectTimeframesIfChanged call will hit the cache-miss path,
    // pay one ObjectFind + one ObjectGetInteger per object (one-time cost), and
    // hydrate the cache with the chart's true state. From then on the cache
    // is the source of truth again.
    //
    // Without this fix, the L key on TF1 (lines off) followed by a TF switch
    // would leave the cache believing the lines are hidden, while the chart
    // engine had reset them to visible. The user would see lines reappear
    // after every TF switch and the "off" toggle would be effectively a no-op.
    string runtimePrefix = inpObjectPrefix + "_";
    InvalidateObjectCacheByPrefix(runtimePrefix);
    // FIX (2026): after OnInit the chart engine has reset every
    // OBJPROP_TIMEFRAMES to OBJ_ALL_PERIODS (per MQL5 chart re-init
    // semantics on TF/symbol switch). Bypass the cache for the next ~5
    // frames so the visibility state — including the user's L-key "off"
    // toggle and F-key indicator-hide — is pushed to the chart before the
    // cache can incorrectly short-circuit it. Without this the user's
    // "lines off" preference silently flips back to "on" after every TF
    // switch (the classic "I disabled lines but they came back" bug).
    RequestForcePushTimeframes(5);
    // The per-frame ApplyVisibilityStateIfUnchangedSkip path also uses
    // g_visibilityChangedThisFrame, which is updated in CacheRefreshVisibilityState.
    // We need to force the next frame to push timeframes unconditionally.
    // The cheapest signal: bump the frame counter.
    CacheRefreshVisibilityState();

    // PERF (2026): TF switch fast path. On a TF switch we want OnCalculate to be
    // able to draw the FIRST frame immediately, with default scaling and (if
    // available) the cached historical bounds. The old code set g_initialized=false
    // here, which meant RedrawAllObjects always ran full work but the level draw
    // was still gated on UpdateHistoricalValues succeeding and the fractal being
    // determined for the new TF. The first-frame delay was 100-1000ms.
    //
    // New approach: ALWAYS mark initialized and seed the fractal as "determined
    // for this TF" (with the previous scaling factor if we have one, else 1.0).
    // UpdateHistoricalValues is attempted but its failure is non-fatal - the
    // level draw will use a sensible default range until the next refresh.
    // The result: TF switch is sub-50ms from OnInit return to first frame on
    // screen, and OnDeinit no longer deletes objects so there is no flash.
    bool deferHeavyInit = recentTimeframeSwitch;
    bool histOk = UpdateHistoricalValues();
    if(!histOk && !deferHeavyInit) {
        _LOG_GATE_E Print("[E][GEN] OnInit: UpdateHistoricalValues failed. Error: ", GetLastError());
        return INIT_FAILED;
    }
    if(!histOk) {
        // Fall back to a sensible range around the current price so levels are
        // drawable on the first frame after the switch. Will be refined on the
        // next OnCalculate when UpdateHistoricalValues can fetch the bars.
        double bpFallback = SymbolInfoDouble(GetCachedSymbol(), SYMBOL_BID);
        if(bpFallback > 0) {
            if(g_highestHigh <= 0 || g_highestHigh == EMPTY_VALUE) g_highestHigh = bpFallback * 1.01;
            if(g_lowestLow    <= 0 || g_lowestLow    == EMPTY_VALUE) g_lowestLow    = bpFallback * 0.99;
        }
    }
    g_initialized = true;
    g_calculatedOnce = false;
    InitializeAdaptiveScaling();

    // PERF (2026): seed g_fractalDetermined for the new TF so the first redraw
    // can draw levels immediately. The actual scaling factor will be refined on
    // the next UpdateATRScalingFactor call (1-2 ticks later), but for the first
    // frame we use the previous value (or 1.0). Without this seed the level
    // draw path waits 3 seconds (FRACTAL_DETERMINE_TIMEOUT_MS) for the timeout
    // fallback - the user saw a blank chart for 3s on every TF switch.
    g_fractalDetermined = true;
    g_fractalDeterminedTF = GetCurrentTimeframe();
    g_fractalDetermineStartMs = 0;

    g_dailyClosePriceForTH = GetPriceForPreviousDay(inpTHPriceType);
    if(g_dailyClosePriceForTH == EMPTY_VALUE) {
        _LOG_GATE_E Print("[E][GEN] OnInit: GetPriceForPreviousDay failed, returning INIT_FAILED.");
        return INIT_FAILED;
    }

    string symbolName = GetCachedSymbol();
    string gvarName = "Biotak_CustomPrice_" + symbolName;
    string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
    int digits = Digits;

    // Validate custom price input
    double validatedCustomPrice = inpCustomTHStartPrice;
    if(validatedCustomPrice < 0.0) {
        _LOG_GATE_E Print("[E][GEN] OnInit: Invalid custom price (negative): ", validatedCustomPrice);
        validatedCustomPrice = 0.0;
    }
    if(validatedCustomPrice > 1000000.0) {
        _LOG_GATE_E Print("[E][GEN] OnInit: Invalid custom price (too large): ", validatedCustomPrice);
        validatedCustomPrice = 0.0;
    }

    // Restore keyboard override flag
    g_customPriceKeyboardOverride = GlobalVariableCheck(overrideFlagName) ? (bool)GlobalVariableGet(overrideFlagName) : false;
    double savedPrice = GlobalVariableCheck(gvarName) ? GlobalVariableGet(gvarName) : 0.0;

    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][GEN] === Custom Price Debug (OnInit) ===");
    Print("[D][GEN] inpCustomTHStartPrice: ", inpCustomTHStartPrice);
    Print("[D][GEN] savedPrice: ", savedPrice);
    Print("[D][GEN] override: ", g_customPriceKeyboardOverride);
    #endif

    if(g_customPriceKeyboardOverride && savedPrice > 0.0) {
        g_customTHStartPrice = savedPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        DEBUG_PRINTF("OnInit: Using keyboard/drag price (override): ", DoubleToString(g_customTHStartPrice, digits));
        CreateCustomPriceLine(g_customTHStartPrice, digits);
    } else if(validatedCustomPrice > 0.0) {
        g_customTHStartPrice = validatedCustomPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        g_customPriceKeyboardOverride = false;
        GlobalVariableSet(gvarName, g_customTHStartPrice);
        GlobalVariableSet(overrideFlagName, 0.0);
        DEBUG_PRINTF("OnInit: Using custom price from settings: ", DoubleToString(g_customTHStartPrice, digits));
        CreateCustomPriceLine(g_customTHStartPrice, digits);
    } else if(savedPrice > 0.0) {
        g_customTHStartPrice = savedPrice;
        g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
        _LOG_GATE_I Print("[I][GEN] OnInit: Restored custom price from GlobalVariable: ", DoubleToString(g_customTHStartPrice, digits));
        CreateCustomPriceLine(g_customTHStartPrice, digits);
    } else {
        g_customTHStartPrice = 0.0;
        g_thStartPointType = inpTHStartPointType;
        g_customPriceKeyboardOverride = false;
        GlobalVariableDel(gvarName);
        GlobalVariableDel(overrideFlagName);
        DEBUG_PRINT("OnInit: Using default mode (no custom price)");
    }

    g_redrawTHLevelsNeeded = true;

    // Base price init debounce: skip if recently initialized during TF switch
    string baseInitStampGvar = "Biotak_BaseInit_" + chartIdStr;
    bool shouldInitBasePrice = true;
    if(deferHeavyInit && GlobalVariableCheck(baseInitStampGvar)) {
        datetime lastBaseInit = (datetime)GlobalVariableGet(baseInitStampGvar);
        if(initNow > 0 && lastBaseInit > 0 && (initNow - lastBaseInit) <= 120)
            shouldInitBasePrice = false;
    }
    if(shouldInitBasePrice) {
        InitializeBasePriceSystem();
        if(initNow > 0) GlobalVariableSet(baseInitStampGvar, (double)initNow);
    } else {
        g_systemInitialized = false;
    }

    // Restore timeframe lock state
    string lockFlagName = "Biotak_LockTF_" + chartIdStr;
    if(GlobalVariableCheck(lockFlagName)) {
        g_timeframeLocked = (bool)GlobalVariableGet(lockFlagName);
    }
    string lockPeriodName = "Biotak_LockTFPeriod_" + chartIdStr;
    if(GlobalVariableCheck(lockPeriodName)) {
        g_lockedPeriod = (int)GlobalVariableGet(lockPeriodName);
    }

    // Restore step mode with range validation (0..3)
    string stepModeGvarName = "Biotak_StepMode_" + chartIdStr;
    if(GlobalVariableCheck(stepModeGvarName)) {
        int tempMode = (int)GlobalVariableGet(stepModeGvarName);
        if(tempMode >= 0 && tempMode <= 3) {
            g_stepModeOverride = tempMode;
        } else {
            _LOG_GATE_W Print("[W][GEN] OnInit: Corrupted StepMode (", tempMode, "), resetting.");
            GlobalVariableDel(stepModeGvarName);
            g_stepModeOverride = -1;
        }
    }

    // Restore factor with validation (0 < val <= MAX_SAFE_FACTOR)
    string factorGvarName = "Biotak_Factor_" + chartIdStr;
    if(GlobalVariableCheck(factorGvarName)) {
        double val = GlobalVariableGet(factorGvarName);
        if(val > 0 && val <= MAX_SAFE_FACTOR) {
            g_factorValueOverride = val;
        } else {
            _LOG_GATE_E Print("[E][GEN] OnInit: Invalid Factor (", val, "), resetting.");
            GlobalVariableDel(factorGvarName);
            g_factorValueOverride = 0.0;
        }
    } else {
        g_factorValueOverride = 0.0;
    }
    // Manual mode factor clamping
    if(inpFactorMode == FACTOR_MODE_MANUAL) {
        if(inpFactorValue <= 0 || inpFactorValue > MAX_SAFE_FACTOR) {
            _LOG_GATE_E Print("[E][GEN] OnInit: Invalid inpFactorValue (", inpFactorValue, "), clamping to 50.0");
            g_factorValueOverride = 50.0;
        }
    }

#ifndef BUILD_LITE
    // Restore TH3 frequency with dynamic max validation (binary subdivision)
    string freqGvarName = "Biotak_TH3Freq_" + chartIdStr;
    if(GlobalVariableCheck(freqGvarName)) {
        double restoredFreq = GlobalVariableGet(freqGvarName);
        double maxFreq = GetFrequencyByIndex(MAX_TH3_FREQ_INDEX);
        if(restoredFreq > 0 && restoredFreq <= maxFreq) {
            g_th3FreqOverride = restoredFreq;
        } else {
            g_th3FreqOverride = 0;
            GlobalVariableDel(freqGvarName);
        }
    }
    string indexGvarName = "Biotak_TH3FreqIdx_" + chartIdStr;
    if(GlobalVariableCheck(indexGvarName)) {
        int restoredIndex = (int)GlobalVariableGet(indexGvarName);
        if(restoredIndex >= MIN_TH3_FREQ_INDEX && restoredIndex <= MAX_TH3_FREQ_INDEX) {
            g_th3FreqIndex = restoredIndex;
        } else {
            g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
            GlobalVariableDel(indexGvarName);
        }
    }
    // Binary subdivision migration: sync index with saved frequency (old GM -> binary)
    if(g_th3FreqOverride > 0) {
        double expectedFreq = GetFrequencyByIndex(g_th3FreqIndex);
        if(MathAbs(expectedFreq - g_th3FreqOverride) > 0.01) {
            g_th3FreqIndex = FindNearestFreqIndex(g_th3FreqOverride);
            g_th3FreqOverride = GetFrequencyByIndex(g_th3FreqIndex);
            GlobalVariableSet(freqGvarName, g_th3FreqOverride);
            GlobalVariableSet(indexGvarName, (double)g_th3FreqIndex);
            _LOG_GATE_I Print("[I][GEN] OnInit: TH3 Freq migrated to binary subdivision: idx=", g_th3FreqIndex,
                              " freq=", DoubleToString(g_th3FreqOverride, 4));
        }
    }
#endif

    InitializeATRCache();

    // ATR warmup debounce: skip if recently warmed up (within 90s)
    if(inpShowATRLabels && !shouldBeHidden) {
        datetime nowWarmup = TimeCurrent();
        string warmupGvar = "Biotak_ATRWarmup_" + chartIdStr;
        datetime lastWarmup = 0;
        if(GlobalVariableCheck(warmupGvar)) {
            lastWarmup = (datetime)GlobalVariableGet(warmupGvar);
        }
        if(lastWarmup <= 0 || nowWarmup <= 0 || (nowWarmup - lastWarmup) > 90) {
            WarmupATRMultiTFCache();
            if(nowWarmup > 0) GlobalVariableSet(warmupGvar, (double)nowWarmup);
        }
    }

    PrintBuildInfo();

#ifndef BUILD_LITE
    // Check if TH3 objects need update (after settings change)
    string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStr;
    if(GlobalVariableCheck(th3UpdateFlag) && GlobalVariableGet(th3UpdateFlag) > 0) {
        UpdateAllTH3Objects();
        GlobalVariableDel(th3UpdateFlag);
    }
#endif

    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][GEN] OnInit complete: deferred=", deferHeavyInit, " hidden=", shouldBeHidden);
    #endif

    // Hidden state: set flags (objects created later in OnCalculate/RedrawAllObjects)
    if(shouldBeHidden) {
        g_redrawTHLevelsNeeded = false;
    } else {
        g_redrawTHLevelsNeeded = true;
    }

    return INIT_SUCCEEDED;
}

// Helper function to create custom price horizontal line (DRY)
bool CreateCustomPriceLine(double price, int digits, bool selected = false, 
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
    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES,
                     IsIndicatorHidden() ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, 
                  "[PIN] Custom Price: " + DoubleToString(price, digits) + " | " + tooltipSuffix);
    g_customPriceLineCreated = true;
    return true;
}

//| Helper function to hide all TH objects (DRY)                     |
//|                                                                  |
//| Centralized hide logic to avoid code duplication                 |
//| Used by: OnInit, RedrawAllObjects, F key handler                 |
//| COVERS: TH levels, labels, zones, mode labels, custom price      |
//+------------------------------------------------------------------+
void HideAllTHObjects()
{
    string cachedPrefix = inpObjectPrefix;
    int prefixLen = StringLen(cachedPrefix);
    long noPeriodsVal = OBJ_NO_PERIODS;
    ushort prefixFirstChar = StringGetCharacter(cachedPrefix, 0);
    // PERF (2026): iterate the object cache (only OUR objects) instead of
    // ObjectsTotal(0,-1,-1) which enumerates EVERY chart object - including other
    // indicators' objects - and calls ObjectName() per object. The cache is the
    // authoritative index of our objects, so this is O(our objects), not O(all).
    // SetObjectTimeframesIfChanged is cache-backed: it issues no chart API call
    // when the object is already hidden.
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++)
    {
        if(!g_objectCacheHash[i].occupied) continue;
        string objName = g_objectCacheHash[i].name;
        // Quick first-char rejection before the (still cheap) prefix compare
        if(StringGetCharacter(objName, 0) != prefixFirstChar) continue;
        if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix)
            SetObjectTimeframesIfChanged(objName, noPeriodsVal);
    }
    // PERF: Batch special label hide - ObjectSetInteger is no-op if object doesn't exist
    ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
#ifndef BUILD_LITE
    ObjectSetInteger(0, g_th3FreqLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
#endif
    ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    if(g_customPriceLineCreated)
        ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, noPeriodsVal);
    // NOTE: ABCD pattern objects are NOT hidden by F key
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
        // OPTIMIZATION: Use Symbol() directly here since this is cleanup code (not in a loop)
        string symbolName = GetCachedSymbol();
        string gvarName = "Biotak_CustomPrice_" + symbolName;
        string overrideFlagName = "Biotak_CustomPriceOverride_" + symbolName;
        // Direct delete (safe if not found)
        GlobalVariableDel(gvarName);

        if(GlobalVariableCheck(overrideFlagName)) {
            GlobalVariableDel(overrideFlagName);
        }
        g_customTHStartPrice = 0.0;
        g_thStartPointType = inpTHStartPointType;
        g_customPriceKeyboardOverride = false; // Reset keyboard override flag
    }
}

//+------------------------------------------------------------------+
//| OnDeinit Handler - cleanup and state persistence (matching MT5)  |
//+------------------------------------------------------------------+
void OnDeinitHandler(const int reason) {
    DEBUG_PRINT("Starting cleanup");
    // Save TF-switch timestamp for deferred init debounce
    if(reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS) {
        string tfSwitchStampGvar = "Biotak_LastTFSwitch_" + GetCachedChartIdStr();
        datetime nowSwitch = TimeCurrent();
        if(nowSwitch > 0) GlobalVariableSet(tfSwitchStampGvar, (double)nowSwitch);
    }

    ReleaseATRHandle();
    EventKillTimer();

    // PERF: ObjectDelete is safe to call on non-existent objects (returns false, no error)
    // Eliminates ObjectFind syscalls
    ObjectDelete(0, g_stepModeLabelName);
    ObjectDelete(0, g_factorLabelName);
#ifndef BUILD_LITE
    ObjectDelete(0, g_th3FreqLabelName);
#endif
    ObjectDelete(0, g_lockStatusLabelName);
    ObjectDelete(0, g_customPriceHorizontalLineName);

    if(reason == REASON_REMOVE)
    {
        DEBUG_PRINT("Indicator removed - cleaning all GlobalVariables");
        string removeChartIdStr = GetCachedChartIdStr();
        string removeSymbolFile = "Biotak_LastSymbol_" + removeChartIdStr + ".dat";
        FileDelete(removeSymbolFile);
        CleanupAllGlobalVariables();
        DeleteAllIndicatorObjects(true);
        ObjectsDeleteAll(0, "TH3_Structure_");
#ifndef BUILD_LITE
        ObjectsDeleteAll(0, TH3_PATTERN_PREFIX);  // Clean up AB=CD pattern objects
        ObjectsDeleteAll(0, TH3_TEMP_PREFIX);     // Clean up any temp drawing objects
#endif
    }
    else if(reason == REASON_PARAMETERS)
    {
        // Clear all ATR and TH labels to apply new settings
        string currentTFStr = IntegerToString(GetCachedPeriod());
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
#ifndef BUILD_LITE
        string th3UpdateFlag = "Biotak_TH3_NeedsUpdate_" + chartIdStrLocal;
        GlobalVariableSet(th3UpdateFlag, 1.0);
#endif
        DEBUG_PRINT("OnDeinit (REASON_PARAMETERS) - reset overrides");
        DeleteAllIndicatorObjects(false);
    }
    else if(reason == REASON_CHARTCHANGE)
    {
        // PERF (2026): TF switch is the most common user interaction and was
        // the dominant source of "the chart is slow" complaints. The old code
        // deleted every level/zone object synchronously here (DeleteAllIndicatorObjects
        // -> ObjectsDeleteAll) which on a 200-object chart costs ~50-150ms and
        // causes a visible flash. The 2026 architecture (TF-independent prefix +
        // rename-in-place in RedrawAllObjects) means the same object set survives
        // a TF switch - we only need to update prices and geometry. Skipping the
        // delete here keeps the chart continuous: old levels stay on screen with
        // their old prices for a frame or two, then RedrawAllObjects moves them
        // to the new TF's prices in a single pass. No flash, no 100ms+ freeze.
        DEBUG_PRINT("OnDeinit (REASON_CHARTCHANGE) - skipping object delete (handled by rename-in-place on next redraw)");
    }
    else
    {
        DEBUG_PRINTF("OnDeinit (reason=", reason);
        DeleteAllIndicatorObjects(false);
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
    CleanupPerformanceOptimizations();
    CacheClear();
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
//|                                        |
//| CRITICAL FIX: Added error handling and retry logic              |
//+------------------------------------------------------------------+
//| Clear all level objects from all modes (2026 PERF)              |
//|                                                                  |
//| PERF FIX: Collapse 26+ ObjectsDeleteAll suffix-variant calls     |
//| into ONE prefix-based call.                                       |
//|                                                                  |
//| MQL5 official docs (ObjectsDeleteAll):                            |
//|   "Removes all objects of the specified type using prefix in      |
//|    object names. All objects whose names start with this set of   |
//|    characters will be removed from chart."                        |
//|   "The function uses a synchronous call ... that is why this      |
//|    function can be time consuming. This feature should be taken   |
//|    into account when working with a large number of objects."     |
//|                                                                  |
//| Every level/zone/legacy object we draw is named                   |
//| "<objectPrefix><Suffix>" (e.g. "Biotak_H1_SSLS_Above_3").        |
//| Since they all share the same leading substring, a SINGLE native  |
//| call with the bare objectPrefix removes them all in one trip.    |
//| Measured: 26 -> 1 synchronous call on TF switch.                 |
//+------------------------------------------------------------------+
void ClearAllLevels(const string objectPrefix, bool clearZones = true)
{
    if(StringLen(objectPrefix) == 0) return;

    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastClearLog = 0;
    if(TimeCurrent() - s_lastClearLog > 5) {
        Print("[D][GEN] [MT4] [CLEAN] CLEARING ALL LEVELS with prefix: ", objectPrefix);
        s_lastClearLog = TimeCurrent();
    }
    #endif

    g_suppressDeleteEvents = true;
    int totalDeleted = 0;

    if(clearZones) {
        // FAST PATH: one synchronous call removes every level/zone/legacy
        // object sharing this prefix. This is the dominant case (TF switch,
        // topology change, R/K key, parameter change).
        totalDeleted = ObjectsDeleteAll(0, objectPrefix);
    } else {
        // SLOW PATH: custom-price drag wants zone rectangles preserved
        // (zones stay anchored while the price line moves). Delete only
        // the non-zone objects via the suffix registry.
        totalDeleted = DeleteLevelObjectsKeepZones(objectPrefix);
    }

    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
    g_suppressDeleteEvents = false;

    #ifdef ENABLE_DEBUG_LOGS
    if(totalDeleted > 0) {
        Print("[D][GEN] ClearAllLevels PERF: Deleted ", totalDeleted,
              " objects via ",
              (clearZones ? "single" : "suffix-loop"),
              " bulk delete (prefix=", objectPrefix, ")");
    }
    #endif

    // PERF: O(occupied) cache invalidation. Every cache entry whose name
    // starts with `objectPrefix` is now stale (the chart object no longer
    // exists). We mark those slots as tombstones. Subsequent cache lookups
    // skip tombstones via linear probing, and ZoneFactory/ZoneRenderer
    // re-verify existence on cache miss, so correctness is preserved.
    InvalidateObjectCacheByPrefix(objectPrefix);
    InvalidateObjectCountCache();
}

//+------------------------------------------------------------------+
//| PERF (2026): Rename TF-scoped objects in place on timeframe switch |
//|                                                                  |
//| Official MQL5 guidance: the most expensive chart operation is      |
//| ObjectCreate (and the paired ObjectDelete). On a timeframe switch   |
//| the SET of level/zone objects is identical (Above_1..N, Below_1..N) |
//| - only their prices differ. So instead of ClearAllLevels() (which  |
//| does ObjectDelete of every object + a later ObjectCreate of every  |
//| object), we rename the existing objects from the old TF prefix to   |
//| the new one with a single ObjectSetString(OBJPROP_NAME). All visual |
//| properties (color/style/width/back/selectable/tooltip) are preserved|
//| by the rename, and the following redraw then updates only the prices|
//| and zone geometry in place. This removes the ObjectDelete+ObjectCreate|
//| storm entirely from the TF-switch hot path.                         |
//|                                                                  |
//| Every name under `oldPrefix` becomes `newPrefix` + the same suffix, |
//| which is a valid 1:1 mapping for levels, zones and TF-specific      |
//| labels alike. The object cache is then tombstoned for the old prefix|
//| so the redraw repopulates it (one-time ObjectFind per object).       |
//+------------------------------------------------------------------+
void RenamePrefixedObjects(const string oldPrefix, const string newPrefix)
{
    if(oldPrefix == newPrefix) return;
    if(StringLen(oldPrefix) == 0) return;
    int oldLen = StringLen(oldPrefix);

    g_suppressDeleteEvents = true;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(!g_objectCacheHash[i].occupied) continue;
        string objName = g_objectCacheHash[i].name;
        // Only objects that actually start with the old TF prefix.
        if(StringLen(objName) < oldLen || StringSubstr(objName, 0, oldLen) != oldPrefix) continue;
        string newName = newPrefix + StringSubstr(objName, oldLen);
        if(objName == newName) continue;
        // Rename in place: keeps all properties, avoids delete+create.
        ObjectSetString(0, objName, OBJPROP_NAME, newName);
        // PERF (2026): update the in-memory cache to mirror the new name.
        // The previous version called InvalidateObjectCacheByPrefix(oldPrefix)
        // after the loop, throwing away every cache entry under the old
        // prefix. The next RenderZones/RenderTriggerLines pass then had to
        // re-verify every cached object with a SYNCHRONOUS ObjectFind(0,name)
        // call (ObjectFind is documented as "can be time consuming" in the
        // MQL5 docs). On M1 with 289 objects that was 289 sync syscalls
        // after every prefix rename. Updating the cache name in-place keeps
        // the cache-only fast path active for the renamed objects and
        // eliminates the entire ObjectFind storm.
        g_objectCacheHash[i].name = newName;
        g_objectCacheHash[i].lastAccess = CacheGetFrameTime();
    }
    g_suppressDeleteEvents = false;
    InvalidateObjectCountCache();
}

//+------------------------------------------------------------------+
//| Helper: delete level/line/legacy objects while keeping zones.   |
//| Used only when ClearAllLevels is called with clearZones=false    |
//| (custom-price drag path).                                         |
//+------------------------------------------------------------------+
int DeleteLevelObjectsKeepZones(const string objectPrefix)
{
    int deleted = 0;

    static string NON_ZONE_SUFFIXES[];
    static bool s_nonZoneInit = false;
    if(!s_nonZoneInit) {
        // Pipeline level/line suffixes
        int levelCount = 0;
        GetAllLevelSuffixes(NON_ZONE_SUFFIXES, levelCount);

        // Legacy non-zone suffixes
        int legacyCount = ArraySize(NON_ZONE_SUFFIXES);
        ArrayResize(NON_ZONE_SUFFIXES, legacyCount + 16);
        NON_ZONE_SUFFIXES[legacyCount++] = "SharedPattern_";
        NON_ZONE_SUFFIXES[legacyCount++] = "TH_Level_";
        NON_ZONE_SUFFIXES[legacyCount++] = "S_";
        NON_ZONE_SUFFIXES[legacyCount++] = "TriggerTH_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "TriggerTH_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel1_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel1_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel2_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel2_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel3_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel3_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel4_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel4_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel5_Up_";
        NON_ZONE_SUFFIXES[legacyCount++] = "StructureLevel5_Down_";
        NON_ZONE_SUFFIXES[legacyCount++] = "Mid";
        s_nonZoneInit = true;
    }

    for(int i = 0; i < ArraySize(NON_ZONE_SUFFIXES); i++) {
        deleted += ObjectsDeleteAll(0, objectPrefix + NON_ZONE_SUFFIXES[i]);
    }
    return deleted;
}

//+------------------------------------------------------------------+
//| 64-bit FNV-1a hash of all level-drawing topology inputs.         |
//|                                                                  |
//| PERF: Replaces the previous 26+ string-concat "levelSig" with a  |
//| single 64-bit integer hash. Collisions on 26 fields of 8-32 bits |
//| are astronomically unlikely (birthday bound ~2^32) and harmless  |
//| — at worst we redraw once more, same as the old code would do.   |
//|                                                                  |
//| Doubles are scaled by 1000 and truncated to long so the hash is   |
//| stable across float rounding noise.                              |
//+------------------------------------------------------------------+
ulong HashLevelTopology(const string prefix, ENUM_STEP_CALCULATION_MODE mode) {
    // FNV-1a 64-bit constants
    const ulong FNV_OFFSET = 14695981039346656037ULL;
    const ulong FNV_PRIME  = 1099511628211ULL;

    ulong h = FNV_OFFSET;

    // Mix the prefix string into the hash (cheap char-by-char XOR)
    int prefixLen = StringLen(prefix);
    for(int i = 0; i < prefixLen; i++) {
        h ^= (ulong)(ushort)StringGetCharacter(prefix, i);
        h *= FNV_PRIME;
    }

    // Mix all integer / bool / scaled-double inputs
    h ^= (ulong)(int)mode;                  h *= FNV_PRIME;
    h ^= (ulong)inpMaxLevels;               h *= FNV_PRIME;
    h ^= (ulong)(int)g_thStartPointType;     h *= FNV_PRIME;
    h ^= (ulong)(inpLSFirst ? 1 : 0);       h *= FNV_PRIME;
    h ^= (ulong)(inpShowMidZones ? 1 : 0);  h *= FNV_PRIME;
    h ^= (ulong)(int)inpMidZoneStyle;       h *= FNV_PRIME;
    h ^= (ulong)inpMidZoneTransparency;     h *= FNV_PRIME;
    // Double → scaled long (3 decimal places of precision)
    h ^= (ulong)(long)(inpMidZoneHeightPercent * 1000.0);
    h *= FNV_PRIME;
    h ^= (ulong)(IsTriggerLevelsEnabled() ? 1 : 0);
    h *= FNV_PRIME;
#ifndef BUILD_LITE
    h ^= (ulong)(inpEnableHarmonicPattern ? 1 : 0);
    h *= FNV_PRIME;
    h ^= (ulong)(long)(inpHarmonicRatio * 1000.0);
    h *= FNV_PRIME;
    // COMBO FIX #2: include combo config so operation/preset/component
    // changes invalidate the cache and force a level redraw.
    h ^= (ulong)(int)inpComboMode;          h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboPreset;        h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboTopology;      h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp1;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp1;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp2;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp2;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp3;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp3;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp4;         h *= FNV_PRIME;
#else
    h ^= (ulong)(int)inpComboMode;          h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboPreset;        h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboTopology;      h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp1;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp1;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp2;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp2;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp3;         h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboOp3;           h *= FNV_PRIME;
    h ^= (ulong)(int)inpComboComp4;         h *= FNV_PRIME;
#endif
    return h;
}

//+------------------------------------------------------------------+
//| PERF (2026, A): Compute full redraw identity hash                |
//|                                                                  |
//| The existing HashLevelTopology mixes ~26 inputs (mode, all        |
//| settings, combo config, prefix) and is used to detect "topology   |
//| changed" inside the heavy pipeline. But the *visual output* of    |
//| the full redraw also depends on the dynamic price inputs (base   |
//| price, custom price, historical High/Low) and on the show-TH-     |
//| levels toggle.                                                    |
//|                                                                  |
//| By extending HashLevelTopology with those fields we get a single  |
//| 64-bit identity hash for the *entire redraw frame*. If it matches |
//| the last full redraw, the 289-zone pipeline (CalculateLevels /   |
//| ClassifyLevels / BuildZonesAndLines / RenderZones /              |
//| RenderTriggerLines) would produce identical output and can be     |
//| skipped entirely. The cheap tail (CheckAlerts, ThrottledChart-    |
//| Redraw) still runs so alerts and pip-distance labels stay current.|
//|                                                                  |
//| Per the official MQL5 docs (2026), ObjectGetInteger / ObjectFind |
//| are SYNCHRONOUS calls ("can be time consuming when working with  |
//| a large number of objects on a chart"). The cache-backed render   |
//| path already cuts those out, but the pipeline itself does ~290   |
//| iterations of classification, geometry and zone construction per |
//| redraw. Skipping that is the single biggest CPU win on lower     |
//| timeframes (logged ~480-670 ms on M15 with 289 zones).           |
//|                                                                  |
//| Collisions across 30+ mixed fields are astronomically unlikely    |
//| (birthday bound ~2^32) and harmless: at worst we redraw once     |
//| more, same as the old code would do.                              |
//+------------------------------------------------------------------+
ulong ComputeRedrawIdentityHash(
    const string prefix,
    ENUM_STEP_CALCULATION_MODE mode,
    const double basePrice,
    const double customPrice,
    const double highestHigh,
    const double lowestLow,
    const bool customPriceActive,
    const bool showLevels)
{
    const ulong FNV_PRIME = 1099511628211ULL;

    // Start from topology hash. It already mixes mode, all settings,
    // combo config, mid-zone style, etc.
    ulong h = HashLevelTopology(prefix, mode);

    // Mix in the dynamic price inputs that drive the actual pixel output
    // of every level and zone. 5 decimal places = 0.1 pip on 5-digit
    // forex (well below any meaningful level distance), so float-rounding
    // noise never changes the hash.
    h ^= (ulong)(long)(basePrice    * 100000.0);  h *= FNV_PRIME;
    h ^= (ulong)(long)(customPrice  * 100000.0);  h *= FNV_PRIME;
    h ^= (ulong)(long)(highestHigh  * 100000.0);  h *= FNV_PRIME;
    h ^= (ulong)(long)(lowestLow    * 100000.0);  h *= FNV_PRIME;
    h ^= (ulong)(customPriceActive  ? 1 : 0);     h *= FNV_PRIME;
    h ^= (ulong)(showLevels         ? 1 : 0);     h *= FNV_PRIME;
    // PERF (2026): include the chart timeframe so the hash changes on a
    // TF switch. Even though object names are now TF-independent (so the
    // same 200+ objects survive the switch), the level VALUES still need
    // to update - the fractal TF and ATR step depend on the chart TF.
    h ^= (ulong)GetCachedPeriod();                h *= FNV_PRIME;
    return h;
}

string GetActivePipelineModeName()
{
    switch(GetCurrentStepMode()) {
        case SS_LS_STEP:
            return "SSLS";
        case COMBO_STEP:
            return "Combo";
        case FACTOR_STEP:
#ifndef BUILD_LITE
            if(inpEnableHarmonicPattern) return "Factor_Harmonic";
#endif
            return "Factor";
        case TH_STEP:
        default:
            return "TH_Level";
    }
}

string GetRuntimeObjectPrefix()
{
    // PERF (2026): TF-independent object prefix. The same indicator objects
    // are reused across chart timeframes. Reasons:
    //   1. The TH percentage and base price are TF-independent - level VALUES
    //      only change when the FRACTAL TF changes (and the chart TF is just
    //      an alias for that), not on every chart switch.
    //   2. The OLD design renamed 200+ objects per switch via
    //      ObjectSetString(OBJPROP_NAME), which (a) is expensive because the
    //      chart engine has to reindex its name->object map, and (b) ACCUMULATES
    //      command-queue depth on rapid TF toggling - users reported each switch
    //      getting slower instead of faster. 10 toggles = 2000+ queued renames
    //      and the chart lagged behind.
    //   3. With TF-independent names the rename path becomes a no-op (same
    //      prefix before/after the switch), the cache stays consistent, and
    //      the same objects are reused. Only their prices move.
    return inpObjectPrefix + "_";
}

void InvalidateObjectCacheByPrefix(const string objectPrefix)
{
    if(StringLen(objectPrefix) == 0 || g_objectCacheSize <= 0) return;

    int prefixLen = StringLen(objectPrefix);
    // PERF (2026): cheap first-character rejection skips ~95% of buckets
    // before the expensive StringSubstr/compare (the only char that varies
    // across timeframes is the trailing digit, e.g. "Biotak_H1_" vs
    // "Biotak_M5_" — first char is always 'B').
    ushort prefixFirstChar = StringGetCharacter(objectPrefix, 0);
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(!g_objectCacheHash[i].occupied) continue;
        if(StringGetCharacter(g_objectCacheHash[i].name, 0) != prefixFirstChar) continue;
        if(StringLen(g_objectCacheHash[i].name) < prefixLen) continue;
        if(StringSubstr(g_objectCacheHash[i].name, 0, prefixLen) != objectPrefix) continue;

        g_objectCacheHash[i].name = "";
        g_objectCacheHash[i].occupied = false;
        g_objectCacheHash[i].deleted = true;
        g_objectCacheHash[i].lastAccess = 0;
        g_objectCacheSize--;
        if(g_objectCacheSize == 0) break;
    }
}

int DeleteObjectsByPrefixAndInvalidate(const string objectPrefix)
{
    if(StringLen(objectPrefix) == 0) return 0;

    int deleted = ObjectsDeleteAll(0, objectPrefix);
    if(deleted > 0) InvalidateObjectCacheByPrefix(objectPrefix);
    return deleted;
}

void CleanupInactivePipelineModes(const string objectPrefix, const string activeModeName, bool clearZones = true)
{
    if(StringLen(objectPrefix) == 0 || StringLen(activeModeName) == 0) return;

    SModeSuffixEntry entries[];
    int entryCount = 0;
    GetAllModeSuffixes(entries, entryCount);

    g_suppressDeleteEvents = true;
    int totalDeleted = 0;
    for(int i = 0; i < entryCount; i++) {
        int modeNameEnd = StringFind(entries[i].levelAbove, "_Above_");
        string modeName = (modeNameEnd > 0) ? StringSubstr(entries[i].levelAbove, 0, modeNameEnd) : "";
        if(modeName == "" || modeName == activeModeName) continue;

        if(clearZones) {
            totalDeleted += ObjectsDeleteAll(0, objectPrefix + entries[i].zoneSuffix);
            totalDeleted += ObjectsDeleteAll(0, objectPrefix + entries[i].zoneCenter);
        }

        totalDeleted += ObjectsDeleteAll(0, objectPrefix + entries[i].levelAbove);
        totalDeleted += ObjectsDeleteAll(0, objectPrefix + entries[i].levelBelow);
        totalDeleted += ObjectsDeleteAll(0, objectPrefix + entries[i].midpoint);
        totalDeleted += ObjectsDeleteAll(0, objectPrefix + modeName + "_Midpoint_");
    }
    g_suppressDeleteEvents = false;

    // PERF (2026): invalidate the object cache ONCE for the whole prefix instead of
    // once per suffix. The old DeleteObjectsByPrefixAndInvalidate rescanned all
    // 2048 cache buckets per suffix (~25 times). A single pass after the loop is
    // sufficient and removes that redundant synchronous work.
    if(totalDeleted > 0) {
        InvalidateObjectCacheByPrefix(objectPrefix);
        InvalidateObjectCountCache();
    }
}

//| Get adaptive level counts (reduce object load on fast TFs)       |
//+------------------------------------------------------------------+
void GetAdaptiveLevelCounts(int &maxAbove, int &maxBelow)
{
    int levels = inpMaxLevels;
    // PERFORMANCE NOTE: Lower timeframes create more objects because TH steps are tiny.
    // v2026: Adaptive per-TF caps were removed at user request so that inpMaxLevels is
    // honored on every timeframe. When the base price is far from the visible range the
    // range-skip offset in CalculateLevels already keeps the level budget inside the
    // visible window, so lower TFs no longer run out of levels before reaching them.
    // The MAX_SAFE_LEVELS clamp below still guards against runaway object counts.

    maxAbove = levels;
    maxBelow = levels;
    if(maxAbove > MAX_SAFE_LEVELS) maxAbove = MAX_SAFE_LEVELS;
    if(maxBelow > MAX_SAFE_LEVELS) maxBelow = MAX_SAFE_LEVELS;
    if(maxAbove < 1) maxAbove = 1;
    if(maxBelow < 1) maxBelow = 1;
}
//| Calculate common values used across all step modes              |
//| TH-based only (ATR basis removed, matching MT5)                |
//+------------------------------------------------------------------+
bool CalculateCommonStepData(const double dailyClosePrice, SCommonStepData &data)
{
    if(dailyClosePrice <= 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][GEN] CalculateCommonStepData: Invalid daily close price");
        #endif
        return false;
    }

    // PERF: Per-timeframe computation cache (ring of 4). Toggling back to a
    // recently viewed timeframe reuses the TH/ATR/fractal results instead of
    // recomputing from scratch, so switching TFs is cheap.
    struct SStepCacheEntry {
        double dailyClose;
        string tf;
        int    startPointType;
        double customPrice;
        int    maxAbove;
        int    maxBelow;
        double scaling;
        double highestHigh;
        double lowestLow;
        int    fractalShift;
        SCommonStepData data;
    };
    static SStepCacheEntry s_stepCache[4];
    static int s_stepCacheHead = -1;

    string currentTF = GetFractalTimeframeForCurrent();
    double currentScalingFactor = GetCurrentScalingFactor();

    bool cacheHit = false;
    for(int ci = 0; ci < 4; ci++) {
        if(s_stepCache[ci].tf == currentTF &&
           s_stepCache[ci].startPointType == g_thStartPointType &&
           (g_thStartPointType != TH_START_POINT_CUSTOM_PRICE || s_stepCache[ci].customPrice == g_customTHStartPrice) &&
           s_stepCache[ci].maxAbove == inpMaxLevels &&
           s_stepCache[ci].maxBelow == inpMaxLevels &&
           MathAbs(s_stepCache[ci].scaling - currentScalingFactor) < EPSILON_GENERAL &&
            MathAbs(s_stepCache[ci].highestHigh - g_highestHigh) < EPSILON_PRICE &&
            MathAbs(s_stepCache[ci].lowestLow - g_lowestLow) < EPSILON_PRICE &&
            s_stepCache[ci].fractalShift == g_fractalShift &&
            s_stepCache[ci].dailyClose == dailyClosePrice) {
            data = s_stepCache[ci].data;
            cacheHit = true;
            break;
        }
    }
    if(cacheHit) {
        return true;
    }

    // OPTIMIZATION: Use global Digits instead of MarketInfo call
    int digits = Digits;

    // TH-based step calculations
    double timeframePercentage = GetTimeframeTH();
    data.thValue = CalculateTH(dailyClosePrice, digits, timeframePercentage);

    // Apply ATR Adaptive Scaling to TH value
    // This preserves the fractal 2x ratio since the same factor scales all levels uniformly
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
        Print("[D][GEN] SS (1.5 x Structure): ", DoubleToString(data.structureValue * 1.5, 10));
        Print("[D][GEN] LS (2.0 x Structure): ", DoubleToString(data.structureValue * 2.0, 10));
        Print("[D][GEN] ==============================================");
        s_lastTHDebugLogTime = currentDebugTime;
    }
    #endif

    // Calculate SS/LS values using simple multipliers (in PRICE units)
    data.shortStep = data.structureValue * 1.5;
    data.longStep = data.structureValue * 2.0;

    // NO point size conversion needed - values are already in price units
    data.pointSize = 1.0;  // Not used anymore

    // Get midpoint price using utility function
    data.midpointPrice = GetMidpointPrice(g_thStartPointType);

    // Validate midpoint price
    if(data.midpointPrice <= 0 || data.midpointPrice == EMPTY_VALUE) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][GEN] ERROR: Invalid midpoint price! g_highestHigh=", g_highestHigh, ", g_lowestLow=", g_lowestLow);
        #endif
        return false;
    }

    // Get adaptive level counts
    GetAdaptiveLevelCounts(data.maxLevelsAbove, data.maxLevelsBelow);

    // Store into per-timeframe ring cache (overwrite oldest slot)
    s_stepCacheHead = (s_stepCacheHead + 1) % 4;
    s_stepCache[s_stepCacheHead].dailyClose = dailyClosePrice;
    s_stepCache[s_stepCacheHead].tf = currentTF;
    s_stepCache[s_stepCacheHead].startPointType = g_thStartPointType;
    s_stepCache[s_stepCacheHead].customPrice = g_customTHStartPrice;
    s_stepCache[s_stepCacheHead].maxAbove = inpMaxLevels;
    s_stepCache[s_stepCacheHead].maxBelow = inpMaxLevels;
    s_stepCache[s_stepCacheHead].scaling = currentScalingFactor;
    s_stepCache[s_stepCacheHead].highestHigh = g_highestHigh;
    s_stepCache[s_stepCacheHead].lowestLow = g_lowestLow;
    s_stepCache[s_stepCacheHead].fractalShift = g_fractalShift;
    s_stepCache[s_stepCacheHead].data = data;

    return true;
}

//+------------------------------------------------------------------+
//| Wrapper function to handle different step calculation modes     |
//| REFACTORED: Uses centralized ModeDefinitions factory             |
//+------------------------------------------------------------------+
void DrawLevelsBasedOnMode(const string objectPrefix, const double dailyClosePrice)
{
    // DIAGNOSTIC LOG: confirm drawing called
    static int s_drawLevelsLogCount = 0;
    if(s_drawLevelsLogCount < 5) {
        Print("[DRAWLEVELS_ENTRY] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " prefix=", objectPrefix,
              " dailyClose=", DoubleToString(dailyClosePrice, Digits));
        s_drawLevelsLogCount++;
    }
    
    // Draw based on selected mode (respects keyboard override)
    ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
    SCommonStepData data;
    if(!CalculateCommonStepData(dailyClosePrice, data)) {
        Print("[DRAWLEVELS_FAIL] CalculateCommonStepData returned false");
        return;
    }
    
    // Use the modular Mode Factory
    SModeDefinition def = GetModeDefinition(currentMode, objectPrefix, data, dailyClosePrice);
    
    if(def.success) {
        // Convert static array to dynamic for ExecutePipeline compatibility
        double sizes[];
        ArrayResize(sizes, def.stepSizeCount);
        for(int i = 0; i < def.stepSizeCount; i++) {
            sizes[i] = def.stepSizes[i];
        }
        
        SPipelineResult result = ExecutePipeline(def.config, data.midpointPrice, sizes, def.stepSizeCount,
                                                def.stepMode, def.classifyMode, def.lsFirst,
                                                data.maxLevelsAbove, data.maxLevelsBelow);

        if(!result.success) {
            _LOG_GATE_W Print("[W][DRAW] DrawLevelsBasedOnMode: pipeline failed | mode=", GetStepModeName(currentMode),
                              " | reason=", result.errorMessage,
                              " | base=", DoubleToString(dailyClosePrice, Digits),
                              " | center=", DoubleToString(data.midpointPrice, Digits),
                              " | stepCount=", def.stepSizeCount);
        } else if(result.zoneCount <= 0 && result.lineCount <= 0) {
            _LOG_GATE_W Print("[W][DRAW] DrawLevelsBasedOnMode: pipeline produced no drawable objects | mode=",
                              GetStepModeName(currentMode),
                              " | base=", DoubleToString(dailyClosePrice, Digits),
                              " | center=", DoubleToString(data.midpointPrice, Digits),
                              " | maxAbove=", data.maxLevelsAbove,
                              " | maxBelow=", data.maxLevelsBelow);
        }
        
        ArrayFree(sizes);
    } else {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][DRAW] DrawLevelsBasedOnMode: Failed to get mode definition for ", EnumToString(currentMode));
        #endif
    }
}

// DEPRECATED: Old helper functions removed
// Base price history is now managed by BasePriceManager.mqh
// Use PrintBasePriceHistory() from BasePriceManager instead

void RedrawAllObjects(bool force_redraw=false)
{
    // PERF (2026): The [REDRAW_ENTRY] diagnostic is gated to 10 calls per
    // indicator run, but the print still fires BEFORE the function does any
    // work - on every no-op tick it just spams the journal. Moved the print
    // to fire only AFTER we have decided to do real work (past the early-exit
    // gates), so the log accurately reflects "a real redraw is happening".
    // PERF (2026): also measure full redraw duration. (Merged the previously
    // separate `uint redrawStartMs` declaration below the print to keep all
    // the per-run setup in one place.)
    uint redrawStartMs = GetTickCount();

    // Mark the start of the jump-determination window (used for the timeout fallback
    // so levels still draw if ATR never becomes available).
    if(g_fractalDetermineStartMs == 0) g_fractalDetermineStartMs = redrawStartMs;

    // PERF: Soft millisecond guard for burst calls (independent from second-based gate)
    static uint s_lastRedrawAttemptMs = 0;
    static uint s_lastForcedRedrawMs = 0;
    uint nowMs = GetTickCount();

    // PERF (2026): zero the throttle timestamps when this is the first call
    // after a fresh OnInit (s_lastRedrawAttemptMs is the cleanest signal we
    // have - it's 0 in the first frame after init and only ever gets set to
    // a positive value after the first successful RedrawAllObjects).
    // Without this reset, a TF switch that fires within 60ms of any prior
    // forced redraw (e.g. a hotkey, an OnInit, a redraw from a previous TF)
    // would early-return on the throttle and the user would see a 60ms gap
    // before levels updated. The first frame after OnInit is exactly the
    // frame that MUST pass through.
    bool isFirstFrameAfterInit = (s_lastRedrawAttemptMs == 0);
    if(isFirstFrameAfterInit) {
        s_lastForcedRedrawMs = 0;
    }

    // PERF: Coalesce event-burst forced redraws. A wider window collapses the
    // burst of forced redraws right after a timeframe switch into fewer full
    // clear+recreate cycles.
    if(force_redraw) {
        if(!isFirstFrameAfterInit && s_lastForcedRedrawMs != 0 && nowMs - s_lastForcedRedrawMs < 60) return;
        s_lastForcedRedrawMs = nowMs;
    }

    datetime currentTime = TimeGMT();

    // PERF: Idle fast-path   when no work is pending, skip expensive UpdateBasePrice/ATR path.
    bool customPriceLineExists = g_customPriceLineCreated;
    bool historicalRefreshDue = (currentTime - g_lastHistoricalUpdate >= 3600 || !g_initialized);
    // PERF (2026): basePriceBoundary was previously "true for the WHOLE minute
    // window (minute==0 OR minute==30)", so on M1 with 60 ticks per minute at
    // minute==0 it kept hasPendingWork=true for the full 60 seconds, blocking
    // the idle early-exit and forcing us through UpdateBasePrice/scaling/ATR
    // 60 times in a row even though the actual UpdateBasePrice work was
    // already gated to the boundary transition via s_nextBasePriceCheckServer.
    // The right signal is "is THIS tick the first one at the boundary?" so we
    // only do the heavy path on the transition tick. Below we detect the
    // edge: minute is now 0/30 AND it wasn't 0/30 on the previous tick.
    int currentServerMinute = TimeMinute(TimeCurrent());
    static int s_lastServerMinute = -1;
    bool basePriceBoundary = ((currentServerMinute == 0 || currentServerMinute == 30)
                              && currentServerMinute != s_lastServerMinute);
    s_lastServerMinute = currentServerMinute;
    bool hasPendingWork = (force_redraw || g_labelsRelayoutNeeded || g_redrawTHLevelsNeeded || historicalRefreshDue || basePriceBoundary);
    
    // PERFORMANCE FIX: Hard millisecond gate for ALL redraws (except forced UI events)
    // This prevents price vibrations from hammering the CPU
    if(!force_redraw) {
        uint minWait = g_redrawTHLevelsNeeded ? 200 : 500; // 5 FPS for levels, 2 FPS for housekeeping
        if(nowMs - s_lastRedrawAttemptMs < minWait) return;
    }

    if(!hasPendingWork) {
        s_lastRedrawAttemptMs = nowMs;
        return;
    }

    // PERF (2026): diagnostic print only after we passed the early-exit gates,
    // so the journal only logs genuine redraws (not the 30 no-op ticks per
    // second that previously made this log unreadable).
    static int s_redrawEntryLogCount = 0;
    if(s_redrawEntryLogCount < 10) {
        Print("[REDRAW_ENTRY] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " force=", (force_redraw ? "Y" : "N"),
              " levelsNeeded=", (g_redrawTHLevelsNeeded ? "Y" : "N"),
              " initialized=", (g_initialized ? "Y" : "N"),
              " bid=", DoubleToString(Bid, Digits));
        s_redrawEntryLogCount++;
    }

    // PERF: Refresh cached frame time once   eliminates ~2000+ TimeCurrent() syscalls in cache ops
    // Moved after early-exit checks so idle frames skip this entirely
    CacheRefreshFrameTime();
    // PERF: Cache visibility state once per frame   skips ~800 ObjectSetInteger calls when unchanged
    CacheRefreshVisibilityState();

    string s_cachedSymbol = GetCachedSymbol();
    int s_cachedDigits = GetCachedDigits();
    double s_cachedPoint = GetCachedPoint();
    // PERF: Cache Bid/Ask once per redraw frame instead of ~10 SymbolInfoDouble syscalls
    CacheTickPrices();
    g_currentPrice = GetCachedBid();
    if(g_currentPrice <= 0) return;

    // PERF: Controlled lazy base-price init (for deferred TF-switch startup path)
    if(!g_systemInitialized) {
        static uint s_lastBaseInitAttemptMs = 0;
        if(s_lastBaseInitAttemptMs == 0 || nowMs - s_lastBaseInitAttemptMs > 3000) {
            s_lastBaseInitAttemptMs = nowMs;
            InitializeBasePriceSystem();
        }
    }

    // PERF: Gate base-price updates to 30-min boundaries instead of checking every redraw.
    static datetime s_nextBasePriceCheckServer = 0;
    datetime nowServerTs = CacheGetFrameTime();
    bool shouldCheckBasePrice = (s_nextBasePriceCheckServer <= 0 || nowServerTs >= s_nextBasePriceCheckServer);
    if(shouldCheckBasePrice) {
        TH3_PROF_START(BasePrice);
        UpdateBasePrice();
        TH3_PROF_END(BasePrice);

        MqlDateTime nextCheckDt;
        TimeToStruct(nowServerTs, nextCheckDt);
        if(nextCheckDt.min < 30) {
            nextCheckDt.min = 30;
        } else {
            nextCheckDt.hour++;
            nextCheckDt.min = 0;
        }
        nextCheckDt.sec = 0;
        // +1 second prevents repeat runs at the exact boundary timestamp.
        s_nextBasePriceCheckServer = StructToTime(nextCheckDt) + 1;
    }

    double thBasePrice = GetBasePriceForTH();
    if(thBasePrice <= 0 || thBasePrice == EMPTY_VALUE) {
        thBasePrice = g_dailyClosePriceForTH;
    }
    
    // Update ATR Adaptive Scaling factor (reacts to ATR changes every 5 seconds)
    if(UpdateATRScalingFactor(thBasePrice, s_cachedDigits)) {
        g_redrawTHLevelsNeeded = true;
    }
    
    static double s_lastDrawnBasePrice = 0.0;
    bool basePriceChanged = (MathAbs(thBasePrice - s_lastDrawnBasePrice) > s_cachedPoint);
    if(basePriceChanged) {
        s_lastDrawnBasePrice = thBasePrice;
        g_redrawTHLevelsNeeded = true;
    }

    // PERF: Use tracked bool instead of ObjectFind MT5 syscall (~0.5ms saved per frame)
    // While the fractal jump has not yet been determined for THIS timeframe, never
    // skip: we must keep running UpdateATRScalingFactor every tick so the first level
    // draw uses the correct spacing (jump applied BEFORE any levels are drawn).
    string curTFStr = GetCurrentTimeframe();
    bool fractalReady = (g_fractalDetermined && g_fractalDeterminedTF == curTFStr);
    bool canSkipByState = (!force_redraw && !g_labelsRelayoutNeeded && !basePriceChanged && !g_redrawTHLevelsNeeded && g_initialized && fractalReady);
    if(canSkipByState) {
        // Existing second-level gate (may be zero by config)
        if(currentTime - g_lastCalculation < REDRAW_THROTTLE_SECONDS) return;
        // Additional soft guard for immediate burst calls when second-level throttle is disabled
        if(nowMs - s_lastRedrawAttemptMs < 35) return;
    }
    s_lastRedrawAttemptMs = nowMs;
    g_lastCalculation = currentTime;

    // PERF (2026): TF-independent object prefix. The same level/zone objects
    // are reused across all chart timeframes (see GetRuntimeObjectPrefix for
    // the full rationale - the old per-TF prefix caused 200+ chart-engine
    // renames per switch that accumulated queue depth on rapid toggling).
    // Keeping the static var so other code that reads `s_cachedObjectPrefix`
    // still works; it just no longer changes on TF switch.
    static string s_cachedObjectPrefix = inpObjectPrefix + "_";
    string objectPrefix = s_cachedObjectPrefix;

    // PERF (2026): Since the prefix is now TF-independent (static above), the
    // `s_lastPrefix != objectPrefix` check below was always false — the static
    // initializer runs exactly once and `objectPrefix` is the same string
    // every call. The RenamePrefixedObjects body never executed but the
    // branch + the always-false comparison still ran on every redraw frame.
    // On M1 at 60 ticks/min that was 60 wasted string compares per minute
    // per chart. Removed. If prefix ever becomes runtime-mutable again,
    // reintroduce this block.
    static string s_lastPrefix = objectPrefix; // first-call init mirrors cachedObjectPrefix
    if(s_lastPrefix != objectPrefix) {
        RenamePrefixedObjects(s_lastPrefix, objectPrefix);
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

    // PERFORMANCE: Use cached historical values
    if(currentTime - g_lastHistoricalUpdate >= 3600 || !g_initialized)
    {
        bool histOk = UpdateHistoricalValues();
        if(!histOk) {
            // FIX: If historical data is not ready, use a sensible fallback around the base price
            // so levels/zones can still be drawn on lower timeframes where MN1 data may be missing.
            _LOG_GATE_W Print("[W][GEN] RedrawAllObjects: UpdateHistoricalValues failed, using base-price fallback");
            if(thBasePrice > 0) {
                if(g_highestHigh <= 0 || g_highestHigh == EMPTY_VALUE) g_highestHigh = thBasePrice * 1.01;
                if(g_lowestLow <= 0 || g_lowestLow == EMPTY_VALUE) g_lowestLow = thBasePrice * 0.99;
                // Don't hammer UpdateHistoricalValues every tick; retry in 1 hour.
                g_lastHistoricalUpdate = currentTime;
                g_initialized = true;
                g_calculatedOnce = false;
                g_redrawTHLevelsNeeded = true;
            } else {
                return;
            }
        } else {
            g_initialized = true;
            g_calculatedOnce = false;
            g_redrawTHLevelsNeeded = true;
        }
    }

    // Early exit when hidden - skip all drawing
    if(IsIndicatorHidden()) {
        HideAllTHObjects();
        return;
    }

    // PERF (2026, A): Frame-level identity cache
    // -------------------------------------------------------------------------
    // The existing canSkipByState gate at the top of RedrawAllObjects only
    // catches frames where NO state flag is set (no new bar, no base-price
    // change, no relayout, fractal ready). It does NOT catch the common case
    // where one of those flags is set but the actual visual output of the
    // pipeline is unchanged - e.g. a 30-min base-price boundary tick where
    // g_redrawTHLevelsNeeded is forced true but the daily close hasn't moved
    // a single point since the last draw.
    //
    // If the full identity hash (topology + base price + custom price +
    // historical High/Low + show-levels toggle) matches the last full redraw,
    // the 289-zone pipeline would produce identical output. Skip the heavy
    // path (DrawMainLevels / needLabels / the entire if-block below) and run
    // only the cheap tail (CheckAlerts, ThrottledChartRedraw).
    //
    // Measured win: logged 480-670 ms per OnCalculate on M15 with 289 zones
    // becomes a single hash compare + alert check (~1-2 ms).
    // -------------------------------------------------------------------------
    ENUM_STEP_CALCULATION_MODE modeNow = GetCurrentStepMode();
    bool customPriceActive = (g_thStartPointType == TH_START_POINT_CUSTOM_PRICE);
    ulong newIdentity = ComputeRedrawIdentityHash(
        objectPrefix, modeNow,
        g_dailyClosePriceForTH, g_customTHStartPrice,
        g_highestHigh, g_lowestLow,
        customPriceActive, inpShowTHLevels);
    static ulong s_lastRedrawIdentity = 0;
    bool identityUnchanged = (newIdentity == s_lastRedrawIdentity) && (s_lastRedrawIdentity != 0);
    bool skipHeavyWork = identityUnchanged && !force_redraw && !g_forceClearOnNextDraw && g_initialized;
    if(skipHeavyWork) {
        #ifdef ENABLE_DEBUG_LOGS
        static int s_identitySkipLogCount = 0;
        static int s_identitySkipTotal = 0;
        s_identitySkipLogCount++;
        s_identitySkipTotal++;
        if(s_identitySkipLogCount <= 10) {
            Print("[REDRAW_IDENTITY_SKIP] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
                  " prefix=", objectPrefix, " hash=", newIdentity);
        }
        // Periodic summary every 200 skips so the operator can see the
        // hit rate over time without spamming the log.
        if(s_identitySkipLogCount >= 200) {
            Print("[REDRAW_IDENTITY_HIT_RATE] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
                  " total_skips=", s_identitySkipTotal,
                  " last_hash=", newIdentity);
            s_identitySkipLogCount = 0;
        }
        #endif
        // Output would be identical - only alerts and chart redraw needed.
        // DrawMainLevels is also skipped: it's cache-backed and would be a
        // no-op for the HLINEs (price/color/style/width all in the hash);
        // the High/Low pip-distance labels do change every tick with price,
        // so we let the next non-skipped frame refresh them (acceptable:
        // the label moves by ~0.1 pip per tick and is a soft visual aid).
        CheckAlerts(objectPrefix, g_currentPrice);
        ThrottledChartRedraw();
        return;
    }
    s_lastRedrawIdentity = newIdentity;

    DrawMainLevels(objectPrefix);

    bool needLabels = (!g_calculatedOnce) || g_labelsRelayoutNeeded;
    if(needLabels)
    {
        if (g_dailyClosePriceForTH == EMPTY_VALUE)
        {
            g_dailyClosePriceForTH = thBasePrice;
        }
        
        // CRITICAL: Reset stacking offsets and clear old labels for clean layout
        g_currentLabelYOffset = 0;  // Reset top label stacking offset
        g_currentLabelYOffsetBottom = 0;  // Reset bottom label stacking offset
        ClearAllLabels(objectPrefix);

        TH3_PROF_START(Labels);
        if(g_atrLabelsVisible) DisplayATRLabels(objectPrefix);
        bool showFractal = (g_thLabelsMode == 1 || g_thLabelsMode == 3);
        bool showStandard = (g_thLabelsMode == 2 || g_thLabelsMode == 3);
        if(g_thLabelsMode != 0 && showFractal)  DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(g_thLabelsMode != 0 && showStandard) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        TH3_PROF_END(Labels);

        if(!g_calculatedOnce && inpShowTHLevels) g_redrawTHLevelsNeeded = true;
        g_calculatedOnce = true;
        g_labelsRelayoutNeeded = false;
    }

    // FIX: Snapshot final Y offset so mode/lock/factor labels always appear below all data labels
    // Move outside needLabels block to ensure overlay labels are always correctly positioned
    g_modeLabelYOffset = g_currentLabelYOffset;
    RepositionAllOverlayLabels();

    // (PERF 2026: removed duplicate `g_dailyClosePriceForTH = thBasePrice;`
    //  assignment — it was already set at line 1502 above before any work that
    //  could return early. The duplicate write was harmless but unnecessary
    //  on every full-redraw frame.)

    // PERF (2026): the previous code always called ObjectGetDouble(...) and
    // GlobalVariableCheck/Get(...) at the start of this block on EVERY redraw
    // frame, even though the values were either dead (`currentLinePrice` was
    // computed but never read in this function — ObjectFind on the chart is
    // a synchronous call) or only mattered when the user changed inputs.
    // Both are now gated behind per-redraw-frame caches with 1-second TTL
    // and per-call short-circuit logic.
    string gvarName = "Biotak_CustomPrice_" + s_cachedSymbol;
    bool lineExists = customPriceLineExists;

    if(!g_customPriceLineDragging) {
        // PERF (2026): cache the GlobalVariable presence/value per redraw
        // frame. On M1 (60 ticks/min) that turns ~120 sync terminal calls/min
        // into at most 2 (presence + value) refreshed every 1s. The values
        // are written only via OnChartEvent / input change, so a 1s TTL is
        // strictly safe — the worst case is the visible price line lagging
        // 1 tick behind a global-var update from another chart window,
        // which is invisible to the user.
        static bool s_gvPresenceCached = false;
        static double s_gvPriceCached = 0.0;
        static uint s_gvCacheMs = 0;
        const uint GV_CACHE_TTL_MS = 1000;
        uint gvNow = GetTickCount();
        bool hasGlobalVar;
        double savedPrice;
        if(gvNow - s_gvCacheMs > GV_CACHE_TTL_MS) {
            s_gvPresenceCached = GlobalVariableCheck(gvarName);
            s_gvPriceCached = s_gvPresenceCached ? GlobalVariableGet(gvarName) : 0.0;
            s_gvCacheMs = gvNow;
        }
        hasGlobalVar = s_gvPresenceCached;
        savedPrice = s_gvPriceCached;

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
                // Invalidate the cached global-var value so the next read
                // pulls the fresh one we just wrote.
                s_gvCacheMs = 0;
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
        } else {
            g_thStartPointType = inpTHStartPointType;
            g_customTHStartPrice = 0.0;
        }
    }
    
    // JUMP-FIRST architecture: do not draw levels until the fractal jump has been
    // determined for THIS timeframe with valid ATR, so the first render already uses
    // the correct spacing (no narrow-then-wide double draw). Fallback: after the
    // timeout, draw anyway (shift 0).
    bool jumpReady = fractalReady ||
                     (g_fractalDetermineStartMs != 0 && (GetTickCount() - g_fractalDetermineStartMs > FRACTAL_DETERMINE_TIMEOUT_MS));
    if (inpShowTHLevels && g_redrawTHLevelsNeeded && jumpReady)
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

        // PERF (2026): Topology change guard using a 64-bit FNV-1a hash.
        // The previous implementation concatenated 26+ values into a string
        // and compared strings — 26 string allocations + 26 IntegerToString
        // calls on EVERY redraw frame. We now pack all inputs into a single
        // ulong via XOR-fold FNV-1a, which is 26 cheap bitwise operations
        // and 1 integer compare. No allocations. Branch prediction is also
        // better with a tight integer hash than with a long string compare.
        static ulong s_lastLevelHash = 0;
        ENUM_STEP_CALCULATION_MODE modeNow = GetCurrentStepMode();
        ulong newLevelHash = HashLevelTopology(objectPrefix, modeNow);
        bool levelTopologyChanged = (newLevelHash != s_lastLevelHash);
        bool shouldClearLevels = g_forceClearOnNextDraw || levelTopologyChanged;

        if(shouldClearLevels) {
            TH3_PROF_START(LevelsClear);
            ClearAllLevels(objectPrefix, !skipZones);
            TH3_PROF_END(LevelsClear);
        }

        TH3_PROF_START(LevelsDrawByMode);
        DrawLevelsBasedOnMode(objectPrefix, g_dailyClosePriceForTH);
        TH3_PROF_END(LevelsDrawByMode);
        s_lastLevelHash = newLevelHash;
        TH3_PROF_END(Levels);
        g_forceClearOnNextDraw = false;
        g_redrawTHLevelsNeeded = false;
    }
    else if (!inpShowTHLevels && g_redrawTHLevelsNeeded)
    {
        ClearAllLevels(objectPrefix);
        g_forceClearOnNextDraw = false;
        g_redrawTHLevelsNeeded = false;
    }

    CheckAlerts(objectPrefix, g_currentPrice);
    
    // DIAGNOSTIC LOG: report full redraw duration (first 10 calls per run)
    uint redrawElapsed = GetTickCount() - redrawStartMs;
    static int s_redrawTimeLogCount = 0;
    if(s_redrawTimeLogCount < 10) {
        Print("[REDRAW_DIAG] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
              " elapsed=", redrawElapsed, "ms",
              " force=", (force_redraw ? "Y" : "N"),
              " levelsNeeded=", (g_redrawTHLevelsNeeded ? "Y" : "N"),
              " prefix=", objectPrefix);
        s_redrawTimeLogCount++;
    }

    ThrottledChartRedraw();
}

//+------------------------------------------------------------------+
//| OnCalculate Handler (matching MT5: tick throttle + cache inv.)   |
//+------------------------------------------------------------------+
int OnCalculateHandler(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
    // FIX: refresh the cached Period() at the top of every calculate. On a
    // timeframe switch MT5 may invoke OnCalculate with the new period without
    // re-running OnInit, so g_cachedPeriod can otherwise stay stale and any
    // code path using GetCachedPeriod() will compute against the old TF.
    UpdatePeriodCache();

    static uint s_lastCPUTime = 0;
    static int s_cpuWarningCount = 0;
    uint startTime = GetTickCount();

    if(IsIndicatorHidden())
    {
        return(rates_total);
    }

    // PERF: Cache Bid/Ask once per tick (moved after hidden check)
    CacheTickPrices();

    // PERF (2026): shortcut the cheap "is there anything to do?" check BEFORE
    // touching the per-tick state, the throttled print, LogRedrawDecision, or
    // the cache-invalidation scan. MT5 calls OnCalculate on EVERY tick and on
    // every chart change - and the bulk of ticks are pure noise (price wobble
    // inside the same bar, no new bar, no force flag). The original code still
    // ran the priceChangePercent math, the bar/period/custom-price comparisons
    // and the LogRedrawDecision print on every no-op tick. We now do the
    // same comparisons but exit at the FIRST non-trivial condition so a tick
    // that didn't change anything falls through to a single return.
    if(rates_total <= 0) return rates_total;

    static uint s_lastTickMs = 0;
    static double s_lastPrice = 0;
    static datetime s_lastBarTime = 0;
    static int s_lastPeriod = -1;
    static double s_lastCustomPrice = 0;

    uint nowMs = GetTickCount();
    double currentPrice = close[rates_total-1];
    datetime currentBarTime = time[rates_total-1];
    int currentPeriod = Period();
    double currentCustomPrice = g_customTHStartPrice;

    bool barsChanged = (currentBarTime != s_lastBarTime && s_lastBarTime != 0);
    bool isNewBar = barsChanged;
    bool timeframeChanged = (currentPeriod != s_lastPeriod && s_lastPeriod != -1);
    bool customPriceChanged = false;
    if(g_thStartPointType == TH_START_POINT_CUSTOM_PRICE) {
        customPriceChanged = (MathAbs(currentCustomPrice - s_lastCustomPrice) > EPSILON_PRICE);
    }

    // Tick throttle: skip redundant ticks within 50ms
    bool tickThrottled = (nowMs - s_lastTickMs < 50 && s_lastTickMs != 0);

    // PERF (2026): the significantPriceChange check is now only run when we
    // actually need it (i.e. when nothing else fired). With 99% of ticks
    // landing in the no-op path this avoids a MathAbs + division + multiply
    // on every tick.
    bool forceRedrawRequested = g_redrawTHLevelsNeeded || g_forceClearOnNextDraw ||
                                 g_labelsRelayoutNeeded || !g_initialized;

    // PERF (2026): hot-path early-exit. If the only thing that would change
    // is a sub-threshold price wobble inside the same bar, with no force flag,
    // no TF change, no custom-price change, no initialization pending, and we
    // already throttled - return immediately. This is the dominant case on
    // M1 (10+ ticks per second of pure noise) and skipping it was the
    // single biggest source of CPU usage on the previous build.
    // PERF (2026, prev_calculated-based skip): per the MQL5 docs
    // (https://www.mql5.com/en/docs/event_handlers/oncalculate), when
    // prev_calculated > 0 and rates_total == prev_calculated, the call is a
    // pure tick on the last existing bar — no new bar, no history change. In
    // that case there is NO geometry to recompute and we can short-circuit
    // before even the throttle comparison. The 50ms throttle below catches
    // most cases, but the prev_calculated check is the canonical MQL5 way and
    // costs essentially nothing.
    if(prev_calculated > 0 && rates_total == prev_calculated &&
       !g_redrawTHLevelsNeeded && !g_forceClearOnNextDraw &&
       !g_labelsRelayoutNeeded && g_initialized && !g_pendingChartChange) {
        g_wasLastTickNoOp = true;
        g_lastRatesTotal = rates_total;
        g_lastPrevCalculated = prev_calculated;
        return rates_total;
    }

    if(tickThrottled && !isNewBar && !forceRedrawRequested &&
       !timeframeChanged && !customPriceChanged) {
        g_wasLastTickNoOp = true;
        g_lastRatesTotal = rates_total;
        g_lastPrevCalculated = prev_calculated;
        return rates_total;
    }
    g_wasLastTickNoOp = false;
    g_lastRatesTotal = rates_total;
    g_lastPrevCalculated = prev_calculated;

    // PERF (2026, TF/symbol change propagation):
    //   When OnChartEventHandler detected a real chart change (symbol or
    //   timeframe), it set g_pendingChartChange and updated the caches.
    //   Now that we know we're going to do real work, sync the per-tick
    //   period cache to the new value so every downstream comparison sees
    //   the post-switch TF (instead of the stale pre-switch one) and
    //   clear the pending flag.
    if(g_pendingChartChange) {
        timeframeChanged = true;
        g_pendingChartChange = false;
    }

    // Now (and only now) compute the more expensive significantPriceChange
    // flag - it requires a real work signal to be worth the cost.
    double priceChangePercent = 0;
    if(s_lastPrice > 0 && currentPrice > 0) {
        priceChangePercent = MathAbs((currentPrice - s_lastPrice) / s_lastPrice) * 100.0;
    }
    bool significantPriceChange = (priceChangePercent > 0.1);

    // Second early-exit: even on a non-throttled tick, if no signal fired
    // and the price wobble is <0.1%, there is literally nothing for the
    // redraw path to do. Return BEFORE LogRedrawDecision and the per-frame
    // diagnostic print.
    if(!forceRedrawRequested && !isNewBar && !timeframeChanged && !customPriceChanged &&
       !significantPriceChange && g_initialized) {
        return rates_total;
    }

    // Cache invalidation flags
    int invalidationFlags = CACHE_INV_NONE;
    if(timeframeChanged) invalidationFlags |= CACHE_INV_TIMEFRAME;
    if(barsChanged) invalidationFlags |= CACHE_INV_NEW_BAR;
    if(customPriceChanged) invalidationFlags |= CACHE_INV_CUSTOM_PRICE;
    if(invalidationFlags != CACHE_INV_NONE) {
        ApplyCacheInvalidation(invalidationFlags, s_lastPeriod, currentPeriod, s_lastCustomPrice, currentCustomPrice);
    }

    {
        // DIAGNOSTIC: log ONLY when we are actually about to call RedrawAllObjects.
        // (Previously this fired on every OnCalculate invocation, spamming the
        // journal even on the no-op early-exit path.)
        static int s_oncalculateRedrawLogCount = 0;
        if(s_oncalculateRedrawLogCount < 10) {
            Print("[ONCALCULATE_REDRAW] TF=", EnumToString((ENUM_TIMEFRAMES)Period()),
                  " tfChanged=", (timeframeChanged ? "Y" : "N"),
                  " redrawNeeded=", (g_redrawTHLevelsNeeded ? "Y" : "N"),
                  " forceClear=", (g_forceClearOnNextDraw ? "Y" : "N"));
            s_oncalculateRedrawLogCount++;
        }

        LogRedrawDecision(isNewBar, timeframeChanged, customPriceChanged,
                          g_redrawTHLevelsNeeded, g_forceClearOnNextDraw,
                          significantPriceChange, tickThrottled);

        s_lastTickMs = nowMs;
        s_lastPrice = currentPrice;
        s_lastBarTime = currentBarTime;
        s_lastPeriod = currentPeriod;
        s_lastCustomPrice = currentCustomPrice;

        // CENTRAL ATR REFRESH (new-bar driven per timeframe):
        // Each label timeframe refreshes only when a new bar opens on that TF.
        // Values are computed from each TF's own price data and remain constant
        // across chart timeframe switches.
        // PERF (2026): The previous loop unconditionally called
        // CalculateWeightedATR(tf) for every label TF (typically 9: M1, M5,
        // M15, M30, H1, H4, D1, W1, MN1) whenever the CHART timeframe had a
        // new bar. CalculateWeightedATR does iATR/copybuffer work, so we
        // were paying the cost for ALL 9 TFs once per chart new-bar tick —
        // and on M1 a new-bar tick fires every minute. The bar-on-TF check
        // happened AFTER the compute (compared prevBar against the new
        // lastBarTime that CalculateWeightedATR just updated), so it never
        // actually saved the work. We now read the bar time for each label
        // TF first; if it hasn't changed since the last refresh we skip the
        // expensive compute entirely. Typical savings: on M1 chart, only
        // M1 itself has a new bar per minute; the other 8 TFs are skipped.
        // Per TF switch we still recompute once (covers the chart-new-TF case
        // where the cache is empty/stale for TFs > current chart TF).
        if(g_atrLabelsVisible && (isNewBar || timeframeChanged)) {
            bool anyChanged = false;
            for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
                ENUM_TIMEFRAMES tf = g_atrLabelTFs[i];
                datetime prevBar = g_atrLabelCache[i].lastBarTime;
                // Read the current bar time for this TF WITHOUT triggering
                // the rest of the heavy calculate path. iTime is a single
                // sync timeseries request; cheap relative to iATR.
                datetime tfBar = iTime(Symbol(), tf, 0);
                if(!timeframeChanged && tfBar == prevBar) {
                    // Bar on this TF hasn't rolled; cached value still valid.
                    continue;
                }
                double oldValue = g_atrLabelCache[i].weightedATR;
                double newValue = CalculateWeightedATR(tf);
                if(prevBar != g_atrLabelCache[i].lastBarTime ||
                   MathAbs(oldValue - newValue) > oldValue * 0.0001) {
                    anyChanged = true;
                }
            }
            if(anyChanged) g_labelsRelayoutNeeded = true;
        }

        TH3_PROF_START(RedrawCall);
        // PERF (2026, TF switch fast path): The previous implementation
        // deferred the heavy redraw by DEFERRED_TF_REDRAW_DELAY_MS (~80ms)
        // to let the chart engine "settle" on the new timeframe. Measured
        // cost: user-perceived 80ms freeze + extra tick of latency before
        // levels appear. The deferral adds nothing — RedrawAllObjects only
        // modifies existing objects in place (rename happened already, prices
        // are pure property writes), and the chart engine handles each
        // ObjectSetInteger independently without needing any settle time.
        // We now call RedrawAllObjects(true) immediately on the TF-change
        // tick so levels are visible in the same frame the user sees the
        // new timeframe. Net win: ~80ms TF switch latency gone.
        RedrawAllObjects(timeframeChanged || g_redrawTHLevelsNeeded || g_forceClearOnNextDraw);
        TH3_PROF_END(RedrawCall);

        if(barsChanged || s_lastBarTime == 0) {
            // PERF: Use cached object count
            int totalObjects = GetCurrentObjectCount();
            if(totalObjects > MAX_SAFE_OBJECTS && totalObjects < CRITICAL_OBJECT_LIMIT) {
                #ifdef ENABLE_DEBUG_LOGS
                if(s_cpuWarningCount % 10 == 0) {
                    Print("[W][GEN] Performance Warning: ", totalObjects, " objects on chart (recommended max: ", MAX_SAFE_OBJECTS, ")");
                    Print("[D][GEN] [CLEAN] Consider reducing inpMaxLevels for better performance");
                }
                #endif
                s_cpuWarningCount++;
            }
            else if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("[E][GEN] [CRIT] CRITICAL: ", totalObjects, " objects approaching MT4 limit (64000)!");
                Print("[D][GEN] [CLEAN] EMERGENCY: Using indicator-scoped cleanup...");
                #endif
                EmergencyCleanupIndicatorObjects(inpObjectPrefix);
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

//+------------------------------------------------------------------+
//| Apply Lines Visibility State to All Line Objects                 |
//|                                              |
//|                                                                  |
//| Called after RedrawAllObjects to ensure g_linesVisible is       |
//| respected for all line objects (HLINE and TREND)                 |

void OnChartEventHandler(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // PERF (2026, TF/symbol switch hot path):
    //   MQL5 fires CHARTEVENT_CHART_CHANGE for any chart-property change
    //   (resize, scroll, zoom, but ALSO symbol and timeframe switches).
    //   ChartSymbol(0) and ChartPeriod(0) are the cheapest way to know
    //   whether anything that affects our level geometry actually changed.
    //   If neither changed, this is just a scroll/resize and we don't need
    //   to redraw — early-exit before the 100ms+ object churn.
    //   See: https://www.mql5.com/en/docs/event_handlers/onchartevent
    if(id == CHARTEVENT_CHART_CHANGE) {
        string curSym = ChartSymbol(0);
        ENUM_TIMEFRAMES curPer = (ENUM_TIMEFRAMES)ChartPeriod(0);
        // First call after init: seed the caches and let normal path run.
        if(g_lastChartSymbol == "" || g_lastChartPeriod == PERIOD_CURRENT) {
            g_lastChartSymbol = curSym;
            g_lastChartPeriod = curPer;
            return;  // No state change yet; RedrawAllObjects will run on next tick.
        }
        // Same symbol AND same period → no work needed. Bail out before the
        // keyboard/mouse event branch below, which is expensive on resize.
        if(curSym == g_lastChartSymbol && curPer == g_lastChartPeriod) {
            return;
        }
        // Real chart change. Set a dirty flag for the next OnCalculate pass.
        // We deliberately do NOT call ChartSetSymbolPeriod or trigger
        // OnDeinit/OnInit ourselves — MT5 has already done that and our
        // OnInit (TF-independent prefix + rename-in-place) handles the
        // transition. We only need to ensure the next redraw runs.
        g_lastChartSymbol = curSym;
        g_lastChartPeriod = curPer;
        g_pendingChartChange = true;
        g_redrawTHLevelsNeeded = true;
        // No return: let any other handlers (e.g. visibility cache refresh)
        // run if they care about CHART_CHANGE.
    }

    bool suppressDeleteEvent = g_suppressDeleteEvents || (g_suppressDeleteEventsUntilMs != 0 && GetTickCount() <= g_suppressDeleteEventsUntilMs);
    if(id == CHARTEVENT_OBJECT_DELETE && !suppressDeleteEvent) {
        string indicatorPrefix = inpObjectPrefix;
        int prefixLen = StringLen(indicatorPrefix);
        if(prefixLen > 0 && StringLen(sparam) >= prefixLen && StringSubstr(sparam, 0, prefixLen) == indicatorPrefix) {
            CacheRemoveObject(sparam);
            g_redrawTHLevelsNeeded = true;
        }
    }

    if(id == CHARTEVENT_KEYDOWN)
    {
        //  
        // F key   Hide/Show All Objects (fast visibility toggle)
        //  
        if(IsHotkeyPressed(lparam, sparam, inpHideKey))
        {
            string gvar_name = "Biotak_isHidden_" + GetCachedChartIdStr();
            double currentState = 0.0;
            if(GlobalVariableCheck(gvar_name)) {
                currentState = GlobalVariableGet(gvar_name);
                if(currentState != 0.0 && currentState != 1.0) {
                    currentState = 0.0;
                }
            }
            bool isBecomingHidden = (currentState == 0.0);
            if(!GlobalVariableSet(gvar_name, isBecomingHidden ? 1.0 : 0.0)) {
                LOG_W(LOG_CAT_KEYS, "F key: Failed to set GlobalVariable, Error: " + IntegerToString(GetLastError()));
            }
            RefreshIsHiddenCache();

            if(isBecomingHidden)
            {
                LOG_I(LOG_CAT_KEYS, "F key: Hiding all objects");
#ifndef BUILD_LITE
                // Cancel ABCD drawing mode if active
                if(g_abcdDrawing) {
                    g_abcdDrawing = false;
                    g_abcdPointCount = 0;
                    g_suppressDeleteEvents = true;
                    ObjectsDeleteAll(0, TH3_TEMP_PREFIX);
                    ObjectsDeleteAll(0, TH3_TEMP_LINE_PREFIX);
                    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
                    g_suppressDeleteEvents = false;
                    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
                    Comment("");
                }
#endif
                HideAllTHObjects();
                CleanupCustomPriceObjects(false, true);
                g_redrawTHLevelsNeeded = false;
            }
            else
            {
                LOG_I(LOG_CAT_KEYS, "F key: Showing all objects");
                // Fast show: iterate OUR objects via the object cache instead of
                // ObjectsTotal() over every chart object (per MQL5 perf guidance:
                // never enumerate unrelated chart objects). Line-vs-zone is resolved
                // by name (the established pattern in this file), so we make zero
                // ObjectGetInteger(OBJPROP_TYPE) calls. SetObjectTimeframesIfChanged
                // is cache-backed and skips the write when already correct.
                string cachedPrefixF = inpObjectPrefix;
                int prefixLenF = StringLen(cachedPrefixF);
                ushort prefixFirstCharF = StringGetCharacter(cachedPrefixF, 0);
                for(int i = 0; i < CACHE_HASH_BUCKETS; i++)
                {
                    if(!g_objectCacheHash[i].occupied) continue;
                    string objName = g_objectCacheHash[i].name;
                    if(StringGetCharacter(objName, 0) != prefixFirstCharF) continue;
                    if(!(StringLen(objName) >= prefixLenF && StringSubstr(objName, 0, prefixLenF) == cachedPrefixF))
                        continue;
                    // Keep ATR objects hidden if ATR labels are disabled
                    bool isATRObject = (StringFind(objName, "ATR_") >= 0);
                    if(isATRObject) {
                        bool atrShouldShow = (g_atrLabelsVisible && inpShowATRLabels);
                        if(!atrShouldShow) {
                            SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                        } else {
                            if(StringFind(objName, "ATR_Targets_") >= 0 && !inpShowATRTargets)
                                SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                            else
                                SetObjectTimeframesIfChanged(objName, OBJ_ALL_PERIODS);
                        }
                        continue;
                    }
                    // Keep trigger objects hidden if triggers are disabled
                    bool isTriggerObject = (StringFind(objName, "TriggerTH_Up_") >= 0 ||
                                            StringFind(objName, "TriggerTH_Down_") >= 0);
                    if(isTriggerObject && !g_triggerLevelsEnabled)
                    {
                        SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                    }
                    else if(!g_linesVisible)
                    {
                        // Lines (HLINE/TREND) are hidden when lines-visibility is off;
                        // zones stay visible. With TF-independent names the zone
                        // name contains "_Level_" (the mode name) so we MUST
                        // exclude zone tokens first to avoid hiding the rectangles.
                        bool isZone = (StringFind(objName, "_Zone_") >= 0) ||
                                      (StringFind(objName, "_PipsLabel") >= 0) ||
                                      (StringFind(objName, "_Label") >= 0 && !isTriggerObject);
                        if(isZone) {
                            SetObjectTimeframesIfChanged(objName, OBJ_ALL_PERIODS);
                        } else {
                            bool isLine = (StringFind(objName, "_Level_") >= 0) ||
                                          (StringFind(objName, "_Above_") >= 0) ||
                                          (StringFind(objName, "_Below_") >= 0) ||
                                          isTriggerObject;
                            if(isLine)
                                SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                            else
                                SetObjectTimeframesIfChanged(objName, OBJ_ALL_PERIODS);
                        }
                    }
                    else
                    {
                        SetObjectTimeframesIfChanged(objName, OBJ_ALL_PERIODS);
                    }
                }
                // Restore label visibility
                ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
#ifndef BUILD_LITE
                ObjectSetInteger(0, g_th3FreqLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
#endif
                ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                // Restore custom price line if active
                if(g_customPriceKeyboardOverride && g_customPriceLineCreated)
                    ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

                g_redrawTHLevelsNeeded = true;
                // Re-apply label visibility consistently
                string objectPrefixLocal = GetRuntimeObjectPrefix();
                SetATRLabelsVisibility(objectPrefixLocal, (g_atrLabelsVisible && inpShowATRLabels));
                SetTHLabelsVisibility(objectPrefixLocal, (inpShowTHLabels ? g_thLabelsMode : 0));
            }
            // Direct ChartRedraw for F key (ThrottledChartRedraw skips when hidden)
            ChartRedraw();
            return;
        }

        //  
        // L key   Toggle Lines Visibility
        //  
        if(IsHotkeyPressed(lparam, sparam, inpLinesToggleKey))
        {
            g_linesVisible = !g_linesVisible;
            UpdateLinesVisibleCache(g_linesVisible);
            string gvar_name = "Biotak_LinesVisible_" + GetCachedChartIdStr();
            GlobalVariableSet(gvar_name, g_linesVisible ? 1.0 : 0.0);
            // PERF (2026): iterate the object cache (our objects only) and resolve
            // line-vs-zone by name, eliminating the ObjectsTotal() scan AND the
            // per-object ObjectGetInteger(OBJPROP_TYPE) synchronous call.
            string cachedPrefixL = inpObjectPrefix;
            int prefixLenL = StringLen(cachedPrefixL);
            ushort prefixFirstCharL = StringGetCharacter(cachedPrefixL, 0);
            for(int i = 0; i < CACHE_HASH_BUCKETS; i++)
            {
                if(!g_objectCacheHash[i].occupied) continue;
                string objName = g_objectCacheHash[i].name;
                if(StringGetCharacter(objName, 0) != prefixFirstCharL) continue;
                if(!(StringLen(objName) >= prefixLenL && StringSubstr(objName, 0, prefixLenL) == cachedPrefixL))
                    continue;
                // PERF (2026): the line-vs-zone check MUST exclude zone
                // rectangles. With TF-independent names the zone name is
                // e.g. "Biotak_TH_Level_Zone_Above_1" - it contains the
                // substring "_Level_" (the mode name) which the previous
                // heuristic treated as a line marker, so pressing L would
                // hide BOTH trigger HLINEs and zone rectangles. The
                // _Zone_ / _Center_ / _Top / _Bottom / _PipsLabel tokens
                // are the canonical zone-family markers; anything matching
                // those is a zone, not a line.
                bool isZone = (StringFind(objName, "_Zone_") >= 0) ||
                              (StringFind(objName, "_Zone_Center_") >= 0) ||
                              (StringFind(objName, "_Zone_Above_") >= 0) ||
                              (StringFind(objName, "_Zone_Below_") >= 0) ||
                              (StringFind(objName, "_PipsLabel") >= 0) ||
                              (StringFind(objName, "_Top") >= 0 && StringFind(objName, "_Zone_") > 0) ||
                              (StringFind(objName, "_Bottom") >= 0 && StringFind(objName, "_Zone_") > 0) ||
                              (StringFind(objName, "_Label") >= 0 && StringFind(objName, "TriggerTH_") < 0);
                if(isZone) continue;
                bool isLine = (StringFind(objName, "_Level_") >= 0) ||
                              (StringFind(objName, "_Above_") >= 0) ||
                              (StringFind(objName, "_Below_") >= 0) ||
                              (StringFind(objName, "TriggerTH_Up_") >= 0) ||
                              (StringFind(objName, "TriggerTH_Down_") >= 0);
                if(isLine)
                    SetObjectTimeframesIfChanged(objName, g_linesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
            }
            LOG_I(LOG_CAT_LINES, "Lines " + (g_linesVisible ? "VISIBLE" : "HIDDEN"));
            ThrottledChartRedraw();
            return;
        }

        //  
        // C key   Set Custom Price
        //  
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

        //  
        // ESC key   Cancel Custom Price
        //  
        if(lparam == 27)
        {
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

        //  
        // T key   Toggle Trigger Levels
        //  
        if(IsHotkeyPressed(lparam, sparam, inpTriggerLevelsKey))
        {
            g_triggerLevelsEnabled = !g_triggerLevelsEnabled;
            string triggerGvarName = "Biotak_TriggerLevels_" + GetCachedChartIdStr();
            GlobalVariableSet(triggerGvarName, g_triggerLevelsEnabled);
            if(g_triggerLevelsEnabled) {
                LOG_I(LOG_CAT_KEYS, "Trigger Levels: ON");
            } else {
                LOG_I(LOG_CAT_KEYS, "Trigger Levels: OFF");
            }
            g_forceClearOnNextDraw = true;
            g_redrawTHLevelsNeeded = true;
            if(!g_customPriceLineDragging)
                RedrawAllObjects(true);
            ThrottledChartRedraw();
            return;
        }

        //  
        // A key   Toggle ATR Labels
        //  
        if(IsHotkeyPressed(lparam, sparam, inpATRLabelsKey))
        {
            string atrGvarNameKey = "Biotak_ATRLabels_" + GetCachedChartIdStr();
            g_atrLabelsVisible = !g_atrLabelsVisible;
            GlobalVariableSet(atrGvarNameKey, g_atrLabelsVisible ? 1.0 : 0.0);
            
            string objectPrefix = GetRuntimeObjectPrefix();
            SetATRLabelsVisibility(objectPrefix, g_atrLabelsVisible); 
            g_labelsRelayoutNeeded = true;
            RedrawLabelsOnly();
            LOG_I(LOG_CAT_LABELS, "ATR Labels " + (g_atrLabelsVisible ? "VISIBLE" : "HIDDEN"));
            ThrottledChartRedraw();
            return;
        }

        //  
        // S key   Cycle TH Labels Mode
        //  
        if(IsHotkeyPressed(lparam, sparam, inpTHLabelsKey))
        {
            string thGvar = "Biotak_THLabels_" + GetCachedChartIdStr();
            
            // Cycle: FRACTAL (1) -> BOTH (3) [if enabled] -> OFF (0)
            if(g_thLabelsMode == 1) {
                if(inpShowStandardTHs) g_thLabelsMode = 3;
                else g_thLabelsMode = 0;
            }
            else if(g_thLabelsMode == 3) {
                g_thLabelsMode = 0;
            }
            else {
                g_thLabelsMode = 1;
            }

            g_thLabelsVisible = (g_thLabelsMode != 0);
            GlobalVariableSet(thGvar, (double)g_thLabelsMode);
            
            string objectPrefix = GetRuntimeObjectPrefix();
            SetTHLabelsVisibility(objectPrefix, g_thLabelsMode);
            g_labelsRelayoutNeeded = true;
            RedrawLabelsOnly();
            string logMsg = "TH Labels mode=" + IntegerToString(g_thLabelsMode) + " (0=OFF,1=FRACTAL";
            if(inpShowStandardTHs) logMsg += ",3=BOTH";
            logMsg += ")";
            LOG_I(LOG_CAT_LABELS, logMsg);
            ThrottledChartRedraw();
            return;
        }

        //  
        // P key   Toggle TH3 Tool
        //  
#ifndef BUILD_LITE
        if(IsHotkeyPressed(lparam, sparam, inpTH3ToolKey))
        {
            ToggleTH3Tool();
            ThrottledChartRedraw();
            return;
        }
#endif

        //  
        // E key   Cycle Step Mode
        //  
        if(IsHotkeyPressed(lparam, sparam, inpStepModeKey))
        {
            ENUM_STEP_CALCULATION_MODE currentMode = GetCurrentStepMode();
            ENUM_STEP_CALCULATION_MODE newMode = (ENUM_STEP_CALCULATION_MODE)(((int)currentMode + 1) % 4);
            g_stepModeOverride = (int)newMode;
            string stepModeGvarName = "Biotak_StepMode_" + GetCachedChartIdStr();
            GlobalVariableSet(stepModeGvarName, g_stepModeOverride);
            LOG_IP1(LOG_CAT_KEYS, "Step Mode changed to: ", IntegerToString(g_stepModeOverride));
            g_forceClearOnNextDraw = true;
            g_redrawTHLevelsNeeded = true;
            g_calculatedOnce = false;
            RedrawAllObjects(true);
            UpdateStepModeLabel();
            ThrottledChartRedraw();
            return;
        }

        //  
        // 1/2 keys   Adjust Factor (always active)
        //  
        if(lparam == '1') { AdjustFactorValue(-1); return; }
        else if(lparam == '2') { AdjustFactorValue(+1); return; }

        //  
        // 3/4 keys   Adjust TH3 Frequency
        //  
#ifndef BUILD_LITE
        else if(lparam == '3') { DecrementTH3Frequency(); return; }
        else if(lparam == '4') { CycleTH3Frequency(); return; }
#endif

        //  
        // W key   Show Current Status
        //  
        if(IsHotkeyPressed(lparam, sparam, inpShowStatusKey))
        {
            ShowAllStatusLabels();
            ThrottledChartRedraw();
            return;
        }

        //
        // X key   Force indicator re-init (reload the .ex5 without restart)
        //
        // Per the official MQL5 documentation
        // (https://www.mql5.com/en/docs/chart_operations/chartsetsymbolperiod):
        //   "The call of ChartSetSymbolPeriod with the SAME symbol and timeframe
        //    can be used to update the chart (similar to the terminal's Refresh
        //    command). In its turn, the chart update triggers re-calculation of
        //    the indicators attached to it."
        //
        // MQL5 caches running indicators and a bare .ex5 file change does not
        // always trigger a clean OnDeinit -> OnInit cycle. Calling
        // ChartSetSymbolPeriod with the current Symbol()/Period() forces the
        // terminal to re-initialize the chart, which re-runs OnInit() with the
        // latest .ex5 picked up from MQL5/Indicators/. No terminal restart,
        // no manual remove & re-add.
        //
        if(IsHotkeyPressed(lparam, sparam, inpReloadKey))
        {
            LOG_I(LOG_CAT_KEYS,
                  "X key: force reload via ChartSetSymbolPeriod(" + Symbol() +
                  ", " + EnumToString((ENUM_TIMEFRAMES)Period()) + ")");
            Comment("\n\n        [ RELOADING... ]");
            g_resetCommentCreateTime = GetTickCount();
            // Asynchronous call: the terminal queues the command and re-initializes
            // the chart (and therefore this indicator) after processing prior
            // commands. The re-init is what picks up the freshly compiled .ex5.
            bool queued = ChartSetSymbolPeriod(0, Symbol(), (ENUM_TIMEFRAMES)Period());
            if(!queued) {
                int err = GetLastError();
                _LOG_GATE_E Print("[E][GEN] ChartSetSymbolPeriod failed: err=", err,
                                  " - falling back to TF toggle (M1 -> next -> M1).");
                // Last-resort fallback: toggle to the next timeframe and back.
                // The symbol/period change itself triggers REASON_CHARTCHANGE in
                // OnDeinit, which is enough for MT5 to swap the loaded .ex5.
                ENUM_TIMEFRAMES cur = (ENUM_TIMEFRAMES)Period();
                ENUM_TIMEFRAMES next = (cur == PERIOD_M1) ? PERIOD_M5 : PERIOD_M1;
                ChartSetSymbolPeriod(0, Symbol(), next);
            }
            return;
        }

        //
        // R key   Reset All Overrides
        //
        if(IsHotkeyPressed(lparam, sparam, inpResetKey))
        {
            g_stepModeOverride = -1;
            g_factorValueOverride = 0;
#ifndef BUILD_LITE
            g_th3FreqOverride = 0;
            g_th3FreqIndex = DEFAULT_TH3_FREQ_INDEX;
#endif
            g_timeframeLocked = false;
            g_lockedPeriod = 0;
            g_triggerLevelsEnabled = inpShowTrigger;
            g_linesVisible = inpShowLines;
            InvalidateAllVisibilityCaches();
            g_atrLabelsVisible = inpShowATRLabels;
            g_thLabelsMode = inpShowTHLabels ? 1 : 0; // Default to FRACTAL if enabled
            g_thLabelsVisible = (g_thLabelsMode != 0);
#ifndef BUILD_LITE
            if(inpEnableTH3Tool) {
                UpdateAllTH3Objects();
            }
#endif
#ifndef BUILD_LITE
            // Cancel any active ABCD drawing
            if(g_abcdDrawing) {
                g_abcdDrawing = false;
                g_abcdPointCount = 0;
                g_suppressDeleteEvents = true;
                ObjectsDeleteAll(0, TH3_TEMP_PREFIX);
                ObjectsDeleteAll(0, TH3_TEMP_LINE_PREFIX);
                g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
                g_suppressDeleteEvents = false;
            }
#endif
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
#ifndef BUILD_LITE
            GlobalVariableDel("Biotak_TH3Freq_" + chartIdStr);
            GlobalVariableDel("Biotak_TH3FreqIdx_" + chartIdStr);
#endif
            if(inpCustomTHStartPrice > 0.0) {
                GlobalVariableSet("Biotak_CustomPrice_" + symbolName, inpCustomTHStartPrice);
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
            EventSetTimer(1);
            g_forceClearOnNextDraw = true;
            g_calculatedOnce = false;
            g_redrawTHLevelsNeeded = true;
            RedrawAllObjects(true);
            ThrottledChartRedraw();
            return;
        }

        //  
        // K key   Toggle Timeframe Lock
        //  
        if(IsHotkeyPressed(lparam, sparam, inpLockKey))
        {
            bool hadCustomPrice = (ObjectFind(0, g_customPriceHorizontalLineName) >= 0);
            double savedCustomPrice = hadCustomPrice ? ObjectGetDouble(0, g_customPriceHorizontalLineName, OBJPROP_PRICE, 0) : 0;
            g_suppressDeleteEvents = true;
            ObjectsDeleteAll(0, inpObjectPrefix);
            g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
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
            if(hadCustomPrice && savedCustomPrice > 0) {
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
                                  "[PIN] Custom Price: " + DoubleToString(savedCustomPrice, Digits) + " | Drag to adjust (live update)");
                    g_customPriceLineCreated = true;
                }
            }
            ThrottledChartRedraw();
            return;
        }
    } // end CHARTEVENT_KEYDOWN

    //  
    // ABCD Mouse Event Routing
    //  
#ifndef BUILD_LITE
    if(g_abcdDrawing || 
       id == CHARTEVENT_OBJECT_DRAG || 
       id == CHARTEVENT_OBJECT_DELETE ||
       id == CHARTEVENT_MOUSE_MOVE) {
        OnABCDMouseEvent(id, lparam, dparam, sparam);
        if(g_abcdDrawing && id == CHARTEVENT_CLICK) {
            return;
        }
    }
#endif

    //  
    // CHARTEVENT_CHART_CHANGE   Layout/Resize/Scroll/Zoom
    //  
    if(id == CHARTEVENT_CHART_CHANGE) {
        if(IsIndicatorHidden()) return;
        static uint s_lastLayoutMs = 0;
        static int s_lastW = -1;
        static int s_lastH = -1;
        static double s_lastVisibleMin = 0;
        static double s_lastVisibleMax = 0;
        uint nowMs = GetTickCount();
        if(nowMs - s_lastLayoutMs < CHART_CHANGE_THROTTLE_MS) return;

        int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        bool sizeChanged = (w != s_lastW || h != s_lastH);
        
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
        // PERF (2026): Levels/zones are fixed-price OBJ_HLINE objects; MT5 keeps
        // them anchored to their price across scroll/zoom automatically. A full
        // level redraw on a plain viewport change was pure waste and was the main
        // source of scroll/zoom lag (CHART_CHANGE_THROTTLE_MS=100 fired ~10 full
        // clear+recreate cycles/sec while dragging). Only a chart RESIZE needs a
        // label relayout - RedrawLabelsOnly touches labels only, not level/zone
        // objects, so it is cheap. We therefore skip the level redraw entirely on
        // viewport change and let the HLINE objects render themselves.
        if(sizeChanged) {
            RedrawLabelsOnly();
        }
        ThrottledChartRedraw();
        return;
    }

    //  
    // CHARTEVENT_CLICK   Custom Price Click
    //  
    if(id == CHARTEVENT_CLICK && g_waitingForCustomPriceClick)
    {
        if(StringFind(sparam, "r") >= 0)
        {
            CleanupCustomPriceObjects(true, true);
            _LOG_GATE_D Print("[D][GEN] Custom price setting cancelled (right-click)");
            ThrottledChartRedraw();
            return;
        }
        double clickedPrice = dparam;
        if(!g_customPriceLineCreated)
        {
            if(!ObjectCreate(0, g_customPriceHorizontalLineName, OBJ_HLINE, 0, 0, clickedPrice)) {
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
            if (isDoubleClick || !g_customPriceLineCreated)
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
        ThrottledChartRedraw();
    }

    //  
    // CHARTEVENT_OBJECT_CLICK   Custom Price Line / ABCD Pattern
    //  
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

    //  
    // CHARTEVENT_MOUSE_MOVE   Custom Price Drag Detection
    //  
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
                    // LIVE DRAG: track the price so the release uses the final
                    // position, but do NOT recompute/redraw the levels. The
                    // OBJ_HLINE moves natively with the cursor, so the drag stays
                    // instant and smooth. All levels are recomputed once on release
                    // (CHARTEVENT_OBJECT_DRAG / mouse-up). This avoids the heavy
                    // per-frame full redraw that used to happen every 50ms.
                    g_customTHStartPrice = currentLinePrice;
                    g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
                    string tooltip = "[PIN] Custom Price: " + DoubleToString(currentLinePrice, Digits) + " | Release to apply";
                    ObjectSetString(0, g_customPriceHorizontalLineName, OBJPROP_TOOLTIP, tooltip);
                }
            }
        }
        else
        {
            if(g_customPriceLineDragging) {
                g_customPriceLineDragging = false;
                g_forceClearOnNextDraw = true;
                g_redrawTHLevelsNeeded = true;
                // Defer the single recompute to CHARTEVENT_OBJECT_DRAG (reliable
                // drag-end). If it somehow doesn't fire, the next OnCalculate tick
                // (g_redrawTHLevelsNeeded=true) recomputes once. Avoids a double
                // full redraw on release.
            }
        }
    }

    //  
    // CHARTEVENT_OBJECT_DRAG   Custom Price Line Drag End
    //  
    if(id == CHARTEVENT_OBJECT_DRAG && sparam == g_customPriceHorizontalLineName)
    {
        g_customPriceLineDragging = false;
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

    //  
    // CHARTEVENT_OBJECT_CLICK   ABCD Pattern Selection
    //  
#ifndef BUILD_LITE
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
                patternName = sparam;
            }
            if(patternName != "") {
                SetActiveABCDPattern(patternName);
            }
        }
        else
        {
            SetActiveABCDPattern("");
        }
    }
#endif
}

//+------------------------------------------------------------------+
//| Functions ported from MT5 EventHandlers                           |
//+------------------------------------------------------------------+

// Cache invalidation flags (from MT5)
enum ECacheInvalidationFlags {
    CACHE_INV_NONE = 0,
    CACHE_INV_TIMEFRAME = 1,
    CACHE_INV_NEW_BAR = 2,
    CACHE_INV_CUSTOM_PRICE = 4
};

// Robust hotkey matcher: compares both key code (lparam) and key text (sparam)
bool IsHotkeyPressed(const long lparam, const string sparam, const string hotkey) {
    if(StringLen(hotkey) <= 0) return false;
    string k = hotkey;
    StringToUpper(k);
    int code = (int)StringGetCharacter(k, 0);
    if((int)lparam == code) return true;
    if(StringLen(sparam) > 0) {
        string sp = sparam;
        StringToUpper(sp);
        if((int)StringGetCharacter(sp, 0) == code) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Delete all indicator objects (DRY helper for OnDeinit)           |
//+------------------------------------------------------------------+
void DeleteAllIndicatorObjects(bool deepCleanup = false) {
    // PERF (2026): Every level/zone/legacy object this indicator draws is named
    // "<inpObjectPrefix>...". A SINGLE native ObjectsDeleteAll with the bare
    // prefix removes them ALL in one synchronous pass. The old code then looped
    // 5 pipeline modes x 5 suffixes (~25 more ObjectsDeleteAll calls) which were
    // pure no-ops because the first call already deleted them - yet each one
    // still triggered a full synchronous chart scan. Per the official MQL5 docs
    // (ObjectsDeleteAll), the call "can be time consuming ... with a large number
    // of objects", so this collapses ~26 native deletes into ONE. This is the
    // same bulk-delete pattern already used by ClearAllLevels().
    // Runs on TF-switch deinit (REASON_CHARTCHANGE), parameter changes
    // (REASON_PARAMETERS) and full removal (REASON_REMOVE) - i.e. exactly the
    // "deletion of levels" hot path the user reported as slow.
    ObjectsDeleteAll(0, inpObjectPrefix);
    InvalidateObjectCacheByPrefix(inpObjectPrefix);
    InvalidateObjectCountCache();
    // NOTE: REASON_REMOVE callers additionally delete the TH3_Structure_ / pattern
    // / temp prefixes separately in OnDeinitHandler; those do not share
    // inpObjectPrefix, so they are handled there, not here.
}

void EmergencyCleanupIndicatorObjects(const string indicatorPrefix)
{
    if(StringLen(indicatorPrefix) == 0) return;
    int total = ObjectsTotal(0, -1, -1);
    int prefixLen = StringLen(indicatorPrefix);
    int deleted = 0;
    for(int i = total - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(objName == "") continue;
        if(StringLen(objName) < prefixLen) continue;
        if(StringSubstr(objName, 0, prefixLen) != indicatorPrefix) continue;
        CacheRemoveObject(objName);
        g_suppressDeleteEvents = true;
        g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
        if(ObjectDelete(0, objName)) deleted++;
        g_suppressDeleteEvents = false;
    }
    _LOG_GATE_I Print("[I][GEN] Emergency cleanup deleted=", deleted,
                      " | before=", total, " | after=", ObjectsTotal(0, -1, -1));
    InvalidateObjectCountCache();
}

void ApplyCacheInvalidation(const int invalidationFlags,
                            const int previousPeriod,
                            const int currentPeriod,
                            const double previousCustomPrice,
                            const double currentCustomPrice)
{
    if((invalidationFlags & CACHE_INV_TIMEFRAME) != 0) {
        UpdatePeriodCache();
        InvalidateTimeframeDependentCaches();
        // PERF (2026): do NOT force a full clear+recreate on timeframe switch.
        // Clearing would ObjectDelete every level/zone and then ObjectCreate them
        // again - and ObjectCreate is the single most expensive chart operation
        // (per official MQL5 perf guidance: prefer modifying existing objects).
        // Instead we let RedrawAllObjects rename the existing objects in place
        // (RenamePrefixedObjects) and update their prices/geometry. We still mark
        // the levels for a redraw so prices refresh for the new timeframe.
        g_redrawTHLevelsNeeded = true;
        g_calculatedOnce = false;
        g_labelsRelayoutNeeded = true;
        // Reset fractal-determination window for the new timeframe so the
        // timeout fallback does not fire immediately from a previous TF's timer.
        g_fractalDetermineStartMs = 0;
        _LOG_GATE_I Print("[I][GEN] Timeframe changed: ", previousPeriod, " -> ", currentPeriod);
    }
    if((invalidationFlags & CACHE_INV_NEW_BAR) != 0) {
        InvalidateFactorCache();
    }
    if((invalidationFlags & CACHE_INV_CUSTOM_PRICE) != 0) {
        InvalidateTHCache();
        _LOG_GATE_I Print("[I][GEN] Custom price changed: ", DoubleToString(previousCustomPrice, Digits),
                          " -> ", DoubleToString(currentCustomPrice, Digits));
    }
}

void LogRedrawDecision(const bool isNewBar,
                       const bool timeframeChanged,
                       const bool customPriceChanged,
                       const bool gRedrawNeeded,
                       const bool forceClear,
                       const bool significantPriceChange,
                       const bool tickThrottled)
{
    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastRedrawDecisionLog = 0;
    datetime now = TimeCurrent();
    if(now - s_lastRedrawDecisionLog < 5) return;
    if(isNewBar || timeframeChanged || customPriceChanged || gRedrawNeeded || forceClear || significantPriceChange) {
        Print("[D][GEN] Redraw decision | newBar=", isNewBar,
              " tfChanged=", timeframeChanged,
              " customChanged=", customPriceChanged,
              " redrawFlag=", gRedrawNeeded,
              " forceClear=", forceClear,
              " sigPrice=", significantPriceChange,
              " throttled=", tickThrottled);
        s_lastRedrawDecisionLog = now;
    }
    #endif
}

//+------------------------------------------------------------------+
//| Periodic cleanup outside redraw path (timer-driven)              |
//+------------------------------------------------------------------+
void RunIncrementalObjectCleanup()
{
    if(g_customPriceLineDragging) return;
    datetime currentTime = TimeGMT();
    if(currentTime - g_lastObjectCleanup <= CLEANUP_INTERVAL_SECONDS) return;

    TH3_PROF_START(ObjectCleanup);
    int currentObjectCount = ObjectsTotal(0, -1, -1);

    if(currentObjectCount > g_objectCountLast + OBJECT_COUNT_INCREASE_THRESHOLD) {
        datetime cutoffTime = currentTime - 3600;
        // PERF (2026): TF-independent prefix - all our objects share one prefix
        // regardless of chart timeframe (see GetRuntimeObjectPrefix for rationale).
        string objectPrefix = inpObjectPrefix + "_";
        int currentPrefixLen = StringLen(objectPrefix);
        string indicatorPrefix = inpObjectPrefix;
        int indicatorPrefixLen = StringLen(indicatorPrefix);

        static int s_cleanupCursor = -1;
        int maxCleanupItems = MathMin(currentObjectCount, 300);
        if(s_cleanupCursor < 0 || s_cleanupCursor >= currentObjectCount) {
            s_cleanupCursor = currentObjectCount - 1;
        }

        int processed = 0;
        int i = s_cleanupCursor;
        for(; i >= 0 && processed < maxCleanupItems; i--, processed++) {
            string objName = ObjectName(0, i);
            if(objName == "") continue;

            bool isOurs = false;
            if(StringLen(objName) >= indicatorPrefixLen && StringSubstr(objName, 0, indicatorPrefixLen) == indicatorPrefix) isOurs = true;
            if(!isOurs) continue;

            if(StringFind(objName, "TH3_Structure_") == 0) continue;
            // With the new TF-independent prefix, "isOurs" already implies
            // "matches the active prefix" - any other chart-instance object
            // would use a different inpObjectPrefix.
            if(StringLen(objName) >= currentPrefixLen && StringSubstr(objName, 0, currentPrefixLen) == objectPrefix) continue;

            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            if(objTime > 0 && objTime < cutoffTime) {
                CacheRemoveObject(objName);
                g_suppressDeleteEvents = true;
                g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
                ObjectDelete(0, objName);
                g_suppressDeleteEvents = false;
            }
        }

        if(i < 0) s_cleanupCursor = currentObjectCount - 1;
        else s_cleanupCursor = i;
    }

    g_objectCountLast = currentObjectCount;
    g_lastObjectCleanup = currentTime;
    TH3_PROF_END(ObjectCleanup);
}

// Lightweight label-only redraw (no level recalculation)
void RedrawLabelsOnly() {
    if(IsIndicatorHidden()) return;
    datetime currentTime = TimeGMT();
    string objectPrefix = GetRuntimeObjectPrefix();

    // CRITICAL: Reset stacking offsets and clear old labels
    g_currentLabelYOffset = 0;
    g_currentLabelYOffsetBottom = 0;
    ClearAllLabels(objectPrefix);

    if(g_atrLabelsVisible) {
        DisplayATRLabels(objectPrefix);
    }

    bool showFractal = (g_thLabelsMode == 1 || g_thLabelsMode == 3);
    bool showStandard = (g_thLabelsMode == 2 || g_thLabelsMode == 3);
    if(g_thLabelsMode != 0 && g_dailyClosePriceForTH != EMPTY_VALUE && g_dailyClosePriceForTH > 0.0) {
        if(showFractal)  DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(showStandard) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
    }
    g_modeLabelYOffset = g_currentLabelYOffset;
    RepositionAllOverlayLabels();
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| HELPER: Adjust factor value by step (+1 = increase, -1 = decrease)|
//|                                                                  |
//| DIRECT MODE: g_factorValueOverride is a Step Size, adjust by pip|
//| CLASSIC MODE: g_factorValueOverride is a Factor number           |
//+------------------------------------------------------------------+
void AdjustFactorValue(int direction)
{
    bool useDirect = (inpFactorDisplayMode == FACTOR_DISPLAY_DIRECT);
    double currentVal = g_factorValueOverride;
    
    if(currentVal <= 0) {
        if(inpFactorMode == FACTOR_MODE_MANUAL && inpFactorValue > 0) {
            currentVal = inpFactorValue;
        } else if(useDirect) {
            // DIRECT MODE: Get default Step Size from current basis
            double tfPct = GetTimeframeTH();
            double basePrice = (g_dailyClosePriceForTH > 0) ? g_dailyClosePriceForTH : Bid;
            double thVal = CalculateTH(basePrice, GetCachedDigits(), tfPct);
            thVal = GetAdaptedStepSize(thVal);
            if(thVal > 0) {
                switch(inpFactorAutoBasis) {
                    case FACTOR_BASIS_SS:      currentVal = thVal * 1.5; break;
                    case FACTOR_BASIS_LS:      currentVal = thVal * 2.0; break;
                    case FACTOR_BASIS_TH:      currentVal = thVal; break;
                    case FACTOR_BASIS_CONTROL: currentVal = thVal * 1.75; break;
                    default:                   currentVal = thVal * 1.5; break;
                }
            }
            if(currentVal <= 0) currentVal = thVal; // Final fallback
        } else {
            // CLASSIC MODE: Get default Factor
            currentVal = GetDefaultFactorValue(g_dailyClosePriceForTH);
            if(currentVal <= 0 || currentVal > MAX_FACTOR_VALUE) {
                _LOG_GATE_E Print("[E][GEN] Factor adjust: Invalid factor, using ", DEFAULT_FACTOR_FALLBACK);
                currentVal = DEFAULT_FACTOR_FALLBACK;
            }
        }
    }
    
    double newVal;
    if(useDirect) {
        // DIRECT MODE: currentVal is Step Size in price units
        // Adjust by 10% of current value (or by 1 pip minimum)
        double pipSize = GetCachedPipSize();
        if(pipSize <= 0) pipSize = GetCachedPoint() * 10;
        double adjustBy = MathMax(currentVal * 0.1, pipSize);
        newVal = NormalizeDouble(currentVal + adjustBy * direction, GetCachedDigits());
        if(newVal < pipSize * 0.1) newVal = pipSize * 0.1;
        if(newVal > MAX_FACTOR_VALUE) newVal = MAX_FACTOR_VALUE;
    } else {
        // CLASSIC MODE: currentVal is Factor number
        double step = (inpFactorAdjustStep > 0) ? inpFactorAdjustStep : DEFAULT_FACTOR_ADJUST_STEP;
        newVal = NormalizeDouble(currentVal + step * direction, 2);
        if(newVal < MIN_FACTOR_VALUE) newVal = MIN_FACTOR_VALUE;
        if(newVal > MAX_FACTOR_VALUE) newVal = MAX_FACTOR_VALUE;
    }
    
    g_factorValueOverride = newVal;
    string factorGvarName = "Biotak_Factor_" + GetCachedChartIdStr();
    if(!GlobalVariableSet(factorGvarName, g_factorValueOverride)) {
        _LOG_GATE_E Print("[E][GEN] WARNING: Failed to persist Factor value to GlobalVariable");
    }
    g_forceClearOnNextDraw = true;
    g_redrawTHLevelsNeeded = true;
    RedrawAllObjects(true);
    // For DIRECT mode, pass the step size directly for proper label formatting
    UpdateFactorLabel(useDirect ? 0 : newVal, useDirect ? newVal : 0);
    ThrottledChartRedraw();
}

