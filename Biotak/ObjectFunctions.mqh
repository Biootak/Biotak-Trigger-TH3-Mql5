#ifndef OBJECT_FUNCTIONS_MQH
#define OBJECT_FUNCTIONS_MQH

#include "ObjectCache.mqh"

bool CreateTHLineObject(const string name, const double price, const color lineColor, const ENUM_LINE_STYLE style, const int width, const string tooltip, ENUM_LINE_OBJECT_TYPE lineObjectType, bool isSelectable = false) {

    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreateTHLineObject: Object limit reached, cannot create '", name, "'");
    #endif
    return false;
    }
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreateTHLineObject: Empty object name");
    #endif
    return false;
    }

    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreateTHLineObject: Invalid price (", price, ") for '", name, "'");
    #endif
    return false;
    }
    double normalizedPrice = NormalizePrice(price);
    // PERF: Use cached frame time and period seconds instead of per-object syscalls
    datetime currentTime = CacheGetFrameTime();
    static int s_cachedPeriodSec = 0;
    if(s_cachedPeriodSec == 0) s_cachedPeriodSec = PeriodSeconds((ENUM_TIMEFRAMES)GetCachedPeriod());
    datetime futureTime = currentTime + s_cachedPeriodSec * ZONE_EXTENSION_MULTIPLIER;
    ENUM_OBJECT objectType = (lineObjectType == LINE_OBJECT_RAY_LINE) ? OBJ_TREND : OBJ_HLINE;
    SObjectCacheEntry cachedEntry;
    bool objectInCache = CacheGetObject(name, cachedEntry);
    bool objectExists = false;
    if(objectInCache && cachedEntry.exists) {
        objectExists = true;
    } else {
        objectExists = (ObjectFind(0, name) >= 0);
    }
    
    if(!objectExists) {

        if(!ObjectCreate(0, name, objectType, 0, currentTime, normalizedPrice, (objectType == OBJ_TREND ? futureTime : (datetime)0), normalizedPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
            int error = GetLastError();
    Print("[ERR] CreateTHLineObject: Failed to create '", name, "', error=", error);
    #endif
    return false;
        }
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
    Print("[WARN] CreateTHLineObject: Failed to set some properties for '", name, "', error=", error);
    #endif
    }

        CacheAddObject(name, normalizedPrice, lineColor, style, width);
    ApplyVisibilityState(name, true);
        
    } else {

        SPropertyChangeResult changes;
    if(objectInCache) {
            changes = DetectPropertyChanges(cachedEntry, normalizedPrice, lineColor, style, width);
        } else {
        double currentPrice = ObjectGetDouble(0, name, OBJPROP_PRICE);
    color currentColor = (color)ObjectGetInteger(0, name, OBJPROP_COLOR);
    int currentStyle = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
    int currentWidth = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);
    changes = DetectPropertyChanges(currentPrice, normalizedPrice,
                                           currentColor, lineColor,
                                           currentStyle, style,
                                           currentWidth, width);
        }
    int changedCount = 0;
    if(changes.priceChanged) changedCount++;
    if(changes.colorChanged) changedCount++;
    if(changes.styleChanged) changedCount++;
    if(changes.widthChanged) changedCount++;
    if(changedCount == 1) {
        if(changes.priceChanged) {
                if(!ObjectSetDouble(0, name, OBJPROP_PRICE, normalizedPrice)) {
        #ifdef ENABLE_DEBUG_LOGS
                    Print("[WARN] CreateTHLineObject: Failed to update price for '", name, "'");
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
                Print("[WARN] CreateTHLineObject: Failed to update some properties for '", name, "'");
    #endif
    }
        }
    if(changes.anyChanged) {
            CacheUpdateObject(name, normalizedPrice, lineColor, style, width);
        }

        // PERF: Skip visibility update if state unchanged since last frame
        ApplyVisibilityStateIfUnchangedSkip(name, true);
    }
    return true;
}
    bool CreatePipDistanceLabel(const string name, const double price, const double pips, const color textColor, const string levelInfo = "") {
    if(!inpShowPipDistanceLabels) return true;
    if(!CanCreateObject()) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreatePipDistanceLabel: Object limit reached, cannot create '", name, "'");
    #endif
    return false;
    }
    if(StringLen(name) == 0) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreatePipDistanceLabel: Empty label name");
    #endif
    return false;
    }
    
    if(!IsValidPrice(price)) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[ERR] CreatePipDistanceLabel: Invalid price (", price, ")");
    #endif
    return false;
    }
    bool objectExists = CacheObjectExists(name);
    if(!objectExists) {
        objectExists = (ObjectFind(0, name) >= 0);
    }
    
    if(!objectExists) {
        if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, price)) {
            ObjectDelete(0, name);
    if(!ObjectCreate(0, name, OBJ_TEXT, 0, 0, price)) {
        #ifdef ENABLE_DEBUG_LOGS
                int error = GetLastError();
    Print("[ERR] CreatePipDistanceLabel: Failed to create '", name, "', error=", error);
    #endif
    return false;
            }
        }
    string labelText;
    if(StringLen(levelInfo) > 0) {
            labelText = StringFormat("%s | %.1f", levelInfo, pips);
        } else {
            labelText = StringFormat("%.1f pips", pips);
        }
        
        ObjectSetString(0, name, OBJPROP_TEXT, labelText);
    ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    // PERF: Cache font validation result to avoid 9-string comparison per call
    static string s_validatedFont = "";
    static string s_lastInputFont = "";
    string safeFontName;
    if(inpFontName == s_lastInputFont) {
            safeFontName = s_validatedFont;
        } else {
            s_lastInputFont = inpFontName;
    safeFontName = inpFontName;
    static string validFonts[9] = {"Arial", "Arial Black", "Courier New", "Tahoma", "Verdana",
                                "Times New Roman", "Calibri", "Segoe UI", "Consolas"};
    bool fontValid = false;
    for(int i = 0; i < 9; i++) {
        if(safeFontName == validFonts[i]) {
                fontValid = true;
    break;
            }
        }
        if(!fontValid) {
            safeFontName = "Arial";
        }
        s_validatedFont = safeFontName;
        }
        
        ObjectSetString(0, name, OBJPROP_FONT, safeFontName);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, inpFontSize);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_RIGHT);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 5);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 2);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    CacheAddObject(name, price, textColor, 0, 0);
    ApplyVisibilityState(name, false);
        
    } else {
        string labelText;
    if(StringLen(levelInfo) > 0) {
            labelText = StringFormat("%s | %.1f", levelInfo, pips);
        } else {
            labelText = StringFormat("%.1f pips", pips);
        }
        
        // PERF: Always update text (pip distance changes per tick)
        ObjectSetString(0, name, OBJPROP_TEXT, labelText);
    // PERF: Only update color/price if actually changed (skip ~800 API calls per redraw)
    SObjectCacheEntry labelCache;
    bool inCache = CacheGetObject(name, labelCache);
    if(!inCache || labelCache.lastColor != textColor) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
    }
    double normPrice = NormalizePrice(price);
    if(!inCache || MathAbs(labelCache.lastPrice - normPrice) > GetCachedPoint() * 0.1) {
        ObjectSetDouble(0, name, OBJPROP_PRICE, normPrice);
    }
    CacheUpdateObject(name, normPrice, textColor, 0, 0);
    // PERF: Skip visibility update if state unchanged since last frame
    ApplyVisibilityStateIfUnchangedSkip(name, false);
    }
    return true;
}
    #endif
