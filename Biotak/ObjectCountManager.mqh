  //+------------------------------------------------------------------+
//|                                          ObjectCountManager.mqh  |
//|                     Object Count Management & Overflow Prevention|
//|                                                     Overflow      |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| CONSTANTS - MT4 Object Limits                                    |
//+------------------------------------------------------------------+
#ifndef MT4_OBJECT_LIMIT
#define MT4_OBJECT_LIMIT 64000          // MT4 hard limit (~64K)
#endif
#ifndef CRITICAL_OBJECT_LIMIT
#define CRITICAL_OBJECT_LIMIT 50000     // Critical threshold (78% of limit)
#endif
#ifndef MAX_SAFE_OBJECTS
#define MAX_SAFE_OBJECTS 5000           // Warning threshold
#endif
#ifndef EMERGENCY_CLEANUP_AGE
#define EMERGENCY_CLEANUP_AGE 3600      // 1 hour (seconds)
#endif

//+------------------------------------------------------------------+
//| Global State                                                      |
//+------------------------------------------------------------------+
static datetime g_lastObjectCountCheck = 0;
static int g_lastObjectCount = 0;
static datetime g_lastEmergencyCleanup = 0;

//+------------------------------------------------------------------+
//| PERF (2026): Per-frame cached object count                       |
//|                                                                  |
//| The original CanCreateObject was called from every per-object    |
//| code path (CreatePipDistanceLabel x158 per redraw, etc.) and     |
//| each call could re-enumerate ALL chart objects via              |
//| ObjectsTotal(0,-1,-1). Per the official MQL5 docs, that call   |
//| is SYNCHRONOUS and "can be time consuming when working with a   |
//| large number of objects on a chart" — the very definition of   |
//| the per-redraw hot path.                                        |
//|                                                                  |
//| Fix: the count is now memoized on CacheGetFrameTime() (one      |
//| enumeration per redraw frame, not per object). The 5-second     |
//| cross-frame throttle is kept as a safety net so a runaway caller|
//| that somehow ran without a frame stamp still works.             |
//+------------------------------------------------------------------+
static datetime g_countCacheFrame = 0;
static int      g_countCacheValue = -1;

