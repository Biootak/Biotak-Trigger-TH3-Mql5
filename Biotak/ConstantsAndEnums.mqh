#define MAX_LINES 10
#define CACHE_TIMEOUT 60

// Performance & Safety Constants
#define MAX_SAFE_LEVELS 200           // Maximum safe number of levels per side (was 2000 - too many objects)
#define MAX_SAFE_OBJECTS 3000         // Warning threshold for total objects
#define CRITICAL_OBJECT_LIMIT 50000   // Critical threshold (MT5 limit ~64K)
#define CPU_WARNING_MS 100            // Warning if OnCalculate takes >100ms
#define CPU_CRITICAL_MS 500           // Critical if OnCalculate takes >500ms

// Array Safety Constants (GOLD FIX v3)
#define MAX_PREFIX_COUNT 50           // Maximum number of object prefixes (with safety margin)
#define OBJECT_COUNT_INCREASE_THRESHOLD 100  // Trigger cleanup if objects increased by 100
#define REDRAW_THROTTLE_SECONDS 10    // Minimum 10 seconds between redraws
#define CLEANUP_INTERVAL_SECONDS 300  // 5 minutes between periodic cleanups

// Division Safety Constants (GOLD FIX v3)
#define MIN_SAFE_DIVISIONS 0.001      // Minimum divisions to prevent precision loss
#define MAX_SAFE_FACTOR 10000.0       // Maximum factor value to prevent overflow

// تعریف ثابت‌های مورد نیاز برای تنظیم خصوصیات آبجکت‌ها
#ifndef OBJPROP_BOLD
#define OBJPROP_BOLD 5
#endif

const string FRACTAL_TIMEFRAMES[] = {
    "M1", "M4", "M16", "H1+M4", "H4+M16", "H17+M4",
    "D2+H20+M16", "D11+H9+M4", "D45+H12+M16"
};
// Adjusted by factor 1.0415625 so H17+M4 (1024min) = 66.66% instead of 64%
// These percentages MUST match MotiveWave Constants.java FRACTAL_PERCENTAGES
const double MODIFIED_FRACTAL_PERCENTAGES[] = {
    0.0208,   // M1: 2.08%
    0.0417,   // M4: 4.17%
    0.0833,   // M16: 8.33%
    0.1666,   // H1+M4: 16.66%
    0.3333,   // H4+M16: 33.33%
    0.6666,   // H17+M4: 66.66% ✓
    1.3332,   // D2+H20+M16: 133.32%
    2.6664,   // D11+H9+M4: 266.64%
    5.3328    // D45+H12+M16: 533.28%
};
const color FRACTAL_COLORS[] = {
    clrBlack, clrBlack, clrBlack, clrBlue, clrRed,
    clrRed, clrGreen, clrBlack, clrBlack
};
const string STANDARD_TIMEFRAMES[] = {"D1", "W1", "MN1"};
const int STANDARD_MINUTES[] = {1440, 10080, 43200};
const color STANDARD_COLORS[] = {clrBlue, clrBlue, clrBlue};

enum ENUM_TH_START_POINT_TYPE {
    TH_START_POINT_MIDPOINT = 0,      // Midpoint
    TH_START_POINT_HISTORICAL_HIGH = 1, // Historical High
    TH_START_POINT_HISTORICAL_LOW = 2,  // Historical Low
    TH_START_POINT_CUSTOM_PRICE = 3    // Custom Price
};

enum ENUM_LINE_OBJECT_TYPE {
    LINE_OBJECT_HORIZONTAL_LINE = 0,
    LINE_OBJECT_RAY_LINE = 1
};

enum ENUM_LABEL_CORNER_POSITION {
    LABEL_CORNER_LEFT_TOP = 0,
    LABEL_CORNER_LEFT_BOTTOM = 1
};

enum ENUM_LABEL_ARRANGEMENT {
    LABEL_ARRANGEMENT_VERTICAL = 0,
    LABEL_ARRANGEMENT_HORIZONTAL = 1
};

// Step calculation modes (matching MotiveWave implementation exactly)
// E_STEP removed - TP is now a standalone mode (like Java version)
enum ENUM_STEP_CALCULATION_MODE {
    TH_STEP = 0,        // Traditional TH step mode
    SS_LS_STEP = 1,     // Short Step / Long Step alternating mode
    M_STEP = 2,         // M levels mode (Control-based)
    TP_STEP = 3,        // TP levels mode (TH × 0.75 × 3 = TH × 2.25)
    COMBO_STEP = 4,     // Combo Step mode (customizable: Component1 + Component2)
    FACTOR_STEP = 5     // Factor Step mode (divides High-Low range by Factor × 2)
};

