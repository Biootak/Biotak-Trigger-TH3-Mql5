bool CreateTHLineObject(const string name, const double price, const color lineColor, const ENUM_LINE_STYLE style, const int width, const string tooltip, ENUM_LINE_OBJECT_TYPE lineObjectType, bool isSelectable = false) {
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #1: Check object count BEFORE creation
    // ═══════════════════════════════════════════════════════════════
    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateTHLineObject: Object limit reached, cannot create '", name, "'");
        #endif
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #2: Validate object name
    // ═══════════════════════════════════════════════════════════════
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateTHLineObject: Empty object name");
        #endif
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #3: Validate price using FloatingPointHelper
    // ═══════════════════════════════════════════════════════════════
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreateTHLineObject: Invalid price (", price, ") for '", name, "'");
        #endif
        return false;
    }
    
    // Normalize price for consistent comparison
    double normalizedPrice = NormalizePrice(price);
    datetime currentTime = TimeCurrent();
    datetime futureTime = currentTime + PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod()) * ZONE_EXTENSION_MULTIPLIER;
    ENUM_OBJECT objectType = (lineObjectType == LINE_OBJECT_RAY_LINE) ? OBJ_TREND : OBJ_HLINE;
    
    // ═══════════════════════════════════════════════════════════════
    // FLICKERING FIX: Check cache first before ObjectFind
    // Requirements: 2.1, 11.3, 11.4
    // ═══════════════════════════════════════════════════════════════
    SObjectCacheEntry cachedEntry;
    bool objectInCache = CacheGetObject(name, cachedEntry);
    bool objectExists = false;
    
    if(objectInCache && cachedEntry.exists) {
        // Object exists in cache, trust cache
        objectExists = true;
    } else {
        // Not in cache or marked as non-existent, verify with ObjectFind
        objectExists = (ObjectFind(0, name) >= 0);
    }
    
    if(!objectExists) {
        // ═══════════════════════════════════════════════════════════════
        // Create new object
        // Requirements: 2.4, 8.1
        // ═══════════════════════════════════════════════════════════════
        if(!ObjectCreate(0, name, objectType, 0, currentTime, normalizedPrice, (objectType == OBJ_TREND ? futureTime : (datetime)0), normalizedPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("❌ CreateTHLineObject: Failed to create '", name, "', error=", error);
            #endif
            return false;
        }
        
        // ═══════════════════════════════════════════════════════════════
        // BATCH PROPERTY UPDATE OPTIMIZATION
        // Requirements: 8.1, 8.3 - Set all properties in sequence without intermediate operations
        // ═══════════════════════════════════════════════════════════════
        bool propsSuccess = true;
        propsSuccess = propsSuccess && ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        propsSuccess = propsSuccess && ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        propsSuccess = propsSuccess && ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        propsSuccess = propsSuccess && ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
        propsSuccess = propsSuccess && ObjectSetInteger(0, name, OBJPROP_SELECTABLE, isSelectable);
        propsSuccess = propsSuccess && ObjectSetInteger(0, name, OBJPROP_BACK, false);
        
        if(!propsSuccess) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("⚠️ CreateTHLineObject: Failed to set some properties for '", name, "', error=", error);
            #endif
            // Don't fail completely - object is created, just properties might be incomplete
        }
        
        // ═══════════════════════════════════════════════════════════════
        // Add to cache after successful creation
        // Requirements: 11.1
        // ═══════════════════════════════════════════════════════════════
        CacheAddObject(name, normalizedPrice, lineColor, style, width);
        
        // ═══════════════════════════════════════════════════════════════
        // Apply visibility state immediately for new objects
        // Requirements: 10.1, 10.2
        // ═══════════════════════════════════════════════════════════════
        ApplyVisibilityState(name, true); // true = is a line object
        
    } else {
        // ═══════════════════════════════════════════════════════════════
        // Object exists - use PropertyChangeDetector for selective updates
        // Requirements: 2.3, 3.1, 3.2, 3.3, 3.4, 3.5
        // ═══════════════════════════════════════════════════════════════
        
        // Detect which properties have changed
        SPropertyChangeResult changes;
        if(objectInCache) {
            // Use cached values for comparison
            changes = DetectPropertyChanges(cachedEntry, normalizedPrice, lineColor, style, width);
        } else {
            // No cache entry, get current values from chart object
            double currentPrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
            color currentColor = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
            int currentStyle = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
            int currentWidth = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
            
            changes = DetectPropertyChanges(currentPrice, normalizedPrice,
                                           currentColor, lineColor,
                                           currentStyle, style,
                                           currentWidth, width);
        }
        
        // ═══════════════════════════════════════════════════════════════
        // OPTIMIZED PROPERTY UPDATES
        // Requirements: 8.2, 8.5 - Single property optimization, avoid redundant calls
        // ═══════════════════════════════════════════════════════════════
        
        // Count how many properties changed
        int changedCount = 0;
        if(changes.priceChanged) changedCount++;
        if(changes.colorChanged) changedCount++;
        if(changes.styleChanged) changedCount++;
        if(changes.widthChanged) changedCount++;
        
        // Requirement 8.2: Optimize single property updates
        if(changedCount == 1) {
            // Single property optimization - fastest path
            if(changes.priceChanged) {
                if(!ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice)) {
                    #ifdef ENABLE_DEBUG_LOGS
                    Print("⚠️ CreateTHLineObject: Failed to update price for '", name, "'");
                    #endif
                }
            }
            else if(changes.colorChanged) {
                ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
            }
            else if(changes.styleChanged) {
                ObjectSetInteger(0, name, OBJPROP_STYLE, style);
            }
            else if(changes.widthChanged) {
                ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
            }
        }
        else if(changedCount > 1) {
            // Requirement 8.3: Batch property setting for multiple changes
            // Set all changed properties in sequence without intermediate operations
            bool updateSuccess = true;
            
            if(changes.priceChanged) {
                updateSuccess = updateSuccess && ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice);
            }
            if(changes.colorChanged) {
                updateSuccess = updateSuccess && ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
            }
            if(changes.styleChanged) {
                updateSuccess = updateSuccess && ObjectSetInteger(0, name, OBJPROP_STYLE, style);
            }
            if(changes.widthChanged) {
                updateSuccess = updateSuccess && ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
            }
            
            if(!updateSuccess) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ CreateTHLineObject: Failed to update some properties for '", name, "'");
                #endif
            }
        }
        // else: changedCount == 0, no updates needed (Requirement 8.5: avoid redundant calls)
        
        // ═══════════════════════════════════════════════════════════════
        // Update cache with new property values
        // Requirements: 11.1, 8.5 - Only update cache if properties actually changed
        // ═══════════════════════════════════════════════════════════════
        if(changes.anyChanged) {
            CacheUpdateObject(name, normalizedPrice, lineColor, style, width);
        }
        
        // ═══════════════════════════════════════════════════════════════
        // Apply visibility state for existing objects
        // Requirements: 10.1, 10.2
        // ═══════════════════════════════════════════════════════════════
        ApplyVisibilityState(name, true); // true = is a line object
    }
    
    return true;
}

