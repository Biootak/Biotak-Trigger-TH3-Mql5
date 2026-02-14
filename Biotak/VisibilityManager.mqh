#ifndef VISIBILITY_MANAGER_MQH
#define VISIBILITY_MANAGER_MQH

#include "GlobalVariables.mqh"
#include "ConstantsAndEnums.mqh"

static bool g_linesVisibleCached = true;
static uint g_linesVisibleCacheTime = 0;
static const int LINES_VISIBLE_CACHE_TTL_MS = 100;

static bool g_triggerEnabledCached = true;
static uint g_triggerEnabledCacheTime = 0;
static const int TRIGGER_ENABLED_CACHE_TTL_MS = 100;

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

bool GetCachedTriggerEnabled()
{
    uint now = GetTickCount();
    if((int)(now - g_triggerEnabledCacheTime) > TRIGGER_ENABLED_CACHE_TTL_MS) {
        g_triggerEnabledCached = g_triggerLevelsEnabled;
        g_triggerEnabledCacheTime = now;
    }
    return g_triggerEnabledCached;
}

void UpdateTriggerEnabledCache(bool enabled)
{
    g_triggerEnabledCached = enabled;
    g_triggerEnabledCacheTime = GetTickCount();
}

void InvalidateTriggerEnabledCache() { g_triggerEnabledCacheTime = 0; }

void InvalidateAllVisibilityCaches()
{
    InvalidateLinesVisibleCache();
    InvalidateTriggerEnabledCache();
}

void SetObjectVisibility(const string name, const bool visible)
{
    if(ObjectFind(0, name) < 0) return;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

void SetAllTHObjectsVisibility(const bool visible)
{
    string prefix = inpObjectPrefix;
    int prefixLen = StringLen(prefix);
    int total = ObjectsTotal(0, -1, -1);
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < total; i++) {
        string objName = ObjectName(0, i, -1, -1);
        if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == prefix) {
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, timeframes);
        }
    }
}

void SetAllLineObjectsVisibility(const bool visible)
{
    string prefix = inpObjectPrefix;
    int prefixLen = StringLen(prefix);
    int total = ObjectsTotal(0, -1, -1);
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    for(int i = 0; i < total; i++) {
        string objName = ObjectName(0, i, -1, -1);
        if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == prefix) {
            ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, objName, OBJPROP_TYPE);
            if(objType == OBJ_HLINE || objType == OBJ_TREND) {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, timeframes);
            }
        }
    }
}

// PERF: Track per-frame visibility state to skip redundant ObjectSetInteger calls
// Visibility only changes when user toggles lines/indicator — extremely rare.
static bool g_frameVisibilityLines = true;
static bool g_frameVisibilityNonLines = true;
static bool g_prevFrameVisibilityLines = true;
static bool g_prevFrameVisibilityNonLines = true;
static bool g_visibilityChangedThisFrame = true; // true on first frame to force initial set
static int g_visibilityFrameCounter = 0;         // Counter for periodic visibility re-sync

// Call once at start of RedrawAllObjects to compute frame visibility
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

// PERF: Caller always just created or verified the object exists.
// Skip the expensive ObjectFind check — it was wasting ~864 calls per redraw.
void ApplyVisibilityState(const string name, const bool isLine)
{
    long tf = (isLine ? g_frameVisibilityLines : g_frameVisibilityNonLines) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf);
}

// PERF: For existing objects, only update visibility if state changed this frame
// Saves ~800 ObjectSetInteger calls per redraw when visibility is stable
// FIX: Periodic re-sync every 10 frames to self-heal corrupted visibility states
void ApplyVisibilityStateIfUnchangedSkip(const string name, const bool isLine)
{
    if(!g_visibilityChangedThisFrame && (g_visibilityFrameCounter % 10) != 0) return;
    long tf = (isLine ? g_frameVisibilityLines : g_frameVisibilityNonLines) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tf);
}

#endif // VISIBILITY_MANAGER_MQH