// Factor calculation mode (Auto vs Manual)
enum ENUM_FACTOR_MODE {
    FACTOR_MODE_AUTO = 0,    // Auto (based on TH)
    FACTOR_MODE_MANUAL = 1   // Manual (user-defined)
};

//+------------------------------------------------------------------+
//| Factor Auto Basis - What to base the auto calculation on         |
//| مبنای محاسبه خودکار Factor                                       |
//|                                                                  |
//| CONTROL: Average of SS and LS (TH×1.75) - Balanced [DEFAULT]    |
//| SS: Short Step (TH×1.5) - Closer levels, more lines             |
//| LS: Long Step (TH×2.0) - Wider levels, fewer lines              |
//| TH: Pure TH (TH×1.0) - Standard spacing                         |
//| TRIGGER: Current timeframe TH - Responsive to current TF        |
//| PATTERN: 4x timeframe TH - Medium-term structure                |
//| STRUCTURE: 16x timeframe TH - Long-term structure               |
//| COMBO: Average of 2 components - Custom mix like Combo Mode     |
//+------------------------------------------------------------------+
enum ENUM_FACTOR_AUTO_BASIS {
    FACTOR_BASIS_CONTROL = 0,      // Control: (SS+LS)/2 = TH×1.75 [Balanced]
    FACTOR_BASIS_SS = 1,           // Short Step: TH×1.5 (More levels)
    FACTOR_BASIS_LS = 2,           // Long Step: TH×2.0 (Fewer levels)
    FACTOR_BASIS_TH = 3,           // Pure TH: TH×1.0 (Standard)
    FACTOR_BASIS_TRIGGER = 4,      // Trigger: Current TF (Responsive)
    FACTOR_BASIS_PATTERN = 5,      // Pattern: 4x TF (Medium-term)
    FACTOR_BASIS_STRUCTURE = 6,    // Structure: 16x TF (Long-term)
    FACTOR_BASIS_COMBO = 7         // Combo: Average of 2 components (Custom)
};

//+------------------------------------------------------------------+
//| Structure Base Multiplier - Valid range 2-9                      |
//| ضریب پایه ساختار - محدوده معتبر ۲ تا ۹                          |
//|                                                                  |
//| Defines the hierarchical structure levels:                      |
//| L1 = base^1, L2 = base^2, L3 = base^3, L4 = base^4, L5 = base^5|
//|                                                                  |
//| Example with base=3: L1=3, L2=9, L3=27, L4=81, L5=243          |
//| Example with base=4: L1=4, L2=16, L3=64, L4=256, L5=1024       |
//|                                                                  |
//| NOTE: Value 1 is INVALID because all levels become identical    |
//| (1^1 = 1^2 = 1^3 = 1^4 = 1^5 = 1)                              |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_BASE_MULTIPLIER {
    BASE_MULTIPLIER_2 = 2,   // Base 2: L1=2, L2=4, L3=8, L4=16, L5=32
    BASE_MULTIPLIER_3 = 3,   // Base 3: L1=3, L2=9, L3=27, L4=81, L5=243 [DEFAULT]
    BASE_MULTIPLIER_4 = 4,   // Base 4: L1=4, L2=16, L3=64, L4=256, L5=1024
    BASE_MULTIPLIER_5 = 5,   // Base 5: L1=5, L2=25, L3=125, L4=625, L5=3125
    BASE_MULTIPLIER_6 = 6,   // Base 6: L1=6, L2=36, L3=216, L4=1296, L5=7776
    BASE_MULTIPLIER_7 = 7,   // Base 7: L1=7, L2=49, L3=343, L4=2401, L5=16807
    BASE_MULTIPLIER_8 = 8,   // Base 8: L1=8, L2=64, L3=512, L4=4096, L5=32768
    BASE_MULTIPLIER_9 = 9    // Base 9: L1=9, L2=81, L3=729, L4=6561, L5=59049
};

// Harmonic Ratio validation constants
#define MIN_HARMONIC_RATIO 1.01   // حداقل 1% تفاوت (meaningful alternation)
#define MAX_HARMONIC_RATIO 2.0    // حداکثر 2x (maximum variation)
#define DEFAULT_HARMONIC_RATIO 1.333  // Golden-like ratio (4/3)

//+------------------------------------------------------------------+
//| Mean Type Selection (for aggregates and quick test)              |
//| انتخاب نوع میانگین (برای aggregates و تست سریع)                 |
//+------------------------------------------------------------------+
enum ENUM_MEAN_TYPE {
    MEAN_ARITHMETIC = 0,    // Arithmetic Mean: (A + B + ...) / n
    MEAN_GEOMETRIC = 1,     // Geometric Mean: ⁿ√(A × B × ...)
    MEAN_HARMONIC = 2       // Harmonic Mean: n / (1/A + 1/B + ...)
};

