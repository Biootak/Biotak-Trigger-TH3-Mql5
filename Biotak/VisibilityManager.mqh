  #ifndef VISIBILITY_MANAGER_MQH
#define VISIBILITY_MANAGER_MQH

#property strict

#include "GlobalVariables.mqh"
#include "ConstantsAndEnums.mqh"

static bool g_linesVisibleCached = true;
static uint g_linesVisibleCacheTime = 0;
static const int LINES_VISIBLE_CACHE_TTL_MS = 100;

bool GetCachedLinesVisible()
{
    uint now = GetTickCount();
    if((int)(now - g_linesVisibleCacheTime) > LINES_VISIBLE_CACHE_TTL_MS) {
        g_linesVisibleCached = g_linesVisible;
        g_linesVisibleCacheTime = now;
    }
    return g_linesVisibleCached;
}

void UpdateLinesVisibleCache(bool visible)
{
    g_linesVisibleCached = visible;
    g_linesVisibleCacheTime = GetTickCount();
}

void InvalidateLinesVisibleCache() { g_linesVisibleCacheTime = 0; }

void InvalidateAllVisibilityCaches()
{
    InvalidateLinesVisibleCache();
}

void SetObjectVisibility(const string name, const bool visible)
{
    if(ObjectFind(0, name) < 0) return;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

void SetAllTHObjectsVisibility(const bool visible)
{
    static bool s_lastAllTHVisible = true;
    static bool s_allTHInit = false;
    if(s_allTHInit && s_lastAllTHVisible == visible) return;
    s_allTHInit = true;
    s_lastAllTHVisible = visible;

    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(g_objectCacheHash[i].occupied) {
            ObjectSetInteger(0, g_objectCacheHash[i].name, OBJPROP_TIMEFRAMES, timeframes);
        }
    }
}

void SetAllLineObjectsVisibility(const bool visible)
{
    static bool s_lastAllLineVisible = true;
    static bool s_allLineInit = false;
    if(s_allLineInit && s_lastAllLineVisible == visible) return;
    s_allLineInit = true;
    s_lastAllLineVisible = visible;

    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(g_objectCacheHash[i].occupied) {
            int objType = (int)ObjectGetInteger(0, g_objectCacheHash[i].name, OBJPROP_TYPE);
            if(objType == OBJ_HLINE || objType == OBJ_TREND) {
                ObjectSetInteger(0, g_objectCacheHash[i].name, OBJPROP_TIMEFRAMES, timeframes);
            }
        }
    }
}

// Per-frame visibility state tracking
static bool g_frameVisibilityLines = true;
static bool g_frameVisibilityNonLines = true;
static bool g_prevFrameVisibilityLines = true;
static bool g_prevFrameVisibilityNonLines = true;
static bool g_visibilityChangedThisFrame = true;
static int g_visibilityFrameCounter = 0;

void CacheRefreshVisibilityState()
{
    g_visibilityFrameCounter++;
    bool hidden = IsIndicatorHidden();
    g_frameVisibilityNonLines = !hidden;
    g_frameVisibilityLines = !hidden && GetCachedLinesVisible();
    
    g_visibilityChangedThisFrame = (g_frameVisibilityLines != g_prevFrameVisibilityLines) ||
                                    (g_frameVisibilityNonLines != g_prevFrameVisibilityNonLines);
    g_prevFrameVisibilityLines = g_frameVisibilityLines;
    g_prevFrameVisibilityNonLines = g_frameVisibilityNonLines;
}

void ApplyVisibilityState(const string name, const bool isLine)
{
    long tf = (isLine ? g_frameVisibilityLines : g_frameVisibilityNonLines) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf);
    // PERF (2026): keep the cache in sync so subsequent callers can take
    // the cache-only fast path in ApplyVisibilityStateIfUnchangedSkip /
    // SetObjectTimeframesIfChanged.
    int idx = CacheFindIndex(name);
    if(idx >= 0) {
        g_objectCacheHash[idx].entry.lastTimeframes = tf;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
    }
}

//+------------------------------------------------------------------+
//| PERF (2026): cache-backed ApplyVisibilityStateIfUnchangedSkip    |
//|                                                                  |
//| Old implementation called the SYNCHRONOUS chart API              |
//| ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES) for every line/    |
//| label on every redraw just to decide whether to skip the async  |
//| ObjectSetInteger write. Per the MQL5 docs that getter is "time   |
//| consuming" with many objects. With 200+ lines/labels on M1 this  |
//| is the dominant sync cost on timeframe switch and tick updates.  |
//|                                                                  |
//| We replace the chart read with a cache lookup. The cache is the  |
//| source of truth — every place that mutates OBJPROP_TIMEFRAMES    |
//| (ApplyVisibilityState, SetObjectTimeframesIfChanged,             |
//|  SetPipelineObjectTimeframesIfExists, CreateZone, CreateOrUpdate |
//|  HLine) keeps the cached value in sync.                          |
//+------------------------------------------------------------------+
void ApplyVisibilityStateIfUnchangedSkip(const string name, const bool isLine)
{
    long tf = (isLine ? g_frameVisibilityLines : g_frameVisibilityNonLines) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;

    // Visibility state changed this frame: always push to chart.
    if(g_visibilityChangedThisFrame) {
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf);
        int idx = CacheFindIndex(name);
        if(idx >= 0) {
            g_objectCacheHash[idx].entry.lastTimeframes = tf;
            g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
            g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
        }
        return;
    }

    // Steady-state frame: trust the cache.
    int idx = CacheFindIndex(name);
    if(idx >= 0 && g_objectCacheHash[idx].entry.exists &&
       g_objectCacheHash[idx].entry.lastTimeframes == tf) {
        return;  // already on the right timeframes, skip chart API
    }

    // Cache miss / object not tracked: keep the old fallback (every 10th
    // frame we still pay the ObjectGetInteger cost to re-hydrate) so
    // a freshly added but not-yet-cached object still gets its timeframe
    // updated at least once per 10 frames.
    if((g_visibilityFrameCounter % 10) == 0) {
        long currentTf = ObjectGetInteger(0, name, OBJPROP_TIMEFRAMES);
        if(currentTf == tf) {
            if(idx >= 0) {
                g_objectCacheHash[idx].entry.lastTimeframes = tf;
                g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
                g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
            }
            return;
        }
    }
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf);
    if(idx >= 0) {
        g_objectCacheHash[idx].entry.lastTimeframes = tf;
        g_objectCacheHash[idx].entry.lastUpdate     = CacheGetFrameTime();
        g_objectCacheHash[idx].lastAccess          = CacheGetFrameTime();
    }
}

#endif // VISIBILITY_MANAGER_MQH
