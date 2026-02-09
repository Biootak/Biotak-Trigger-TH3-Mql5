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
    
    // OPTIMIZATION: Check if object exists first, only update properties instead of recreate
    double normalizedPrice = NormalizePrice(price);
    datetime currentTime = TimeCurrent();
    datetime futureTime = currentTime + PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod()) * ZONE_EXTENSION_MULTIPLIER;
    ENUM_OBJECT objectType = (lineObjectType == LINE_OBJECT_RAY_LINE) ? OBJ_TREND : OBJ_HLINE;
    
    // Check if object already exists
    bool objectExists = (ObjectFind(0, name) >= 0);
    
    if(!objectExists) {
        // Create new object
        if(!ObjectCreate(0, name, objectType, 0, currentTime, normalizedPrice, (objectType == OBJ_TREND ? futureTime : (datetime)0), normalizedPrice)) {
            #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
            Print("❌ CreateTHLineObject: Failed to create '", name, "', error=", error);
            #endif
            return false;
        }
        
        // Set properties only for NEW objects (reduces API calls for existing objects)
        ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
        ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, isSelectable);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
    } else {
        // Object exists - just update price
        // OPTIMIZATION: Only update if price actually changed (reduces terminal calls)
        double currentObjPrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
        if(MathAbs(currentObjPrice - normalizedPrice) > GetCachedPoint() * 0.1) {
            if(!ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice)) {
                #ifdef ENABLE_DEBUG_LOGS
                Print("⚠️ CreateTHLineObject: Failed to update price for '", name, "'");
                #endif
            }
        }
        // PERF FIX: Only update color/style if they may have changed
        // For existing objects, skip redundant property setting
    }
    
    // CRITICAL FIX: Respect BOTH Hide state (F key) AND Lines visibility (L key)
    // PERFORMANCE: Use cached IsIndicatorHidden() instead of per-object GlobalVariable call
    if(IsIndicatorHidden() || !g_linesVisible) {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
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
    
    // CRITICAL FIX: Respect Hide state (F key)
    // PERFORMANCE: Use cached IsIndicatorHidden() instead of per-object GlobalVariable call
    if(IsIndicatorHidden()) {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
    } else {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }
    
    return true;
}