// NOTE: ENUM_QUICK_TEST_MODE removed - not used anywhere
// Quick Test is controlled by ENUM_COMBO_MODE instead

//+------------------------------------------------------------------+
//| Quick Test Presets (Simplified Component Selection)              |
//| Preset‌های تست سریع (انتخاب ساده components)                     |
//|                                                                  |
//| NOTE: CUSTOM removed - use Advanced mode for full control       |
//+------------------------------------------------------------------+
enum ENUM_QUICK_TEST_PRESET {
    QUICK_PRESET_TRIGGER_PATTERN = 0,       // Trigger + Pattern (2 TF)
    QUICK_PRESET_ALL_4TF = 1,               // Sub + Trigger + Pattern + Structure (4 TF)
    QUICK_PRESET_TRIGGER_PATTERN_STRUCTURE = 2,  // Trigger + Pattern + Structure (3 TF)
    QUICK_PRESET_PATTERN_STRUCTURE = 3,     // Pattern + Structure (2 TF)
    QUICK_PRESET_TRIGGER_ONLY = 4           // Trigger only (1 TF)
};

// SS/LS basis type
enum ENUM_SSLS_BASIS_TYPE {
    SSLS_BASIS_STRUCTURE = 0,   // Based on Structure TH
    SSLS_BASIS_PATTERN = 1,     // Based on Pattern TH
    SSLS_BASIS_TRIGGER = 2      // Based on Trigger TH
};

//+------------------------------------------------------------------+
//| Calculation Basis (matching Java CalculationBasis enum)          |
//| مبنای محاسبات (مطابق با جاوا)                                    |
//|                                                                  |
//| TH_BASIS - محاسبات بر اساس TH (درصد قیمت × √دقیقه)               |
//| ATR_BASIS - محاسبات بر اساس ATR واقعی (Weighted ATR)             |
//+------------------------------------------------------------------+
enum ENUM_CALCULATION_BASIS {
    CALC_BASIS_TH = 0,          // TH-Based (Theoretical) - پیش‌فرض
    CALC_BASIS_ATR = 1          // ATR-Based (Actual) - واقعی
};

// M step basis type
enum ENUM_MSTEP_BASIS_TYPE {
    MSTEP_BASIS_C_BASED = 0,    // Control-based (C ladder with every 3rd as M)
    MSTEP_BASIS_M_EQUAL = 1     // Equal M spacing
};

// Smart Combo Component Selection (Unified)
// انتخاب هوشمند اجزای ترکیبی (یکپارچه)
enum ENUM_COMBO_COMPONENT_ITEM {
    // Sub Components (Fastest - 1/4x)
    COMP_SUB_TH = 0,            // Sub TH
    COMP_SUB_SS = 1,            // Sub SS
    COMP_SUB_LS = 2,            // Sub LS
    
    // Trigger Components (Current - 1x)
    COMP_TRIGGER_TH = 3,        // Trigger TH
    COMP_TRIGGER_SS = 4,        // Trigger SS
    COMP_TRIGGER_LS = 5,        // Trigger LS
    
    // Pattern Components (Medium - 4x)
    COMP_PATTERN_TH = 6,        // Pattern TH
    COMP_PATTERN_SS = 7,        // Pattern SS
    COMP_PATTERN_LS = 8,        // Pattern LS
    
    // Structure Components (Slow - 16x)
    COMP_STRUCTURE_TH = 9,      // Structure TH
    COMP_STRUCTURE_SS = 10,     // Structure SS
    COMP_STRUCTURE_LS = 11,     // Structure LS
    
    // ═══════════════════════════════════════════════════════════════
    // AGGREGATE COMPONENTS (میانگین‌های ترکیبی)
    // These calculate the mean of TH, SS, LS for a timeframe
    // ═══════════════════════════════════════════════════════════════
    COMP_SUB_MEAN = 12,         // Sub Mean: (Sub_TH + Sub_SS + Sub_LS) / 3
    COMP_TRIGGER_MEAN = 13,     // Trigger Mean: (Trigger_TH + Trigger_SS + Trigger_LS) / 3
    COMP_PATTERN_MEAN = 14,     // Pattern Mean: (Pattern_TH + Pattern_SS + Pattern_LS) / 3
    COMP_STRUCTURE_MEAN = 15,   // Structure Mean: (Structure_TH + Structure_SS + Structure_LS) / 3
    
    // Special
    COMP_IGNORE = 16            // Ignore (None)
};

