//+------------------------------------------------------------------+
//|                                                ZoneConstants.mqh |
//|                                  Copyright 2025, Biotak Project  |
//|                                    Global Constants & Settings   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Biotak Project"
#property link      "https://www.mql5.com"

// CRITICAL: Include guard to prevent duplicate symbols
#ifndef ZONE_CONSTANTS_MQH
#define ZONE_CONSTANTS_MQH

//+------------------------------------------------------------------+
//| GLOBAL CONSTANTS: Zone Drawing Configuration                     |
//| ثوابت جهانی: تنظیمات رسم زون                                     |
//+------------------------------------------------------------------+

// Performance Constants — duplicates moved to ProjectConstants.mqh (single source of truth)\n// ZONE_EXTENSION_PERIODS, MAX_ZONES_PER_CHART, OBJECT_CACHE_SIZE → ProjectConstants.mqh
const int VALIDATION_CACHE_TTL = 60;           // مدت اعتبار کش اعتبارسنجی (ثانیه)
const int CACHE_CLEANUP_INTERVAL = 300;        // فاصله cleanup کش (5 دقیقه)
const int MAX_ALPHA_VALUE = 255;               // حداکثر مقدار آلفا برای transparency
const int MIN_ALPHA_VALUE = 0;                 // حداقل مقدار آلفا

// Safety Limits — duplicates moved to ProjectConstants.mqh (single source of truth)\n// MAX_ZONE_HEIGHT_PERCENT, MIN_ZONE_HEIGHT_PERCENT, MAX_PRICE_DEVIATION → ProjectConstants.mqh
const double MIN_STEP_SIZE_RATIO = 0.000001;   // حداقل نسبت اندازه گام به قیمت

// Error Codes
const int ERR_ZONE_NONE = 0;
const int ERR_ZONE_INVALID_ARRAY = 1;
const int ERR_ZONE_INVALID_STEP = 2;
const int ERR_ZONE_INVALID_CONFIG = 3;
const int ERR_ZONE_RENDER_FAILED = 4;
const int ERR_ZONE_MEMORY_LIMIT = 5;
const int ERR_ZONE_ARRAY_MISMATCH = 6;
const int ERR_ZONE_NO_DATA = 7;            // ✅ NEW: No bars available yet

// Debug Flags
#ifdef ENABLE_DEBUG_LOGS
    #define ZONE_DEBUG_VALIDATION true
    #define ZONE_DEBUG_CALCULATION true
    #define ZONE_DEBUG_RENDERING true
    #define ZONE_DEBUG_PERFORMANCE true
#else
    #define ZONE_DEBUG_VALIDATION false
    #define ZONE_DEBUG_CALCULATION false
    #define ZONE_DEBUG_RENDERING false
    #define ZONE_DEBUG_PERFORMANCE false
#endif

