  #ifndef OBJECT_CACHE_MQH
#define OBJECT_CACHE_MQH

#property copyright "Biotak"
#property strict

struct SObjectCacheEntry {
    string name;           // Object name
    double lastPrice;      // Last known price (for lines/zones - Price 1)
    double lastPrice2;     // Last known price 2 (for zones)
    datetime lastTime1;    // Last known time 1 (for zones)
    datetime lastTime2;    // Last known time 2 (for zones)
    color lastColor;       // Last known color
    int lastStyle;         // Last known line style
    int lastWidth;         // Last known line width
    string lastText;       // Last known text (for labels)
    string lastTooltip;    // PERF (2026): last OBJPROP_TOOLTIP value for lines.
                           // Avoids a synchronous ObjectSetString chart call
                           // when the tooltip string is unchanged. With ~288
                           // line objects per redraw on M1 this saves 288
                           // chart-engine syscalls per full redraw.
    bool lastFilled;       // Last known fill state (for zones)
    bool exists;           // True if object exists on chart
    datetime lastUpdate;   // Last update timestamp
    long lastTimeframes;   // PERF (2026): last OBJPROP_TIMEFRAMES value.
                           // Cached locally to avoid the synchronous
                           // ObjectGetInteger(..., OBJPROP_TIMEFRAMES) call
                           // on every redraw (the MQL5 docs explicitly warn
                           // that synchronous chart API calls are time
                           // consuming when working with a large number of
                           // objects on a chart).
    // PERF (2026): cached inputs for the pip-distance label formatter so
    // CreatePipDistanceLabel can skip its StringFormat call when neither
    // pips nor levelInfo have changed (158 allocations/frame on MN1).
    double lastPips;
    string lastLevelInfo;
    int    category;       // PERF (2026): cached object category (Line/Zone/
                           // Label/Trigger/CustomPrice) populated at insert
                           // time. Removes 5-7 StringFind calls per object
                           // in the F/L keypress handlers.
};

// Hash-based cache configuration
#define CACHE_HASH_BUCKETS 2048  // Power of 2 for fast modulo
#define CACHE_MAX_PROBE 64       // Keep cache lookups bounded without false misses at normal load

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

// PERF: LRU eviction tracking via lastAccess scan
// (Removed broken O(1) fast path that tracked oldest INSERT instead of oldest ACCESS.)

// PERF: Cached TimeCurrent() - refreshed once per redraw frame
static datetime g_cacheFrameTime = 0;

// PERF (2026): per-frame ms stamp for cheap frame-equality checks.
// Refreshed by CacheRefreshFrameMs() at the top of redraw / calculate paths.
// Used by GetCachedITimeForFrame to memoize timeseries lookups for the
// current frame.
static ulong g_cacheFrameMs = 0;
void CacheRefreshFrameMs() { g_cacheFrameMs = (ulong)GetTickCount(); }
ulong CacheGetFrameMs() {
    if(g_cacheFrameMs == 0) g_cacheFrameMs = (ulong)GetTickCount();
    return g_cacheFrameMs;
}

