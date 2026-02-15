#ifndef OBJECT_CACHE_MQH
#define OBJECT_CACHE_MQH

#property copyright "Biotak"
#property strict

struct SObjectCacheEntry {
        string name;           // Object name
    double lastPrice;      // Last known price (for lines/zones)
    color lastColor;       // Last known color
    int lastStyle;         // Last known line style
    int lastWidth;         // Last known line width
    bool exists;           // True if object exists on chart
    datetime lastUpdate;   // Last update timestamp
};

// Hash-based cache configuration
#define CACHE_HASH_BUCKETS 2048  // Power of 2 for fast modulo (was 512 — increased to fit ~1200 objects)
#define CACHE_MAX_PROBE 8        // Maximum linear probing attempts

// Hash bucket structure
struct SObjectCacheSlot {
        string name;
    SObjectCacheEntry entry;
    bool occupied;
    bool deleted;         // Tombstone sentinel for linear probing
    datetime lastAccess;  // For LRU eviction
};

// Global hash-based cache
static SObjectCacheSlot g_objectCacheHash[CACHE_HASH_BUCKETS];
    static bool g_objectCacheHashInitialized = false;
    static int g_objectCacheSize = 0;

// PERF: O(1) LRU eviction tracking — avoids O(512) full scan on eviction
static int g_lruMinIdx = -1;
static datetime g_lruMinTime = 0;

// PERF: Cached TimeCurrent() - refreshed once per redraw frame via CacheRefreshFrameTime()
// Eliminates ~2000+ TimeCurrent() syscalls per redraw cycle
static datetime g_cacheFrameTime = 0;

void CacheRefreshFrameTime() {
    g_cacheFrameTime = TimeCurrent();
}

datetime CacheGetFrameTime() {
    if(g_cacheFrameTime == 0) g_cacheFrameTime = TimeCurrent();
    return g_cacheFrameTime;
}

// Maximum cache size (80% load factor of 2048 buckets)
#define MAX_CACHE_SIZE 1600