//+------------------------------------------------------------------+
//| Combo Operators for Calculator Mode (Manual)                     |
//| عملگرهای ترکیبی برای حالت ماشین حساب (دستی)                      |
//|                                                                  |
//| BINARY OPERATORS (2 operands): OP_PLUS to OP_HARMONIC_MEAN      |
//| N-ARY OPERATORS (all components): OP_GEOMETRIC_MEAN_ALL to end  |
//|                                                                  |
//| USAGE EXAMPLE (N-ARY):                                           |
//| Component 1: Trigger SS                                          |
//| Operator 1: Geometric Mean (All)  ← Collects ALL components     |
//| Component 2: Pattern LS                                          |
//| Operator 2: [Ignored]                                            |
//| Component 3: Structure TH                                        |
//| Operator 3: [Ignored]                                            |
//| Component 4: Ignore                                              |
//| Result: ³√(Trigger_SS × Pattern_LS × Structure_TH)              |
//+------------------------------------------------------------------+
enum ENUM_COMBO_OPERATOR {
    // ═══════════════════════════════════════════════════════════════
    // BINARY OPERATORS (عملگرهای دوتایی) - Work on 2 values
    // ═══════════════════════════════════════════════════════════════
    OP_PLUS = 0,                // Plus: A + B
    OP_MINUS = 1,               // Minus: A - B
    OP_MULTIPLY = 2,            // Multiply: A × B
    OP_DIVIDE = 3,              // Divide: A ÷ B
    OP_AVERAGE = 4,             // Arithmetic Mean: (A + B) / 2
    OP_GEOMETRIC_MEAN = 5,      // Geometric Mean: √(A × B)
    OP_HARMONIC_MEAN = 6,       // Harmonic Mean: 2AB / (A + B)
    
    // ═══════════════════════════════════════════════════════════════
    // N-ARY OPERATORS (عملگرهای چندتایی) - Work on ALL active components
    // When used as Operator 1, collects ALL non-IGNORE components
    // ═══════════════════════════════════════════════════════════════
    OP_GEOMETRIC_MEAN_ALL = 7,  // Geometric Mean (All): ⁿ√(C1 × C2 × ... × Cn)
    OP_ARITHMETIC_MEAN_ALL = 8, // Arithmetic Mean (All): (C1 + C2 + ... + Cn) / n
    OP_HARMONIC_MEAN_ALL = 9,   // Harmonic Mean (All): n / (1/C1 + 1/C2 + ... + 1/Cn)
    OP_MIN_ALL = 10,            // Minimum (All): min(C1, C2, ..., Cn)
    OP_MAX_ALL = 11,            // Maximum (All): max(C1, C2, ..., Cn)
    
    // ═══════════════════════════════════════════════════════════════
    // SPECIAL
    // ═══════════════════════════════════════════════════════════════
    OP_NONE = 12                // None (End Chain)
};

//+------------------------------------------------------------------+
//| Calculator Topology (Architecture of Calculation)                |
//| معماری محاسبات ماشین حساب (ساختار فرمول)                         |
//+------------------------------------------------------------------+
enum ENUM_CALCULATOR_TOPOLOGY {
    TOPOLOGY_LINEAR = 0,        // Linear: ((A op B) op C) op D [Sequential]
    TOPOLOGY_DUAL_GROUP = 1     // Dual Group: (A op B) MainOp (C op D) [Structural]
};

//+------------------------------------------------------------------+
//| Advanced Combo Operations for Factor Auto Basis                  |
//| عملیات‌های پیشرفته Combo برای Factor Auto Basis                  |
//+------------------------------------------------------------------+
enum ENUM_COMBO_OPERATION {
    COMBO_OP_AVERAGE = 0,       // Average: (A + B) / 2 [Default]
    COMBO_OP_ADD = 1,           // Add: A + B
    COMBO_OP_SUBTRACT = 2,      // Subtract: A - B (or |A - B|)
    COMBO_OP_MULTIPLY = 3,      // Multiply: A × B
    COMBO_OP_MIN = 4,           // Minimum: min(A, B) or min(A, B, C)
    COMBO_OP_MAX = 5,           // Maximum: max(A, B) or max(A, B, C)
    COMBO_OP_WEIGHTED = 6       // Weighted: A×W1 + B×W2 (W1+W2=1)
};

