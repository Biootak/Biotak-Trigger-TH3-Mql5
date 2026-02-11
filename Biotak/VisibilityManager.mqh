#ifndef VISIBILITY_MANAGER_MQH
#define VISIBILITY_MANAGER_MQH

#include "GlobalVariables.mqh"
#include "ConstantsAndEnums.mqh"

static bool g_linesVisibleCached = true;
static uint g_linesVisibleCacheTime = 0;
static const int LINES_VISIBLE_CACHE_TTL_MS = 500;

static bool g_triggerEnabledCached = true;
static uint g_triggerEnabledCacheTime = 0;
static const int TRIGGER_ENABLED_CACHE_TTL_MS = 500;

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

void ApplyVisibilityState(const string name, const bool isLine)
{
    if(ObjectFind(0, name) < 0) return;
    bool shouldBeVisible = true;
    if(IsIndicatorHidden()) shouldBeVisible = false;
    else if(isLine && !GetCachedLinesVisible()) shouldBeVisible = false;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, shouldBeVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

bool ShouldObjectBeVisible(const bool isLine)
{
    if(IsIndicatorHidden()) return false;
    if(isLine && !GetCachedLinesVisible()) return false;
    return true;
}

#endif // VISIBILITY_MANAGER_MQH