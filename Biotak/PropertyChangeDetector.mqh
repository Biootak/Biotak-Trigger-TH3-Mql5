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
//+------------------------------------------------------------------+
bool HasAnyPropertyChanged(const double oldPrice, const double newPrice,
                           const color oldColor, const color newColor,
                           const int oldStyle, const int newStyle,
                           const int oldWidth, const int newWidth) {
    return HasPriceChanged(oldPrice, newPrice) ||
           HasColorChanged(oldColor, newColor) ||
           HasStyleChanged(oldStyle, newStyle) ||
           HasWidthChanged(oldWidth, newWidth);
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