//+------------------------------------------------------------------+
//| Combo Mode Selection (Quick Test / Preset / Advanced)            |
//| انتخاب حالت Combo (تست سریع / Preset / پیشرفته)                 |
//|                                                                  |
//| THREE INDEPENDENT MODES - No overlap, no conflicts              |
//|                                                                  |
//| QUICK_TEST: Fast testing with presets (For testing combinations)|
//|   - Select preset (which timeframes)                            |
//|   - Select step type (TH/SS/LS for all)                         |
//|   - Select mean type (how to combine)                           |
//|   Uses: inpQuickTestPreset, inpQuickTestStepType, inpQuickTestMeanType |
//|                                                                  |
//| PRESET: Quick select from ready-to-use combinations             |
//|   - 15 predefined combinations                                  |
//|   - Each preset has fixed components and operation              |
//|   - Recommended for daily use                                   |
//|   Uses: inpComboPreset                                          |
//|                                                                  |
//| ADVANCED: Full manual control (For power users)                 |
//|   - Select topology (Linear/Dual Group)                         |
//|   - Select 4 components and 3 operators                         |
//|   - Supports N-ary operators (work on all components)           |
//|   - Maximum flexibility                                         |
//|   Uses: inpComboTopology, inpComboComp1-4, inpComboOp1-3       |
//|                                                                  |
//| GLOBAL SETTING (All modes):                                     |
//|   - inpAggregateMeanType: ONLY for COMP_*_MEAN components       |
//+------------------------------------------------------------------+
enum ENUM_COMBO_MODE {
    COMBO_MODE_QUICK_TEST = 0,  // Quick Test (Fast testing)
    COMBO_MODE_PRESET = 1,      // Preset Mode (Recommended)
    COMBO_MODE_ADVANCED = 2     // Advanced Mode (Full control)
};

//+------------------------------------------------------------------+
//| Timeframe Types for Advanced Combo                               |
//| انواع تایم‌فریم برای Combo پیشرفته                               |
//+------------------------------------------------------------------+
enum ENUM_COMBO_TIMEFRAME_TYPE {
    COMBO_TF_SUB = 0,           // Sub: 1/4 current (faster)
    COMBO_TF_TRIGGER = 1,       // Trigger: Current timeframe
    COMBO_TF_PATTERN = 2,       // Pattern: 4x current
    COMBO_TF_STRUCTURE = 3      // Structure: 16x current
};

//+------------------------------------------------------------------+
//| Step Size Type (TH, SS, LS)                                      |
//| نوع اندازه گام                                                    |
//+------------------------------------------------------------------+
enum ENUM_COMBO_STEP_TYPE {
    COMBO_STEP_TH = 0,          // TH: Base step (1.0×)
    COMBO_STEP_SS = 1,          // SS: Short step (1.5×)
    COMBO_STEP_LS = 2           // LS: Long step (2.0×)
};

//+------------------------------------------------------------------+
//| Preset Combinations (Common Use Cases) - OPTIMIZED FOR UX        |
//| ترکیب‌های از پیش تعریف شده - بهینه شده برای کاربر               |
//|                                                                  |
//| DESIGN PRINCIPLE: 80/20 Rule - 15 presets cover 98% of needs    |
//| اصل طراحی: قانون 80/20 - 15 preset پوشش 98% نیاز               |
//|                                                                  |
//| IMPORTANT: COMBO_PRESET_LEGACY_ADD is the default for backward  |
//| compatibility with old Combo Step Mode (Component1 + Component2)|
//+------------------------------------------------------------------+
enum ENUM_COMBO_PRESET {
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 0: LEGACY (سازگاری با نسخه قدیم) - DEFAULT
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_LEGACY_ADD = 0,            // Legacy: Trigger SS + Pattern SS (ADD)
    
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 1: BALANCED (متعادل) - Most Common (58% usage)
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_BALANCED_MEDIUM = 1,       // Balanced Medium: (Pattern + Trigger) / 2 [Most Popular]
    COMBO_PRESET_BALANCED_LONG = 2,         // Balanced Long: (Structure + Pattern) / 2
    COMBO_PRESET_BALANCED_TRIPLE = 3,       // Triple Balanced: (Trigger + Pattern + Structure) / 3
    COMBO_PRESET_BALANCED_MIN = 4,          // Balanced Min: min(Pattern, Trigger)
    
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 2: CONSERVATIVE (محافظه‌کار) - Fewer Levels (15% usage)
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_CONSERVATIVE = 5,          // Conservative: max(Structure, Pattern)
    COMBO_PRESET_ULTRA_CONSERVATIVE = 6,    // Ultra Conservative: Structure TH
    COMBO_PRESET_TRIPLE_CONSERVATIVE = 7,   // Triple Conservative: max(Trigger, Pattern, Structure)
    
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 3: AGGRESSIVE (تهاجمی) - More Levels (11% usage)
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_AGGRESSIVE = 8,            // Aggressive: min(Pattern, Trigger)
    COMBO_PRESET_ULTRA_AGGRESSIVE = 9,      // Ultra Aggressive: min(Trigger, Sub)
    COMBO_PRESET_TRIPLE_AGGRESSIVE = 10,    // Triple Aggressive: min(Trigger, Pattern, Structure)
    
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 4: SPECIAL (ویژه) - Advanced Use Cases (4% usage)
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_TREND_FILTER = 11,         // Trend Filter: Structure - Sub
    COMBO_PRESET_VOLATILITY_ADAPTIVE = 12,  // Volatility: (Structure + Sub) / 2
    