//+------------------------------------------------------------------+
//| STRUCTURE: Performance Metrics                                    |
//| ساختار: معیارهای عملکرد                                          |
//+------------------------------------------------------------------+
struct SZonePerformanceMetrics {
    int totalZonesCreated;
    int totalZonesUpdated;
    int totalZonesFailed;
    int totalValidationCalls;
    int totalRenderCalls;
    double avgValidationTime;
    double avgRenderTime;
    datetime lastResetTime;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES: Performance Tracking                           |
//| متغیرهای جهانی: ردیابی عملکرد                                    |
//+------------------------------------------------------------------+
static SZonePerformanceMetrics g_zoneMetrics;
static datetime g_lastCacheCleanup = 0;

// Market Price Cache (برای جلوگیری از محاسبات تکراری)
static double g_cachedMarketPrice = 0;
static datetime g_cachedMarketPriceTime = 0;
static int g_cachedMarketPriceTTL = 1; // 1 ثانیه

//+------------------------------------------------------------------+
//| Initialize Performance Metrics                                    |
//| مقداردهی اولیه معیارهای عملکرد                                   |
//+------------------------------------------------------------------+
void InitializeZoneMetrics() {
    g_zoneMetrics.totalZonesCreated = 0;
    g_zoneMetrics.totalZonesUpdated = 0;
    g_zoneMetrics.totalZonesFailed = 0;
    g_zoneMetrics.totalValidationCalls = 0;
    g_zoneMetrics.totalRenderCalls = 0;
    g_zoneMetrics.avgValidationTime = 0;
    g_zoneMetrics.avgRenderTime = 0;
    g_zoneMetrics.lastResetTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Reset Performance Metrics                                         |
//| بازنشانی معیارهای عملکرد                                          |
//+------------------------------------------------------------------+
void ResetZoneMetrics() {
    InitializeZoneMetrics();
}

//+------------------------------------------------------------------+
//| Get Performance Metrics                                           |
//| دریافت معیارهای عملکرد                                            |
//+------------------------------------------------------------------+
SZonePerformanceMetrics GetZoneMetrics() {
    return g_zoneMetrics;
}

//+------------------------------------------------------------------+
//| Print Performance Report                                          |
//| چاپ گزارش عملکرد                                                  |
//+------------------------------------------------------------------+
void PrintZonePerformanceReport() {
    #ifdef ENABLE_DEBUG_LOGS
    Print("═══════════════════════════════════════════════════════════");
    Print("📊 Zone Drawing Performance Report");
    Print("═══════════════════════════════════════════════════════════");
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ Zones Created: ", g_zoneMetrics.totalZonesCreated);
    Print("🔄 Zones Updated: ", g_zoneMetrics.totalZonesUpdated);
    Print("❌ Zones Failed: ", g_zoneMetrics.totalZonesFailed);
    Print("🔍 Validation Calls: ", g_zoneMetrics.totalValidationCalls);
    Print("🎨 Render Calls: ", g_zoneMetrics.totalRenderCalls);
    Print("⏱️ Avg Validation Time: ", DoubleToString(g_zoneMetrics.avgValidationTime, 2), " ms");
    Print("⏱️ Avg Render Time: ", DoubleToString(g_zoneMetrics.avgRenderTime, 2), " ms");
    Print("📅 Last Reset: ", TimeToString(g_zoneMetrics.lastResetTime));
    Print("═══════════════════════════════════════════════════════════");
    #endif
    #endif
}

//+------------------------------------------------------------------+
//| Cleanup Zone System (برای OnDeinit)                              |
//| پاک‌سازی سیستم زون                                               |
//+------------------------------------------------------------------+
void CleanupZoneSystem() {
    // Reset metrics
    g_zoneMetrics.totalZonesCreated = 0;
    g_zoneMetrics.totalZonesUpdated = 0;
    g_zoneMetrics.totalZonesFailed = 0;
    g_zoneMetrics.totalValidationCalls = 0;
    g_zoneMetrics.totalRenderCalls = 0;
    g_zoneMetrics.avgValidationTime = 0;
    g_zoneMetrics.avgRenderTime = 0;
    
    g_lastCacheCleanup = 0;
    
    // Clear market price cache
    g_cachedMarketPrice = 0;
    g_cachedMarketPriceTime = 0;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CleanupZoneSystem: System cleaned up successfully");
    #endif
}

//+------------------------------------------------------------------+
//| Get Cached Market Price (با TTL)                                 |
//| دریافت قیمت بازار از کش                                          |
//+------------------------------------------------------------------+
double GetCachedMarketPrice() {
    datetime currentTime = TimeCurrent();
    
    // بررسی اعتبار کش
    if(g_cachedMarketPriceTime > 0 && 
       (currentTime - g_cachedMarketPriceTime) < g_cachedMarketPriceTTL) {
        return g_cachedMarketPrice;
    }
    
    // CRITICAL: Cache Bid/Ask to avoid race condition
    double cachedBid = Bid;
    double cachedAsk = Ask;
    
    // محاسبه و ذخیره در کش
    g_cachedMarketPrice = (cachedBid + cachedAsk) / 2.0;
    g_cachedMarketPriceTime = currentTime;
    
    return g_cachedMarketPrice;
}

//+------------------------------------------------------------------+
//| Cleanup Object Cache (پاک‌سازی دوره‌ای)                          |
//| Note: This function is deprecated - use ObjectCache.mqh instead  |
//+------------------------------------------------------------------+
void CleanupObjectCache() {
    // Deprecated: Object cache is now managed by ObjectCache.mqh
    // This function is kept for backward compatibility but does nothing
    g_lastCacheCleanup = TimeCurrent();
}

#endif // ZONE_CONSTANTS_MQH