// PERF (2026): one-time object categorization by name prefix/suffix.
// F/L key handlers previously ran 5-7 StringFind calls per cached object;
// with category pre-computed at insert time the handlers do a single int
// compare instead. Categories: 0=Unknown, 1=Line, 2=Zone, 3=Label,
// 4=Trigger/Midpoint, 5=CustomPrice.
//
// Order matters: trigger objects (4) and zone tokens (2) must be matched
// before generic line/label suffixes. _Above_/_Below_ are ambiguous (could
// be a zone above/below or a line above/below), so _Zone_ is checked first.
int ClassifyObjectCategoryByName(const string name) {
    int len = StringLen(name);
    if(len < 2) return 0;
    // TH3_Structure_* — handled separately by callers (skip in F/L).
    if(StringFind(name, "TH3_Structure_") == 0) return 0;
    // Trigger subdivisions (TriggerTH_Up_, TriggerTH_Down_).
    // FIX (T-hotkey, 2026): the actual trigger object names are
    //   "<prefix>TH_Level_TriggerTH_Up_<step>"
    //   "<prefix>TH_Level_TriggerTH_Down_<step>"
    // i.e. the "TriggerTH_" token sits in the MIDDLE of the name, never at
    // position 0. The previous `== 0` check therefore always failed and
    // every trigger line fell through to the generic `_Level_` branch
    // below, returning category 1 (Line) instead of 4 (Trigger). The T-key
    // handler filters by `category == 4` to isolate trigger objects, so the
    // misclassification silently broke the T toggle — pressing T updated
    // the global var but flipped zero objects. Use `>= 0` so the trigger
    // token matches anywhere in the name. "TriggerTH_" only appears in
    // trigger line names; no other category uses this substring, so the
    // broader match is safe.
    if(StringFind(name, "TriggerTH_") >= 0) return 4;
    // Custom price line.
    if(StringFind(name, "TH3v1_CustomPrice") >= 0) return 5;
    // Zone family (rectangles + zone tops/bottoms). Must precede Above/Below.
    if(StringFind(name, "_Zone_")        >= 0) return 2;
    if(StringFind(name, "_Zone_Top")    >= 0) return 2;
    if(StringFind(name, "_Zone_Bottom") >= 0) return 2;
    // Pip-distance label (kept visible in F/L handlers).
    if(StringFind(name, "_PipsLabel")   >= 0) return 3;
    // Generic label suffix (e.g. TH..._Label).
    if(StringFind(name, "_Label")       >= 0) return 3;
    // Midpoint line.
    if(StringFind(name, "_Midpoint_")   >= 0) return 4;
    // Generic line tokens.
    if(StringFind(name, "_Level_")      >= 0) return 1;
    if(StringFind(name, "_Above_")      >= 0) return 1;
    if(StringFind(name, "_Below_")      >= 0) return 1;
    int c0 = StringGetCharacter(name, 0);
    int c1 = StringGetCharacter(name, 1);
    if(c0 == 'T' && c1 == 'H') return 1;
    return 0;
}

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
    _LOG_GATE_I Print("[I][SYNC] Object Cache Hash Initialized (", CACHE_HASH_BUCKETS, " buckets)");
}

int CacheFindIndex(const string name) {
    if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
    int slot = HashObjectName(name);
    
    for(int probe = 0; probe < CACHE_MAX_PROBE; probe++) {
        int idx = (slot + probe) % CACHE_HASH_BUCKETS;
        if(!g_objectCacheHash[idx].occupied && !g_objectCacheHash[idx].deleted) {
            return -1;  // Empty slot - object not in cache
        }
        
        // Skip tombstone slots
        if(g_objectCacheHash[idx].deleted && !g_objectCacheHash[idx].occupied)
            continue;
        if(g_objectCacheHash[idx].name == name) {
            g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
            return idx;
        }
    }
    
    return -1;
}

int CacheFindInsertIndex(const string name) {
    if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
    int slot = HashObjectName(name);
    int firstDeleted = -1;

    for(int probe = 0; probe < CACHE_MAX_PROBE; probe++) {
        int idx = (slot + probe) % CACHE_HASH_BUCKETS;
        if(g_objectCacheHash[idx].deleted && !g_objectCacheHash[idx].occupied) {
            if(firstDeleted < 0) firstDeleted = idx;
            continue;
        }
        // Avoid duplicate cache entries if the name is already present.
        if(g_objectCacheHash[idx].occupied && g_objectCacheHash[idx].name == name) {
            return idx;
        }
        if(!g_objectCacheHash[idx].occupied) {
            return (firstDeleted >= 0) ? firstDeleted : idx;
        }
    }

    return firstDeleted;
}