    // ═══════════════════════════════════════════════════════════════
    // CATEGORY 5: ADVANCED USER (دستی) - For Advanced Users (2% usage)
    // These presets redirect to Advanced Mode for full control
    // ═══════════════════════════════════════════════════════════════
    COMBO_PRESET_MANUAL_DUAL = 13,          // Advanced Dual: User-defined (2 components) → Redirects to Advanced Mode
    COMBO_PRESET_MANUAL_TRIPLE = 14         // Advanced Triple: User-defined (3 components) → Redirects to Advanced Mode
};

// Mode label duration options
// مدت زمان نمایش لیبل تغییر مود
enum ENUM_MODE_LABEL_DURATION {
    MODE_LABEL_1_SEC = 1,       // 1 Second
    MODE_LABEL_2_SEC = 2,       // 2 Seconds (Default)
    MODE_LABEL_3_SEC = 3,       // 3 Seconds
    MODE_LABEL_5_SEC = 5,       // 5 Seconds
    MODE_LABEL_10_SEC = 10,     // 10 Seconds
    MODE_LABEL_PERMANENT = 0    // Permanent (Always Show)
};

// TH3 Label Position
// موقعیت نمایش label های TH3
enum ENUM_TH3_LABEL_POSITION {
    TH3_LABEL_START = 0,        // Start (Beginning of line)
    TH3_LABEL_MIDDLE = 1,       // Middle (Center of visible range)
    TH3_LABEL_END = 2,          // End (Right side - Default)
    TH3_LABEL_HIDDEN = 3        // Hidden (No labels)
};

// Unified Zone Display Style (Used by ALL modes)
// نحوه نمایش Zone ها (برای تمام مودها)
enum ENUM_ZONE_STYLE {
    ZONE_STYLE_LINES = 0,         // Lines Only (Two boundary lines)
    ZONE_STYLE_BOX_FILLED = 1,    // Filled Box (Rectangle with fill)
    ZONE_STYLE_BOX_EMPTY = 2,     // Empty Box (Rectangle outline only)
    ZONE_STYLE_HIDDEN = 3         // Hidden (No zones)
};

// Legacy aliases for backward compatibility
// نام‌های قدیمی برای سازگاری با کد قبلی
#define ENUM_TH3_ZONE_STYLE ENUM_ZONE_STYLE
#define ENUM_FACTOR_ZONE_STYLE ENUM_ZONE_STYLE
#define TH3_ZONE_LINES ZONE_STYLE_LINES
#define TH3_ZONE_BOX_FILLED ZONE_STYLE_BOX_FILLED
#define TH3_ZONE_BOX_EMPTY ZONE_STYLE_BOX_EMPTY
#define TH3_ZONE_HIDDEN ZONE_STYLE_HIDDEN
#define FACTOR_ZONE_LINES ZONE_STYLE_LINES
#define FACTOR_ZONE_BOX_FILLED ZONE_STYLE_BOX_FILLED
#define FACTOR_ZONE_BOX_EMPTY ZONE_STYLE_BOX_EMPTY
#define FACTOR_ZONE_HIDDEN ZONE_STYLE_HIDDEN

// TH3 Drawing Mode
// حالت رسم TH3 (Steps یا AB=CD)
enum ENUM_TH3_DRAWING_MODE {
    TH3_MODE_STEPS = 0,         // Steps Mode (2-point drag)
    TH3_MODE_ABCD = 1           // AB=CD Mode (3-point click: A, B, C → calculates D)
};

