#ifndef PROPERTY_CHANGE_DETECTOR_MQH
#define PROPERTY_CHANGE_DETECTOR_MQH

#property copyright "Biotak"
#property strict

struct SPropertyChangeResult {
        bool priceChanged;     // Price property changed
    bool colorChanged;     // Color property changed
    bool styleChanged;     // Style property changed
    bool widthChanged;     // Width property changed
    bool anyChanged;       // Any property changed
};

    bool HasPriceChanged(const double oldPrice, const double newPrice) {
    // Handle special cases
    if(oldPrice == 0.0 && newPrice == 0.0) {
        return false;
    }
    
    // Use epsilon comparison for floating-point values
    double diff = MathAbs(oldPrice - newPrice);
    return diff > EPSILON_PRICE;
}
    bool HasColorChanged(const color oldColor, const color newColor) {
        return oldColor != newColor;
}
    bool HasStyleChanged(const int oldStyle, const int newStyle) {
        return oldStyle != newStyle;
}
    bool HasWidthChanged(const int oldWidth, const int newWidth) {
        return oldWidth != newWidth;
}
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

#endif
    // PROPERTY_CHANGE_DETECTOR_MQH