void EvictLRUEntry() {
    if(g_objectCacheSize == 0) return;

    // PERF: Use sampling instead of full 2048-bucket scan.
    // Scanning all buckets on every eviction (rare: only when cache is full at 1600 entries)
    // adds unnecessary latency. Sample every 8th bucket (256 probes) to find a good
    // eviction candidate. This is O(1/8) vs O(n) and still finds a sufficiently old entry.
    int lruIdx = -1;
    datetime oldestAccess = CacheGetFrameTime() + 86400;
    const int sampleStep = 8;

    for(int i = 0; i < CACHE_HASH_BUCKETS; i += sampleStep) {
        if(g_objectCacheHash[i].occupied && g_objectCacheHash[i].lastAccess < oldestAccess) {
            oldestAccess = g_objectCacheHash[i].lastAccess;
            lruIdx = i;
        }
    }
    // Fallback: if sampling didn't find anything, scan a few more random-ish buckets
    if(lruIdx < 0) {
        for(int i = 1; i < CACHE_HASH_BUCKETS; i += 16) {
            if(g_objectCacheHash[i].occupied && g_objectCacheHash[i].lastAccess < oldestAccess) {
                oldestAccess = g_objectCacheHash[i].lastAccess;
                lruIdx = i;
            }
        }
    }
    // Last resort: scan all (should rarely happen)
    if(lruIdx < 0) {
        for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
            if(g_objectCacheHash[i].occupied && g_objectCacheHash[i].lastAccess < oldestAccess) {
                oldestAccess = g_objectCacheHash[i].lastAccess;
                lruIdx = i;
            }
        }
    }
    if(lruIdx >= 0) {
        _LOG_GATE_D Print("[D][SYNC] [DEL] Evicting LRU cache entry: '", g_objectCacheHash[lruIdx].name, "'");
        g_objectCacheHash[lruIdx].name = "";
        g_objectCacheHash[lruIdx].occupied = false;
        g_objectCacheHash[lruIdx].deleted = true;
        g_objectCacheHash[lruIdx].lastAccess = 0;
        g_objectCacheSize--;
    }
}

