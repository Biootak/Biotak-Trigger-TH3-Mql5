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

// Performance Constants
const int ZONE_EXTENSION_PERIODS = 100;        // تعداد دوره‌های گسترش زون به آینده (برای ray_right)
const int MAX_ZONES_PER_CHART = 500;          // حداکثر تعداد زون در هر چارت (محدودیت MT4)
const int OBJECT_CACHE_SIZE = 1000;            // اندازه کش اشیاء (بهینه برای 500 zone)
const int VALIDATION_CACHE_TTL = 60;           // مدت اعتبار کش اعتبارسنجی (ثانیه)
const int CACHE_CLEANUP_INTERVAL = 300;        // فاصله cleanup کش (5 دقیقه)
const int MAX_ALPHA_VALUE = 255;               // حداکثر مقدار آلفا برای transparency
const int MIN_ALPHA_VALUE = 0;                 // حداقل مقدار آلفا

// Safety Limits
const double MAX_ZONE_HEIGHT_PERCENT = 1.0;    // حداکثر درصد ارتفاع زون (100%)
const double MIN_ZONE_HEIGHT_PERCENT = 0.01;   // حداقل درصد ارتفاع زون (1%)
const double MAX_PRICE_DEVIATION = 2.0;        // حداکثر انحراف قیمت (200% قیمت فعلی)
const double MIN_STEP_SIZE_RATIO = 0.000001;   // حداقل نسبت اندازه گام به قیمت

// Error Codes
const int ERR_ZONE_NONE = 0;
const int ERR_ZONE_INVALID_ARRAY = 1;
const int ERR_ZONE_INVALID_STEP = 2;
const int ERR_ZONE_INVALID_CONFIG = 3;
const int ERR_ZONE_RENDER_FAILED = 4;
const int ERR_ZONE_MEMORY_LIMIT = 5;
const int ERR_ZONE_ARRAY_MISMATCH = 6;

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
//| STRUCTURE: Object Cache Entry                                    |
//| ساختار: ورودی کش اشیاء                                           |
//+------------------------------------------------------------------+
struct SObjectCacheEntry {
    string name;
    bool exists;
    datetime lastCheck;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES: Performance Tracking                           |
//| متغیرهای جهانی: ردیابی عملکرد                                    |
//+------------------------------------------------------------------+
static SZonePerformanceMetrics g_zoneMetrics;
static SObjectCacheEntry g_objectCache[];
static int g_objectCacheSize = 0;
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
    
    ArrayResize(g_objectCache, OBJECT_CACHE_SIZE);
    g_objectCacheSize = 0;
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
    
    // Clear cache
    ArrayResize(g_objectCache, 0);
    g_objectCacheSize = 0;
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
//| پاک‌سازی کش اشیاء                                                 |
//+------------------------------------------------------------------+
void CleanupObjectCache() {
    datetime currentTime = TimeCurrent();
    
    // بررسی نیاز به cleanup
    if(g_lastCacheCleanup > 0 && 
       (currentTime - g_lastCacheCleanup) < CACHE_CLEANUP_INTERVAL) {
        return;
    }
    
    // CRITICAL: Validate array size before access
    int cacheArraySize = ArraySize(g_objectCache);
    int safeSize = MathMin(g_objectCacheSize, cacheArraySize);
    
    // پاک‌سازی ورودی‌های قدیمی
    int validCount = 0;
    for(int i = 0; i < safeSize; i++) {
        if((currentTime - g_objectCache[i].lastCheck) < VALIDATION_CACHE_TTL) {
            if(validCount != i) {
                g_objectCache[validCount] = g_objectCache[i];
            }
            validCount++;
        }
    }
    
    g_objectCacheSize = validCount;
    g_lastCacheCleanup = currentTime;
    
    #ifdef ENABLE_DEBUG_LOGS
    Print("✅ CleanupObjectCache: Cleaned ", (safeSize - validCount), " old entries");
    #endif
}

#endif // ZONE_CONSTANTS_MQH
