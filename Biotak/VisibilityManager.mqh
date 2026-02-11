//+------------------------------------------------------------------+
//|                                            VisibilityManager.mqh |
//|                        Biotak Trigger TH3 - Visibility Manager   |
//|                                                                  |
//| Purpose: Manage object visibility without deletion               |
//| Feature: zone-level-flickering-fix                               |
//|                                                                  |
//| This module provides visibility control functions that use       |
//| OBJPROP_TIMEFRAMES instead of object deletion to hide/show       |
//| chart objects. This prevents flickering caused by repeated       |
//| creation and deletion cycles.                                    |
//|                                                                  |
//| Requirements: 4.1, 4.2, 4.3, 4.4, 10.1, 10.2                     |
//+------------------------------------------------------------------+

#ifndef VISIBILITY_MANAGER_MQH
#define VISIBILITY_MANAGER_MQH

// Include required dependencies
#include "GlobalVariables.mqh"
#include "ConstantsAndEnums.mqh"

//+------------------------------------------------------------------+
//| Visibility State Cache (Task 11 - Requirements 16.1-16.7)        |
//| Caches visibility states to avoid repeated GlobalVariable reads  |
//+------------------------------------------------------------------+

// Cache for lines visibility state
static bool g_linesVisibleCached = true;
static uint g_linesVisibleCacheTime = 0;
static const int LINES_VISIBLE_CACHE_TTL_MS = 500;  // 500ms TTL

// Cache for trigger enabled state
static bool g_triggerEnabledCached = true;
static uint g_triggerEnabledCacheTime = 0;
static const int TRIGGER_ENABLED_CACHE_TTL_MS = 500;  // 500ms TTL

//+------------------------------------------------------------------+
//| Get Cached Lines Visible State                                   |
//| Requirement 16.2: Use cached state instead of GlobalVariable     |
//| Requirement 16.5: Skip GlobalVariable reads when cache valid     |
//+------------------------------------------------------------------+
bool GetCachedLinesVisible() {
    uint now = GetTickCount();
    
    // Check if cache is still valid
    if((int)(now - g_linesVisibleCacheTime) > LINES_VISIBLE_CACHE_TTL_MS) {
        // Cache expired - refresh from global variable
        // Requirement 16.6: Refresh from GlobalVariable on invalidation
        g_linesVisibleCached = g_linesVisible;
        g_linesVisibleCacheTime = now;
    }
    
    // Requirement 16.7: Use cached value for multiple checks
    return g_linesVisibleCached;
}

//+------------------------------------------------------------------+
//| Update Lines Visible Cache                                       |
//| Requirement 16.4: Update cache immediately on state change       |
//+------------------------------------------------------------------+
void UpdateLinesVisibleCache(bool visible) {
    g_linesVisibleCached = visible;
    g_linesVisibleCacheTime = GetTickCount();
}

//+------------------------------------------------------------------+
//| Invalidate Lines Visible Cache                                   |
//| Forces cache refresh on next access                              |
//+------------------------------------------------------------------+
void InvalidateLinesVisibleCache() {
    g_linesVisibleCacheTime = 0;
}

//+------------------------------------------------------------------+
//| Get Cached Trigger Enabled State                                 |
//| Requirement 16.3: Use cached state instead of GlobalVariable     |
//| Requirement 16.5: Skip GlobalVariable reads when cache valid     |
//+------------------------------------------------------------------+
bool GetCachedTriggerEnabled() {
    uint now = GetTickCount();
    
    // Check if cache is still valid
    if((int)(now - g_triggerEnabledCacheTime) > TRIGGER_ENABLED_CACHE_TTL_MS) {
        // Cache expired - refresh from global variable
        // Requirement 16.6: Refresh from GlobalVariable on invalidation
        // Note: Trigger enabled state is stored in g_triggerLevelsEnabled
        g_triggerEnabledCached = g_triggerLevelsEnabled;
        g_triggerEnabledCacheTime = now;
    }
    
    // Requirement 16.7: Use cached value for multiple checks
    return g_triggerEnabledCached;
}

