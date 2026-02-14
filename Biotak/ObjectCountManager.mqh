#ifndef OBJECT_COUNT_MANAGER_MQH
#define OBJECT_COUNT_MANAGER_MQH

//+------------------------------------------------------------------+
//|                                          ObjectCountManager.mqh  |
//|                     Object Count Management & Overflow Prevention|

//+------------------------------------------------------------------+

#ifndef MT4_OBJECT_LIMIT
#define MT4_OBJECT_LIMIT 512000         // MQL5 has much higher limit (~512K)
#endif
    #ifndef CRITICAL_OBJECT_LIMIT
#define CRITICAL_OBJECT_LIMIT 50000     // Matches ConstantsAndEnums.mqh
#endif
    #ifndef MAX_SAFE_OBJECTS
#define MAX_SAFE_OBJECTS 3000           // Matches ConstantsAndEnums.mqh
#endif
    #ifndef EMERGENCY_CLEANUP_AGE
#define EMERGENCY_CLEANUP_AGE 3600      // 1 hour (seconds)
#endif
    static datetime g_lastObjectCountCheck = 0;
    static int g_lastObjectCount = 0;
    static datetime g_lastEmergencyCleanup = 0;

//+------------------------------------------------------------------+
//| Check if we can safely create new objects                        |

//| Returns: true if safe, false if limit reached                   |
//+------------------------------------------------------------------+
bool CanCreateObject()
{
    // ═══════════════════════════════════════════════════════════════
    // OPTIMIZATION: Cache check (update every 5 seconds)
    // ═══════════════════════════════════════════════════════════════
    datetime currentTime = TimeCurrent();
    if(currentTime - g_lastObjectCountCheck < 1 && g_lastObjectCount > 0) {
        // Use cached count (1s cache)
        if(g_lastObjectCount < MAX_SAFE_OBJECTS) {
        return true; // Fast path
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Get current object count
    // ═══════════════════════════════════════════════════════════════
    int totalObjects = ObjectsTotal(0, -1, -1);
    g_lastObjectCount = totalObjects;
    g_lastObjectCountCheck = currentTime;
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL: Check if limit reached
    // ═══════════════════════════════════════════════════════════════
    if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("[E][CLN] CRITICAL: Object limit reached (", totalObjects, "/", MT4_OBJECT_LIMIT, ")");
    Print("[D][CLN]    Forcing emergency cleanup...");
    #endif
        
        // Emergency cleanup
        int cleanedCount = EmergencyCleanupObjects();
        
        // Re-check after cleanup
        totalObjects = ObjectsTotal(0, -1, -1);
    g_lastObjectCount = totalObjects;
    if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[E][CLN] FATAL: Cannot free objects (", totalObjects, " remaining)");
    Print("[D][CLN]    Please close some charts or remove other indicators");
    #endif
    return false;
        }
    #ifdef ENABLE_DEBUG_LOGS
        Print("[I][CLN] Emergency cleanup successful: ", cleanedCount, " objects removed");
    Print("[D][CLN]    Current count: ", totalObjects);
    #endif
    }
    
    // ═══════════════════════════════════════════════════════════════
    // WARNING: Approaching limit
    // ═══════════════════════════════════════════════════════════════
    if(totalObjects >= MAX_SAFE_OBJECTS) {
        // Throttle warning (once per minute)
        static datetime s_lastWarning = 0;
    if(currentTime - s_lastWarning > 60) {
        #ifdef ENABLE_DEBUG_LOGS
            Print("[W][CLN] WARNING: Approaching object limit (", totalObjects, "/", MAX_SAFE_OBJECTS, ")");
    Print("[D][CLN]    Consider reducing Max Levels in settings");
    #endif
    s_lastWarning = currentTime;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Emergency Object Cleanup                                         |

//| Returns: Number of objects deleted                               |
//+------------------------------------------------------------------+
int EmergencyCleanupObjects()
{
        datetime currentTime = TimeCurrent();
    
    // ═══════════════════════════════════════════════════════════════
    // Prevent cleanup spam (minimum 30 seconds between cleanups)
    // ═══════════════════════════════════════════════════════════════
    if(currentTime - g_lastEmergencyCleanup < 10) {
        _LOG_GATE_W Print("[W][CLN] EmergencyCleanup: Too soon since last cleanup, skipping");
    return 0;
    }
    
    g_lastEmergencyCleanup = currentTime;
    int deletedCount = 0;
    datetime cutoffTime = currentTime - EMERGENCY_CLEANUP_AGE;
    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][CLN] [CLEAN] Emergency cleanup starting...");
    Print("[D][CLN]    Cutoff time: ", TimeToString(cutoffTime, TIME_DATE|TIME_MINUTES));
    #endif
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 1: Delete old temporary objects (labels, zones)
    // OPTIMIZATION: Cache prefix and length
    // ═══════════════════════════════════════════════════════════════
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
        
        // CRITICAL FIX: Skip current indicator objects (prevent self-deletion)
        // OPTIMIZED: Use StringSubstr for faster prefix check
        if(StringLen(objName) >= prefixLen && StringSubstr(objName, 0, prefixLen) == cachedPrefix) {
            continue;
        }
        
        // Get object creation time
        datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
        
        // Delete if older than cutoff
        if(objTime > 0 && objTime < cutoffTime)
        {
        if(ObjectDelete(0, objName)) {
                deletedCount++;
            }
        }
    }
    _LOG_GATE_D Print("[D][CLN]    Phase 1: Deleted ", deletedCount, " old objects");
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 2: If still critical, delete ALL non-essential objects
    // ═══════════════════════════════════════════════════════════════
    totalObjects = ObjectsTotal(0, -1, -1);
    if(totalObjects >= CRITICAL_OBJECT_LIMIT) {
        _LOG_GATE_E Print("[E][CLN] Still critical after Phase 1, starting Phase 2...");
    int phase2Deleted = 0;
        
        // Delete all zones (can be recreated)
        phase2Deleted += ObjectsDeleteAll(0, "Zone_", -1, -1);
        
        // Delete all mid-zones (can be recreated)
        phase2Deleted += ObjectsDeleteAll(0, "Mid_", -1, -1);
        
        // Delete all labels except mode labels
        // GOLD FIX: Cache ObjectsTotal outside loop
        totalObjects = ObjectsTotal(0, -1, -1);
    for(int i = totalObjects - 1; i >= 0; i--)
        {
        string objName = ObjectName(0, i, -1, -1);
            
            // GOLD FIX: Optimize StringFind with early exit pattern
            // Cache first char check for faster rejection
            int nameLen = StringLen(objName);
    if(nameLen < 12) continue;  // All labels are at least 12 chars
            
            // Keep mode labels (important for user)
            // OPTIMIZATION: Check most common first
            bool isModeLabel = (StringFind(objName, "StepMode_Label") >= 0);
    if(!isModeLabel) isModeLabel = (StringFind(objName, "Factor_Label") >= 0);
    if(!isModeLabel) isModeLabel = (StringFind(objName, "LockStatus_Label") >= 0);
    if(isModeLabel) {
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
        _LOG_GATE_D Print("[D][CLN]    Phase 2: Deleted ", phase2Deleted, " non-essential objects");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PHASE 3: Force chart redraw
    // ═══════════════════════════════════════════════════════════════
    ChartRedraw();
    _LOG_GATE_I Print("[I][CLN] Emergency cleanup complete: ", deletedCount, " total objects removed");
    return deletedCount;
}

//+------------------------------------------------------------------+
//| Get Current Object Count (cached)                                |

//+------------------------------------------------------------------+
int GetCurrentObjectCount()
{
        datetime currentTime = TimeCurrent();
    
    // Reduced cache timeout to 5s for more responsive object count tracking
    if(currentTime - g_lastObjectCountCheck < 5 && g_lastObjectCount > 0) {
        return g_lastObjectCount;
    }
    
    // Update cache
    g_lastObjectCount = ObjectsTotal(0, -1, -1);
    g_lastObjectCountCheck = currentTime;
    return g_lastObjectCount;
}

//+------------------------------------------------------------------+
//| Cleanup Object Count Manager                                     |

//+------------------------------------------------------------------+
// FIX: Invalidate cached object count immediately after bulk deletion
void InvalidateObjectCountCache()
{
    g_lastObjectCountCheck = 0;
    g_lastObjectCount = 0;
}

void CleanupObjectCountManager()
{
    g_lastObjectCountCheck = 0;
    g_lastObjectCount = 0;
    g_lastEmergencyCleanup = 0;
    _LOG_GATE_I Print("[I][CLN] ObjectCountManager cleaned up");
    }

//+------------------------------------------------------------------+
//| Print Object Count Statistics                                    |

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
    #ifdef ENABLE_DEBUG_LOGS
    Print("[D][CLN] ╔═══════════════════════════════════════════════════════════════╗");
    Print("[D][CLN] ║  OBJECT COUNT STATISTICS                                      ║");
    Print("[D][CLN] ╠═══════════════════════════════════════════════════════════════╣");
    Print("[D][CLN] ║  Total Objects: ", totalObjects, " / ", MT4_OBJECT_LIMIT);
    Print("[D][CLN] ║  Usage: ", DoubleToString(100.0 * totalObjects / MT4_OBJECT_LIMIT, 1), "%");
    Print("[D][CLN] ╠═══════════════════════════════════════════════════════════════╣");
    Print("[D][CLN] ║  Lines:      ", lines);
    Print("[D][CLN] ║  Labels:     ", labels);
    Print("[D][CLN] ║  Rectangles: ", rectangles);
    Print("[D][CLN] ║  Trends:     ", trends);
    Print("[D][CLN] ║  Other:      ", other);
    Print("[D][CLN] ╚═══════════════════════════════════════════════════════════════╝");
    #endif
    }
    #endif
    // OBJECT_COUNT_MANAGER_MQH
