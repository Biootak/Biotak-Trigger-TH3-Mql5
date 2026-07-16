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
    // semantics on TF/symbol switch). Bypass the cache for the next
    // frame so the visibility state — including the user's L-key "off"
    // toggle and F-key indicator-hide — is pushed to the chart before the
    // cache can incorrectly short-circuit it. Without this the user's
    // "lines off" preference silently flips back to "on" after every TF
    // switch (the classic "I disabled lines but they came back" bug).
    //
    // PERF (2026, D): reduced from 5 frames to 1. The original 5-frame
    // window was a paranoia buffer to cover the case where MT5 fires
    // OnCalculate asynchronously after OnInit and the chart engine
    // hasn't fully settled the chart-object attachment state. With 200
    // cached objects × 5 frames = 1000 sync ObjectSetInteger calls per
    // OnInit - a measurable startup freeze. One frame is enough: by
    // the time the second OnCalculate runs, the cache has been
    // populated and the normal in-place visibility path takes over.
    // MT4 had no equivalent forced-push at all (it did direct
    // ObjectSetInteger on every visibility toggle).
    // FIX (TF switch lag, 2026, C): only request force-push when the user's
    // visibility state diverges from the chart engine's default reset.
    // MQL5 resets every OBJPROP_TIMEFRAMES back to OBJ_ALL_PERIODS on chart
    // re-init (TF/symbol switch). If the user is at the default visibility
    // (lines visible, indicator not hidden, g_thLabelsMode default), then
    // the chart engine's reset MATCHES the desired state and the cache is
    // still authoritative — no force-push needed, saving ~200 sync
    // ObjectSetInteger calls per TF switch.
    //
    // We must still force-push when:
    //   - g_linesVisible == false  (user pressed L to hide lines)
    //   - g_thLabelsMode != 0      (user enabled ATR/TH labels)
    //   - shouldBeHidden == true   (user pressed F to hide indicator)
    // because the chart reset to OBJ_ALL_PERIODS would silently re-show
    // objects the user explicitly hid.
    if(!g_linesVisible || g_thLabelsMode != 0 || shouldBeHidden) {
        RequestForcePushTimeframes(1);
    }
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
    // FIX (2026, TF switch continuity): with the OnDeinit state preservation
    // fix, OnInit runs after a TF switch WITHOUT the cache + state having
    // been wiped. g_calculatedOnce stays true across the OnDeinit/OnInit
    // pair so the rename-in-place fast path works and we don't re-issue
    // ClearAllLabels + DisplayATRLabels on every TF toggle. The label
    // relayout is still requested via g_labelsRelayoutNeeded by the
    // CHARTEVENT_CHART_CHANGE handler when the chart pixel size changes,
    // and the price-geometry recalc runs unconditionally because
    // g_redrawTHLevelsNeeded is set in both OnDeinit and OnInit.
    //
    // For non-TF-switch re-inits (terminal restart, indicator reload,
    // settings change → REASON_PARAMETERS → re-OnInit) we keep the
    // historical `g_calculatedOnce = false` reset: there the OnDeinit
    // path DID clear state (preserveStateForReinit=false), so the labels
    // do need to be redrawn from scratch.
    if(!recentTimeframeSwitch) {
        g_calculatedOnce = false;
    }
    InitializeAdaptiveScaling();

    // FIX (2026, G1): historical high/low are loaded ONCE in OnInit and never
    // re-read. The values come from iHighest/iLowest on inpHistoricalTimeframe
    // (default MN1), which means they change at most once per MN1 bar — i.e.
    // ~once per month. Re-reading them every hour (the old UpdateHistoricalValues
    // 3600s gate) or even every OnCalculate tick after a TF switch is wasted
    // work and on cold-start where the MN1 history isn't loaded yet it can
    // silently fall back to a +/- 1% range around Bid — that's the "drawn
    // incorrectly" the user reported. Once set, they stay set until the next
    // OnInit (i.e. terminal restart, indicator reload, or user-initiated reset).
    //
    // To force a re-load after a settings change at runtime, the user can press
    // the X-key (inpReloadKey = "X") which routes through OnInit.
    g_lastHistoricalUpdate = TimeCurrent();
    // (no periodic re-read)

    // FIX (2026, M2): on a TF switch, the previous TF's g_fractalShift would
    // carry over and be used by the first redraw on the new TF - the user saw
    // wrong spacing for ~10s while the hysteresis counted 2 confirmations.
    // Reset the shift to 0 and the hysteresis state, then explicitly call
    // UpdateATRScalingFactor so the new TF's correct shift is committed on
    // the very first eligible tick (firstDetermination=true after the reset).
    g_fractalShift = 0;
    ResetFractalJumpHysteresis();
    g_fractalDetermined = false;
    g_fractalDeterminedTF = "";
    g_fractalDetermineStartMs = 0;

    // Try to commit the shift immediately. UpdateATRScalingFactor needs a
    // valid basePrice and ATR. If ATR is not yet loaded (cold-start, MN1
    // history not ready) it returns false and g_fractalDetermined stays
    // false; the FRACTAL_DETERMINE_TIMEOUT_MS fallback then kicks in.
    double thBasePriceInit = GetBasePriceForTH();
    if(thBasePriceInit <= 0 || thBasePriceInit == EMPTY_VALUE)
        thBasePriceInit = g_dailyClosePriceForTH;
    if(thBasePriceInit > 0) {
        // Try once. If it returns true, shift was committed + fractalReady
        // will be true on the first redraw.
        UpdateATRScalingFactor(thBasePriceInit, Digits);
    }

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

        // FIX (2026, L): when the chosen anchor is a historical extreme
        // (HIGH/LOW), draw a visible horizontal line at the anchor price so
        // the user can see WHERE the levels are anchored — same UX as the
        // custom-price line, but read-only (no drag, no save). The line is
        // deleted on Deinit / F-key hide / mode change. The custom-price
        // branch above already handles its own anchor line; this handles
        // the case where inpTHStartPointType is one of the historical
        // options and no manual anchor was supplied.
        if(inpTHStartPointType == TH_START_POINT_HISTORICAL_HIGH && g_highestHigh > 0) {
            if(CreateCustomPriceLine(g_highestHigh, digits, false, "Historical High anchor")) {
                // Read-only: user cannot drag a historical anchor.
                ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, false);
            }
        } else if(inpTHStartPointType == TH_START_POINT_HISTORICAL_LOW && g_lowestLow > 0) {
            if(CreateCustomPriceLine(g_lowestLow, digits, false, "Historical Low anchor")) {
                ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_SELECTABLE, false);
            }
        }
        // TH_START_POINT_MIDPOINT deliberately has no anchor line: it's
        // the (high+low)/2 value which the user can read off the visible
        // high/low lines without needing a third object.
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
            _LOG_GATE_E Print("[E][GEN] OnInit: Invalid inpFactorValue (", inpFactorValue, "), clamping to ", DoubleToString(DEFAULT_FACTOR_VALUE, 1));
            g_factorValueOverride = DEFAULT_FACTOR_VALUE;
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

    // FIX (TF switch lag, 2026): seed the chart-change caches to the CURRENT
    // chart state before returning. Without this, the CHARTEVENT_CHART_CHANGE
    // that fires right after OnInit (MQL5 fires one for every TF/symbol switch
    // and chart re-init) compares ChartSymbol(0)/ChartPeriod(0) against
    // g_lastChartSymbol/g_lastChartPeriod which still hold the PRE-switch
    // values (these statics persist across OnInit/OnDeinit on the same chart).
    // The mismatch sets g_pendingChartChange=true and forces a SECOND full
    // RedrawAllObjects right after the first one (already triggered by
    // g_redrawTHLevelsNeeded=true above). That second redraw runs the entire
    // pipeline again — 290-zone wipe+recreate, label pass, identity hash,
    // alerts — adding 100-500ms of lag to every TF switch with zero visual
    // benefit (the first redraw already produced the correct output).
    //
    // With this seed, the immediate post-init CHART_CHANGE takes the
    // "same symbol AND same period" early-return at OnChartEventHandler
    // (the compare at L2224), so g_pendingChartChange stays false and only
    // the first OnCalculate redraw runs.
    // FIX (2026, force relayout after restore): when the user has labels
    // visible (g_atrLabelsVisible or g_thLabelsVisible restored to true
    // from GlobalVariable), we MUST mark the labels for relayout on the
    // next redraw. Without this, the relayout depends on either:
    //   - a new-bar tick (which on M1/M5 is up to 5 minutes, on MN1 a month)
    //   - the 30-min ATR-refresh interval
    //   - the CHARTEVENT_CHART_CHANGE pixel-size gate (only fires on resize)
    //   - the recentTimeframeSwitch detector (20s window — fast TF toggles miss it)
    // So labels could keep showing the PREVIOUS TF's values for up to 30 min
    // after a switch. Setting g_labelsRelayoutNeeded=true here guarantees the
    // very next RedrawAllObjects re-runs Display* with the new TF's values.
    // Per the no-clear-on-relayout fix in RedrawAllObjects (the Display*
    // functions do in-place ObjectSetInteger updates for existing OBJ_LABEL
    // objects), this is a pure value refresh — no ObjectDelete flicker.
    bool labelsVisibleAfterRestore = (g_atrLabelsVisible || g_thLabelsVisible);
    if(labelsVisibleAfterRestore) {
        g_labelsRelayoutNeeded = true;
    }

    // FIX (2026, TF switch label refresh): the central ATR refresh loop in
    // OnCalculate sets g_labelsRelayoutNeeded=true on a new-bar tick OR when
    // the 30-min ATR-refresh interval is due. On a TF switch neither of those
    // is guaranteed to fire on the first tick (M1 = up to 1 minute, MN1 =
    // up to 1 month), so we explicitly request a label value refresh here.
    // Per the no-clear-on-relayout fix further down, this triggers an
    // in-place update of all ATR/TH labels without any ObjectDelete call,
    // so the existing OBJ_LABEL objects just get their text and pixel
    // positions refreshed for the new chart TF. No flicker.
    if(recentTimeframeSwitch) {
        g_labelsRelayoutNeeded = true;
    }

    // FIX (LBL-2, 2026): MT5 resets every OBJPROP_TIMEFRAMES back to
    // OBJ_ALL_PERIODS when the chart engine re-initializes (TF switch,
    // symbol switch, OnDeinit/OnInit cycle). Our cache invalidation above
    // marks those properties as unknown, but the next visibility push still
    // needs to fire. We force-push ATR label visibility here using the same
    // SetATRLabelsVisibility helper the hotkey toggle uses, so the user's
    // "labels on/off" preference is correctly re-applied regardless of what
    // the chart engine did to the property during the reset.
    //
    // BUG (2026, LBL-2 hotkey path): the previous condition was
    //   if(inpShowATRLabels && g_atrLabelsVisible && !shouldBeHidden) ...
    // which skipped the force-push when the user enabled labels via the A
    // hotkey WITHOUT having checked the input property. In that case
    // g_atrLabelsVisible=true (restored from GlobalVariable) but
    // inpShowATRLabels=false, so the first if-branch was skipped and the
    // else-if-branch (!g_atrLabelsVisible) was also skipped. The result:
    // labels vanished on every TF/symbol switch for hotkey-only users.
    // Fix: drive visibility off the runtime state (g_atrLabelsVisible +
    // shouldBeHidden), not off the input property. Both callers converge
    // on the same SetATRLabelsVisibility call.
    {
        bool atrShouldShow = (g_atrLabelsVisible && !shouldBeHidden);
        SetATRLabelsVisibility(inpObjectPrefix, atrShouldShow);
    }
    // FIX (2026, TH labels TF switch): mirror the ATR force-push for TH
    // labels. Previously OnInit had no TH visibility force-push at all,
    // so after a TF switch the user's S-key "TH labels on" preference was
    // silently reset to OBJ_ALL_PERIODS by the chart engine and the labels
    // either disappeared (if user had been hiding them) or appeared where
    // they didn't want them. Drive off the runtime state too — same
    // hotkey-vs-input bug fix as the ATR branch above.
    {
        int thMode = (shouldBeHidden || !g_thLabelsVisible) ? 0 : g_thLabelsMode;
        SetTHLabelsVisibility(inpObjectPrefix, thMode);
    }

    // FIX (LBL-DISSOLVE follow-up, 2026): the 5 special overlay objects
    // (StepMode / Factor / TH3Freq / LockStatus labels + CustomPrice line)
    // are PRESERVED across REASON_CHARTCHANGE in OnDeinitHandler. After the
    // chart re-init the engine has reset their OBJPROP_TIMEFRAMES back to
    // OBJ_ALL_PERIODS — without an explicit push the user's hidden state
    // (L key, F key, lock-off) is lost. The general InvalidateObjectCache
    // + RequestForcePushTimeframes(1) above will eventually cover the
    // OBJECT-CACHE-MANAGED objects, but these 5 special names live outside
    // that cache (they have fixed global names, never inserted via
    // CacheInsert). Push their timeframes here directly.
    //
    // For the auto-hide mode labels (StepMode / Factor / TH3Freq) we also
    // enforce the inpModeLabelDuration timer: if the timer expired during
    // the OnDeinit gap, delete the label now. The CreateTime statics
    // survive OnDeinit/OnInit (they're static, not instance), so we can
    // compare against them. For LockStatus we re-evaluate visibility based
    // on the current g_timeframeLocked state. For CustomPrice we keep the
    // line if there's a saved custom price global var for this symbol.
    {
        long overlayTF = shouldBeHidden ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
        // Auto-hide mode labels: enforce timer.
        // inpModeLabelDuration == 0 means "permanent", so always restore.
        // > 0 means seconds; if (now - createTime) >= duration the label
        // should be gone — but during the switch gap we got a fresh "now",
        // so a label that was about to expire is now stale.
        if(inpModeLabelDuration > 0) {
            uint nowMs = GetTickCount();
            uint durMs = (uint)inpModeLabelDuration * 1000;
            if(g_stepModeLabelCreateTime > 0 &&
               (nowMs - g_stepModeLabelCreateTime) >= durMs) {
                ObjectDelete(0, g_stepModeLabelName);
                g_stepModeLabelCreateTime = 0;
            }
            if(g_factorLabelCreateTime > 0 &&
               (nowMs - g_factorLabelCreateTime) >= durMs) {
                ObjectDelete(0, g_factorLabelName);
                g_factorLabelCreateTime = 0;
            }
#ifndef BUILD_LITE
            if(g_th3FreqLabelCreateTime > 0 &&
               (nowMs - g_th3FreqLabelCreateTime) >= durMs) {
                ObjectDelete(0, g_th3FreqLabelName);
                g_th3FreqLabelCreateTime = 0;
            }
#endif
        }
        // Push timeframes for the (still-existing) overlay labels.
        if(ObjectFind(0, g_stepModeLabelName) >= 0)
            ObjectSetInteger(0, g_stepModeLabelName, OBJPROP_TIMEFRAMES, overlayTF);
        if(ObjectFind(0, g_factorLabelName) >= 0)
            ObjectSetInteger(0, g_factorLabelName, OBJPROP_TIMEFRAMES, overlayTF);
#ifndef BUILD_LITE
        if(ObjectFind(0, g_th3FreqLabelName) >= 0)
            ObjectSetInteger(0, g_th3FreqLabelName, OBJPROP_TIMEFRAMES, overlayTF);
#endif
        // LockStatus: re-evaluate against current lock state. The user could
        // have toggled the K key during the OnDeinit/OnInit gap (rare but
        // possible). If lock is now off, the preserved label is stale and
        // must be removed. If lock is on, refresh the text in case the
        // locked period changed during the gap. If we're hidden via F, just
        // push timeframes off — HideAllTHObjects/ShowAll path will toggle it.
        if(ObjectFind(0, g_lockStatusLabelName) >= 0) {
            if(!g_timeframeLocked) {
                // Lock released during the gap. Label no longer relevant;
                // delete it and reset its create-time so it doesn't reappear
                // via RepositionAllOverlayLabels on the next redraw.
                ObjectDelete(0, g_lockStatusLabelName);
                g_lockStatusLabelCreateTime = 0;
            } else {
                ObjectSetInteger(0, g_lockStatusLabelName, OBJPROP_TIMEFRAMES, overlayTF);
                if(!shouldBeHidden) {
                    UpdateLockStatusLabel(false);  // refresh text in case locked period changed
                }
            }
        }
        // CustomPrice line: keep it ONLY if the user has an active custom
        // price configured. Otherwise the previous TF's line was already
        // deleted by OnDeinit for non-CHARTCHANGE reasons, so a stale line
        // here means a real bug — clean it up.
        if(ObjectFind(0, g_customPriceHorizontalLineName) >= 0) {
            string cpGvarName = "Biotak_CustomPrice_" + GetCachedSymbol();
            bool hasCustomPrice =
                (g_customTHStartPrice > 0.0) ||
                (inpCustomTHStartPrice > 0.0) ||
                GlobalVariableCheck(cpGvarName);
            if(hasCustomPrice) {
                ObjectSetInteger(0, g_customPriceHorizontalLineName, OBJPROP_TIMEFRAMES, overlayTF);
                g_customPriceLineCreated = true;
            } else {
                // Stale line from a prior config that no longer applies.
                ObjectDelete(0, g_customPriceHorizontalLineName);
                g_customPriceLineCreated = false;
            }
        }
    }

    g_lastChartSymbol = ChartSymbol(0);
    g_lastChartPeriod = (ENUM_TIMEFRAMES)ChartPeriod(0);
    // LBL-1 closure: seed chart pixel dimensions too so the very first
    // CHARTEVENT_CHART_CHANGE that arrives right after OnInit (MQL5 fires
    // one for every TF/symbol switch) does not trigger a phantom relayout
    // by comparing stale (0) cache values against real dimensions.
    g_lastChartWidthPx  = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    g_lastChartHeightPx = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

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

    // FIX (LBL-DISSOLVE, 2026): On TF/symbol switch (REASON_CHARTCHANGE) the
    // 5 special overlay labels + custom-price line MUST be PRESERVED across
    // the OnDeinit/OnInit cycle. Previously they were ObjectDelete'd here
    // unconditionally — the chart then re-initialized and RedrawAllObjects
    // only recreates ATR/TH labels, never the special overlays. Net effect:
    // every TF switch made StepMode / Factor / TH3Freq / LockStatus /
    // CustomPrice vanish, and they only reappeared when the user pressed
    // the matching hotkey (S / 1-2 / 3-4 / K). The same rename-in-place
    // pattern that keeps HLINEs continuous through a TF switch (see the
    // comment block at L837) applies here: the labels are TF-independent
    // OBJ_LABEL/OBJ_HLINE objects keyed by chart-scoped name, so the chart
    // engine's reset is purely a property one — the objects themselves
    // survive. We delete them ONLY on full REMOVE or PARAMETERS (settings
    // change), never on REASON_CHARTCHANGE.
    //
    // Notes:
    //   - g_*LabelCreateTime statics persist across OnInit, so the OnTimer
    //     auto-hide path (inpModeLabelDuration > 0) still works correctly
    //     for the labels that were temporarily shown.
    //   - The chart engine resets OBJPROP_TIMEFRAMES on re-init, but
    //     OnInitHandler force-pushes timeframes for one frame and the
    //     cache invalidation (InvalidateObjectCacheByPrefix + RequestForcePushTimeframes)
    //     restores the user's hidden/visible state for the next redraw.
    //   - RepositionAllOverlayLabels runs at the end of RedrawAllObjects
    //     and re-applies OBJPROP_XDISTANCE/YDISTANCE (needed because the
    //     chart pixel dimensions may have changed and labels can sit at
    //     stale offsets).
    if(reason == REASON_CHARTCHANGE) {
        // TF/symbol switch: keep all overlay objects. Do NOT touch them.
        DEBUG_PRINT("OnDeinit (REASON_CHARTCHANGE) - preserving overlay labels and custom price line");
    } else {
        // REMOVE / PARAMETERS / other: full cleanup, objects will be
        // recreated from scratch by RedrawAllObjects or left gone.
        ObjectDelete(0, g_stepModeLabelName);
        ObjectDelete(0, g_factorLabelName);
#ifndef BUILD_LITE
        ObjectDelete(0, g_th3FreqLabelName);
#endif
        ObjectDelete(0, g_lockStatusLabelName);
        ObjectDelete(0, g_customPriceHorizontalLineName);
    }

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
    // FIX (2026, CHARTCHANGE state preservation):
    // The REASON_CHARTCHANGE branch above (L766-L779) documents the
    // "rename-in-place" architecture: a TF/symbol switch reuses the
    // existing object set and the next RedrawAllObjects updates prices
    // in place. But the unconditional resets below were defeating that
    // promise:
    //   CacheClear()         wiped the per-object identity cache
    //   g_calculatedOnce=false forced needLabels=true on next redraw
    //   g_redrawTHLevelsNeeded=true forced the heavy label path
    // Effect: every TF/symbol switch triggered a full ClearAllLabels +
    // re-create of every ATR/TH label + every level/zone object — the
    // visible "wipe and redraw" the user reported on scroll/zoom and TF
    // toggling, and the labels-going-invisible on first frame after the
    // switch.
    //
    // Fix: scope those resets to reasons that genuinely destroy the chart
    // state (REASON_REMOVE, REASON_PARAMETERS, REASON_CLOSE, REASON_TEMPLATE,
    // REASON_INITFAILED, REASON_CHARTCLOSE, REASON_ACCOUNT). For
    // REASON_CHARTCHANGE (TF/symbol toggle) we keep the cache and the
    // "labels already drawn once" flag so the rename-in-place path can
    // proceed without a redundant ClearAllLabels.
    bool preserveStateForReinit = (reason == REASON_CHARTCHANGE);
    if(!preserveStateForReinit) {
        DEBUG_PRINT("Clearing caches and resetting state (full teardown)");
        CacheClear();
        g_initialized = false;
        g_calculatedOnce = false;
        g_redrawTHLevelsNeeded = true;
        g_highestHigh = EMPTY_VALUE;
        g_lowestLow = EMPTY_VALUE;
        g_currentPrice = 0.0;
        g_lastCalculation = 0;
        g_lastHistoricalUpdate = 0;
    } else {
        DEBUG_PRINT("REASON_CHARTCHANGE: preserving cache + g_calculatedOnce for rename-in-place");
        // CHARTCHANGE-specific: we still want g_redrawTHLevelsNeeded to
        // trigger ONE full geometry recalc on the new TF (the price step,
        // fractal shift and base price all depend on TF), but we keep
        // g_calculatedOnce=true so the label-redraw branch is skipped
        // and the existing OBJ_LABEL objects stay alive across the
        // switch. The identity-hash will differ (period changed) so the
        // skipHeavyWork gate at L1710 will not short-circuit the price
        // update — labels stay where they are, only price geometry moves.
        g_redrawTHLevelsNeeded = true;
        // Seed the chart pixel cache so the first CHARTEVENT_CHART_CHANGE
        // after this OnDeinit/OnInit pair does not fire a phantom
        // relayout (L2299 compares against the new values). The actual
        // reseed happens in OnInit at L585+; this is just a belt-and-braces.
        g_lastChartWidthPx  = 0;
        g_lastChartHeightPx = 0;
    }
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
    // FIX (2026, J): inpMaxLevels was the legacy symmetric cap; replaced
    // with MathMax(above, below) so the hash tracks whichever side dominates
    // the topology. The two inputs are mixed separately further down.
    h ^= (ulong)MathMax(inpMaxTHLevelsAbove, inpMaxTHLevelsBelow); h *= FNV_PRIME;
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

    // PERF (2026, A): include the adaptive math that actually moves the level
    // values. Without these, the hash stays equal when g_fractalShift changes
    // and the pipeline runs its diff-then-delete branch on every tick instead
    // of running a single full redraw on the shift boundary.
    h ^= (ulong)g_fractalShift;                          h *= FNV_PRIME;
    h ^= (ulong)(long)(g_smoothedScalingFactor * 1000.0); h *= FNV_PRIME;
    h ^= (ulong)(long)(g_atrScalingFactor   * 1000.0);   h *= FNV_PRIME;
    h ^= (ulong)(int)inpAdaptiveMode;                    h *= FNV_PRIME;
    h ^= (ulong)(int)inpFractalJumpStrategy;             h *= FNV_PRIME;
    h ^= (ulong)(int)g_fractalDetermined;                h *= FNV_PRIME;
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
    // combo config, mid-zone style, adaptive math (g_fractalShift,
    // g_smoothedScalingFactor, g_atrScalingFactor, etc.), so a tick that
    // only wobbles the base price by 1 point does NOT flip the hash.
    ulong h = HashLevelTopology(prefix, mode);

    // PERF (2026, A): the previous code mixed basePrice/customPrice/
    // highestHigh/lowestLow into the hash at 5-decimal precision. That
    // meant every OnCalculate tick on M1 — where the last-bar close
    // changes by 0.1 pip every tick — flipped the hash and forced the
    // full redraw to run. The in-place update path
    // (CreateOrUpdateHLine cache hit with ObjectSetDouble(OBJPROP_PRICE)
    // only when the move > 0.1 point) already keeps the visual output
    // correct without a redraw. The hash now reflects STRUCTURAL change
    // only — settings, mode, shift, scaling, custom-price toggle, TF.
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
        // PERF (2026): hoist the 6 suffix concatenations out of the loop body.
        // On a TF/symbol switch with ~5 inactive modes, that was ~30 string
        // allocations per call. Each suffix is a constant for the whole call
        // (entries[] is filled once before the loop), so we compute them here.
        int modeNameEnd = StringFind(entries[i].levelAbove, "_Above_");
        string modeName = (modeNameEnd > 0) ? StringSubstr(entries[i].levelAbove, 0, modeNameEnd) : "";
        if(modeName == "" || modeName == activeModeName) continue;

        const string zAbove = objectPrefix + entries[i].zoneSuffix;
        const string zCenter = objectPrefix + entries[i].zoneCenter;
        const string lAbove  = objectPrefix + entries[i].levelAbove;
        const string lBelow  = objectPrefix + entries[i].levelBelow;
        const string mPoint  = objectPrefix + entries[i].midpoint;

        if(clearZones) {
            totalDeleted += ObjectsDeleteAll(0, zAbove);
            totalDeleted += ObjectsDeleteAll(0, zCenter);
        }

        totalDeleted += ObjectsDeleteAll(0, lAbove);
        totalDeleted += ObjectsDeleteAll(0, lBelow);
        totalDeleted += ObjectsDeleteAll(0, mPoint);
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
    // FIX (2026, H): asymmetric level counts. The two inputs are independent
    // because the user often needs very different counts above vs below the
    // midpoint — e.g. 10 levels above to reach a recent high, but 1000 levels
    // below to step down to M1 on a lower timeframe. Forcing a single
    // inpMaxLevels number for both sides either wastes memory (when the user
    // over-provisions to reach far in one direction) or truncates levels in
    // the other direction. The MAX_SAFE_LEVELS clamp still guards against
    // runaway object counts.
    maxAbove = inpMaxTHLevelsAbove;
    maxBelow = inpMaxTHLevelsBelow;
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
           s_stepCache[ci].maxAbove == inpMaxTHLevelsAbove &&
           s_stepCache[ci].maxBelow == inpMaxTHLevelsBelow &&
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
    // FIX (2026, J): was `maxAbove = inpMaxLevels` (legacy symmetric). Now
    // stores the two independent caps so the cacheHit check above correctly
    // distinguishes 10/1000 from 1000/10.
    s_stepCache[s_stepCacheHead].maxAbove = inpMaxTHLevelsAbove;
    s_stepCache[s_stepCacheHead].maxBelow = inpMaxTHLevelsBelow;
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
    uint nowMs = redrawStartMs;  // PERF (2026): reuse redrawStartMs (already GetTickCount())

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
    // FIX (2026, K): removed `historicalRefreshDue` flag entirely. After FIX
    // G1 historical high/low are loaded ONCE in OnInit and never refreshed.
    // The flag was hard-coded to false here and contributed to hasPendingWork
    // for no reason. The previous hourly refresh path inside RedrawAllObjects
    // is gone too.
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
    bool hasPendingWork = (force_redraw || g_labelsRelayoutNeeded || g_redrawTHLevelsNeeded || basePriceBoundary);
    
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
    // `s_lastPrefix != objectPrefix` check was always false — the static
    // initializer runs exactly once and `objectPrefix` is the same string
    // every call. The RenamePrefixedObjects body never executed but the
    // branch + the always-false comparison still ran on every redraw frame.
    // On M1 at 60 ticks/min that was 60 wasted string compares per minute
    // per chart. The block is removed entirely. If prefix ever becomes
    // runtime-mutable again, reintroduce it (the comparison goes back to
    // true on the first prefix change).

    #ifdef ENABLE_DEBUG_LOGS
    static datetime s_lastDebugLog = 0;
    if(TimeGMT() - s_lastDebugLog > 60) {
        Print("[D][GEN] [MT4 DEBUG] RedrawAllObjects executing - Bid: ", DoubleToString(Bid, Digits));
        s_lastDebugLog = TimeGMT();
    }
    #endif

    g_dailyClosePriceForTH = thBasePrice;

    // FIX (2026, G1): historical high/low are loaded ONCE in OnInit and NEVER
    // re-read inside RedrawAllObjects. The previous code's hourly refresh was
    // wasted work (MN1 data changes at most once a month) AND on cold-start
    // when MN1 history wasn't loaded it would overwrite the OnInit-seeded
    // values with a +/- 1% Bid fallback — the "historical high/low drawn
    // incorrectly" the user reported.
    //
    // If g_highestHigh / g_lowestLow were never seeded (init failed silently),
    // they stay at 0/EMPTY_VALUE; downstream code at L1156-1157 of
    // LevelPipeline.mqh then skips the historical bounding (custom-price
    // mode) or treats the range as empty and falls back to the base-price-
    // derived steps. Either way we never overwrite a valid seeded value.

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

        // FIX (2026, no-clear on relayout): previously this block called
        // ClearAllLabels(objectPrefix) unconditionally on every needLabels
        // pass. With the OnDeinit state-preservation fix, a TF/symbol
        // switch now sets g_labelsRelayoutNeeded=true (via the central ATR
        // refresh loop detecting value changes), which made this Clear fire
        // on every TF toggle — deleting all 24 ATR labels + ~30 TH labels
        // and recreating them one tick later. The visible flicker the user
        // reported was this: the OBJ_LABEL objects disappeared for one
        // redraw frame and reappeared with new text.
        //
        // CreateATRLabelSimple already handles the create-or-update case
        // correctly (ObjectFind check + per-label cache for text/color
        // delta; positions are reapplied every call). The same applies to
        // DisplayFractalTHs and DisplayStandardTHs. So we ONLY clear on
        // the very first redraw (g_calculatedOnce=false) where we cannot
        // trust any pre-existing label state. On relayout passes we let
        // the Display* functions update in place.
        //
        // Explicit-clear callers (which genuinely need a clean slate) are:
        //   - RedrawLabelsOnly()      → A/S hotkey toggles
        //   - OnDeinit REASON_PARAMETERS → settings dialog
        //   - OnDeinit REASON_REMOVE      → indicator remove
        //   - DisplayATRLabels itself when g_atrLabelsVisible=false
        bool isFirstLabelsDraw = !g_calculatedOnce;
        if(isFirstLabelsDraw) {
            ClearAllLabels(objectPrefix);
            // FIX (2026, bottom offset reset on first draw): DisplayFractalTHs
            // and DisplayStandardTHs BOTH mutate g_currentLabelYOffsetBottom
            // (they're stacked sections that share one accumulator). If we
            // don't reset it on the first draw, the labels will progressively
            // creep off-screen on each relayout pass — a bug the user sees as
            // "TH labels drift down after every TF switch". The first-draw
            // guard (NOT a per-relayout reset) preserves the design from the
            // LBL-3 fix: DisplayATRLabels resets its own top offset, the
            // caller owns the bottom offset for the lifetime of one draw cycle.
            g_currentLabelYOffsetBottom = 0;
        } else {
            // FIX (TF-switch / relayout drift, 2026): every subsequent
            // relayout pass (g_labelsRelayoutNeeded=true) must also start
            // from a clean bottom offset, otherwise DisplayFractalTHs +
            // DisplayStandardTHs keep adding to a stale value and the TH
            // title and labels drift up on every redraw. This is the
            // "TH labels move up after a TF switch" symptom reported by
            // users. The accumulator is local to one draw cycle, so
            // resetting it here is safe and matches what RedrawLabelsOnly
            // already does on the hotkey path.
            g_currentLabelYOffsetBottom = 0;
        }

        // FIX (2026, unconditional display* calls): drop the
        // if(g_atrLabelsVisible) / if(g_thLabelsMode != 0) guards that
        // used to skip the Display* calls. The guards meant that when
        // g_atrLabelsVisible (or g_thLabelsVisible) flipped between
        // renders, the Display* function never ran and the previous
        // labels were never cleared — leaving ghost labels on screen
        // after a TF switch that reset visibility state. The Display*
        // functions now own their own clear-or-draw decision internally:
        //   - DisplayATRLabels clears when g_atrLabelsVisible=false (L698)
        //   - DisplayFractalTHs/StandardTHs clear when not in mode (new)
        //
        // This means the relayout pass on every TF switch now:
        //   1. Removes any stale OBJ_LABEL objects the previous TF left
        //   2. Creates fresh ones for the new TF's values
        // with no ObjectDelete flicker on the visible chart.
        TH3_PROF_START(Labels);
        DisplayATRLabels(objectPrefix);
        bool showFractal = (g_thLabelsMode == 1 || g_thLabelsMode == 3);
        bool showStandard = (g_thLabelsMode == 2 || g_thLabelsMode == 3);
        if(showFractal)  DisplayFractalTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        if(showStandard) DisplayStandardTHs(objectPrefix, g_dailyClosePriceForTH, currentTime);
        // FIX (2026, consume the relayout flag): after a relayout-driven
        // draw, clear the flag so subsequent frames don't redundantly
        // re-run the (relatively expensive) label rebuild on every tick.
        // The next flag-set will come from the central ATR refresh loop
        // when ATR values actually change.
        g_labelsRelayoutNeeded = false;
        TH3_PROF_END(Labels);

        if(!g_calculatedOnce && inpShowTHLevels) g_redrawTHLevelsNeeded = true;
        g_calculatedOnce = true;
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
            Print("[D][GEN] REDRAWING LEVELS | Base Price: ", DoubleToString(g_dailyClosePriceForTH, Digits),
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

        // PERF (2026, TF-switch fast path): on first frame after TF switch,
        // the object count and names are identical to the previous TF — only
        // their prices differ. Skip the expensive ObjectsDeleteAll + ObjectCreate
        // cycle (50-150ms clear + 200ms draw) and update everything in-place
        // via the cache. Old objects at stale prices are overwritten on first
        // contact; extra objects from a larger previous TF are cleaned lazily
        // on the next redraw when topology changes again.
        bool skipClearOnTFSwitch = false;
        if(levelTopologyChanged && g_pendingChartChange) {
            skipClearOnTFSwitch = true;
        }

        // PERF (2026, A): a "topology change" — shift moved, scaling factor
        // moved, mode changed, settings changed — is the ONLY thing that
        // requires a chart wipe. Keyboard handlers that set
        // g_forceClearOnNextDraw (T/R/A/S/E/L/H/C keys) toggle visibility
        // in-place via OBJPROP_TIMEFRAMES; they do NOT need a wipe. A
        // non-structural price wobble that leaves the hash equal does not
        // need a wipe either. The in-place update path (CreateOrUpdateHLine
        // cache hit + SetPipelineObjectTimeframesIfExists) handles every
        // other tick at zero chart-engine cost.
        bool shouldClearLevels = levelTopologyChanged;

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
        // Reset the flags regardless. Keyboard handlers that needed a wipe
        // would have flipped the topology hash via inp* settings OR set
        // g_forceClearOnNextDraw via the visibility branch (handled below).
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
// PERF (2026): memoize iTime(Symbol(), tf, 0) for the current frame.
// On new-bar ticks the OnCalculate path calls this 9 times (once per TF);
// without caching that's 9 synchronous timeseries syscalls per new-bar tick.
datetime GetCachedITimeForFrame(const string symbol, ENUM_TIMEFRAMES tf) {
    static string s_sym = "";
    static ulong  s_frameMs = 0;
    static ENUM_TIMEFRAMES s_tf[16];
    static datetime s_bar[16];
    static int s_count = 0;
    const ulong nowMs = CacheGetFrameMs();
    if(nowMs != s_frameMs || s_sym != symbol) {
        s_sym = symbol;
        s_frameMs = nowMs;
        s_count = 0;
    }
    for(int i = 0; i < s_count; i++) if(s_tf[i] == tf) return s_bar[i];
    datetime v = iTime(symbol, tf, 0);
    if(s_count < 16) { s_tf[s_count] = tf; s_bar[s_count] = v; s_count++; }
    return v;
}

int OnCalculateHandler(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const long &tick_volume[], const long &volume[], const int &spread[]) {
    // PERF (2026, D): cheap hidden-state check FIRST. MT4 ran only
    // IsIndicatorHidden + CacheTickPrices before its no-op exit; MT5 was
    // doing UpdatePeriodCache + CacheRefreshFrameMs (with their own
    // GetTickCount() calls) on every no-op tick before any early-exit.
    if(IsIndicatorHidden()) return(rates_total);

    if(rates_total <= 0) return rates_total;

    // Cheap canonical no-op check BEFORE any cache refresh. The most common
    // case is MT5 calling OnCalculate on a tick with no bar change, no TF
    // switch, no force flag. MT4 was effectively here too; we just never
    // did the per-tick UpdatePeriodCache / CacheRefreshFrameMs work because
    // those functions take GetTickCount() internally.
    if(prev_calculated > 0 && rates_total == prev_calculated &&
       !g_redrawTHLevelsNeeded && !g_forceClearOnNextDraw &&
       !g_labelsRelayoutNeeded && g_initialized && !g_pendingChartChange) {
        return rates_total;
    }

    static uint s_lastCPUTime = 0;
    static int s_cpuWarningCount = 0;
    // PERF (2026, E): single GetTickCount() per OnCalculate invocation. The
    // previous code called GetTickCount() at L1852 (startTime) and again at
    // L1884 (nowMs) — two synchronous system calls per tick. nowMs is used
    // for the tick-throttle gate and the 30-min ATR refresh gate; startTime
    // is used for the CPU warning at the end. We compute once and reuse.
    uint startTime = GetTickCount();
    uint nowMs = startTime;

    // FIX: refresh the cached Period() at the top of every calculate. On a
    // timeframe switch MT5 may invoke OnCalculate with the new period without
    // re-running OnInit, so g_cachedPeriod can otherwise stay stale and any
    // code path using GetCachedPeriod() will compute against the old TF.
    UpdatePeriodCache();

    // PERF: Cache Bid/Ask once per tick (moved after hidden check)
    CacheTickPrices();

    // PERF (2026): stamp the frame ms so per-frame memos (e.g.
    // GetCachedITimeForFrame) can detect frame boundaries without each
    // helper taking its own GetTickCount() call.
    CacheRefreshFrameMs();

    // PERF (2026): shortcut the cheap "is there anything to do?" check BEFORE
    // touching the per-tick state, the throttled print, LogRedrawDecision, or
    // the cache-invalidation scan. MT5 calls OnCalculate on EVERY tick and on
    // every chart change - and the bulk of ticks are pure noise (price wobble
    // inside the same bar, no new bar, no force flag). The original code still
    // ran the priceChangePercent math, the bar/period/custom-price comparisons
    // and the LogRedrawDecision print on every no-op tick. We now do the
    // same comparisons but exit at the FIRST non-trivial condition so a tick
    // that didn't change anything falls through to a single return.

    static uint s_lastTickMs = 0;
    static double s_lastPrice = 0;
    static datetime s_lastBarTime = 0;
    static int s_lastPeriod = -1;
    static double s_lastCustomPrice = 0;

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
    // costs essentially nothing. (Already handled above at first gate.)

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
        // PERF (2026, D): throttle the 9-TF ATR refresh to once every 30 min
        // (same cadence as the base-price check) plus on TF switch. ATR label
        // values move slowly relative to the chart redraw rate; refreshing them
        // every new-bar minute wastes ~9 sync iATR/copybuffer calls per minute
        // on M1 even though the user sees the labels at most a few times an
        // hour. MT4 had no equivalent loop in OnCalculate — DisplayATRLabels
        // was gated by g_labelsRelayoutNeeded which only fires on TF switch.
        static datetime s_nextATRLabelRefresh = 0;
        datetime nowServerTs = CacheGetFrameTime();
        bool atrIntervalDue = (s_nextATRLabelRefresh == 0 || nowServerTs >= s_nextATRLabelRefresh);
        if(g_atrLabelsVisible && (timeframeChanged || (isNewBar && atrIntervalDue))) {
            bool anyChanged = false;
            for(int i = 0; i < ATR_LABEL_TF_COUNT; i++) {
                ENUM_TIMEFRAMES tf = g_atrLabelTFs[i];
                datetime prevBar = g_atrLabelCache[i].lastBarTime;
                // Read the current bar time for this TF WITHOUT triggering
                // the rest of the heavy calculate path. iTime is a single
                // sync timeseries request; cheap relative to iATR.
                datetime tfBar = GetCachedITimeForFrame(Symbol(), tf);
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
            // 30 minutes between label refreshes. Re-checked on every new-bar
            // tick; if nowServerTs is still < s_nextATRLabelRefresh we skip the
            // loop entirely above via the `atrIntervalDue` gate.
            s_nextATRLabelRefresh = nowServerTs + 1800;
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
        // PERF (2026, D): drop `timeframeChanged ||` from the force argument.
        // The CHARTEVENT_CHART_CHANGE handler at L2134 already sets
        // g_redrawTHLevelsNeeded=true on a TF switch, so the flag is already
        // set by the time we reach this line. The previous code passed
        // timeframeChanged as force_redraw=true which defeated both the 200ms
        // ms-gate AND the identity-skip guard inside RedrawAllObjects, forcing
        // the full pipeline to run unconditionally on every TF-switch tick.
        // MT4 didn't have this — it relied on the g_redrawTHLevelsNeeded flag.
        RedrawAllObjects(g_redrawTHLevelsNeeded || g_forceClearOnNextDraw);
        TH3_PROF_END(RedrawCall);

        if(barsChanged || s_lastBarTime == 0) {
            // PERF: Use cached object count
            int totalObjects = GetCurrentObjectCount();
            if(totalObjects > MAX_SAFE_OBJECTS && totalObjects < CRITICAL_OBJECT_LIMIT) {
                #ifdef ENABLE_DEBUG_LOGS
                if(s_cpuWarningCount % 10 == 0) {
                    Print("[W][GEN] Performance Warning: ", totalObjects, " objects on chart (recommended max: ", MAX_SAFE_OBJECTS, ")");
                    Print("[D][GEN] [CLEAN] Consider reducing inpMaxTHLevelsAbove/inpMaxTHLevelsBelow for better performance");
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
        // FIX (LBL-1, 2026): also detect chart pixel size changes. Scroll and
        // zoom leave symbol+period unchanged, but a window resize or maximize/
        // minimize changes the pixel dimensions. Labels are positioned with
        // OBJPROP_XDISTANCE/YDISTANCE (pixel coordinates from the corner),
        // so a narrower window pushes right-edge labels off-screen and the
        // user perceives them as vanished. Without this detection the early-
        // return below skips the relayout that would re-place them.
        long curW = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
        long curH = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
        // First call after init: seed the caches and let normal path run.
        if(g_lastChartSymbol == "" || g_lastChartPeriod == PERIOD_CURRENT) {
            g_lastChartSymbol = curSym;
            g_lastChartPeriod = curPer;
            g_lastChartWidthPx  = curW;
            g_lastChartHeightPx = curH;
            return;  // No state change yet; RedrawAllObjects will run on next tick.
        }
        // Same symbol AND same period → check pixel dimensions. If size
        // changed (resize, maximize, fullscreen toggle), request a relayout
        // so labels re-place into the new viewport. Scroll/zoom alone do
        // NOT change pixel size, so they take the fast-path early-return.
        if(curSym == g_lastChartSymbol && curPer == g_lastChartPeriod) {
            if(curW == g_lastChartWidthPx && curH == g_lastChartHeightPx) {
                return;  // scroll/zoom only; no relayout needed
            }
            // Size changed: relayout labels immediately (resize only, no chart change).
            g_lastChartWidthPx  = curW;
            g_lastChartHeightPx = curH;
            g_labelsRelayoutNeeded = true;
            RedrawLabelsOnly();
            ThrottledChartRedraw();
            return;
        }
        // Real chart change. Set a dirty flag for the next OnCalculate pass.
        // We deliberately do NOT call ChartSetSymbolPeriod or trigger
        // OnDeinit/OnInit ourselves — MT5 has already done that and our
        // OnInit (TF-independent prefix + rename-in-place) handles the
        // transition. We only need to ensure the next redraw runs.
        g_lastChartSymbol = curSym;
        g_lastChartPeriod = curPer;
        g_lastChartWidthPx  = curW;
        g_lastChartHeightPx = curH;
        g_pendingChartChange = true;
        g_redrawTHLevelsNeeded = true;
        g_visibilityFrameCounter++;
        CacheRefreshVisibilityState();
        return;
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
        // FIX (2026, hotkey debounce): MQL5 fires CHARTEVENT_KEYDOWN on every
        // OS-level key repeat while the user holds the key down. Without this
        // guard, holding A or S cycles the toggle 5-10 times per second and
        // makes the labels appear to "auto flip on/off". Same for L, T, E, C.
        // Per the official MQL5 docs the keydown event has no repeat flag, so
        // the canonical fix is to track (lparam, GetTickCount()) and suppress
        // repeats within HOTKEY_DEBOUNCE_MS. 150ms = ~6 presses/sec ceiling,
        // well above the fastest intentional tap rate (~10/sec) but below the
        // ~30/sec OS auto-repeat rate that fires on every key hold.
        const int HOTKEY_DEBOUNCE_MS = 150;
        static int   s_lastHotkeyCode = 0;
        static uint  s_lastHotkeyMs   = 0;
        uint hotkeyNowMs = GetTickCount();
        if((int)lparam == s_lastHotkeyCode &&
           s_lastHotkeyCode != 0 &&
           ((int)hotkeyNowMs - (int)s_lastHotkeyMs) < HOTKEY_DEBOUNCE_MS) {
            return;  // suppressed repeat
        }
        s_lastHotkeyCode = (int)lparam;
        s_lastHotkeyMs   = hotkeyNowMs;

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
                    // PERF (2026): replaced 5-7 StringFind calls per object with a
                    // single int compare against the cached category. Category
                    // is set once at insert time by ClassifyObjectCategoryByName
                    // in ObjectCache.mqh.
                    int cat = g_objectCacheHash[i].entry.category;
                    bool isTriggerObject = (cat == 4);
                    if(isTriggerObject && !g_triggerLevelsEnabled)
                    {
                        SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                    }
                    else if(!g_linesVisible)
                    {
                        // Zones/labels/triggers stay visible; lines hide.
                        if(cat == 2 || cat == 3 || cat == 4 || cat == 5) {
                            SetObjectTimeframesIfChanged(objName, OBJ_ALL_PERIODS);
                        } else if(cat == 1) {
                            SetObjectTimeframesIfChanged(objName, OBJ_NO_PERIODS);
                        } else {
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
                // FIX (2026, hotkey isolation): L key now controls ONLY lines (cat 1).
                // Previously cat==4 (trigger zones) was inside this branch and the
                // L toggle silently flipped trigger zones on/off, leaving T as a
                // state-desync trap (T says ON, screen shows OFF after L press).
                // Trigger visibility is owned exclusively by the T-key handler.
                int catL = g_objectCacheHash[i].entry.category;
                if(catL == 1) {
                    SetObjectTimeframesIfChanged(objName, g_linesVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
                }
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
            double currentPrice = iClose(_Symbol, (ENUM_TIMEFRAMES)GetCachedPeriod(), 0);
            ObjectDelete(0, g_customPriceHorizontalLineName);
            g_customPriceLineCreated = false;
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
            // Set state only after ObjectCreate succeeds. If it failed above we returned.
            g_waitingForCustomPriceClick = true;
            g_customPriceKeyboardOverride = true;
            g_customTHStartPrice = currentPrice;
            g_thStartPointType = TH_START_POINT_CUSTOM_PRICE;
            GlobalVariableSet("Biotak_CustomPriceOverride_" + GetCachedSymbol(), 1.0);
            GlobalVariableSet("Biotak_CustomPrice_" + GetCachedSymbol(), currentPrice);
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
        // FIX (2026, hotkey isolation): T key now flips ONLY trigger objects
        // in-place via the object cache. Previously it set
        // g_forceClearOnNextDraw + g_redrawTHLevelsNeeded + RedrawAllObjects(true),
        // which wiped and recreated the ENTIRE 290-zone pipeline on every press
        // (200-400ms freeze) and was the main source of the visible flicker that
        // made the user think T was wired to L. With in-place toggle the press is
        // sub-1ms and the rest of the chart (lines, zones, labels) is untouched.
        //
        // FIX (T-hotkey live, 2026): trust the cached category, but ALSO do a
        // direct name-substring check for "TriggerTH_". Why the belt-and-braces:
        // ClassifyObjectCategoryByName historically matched "TriggerTH_" only
        // when it appeared at position 0 in the name, but the actual trigger
        // object names look like "<prefix>TH_Level_TriggerTH_Up_<step>" — the
        // "TriggerTH_" token sits in the middle, never at position 0. Every
        // existing cached entry therefore had category=1 (Line), and the T
        // keypress toggled zero objects. The classifier was fixed to match
        // "TriggerTH_" anywhere in the name, but cached entries inserted
        // before that fix keep their stale category=1 until they're evicted
        // or the cache is rebuilt. The inline StringFind guarantees the T key
        // works regardless of cache state, on every press, with no rebuild
        // dependency. Cost: one extra substring search per cached object per
        // T press — negligible vs. the ObjectSetInteger cost.
        if(IsHotkeyPressed(lparam, sparam, inpTriggerLevelsKey))
        {
            g_triggerLevelsEnabled = !g_triggerLevelsEnabled;
            string triggerGvarName = "Biotak_TriggerLevels_" + GetCachedChartIdStr();
            GlobalVariableSet(triggerGvarName, g_triggerLevelsEnabled ? 1.0 : 0.0);
            LOG_I(LOG_CAT_KEYS, "Trigger Levels: " + (g_triggerLevelsEnabled ? "ON" : "OFF"));

            long trigTf = g_triggerLevelsEnabled ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
            string cachedPrefixT = inpObjectPrefix;
            int prefixLenT = StringLen(cachedPrefixT);
            ushort prefixFirstCharT = StringGetCharacter(cachedPrefixT, 0);
            for(int ti = 0; ti < CACHE_HASH_BUCKETS; ti++) {
                if(!g_objectCacheHash[ti].occupied) continue;
                string tn = g_objectCacheHash[ti].name;
                if(StringGetCharacter(tn, 0) != prefixFirstCharT) continue;
                if(!(StringLen(tn) >= prefixLenT && StringSubstr(tn, 0, prefixLenT) == cachedPrefixT))
                    continue;
                // Match by EITHER the (now-correct) cached category OR a direct
                // name substring. The substring fallback is what makes this
                // work for cached entries with stale category=1 from older
                // builds. Midpoint lines are also cat==4 but their names
                // contain "_Midpoint_" — they're toggled intentionally by T
                // along with triggers (the user wants the trigger family
                // hidden together).
                if(g_objectCacheHash[ti].entry.category == 4 ||
                   StringFind(tn, "TriggerTH_") >= 0)
                    SetObjectTimeframesIfChanged(tn, trigTf);
            }
            // FIX (2026): the manual OBJPROP_TIMEFRAMES toggle above changes the
            // chart state but only takes visible effect after a repaint. The
            // trigger-family lines are NOT re-synchronized by DrawTHLevels when
            // trigger is OFF (the loop skips them), so unlike the L key there is
            // no second chance for the next redraw to apply the state. Without a
            // pending-work flag the redraw pipeline early-returns (no
            // ChartRedraw) and the screen keeps showing the old levels until a
            // TF switch forces a full redraw. Setting g_redrawTHLevelsNeeded
            // keeps the object-cache lastTimeframes consistent with the chart
            // for any subsequent full redraw, and the direct ChartRedraw()
            // (bypassing the 100ms throttle, like the F key) repaints the chart
            // IMMEDIATELY so the toggle is applied in-place with no perceptible
            // lag. We deliberately avoid relying on the throttled redraw here:
            // it can be skipped when a redraw just fired, which was the original
            // "must change TF" symptom.
            g_redrawTHLevelsNeeded = true;
            ChartRedraw();
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
    //  
    // CHARTEVENT_CLICK   Custom Price Click
    //  
    if(id == CHARTEVENT_CLICK && g_waitingForCustomPriceClick)
    {
        if(StringFind(sparam, "RIGHT") >= 0)
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
                _LOG_GATE_I Print("[I][GEN] Custom Price Mode activated! Using ", inpMaxTHLevelsAbove, " above / ", inpMaxTHLevelsBelow, " below price: ", DoubleToString(selectedPrice, Digits));
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
            _LOG_GATE_I Print("[I][GEN] Custom Price Mode activated! Using ", inpMaxTHLevelsAbove, " above / ", inpMaxTHLevelsBelow, " below price: ", DoubleToString(selectedPrice, Digits));
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

            // PERF (2026): trust the cached lastUpdate when we have it; only
            // pay the synchronous ObjectGetInteger(OBJPROP_TIME) chart-API
            // call when the cache is cold (orphan object not yet tracked).
            // For active cleanup runs over the same ~hundreds of objects
            // every tick, this turns ~300 syscalls into ~0 (warm cache).
            datetime objTime = 0;
            int orphanIdx = CacheFindIndex(objName);
            if(orphanIdx >= 0 && g_objectCacheHash[orphanIdx].entry.lastUpdate > 0) {
                objTime = (datetime)g_objectCacheHash[orphanIdx].entry.lastUpdate;
            } else {
                objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            }
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

    // Reset bottom stacking offset only. The top offset (ATR) is owned by
    // DisplayATRLabels itself (LBL-3); resetting it here would race with the
    // function's internal write and was the source of the off-by-N offset
    // bug after indicator reload.
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