//+------------------------------------------------------------------+
//| TH3 Frequency Test System - Available Frequencies (0-100%)      |
//| سیستم تست فرکانس TH3 - فرکانس‌های موجود (0 تا 100 درصد)         |
//+------------------------------------------------------------------+
// Base frequencies: multiples of 3.125% (1/32) - 32 frequencies
// Plus: Geometric and Harmonic means between adjacent frequencies
// Total: ~94 frequencies covering full 0-100% range
// 
// فرکانس‌های پایه: مضرب 3.125% (1/32) - 32 فرکانس
// به علاوه: میانگین هندسی و هارمونیک بین فرکانس‌های مجاور
// جمع: حدود 94 فرکانس که کل بازه 0-100% را پوشش می‌دهند
// TH3 Frequency Test Array - EXTENDED (Base + Key means up to 120%)
// آرایه فرکانس‌های تست TH3 - گسترش یافته (Base + میانگین‌های کلیدی تا 120%)
// Includes all base frequencies + geometric means between them (3.125% to 120%)
// شامل همه فرکانس‌های base + میانگین هندسی بین اونها (3.125% تا 120%)
const double TH3_TEST_FREQUENCIES[] = {
    // Original range: 3.125% to 100% (63 frequencies)
    3.125,   // 1/32
    4.419,   // √(3.125 × 6.25)
    6.25,    // 2/32
    7.629,   // √(6.25 × 9.375)
    9.375,   // 3/32
    10.825,  // √(9.375 × 12.5)
    12.5,    // 4/32
    13.975,  // √(12.5 × 15.625)
    15.625,  // 5/32
    17.089,  // √(15.625 × 18.75)
    18.75,   // 6/32
    20.176,  // √(18.75 × 21.875)
    21.875,  // 7/32
    23.242,  // √(21.875 × 25)
    25.0,    // 8/32 - Quarter 1
    26.491,  // √(25 × 28.125)
    28.125,  // 9/32 - DEFAULT (index 16)
    29.619,  // √(28.125 × 31.25)
    31.25,   // 10/32
    32.795,  // √(31.25 × 34.375)
    34.375,  // 11/32
    35.951,  // √(34.375 × 37.5)
    37.5,    // 12/32
    39.063,  // √(37.5 × 40.625)
    40.625,  // 13/32
    42.157,  // √(40.625 × 43.75)
    43.75,   // 14/32
    45.234,  // √(43.75 × 46.875)
    46.875,  // 15/32
    48.295,  // √(46.875 × 50)
    50.0,    // 16/32 - MIDPOINT
    51.705,  // √(50 × 53.125)
    53.125,  // 17/32
    54.766,  // √(53.125 × 56.25)
    56.25,   // 18/32
    57.843,  // √(56.25 × 59.375)
    59.375,  // 19/32
    60.937,  // √(59.375 × 62.5)
    62.5,    // 20/32
    64.049,  // √(62.5 × 65.625)
    65.625,  // 21/32
    67.187,  // √(65.625 × 68.75)
    68.75,   // 22/32
    70.205,  // √(68.75 × 71.875)
    71.875,  // 23/32
    73.381,  // √(71.875 × 75)
    75.0,    // 24/32 - Quarter 3
    76.509,  // √(75 × 78.125)
    78.125,  // 25/32
    79.658,  // √(78.125 × 81.25)
    81.25,   // 26/32
    82.795,  // √(81.25 × 84.375)
    84.375,  // 27/32
    85.911,  // √(84.375 × 87.5)
    87.5,    // 28/32
    89.024,  // √(87.5 × 90.625)
    90.625,  // 29/32
    92.157,  // √(90.625 × 93.75)
    93.75,   // 30/32
    95.299,  // √(93.75 × 96.875)
    96.875,  // 31/32
    98.425,  // √(96.875 × 100)
    100.0,   // 32/32 - Full range
    
    // Extended range: 100% to 120% (13 additional frequencies)
    101.491, // √(100 × 103.125)
    103.125, // 33/32
    105.176, // √(103.125 × 106.25)
    106.25,  // 34/32
    107.795, // √(106.25 × 109.375)
    109.375, // 35/32
    110.825, // √(109.375 × 112.5)
    112.5,   // 36/32
    114.024, // √(112.5 × 115.625)
    115.625, // 37/32
    117.176, // √(115.625 × 118.75)
    118.75,  // 38/32
    119.372, // √(118.75 × 120)
    120.0    // 38.4/32 - Extended maximum
};

const int TH3_FREQUENCY_COUNT = 76; // 38 base + 38 geometric means (extended to 120%)

//+------------------------------------------------------------------+
//| PIPELINE ARCHITECTURE STRUCTS (Added for Modular Refactoring)    |
//| ساختارهای معماری پایپ‌لاین (برای ریفکتورینگ ماژولار)            |
//+------------------------------------------------------------------+

// 1. Raw Calculation Data (خروجی لایه محاسبات)
struct SLevelRawData {
    double price;           // قیمت سطح
    int logicalStep;        // شماره گام منطقی (مثلاً 0, 1, -1)
    string label;           // برچسب اختیاری
    int stepTypeIndex;      // نوع گام (برای مودهای SS/LS یا Factor)
};

// 2. Render Information for Lines (اطلاعات نهایی برای رسم خط)
struct SLineRenderInfo {
    bool isVisible;         // آیا باید رسم شود؟
    string name;            // نام یکتای آبجکت
    double price;           // قیمت
    color clr;              // رنگ
    ENUM_LINE_STYLE style;  // استایل
    int width;              // ضخامت
    string tooltip;         // تول‌تیپ
    bool selectable;        // قابل انتخاب بودن
    bool selected;          // وضعیت انتخاب
    int zOrder;             // اولویت نمایش
};

