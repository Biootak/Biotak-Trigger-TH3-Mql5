#ifndef BUILD_CONFIG_MQH
#define BUILD_CONFIG_MQH

#property copyright " Biotak"

// Uncomment for DEBUG mode:
// #define DEBUG_BUILD

// Optional compile-time profiler (no inputs; when disabled it compiles out)
// Enable by defining ENABLE_TH3_PROFILER (presence macro).
// Default: enabled only in DEBUG_BUILD.
#define ENABLE_TH3_PROFILER

#ifndef ENABLE_TH3_PROFILER
    #ifdef DEBUG_BUILD
        #define ENABLE_TH3_PROFILER
    #endif
#endif

// Must be after ENABLE_TH3_PROFILER
#include "Profiler.mqh"

#ifdef DEBUG_BUILD
    #define ENABLE_ATR_LOGS
    #define ENABLE_VERBOSE_ERRORS
    #define ENABLE_ASSERTIONS
    #define BUILD_MODE_STR "DEBUG"
    #define BUILD_MODE_EMOJI "[D]"
#else
    #define BUILD_MODE_STR "PRODUCTION"
    #define BUILD_MODE_EMOJI "[P]"
#endif

// ATR Logs
#ifdef ENABLE_ATR_LOGS
    #define ATR_PRINT(msg) Print("[ATR] ", msg)
    #define ATR_PRINTF(msg, p1) Print("[ATR] ", msg, p1)
    #define ATR_PRINTF2(msg, p1, p2) Print("[ATR] ", msg, p1, p2)
    #define ATR_PRINTF3(msg, p1, p2, p3) Print("[ATR] ", msg, p1, p2, p3)
#else
    #define ATR_PRINT(msg)
    #define ATR_PRINTF(msg, p1)
    #define ATR_PRINTF2(msg, p1, p2)
    #define ATR_PRINTF3(msg, p1, p2, p3)
#endif

// Debug Logs
#ifdef ENABLE_DEBUG_LOGS
    #define DEBUG_PRINT(msg) Print("[DEBUG] ", msg)
    #define DEBUG_PRINTF(msg, p1) Print("[DEBUG] ", msg, p1)
    #define DEBUG_PRINTF2(msg, p1, p2) Print("[DEBUG] ", msg, p1, p2)
    #define DEBUG_PRINTF3(msg, p1, p2, p3) Print("[DEBUG] ", msg, p1, p2, p3)
    #define DEBUG_PRINTF4(msg, p1, p2, p3, p4) Print("[DEBUG] ", msg, p1, p2, p3, p4)
    #define DEBUG_PRINTF5(msg, p1, p2, p3, p4, p5) Print("[DEBUG] ", msg, p1, p2, p3, p4, p5)
    #define HISTORY_LOG_ENABLED 1
#else
    #define DEBUG_PRINT(msg)
    #define DEBUG_PRINTF(msg, p1)
    #define DEBUG_PRINTF2(msg, p1, p2)
    #define DEBUG_PRINTF3(msg, p1, p2, p3)
    #define DEBUG_PRINTF4(msg, p1, p2, p3, p4)
    #define DEBUG_PRINTF5(msg, p1, p2, p3, p4, p5)
    #define HISTORY_LOG_ENABLED 0
#endif
    #define PERF_START()
#define PERF_END(name)

#ifdef ENABLE_VERBOSE_ERRORS
    #define ERROR_PRINT(msg) Print("[ERROR] ", __FUNCTION__, " - ", msg)
    #define WARN_PRINT(msg) Print("[WARN] ", __FUNCTION__, " - ", msg)
#else
    #define ERROR_PRINT(msg) Print("[ERROR] ", msg)
    #define WARN_PRINT(msg)
#endif
    #ifdef ENABLE_ASSERTIONS
    #define ASSERT(condition, msg) if(!(condition)) { Print("[ASSERT FAILED] ", __FUNCTION__, " - ", msg); }
    #define ASSERT_PRICE(price) ASSERT(price > 0 && price < 1000000, "Invalid price")
#else
    #define ASSERT(condition, msg)
    #define ASSERT_PRICE(price)
#endif
    #define INDICATOR_VERSION "3.05"

void PrintBuildInfo()
{
        #ifdef ENABLE_DEBUG_LOGS
    Print("=== Biotak Trigger TH3 v", INDICATOR_VERSION, " [", BUILD_MODE_STR, "] ===");
    #ifdef DEBUG_BUILD
    Print("WARNING: DEBUG BUILD");
    #endif
    #endif
}
    #endif
    // BUILD_CONFIG_MQH