//+------------------------------------------------------------------+
//| Update Trigger Enabled Cache                                     |
//| Requirement 16.4: Update cache immediately on state change       |
//+------------------------------------------------------------------+
void UpdateTriggerEnabledCache(bool enabled) {
    g_triggerEnabledCached = enabled;
    g_triggerEnabledCacheTime = GetTickCount();
}

//+------------------------------------------------------------------+
//| Invalidate Trigger Enabled Cache                                 |
//| Forces cache refresh on next access                              |
//+------------------------------------------------------------------+
void InvalidateTriggerEnabledCache() {
    g_triggerEnabledCacheTime = 0;
}

//+------------------------------------------------------------------+
//| Invalidate All Visibility Caches                                 |
//| Call when major state changes occur                              |
//+------------------------------------------------------------------+
void InvalidateAllVisibilityCaches() {
    InvalidateLinesVisibleCache();
    InvalidateTriggerEnabledCache();
    // Note: IsIndicatorHidden cache is managed in GlobalVariables.mqh
}

//+------------------------------------------------------------------+
//| Set visibility for a single object using OBJPROP_TIMEFRAMES      |
//| Requirements: 4.1, 4.2                                           |
//|                                                                  |
//| Parameters:                                                      |
//|   name - Object name                                             |
//|   visible - true to show, false to hide                          |
//|                                                                  |
//| Implementation:                                                  |
//|   - Uses OBJPROP_TIMEFRAMES property                             |
//|   - OBJ_ALL_PERIODS (0xFFFFFFFF) to show on all timeframes      |
//|   - OBJ_NO_PERIODS (0) to hide on all timeframes                |
//|   - Object remains in memory when hidden                         |
//|   - All properties preserved during hide/show                    |
//+------------------------------------------------------------------+
void SetObjectVisibility(const string name, const bool visible)
{
    // Check if object exists
    if(ObjectFind(0, name) < 0) {
        return; // Object doesn't exist, nothing to do
    }
    
    // Set visibility using OBJPROP_TIMEFRAMES
    // OBJ_ALL_PERIODS = show on all timeframes
    // OBJ_NO_PERIODS = hide on all timeframes
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
}

//+------------------------------------------------------------------+
//| Set visibility for all TH objects (bulk operation)               |
//| Requirements: 4.3, 10.1                                          |
//|                                                                  |
//| Parameters:                                                      |
//|   visible - true to show all TH objects, false to hide all      |
//|                                                                  |
//| Implementation:                                                  |
//|   - Iterates through all chart objects                           |
//|   - Filters objects by prefix (inpObjectPrefix)                  |
//|   - Updates visibility for matching objects                      |
//|   - No object deletion or recreation                             |
//|   - Efficient bulk operation                                     |
//+------------------------------------------------------------------+
void SetAllTHObjectsVisibility(const bool visible)
{
    // Get object prefix from input parameters
    string prefix = inpObjectPrefix;
    int prefixLen = StringLen(prefix);
    
    // Get total number of objects on chart
    int total = ObjectsTotal(0, -1, -1);
    
    // Set visibility timeframes value
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    
    // Iterate through all objects
    for(int i = 0; i < total; i++) {
        string objName = ObjectName(0, i, -1, -1);
        
        // Check if object belongs to this indicator (matches prefix)
        if(StringLen(objName) >= prefixLen && 
           StringSubstr(objName, 0, prefixLen) == prefix) {
            // Update visibility
            ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, timeframes);
        }
    }
}

