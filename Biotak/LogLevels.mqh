//+------------------------------------------------------------------+
//|                                                    LogLevels.mqh |
//|                                  GOLD VERSION: Unified Logging   |
//|                                  Centralized Log Level Management|
//+------------------------------------------------------------------+
#property copyright "© Biotak - GOLD Version v3"

#ifndef LOG_LEVELS_MQH
#define LOG_LEVELS_MQH

//+------------------------------------------------------------------+
//| Log Levels (Priority Order)                                      |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
    LOG_LEVEL_NONE = 0,      // No logging
    LOG_LEVEL_ERROR = 1,     // Only errors
    LOG_LEVEL_WARNING = 2,   // Errors + warnings
    LOG_LEVEL_INFO = 3,      // Errors + warnings + info
    LOG_LEVEL_DEBUG = 4      // All messages (verbose)
};

// Global log level setting
#ifdef ENABLE_DEBUG_LOGS
    static ENUM_LOG_LEVEL g_currentLogLevel = LOG_LEVEL_DEBUG;
#else
    static ENUM_LOG_LEVEL g_currentLogLevel = LOG_LEVEL_WARNING;
#endif

//+------------------------------------------------------------------+
//| Set Current Log Level                                            |
//+------------------------------------------------------------------+
void SetLogLevel(ENUM_LOG_LEVEL level) {
    g_currentLogLevel = level;
}

//+------------------------------------------------------------------+
//| Get Current Log Level                                            |
//+------------------------------------------------------------------+
ENUM_LOG_LEVEL GetLogLevel() {
    return g_currentLogLevel;
}

//+------------------------------------------------------------------+
//| Log Functions with Level Filtering                               |
//+------------------------------------------------------------------+

// Log Error (always shown unless LOG_LEVEL_NONE)
void LogError(string message) {
    if(g_currentLogLevel >= LOG_LEVEL_ERROR) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("❌ ERROR: ", message);
        #endif
    }
}

// Log Warning
void LogWarning(string message) {
    if(g_currentLogLevel >= LOG_LEVEL_WARNING) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("⚠️ WARNING: ", message);
        #endif
    }
}

// Log Info
void LogInfo(string message) {
    if(g_currentLogLevel >= LOG_LEVEL_INFO) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("ℹ️ INFO: ", message);
        #endif
    }
}

// Log Debug (verbose)
void LogDebug(string message) {
    if(g_currentLogLevel >= LOG_LEVEL_DEBUG) {
        #ifdef ENABLE_DEBUG_LOGS
        Print("🔍 DEBUG: ", message);
        #endif
    }
}

#endif // LOG_LEVELS_MQH