bool CanCreateObject()
{
    datetime frameStamp = CacheGetFrameTime();

    // PERF (2026): same-frame fast path. The vast majority of redraws call
    // CanCreateObject from ~158 (CreatePipDistanceLabel) and ~159 (zone create)
    // per-frame call sites. Without this cache each one would enumerate
    // the entire chart. With it, the first call per frame pays the ObjectsTotal
    // cost; the other 317 are a single int compare and return.
    if(frameStamp == g_countCacheFrame && g_countCacheFrame > 0 && g_countCacheValue >= 0) {
        return (g_countCacheValue < CRITICAL_OBJECT_LIMIT);
    }

    datetime currentTime = TimeCurrent();
    if(currentTime - g_lastObjectCountCheck < 5 && g_lastObjectCount > 0) {
        // Use cached count
        g_countCacheFrame  = frameStamp;
        g_countCacheValue  = g_lastObjectCount;
        if(g_lastObjectCount < MAX_SAFE_OBJECTS) {
            return true; // Fast path
        }
    }

    //
    // Get current object count
    //
    int totalObjects = ObjectsTotal(0, -1, -1);
    g_lastObjectCount = totalObjects;
    g_lastObjectCountCheck = currentTime;
    g_countCacheFrame = frameStamp;
    g_countCacheValue = totalObjects;

    //
    // CRITICAL: Check if limit reached
    //
    if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        Print("  CRITICAL: Object limit reached (", totalObjects, "/", MT4_OBJECT_LIMIT, ")");
        Print("   Forcing emergency cleanup...");

        // Emergency cleanup
        int cleanedCount = EmergencyCleanupObjects();

        // Re-check after cleanup
        totalObjects = ObjectsTotal(0, -1, -1);
        g_lastObjectCount = totalObjects;
        g_countCacheValue = totalObjects;

        if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
            Print("  FATAL: Cannot free objects (", totalObjects, " remaining)");
            Print("   Please close some charts or remove other indicators");
            return false;
        }

        Print("  Emergency cleanup successful: ", cleanedCount, " objects removed");
        Print("   Current count: ", totalObjects);
    }

    //
    // WARNING: Approaching limit
    //
    if(totalObjects >= MAX_SAFE_OBJECTS) {
        // Throttle warning (once per minute)
        static datetime s_lastWarning = 0;
        if(currentTime - s_lastWarning > 60) {
            Print("   WARNING: Approaching object limit (", totalObjects, "/", MAX_SAFE_OBJECTS, ")");
            Print("   Consider reducing Max Levels in settings");
            s_lastWarning = currentTime;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Emergency Object Cleanup                                         |
//|                                                                  |
//| Returns: Number of objects deleted                               |
//+------------------------------------------------------------------+
int EmergencyCleanupObjects()
{
    datetime currentTime = TimeCurrent();
    
    //                                                                
    // Prevent cleanup spam (minimum 30 seconds between cleanups)
    //                                                                
    if(currentTime - g_lastEmergencyCleanup < 30) {
        Print("   EmergencyCleanup: Too soon since last cleanup, skipping");
        return 0;
    }
    
    g_lastEmergencyCleanup = currentTime;
    
    int deletedCount = 0;
    datetime cutoffTime = currentTime - EMERGENCY_CLEANUP_AGE;
    
    Print("   Emergency cleanup starting...");
    Print("   Cutoff time: ", TimeToString(cutoffTime, TIME_DATE|TIME_MINUTES));
    
    //
    // PHASE 1: Delete old temporary objects (labels, zones)
    // OPTIMIZATION: Cache prefix and length
    // FIX (H8): only delete objects that belong to THIS indicator (match the
    // configured prefix). Previously this loop deleted ANY chart object older
    // than the cutoff - including drawings from other indicators, manual user
    // objects, and unrelated EA annotations. With MT4's 64K object ceiling
    // this could wipe a third-party indicator's state. The fix gates every
    // delete on a prefix match so we can only reap our own objects.
    //
    string cachedPrefix = inpObjectPrefix;
    int prefixLen = StringLen(cachedPrefix);

    int totalObjects = ObjectsTotal(0, -1, -1);
    for(int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);

        // Skip TH3 structures (user drawings - never delete)
        if(StringFind(objName, "TH3_Structure_") >= 0) {
            continue;
        }

        // Skip custom price line (user setting)
        if(StringFind(objName, "CustomPriceHorizontalLine") >= 0) {
            continue;
        }

        // FIX (H8): only consider objects that match our prefix. Objects
        // belonging to other indicators or the user's manual drawings are
        // left untouched regardless of age.
        if(StringLen(objName) < prefixLen || StringSubstr(objName, 0, prefixLen) != cachedPrefix) {
            continue;
        }
        
        // FIX: OBJPROP_TIME is 0 for OBJ_HLINE (and a few other types), so those
        // objects were never reaped and accumulated as leaks. Fall back to
        // OBJPROP_CREATETIME when OBJPROP_TIME is unavailable; behavior for
        // objects with a valid OBJPROP_TIME is unchanged.
        datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
        if(objTime == 0) {
            datetime created = (datetime)ObjectGetInteger(0, objName, OBJPROP_CREATETIME);
            if(created > 0) objTime = created;
        }

        // Delete if older than cutoff
        if(objTime > 0 && objTime < cutoffTime)
        {
            if(ObjectDelete(0, objName)) {
                deletedCount++;
            }
        }
    }
    
    Print("   Phase 1: Deleted ", deletedCount, " old objects");
    
    //
    // PHASE 2: If still critical, delete ALL non-essential objects
    // FIX (H8): scope Zone_/Mid_ deletion to our prefix only. Other
    // indicators commonly use the same generic tokens ("Zone_", "Mid_")
    // for their own objects; deleting them by token alone was a silent
    // cross-indicator wipe.
    //
    totalObjects = ObjectsTotal(0, -1, -1);
    if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        Print("   Still critical after Phase 1, starting Phase 2...");

        int phase2Deleted = 0;

        // Delete all our zones (can be recreated). Use ObjectsDeleteAll with
        // the full prefix so we never touch a foreign "Zone_" object.
        phase2Deleted += ObjectsDeleteAll(0, cachedPrefix + "Zone_", -1, -1);

        // Delete all our mid-zones (can be recreated).
        phase2Deleted += ObjectsDeleteAll(0, cachedPrefix + "Mid_", -1, -1);

        // Delete our own non-essential labels, keep user-facing mode labels.
        for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
        {
            string objName = ObjectName(0, i, -1, -1);

            // FIX (H8): only touch our own labels in this pass.
            if(StringLen(objName) < prefixLen || StringSubstr(objName, 0, prefixLen) != cachedPrefix) {
                continue;
            }

            // Keep mode labels (important for user)
            if(StringFind(objName, "StepMode_Label") >= 0 ||
               StringFind(objName, "BasisMode_Label") >= 0 ||
               StringFind(objName, "Factor_Label") >= 0 ||
               StringFind(objName, "LockStatus_Label") >= 0) {
                continue;
            }

            // Delete other labels
            if(ObjectGetInteger(0, objName, OBJPROP_TYPE) == OBJ_LABEL) {
                if(ObjectDelete(0, objName)) {
                    phase2Deleted++;
                }
            }
        }

        deletedCount += phase2Deleted;
        Print("   Phase 2: Deleted ", phase2Deleted, " non-essential objects");
    }
    
    //                                                                
    // PHASE 3: Force chart redraw
    //                                                                
    ChartRedraw();
    
    Print("  Emergency cleanup complete: ", deletedCount, " total objects removed");
    
    return deletedCount;
}

