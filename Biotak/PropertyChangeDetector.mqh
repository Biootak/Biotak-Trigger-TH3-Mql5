//+------------------------------------------------------------------+
//|                                        PropertyChangeDetector.mqh |
//|                                      Biotak Trigger TH3 Indicator |
//|                    Property Change Detection for Flicker Prevention |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict

//+------------------------------------------------------------------+
//| Property Change Result Structure                                  |
//| Tracks which properties have changed during an update operation   |
//+------------------------------------------------------------------+
struct SPropertyChangeResult {
    bool priceChanged;     // Price property changed
    bool colorChanged;     // Color property changed
    bool styleChanged;     // Style property changed
    bool widthChanged;     // Width property changed
    bool anyChanged;       // Any property changed
};

//+------------------------------------------------------------------+
//| Epsilon for floating-point price comparison                       |
//| Used to avoid false positives from floating-point precision       |
//| Value: 1e-8 (0.00000001) - appropriate for most currency pairs   |
//| Note: This epsilon-based comparison satisfies Requirement 10.1    |
//+------------------------------------------------------------------+
#define PRICE_EPSILON 0.00000001

//+------------------------------------------------------------------+
//| Check if price changed significantly                              |
//| Uses epsilon comparison to handle floating-point precision        |
//| Parameters:                                                       |
//|   oldPrice - Previous price value                                |
//|   newPrice - New price value                                     |
//| Returns: true if prices differ by more than epsilon              |
//+------------------------------------------------------------------+
bool HasPriceChanged(const double oldPrice, const double newPrice) {
    // Handle special cases
    if(oldPrice == 0.0 && newPrice == 0.0) {
        return false;
    }
    
    // Use epsilon comparison for floating-point values
    double diff = MathAbs(oldPrice - newPrice);
    return diff > PRICE_EPSILON;
}

//+------------------------------------------------------------------+
//| Check if color changed                                            |
//| Uses exact integer comparison (no epsilon) per Requirement 10.2  |
//| Parameters:                                                       |
//|   oldColor - Previous color value                                |
//|   newColor - New color value                                     |
//| Returns: true if colors are different                            |
//+------------------------------------------------------------------+
bool HasColorChanged(const color oldColor, const color newColor) {
    return oldColor != newColor;
}

//+------------------------------------------------------------------+
//| Check if style changed                                            |
//| Uses exact integer comparison (no epsilon) per Requirement 10.3  |
//| Parameters:                                                       |
//|   oldStyle - Previous style value (ENUM_LINE_STYLE)              |
//|   newStyle - New style value (ENUM_LINE_STYLE)                   |
//| Returns: true if styles are different                            |
//+------------------------------------------------------------------+
bool HasStyleChanged(const int oldStyle, const int newStyle) {
    return oldStyle != newStyle;
}

//+------------------------------------------------------------------+
//| Check if width changed                                            |
//| Parameters:                                                       |
//|   oldWidth - Previous width value                                |
//|   newWidth - New width value                                     |
//| Returns: true if widths are different                            |
//+------------------------------------------------------------------+
bool HasWidthChanged(const int oldWidth, const int newWidth) {
    return oldWidth != newWidth;
}

//+------------------------------------------------------------------+
//| Check if any visual property changed                              |
//| Comprehensive check for all object properties                     |
//| Uses short-circuit evaluation for performance optimization        |
//| Parameters:                                                       |
//|   oldPrice - Previous price value                                |
//|   newPrice - New price value                                     |
//|   oldColor - Previous color value                                |
//|   newColor - New color value                                     |
//|   oldStyle - Previous style value                                |
//|   newStyle - New style value                                     |
//|   oldWidth - Previous width value                                |
//|   newWidth - New width value                                     |
//| Returns: true if any property has changed                        |
//| Note: Checks properties in order of likelihood to change         |
//|       Returns immediately on first change detected (short-circuit)|
//+------------------------------------------------------------------+
bool HasAnyPropertyChanged(const double oldPrice, const double newPrice,
                           const color oldColor, const color newColor,
                           const int oldStyle, const int newStyle,
                           const int oldWidth, const int newWidth) {
    // Short-circuit evaluation: check most likely changes first
    // Price changes most frequently in real-time trading
    if(HasPriceChanged(oldPrice, newPrice)) {
        return true;
    }
    
    // Color changes less frequently (user settings, theme changes)
    if(HasColorChanged(oldColor, newColor)) {
        return true;
    }
    
    // Style changes rarely (user settings only)
    if(HasStyleChanged(oldStyle, newStyle)) {
        return true;
    }
    
    // Width changes rarely (user settings only)
    if(HasWidthChanged(oldWidth, newWidth)) {
        return true;
    }
    
    // No changes detected
    return false;
}