// 3. Render Information for Zones (اطلاعات نهایی برای رسم زون)
struct SZoneRenderInfo {
    bool isVisible;         // آیا باید رسم شود؟
    string name;            // نام یکتای آبجکت
    double topPrice;        // قیمت بالا
    double bottomPrice;     // قیمت پایین
    color clr;              // رنگ پس‌زمینه
    int transparency;       // شفافیت (برای Rectangle Label اگر نیاز شد، فعلا Rect ساده است)
    bool filled;            // توپر بودن
};

// 4. Configuration for Styling (تنظیمات استایل‌دهی)
struct SStyleConfig {
    // Structure Settings
    bool showStructure;
    color structColorL1;
    ENUM_LINE_STYLE structStyleL1;
    int structWidthL1;
    int baseMultiplier;
    
    // Trigger Settings
    bool showTrigger;
    color triggerColor;
    ENUM_LINE_STYLE triggerStyle;
    int triggerWidth;
    
    // Global Settings
    bool globalShowLines;
    
    // Zone Settings
    bool showZones;
    int zoneTransparency;
    double zoneHeightPercent; // درصد ارتفاع زون نسبت به گام (0.0-1.0)
};

//+------------------------------------------------------------------+
//| STRUCTURE: Level Classification Result                           |
//| نتیجه طبقه‌بندی سطح (Active/Inactive, Structure/Trigger)         |
//+------------------------------------------------------------------+
struct SLevelClassification {
    bool isActive;        // آیا این سطح فعال است؟ (باید در محاسبات لحاظ شود)
    bool isStructure;     // آیا سطح Structure است؟
    color levelColor;     // رنگ سطح
    int style;            // استایل خط (STYLE_SOLID, STYLE_DOT, etc.)
    int width;            // عرض خط (1-5)
};

//+------------------------------------------------------------------+
//| STRUCTURE: Zone Geometry Data                                    |
//| داده‌های هندسی زون (مستقل از رسم)                                |
//+------------------------------------------------------------------+
struct SZoneGeometry {
    bool isValid;         // آیا این زون معتبر است؟
    double topPrice;      // قیمت بالای زون (normalized)
    double bottomPrice;   // قیمت پایین زون (normalized)
    double midPoint;      // نقطه میانی بین دو سطح
    int linkedLevelIndex; // ایندکس سطحی که این زون به آن متصل است
};

//+------------------------------------------------------------------+
//| STRUCTURE: Zone Validation Result                                |
//| نتیجه اعتبارسنجی زون                                             |
//+------------------------------------------------------------------+
struct SZoneValidationResult {
    bool isValid;         // آیا زون معتبر است؟
    string errorMessage;  // پیام خطا (در صورت عدم اعتبار)
    int errorCode;        // کد خطا (0 = موفق)
};

//+------------------------------------------------------------------+
//| ENUM: Zone Validation Error Codes                                |
//| کدهای خطای اعتبارسنجی زون                                        |
//+------------------------------------------------------------------+
enum ENUM_ZONE_ERROR {
    ZONE_ERROR_NONE = 0,              // بدون خطا
    ZONE_ERROR_INVALID_PRICES = 1,    // قیمت‌های نامعتبر
    ZONE_ERROR_INVALID_HEIGHT = 2,    // ارتفاع نامعتبر
    ZONE_ERROR_EQUAL_PRICES = 3,      // قیمت‌های برابر
    ZONE_ERROR_INVERTED_BOUNDS = 4,   // مرزهای معکوس (top < bottom)
    ZONE_ERROR_OUT_OF_RANGE = 5,      // خارج از محدوده معقول
    ZONE_ERROR_INVALID_TIMEFRAME = 6  // تایم‌فریم نامعتبر
};

//+------------------------------------------------------------------+
//| TH3 Object Name Suffixes (Magic Numbers Elimination)            |
//| پسوندهای نام اشیاء TH3 (حذف Magic Numbers)                       |
//+------------------------------------------------------------------+
const string TH3_SUFFIX_LINE_AB = "_Line_AB";
const string TH3_SUFFIX_LINE_BC = "_Line_BC";
const string TH3_SUFFIX_TARGET = "_Target_";
const string TH3_SUFFIX_POINT = "_Point_";
const string TH3_SUFFIX_LABEL = "_Label_";
const string TH3_SUFFIX_INFO = "_Info";
const string TH3_SUFFIX_ZONE = "_Zone";