bool CreatePipDistanceLabel(const string name, const double price, const double pips, const color textColor, const string levelInfo = "") {
    if(!inpShowPipDistanceLabels) return true;
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #1: Check object count BEFORE creation
    // ═══════════════════════════════════════════════════════════════
    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreatePipDistanceLabel: Object limit reached, cannot create '", name, "'");
        #endif
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FIX #2: Validate inputs
    // ═══════════════════════════════════════════════════════════════
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreatePipDistanceLabel: Empty label name");
        #endif
        return false;
    }
    
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ CreatePipDistanceLabel: Invalid price (", price, ")");
        #endif
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // FLICKERING FIX: Check cache first before ObjectFind
    // Requirements: 2.1, 11.3, 11.4
    // ═══════════════════════════════════════════════════════════════
    bool objectExists = CacheObjectExists(name);
    
    if(!objectExists) {
        // Verify with ObjectFind if not in cache
        objectExists = (ObjectFind(0, name) >= 0);
    }
    
    if(!objectExists) {
        // Create new label object
        if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, price)) {
            ObjectDelete(0, name);
            if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, price)) {
                #ifdef ENABLE_DEBUG_LOGS
                int error = GetLastError();
                Print("❌ CreatePipDistanceLabel: Failed to create '", name, "', error=", error);
                #endif
                return false;
            }
        }
        
        // Format: "M1 +3 | 45.2 pips" or just "45.2 pips" if no levelInfo
        string labelText;
        if(StringLen(levelInfo) > 0) {
            labelText = StringFormat("%s | %.1f", levelInfo, pips);
        } else {
            labelText = StringFormat("%.1f pips", pips);
        }
        
        ObjectSetString(0, name, OBJPROP_TEXT, labelText);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        
        // ✅ SECURITY FIX: Validate font name before use
        string safeFontName = inpFontName;
        string validFonts[9] = {"Arial", "Arial Black", "Courier New", "Tahoma", "Verdana",
                                "Times New Roman", "Calibri", "Segoe UI", "Consolas"};
        bool fontValid = false;
        for(int i = 0; i < 9; i++) {
            if(safeFontName == validFonts[i]) {
                fontValid = true;
                break;
            }
        }
        if(!fontValid) {
            safeFontName = "Arial";  // Fallback to safe default
        }
        
        ObjectSetString(0, name, OBJPROP_FONT, safeFontName);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpFontSize);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 5);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 2);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        
        // ═══════════════════════════════════════════════════════════════
        // Add to cache after successful creation
        // Requirements: 11.1
        // Note: Labels don't have style/width, use defaults for cache
        // ═══════════════════════════════════════════════════════════════
        CacheAddObject(name, price, textColor, 0, 0);
        
        // ═══════════════════════════════════════════════════════════════
        // Apply visibility state immediately for new objects
        // Requirements: 10.1
        // ═══════════════════════════════════════════════════════════════
        ApplyVisibilityState(name, false); // false = not a line object
        
    } else {
        // Object exists - labels are typically recreated with new text
        // Update text and color if needed
        string labelText;
        if(StringLen(levelInfo) > 0) {
            labelText = StringFormat("%s | %.1f", levelInfo, pips);
        } else {
            labelText = StringFormat("%.1f pips", pips);
        }
        
        ObjectSetString(0, name, OBJPROP_TEXT, labelText);
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
        
        // Update cache
        CacheUpdateObject(name, price, textColor, 0, 0);
        
        // Apply visibility state
        ApplyVisibilityState(name, false); // false = not a line object
    }
    
    return true;
}