//+------------------------------------------------------------------+
//| Detect all property changes and return detailed result            |
//| Analyzes all properties and returns structured change information |
//| Parameters:                                                       |
//|   oldPrice - Previous price value                                |
//|   newPrice - New price value                                     |
//|   oldColor - Previous color value                                |
//|   newColor - New color value                                     |
//|   oldStyle - Previous style value                                |
//|   newStyle - New style value                                     |
//|   oldWidth - Previous width value                                |
//|   newWidth - New width value                                     |
//| Returns: SPropertyChangeResult with detailed change flags        |
//+------------------------------------------------------------------+
SPropertyChangeResult DetectPropertyChanges(const double oldPrice, const double newPrice,
                                            const color oldColor, const color newColor,
                                            const int oldStyle, const int newStyle,
                                            const int oldWidth, const int newWidth) {
    SPropertyChangeResult result;
    
    result.priceChanged = HasPriceChanged(oldPrice, newPrice);
    result.colorChanged = HasColorChanged(oldColor, newColor);
    result.styleChanged = HasStyleChanged(oldStyle, newStyle);
    result.widthChanged = HasWidthChanged(oldWidth, newWidth);
    result.anyChanged = result.priceChanged || result.colorChanged || 
                        result.styleChanged || result.widthChanged;
    
    return result;
}

//+------------------------------------------------------------------+
//| Overloaded version using SObjectCacheEntry                        |
//| Convenience function for cache-based change detection             |
//| Parameters:                                                       |
//|   cached - Cached object entry with old property values          |
//|   newPrice - New price value                                     |
//|   newColor - New color value                                     |
//|   newStyle - New style value                                     |
//|   newWidth - New width value                                     |
//| Returns: SPropertyChangeResult with detailed change flags        |
//+------------------------------------------------------------------+
SPropertyChangeResult DetectPropertyChanges(const SObjectCacheEntry &cached,
                                            const double newPrice,
                                            const color newColor,
                                            const int newStyle,
                                            const int newWidth) {
    return DetectPropertyChanges(cached.lastPrice, newPrice,
                                 cached.lastColor, newColor,
                                 cached.lastStyle, newStyle,
                                 cached.lastWidth, newWidth);
}

//+------------------------------------------------------------------+
//| Check if any property changed (cache-based convenience function)  |
//| Parameters:                                                       |
//|   cached - Cached object entry with old property values          |
//|   newPrice - New price value                                     |
//|   newColor - New color value                                     |
//|   newStyle - New style value                                     |
//|   newWidth - New width value                                     |
//| Returns: true if any property has changed                        |
//| Note: If cache entry is missing or invalid, caller should assume |
//|       properties changed and perform full update                 |
//+------------------------------------------------------------------+
bool HasAnyPropertyChanged(const SObjectCacheEntry &cached,
                           const double newPrice,
                           const color newColor,
                           const int newStyle,
                           const int newWidth) {
    return HasAnyPropertyChanged(cached.lastPrice, newPrice,
                                 cached.lastColor, newColor,
                                 cached.lastStyle, newStyle,
                                 cached.lastWidth, newWidth);
}

//+------------------------------------------------------------------+
//| Check if properties changed with cache lookup                     |
//| Handles missing cache entries by assuming properties changed      |
//| Parameters:                                                       |
//|   objectName - Name of the object to check                       |
//|   newPrice - New price value                                     |
//|   newColor - New color value                                     |
//|   newStyle - New style value                                     |
//|   newWidth - New width value                                     |
//| Returns: true if any property has changed or cache entry missing |
//| Note: Missing cache entries trigger full update (Requirement 10.6)|
//+------------------------------------------------------------------+
bool HasAnyPropertyChangedWithCacheLookup(const string objectName,
                                          const double newPrice,
                                          const color newColor,
                                          const int newStyle,
                                          const int newWidth) {
    SObjectCacheEntry cached;
    
    // If cache entry is missing, assume properties changed
    // This ensures full update occurs for new or uncached objects
    if(!CacheGetObject(objectName, cached)) {
        return true;  // Missing cache entry triggers full update
    }
    
    // Cache entry exists, perform normal comparison
    return HasAnyPropertyChanged(cached, newPrice, newColor, newStyle, newWidth);
}

//+------------------------------------------------------------------+
