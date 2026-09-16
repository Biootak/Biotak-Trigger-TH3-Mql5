  #property strict

#ifndef OBJECT_FUNCTIONS_MQH
#define OBJECT_FUNCTIONS_MQH
bool CreateTHLineObject(const string name, const double price, const color lineColor, const ENUM_LINE_STYLE style, const int width, const string tooltip, ENUM_LINE_OBJECT_TYPE lineObjectType, bool isSelectable = false) {
    // Validate before touching the terminal. The object-count query is only
    // needed on the actual creation path; checking it for every update adds a
    // synchronous ObjectsTotal call when a chart has many objects.
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreateTHLineObject: Empty object name");
        #endif
        return false;
    }
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("  CreateTHLineObject: Invalid price (", price, ") for '", name, "'");
        #endif
        return false;
    }

    double normalizedPrice = NormalizePrice(price);
    ENUM_OBJECT objectType = (lineObjectType == LINE_OBJECT_RAY_LINE) ? OBJ_TREND : OBJ_HLINE;
    SObjectCacheEntry cachedEntry;
    bool hasCachedObject = CacheGetObject(name, cachedEntry) && cachedEntry.exists;
    bool objectExists = hasCachedObject;

    // Managed objects are deleted through the event path and are therefore
    // safe to trust in the cache. ObjectFind is the one-time fallback for
    // objects that predate the cache (or were created outside this renderer).
    if(!objectExists)
        objectExists = (ObjectFind(0, name) >= 0);

    if(!objectExists) {
        if(!CanCreateObject()) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("  CreateTHLineObject: Object limit reached, cannot create '", name, "'");
            #endif
            return false;
        }

        datetime currentTime = TimeCurrent();
        int periodSeconds = PeriodSeconds(Period());
        datetime futureTime = currentTime + (periodSeconds > 0 ? periodSeconds * 10000 : 0);
        if(!ObjectCreate(0, name, objectType, 0, currentTime, normalizedPrice,
                        (objectType == OBJ_TREND ? futureTime : 0), normalizedPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("  CreateTHLineObject: Failed to create '", name, "', error=", error);
            #endif
            return false;
        }
    } else if(hasCachedObject && MathAbs(cachedEntry.lastPrice - normalizedPrice) > GetCachedPoint() * 0.1) {
        if(!ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("   CreateTHLineObject: Failed to update price for '", name, "'");
            #endif
        }
    } else if(!hasCachedObject) {
        // Synchronize an object found during cache warm-up once; subsequent
        // redraws use the cached price and avoid this terminal write.
        ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice);
    }

    // Set properties only when the cache says they differ.
    if(!hasCachedObject || cachedEntry.lastColor != lineColor)
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    if(!hasCachedObject || cachedEntry.lastStyle != (int)style)
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    if(!hasCachedObject || cachedEntry.lastWidth != width)
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);

    bool tooltipChanged = !hasCachedObject || cachedEntry.lastTooltip != tooltip;
    if(tooltipChanged)
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);

    if(!hasCachedObject) {
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, isSelectable);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    }

    CacheUpdateObject(name, normalizedPrice, lineColor, (int)style, width);
    if(tooltipChanged) CacheUpdateTooltip(name, tooltip);

    // Respect both the F hide state and the L line toggle, but do not enqueue
    // an identical TIMEFRAMES command on every redraw.
    bool isHidden = IsIndicatorHidden();
    SetManagedObjectTimeframes(name, (isHidden || !g_linesVisible) ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
    return true;
}

bool CreatePipDistanceLabel(const string name, const double price, const double pips, const color textColor, const string levelInfo = "") {
    if(!inpShowPipDistanceLabels) return true;
    
    // Validate before touching the terminal. Object-count checks are only
    // needed when this label is actually being created.
    
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

    // Format: "M1 +3 | 45.2 pips" or just "45.2 pips" if no levelInfo
    string labelText;
    if(StringLen(levelInfo) > 0) {
        labelText = StringFormat("%s | %.1f", levelInfo, pips);
    } else {
        labelText = StringFormat("%.1f pips", pips);
    }

    SObjectCacheEntry cachedEntry;
    bool hasCachedLabel = CacheGetObject(name, cachedEntry) && cachedEntry.exists;
    bool objectExists = hasCachedLabel;
    if(!objectExists)
        objectExists = (ObjectFind(0, name) >= 0);

    if(!objectExists) {
        if(!CanCreateObject()) {
            #ifdef ENABLE_DEBUG_LOGS
            Print("  CreatePipDistanceLabel: Object limit reached, cannot create '", name, "'");
            #endif
            return false;
        }
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
        if(!hasCachedLabel || cachedEntry.lastText != labelText)
            ObjectSetString(0, name, OBJPROP_TEXT, labelText);
        if(!hasCachedLabel || cachedEntry.lastColor != textColor)
            ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        if(!hasCachedLabel || MathAbs(cachedEntry.lastPrice - price) > GetCachedPoint() * 0.1)
            ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    }

    CacheUpdateLabelAtPrice(name, labelText, textColor, price);
    ApplyVisibilityStateIfUnchangedSkip(name, false);

    return true;
}

#endif // OBJECT_FUNCTIONS_MQH