int HashObjectName(const string name) {
        uint hash = 5381;
    int len = StringLen(name);
    for(int i = 0; i < len; i++) {
        hash = ((hash << 5) + hash) + (uint)StringGetCharacter(name, i);
    }
    return (int)(hash % (uint)CACHE_HASH_BUCKETS);
}
    void InitializeObjectCacheHash() {
        if(g_objectCacheHashInitialized) return;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        g_objectCacheHash[i].name = "";
    g_objectCacheHash[i].occupied = false;
    g_objectCacheHash[i].deleted = false;
    g_objectCacheHash[i].lastAccess = 0;
    }
    
    g_objectCacheHashInitialized = true;
    g_objectCacheSize = 0;
    g_lruMinIdx = -1;
    g_lruMinTime = 0;
    _LOG_GATE_I Print("[I][SYNC] Object Cache Hash Initialized (", CACHE_HASH_BUCKETS, " buckets)");
    }
    int CacheFindIndex(const string name) {
    if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
    int slot = HashObjectName(name);
    
    // Linear probing with max attempts (skip tombstones, stop at truly empty)
    for(int probe = 0; probe < CACHE_MAX_PROBE; probe++) {
        int idx = (slot + probe) % CACHE_HASH_BUCKETS;
    if(!g_objectCacheHash[idx].occupied && !g_objectCacheHash[idx].deleted) {
            return -1;  // Empty slot (never used) - object not in cache
        }
        
        // Skip tombstone slots (deleted=true, occupied=false)
        if(g_objectCacheHash[idx].deleted && !g_objectCacheHash[idx].occupied)
            continue;
    if(g_objectCacheHash[idx].name == name) {
            // Update last access time for LRU
            g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
    return idx;  // Found
        }
    }
    
    return -1;  // Not found after max probes
}
    void CacheAddObject(const string name, const double price, 
                    const color clr, const int style, const int width) {
    if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
    
    // Check if object already exists in cache
    int idx = CacheFindIndex(name);
    if(idx >= 0) {
        // Update existing entry
        g_objectCacheHash[idx].entry.lastPrice = price;
    g_objectCacheHash[idx].entry.lastColor = clr;
    g_objectCacheHash[idx].entry.lastStyle = style;
    g_objectCacheHash[idx].entry.lastWidth = width;
    g_objectCacheHash[idx].entry.exists = true;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
    return;
    }
    
    // Check cache size limit - use LRU eviction if full
    if(g_objectCacheSize >= MAX_CACHE_SIZE) {
        EvictLRUEntry();
    }
    
    // Find empty slot using linear probing
    int slot = HashObjectName(name);
    for(int probe = 0; probe < CACHE_HASH_BUCKETS; probe++) {
        int insertIdx = (slot + probe) % CACHE_HASH_BUCKETS;
    if(!g_objectCacheHash[insertIdx].occupied || g_objectCacheHash[insertIdx].deleted) {
            // Found empty or tombstone slot - insert here
            g_objectCacheHash[insertIdx].name = name;
    g_objectCacheHash[insertIdx].entry.name = name;
    g_objectCacheHash[insertIdx].entry.lastPrice = price;
    g_objectCacheHash[insertIdx].entry.lastColor = clr;
    g_objectCacheHash[insertIdx].entry.lastStyle = style;
    g_objectCacheHash[insertIdx].entry.lastWidth = width;
    g_objectCacheHash[insertIdx].entry.exists = true;
    g_objectCacheHash[insertIdx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[insertIdx].occupied = true;
    g_objectCacheHash[insertIdx].deleted = false;
    g_objectCacheHash[insertIdx].lastAccess = CacheGetFrameTime();
    g_objectCacheSize++;
    // PERF: Track LRU minimum for O(1) eviction
    datetime insertTime = g_objectCacheHash[insertIdx].lastAccess;
    if(g_lruMinIdx < 0 || insertTime < g_lruMinTime) {
        g_lruMinIdx = insertIdx;
        g_lruMinTime = insertTime;
    }
    return;
        }
    }
    
    // All probed slots occupied - force eviction
    _LOG_GATE_W Print("[W][SYNC] Object cache collision - forcing LRU eviction");
    EvictLRUEntry();
    
    // Try again after eviction
    CacheAddObject(name, price, clr, style, width);
}
    void EvictLRUEntry() {
        if(g_objectCacheSize == 0) return;
    
    // PERF: O(1) fast path — use tracked LRU minimum if valid
    if(g_lruMinIdx >= 0 && g_lruMinIdx < CACHE_HASH_BUCKETS &&
       g_objectCacheHash[g_lruMinIdx].occupied) {
        int lruIdx = g_lruMinIdx;
        _LOG_GATE_D Print("[D][SYNC] [DEL] Evicting LRU cache entry (O(1)): '", g_objectCacheHash[lruIdx].name, "'");
        g_objectCacheHash[lruIdx].name = "";
        g_objectCacheHash[lruIdx].occupied = false;
        g_objectCacheHash[lruIdx].deleted = true;  // Tombstone
        g_objectCacheHash[lruIdx].lastAccess = 0;
        g_objectCacheSize--;
        // Invalidate tracked minimum — will be lazily refreshed
        g_lruMinIdx = -1;
        g_lruMinTime = 0;
        return;
    }
    
    // Fallback: Full scan to find LRU entry
    int lruIdx = -1;
    datetime oldestAccess = CacheGetFrameTime() + 86400;  // Start with future time
    
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(g_objectCacheHash[i].occupied && g_objectCacheHash[i].lastAccess < oldestAccess) {
            oldestAccess = g_objectCacheHash[i].lastAccess;
    lruIdx = i;
        }
    }
    if(lruIdx >= 0) {
        // Evict this entry
        _LOG_GATE_D Print("[D][SYNC] [DEL] Evicting LRU cache entry: '", g_objectCacheHash[lruIdx].name, "'");
    g_objectCacheHash[lruIdx].name = "";
    g_objectCacheHash[lruIdx].occupied = false;
    g_objectCacheHash[lruIdx].deleted = true;  // Tombstone
        g_objectCacheHash[lruIdx].lastAccess = 0;
    g_objectCacheSize--;
    // Invalidate tracked minimum
    g_lruMinIdx = -1;
    g_lruMinTime = 0;
    }
}
    void CacheRemoveObject(const string name) {
        int idx = CacheFindIndex(name);
    if(idx < 0) {
        return; // Object not in cache
    }
    
    // Mark slot as tombstone (preserves linear probing chain)
    g_objectCacheHash[idx].name = "";
    g_objectCacheHash[idx].occupied = false;
    g_objectCacheHash[idx].deleted = true;  // Tombstone sentinel
    g_objectCacheHash[idx].lastAccess = 0;
    g_objectCacheSize--;
    _LOG_GATE_D Print("[D][SYNC] [DEL] Removed object from cache (size now: ", g_objectCacheSize, ")");
    }
    void CacheClear() {
    if(!g_objectCacheHashInitialized) return;
    // PERF: Early exit when cache is already empty
    if(g_objectCacheSize == 0) return;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        g_objectCacheHash[i].name = "";
    g_objectCacheHash[i].occupied = false;
    g_objectCacheHash[i].deleted = false;
    g_objectCacheHash[i].lastAccess = 0;
    }
    
    g_objectCacheSize = 0;
    // Reset LRU tracking
    g_lruMinIdx = -1;
    g_lruMinTime = 0;
    _LOG_GATE_I Print("[I][SYNC] Object cache cleared");
    }
    bool CacheObjectExists(const string name) {
        int idx = CacheFindIndex(name);
    if(idx < 0) {
        return false;
    }
    return g_objectCacheHash[idx].entry.exists;
}
    bool CacheGetObject(const string name, SObjectCacheEntry &entry) {
        int idx = CacheFindIndex(name);
    if(idx < 0) {
        return false;
    }
    
    entry = g_objectCacheHash[idx].entry;
    return true;
}
    void CacheUpdateObject(const string name, const double price, 
                       const color clr, const int style, const int width) {
        int idx = CacheFindIndex(name);
    if(idx < 0) {
        // Object not in cache, add it
        CacheAddObject(name, price, clr, style, width);
    return;
    }
    
    // Update existing entry
    g_objectCacheHash[idx].entry.lastPrice = price;
    g_objectCacheHash[idx].entry.lastColor = clr;
    g_objectCacheHash[idx].entry.lastStyle = style;
    g_objectCacheHash[idx].entry.lastWidth = width;
    g_objectCacheHash[idx].entry.exists = true;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
}
    int CacheGetSize() {
        return g_objectCacheSize;
}
    void CacheRebuild() {
    // Clear existing cache
    CacheClear();
    
    // Get total objects on chart (MT5: need to specify chart_id and sub_window)
    int totalObjects = ObjectsTotal(0, -1, -1);
    
    // Scan all objects and add TH-related objects to cache
    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i, -1, -1);
        
        // PERF: Character comparison instead of StringFind for prefix check
        if(StringLen(objName) >= 2 && StringGetCharacter(objName, 0) == 'T' && StringGetCharacter(objName, 1) == 'H') {
            // Get object properties
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE);
    color clr = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
    int style = (int)ObjectGetInteger(0, objName, OBJPROP_STYLE);
    int width = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
            
            // Add to cache
            CacheAddObject(objName, price, clr, style, width);
        }
    }
    
    _LOG_GATE_D Print("[D][SYNC] Object cache rebuilt: ", g_objectCacheSize, " objects cached from ", totalObjects, " total chart objects");
}
    int CacheValidate() {
    if(!g_objectCacheHashInitialized) return 0;
    int invalidCount = 0;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(!g_objectCacheHash[i].occupied) continue;
    string objName = g_objectCacheHash[i].name;
        
        // Check if object still exists on chart
        if(ObjectFind(0, objName) < 0) {
            g_objectCacheHash[i].entry.exists = false;
    invalidCount++;
        }
    }
    if(invalidCount > 0) {
        _LOG_GATE_E Print("[E][SYNC] Cache validation found ", invalidCount, " invalid entries out of ", g_objectCacheSize);
    }
    return invalidCount;
}

//+------------------------------------------------------------------+

#endif
    // OBJECT_CACHE_MQH
