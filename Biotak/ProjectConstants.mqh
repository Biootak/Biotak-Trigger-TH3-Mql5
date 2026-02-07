//+------------------------------------------------------------------+
//|                                      ProjectConstants.mqh        |
//|                     Centralized Constants - PLATINUM VERSION     |
//|                     ثابت‌های متمرکز - نسخه پلاتینیوم              |
//|                                                                  |
//| BENEFITS:                                                        |
//| - Single source of truth for all constants                      |
//| - Easy to maintain and update                                   |
//| - No magic numbers in code                                      |
//| - Self-documenting with clear names                             |
//+------------------------------------------------------------------+

// ═══════════════════════════════════════════════════════════════
// PERCENTAGE CONSTANTS
// ثابت‌های درصدی
// ═══════════════════════════════════════════════════════════════
const int MIN_TRANSPARENCY_PERCENT = 0;
const int MAX_TRANSPARENCY_PERCENT = 100;
const int DEFAULT_TRANSPARENCY_PERCENT = 50;

const double MIN_ZONE_HEIGHT_PERCENT = 0.01;    // 1%
const double MAX_ZONE_HEIGHT_PERCENT = 1.0;     // 100%
const double DEFAULT_ZONE_HEIGHT_PERCENT = 0.125; // 12.5%

// ═══════════════════════════════════════════════════════════════
// MULTIPLIERS & FACTORS
// ضرایب و فاکتورها
// ═══════════════════════════════════════════════════════════════
const int ZONE_EXTENSION_MULTIPLIER = 10000;    // برای محاسبه endTime
const int ALPHA_SCALE_FACTOR = 255;             // برای محاسبه alpha channel
const int PERCENTAGE_TO_DECIMAL = 100;          // تبدیل درصد به اعشار

// ═══════════════════════════════════════════════════════════════
// PERFORMANCE CONSTANTS
// ثابت‌های عملکردی
// ═══════════════════════════════════════════════════════════════
const int CACHE_LOG_INTERVAL = 100;             // فاصله لاگ cache hits
const int ZONE_EXTENSION_PERIODS = 100;         // تعداد دوره‌های گسترش zone
const int MAX_ZONES_PER_CHART = 500;            // حداکثر تعداد zone در چارت
const int OBJECT_CACHE_SIZE = 1000;             // اندازه کش اشیاء

// ═══════════════════════════════════════════════════════════════
// LIMITS & THRESHOLDS
// محدودیت‌ها و آستانه‌ها
// ═══════════════════════════════════════════════════════════════
const int MAX_MOVEMENT_CANDLES = 10000;         // حداکثر کندل‌های حرکت
const int MAX_REST_CANDLES = 1000;              // حداکثر کندل‌های استراحت
const int MAX_LEARNING_DATA_SIZE = 10000;       // حداکثر اندازه داده‌های یادگیری

const double MAX_PRICE_DEVIATION = 2.0;         // حداکثر انحراف قیمت (200%)
const double MAX_ZONE_HEIGHT_PERCENT_LIMIT = 1.0; // محدودیت ارتفاع zone

// ═══════════════════════════════════════════════════════════════
// FREQUENCY CALCULATION
// محاسبات فرکانس
// ═══════════════════════════════════════════════════════════════
const int FREQUENCY_BASE = 100;                 // برای Step N: frequency = 100/N

// Step-specific frequencies
const double FREQUENCY_STEP_3 = 33.333;         // 100/3
const double FREQUENCY_STEP_5 = 20.0;           // 100/5
const double FREQUENCY_STEP_7 = 14.286;         // 100/7

// ═══════════════════════════════════════════════════════════════
// CONSOLIDATION THRESHOLDS
// آستانه‌های consolidation
// ═══════════════════════════════════════════════════════════════
const double CONSOLIDATION_VERY_LOW = 0.6;      // 60% - انرژی خیلی کم
const double CONSOLIDATION_LOW = 1.0;           // 100% - انرژی کافی
const double CONSOLIDATION_MEDIUM = 1.5;        // 150% - انرژی زیاد

