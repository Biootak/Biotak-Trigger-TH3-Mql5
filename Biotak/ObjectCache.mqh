//+------------------------------------------------------------------+
//|                                                  ObjectCache.mqh |
//|                                      Biotak Trigger TH3 Indicator |
//|                          Object Cache System for Flicker Prevention |
//+------------------------------------------------------------------+
#property copyright "Biotak"
#property strict

//+------------------------------------------------------------------+
//| Object Cache Entry Structure                                      |
//| Stores cached information about chart objects to avoid redundant  |
//| ObjectFind calls and track object properties                      |
//+------------------------------------------------------------------+
struct SObjectCacheEntry {
    string name;           // Object name
    double lastPrice;      // Last known price (for lines/zones)
    color lastColor;       // Last known color
    int lastStyle;         // Last known line style
    int lastWidth;         // Last known line width
    bool exists;           // True if object exists on chart
    datetime lastUpdate;   // Last update timestamp
};

//+------------------------------------------------------------------+
//| Global Cache Arrays                                               |
//| Simulates a hash map using parallel arrays for MQL4 compatibility |
//+------------------------------------------------------------------+
string g_objectCacheNames[];
SObjectCacheEntry g_objectCacheEntries[];
int g_objectCacheSize = 0;

// Maximum cache size (prevents unbounded growth)
#define MAX_CACHE_SIZE 1000

