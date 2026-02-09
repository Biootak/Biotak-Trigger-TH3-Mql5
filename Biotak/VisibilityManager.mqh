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
//| Requirements: 10.1, 10.2                                         |
//|                                                                  |
//| Parameters:                                                      |
//|   name - Object name                                             |
//|   isLine - true if object is a line, false otherwise            |
//|                                                                  |
//| Implementation:                                                  |
//|   - Checks global Hide state (g_isHidden via IsIndicatorHidden) |
//|   - Checks global Lines visibility state (g_linesVisible)        |
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
    if(IsIndicatorHidden()) {
        shouldBeVisible = false;
    }
    // Check Lines visibility (L key) - affects only line objects
    else if(isLine && !g_linesVisible) {
        shouldBeVisible = false;
    }
    
    // Apply visibility
    long timeframes = shouldBeVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
}

//+------------------------------------------------------------------+
//| Check if an object should be visible based on current state      |
//| Requirements: 10.1, 10.2                                         |
//|                                                                  |
//| Parameters:                                                      |
//|   isLine - true if checking for a line object, false otherwise  |
//|                                                                  |
//| Returns:                                                         |
//|   true if object should be visible, false if should be hidden   |
//|                                                                  |
//| Implementation:                                                  |
//|   - Checks global Hide state (cached via IsIndicatorHidden)     |
//|   - Checks global Lines visibility state (g_linesVisible)        |
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
    if(IsIndicatorHidden()) {
        return false;
    }
    
    // Check Lines visibility (L key) - affects only line objects
    if(isLine && !g_linesVisible) {
        return false;
    }
    
    // Object should be visible
    return true;
}

#endif // VISIBILITY_MANAGER_MQH