// ═══════════════════════════════════════════════════════════════
// PATTERN DETECTION THRESHOLDS
// آستانه‌های تشخیص الگو
// ═══════════════════════════════════════════════════════════════
const double GANN_ANGLE_STRONG_IMPULSIVE = 75.0;    // زاویه Gann برای الگوی قوی
const double GANN_ANGLE_MEDIUM_IMPULSIVE = 50.0;   // زاویه Gann برای الگوی متوسط
const double CONSOLIDATION_IMPULSIVE_MAX = 0.1;    // حداکثر consolidation برای impulsive (10%)
const double TIME_SYMMETRY_GOOD = 0.8;             // تقارن زمانی خوب (80%)

// ═══════════════════════════════════════════════════════════════
// LOGGING INTERVALS
// فواصل لاگ‌گذاری
// ═══════════════════════════════════════════════════════════════
const int TEST_ARRAY_SIZE = 100;                // اندازه آرایه تست
const int TEST_OVERFLOW_COUNT = 100;            // تعداد overflow در تست
const int LABEL_OFFSET_MAX_PIPS = 100;          // حداکثر offset لیبل (pips)
const int PATTERN_BARS_PADDING = 100;           // padding برای نمایش الگو

// ═══════════════════════════════════════════════════════════════
// TIME CONSTANTS
// ثابت‌های زمانی
// ═══════════════════════════════════════════════════════════════
const int SECONDS_PER_MINUTE = 60;
const int SECONDS_PER_HOUR = 3600;
const int SECONDS_PER_DAY = 86400;
const int SECONDS_PER_MONTH = 2592000;          // 30 days

const int MUTEX_STALE_TIMEOUT_SECONDS = 2;      // timeout برای stale mutex
const int MUTEX_RETRY_ATTEMPTS = 10;            // تعداد تلاش برای گرفتن mutex
const int MUTEX_RETRY_DELAY_MS = 10;            // تأخیر بین تلاش‌ها (میلی‌ثانیه)

// ═══════════════════════════════════════════════════════════════
// ARRAY SIZES
// اندازه‌های آرایه
// ═══════════════════════════════════════════════════════════════
const int DEFAULT_ARRAY_SIZE = 10;
const int SMALL_ARRAY_SIZE = 50;
const int MEDIUM_ARRAY_SIZE = 100;
const int LARGE_ARRAY_SIZE = 500;

// ═══════════════════════════════════════════════════════════════
// VALIDATION CONSTANTS
// ثابت‌های اعتبارسنجی
// ═══════════════════════════════════════════════════════════════
const double MIN_PRICE_VALUE = 0.00001;         // حداقل قیمت معتبر
const double MAX_PRICE_MULTIPLIER = 1000000.0;  // حداکثر ضریب قیمت
const int MIN_BARS_REQUIRED = 1;                // حداقل تعداد کندل مورد نیاز
const int MAX_BARS_LOOKBACK = 10000;            // حداکثر lookback

// ═══════════════════════════════════════════════════════════════
// ERROR CODES (Centralized)
// کدهای خطا (متمرکز)
// ═══════════════════════════════════════════════════════════════
const int ERROR_CODE_SUCCESS = 0;
const int ERROR_CODE_INVALID_INPUT = -1;
const int ERROR_CODE_MEMORY_LIMIT = -2;
const int ERROR_CODE_FILE_OPERATION = -3;
const int ERROR_CODE_STATE_CONFLICT = -4;
const int ERROR_CODE_OVERFLOW = -5;

// ═══════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// توابع کمکی
// ═══════════════════════════════════════════════════════════════

//+------------------------------------------------------------------+
//| Convert Percentage to Decimal                                    |
//| تبدیل درصد به اعشار                                              |
//+------------------------------------------------------------------+
double PercentToDecimal(double percent)
{
    return percent / PERCENTAGE_TO_DECIMAL;
}