//+------------------------------------------------------------------+
//| Set visibility for all line objects (line-specific control)      |
//| Requirements: 4.4, 10.2                                          |
//|                                                                  |
//| Parameters:                                                      |
//|   visible - true to show lines, false to hide lines             |
//|                                                                  |
//| Implementation:                                                  |
//|   - Iterates through all chart objects                           |
//|   - Filters by prefix AND object type (OBJ_HLINE, OBJ_TREND)    |
//|   - Updates visibility only for line objects                     |
//|   - Zones and labels remain unaffected                           |
//|   - Respects L key toggle functionality                          |
//+------------------------------------------------------------------+
void SetAllLineObjectsVisibility(const bool visible)
{
    // Get object prefix from input parameters
    string prefix = inpObjectPrefix;
    int prefixLen = StringLen(prefix);
    
    // Get total number of objects on chart
    int total = ObjectsTotal(0, -1, -1);
    
    // Set visibility timeframes value
    long timeframes = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    
    // Iterate through all objects
    for(int i = 0; i < total; i++) {
        string objName = ObjectName(0, i, -1, -1);
        
        // Check if object belongs to this indicator (matches prefix)
        if(StringLen(objName) >= prefixLen && 
           StringSubstr(objName, 0, prefixLen) == prefix) {
            
            // Get object type
            ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, objName, OBJPROP_TYPE);
            
            // Only update visibility for line objects
            // OBJ_HLINE = horizontal line
            // OBJ_TREND = trend line (used for ray lines)
            if(objType == OBJ_HLINE || objType == OBJ_TREND) {
                ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, timeframes);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply current Hide and Lines visibility state to an object       |
//| Requirements: 10.1, 10.2, 16.1, 16.2, 16.7                       |
//|                                                                  |
//| Parameters:                                                      |
//|   name - Object name                                             |
//|   isLine - true if object is a line, false otherwise            |
//|                                                                  |
//| Implementation:                                                  |
//|   - Checks global Hide state (g_isHidden via IsIndicatorHidden) |
//|   - Checks global Lines visibility state (cached)                |
//|   - Applies appropriate visibility based on object type          |
//|   - Called immediately after object creation                     |
//|   - Ensures consistent state application                         |
//|                                                                  |
//| Logic:                                                           |
//|   - If indicator is hidden: hide all objects                     |
//|   - Else if object is line AND lines are hidden: hide line      |
//|   - Else: show object                                            |
//+------------------------------------------------------------------+
void ApplyVisibilityState(const string name, const bool isLine)
{
    // Check if object exists
    if(ObjectFind(0, name) < 0) {
        return; // Object doesn't exist, nothing to do
    }
    
    // Determine visibility based on current state
    bool shouldBeVisible = true;
    
    // Check Hide state (F key) - affects all objects
    // Requirement 16.1: Use cached hidden state
    if(IsIndicatorHidden()) {
        shouldBeVisible = false;
    }
    // Check Lines visibility (L key) - affects only line objects
    // Requirement 16.2: Use cached lines visible state
    // Requirement 16.7: Multiple visibility checks use cached values
    else if(isLine && !GetCachedLinesVisible()) {
        shouldBeVisible = false;
    }
    
    // Apply visibility
    long timeframes = shouldBeVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
}

//+------------------------------------------------------------------+
//| Check if an object should be visible based on current state      |
//| Requirements: 10.1, 10.2, 16.1, 16.2, 16.7                       |
//|                                                                  |
//| Parameters:                                                      |
//|   isLine - true if checking for a line object, false otherwise  |
//|                                                                  |
//| Returns:                                                         |
//|   true if object should be visible, false if should be hidden   |
//|                                                                  |
//| Implementation:                                                  |
//|   - Checks global Hide state (cached via IsIndicatorHidden)     |
//|   - Checks global Lines visibility state (cached)                |
//|   - Returns visibility decision without modifying objects        |
//|   - Used for pre-creation visibility checks                      |
//|                                                                  |
//| Logic:                                                           |
//|   - If indicator is hidden: return false                         |
//|   - If object is line AND lines are hidden: return false        |
//|   - Otherwise: return true                                       |
//+------------------------------------------------------------------+
bool ShouldObjectBeVisible(const bool isLine)
{
    // Check Hide state (F key) - affects all objects
    // Requirement 16.1: Use cached hidden state
    if(IsIndicatorHidden()) {
        return false;
    }
    
    // Check Lines visibility (L key) - affects only line objects
    // Requirement 16.2: Use cached lines visible state
    // Requirement 16.7: Multiple visibility checks use cached values
    if(isLine && !GetCachedLinesVisible()) {
        return false;
    }
    
    // Object should be visible
    return true;
}

#endif // VISIBILITY_MANAGER_MQH
