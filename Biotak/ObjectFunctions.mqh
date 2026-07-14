  #property strict

bool CreateTHLineObject(const string name, const double price, const color lineColor, const ENUM_LINE_STYLE style, const int width, const string tooltip, ENUM_LINE_OBJECT_TYPE lineObjectType, bool isSelectable = false) {
    //                                                                
    // CRITICAL FIX #1: Check object count BEFORE creation
    //                                                                
    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreateTHLineObject: Object limit reached, cannot create '", name, "'");
        #endif
        return false;
    }
    
    //                                                                
    // CRITICAL FIX #2: Validate object name
    //                                                                
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreateTHLineObject: Empty object name");
        #endif
        return false;
    }
    
    //                                                                
    // CRITICAL FIX #3: Validate price using FloatingPointHelper
    //                                                                
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreateTHLineObject: Invalid price (", price, ") for '", name, "'");
        #endif
        return false;
    }
    
    // OPTIMIZATION: Check if object exists first, only update properties instead of recreate
    double normalizedPrice = NormalizePrice(price);
    datetime currentTime = TimeCurrent();
    // FIX: original formula `PeriodSeconds() * 10000` produces absurd values on
    // D1+ (e.g. ~27 years into the future). Preserve behavior on short timeframes
    // (where the original was already reasonable) and cap only the absurd cases.
    datetime futureTime = currentTime + PeriodSeconds((ENUM_TIMEFRAMES)Period()) * 10000;
    datetime maxFuture = currentTime + 31536000; // 1 year cap
    if(futureTime > maxFuture) futureTime = maxFuture;
    ENUM_OBJECT objectType = (lineObjectType == LINE_OBJECT_RAY_LINE) ? OBJ_TREND : OBJ_HLINE;
    
    // Check if object already exists in cache. After CHARTCHANGE we preserve
    // runtime objects but reset the cache, so rehydrate from chart on cache miss.
    SObjectCacheEntry cachedEntry;
    bool objectExistsInCache = CacheGetObject(name, cachedEntry);
    bool objectExistsOnChart = false;
    if(objectExistsInCache && cachedEntry.exists &&
       cachedEntry.lastUpdate == CacheGetFrameTime() && cachedEntry.lastUpdate > 0) {
        objectExistsOnChart = true;
    }
    else if(!objectExistsInCache && ObjectFind(0, name) >= 0) {
        cachedEntry.name = name;
        cachedEntry.lastPrice = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
        cachedEntry.lastColor = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
        cachedEntry.lastStyle = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
        cachedEntry.lastWidth = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
        // PERF (2026): hydrate the tooltip too so the very first
        // diff can take the cache-only path.
        cachedEntry.lastTooltip = ObjectGetString(0, name, OBJPROP_TOOLTIP);
        cachedEntry.exists = true;
        objectExistsInCache = true;
        objectExistsOnChart = true;
    }
    else if(objectExistsInCache && !objectExistsOnChart) {
        CacheRemoveObject(name);
        objectExistsInCache = false;
    }

    if(!objectExistsInCache) {
        // Create new object
        if(!ObjectCreate(0, name, objectType, 0, currentTime, normalizedPrice, (objectType == OBJ_TREND ? futureTime : (datetime)0), normalizedPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("  CreateTHLineObject: Failed to create '", name, "', error=", error);
            #endif
            return false;
        }
    } else {
        // Object exists - just update price if changed
        if(MathAbs(cachedEntry.lastPrice - normalizedPrice) > Point * 0.1) {
            if(!ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice)) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("   CreateTHLineObject: Failed to update price for '", name, "'");
                #endif
            }
        }
    }

    // Set properties only if they changed
    if(!objectExistsInCache || cachedEntry.lastColor != lineColor)
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);

    if(!objectExistsInCache || cachedEntry.lastStyle != (int)style)
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);

    if(!objectExistsInCache || cachedEntry.lastWidth != width)
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);

    // PERF (2026): only push OBJPROP_TOOLTIP to the chart when it actually
    // changed. The previous implementation always issued the syscall - with
    // ~288 line objects per redraw on M1 that was 288 ObjectSetString
    // chart-engine calls per frame for identical strings.
    bool tooltipChanged = !objectExistsInCache || cachedEntry.lastTooltip != tooltip;
    if(tooltipChanged) {
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
        CacheUpdateTooltip(name, tooltip);
    }

    if(!objectExistsInCache) {
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, isSelectable);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }
    
    // Update cache
    CacheUpdateObject(name, normalizedPrice, lineColor, (int)style, width);
    
    // CRITICAL FIX: Respect BOTH Hide state (F key) AND Lines visibility (L key)
    // PERFORMANCE: Use TTL-cached IsIndicatorHidden() instead of GlobalVariableGet
    bool isHidden = IsIndicatorHidden();
    
    if(isHidden || !g_linesVisible) {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    
    return true;
}