//+------------------------------------------------------------------+
//| Convert Decimal to Percentage                                    |
//| تبدیل اعشار به درصد                                              |
//+------------------------------------------------------------------+
double DecimalToPercent(double decimal)
{
    return decimal * PERCENTAGE_TO_DECIMAL;
}

//+------------------------------------------------------------------+
//| Calculate Alpha from Transparency                                |
//| محاسبه alpha از transparency                                     |
//+------------------------------------------------------------------+
int TransparencyToAlpha(int transparency)
{
    // Clamp transparency
    if(transparency < MIN_TRANSPARENCY_PERCENT) transparency = MIN_TRANSPARENCY_PERCENT;
    if(transparency > MAX_TRANSPARENCY_PERCENT) transparency = MAX_TRANSPARENCY_PERCENT;
    
    // Calculate alpha
    return (int)((MAX_TRANSPARENCY_PERCENT - transparency) * ALPHA_SCALE_FACTOR / PERCENTAGE_TO_DECIMAL);
}

//+------------------------------------------------------------------+
//| Validate Transparency Range                                      |
//| اعتبارسنجی محدوده transparency                                   |
//+------------------------------------------------------------------+
bool IsValidTransparency(int transparency)
{
    return (transparency >= MIN_TRANSPARENCY_PERCENT && 
            transparency <= MAX_TRANSPARENCY_PERCENT);
}

//+------------------------------------------------------------------+
//| Validate Zone Height Percent                                     |
//| اعتبارسنجی درصد ارتفاع zone                                      |
//+------------------------------------------------------------------+
bool IsValidZoneHeightPercent(double heightPercent)
{
    return (heightPercent >= MIN_ZONE_HEIGHT_PERCENT && 
            heightPercent <= MAX_ZONE_HEIGHT_PERCENT);
}

//+------------------------------------------------------------------+
//| Get Frequency for Step                                           |
//| دریافت فرکانس برای گام                                           |
//+------------------------------------------------------------------+
double GetFrequencyForStep(int step)
{
    if(step <= 0) return 0.0;
    return (double)FREQUENCY_BASE / step;
}

//+------------------------------------------------------------------+
//| Validate Price Value                                             |
//| اعتبارسنجی مقدار قیمت                                            |
//+------------------------------------------------------------------+
bool IsValidPrice(double price)
{
    return (price >= MIN_PRICE_VALUE && price < MAX_PRICE_MULTIPLIER);
}

//+------------------------------------------------------------------+
//| Print Constants Summary (Debug)                                  |
//| چاپ خلاصه ثابت‌ها (دیباگ)                                        |
//+------------------------------------------------------------------+
void PrintConstantsSummary()
{
    #ifdef ENABLE_DEBUG_LOGS
    Print("═══════════════════════════════════════════════════════════");
    Print("📋 PROJECT CONSTANTS SUMMARY");
    Print("═══════════════════════════════════════════════════════════");
    #ifdef ENABLE_DEBUG_LOGS
    Print("Transparency Range: ", MIN_TRANSPARENCY_PERCENT, "-", MAX_TRANSPARENCY_PERCENT, "%");
    Print("Zone Height Range: ", DoubleToString(MIN_ZONE_HEIGHT_PERCENT * 100, 2), "-", 
    #endif
          DoubleToString(MAX_ZONE_HEIGHT_PERCENT * 100, 2), "%");
    #ifdef ENABLE_DEBUG_LOGS
    Print("Max Zones Per Chart: ", MAX_ZONES_PER_CHART);
    Print("Max Learning Data: ", MAX_LEARNING_DATA_SIZE);
    Print("Cache Log Interval: ", CACHE_LOG_INTERVAL);
    Print("═══════════════════════════════════════════════════════════");
    #endif
    #endif
}