//+------------------------------------------------------------------+
//| Find object index in cache                                        |
//| Returns: Index if found, -1 if not found                         |
//+------------------------------------------------------------------+
int CacheFindIndex(const string name) {
    for(int i = 0; i < g_objectCacheSize; i++) {
        if(g_objectCacheNames[i] == name) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Add object to cache                                               |
//| Creates new cache entry with specified properties                |
//+------------------------------------------------------------------+
void CacheAddObject(const string name, const double price, 
                    const color clr, const int style, const int width) {
    // Check if object already exists in cache
    int idx = CacheFindIndex(name);
    
    if(idx >= 0) {
        // Update existing entry
        g_objectCacheEntries[idx].lastPrice = price;
        g_objectCacheEntries[idx].lastColor = clr;
        g_objectCacheEntries[idx].lastStyle = style;
        g_objectCacheEntries[idx].lastWidth = width;
        g_objectCacheEntries[idx].exists = true;
        g_objectCacheEntries[idx].lastUpdate = TimeCurrent();
        return;
    }
    
    // Check cache size limit
    if(g_objectCacheSize >= MAX_CACHE_SIZE) {
        Print("WARNING: Object cache size limit reached (", MAX_CACHE_SIZE, "). Triggering rebuild.");
        CacheRebuild();
        return;
    }
    
    // Add new entry
    ArrayResize(g_objectCacheNames, g_objectCacheSize + 1);
    ArrayResize(g_objectCacheEntries, g_objectCacheSize + 1);
    
    g_objectCacheNames[g_objectCacheSize] = name;
    
    g_objectCacheEntries[g_objectCacheSize].name = name;
    g_objectCacheEntries[g_objectCacheSize].lastPrice = price;
    g_objectCacheEntries[g_objectCacheSize].lastColor = clr;
    g_objectCacheEntries[g_objectCacheSize].lastStyle = style;
    g_objectCacheEntries[g_objectCacheSize].lastWidth = width;
    g_objectCacheEntries[g_objectCacheSize].exists = true;
    g_objectCacheEntries[g_objectCacheSize].lastUpdate = TimeCurrent();
    
    g_objectCacheSize++;
}

//+------------------------------------------------------------------+
//| Remove object from cache                                          |
//| Removes cache entry for deleted objects                          |
//+------------------------------------------------------------------+
void CacheRemoveObject(const string name) {
    int idx = CacheFindIndex(name);
    
    if(idx < 0) {
        return; // Object not in cache
    }
    
    // Shift remaining entries down
    for(int i = idx; i < g_objectCacheSize - 1; i++) {
        g_objectCacheNames[i] = g_objectCacheNames[i + 1];
        g_objectCacheEntries[i] = g_objectCacheEntries[i + 1];
    }
    
    g_objectCacheSize--;
    ArrayResize(g_objectCacheNames, g_objectCacheSize);
    ArrayResize(g_objectCacheEntries, g_objectCacheSize);
}

//+------------------------------------------------------------------+
//| Clear entire cache                                                |
//| Removes all cache entries and resets size                        |
//+------------------------------------------------------------------+
void CacheClear() {
    ArrayResize(g_objectCacheNames, 0);
    ArrayResize(g_objectCacheEntries, 0);
    g_objectCacheSize = 0;
}

//+------------------------------------------------------------------+
//| Check if object exists in cache                                   |
//| Returns: true if object exists in cache, false otherwise         |
//+------------------------------------------------------------------+
bool CacheObjectExists(const string name) {
    int idx = CacheFindIndex(name);
    
    if(idx < 0) {
        return false;
    }
    
    return g_objectCacheEntries[idx].exists;
}

//+------------------------------------------------------------------+
//| Get cached object properties                                      |
//| Returns: true if object found, false otherwise                   |
//| Output: entry parameter filled with cached data                  |
//+------------------------------------------------------------------+
bool CacheGetObject(const string name, SObjectCacheEntry &entry) {
    int idx = CacheFindIndex(name);
    
    if(idx < 0) {
        return false;
    }
    
    entry = g_objectCacheEntries[idx];
    return true;
}

//+------------------------------------------------------------------+
//| Update cached object properties                                   |
//| Updates existing cache entry with new property values            |
//+------------------------------------------------------------------+
void CacheUpdateObject(const string name, const double price, 
                       const color clr, const int style, const int width) {
    int idx = CacheFindIndex(name);
    
    if(idx < 0) {
        // Object not in cache, add it
        CacheAddObject(name, price, clr, style, width);
        return;
    }
    
    // Update existing entry
    g_objectCacheEntries[idx].lastPrice = price;
    g_objectCacheEntries[idx].lastColor = clr;
    g_objectCacheEntries[idx].lastStyle = style;
    g_objectCacheEntries[idx].lastWidth = width;
    g_objectCacheEntries[idx].exists = true;
    g_objectCacheEntries[idx].lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Rebuild cache from chart objects                                  |
//| Scans all chart objects and rebuilds cache from scratch          |
//| Used for cache invalidation or initialization                    |
//+------------------------------------------------------------------+
void CacheRebuild() {
    // Clear existing cache
    CacheClear();
    
    // Get total objects on chart (MT5: need to specify chart_id and sub_window)
    int totalObjects = ObjectsTotal(0, -1, -1);
    
    // Scan all objects and add TH-related objects to cache
    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(i, 0, -1, -1);
        
        // Only cache objects with "TH" prefix (indicator objects)
        if(StringFind(objName, "TH") == 0) {
            // Get object properties
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE);
            color clr = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            int style = (int)ObjectGetInteger(0, objName, OBJPROP_STYLE);
            int width = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
            
            // Add to cache
            CacheAddObject(objName, price, clr, style, width);
        }
    }
    
    Print("Object cache rebuilt: ", g_objectCacheSize, " objects cached from ", totalObjects, " total chart objects");
}

//+------------------------------------------------------------------+
//| Get cache statistics                                              |
//| Returns: Current cache size                                      |
//+------------------------------------------------------------------+
int CacheGetSize() {
    return g_objectCacheSize;
}

//+------------------------------------------------------------------+
//| Validate cache integrity                                          |
//| Checks if cached objects still exist on chart                    |
//| Returns: Number of invalid entries found                         |
//+------------------------------------------------------------------+
int CacheValidate() {
    int invalidCount = 0;
    
    for(int i = 0; i < g_objectCacheSize; i++) {
        string objName = g_objectCacheNames[i];
        
        // Check if object still exists on chart
        if(ObjectFind(0, objName) < 0) {
            g_objectCacheEntries[i].exists = false;
            invalidCount++;
        }
    }
    
    if(invalidCount > 0) {
        Print("Cache validation found ", invalidCount, " invalid entries out of ", g_objectCacheSize);
    }
    
    return invalidCount;
}

//+------------------------------------------------------------------+