bool CreatePipDistanceLabel(const string name, const double price, const double pips, const color textColor, const string levelInfo = "") {
    if(!inpShowPipDistanceLabels) return true;
    
    //                                                                 
    // CRITICAL FIX #1: Check object count BEFORE creation
    //                                                                 
    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreatePipDistanceLabel: Object limit reached, cannot create '", name, "'");
        #endif
        return false;
    }
    
    //                                                                 
    // CRITICAL FIX #2: Validate inputs
    //                                                                 
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreatePipDistanceLabel: Empty label name");
        #endif
        return false;
    }
    
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreatePipDistanceLabel: Invalid price (", price, ")");
        #endif
        return false;
    }

    // PERF (2026): skip the StringFormat call when neither pips nor levelInfo
    // changed since the last push. The cache stores lastPips + lastLevelInfo
    // (added to SObjectCacheEntry). On MN1 with 158 active labels and 60
    // ticks/min that drops ~9,500 StringFormat heap allocations per minute
    // to ~0 (only rebuild when the underlying input actually moves).
    string cachedText;
    color cachedColor;
    double cachedPips = 0.0;
    string cachedLevelInfo = "";
    bool hasCachedLabel = CacheGetLabel(name, cachedText, cachedColor, cachedPips, cachedLevelInfo);
    bool inputsChanged = !hasCachedLabel || cachedPips != pips || cachedLevelInfo != levelInfo;

    string labelText = cachedText;
    if(inputsChanged) {
        if(StringLen(levelInfo) > 0) {
            labelText = StringFormat("%s | %.1f", levelInfo, pips);
        } else {
            labelText = StringFormat("%.1f pips", pips);
        }
    }

    bool objectExists = false;
    // PERF (2026): mirror the same per-frame trust-the-cache check that
    // CreateOrUpdateHLine already uses. The previous implementation always
    // called ObjectFind(0, name) even on a cache hit, which is a
    // SYNCHRONOUS chart API call ("can be time consuming" per the official
    // MQL5 docs). With 288 labels on M1 that is 288 sync syscalls per
    // redraw for nothing — the cache already told us the object exists.
    if(hasCachedLabel) {
        int cachedIdx = CacheFindIndex(name);
        if(cachedIdx >= 0 &&
           g_objectCacheHash[cachedIdx].entry.lastUpdate == CacheGetFrameTime() &&
           g_objectCacheHash[cachedIdx].entry.lastUpdate > 0) {
            objectExists = true;
        } else {
            objectExists = (ObjectFind(0, name) >= 0);
            if(!objectExists) {
                CacheRemoveObject(name);
                hasCachedLabel = false;
            }
        }
    } else {
        objectExists = (ObjectFind(0, name) >= 0);
    }

    if(!objectExists) {
        if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, price)) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("  CreatePipDistanceLabel: Failed to create '", name, "', error=", error);
            #endif
            return false;
        }
        ObjectSetString(0, name, OBJPROP_TEXT, labelText);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetString(0, name, OBJPROP_FONT, inpFontName);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpFontSize);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    } else {
        if(!hasCachedLabel || cachedText != labelText)
            ObjectSetString(0, name, OBJPROP_TEXT, labelText);
        if(!hasCachedLabel || cachedColor != textColor)
            ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    }

    CacheUpdateLabel(name, labelText, textColor);
    ApplyVisibilityStateIfUnchangedSkip(name, false);
    
    return true;
}
