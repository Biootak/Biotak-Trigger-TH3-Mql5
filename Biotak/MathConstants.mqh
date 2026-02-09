//+------------------------------------------------------------------+
//|                                             MathConstants.mqh     |
//|                     Centralized Mathematical Constants            |
//|                     ثابت‌های ریاضی متمرکز                          |
//+------------------------------------------------------------------+
#property copyright "© Biotak - Professional Trading Systems"

//+------------------------------------------------------------------+
//| STEP MULTIPLIERS - TH Calculation Constants                      |
//| ضرایب گام - ثابت‌های محاسبه TH                                   |
//+------------------------------------------------------------------+
// Short Step (SS) = 1.5 × TH
// Long Step (LS) = 2.0 × TH
// Control (C) = Average of SS and LS = 1.75 × TH
// E Step = 0.75 × TH
// TP Step = 3 × E = 2.25 × TH

#define SS_MULTIPLIER 1.5        // Short Step
#define LS_MULTIPLIER 2.0        // Long Step
#define CONTROL_MULTIPLIER 1.75  // Control (average of SS/LS)
#define E_MULTIPLIER 0.75        // E Step
#define TP_MULTIPLIER 2.25       // TP Step (3×E = 3×0.75 = 2.25)

//+------------------------------------------------------------------+
//| ATR FACTORS                                                       |
//| فاکتورهای ATR                                                     |
//+------------------------------------------------------------------+
#define ATR_FACTOR_M 3.0         // ATR factor for M calculations
#define ATR_PERIODS_D1 14        // ATR period for daily timeframe

//+------------------------------------------------------------------+
//| FIBONACCI RATIOS                                                  |
//| نسبت‌های فیبوناچی                                                 |
//+------------------------------------------------------------------+
#define FIB_RATIO_0_382 0.382
#define FIB_RATIO_0_500 0.500
#define FIB_RATIO_0_618 0.618
#define FIB_RATIO_0_786 0.786
#define FIB_RATIO_1_000 1.000
#define FIB_RATIO_1_272 1.272
#define FIB_RATIO_1_414 1.414
#define FIB_RATIO_1_618 1.618
#define FIB_RATIO_2_000 2.000
#define FIB_RATIO_2_618 2.618

//+------------------------------------------------------------------+
//| GOLDEN RATIO                                                      |
//| نسبت طلایی                                                        |
//+------------------------------------------------------------------+
#define GOLDEN_RATIO 1.618033988749895
#define GOLDEN_RATIO_INVERSE 0.618033988749895

//+------------------------------------------------------------------+
//| PERCENTAGE CONVERSIONS                                            |
//| تبدیل‌های درصدی                                                   |
//+------------------------------------------------------------------+
#define PERCENT_TO_DECIMAL 100.0     // تبدیل درصد به اعشار: 50% → 0.50
#define DECIMAL_TO_PERCENT 100.0     // تبدیل اعشار به درصد: 0.50 → 50%

//+------------------------------------------------------------------+
//| FRACTAL PERCENTAGES (Modified by 1.0415625 factor)              |
//| درصدهای فرکتال (اصلاح شده با ضریب 1.0415625)                     |
//| Matches MotiveWave FRACTAL_PERCENTAGES exactly                  |
//+------------------------------------------------------------------+
const double FRACTAL_PERCENT_M1       = 0.0208;   // M1: 2.08%
const double FRACTAL_PERCENT_M4       = 0.0417;   // M4: 4.17%
const double FRACTAL_PERCENT_M16      = 0.0833;   // M16: 8.33%
const double FRACTAL_PERCENT_H1M4     = 0.1666;   // H1+M4: 16.66%
const double FRACTAL_PERCENT_H4M16    = 0.3333;   // H4+M16: 33.33%
const double FRACTAL_PERCENT_H17M4    = 0.6666;   // H17+M4: 66.66%
const double FRACTAL_PERCENT_D2H20M16 = 1.3332;   // D2+H20+M16: 133.32%
const double FRACTAL_PERCENT_D11H9M4  = 2.6664;   // D11+H9+M4: 266.64%
const double FRACTAL_PERCENT_D45H12M16= 5.3328;   // D45+H12+M16: 533.28%

//+------------------------------------------------------------------+
//| ANGLE CONSTANTS (Gann Angles)                                    |
//| ثابت‌های زاویه (زوایای گن)                                       |
//+------------------------------------------------------------------+
#define GANN_8X1_ANGLE  82.5      // 8×1 angle
#define GANN_4X1_ANGLE  75.0      // 4×1 angle
#define GANN_3X1_ANGLE  71.565    // 3×1 angle
#define GANN_2X1_ANGLE  63.435    // 2×1 angle
#define GANN_1X1_ANGLE  45.0      // 1×1 angle (most important)
#define GANN_1X2_ANGLE  26.565    // 1×2 angle
#define GANN_1X3_ANGLE  18.435    // 1×3 angle
#define GANN_1X4_ANGLE  14.036    // 1×4 angle
#define GANN_1X8_ANGLE  7.125     // 1×8 angle

//+------------------------------------------------------------------+
//| TIME CONVERSIONS                                                  |
//| تبدیل‌های زمانی                                                   |
//+------------------------------------------------------------------+
#define SECONDS_IN_MINUTE 60
#define MINUTES_IN_HOUR   60
#define HOURS_IN_DAY      24
#define DAYS_IN_WEEK      7
#define DAYS_IN_MONTH_AVG 30
#define DAYS_IN_YEAR      365

#define SECONDS_IN_HOUR   3600    // 60 × 60
#define SECONDS_IN_DAY    86400   // 60 × 60 × 24
#define SECONDS_IN_WEEK   604800  // 60 × 60 × 24 × 7

//+------------------------------------------------------------------+
//| PRICE SCALING                                                     |
//| مقیاس‌گذاری قیمت                                                  |
//+------------------------------------------------------------------+
#define PIPS_MULTIPLIER_3_DIGIT 10.0   // برای سیمبل‌های 3 رقمی (JPY)
#define PIPS_MULTIPLIER_5_DIGIT 10.0   // برای سیمبل‌های 5 رقمی (EUR/USD)

//+------------------------------------------------------------------+
//| MATHEMATICAL CONSTANTS                                            |
//| ثابت‌های ریاضی                                                    |
//+------------------------------------------------------------------+
#define PI       3.14159265358979323846
#define TWO_PI   6.28318530717958647692
#define HALF_PI  1.57079632679489661923
#define E        2.71828182845904523536  // Euler's number
#define SQRT_2   1.41421356237309504880  // Square root of 2
#define SQRT_3   1.73205080756887729352  // Square root of 3

//+------------------------------------------------------------------+
