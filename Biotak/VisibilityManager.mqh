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
    SetManagedObjectTimeframes(name, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
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
        if(g_objectCacheHash[i].occupied)
            SetManagedObjectTimeframes(g_objectCacheHash[i].name, timeframes);
    }
}

// Per-frame visibility state tracking
static bool g_frameVisibilityLines = true;
static bool g_frameVisibilityNonLines = true;
static bool g_prevFrameVisibilityLines = true;
static bool g_prevFrameVisibilityNonLines = true;
static bool g_visibilityChangedThisFrame = true;
static int g_visibilityFrameCounter = 0;

bool IsLineVisibilityExcludedObject(const string name)
{
    // Empty-box borders belong to the zone itself, not to the L-key line set.
    if(StringFind(name, "_B_Top") >= 0)    return true;
    if(StringFind(name, "_B_Bottom") >= 0) return true;
    if(StringFind(name, "_B_Left") >= 0)   return true;
    if(StringFind(name, "_B_Right") >= 0)  return true;
    return false;
}

void SetAllLineObjectsVisibility(const bool visible)
{
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    string prefix = inpObjectPrefix;
    int prefixLen = StringLen(prefix);

    // Scan the chart itself so objects created by either the legacy renderer
    // or the zone-first pipeline are handled, even if the cache missed them.
    int total = ObjectsTotal(0, -1, -1);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(prefixLen == 0 || StringLen(name) < prefixLen ||
           StringSubstr(name, 0, prefixLen) != prefix)
            continue;
        if(IsLineVisibilityExcludedObject(name)) continue;

        int objType = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
        if(objType == OBJ_HLINE || objType == OBJ_TREND)
            SetManagedObjectTimeframes(name, timeframes);
    }

    // Second pass closes the gap for objects that are temporarily absent from
    // the terminal enumeration during a redraw but are already cache-managed.
    for(int i = 0; i < CACHE_HASH_BUCKETS; i++)
    {
        if(!g_objectCacheHash[i].occupied) continue;
        string name = g_objectCacheHash[i].name;
        if(prefixLen == 0 || StringLen(name) < prefixLen ||
           StringSubstr(name, 0, prefixLen) != prefix)
            continue;
        if(IsLineVisibilityExcludedObject(name)) continue;

        int objType = (int)ObjectGetInteger(0, name, OBJPROP_TYPE);
        if(objType == OBJ_HLINE || objType == OBJ_TREND)
            SetManagedObjectTimeframes(name, timeframes);
    }

    // Keep both visibility caches in sync before the next redraw frame.
    UpdateLinesVisibleCache(visible);
    g_frameVisibilityLines = visible && !IsIndicatorHidden();
    g_visibilityChangedThisFrame = true;
}

//+------------------------------------------------------------------+
//| Hide retained objects belonging to inactive step-mode families   |
//|                                                                  |
//| Mode changes normally cleared every family and recreated the     |
//| selected one. Keeping the families cached allows E-key switches  |
//| to update existing objects in place; only the inactive families   |
//| need a visibility change here.                                  |
//+------------------------------------------------------------------+
string GetStepModeFamilySuffix(const ENUM_STEP_CALCULATION_MODE mode)
{
    switch(mode) {
        case SS_LS_STEP: return "SSLS_";
        case COMBO_STEP: return "Combo_";
        case FACTOR_STEP: return "Factor_"; // Covers Factor_Harmonic_ too.
        case TH_STEP:
        default:          return "TH_Level_";
    }
}

void HideInactiveStepModeObjects(const string objectPrefix,
                                 const ENUM_STEP_CALCULATION_MODE activeMode,
                                 const bool forceApply = false)
{
    if(StringLen(objectPrefix) == 0) return;

    static const string modeFamilies[] = {"SSLS_", "Combo_", "Factor_", "TH_Level_"};
    string activeFamily = objectPrefix + GetStepModeFamilySuffix(activeMode);
    int prefixLen = StringLen(objectPrefix);

    for(int i = 0; i < CACHE_HASH_BUCKETS; i++) {
        if(!g_objectCacheHash[i].occupied || !g_objectCacheHash[i].entry.exists) continue;

        string name = g_objectCacheHash[i].name;
        if(StringLen(name) < prefixLen || StringSubstr(name, 0, prefixLen) != objectPrefix)
            continue;

        bool isInactiveModeObject = false;
        for(int family = 0; family < ArraySize(modeFamilies); family++) {
            string familyPrefix = objectPrefix + modeFamilies[family];
            if(StringFind(name, familyPrefix, 0) == 0) {
                isInactiveModeObject = (familyPrefix != activeFamily);
                break;
            }
        }
        if(!isInactiveModeObject) continue;

        // F/L handlers can write OBJPROP_TIMEFRAMES directly while walking
        // chart objects, so forceApply refreshes the cache-backed state after
        // those paths. The normal E-key path skips already-hidden objects.
        if(forceApply || !g_objectCacheHash[i].entry.lastTimeframesKnown ||
           g_objectCacheHash[i].entry.lastTimeframes != OBJ_NO_PERIODS) {
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
            g_objectCacheHash[i].entry.lastTimeframes = OBJ_NO_PERIODS;
            g_objectCacheHash[i].entry.lastTimeframesKnown = true;
        }
    }
}

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
    SetManagedObjectTimeframes(name, tf);
}

void ApplyVisibilityStateIfUnchangedSkip(const string name, const bool isLine)
{
    if(!g_visibilityChangedThisFrame && (g_visibilityFrameCounter % 10) != 0) return;
    long tf = (isLine ? g_frameVisibilityLines : g_frameVisibilityNonLines) ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    SetManagedObjectTimeframes(name, tf);
}

#endif // VISIBILITY_MANAGER_MQH