//+------------------------------------------------------------------+
//| Get Current Object Count (cached)                                |
//|                         (     )                                  |
//+------------------------------------------------------------------+
int GetCurrentObjectCount()
{
    datetime currentTime = TimeCurrent();
    
    // Use cache if recent (< 5 seconds)
    if(currentTime - g_lastObjectCountCheck < 5 && g_lastObjectCount > 0) {
        return g_lastObjectCount;
    }
    
    // Update cache
    g_lastObjectCount = ObjectsTotal(0, -1, -1);
    g_lastObjectCountCheck = currentTime;
    
    return g_lastObjectCount;
}

//+------------------------------------------------------------------+
//| Invalidate Object Count Cache (force refresh on next query)      |
//+------------------------------------------------------------------+
void InvalidateObjectCountCache()
{
    g_lastObjectCountCheck = 0;
    g_lastObjectCount = 0;
    // PERF (2026): also clear the per-frame cache so the next CanCreateObject
    // call re-enumerates (used after EmergencyCleanupObjects which mutates
    // the chart object count behind the cache's back).
    g_countCacheFrame = 0;
    g_countCacheValue = -1;
}

//+------------------------------------------------------------------+
//| Cleanup Object Count Manager                                     |
//|                                                                  |
//+------------------------------------------------------------------+
void CleanupObjectCountManager()
{
    g_lastObjectCountCheck = 0;
    g_lastObjectCount = 0;
    g_lastEmergencyCleanup = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("  ObjectCountManager cleaned up");
    #endif
}

//+------------------------------------------------------------------+
//| Print Object Count Statistics                                    |
//|                                                                  |
//+------------------------------------------------------------------+
void PrintObjectCountStats()
{
    int totalObjects = ObjectsTotal(0, -1, -1);
    
    // Count by type
    int lines = 0, labels = 0, rectangles = 0, trends = 0, other = 0;
    
    for(int i = 0; i < totalObjects; i++)
    {
        string objName = ObjectName(0, i, -1, -1);
        int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
        
        switch(objType)
        {
            case OBJ_HLINE:
            case OBJ_VLINE:
                lines++;
                break;
            case OBJ_LABEL:
                labels++;
                break;
            case OBJ_RECTANGLE:
            case OBJ_RECTANGLE_LABEL:
                rectangles++;
                break;
            case OBJ_TREND:
                trends++;
                break;
            default:
                other++;
                break;
        }
    }
    
    Print("====================");
    Print("   OBJECT COUNT STATISTICS                                       ");
    Print("====================");
    Print("   Total Objects: ", totalObjects, " / ", MT4_OBJECT_LIMIT);
    Print("   Usage: ", DoubleToString(100.0 * totalObjects / MT4_OBJECT_LIMIT, 1), "%");
    Print("====================");
    Print("   Lines:      ", lines);
    Print("   Labels:     ", labels);
    Print("   Rectangles: ", rectangles);
    Print("   Trends:     ", trends);
    Print("   Other:      ", other);
    Print("====================");
}