void CacheAddObject(const string name, const double price,
                    const color clr, const int style, const int width) {
    if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();

    int idx = CacheFindIndex(name);
    if(idx >= 0) {
        g_objectCacheHash[idx].entry.lastPrice = price;
        g_objectCacheHash[idx].entry.lastColor = clr;
        g_objectCacheHash[idx].entry.lastStyle = style;
        g_objectCacheHash[idx].entry.lastWidth = width;
        g_objectCacheHash[idx].entry.exists = true;
        g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
        // PERF: keep the previously-cached timeframes (do not reset)
        return;
    }

    if(g_objectCacheSize >= MAX_CACHE_SIZE) {
        EvictLRUEntry();
    }

    int insertIdx = CacheFindInsertIndex(name);
    if(insertIdx < 0) {
        EvictLRUEntry();
        insertIdx = CacheFindInsertIndex(name);
    }
    if(insertIdx < 0) {
        CacheClear();
        insertIdx = CacheFindInsertIndex(name);
    }
    if(insertIdx < 0) return;

    g_objectCacheHash[insertIdx].name = name;
    g_objectCacheHash[insertIdx].entry.name = name;
    // PERF (2026): classify at insert so F/L key handlers can skip 5-7
    // StringFind calls per cached object.
    g_objectCacheHash[insertIdx].entry.category = ClassifyObjectCategoryByName(name);
    g_objectCacheHash[insertIdx].entry.lastPrice = price;
    g_objectCacheHash[insertIdx].entry.lastColor = clr;
    g_objectCacheHash[insertIdx].entry.lastStyle = style;
    g_objectCacheHash[insertIdx].entry.lastWidth = width;
    // PERF (2026): seed an empty tooltip so CreateTHLineObject's diff can
    // always compare against the cached value without a null-handling branch.
    g_objectCacheHash[insertIdx].entry.lastTooltip = "";
    // PERF (2026): new chart objects default to OBJ_ALL_PERIODS (visible on
    // every timeframe). Seed the cache with that default so the very first
    // SetObjectTimeframesIfChanged / ApplyVisibilityStateIfUnchangedSkip call
    // can take the fast (cache-only) path and skip the synchronous
    // ObjectGetInteger(..., OBJPROP_TIMEFRAMES) chart API call.
    g_objectCacheHash[insertIdx].entry.lastTimeframes = OBJ_ALL_PERIODS;
    g_objectCacheHash[insertIdx].entry.exists = true;
    g_objectCacheHash[insertIdx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[insertIdx].occupied = true;
    g_objectCacheHash[insertIdx].deleted = false;
    g_objectCacheHash[insertIdx].lastAccess = CacheGetFrameTime();
    g_objectCacheSize++;
}

void CacheRemoveObject(const string name) {
    int idx = CacheFindIndex(name);
    if(idx < 0) {
        return;
    }
    
    g_objectCacheHash[idx].name = "";
    g_objectCacheHash[idx].occupied = false;
    g_objectCacheHash[idx].deleted = true;
    g_objectCacheHash[idx].lastAccess = 0;
    g_objectCacheSize--;
    _LOG_GATE_D Print("[D][SYNC] [DEL] Removed object from cache (size now: ", g_objectCacheSize, ")");
}

bool DeleteIndicatorObjectManaged(const string name, const bool verifyChartObject = false)
{
    if(StringLen(name) == 0) return false;

    int cacheIdx = CacheFindIndex(name);
    bool inCache = (cacheIdx >= 0 && g_objectCacheHash[cacheIdx].entry.exists);
    bool existsOnChart = false;

    if(inCache || verifyChartObject) {
        existsOnChart = (ObjectFind(0, name) >= 0);
    }

    if(inCache || existsOnChart) {
        CacheRemoveObject(name);
    }

    if(!existsOnChart) return inCache;

    g_suppressDeleteEvents = true;
    g_suppressDeleteEventsUntilMs = GetTickCount() + 250;
    bool deleted = ObjectDelete(0, name);
    g_suppressDeleteEvents = false;
    return deleted;
}

bool DeleteManagedZoneObjects(const string zoneName, const bool verifyChartObjects = false)
{
    if(StringLen(zoneName) == 0) return false;

    bool foundAny = false;
    if(DeleteIndicatorObjectManaged(zoneName, verifyChartObjects))
        foundAny = true;
    if(DeleteIndicatorObjectManaged(zoneName + "_Top", verifyChartObjects))
        foundAny = true;
    if(DeleteIndicatorObjectManaged(zoneName + "_Bottom", verifyChartObjects))
        foundAny = true;
    return foundAny;
}

void CacheMarkObjectMissing(const string name) {
    int idx = CacheFindIndex(name);
    if(idx < 0) return;
    g_objectCacheHash[idx].entry.exists = false;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
}

void CacheClear() {
    if(!g_objectCacheHashInitialized) return;
    if(g_objectCacheSize == 0) return;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        g_objectCacheHash[i].name = "";
        g_objectCacheHash[i].occupied = false;
        g_objectCacheHash[i].deleted = false;
        g_objectCacheHash[i].lastAccess = 0;
    }
    
    g_objectCacheSize = 0;
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

// PERF (2026): overload returning the cached inputs (pips, levelInfo) so
// CreatePipDistanceLabel can short-circuit its StringFormat call when those
// haven't changed.
bool CacheGetLabel(const string name, string &text, color &clr,
                   double &pips, string &levelInfo) {
    int idx = CacheFindIndex(name);
    if(idx < 0) {
        pips = 0.0;
        levelInfo = "";
        return false;
    }
    text = g_objectCacheHash[idx].entry.lastText;
    clr = g_objectCacheHash[idx].entry.lastColor;
    pips = g_objectCacheHash[idx].entry.lastPips;
    levelInfo = g_objectCacheHash[idx].entry.lastLevelInfo;
    return g_objectCacheHash[idx].entry.exists;
}

// 2-arg overload for callers that don't need the input snapshot.
bool CacheGetLabel(const string name, string &text, color &clr) {
    double dummyPips;
    string dummyInfo;
    return CacheGetLabel(name, text, clr, dummyPips, dummyInfo);
}

void CacheUpdateObject(const string name, const double price,
                       const color clr, const int style, const int width) {
    int idx = CacheFindIndex(name);
    if(idx < 0) {
        CacheAddObject(name, price, clr, style, width);
        return;
    }

    g_objectCacheHash[idx].entry.lastPrice = price;
    g_objectCacheHash[idx].entry.lastColor = clr;
    g_objectCacheHash[idx].entry.lastStyle = style;
    g_objectCacheHash[idx].entry.lastWidth = width;
    g_objectCacheHash[idx].entry.exists = true;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
    // PERF: preserve lastTimeframes — visibility is owned by
    // SetObjectTimeframesIfChanged / ApplyVisibilityStateIfUnchangedSkip.
}

void CacheUpdateTooltip(const string name, const string tooltip) {
    int idx = CacheFindIndex(name);
    if(idx < 0) return;
    g_objectCacheHash[idx].entry.lastTooltip  = tooltip;
    g_objectCacheHash[idx].entry.lastUpdate   = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess        = CacheGetFrameTime();
}

string CacheGetTooltip(const string name) {
    int idx = CacheFindIndex(name);
    if(idx < 0) return "";
    return g_objectCacheHash[idx].entry.lastTooltip;
}

void CacheUpdateZone(const string name, const double price1, const double price2,
                      const datetime time1, const datetime time2,
                      const color clr, const bool filled) {
    int idx = CacheFindIndex(name);
    if(idx < 0) {
        if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
        if(g_objectCacheSize >= MAX_CACHE_SIZE) EvictLRUEntry();

        int insertIdx = CacheFindInsertIndex(name);
        if(insertIdx < 0) {
            EvictLRUEntry();
            insertIdx = CacheFindInsertIndex(name);
        }
        if(insertIdx < 0) {
            CacheClear();
            insertIdx = CacheFindInsertIndex(name);
        }
        if(insertIdx < 0) return;

        g_objectCacheHash[insertIdx].name = name;
        g_objectCacheHash[insertIdx].entry.name = name;
        // PERF (2026): classify at insert so F/L key handlers can skip
        // StringFind calls per cached object.
        g_objectCacheHash[insertIdx].entry.category = ClassifyObjectCategoryByName(name);
        g_objectCacheHash[insertIdx].entry.lastPrice = price1;
        g_objectCacheHash[insertIdx].entry.lastPrice2 = price2;
        g_objectCacheHash[insertIdx].entry.lastTime1 = time1;
        g_objectCacheHash[insertIdx].entry.lastTime2 = time2;
        g_objectCacheHash[insertIdx].entry.lastColor = clr;
        g_objectCacheHash[insertIdx].entry.lastFilled = filled;
        // PERF (2026): new chart objects default to OBJ_ALL_PERIODS.
        g_objectCacheHash[insertIdx].entry.lastTimeframes = OBJ_ALL_PERIODS;
        g_objectCacheHash[insertIdx].entry.exists = true;
        g_objectCacheHash[insertIdx].entry.lastUpdate = CacheGetFrameTime();
        g_objectCacheHash[insertIdx].occupied = true;
        g_objectCacheHash[insertIdx].deleted = false;
        g_objectCacheHash[insertIdx].lastAccess = CacheGetFrameTime();
        g_objectCacheSize++;
        return;
    }

    g_objectCacheHash[idx].entry.lastPrice = price1;
    g_objectCacheHash[idx].entry.lastPrice2 = price2;
    g_objectCacheHash[idx].entry.lastTime1 = time1;
    g_objectCacheHash[idx].entry.lastTime2 = time2;
    g_objectCacheHash[idx].entry.lastColor = clr;
    g_objectCacheHash[idx].entry.lastFilled = filled;
    g_objectCacheHash[idx].entry.exists = true;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
    // PERF: preserve lastTimeframes
}

void CacheUpdateLabel(const string name, const string text, const color clr,
                       double pips = 0.0, string levelInfo = "") {
    int idx = CacheFindIndex(name);
    if(idx < 0) {
        if(!g_objectCacheHashInitialized) InitializeObjectCacheHash();
        if(g_objectCacheSize >= MAX_CACHE_SIZE) EvictLRUEntry();

        int insertIdx = CacheFindInsertIndex(name);
        if(insertIdx < 0) {
            EvictLRUEntry();
            insertIdx = CacheFindInsertIndex(name);
        }
        if(insertIdx < 0) {
            CacheClear();
            insertIdx = CacheFindInsertIndex(name);
        }
        if(insertIdx < 0) return;

        g_objectCacheHash[insertIdx].name = name;
        g_objectCacheHash[insertIdx].entry.name = name;
        // PERF (2026): classify at insert so F/L key handlers can skip
        // StringFind calls per cached object.
        g_objectCacheHash[insertIdx].entry.category = ClassifyObjectCategoryByName(name);
        g_objectCacheHash[insertIdx].entry.lastText = text;
        g_objectCacheHash[insertIdx].entry.lastColor = clr;
        // PERF (2026): snapshot input fields so CreatePipDistanceLabel can
        // skip StringFormat when neither pips nor levelInfo has changed.
        g_objectCacheHash[insertIdx].entry.lastPips = pips;
        g_objectCacheHash[insertIdx].entry.lastLevelInfo = levelInfo;
        // PERF (2026): new chart objects default to OBJ_ALL_PERIODS.
        g_objectCacheHash[insertIdx].entry.lastTimeframes = OBJ_ALL_PERIODS;
        g_objectCacheHash[insertIdx].entry.exists = true;
        g_objectCacheHash[insertIdx].entry.lastUpdate = CacheGetFrameTime();
        g_objectCacheHash[insertIdx].occupied = true;
        g_objectCacheHash[insertIdx].deleted = false;
        g_objectCacheHash[insertIdx].lastAccess = CacheGetFrameTime();
        g_objectCacheSize++;
        return;
    }

    g_objectCacheHash[idx].entry.lastText = text;
    g_objectCacheHash[idx].entry.lastColor = clr;
    // PERF (2026): update the input snapshot too.
    g_objectCacheHash[idx].entry.lastPips = pips;
    g_objectCacheHash[idx].entry.lastLevelInfo = levelInfo;
    g_objectCacheHash[idx].entry.exists = true;
    g_objectCacheHash[idx].entry.lastUpdate = CacheGetFrameTime();
    g_objectCacheHash[idx].lastAccess = CacheGetFrameTime();
    // PERF: preserve lastTimeframes
}

int CacheGetSize() {
    return g_objectCacheSize;
}

void CacheRebuild() {
    CacheClear();

    // MT4: ObjectsTotal() with chart_id parameter
    int totalObjects = ObjectsTotal(0, -1, -1);

    for(int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i);

        // Only cache TH-related objects
        if(StringLen(objName) >= 2 && StringGetCharacter(objName, 0) == 'T' && StringGetCharacter(objName, 1) == 'H') {
            double price = ObjectGetDouble(0, objName, OBJPROP_PRICE);
            color clr = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            int style = (int)ObjectGetInteger(0, objName, OBJPROP_STYLE);
            int width = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);

            CacheAddObject(objName, price, clr, style, width);
            // PERF (2026): also cache the current OBJPROP_TIMEFRAMES so the
            // hot path can stay on the local cache after a rebuild.
            int idx = CacheFindIndex(objName);
            if(idx >= 0) {
                g_objectCacheHash[idx].entry.lastTimeframes =
                    ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES);
                // PERF (2026): hydrate the tooltip so the first diff after a
                // rebuild takes the fast (cache-only) path.
                g_objectCacheHash[idx].entry.lastTooltip =
                    ObjectGetString(0, objName, OBJPROP_TOOLTIP);
            }
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
//+------------------------------------------------------------------+
//| PERF (2026): cache-backed SetObjectTimeframesIfChanged            |
//|                                                                  |
//| Old implementation made 2 SYNCHRONOUS chart API calls per object: |
//|   1) ObjectFind(0, name)                                         |
//|   2) ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES)                |
//|                                                                  |
//| Per the official MQL5 documentation                              |
//| (https://www.mql5.com/en/docs/objects/objectsetinteger and        |
//|  https://www.mql5.com/en/docs/objects/objectgetinteger):          |
//|   * ObjectSetInteger uses an ASYNCHRONOUS call (just queues       |
//|     the command, returns immediately).                            |
//|   * ObjectGetInteger uses a SYNCHRONOUS call: the function is     |
//|     added to the END of the chart's command queue and waits for   |
//|     the result, "and can therefore be time consuming. This       |
//|     feature should be taken into account when working with a     |
//|     large number of objects on a chart."                          |
//|                                                                  |
//| The cached `lastTimeframes` field on SObjectCacheEntry removes    |
//| both sync calls from the hot path. Object existence is trusted    |
//| from the cache (the cache is the source of truth maintained by   |
//| every other call site). We only fall back to the chart API when   |
//| the entry is not in the cache, in which case we pay the cost     |
//| once and then hydrate the cache for the next call.                |
//+------------------------------------------------------------------+
void SetObjectTimeframesIfChanged(const string name, const long timeframes)
{
    int idx = CacheFindIndex(name);

    // Cache hit: trust the cache, no chart API calls needed.
    if(idx >= 0 && g_objectCacheHash[idx].entry.exists) {
        if(g_objectCacheHash[idx].entry.lastTimeframes == timeframes)
            return;  // already on the right timeframes, skip
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
        g_objectCacheHash[idx].entry.lastTimeframes = timeframes;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
        return;
    }

    // Cache miss: pay the sync ObjectFind + ObjectGetInteger cost
    // ONCE so the next call takes the fast path. This branch is rare
    // (only on the very first sighting of an object, or after
    // CacheClear / InvalidateObjectCacheByPrefix removed it).
    if(ObjectFind(0, name) < 0) return;
    long current = ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES);
    if(current != timeframes)
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
    if(idx >= 0) {
        g_objectCacheHash[idx].entry.lastTimeframes = timeframes;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
    }
}

#endif // OBJECT_CACHE_MQH
