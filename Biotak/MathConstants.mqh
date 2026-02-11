#ifndef MATH_CONSTANTS_MQH
#define MATH_CONSTANTS_MQH

#property copyright " Biotak"

// TH Step Multipliers
#define SS_MULTIPLIER 1.5
#define LS_MULTIPLIER 2.0
#define CONTROL_MULTIPLIER 1.75
#define E_MULTIPLIER 0.75
#define TP_MULTIPLIER 2.25

// ATR
#define ATR_FACTOR_M 3.0
#define ATR_PERIODS_D1 14

// Fibonacci Ratios
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

// Golden Ratio
#define GOLDEN_RATIO 1.618033988749895
#define GOLDEN_RATIO_INVERSE 0.618033988749895

// Percentage Conversions
#define PERCENT_TO_DECIMAL 100.0
#define DECIMAL_TO_PERCENT 100.0

// Fractal Percentages (MotiveWave-compatible)
const double FRACTAL_PERCENT_M1       = 0.0208;
const double FRACTAL_PERCENT_M4       = 0.0417;
const double FRACTAL_PERCENT_M16      = 0.0833;
const double FRACTAL_PERCENT_H1M4     = 0.1666;
const double FRACTAL_PERCENT_H4M16    = 0.3333;
const double FRACTAL_PERCENT_H17M4    = 0.6666;
const double FRACTAL_PERCENT_D2H20M16 = 1.3332;
const double FRACTAL_PERCENT_D11H9M4  = 2.6664;
const double FRACTAL_PERCENT_D45H12M16= 5.3328;

// Gann Angles
#define GANN_8X1_ANGLE  82.5
#define GANN_4X1_ANGLE  75.0
#define GANN_3X1_ANGLE  71.565
#define GANN_2X1_ANGLE  63.435
#define GANN_1X1_ANGLE  45.0
#define GANN_1X2_ANGLE  26.565
#define GANN_1X3_ANGLE  18.435
#define GANN_1X4_ANGLE  14.036
#define GANN_1X8_ANGLE  7.125

// Time Conversions
#define SECONDS_IN_MINUTE 60
#define MINUTES_IN_HOUR   60
#define HOURS_IN_DAY      24
#define DAYS_IN_WEEK      7
#define DAYS_IN_MONTH_AVG 30
#define DAYS_IN_YEAR      365
#define SECONDS_IN_HOUR   3600
#define SECONDS_IN_DAY    86400
#define SECONDS_IN_WEEK   604800

// Price Scaling
#define PIPS_MULTIPLIER_3_DIGIT 10.0
#define PIPS_MULTIPLIER_5_DIGIT 10.0

// Mathematical Constants
#define PI       3.14159265358979323846
#define TWO_PI   6.28318530717958647692
#define HALF_PI  1.57079632679489661923
#define E        2.71828182845904523536
#define SQRT_2   1.41421356237309504880
#define SQRT_3   1.73205080756887729352

#endif
    // MATH_CONSTANTS_MQH